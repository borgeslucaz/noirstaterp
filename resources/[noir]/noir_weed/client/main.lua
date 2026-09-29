---Client: desenha as plantas perto do jogador (prop local, sem entidade de rede), põe o
---alvo nelas, abre o menu e roda as animações. Quem decide qualquer coisa é o servidor.

local Shared = require 'config.shared'
local Integrations = require 'client.integrations'
local Placement = require 'client.placement'

lib.locale()

---[id] = { view, point, entity? }
local plants = {}
---ids das plantas do personagem atual
local mine = {}
local busy = false

-- Prop ----------------------------------------------------------------------------------

---@param view { seed: string, stage: integer }
---@return integer
local function modelFor(view)
    local stage = Shared.stages[view.stage] or Shared.stages[1]
    return stage.prop
end

local openMenu, destroyPlant

---@param id integer
local function targetOptions(id)
    return {
        {
            name = 'noir_weed:open',
            icon = 'fa-solid fa-cannabis',
            label = locale('target_open'),
            distance = Shared.targetDistance,
            canInteract = function() return mine[id] == true and not busy end,
            onSelect = function() openMenu(id) end,
        },
        {
            name = 'noir_weed:burn',
            icon = 'fa-solid fa-fire',
            label = locale('target_destroy'),
            distance = Shared.targetDistance,
            canInteract = function()
                return not mine[id] and not busy and Integrations.onDutyIn(Shared.destroyJobs)
            end,
            onSelect = function() destroyPlant(id) end,
        },
    }
end

local function despawn(entry)
    if not entry.entity then return end
    Integrations.removeEntityTarget(entry.entity)
    if DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
    entry.entity = nil
end

local function spawn(entry)
    despawn(entry)
    local view = entry.view
    local model = modelFor(view)
    if not IsModelInCdimage(model) or not pcall(lib.requestModel, model, 5000) then
        lib.print.error(('modelo indisponível: %s'):format(model))
        return
    end
    local entity = CreateObjectNoOffset(model, view.x, view.y, view.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if entity == 0 then return end
    SetEntityHeading(entity, view.heading or 0.0)
    FreezeEntityPosition(entity, true)
    entry.entity = entity
    Integrations.addEntityTarget(entity, targetOptions(view.id))
end

---@param view table
local function upsert(view)
    local entry = plants[view.id]
    if entry then
        local moved = entry.view.x ~= view.x or entry.view.y ~= view.y or entry.view.z ~= view.z
        entry.view = view
        if moved then
            entry.point:remove()
            entry.point = nil
        elseif entry.entity then
            spawn(entry)
            return
        end
    else
        entry = { view = view }
        plants[view.id] = entry
    end

    if not entry.point then
        entry.point = lib.points.new({
            coords = vector3(view.x, view.y, view.z),
            distance = Shared.renderDistance,
            onEnter = function() spawn(entry) end,
            onExit = function() despawn(entry) end,
        })
        despawn(entry)
    end
end

---@param id integer
local function remove(id)
    local entry = plants[id]
    if not entry then return end
    despawn(entry)
    if entry.point then entry.point:remove() end
    plants[id] = nil
    mine[id] = nil
end

local function clearAll()
    for id in pairs(plants) do remove(id) end
    mine = {}
end

local function resync()
    clearAll()
    if not Integrations.isLoggedIn() then return end
    local data = lib.callback.await('noir_weed:server:sync', false)
    if type(data) ~= 'table' then return end
    for _, id in ipairs(data.mine or {}) do mine[id] = true end
    for _, view in ipairs(data.plants or {}) do upsert(view) end
end

RegisterNetEvent('noir_weed:client:upsert', upsert)
RegisterNetEvent('noir_weed:client:remove', remove)
RegisterNetEvent('noir_weed:client:mine', function(id) mine[id] = true end)
RegisterNetEvent('noir_weed:client:resync', resync)
AddEventHandler('bgrz_core:client:playerLoaded', resync)
AddEventHandler('bgrz_core:client:playerUnloaded', clearAll)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == cache.resource then resync() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for _, entry in pairs(plants) do despawn(entry) end
end)

-- Ações ---------------------------------------------------------------------------------

---@param code? string
local function fail(code)
    Integrations.notify(locale('error_' .. tostring(code or 'operation_failed')), 'error')
end

---@param action string
---@return boolean
local function playProgress(action)
    local duration = Shared.durations[action] or 0
    if duration <= 0 then return true end
    local anim = Shared.animations[action]
    return lib.progressBar({
        duration = duration,
        label = locale('progress_' .. action),
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = anim and { dict = anim.dict, clip = anim.clip, flag = anim.flag } or nil,
        prop = Shared.props[action],
    })
end

---begin -> (escolha do lugar) -> animação -> finish. Qualquer desistência no meio avisa
---o servidor para soltar a ação.
---@param action string
---@param payload table
---@param choose? fun(): table? escolhe o lugar depois do begin (mover)
---@return table? response
local function perform(action, payload, choose)
    if busy then return nil end
    busy = true

    local began = lib.callback.await('noir_weed:server:begin', false, action, payload)
    if not began or not began.ok then
        busy = false
        fail(began and began.code)
        return nil
    end

    local extra
    if choose then
        extra = choose()
        if not extra then
            TriggerServerEvent('noir_weed:server:cancel')
            busy = false
            return nil
        end
    end

    if not playProgress(action) then
        TriggerServerEvent('noir_weed:server:cancel')
        busy = false
        return nil
    end

    local response = lib.callback.await('noir_weed:server:finish', false, action, extra)
    busy = false
    if not response or not response.ok then
        fail(response and response.code)
        return nil
    end
    return response
end

exports('useSeed', function(data)
    local seed = type(data) == 'table' and data.name
    if not seed or not Shared.strains[seed] then return end
    if busy then return end

    local placement = Placement.run(Shared.stages[1].prop)
    if not placement then return end

    if perform('plant', { seed = seed, placement = placement }) then
        Integrations.notify(locale('success_plant'), 'success')
    end
end)

---@param id integer
function destroyPlant(id)
    local confirm = lib.alertDialog({
        header = locale('destroy_header'),
        content = locale('destroy_confirm'),
        centered = true,
        cancel = true,
    })
    if confirm ~= 'confirm' then return end
    if perform('destroy', { id = id }) then
        Integrations.notify(locale('success_destroy'), 'success')
    end
end

---@param id integer
local function movePlant(id)
    local entry = plants[id]
    if not entry then return end
    local model = modelFor(entry.view)
    local response = perform('move', { id = id }, function()
        if entry.entity then SetEntityAlpha(entry.entity, 80, false) end
        local placement = Placement.run(model)
        if entry.entity and DoesEntityExist(entry.entity) then ResetEntityAlpha(entry.entity) end
        return placement
    end)
    if response then Integrations.notify(locale('success_move'), 'success') end
end

---@param status table
local function statusMenu(status)
    local strain = Shared.strains[status.seed]
    local canHarvest = status.growth >= Shared.harvestAt

    local function careOption(action, stat, icon)
        return {
            title = locale('menu_' .. action),
            description = locale('menu_care_hint', math.floor(status[stat]), locale('item_' .. action)),
            icon = icon,
            progress = status[stat],
            colorScheme = status[stat] < 25 and 'red' or 'blue',
            onSelect = function()
                local response = perform(action, { id = status.id })
                if response then
                    Integrations.notify(locale('success_' .. action), 'success')
                    if response.status then statusMenu(response.status) end
                end
            end,
        }
    end

    lib.registerContext({
        id = 'noir_weed:plant',
        title = strain and strain.label or status.seed,
        options = {
            {
                title = locale('menu_growth'),
                description = ('%d%%'):format(math.floor(status.growth)),
                icon = 'seedling',
                progress = status.growth,
                colorScheme = 'green',
                readOnly = true,
            },
            careOption('herbicide', 'health', 'spray-can'),
            careOption('water', 'water', 'droplet'),
            careOption('fertilizer', 'fertilizer', 'flask'),
            {
                title = locale('menu_harvest'),
                description = canHarvest and locale('menu_harvest_ready') or locale('menu_harvest_wait'),
                icon = 'scissors',
                disabled = not canHarvest,
                onSelect = function()
                    local response = perform('harvest', { id = status.id })
                    if response and response.result then
                        local label = strain and strain.label or status.seed
                        Integrations.notify(locale('success_harvest', response.result.amount, label), 'success')
                    end
                end,
            },
            {
                title = locale('menu_move'),
                icon = 'up-down-left-right',
                onSelect = function() movePlant(status.id) end,
            },
            {
                title = locale('menu_destroy'),
                icon = 'fire',
                onSelect = function() destroyPlant(status.id) end,
            },
        },
    })
    lib.showContext('noir_weed:plant')
end

---@param id integer
function openMenu(id)
    local response = lib.callback.await('noir_weed:server:status', false, id)
    if not response or not response.ok then return fail(response and response.code) end
    statusMenu(response.status)
end
