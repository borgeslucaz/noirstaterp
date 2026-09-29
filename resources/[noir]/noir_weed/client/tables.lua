---Mesas no client: prop, alvo (usar, recolher, apreender) e o uso do item da mesa. Usar
---a mesa abre o minigame (`client/packing.lua`).

local Shared = require 'config.shared'
local Integrations = require 'client.integrations'
local Placement = require 'client.placement'
local Actions = require 'client.actions'
local Objects = require 'client.objects'
local Packing = require 'client.packing'

local Tables = {}

---ids das mesas do personagem atual
local mine = {}

---@param view { type: string }
---@return integer?
local function modelFor(view)
    local def = Shared.tables[view.type]
    return def and def.model
end

local openRecipes, pickup, seize

local objects = Objects.new({
    model = modelFor,
    targets = function(id)
        return {
            {
                name = 'noir_weed:table_use',
                icon = 'fa-solid fa-scale-balanced',
                label = locale('target_table_use'),
                distance = Shared.targetDistance,
                canInteract = function() return not Actions.isBusy() end,
                onSelect = function() openRecipes(id) end,
            },
            {
                name = 'noir_weed:table_pickup',
                icon = 'fa-solid fa-box',
                label = locale('target_table_pickup'),
                distance = Shared.targetDistance,
                canInteract = function() return mine[id] == true and not Actions.isBusy() end,
                onSelect = function() pickup(id) end,
            },
            {
                name = 'noir_weed:table_seize',
                icon = 'fa-solid fa-handcuffs',
                label = locale('target_table_seize'),
                distance = Shared.targetDistance,
                canInteract = function()
                    return not mine[id] and not Actions.isBusy() and Integrations.onDutyIn(Shared.destroyJobs)
                end,
                onSelect = function() seize(id) end,
            },
        }
    end,
})

---@param id integer
function pickup(id)
    if Actions.perform('pickupTable', { id = id }) then
        Integrations.notify(locale('success_pickup_table'), 'success')
    end
end

---@param id integer
function seize(id)
    local confirm = lib.alertDialog({
        header = locale('seize_header'),
        content = locale('seize_confirm'),
        centered = true,
        cancel = true,
    })
    if confirm ~= 'confirm' then return end
    if Actions.perform('seizeTable', { id = id }) then
        Integrations.notify(locale('success_seize_table'), 'success')
    end
end

---@param id integer
function openRecipes(id)
    local view = objects:get(id)
    local def = view and Shared.tables[view.type]
    if def then Packing.open(id, def) end
end

exports('useTable', function(data)
    local item = type(data) == 'table' and data.name
    local def = item and Shared.tables[item]
    if not def or Actions.isBusy() then return end

    local placement = Placement.run(def.model)
    if not placement then return end

    if Actions.perform('placeTable', { item = item, placement = placement }) then
        Integrations.notify(locale('success_place_table'), 'success')
    end
end)

-- Sync ----------------------------------------------------------------------------------

---@param views table[]
---@param ids integer[]
function Tables.load(views, ids)
    for _, id in ipairs(ids) do mine[id] = true end
    for _, view in ipairs(views) do objects:upsert(view) end
end

function Tables.clear()
    objects:clear()
    mine = {}
end

function Tables.despawnAll()
    objects:despawnAll()
end

RegisterNetEvent('noir_weed:client:tableUpsert', function(view) objects:upsert(view) end)
RegisterNetEvent('noir_weed:client:tableRemove', function(id)
    objects:remove(id)
    mine[id] = nil
end)
RegisterNetEvent('noir_weed:client:tableMine', function(id) mine[id] = true end)

return Tables
