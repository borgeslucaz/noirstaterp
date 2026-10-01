---Frota: viatura e helicóptero de departamento, sem dono.

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Departments = require 'shared.departments'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Layout = require 'server.layout'

local Fleet = {}

---@type table<integer, { entity: integer, department: string, owner: integer }> netId -> viatura
local vehicles = {}

local function fail(code) return { ok = false, code = code } end

local function findGarage(stationId, garageIndex)
    for _, station in ipairs(Layout.stations()) do
        if station.id == stationId then return station, station.garages and station.garages[garageIndex] end
    end
end

local function activeCount(src)
    local count = 0
    for netId, entry in pairs(vehicles) do
        if not DoesEntityExist(entry.entity) then
            vehicles[netId] = nil
        elseif entry.owner == src then
            count = count + 1
        end
    end
    return count
end

local function freeSpawn(garage)
    local all = GetAllVehicles()
    for _, spawn in ipairs(garage.spawns) do
        local taken = false
        for index = 1, #all do
            if #(GetEntityCoords(all[index]) - spawn.xyz) < 3.0 then taken = true break end
        end
        if not taken then return spawn end
    end
end

local function plateFor(department)
    local prefix = Config.fleet.platePrefix[department] or 'PD'
    local digits = 8 - #prefix
    return prefix .. tostring(math.random(10 ^ (digits - 1), 10 ^ digits - 1))
end

lib.callback.register('noir_police:server:fleetSpawn', function(src, stationId, garageIndex, model)
    if not Security.rateLimit(src, 'garage') then return fail('rate_limited') end
    local job = Security.police(src)
    if not job then return fail('not_police') end

    local station, garage = findGarage(stationId, tonumber(garageIndex))
    if not garage or not Departments.stationServes(station, job.name) then return fail('invalid_garage') end
    if not Security.near(src, garage.point, ServerConfig.distance.station + 2.0) then return fail('too_far') end

    local entry
    for _, candidate in ipairs(Config.fleet[garage.type] or {}) do
        if candidate.model == model then entry = candidate end
    end
    if not entry or not Departments.fleetAllows(entry, job) then return fail('not_allowed') end
    if activeCount(src) >= ServerConfig.fleet.maxActivePerOfficer then return fail('fleet_limit') end

    local spawn = freeSpawn(garage)
    if not spawn then return fail('spawn_blocked') end

    local netId, vehicle = Integrations.spawnVehicle(src, entry.model, spawn, true, plateFor(job.name))
    if not netId or not vehicle then return fail('spawn_failed') end
    vehicles[netId] = { entity = vehicle, department = job.name, owner = src }
    Entity(vehicle).state:set('noirPoliceFleet', job.name, true)
    Integrations.log(src, 'fleet_spawn', ('%s retirou %s'):format(Integrations.getName(src), entry.model))
    return { ok = true, netId = netId }
end)

lib.callback.register('noir_police:server:fleetStore', function(src, netId)
    if not Security.rateLimit(src, 'garage') then return fail('rate_limited') end
    local job = Security.police(src)
    if not job then return fail('not_police') end
    netId = tonumber(netId)
    local entry = netId and vehicles[netId]
    if not entry or not DoesEntityExist(entry.entity) then return fail('not_fleet') end
    if entry.department ~= job.name then return fail('not_fleet') end

    local coords = GetEntityCoords(entry.entity)
    local nearGarage = false
    for _, station in ipairs(Layout.stations()) do
        if Departments.stationServes(station, job.name) then
            for _, garage in ipairs(station.garages or {}) do
                if #(coords - garage.point) <= ServerConfig.fleet.storeDistance then nearGarage = true end
            end
        end
    end
    if not nearGarage then return fail('too_far') end
    if not Security.near(src, coords, ServerConfig.distance.vehicle + 4.0) then return fail('too_far') end

    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(playerId))
        if ped ~= 0 and GetVehiclePedIsIn(ped, false) == entry.entity and tonumber(playerId) ~= src then
            return fail('vehicle_occupied')
        end
    end

    DeleteEntity(entry.entity)
    vehicles[netId] = nil
    return { ok = true }
end)

---Viatura da frota? Usado pelo porta-malas (objetos).
---@param entity integer
---@return string? department
function Fleet.department(entity)
    for _, entry in pairs(vehicles) do
        if entry.entity == entity then return entry.department end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    for _, entry in pairs(vehicles) do
        if entry.owner == src then entry.owner = 0 end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, entry in pairs(vehicles) do
        if DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
    end
end)

return Fleet
