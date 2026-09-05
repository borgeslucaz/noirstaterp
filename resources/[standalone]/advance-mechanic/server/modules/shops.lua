local Shops = {}
local Database = require 'server.modules.database'
local Business = require 'server.modules.business'
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'
local shopCache = {}
local serviceVehicles = {}

function Shops.IsServiceVehicle(netId)
    return serviceVehicles[tonumber(netId)] == true
end

function Shops.RemoveServiceVehicle(netId)
    serviceVehicles[tonumber(netId)] = nil
end

local function buildPublicShopData(shop)
    local publicShop = {}
    for key, value in pairs(shop) do
        if key ~= 'storage' and key ~= 'employees' then
            publicShop[key] = value
        end
    end
    return publicShop
end

local function getPublicShops()
    local public = {}
    for _, shop in ipairs(shopCache) do
        table.insert(public, buildPublicShopData(shop))
    end
    return public
end

local function canManageShop(source, shopId, permission)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end

    local citizenid = Player.PlayerData.citizenid
    local shop = Shops.GetById(shopId)
    if not shop then return false end

    if Validation.IsAdmin(source) then return true end

    if shop.owner and shop.owner == citizenid then
        return true
    end

    if Business.isBusinessBoss(citizenid, shopId) then
        return true
    end

    if not Business.isEmployee(citizenid, shopId) then return false end

    if permission and Business.hasBusinessPermission(citizenid, shopId, permission) then
        return true
    end

    local rank = Business.getEmployeeRank(citizenid, shopId)
    if rank >= Config.BossGrade then
        return true
    end

    local permissions = Config.Employees.permissions[rank]
    if permissions and permission and permissions[permission] then
        return true
    end

    return false
end

local function isAllowedServiceModel(model)
    if type(model) ~= 'string' or #model < 1 or #model > 50 then return false end
    local lower = model:lower()
    for _, data in pairs(Config.Towing.vehicles) do
        if type(data.model) == 'string' and data.model:lower() == lower then
            return true
        end
        if type(data.model) == 'number' and data.model == joaat(lower) then
            return true
        end
        if data.models then
            for _, alias in ipairs(data.models) do
                if type(alias) == 'string' and alias:lower() == lower then
                    return true
                end
                if type(alias) == 'number' and alias == joaat(lower) then
                    return true
                end
            end
        end
    end
    return false
end

local function getShopAtSpawn(coords)
    if not Validation.IsValidCoords(coords) then return false end
    local normalized = Validation.NormalizeCoords(coords)
    if not normalized then return false end

    for _, shop in ipairs(shopCache) do
        if shop.vehicleSpawns then
            for _, spawnType in pairs(shop.vehicleSpawns) do
                for _, spawnPoint in ipairs(spawnType) do
                    local spawnCoords = Validation.NormalizeCoords(spawnPoint)
                    if spawnCoords and #(spawnCoords - normalized) <= 7.5 then
                        return shop
                    end
                end
            end
        end
    end

    return nil
end

local function buildDefaultStock()
    local stock = {}
    for _, itemData in pairs(Config.MaintenanceItems) do
        stock[itemData.item] = {
            label = itemData.label,
            price = math.floor(itemData.price or 0),
            quantity = 0
        }
    end
    for _, partData in pairs(Config.VehicleParts) do
        stock[partData.item] = {
            label = partData.label,
            price = math.floor((partData.price or 0) * Config.Economy.partMarkup),
            quantity = 0
        }
    end
    for _, toolCategory in pairs(Config.Tools) do
        for _, tool in ipairs(toolCategory) do
            stock[tool.item] = {
                label = tool.label,
                price = 500,
                quantity = 0
            }
        end
    end
    return stock
end

local function getShopStorage(shop)
    if not shop.storage or type(shop.storage) ~= 'table' then
        shop.storage = {}
    end
    return shop.storage
end

local function getShopStock(shop)
    local storage = getShopStorage(shop)
    if type(storage.stock) ~= 'table' then
        storage.stock = buildDefaultStock()
    else
        local defaults = buildDefaultStock()
        for itemName, data in pairs(defaults) do
            if not storage.stock[itemName] then
                storage.stock[itemName] = data
            end
        end
    end
    return storage.stock
end

-- Load all shops from database
function Shops.LoadAll()
    shopCache = Database.GetAllShops()
    -- Sync to all clients
    TriggerClientEvent('mechanic:client:shopsUpdated', -1, getPublicShops())
end

-- Get all shops
function Shops.GetAll()
    return shopCache
end

-- Get shop by ID
function Shops.GetById(shopId)
    for _, shop in ipairs(shopCache) do
        if shop.id == shopId then
            return shop
        end
    end
    return nil
end

-- Create new shop
function Shops.Create(data, source)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    
    -- Check admin permissions
    if Config.ShopCreation.requiresAdmin and not Framework.HasPermission(source, 'admin') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('no_permission'),
            type = 'error'
        })
        return false
    end

    if not Config.ShopCreation.requiresAdmin then
        local job = Player.PlayerData.job
        local grade = job and job.grade or 0
        if type(grade) == 'table' then
            grade = grade.level
        end
        grade = tonumber(grade) or 0
        if not Validation.IsMechanic(Player) or grade < Config.BossGrade then
            TriggerClientEvent('ox_lib:notify', source, {
                title = locale('no_permission'),
                type = 'error'
            })
            return false
        end
    end

    if type(data) ~= 'table' or type(data.name) ~= 'string' then
        return false
    end
    data.name = data.name:match('^%s*(.-)%s*$')
    if #data.name < 3 or #data.name > 50 or data.name:find('[%c]') then return false end

    if not Validation.IsPositiveInteger(data.price, 0, 1000000000) then
        return false
    end
    data.price = tonumber(data.price)

    if type(data.zones) ~= 'table' then return false end
    for zoneName, _ in pairs(Config.ShopCreation.requiredZones) do
        local coords = data.zones[zoneName]
        if not Validation.IsValidCoords(coords) then
            return false
        end
    end

    if type(data.lifts) ~= 'table' or #data.lifts < 1 or #data.lifts > Config.ShopCreation.maxLifts then
        return false
    end
    for _, lift in ipairs(data.lifts) do
        if type(lift) ~= 'table' or not Validation.IsValidCoords(lift.entry)
            or not Validation.IsValidCoords(lift.pos) or not Validation.IsValidCoords(lift.control) then
            return false
        end
    end

    if type(data.vehicleSpawns) ~= 'table' then return false end
    for spawnType, spawnConfig in pairs(Config.ShopCreation.vehicleSpawns) do
        local spawns = data.vehicleSpawns[spawnType]
        if type(spawns) ~= 'table' or #spawns < 1 or #spawns > spawnConfig.max then
            return false
        end
        for _, spawn in ipairs(spawns) do
            if not Validation.IsValidCoords(spawn) then
                return false
            end
        end
    end
    
    local shopId = Database.CreateShop(data)
    if shopId then
        -- Reload shops
        Shops.LoadAll()
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('shop_created'),
            description = locale('shop_created_desc', data.name),
            type = 'success'
        })
        
        return true
    end
    
    return false
end

-- Update shop owner
function Shops.UpdateOwner(shopId, citizenid)
    local query = 'UPDATE mechanic_shops SET owner = ? WHERE id = ?'
    if MySQL.update.await(query, {citizenid, shopId}) > 0 then
        Shops.LoadAll()
        return true
    end
    return false
end

-- Purchase shop
function Shops.Purchase(source, shopId)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    
    local shop = Shops.GetById(shopId)
    if not shop then return false end

    local citizenid = Player.PlayerData.citizenid
    local alreadyAssigned = MySQL.scalar.await('SELECT id FROM mechanic_shops WHERE owner = ? LIMIT 1', { citizenid })
        or MySQL.scalar.await('SELECT id FROM mechanic_employees WHERE citizenid = ? LIMIT 1', { citizenid })
    if alreadyAssigned then return false end
    
    -- Check if shop is already owned
    if shop.owner then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('shop_already_owned'),
            type = 'error'
        })
        return false
    end
    
    -- Check money
    local money = Config.Economy.payWithCash and Player.PlayerData.money.cash or Player.PlayerData.money.bank
    if money < shop.price then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('insufficient_funds'),
            type = 'error'
        })
        return false
    end
    
    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if not Player.Functions.RemoveMoney(account, shop.price, 'mechanic-shop-purchase') then
        return false
    end

    local updated = MySQL.update.await(
        'UPDATE mechanic_shops SET owner = ? WHERE id = ? AND owner IS NULL',
        { citizenid, shopId }
    )
    if updated > 0 then
        Shops.LoadAll()
        -- Set job
        Player.Functions.SetJob(Config.JobName, Config.BossGrade)
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('shop_purchased'),
            description = locale('shop_purchased_desc', shop.name),
            type = 'success'
        })
        
        return true
    end

    Player.Functions.AddMoney(account, shop.price, 'mechanic-shop-purchase-refund')
    return false
end

-- Sell shop
function Shops.Sell(source, shopId)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    
    local shop = Shops.GetById(shopId)
    if not shop or shop.owner ~= Player.PlayerData.citizenid then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('not_shop_owner'),
            type = 'error'
        })
        return false
    end
    
    -- Calculate sell price
    local sellPrice = math.floor(shop.price * Config.Economy.sellReturnPercent)
    
    -- Remove owner
    local updated = MySQL.update.await(
        'UPDATE mechanic_shops SET owner = NULL WHERE id = ? AND owner = ?',
        { shopId, Player.PlayerData.citizenid }
    )
    if updated > 0 then
        Shops.LoadAll()
        local account = Config.Economy.payWithCash and 'cash' or 'bank'
        Player.Functions.AddMoney(account, sellPrice, 'mechanic-shop-sale')
        -- Remove job
        Player.Functions.SetJob('unemployed', 0)
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('shop_sold'),
            description = locale('shop_sold_desc', sellPrice),
            type = 'success'
        })
        
        return true
    end
    
    return false
end

-- Spawn service vehicle
function Shops.SpawnServiceVehicle(source, model, coords)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    
    -- Check job
    if Player.PlayerData.job.name ~= Config.JobName then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('not_mechanic'),
            type = 'error'
        })
        return false
    end

    if not Validation.CheckRateLimit(source, 'spawn_vehicle', Config.Security.rateLimits.spawnVehicleMs) then
        return false
    end

    if not isAllowedServiceModel(model) then
        return false
    end

    if not Validation.IsValidCoords(coords) then
        return false
    end

    local spawnShop = getShopAtSpawn(coords)
    if not spawnShop then
        return false
    end
    local citizenid = Player.PlayerData.citizenid
    if spawnShop.owner ~= citizenid and not Business.isEmployee(citizenid, spawnShop.id) then
        return false
    end
    
    -- Create vehicle
    local vehicle = CreateVehicle(joaat(model), coords.x, coords.y, coords.z, coords.w or 0.0, true, true)
    
    -- Wait for vehicle to exist
    local timeoutAt = GetGameTimer() + 5000
    while not DoesEntityExist(vehicle) and GetGameTimer() < timeoutAt do
        Wait(10)
    end

    if not DoesEntityExist(vehicle) then
        return false
    end
    
  
    local plate
    for _ = 1, 20 do
        local candidate = 'MECH' .. math.random(1000, 9999)
        local owned = Validation.IsVehicleOwned(candidate)
        if not owned then
            plate = candidate
            break
        end
    end
    if not plate then
        DeleteEntity(vehicle)
        return false
    end

    lib.setVehicleProperties(vehicle, {
        plate = plate,
        bodyHealth = 1000.0,
        engineHealth = 1000.0,
        fuelLevel = 100.0
    })
    Entity(vehicle).state:set('mechanicServiceVehicle', true, true)
    serviceVehicles[NetworkGetNetworkIdFromEntity(vehicle)] = true

    SetPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)

    return true
end

-- Employee management
function Shops.AddEmployee(shopId, targetId, grade, wage)
    return Business.hireEmployee(shopId, targetId, grade, wage)
end

function Shops.RemoveEmployee(shopId, targetCitizenId)
    return Business.fireEmployee(shopId, targetCitizenId)
end

function Shops.GetEmployees(shopId)
    return Business.getBusinessEmployees(shopId)
end

-- Change employee grade
function Shops.ChangeEmployeeGrade(shopId, targetCitizenId, newGrade)
    return Business.updateEmployeeGrade(shopId, targetCitizenId, newGrade)
end

-- Change employee wage
function Shops.ChangeEmployeeWage(shopId, targetCitizenId, newWage)
    return Business.updateEmployeeWage(shopId, targetCitizenId, newWage)
end

-- Clock in/out system
function Shops.ClockIn(source)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    if not Validation.IsMechanic(Player) then return false end
    if Player.Functions and Player.Functions.SetJobDuty then
        Player.Functions.SetJobDuty(true)
        return true
    end
    return false
end

function Shops.ClockOut(source)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    if not Validation.IsMechanic(Player) then return false end
    if Player.Functions and Player.Functions.SetJobDuty then
        Player.Functions.SetJobDuty(false)
        return true
    end
    return false
end

-- Callbacks
lib.callback.register('mechanic:server:getShops', function(source)
    return getPublicShops()
end)

lib.callback.register('mechanic:server:purchaseShop', function(source, shopId)
    if not Validation.IsPositiveInteger(shopId, 1) then
        Validation.LogDenied(source, 'shop_purchase', 'invalid_shop_id')
        return false
    end
    if not Validation.CheckRateLimit(source, 'shop_purchase', Config.Security.rateLimits.shopTransactionMs) then
        return false
    end
    return Shops.Purchase(source, shopId)
end)

lib.callback.register('mechanic:server:sellShop', function(source, shopId)
    if not Validation.IsPositiveInteger(shopId, 1) then
        Validation.LogDenied(source, 'shop_sell', 'invalid_shop_id')
        return false
    end
    if not Validation.CheckRateLimit(source, 'shop_sell', Config.Security.rateLimits.shopTransactionMs) then
        return false
    end
    return Shops.Sell(source, shopId)
end)

lib.callback.register('mechanic:server:spawnServiceVehicle', function(source, model, coords)
    if type(model) ~= 'string' or not Validation.IsValidCoords(coords) then
        Validation.LogDenied(source, 'shop_spawn_service', 'invalid_payload')
        return false
    end
    return Shops.SpawnServiceVehicle(source, model, coords)
end)

lib.callback.register('mechanic:server:spawnGarageVehicle', function(source, model, coords)
    if type(model) ~= 'string' or not Validation.IsValidCoords(coords) then
        Validation.LogDenied(source, 'shop_spawn_garage', 'invalid_payload')
        return false
    end
    return Shops.SpawnServiceVehicle(source, model, coords)
end)

-- Employee management callbacks
lib.callback.register('mechanic:server:hireEmployee', function(source, shopId, targetId, grade, wage)
    if not Validation.IsPositiveInteger(shopId, 1) or not Validation.IsPositiveInteger(targetId, 1) then
        return false, locale('hire_failed')
    end
    local numericGrade = tonumber(grade)
    if not Validation.IsPositiveInteger(numericGrade, 0, Config.BossGrade) then
        return false, locale('hire_failed')
    end
    if not canManageShop(source, shopId, 'manage_employees') then
        return false, locale('no_permission')
    end
    local numericWage = tonumber(wage) or Config.Employees.defaultWage
    if not Validation.IsNumberInRange(numericWage, Config.Employees.minWage, Config.Employees.maxWage) then
        return false, locale('hire_failed')
    end
    local success, message = Shops.AddEmployee(shopId, targetId, numericGrade, numericWage)
    if success then
        -- El wage se establece en el Business.hireEmployee
        return true, message or locale('employee_hired')
    end
    return false, message or locale('hire_failed')
end)

lib.callback.register('mechanic:server:changeEmployeeGrade', function(source, shopId, targetCitizenId, newGrade)
    if not Validation.IsPositiveInteger(shopId, 1) or not Validation.IsValidCitizenId(targetCitizenId) then
        return false, locale('change_failed')
    end
    local numericGrade = tonumber(newGrade)
    if not Validation.IsPositiveInteger(numericGrade, 0, Config.BossGrade) then
        return false, locale('change_failed')
    end
    if not canManageShop(source, shopId, 'manage_employees') then
        return false, locale('no_permission')
    end
    if Shops.ChangeEmployeeGrade(shopId, targetCitizenId, numericGrade) then
        return true, locale('grade_changed')
    end
    return false, locale('change_failed')
end)

lib.callback.register('mechanic:server:changeEmployeeWage', function(source, shopId, targetCitizenId, newWage)
    if not Validation.IsPositiveInteger(shopId, 1) or not Validation.IsValidCitizenId(targetCitizenId) then
        return false, locale('change_failed')
    end
    local numericWage = tonumber(newWage)
    if not Validation.IsNumberInRange(numericWage, Config.Employees.minWage, Config.Employees.maxWage) then
        return false, locale('change_failed')
    end
    if not canManageShop(source, shopId, 'manage_employees') then
        return false, locale('no_permission')
    end
    if Shops.ChangeEmployeeWage(shopId, targetCitizenId, numericWage) then
        return true, locale('wage_changed')
    end
    return false, locale('change_failed')
end)

lib.callback.register('mechanic:server:fireEmployee', function(source, shopId, targetCitizenId)
    if not Validation.IsPositiveInteger(shopId, 1) or not Validation.IsValidCitizenId(targetCitizenId) then
        return false, locale('fire_failed')
    end
    if not canManageShop(source, shopId, 'manage_employees') then
        return false, locale('no_permission')
    end
    if Shops.RemoveEmployee(shopId, targetCitizenId) then
        return true, locale('employee_fired')
    end
    return false, locale('fire_failed')
end)

lib.callback.register('mechanic:server:getEmployees', function(source, shopId)
    if not Validation.IsPositiveInteger(shopId, 1) then
        return {}
    end
    if not canManageShop(source, shopId, 'manage_employees') then
        return {}
    end
    return Shops.GetEmployees(shopId)
end)

lib.callback.register('mechanic:server:clockIn', function(source)
    return Shops.ClockIn(source)
end)

lib.callback.register('mechanic:server:clockOut', function(source)
    return Shops.ClockOut(source)
end)

-- Verificar permisos de empleados
lib.callback.register('mechanic:server:hasEmployeePermission', function(source, shopId, permission)
    local Player = Framework.GetPlayer(source)
    if not Player then return false end
    if not Validation.IsPositiveInteger(shopId, 1) then return false end
    if permission ~= nil and (type(permission) ~= 'string' or #permission > 64) then return false end

    return canManageShop(source, shopId, permission)
end)

lib.callback.register('mechanic:server:getShopStock', function(source, shopId)
    if not Validation.IsPositiveInteger(shopId, 1) then
        return nil
    end
    if not canManageShop(source, shopId, 'manage_inventory') then
        return nil
    end

    if not Validation.CheckRateLimit(source, 'shop_stock', Config.Security.rateLimits.shopStockMs) then
        return nil
    end

    local shop = Shops.GetById(shopId)
    if not shop then return nil end

    local stock = getShopStock(shop)
    Database.UpdateShopStorage(shopId, shop.storage)
    return stock
end)

lib.callback.register('mechanic:server:restockItem', function(source, shopId, itemName, quantity, totalCost)
    if not Validation.IsPositiveInteger(shopId, 1) then
        return false
    end
    if type(itemName) ~= 'string' or #itemName < 1 or #itemName > 64 then
        return false
    end
    if not canManageShop(source, shopId, 'manage_inventory') then
        return false
    end

    if not Validation.CheckRateLimit(source, 'shop_stock', Config.Security.rateLimits.shopStockMs) then
        return false
    end

    local numericQuantity = tonumber(quantity)
    if not Validation.IsPositiveInteger(numericQuantity, 1, 100) then
        return false
    end

    local shop = Shops.GetById(shopId)
    if not shop then return false end

    local stock = getShopStock(shop)
    if not stock[itemName] then
        return false
    end

    local unitPrice = tonumber(stock[itemName].price)
    if not Validation.IsNumberInRange(unitPrice, 1, 1000000) then
        return false
    end

    local supplierUnitPrice = math.max(1, math.floor(unitPrice * 0.6))
    local calculatedTotal = supplierUnitPrice * numericQuantity
    if not Validation.IsNumberInRange(calculatedTotal, 1, 100000000) then
        return false
    end

    local funds = Business.getBusinessFunds(shopId)
    if funds < calculatedTotal then
        return false
    end

    if not Business.updateBusinessFunds(shopId, calculatedTotal, true) then
        return false
    end

    shop.storage.funds = funds - calculatedTotal
    stock[itemName].quantity = (stock[itemName].quantity or 0) + numericQuantity
    if not Database.UpdateShopStorage(shopId, shop.storage) then
        Business.updateBusinessFunds(shopId, calculatedTotal, false)
        shop.storage.funds = funds
        stock[itemName].quantity = stock[itemName].quantity - numericQuantity
        return false
    end

    return true
end)

-- Check if player belongs to any shop (owner or employee)
lib.callback.register('mechanic:server:getPlayerShop', function(source)
    local Player = Framework.GetPlayer(source)
    if not Player then return nil end
    if not Validation.IsMechanic(Player) then return nil end

    local citizenid = Player.PlayerData.citizenid

    for _, shop in ipairs(shopCache) do
        if shop.owner and shop.owner == citizenid then
            return shop.id
        end
    end

    local result = MySQL.query.await('SELECT shop_id FROM mechanic_employees WHERE citizenid = ? LIMIT 1', { citizenid })
    if result and result[1] then
        return result[1].shop_id
    end

    for _, shop in ipairs(shopCache) do
        local rank = Business.getEmployeeRank(citizenid, shop.id)
        if rank and rank > 0 then
            return shop.id
        end
    end

    return nil
end)

-- Events
RegisterNetEvent('mechanic:server:createShop', function(data)
    if type(data) ~= 'table' then
        Validation.LogDenied(source, 'shop_create', 'invalid_payload')
        return
    end
    if not Validation.CheckRateLimit(source, 'create_shop', Config.Security.rateLimits.createShopMs) then
        Validation.LogDenied(source, 'shop_create', 'rate_limited')
        return
    end
    Shops.Create(data, source)
end)

-- Initialize
CreateThread(function()
    Wait(1000)
    Shops.LoadAll()
end)

return Shops
