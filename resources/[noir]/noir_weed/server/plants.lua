---Plantas: estado, ações e ciclo de crescimento.

local Shared = require 'config.shared'
local Config = require 'config.server'
local Rules = require 'shared.rules'
local Integrations = require 'server.integrations'
local Storage = require 'server.storage'
local World = require 'server.world'
local Actions = require 'server.actions'

---@class WeedPlant
---@field id integer
---@field owner string
---@field seed string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field growth number
---@field health number
---@field water number
---@field fertilizer number

local Plants = {}

---@type table<integer, WeedPlant>
local plants = {}

-- Visões --------------------------------------------------------------------------------

---O que todo client recebe: onde está, que semente e em que estágio. Dono fica de fora.
---@param plant WeedPlant
local function publicView(plant)
    return {
        id = plant.id,
        x = plant.x, y = plant.y, z = plant.z,
        heading = plant.heading,
        seed = plant.seed,
        stage = Rules.stageFor(Shared.stageAt, plant.growth),
    }
end

---@param plant WeedPlant
local function statusView(plant)
    return {
        id = plant.id,
        seed = plant.seed,
        growth = plant.growth,
        health = plant.health,
        water = plant.water,
        fertilizer = plant.fertilizer,
    }
end

local function broadcast(plant)
    TriggerClientEvent('noir_weed:client:upsert', -1, publicView(plant))
end

---@param plant WeedPlant
local function removePlant(plant)
    plants[plant.id] = nil
    Storage.delete(plant.id)
    TriggerClientEvent('noir_weed:client:remove', -1, plant.id)
end

---@param source number
---@param citizenId string
---@param id any
---@param ownerOnly boolean
---@return WeedPlant? plant
---@return string? code
local function reachPlant(source, citizenId, id, ownerOnly)
    local plant = type(id) == 'number' and plants[id] or nil
    if not plant then return nil, 'no_plant' end
    if ownerOnly and plant.owner ~= citizenId then return nil, 'not_owner' end
    if World.distanceTo(source, plant) > Config.distance.interact then return nil, 'too_far' end
    return plant
end

---@param payload any
---@return any
local function idOf(payload)
    return type(payload) == 'table' and payload.id or nil
end

-- Ações ---------------------------------------------------------------------------------

Actions.register('plant', {
    check = function(source, citizenId, payload)
        if type(payload) ~= 'table' then return false, 'invalid_request' end
        local seed = payload.seed
        if type(seed) ~= 'string' or not Shared.strains[seed] then return false, 'invalid_request' end
        if World.ownedCount(plants, citizenId) >= Config.maxPlants then return false, 'max_plants' end
        if Integrations.count(source, seed) < 1 then return false, 'no_seed' end
        if Integrations.count(source, Shared.items.pot) < 1 then return false, 'no_pot' end
        if Integrations.count(source, Shared.items.shovel) < 1 then return false, 'no_shovel' end
        local ok, code = World.checkSpot(source, payload.placement, plants, Config.distance.spacing)
        if not ok then return false, code end
        return true, nil, payload
    end,
    apply = function(source, citizenId, payload)
        if not Integrations.removeItem(source, payload.seed, 1) then return false, 'no_seed' end
        if not Integrations.removeItem(source, Shared.items.pot, 1) then
            Integrations.addItem(source, payload.seed, 1)
            return false, 'no_pot'
        end

        local placement = payload.placement
        local plant = {
            owner = citizenId,
            seed = payload.seed,
            x = placement.x, y = placement.y, z = placement.z,
            heading = placement.w % 360,
            growth = 0.0,
            health = Config.initial.health,
            water = Config.initial.water,
            fertilizer = Config.initial.fertilizer,
        }
        local id = Storage.insert(plant)
        if not id then
            Integrations.addItem(source, payload.seed, 1)
            Integrations.addItem(source, Shared.items.pot, 1)
            return false, 'operation_failed'
        end
        plant.id = id
        plants[id] = plant
        broadcast(plant)
        TriggerClientEvent('noir_weed:client:mine', source, id)
        return true
    end,
})

---stat da planta que cada cuidado repõe
local CARE_STAT = { water = 'water', fertilizer = 'fertilizer', herbicide = 'health' }

for action, stat in pairs(CARE_STAT) do
    Actions.register(action, {
        check = function(source, citizenId, payload)
            local plant, code = reachPlant(source, citizenId, idOf(payload), true)
            if not plant then return false, code end
            if plant[stat] >= 100 then return false, 'max_' .. action end
            if Integrations.count(source, Shared.items[action]) < 1 then return false, 'no_' .. action end
            return true, nil, plant
        end,
        apply = function(source, _, plant)
            if not Integrations.removeItem(source, Shared.items[action], 1) then return false, 'no_' .. action end
            plant[stat] = Rules.clamp(plant[stat] + Config.care[action], 0, 100)
            return true, nil, { status = statusView(plant) }
        end,
    })
end

Actions.register('harvest', {
    check = function(source, citizenId, payload)
        local plant, code = reachPlant(source, citizenId, idOf(payload), true)
        if not plant then return false, code end
        if plant.growth < Shared.harvestAt then return false, 'not_ready' end
        if Integrations.count(source, Shared.items.shovel) < 1 then return false, 'no_shovel' end
        local amount = Rules.reward(Config.reward, plant.health)
        if not Integrations.canCarry(source, Shared.strains[plant.seed].product, amount) then return false, 'inventory_full' end
        return true, nil, plant
    end,
    apply = function(source, _, plant)
        local amount = Rules.reward(Config.reward, plant.health)
        -- Remove antes de entregar: com duas colheitas no mesmo tick, a segunda não acha
        -- mais a planta no check e para ali.
        removePlant(plant)
        local ok, code = Integrations.addItem(source, Shared.strains[plant.seed].product, amount)
        if not ok then
            lib.print.error(('colheita %d: AddItem falhou para %d (%s)'):format(plant.id, source, tostring(code)))
            return false, 'operation_failed'
        end
        return true, nil, { amount = amount, seed = plant.seed }
    end,
})

Actions.register('destroy', {
    check = function(source, citizenId, payload)
        local plant, code = reachPlant(source, citizenId, idOf(payload), false)
        if not plant then return false, code end
        if plant.owner ~= citizenId
            and not Integrations.hasAnyJob(source, Shared.destroyJobs, Config.destroyRequiresDuty) then
            return false, 'not_owner'
        end
        return true, nil, plant
    end,
    apply = function(_, _, plant)
        removePlant(plant)
        return true
    end,
})

---Mover: o begin confere dono e alcance; o finish traz o ponto novo.
Actions.register('move', {
    check = function(source, citizenId, payload, extra)
        local plant = plants[idOf(payload) or -1]
        if not plant then return false, 'no_plant' end
        if plant.owner ~= citizenId then return false, 'not_owner' end
        if extra == nil then
            if World.distanceTo(source, plant) > Config.distance.interact then return false, 'too_far' end
            return true, nil, plant
        end
        local ok, code = World.checkSpot(source, extra, plants, Config.distance.spacing, plant.id)
        if not ok then return false, code end
        return true, nil, plant
    end,
    apply = function(_, _, plant, extra)
        plant.x, plant.y, plant.z, plant.heading = extra.x, extra.y, extra.z, extra.w % 360
        Storage.move(plant)
        broadcast(plant)
        return true
    end,
})

lib.callback.register('noir_weed:server:status', function(source, id)
    local citizenId = Integrations.citizenId(source)
    if not citizenId then return { ok = false, code = 'not_loaded' } end
    local plant, code = reachPlant(source, citizenId, id, true)
    if not plant then return { ok = false, code = code } end
    return { ok = true, status = statusView(plant) }
end)

-- Boot, sync e ciclo --------------------------------------------------------------------

function Plants.load()
    for _, row in ipairs(Storage.loadAll()) do
        if Shared.strains[row.seed] then
            plants[row.id] = row
        else
            lib.print.warn(('planta %d com semente desconhecida (%s): ignorada'):format(row.id, tostring(row.seed)))
        end
    end
end

---@param citizenId? string
---@return table[] views
---@return integer[] mine
function Plants.sync(citizenId)
    local list, mine = {}, {}
    for id, plant in pairs(plants) do
        list[#list + 1] = publicView(plant)
        if citizenId and plant.owner == citizenId then mine[#mine + 1] = id end
    end
    return list, mine
end

function Plants.save()
    local list = {}
    for _, plant in pairs(plants) do list[#list + 1] = plant end
    Storage.saveStatus(list)
end

function Plants.run()
    local ticks = 0
    while true do
        Wait(Config.growth.interval)
        for _, plant in pairs(plants) do
            local before = Rules.stageFor(Shared.stageAt, plant.growth)
            Rules.tick(plant, Config.growth, Shared.harvestAt)
            if Rules.stageFor(Shared.stageAt, plant.growth) ~= before then broadcast(plant) end
        end
        ticks += 1
        if ticks >= Config.saveEveryTicks then
            ticks = 0
            Plants.save()
        end
    end
end

return Plants
