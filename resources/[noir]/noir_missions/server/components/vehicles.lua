---Veículos de missão (a van da carga, um barco) e objetos de cenário.
---
---O veículo nasce pelo native de servidor, não pelo `SpawnVehicle` do bridge: aquele espera um
---cliente virar dono em até 5 s e desiste, e a van de uma missão nasce longe de todo mundo.
---A chave continua indo pelo bridge.
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Integrations = require 'server.integrations'

local Vehicles = {}

---@param inst table
---@param vehicle table
local function giveKeys(inst, vehicle)
    if not vehicle.def.giveKeys or not World.exists(vehicle.record) then return end
    for source in pairs(inst.participants) do
        local attempts = vehicle.keysGiven[source]
        -- true = entregue; número = tentativas. Provider fora do ar não vira chamada por segundo.
        if attempts ~= true and (attempts or 0) < 3 then
            vehicle.keysGiven[source] = Integrations.giveKeys(source, vehicle.record.entity, vehicle.record.plate)
                or (attempts or 0) + 1
        end
    end
    -- O bridge destranca ao dar a chave; quem configurou trancado quer trancado.
    if vehicle.def.locked then SetVehicleDoorsLocked(vehicle.record.entity, 2) end
end

---@param inst table
---@param vehicleId string
---@return table? vehicle
function Vehicles.spawn(inst, vehicleId)
    local def = Utils.findById(inst.def.vehicles, vehicleId)
    if not def then return nil end
    local current = inst.vehicles[vehicleId]
    if current and World.exists(current.record) then return current end

    local vehicleType = World.vehicleType(def.model, inst.leader)
    local plate = (def.plate and def.plate ~= '') and def.plate:upper() or World.randomPlate()
    local record = World.createVehicle(inst, 'vehicle:' .. vehicleId, def.model, vehicleType, def.coords, {
        plate = plate, locked = def.locked,
    })
    if not record then return nil end
    local vehicle = { id = vehicleId, def = def, record = record, destroyed = false, keysGiven = {} }
    inst.vehicles[vehicleId] = vehicle
    giveKeys(inst, vehicle)
    Runtime.markDirty(inst)
    return vehicle
end

---@param inst table
---@param vehicleId string
function Vehicles.despawn(inst, vehicleId)
    local vehicle = inst.vehicles[vehicleId]
    if not vehicle then return end
    World.delete(vehicle.record)
    inst.vehicles[vehicleId] = nil
    Runtime.markDirty(inst)
end

---@param inst table
---@param netId integer
---@return table? vehicle
function Vehicles.byNetId(inst, netId)
    for _, vehicle in pairs(inst.vehicles) do
        if vehicle.record and vehicle.record.netId == netId then return vehicle end
    end
    return nil
end

---@param inst table
---@param propId string
function Vehicles.spawnProp(inst, propId)
    local def = Utils.findById(inst.def.props, propId)
    if not def or (inst.props[propId] and World.exists(inst.props[propId])) then return end
    inst.props[propId] = World.createObject(inst, 'prop:' .. propId, def.model, def.coords, def.frozen ~= false)
end

---@param inst table
---@param propId string
function Vehicles.despawnProp(inst, propId)
    World.delete(inst.props[propId])
    inst.props[propId] = nil
end

MissionComponents.register('vehicles', {
    init = function(inst)
        inst.vehicles = {}
        inst.props = {}
    end,

    start = function(inst)
        for index = 1, #inst.def.vehicles do
            if inst.def.vehicles[index].spawnOnStart then Vehicles.spawn(inst, inst.def.vehicles[index].id) end
        end
        for index = 1, #inst.def.props do
            if inst.def.props[index].spawnOnStart then Vehicles.spawnProp(inst, inst.def.props[index].id) end
        end
    end,

    tick = function(inst)
        for id, vehicle in pairs(inst.vehicles) do
            if not vehicle.destroyed and World.vehicleDestroyed(vehicle.record) then
                vehicle.destroyed = true
                Runtime.emit(inst, 'vehicle_destroyed', { vehicle = id })
                Runtime.markDirty(inst)
                if vehicle.def.required and inst.status == 'ACTIVE' then
                    Runtime.finish(inst, 'FAILED', 'vehicle_destroyed')
                    return
                end
            elseif not vehicle.destroyed then
                -- Participante que entrou depois (ou chave que falhou) recebe a chave aqui.
                giveKeys(inst, vehicle)
            end
        end
    end,

    view = function(inst, view)
        for id, vehicle in pairs(inst.vehicles) do
            if not vehicle.destroyed and vehicle.record then
                view.vehicles[#view.vehicles + 1] = {
                    id = id, netId = vehicle.record.netId, label = vehicle.def.label,
                }
            end
        end
    end,

    debug = function(inst, out)
        out.vehicles = {}
        for id, vehicle in pairs(inst.vehicles) do
            out.vehicles[#out.vehicles + 1] = ('%s net=%s destruído=%s'):format(
                id, vehicle.record and vehicle.record.netId or '-', tostring(vehicle.destroyed))
        end
    end,

    actions = {
        spawn_vehicle = function(inst, action) Vehicles.spawn(inst, action.vehicle) end,
        despawn_vehicle = function(inst, action) Vehicles.despawn(inst, action.vehicle) end,
        spawn_prop = function(inst, action) Vehicles.spawnProp(inst, action.prop) end,
        despawn_prop = function(inst, action) Vehicles.despawnProp(inst, action.prop) end,
    },
})

return Vehicles
