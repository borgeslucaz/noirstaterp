---Objetos do porta-malas e spike strip. Todo objeto nasce e morre no servidor.

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Utils = require 'shared.utils'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Fleet = require 'server.modules.fleet'

local Equipment = {}

---@type table<integer, { entity: integer, owner: integer }> netId -> objeto
local objects = {}
local spikes = {}

local objectById = {}
for _, entry in ipairs(Config.objects) do objectById[entry.id] = entry end

local function fail(code) return { ok = false, code = code } end

local function ownedCount(src)
    local count = 0
    for netId, entry in pairs(objects) do
        if not DoesEntityExist(entry.entity) then objects[netId] = nil
        elseif entry.owner == src then count = count + 1 end
    end
    return count
end

local function fleetNearby(src)
    local coords = Security.coords(src)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(vehicle) - coords) <= 12.0 and Fleet.department(vehicle) then return true end
    end
    return false
end

local function spawnObject(model, coords, heading, freeze)
    local entity = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, true, false)
    local deadline = GetGameTimer() + 2000
    while not DoesEntityExist(entity) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end
    SetEntityHeading(entity, heading + 0.0)
    FreezeEntityPosition(entity, freeze == true)
    return entity
end

lib.callback.register('noir_police:server:placeObject', function(src, objectId, coords, heading)
    if not Security.rateLimit(src, 'object') then return fail('rate_limited') end
    if not Security.police(src) then return fail('not_police') end
    local entry = objectById[objectId]
    coords = Utils.toVec3(coords)
    heading = tonumber(heading)
    if not entry or not coords or not heading then return fail('invalid_input') end
    if not Security.near(src, coords, ServerConfig.distance.objectPlace) then return fail('too_far') end
    if ownedCount(src) >= ServerConfig.objects.maxPerOfficer then return fail('object_limit') end
    if not fleetNearby(src) then return fail('no_fleet_vehicle') end

    local entity = spawnObject(entry.model, coords, heading, entry.freeze)
    if not entity then return fail('spawn_failed') end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    objects[netId] = { entity = entity, owner = src }
    Entity(entity).state:set('noirPoliceObject', true, true)
    return { ok = true, netId = netId }
end)

lib.callback.register('noir_police:server:removeObject', function(src, netId)
    if not Security.rateLimit(src, 'object') then return fail('rate_limited') end
    if not Security.police(src) then return fail('not_police') end
    netId = tonumber(netId)
    local entry = netId and objects[netId]
    if not entry or not DoesEntityExist(entry.entity) then return fail('invalid_object') end
    if not Security.near(src, GetEntityCoords(entry.entity), ServerConfig.distance.interact + 2.0) then return fail('too_far') end
    DeleteEntity(entry.entity)
    objects[netId] = nil
    return { ok = true }
end)

-- Spike strip ----------------------------------------------------------------------

lib.callback.register('noir_police:server:deploySpikes', function(src, first, second, size)
    if not Security.rateLimit(src, 'spikes') then return fail('rate_limited') end
    if not Security.police(src) then return fail('not_police') end
    if Security.inVehicle(src) then return fail('in_vehicle') end
    size = Utils.intInRange(size, 1, Config.spikes.maxPerDeploy)
    first, second = Utils.toVec3(first), Utils.toVec3(second)
    if not size or not first or not second then return fail('invalid_input') end

    local maximum = ServerConfig.spikes.maxSegmentLength
    if #(first - second) > maximum or not Security.near(src, first, maximum) or not Security.near(src, second, maximum) then
        return fail('too_far')
    end
    if Integrations.itemCount(src, Config.items.spikestrip) < size then return fail('no_item') end
    if not Integrations.removeItem(src, Config.items.spikestrip, size) then return fail('no_item') end

    local direction = second - first
    local length = #direction
    local unit = length > 0 and direction / length or vector3(0.0, 1.0, 0.0)
    local heading = math.deg(math.atan(unit.y, unit.x)) + 90.0

    CreateThread(function()
        for index = size, 1, -1 do
            local t = (index * 2 - 1) / (size * 2)
            local point = first + direction * t
            local entity = spawnObject(Config.spikes.model, point, heading, false)
            if entity then
                SetEntityRotation(entity, 0.0, 0.0, heading, 2, false)
                spikes[NetworkGetNetworkIdFromEntity(entity)] = entity
                Entity(entity).state:set('noirPoliceSpike', true, true)
            end
            Wait(800)
        end
    end)
    Integrations.log(src, 'spikes', ('%s abriu %d spike(s)'):format(Integrations.getName(src), size))
    return { ok = true }
end)

lib.callback.register('noir_police:server:retrieveSpikes', function(src, netId)
    if not Security.rateLimit(src, 'spikes') then return fail('rate_limited') end
    if Security.inVehicle(src) then return fail('in_vehicle') end
    netId = tonumber(netId)
    local entity = netId and spikes[netId]
    if not entity or not DoesEntityExist(entity) then return fail('invalid_object') end
    if not Security.near(src, GetEntityCoords(entity), 5.0) then return fail('too_far') end
    if not Integrations.canCarry(src, Config.items.spikestrip, 1) then return fail('inventory_full') end
    DeleteEntity(entity)
    spikes[netId] = nil
    Integrations.addItem(src, Config.items.spikestrip, 1)
    return { ok = true }
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, entry in pairs(objects) do if DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end end
    for _, entity in pairs(spikes) do if DoesEntityExist(entity) then DeleteEntity(entity) end end
end)

return Equipment
