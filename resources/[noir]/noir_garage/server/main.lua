local logger = require '@qbx_core.modules.logger'

assert(lib.checkDependency('qbx_core', '1.19.0', true))
assert(lib.checkDependency('qbx_vehicles', '1.3.1', true))

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
---@field onServer? boolean

Config = require 'config.server'
VEHICLES = exports.qbx_core:GetVehiclesByName()
Storage = require 'server.storage'
---@type table<string, GarageConfig>
Garages = Config.garages

lib.callback.register('noir_garage:server:getGarages', function()
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
    TriggerClientEvent('noir_garage:client:garageRegistered', -1, name, config)
    TriggerEvent('noir_garage:server:garageRegistered', name, config)
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

---@param plate string
---@return boolean
function FindPlateOnServer(plate)
    plate = qbx.string.trim(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if plate == qbx.string.trim(GetVehicleNumberPlateText(vehicles[i])) then
            return true
        end
    end
    return false
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
    local garage = type(garageName) == 'string' and Garages[garageName]
    if garage then return garage end

    logger.log({
        source = source,
        event = 'error',
        message = string.format('Attempted to use a non-existent garage: %s', tostring(garageName)),
        webhook = Config.logging.webhook.error,
        color = 'red'
    })
end

---@param player table
---@param garage GarageConfig
---@return boolean
function CanAccessGarage(player, garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(player.PlayerData.source, garage.groups) then
        return false
    end
    if garage.canAccess ~= nil and not garage.canAccess(player.PlayerData.source) then
        return false
    end
    return true
end

---Guiche da garagem, so se o jogador estiver ao lado dele. Tudo que abre menu, retira ou cobra passa por aqui.
---@param source number
---@param garageName string
---@param accessPointIndex integer
---@return GarageConfig? garage, AccessPoint? accessPoint, table? player
function GetGarageAtAccessPoint(source, garageName, accessPointIndex)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = TryGetGarage(source, garageName)
    if not player or not garage then return end
    if not CanAccessGarage(player, garage) then return end

    local accessPoint = type(accessPointIndex) == 'number' and garage.accessPoints[accessPointIndex]
    if not accessPoint then return end

    local distance = #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz)
    if distance > Config.accessDistance then
        logger.log({
            source = source,
            message = string.format(
                'Player used garage %s access point %d from %.2f meters away',
                garageName,
                accessPointIndex,
                distance
            ),
            webhook = Config.logging.webhook.anticheat,
            event = 'suspicious',
            color = 'white'
        })
        return
    end

    return garage, accessPoint, player
end

---@param playerVehicle PlayerVehicle
---@return VehicleType
function GetVehicleType(playerVehicle)
    local category = VEHICLES[playerVehicle.modelName]?.category
    if category == 'helicopters' or category == 'planes' then
        return VehicleType.AIR
    elseif category == 'boats' then
        return VehicleType.SEA
    else
        return VehicleType.CAR
    end
end

---Cobra em dinheiro e depois no banco.
---@param player table
---@param price integer
---@param reason string
---@return string? account
function ChargePlayer(player, price, reason)
    if price <= 0 then return 'cash' end
    local account = player.PlayerData.money.cash >= price and 'cash' or player.PlayerData.money.bank >= price and 'bank'
    if not account or not player.Functions.RemoveMoney(account, price, reason) then return end
    return account
end

---@param vehicleId integer
---@param message string
function AddVehicleLog(vehicleId, message)
    CreateThread(function()
        local logs = Storage.getLogs(vehicleId)
        logs[#logs + 1] = { date = os.date('%d/%m/%Y %H:%M'), message = message }
        while #logs > Config.logsLimit do
            table.remove(logs, 1)
        end
        Storage.setLogs(vehicleId, logs)
    end)
end

function OverrideFreeDepotPriceForOutVehicle(vehicle)
    if VehicleState.OUT ~= vehicle.state then return end
    if vehicle.depotPrice and vehicle.depotPrice > 0 then return end

    vehicle.depotPrice = Config.calculateImpoundFee(vehicle.id, vehicle.modelName)
end

local categoryIcons = {
    motorcycles = 'motorcycle',
    cycles = 'bicycle',
    boats = 'boat',
    helicopters = 'helicopter',
    planes = 'plane',
}

---@param source number
---@param garageName string
---@param accessPointIndex integer
---@return table? garageInfo, table[]? vehicles
lib.callback.register('noir_garage:server:getGarageVehicles', function(source, garageName, accessPointIndex)
    local garage, _, player = GetGarageAtAccessPoint(source, garageName, accessPointIndex)
    if not garage or not player then return end

    local citizenid = player.PlayerData.citizenid
    local isDepot = garage.type == GarageType.DEPOT
    local keysAvailable = GetResourceState('mri_Qcarkeys') == 'started'

    local garageInfo = {
        label = garage.label,
        isDepot = isDepot,
        rename = Config.rename.enabled,
        renameMaxLength = Config.rename.maxLength,
        transfer = Config.transfer.enabled and not isDepot,
        transferPrice = Config.transfer.price,
        keys = keysAvailable and { copy = Config.keyCopyPrice, lock = Config.lockChangePrice } or nil,
    }

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicles = exports.qbx_vehicles:GetPlayerVehicles(filter)
    if not playerVehicles[1] then return garageInfo, {} end

    local list = {}
    for _, vehicle in pairs(playerVehicles) do
        -- No patio, o carro que ainda esta no mundo tambem aparece (so com as opcoes de chave): e o
        -- unico caminho para quem perdeu a chave com o carro trancado na rua. Retirar continua barrado.
        local onServer = FindPlateOnServer(vehicle.props.plate)
        if (not onServer or isDepot) and VEHICLES[vehicle.modelName] and garage.vehicleType == GetVehicleType(vehicle) then
            vehicle.onServer = onServer
            OverrideFreeDepotPriceForOutVehicle(vehicle)
            list[#list + 1] = vehicle
        end
    end

    local ids = {}
    for i = 1, #list do ids[i] = list[i].id end
    local nicknames = Storage.getNicknames(ids)

    local toSend = {}
    for i = 1, #list do
        local vehicle = list[i]
        local info = VEHICLES[vehicle.modelName]
        local isOwner = vehicle.citizenid == citizenid
        local plate = qbx.string.trim(vehicle.props.plate)

        local canTakeOut, notice = false, nil
        if vehicle.state == VehicleState.GARAGED then
            canTakeOut = true
        elseif vehicle.state == VehicleState.IMPOUNDED then
            notice = locale('menu.veh_impounded')
        elseif isDepot and vehicle.onServer then
            notice = locale('menu.still_on_street')
        elseif isDepot then
            canTakeOut = true
        end

        toSend[#toSend + 1] = {
            id = vehicle.id,
            modelName = vehicle.modelName,
            name = nicknames[vehicle.id] or ('%s %s'):format(info.brand, info.name),
            modelLabel = ('%s %s'):format(info.brand, info.name),
            plate = plate,
            icon = categoryIcons[info.category] or 'car',
            state = vehicle.state,
            depotPrice = isDepot and vehicle.state == VehicleState.OUT and vehicle.depotPrice or 0,
            onServer = vehicle.onServer,
            canTakeOut = canTakeOut,
            notice = notice,
            isOwner = isOwner,
            canManageKeys = isOwner and garageInfo.keys ~= nil and (canTakeOut or vehicle.onServer == true),
            canTransfer = isOwner and garageInfo.transfer and vehicle.state == VehicleState.GARAGED,
            canRename = isOwner and Config.rename.enabled,
            props = vehicle.props,
        }
    end

    table.sort(toSend, function(a, b) return a.name < b.name end)
    return garageInfo, toSend
end)

---@param source number
---@param vehicleId integer
---@param garageName string
---@return boolean
local function isParkable(source, vehicleId, garageName)
    local garageType = GetGarageType(garageName)
    --- DEPOTS are only for retrieving, not storing
    if garageType == GarageType.DEPOT then return false end
    if not vehicleId then return false end
    local player = exports.qbx_core:GetPlayer(source)
    local garage = Garages[garageName]
    if not player or not garage or not CanAccessGarage(player, garage) then
        return false
    end
    ---@type PlayerVehicle
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not playerVehicle or GetVehicleType(playerVehicle) ~= garage.vehicleType then
        return false
    end
    if not garage.shared then
        if playerVehicle.citizenid ~= player.PlayerData.citizenid then
            return false
        end
    end
    return true
end

---O jogador e o carro precisam estar perto de algum ponto de guardar desta garagem.
---@param source number
---@param vehicle number
---@param garage GarageConfig
---@return boolean
local function isNearDropPoint(source, vehicle, garage)
    local pedCoords = GetEntityCoords(GetPlayerPed(source))
    local vehCoords = GetEntityCoords(vehicle)
    for i = 1, #garage.accessPoints do
        local accessPoint = garage.accessPoints[i]
        local point = (accessPoint.dropPoint or accessPoint.spawn or accessPoint.coords).xyz
        if #(pedCoords - point) <= Config.parkDistance and #(vehCoords - point) <= Config.parkDistance then
            return true
        end
    end
    return false
end

---@param netId number
---@return number? vehicle, integer? vehicleId
local function getVehicleFromNetId(netId)
    if type(netId) ~= 'number' then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    return vehicle, vehicleId
end

lib.callback.register('noir_garage:server:isParkable', function(source, garage, netId)
    local vehicle, vehicleId = getVehicleFromNetId(netId)
    if not vehicle or not Garages[garage] then return false end
    return isParkable(source, vehicleId, garage) and isNearDropPoint(source, vehicle, Garages[garage])
end)

---@param source number
---@param netId number
---@param props table ox_lib vehicle props https://github.com/communityox/ox_lib/blob/master/resource/vehicleProperties/client.lua#L3
---@param garageName string
lib.callback.register('noir_garage:server:parkVehicle', function(source, netId, props, garageName)
    local garage = Garages[garageName]
    local vehicle, vehicleId = getVehicleFromNetId(netId)
    if not garage or not vehicle or type(props) ~= 'table' then return end

    if not isParkable(source, vehicleId, garageName) or not isNearDropPoint(source, vehicle, garage) then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end

    -- A placa gravada e a do carro no mundo, nunca a que veio do cliente.
    props.plate = GetVehicleNumberPlateText(vehicle)

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        garage = garageName,
        state = VehicleState.GARAGED,
        props = props
    })

    exports.qbx_core:DeleteVehicle(vehicle)
    AddVehicleLog(vehicleId, locale('logs.stored', garage.label))
    return true
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Storage.ensureSchema()
    if Config.autoRespawn then
        Storage.moveOutVehiclesIntoGarages()
    end
end)
