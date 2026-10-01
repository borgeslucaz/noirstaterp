---Reforços: o veículo nasce longe, dirige até o local (passando pela rota, se houver), a
---tripulação desce e ataca. Nada aparece do nada perto do jogador.
---
---O servidor acompanha a viagem pela posição do veículo e decide a chegada; quem dirige é o
---dono de rede do motorista, pela tarefa no registro (server/instances/world.lua).
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Npc = require 'server.components.npc'

local Reinforcement = {}

local WAYPOINT_REACHED = 25.0

local DRIVING_SPEED_FACTOR = { normal = 0.7, rushed = 1.0, aggressive = 1.0 }

---@param def table
---@param target table
---@return table task
local function driveTask(def, vehicleNetId, target, final)
    return {
        n = 'drive_to', veh = vehicleNetId, x = target.x, y = target.y, z = target.z,
        speed = (def.speed or 25) * (DRIVING_SPEED_FACTOR[def.drivingStyle] or 1.0),
        style = def.drivingStyle or 'rushed',
        stop = final and (def.arrivalDistance or 15) or WAYPOINT_REACHED,
    }
end

---@param inst table
---@param reinforcementId string
---@return table? run
function Reinforcement.send(inst, reinforcementId)
    local def = Utils.findById(inst.def.reinforcements, reinforcementId)
    if not def then return nil end

    inst.reinforcementCount = (inst.reinforcementCount or 0) + 1
    local key = ('reinf:%s:%d'):format(def.id, inst.reinforcementCount)
    local vehicle = World.createVehicle(inst, key, def.model, World.vehicleType(def.model, inst.leader), def.spawn, {
        plate = World.randomPlate(), npc = true,
    })
    if not vehicle then return nil end

    local run = {
        id = def.id, key = key, def = def, vehicle = vehicle, crew = {}, waypoint = 1,
        startedAt = Runtime.io.now(), arrived = false,
    }
    local points = {}
    for index = 1, #(def.route or {}) do points[#points + 1] = def.route[index] end
    points[#points + 1] = def.destination
    run.points = points

    for index = 1, #def.crew do
        local seat = index - 2 -- o primeiro dirige (-1), os outros 0, 1, 2...
        local task = seat == -1 and driveTask(def, vehicle.netId, points[1], #points == 1)
            or { n = 'ride', veh = vehicle.netId }
        local record = World.createPedInVehicle(inst, key, def.crew[index], vehicle, seat, task)
        if record then
            run.crew[#run.crew + 1] = record
            Npc.addPed(inst, key, record)
        end
    end
    -- A tripulação é hostil desde o começo: se for atacada no caminho, revida. A tarefa de
    -- dirigir continua até a chegada (Npc.setHostile não tira ninguém do volante).
    local crewGroup = inst.groups[key]
    if crewGroup then crewGroup.hostile = def.engage ~= false end

    inst.reinforcements[#inst.reinforcements + 1] = run
    Runtime.markDirty(inst)
    return run
end

---@param inst table
---@param run table
local function arrive(inst, run)
    run.arrived = true
    for index = 1, #run.crew do
        local record = run.crew[index]
        if run.def.exitOnArrival ~= false then
            World.setTask(record, { n = 'exit', veh = run.vehicle.netId, engage = run.def.engage ~= false })
        elseif run.def.engage ~= false then
            World.setTask(record, { n = 'combat' })
        end
    end
    Runtime.emit(inst, 'reinforcement_arrived', { reinforcement = run.id })
end

MissionComponents.register('reinforcement', {
    init = function(inst)
        inst.reinforcements = {}
    end,

    tick = function(inst)
        local now = Runtime.io.now()
        for index = 1, #inst.reinforcements do
            local run = inst.reinforcements[index]
            if not run.arrived then
                local coords = World.coords(run.vehicle)
                local driver = run.crew[1]
                local driverGone = not driver or driver.dead or not World.exists(driver)
                if not coords or driverGone then
                    -- Veículo destruído ou motorista morto: quem sobrou desce e luta.
                    arrive(inst, run)
                else
                    local target = run.points[run.waypoint]
                    local final = run.waypoint == #run.points
                    local reach = final and (run.def.arrivalDistance or 15) + 5.0 or WAYPOINT_REACHED
                    if Utils.distance(coords, target) <= reach then
                        if final then
                            arrive(inst, run)
                        else
                            run.waypoint = run.waypoint + 1
                            World.setTask(driver, driveTask(run.def, run.vehicle.netId,
                                run.points[run.waypoint], run.waypoint == #run.points))
                        end
                    elseif now - run.startedAt > (run.def.maxTravelSeconds or 150) * 1000 then
                        arrive(inst, run)
                    end
                end
            end
        end
    end,

    debug = function(inst, out)
        out.reinforcements = {}
        for index = 1, #inst.reinforcements do
            local run = inst.reinforcements[index]
            out.reinforcements[#out.reinforcements + 1] = ('%s ponto=%d/%d chegou=%s vivos=%d'):format(
                run.id, run.waypoint, #run.points, tostring(run.arrived), Npc.aliveCount(inst, run.key))
        end
    end,

    actions = {
        send_reinforcement = function(inst, action)
            Reinforcement.send(inst, action.reinforcement)
        end,
    },
})

return Reinforcement
