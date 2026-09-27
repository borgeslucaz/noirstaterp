local logger = require '@qbx_core.modules.logger'

---@param vehicleId integer
---@param modelName string
local function setVehicleStateToOut(vehicleId, vehicle, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    exports.qbx_vehicles:SaveVehicle(vehicle, {
        state = VehicleState.OUT,
        depotPrice = depotPrice
    })
end

local spawning = {} ---@type table<integer, true>

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
local function spawnVehicle(source, vehicleId, garageName, accessPointIndex)
    local garage, accessPoint, player = GetGarageAtAccessPoint(source, garageName, accessPointIndex)
    if not garage or not accessPoint or not player then return end
    if type(vehicleId) ~= 'number' then return end

    local isDepot = garage.type == GarageType.DEPOT

    local spawnCoords = accessPoint.spawn or accessPoint.coords
    if Config.distanceCheck then
        local nearbyVehicle = lib.getClosestVehicle(spawnCoords.xyz, Config.distanceCheck, false)
        if nearbyVehicle then
            exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
            return
        end
    end

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end

    -- O patio lista o apreendido pela policia so para informar: ele sai pela policia, nao por aqui.
    if playerVehicle.state == VehicleState.IMPOUNDED then
        exports.qbx_core:Notify(source, locale('menu.veh_impounded'), 'error')
        return
    end

    if isDepot and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error')
    end

    -- `props` is the persisted modifications JSON and can contain a stale or
    -- corrupt `model` hash. The database vehicle name is the authoritative
    -- model for a garage record; using props.model can make CreateVehicle try
    -- to create a ped/object and repeatedly emit a native error.
    -- IsModelInCdimage/IsModelAVehicle so existem no cliente; no servidor a referencia e a lista
    -- de veiculos do qbx_core (VEHICLES, carregada em server/main.lua).
    local model = playerVehicle.modelName
    if not model or not VEHICLES[model] then
        logger.log({
            source = source,
            message = string.format('Blocked garage spawn for vehicle id=%s: invalid model=%s', vehicleId, tostring(model)),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })
        exports.qbx_core:Notify(source, locale('error.invalid_model'), 'error')
        return
    end

    local paid = 0
    if isDepot and playerVehicle.state == VehicleState.OUT then
        OverrideFreeDepotPriceForOutVehicle(playerVehicle)
        paid = playerVehicle.depotPrice or 0
        if not ChargePlayer(player, paid, 'paid-depot') then
            exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
            return
        end
    end

    playerVehicle.props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.

    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local netId, veh = qbx.spawnVehicle({ spawnSource = spawnCoords, model = model, props = playerVehicle.props, warp = warpPed })

    if Config.doorsLocked then
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            TriggerEvent('qb-vehiclekeys:server:setVehLockState', netId, 2)
        else
            SetVehicleDoorsLocked(veh, 2)
        end
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)

    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)
    AddVehicleLog(vehicleId, paid > 0
        and locale('logs.taken_out_depot', garage.label, lib.math.groupdigits(paid))
        or locale('logs.taken_out', garage.label))
    TriggerEvent('noir_garage:server:vehicleSpawned', veh)
    return netId
end

-- Uma retirada por carro de cada vez: dois pedidos juntos nao podem criar o mesmo carro duas vezes.
lib.callback.register('noir_garage:server:spawnVehicle', function(source, vehicleId, garageName, accessPointIndex)
    if type(vehicleId) ~= 'number' or spawning[vehicleId] then return end
    spawning[vehicleId] = true
    local ok, netId = pcall(spawnVehicle, source, vehicleId, garageName, accessPointIndex)
    spawning[vehicleId] = nil
    if not ok then error(netId) end
    return netId
end)
