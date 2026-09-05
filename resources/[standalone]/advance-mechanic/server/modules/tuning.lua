local Tuning = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'
local Database = require 'server.modules.database'

local performanceProperty = {
    [11] = 'modEngine',
    [12] = 'modBrakes',
    [13] = 'modTransmission',
    [15] = 'modSuspension',
    [16] = 'modArmor',
    [18] = 'modTurbo'
}

local visualProperty = {
    [0] = 'modSpoilers',
    [1] = 'modFrontBumper',
    [2] = 'modRearBumper',
    [3] = 'modSideSkirt',
    [4] = 'modExhaust'
}

local function getNitroVehicle(source, netId, requireMechanic)
    local Player = Framework.GetPlayer(source)
    if not Player or (requireMechanic and not Validation.IsMechanic(Player)) then return nil end
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(source, vehicle, 8.0) then return nil end
    if requireMechanic and not Validation.IsVehicleOnConfiguredLift(vehicle) then return nil end
    local plate = Validation.NormalizePlate(GetVehicleNumberPlateText(vehicle))
    if not Validation.IsVehicleOwned(plate) then return nil end
    return Player, vehicle, plate
end

local function setNitroState(vehicle, data)
    local state = Entity(vehicle).state
    state:set('hasNitro', data ~= nil, true)
    state:set('nitroCapacity', data and tonumber(data.capacity) or nil, true)
    state:set('nitroLevel', data and tonumber(data.level) or nil, true)
end

local function persistPaidModification(Player, vehicle, plate, account, price, reason, props)
    plate = Validation.NormalizePlate(plate)
    if not Database.MergeVehicleProperties(plate, props) then
        Player.Functions.AddMoney(account, price, reason .. '-refund')
        return false
    end

    lib.setVehicleProperties(vehicle, props)
    return true
end

lib.callback.register('mechanic:server:applyPerformanceMod', function(source, netId, modType, level)
    local src = source
    local Player = Framework.GetPlayer(src)
    
    if not Player then return false end
    
    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'tuning_performance', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'tuning_performance', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'tuning_performance', 'rate_limited')
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        Validation.LogDenied(src, 'tuning_performance', 'vehicle_invalid_or_far')
        return false
    end
    if not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(src, 'tuning_performance', 'vehicle_not_on_lift')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        Validation.LogDenied(src, 'tuning_performance', 'vehicle_unowned')
        return false
    end

    local modTypeValue = tonumber(modType)
    local levelValue = tonumber(level)
    if not Validation.IsPositiveInteger(modTypeValue, 0) or not Validation.IsPositiveInteger(levelValue, 0) then
        Validation.LogDenied(src, 'tuning_performance', 'invalid_mod_params')
        return false
    end

    local price = Validation.CalculatePerformanceModPrice(modTypeValue, levelValue)
    if not price then
        Validation.LogDenied(src, 'tuning_performance', 'invalid_price')
        return false
    end

    local property = performanceProperty[modTypeValue]
    if not property then return false end
    if modTypeValue == 11 and Entity(vehicle).state.engineData then
        Validation.LogDenied(src, 'tuning_performance', 'custom_engine_installed')
        return false
    end

    local propertyValue = levelValue
    if modTypeValue == 18 then propertyValue = levelValue == 1 end
    local props = { [property] = propertyValue }
    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if Player.Functions.RemoveMoney(account, price) then
        return persistPaidModification(Player, vehicle, plate, account, price, 'mechanic-performance', props)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            type = 'error'
        })
        return false
    end
end)

lib.callback.register('mechanic:server:applyVisualMod', function(source, netId, modType, modIndex)
    local src = source
    local Player = Framework.GetPlayer(src)
    
    if not Player then return false end
    
    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'tuning_visual', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'tuning_visual', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'tuning_visual', 'rate_limited')
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        Validation.LogDenied(src, 'tuning_visual', 'vehicle_invalid_or_far')
        return false
    end
    if not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(src, 'tuning_visual', 'vehicle_not_on_lift')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        Validation.LogDenied(src, 'tuning_visual', 'vehicle_unowned')
        return false
    end

    local modTypeValue = tonumber(modType)
    local modIndexValue = tonumber(modIndex)
    if not Validation.IsPositiveInteger(modTypeValue, 0) or modIndexValue == nil
        or modIndexValue % 1 ~= 0 then
        Validation.LogDenied(src, 'tuning_visual', 'invalid_mod_params')
        return false
    end

    local price = Validation.CalculateVisualModPrice(modTypeValue, modIndexValue)
    if price == nil then
        Validation.LogDenied(src, 'tuning_visual', 'invalid_price')
        return false
    end

    local property = visualProperty[modTypeValue]
    if not property then return false end

    local props = { [property] = modIndexValue }
    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if Player.Functions.RemoveMoney(account, price) then
        return persistPaidModification(Player, vehicle, plate, account, price, 'mechanic-visual', props)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            type = 'error'
        })
        return false
    end
end)

lib.callback.register('mechanic:server:installNitro', function(source, netId, capacity, _price)
    local src = source
    local Player = Framework.GetPlayer(src)
    
    if not Player then return false end
    
    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'tuning_nitro', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'tuning_nitro', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'tuning_nitro', 'rate_limited')
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        Validation.LogDenied(src, 'tuning_nitro', 'vehicle_invalid_or_far')
        return false
    end
    if not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(src, 'tuning_nitro', 'vehicle_not_on_lift')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = Validation.IsVehicleOwned(plate)
    if not isOwned then
        Validation.LogDenied(src, 'tuning_nitro', 'vehicle_unowned')
        return false
    end

    local capacityValue = tonumber(capacity)
    if capacityValue == nil then
        Validation.LogDenied(src, 'tuning_nitro', 'invalid_capacity')
        return false
    end

    local configuredPrice = Config.Tuning.nitro.install[capacityValue]
    if not configuredPrice then
        Validation.LogDenied(src, 'tuning_nitro', 'capacity_not_configured')
        return false
    end

    if MySQL.scalar.await('SELECT 1 FROM vehicle_nitro WHERE plate = ? LIMIT 1', {
        Validation.NormalizePlate(plate)
    }) then return false end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if Player.Functions.RemoveMoney(account, configuredPrice) then
        local saved = MySQL.query.await([[
            INSERT INTO vehicle_nitro (plate, capacity, level, installed_by)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE capacity = VALUES(capacity), level = VALUES(level),
                installed_by = VALUES(installed_by)
        ]], { Validation.NormalizePlate(plate), capacityValue, capacityValue, Player.PlayerData.citizenid })
        if not saved then
            Player.Functions.AddMoney(account, configuredPrice, 'mechanic-nitro-refund')
            return false
        end
        setNitroState(vehicle, { capacity = capacityValue, level = capacityValue })
        return true, capacityValue
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            type = 'error'
        })
        return false
    end
end)

lib.callback.register('mechanic:server:refillNitro', function(source, netId)
    local Player, vehicle, plate = getNitroVehicle(source, netId, true)
    if not Player then return false end
    if not Validation.CheckRateLimit(source, 'nitro_refill', Config.Security.rateLimits.vehiclePropsMs) then return false end
    local data = MySQL.single.await('SELECT capacity, level FROM vehicle_nitro WHERE plate = ?', { plate })
    if not data then return false end
    local price = Config.Tuning.nitro.refill
    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if not Player.Functions.RemoveMoney(account, price, 'mechanic-nitro-refill') then return false end
    if MySQL.update.await('UPDATE vehicle_nitro SET level = capacity WHERE plate = ?', { plate }) < 1 then
        Player.Functions.AddMoney(account, price, 'mechanic-nitro-refill-refund')
        return false
    end
    local capacity = tonumber(data.capacity) or 0
    setNitroState(vehicle, { capacity = capacity, level = capacity })
    return true, capacity
end)

lib.callback.register('mechanic:server:removeNitro', function(source, netId)
    local Player, vehicle, plate = getNitroVehicle(source, netId, true)
    if not Player then return false end
    if not Validation.CheckRateLimit(source, 'nitro_remove', Config.Security.rateLimits.vehiclePropsMs) then return false end
    if MySQL.update.await('DELETE FROM vehicle_nitro WHERE plate = ?', { plate }) < 1 then return false end
    setNitroState(vehicle, nil)
    return true
end)

lib.callback.register('mechanic:server:loadNitroState', function(source, netId)
    if not Validation.CheckRateLimit(source, 'nitro_load', Config.Security.rateLimits.vehiclePropsMs) then return false end
    local Player, vehicle, plate = getNitroVehicle(source, netId, false)
    if not Player then return false end
    local ped = GetPlayerPed(source)
    if GetPedInVehicleSeat(vehicle, -1) ~= ped and not Validation.IsMechanic(Player) then return false end
    local data = MySQL.single.await('SELECT capacity, level FROM vehicle_nitro WHERE plate = ?', { plate })
    setNitroState(vehicle, data)
    return data and { capacity = tonumber(data.capacity), level = tonumber(data.level) } or false
end)

lib.callback.register('mechanic:server:useNitro', function(source, netId)
    local Player, vehicle, plate = getNitroVehicle(source, netId, false)
    if not Player or GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(source) then return false end
    if not Validation.CheckRateLimit(source, 'nitro_use', Config.Security.rateLimits.nitroUseMs) then return false end
    local changed = MySQL.update.await(
        'UPDATE vehicle_nitro SET level = level - 1 WHERE plate = ? AND level > 0', { plate }
    )
    if changed < 1 then return false end
    local data = MySQL.single.await('SELECT capacity, level FROM vehicle_nitro WHERE plate = ?', { plate })
    if not data then return false end
    setNitroState(vehicle, data)
    return true, tonumber(data.level) or 0
end)

return Tuning
