---Comboios: veículos em fila numa rota. O primeiro vivo conduz pelos pontos; cada um dos outros
---segue o da frente. Atacados (tiro perto, NPC ferido, veículo batido), defendem a carga.
---Um comboio de um veículo só com fim "repetir" é uma patrulha.
---
---O servidor só decide: quem conduz, qual o próximo ponto, quando houve ataque. Quem dirige é o
---dono de rede de cada motorista, pela tarefa no registro (server/instances/world.lua).
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Npc = require 'server.components.npc'
local Cargo = require 'server.components.cargo'

local Convoy = {}

local WAYPOINT_REACHED = 20.0
local SPEED_FACTOR = { normal = 1.0, rushed = 1.15, aggressive = 1.25 }

---@param a table
---@param b table
---@return number heading em graus (convenção do GTA)
local function headingBetween(a, b)
    return (math.deg(math.atan(-(b.x - a.x), b.y - a.y)) + 360.0) % 360.0
end

---@param run table
---@return table[] veículos com motorista vivo, em ordem de fila
local function aliveUnits(run)
    local list = {}
    for index = 1, #run.units do
        local unit = run.units[index]
        local driver = unit.crew[1]
        if not unit.wrecked and driver and not driver.dead and World.exists(driver) and World.exists(unit.vehicle) then
            list[#list + 1] = unit
        end
    end
    return list
end

---Tarefa de quem conduz: o próximo ponto da rota.
---@param run table
---@param unit table
local function driveLead(run, unit)
    local def = run.def
    local point = def.route[run.waypoint]
    World.setTask(unit.crew[1], {
        n = 'drive_to', veh = unit.vehicle.netId, x = point.x, y = point.y, z = point.z,
        speed = (def.speed or 16) * (SPEED_FACTOR[def.drivingStyle] or 1.0),
        style = def.drivingStyle or 'normal', stop = WAYPOINT_REACHED * 0.5,
    })
end

---Reorganiza a fila: o primeiro vivo conduz, cada um segue o vivo à frente. Chamado ao nascer
---e quando alguém da fila cai.
---@param run table
local function reform(run)
    local units = aliveUnits(run)
    run.formation = units
    for index = 1, #units do
        local unit = units[index]
        if index == 1 then
            driveLead(run, unit)
        else
            World.setTask(unit.crew[1], {
                n = 'escort', veh = unit.vehicle.netId, target = units[index - 1].vehicle.netId,
                -- Quem segue anda um pouco mais rápido para não ficar para trás.
                speed = (run.def.speed or 16) * 1.25, style = run.def.drivingStyle or 'normal',
                distance = run.def.formationDistance or 12,
            })
        end
    end
end

---@param inst table
---@param convoyId string
---@return table? run
function Convoy.spawn(inst, convoyId)
    local def = Utils.findById(inst.def.convoys, convoyId)
    if not def or #def.route < 2 then return nil end
    local existing = inst.convoys[convoyId]
    if existing and not existing.removed then return existing end

    local key = 'convoy:' .. convoyId
    local start, second = def.route[1], def.route[2]
    local heading = start.w or headingBetween(start, second)
    local radians = math.rad(heading)
    local back = { x = math.sin(radians), y = -math.cos(radians) }
    local run = {
        id = convoyId, def = def, key = key, units = {}, waypoint = 2,
        attacked = false, arrived = false, destroyedEmitted = false,
    }

    for index = 1, #def.vehicles do
        local entry = def.vehicles[index]
        local spacing = (index - 1) * ((def.formationDistance or 12) + 4.0)
        local coords = {
            x = start.x + back.x * spacing, y = start.y + back.y * spacing, z = start.z, w = heading,
        }
        local vehicle = World.createVehicle(inst, key, entry.model, World.vehicleType(entry.model, inst.leader), coords, {
            plate = World.randomPlate(), npc = true,
        })
        if vehicle then
            local unit = { index = index, role = entry.role, vehicle = vehicle, crew = {} }
            for crewIndex = 1, #entry.crew do
                local seat = crewIndex - 2
                if not World.seatExists(entry.model, seat, inst.leader) then break end
                local record = World.createPedInVehicle(inst, key, entry.crew[crewIndex], vehicle, seat,
                    { n = 'ride', veh = vehicle.netId })
                if record then
                    unit.crew[#unit.crew + 1] = record
                    Npc.addPed(inst, key, record)
                end
            end
            run.units[#run.units + 1] = unit
        end
    end
    local crewGroup = inst.groups[key]
    if crewGroup then crewGroup.hostile = false end

    inst.convoys[convoyId] = run
    reform(run)

    -- Carga que nasce dentro de um veículo deste comboio.
    for index = 1, #inst.def.cargo do
        local cargoDef = inst.def.cargo[index]
        if cargoDef.startConvoy == convoyId then
            local unit = run.units[cargoDef.startConvoyVehicle or 1]
            if unit then Cargo.loadIntoSource(inst, cargoDef.id, unit.vehicle) end
        end
    end

    Runtime.trace(inst, ('comboio %s saiu com %d veículos'):format(convoyId, #run.units))
    Runtime.markDirty(inst)
    return run
end

---@param inst table
---@param convoyId string
function Convoy.despawn(inst, convoyId)
    local run = inst.convoys[convoyId]
    if not run then return end
    run.removed = true
    for _, unit in ipairs(run.units) do
        for _, record in ipairs(unit.crew) do World.delete(record) end
        World.delete(unit.vehicle)
    end
    inst.groups[run.key] = nil
    inst.convoys[convoyId] = nil
    Runtime.markDirty(inst)
end

---Ataque: escoltas descem para lutar; a carga para junto ou foge pela rota.
---@param inst table
---@param run table
---@param reason string
function Convoy.attack(inst, run, reason)
    if run.attacked then return end
    run.attacked = true
    local crewGroup = inst.groups[run.key]
    if crewGroup then crewGroup.hostile = true end
    local fleeing = run.def.onAttack == 'truck_flees'
    local last = run.def.route[#run.def.route]
    for _, unit in ipairs(run.units) do
        for seatIndex, record in ipairs(unit.crew) do
            if not record.dead then
                if fleeing and unit.role == 'cargo' then
                    if seatIndex == 1 then
                        World.setTask(record, {
                            n = 'drive_to', veh = unit.vehicle.netId, x = last.x, y = last.y, z = last.z,
                            speed = (run.def.speed or 16) * 1.6, style = 'aggressive', stop = 10.0,
                        })
                    else
                        World.setTask(record, { n = 'ride', veh = unit.vehicle.netId })
                    end
                else
                    World.setTask(record, { n = 'exit', veh = unit.vehicle.netId, engage = true })
                end
            end
        end
    end
    Runtime.trace(inst, ('comboio %s atacado (%s)'):format(run.id, reason))
    Runtime.emit(inst, 'convoy_attacked', { convoy = run.id, reason = reason })
end

---Alguém da tripulação ferido ou morto, ou veículo batido, depois de visto inteiro?
---@param run table
---@return string? reason
local function hurt(run)
    for _, unit in ipairs(run.units) do
        local vehicle = unit.vehicle
        if World.exists(vehicle) then
            local engine = GetVehicleEngineHealth(vehicle.entity)
            if not unit.wrecked and World.vehicleDestroyed(vehicle) then
                unit.wrecked = true
                return 'veículo destruído'
            end
            if engine > 0 then
                -- Folga para batidinha de trânsito da própria IA não virar "ataque".
                if unit.maxEngine and engine < unit.maxEngine - 60.0 then return 'veículo atingido' end
                if not unit.maxEngine or engine > unit.maxEngine then unit.maxEngine = engine end
            end
        end
        for _, record in ipairs(unit.crew) do
            if record.dead then return 'tripulante morto' end
            local state, health = World.pedState(record)
            if state == 'dead' then return 'tripulante morto' end
            if state == 'alive' and health and Entity(record.entity).state[World.STATE_INIT] then
                if record.maxHealth and health < record.maxHealth - 2 then return 'tripulante ferido' end
                if not record.maxHealth or health > record.maxHealth then record.maxHealth = health end
            end
        end
    end
    return nil
end

---@param inst table
---@param run table
local function tickRun(inst, run)
    if run.removed then return end

    if not run.attacked then
        local reason = hurt(run)
        if reason then return Convoy.attack(inst, run, reason) end
    end

    local alive = Npc.aliveCount(inst, run.key)
    if alive == 0 and not run.destroyedEmitted then
        run.destroyedEmitted = true
        Runtime.trace(inst, ('comboio %s neutralizado'):format(run.id))
        Runtime.emit(inst, 'convoy_destroyed', { convoy = run.id })
        return
    end
    if run.attacked or run.arrived then return end

    -- O comboio anda: a área onde tiro conta precisa acompanhar no cliente.
    run.areaTicks = (run.areaTicks or 0) + 1
    if run.areaTicks % 3 == 0 then Runtime.markDirty(inst) end

    -- Fila mudou (alguém caiu): reorganiza.
    local units = aliveUnits(run)
    local changed = #units ~= #(run.formation or {})
    for index = 1, #units do
        if run.formation[index] ~= units[index] then changed = true end
    end
    if changed then reform(run) end
    local lead = units[1]
    if not lead then return end

    local coords = World.coords(lead.vehicle)
    local target = run.def.route[run.waypoint]
    if coords and target and Utils.distance(coords, target) <= WAYPOINT_REACHED then
        if run.waypoint < #run.def.route then
            run.waypoint = run.waypoint + 1
            driveLead(run, lead)
        elseif run.def.endBehavior == 'loop' then
            run.waypoint = 1
            driveLead(run, lead)
        else
            run.arrived = true
            Runtime.trace(inst, ('comboio %s chegou ao fim da rota'):format(run.id))
            Runtime.emit(inst, 'convoy_arrived', { convoy = run.id })
            if run.def.endBehavior == 'despawn' then
                Convoy.despawn(inst, run.id)
            else
                for _, unit in ipairs(units) do World.setTask(unit.crew[1], { n = 'ride', veh = unit.vehicle.netId }) end
            end
        end
    end
end

MissionComponents.register('convoy', {
    init = function(inst)
        inst.convoys = {}
    end,

    start = function(inst)
        for index = 1, #inst.def.convoys do
            if inst.def.convoys[index].spawnOnStart then Convoy.spawn(inst, inst.def.convoys[index].id) end
        end
    end,

    tick = function(inst)
        for _, run in pairs(inst.convoys) do
            if inst.status ~= 'ACTIVE' then return end
            tickRun(inst, run)
        end
    end,

    event = function(inst, name, payload)
        if name ~= 'shot_fired' or not payload.coords then return end
        for _, run in pairs(inst.convoys) do
            if not run.attacked and not run.removed then
                for _, unit in ipairs(run.units) do
                    local coords = World.coords(unit.vehicle)
                    if coords and #(coords - payload.coords) <= (run.def.attackRadius or 50) then
                        Convoy.attack(inst, run, 'tiro')
                        break
                    end
                end
            end
        end
    end,

    resolve = function(inst, parts)
        if parts[1] ~= 'convoy' or #parts ~= 3 then return false end
        local run = inst.convoys[parts[2]]
        local field = parts[3]
        if field == 'alive' then return true, run and Npc.aliveCount(inst, run.key) or 0 end
        if field == 'attacked' then return true, run ~= nil and run.attacked end
        if field == 'arrived' then return true, run ~= nil and run.arrived end
        return false
    end,

    -- Tiro perto do comboio conta (o cliente percebe, o servidor confere).
    areas = function(inst, list)
        for _, run in pairs(inst.convoys) do
            if not run.attacked and not run.removed then
                for _, unit in ipairs(run.units) do
                    local coords = World.coords(unit.vehicle)
                    if coords then
                        list[#list + 1] = { x = coords.x, y = coords.y, z = coords.z, r = (run.def.attackRadius or 50) + 30 }
                    end
                end
            end
        end
    end,

    debug = function(inst, out)
        out.convoys = {}
        for id, run in pairs(inst.convoys) do
            out.convoys[#out.convoys + 1] = ('%s ponto=%d/%d vivos=%d atacado=%s chegou=%s'):format(
                id, run.waypoint, #run.def.route, Npc.aliveCount(inst, run.key), tostring(run.attacked), tostring(run.arrived))
        end
    end,

    actions = {
        spawn_convoy = function(inst, action) Convoy.spawn(inst, action.convoy) end,
        despawn_convoy = function(inst, action) Convoy.despawn(inst, action.convoy) end,
        convoy_attack = function(inst, action)
            local run = inst.convoys[action.convoy]
            if run then Convoy.attack(inst, run, 'ação') end
        end,
    },
})

return Convoy
