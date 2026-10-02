---Direção de NPC: ir até um ponto, perseguir, vagar. O mesmo contrato serve carro, moto,
---barco e aeronave; o tipo do modelo escolhe o native.
local Vehicles = {}

local STYLES = {
    normal = 786603,
    rushed = 1074528293,
    aggressive = 1074528293,
}

---@param model integer
---@return 'boat'|'heli'|'plane'|'land'
local function kindOf(model)
    if IsThisModelABoat(model) or IsThisModelAJetski(model) then return 'boat' end
    if IsThisModelAHeli(model) then return 'heli' end
    if IsThisModelAPlane(model) then return 'plane' end
    return 'land'
end
Vehicles.kindOf = kindOf

---@param netId integer?
---@return integer vehicle
local function vehicleOf(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return 0 end
    return NetToVeh(netId)
end

---@param ped integer
---@param style string?
local function driverSetup(ped, style)
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, style == 'aggressive' and 1.0 or 0.6)
    SetBlockingOfNonTemporaryEvents(ped, true)
end

---@param ped integer
---@param task table { veh, x, y, z, speed, style, stop }
function Vehicles.driveTo(ped, task)
    local vehicle = vehicleOf(task.veh)
    if vehicle == 0 then return end
    driverSetup(ped, task.style)
    local speed = (task.speed or 25) + 0.0
    local stop = (task.stop or 10) + 0.0
    local kind = kindOf(GetEntityModel(vehicle))
    if kind == 'boat' then
        TaskBoatMission(ped, vehicle, 0, 0, task.x, task.y, task.z, 4, speed, 786469, stop, 7)
    elseif kind == 'heli' then
        TaskHeliMission(ped, vehicle, 0, 0, task.x, task.y, task.z, 4, speed, stop, -1.0, -1, -1, -1, 0)
    elseif kind == 'plane' then
        TaskPlaneMission(ped, vehicle, 0, 0, task.x, task.y, task.z, 4, speed, 0.0, -1.0, 0, 50.0, false)
    else
        TaskVehicleDriveToCoordLongrange(ped, vehicle, task.x, task.y, task.z, speed, STYLES[task.style] or STYLES.rushed, stop)
    end
end

---@param ped integer
---@param task table { veh, target, speed, style, ram }
---@param targetPed integer
function Vehicles.chase(ped, task, targetPed)
    local vehicle = vehicleOf(task.veh)
    if vehicle == 0 or targetPed == 0 then return end
    driverSetup(ped, 'aggressive')
    SetBlockingOfNonTemporaryEvents(ped, false)
    local kind = kindOf(GetEntityModel(vehicle))
    if kind == 'heli' then
        TaskHeliChase(ped, targetPed, 0.0, 0.0, 40.0)
        return
    end
    TaskVehicleChase(ped, targetPed)
    SetTaskVehicleChaseIdealPursuitDistance(ped, task.ram and 0.0 or 15.0)
    SetDriveTaskMaxCruiseSpeed(ped, (task.speed or 45) + 0.0)
end

---@param ped integer
---@param task table { veh }
function Vehicles.wander(ped, task)
    local vehicle = vehicleOf(task.veh)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        TaskVehicleDriveWander(ped, vehicle, 22.0, STYLES.normal)
    elseif not IsPedInAnyVehicle(ped, false) then
        TaskWanderStandard(ped, 10.0, 10)
    end
end

---Motorista parado (velocidade quase zero) por 10 s longe do destino: reaplica.
---@param ped integer
---@param task table
---@param state table
---@return boolean
function Vehicles.isStuck(ped, task, state)
    local vehicle = vehicleOf(task.veh)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return false end
    if GetEntitySpeed(vehicle) > 1.0 then
        state.stoppedSince = nil
        return false
    end
    if task.x then
        local distance = #(GetEntityCoords(vehicle) - vector3(task.x, task.y, task.z))
        if distance <= (task.stop or 10) + 10.0 then return false end
    end
    local now = GetGameTimer()
    state.stoppedSince = state.stoppedSince or now
    if now - state.stoppedSince < 10000 then return false end
    state.stoppedSince = nil
    return true
end

---Tipo de veículo para o `CreateVehicleServerSetter`, que o servidor não sabe pelo modelo.
---@param modelName string
---@return string?
function Vehicles.serverType(modelName)
    local model = joaat(modelName)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then return nil end
    if IsThisModelABoat(model) or IsThisModelAJetski(model) then return 'boat' end
    if IsThisModelAHeli(model) then return 'heli' end
    if IsThisModelAPlane(model) then return 'plane' end
    if IsThisModelABike(model) or IsThisModelABicycle(model) then return 'bike' end
    if IsThisModelATrain(model) then return 'train' end
    local name = modelName:lower()
    if name:find('submersible', 1, true) or name == 'kosatka' then return 'submarine' end
    if GetVehicleClassFromName(model) == 11 and name:find('trailer', 1, true) then return 'trailer' end
    return 'automobile'
end

RegisterNetEvent('noir_missions:client:vehicleType', function(requestId, modelName)
    if source ~= 65535 then return end
    if type(modelName) ~= 'string' then return end
    local model = joaat(modelName)
    local seats = IsModelInCdimage(model) and GetVehicleModelNumberOfSeats(model) or nil
    TriggerServerEvent('noir_missions:server:vehicleType', requestId, Vehicles.serverType(modelName), seats)
end)

return Vehicles
