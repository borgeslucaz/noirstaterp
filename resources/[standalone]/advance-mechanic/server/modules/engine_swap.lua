local EngineSwap = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

---@param engineId string
---@return table|nil
local function getEngineConfig(engineId)
    if type(engineId) ~= 'string' then return nil end
    return Config.Engines[engineId]
end

---@param vehicle number
---@return table
local function getVehicleDefaults(vehicle)
    local class = GetVehicleClass(vehicle)
    return Config.VehicleClassDefaults[class] or Config.VehicleClassDefaults[0]
end

---@param plate string
---@return table|nil
function EngineSwap.GetData(plate)
    plate = Validation.NormalizePlate(plate)
    local result = MySQL.query.await('SELECT engine_id, wear, temperature, total_km, installed_at, installed_by FROM vehicle_engines WHERE plate = ?', { plate })
    if result and result[1] then
        return result[1]
    end
    return nil
end

---@param plate string
---@param data table
---@return boolean
local function restoreEngineRecord(plate, data)
    return MySQL.query.await([[
        INSERT INTO vehicle_engines (plate, engine_id, wear, temperature, total_km, installed_at, installed_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE engine_id = VALUES(engine_id), wear = VALUES(wear),
            temperature = VALUES(temperature), total_km = VALUES(total_km),
            installed_at = VALUES(installed_at), installed_by = VALUES(installed_by)
    ]], {
        Validation.NormalizePlate(plate), data.engine_id, data.wear, data.temperature,
        data.total_km, data.installed_at, data.installed_by
    }) ~= nil
end

---@param plate string
---@param engineId string
---@param installedBy string
---@return boolean
function EngineSwap.Install(plate, engineId, installedBy)
    plate = Validation.NormalizePlate(plate)
    local existing = EngineSwap.GetData(plate)
    if existing then
        return MySQL.update.await(
            'UPDATE vehicle_engines SET engine_id = ?, wear = 0.00, temperature = 20.00, total_km = 0.00, installed_at = CURRENT_TIMESTAMP, installed_by = ? WHERE plate = ?',
            { engineId, installedBy, plate }
        ) > 0
    else
        return MySQL.insert.await(
            'INSERT INTO vehicle_engines (plate, engine_id, installed_by) VALUES (?, ?, ?)',
            { plate, engineId, installedBy }
        ) > 0
    end
end

---@param plate string
---@return boolean
function EngineSwap.Remove(plate)
    plate = Validation.NormalizePlate(plate)
    return MySQL.update.await('DELETE FROM vehicle_engines WHERE plate = ?', { plate }) > 0
end

---@param plate string
---@param wear number
---@param temperature number
---@param totalKm number
function EngineSwap.SyncData(plate, wear, temperature, totalKm)
    plate = Validation.NormalizePlate(plate)
    MySQL.update('UPDATE vehicle_engines SET wear = ?, temperature = ?, total_km = ? WHERE plate = ?', {
        wear, temperature, totalKm, plate
    })
end

---@param source number
---@param requiredParts table
---@return boolean
local function hasRequiredParts(source, requiredParts)
    for _, partName in ipairs(requiredParts) do
        local count = exports.ox_inventory:Search(source, 'count', partName)
        if not count or count < 1 then
            return false
        end
    end
    return true
end

---@param source number
---@param requiredParts table
local function removeRequiredParts(source, requiredParts)
    local removed = {}
    for _, partName in ipairs(requiredParts) do
        if not exports.ox_inventory:RemoveItem(source, partName, 1) then
            for _, removedPart in ipairs(removed) do
                exports.ox_inventory:AddItem(source, removedPart, 1)
            end
            return false
        end
        removed[#removed + 1] = partName
    end
    return true
end

---@param vehicle number
---@param data table
function EngineSwap.RestoreStateBag(vehicle, data)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    Entity(vehicle).state:set('engineData', {
        engineId = data.engine_id,
        wear = tonumber(data.wear) or 0,
        temperature = tonumber(data.temperature) or 20,
        totalKm = tonumber(data.total_km) or 0
    }, true)
end

lib.callback.register('mechanic:server:getEngineData', function(source, plate)
    if not Config.EngineSwap.enabled then return nil end
    local Player = Framework.GetPlayer(source)
    if not Player then return nil end
    if not Validation.IsMechanic(Player) then return nil end
    if not Validation.CheckRateLimit(source, 'engine_data', Config.Security.rateLimits.engineSwapMs) then return nil end
    if type(plate) ~= 'string' or #plate < 1 or #plate > 15 then return nil end
    return EngineSwap.GetData(plate)
end)

lib.callback.register('mechanic:server:getEngineCompatibility', function(source, netId, engineId)
    if not Config.EngineSwap.enabled then return nil end
    local Player = Framework.GetPlayer(source)
    if not Player then return nil end
    if not Validation.IsMechanic(Player) then return nil end

    local engineConfig = getEngineConfig(engineId)
    if not engineConfig then return nil end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(source, vehicle, Config.EngineSwap.maxDistance) then return nil end

    local defaults = getVehicleDefaults(vehicle)
    local defaultEngine = Config.Engines[defaults.engine]
    if not defaultEngine then return nil end

    local drivetrainOk = false
    for _, dt in ipairs(engineConfig.drivetrainCompat) do
        if dt == defaults.drivetrain then
            drivetrainOk = true
            break
        end
    end

    if Config.EngineSwap.requireLift and not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(source, 'engine_compatibility', 'vehicle_not_on_lift')
        return false
    end

    local hasParts = hasRequiredParts(source, engineConfig.requiredParts)

    return {
        drivetrainCompatible = drivetrainOk,
        hasParts = hasParts,
        missingParts = not hasParts and engineConfig.requiredParts or nil,
        defaultEngine = defaults.engine,
        defaultDrivetrain = defaults.drivetrain,
        defaultHp = defaultEngine.hp,
        defaultTorque = defaultEngine.torque
    }
end)

lib.callback.register('mechanic:server:installEngine', function(source, netId, engineId)
    local src = source
    if not Config.EngineSwap.enabled then return false end
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'engine_swap', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'engine_swap', Config.Security.rateLimits.engineSwapMs) then
        Validation.LogDenied(src, 'engine_swap', 'rate_limited')
        return false
    end

    local engineConfig = getEngineConfig(engineId)
    if not engineConfig then
        Validation.LogDenied(src, 'engine_swap', 'invalid_engine_id')
        return false
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.EngineSwap.maxDistance) then
        Validation.LogDenied(src, 'engine_swap', 'vehicle_invalid_or_far')
        return false
    end

    if Config.EngineSwap.requireLift and not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(src, 'engine_swap', 'vehicle_not_on_lift')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'engine_swap', 'vehicle_unowned')
        return false
    end

    local defaults = getVehicleDefaults(vehicle)
    local drivetrainOk = false
    for _, dt in ipairs(engineConfig.drivetrainCompat) do
        if dt == defaults.drivetrain then
            drivetrainOk = true
            break
        end
    end

    if not drivetrainOk then
        Validation.LogDenied(src, 'engine_swap', 'drivetrain_incompatible')
        return false
    end

    if not hasRequiredParts(src, engineConfig.requiredParts) then
        Validation.LogDenied(src, 'engine_swap', 'missing_parts')
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if not Player.Functions.RemoveMoney(account, engineConfig.price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('engine_insufficient_funds'),
            type = 'error'
        })
        return false
    end

    local existingEngine = EngineSwap.GetData(plate)
    if not removeRequiredParts(src, engineConfig.requiredParts) then
        Player.Functions.AddMoney(account, engineConfig.price, 'mechanic-engine-refund')
        Validation.LogDenied(src, 'engine_swap', 'parts_changed_during_install')
        return false
    end


    if existingEngine and getEngineConfig(existingEngine.engine_id)
        and not exports.ox_inventory:CanCarryItem(src, existingEngine.engine_id, 1, { wear = existingEngine.wear }) then
        for _, partName in ipairs(engineConfig.requiredParts) do
            exports.ox_inventory:AddItem(src, partName, 1)
        end
        Player.Functions.AddMoney(account, engineConfig.price, 'mechanic-engine-refund')
        return false
    end

    local citizenid = Player.PlayerData.citizenid
    if not EngineSwap.Install(plate, engineId, citizenid) then
        for _, partName in ipairs(engineConfig.requiredParts) do
            exports.ox_inventory:AddItem(src, partName, 1)
        end
        Player.Functions.AddMoney(account, engineConfig.price, 'mechanic-engine-refund')
        return false
    end

    if existingEngine and getEngineConfig(existingEngine.engine_id) then
        if not exports.ox_inventory:AddItem(src, existingEngine.engine_id, 1, { wear = existingEngine.wear }) then
            restoreEngineRecord(plate, existingEngine)
            for _, partName in ipairs(engineConfig.requiredParts) do
                exports.ox_inventory:AddItem(src, partName, 1)
            end
            Player.Functions.AddMoney(account, engineConfig.price, 'mechanic-engine-refund')
            return false
        end
    end

    Entity(vehicle).state:set('engineData', {
        engineId = engineId,
        wear = 0.00,
        temperature = 20.0,
        totalKm = 0.00
    }, true)

    return true
end)

lib.callback.register('mechanic:server:removeEngine', function(source, netId)
    local src = source
    if not Config.EngineSwap.enabled then return false end
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'engine_remove', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'engine_remove', Config.Security.rateLimits.engineSwapMs) then
        Validation.LogDenied(src, 'engine_remove', 'rate_limited')
        return false
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.EngineSwap.maxDistance) then
        Validation.LogDenied(src, 'engine_remove', 'vehicle_invalid_or_far')
        return false
    end

    if Config.EngineSwap.requireLift and not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(src, 'engine_remove', 'vehicle_not_on_lift')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'engine_remove', 'vehicle_unowned')
        return false
    end
    local existingEngine = EngineSwap.GetData(plate)
    if not existingEngine then
        return false
    end


    local metadata = { wear = existingEngine.wear }
    if not exports.ox_inventory:CanCarryItem(src, existingEngine.engine_id, 1, metadata) then
        return false
    end

    if not EngineSwap.Remove(plate) then return false end

    local oldConfig = getEngineConfig(existingEngine.engine_id)
    if oldConfig then
        if not exports.ox_inventory:AddItem(src, existingEngine.engine_id, 1, metadata) then
            restoreEngineRecord(plate, existingEngine)
            return false
        end
    end

    Entity(vehicle).state:set('engineData', nil, true)

    return true
end)

RegisterNetEvent('mechanic:server:syncEngineData', function(plate, wear, temperature, totalKm)
    local src = source
    if not Config.EngineSwap.enabled then return end
    local Player = Framework.GetPlayer(src)
    if not Player then return end

    if not Validation.CheckRateLimit(src, 'engine_sync', Config.Security.rateLimits.engineSyncMs) then return end

    if not Validation.IsValidPlate(plate) then return end

    plate = Validation.NormalizePlate(plate)
    local vehicle = Validation.GetVehicleByPlate(plate)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 15.0) then return end
    local ped = GetPlayerPed(src)
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    if not EngineSwap.GetData(plate) then return end

    local clampedWear = Validation.ClampNumber(tonumber(wear), 0, 100, 0)
    local clampedTemp = Validation.ClampNumber(tonumber(temperature), 20, 120, 20)
    local clampedKm = Validation.ClampNumber(tonumber(totalKm), 0, 999999, 0)

    local current = EngineSwap.GetData(plate)
    if not current then return end
    if clampedWear + 0.001 < (tonumber(current.wear) or 0)
        or clampedKm + 0.001 < (tonumber(current.total_km) or 0) then
        Validation.LogDenied(src, 'engine_sync', 'engine_counters_decreased')
        return
    end

    EngineSwap.SyncData(plate, clampedWear, clampedTemp, clampedKm)
end)

lib.callback.register('mechanic:server:loadEngineStateBag', function(source, netId)
    if not Config.EngineSwap.enabled then return false end
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    if not Validation.CheckRateLimit(source, 'engine_load', Config.Security.rateLimits.engineSwapMs) then return false end
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(source, vehicle, 15.0) then return false end
    local ped = GetPlayerPed(source)
    if GetPedInVehicleSeat(vehicle, -1) ~= ped
        and not Validation.IsMechanic(Player) and not Validation.IsAdmin(source) then
        return false
    end
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate or plate == '' then return false end
    local data = EngineSwap.GetData(plate)
    if not data then return false end
    EngineSwap.RestoreStateBag(vehicle, data)
    return true
end)

return EngineSwap
