local logger = require '@qbx_core.modules.logger'

---@param vehicleId integer
---@param modelName string
---@return boolean saved
local function setVehicleStateToOut(vehicleId, vehicle, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    return exports.qbx_vehicles:SaveVehicle(vehicle, {
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
    if not IsInteger(vehicleId) then return end

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
    if not playerVehicle or type(playerVehicle.props) ~= 'table' then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end

    -- O patio lista o apreendido pela policia so para informar: ele sai pela policia, nao por aqui.
    if playerVehicle.state == VehicleState.IMPOUNDED then
        exports.qbx_core:Notify(source, locale('menu.veh_impounded'), 'error')
        return
    end

    -- Carro que ja esta no mundo nao sai de novo, nem do patio nem da garagem (guardado no banco com
    -- uma copia na rua seria carro duplicado).
    if FindPlateOnServer(playerVehicle.props.plate) then
        return exports.qbx_core:Notify(source, locale('menu.still_on_street'), 'error')
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

    local paid, account = 0, nil
    if isDepot and playerVehicle.state == VehicleState.OUT then
        OverrideFreeDepotPriceForOutVehicle(playerVehicle)
        paid = tonumber(playerVehicle.depotPrice) or 0
        if paid ~= paid or paid < 0 or paid > 100000000 then return end
        account = ChargePlayer(player, paid, 'paid-depot')
        if not account then
            exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
            return
        end
    end

    local function refund()
        if paid > 0 and account then player.Functions.AddMoney(account, paid, 'paid-depot-refund') end
    end

    playerVehicle.props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.

    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local spawned, netId, veh = pcall(qbx.spawnVehicle, { spawnSource = spawnCoords, model = model, props = playerVehicle.props, warp = warpPed })
    if not spawned or not netId or not veh or veh == 0 or not DoesEntityExist(veh) then
        if not spawned then lib.print.error(netId) end
        refund()
        return
    end

    -- Estado OUT gravado antes de entregar o carro: se o banco falhar, o carro some e o dinheiro volta.
    Entity(veh).state:set('vehicleid', vehicleId, false)
    local saved, result = pcall(setVehicleStateToOut, vehicleId, veh, playerVehicle.modelName)
    if not saved or not result then
        if not saved then lib.print.error(result) end
        exports.qbx_core:DeleteVehicle(veh)
        refund()
        return
    end

    if Config.doorsLocked then
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            TriggerEvent('qb-vehiclekeys:server:setVehLockState', netId, 2)
        else
            SetVehicleDoorsLocked(veh, 2)
        end
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)

    AddVehicleLog(vehicleId, paid > 0
        and locale('logs.taken_out_depot', garage.label, lib.math.groupdigits(paid))
        or locale('logs.taken_out', garage.label))
    TriggerEvent('noir_garage:server:vehicleSpawned', veh)
    return netId
end

-- Uma retirada por carro de cada vez: dois pedidos juntos nao podem criar o mesmo carro duas vezes.
lib.callback.register('noir_garage:server:spawnVehicle', function(source, vehicleId, garageName, accessPointIndex)
    if not IsInteger(vehicleId) or spawning[vehicleId] then return end
    spawning[vehicleId] = true
    local ok, netId = pcall(spawnVehicle, source, vehicleId, garageName, accessPointIndex)
    spawning[vehicleId] = nil
    if not ok then error(netId) end
    return netId
end)
