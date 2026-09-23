local logger = require '@qbx_core.modules.logger'

assert(lib.checkDependency('qbx_core', '1.19.0', true))
assert(lib.checkDependency('qbx_vehicles', '1.3.1', true))
lib.versionCheck('Qbox-project/qbx_garages')

---@class ErrorResult
---@field code string
---@field message string

---@class PlayerVehicle
---@field id number
---@field citizenid? string
---@field modelName string
---@field garage string
---@field state VehicleState
---@field depotPrice integer
---@field props table ox_lib properties table

Config = require 'config.server'
VEHICLES = exports.qbx_core:GetVehiclesByName()
Storage = require 'server.storage'
---@type table<string, GarageConfig>
Garages = Config.garages

lib.callback.register('qbx_garages:server:getGarages', function()
    return Garages
end)

---Returns garages for use server side.
local function getGarages()
    return Garages
end
exports('GetGarages', getGarages)

---@param name string
---@param config GarageConfig
local function registerGarage(name, config)
    Garages[name] = config
    TriggerClientEvent('qbx_garages:client:garageRegistered', -1, name, config)
    TriggerEvent('qbx_garages:server:garageRegistered', name, config)
end

exports('RegisterGarage', registerGarage)

---Sets the vehicle's garage. It is the caller's responsibility to make sure the vehicle is not currently spawned in the world, or else this may have no effect.
---@param vehicleId integer
---@param garageName string
---@return boolean success, ErrorResult?
local function setVehicleGarage(vehicleId, garageName)
    local garage = Garages[garageName]
    if not garage then
        return false, {
            code = 'not_found',
            message = string.format('garage name %s not found. Did you forget to register it?', garageName)
        }
    end

    local state = garage.type == GarageType.DEPOT and VehicleState.IMPOUNDED or VehicleState.GARAGED
    local numRowsAffected = Storage.setVehicleGarage(vehicleId, garageName, state)
    if numRowsAffected == 0 then
        return false, {
            code = 'no_rows_changed',
            message = string.format('no rows were changed for vehicleId=%s', vehicleId)
        }
    end
    return true
end

exports('SetVehicleGarage', setVehicleGarage)

---Sets the vehicle's price for retrieval at a depot. Only affects vehicles that are OUT or IMPOUNDED.
---@param vehicleId integer
---@param depotPrice integer
---@return boolean success, ErrorResult?
local function setVehicleDepotPrice(vehicleId, depotPrice)
    local numRowsAffected = Storage.setVehicleDepotPrice(vehicleId, depotPrice)
    if numRowsAffected == 0 then
        return false, {
            code = 'no_rows_changed',
            message = string.format('no rows were changed for vehicleId=%s', vehicleId)
        }
    end
    return true
end

exports('SetVehicleDepotPrice', setVehicleDepotPrice)

function FindPlateOnServer(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if plate == GetVehicleNumberPlateText(vehicles[i]) then
            return true
        end
    end
end

---@param garage string
---@return GarageType?
function GetGarageType(garage)
    return Garages[garage]?.type
end

---@class PlayerVehiclesFilters
---@field citizenid? string
---@field states? VehicleState|VehicleState[]
---@field garage? string

---@param source number
---@param garageName string
---@return PlayerVehiclesFilters
function GetPlayerVehicleFilter(source, garageName)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = Garages[garageName]
    local filter = {}
    filter.citizenid = not garage.shared and player.PlayerData.citizenid or nil
    filter.states = garage.states or VehicleState.GARAGED
    filter.garage = not garage.skipGarageCheck and garageName or nil
    return filter
end

---@param source number
---@param garageName string
---@return GarageConfig?
function TryGetGarage(source, garageName)
    local garage = Garages[garageName]
    if garage then return garage end

    logger.log({
        source = source,
        event = 'error',
        message = string.format(
            'Attempted to spawn a vehicle from a non-existent garage: %s',
            garageName
        ),
        webhook = Config.logging.webhook.error,
        color = 'red'
    })
end

local function getCanAccessGarage(player, garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(player.PlayerData.source, garage.groups) then
        return false
    end
    if garage.canAccess ~= nil and not garage.canAccess(player.PlayerData.source) then
        return false
    end
    return true
end

---@param playerVehicle PlayerVehicle
---@return VehicleType
local function getVehicleType(playerVehicle)
    if VEHICLES[playerVehicle.modelName].category == 'helicopters' or VEHICLES[playerVehicle.modelName].category == 'planes' then
        return VehicleType.AIR
    elseif VEHICLES[playerVehicle.modelName].category == 'boats' then
        return VehicleType.SEA
    else
        return VehicleType.CAR
    end
end

---@param source number
---@param garageName string
---@return PlayerVehicle[]?
lib.callback.register('qbx_garages:server:getGarageVehicles', function(source, garageName)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = TryGetGarage(source, garageName)
    if not garage then return end
    if not getCanAccessGarage(player, garage) then return end
    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicles = exports.qbx_vehicles:GetPlayerVehicles(filter)
    local toSend = {}
    if not playerVehicles[1] then return end

    local vehicleType = garage.vehicleType
    for _, vehicle in pairs(playerVehicles) do
        -- No patio, o carro que ainda esta no mundo tambem aparece (so com as opcoes de chave): e o
        -- unico caminho para quem perdeu a chave com o carro trancado na rua. Retirar continua barrado.
        local onServer = FindPlateOnServer(vehicle.props.plate)
        if onServer and garage.type == GarageType.DEPOT then vehicle.onServer = true end
        if not onServer or vehicle.onServer then
            if vehicleType == getVehicleType(vehicle) then
                OverrideFreeDepotPriceForOutVehicle(vehicle)
                toSend[#toSend + 1] = vehicle
            end
        end
    end
    return toSend
end)

---@param source number
---@param vehicleId string
---@param garageName string
---@return boolean
local function isParkable(source, vehicleId, garageName)
    local garageType = GetGarageType(garageName)
    --- DEPOTS are only for retrieving, not storing
    if garageType == GarageType.DEPOT then return false end
    if not vehicleId then return false end
    local player = exports.qbx_core:GetPlayer(source)
    local garage = Garages[garageName]
    if not getCanAccessGarage(player, garage) then
        return false
    end
    ---@type PlayerVehicle
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if getVehicleType(playerVehicle) ~= garage.vehicleType then
        return false
    end
    if not garage.shared then
        if playerVehicle.citizenid ~= player.PlayerData.citizenid then
            return false
        end
    end
    return true
end

lib.callback.register('qbx_garages:server:getKeyPrices', function()
    return { copy = Config.keyCopyPrice, lock = Config.lockChangePrice }
end)

---Servico de chave (item do mri_Qcarkeys) no menu do carro: so o dono, no guiche, com o carro guardado
---nesta garagem ou fora (listado no patio -- quem perdeu a chave com o carro na rua). Cobra em
---dinheiro e depois no banco, como a taxa do patio, e devolve se a entrega falhar.
---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@param price integer
---@param reason string
---@param deliver fun(plate: string): boolean
---@param successLocale string
---@return boolean
local function sellKeyService(source, vehicleId, garageName, accessPointIndex, price, reason, deliver, successLocale)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = Garages[garageName]
    if not player or not garage then return false end
    if not getCanAccessGarage(player, garage) then return false end

    local accessPoint = garage.accessPoints[accessPointIndex]
    if not accessPoint or #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz) > 3 then return false end

    if type(vehicleId) ~= 'number' then return false end
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not playerVehicle or playerVehicle.citizenid ~= player.PlayerData.citizenid then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return false
    end
    local inThisGarage = playerVehicle.state == VehicleState.GARAGED and (garage.skipGarageCheck or playerVehicle.garage == garageName)
    local outAtDepot = garage.type == GarageType.DEPOT and playerVehicle.state == VehicleState.OUT
    if not inThisGarage and not outAtDepot then return false end

    if GetResourceState('mri_Qcarkeys') ~= 'started' then
        exports.qbx_core:Notify(source, locale('error.key_copy_unavailable'), 'error')
        return false
    end

    local account = player.PlayerData.money.cash >= price and 'cash' or player.PlayerData.money.bank >= price and 'bank'
    if not account or not player.Functions.RemoveMoney(account, price, reason) then
        exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
        return false
    end

    local plate = playerVehicle.props.plate
    if not deliver(plate) then
        player.Functions.AddMoney(account, price, reason .. '-refund')
        exports.qbx_core:Notify(source, locale('error.key_copy_unavailable'), 'error')
        return false
    end

    exports.qbx_core:Notify(source, locale(successLocale, plate), 'success')
    return true
end

lib.callback.register('qbx_garages:server:buyKeyCopy', function(source, vehicleId, garageName, accessPointIndex)
    return sellKeyService(source, vehicleId, garageName, accessPointIndex, Config.keyCopyPrice, 'garage-key-copy', function(plate)
        return exports.mri_Qcarkeys:GivePermanentKey(source, plate, true)
    end, 'success.key_copy')
end)

lib.callback.register('qbx_garages:server:changeLock', function(source, vehicleId, garageName, accessPointIndex)
    return sellKeyService(source, vehicleId, garageName, accessPointIndex, Config.lockChangePrice, 'garage-lock-change', function(plate)
        return exports.mri_Qcarkeys:ChangeLock(source, plate)
    end, 'success.lock_changed')
end)

lib.callback.register('qbx_garages:server:isParkable', function(source, garage, netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    return isParkable(source, vehicleId, garage)
end)

---@param source number
---@param netId number
---@param props table ox_lib vehicle props https://github.com/communityox/ox_lib/blob/master/resource/vehicleProperties/client.lua#L3
---@param garage string
lib.callback.register('qbx_garages:server:parkVehicle', function(source, netId, props, garage)
    assert(Garages[garage] ~= nil, string.format('Garage %s not found. Did you register this garage?', garage))
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    local owned = isParkable(source, vehicleId, garage) --Check ownership
    if not owned then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        garage = garage,
        state = VehicleState.GARAGED,
        props = props
    })

    exports.qbx_core:DeleteVehicle(vehicle)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(100)
    if Config.autoRespawn then
        Storage.moveOutVehiclesIntoGarages()
    end
end)