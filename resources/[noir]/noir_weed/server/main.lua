---Plantas no servidor. O servidor guarda o estado, faz o ciclo de crescimento e decide
---toda ação; o client só desenha o prop e roda a animação.
---
---Toda ação passa por `begin` e `finish`. O `begin` valida e anota a hora; o `finish`
---confere que a duração da animação passou (§17.4), valida tudo de novo — o mundo pode
---ter mudado nesses segundos — e só então mexe em item e planta.

local Shared = require 'config.shared'
local Config = require 'config.server'
local Rules = require 'shared.rules'
local Integrations = require 'server.integrations'
local Storage = require 'server.storage'

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

---@type table<integer, WeedPlant>
local plants = {}
local ready = false

---[source] = { action, payload, startedAt, duration }
local pending = {}
---[source] = instante em que o próximo pedido passa
local nextAllowed = {}

-- Visões --------------------------------------------------------------------------------

---O que todo client recebe: onde está, que semente e em que estágio. Dono fica de fora.
---@param plant WeedPlant
local function publicView(plant)
    return {
        id = plant.id,
        x = plant.x, y = plant.y, z = plant.z,
        heading = plant.heading,
        seed = plant.seed,
        stage = Rules.stageFor(Shared.stages, plant.growth),
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

-- Mundo ---------------------------------------------------------------------------------

---@param source number
---@return vector3?
local function pedCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

---@param source number
---@param point { x: number, y: number, z: number }
---@return number
local function distanceTo(source, point)
    local coords = pedCoords(source)
    if not coords then return math.huge end
    return #(coords - vector3(point.x, point.y, point.z))
end

---@param citizenId string
---@return integer
local function ownedCount(citizenId)
    local count = 0
    for _, plant in pairs(plants) do
        if plant.owner == citizenId then count += 1 end
    end
    return count
end

---Vaga para um vaso: perto do jogador, fora das zonas proibidas e longe dos outros vasos.
---@param source number
---@param placement { x: number, y: number, z: number, w: number }
---@param ignoreId? integer planta que está sendo movida
---@return boolean ok
---@return string? code
local function checkSpot(source, placement, ignoreId)
    if not Rules.isPlacement(placement) then return false, 'invalid_request' end
    if distanceTo(source, placement) > Config.distance.place then return false, 'too_far' end
    if Rules.inBlacklist(placement, Config.blacklistZones) then return false, 'blacklisted_zone' end
    local spot = vector3(placement.x, placement.y, placement.z)
    for id, plant in pairs(plants) do
        if id ~= ignoreId and #(spot - vector3(plant.x, plant.y, plant.z)) < Config.distance.spacing then
            return false, 'too_close'
        end
    end
    return true
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
    if distanceTo(source, plant) > Config.distance.interact then return nil, 'too_far' end
    return plant
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

-- Ações ---------------------------------------------------------------------------------

---stat da planta que cada cuidado repõe
local CARE_STAT = { water = 'water', fertilizer = 'fertilizer', herbicide = 'health' }

---Cada ação tem `check` (roda no begin e de novo no finish) e `apply` (só no finish).
---`check` devolve ok, code e um contexto que o `apply` recebe.
local Actions = {}

Actions.plant = {
    check = function(source, citizenId, payload)
        if type(payload) ~= 'table' then return false, 'invalid_request' end
        local seed = payload.seed
        if type(seed) ~= 'string' or not Shared.strains[seed] then return false, 'invalid_request' end
        if ownedCount(citizenId) >= Config.maxPlants then return false, 'max_plants' end
        if Integrations.count(source, seed) < 1 then return false, 'no_seed' end
        if Integrations.count(source, Shared.items.pot) < 1 then return false, 'no_pot' end
        if Integrations.count(source, Shared.items.shovel) < 1 then return false, 'no_shovel' end
        local ok, code = checkSpot(source, payload.placement)
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
}

for action, stat in pairs(CARE_STAT) do
    Actions[action] = {
        check = function(source, citizenId, payload)
            local plant, code = reachPlant(source, citizenId, type(payload) == 'table' and payload.id, true)
            if not plant then return false, code end
            if plant[stat] >= 100 then return false, 'max_' .. action end
            if Integrations.count(source, Shared.items[action]) < 1 then return false, 'no_' .. action end
            return true, nil, plant
        end,
        apply = function(source, _, plant)
            if not Integrations.removeItem(source, Shared.items[action], 1) then return false, 'no_' .. action end
            plant[stat] = Rules.clamp(plant[stat] + Config.care[action], 0, 100)
            return true
        end,
    }
end

Actions.harvest = {
    check = function(source, citizenId, payload)
        local plant, code = reachPlant(source, citizenId, type(payload) == 'table' and payload.id, true)
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
}

Actions.destroy = {
    check = function(source, citizenId, payload)
        local plant, code = reachPlant(source, citizenId, type(payload) == 'table' and payload.id, false)
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
}

---Mover: o begin confere dono e alcance; o finish traz o ponto novo.
Actions.move = {
    check = function(source, citizenId, payload, extra)
        local plant = type(payload) == 'table' and plants[payload.id] or nil
        if not plant then return false, 'no_plant' end
        if plant.owner ~= citizenId then return false, 'not_owner' end
        if extra == nil then
            if distanceTo(source, plant) > Config.distance.interact then return false, 'too_far' end
            return true, nil, plant
        end
        local ok, code = checkSpot(source, extra, plant.id)
        if not ok then return false, code end
        return true, nil, plant
    end,
    apply = function(_, _, plant, extra)
        plant.x, plant.y, plant.z, plant.heading = extra.x, extra.y, extra.z, extra.w % 360
        Storage.move(plant)
        broadcast(plant)
        return true
    end,
}

-- Callbacks -----------------------------------------------------------------------------

---@param source number
---@return boolean
local function rateLimit(source)
    local now = GetGameTimer()
    if (nextAllowed[source] or 0) > now then return false end
    nextAllowed[source] = now + Config.rateLimitMs
    return true
end

lib.callback.register('noir_weed:server:sync', function(source)
    local list, mine = {}, {}
    if not ready then return { plants = list, mine = mine } end
    local citizenId = Integrations.citizenId(source)
    for id, plant in pairs(plants) do
        list[#list + 1] = publicView(plant)
        if citizenId and plant.owner == citizenId then mine[#mine + 1] = id end
    end
    return { plants = list, mine = mine }
end)

lib.callback.register('noir_weed:server:status', function(source, id)
    local citizenId = Integrations.citizenId(source)
    if not citizenId then return { ok = false, code = 'not_loaded' } end
    local plant, code = reachPlant(source, citizenId, id, true)
    if not plant then return { ok = false, code = code } end
    return { ok = true, status = statusView(plant) }
end)

lib.callback.register('noir_weed:server:begin', function(source, action, payload)
    local def = type(action) == 'string' and Actions[action] or nil
    if not def or not ready then return { ok = false, code = 'invalid_request' } end
    if not rateLimit(source) then return { ok = false, code = 'rate_limited' } end
    -- Ação anterior que nunca terminou (client caiu no meio sem desconectar) deixa de
    -- travar depois de um tempo; mover ganha mais prazo porque o jogador escolhe o lugar.
    local previous = pending[source]
    local grace = previous and (previous.action == 'move' and 300000 or 15000)
    if previous and GetGameTimer() - previous.startedAt < previous.duration + grace then
        return { ok = false, code = 'busy' }
    end

    local citizenId = Integrations.citizenId(source)
    if not citizenId then return { ok = false, code = 'not_loaded' } end

    local ok, code = def.check(source, citizenId, payload)
    if not ok then return { ok = false, code = code } end

    pending[source] = {
        action = action,
        payload = payload,
        startedAt = GetGameTimer(),
        duration = Shared.durations[action] or 0,
    }
    return { ok = true }
end)

lib.callback.register('noir_weed:server:finish', function(source, action, extra)
    local session = pending[source]
    pending[source] = nil
    if not session or session.action ~= action then return { ok = false, code = 'invalid_request' } end
    if GetGameTimer() - session.startedAt < session.duration - Config.durationSlackMs then
        return { ok = false, code = 'too_fast' }
    end

    local citizenId = Integrations.citizenId(source)
    if not citizenId then return { ok = false, code = 'not_loaded' } end

    local def = Actions[action]
    local ok, code, context = def.check(source, citizenId, session.payload, extra)
    if not ok then return { ok = false, code = code } end

    local applied, applyCode, result = def.apply(source, citizenId, context, extra)
    if not applied then return { ok = false, code = applyCode } end
    local plant = plants[context and context.id or -1]
    return { ok = true, result = result, status = plant and statusView(plant) or nil }
end)

RegisterNetEvent('noir_weed:server:cancel', function()
    pending[source] = nil
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
    nextAllowed[source] = nil
end)

-- Ciclo ---------------------------------------------------------------------------------

---@return WeedPlant[]
local function allPlants()
    local list = {}
    for _, plant in pairs(plants) do list[#list + 1] = plant end
    return list
end

CreateThread(function()
    Storage.migrate()
    for _, row in ipairs(Storage.loadAll()) do
        if Shared.strains[row.seed] then
            plants[row.id] = row
        else
            lib.print.warn(('planta %d com semente desconhecida (%s): ignorada'):format(row.id, tostring(row.seed)))
        end
    end
    ready = true
    TriggerClientEvent('noir_weed:client:resync', -1)

    local ticks = 0
    while true do
        Wait(Config.growth.interval)
        for _, plant in pairs(plants) do
            local before = Rules.stageFor(Shared.stages, plant.growth)
            Rules.tick(plant, Config.growth, Shared.harvestAt)
            if Rules.stageFor(Shared.stages, plant.growth) ~= before then broadcast(plant) end
        end
        ticks += 1
        if ticks >= Config.saveEveryTicks then
            ticks = 0
            Storage.saveStatus(allPlants())
        end
    end
end)

local function saveAll()
    if ready then Storage.saveStatus(allPlants()) end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then saveAll() end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', saveAll)
AddEventHandler('txAdmin:events:scheduledRestart', function(event)
    if event.secondsRemaining == 60 then saveAll() end
end)
