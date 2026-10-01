---Perseguição: veículos inimigos nascem num ponto cadastrado fora da vista, perseguem o alvo
---(o veículo com a carga, ou um participante), e acabam por derrota, despiste ou tempo. Ondas
---seguintes começam quando a anterior acaba sem os jogadores despistarem.
local Utils = require 'shared.utils.core'
local SpawnPoints = require 'shared.utils.spawnpoints'
local Config = require 'config.server'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Npc = require 'server.components.npc'
local Cargo = require 'server.components.cargo'

local Chase = {}

local LOST_HOLD_MS = 8000
local SPACING = 9.0

---Alvo: o participante que dirige o veículo com carga; senão quem dirige qualquer veículo;
---senão o participante mais perto do líder.
---@param inst table
---@return integer? source
---@return integer? entity
local function pickTarget(inst)
    for _, cargoEntry in pairs(inst.cargo or {}) do
        for _, entry in ipairs(Cargo.loadedByVehicle(inst, cargoEntry.def.id)) do
            local driver = GetPedInVehicleSeat(entry.record.entity, -1)
            for source in pairs(inst.participants) do
                if driver ~= 0 and GetPlayerPed(source) == driver then return source, entry.record.entity end
            end
        end
    end
    for source in pairs(inst.participants) do
        local ped = GetPlayerPed(source)
        local vehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
        if vehicle ~= 0 then return source, vehicle end
    end
    local leader = inst.leader
    if leader and GetPlayerPed(leader) ~= 0 then return leader, GetPlayerPed(leader) end
    for source in pairs(inst.participants) do
        if GetPlayerPed(source) ~= 0 then return source, GetPlayerPed(source) end
    end
    return nil
end

---@param def table
---@param waveIndex integer
---@return table wave { model, countMin, countMax }
local function waveOf(def, waveIndex)
    if waveIndex == 0 then return def end
    return def.waves[waveIndex]
end

---@param inst table
---@param def table
---@param waveIndex integer
---@param attempt integer
function Chase.start(inst, def, waveIndex, attempt)
    local wave = waveOf(def, waveIndex)
    if not wave then return end

    local targetSource, targetEntity = pickTarget(inst)
    if not targetSource then return end
    local targetCoords = GetEntityCoords(targetEntity)
    local players = {}
    for _, position in pairs(inst.positions) do players[#players + 1] = position end
    local index = SpawnPoints.choose(def.spawnPoints, {
        target = targetCoords,
        forward = SpawnPoints.forward(GetEntityVelocity(targetEntity), GetEntityHeading(targetEntity)),
        players = players,
        minDistance = def.minSpawnDistance or 120,
        maxDistance = def.maxSpawnDistance or 450,
    })

    local point = index and def.spawnPoints[index] or nil
    if not point and def.roadSpawn ~= false then
        point = Chase.requestRoadSpawn(targetSource, targetCoords, def)
    end

    if not point then
        if attempt < Config.chase.retryLimit then
            Runtime.schedule(inst, Config.chase.retrySeconds * 1000, function()
                Chase.start(inst, def, waveIndex, attempt + 1)
            end)
        else
            Runtime.io.log('warn', ('#%d perseguição %s sem ponto válido de nascimento'):format(inst.id, def.id))
            Runtime.emit(inst, 'chase_ended', { chase = def.id, reason = 'no_spawn' })
        end
        return
    end

    local heading = math.rad(point.w or 0.0)
    local count = Utils.randomBetween(wave.countMin or 1, math.max(wave.countMin or 1, wave.countMax or 1), Runtime.io.random)
    inst.chaseCount = (inst.chaseCount or 0) + 1
    local key = ('chase:%s:%d'):format(def.id, inst.chaseCount)
    local run = {
        id = def.id, def = def, wave = waveIndex, key = key, vehicles = {}, crew = {},
        target = targetSource, startedAt = Runtime.io.now(),
    }
    local vehicleType = World.vehicleType(wave.model, inst.leader)

    for number = 1, count do
        local back = (number - 1) * SPACING
        local coords = {
            x = point.x + math.sin(heading) * back, y = point.y - math.cos(heading) * back,
            z = point.z, w = point.w or 0.0,
        }
        local vehicle = World.createVehicle(inst, key, wave.model, vehicleType, coords, { plate = World.randomPlate(), npc = true })
        if vehicle then
            run.vehicles[#run.vehicles + 1] = vehicle
            for crewIndex = 1, #def.crew do
                local seat = crewIndex - 2
                local task
                if seat == -1 then
                    task = {
                        n = 'chase', veh = vehicle.netId, target = targetSource, speed = def.maxSpeed or 45,
                        style = def.drivingStyle or 'aggressive', ram = def.ram ~= false, shoot = def.driverShoots == true,
                    }
                elseif def.passengersShoot ~= false then
                    task = { n = 'driveby', veh = vehicle.netId, target = targetSource }
                else
                    task = { n = 'ride', veh = vehicle.netId }
                end
                local record = World.createPedInVehicle(inst, key, def.crew[crewIndex], vehicle, seat, task)
                if record then
                    run.crew[#run.crew + 1] = record
                    Npc.addPed(inst, key, record)
                end
            end
        end
    end
    local crewGroup = inst.groups[key]
    if crewGroup then crewGroup.hostile = true end

    inst.chases[#inst.chases + 1] = run
    Runtime.emit(inst, 'chase_started', { chase = def.id })
    Runtime.markDirty(inst)
end

-- Ponto na estrada, achado pelo cliente do alvo ------------------------------------------
-- O servidor não conhece a malha de vias. O cliente de quem está sendo perseguido procura um
-- nó de via atrás dele, na faixa de distância, fora da tela. O servidor só aceita o ponto se
-- ele for finito e estiver mesmo na faixa, medida pela posição que o servidor tem do alvo.

local roadRequests = {}
local roadCounter = 0

RegisterNetEvent('noir_missions:server:chaseSpawn', function(requestId, point)
    local request = roadRequests[requestId]
    if not request or request.source ~= source then return end
    request.done = true
    if type(point) == 'table' and Utils.isPosition(point) then request.point = point end
end)

---@param targetSource integer
---@param targetCoords vector3
---@param def table
---@return table? point
function Chase.requestRoadSpawn(targetSource, targetCoords, def)
    roadCounter = roadCounter + 1
    local requestId = roadCounter
    local request = { source = targetSource }
    roadRequests[requestId] = request
    local minDistance, maxDistance = def.minSpawnDistance or 120, def.maxSpawnDistance or 450
    TriggerClientEvent('noir_missions:client:chaseSpawn', targetSource, requestId, minDistance, maxDistance)
    for _ = 1, 30 do
        if request.done then break end
        Wait(100)
    end
    roadRequests[requestId] = nil
    local point = request.point
    if not point then return nil end
    local distance = Utils.distance2d(point, targetCoords)
    if distance < minDistance * 0.8 or distance > maxDistance * 1.2 then return nil end
    return { x = point.x, y = point.y, z = point.z, w = point.w or 0.0 }
end

---@param run table
---@param task table
local function retask(run, task)
    for index = 1, #run.crew do
        if not run.crew[index].dead then World.setTask(run.crew[index], task(run.crew[index])) end
    end
end

---@param inst table
---@param run table
---@param reason string
---@param allowNext boolean
local function finishRun(inst, run, reason, allowNext)
    if run.ended then return end
    run.ended = true
    run.endedAt = Runtime.io.now()
    retask(run, function(record)
        if record.seat == -1 then return { n = 'wander', veh = World.getTask(record) and World.getTask(record).veh } end
        return { n = 'ride', veh = World.getTask(record) and World.getTask(record).veh }
    end)
    Runtime.emit(inst, 'chase_ended', { chase = run.id, reason = reason })
    local nextWave = run.def.waves[run.wave + 1]
    if allowNext and reason ~= 'lost' and nextWave then
        Runtime.schedule(inst, (nextWave.delaySeconds or 0) * 1000, function()
            Chase.start(inst, run.def, run.wave + 1, 0)
        end)
    end
end

---@param inst table
---@param run table
local function tickRun(inst, run)
    -- Alvo saiu da missão: o mais perto assume.
    if not inst.participants[run.target] then
        local source = pickTarget(inst)
        if not source then return end
        run.target = source
        retask(run, function(record)
            local task = Utils.deepCopy(World.getTask(record) or {})
            task.target = source
            return task
        end)
    end

    local anyCrew = Npc.aliveCount(inst, run.key) > 0
    local anyVehicle = false
    local closest = math.huge
    local targetPed = GetPlayerPed(run.target)
    local targetCoords = targetPed ~= 0 and GetEntityCoords(targetPed) or nil
    for index = 1, #run.vehicles do
        local vehicle = run.vehicles[index]
        if not World.vehicleDestroyed(vehicle) then
            anyVehicle = true
            if targetCoords then closest = math.min(closest, #(GetEntityCoords(vehicle.entity) - targetCoords)) end
        end
    end

    if not anyCrew or not anyVehicle then return finishRun(inst, run, 'defeated', true) end

    local now = Runtime.io.now()
    if closest > (run.def.loseDistance or 400) then
        run.lostSince = run.lostSince or now
        if now - run.lostSince >= LOST_HOLD_MS then return finishRun(inst, run, 'lost', false) end
    else
        run.lostSince = nil
    end

    if (run.def.durationSeconds or 0) > 0 and now - run.startedAt > run.def.durationSeconds * 1000 then
        return finishRun(inst, run, 'timeout', true)
    end
end

---Depois de acabar, os veículos somem quando ninguém mais está vendo.
---@param inst table
---@param run table
---@return boolean removed
local function despawnIfFar(inst, run)
    local limit = Config.chase.despawnDistance
    local entities = {}
    for index = 1, #run.vehicles do entities[#entities + 1] = run.vehicles[index] end
    for index = 1, #run.crew do entities[#entities + 1] = run.crew[index] end
    for index = 1, #entities do
        local coords = World.coords(entities[index])
        if coords then
            for _, position in pairs(inst.positions) do
                if #(coords - position) < limit then return false end
            end
        end
    end
    for index = 1, #entities do World.delete(entities[index]) end
    inst.groups[run.key] = nil
    return true
end

MissionComponents.register('chase', {
    init = function(inst)
        inst.chases = {}
    end,

    tick = function(inst)
        local kept = {}
        for index = 1, #inst.chases do
            local run = inst.chases[index]
            if not run.ended then tickRun(inst, run) end
            if inst.status ~= 'ACTIVE' then return end
            if not (run.ended and despawnIfFar(inst, run)) then kept[#kept + 1] = run end
        end
        inst.chases = kept
    end,

    resolve = function(inst, parts)
        if parts[1] ~= 'chase' or #parts ~= 3 or parts[3] ~= 'active' then return false end
        for index = 1, #inst.chases do
            if inst.chases[index].id == parts[2] and not inst.chases[index].ended then return true, true end
        end
        return true, false
    end,

    debug = function(inst, out)
        out.chases = {}
        for index = 1, #inst.chases do
            local run = inst.chases[index]
            out.chases[#out.chases + 1] = ('%s onda=%d veículos=%d vivos=%d alvo=%s acabou=%s'):format(
                run.id, run.wave, #run.vehicles, Npc.aliveCount(inst, run.key), tostring(run.target), tostring(run.ended))
        end
    end,

    actions = {
        start_chase = function(inst, action)
            local def = Utils.findById(inst.def.chases, action.chase)
            if def then Chase.start(inst, def, 0, 0) end
        end,
        stop_chase = function(inst, action)
            for index = 1, #inst.chases do
                if inst.chases[index].id == action.chase then finishRun(inst, inst.chases[index], 'stopped', false) end
            end
        end,
    },
})

return Chase
