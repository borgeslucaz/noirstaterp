local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

-- Load modules
local Database = require 'server.modules.database'
local Shops = require 'server.modules.shops'
local Vehicles = require 'server.modules.vehicles'
local Missions = require 'server.modules.missions'
local Billing = require 'server.modules.billing'
local Tuning = require 'server.modules.tuning'
local PaintBooth = require 'server.modules.paint_booth'
local Wrapping = require 'server.modules.wrapping'
local SuspensionSetup = require 'server.modules.suspension_setup'
local EngineSwap = require 'server.modules.engine_swap'

AddEventHandler('playerDropped', function()
    Validation.ClearRateLimit(source)
end)

-- Initialize database tables on resource start
CreateThread(function()
    -- Create mechanic_shops table if not exists
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mechanic_shops` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(50) NOT NULL,
            `owner` varchar(50) DEFAULT NULL,
            `price` int(11) NOT NULL DEFAULT 100000,
            `zones` longtext NOT NULL,
            `lifts` longtext NOT NULL,
            `vehicleSpawns` longtext NOT NULL,
            `employees` longtext DEFAULT '[]',
            `storage` longtext DEFAULT '{}',
            `payrollEnabled` tinyint(1) DEFAULT 0,
            `payment_frequency` varchar(20) DEFAULT 'weekly',
            `payment_day` varchar(20) DEFAULT 'friday',
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Ensure shop columns exist for legacy installs
    MySQL.query([[
        ALTER TABLE `mechanic_shops`
        ADD COLUMN IF NOT EXISTS `employees` longtext DEFAULT '[]',
        ADD COLUMN IF NOT EXISTS `storage` longtext DEFAULT '{}',
        ADD COLUMN IF NOT EXISTS `payrollEnabled` tinyint(1) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS `payment_frequency` varchar(20) DEFAULT 'weekly',
        ADD COLUMN IF NOT EXISTS `payment_day` varchar(20) DEFAULT 'friday',
        ADD COLUMN IF NOT EXISTS `lifts` longtext DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `vehicleSpawns` longtext DEFAULT NULL;
    ]])
    
    -- Add inspection_data and props columns to player_vehicles if not exists
    MySQL.query([[
        ALTER TABLE `player_vehicles` 
        ADD COLUMN IF NOT EXISTS `inspection_data` longtext DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `props` longtext DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `fluid_data` longtext DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `damage_data` longtext DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `maintenance_history` longtext DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `last_diagnostic` longtext DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS `mileage` int(11) DEFAULT 0;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `vehicle_nitro` (
            `plate` VARCHAR(15) NOT NULL,
            `capacity` INT(3) NOT NULL,
            `level` INT(3) NOT NULL,
            `installed_by` VARCHAR(50) DEFAULT NULL,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    print('[Advanced Mechanic] Database tables initialized')
end)

-- Admin commands
lib.addCommand('advsetmechanic', {
    help = 'Set a player as mechanic',
    params = {
        {name = 'target', type = 'playerId', help = 'Target player ID'},
        {name = 'grade', type = 'number', help = 'Job grade (0-4)', optional = true}
    },
    restricted = 'group.admin'
}, function(source, args, raw)
local targetPlayer = Framework.GetPlayer(args.target)
    if targetPlayer then
        targetPlayer.Functions.SetJob(Config.JobName, args.grade or 0)
        TriggerClientEvent('ox_lib:notify', args.target, {
            title = 'Job Updated',
            description = 'You are now a mechanic',
            type = 'success'
        })
        
        if source > 0 then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Success',
                description = 'Player set as mechanic',
                type = 'success'
            })
        end
    end
end)

-- Mechanic menu command
lib.addCommand('mechanicmenu', {
    help = 'Open mechanic menu',
    restricted = false
}, function(source, args, raw)
    local Player = Framework.GetPlayer(source)
    if Player and Player.PlayerData.job.name == Config.JobName then
        TriggerClientEvent('mechanic:client:openMenu', source)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You are not a mechanic',
            type = 'error'
        })
    end
end)

lib.callback.register('mechanic:server:canCreateShop', function(source)
    return not Config.ShopCreation.requiresAdmin or Validation.IsAdmin(source)
end)

-- Mechanic job check
Framework.CreateCallback('mechanic:server:isPlayerMechanic', function(source, cb)
    local Player = Framework.GetPlayer(source)
    if Player then
        cb(Player.PlayerData.job.name == Config.JobName)
    else
        cb(false)
    end
end)

-- Item consumption must be authoritative on the server. The upstream resource
-- attempted to call the ox_inventory server export directly from the client.
lib.callback.register('mechanic:server:consumeWorkItem', function(source, netId, itemName, itemType)
    local Player = Framework.GetPlayer(source)
    if not Player or not Validation.IsMechanic(Player) then return false end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(source, vehicle, 8.0) then return false end

    local allowedItem
    if itemType == 'maintenance' then
        for _, item in pairs(Config.MaintenanceItems) do
            if item.item == itemName then
                allowedItem = true
                break
            end
        end
    elseif itemType == 'part' then
        for _, item in pairs(Config.VehicleParts) do
            if item.item == itemName then
                allowedItem = true
                break
            end
        end
    end

    if not allowedItem then return false end
    return exports.ox_inventory:RemoveItem(source, itemName, 1) == true
end)

lib.callback.register('mechanic:server:performMaintenance', function(source, netId, maintenanceKey)
    local Player = Framework.GetPlayer(source)
    if not Player or not Validation.IsMechanic(Player) then return false end
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(source, vehicle, 8.0) then return false end

    local plate = Validation.NormalizePlate(GetVehicleNumberPlateText(vehicle))
    if not Validation.IsVehicleOwned(plate) then return false end

    local keys = maintenanceKey == 'all' and { 'oil', 'brakefluid', 'coolant' } or { maintenanceKey }
    local fields = { oil = 'oilLevel', brakefluid = 'brakeFluidLevel', coolant = 'coolantLevel', battery = 'batteryLevel' }
    local removed = {}

    for _, key in ipairs(keys) do
        local item = Config.MaintenanceItems[key]
        if not item or not fields[key] or (exports.ox_inventory:Search(source, 'count', item.item) or 0) < 1 then
            return false
        end
    end

    for _, key in ipairs(keys) do
        local item = Config.MaintenanceItems[key]
        if not exports.ox_inventory:RemoveItem(source, item.item, 1) then
            for _, removedItem in ipairs(removed) do exports.ox_inventory:AddItem(source, removedItem, 1) end
            return false
        end
        removed[#removed + 1] = item.item
    end

    local fluidData = Vehicles.GetFluidData(plate)
    for _, key in ipairs(keys) do
        fluidData[fields[key]] = Config.MaintenanceItems[key].restores or 100
    end
    if not Vehicles.UpdateFluidData(plate, fluidData) then
        for _, removedItem in ipairs(removed) do exports.ox_inventory:AddItem(source, removedItem, 1) end
        return false
    end

    for field, value in pairs(fluidData) do
        if type(value) == 'number' and field:find('Level$') then
            Entity(vehicle).state:set(field, value, true)
        end
    end
    return true, fluidData
end)

-- Vehicle spawn handler
RegisterNetEvent('mechanic:server:deleteVehicle', function(netId)
    local src = source
    local Player = Framework.GetPlayer(src)
    if not Player then return end

    if not Validation.IsMechanic(Player) and not Validation.IsAdmin(src) then
        return
    end

    if not Validation.CheckRateLimit(src, 'vehicle_delete', Config.Security.rateLimits.vehicleDeleteMs) then
        return
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle then return end
    if not Validation.IsPlayerNearEntity(src, vehicle, 10.0) then return end

    if not Shops.IsServiceVehicle(netId) and not Validation.IsAdmin(src) then return end

    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwner = Validation.IsVehicleOwnedBy(plate, Player.PlayerData.citizenid)
    local isDriver = GetPedInVehicleSeat(vehicle, -1) == GetPlayerPed(src)

    if not isOwner and not isDriver and not Validation.IsAdmin(src) then
        return
    end

    Shops.RemoveServiceVehicle(netId)
    DeleteEntity(vehicle)
end)

-- QBCore job definitions are expected to be managed by qb-core/shared/jobs.lua

-- Export functions
exports('getMechanicShops', function()
    return Shops.GetAll()
end)

exports('isVehicleOwned', function(plate)
    return Vehicles.IsOwned(plate)
end)

exports('getVehicleInspectionData', function(plate)
    return Vehicles.GetInspectionData(plate)
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Clean up any spawned vehicles
        print('[Advanced Mechanic] Resource stopped, cleaning up...')
    end
end)

-- Additional callbacks for new features
lib.callback.register('mechanic:server:getVehicleData', function(source, plate)
    local Player = Framework.GetPlayer(source)
    if not Player or not Validation.IsMechanic(Player) then return nil end
    if not Validation.IsValidPlate(plate) then
        Validation.LogDenied(source, 'vehicle_data', 'invalid_plate')
        return nil
    end

    if not Validation.CheckRateLimit(source, 'vehicle_data', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(source, 'vehicle_data', 'rate_limited')
        return nil
    end

    local vehicle = Validation.GetVehicleByPlate(plate)
    if not vehicle or not Validation.IsPlayerNearEntity(source, vehicle, 10.0) then
        Validation.LogDenied(source, 'vehicle_data', 'vehicle_invalid_or_far')
        return nil
    end

    plate = Validation.NormalizePlate(plate)
    local result = MySQL.query.await('SELECT plate, mileage, maintenance_history, inspection_data, fluid_data, last_diagnostic, citizenid FROM player_vehicles WHERE plate = ?', {plate})
    
    if result and result[1] then
        local vehicleData = result[1]
        local function safeDecode(str, fallback)
            local ok, result = pcall(json.decode, str or fallback)
            return ok and result or json.decode(fallback)
        end
        vehicleData.maintenanceHistory = safeDecode(vehicleData.maintenance_history, '[]')
        vehicleData.inspectionData = safeDecode(vehicleData.inspection_data, '{}')
        vehicleData.fluidData = safeDecode(vehicleData.fluid_data, '{}')
        vehicleData.lastDiagnostic = safeDecode(vehicleData.last_diagnostic, '{}')
        vehicleData.owner = vehicleData.citizenid
        return vehicleData
    end
    
    return nil
end)

lib.callback.register('mechanic:server:repairVehicle', function(source, netId, _cost)
    local src = source
    local Player = Framework.GetPlayer(src)
    
    if not Player then return false end
    
    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'repair_vehicle', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'repair_vehicle', Config.Security.rateLimits.repairComponentMs) then
        Validation.LogDenied(src, 'repair_vehicle', 'rate_limited')
        return false
    end
    
    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        Validation.LogDenied(src, 'repair_vehicle', 'vehicle_invalid_or_far')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    plate = Validation.NormalizePlate(plate)
    local isOwned = Validation.IsVehicleOwned(plate)
    local isMissionVehicle = Missions.IsMissionVehicle(src, netId)
    if not isOwned and not isMissionVehicle then
        Validation.LogDenied(src, 'repair_vehicle', 'vehicle_unowned')
        return false
    end

    if isMissionVehicle then return true end

    local repairCost = tonumber(Config.Maintenance.repairAllCost)
    if not Validation.IsNumberInRange(repairCost, 1, Config.Maintenance.maxComponentCost) then
        Validation.LogDenied(src, 'repair_vehicle', 'invalid_cost')
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if not Player.Functions.RemoveMoney(account, repairCost) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            type = 'error'
        })
        return false
    end

    local inspectionData = {}
    for name in pairs(Config.Inspection.checkPoints) do
        inspectionData[name] = { health = 100, lastChecked = os.time(), lastRepaired = os.time() }
    end
    if not Vehicles.UpdateInspectionData(plate, inspectionData) then
        Player.Functions.AddMoney(account, repairCost, 'mechanic-repair-refund')
        return false
    end
    return true
end)

lib.callback.register('mechanic:server:generateDiagnosticReport', function(source, plate)
    local src = source
    local Player = Framework.GetPlayer(src)
    
    if not Player or not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'diagnostic_report', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'diagnostic_report', Config.Security.rateLimits.diagnosticReportMs) then
        Validation.LogDenied(src, 'diagnostic_report', 'rate_limited')
        return false
    end

    if not Validation.IsValidPlate(plate) then
        Validation.LogDenied(src, 'diagnostic_report', 'invalid_plate')
        return false
    end

    local vehicle = Validation.GetVehicleByPlate(plate)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, 8.0) then
        Validation.LogDenied(src, 'diagnostic_report', 'vehicle_invalid_or_far')
        return false
    end
    
    plate = Validation.NormalizePlate(plate)
    -- Save diagnostic report to database
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local inspectionData = Vehicles.GetInspectionData(plate)
    local diagnosticData = {}
    for name in pairs(Config.Inspection.checkPoints) do
        local checkpoint = type(inspectionData[name]) == 'table' and inspectionData[name] or {}
        diagnosticData[name] = {
            health = Validation.ClampNumber(tonumber(checkpoint.health), 0, 100, 100),
            lastChecked = tonumber(checkpoint.lastChecked) or os.time()
        }
    end

    local charinfo = Player.PlayerData.charinfo or {}
    local report = {
        date = timestamp,
        mechanic = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):match('^%s*(.-)%s*$'),
        data = diagnosticData
    }
    
    return MySQL.update.await('UPDATE player_vehicles SET last_diagnostic = ? WHERE plate = ?', {
        json.encode(report),
        plate
    }) > 0
end)

print('[Advanced Mechanic] Server initialized successfully')
