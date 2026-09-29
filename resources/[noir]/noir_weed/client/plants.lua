---Plantas no client: prop por estágio, alvo, menu de status e o uso da semente.

local Shared = require 'config.shared'
local Integrations = require 'client.integrations'
local Placement = require 'client.placement'
local Actions = require 'client.actions'
local Objects = require 'client.objects'

local Plants = {}

---ids das plantas do personagem atual
local mine = {}

---@param view { seed: string, stage: integer }
---@return integer
local function modelFor(view)
    local strain = Shared.strains[view.seed]
    local models = Shared.plantModels[strain and strain.look or 'default'] or Shared.plantModels.default
    return models[view.stage] or models[1]
end

local openMenu, destroyPlant

local objects = Objects.new({
    model = modelFor,
    targets = function(id)
        return {
            {
                name = 'noir_weed:open',
                icon = 'fa-solid fa-cannabis',
                label = locale('target_open'),
                distance = Shared.targetDistance,
                canInteract = function() return mine[id] == true and not Actions.isBusy() end,
                onSelect = function() openMenu(id) end,
            },
            {
                name = 'noir_weed:burn',
                icon = 'fa-solid fa-fire',
                label = locale('target_destroy'),
                distance = Shared.targetDistance,
                canInteract = function()
                    return not mine[id] and not Actions.isBusy() and Integrations.onDutyIn(Shared.destroyJobs)
                end,
                onSelect = function() destroyPlant(id) end,
            },
        }
    end,
})

---@param id integer
function destroyPlant(id)
    local confirm = lib.alertDialog({
        header = locale('destroy_header'),
        content = locale('destroy_confirm'),
        centered = true,
        cancel = true,
    })
    if confirm ~= 'confirm' then return end
    if Actions.perform('destroy', { id = id }) then
        Integrations.notify(locale('success_destroy'), 'success')
    end
end

---@param id integer
local function movePlant(id)
    local view, entity = objects:get(id)
    if not view then return end
    local response = Actions.perform('move', { id = id }, {
        choose = function()
            if entity then SetEntityAlpha(entity, 80, false) end
            local placement = Placement.run(modelFor(view))
            if entity and DoesEntityExist(entity) then ResetEntityAlpha(entity) end
            return placement
        end,
    })
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
                local response = Actions.perform(action, { id = status.id })
                if response then
                    Integrations.notify(locale('success_' .. action), 'success')
                    if response.result and response.result.status then statusMenu(response.result.status) end
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
                    local response = Actions.perform('harvest', { id = status.id })
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
    if not response or not response.ok then return Actions.fail(response and response.code) end
    statusMenu(response.status)
end

exports('useSeed', function(data)
    local seed = type(data) == 'table' and data.name
    if not seed or not Shared.strains[seed] or Actions.isBusy() then return end

    local placement = Placement.run(modelFor({ seed = seed, stage = 1 }))
    if not placement then return end

    if Actions.perform('plant', { seed = seed, placement = placement }) then
        Integrations.notify(locale('success_plant'), 'success')
    end
end)

-- Sync ----------------------------------------------------------------------------------

---@param views table[]
---@param ids integer[]
function Plants.load(views, ids)
    for _, id in ipairs(ids) do mine[id] = true end
    for _, view in ipairs(views) do objects:upsert(view) end
end

function Plants.clear()
    objects:clear()
    mine = {}
end

function Plants.despawnAll()
    objects:despawnAll()
end

RegisterNetEvent('noir_weed:client:upsert', function(view) objects:upsert(view) end)
RegisterNetEvent('noir_weed:client:remove', function(id)
    objects:remove(id)
    mine[id] = nil
end)
RegisterNetEvent('noir_weed:client:mine', function(id) mine[id] = true end)

return Plants
