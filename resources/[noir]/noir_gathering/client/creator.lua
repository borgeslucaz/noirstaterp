---Criador de rotas para admin. Tudo é editado num rascunho local e só vira rota quando
---o admin salva; o servidor revalida o rascunho inteiro antes de gravar.

local Config = require 'config.shared'
local Rules = require 'shared.rules'
local Integrations = require 'client.integrations'
local Placement = require 'client.placement'

local Creator = {}

---Dados do servidor: rotas completas, catálogo de itens e grupos.
---@type { routes: { id: integer, route: table }[], items: table[], labels: table<string, string>, groups: table[], progression: table? }?
local data = nil

---@type integer[]
local debugBlips = {}

local limits = Config.limits

local openMain, openRoute, openItems, openItem, openExtras, openPoints, openHaul, openRewards

-- Utilidades ----------------------------------------------------------------------------

local function deepCopy(value)
    return json.decode(json.encode(value))
end

local function itemLabel(name)
    return data and data.labels[name] or name
end

local function yesNo(value)
    return value and locale('yes') or locale('no')
end

local function notifyUpdated()
    Integrations.notify(locale('admin_updated'), 'success')
end

local function confirm(text)
    return lib.alertDialog({
        header = locale('admin_confirm'),
        content = text,
        centered = true,
        cancel = true,
    }) == 'confirm'
end

local function showMenu(id, title, options, back)
    lib.registerContext({ id = id, title = title, menu = back, options = options })
    lib.showContext(id)
end

local function itemOptions()
    local options = {}
    for _, item in ipairs(data.items) do
        options[#options + 1] = { value = item.name, label = ('%s (%s)'):format(item.label, item.name) }
    end
    return options
end

---@param point { x: number, y: number, z: number }?
local function teleport(point)
    if not point then return end
    DoScreenFadeOut(300)
    Wait(400)
    SetPedCoordsKeepVehicle(cache.ped, point.x, point.y, point.z)
    DoScreenFadeIn(300)
end

---Marca pontos na posição do admin: [E] marca, [Backspace] termina. `single` para no
---primeiro ponto marcado.
---@param single boolean
---@return { x: number, y: number, z: number }[]
local function capturePoints(single)
    local points = {}
    Integrations.showKeys({
        { key = 'E', label = locale('admin_key_mark') },
        { key = 'Backspace', label = locale('admin_key_done') },
    })
    while true do
        Wait(0)
        if IsControlJustReleased(0, 38) then
            points[#points + 1] = Rules.normalizeCoords(GetEntityCoords(cache.ped))
            if single then break end
            Integrations.notify(locale('admin_point_added', #points), 'success')
        elseif IsControlJustReleased(0, 177) then
            break
        end
    end
    Integrations.hideKeys()
    return points
end

local function clearDebugBlips()
    for index = 1, #debugBlips do
        if DoesBlipExist(debugBlips[index]) then RemoveBlip(debugBlips[index]) end
    end
    debugBlips = {}
end

local function showDebugBlips(points)
    clearDebugBlips()
    for index, point in ipairs(points) do
        local blip = AddBlipForCoord(point.x, point.y, point.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(locale('admin_point_name', index))
        EndTextCommandSetBlipName(blip)
        debugBlips[#debugBlips + 1] = blip
    end
end

local function fetch()
    local result = lib.callback.await('noir_gathering:server:adminData', false)
    if not result or not result.ok then
        Integrations.notify(locale('admin_failed', result and result.error or '?'), 'error')
        return false
    end

    local labels = {}
    for _, item in ipairs(result.items) do labels[item.name] = item.label end

    local groups = {}
    for _, job in ipairs(result.jobs) do
        groups[#groups + 1] = { value = job.name, label = locale('admin_group_job', job.label) }
    end
    for _, gang in ipairs(result.gangs) do
        groups[#groups + 1] = { value = gang.name, label = locale('admin_group_gang', gang.label) }
    end

    data = { routes = result.routes, items = result.items, labels = labels, groups = groups,
        progression = result.progression }
    return true
end

---@param draft { id: integer?, route: table }
local function save(draft)
    local result = lib.callback.await('noir_gathering:server:adminSave', false, draft.id, draft.route)
    if not result or not result.ok then
        Integrations.notify(locale('admin_failed', result and result.error or '?'), 'error')
        return false
    end
    draft.id, draft.route = result.id, result.route
    Integrations.notify(locale('admin_saved'), 'success')
    return true
end

local function newRoute(name)
    return {
        name = name,
        mode = 'shift',
        afk = false,
        groups = {},
        police = { enabled = false, chance = 0, radius = limits.alertRadius.default },
        items = {},
    }
end

local function newHaul()
    return {
        prop = limits.haul.defaultProp,
        count = 5,
        cooldown = 0,
        rewards = {},
        reputation = 0,
        scout = { enabled = false, chance = 0, radius = limits.alertRadius.default },
    }
end

local MODE_ORDER = { shift = 'free', free = 'haul', haul = 'shift' }
local MODE_LABEL = { shift = 'admin_mode_shift', free = 'admin_mode_free', haul = 'admin_mode_haul' }

local function categoryLabel(id)
    for _, category in ipairs(data.progression and data.progression.categories or {}) do
        if category.id == id then return category.label end
    end
    return id
end

local function categoryOptions()
    local options = {}
    for _, category in ipairs(data.progression and data.progression.categories or {}) do
        options[#options + 1] = { value = category.id, label = category.label }
    end
    return options
end

local function requirementSummary(requirement)
    if not requirement then return locale('admin_requirement_none') end
    local parts = {}
    if requirement.unlock then parts[#parts + 1] = requirement.unlock end
    if requirement.category then
        parts[#parts + 1] = locale('admin_requirement_level', categoryLabel(requirement.category), requirement.level)
    end
    return table.concat(parts, ' + ')
end

local function newItem()
    return { min = 1, max = 1, time = limits.collectTime.default, random = false, unlimited = false, extras = {}, points = {} }
end

-- Pontos --------------------------------------------------------------------------------

local function openPoint(draft, itemName, index)
    local points = draft.route.items[itemName].points
    local back = function() openPoints(draft, itemName) end
    showMenu('noir_gathering:admin:point', locale('admin_point_name', index), {
        {
            title = locale('admin_teleport'),
            icon = 'fa-solid fa-person-walking-arrow-right',
            onSelect = function() teleport(points[index]); openPoint(draft, itemName, index) end,
        },
        {
            title = locale('admin_point_move'),
            description = locale('admin_point_move_desc'),
            icon = 'fa-solid fa-location-crosshairs',
            onSelect = function()
                local captured = capturePoints(true)
                if captured[1] then points[index] = captured[1]; notifyUpdated() end
                openPoint(draft, itemName, index)
            end,
        },
        {
            title = locale('admin_delete'),
            icon = 'fa-solid fa-trash',
            iconColor = '#e03131',
            onSelect = function()
                if confirm(locale('admin_confirm_delete', locale('admin_point_name', index))) then
                    table.remove(points, index)
                end
                back()
            end,
        },
    }, 'noir_gathering:admin:points')
end

function openPoints(draft, itemName)
    local item = draft.route.items[itemName]
    local options = {
        {
            title = locale('admin_points_add'),
            description = locale('admin_points_add_desc', #item.points, limits.pointsPerItem),
            icon = 'fa-solid fa-plus',
            disabled = #item.points >= limits.pointsPerItem,
            onSelect = function()
                for _, point in ipairs(capturePoints(false)) do
                    if #item.points >= limits.pointsPerItem then break end
                    item.points[#item.points + 1] = point
                end
                openPoints(draft, itemName)
            end,
        },
        {
            title = locale('admin_points_show'),
            description = locale('admin_points_show_desc'),
            icon = 'fa-solid fa-map-location-dot',
            onSelect = function()
                if #debugBlips > 0 then clearDebugBlips() else showDebugBlips(item.points) end
                openPoints(draft, itemName)
            end,
        },
    }
    for index, point in ipairs(item.points) do
        local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(point.x, point.y, point.z))
        options[#options + 1] = {
            title = locale('admin_point_name', index),
            description = street,
            icon = 'fa-solid fa-location-dot',
            arrow = true,
            onSelect = function() openPoint(draft, itemName, index) end,
        }
    end
    showMenu('noir_gathering:admin:points', locale('admin_points_title', itemLabel(itemName)), options,
        'noir_gathering:admin:item')
end

-- Extras --------------------------------------------------------------------------------

local function rangeDialog(title, current, max)
    local input = lib.inputDialog(title, {
        { type = 'number', label = locale('admin_min'), default = current and current.min or 1, min = 0, max = max, required = true },
        { type = 'number', label = locale('admin_max'), default = current and current.max or 1, min = 0, max = max, required = true },
    })
    if not input then return nil end
    return { min = math.floor(input[1]), max = math.floor(input[2]) }
end

function openExtras(draft, itemName)
    local item = draft.route.items[itemName]
    local count = 0
    for _ in pairs(item.extras) do count = count + 1 end

    local options = { {
        title = locale('admin_extra_add'),
        icon = 'fa-solid fa-plus',
        disabled = count >= limits.extrasPerItem,
        onSelect = function()
            local input = lib.inputDialog(locale('admin_extra_add'), {
                { type = 'select', label = locale('admin_item'), options = itemOptions(), searchable = true, required = true },
            })
            if input and input[1] then
                local range = rangeDialog(itemLabel(input[1]), nil, limits.amount)
                if range then item.extras[input[1]] = range end
            end
            openExtras(draft, itemName)
        end,
    } }

    for name, range in pairs(item.extras) do
        options[#options + 1] = {
            title = itemLabel(name),
            description = locale('admin_range', range.min, range.max),
            icon = 'fa-solid fa-gift',
            onSelect = function()
                local choice = lib.alertDialog({
                    header = itemLabel(name),
                    content = locale('admin_extra_edit_desc'),
                    centered = true,
                    cancel = true,
                    labels = { confirm = locale('admin_edit'), cancel = locale('admin_delete') },
                })
                if choice == 'confirm' then
                    local newRange = rangeDialog(itemLabel(name), range, limits.amount)
                    if newRange then item.extras[name] = newRange end
                elseif choice == 'cancel' then
                    item.extras[name] = nil
                end
                openExtras(draft, itemName)
            end,
        }
    end
    showMenu('noir_gathering:admin:extras', locale('admin_extras_title', itemLabel(itemName)), options,
        'noir_gathering:admin:item')
end

-- Item ----------------------------------------------------------------------------------

function openItem(draft, itemName)
    local item = draft.route.items[itemName]
    local reopen = function() openItem(draft, itemName) end
    local anim = item.anim or Config.defaultAnim

    showMenu('noir_gathering:admin:item', item.label or itemLabel(itemName), {
        {
            title = locale('admin_item_label'),
            description = item.label or locale('admin_default_label', itemLabel(itemName)),
            icon = 'fa-solid fa-tag',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_item_label'), {
                    { type = 'input', label = locale('admin_item_label'), description = locale('admin_item_label_desc'), default = item.label, max = limits.nameLength },
                })
                if input then item.label = input[1] ~= '' and input[1] or nil end
                reopen()
            end,
        },
        {
            title = locale('admin_amount'),
            description = locale('admin_range', item.min, item.max),
            icon = 'fa-solid fa-hashtag',
            onSelect = function()
                local range = rangeDialog(locale('admin_amount'), item, limits.amount)
                if range then item.min, item.max = range.min, range.max end
                reopen()
            end,
        },
        {
            title = locale('admin_time'),
            description = locale('admin_time_desc', item.time),
            icon = 'fa-solid fa-stopwatch',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_time'), {
                    { type = 'number', label = locale('admin_time_ms'), default = item.time, min = limits.collectTime.min, max = limits.collectTime.max, required = true },
                })
                if input then item.time = math.floor(input[1]) end
                reopen()
            end,
        },
        {
            title = locale('admin_tool'),
            description = item.tool and locale('admin_tool_desc', itemLabel(item.tool.name), item.tool.cost) or locale('none'),
            icon = 'fa-solid fa-screwdriver-wrench',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_tool'), {
                    { type = 'select', label = locale('admin_item'), description = locale('admin_tool_item_desc'), options = itemOptions(), searchable = true, clearable = true, default = item.tool and item.tool.name },
                    { type = 'number', label = locale('admin_tool_cost'), description = locale('admin_tool_cost_desc'), default = item.tool and item.tool.cost or 0, min = 0, max = 100 },
                })
                if input then
                    item.tool = input[1] and { name = input[1], cost = math.floor(input[2] or 0) } or nil
                end
                reopen()
            end,
        },
        {
            title = locale('admin_stress'),
            description = item.stress and locale('admin_range', item.stress.min, item.stress.max) or locale('none'),
            icon = 'fa-solid fa-brain',
            onSelect = function()
                local range = rangeDialog(locale('admin_stress'), item.stress, limits.stress)
                if range then item.stress = range.max > 0 and range or nil end
                reopen()
            end,
        },
        {
            title = locale('admin_random'),
            description = locale('admin_random_desc', yesNo(item.random)),
            icon = 'fa-solid fa-shuffle',
            onSelect = function() item.random = not item.random; reopen() end,
        },
        {
            title = locale('admin_unlimited'),
            description = locale('admin_unlimited_desc', yesNo(item.unlimited)),
            icon = 'fa-solid fa-infinity',
            onSelect = function() item.unlimited = not item.unlimited; reopen() end,
        },
        {
            title = locale('admin_anim'),
            description = ('%s / %s'):format(anim.dict, anim.clip),
            icon = 'fa-solid fa-person-running',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_anim'), {
                    { type = 'input', label = locale('admin_anim_dict'), description = locale('admin_anim_desc'), default = item.anim and item.anim.dict },
                    { type = 'input', label = locale('admin_anim_clip'), default = item.anim and item.anim.clip },
                    { type = 'number', label = locale('admin_anim_flag'), default = item.anim and item.anim.flag or 1, min = 0, max = 65535 },
                })
                if input then
                    if input[1] == '' or input[2] == '' then
                        item.anim = nil
                    elseif not DoesAnimDictExist(input[1]) then
                        Integrations.notify(locale('admin_anim_missing'), 'error')
                    else
                        item.anim = { dict = input[1], clip = input[2], flag = math.floor(input[3] or 1) }
                    end
                end
                reopen()
            end,
        },
        {
            title = locale('admin_item_police'),
            description = item.police and locale('admin_chance', item.police.chance) or locale('admin_item_police_route'),
            icon = 'fa-solid fa-handcuffs',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_item_police'), {
                    { type = 'number', label = locale('admin_chance_label'), description = locale('admin_item_police_desc'), default = item.police and item.police.chance, min = 0, max = 100 },
                })
                if input then item.police = input[1] and { chance = input[1] } or nil end
                reopen()
            end,
        },
        {
            title = locale('admin_extras'),
            description = locale('admin_extras_desc'),
            icon = 'fa-solid fa-gift',
            arrow = true,
            onSelect = function() openExtras(draft, itemName) end,
        },
        {
            title = locale('admin_points'),
            description = locale('admin_points_count', #item.points),
            icon = 'fa-solid fa-location-dot',
            arrow = true,
            onSelect = function() openPoints(draft, itemName) end,
        },
        {
            title = locale('admin_delete'),
            icon = 'fa-solid fa-trash',
            iconColor = '#e03131',
            onSelect = function()
                if confirm(locale('admin_confirm_delete', itemLabel(itemName))) then
                    draft.route.items[itemName] = nil
                    clearDebugBlips()
                    return openItems(draft)
                end
                reopen()
            end,
        },
    }, 'noir_gathering:admin:items')
end

function openItems(draft)
    local count = 0
    for _ in pairs(draft.route.items) do count = count + 1 end

    local options = { {
        title = locale('admin_item_add'),
        icon = 'fa-solid fa-plus',
        disabled = count >= limits.itemsPerRoute,
        onSelect = function()
            local input = lib.inputDialog(locale('admin_item_add'), {
                { type = 'select', label = locale('admin_item'), options = itemOptions(), searchable = true, required = true },
            })
            if not input or not input[1] then return openItems(draft) end
            if draft.route.items[input[1]] then
                Integrations.notify(locale('admin_item_exists'), 'error')
                return openItems(draft)
            end
            draft.route.items[input[1]] = newItem()
            openItem(draft, input[1])
        end,
    } }

    for itemName, item in pairs(draft.route.items) do
        options[#options + 1] = {
            title = item.label or itemLabel(itemName),
            description = locale('admin_item_summary', item.min, item.max, #item.points),
            icon = Config.itemImage:format(itemName),
            arrow = true,
            onSelect = function() openItem(draft, itemName) end,
        }
    end
    showMenu('noir_gathering:admin:items', locale('admin_items_title', draft.route.name), options,
        'noir_gathering:admin:route')
end

-- Carga ---------------------------------------------------------------------------------

function openRewards(draft)
    local haul = draft.route.haul
    local count = 0
    for _ in pairs(haul.rewards) do count = count + 1 end

    local options = { {
        title = locale('admin_reward_add'),
        icon = 'fa-solid fa-plus',
        disabled = count >= limits.haul.rewardItems,
        onSelect = function()
            local input = lib.inputDialog(locale('admin_reward_add'), {
                { type = 'select', label = locale('admin_item'), options = itemOptions(), searchable = true, required = true },
            })
            if input and input[1] then
                local range = rangeDialog(itemLabel(input[1]), nil, limits.amount)
                if range then haul.rewards[input[1]] = range end
            end
            openRewards(draft)
        end,
    } }
    for name, range in pairs(haul.rewards) do
        options[#options + 1] = {
            title = itemLabel(name),
            description = locale('admin_range', range.min, range.max),
            icon = Config.itemImage:format(name),
            onSelect = function()
                local choice = lib.alertDialog({
                    header = itemLabel(name),
                    content = locale('admin_extra_edit_desc'),
                    centered = true,
                    cancel = true,
                    labels = { confirm = locale('admin_edit'), cancel = locale('admin_delete') },
                })
                if choice == 'confirm' then
                    local newRange = rangeDialog(itemLabel(name), range, limits.amount)
                    if newRange then haul.rewards[name] = newRange end
                elseif choice == 'cancel' then
                    haul.rewards[name] = nil
                end
                openRewards(draft)
            end,
        }
    end
    showMenu('noir_gathering:admin:rewards', locale('admin_rewards'), options, 'noir_gathering:admin:haul')
end

local function stackPropOptions()
    local options = {}
    for _, prop in ipairs(Config.haul.stackProps) do options[#options + 1] = { value = prop.model, label = prop.label } end
    return options
end

local function stackPropLabel(model)
    for _, prop in ipairs(Config.haul.stackProps) do
        if prop.model == model then return prop.label end
    end
    return model
end

---Marca um lugar da carga (pilha ou entrega): posicionar pela mira ou teleportar até ele.
local function placeOrTeleport(title, current, place)
    local choice = current and lib.alertDialog({
        header = title,
        content = locale('admin_place_choice'),
        centered = true,
        cancel = true,
        labels = { confirm = locale('admin_place_here'), cancel = locale('admin_teleport') },
    }) or 'confirm'
    if choice == 'confirm' then
        local placed = place()
        if placed then notifyUpdated() end
        return placed
    elseif choice == 'cancel' then
        teleport(current)
    end
end

function openHaul(draft)
    local route = draft.route
    route.haul = route.haul or newHaul()
    local haul = route.haul
    local reopen = function() openHaul(draft) end
    local progression = data.progression
    local cap = progression and progression.gatheringRewardCap or 0
    local rewardCount = 0
    for _ in pairs(haul.rewards) do rewardCount = rewardCount + 1 end

    local options = {
        {
            title = locale('admin_haul_stack'),
            description = haul.stack and stackPropLabel(haul.prop) or locale('admin_haul_stack_missing'),
            icon = 'fa-solid fa-boxes-stacked',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_haul_stack'), {
                    { type = 'select', label = locale('admin_haul_prop'), options = stackPropOptions(), default = haul.prop, required = true },
                })
                if not input then return reopen() end
                local placed = placeOrTeleport(locale('admin_haul_stack'), haul.stack, function()
                    return Placement.run('object', input[1], haul.stack)
                end)
                if placed then haul.stack, haul.prop = placed, input[1] end
                reopen()
            end,
        },
        {
            title = locale('admin_haul_count'),
            description = locale('admin_haul_count_desc', haul.count),
            icon = 'fa-solid fa-hashtag',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_haul_count'), {
                    { type = 'number', label = locale('admin_haul_count'), default = haul.count, min = 1, max = limits.haul.boxes, required = true },
                })
                if input then haul.count = math.floor(input[1]) end
                reopen()
            end,
        },
        {
            title = locale('admin_haul_dropoff'),
            description = haul.dropoff and locale('admin_haul_dropoff_set') or locale('admin_haul_dropoff_missing'),
            icon = 'fa-solid fa-flag-checkered',
            onSelect = function()
                local placed = placeOrTeleport(locale('admin_haul_dropoff'), haul.dropoff, function()
                    return Placement.run('object', Config.haul.carry.prop, haul.dropoff)
                end)
                if placed then haul.dropoff = placed end
                reopen()
            end,
        },
        {
            title = locale('admin_rewards'),
            description = locale('admin_rewards_desc', rewardCount),
            icon = 'fa-solid fa-gift',
            arrow = true,
            onSelect = function() openRewards(draft) end,
        },
    }

    if progression then
        options[#options + 1] = {
            title = locale('admin_haul_reputation'),
            description = haul.category and locale('admin_haul_reputation_desc', haul.reputation, categoryLabel(haul.category))
                or locale('admin_haul_reputation_none'),
            icon = 'fa-solid fa-star',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_haul_reputation'), {
                    { type = 'select', label = locale('admin_haul_category'), description = locale('admin_haul_category_desc'), options = categoryOptions(), clearable = true, default = haul.category },
                    { type = 'number', label = locale('admin_haul_reputation_amount'), description = locale('admin_haul_reputation_cap', cap), default = haul.reputation, min = 0, max = cap, precision = 1 },
                })
                if input then
                    haul.category = input[1]
                    haul.reputation = input[1] and (input[2] or 0) or 0
                    if not haul.category then haul.scout.enabled = false end
                end
                reopen()
            end,
        }
        options[#options + 1] = {
            title = locale('admin_scout'),
            description = haul.scout.enabled and locale('admin_scout_summary', haul.scout.chance, haul.scout.radius)
                or locale('admin_scout_off'),
            icon = 'fa-solid fa-binoculars',
            disabled = not haul.category,
            onSelect = function()
                local input = lib.inputDialog(locale('admin_scout'), {
                    { type = 'checkbox', label = locale('admin_scout_enabled'), checked = haul.scout.enabled },
                    { type = 'number', label = locale('admin_chance_label'), default = haul.scout.chance, min = 0, max = 100 },
                    { type = 'number', label = locale('admin_radius'), description = locale('admin_scout_radius_desc'), default = haul.scout.radius, min = limits.alertRadius.min, max = limits.alertRadius.max },
                })
                if input then
                    haul.scout = { enabled = input[1] == true, chance = input[2] or 0,
                        radius = math.floor(input[3] or limits.alertRadius.default) }
                end
                reopen()
            end,
        }
    end

    options[#options + 1] = {
        title = locale('admin_haul_cooldown'),
        description = locale('admin_haul_cooldown_desc', haul.cooldown),
        icon = 'fa-solid fa-hourglass-half',
        onSelect = function()
            local input = lib.inputDialog(locale('admin_haul_cooldown'), {
                { type = 'number', label = locale('admin_haul_cooldown_minutes'), default = haul.cooldown, min = 0, max = limits.haul.cooldownMinutes },
            })
            if input then haul.cooldown = math.floor(input[1] or 0) end
            reopen()
        end,
    }

    showMenu('noir_gathering:admin:haul', locale('admin_haul_title', route.name), options, 'noir_gathering:admin:route')
end

-- Rota ----------------------------------------------------------------------------------

local function groupsSummary(groups)
    local names, grade = {}, nil
    for name, minGrade in pairs(groups) do
        names[#names + 1] = name
        grade = grade and math.min(grade, minGrade) or minGrade
    end
    if #names == 0 then return locale('admin_groups_public') end
    table.sort(names)
    return locale('admin_groups_summary', table.concat(names, ', '), grade)
end

function openRoute(draft)
    local route = draft.route
    local reopen = function() openRoute(draft) end
    local playable = Rules.isPlayable(route)

    local options = {
        {
            title = locale('admin_save'),
            description = playable and locale('admin_save_desc') or locale('admin_not_playable'),
            icon = 'fa-solid fa-floppy-disk',
            iconColor = playable and '#2f9e44' or '#f59f00',
            onSelect = function()
                save(draft)
                reopen()
            end,
        },
        {
            title = locale('admin_name'),
            description = route.name,
            icon = 'fa-solid fa-pen',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_name'), {
                    { type = 'input', label = locale('admin_name'), default = route.name, required = true, max = limits.nameLength },
                })
                if input then route.name = input[1] end
                reopen()
            end,
        },
        {
            title = locale('admin_mode'),
            description = locale(MODE_LABEL[route.mode]),
            icon = 'fa-solid fa-route',
            onSelect = function()
                route.mode = MODE_ORDER[route.mode]
                if route.mode ~= 'free' then route.afk = false end
                if route.mode == 'haul' then route.haul = route.haul or newHaul() end
                reopen()
            end,
        },
    }

    if route.mode == 'free' then
        options[#options + 1] = {
            title = locale('admin_afk'),
            description = locale('admin_afk_desc', yesNo(route.afk)),
            icon = 'fa-solid fa-mug-hot',
            onSelect = function() route.afk = not route.afk; reopen() end,
        }
    else
        options[#options + 1] = {
            title = locale('admin_start'),
            description = route.start and locale('admin_start_set') or locale('admin_start_missing'),
            icon = 'fa-solid fa-flag',
            onSelect = function()
                local choice = route.start and lib.alertDialog({
                    header = locale('admin_start'),
                    content = locale('admin_start_choice'),
                    centered = true,
                    cancel = true,
                    labels = { confirm = locale('admin_start_here'), cancel = locale('admin_teleport') },
                }) or 'confirm'
                if choice == 'confirm' then
                    local captured = capturePoints(true)
                    if captured[1] then
                        route.start = captured[1]
                        route.start.w = GetEntityHeading(cache.ped)
                        notifyUpdated()
                    end
                elseif choice == 'cancel' then
                    teleport(route.start)
                end
                reopen()
            end,
        }
        options[#options + 1] = {
            title = locale('admin_npc'),
            description = route.npc and route.npc.model or locale('admin_npc_none'),
            icon = 'fa-solid fa-user-tie',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_npc'), {
                    { type = 'input', label = locale('admin_npc_model'), description = locale('admin_npc_desc'), default = route.npc and route.npc.model },
                    { type = 'input', label = locale('admin_npc_scenario'), description = locale('admin_npc_scenario_desc'), default = route.npc and route.npc.scenario },
                })
                if not input then return reopen() end
                local model = input[1] and input[1]:lower() or ''
                if model == '' then
                    route.npc = nil
                    return reopen()
                end
                -- Posicionar o NPC define o início da rota: é nele que o jogador fala.
                local placed = Placement.run('ped', model, route.start)
                if placed then
                    route.start = placed
                    route.npc = { model = model, scenario = input[2] ~= '' and input[2] or nil }
                    notifyUpdated()
                end
                reopen()
            end,
        }
    end

    options[#options + 1] = {
        title = locale('admin_groups'),
        description = groupsSummary(route.groups),
        icon = 'fa-solid fa-users',
        onSelect = function()
            local current, grade = {}, 0
            for name, minGrade in pairs(route.groups) do current[#current + 1] = name; grade = minGrade end
            local input = lib.inputDialog(locale('admin_groups'), {
                { type = 'multi-select', label = locale('admin_groups'), description = locale('admin_groups_desc'), options = data.groups, default = current, searchable = true },
                { type = 'number', label = locale('admin_grade'), description = locale('admin_grade_desc'), default = grade, min = 0, max = 99 },
            })
            if input then
                route.groups = {}
                for _, name in ipairs(input[1] or {}) do route.groups[name] = math.floor(input[2] or 0) end
            end
            reopen()
        end,
    }
    options[#options + 1] = {
        title = locale('admin_vehicle'),
        description = route.vehicle or locale('admin_vehicle_none'),
        icon = 'fa-solid fa-van-shuttle',
        onSelect = function()
            local input = lib.inputDialog(locale('admin_vehicle'), {
                { type = 'input', label = locale('admin_vehicle_model'), description = locale('admin_vehicle_desc'), default = route.vehicle },
            })
            if input then
                local model = input[1] and input[1]:lower() or ''
                if model == '' then
                    route.vehicle, route.vehicleSpawn = nil, nil
                elseif not IsModelInCdimage(joaat(model)) or not IsModelAVehicle(joaat(model)) then
                    Integrations.notify(locale('admin_vehicle_invalid'), 'error')
                else
                    route.vehicle = model
                end
            end
            reopen()
        end,
    }
    if route.mode == 'haul' and route.vehicle then
        options[#options + 1] = {
            title = locale('admin_vehicle_spawn'),
            description = route.vehicleSpawn and locale('admin_vehicle_spawn_set') or locale('admin_vehicle_spawn_none'),
            icon = 'fa-solid fa-square-parking',
            onSelect = function()
                local choice = lib.alertDialog({
                    header = locale('admin_vehicle_spawn'),
                    content = locale('admin_vehicle_spawn_choice'),
                    centered = true,
                    cancel = true,
                    labels = { confirm = locale('admin_vehicle_spawn_place'), cancel = locale('admin_vehicle_spawn_clear') },
                })
                if choice == 'confirm' then
                    local placed = Placement.run('vehicle', route.vehicle, route.vehicleSpawn)
                    if placed then route.vehicleSpawn = placed; notifyUpdated() end
                elseif choice == 'cancel' then
                    route.vehicleSpawn = nil
                end
                reopen()
            end,
        }
    end
    if data.progression then
        options[#options + 1] = {
            title = locale('admin_requirement'),
            description = requirementSummary(route.requirement),
            icon = 'fa-solid fa-lock',
            onSelect = function()
                local unlocks = {}
                for _, key in ipairs(data.progression.unlocks) do unlocks[#unlocks + 1] = { value = key, label = key } end
                local current = route.requirement or {}
                local input = lib.inputDialog(locale('admin_requirement'), {
                    { type = 'select', label = locale('admin_requirement_unlock'), description = locale('admin_requirement_unlock_desc'), options = unlocks, clearable = true, default = current.unlock },
                    { type = 'select', label = locale('admin_requirement_category'), description = locale('admin_requirement_category_desc'), options = categoryOptions(), clearable = true, default = current.category },
                    { type = 'number', label = locale('admin_requirement_min_level'), default = current.level or 1, min = 1, max = 20 },
                })
                if input then
                    local requirement = {}
                    if input[1] then requirement.unlock = input[1] end
                    if input[2] then requirement.category, requirement.level = input[2], math.floor(input[3] or 1) end
                    route.requirement = next(requirement) and requirement or nil
                end
                reopen()
            end,
        }
    end
    options[#options + 1] = {
        title = locale('admin_police'),
        description = route.police.enabled
            and locale('admin_police_summary', route.police.chance, route.police.radius or limits.alertRadius.default)
            or locale('admin_police_off'),
        icon = 'fa-solid fa-handcuffs',
        onSelect = function()
            local input = lib.inputDialog(locale('admin_police'), {
                { type = 'checkbox', label = locale('admin_police_enabled'), checked = route.police.enabled },
                { type = 'number', label = locale('admin_chance_label'), default = route.police.chance, min = 0, max = 100 },
                { type = 'number', label = locale('admin_radius'), description = locale('admin_radius_desc'), default = route.police.radius or limits.alertRadius.default, min = limits.alertRadius.min, max = limits.alertRadius.max },
            })
            if input then
                route.police = { enabled = input[1] == true, chance = input[2] or 0,
                    radius = math.floor(input[3] or limits.alertRadius.default) }
            end
            reopen()
        end,
    }
    if route.mode == 'haul' then
        options[#options + 1] = {
            title = locale('admin_haul'),
            description = locale('admin_haul_desc'),
            icon = 'fa-solid fa-truck-ramp-box',
            arrow = true,
            onSelect = function() openHaul(draft) end,
        }
    else
        options[#options + 1] = {
            title = locale('admin_items'),
            description = locale('admin_items_desc'),
            icon = 'fa-solid fa-boxes-stacked',
            arrow = true,
            onSelect = function() openItems(draft) end,
        }
    end
    options[#options + 1] = {
        title = locale('admin_export'),
        description = locale('admin_export_desc'),
        icon = 'fa-solid fa-file-export',
        onSelect = function()
            lib.setClipboard(json.encode(route, { indent = true }))
            Integrations.notify(locale('admin_exported'), 'success')
            reopen()
        end,
    }

    if draft.id then
        options[#options + 1] = {
            title = locale('admin_duplicate'),
            description = locale('admin_duplicate_desc'),
            icon = 'fa-solid fa-copy',
            onSelect = function()
                local copy = { route = deepCopy(route) }
                copy.route.name = locale('admin_copy_name', route.name):sub(1, limits.nameLength)
                openRoute(copy)
            end,
        }
        options[#options + 1] = {
            title = locale('admin_delete'),
            icon = 'fa-solid fa-trash',
            iconColor = '#e03131',
            onSelect = function()
                if not confirm(locale('admin_confirm_delete', route.name)) then return reopen() end
                local result = lib.callback.await('noir_gathering:server:adminDelete', false, draft.id)
                if not result or not result.ok then
                    Integrations.notify(locale('admin_failed', result and result.error or '?'), 'error')
                    return reopen()
                end
                Integrations.notify(locale('admin_deleted'), 'success')
                openMain()
            end,
        }
    end

    showMenu('noir_gathering:admin:route', route.name, options, 'noir_gathering:admin:main')
end

function openMain()
    clearDebugBlips()
    if not fetch() then return end

    local options = {
        {
            title = locale('admin_create'),
            icon = 'fa-solid fa-plus',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_create'), {
                    { type = 'input', label = locale('admin_name'), required = true, max = limits.nameLength },
                })
                if not input then return openMain() end
                openRoute({ route = newRoute(input[1]) })
            end,
        },
        {
            title = locale('admin_import'),
            description = locale('admin_import_desc'),
            icon = 'fa-solid fa-file-import',
            onSelect = function()
                local input = lib.inputDialog(locale('admin_import'), {
                    { type = 'textarea', label = 'JSON', required = true, autosize = true },
                })
                if not input then return openMain() end
                local ok, decoded = pcall(json.decode, input[1])
                local route, err = nil, 'invalid_json'
                if ok then
                    route, err = Rules.normalizeRoute(decoded, limits, function(name) return data.labels[name] ~= nil end)
                end
                if not route then
                    Integrations.notify(locale('admin_failed', err), 'error')
                    return openMain()
                end
                -- Só vira rota ao salvar, e o servidor revalida tudo de novo.
                openRoute({ route = route })
            end,
        },
    }

    for _, entry in ipairs(data.routes) do
        local itemCount = 0
        for _ in pairs(entry.route.items) do itemCount = itemCount + 1 end
        options[#options + 1] = {
            title = entry.route.name,
            description = entry.route.mode == 'haul'
                and locale('admin_route_summary_haul', entry.route.haul and entry.route.haul.count or 0)
                or locale('admin_route_summary', locale(MODE_LABEL[entry.route.mode]), itemCount),
            icon = 'fa-solid fa-route',
            arrow = true,
            onSelect = function() openRoute({ id = entry.id, route = deepCopy(entry.route) }) end,
        }
    end

    showMenu('noir_gathering:admin:main', locale('admin_title'), options)
end

function Creator.open()
    openMain()
end

function Creator.reset()
    clearDebugBlips()
    Integrations.hideKeys()
end

return Creator
