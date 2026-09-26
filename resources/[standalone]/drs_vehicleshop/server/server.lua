local Framework = nil
local QBCore = nil
local Operations = {}
local TestDrives = {}
local TestDriveCooldowns = {}
local PurchaseCooldowns = {}
local ActiveDeliveries = {}
local PendingHandoffs = {}
local PendingHandoffsBySource = {}
local SpawnReservations = {}
local PlayerVehicleColumns = nil
local OwnershipTextCharset = nil
local OwnershipTextCollation = nil
local VehicleCatalog = nil
local ServiceReady = false
local OrdersReady = false
local JournalIdentityReady = false
local RefundProcessing = {}
local SessionSequence = 0
local CheckoutQuotes = {}
local CheckoutQuoteBySource = {}
local CheckoutQuoteCooldowns = {}
local DeliveryAcknowledgements = {}
local FleetServiceReady = false
local FleetOrdersReady = false
local FleetRequestOperations = {}
local FleetJobOperations = {}
local FleetPurchaseCooldowns = {}
local FleetRefundProcessing = {}

local REQUIRED_VEHICLE_COLUMNS = {
    'id', 'license', 'citizenid', 'vehicle', 'hash', 'mods', 'plate',
    'garage', 'state', 'stored', 'type', 'job', 'fuel', 'engine', 'body'
}

local JOURNAL_TABLE_RENAMES = {
    { legacy = 'qr_vehicle_shop_orders', current = 'drs_vehicle_shop_orders' },
    { legacy = 'qr_vehicle_shop_plate_reservations', current = 'drs_vehicle_shop_plate_reservations' }
}

local JOURNAL_INDEX_RENAMES = {
    {
        tableName = 'drs_vehicle_shop_orders',
        indexes = {
            {
                legacy = 'uk_qr_vehicle_shop_order_id',
                current = 'uk_drs_vehicle_shop_order_id',
                columns = { 'order_id' },
                unique = true
            },
            {
                legacy = 'uk_qr_vehicle_shop_request_id',
                current = 'uk_drs_vehicle_shop_request_id',
                columns = { 'request_id' },
                unique = true
            },
            {
                legacy = 'idx_qr_vehicle_shop_orders_citizen_status',
                current = 'idx_drs_vehicle_shop_orders_citizen_status',
                columns = { 'citizenid', 'status' },
                unique = false
            },
            {
                legacy = 'idx_qr_vehicle_shop_orders_plate',
                current = 'idx_drs_vehicle_shop_orders_plate',
                columns = { 'plate' },
                unique = false
            }
        }
    },
    {
        tableName = 'drs_vehicle_shop_plate_reservations',
        indexes = {
            {
                legacy = 'uk_qr_vehicle_shop_reservation_plate',
                current = 'uk_drs_vehicle_shop_reservation_plate',
                columns = { 'plate' },
                unique = true
            },
            {
                legacy = 'uk_qr_vehicle_shop_reservation_request',
                current = 'uk_drs_vehicle_shop_reservation_request',
                columns = { 'request_id' },
                unique = true
            },
            {
                legacy = 'uk_qr_vehicle_shop_reservation_order',
                current = 'uk_drs_vehicle_shop_reservation_order',
                columns = { 'order_id' },
                unique = true
            }
        }
    }
}

local function Result(ok, code, message, extra)
    local result = extra or {}
    result.ok = ok == true
    result.code = code
    result.message = message
    return result
end

-- oxmysql returns TINYINT(1) columns as booleans. Normalize both boolean and
-- numeric database values before comparing compatibility state fields.
local function DatabaseInteger(value)
    if value == true then return 1 end
    if value == false then return 0 end
    return tonumber(value)
end

local function GetFramework()
    if Framework == 'qbox' and GetResourceState('qbx_core') == 'started' then
        return Framework
    elseif Framework == 'qb' and GetResourceState('qb-core') == 'started' then
        return Framework
    end

    Framework = nil
    QBCore = nil

    local configured = Config.Framework or 'auto'

    if configured == 'qbox' or (configured == 'auto' and GetResourceState('qbx_core') == 'started') then
        if GetResourceState('qbx_core') ~= 'started' then return nil end
        Framework = 'qbox'
    elseif configured == 'qb' or (configured == 'auto' and GetResourceState('qb-core') == 'started') then
        if GetResourceState('qb-core') ~= 'started' then return nil end
        Framework = 'qb'
        QBCore = exports['qb-core']:GetCoreObject()
    end

    return Framework
end

local function Notify(src, message, notifyType)
    notifyType = notifyType or 'inform'

    if GetResourceState('qbx_core') == 'started' then
        exports.qbx_core:Notify(src, message, notifyType)
        return
    end

    TriggerClientEvent('ox_lib:notify', src, {
        description = message,
        type = notifyType
    })
end

local function GetPlayer(src)
    local framework = GetFramework()

    if framework == 'qbox' then
        return exports.qbx_core:GetPlayer(src)
    elseif framework == 'qb' and QBCore then
        return QBCore.Functions.GetPlayer(src)
    end
end

local function GetLicense(src, data)
    if data and data.license then return data.license end

    if GetPlayerIdentifierByType then
        local ok, license = pcall(GetPlayerIdentifierByType, src, 'license')
        if ok and license then return license end
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' or identifier:sub(1, 9) == 'license2:' then
            return identifier
        end
    end
end

local function GetPlayerData(src)
    local player = GetPlayer(src)
    if not player then return nil end

    local data = player.PlayerData or player
    if not data.citizenid then return nil end

    return {
        player = player,
        citizenid = data.citizenid,
        license = GetLicense(src, data),
        money = data.money or {},
        job = data.job,
        gang = data.gang,
        metadata = data.metadata or {}
    }
end

local function PlayerIdentityMatches(src, citizenid)
    local current = GetPlayerData(src)
    return current ~= nil and current.citizenid == citizenid
end

local function GetMoney(src, account, citizenid)
    account = account or Config.PaymentAccount or 'cash'

    if GetFramework() == 'qbox' then
        return tonumber(exports.qbx_core:GetMoney(citizenid or src, account)) or 0
    end

    local data = GetPlayerData(src)
    if citizenid and (not data or data.citizenid ~= citizenid) then return 0 end
    return data and tonumber(data.money[account]) or 0
end

local function RemoveMoney(src, account, amount, reason, citizenid)
    account = account or Config.PaymentAccount or 'cash'

    if GetFramework() == 'qbox' then
        return exports.qbx_core:RemoveMoney(citizenid or src, account, amount, reason)
    end

    local data = GetPlayerData(src)
    if citizenid and (not data or data.citizenid ~= citizenid) then return false end
    return data and data.player.Functions.RemoveMoney(account, amount, reason) == true or false
end

local function AddMoney(src, account, amount, reason, citizenid)
    account = account or Config.PaymentAccount or 'cash'

    if GetFramework() == 'qbox' then
        return exports.qbx_core:AddMoney(citizenid or src, account, amount, reason)
    end

    local data = GetPlayerData(src)
    if citizenid and (not data or data.citizenid ~= citizenid) then return false end
    return data and data.player.Functions.AddMoney(account, amount, reason) == true or false
end

local function GetLegacyShop()
    return {
        label = 'Vehicle Shop',
        type = 'car',
        dealership = Config.DealershipCoords or (Config.Locations and Config.Locations.dealership),
        testDrive = Config.TestDriveCoords or (Config.Locations and Config.Locations.testDrive),
        spawn = Config.VehicleSpawnCoords or (Config.Locations and Config.Locations.spawn),
        garage = Config.DefaultGarage or 'pillboxgarage'
    }
end

local function GetShop(shopId)
    if type(Config.Shops) == 'table' then
        if shopId ~= nil then
            shopId = tostring(shopId)
            return Config.Shops[shopId], shopId
        end

        local defaultShop = Config.DefaultShop
        if defaultShop and Config.Shops[defaultShop] then
            return Config.Shops[defaultShop], defaultShop
        end

        return nil, nil
    end

    if shopId ~= nil and shopId ~= 'default' then return nil, tostring(shopId) end
    return GetLegacyShop(), 'default'
end

local function GetPedCoords(shop)
    local ped = shop and shop.ped
    if ped and ped.x then return ped end

    if type(ped) == 'table' then
        return ped.coords or ped.location or ped.position
    end

    return shop and (shop.pedCoords or shop.PedLocation or shop.dealership or shop.coords) or nil
end

local function GetShopCoords(shop)
    if not shop then return nil end
    if shop.locations and shop.locations.dealership then return shop.locations.dealership end
    return shop.dealership or shop.coords or GetPedCoords(shop)
end

local function GetShopLocation(shop, name)
    if not shop then return nil end
    if shop.locations and shop.locations[name] then return shop.locations[name] end
    return shop[name]
end

local function ShopAllowsCategory(shop, category)
    local categories = shop and shop.categories
    if type(categories) ~= 'table' then return true end
    if categories[category] == true then return true end

    for _, allowedCategory in pairs(categories) do
        if allowedCategory == category then return true end
    end

    return false
end

local function NormalizeGarageType(value)
    value = tostring(value or 'car'):lower()

    if value == 'automobile' or value == 'bike' or value == 'bicycle' or value == 'quadbike' or value == 'car' then
        return 'car'
    elseif value == 'boat' or value == 'jetski' then
        return 'boat'
    elseif value == 'air' or value == 'heli' or value == 'helicopter' or value == 'plane' then
        return 'air'
    end

    return value
end

local function GetVehicleGarageType(vehicle, category, shop)
    local configured = vehicle and (vehicle.garageType or vehicle.vehicleType or vehicle.type)
    if configured then return NormalizeGarageType(configured) end
    if category == 'boats' then return 'boat' end
    if category == 'helicopters' or category == 'planes' then return 'air' end
    return NormalizeGarageType(shop and shop.type or 'car')
end

local function GetServerVehicleType(vehicle, category)
    local configured = vehicle and vehicle.spawnType
    if configured then return tostring(configured):lower() end
    if category == 'boats' then return 'boat' end
    if category == 'helicopters' then return 'heli' end
    if category == 'planes' then return 'plane' end
    if category == 'motorcycles' then return 'bike' end
    return 'automobile'
end

local function BuildVehicleCatalog()
    local catalog = {}

    for category, categoryVehicles in pairs(Config.Vehicles or {}) do
        for key, vehicle in pairs(categoryVehicles) do
            if type(vehicle) == 'table' then
                local model = tostring(vehicle.model or key):lower()
                catalog[model] = catalog[model] or {}
                catalog[model][#catalog[model] + 1] = {
                    category = category,
                    vehicle = vehicle
                }
            end
        end
    end

    VehicleCatalog = catalog
end

local function GetVehicleFromConfig(model, shopId)
    if type(model) ~= 'string' or #model < 1 or #model > 64 or not model:match('^[%w_%-]+$') then
        return nil
    end

    model = model:lower()
    local shop, resolvedShopId = GetShop(shopId)
    if not shop then return nil end
    if not VehicleCatalog then BuildVehicleCatalog() end

    for _, entry in ipairs(VehicleCatalog[model] or {}) do
        if ShopAllowsCategory(shop, entry.category) then
            return entry.vehicle, entry.category, shop, resolvedShopId, model
        end
    end
end

local function GetGrade(group)
    if type(group) ~= 'table' then return 0 end
    local grade = group.grade
    if type(grade) == 'table' then grade = grade.level or grade.grade end
    return tonumber(grade) or 0
end

local function GetPlayerGroups(src, data)
    if GetFramework() == 'qbox' then
        local ok, groups = pcall(function()
            return exports.qbx_core:GetGroups(src)
        end)
        if ok and type(groups) == 'table' then return groups end
    end

    local groups = {}
    if data and data.job and data.job.name then groups[data.job.name] = GetGrade(data.job) end
    if data and data.gang and data.gang.name then groups[data.gang.name] = GetGrade(data.gang) end
    return groups
end

local function HasGroupAccess(src, data, rules)
    if type(rules) ~= 'table' or not next(rules) then return true end

    local groups = GetPlayerGroups(src, data)

    for key, value in pairs(rules) do
        local groupName
        local minimumGrade

        if type(key) == 'number' then
            groupName = tostring(value)
            minimumGrade = 0
        else
            groupName = tostring(key)
            minimumGrade = tonumber(value) or 0
        end

        if groups[groupName] ~= nil and (tonumber(groups[groupName]) or 0) >= minimumGrade then
            return true
        end
    end

    return false
end

local function HasPolicyAccess(src, data, vehicle, category, shop, action)
    if shop[action] == false or vehicle[action] == false then return false, 'action_disabled' end

    local categoryPolicy = type(Config.CategoryAccess) == 'table' and Config.CategoryAccess[category] or nil
    local policies = { shop.groups, categoryPolicy and categoryPolicy.groups, vehicle.groups }

    for _, groups in pairs(policies) do
        if type(groups) == 'table' and next(groups) and not HasGroupAccess(src, data, groups) then
            return false, 'restricted'
        end
    end

    local requiredLicense = vehicle.license or (categoryPolicy and categoryPolicy.license) or shop.license
    if requiredLicense then
        local licences = data.metadata and (data.metadata.licences or data.metadata.licenses) or {}
        if type(licences) ~= 'table' or licences[requiredLicense] ~= true then
            return false, 'license_required'
        end
    end

    return true
end

local function IsNearDealership(src, shop)
    local maxDistance = tonumber(Config.MaxPurchaseDistance) or 25.0
    if maxDistance <= 0 then return false end

    local dealershipCoords = GetShopCoords(shop)
    if not dealershipCoords then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    return #(GetEntityCoords(ped) - vector3(dealershipCoords.x, dealershipCoords.y, dealershipCoords.z)) <= maxDistance
end

local CHECKOUT_CUSTOMIZATION_KEYS = {
    primaryColorId = true,
    secondaryColorId = true,
    plateMode = true,
    platePrefix = true,
    plateStyleId = true,
    deliveryMode = true
}

local function NormalizeOptionId(value)
    if type(value) ~= 'string' or #value < 1 or #value > 64 then return nil end
    value = value:lower()
    if not value:match('^[a-z0-9_%-]+$') then return nil end
    return value
end

local function NormalizeConfiguredPrice(value)
    value = tonumber(value or 0)
    if not value or value < 0 or value % 1 ~= 0 or value > 4294967295 then return nil end
    return value
end

local function GetFleetConfig()
    return type(Config.Fleet) == 'table' and Config.Fleet or {}
end

local function CleanFleetName(value, maximum)
    if type(value) ~= 'string' then return nil end
    value = value:lower():match('^%s*(.-)%s*$')
    if value == '' or #value > maximum or not value:match('^[%w_%-]+$') then return nil end
    return value
end

local function CleanFleetRequestId(value)
    if type(value) ~= 'string' or #value < 8 or #value > 64 then return nil end
    if not value:match('^[%w_%.:%-]+$') then return nil end
    return value
end

local function CleanFleetReason(value)
    if value == nil then return nil end
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%z\1-\31\127]', ''):match('^%s*(.-)%s*$')
    if value == '' then return nil end
    return value:sub(1, 160)
end

local function FleetInteger(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge
        or value % 1 ~= 0 or value < minimum or value > maximum then
        return nil
    end
    return math.floor(value)
end

local function FleetCollectionContains(collection, needle)
    if type(collection) ~= 'table' then return false end
    if collection[needle] == true then return true end
    for key, value in pairs(collection) do
        if type(key) == 'number' and tostring(value):lower() == needle then return true end
    end
    return false
end

local function GetFleetCatalogRule(job)
    local catalogs = GetFleetConfig().Catalogs
    local rule = type(catalogs) == 'table' and catalogs[job] or nil
    if type(rule) ~= 'table' or rule.enabled == false then return nil end
    if not next(type(rule.models) == 'table' and rule.models or {})
        and not next(type(rule.categories) == 'table' and rule.categories or {}) then
        return nil
    end
    return rule
end

local function FleetRuleAllows(rule, model, category)
    if FleetCollectionContains(rule.denyModels, model) then return false end
    return FleetCollectionContains(rule.models, model)
        or FleetCollectionContains(rule.categories, tostring(category or ''):lower())
end

local function ResolveFleetCatalogVehicle(job, model)
    local rule = GetFleetCatalogRule(job)
    if not rule then return nil, 'fleet_job_not_configured' end
    if not VehicleCatalog then BuildVehicleCatalog() end

    local selected
    for _, entry in ipairs(VehicleCatalog[model] or {}) do
        if FleetRuleAllows(rule, model, entry.category) then
            local price = NormalizeConfiguredPrice(entry.vehicle and entry.vehicle.price)
            if not price then return nil, 'fleet_price_invalid' end
            local candidate = {
                vehicle = entry.vehicle,
                category = entry.category,
                model = model,
                price = price,
                vehicleType = GetVehicleGarageType(entry.vehicle, entry.category, nil)
            }
            if selected and (selected.price ~= candidate.price
                or selected.vehicleType ~= candidate.vehicleType
                or selected.category ~= candidate.category) then
                return nil, 'fleet_catalog_ambiguous'
            end
            selected = candidate
        end
    end

    if not selected then return nil, 'fleet_vehicle_not_allowed' end
    return selected, nil, rule
end

local function BuildFleetCatalog(job)
    local rule = GetFleetCatalogRule(job)
    if not rule then return nil, 'fleet_job_not_configured' end
    if not VehicleCatalog then BuildVehicleCatalog() end

    local models = {}
    for model in pairs(VehicleCatalog) do models[#models + 1] = model end
    table.sort(models)

    local maximum = math.max(1, math.min(1000, math.floor(tonumber(GetFleetConfig().MaxCatalogResults) or 300)))
    local output = {}
    for _, model in ipairs(models) do
        local resolved = ResolveFleetCatalogVehicle(job, model)
        if resolved then
            local vehicle = resolved.vehicle
            output[#output + 1] = {
                model = resolved.model,
                name = tostring(vehicle.name or resolved.model):sub(1, 96),
                brand = tostring(vehicle.brand or ''):sub(1, 64),
                category = tostring(resolved.category or ''):sub(1, 64),
                vehicleType = resolved.vehicleType,
                price = resolved.price,
                image = type(vehicle.image) == 'string' and vehicle.image:sub(1, 128) or nil
            }
            if #output >= maximum then break end
        end
    end

    table.sort(output, function(left, right)
        local leftName = tostring(left.name or left.model):lower()
        local rightName = tostring(right.name or right.model):lower()
        if leftName == rightName then return left.model < right.model end
        return leftName < rightName
    end)
    return output, nil, rule
end

local function GetFleetJobGrade(job)
    if type(job) ~= 'table' then return 0 end
    local grade = job.grade
    if type(grade) == 'table' then grade = grade.level or grade.grade end
    return tonumber(grade) or 0
end

local function ValidateFleetBoss(src, requestedJob, minimumGrade)
    if GetFramework() ~= 'qbox' then
        return nil, 'fleet_framework_unsupported', 'Paid society fleet purchases currently require Qbox.'
    end

    local data = GetPlayerData(src)
    if not data then return nil, 'player_unavailable', 'The acting player is no longer available.' end
    local job = data.job
    local currentJob = type(job) == 'table' and CleanFleetName(job.name, 50) or nil
    if not currentJob or currentJob ~= requestedJob then
        return nil, 'fleet_job_changed', 'Your current job no longer matches this fleet.'
    end
    if job.isboss ~= true then
        return nil, 'fleet_boss_required', 'Only the current job boss can purchase society vehicles.'
    end

    local configuredMinimum = math.max(0, math.floor(tonumber(GetFleetConfig().MinimumBossGrade) or 0))
    minimumGrade = math.max(configuredMinimum, math.max(0, math.floor(tonumber(minimumGrade) or 0)))
    if GetFleetJobGrade(job) < minimumGrade then
        return nil, 'fleet_grade_required', 'Your job grade is not high enough for this fleet purchase.'
    end
    if GetFleetConfig().RequireOnDuty ~= false and job.onduty ~= true and job.onDuty ~= true then
        return nil, 'fleet_duty_required', 'You must be on duty to purchase a society vehicle.'
    end
    return data
end

local function ResolveFleetBankProvider(configured)
    configured = tostring(configured or GetFleetConfig().BankProvider or 'auto'):lower()
    if configured == 'none' then return nil end
    if configured == 'auto' then
        if GetResourceState('qb-banking') == 'started' then return 'qb-banking' end
        if GetResourceState('Renewed-Banking') == 'started' then return 'renewed-banking' end
        return nil
    end
    if configured == 'renewed-banking' and GetResourceState('Renewed-Banking') == 'started' then
        return configured
    end
    if configured == 'qb-banking' and GetResourceState('qb-banking') == 'started' then
        return configured
    end
end

local function GetSocietyBalance(provider, account)
    local ok, balance
    if provider == 'renewed-banking' then
        ok, balance = pcall(function()
            return exports['Renewed-Banking']:getAccountMoney(account)
        end)
    elseif provider == 'qb-banking' then
        ok, balance = pcall(function()
            return exports['qb-banking']:GetAccountBalance(account)
        end)
    else
        return nil, 'unsupported_provider'
    end
    balance = ok and tonumber(balance) or nil
    if not ok or not balance then return nil, tostring(balance or 'balance_unavailable') end
    return balance
end

-- Returns true only for a confirmed mutation, false for a confirmed rejection,
-- and nil when the provider response is ambiguous and staff review is required.
-- Renewed Banking documents boolean results. QB Banking returns oxmysql's
-- affected-row count, although true is also accepted for compatible forks.
local function ClassifySocietyMutation(provider, result)
    if result == true then return true end
    if result == false then return false, 'provider_rejected' end
    if provider == 'qb-banking' and type(result) == 'number'
        and result == result and result ~= math.huge and result ~= -math.huge and result > 0
    then
        return true
    end
    return nil, 'provider_response_unconfirmed'
end

local function RemoveSocietyFunds(provider, account, amount, reason)
    if amount == 0 then return true end
    local ok, removed
    if provider == 'renewed-banking' then
        ok, removed = pcall(function()
            return exports['Renewed-Banking']:removeAccountMoney(account, amount, reason)
        end)
    elseif provider == 'qb-banking' then
        ok, removed = pcall(function()
            return exports['qb-banking']:RemoveMoney(account, amount, reason)
        end)
    else
        return false, 'unsupported_provider'
    end
    if not ok then return nil, tostring(removed) end
    return ClassifySocietyMutation(provider, removed)
end

local function AddSocietyFunds(provider, account, amount, reason)
    if amount == 0 then return true end
    local ok, added
    if provider == 'renewed-banking' then
        ok, added = pcall(function()
            return exports['Renewed-Banking']:addAccountMoney(account, amount, reason)
        end)
    elseif provider == 'qb-banking' then
        ok, added = pcall(function()
            return exports['qb-banking']:AddMoney(account, amount, reason)
        end)
    else
        return false, 'unsupported_provider'
    end
    if not ok then return nil, tostring(added) end
    return ClassifySocietyMutation(provider, added)
end

local function GetFleetGarageResource()
    local resource = CleanFleetName(GetFleetConfig().GarageResource or 'drs_garages', 64)
    return resource or 'drs_garages'
end

local function FleetRuntimeReady(requireBank)
    local fleet = GetFleetConfig()
    if fleet.Enabled ~= true then return false, 'fleet_disabled', 'Society fleet checkout is disabled.' end
    if not FleetServiceReady then
        return false, 'fleet_service_unavailable', 'Society fleet checkout is still starting or needs database attention.'
    end
    if GetFramework() ~= 'qbox' then
        return false, 'fleet_framework_unsupported', 'Paid society fleet purchases currently require Qbox.'
    end
    local garageResource = GetFleetGarageResource()
    if GetResourceState(garageResource) ~= 'started' then
        return false, 'fleet_garage_unavailable', 'DRS Garages is not available for fleet creation.'
    end
    local statusCalled, garageStatus = pcall(function()
        return exports[garageResource]:GetJobFleetServiceStatus()
    end)
    if not statusCalled or type(garageStatus) ~= 'table'
        or garageStatus.ok ~= true or garageStatus.ready ~= true then
        return false, 'fleet_garage_unavailable',
            type(garageStatus) == 'table' and tostring(garageStatus.message or 'DRS Garages fleet service is not ready.')
                or 'DRS Garages does not provide a ready fleet-creation service.'
    end
    local provider = ResolveFleetBankProvider()
    if requireBank and not provider then
        return false, 'fleet_bank_unavailable', 'No supported society banking provider is available.'
    end
    return true, nil, nil, provider, garageResource
end

local function GetAuthorizedFleetCaller()
    local caller = GetInvokingResource()
    local allowed = GetFleetConfig().AllowedCallers
    if type(caller) ~= 'string' or type(allowed) ~= 'table' or allowed[caller] ~= true then
        return nil
    end
    return caller
end

local function NormalizeFleetPurchaseRequest(request)
    if type(request) ~= 'table' then return nil, 'invalid_request' end
    local allowedKeys = {
        requestId = true, actorSource = true, action = true, job = true,
        model = true, garageIndex = true, reason = true
    }
    for key in pairs(request) do
        if not allowedKeys[key] then return nil, 'invalid_request_field' end
    end
    if request.action ~= nil and request.action ~= 'society_purchase' then
        return nil, 'invalid_action'
    end

    local actorSource = FleetInteger(request.actorSource, 1, 2147483647)
    local garageIndex = FleetInteger(request.garageIndex, 1, 100000)
    local normalized = {
        requestId = CleanFleetRequestId(request.requestId),
        actorSource = actorSource,
        job = CleanFleetName(request.job, 50),
        model = CleanFleetName(request.model, 64),
        garageIndex = garageIndex,
        reason = CleanFleetReason(request.reason)
    }
    if not normalized.requestId or not normalized.actorSource or normalized.actorSource < 1
        or not normalized.job or not normalized.model
        or not normalized.garageIndex or normalized.garageIndex < 1
        or normalized.garageIndex > 100000 then
        return nil, 'invalid_request'
    end
    if request.reason ~= nil and type(request.reason) ~= 'string' then return nil, 'invalid_reason' end
    return normalized
end

local function NormalizePlatePrefix(value, settings)
    if value == nil then return '' end
    if type(value) ~= 'string' then return nil, 'Plate prefixes must be text.' end

    value = value:upper():match('^%s*(.-)%s*$')
    local configuredMaximum = tonumber(settings and settings.maxLength) or 3
    local maximum = math.max(1, math.min(3, math.floor(configuredMaximum)))
    if value == '' then return '' end
    if #value > maximum or not value:match('^[A-Z0-9]+$') then
        return nil, ('Plate prefixes must contain one to %s letters or numbers.'):format(maximum)
    end

    local blockedPrefixes = settings and type(settings.blocked) == 'table' and settings.blocked or {}
    for _, blocked in ipairs(blockedPrefixes) do
        if type(blocked) == 'string' and value == blocked:upper() then
            return nil, 'That plate prefix is reserved.'
        end
    end

    return value
end

local function BuildCheckoutColorOptions(settings)
    local options, byId = {}, {}
    if type(settings.colors) ~= 'table' then return nil, nil, 'Checkout colors must be a table.' end
    for _, configured in ipairs(settings.colors) do
        if type(configured) ~= 'table' then
            return nil, nil, 'Checkout color configuration is invalid.'
        end
        local id = NormalizeOptionId(configured.id)
        local index = tonumber(configured.index)
        local price = NormalizeConfiguredPrice(configured.price)
        if not id or byId[id] or not index or index % 1 ~= 0 or index < 0 or index > 160
            or not price or type(configured.label) ~= 'string' then
            return nil, nil, 'Checkout color configuration is invalid.'
        end

        local option = {
            id = id,
            label = configured.label:sub(1, 64),
            swatch = type(configured.swatch) == 'string' and configured.swatch:sub(1, 16) or '#ffffff',
            index = index,
            price = price
        }
        options[#options + 1] = option
        byId[id] = option
    end
    return options, byId
end

local function BuildCheckoutPlateStyleOptions(settings, enabled)
    local options, byId = {}, {}
    if not enabled then return options, byId end
    if type(settings.plateStyles) ~= 'table' then
        return nil, nil, 'Checkout plate styles must be a table.'
    end

    for _, configured in ipairs(settings.plateStyles) do
        if type(configured) ~= 'table' then
            return nil, nil, 'Checkout plate-style configuration is invalid.'
        end
        local id = NormalizeOptionId(configured.id)
        local index = tonumber(configured.index)
        local price = NormalizeConfiguredPrice(configured.price)
        if not id or byId[id] or not index or index % 1 ~= 0 or index < 0 or index > 5
            or not price or type(configured.label) ~= 'string' then
            return nil, nil, 'Checkout plate-style configuration is invalid.'
        end

        local option = {
            id = id,
            label = configured.label:sub(1, 64),
            preview = type(configured.preview) == 'string' and configured.preview:sub(1, 64) or configured.label:sub(1, 64),
            image = type(configured.image) == 'string'
                and (configured.image:match('^assets/plates/[%w_-]+%.png$')
                    or configured.image:match('^assets/plates/[%w_-]+%.webp$'))
                or nil,
            index = index,
            price = price
        }
        options[#options + 1] = option
        byId[id] = option
    end
    return options, byId
end

local function BuildCheckoutDeliveryOptions(settings, canDriveaway)
    local options, byId = {}, {}
    if type(settings.deliveryModes) ~= 'table' then
        return nil, nil, 'Checkout delivery modes must be a table.'
    end
    for _, configured in ipairs(settings.deliveryModes) do
        if type(configured) ~= 'table' then
            return nil, nil, 'Checkout delivery configuration is invalid.'
        end
        local id = NormalizeOptionId(configured.id)
        local price = NormalizeConfiguredPrice(configured.price)
        if (id ~= 'driveaway' and id ~= 'garage') or byId[id] or price ~= 0
            or type(configured.label) ~= 'string' then
            return nil, nil, 'Checkout delivery configuration is invalid.'
        end

        if id == 'garage' or canDriveaway then
            local option = {
                id = id,
                label = configured.label:sub(1, 64),
                description = type(configured.description) == 'string'
                    and configured.description:sub(1, 160) or '',
                price = 0
            }
            options[#options + 1] = option
            byId[id] = option
        end
    end
    return options, byId
end

local function ResolveCheckout(vehicle, category, shop, resolvedShopId, model, customization)
    local settings = type(Config.Checkout) == 'table' and Config.Checkout or {}
    if settings.enabled ~= true then
        return nil, 'checkout_disabled', 'Vehicle checkout is currently disabled.'
    end
    if customization == nil then customization = {} end
    if type(customization) ~= 'table' then
        return nil, 'invalid_customization', 'Invalid checkout selections.'
    end
    for key in pairs(customization) do
        if not CHECKOUT_CUSTOMIZATION_KEYS[key] then
            return nil, 'invalid_customization', 'Checkout contained an unknown selection.'
        end
    end

    local basePrice = NormalizeConfiguredPrice(vehicle.price)
    if not basePrice then return nil, 'invalid_price', 'This vehicle has an invalid price.' end

    local vehicleType = GetVehicleGarageType(vehicle, category, shop)
    local roadVehicle = vehicleType == 'car'
    local configuredCapabilities = type(settings.capabilities) == 'table' and settings.capabilities or {}
    local colors, colorsById, colorError = BuildCheckoutColorOptions(settings)
    if not colors then return nil, 'checkout_config_invalid', colorError end

    local colorsEnabled = configuredCapabilities.colors ~= false and #colors > 0
    local secondaryEnabled = colorsEnabled and configuredCapabilities.secondaryColor ~= false
    local prefixSettings = type(settings.platePrefix) == 'table' and settings.platePrefix or {}
    local prefixEnabled = roadVehicle and configuredCapabilities.platePrefix ~= false
        and prefixSettings.enabled ~= false
    local stylesEnabled = roadVehicle and configuredCapabilities.plateStyles ~= false
    local plateStyles, plateStylesById, styleError = BuildCheckoutPlateStyleOptions(settings, stylesEnabled)
    if not plateStyles then return nil, 'checkout_config_invalid', styleError end
    stylesEnabled = stylesEnabled and #plateStyles > 0

    local canDriveaway = configuredCapabilities.delivery ~= false
        and Config.DeliverPurchasedVehicles ~= false
        and tonumber(Config.PurchasedVehicleState or 0) == 0
        and GetShopLocation(shop, 'spawn') ~= nil
    local deliveryModes, deliveryById, deliveryError = BuildCheckoutDeliveryOptions(settings, canDriveaway)
    if not deliveryModes then return nil, 'checkout_config_invalid', deliveryError end
    if not deliveryById.garage then
        return nil, 'checkout_config_invalid', 'Checkout must include a garage delivery option.'
    end

    local defaults = type(settings.defaults) == 'table' and settings.defaults or {}
    local primaryId = customization.primaryColorId or defaults.primaryColorId
    local secondaryId = customization.secondaryColorId or defaults.secondaryColorId or primaryId
    primaryId = primaryId and NormalizeOptionId(primaryId) or nil
    secondaryId = secondaryId and NormalizeOptionId(secondaryId) or nil

    local primary = primaryId and colorsById[primaryId] or nil
    local secondary = secondaryId and colorsById[secondaryId] or nil
    if colorsEnabled and (not primary or not secondary) then
        return nil, 'invalid_color', 'Select a valid factory color.'
    elseif not colorsEnabled and (customization.primaryColorId ~= nil or customization.secondaryColorId ~= nil) then
        return nil, 'color_unavailable', 'Factory colors are unavailable for this vehicle.'
    end
    if not secondaryEnabled then secondary = primary; secondaryId = primaryId end

    local plateMode = customization.plateMode or defaults.plateMode or 'standard'
    if plateMode ~= 'standard' and plateMode ~= 'prefix' then
        return nil, 'invalid_plate_mode', 'Select a valid registration option.'
    end
    local prefix, prefixError = NormalizePlatePrefix(customization.platePrefix, prefixSettings)
    if not prefix then return nil, 'invalid_plate_prefix', prefixError end
    if plateMode == 'prefix' and prefix == '' then plateMode = 'standard' end
    if plateMode == 'prefix' and not prefixEnabled then
        return nil, 'plate_prefix_unavailable', 'Custom plate prefixes are only available for road vehicles.'
    end
    if plateMode == 'standard' then prefix = '' end

    local styleId = customization.plateStyleId or defaults.plateStyleId
    styleId = styleId and NormalizeOptionId(styleId) or nil
    local plateStyle = styleId and plateStylesById[styleId] or nil
    if stylesEnabled and not plateStyle then
        return nil, 'invalid_plate_style', 'Select a valid plate style.'
    elseif not stylesEnabled and customization.plateStyleId ~= nil then
        return nil, 'plate_style_unavailable', 'Plate styles are unavailable for this vehicle.'
    end

    local deliveryMode = customization.deliveryMode or defaults.deliveryMode or 'garage'
    deliveryMode = NormalizeOptionId(deliveryMode)
    if not deliveryMode or not deliveryById[deliveryMode] then
        if customization.deliveryMode == nil and deliveryById.garage then deliveryMode = 'garage' end
    end
    local delivery = deliveryMode and deliveryById[deliveryMode] or nil
    if not delivery then return nil, 'invalid_delivery_mode', 'Select a valid delivery option.' end

    local paintCost = 0
    if colorsEnabled then
        paintCost = primary.price + (secondary.id ~= primary.id and secondary.price or 0)
    end
    local configuredPrefixPrice = NormalizeConfiguredPrice(prefixSettings.price)
    if configuredPrefixPrice == nil then
        return nil, 'checkout_config_invalid', 'Plate-prefix pricing is invalid.'
    end
    local prefixCost = plateMode == 'prefix' and configuredPrefixPrice or 0
    local styleCost = plateStyle and plateStyle.price or 0
    local optionCost = paintCost + prefixCost + styleCost
    local total = basePrice + optionCost
    if total > 4294967295 then return nil, 'invalid_price', 'The configured checkout total is too large.' end

    local selection = {
        primaryColorId = primary and primary.id or nil,
        secondaryColorId = secondary and secondary.id or nil,
        plateMode = plateMode,
        platePrefix = prefix,
        plateStyleId = plateStyle and plateStyle.id or nil,
        deliveryMode = delivery.id
    }
    local costs = {
        base = basePrice,
        paint = paintCost,
        plate = prefixCost,
        style = styleCost,
        total = total
    }
    local capabilities = {
        colors = colorsEnabled,
        secondaryColor = secondaryEnabled,
        platePrefix = prefixEnabled,
        plateStyles = stylesEnabled,
        delivery = configuredCapabilities.delivery ~= false
    }
    local labels = {
        shop = tostring(shop.label or resolvedShopId),
        vehicle = tostring(vehicle.name or vehicle.label or model),
        primaryColor = primary and primary.label or 'Factory',
        secondaryColor = secondary and secondary.label or 'Factory',
        plate = plateMode == 'prefix' and ('%s prefix'):format(prefix) or 'Standard registration',
        plateMode = plateMode == 'prefix' and 'Custom prefix' or 'Standard issue',
        plateStyle = plateStyle and plateStyle.label or 'Standard',
        delivery = delivery.label,
        deliveryMode = delivery.label
    }
    local previewCharacters = plateMode == 'prefix' and (8 - #prefix) or 8
    local platePreview = (plateMode == 'prefix' and prefix or '') .. string.rep('•', previewCharacters)

    local publicColors = {}
    for _, option in ipairs(colors) do
        publicColors[#publicColors + 1] = {
            id = option.id, label = option.label, swatch = option.swatch, price = option.price
        }
    end
    local publicStyles = {}
    for _, option in ipairs(plateStyles) do
        publicStyles[#publicStyles + 1] = {
            id = option.id, label = option.label, preview = option.preview, image = option.image, price = option.price
        }
    end

    local customizationRecord = {
        primaryColorId = selection.primaryColorId,
        primaryColor = primary and primary.index or nil,
        secondaryColorId = selection.secondaryColorId,
        secondaryColor = secondary and secondary.index or nil,
        plateMode = plateMode,
        platePrefix = prefix,
        plateStyleId = selection.plateStyleId,
        plateIndex = plateStyle and plateStyle.index or 0,
        deliveryMode = delivery.id
    }

    return {
        model = model,
        shopId = resolvedShopId,
        vehicleType = vehicleType,
        capabilities = capabilities,
        options = {
            colors = publicColors,
            primaryColors = publicColors,
            secondaryColors = publicColors,
            plateStyles = publicStyles,
            deliveryModes = deliveryModes,
            platePrefix = {
                minLength = 1,
                maxLength = math.max(1, math.min(3, math.floor(tonumber(prefixSettings.maxLength) or 3))),
                price = configuredPrefixPrice
            }
        },
        selection = selection,
        labels = labels,
        costs = costs,
        platePreview = platePreview,
        customization = customizationRecord,
        basePrice = basePrice,
        optionPrice = optionCost,
        totalPrice = total
    }
end

local function CheckoutFingerprint(resolved)
    local selection, costs = resolved.selection, resolved.costs
    return table.concat({
        resolved.model, resolved.shopId, resolved.vehicleType,
        selection.primaryColorId or '', selection.secondaryColorId or '',
        selection.plateMode, selection.platePrefix, selection.plateStyleId or '',
        selection.deliveryMode, tostring(costs.base), tostring(costs.paint),
        tostring(costs.plate), tostring(costs.style), tostring(costs.total)
    }, '\31')
end

local function NormalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:upper():match('^%s*(.-)%s*$')
    if not plate or plate == '' or #plate > 8 or not plate:match('^[A-Z0-9 ]+$') then return nil end
    return plate
end

local function RandomNumber(length)
    local output = {}
    for _ = 1, length do output[#output + 1] = tostring(math.random(0, 9)) end
    return table.concat(output)
end

local function RandomLetter()
    return string.char(math.random(65, 90))
end

local function RandomAlphaNumeric(length)
    local output = {}
    for _ = 1, length do
        if math.random(0, 1) == 0 then output[#output + 1] = tostring(math.random(0, 9))
        else output[#output + 1] = RandomLetter() end
    end
    return table.concat(output)
end

local function BuildPlateCandidate(prefix)
    if prefix and prefix ~= '' then
        if type(prefix) ~= 'string' or #prefix > 3 or not prefix:match('^[A-Z0-9]+$') then return nil end
        return NormalizePlate((prefix .. RandomAlphaNumeric(8 - #prefix)):sub(1, 8))
    end

    local format = tostring(Config.PlateFormat or '1LL3LL')
    local plate = format:gsub('[1234L]', function(token)
        if token == 'L' then return RandomLetter() end
        return RandomNumber(tonumber(token))
    end)

    return NormalizePlate(plate:sub(1, 8))
end

local function PlateExists(plate)
    if GetFramework() == 'qbox' and GetResourceState('qbx_vehicles') == 'started' then
        local ok, exists = pcall(function()
            return exports.qbx_vehicles:DoesPlayerVehiclePlateExist(plate)
        end)
        if ok then return exists == true end
    end

    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }) ~= nil
end

local function SchemaValue(row, key)
    if type(row) ~= 'table' then return nil end
    return row[key] or row[key:upper()] or row[key:lower()]
end

local function InspectTable(tableName)
    local tableOk, tableRow = pcall(MySQL.single.await, [[
        SELECT ENGINE AS engine, TABLE_COLLATION AS table_collation
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
        LIMIT 1
    ]], { tableName })
    if not tableOk then return nil, tableRow end
    if not tableRow then return { exists = false, columns = {}, indexes = {} } end

    local columnsOk, columnRows = pcall(MySQL.query.await, [[
        SELECT COLUMN_NAME AS column_name, DATA_TYPE AS data_type,
               COLUMN_TYPE AS column_type, CHARACTER_MAXIMUM_LENGTH AS maximum_length,
               CHARACTER_SET_NAME AS character_set_name, COLLATION_NAME AS collation_name,
               IS_NULLABLE AS is_nullable, COLUMN_DEFAULT AS column_default, EXTRA AS extra
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
    ]], { tableName })
    if not columnsOk or type(columnRows) ~= 'table' then return nil, columnRows end

    local indexesOk, indexRows = pcall(MySQL.query.await, [[
        SELECT INDEX_NAME AS index_name, COLUMN_NAME AS column_name,
               SEQ_IN_INDEX AS sequence_number, NON_UNIQUE AS non_unique,
               SUB_PART AS sub_part
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
        ORDER BY INDEX_NAME, SEQ_IN_INDEX
    ]], { tableName })
    if not indexesOk or type(indexRows) ~= 'table' then return nil, indexRows end

    local schema = {
        exists = true,
        engine = tostring(SchemaValue(tableRow, 'engine') or ''),
        tableCollation = tostring(SchemaValue(tableRow, 'table_collation') or ''),
        columns = {},
        indexes = {}
    }
    for _, row in ipairs(columnRows) do
        local name = SchemaValue(row, 'column_name')
        if name then
            name = tostring(name):lower()
            schema.columns[name] = {
                dataType = tostring(SchemaValue(row, 'data_type') or ''):lower(),
                columnType = tostring(SchemaValue(row, 'column_type') or ''):lower(),
                maximumLength = tonumber(SchemaValue(row, 'maximum_length')),
                characterSet = SchemaValue(row, 'character_set_name'),
                collation = SchemaValue(row, 'collation_name'),
                nullable = tostring(SchemaValue(row, 'is_nullable') or ''):upper() == 'YES',
                default = SchemaValue(row, 'column_default'),
                extra = tostring(SchemaValue(row, 'extra') or ''):lower()
            }
        end
    end
    for _, row in ipairs(indexRows) do
        local name = SchemaValue(row, 'index_name')
        local column = SchemaValue(row, 'column_name')
        if name and column then
            name = tostring(name):lower()
            column = tostring(column):lower()
            local index = schema.indexes[name]
            if not index then
                index = { unique = tonumber(SchemaValue(row, 'non_unique')) == 0, columns = {} }
                schema.indexes[name] = index
            end
            index.columns[tonumber(SchemaValue(row, 'sequence_number')) or (#index.columns + 1)] = {
                name = column,
                subPart = SchemaValue(row, 'sub_part')
            }
        end
    end
    return schema
end

local function SchemaFailure(action, errorMessage)
    print(('[drs_vehicleshop] Automatic database migration failed while %s: %s. ' ..
        'Grant the oxmysql account CREATE, ALTER, INDEX, DROP, and INSERT privileges for the first DRS upgrade, ' ..
        'or run the documented migration manually.'):format(
        action, tostring(errorMessage)
    ))
    return false
end

local function ExecuteSchemaChange(action, statement)
    local ok, result = pcall(MySQL.query.await, statement, {})
    if not ok then return SchemaFailure(action, result) end
    print(('[drs_vehicleshop] Database migration: %s.'):format(action))
    return true
end

local function HasIndexSignature(schema, columns, requireUnique)
    if not schema then return false end
    for _, index in pairs(schema.indexes) do
        if index.unique == requireUnique and #index.columns == #columns then
            local matches = true
            for position, column in ipairs(columns) do
                local indexed = index.columns[position]
                if not indexed or indexed.name ~= column or indexed.subPart ~= nil then
                    matches = false
                    break
                end
            end
            if matches then return true end
        end
    end
    return false
end

local function AvailableIndexName(schema, preferred)
    if not schema.indexes[preferred] then return preferred end
    for suffix = 2, 99 do
        local candidate = ('%s_%d'):format(preferred, suffix)
        if not schema.indexes[candidate] then return candidate end
    end
end

local function EnsureIndex(tableName, schema, preferredName, columns, unique)
    if not unique and HasIndexSignature(schema, columns, true) then
        return SchemaFailure(('verifying indexes on %s'):format(tableName),
            ('an incompatible UNIQUE index already constrains (%s)'):format(table.concat(columns, ', ')))
    end
    if HasIndexSignature(schema, columns, unique) then return true end
    local name = AvailableIndexName(schema, preferredName)
    if not name then return SchemaFailure(('choosing an index name for %s'):format(tableName), 'all safe names are occupied') end
    local quotedColumns = {}
    for index, column in ipairs(columns) do quotedColumns[index] = ('`%s`'):format(column) end
    local statement = ('ALTER TABLE `%s` ADD %sINDEX `%s` (%s)'):format(
        tableName, unique and 'UNIQUE ' or '', name, table.concat(quotedColumns, ', ')
    )
    if not ExecuteSchemaChange(('adding index %s to %s'):format(name, tableName), statement) then return false end
    local refreshed, inspectError = InspectTable(tableName)
    if not refreshed then return SchemaFailure(('verifying index %s'):format(name), inspectError) end
    if not HasIndexSignature(refreshed, columns, unique) then
        return SchemaFailure(('verifying index %s'):format(name), 'the expected index signature was not created')
    end
    return true, refreshed
end

local function EnsureInnoDB(tableName, schema)
    if schema.engine:lower() == 'innodb' then return true, schema end
    if not ExecuteSchemaChange(('converting %s to InnoDB'):format(tableName),
        ('ALTER TABLE `%s` ENGINE=InnoDB'):format(tableName)) then return false end
    local refreshed, inspectError = InspectTable(tableName)
    if not refreshed then return SchemaFailure(('verifying %s storage engine'):format(tableName), inspectError) end
    if refreshed.engine:lower() ~= 'innodb' then
        return SchemaFailure(('verifying %s storage engine'):format(tableName), 'InnoDB was not applied')
    end
    return true, refreshed
end

local function EnsureTableTextCollation(tableName, schema, characterSet, collation)
    characterSet = tostring(characterSet or ''):lower()
    collation = tostring(collation or ''):lower()
    if not characterSet:match('^[%w_]+$') or not collation:match('^[%w_]+$') then
        return SchemaFailure(('aligning %s text collation'):format(tableName),
            'the ownership plate charset or collation is unavailable or unsafe')
    end

    local requiresConversion = tostring(schema.tableCollation or ''):lower() ~= collation
    for _, column in pairs(schema.columns) do
        if column.characterSet and (tostring(column.characterSet):lower() ~= characterSet
            or tostring(column.collation or ''):lower() ~= collation) then
            requiresConversion = true
            break
        end
    end
    if not requiresConversion then return true, schema end

    if not ExecuteSchemaChange(('aligning %s text with player_vehicles.plate'):format(tableName),
        ('ALTER TABLE `%s` CONVERT TO CHARACTER SET %s COLLATE %s'):format(
            tableName, characterSet, collation
        )) then return false end

    local refreshed, inspectError = InspectTable(tableName)
    if not refreshed then return SchemaFailure(('verifying %s text collation'):format(tableName), inspectError) end
    if tostring(refreshed.tableCollation or ''):lower() ~= collation then
        return SchemaFailure(('verifying %s table collation'):format(tableName),
            ('expected %s but found %s'):format(collation, tostring(refreshed.tableCollation)))
    end
    for columnName, column in pairs(refreshed.columns) do
        if column.characterSet and (tostring(column.characterSet):lower() ~= characterSet
            or tostring(column.collation or ''):lower() ~= collation) then
            return SchemaFailure(('verifying %s.%s text collation'):format(tableName, columnName),
                ('expected %s/%s but found %s/%s'):format(
                    characterSet, collation, tostring(column.characterSet), tostring(column.collation)
                ))
        end
    end
    return true, refreshed
end

local function AddColumn(tableName, columnName, definition)
    return ExecuteSchemaChange(('adding %s.%s'):format(tableName, columnName),
        ('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, columnName, definition))
end

local function EnsurePlayerVehicleSchema()
    if PlayerVehicleColumns then return PlayerVehicleColumns end
    local schema, inspectError = InspectTable('player_vehicles')
    if not schema then
        SchemaFailure('inspecting player_vehicles', inspectError)
        return nil
    end
    if not schema.exists then
        if not ExecuteSchemaChange('creating player_vehicles', [[
            CREATE TABLE IF NOT EXISTS `player_vehicles` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(50) DEFAULT NULL,
            `citizenid` VARCHAR(50) DEFAULT NULL,
            `vehicle` VARCHAR(64) DEFAULT NULL,
            `hash` VARCHAR(50) DEFAULT NULL,
            `mods` LONGTEXT DEFAULT NULL,
            `plate` VARCHAR(15) NOT NULL,
            `fakeplate` VARCHAR(50) DEFAULT NULL,
            `garage` VARCHAR(50) DEFAULT NULL,
            `fuel` INT DEFAULT 100,
            `engine` FLOAT DEFAULT 1000,
            `body` FLOAT DEFAULT 1000,
            `state` INT NOT NULL DEFAULT 1,
            `type` VARCHAR(20) NOT NULL DEFAULT 'car',
            `stored` TINYINT(1) NOT NULL DEFAULT 1,
            `job` VARCHAR(50) DEFAULT NULL,
            `depotprice` INT NOT NULL DEFAULT 0,
            `drivingdistance` INT DEFAULT NULL,
            `status` TEXT DEFAULT NULL,
            `coords` TEXT DEFAULT NULL,
            `balance` INT NOT NULL DEFAULT 0,
            `paymentamount` INT NOT NULL DEFAULT 0,
            `paymentsleft` INT NOT NULL DEFAULT 0,
            `financetime` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]) then return nil end
        schema, inspectError = InspectTable('player_vehicles')
    end
    if not schema or not schema.exists then
        SchemaFailure('inspecting player_vehicles', inspectError or 'table was not created')
        return nil
    end

    local baseColumns = { 'id', 'license', 'citizenid', 'vehicle', 'hash', 'mods', 'plate', 'garage', 'fuel', 'engine', 'body' }
    for _, column in ipairs(baseColumns) do
        if not schema.columns[column] then
            SchemaFailure('verifying player_vehicles', ('required framework column %s is missing'):format(column))
            return nil
        end
    end

    local hadState = schema.columns.state ~= nil
    local hadStored = schema.columns.stored ~= nil
    if not hadState then
        local stateDefinition = hadStored
            and 'INT NULL DEFAULT NULL AFTER `body`'
            or 'INT NOT NULL DEFAULT 1 AFTER `body`'
        if not AddColumn('player_vehicles', 'state', stateDefinition) then return nil end
        schema.columns.state = true
    end
    local additiveColumns = {
        { 'type', "VARCHAR(20) NOT NULL DEFAULT 'car' AFTER `state`" },
        { 'job', "VARCHAR(50) NULL DEFAULT NULL AFTER `type`" },
        { 'balance', 'INT NOT NULL DEFAULT 0' },
        { 'paymentamount', 'INT NOT NULL DEFAULT 0' },
        { 'paymentsleft', 'INT NOT NULL DEFAULT 0' },
        { 'financetime', 'INT NOT NULL DEFAULT 0' }
    }
    for _, specification in ipairs(additiveColumns) do
        if not schema.columns[specification[1]] then
            if not AddColumn('player_vehicles', specification[1], specification[2]) then return nil end
            schema.columns[specification[1]] = true
        end
    end

    if not hadStored then
        if not AddColumn('player_vehicles', 'stored', 'TINYINT(1) NULL DEFAULT NULL AFTER `state`') then return nil end
    end

    local synchronized, syncError = pcall(MySQL.update.await, [[
        UPDATE player_vehicles
        SET state = CASE WHEN stored = 1 THEN 1 ELSE 0 END
        WHERE state IS NULL AND stored IS NOT NULL
    ]], {})
    if not synchronized then
        SchemaFailure('backfilling player_vehicles.state from stored', syncError)
        return nil
    end
    synchronized, syncError = pcall(MySQL.update.await, [[
        UPDATE player_vehicles SET state = 1 WHERE state IS NULL
    ]], {})
    if not synchronized then
        SchemaFailure('finalizing empty player_vehicles.state values', syncError)
        return nil
    end

    local backfilled, backfillError = pcall(MySQL.update.await, [[
        UPDATE player_vehicles
        SET stored = CASE WHEN state = 1 THEN 1 ELSE 0 END
        WHERE stored IS NULL
    ]], {})
    if not backfilled then
        SchemaFailure('backfilling player_vehicles.stored from state', backfillError)
        return nil
    end

    schema, inspectError = InspectTable('player_vehicles')
    if not schema then
        SchemaFailure('checking player_vehicles.stored', inspectError)
        return nil
    end
    local integerTypes = { tinyint = true, smallint = true, mediumint = true, int = true, integer = true, bigint = true }
    local storedColumn = schema.columns.stored
    if not storedColumn or not integerTypes[storedColumn.dataType] then
        SchemaFailure('verifying player_vehicles.stored', 'an existing non-integer column cannot be migrated safely')
        return nil
    end
    if storedColumn.nullable or tonumber(storedColumn.default) ~= 1 then
        if not storedColumn.columnType:match('^[%w%(%) ,]+$') then
            SchemaFailure('verifying player_vehicles.stored', 'the existing integer definition cannot be preserved safely')
            return nil
        end
        if not ExecuteSchemaChange('finalizing player_vehicles.stored',
            ('ALTER TABLE `player_vehicles` MODIFY COLUMN `stored` %s NOT NULL DEFAULT 1'):format(
                storedColumn.columnType
            )) then return nil end
    end
    local stateColumn = schema.columns.state
    if not stateColumn or not integerTypes[stateColumn.dataType] then
        SchemaFailure('verifying player_vehicles.state', 'an existing non-integer column cannot be migrated safely')
        return nil
    end
    if stateColumn.nullable or tonumber(stateColumn.default) ~= 1 then
        if not stateColumn.columnType:match('^[%w%(%) ,]+$') then
            SchemaFailure('verifying player_vehicles.state', 'the existing integer definition cannot be preserved safely')
            return nil
        end
        if not ExecuteSchemaChange('finalizing player_vehicles.state',
            ('ALTER TABLE `player_vehicles` MODIFY COLUMN `state` %s NOT NULL DEFAULT 1'):format(
                stateColumn.columnType
            )) then return nil end
    end

    local vehicleColumn = schema.columns.vehicle
    if vehicleColumn and vehicleColumn.dataType == 'varchar'
        and vehicleColumn.maximumLength and vehicleColumn.maximumLength < 64 then
        local characterSet = tostring(vehicleColumn.characterSet or '')
        local collation = tostring(vehicleColumn.collation or '')
        if not characterSet:match('^[%w_]+$') or not collation:match('^[%w_]+$') then
            SchemaFailure('widening player_vehicles.vehicle', 'unsafe or missing character metadata')
            return nil
        end
        local definition = ('VARCHAR(64) CHARACTER SET %s COLLATE %s %s'):format(
            characterSet, collation, vehicleColumn.nullable and 'NULL' or 'NOT NULL'
        )
        if vehicleColumn.default == nil then
            if vehicleColumn.nullable then definition = definition .. ' DEFAULT NULL' end
        else
            local default = tostring(vehicleColumn.default)
            if not default:match('^[%w _%.%-]*$') then
                SchemaFailure('widening player_vehicles.vehicle', 'the existing default cannot be preserved safely')
                return nil
            end
            definition = definition .. (" DEFAULT '%s'"):format(default:gsub("'", "''"))
        end
        if not ExecuteSchemaChange('widening player_vehicles.vehicle for addon model names',
            ('ALTER TABLE `player_vehicles` MODIFY COLUMN `vehicle` %s'):format(definition)) then return nil end
    end

    schema, inspectError = InspectTable('player_vehicles')
    if not schema then
        SchemaFailure('re-inspecting player_vehicles', inspectError)
        return nil
    end
    for _, required in ipairs(REQUIRED_VEHICLE_COLUMNS) do
        if not schema.columns[required] then
            SchemaFailure('verifying player_vehicles', ('required column %s is missing after migration'):format(required))
            return nil
        end
    end

    local plateColumn = schema.columns.plate
    if not plateColumn or (plateColumn.dataType ~= 'varchar' and plateColumn.dataType ~= 'char')
        or not tostring(plateColumn.characterSet or ''):match('^[%w_]+$')
        or not tostring(plateColumn.collation or ''):match('^[%w_]+$') then
        SchemaFailure('reading player_vehicles.plate collation',
            'plate must be a character column with a valid charset and collation')
        return nil
    end
    OwnershipTextCharset = tostring(plateColumn.characterSet):lower()
    OwnershipTextCollation = tostring(plateColumn.collation):lower()

    local indexed, refreshed = EnsureIndex('player_vehicles', schema,
        'idx_player_vehicles_citizenid_type_stored', { 'citizenid', 'type', 'stored' }, false)
    if not indexed then return nil end
    schema = refreshed or schema
    indexed, refreshed = EnsureIndex('player_vehicles', schema,
        'idx_player_vehicles_job_type_stored', { 'job', 'type', 'stored' }, false)
    if not indexed then return nil end
    schema = refreshed or schema

    PlayerVehicleColumns = {}
    for column in pairs(schema.columns) do PlayerVehicleColumns[column] = true end
    return PlayerVehicleColumns
end

local function DuplicateValue(tableName, columnName)
    local ok, duplicate = pcall(MySQL.single.await, ([[
        SELECT `%s` AS duplicate_value, COUNT(*) AS duplicate_count
        FROM `%s`
        WHERE `%s` IS NOT NULL
        GROUP BY `%s`
        HAVING COUNT(*) > 1
        LIMIT 1
    ]]):format(columnName, tableName, columnName, columnName), {})
    if not ok then return nil, duplicate end
    return duplicate, nil
end

local function EnsureUniqueIndex(tableName, schema, preferredName, columnName, description)
    if HasIndexSignature(schema, { columnName }, true) then return true, schema end
    local duplicate, duplicateError = DuplicateValue(tableName, columnName)
    if duplicateError then return SchemaFailure(('checking duplicate %s'):format(description), duplicateError) end
    if duplicate then
        print(('[drs_vehicleshop] Purchases disabled: duplicate %s "%s" exists %s times. ' ..
            'Resolve the duplicate rows manually; the automatic migration never deletes ownership or order data.'):format(
            description, tostring(SchemaValue(duplicate, 'duplicate_value')),
            tostring(SchemaValue(duplicate, 'duplicate_count'))
        ))
        return false
    end
    return EnsureIndex(tableName, schema, preferredName, { columnName }, true)
end

local function EnsureInternalTableColumns(tableName, schema, requiredColumns, additiveColumns)
    local rowCount = tonumber(MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`'):format(tableName))) or 0
    for _, column in ipairs(requiredColumns) do
        if not schema.columns[column] then
            if rowCount > 0 or not additiveColumns[column] then
                return SchemaFailure(('upgrading %s'):format(tableName),
                    ('required column %s is missing from a non-empty or incompatible table'):format(column))
            end
            if not AddColumn(tableName, column, additiveColumns[column]) then return false end
        end
    end
    return true
end

local function IndexMatches(index, expectedColumns, expectedUnique)
    if not index or index.unique ~= expectedUnique or #index.columns ~= #expectedColumns then return false end
    for position, expectedColumn in ipairs(expectedColumns) do
        local indexedColumn = index.columns[position]
        if not indexedColumn or indexedColumn.name ~= expectedColumn or indexedColumn.subPart ~= nil then
            return false
        end
    end
    return true
end

local function RenameLegacyJournalIndex(tableName, mapping)
    local schema, inspectError = InspectTable(tableName)
    if not schema then
        return SchemaFailure(('inspecting indexes on %s'):format(tableName), inspectError)
    end
    if not schema.exists then return true end

    local legacyIndex = schema.indexes[mapping.legacy]
    local currentIndex = schema.indexes[mapping.current]
    if legacyIndex and not IndexMatches(legacyIndex, mapping.columns, mapping.unique) then
        return SchemaFailure(('renaming legacy index %s'):format(mapping.legacy),
            'the existing index definition does not match the expected DRS journal schema')
    end
    if currentIndex and not IndexMatches(currentIndex, mapping.columns, mapping.unique) then
        return SchemaFailure(('verifying DRS index %s'):format(mapping.current),
            ('the existing index on %s does not match the expected journal schema'):format(tableName))
    end
    if not legacyIndex then return true end
    if currentIndex then
        if not ExecuteSchemaChange(
            ('removing duplicate legacy index %s from %s'):format(mapping.legacy, tableName),
            ('ALTER TABLE `%s` DROP INDEX `%s`'):format(tableName, mapping.legacy)
        ) then return false end
    else
        local renameStatement = ('ALTER TABLE `%s` RENAME INDEX `%s` TO `%s`'):format(
            tableName, mapping.legacy, mapping.current
        )
        local renamed = pcall(MySQL.query.await, renameStatement, {})
        if renamed then
            print(('[drs_vehicleshop] Database migration: renamed legacy index %s to %s.'):format(
                mapping.legacy, mapping.current
            ))
        else
            local quotedColumns = {}
            for position, columnName in ipairs(mapping.columns) do
                quotedColumns[position] = ('`%s`'):format(columnName)
            end
            local replacementStatement = ('ALTER TABLE `%s` ADD %sINDEX `%s` (%s)'):format(
                tableName,
                mapping.unique and 'UNIQUE ' or '',
                mapping.current,
                table.concat(quotedColumns, ', ')
            )
            if not ExecuteSchemaChange(
                ('creating DRS replacement index %s on %s'):format(mapping.current, tableName),
                replacementStatement
            ) then return false end

            local replacementSchema, replacementError = InspectTable(tableName)
            if not replacementSchema then
                return SchemaFailure(('verifying replacement index on %s'):format(tableName), replacementError)
            end
            if not IndexMatches(replacementSchema.indexes[mapping.legacy], mapping.columns, mapping.unique)
                or not IndexMatches(replacementSchema.indexes[mapping.current], mapping.columns, mapping.unique) then
                return SchemaFailure(('verifying replacement index on %s'):format(tableName),
                    'the old and new index definitions were not both present after the portable replacement step')
            end
            if not ExecuteSchemaChange(
                ('removing replaced legacy index %s from %s'):format(mapping.legacy, tableName),
                ('ALTER TABLE `%s` DROP INDEX `%s`'):format(tableName, mapping.legacy)
            ) then return false end
        end
    end

    schema, inspectError = InspectTable(tableName)
    if not schema then
        return SchemaFailure(('verifying renamed index on %s'):format(tableName), inspectError)
    end
    if schema.indexes[mapping.legacy] then
        return SchemaFailure(('verifying renamed index on %s'):format(tableName),
            ('legacy index %s still exists after migration'):format(mapping.legacy))
    end
    if not IndexMatches(schema.indexes[mapping.current], mapping.columns, mapping.unique) then
        return SchemaFailure(('verifying renamed index on %s'):format(tableName),
            ('DRS index %s is missing or has an unexpected definition'):format(mapping.current))
    end
    return true
end

local function EnsureJournalIdentity()
    if JournalIdentityReady then return true end

    local renameClauses = {}
    local previouslyLegacy = {}
    for position, mapping in ipairs(JOURNAL_TABLE_RENAMES) do
        local legacySchema, legacyError = InspectTable(mapping.legacy)
        if not legacySchema then
            return SchemaFailure(('inspecting legacy journal table %s'):format(mapping.legacy), legacyError)
        end
        local currentSchema, currentError = InspectTable(mapping.current)
        if not currentSchema then
            return SchemaFailure(('inspecting DRS journal table %s'):format(mapping.current), currentError)
        end
        if legacySchema.exists and currentSchema.exists then
            return SchemaFailure('renaming legacy vehicle-shop journal tables',
                ('both %s and %s exist; back up the database and resolve the collision manually. ' ..
                    'The automatic migration never merges or deletes financial journal data.'):format(
                    mapping.legacy, mapping.current
                ))
        end
        previouslyLegacy[position] = legacySchema.exists
        if legacySchema.exists then
            renameClauses[#renameClauses + 1] = ('`%s` TO `%s`'):format(mapping.legacy, mapping.current)
        end
    end

    if #renameClauses > 0 then
        if not ExecuteSchemaChange(
            'renaming legacy QR vehicle-shop journal tables to DRS',
            'RENAME TABLE ' .. table.concat(renameClauses, ', ')
        ) then return false end
    end

    for position, mapping in ipairs(JOURNAL_TABLE_RENAMES) do
        local legacySchema, legacyError = InspectTable(mapping.legacy)
        if not legacySchema then
            return SchemaFailure(('verifying legacy table removal for %s'):format(mapping.legacy), legacyError)
        end
        local currentSchema, currentError = InspectTable(mapping.current)
        if not currentSchema then
            return SchemaFailure(('verifying DRS journal table %s'):format(mapping.current), currentError)
        end
        if legacySchema.exists then
            return SchemaFailure('verifying vehicle-shop journal table rename',
                ('legacy table %s still exists after migration'):format(mapping.legacy))
        end
        if previouslyLegacy[position] and not currentSchema.exists then
            return SchemaFailure('verifying vehicle-shop journal table rename',
                ('DRS table %s is missing after migrating %s'):format(mapping.current, mapping.legacy))
        end
    end

    for _, tableMapping in ipairs(JOURNAL_INDEX_RENAMES) do
        for _, indexMapping in ipairs(tableMapping.indexes) do
            if not RenameLegacyJournalIndex(tableMapping.tableName, indexMapping) then return false end
        end
    end

    JournalIdentityReady = true
    return true
end

local function ValidateSchemaColumn(tableName, schema, columnName, options)
    local column = schema.columns[columnName]
    if not column then
        return SchemaFailure(('verifying %s'):format(tableName), ('column %s is missing'):format(columnName))
    end
    if options.types and not options.types[column.dataType] then
        return SchemaFailure(('verifying %s.%s'):format(tableName, columnName),
            ('unexpected type %s'):format(column.columnType or column.dataType))
    end
    if options.minimumLength and (not column.maximumLength or column.maximumLength < options.minimumLength) then
        return SchemaFailure(('verifying %s.%s'):format(tableName, columnName),
            ('length %s is below the required %s'):format(tostring(column.maximumLength), options.minimumLength))
    end
    if options.notNull and column.nullable then
        return SchemaFailure(('verifying %s.%s'):format(tableName, columnName), 'the column must be NOT NULL')
    end
    if options.autoIncrement and not column.extra:find('auto_increment', 1, true) then
        return SchemaFailure(('verifying %s.%s'):format(tableName, columnName), 'AUTO_INCREMENT is required')
    end
    if options.insertOptional and not column.nullable and column.default == nil then
        return SchemaFailure(('verifying %s.%s'):format(tableName, columnName),
            'the column is omitted by initial inserts and must be nullable or have a default')
    end
    if options.requiresDefault and column.default == nil then
        return SchemaFailure(('verifying %s.%s'):format(tableName, columnName),
            'a database default is required')
    end
    return true
end

local INTEGER_SCHEMA_TYPES = {
    tinyint = true, smallint = true, mediumint = true, int = true, integer = true, bigint = true
}
local STRING_SCHEMA_TYPES = { char = true, varchar = true }
local TEXT_SCHEMA_TYPES = { tinytext = true, text = true, mediumtext = true, longtext = true }
local TIME_SCHEMA_TYPES = { timestamp = true, datetime = true }

local function ValidateOrderSchema(schema)
    local checks = {
        { 'id', { types = INTEGER_SCHEMA_TYPES, notNull = true, autoIncrement = true } },
        { 'order_id', { types = STRING_SCHEMA_TYPES, minimumLength = 64, notNull = true } },
        { 'request_id', { types = STRING_SCHEMA_TYPES, minimumLength = 96 } },
        { 'citizenid', { types = STRING_SCHEMA_TYPES, minimumLength = 50, notNull = true } },
        { 'shop_id', { types = STRING_SCHEMA_TYPES, minimumLength = 50, notNull = true } },
        { 'model', { types = STRING_SCHEMA_TYPES, minimumLength = 64, notNull = true } },
        { 'vehicle_type', { types = STRING_SCHEMA_TYPES, minimumLength = 20 } },
        { 'delivery_mode', { types = STRING_SCHEMA_TYPES, minimumLength = 16 } },
        { 'plate', { types = STRING_SCHEMA_TYPES, minimumLength = 15, notNull = true } },
        { 'account', { types = STRING_SCHEMA_TYPES, minimumLength = 20, notNull = true } },
        { 'base_amount', { types = INTEGER_SCHEMA_TYPES, notNull = true } },
        { 'options_amount', { types = INTEGER_SCHEMA_TYPES, notNull = true } },
        { 'amount', { types = INTEGER_SCHEMA_TYPES, notNull = true } },
        { 'customization', { types = TEXT_SCHEMA_TYPES } },
        { 'status', { types = STRING_SCHEMA_TYPES, minimumLength = 32, notNull = true } },
        { 'vehicle_id', { types = INTEGER_SCHEMA_TYPES, insertOptional = true } },
        { 'net_id', { types = INTEGER_SCHEMA_TYPES, insertOptional = true } },
        { 'failure_reason', { types = { varchar = true, text = true }, minimumLength = 255, insertOptional = true } },
        { 'created_at', { types = TIME_SCHEMA_TYPES, notNull = true, requiresDefault = true } },
        { 'updated_at', { types = TIME_SCHEMA_TYPES, notNull = true, requiresDefault = true } }
    }
    for _, check in ipairs(checks) do
        if not ValidateSchemaColumn('drs_vehicle_shop_orders', schema, check[1], check[2]) then return false end
    end
    return true
end

local function ValidateReservationSchema(schema)
    local checks = {
        { 'plate', { types = STRING_SCHEMA_TYPES, minimumLength = 15, notNull = true } },
        { 'request_id', { types = STRING_SCHEMA_TYPES, minimumLength = 96, notNull = true } },
        { 'order_id', { types = STRING_SCHEMA_TYPES, minimumLength = 64, notNull = true } },
        { 'citizenid', { types = STRING_SCHEMA_TYPES, minimumLength = 50, notNull = true } },
        { 'created_at', { types = TIME_SCHEMA_TYPES, notNull = true, requiresDefault = true } }
    }
    for _, check in ipairs(checks) do
        if not ValidateSchemaColumn('drs_vehicle_shop_plate_reservations', schema, check[1], check[2]) then return false end
    end
    return true
end

local function EnsureOrderTable()
    if OrdersReady then return true end
    if not EnsureJournalIdentity() then return false end
    local schema, inspectError = InspectTable('drs_vehicle_shop_orders')
    if not schema then return SchemaFailure('inspecting the purchase journal', inspectError) end
    if not schema.exists then
        if not ExecuteSchemaChange('creating the purchase journal', [[
            CREATE TABLE IF NOT EXISTS drs_vehicle_shop_orders (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            order_id VARCHAR(64) NOT NULL,
            request_id VARCHAR(96) NULL,
            citizenid VARCHAR(50) NOT NULL,
            shop_id VARCHAR(50) NOT NULL,
            model VARCHAR(64) NOT NULL,
            vehicle_type VARCHAR(20) NULL,
            delivery_mode VARCHAR(16) NULL,
            plate VARCHAR(15) NOT NULL,
            account VARCHAR(20) NOT NULL,
            base_amount INT UNSIGNED NOT NULL DEFAULT 0,
            options_amount INT UNSIGNED NOT NULL DEFAULT 0,
            amount INT UNSIGNED NOT NULL,
            customization LONGTEXT NULL,
            status VARCHAR(32) NOT NULL,
            vehicle_id BIGINT NULL,
            net_id INT NULL,
            failure_reason VARCHAR(255) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]) then return false end
        schema, inspectError = InspectTable('drs_vehicle_shop_orders')
        if not schema then return SchemaFailure('inspecting the purchase journal', inspectError) end
    end
    local baseColumns = {
        'id', 'order_id', 'citizenid', 'shop_id', 'model', 'plate', 'account', 'amount',
        'status', 'vehicle_id', 'net_id', 'failure_reason', 'created_at', 'updated_at'
    }
    for _, column in ipairs(baseColumns) do
        if not schema.columns[column] then
            return SchemaFailure('upgrading the purchase journal',
                ('required historical column %s is missing; refusing to invent financial data'):format(column))
        end
    end
    local upgrades = {
        request_id = 'VARCHAR(96) NULL AFTER `order_id`',
        vehicle_type = 'VARCHAR(20) NULL AFTER `model`',
        delivery_mode = 'VARCHAR(16) NULL AFTER `vehicle_type`',
        base_amount = 'INT UNSIGNED NOT NULL DEFAULT 0 AFTER `account`',
        options_amount = 'INT UNSIGNED NOT NULL DEFAULT 0 AFTER `base_amount`',
        customization = 'LONGTEXT NULL AFTER `amount`'
    }
    for _, column in ipairs({ 'request_id', 'vehicle_type', 'delivery_mode', 'base_amount', 'options_amount', 'customization' }) do
        if not schema.columns[column] and not AddColumn('drs_vehicle_shop_orders', column, upgrades[column]) then return false end
    end

    schema, inspectError = InspectTable('drs_vehicle_shop_orders')
    if not schema then return SchemaFailure('re-inspecting the purchase journal', inspectError) end
    if not ValidateOrderSchema(schema) then return false end
    local engineOk, refreshed = EnsureInnoDB('drs_vehicle_shop_orders', schema)
    if not engineOk then return false end
    schema = refreshed or schema
    local collationOk
    collationOk, refreshed = EnsureTableTextCollation(
        'drs_vehicle_shop_orders', schema, OwnershipTextCharset, OwnershipTextCollation
    )
    if not collationOk then return false end
    schema = refreshed or schema
    if not ValidateOrderSchema(schema) then return false end
    local indexOk
    indexOk, refreshed = EnsureUniqueIndex('drs_vehicle_shop_orders', schema,
        'uk_drs_vehicle_shop_order_id', 'order_id', 'vehicle-shop order id')
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk, refreshed = EnsureUniqueIndex('drs_vehicle_shop_orders', schema,
        'uk_drs_vehicle_shop_request_id', 'request_id', 'checkout request id')
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk, refreshed = EnsureIndex('drs_vehicle_shop_orders', schema,
        'idx_drs_vehicle_shop_orders_citizen_status', { 'citizenid', 'status' }, false)
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk, refreshed = EnsureIndex('drs_vehicle_shop_orders', schema,
        'idx_drs_vehicle_shop_orders_plate', { 'plate' }, false)
    if not indexOk then return false end

    schema, inspectError = InspectTable('drs_vehicle_shop_plate_reservations')
    if not schema then return SchemaFailure('inspecting plate reservations', inspectError) end
    if not schema.exists then
        if not ExecuteSchemaChange('creating plate reservations', [[
            CREATE TABLE IF NOT EXISTS drs_vehicle_shop_plate_reservations (
            plate VARCHAR(15) NOT NULL,
            request_id VARCHAR(96) NOT NULL,
            order_id VARCHAR(64) NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (plate)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]) then return false end
        schema, inspectError = InspectTable('drs_vehicle_shop_plate_reservations')
    end
    if not schema then return SchemaFailure('inspecting plate reservations', inspectError) end
    local reservationDefinitions = {
        plate = "VARCHAR(15) NOT NULL DEFAULT ''", request_id = "VARCHAR(96) NOT NULL DEFAULT ''",
        order_id = "VARCHAR(64) NOT NULL DEFAULT ''", citizenid = "VARCHAR(50) NOT NULL DEFAULT ''",
        created_at = 'TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP'
    }
    if not EnsureInternalTableColumns('drs_vehicle_shop_plate_reservations', schema,
        { 'plate', 'request_id', 'order_id', 'citizenid', 'created_at' }, reservationDefinitions) then return false end
    schema, inspectError = InspectTable('drs_vehicle_shop_plate_reservations')
    if not schema then return SchemaFailure('re-inspecting plate reservations', inspectError) end
    if not ValidateReservationSchema(schema) then return false end
    engineOk, refreshed = EnsureInnoDB('drs_vehicle_shop_plate_reservations', schema)
    if not engineOk then return false end
    schema = refreshed or schema
    collationOk, refreshed = EnsureTableTextCollation(
        'drs_vehicle_shop_plate_reservations', schema, OwnershipTextCharset, OwnershipTextCollation
    )
    if not collationOk then return false end
    schema = refreshed or schema
    if not ValidateReservationSchema(schema) then return false end
    indexOk, refreshed = EnsureUniqueIndex('drs_vehicle_shop_plate_reservations', schema,
        'uk_drs_vehicle_shop_reservation_plate', 'plate', 'reserved plate')
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk, refreshed = EnsureUniqueIndex('drs_vehicle_shop_plate_reservations', schema,
        'uk_drs_vehicle_shop_reservation_request', 'request_id', 'reservation request id')
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk = EnsureUniqueIndex('drs_vehicle_shop_plate_reservations', schema,
        'uk_drs_vehicle_shop_reservation_order', 'order_id', 'reservation order id')
    if not indexOk then return false end

    OrdersReady = true
    return true
end

local function ValidateFleetOrderSchema(schema)
    local checks = {
        { 'id', { types = INTEGER_SCHEMA_TYPES, notNull = true, autoIncrement = true } },
        { 'order_id', { types = STRING_SCHEMA_TYPES, minimumLength = 64, notNull = true } },
        { 'request_id', { types = STRING_SCHEMA_TYPES, minimumLength = 96, notNull = true } },
        { 'caller_resource', { types = STRING_SCHEMA_TYPES, minimumLength = 64, notNull = true } },
        { 'actor_citizenid', { types = STRING_SCHEMA_TYPES, minimumLength = 50, notNull = true } },
        { 'actor_license', { types = STRING_SCHEMA_TYPES, minimumLength = 80, insertOptional = true } },
        { 'job', { types = STRING_SCHEMA_TYPES, minimumLength = 50, notNull = true } },
        { 'model', { types = STRING_SCHEMA_TYPES, minimumLength = 64, notNull = true } },
        { 'vehicle_type', { types = STRING_SCHEMA_TYPES, minimumLength = 20, notNull = true } },
        { 'garage_index', { types = INTEGER_SCHEMA_TYPES, notNull = true } },
        { 'minimum_grade', { types = INTEGER_SCHEMA_TYPES, notNull = true } },
        { 'account', { types = STRING_SCHEMA_TYPES, minimumLength = 64, notNull = true } },
        { 'bank_provider', { types = STRING_SCHEMA_TYPES, minimumLength = 32, notNull = true } },
        { 'amount', { types = INTEGER_SCHEMA_TYPES, notNull = true } },
        { 'purchase_reason', { types = STRING_SCHEMA_TYPES, minimumLength = 160, insertOptional = true } },
        { 'status', { types = STRING_SCHEMA_TYPES, minimumLength = 32, notNull = true } },
        { 'vehicle_id', { types = INTEGER_SCHEMA_TYPES, insertOptional = true } },
        { 'plate', { types = STRING_SCHEMA_TYPES, minimumLength = 15, insertOptional = true } },
        { 'garage_operation_id', { types = STRING_SCHEMA_TYPES, minimumLength = 96, insertOptional = true } },
        { 'failure_reason', { types = { varchar = true, text = true }, minimumLength = 255, insertOptional = true } },
        { 'created_at', { types = TIME_SCHEMA_TYPES, notNull = true, requiresDefault = true } },
        { 'updated_at', { types = TIME_SCHEMA_TYPES, notNull = true, requiresDefault = true } }
    }
    for _, check in ipairs(checks) do
        if not ValidateSchemaColumn('drs_vehicle_shop_fleet_orders', schema, check[1], check[2]) then return false end
    end
    return true
end

local function EnsureFleetOrderTable()
    if FleetOrdersReady then return true end
    local schema, inspectError = InspectTable('drs_vehicle_shop_fleet_orders')
    if not schema then return SchemaFailure('inspecting the fleet-purchase journal', inspectError) end
    if not schema.exists then
        if not ExecuteSchemaChange('creating the fleet-purchase journal', [[
            CREATE TABLE IF NOT EXISTS drs_vehicle_shop_fleet_orders (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            order_id VARCHAR(64) NOT NULL,
            request_id VARCHAR(96) NOT NULL,
            caller_resource VARCHAR(64) NOT NULL,
            actor_citizenid VARCHAR(50) NOT NULL,
            actor_license VARCHAR(80) NULL,
            job VARCHAR(50) NOT NULL,
            model VARCHAR(64) NOT NULL,
            vehicle_type VARCHAR(20) NOT NULL,
            garage_index INT UNSIGNED NOT NULL,
            minimum_grade INT UNSIGNED NOT NULL DEFAULT 0,
            account VARCHAR(64) NOT NULL,
            bank_provider VARCHAR(32) NOT NULL,
            amount INT UNSIGNED NOT NULL,
            purchase_reason VARCHAR(160) NULL,
            status VARCHAR(32) NOT NULL,
            vehicle_id BIGINT NULL,
            plate VARCHAR(15) NULL,
            garage_operation_id VARCHAR(96) NULL,
            failure_reason VARCHAR(255) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]) then return false end
        schema, inspectError = InspectTable('drs_vehicle_shop_fleet_orders')
    end
    if not schema then return SchemaFailure('re-inspecting the fleet-purchase journal', inspectError) end
    local historicalColumns = {
        'id', 'order_id', 'request_id', 'caller_resource', 'actor_citizenid', 'actor_license',
        'job', 'model', 'vehicle_type', 'garage_index', 'minimum_grade', 'account',
        'bank_provider', 'amount', 'status', 'vehicle_id', 'plate', 'garage_operation_id',
        'failure_reason', 'created_at', 'updated_at'
    }
    for _, column in ipairs(historicalColumns) do
        if not schema.columns[column] then
            return SchemaFailure('upgrading the fleet-purchase journal',
                ('required historical column %s is missing; refusing to invent financial data'):format(column))
        end
    end
    if not schema.columns.purchase_reason then
        if not AddColumn('drs_vehicle_shop_fleet_orders', 'purchase_reason',
            'VARCHAR(160) NULL AFTER `amount`') then return false end
        schema, inspectError = InspectTable('drs_vehicle_shop_fleet_orders')
        if not schema then return SchemaFailure('re-inspecting the fleet-purchase journal', inspectError) end
    end
    if not ValidateFleetOrderSchema(schema) then return false end

    local engineOk, refreshed = EnsureInnoDB('drs_vehicle_shop_fleet_orders', schema)
    if not engineOk then return false end
    schema = refreshed or schema
    local collationOk
    collationOk, refreshed = EnsureTableTextCollation(
        'drs_vehicle_shop_fleet_orders', schema, OwnershipTextCharset, OwnershipTextCollation
    )
    if not collationOk then return false end
    schema = refreshed or schema
    if not ValidateFleetOrderSchema(schema) then return false end

    local indexOk
    indexOk, refreshed = EnsureUniqueIndex('drs_vehicle_shop_fleet_orders', schema,
        'uk_drs_vehicle_shop_fleet_order_id', 'order_id', 'fleet order id')
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk, refreshed = EnsureUniqueIndex('drs_vehicle_shop_fleet_orders', schema,
        'uk_drs_vehicle_shop_fleet_request_id', 'request_id', 'fleet request id')
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk, refreshed = EnsureIndex('drs_vehicle_shop_fleet_orders', schema,
        'idx_drs_vehicle_shop_fleet_job_status', { 'job', 'status' }, false)
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk, refreshed = EnsureIndex('drs_vehicle_shop_fleet_orders', schema,
        'idx_drs_vehicle_shop_fleet_actor_status', { 'actor_citizenid', 'status' }, false)
    if not indexOk then return false end
    schema = refreshed or schema
    indexOk = EnsureIndex('drs_vehicle_shop_fleet_orders', schema,
        'idx_drs_vehicle_shop_fleet_plate', { 'plate' }, false)
    if not indexOk then return false end

    FleetOrdersReady = true
    return true
end

local function EnsureUniquePlateConstraint()
    local schema, inspectError = InspectTable('player_vehicles')
    if not schema then return SchemaFailure('inspecting the vehicle plate index', inspectError) end
    local indexed = EnsureUniqueIndex('player_vehicles', schema,
        'uk_player_vehicles_plate', 'plate', 'vehicle plate')
    return indexed == true
end

local function EnsureServiceReady()
    if ServiceReady then return true end
    if not GetFramework() then return false, 'framework_unavailable' end
    if not EnsurePlayerVehicleSchema() then return false, 'schema_unavailable' end
    if not EnsureUniquePlateConstraint() then return false, 'plate_constraint_unavailable' end
    if not EnsureOrderTable() then return false, 'journal_unavailable' end
    return true
end

local function NewOrderId(src)
    return ('%s-%s-%06d'):format(os.time(), src, math.random(0, 999999))
end

local function ReleasePlateReservation(orderId)
    if not orderId then return false end
    local ok, deleted = pcall(
        MySQL.update.await,
        'DELETE FROM drs_vehicle_shop_plate_reservations WHERE order_id = ?',
        { orderId }
    )
    if not ok then
        print(('[drs_vehicleshop] Could not release the plate reservation for order %s: %s'):format(
            tostring(orderId), tostring(deleted)
        ))
        return false
    end
    return true
end

local function GetOrderByRequest(requestId)
    if type(requestId) ~= 'string' then return nil end
    local ok, row = pcall(MySQL.single.await, [[
        SELECT order_id, request_id, citizenid, shop_id, model, vehicle_type,
               delivery_mode, plate, account, base_amount, options_amount, amount,
               customization, status, vehicle_id, net_id, failure_reason
        FROM drs_vehicle_shop_orders
        WHERE request_id = ?
        LIMIT 1
    ]], { requestId })
    return ok and row or nil
end

local function GetUnresolvedOrder(citizenid)
    if type(citizenid) ~= 'string' or citizenid == '' then return nil, 'invalid_identity' end
    local ok, row = pcall(MySQL.single.await, [[
        SELECT order_id, status, model, plate, amount
        FROM drs_vehicle_shop_orders
        WHERE citizenid = ?
          AND status NOT IN ('stored', 'delivered', 'refunded', 'cancelled', 'payment_failed')
        ORDER BY id ASC
        LIMIT 1
    ]], { citizenid })
    if not ok then return nil, 'guard_unavailable' end
    return row
end

local function CreateOrderAndReserve(src, data, quoteId, resolvedShopId, model, account, resolved)
    local attempts = math.max(5, tonumber(Config.PlateGenerationAttempts) or 25)
    local prefix = resolved.selection.plateMode == 'prefix' and resolved.selection.platePrefix or nil
    local customizationJson = json.encode(resolved.customization)

    for _ = 1, attempts do
        local plate = BuildPlateCandidate(prefix)
        if plate and not PlateExists(plate) then
            local orderId = NewOrderId(src)
            local transactionOk, committed = pcall(MySQL.transaction.await, {
                {
                    query = [[
                        INSERT INTO drs_vehicle_shop_plate_reservations
                            (plate, request_id, order_id, citizenid)
                        VALUES (?, ?, ?, ?)
                    ]],
                    values = { plate, quoteId, orderId, data.citizenid }
                },
                {
                    query = [[
                        INSERT INTO drs_vehicle_shop_orders
                            (order_id, request_id, citizenid, shop_id, model, vehicle_type,
                             delivery_mode, plate, account, base_amount, options_amount,
                             amount, customization, status)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
                    ]],
                    values = {
                        orderId, quoteId, data.citizenid, resolvedShopId, model,
                        resolved.vehicleType, resolved.selection.deliveryMode, plate, account,
                        resolved.basePrice, resolved.optionPrice, resolved.totalPrice,
                        customizationJson
                    }
                }
            })

            if transactionOk and committed == true then return orderId, plate end

            local existing = GetOrderByRequest(quoteId)
            if existing then
                local exactPending = existing.citizenid == data.citizenid
                    and tostring(existing.model):lower() == model
                    and tostring(existing.shop_id) == tostring(resolvedShopId)
                    and existing.status == 'pending'
                    and tonumber(existing.amount) == tonumber(resolved.totalPrice)
                if exactPending then
                    local cancelOk, cancelled = pcall(MySQL.update.await, [[
                            UPDATE drs_vehicle_shop_orders
                            SET status = 'cancelled', failure_reason = 'reservation_commit_response_unknown'
                            WHERE order_id = ? AND request_id = ? AND status = 'pending'
                        ]], { existing.order_id, quoteId })
                    if cancelOk and cancelled == 1 then
                        ReleasePlateReservation(existing.order_id)
                        return nil, nil, 'quote_retry', existing
                    end
                end
                return nil, nil, 'duplicate_request', existing
            end
        end
    end

    return nil, nil, 'reservation_failed'
end

local function UpdateOrder(orderId, status, fields)
    fields = fields or {}
    if fields.reason ~= nil then fields.reason = tostring(fields.reason):sub(1, 255) end

    local assignments = { 'status = ?' }
    local params = { status }
    if fields.vehicleId ~= nil then
        assignments[#assignments + 1] = 'vehicle_id = ?'
        params[#params + 1] = fields.vehicleId
    end
    if fields.netId ~= nil then
        assignments[#assignments + 1] = 'net_id = ?'
        params[#params + 1] = fields.netId
    end
    if fields.reason ~= nil then
        assignments[#assignments + 1] = 'failure_reason = ?'
        params[#params + 1] = fields.reason
    elseif status == 'delivered' or status == 'refunded' then
        assignments[#assignments + 1] = 'failure_reason = NULL'
    end
    params[#params + 1] = orderId

    local query = ('UPDATE drs_vehicle_shop_orders SET %s WHERE order_id = ?'):format(
        table.concat(assignments, ', ')
    )
    local ok, changed = pcall(MySQL.update.await, query, params)

    if not ok then
        print(('[drs_vehicleshop] Failed to update order %s to %s: %s'):format(
            tostring(orderId), tostring(status), tostring(changed)
        ))
        return false
    end

    if changed and changed > 0 then return true end

    local readOk, row = pcall(MySQL.single.await, [[
        SELECT status, vehicle_id, net_id, failure_reason
        FROM drs_vehicle_shop_orders
        WHERE order_id = ?
        LIMIT 1
    ]], { orderId })

    if not readOk or not row or row.status ~= status then return false end
    if fields.vehicleId and tonumber(row.vehicle_id) ~= tonumber(fields.vehicleId) then return false end
    if fields.netId and tonumber(row.net_id) ~= tonumber(fields.netId) then return false end
    if fields.reason ~= nil and tostring(row.failure_reason or '') ~= tostring(fields.reason) then return false end
    return true
end

local function GetDefaultGarage(vehicleType, shop)
    if shop and (shop.garage or shop.defaultGarage) then
        return shop.garage or shop.defaultGarage
    end

    if type(Config.DefaultGarages) == 'table' and Config.DefaultGarages[vehicleType] then
        return Config.DefaultGarages[vehicleType]
    end

    return Config.DefaultGarage or 'pillboxgarage'
end

local function TrustedProps(model, plate, customization)
    local props = {
        model = joaat(model),
        plate = plate,
        fuelLevel = 100.0,
        engineHealth = 1000.0,
        bodyHealth = 1000.0,
        dirtLevel = 0.0
    }
    if type(customization) == 'table' then
        props.color1 = tonumber(customization.primaryColor)
        props.color2 = tonumber(customization.secondaryColor)
        props.plateIndex = tonumber(customization.plateIndex) or 0
    end
    return props
end

local function UpdateVehicleCompatibility(vehicleId, data, model, plate, vehicleType, garage, props)
    local ok, row = pcall(function()
        MySQL.update.await([[
            UPDATE player_vehicles
            SET vehicle = ?, hash = ?, mods = ?, plate = ?, garage = ?,
                state = 1, stored = 1, type = ?, fuel = 100, engine = 1000, body = 1000
            WHERE id = ? AND citizenid = ?
        ]], {
            model, joaat(model), json.encode(props), plate, garage,
            vehicleType, vehicleId, data.citizenid
        })

        local saved = MySQL.single.await([[
            SELECT id, citizenid, vehicle, hash, mods, plate, garage, state, stored, type,
                   fuel, engine, body
            FROM player_vehicles
            WHERE id = ? AND citizenid = ?
            LIMIT 1
        ]], {
            vehicleId, data.citizenid
        })

        if not saved then return nil end

        local propsOk, savedProps = pcall(json.decode, saved.mods or '{}')
        if not propsOk or type(savedProps) ~= 'table' then return nil end
        local expectedHash = joaat(model) % 4294967296
        local storedHash = tonumber(saved.hash)
        local propsHash = tonumber(savedProps.model)
        storedHash = storedHash and (storedHash % 4294967296) or nil
        propsHash = propsHash and (propsHash % 4294967296) or nil

        if saved.citizenid ~= data.citizenid
            or NormalizePlate(saved.plate) ~= plate
            or tostring(saved.vehicle or ''):lower() ~= model
            or storedHash ~= expectedHash
            or propsHash ~= expectedHash
            or NormalizePlate(savedProps.plate) ~= plate
            or (props.color1 ~= nil and tonumber(savedProps.color1) ~= tonumber(props.color1))
            or (props.color2 ~= nil and tonumber(savedProps.color2) ~= tonumber(props.color2))
            or (props.plateIndex ~= nil and tonumber(savedProps.plateIndex) ~= tonumber(props.plateIndex))
            or saved.garage ~= garage
            or DatabaseInteger(saved.state) ~= 1
            or DatabaseInteger(saved.stored) ~= 1
            or saved.type ~= vehicleType
            or tonumber(saved.fuel) ~= 100
            or tonumber(saved.engine) ~= 1000
            or tonumber(saved.body) ~= 1000 then
            return nil
        end

        return saved
    end)

    if not ok then
        print(('[drs_vehicleshop] Failed to stage Qbox vehicle %s: %s'):format(
            tostring(vehicleId), tostring(row)
        ))
        return nil
    end

    return row
end

local function CreateOwnedVehicle(data, model, plate, vehicleType, garage, props)
    local function reconcileCreationResponse()
        local lookupOk, row = pcall(MySQL.single.await, [[
            SELECT id
            FROM player_vehicles
            WHERE citizenid = ? AND plate = ?
            LIMIT 1
        ]], { data.citizenid, plate })

        if not lookupOk then return nil, true end
        return row and tonumber(row.id) or nil, false
    end

    if GetFramework() == 'qbox' then
        if GetResourceState('qbx_vehicles') ~= 'started' then
            return nil, 'qbx_vehicles_not_started'
        end

        local ok, vehicleId, errorResult = pcall(function()
            return exports.qbx_vehicles:CreatePlayerVehicle({
                model = model,
                citizenid = data.citizenid,
                garage = garage,
                props = props
            })
        end)

        if not ok or not vehicleId then
            local reason = type(errorResult) == 'table' and (errorResult.code or errorResult.message) or errorResult
            reason = tostring(reason or vehicleId or 'qbx_vehicle_creation_failed')
            local recoveredId, lookupAmbiguous = reconcileCreationResponse()

            if lookupAmbiguous then
                return nil, ('ownership_lookup_failed:%s'):format(reason), true
            elseif recoveredId then
                -- A row found after an ambiguous export response remains a review case.
                -- Do not rewrite it before its origin can be proven; startup recovery
                -- will safely reconcile the journal and ownership row.
                return recoveredId, ('creation_response_unknown:%s'):format(reason), false
            end

            if not ok then
                return nil, ('creation_result_unknown:%s'):format(reason), true
            end

            return nil, reason, false
        end

        local row = UpdateVehicleCompatibility(vehicleId, data, model, plate, vehicleType, garage, props)
        if not row then
            -- CreatePlayerVehicle returned an id, so ownership may already exist even if the
            -- compatibility read-back failed. Never refund this ambiguous case; retain it as
            -- an owned/stored record for recovery instead of risking a free orphan vehicle.
            return tonumber(vehicleId), 'vehicle_compatibility_update_failed'
        end

        return tonumber(vehicleId), nil
    end

    local ok, vehicleId = pcall(MySQL.insert.await, [[
        INSERT INTO player_vehicles
            (license, citizenid, vehicle, hash, mods, plate, garage, state, stored, type, job, fuel, engine, body)
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1, ?, NULL, 100, 1000, 1000)
    ]], {
        data.license, data.citizenid, model, joaat(model), json.encode(props),
        plate, garage, vehicleType
    })

    if not ok or not vehicleId then
        local reason = tostring(vehicleId or 'vehicle_insert_failed')
        local recoveredId, lookupAmbiguous = reconcileCreationResponse()
        if lookupAmbiguous then return nil, ('ownership_lookup_failed:%s'):format(reason), true end
        if recoveredId then return recoveredId, ('creation_response_unknown:%s'):format(reason), false end
        if not ok then return nil, ('creation_result_unknown:%s'):format(reason), true end
        return nil, reason, false
    end

    return tonumber(vehicleId), nil
end

local function SetVehicleStored(data, plate, stored, garage)
    stored = stored and 1 or 0
    local ok, changed = pcall(MySQL.update.await, [[
            UPDATE player_vehicles
            SET stored = ?, state = ?, garage = ?
            WHERE citizenid = ? AND plate = ?
        ]], {
            stored, stored, garage, data.citizenid, plate
        })

    if not ok then
        print(('[drs_vehicleshop] Failed to update storage state for %s: %s'):format(plate, tostring(changed)))
    end

    if ok and changed and changed > 0 then return true end

    local queryOk, exists = pcall(
        MySQL.scalar.await,
        'SELECT 1 FROM player_vehicles WHERE citizenid = ? AND plate = ? AND stored = ? AND state = ? LIMIT 1',
        { data.citizenid, plate, stored, stored }
    )

    if queryOk and exists ~= nil then return true end
    return false, queryOk and 'state_mismatch' or 'state_unknown'
end

local function IsSpawnClear(coords, radius, bucket)
    radius = tonumber(radius) or 4.0
    if radius <= 0 then return true end

    for _, entity in ipairs(GetAllVehicles()) do
        if DoesEntityExist(entity) and (bucket == nil or GetEntityRoutingBucket(entity) == bucket) then
            if #(GetEntityCoords(entity) - vector3(coords.x, coords.y, coords.z)) <= radius then
                return false
            end
        end
    end

    return true
end

local function DeleteServerVehicle(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return true end

    if GetResourceState('qbx_core') == 'started' then
        pcall(function()
            exports.qbx_core:DeleteVehicle(entity)
        end)
    end

    local deadline = GetGameTimer() + 2000
    repeat
        if not DoesEntityExist(entity) then return true end
        pcall(DeleteEntity, entity)
        Wait(25)
    until GetGameTimer() >= deadline

    return not DoesEntityExist(entity)
end

local function CreateServerVehicle(model, serverType, coords, plate, bucket, vehicleId, props)
    if not coords or not coords.x or not coords.y or not coords.z then
        return nil, nil, 'missing_spawn_coords'
    end

    local entity = CreateVehicleServerSetter(
        joaat(model),
        serverType,
        coords.x + 0.0,
        coords.y + 0.0,
        coords.z + 0.0,
        tonumber(coords.w or coords.heading) or 0.0
    )

    if not entity or entity == 0 then return nil, nil, 'spawn_failed' end

    local setupOk, setupError = pcall(function()
        if bucket then SetEntityRoutingBucket(entity, bucket) end
        SetEntityHeading(entity, tonumber(coords.w or coords.heading) or 0.0)
        SetVehicleNumberPlateText(entity, plate)
        if props and props.color1 ~= nil and props.color2 ~= nil and type(SetVehicleColours) == 'function' then
            SetVehicleColours(entity, props.color1, props.color2)
        end
        if props and props.plateIndex ~= nil and type(SetVehicleNumberPlateTextIndex) == 'function' then
            SetVehicleNumberPlateTextIndex(entity, props.plateIndex)
        end
        SetVehicleDoorsLocked(entity, 1)
    end)

    if not setupOk then
        local deleted = DeleteServerVehicle(entity)
        local cleanupEntity = not deleted and entity or nil
        return nil, nil, ('spawn_setup_failed:%s'):format(tostring(setupError)), cleanupEntity
    end

    local deadline = GetGameTimer() + (tonumber(Config.ServerSpawnTimeout) or 5000)
    local netId = 0

    while GetGameTimer() < deadline do
        if DoesEntityExist(entity) then
            netId = NetworkGetNetworkIdFromEntity(entity)
            if netId and netId > 0 and NormalizePlate(GetVehicleNumberPlateText(entity)) == plate then
                break
            end
        end
        Wait(25)
    end

    if not DoesEntityExist(entity) or not netId or netId <= 0 then
        local cleanupEntity = DoesEntityExist(entity) and entity or nil
        local deleted = DeleteServerVehicle(cleanupEntity)
        cleanupEntity = not deleted and cleanupEntity or nil
        return nil, nil, 'network_registration_failed', cleanupEntity
    end

    local stateOk, stateError = pcall(function()
        Entity(entity).state:set('drsVehicleShopInit', {
            model = joaat(model),
            plate = plate,
            fuelLevel = 100.0,
            engineHealth = 1000.0,
            bodyHealth = 1000.0,
            dirtLevel = 0.0,
            color1 = props and props.color1 or nil,
            color2 = props and props.color2 or nil,
            plateIndex = props and props.plateIndex or nil
        }, true)
        if vehicleId then Entity(entity).state:set('vehicleid', vehicleId, false) end
        if not vehicleId then Entity(entity).state:set('drsVehicleShopTest', true, false) end
    end)
    if not stateOk then
        local deleted = DeleteServerVehicle(entity)
        local cleanupEntity = not deleted and entity or nil
        return nil, nil, ('state_setup_failed:%s'):format(tostring(stateError)), cleanupEntity
    end
    pcall(SetEntityOrphanMode, entity, 2)

    return entity, netId, nil
end

local function CleanupOrphanedTestVehicles()
    local removed = 0
    local failed = 0

    for _, entity in ipairs(GetAllVehicles()) do
        if entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 2 then
            local isShopTest
            local vehicleId
            pcall(function()
                local entityState = Entity(entity).state
                isShopTest = entityState.drsVehicleShopTest == true
                    or entityState.qrVehicleShopTest == true
                vehicleId = entityState.vehicleid
            end)

            local plate = NormalizePlate(GetVehicleNumberPlateText(entity))
            if isShopTest and not vehicleId and plate and plate:match('^TEST%d%d%d%d$') then
                if DeleteServerVehicle(entity) then removed = removed + 1 else failed = failed + 1 end
            end
        end
    end

    if removed > 0 or failed > 0 then
        print(('[drs_vehicleshop] Startup test-vehicle cleanup removed %s orphan(s); %s deletion(s) need retry.'):format(
            removed, failed
        ))
    end
end

local function GetStartedGarageResource()
    if GetResourceState('drs_garages') == 'started' then return 'drs_garages' end
    if GetResourceState('lunar_garage') == 'started' then return 'lunar_garage' end
end

local function RegisterWithGarage(src, plate, netId)
    local integration = tostring(Config.GarageIntegration or 'drs'):lower()
    local garageResource = GetStartedGarageResource()

    if integration == 'none' then return true, 'disabled' end
    if integration == 'auto' and not garageResource then return true, 'not_running' end
    if not garageResource then return false, 'garage_resource_not_started' end

    local ok, registered, reason = pcall(function()
        return exports[garageResource]:RegisterActiveVehicle(src, plate, netId)
    end)

    if not ok then return false, tostring(registered), garageResource end
    return registered == true, reason, garageResource
end

local function UnregisterWithGarage(plate, netId, registeredResource)
    local garageResource = registeredResource or GetStartedGarageResource()
    if not garageResource or GetResourceState(garageResource) ~= 'started' then return end
    pcall(function()
        exports[garageResource]:UnregisterActiveVehicle(plate, netId)
    end)
end

-- noir: o mri_Qcarkeys (provide qbx_vehiclekeys) nao entrega chave de carro com dono pelo
-- GiveKeys; a chave definitiva e um item que sai so pelo export GivePermanentKey, o mesmo que o
-- qbx_garages usa. Idempotente: nao duplica se o jogador ja tem a chave desta placa.
local function GivePermanentKey(src, plate)
    if GetResourceState('mri_Qcarkeys') ~= 'started' then return nil end
    local ok, given = pcall(function()
        return exports.mri_Qcarkeys:GivePermanentKey(src, plate)
    end)
    return ok and given == true
end

local function GiveVehicleKeys(src, entity, plate, temporary)
    local configured = tostring(Config.KeySystem or 'auto'):lower()
    if configured == 'none' then return true end

    if not temporary then
        local given = GivePermanentKey(src, plate)
        if given ~= nil then return given end
    end

    if configured == 'qbx_vehiclekeys' or (configured == 'auto' and GetResourceState('qbx_vehiclekeys') == 'started') then
        if GetResourceState('qbx_vehiclekeys') ~= 'started' then return false end
        return pcall(function()
            exports.qbx_vehiclekeys:GiveKeys(src, entity, temporary == true)
        end)
    end

    if configured == 'qb-vehiclekeys' or (configured == 'auto' and GetResourceState('qb-vehiclekeys') == 'started') then
        if GetResourceState('qb-vehiclekeys') ~= 'started' then return false end
        TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate)
        return true
    end

    return false
end

local function RemoveTemporaryKeys(src, entity)
    if GetResourceState('qbx_vehiclekeys') ~= 'started' then return end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    pcall(function()
        exports.qbx_vehiclekeys:RemoveKeys(src, entity, true)
    end)
end

local function CleanupTestDriveEntity(src, session)
    if not session or session.entityCleaned then return end
    session.entityCleaned = true
    RemoveTemporaryKeys(src, session.entity)
    DeleteServerVehicle(session.entity)
end

local function FinalizeTestDrive(src, session, teleportPlayer)
    if not session or TestDrives[src] ~= session then return false end

    TestDrives[src] = nil
    local cooldown = tonumber((Config.TestDrive and Config.TestDrive.cooldown) or Config.TestDriveCooldown) or 30
    TestDriveCooldowns[src] = os.time() + math.max(0, cooldown)
    CleanupTestDriveEntity(src, session)

    if teleportPlayer and session.returnCoords and PlayerIdentityMatches(src, session.citizenid) then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            SetEntityCoords(
                ped,
                session.returnCoords.x + 0.0,
                session.returnCoords.y + 0.0,
                session.returnCoords.z + 0.0,
                false, false, false, false
            )
        end
    end

    return true
end

local function EndTestDrive(src, reason, expectedSession, clientReturned)
    local session = TestDrives[src]
    if not session or (expectedSession and session.id ~= expectedSession) then return false end

    reason = tostring(reason or 'server_request')
    local lifecycleEnd = reason == 'resource_stopped'
        or reason == 'player_dropped'
        or reason == 'player_unloaded'

    if session.returning then
        if lifecycleEnd then
            return FinalizeTestDrive(src, session, false)
        end
        if clientReturned ~= true then return true end

        local returned = PlayerIdentityMatches(src, session.citizenid)
        local ped = returned and GetPlayerPed(src) or 0
        returned = returned and ped and ped ~= 0 and DoesEntityExist(ped)
            and #(GetEntityCoords(ped) - session.returnCoords) <= 15.0

        return FinalizeTestDrive(src, session, not returned)
    end

    if lifecycleEnd then
        return FinalizeTestDrive(src, session, false)
    end

    if clientReturned == true then
        local returned = PlayerIdentityMatches(src, session.citizenid)
        local ped = returned and GetPlayerPed(src) or 0
        returned = returned and ped and ped ~= 0 and DoesEntityExist(ped)
            and session.returnCoords
            and #(GetEntityCoords(ped) - session.returnCoords) <= 15.0

        return FinalizeTestDrive(src, session, not returned)
    end

    local canRequestClientReturn = session.ready == true
        and session.returnCoords
        and PlayerIdentityMatches(src, session.citizenid)

    if not canRequestClientReturn then
        return FinalizeTestDrive(src, session, true)
    end

    session.returning = true
    session.returnReason = reason
    TriggerClientEvent('drs_vehicleshop:client:endTestDrive', src, reason, session.id)

    local fallbackDelay = math.max(2000, math.min(
        30000,
        math.floor(tonumber(Config.TestDrive and Config.TestDrive.returnFallbackTimeout) or 8000)
    ))

    SetTimeout(fallbackDelay, function()
        if TestDrives[src] ~= session or session.returning ~= true then return end
        FinalizeTestDrive(src, session, true)
    end)

    return true
end

local function TrustedPropsFromJournal(order)
    if not order or type(order.model) ~= 'string' or #order.model < 1 or #order.model > 64
        or not order.model:match('^[%w_%-]+$') or not NormalizePlate(order.plate) then
        return nil, 'vehicle_identity_invalid'
    end
    local raw = order and order.customization
    if raw == nil or raw == '' then
        -- Orders created before factory checkout had no configurable paint/style.
        return TrustedProps(order.model, NormalizePlate(order.plate))
    end
    if type(raw) ~= 'string' or #raw > 8192 then return nil, 'customization_payload_invalid' end

    local decodedOk, customization = pcall(json.decode, raw)
    if not decodedOk or type(customization) ~= 'table' then return nil, 'customization_json_invalid' end
    local hasPrimary = customization.primaryColor ~= nil
    local hasSecondary = customization.secondaryColor ~= nil
    local primary = tonumber(customization.primaryColor)
    local secondary = tonumber(customization.secondaryColor)
    local plateIndex = tonumber(customization.plateIndex)
    if hasPrimary ~= hasSecondary
        or (hasPrimary and (not primary or primary % 1 ~= 0 or primary < 0 or primary > 160))
        or (hasSecondary and (not secondary or secondary % 1 ~= 0 or secondary < 0 or secondary > 160))
        or not plateIndex or plateIndex % 1 ~= 0 or plateIndex < 0 or plateIndex > 5
        or (customization.deliveryMode ~= 'driveaway' and customization.deliveryMode ~= 'garage') then
        return nil, 'customization_values_invalid'
    end

    return TrustedProps(order.model, NormalizePlate(order.plate), {
        primaryColor = hasPrimary and primary or nil,
        secondaryColor = hasSecondary and secondary or nil,
        plateIndex = plateIndex
    })
end

local function QuarantineOwnedRow(vehicleId, citizenid)
    local changed = MySQL.update.await([[
        UPDATE player_vehicles SET stored = 0, state = 0
        WHERE id = ? AND citizenid = ?
    ]], { vehicleId, citizenid })
    if changed and changed > 0 then return true end
    return MySQL.scalar.await([[
        SELECT 1 FROM player_vehicles
        WHERE id = ? AND citizenid = ? AND stored = 0 AND state = 0
        LIMIT 1
    ]], { vehicleId, citizenid }) ~= nil
end

local function ReconcileOrders()
    if not OrdersReady then return end

    -- Ownership rows and conclusive pre-ownership terminals no longer need a
    -- reservation. Ambiguous payment/ownership/refund states deliberately keep it.
    MySQL.update.await([[
        DELETE reservation
        FROM drs_vehicle_shop_plate_reservations reservation
        INNER JOIN drs_vehicle_shop_orders purchase ON purchase.order_id = reservation.order_id
        LEFT JOIN player_vehicles owned ON owned.plate = reservation.plate
        WHERE owned.id IS NOT NULL
           OR purchase.status IN ('cancelled', 'payment_failed', 'refunded')
    ]], {})

    local rows = MySQL.query.await([[
        SELECT order_id, citizenid, model, vehicle_type, plate, vehicle_id, net_id,
               customization, status
        FROM drs_vehicle_shop_orders
        WHERE status IN (
            'pending', 'debiting', 'payment_processing', 'debited',
            'vehicle_created', 'delivering', 'delivery_spawning', 'delivery_spawned', 'out_pending_registration',
            'handoff_pending', 'ack_finalizing', 'rollback_finalizing', 'delivery_review',
            'refund_due', 'refund_processing'
        )
    ]]) or {}

    for _, order in ipairs(rows) do
        if order.status == 'pending' then
            if UpdateOrder(order.order_id, 'cancelled', { reason = 'resource_restart_before_debit' }) then
                ReleasePlateReservation(order.order_id)
            end
        elseif order.status == 'debiting' or order.status == 'payment_processing' then
            -- The framework money export and this SQL journal cannot share a transaction.
            -- Never auto-credit an order when a crash made the debit result unknowable.
            UpdateOrder(order.order_id, 'payment_review', { reason = 'restart_during_payment' })
        elseif order.status == 'refund_processing' then
            -- Likewise, a crash may have happened after AddMoney but before the final status write.
            -- Holding for review prevents an automatic duplicate credit.
            UpdateOrder(order.order_id, 'refund_review', { reason = 'restart_during_refund' })
        elseif order.status ~= 'refund_due' then
            local owned = MySQL.single.await(
                'SELECT id, garage, type FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1',
                { order.citizenid, order.plate }
            )

            if owned then
                ReleasePlateReservation(order.order_id)
                local recoveryProps, customizationError = TrustedPropsFromJournal(order)
                if not tonumber(owned.id) or type(owned.garage) ~= 'string' or owned.garage == '' then
                    recoveryProps, customizationError = nil, 'ownership_row_invalid'
                end
                if not recoveryProps then
                    if not QuarantineOwnedRow(owned.id, order.citizenid) then
                        error(('unable to quarantine order %s after invalid customization'):format(order.order_id))
                    end
                    UpdateOrder(order.order_id, 'delivery_review', {
                        reason = ('restart_%s'):format(customizationError or 'customization_unavailable')
                    })
                else
                    -- Hold the row out of every garage before touching a possibly
                    -- persistent entity. It only becomes stored after all exact
                    -- entity matches are confirmed absent.
                    local changed = MySQL.update.await(
                        'UPDATE player_vehicles SET stored = 0, state = 0 WHERE citizenid = ? AND plate = ?',
                        { order.citizenid, order.plate }
                    )
                    local heldOut = changed and changed > 0 or MySQL.scalar.await([[
                        SELECT 1 FROM player_vehicles
                        WHERE citizenid = ? AND plate = ? AND stored = 0 AND state = 0
                        LIMIT 1
                    ]], { order.citizenid, order.plate }) ~= nil

                    if heldOut then
                        local expectedPlate = NormalizePlate(order.plate)
                        local expectedModel = joaat(order.model) % 4294967296
                        local allDeleted = true
                        local modelMismatch = false
                        for _, entity in ipairs(GetAllVehicles()) do
                            if entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 2 then
                                local stateVehicleId
                                pcall(function() stateVehicleId = tonumber(Entity(entity).state.vehicleid) end)
                                local identityMatches = NormalizePlate(GetVehicleNumberPlateText(entity)) == expectedPlate
                                    or (order.vehicle_id and stateVehicleId == tonumber(order.vehicle_id))

                                local actualModel = GetEntityModel(entity) % 4294967296
                                if identityMatches and actualModel == expectedModel then
                                    local netId = NetworkGetNetworkIdFromEntity(entity)
                                    if DeleteServerVehicle(entity) then
                                        UnregisterWithGarage(expectedPlate, netId and netId > 0 and netId or nil)
                                    else
                                        allDeleted = false
                                        pcall(SetEntityOrphanMode, entity, 1)
                                        pcall(FreezeEntityPosition, entity, true)
                                        pcall(SetVehicleDoorsLocked, entity, 2)
                                        pcall(SetEntityRoutingBucket, entity,
                                            math.floor(tonumber(Config.QuarantineRoutingBucket) or 900000))
                                    end
                                elseif identityMatches then
                                    -- A matching plate/vehicle id with another model is not safe to
                                    -- delete automatically, but it must prevent the owned row from
                                    -- becoming simultaneously available in a garage.
                                    allDeleted = false
                                    modelMismatch = true
                                    local netId = NetworkGetNetworkIdFromEntity(entity)
                                    UnregisterWithGarage(expectedPlate, netId and netId > 0 and netId or nil)
                                    pcall(SetEntityOrphanMode, entity, 1)
                                    pcall(FreezeEntityPosition, entity, true)
                                    pcall(SetVehicleDoorsLocked, entity, 2)
                                    pcall(SetEntityRoutingBucket, entity,
                                        math.floor(tonumber(Config.QuarantineRoutingBucket) or 900000))
                                end
                            end
                        end

                        if allDeleted then
                            local vehicleType = NormalizeGarageType(order.vehicle_type or owned.type or 'car')
                            local restored
                            if vehicleType == 'car' or vehicleType == 'boat' or vehicleType == 'air' then
                                restored = UpdateVehicleCompatibility(
                                    tonumber(owned.id), { citizenid = order.citizenid }, tostring(order.model):lower(),
                                    expectedPlate, vehicleType, owned.garage, recoveryProps
                                )
                            end

                            if restored then
                                UpdateOrder(order.order_id, 'stored', { reason = 'resource_restart_recovery' })
                            else
                                if not QuarantineOwnedRow(owned.id, order.citizenid) then
                                    error(('unable to quarantine order %s after customization restore failure'):format(
                                        order.order_id
                                    ))
                                end
                                UpdateOrder(order.order_id, 'delivery_review', {
                                    reason = 'restart_customization_restore_failed'
                                })
                            end
                        else
                            UpdateOrder(order.order_id, 'delivery_review', {
                                reason = modelMismatch and 'restart_entity_model_mismatch'
                                    or 'restart_entity_delete_retry'
                            })
                        end
                    else
                        UpdateOrder(order.order_id, 'delivery_review', {
                            reason = 'restart_out_state_quarantine_failed'
                        })
                    end
                end
            else
                UpdateOrder(order.order_id, 'refund_due', { reason = 'resource_restart_recovery' })
            end
        end
    end
end

local function ProcessOneRefund(src, order, reason)
    reason = tostring(reason or 'automatic_recovery'):sub(1, 255)
    local claimOk, claimed = pcall(MySQL.update.await, [[
        UPDATE drs_vehicle_shop_orders
        SET status = 'refund_processing', failure_reason = ?
        WHERE order_id = ? AND status = 'refund_due'
    ]], { reason, order.order_id })

    if not claimOk or claimed ~= 1 then
        return false, claimOk and 'not_claimed' or 'claim_failed'
    end

    local callOk, refunded = pcall(
        AddMoney,
        src,
        order.account,
        tonumber(order.amount) or 0,
        ('vehicle-purchase-recovery-%s'):format(order.model),
        order.citizenid
    )

    if callOk and refunded == true then
        if not UpdateOrder(order.order_id, 'refunded', { reason = reason }) then
            print(('[drs_vehicleshop] CRITICAL: refund credited but final journal write failed for order %s; '
                .. 'the order remains claimed and must be reviewed manually.'):format(tostring(order.order_id)))
            return true, 'credited_unrecorded'
        end

        ReleasePlateReservation(order.order_id)
        return true, 'refunded'
    end

    if callOk then
        UpdateOrder(order.order_id, 'refund_due', { reason = 'add_money_returned_false' })
        return false, 'retry_later'
    end

    UpdateOrder(order.order_id, 'refund_review', { reason = ('add_money_error:%s'):format(tostring(refunded)) })
    print(('[drs_vehicleshop] Refund result is unknown for order %s; manual review required: %s'):format(
        tostring(order.order_id), tostring(refunded)
    ))
    return false, 'refund_review'
end

local function QueueAndProcessRefund(src, order, reason)
    local queueOk, changed = pcall(MySQL.update.await, [[
        UPDATE drs_vehicle_shop_orders
        SET status = 'refund_due', failure_reason = ?
        WHERE order_id = ?
          AND status IN ('payment_processing', 'payment_unknown', 'debited')
    ]], { tostring(reason or 'purchase_failed'):sub(1, 255), order.order_id })

    if not queueOk then return false, 'queue_failed' end
    if changed ~= 1 then
        local readOk, current = pcall(
            MySQL.scalar.await,
            'SELECT status FROM drs_vehicle_shop_orders WHERE order_id = ? LIMIT 1',
            { order.order_id }
        )

        if not readOk then return false, 'queue_failed' end
        if current == 'refunded' then return true, 'already_refunded' end
        if current ~= 'refund_due' then return false, 'queue_failed' end
    end

    return ProcessOneRefund(src, order, reason)
end

local function ProcessRefunds(src)
    if not OrdersReady or RefundProcessing[src] then return end

    local data = GetPlayerData(src)
    if not data then return end

    RefundProcessing[src] = true
    local ok, err = xpcall(function()
        local rows = MySQL.query.await([[
            SELECT order_id, citizenid, account, amount, model
            FROM drs_vehicle_shop_orders
            WHERE citizenid = ? AND status = 'refund_due'
            ORDER BY id ASC
        ]], { data.citizenid }) or {}

        for _, order in ipairs(rows) do
            local refunded, refundCode = ProcessOneRefund(src, order, 'automatic_recovery')
            if refunded and PlayerIdentityMatches(src, order.citizenid) then
                Notify(src, ('A pending vehicle-shop refund of $%s was restored to your %s account.'):format(
                    order.amount, order.account
                ), 'success')
            elseif refundCode == 'claim_failed' or refundCode == 'refund_review' then
                print(('[drs_vehicleshop] Refund retry for order %s needs attention (%s).'):format(
                    tostring(order.order_id), tostring(refundCode)
                ))
            end
        end
    end, debug.traceback)

    RefundProcessing[src] = nil
    if not ok then
        print(('[drs_vehicleshop] Refund processing failed for source %s: %s'):format(tostring(src), tostring(err)))
    end
end

local function NewQuoteId(src)
    for _ = 1, 5 do
        SessionSequence = SessionSequence + 1
        local quoteId = ('q_%d_%d_%08x_%d'):format(
            os.time(), src, math.random(0, 0x7fffffff), SessionSequence
        )
        if not CheckoutQuotes[quoteId] then return quoteId end
    end
end

local function CompleteCheckoutQuote(quote, result)
    if not quote then return result end
    quote.status = 'completed'
    quote.result = result
    quote.resultUntil = os.time() + math.max(60, math.min(
        3600, math.floor(tonumber(Config.Checkout and Config.Checkout.resultLifetime) or 600)
    ))
    return result
end

local function QuoteVehicle(src, model, shopId, customization)
    if not ServiceReady then
        return Result(false, 'service_not_ready', 'The vehicle shop service is not ready.')
    end
    if Operations[src] then return Result(false, 'busy', 'Another vehicle-shop operation is already running.') end
    if TestDrives[src] then return Result(false, 'test_drive_active', 'Finish your test drive before checking out.') end
    if PendingHandoffsBySource[src] then
        return Result(false, 'delivery_pending', 'Your previous vehicle delivery is still being confirmed.')
    end

    local now = GetGameTimer()
    if (CheckoutQuoteCooldowns[src] or 0) > now then
        return Result(false, 'quote_cooldown', 'Please wait a moment before updating the checkout quote.')
    end
    CheckoutQuoteCooldowns[src] = now + math.max(250, math.min(
        5000, math.floor(tonumber(Config.Checkout and Config.Checkout.quoteCooldown) or 750)
    ))

    local data = GetPlayerData(src)
    if not data then return Result(false, 'player_not_found', 'Player data is unavailable.') end
    ProcessRefunds(src)
    local unresolved, guardError = GetUnresolvedOrder(data.citizenid)
    if guardError then
        return Result(false, 'order_guard_unavailable', 'Unable to verify previous purchase orders right now.')
    elseif unresolved then
        return Result(false, 'unresolved_order',
            'A previous vehicle order still needs to finish or be reviewed before another checkout.')
    end
    local vehicle, category, shop, resolvedShopId, quoteModel = GetVehicleFromConfig(model, shopId)
    if not vehicle then return Result(false, 'invalid_vehicle', 'Invalid vehicle or shop selected.') end
    if not IsNearDealership(src, shop) then
        return Result(false, 'too_far', 'You are too far away from the dealership.')
    end

    local allowed, accessCode = HasPolicyAccess(src, data, vehicle, category, shop, 'allowPurchase')
    if not allowed then
        return Result(false, accessCode, 'You are not authorized to purchase this vehicle.')
    end

    local resolved, resolveCode, resolveMessage = ResolveCheckout(
        vehicle, category, shop, resolvedShopId, quoteModel, customization
    )
    if not resolved then return Result(false, resolveCode, resolveMessage) end

    local previousId = CheckoutQuoteBySource[src]
    local previous = previousId and CheckoutQuotes[previousId]
    if previous and previous.status == 'processing' then
        return Result(false, 'purchase_processing', 'Your current checkout is still being processed.')
    elseif previous and previous.status == 'ready' then
        CheckoutQuotes[previousId] = nil
    end

    local quoteId = NewQuoteId(src)
    if not quoteId then return Result(false, 'quote_failed', 'Unable to create a checkout quote.') end
    local lifetime = math.max(15, math.min(
        600, math.floor(tonumber(Config.Checkout and Config.Checkout.quoteLifetime) or 120)
    ))
    local expiresAt = os.time() + lifetime
    local publicQuote = {
        id = quoteId,
        expiresAt = expiresAt,
        model = resolved.model,
        shopId = resolved.shopId,
        vehicleType = resolved.vehicleType,
        capabilities = resolved.capabilities,
        options = resolved.options,
        selection = resolved.selection,
        labels = resolved.labels,
        costs = resolved.costs,
        platePreview = resolved.platePreview
    }
    CheckoutQuotes[quoteId] = {
        id = quoteId,
        src = src,
        citizenid = data.citizenid,
        model = resolved.model,
        shopId = resolved.shopId,
        expiresAt = expiresAt,
        status = 'ready',
        selection = resolved.selection,
        fingerprint = CheckoutFingerprint(resolved),
        public = publicQuote
    }
    CheckoutQuoteBySource[src] = quoteId

    return Result(true, 'quoted', 'Checkout quote ready.', { quote = publicQuote })
end

local function VehicleResultData(context)
    return {
        netId = context.netId,
        model = context.model,
        plate = context.plate,
        shopId = context.shopId,
        garage = context.garage,
        orderId = context.orderId,
        vehicleType = context.vehicleType,
        deliveryMode = context.deliveryMode,
        customization = context.selection,
        props = context.props and {
            color1 = context.props.color1,
            color2 = context.props.color2,
            plateIndex = context.props.plateIndex
        } or nil
    }
end

local function CacheDeliveryAcknowledgement(context, result)
    if not context or not context.handoffToken or not context.data or not result then return result end
    DeliveryAcknowledgements[context.handoffToken] = {
        src = context.src,
        citizenid = context.data.citizenid,
        result = result,
        expiresAt = os.time() + math.max(60, math.min(
            3600, math.floor(tonumber(Config.Checkout and Config.Checkout.resultLifetime) or 600)
        ))
    }
    return result
end

local function ReserveSpawn(context, coords, bucket)
    local key = ('%s:%.1f:%.1f:%.1f'):format(
        tostring(bucket or 0), tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0
    )
    if SpawnReservations[key] then return false end
    SpawnReservations[key] = context
    context.spawnReservation = key
    return true
end

local function ReleaseSpawn(context)
    if not context or not context.spawnReservation then return end
    if SpawnReservations[context.spawnReservation] == context then
        SpawnReservations[context.spawnReservation] = nil
    end
    context.spawnReservation = nil
end

local function ClearPendingHandoff(context)
    if not context or not context.handoffToken then return end
    if PendingHandoffs[context.handoffToken] == context then
        PendingHandoffs[context.handoffToken] = nil
    end
    if PendingHandoffsBySource[context.src] == context.handoffToken then
        PendingHandoffsBySource[context.src] = nil
    end
end

local RecoverOwnedPurchase

local function SchedulePurchaseRecovery(context, reason)
    if not context or context.recoveryScheduled or context.completed then return end
    context.recoveryScheduled = true
    SetTimeout(5000, function()
        context.recoveryScheduled = false
        if not context.completed then RecoverOwnedPurchase(context, reason) end
    end)
end

RecoverOwnedPurchase = function(context, reason)
    if not context or not context.vehicleId or not context.data or not context.plate or not context.garage then
        return false
    end
    if context.finalizing then
        context.rollbackRequested = true
        return false, 'finalization_busy'
    end

    context.finalizing = 'rollback'
    ReleaseSpawn(context)
    reason = tostring(reason or 'delivery_recovery'):sub(1, 255)
    if context.handoffToken and context.orderId then
        UpdateOrder(context.orderId, 'rollback_finalizing', {
            vehicleId = context.vehicleId, netId = context.netId, reason = reason
        })
    end

    if context.keysGiven then
        RemoveTemporaryKeys(context.src, context.entity)
        context.keysGiven = false
    end

    if context.entity then
        local deleted = DeleteServerVehicle(context.entity)
        if not deleted then
            -- Keep the row unavailable while the surviving entity is quarantined and retried.
            local quarantined = SetVehicleStored(context.data, context.plate, false, context.garage)
            if quarantined and not context.registered and context.netId then
                local registered, registrationReason, registrationResource = RegisterWithGarage(
                    context.src, context.plate, context.netId
                )
                context.registered = registered == true
                    and registrationReason ~= 'disabled'
                    and registrationReason ~= 'not_running'
                context.garageResource = context.registered and registrationResource or nil
            end
            pcall(SetEntityOrphanMode, context.entity, 1)
            pcall(FreezeEntityPosition, context.entity, true)
            pcall(SetVehicleDoorsLocked, context.entity, 2)
            pcall(SetEntityRoutingBucket, context.entity,
                math.floor(tonumber(Config.QuarantineRoutingBucket) or 900000))
            if context.orderId then
                UpdateOrder(context.orderId, 'delivery_review', {
                    vehicleId = context.vehicleId,
                    netId = context.netId,
                    reason = (quarantined and 'entity_delete_retry:' or 'entity_delete_and_quarantine_unknown:') .. reason
                })
            end
            context.finalizing = nil
            SchedulePurchaseRecovery(context, 'entity_delete_retry')
            return false, 'entity_delete_failed'
        end
        context.entity = nil
    end

    if context.registered then
        UnregisterWithGarage(context.plate, context.netId, context.garageResource)
        context.registered = false
        context.garageResource = nil
    end

    local stored, storageReason = SetVehicleStored(context.data, context.plate, true, context.garage)
    if not stored then
        if context.orderId then
            UpdateOrder(context.orderId, 'delivery_review', {
                vehicleId = context.vehicleId,
                netId = context.netId,
                reason = ('storage_rollback_%s:%s'):format(tostring(storageReason), reason):sub(1, 255)
            })
        end
        print(('[drs_vehicleshop] CRITICAL: entity removal succeeded, but stored state is unverified for order %s (%s).'):format(
            tostring(context.orderId), tostring(storageReason)
        ))
        context.finalizing = nil
        context.completed = true
        ClearPendingHandoff(context)
        return false, storageReason
    end

    context.outState = false
    ClearPendingHandoff(context)

    if context.orderId and not UpdateOrder(context.orderId, 'stored', {
        vehicleId = context.vehicleId,
        reason = reason
    }) then
        print(('[drs_vehicleshop] Stored state is safe, but order %s could not be finalized in the journal.'):format(
            tostring(context.orderId)
        ))
    end

    context.completed = true
    context.finalizing = 'complete'
    return true
end

local function StoredPurchaseResult(context, reason, message)
    local recovered = RecoverOwnedPurchase(context, reason)
    if not recovered then
        return Result(true, 'delivery_review',
            'Vehicle ownership was created, but automatic delivery recovery needs staff review. Do not purchase it again.', {
                fallbackStored = true,
                vehicle = VehicleResultData(context)
            })
    end

    return Result(true, 'stored', message or ('Vehicle purchased and stored at %s.'):format(context.garage), {
        fallbackStored = true,
        vehicle = VehicleResultData(context)
    })
end

local function RefundFailureResult(src, context, reason, failureMessage)
    local refunded, refundCode = QueueAndProcessRefund(src, {
        order_id = context.orderId,
        citizenid = context.data and context.data.citizenid,
        account = context.account,
        amount = context.amount,
        model = context.model
    }, reason)

    if refunded then
        return Result(false, 'purchase_failed_refunded', failureMessage .. ' Your payment was refunded.')
    end

    if refundCode == 'retry_later' then
        return Result(false, 'refund_queued', failureMessage .. ' Your refund is queued for automatic retry.')
    end

    return Result(false, 'refund_review',
        failureMessage .. ' The payment recovery record needs staff review; do not retry this purchase yet.')
end

local function PurchaseVehicle(src, model, shopId, quoteId)
    if not ServiceReady then
        return Result(false, 'service_not_ready', 'The vehicle shop service is not ready.')
    end
    if type(quoteId) ~= 'string' or #quoteId < 8 or #quoteId > 100
        or not quoteId:match('^[A-Za-z0-9_%-]+$') then
        return Result(false, 'quote_required', 'Create a valid checkout quote before purchasing.')
    end

    local quote = CheckoutQuotes[quoteId]
    if not quote then return Result(false, 'quote_expired', 'That checkout quote expired. Create a new one.') end
    if quote.src ~= src then return Result(false, 'quote_not_owned', 'That checkout quote belongs to another player.') end
    local currentData = GetPlayerData(src)
    if not currentData or currentData.citizenid ~= quote.citizenid then
        return Result(false, 'quote_not_owned', 'Your player session no longer matches this checkout quote.')
    end
    local requestedModel = type(model) == 'string' and model:lower() or nil
    local requestedShop = shopId ~= nil and tostring(shopId) or nil
    if requestedModel ~= quote.model or requestedShop ~= quote.shopId then
        return Result(false, 'quote_mismatch', 'The checkout quote does not match this vehicle and shop.')
    end
    if quote.status == 'completed' and quote.result then
        if os.time() <= (quote.resultUntil or quote.expiresAt) then return quote.result end
        CheckoutQuotes[quoteId] = nil
        if CheckoutQuoteBySource[src] == quoteId then CheckoutQuoteBySource[src] = nil end
        return Result(false, 'quote_expired', 'That completed checkout receipt expired.')
    end
    if quote.status == 'processing' then
        return Result(false, 'purchase_processing', 'This checkout is already being processed.')
    end
    if os.time() > quote.expiresAt then
        CheckoutQuotes[quoteId] = nil
        if CheckoutQuoteBySource[src] == quoteId then CheckoutQuoteBySource[src] = nil end
        return Result(false, 'quote_expired', 'That checkout quote expired. Create a new one.')
    end

    if Operations[src] then return Result(false, 'busy', 'Another vehicle-shop operation is already running.') end
    if TestDrives[src] then return Result(false, 'test_drive_active', 'Finish your test drive before purchasing.') end
    if PendingHandoffsBySource[src] then
        return Result(false, 'delivery_pending', 'Your previous vehicle delivery is still being confirmed.')
    end

    local now = GetGameTimer()
    local cooldownEnds = PurchaseCooldowns[src] or 0
    if cooldownEnds > now then
        return Result(false, 'purchase_cooldown', 'Please wait a moment before another purchase attempt.')
    end
    PurchaseCooldowns[src] = now + math.max(0, math.floor(tonumber(Config.PurchaseCooldown) or 2500))

    SessionSequence = SessionSequence + 1
    local operation = { id = SessionSequence, src = src }
    local context = { src = src }
    Operations[src] = operation
    quote.status = 'processing'

    local ok, result = xpcall(function()
        local data = GetPlayerData(src)
        if not data then return Result(false, 'player_not_found', 'Player data is unavailable.') end
        operation.citizenid = data.citizenid
        context.data = data

        ProcessRefunds(src)
        if not PlayerIdentityMatches(src, data.citizenid) then
            return Result(false, 'player_session_changed', 'Your player session changed before the purchase began.')
        end

        local vehicle, category, shop, resolvedShopId, purchaseModel = GetVehicleFromConfig(model, shopId)
        if not vehicle then return Result(false, 'invalid_vehicle', 'Invalid vehicle or shop selected.') end
        if not IsNearDealership(src, shop) then
            return Result(false, 'too_far', 'You are too far away from the dealership.')
        end

        local allowed, accessCode = HasPolicyAccess(src, data, vehicle, category, shop, 'allowPurchase')
        if not allowed then
            return Result(false, accessCode, 'You are not authorized to purchase this vehicle.')
        end

        local resolved, resolveCode, resolveMessage = ResolveCheckout(
            vehicle, category, shop, resolvedShopId, purchaseModel, quote.selection
        )
        if not resolved then return Result(false, resolveCode, resolveMessage) end
        if CheckoutFingerprint(resolved) ~= quote.fingerprint then
            return Result(false, 'quote_changed', 'The vehicle, options, or price changed. Create a new quote.')
        end

        local spawnCoords = resolved.selection.deliveryMode == 'driveaway'
            and GetShopLocation(shop, 'spawn') or nil
        if resolved.selection.deliveryMode == 'driveaway' and not spawnCoords then
            return Result(false, 'missing_spawn', 'This dealership has no delivery location configured.')
        end

        local account = Config.PaymentAccount or 'cash'
        if GetMoney(src, account, data.citizenid) < resolved.totalPrice then
            return Result(false, 'insufficient_funds', 'Not enough money!')
        end

        local unresolved, guardError = GetUnresolvedOrder(data.citizenid)
        if guardError then
            return Result(false, 'order_guard_unavailable', 'Unable to verify previous purchase orders right now.')
        elseif unresolved then
            return Result(false, 'unresolved_order',
                'A previous vehicle order still needs to finish or be reviewed before another purchase.')
        end

        local orderId, plate, reservationCode, existingOrder = CreateOrderAndReserve(
            src, data, quoteId, resolvedShopId, purchaseModel, account, resolved
        )
        if not orderId then
            if reservationCode == 'quote_retry' then
                quote.expiresAt = 0
                return Result(false, 'quote_retry',
                    'The plate reservation was safely reconciled. Create a new quote and try again.')
            elseif reservationCode == 'duplicate_request' and existingOrder
                and existingOrder.citizenid == data.citizenid then
                context.orderId = existingOrder.order_id
                return Result(false, 'unresolved_order',
                    'This checkout already has a durable order that must finish or be reviewed.')
            end
            return Result(false, 'reservation_failed', 'Unable to reserve a unique plate and purchase order.')
        end

        quote.orderId = orderId
        context.orderId = orderId
        context.account = account
        context.amount = resolved.totalPrice
        context.model = purchaseModel
        context.plate = plate
        context.shopId = resolvedShopId
        context.vehicleType = resolved.vehicleType
        context.deliveryMode = resolved.selection.deliveryMode
        context.selection = resolved.selection

        if not UpdateOrder(orderId, 'payment_processing') then
            if UpdateOrder(orderId, 'cancelled', { reason = 'payment_journal_start_failed' }) then
                ReleasePlateReservation(orderId)
            end
            return Result(false, 'journal_failed', 'The purchase journal became unavailable before payment.')
        end

        if not PlayerIdentityMatches(src, data.citizenid) then
            if UpdateOrder(orderId, 'cancelled', { reason = 'player_session_changed_before_payment' }) then
                ReleasePlateReservation(orderId)
            end
            return Result(false, 'player_session_changed', 'Your player session changed before payment.')
        end

        local paymentCallOk, paymentRemoved = pcall(
            RemoveMoney,
            src,
            account,
            resolved.totalPrice,
            ('vehicle-purchase-%s-%s'):format(purchaseModel, orderId),
            data.citizenid
        )

        if not paymentCallOk then
            UpdateOrder(orderId, 'payment_review', { reason = tostring(paymentRemoved) })
            return Result(
                false,
                'payment_review',
                'The payment provider did not confirm the transaction. Staff should review this order before retrying.'
            )
        end

        if not paymentRemoved then
            if UpdateOrder(orderId, 'payment_failed', { reason = 'remove_money_failed' }) then
                ReleasePlateReservation(orderId)
            end
            return Result(false, 'payment_failed', 'Payment failed.')
        end

        context.debited = true
        if not UpdateOrder(orderId, 'debited') then
            return RefundFailureResult(src, context, 'debited_status_write_failed',
                'The purchase journal failed after payment.')
        end

        local vehicleType = resolved.vehicleType
        local garage = GetDefaultGarage(vehicleType, shop)
        local props = TrustedProps(purchaseModel, plate, resolved.customization)
        context.garage = garage
        context.props = props

        local vehicleId, createError, creationAmbiguous = CreateOwnedVehicle(
            data, purchaseModel, plate, vehicleType, garage, props
        )

        if not vehicleId then
            if creationAmbiguous then
                UpdateOrder(orderId, 'ownership_review', { reason = createError or 'ownership_creation_ambiguous' })
                return Result(false, 'ownership_review',
                    'The ownership provider did not confirm whether the vehicle row was created. Staff must review this order before any refund or retry.')
            end
            return RefundFailureResult(src, context, createError or 'ownership_creation_failed',
                'Vehicle ownership creation failed.')
        end

        context.vehicleId = vehicleId
        ReleasePlateReservation(orderId)

        -- noir: a chave vem com a compra, tambem quando o carro vai direto para a garagem ou cai
        -- no fallback de guardar; sem isso so a entrega na concessionaria entregava chave.
        if PlayerIdentityMatches(src, data.citizenid) and GivePermanentKey(src, plate) == false then
            Notify(src, 'Não coube a chave do veículo no inventário. Peça uma cópia na garagem.', 'error')
        end
        if not UpdateOrder(orderId, 'vehicle_created', { vehicleId = vehicleId }) then
            return StoredPurchaseResult(context, 'vehicle_created_journal_failed',
                ('Vehicle purchased and stored at %s because the delivery journal was unavailable.'):format(garage))
        end

        if createError then
            return StoredPurchaseResult(context, createError,
                ('Vehicle purchased and stored at %s because compatibility staging needs review.'):format(garage))
        end

        local deliverPurchases = resolved.selection.deliveryMode == 'driveaway'
            and Config.DeliverPurchasedVehicles ~= false
            and tonumber(Config.PurchasedVehicleState or 0) == 0
        local bucket = GetPlayerRoutingBucket(src)
        local clearance = tonumber(Config.DeliveryClearanceRadius) or 4.0

        if not deliverPurchases then
            return StoredPurchaseResult(
                context,
                'stored_delivery_configured',
                ('Vehicle purchased and stored at %s.'):format(garage)
            )
        end

        if not ReserveSpawn(context, spawnCoords, bucket) or not IsSpawnClear(spawnCoords, clearance, bucket) then
            ReleaseSpawn(context)
            return StoredPurchaseResult(context, 'delivery_point_blocked',
                ('Vehicle purchased and stored at %s because the delivery point is occupied.'):format(garage))
        end

        if not PlayerIdentityMatches(src, data.citizenid) then
            return StoredPurchaseResult(context, 'player_session_changed_before_delivery',
                ('Vehicle purchased and stored at %s because your player session changed.'):format(garage))
        end

        if not UpdateOrder(orderId, 'delivery_spawning', { vehicleId = vehicleId }) then
            return StoredPurchaseResult(context, 'delivery_spawning_journal_failed',
                ('Vehicle purchased and stored at %s because delivery could not start safely.'):format(garage))
        end

        -- Make the ownership row unavailable to garages before a persistent world
        -- entity can exist. Recovery reverses this only after verified entity removal.
        if not SetVehicleStored(data, plate, false, garage) then
            return StoredPurchaseResult(context, 'delivery_spawning_out_state_failed',
                ('Vehicle purchased; state synchronization failed, so it was stored at %s.'):format(garage))
        end
        context.outState = true

        local entity, netId, spawnError, cleanupEntity = CreateServerVehicle(
            purchaseModel,
            GetServerVehicleType(vehicle, category),
            spawnCoords,
            plate,
            bucket,
            vehicleId,
            props
        )
        ReleaseSpawn(context)

        if not entity then
            context.entity = cleanupEntity
            return StoredPurchaseResult(context, spawnError or 'delivery_spawn_failed',
                ('Vehicle purchased; delivery failed, so it was stored at %s.'):format(garage))
        end

        context.entity = entity
        context.netId = netId
        if not UpdateOrder(orderId, 'delivery_spawned', { vehicleId = vehicleId, netId = netId }) then
            return StoredPurchaseResult(context, 'delivery_spawn_journal_failed',
                ('Vehicle purchased and stored at %s because delivery tracking failed.'):format(garage))
        end

        if not PlayerIdentityMatches(src, data.citizenid) then
            return StoredPurchaseResult(context, 'player_session_changed_before_delivery',
                ('Vehicle purchased and stored at %s because your player session changed.'):format(garage))
        end

        -- Re-check after the OneSync wait in case another garage resource restarted
        -- or otherwise reconciled the row while the entity was being created.
        if not SetVehicleStored(data, plate, false, garage) then
            return StoredPurchaseResult(context, 'out_state_recheck_failed',
                ('Vehicle purchased; state synchronization failed, so it was stored at %s.'):format(garage))
        end

        if not UpdateOrder(orderId, 'out_pending_registration', { vehicleId = vehicleId, netId = netId }) then
            return StoredPurchaseResult(context, 'out_state_journal_failed',
                ('Vehicle purchased and stored at %s because state tracking failed.'):format(garage))
        end

        local registered, registrationReason, registrationResource = RegisterWithGarage(src, plate, netId)
        if not registered then
            return StoredPurchaseResult(context,
                ('garage_registration_failed:%s'):format(tostring(registrationReason)),
                ('Vehicle purchased; garage registration failed, so it was stored at %s.'):format(garage))
        end
        context.registered = registrationReason ~= 'disabled' and registrationReason ~= 'not_running'
        context.garageResource = context.registered and registrationResource or nil

        if GetFramework() == 'qbox' and GetResourceState('qbx_vehicles') == 'started' then
            local saveCallOk, saved, saveError = pcall(function()
                return exports.qbx_vehicles:SaveVehicle(entity, {
                    garage = garage,
                    state = 0,
                    props = props
                })
            end)

            if not saveCallOk or saved ~= true then
                return StoredPurchaseResult(context,
                    ('qbx_save_failed:%s'):format(tostring(saveError or saved)),
                    ('Vehicle purchased; persistence synchronization failed, so it was stored at %s.'):format(garage))
            end
        end

        if not PlayerIdentityMatches(src, data.citizenid) then
            return StoredPurchaseResult(context, 'player_session_changed_before_keys',
                ('Vehicle purchased and stored at %s because your player session changed.'):format(garage))
        end

        if not GiveVehicleKeys(src, entity, plate, false) then
            return StoredPurchaseResult(context, 'key_delivery_failed',
                ('Vehicle purchased; keys could not be issued, so it was stored at %s.'):format(garage))
        end
        context.keysGiven = true

        local handoffToken = ('%s-%08x'):format(orderId, math.random(0, 0x7fffffff))
        context.handoffToken = handoffToken
        if not UpdateOrder(orderId, 'handoff_pending', { vehicleId = vehicleId, netId = netId }) then
            return StoredPurchaseResult(context, 'handoff_journal_failed',
                ('Vehicle purchased and stored at %s because the handoff could not be tracked.'):format(garage))
        end
        PendingHandoffs[handoffToken] = context
        PendingHandoffsBySource[src] = handoffToken
        local acknowledgementTimeout = tonumber(Config.DeliveryAcknowledgementTimeout)
            or ((tonumber(Config.EntityHandoffTimeout) or 10000) + 5000)
        SetTimeout(math.max(5000, math.floor(acknowledgementTimeout)), function()
            if PendingHandoffs[handoffToken] ~= context then return end
            local recovered, recoveryCode = RecoverOwnedPurchase(context, 'delivery_ack_timeout')
            if recoveryCode == 'finalization_busy' then return end
            CacheDeliveryAcknowledgement(context, Result(true, recovered and 'stored' or 'delivery_review', recovered
                and ('Vehicle delivery timed out and was returned to %s.'):format(garage)
                or 'Vehicle delivery timed out and needs staff review.', {
                    fallbackStored = true,
                    vehicle = VehicleResultData(context)
                }))
            if PlayerIdentityMatches(src, data.citizenid) then
                pcall(Notify, src, recovered
                    and ('Vehicle delivery timed out and was returned to %s.'):format(garage)
                    or 'Vehicle delivery timed out and needs staff review.', recovered and 'warning' or 'error')
            end
        end)

        return Result(true, 'purchased', 'Congratulations on your purchase! Your vehicle is ready.', {
            handoffToken = handoffToken,
            vehicle = VehicleResultData(context)
        })
    end, debug.traceback)

    if Operations[src] == operation then Operations[src] = nil end

    if not ok then
        print(('[drs_vehicleshop] Purchase callback failed for source %s: %s'):format(src, tostring(result)))
        if context.vehicleId then
            result = StoredPurchaseResult(context, ('purchase_exception:%s'):format(tostring(result)):sub(1, 255),
                ('Vehicle purchased and stored at %s after an internal delivery error.'):format(context.garage))
        elseif context.debited and context.orderId then
            result = RefundFailureResult(src, context, 'purchase_exception_before_ownership',
                'The purchase stopped before ownership could be created.')
        else
            result = Result(false, 'internal_error', 'The purchase could not be completed safely.')
        end
    end

    if not context.orderId then
        quote.status = 'ready'
        return result
    end
    return CompleteCheckoutQuote(quote, result)
end

local function ValidateDeliveryHandoff(context, src)
    if not context or context.src ~= src or not context.data
        or not PlayerIdentityMatches(src, context.data.citizenid) then
        return false, 'player_session_changed'
    end

    local entity = context.entity
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return false, 'entity_missing'
    end
    if NetworkGetEntityFromNetworkId(context.netId) ~= entity
        or NetworkGetNetworkIdFromEntity(entity) ~= context.netId then
        return false, 'network_entity_changed'
    end
    if GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entity) then
        return false, 'routing_bucket_changed'
    end
    if NormalizePlate(GetVehicleNumberPlateText(entity)) ~= context.plate then
        return false, 'plate_changed'
    end
    if (GetEntityModel(entity) % 4294967296) ~= (joaat(context.model) % 4294967296) then
        return false, 'model_changed'
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped)
        or GetPedInVehicleSeat(entity, -1) ~= ped
        or #(GetEntityCoords(ped) - GetEntityCoords(entity)) > 15.0 then
        return false, 'driver_handoff_not_confirmed'
    end

    return true
end

local function AcknowledgeDelivery(src, token)
    if type(token) ~= 'string' or #token < 8 or #token > 100
        or not token:match('^[A-Za-z0-9_%-]+$') then
        return Result(false, 'invalid_handoff', 'The delivery confirmation token is invalid.')
    end

    local cached = DeliveryAcknowledgements[token]
    if cached then
        local data = GetPlayerData(src)
        if cached.src == src and data and data.citizenid == cached.citizenid
            and os.time() <= cached.expiresAt then
            return cached.result
        end
        return Result(false, 'invalid_handoff', 'That delivery confirmation belongs to another player.')
    end

    local context = PendingHandoffs[token]
    if not context or context.handoffToken ~= token or context.src ~= src then
        return Result(false, 'handoff_not_found', 'That vehicle delivery is no longer pending.')
    end
    if context.finalizing or context.completed then
        return Result(false, 'handoff_busy', 'That vehicle delivery is already being finalized.')
    end
    context.finalizing = 'ack'
    context.rollbackRequested = false

    local function rollback(reason, message)
        context.finalizing = nil
        local recovered = RecoverOwnedPurchase(context, reason)
        local resultMessage = message or (recovered
            and ('Vehicle handoff failed and was returned to %s.'):format(context.garage)
            or 'Vehicle handoff failed and needs staff review.')
        return CacheDeliveryAcknowledgement(context, Result(true,
            recovered and 'stored' or 'delivery_review', resultMessage, {
                fallbackStored = true,
                vehicle = VehicleResultData(context)
            }))
    end

    if not UpdateOrder(context.orderId, 'ack_finalizing', {
        vehicleId = context.vehicleId,
        netId = context.netId
    }) then
        return rollback('ack_claim_failed')
    end

    local valid, reason = ValidateDeliveryHandoff(context, src)
    if not valid or context.rollbackRequested then
        return rollback(('handoff_rejected:%s'):format(reason or 'rollback_requested'))
    end

    if not SetVehicleStored(context.data, context.plate, false, context.garage) then
        return rollback('handoff_out_state_recheck_failed',
            'Vehicle handoff could not be finalized and was returned to storage.')
    end

    valid, reason = ValidateDeliveryHandoff(context, src)
    if not valid or context.rollbackRequested then
        return rollback(valid and 'handoff_rollback_requested' or ('handoff_changed:%s'):format(reason))
    end

    -- Reassert keys only after the client is verifiably seated. This is
    -- idempotent for Qbox and gives event-based QB key systems a second,
    -- correctly-timed ownership notification after the entity has streamed.
    if not GiveVehicleKeys(src, context.entity, context.plate, false) then
        return rollback('handoff_key_confirmation_failed',
            'Vehicle keys could not be confirmed and the vehicle was returned to storage.')
    end

    valid, reason = ValidateDeliveryHandoff(context, src)
    if not valid or context.rollbackRequested then
        return rollback(valid and 'handoff_rollback_requested'
            or ('handoff_changed_after_keys:%s'):format(reason))
    end

    -- This is the final durable step. No further validation await occurs after it;
    -- later entity loss is normal out-vehicle/impound behavior, not a failed handoff.
    if not UpdateOrder(context.orderId, 'delivered', {
        vehicleId = context.vehicleId,
        netId = context.netId
    }) then
        return rollback('delivered_journal_failed',
            'Vehicle handoff could not be finalized and was returned to storage.')
    end

    -- The journal write above yields. A timeout, disconnect, or entity removal
    -- can request rollback while it is in flight, so give that request the last
    -- word before clearing the pending handoff. Recovery can safely move the
    -- just-written delivered status back through rollback_finalizing to stored.
    valid, reason = ValidateDeliveryHandoff(context, src)
    if not valid or context.rollbackRequested then
        return rollback(valid and 'handoff_rollback_requested_after_commit'
            or ('handoff_changed_after_commit:%s'):format(reason))
    end

    ClearPendingHandoff(context)
    context.completed = true
    context.finalizing = 'complete'
    context.delivered = true
    ActiveDeliveries[context.plate] = {
        entity = context.entity,
        netId = context.netId,
        citizenid = context.data.citizenid
    }
    return CacheDeliveryAcknowledgement(context, Result(true, 'delivered',
        'Vehicle delivery confirmed.', { vehicle = VehicleResultData(context) }))
end

RegisterNetEvent('drs_vehicleshop:server:acknowledgeDelivery', function(token)
    local result = AcknowledgeDelivery(source, token)
    if result and result.code ~= 'delivered' then
        Notify(source, result.message or 'Vehicle delivery could not be confirmed.',
            result.ok and 'warning' or 'error')
    end
end)

local function ValidateTestDriveHandoff(src, session)
    if not session or TestDrives[src] ~= session or session.returning
        or not PlayerIdentityMatches(src, session.citizenid) then return false end

    local entity = session.entity
    local ped = GetPlayerPed(src)
    local valid = entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 2
        and NetworkGetEntityFromNetworkId(session.netId) == entity
        and NetworkGetNetworkIdFromEntity(entity) == session.netId
        and GetPlayerRoutingBucket(src) == GetEntityRoutingBucket(entity)
        and NormalizePlate(GetVehicleNumberPlateText(entity)) == session.plate
        and (GetEntityModel(entity) % 4294967296) == (session.modelHash % 4294967296)
        and ped and ped ~= 0 and DoesEntityExist(ped)
        and GetPedInVehicleSeat(entity, -1) == ped

    return valid == true, entity
end

local function AcknowledgeTestDrive(src, expectedSession)
    expectedSession = tonumber(expectedSession)
    if not expectedSession or expectedSession % 1 ~= 0 then
        return Result(false, 'invalid_test_drive_session',
            'The test-drive session identifier is invalid.')
    end

    local session = TestDrives[src]
    if not session or session.id ~= expectedSession then
        return Result(false, 'test_drive_not_found', 'That test drive is no longer available.')
    end

    local valid, entity = ValidateTestDriveHandoff(src, session)

    if not valid then
        EndTestDrive(src, 'handoff_not_confirmed', session.id)
        return Result(false, 'test_drive_handoff_failed',
            'The test-drive vehicle could not be confirmed safely.')
    end

    if session.ready then
        return Result(true, 'test_drive_ready',
            ('Test drive is ready with %s seconds remaining.'):format(
                math.max(0, (session.expiresAt or os.time()) - os.time())
            ))
    end
    if session.acknowledging then
        return Result(false, 'test_drive_handoff_busy',
            'The test-drive handoff is already being confirmed.')
    end
    session.acknowledging = true

    if not GiveVehicleKeys(src, entity, session.plate, true) then
        EndTestDrive(src, 'key_confirmation_failed', session.id)
        return Result(false, 'key_delivery_failed',
            'Temporary vehicle keys could not be confirmed.')
    end

    valid = ValidateTestDriveHandoff(src, session)
    if not valid then
        EndTestDrive(src, 'handoff_changed_after_keys', session.id)
        return Result(false, 'test_drive_handoff_failed',
            'The test-drive handoff changed before it could be confirmed.')
    end

    session.acknowledging = false
    session.ready = true
    session.handoffUntil = os.time()
    session.expiresAt = os.time() + session.duration
    return Result(true, 'test_drive_ready',
        ('Test drive started! You have %s seconds.'):format(session.duration))
end

local function StartTestDrive(src, model, shopId)
    if not ServiceReady then
        return Result(false, 'service_not_ready', 'The vehicle shop service is not ready.')
    end
    if Operations[src] then return Result(false, 'busy', 'Another vehicle-shop operation is already running.') end
    if TestDrives[src] then return Result(false, 'test_drive_active', 'You already have an active test drive.') end
    if PendingHandoffsBySource[src] then
        return Result(false, 'delivery_pending', 'Your vehicle delivery is still being confirmed.')
    end

    local cooldownEnds = TestDriveCooldowns[src] or 0
    if cooldownEnds > os.time() then
        return Result(false, 'test_drive_cooldown', ('Please wait %s seconds before another test drive.'):format(
            cooldownEnds - os.time()
        ))
    end

    SessionSequence = SessionSequence + 1
    local operation = { id = SessionSequence, src = src }
    local context = { src = src }
    Operations[src] = operation

    local ok, result = xpcall(function()
        local data = GetPlayerData(src)
        if not data then return Result(false, 'player_not_found', 'Player data is unavailable.') end
        operation.citizenid = data.citizenid
        context.data = data

        local vehicle, category, shop, resolvedShopId, testModel = GetVehicleFromConfig(model, shopId)
        if not vehicle then return Result(false, 'invalid_vehicle', 'Invalid vehicle or shop selected.') end
        if not IsNearDealership(src, shop) then
            return Result(false, 'too_far', 'You are too far away from the dealership.')
        end

        if Config.TestDrive and Config.TestDrive.enabled == false then
            return Result(false, 'test_drive_disabled', 'Test drives are disabled.')
        end

        local allowed, accessCode = HasPolicyAccess(src, data, vehicle, category, shop, 'allowTestDrive')
        if not allowed then
            return Result(false, accessCode, 'You are not authorized to test drive this vehicle.')
        end

        local spawnCoords = GetShopLocation(shop, 'testDrive')
        if not spawnCoords then
            return Result(false, 'missing_spawn', 'This dealership has no test-drive location configured.')
        end

        local bucket = GetPlayerRoutingBucket(src)
        local clearance = tonumber((Config.TestDrive and Config.TestDrive.clearanceRadius) or Config.TestDriveClearanceRadius) or 4.0
        if not ReserveSpawn(context, spawnCoords, bucket) or not IsSpawnClear(spawnCoords, clearance, bucket) then
            ReleaseSpawn(context)
            return Result(false, 'spawn_blocked', 'The test-drive area is blocked.')
        end

        local plate = ('TEST%04d'):format(math.random(0, 9999))
        local entity, netId, spawnError = CreateServerVehicle(
            testModel,
            GetServerVehicleType(vehicle, category),
            spawnCoords,
            plate,
            bucket,
            nil
        )
        ReleaseSpawn(context)

        if not entity then
            return Result(false, spawnError or 'spawn_failed', 'The test-drive vehicle could not be created.')
        end
        context.entity = entity

        if not PlayerIdentityMatches(src, data.citizenid)
            or not GiveVehicleKeys(src, entity, plate, true) then
            DeleteServerVehicle(entity)
            context.entity = nil
            return Result(false, 'key_delivery_failed', 'Temporary vehicle keys could not be issued.')
        end
        context.keysGiven = true

        SessionSequence = SessionSequence + 1
        local sessionId = SessionSequence
        context.sessionId = sessionId
        local duration = math.max(15, math.floor(tonumber((Config.TestDrive and Config.TestDrive.time) or Config.TestDriveTime) or 300))
        local handoffTimeout = math.max(
            5,
            math.floor(tonumber(Config.TestDrive and Config.TestDrive.handoffTimeout) or 25)
        )
        local handoffUntil = os.time() + handoffTimeout

        TestDrives[src] = {
            id = sessionId,
            citizenid = data.citizenid,
            entity = entity,
            netId = netId,
            model = testModel,
            modelHash = joaat(testModel),
            plate = plate,
            shopId = resolvedShopId,
            origin = vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z),
            returnCoords = GetShopCoords(shop),
            duration = duration,
            handoffUntil = handoffUntil,
            -- The full configured test period begins only after the seated ACK.
            -- This fallback stays beyond the handoff deadline for unready clients.
            expiresAt = handoffUntil + duration
        }
        context.entity = nil
        context.keysGiven = false

        return Result(true, 'test_drive_started', ('Test drive started! You have %s seconds.'):format(duration), {
            sessionId = sessionId,
            duration = duration,
            vehicle = {
                netId = netId, model = testModel, plate = plate, shopId = resolvedShopId,
                sessionId = sessionId
            }
        })
    end, debug.traceback)

    ReleaseSpawn(context)
    if Operations[src] == operation then Operations[src] = nil end

    if not ok then
        if context.sessionId then EndTestDrive(src, 'start_exception', context.sessionId) end
        if context.keysGiven then RemoveTemporaryKeys(src, context.entity) end
        if context.entity then DeleteServerVehicle(context.entity) end
        print(('[drs_vehicleshop] Test-drive callback failed for source %s: %s'):format(src, tostring(result)))
        return Result(false, 'internal_error', 'The test drive could not be started safely.')
    end

    return result
end

local FLEET_ORDER_FIELDS = [[
    order_id, request_id, caller_resource, actor_citizenid, actor_license,
    job, model, vehicle_type, garage_index, minimum_grade, account,
    bank_provider, amount, purchase_reason, status, vehicle_id, plate, garage_operation_id,
    failure_reason
]]

local function NewFleetOrderId(src)
    SessionSequence = SessionSequence + 1
    return ('fleet-%d-%d-%08x-%d'):format(
        os.time(), src, math.random(0, 0x7fffffff), SessionSequence
    )
end

local function GetFleetOrderByRequest(requestId)
    local ok, row = pcall(MySQL.single.await, ([[
        SELECT %s
        FROM drs_vehicle_shop_fleet_orders
        WHERE request_id = ?
        LIMIT 1
    ]]):format(FLEET_ORDER_FIELDS), { requestId })
    if not ok then return nil, tostring(row) end
    return row
end

local function GetFleetOrderById(orderId)
    local ok, row = pcall(MySQL.single.await, ([[
        SELECT %s
        FROM drs_vehicle_shop_fleet_orders
        WHERE order_id = ?
        LIMIT 1
    ]]):format(FLEET_ORDER_FIELDS), { orderId })
    if not ok then return nil, tostring(row) end
    return row
end

local function GetUnresolvedFleetOrder(job)
    local ok, row = pcall(MySQL.single.await, [[
        SELECT order_id, request_id, actor_citizenid, status, model
        FROM drs_vehicle_shop_fleet_orders
        WHERE job = ?
          AND status NOT IN ('stored', 'refunded', 'cancelled', 'payment_failed')
        ORDER BY id ASC
        LIMIT 1
    ]], { job })
    if not ok then return nil, tostring(row) end
    return row
end

local function CreateFleetOrder(caller, data, request, resolved, rule, provider, account)
    local orderId = NewFleetOrderId(request.actorSource)
    local minimumGrade = math.max(
        math.max(0, math.floor(tonumber(GetFleetConfig().MinimumBossGrade) or 0)),
        math.max(0, math.floor(tonumber(rule.minimumGrade) or 0))
    )
    local ok, inserted = pcall(MySQL.insert.await, [[
        INSERT INTO drs_vehicle_shop_fleet_orders
            (order_id, request_id, caller_resource, actor_citizenid, actor_license,
             job, model, vehicle_type, garage_index, minimum_grade, account,
             bank_provider, amount, purchase_reason, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    ]], {
        orderId, request.requestId, caller, data.citizenid, data.license,
        request.job, request.model, resolved.vehicleType, request.garageIndex,
        minimumGrade, account, provider, resolved.price, request.reason
    })

    if ok and inserted then
        local row, readError = GetFleetOrderByRequest(request.requestId)
        if row then return row end
        return nil, readError or 'fleet_order_readback_failed'
    end

    local existing, readError = GetFleetOrderByRequest(request.requestId)
    if existing then return existing, 'duplicate_request' end
    return nil, readError or tostring(inserted or 'fleet_order_insert_failed')
end

local function UpdateFleetOrder(orderId, status, fields, expectedStatuses)
    fields = fields or {}
    local assignments = { 'status = ?' }
    local parameters = { status }
    if fields.vehicleId ~= nil then
        assignments[#assignments + 1] = 'vehicle_id = ?'
        parameters[#parameters + 1] = fields.vehicleId
    end
    if fields.plate ~= nil then
        assignments[#assignments + 1] = 'plate = ?'
        parameters[#parameters + 1] = fields.plate
    end
    if fields.garageOperationId ~= nil then
        assignments[#assignments + 1] = 'garage_operation_id = ?'
        parameters[#parameters + 1] = fields.garageOperationId
    end
    if fields.reason ~= nil then
        fields.reason = tostring(fields.reason):sub(1, 255)
        assignments[#assignments + 1] = 'failure_reason = ?'
        parameters[#parameters + 1] = fields.reason
    elseif fields.clearReason == true or status == 'stored' or status == 'refunded' then
        assignments[#assignments + 1] = 'failure_reason = NULL'
    end

    parameters[#parameters + 1] = orderId
    local where = 'order_id = ?'
    if expectedStatuses ~= nil then
        if type(expectedStatuses) ~= 'table' then expectedStatuses = { expectedStatuses } end
        if #expectedStatuses < 1 then return false end
        local placeholders = {}
        for index, expected in ipairs(expectedStatuses) do
            placeholders[index] = '?'
            parameters[#parameters + 1] = expected
        end
        where = where .. (' AND status IN (%s)'):format(table.concat(placeholders, ', '))
    end

    local query = ('UPDATE drs_vehicle_shop_fleet_orders SET %s WHERE %s'):format(
        table.concat(assignments, ', '), where
    )
    local ok, changed = pcall(MySQL.update.await, query, parameters)
    if not ok then
        print(('[drs_vehicleshop] Failed to update fleet order %s to %s: %s'):format(
            tostring(orderId), tostring(status), tostring(changed)
        ))
        return false
    end
    if changed and changed > 0 then return true end

    local row = GetFleetOrderById(orderId)
    if not row or row.status ~= status then return false end
    if fields.vehicleId ~= nil and tonumber(row.vehicle_id) ~= tonumber(fields.vehicleId) then return false end
    if fields.plate ~= nil and NormalizePlate(row.plate) ~= NormalizePlate(fields.plate) then return false end
    if fields.garageOperationId ~= nil
        and tostring(row.garage_operation_id or '') ~= tostring(fields.garageOperationId) then return false end
    if fields.reason ~= nil and tostring(row.failure_reason or '') ~= fields.reason then return false end
    return true
end

local function FleetOrderMatchesRequest(order, caller, data, request)
    if not order or order.request_id ~= request.requestId then return false end
    if order.caller_resource ~= caller or order.actor_citizenid ~= data.citizenid then return false end
    if tostring(order.job):lower() ~= request.job or tostring(order.model):lower() ~= request.model then return false end
    if tonumber(order.garage_index) ~= request.garageIndex then return false end
    return true
end

local function FleetCreationReviewIsRetryable(order)
    if not order or order.status ~= 'creation_review' then return false end
    local reason = tostring(order.failure_reason or '')
    return reason:find('garage_result_unknown:', 1, true) == 1
        or reason:find('garage_attention_retryable:', 1, true) == 1
        or reason == 'restart_during_fleet_creation'
        or reason == 'fleet_purchase_exception_during_creation'
end

local function FleetOrderResult(order, replayed)
    if not order then
        return Result(false, 'fleet_order_unavailable', 'The fleet order could not be read safely.')
    end
    local extra = {
        orderId = order.order_id,
        requestId = order.request_id,
        operationId = order.garage_operation_id,
        vehicleId = tonumber(order.vehicle_id),
        plate = order.plate and NormalizePlate(order.plate) or nil,
        job = order.job,
        model = order.model,
        amount = tonumber(order.amount) or 0,
        status = order.status,
        replayed = replayed == true
    }
    if order.status == 'stored' then
        extra.committed = true
        return Result(true, 'fleet_purchased', 'The society vehicle was purchased and stored in the job garage.', extra)
    elseif order.status == 'refunded' then
        return Result(false, 'fleet_purchase_refunded', 'The fleet purchase did not complete and the society account was refunded.', extra)
    elseif order.status == 'payment_failed' then
        return Result(false, 'fleet_payment_failed', 'The society payment was rejected.', extra)
    elseif order.status == 'cancelled' then
        return Result(false, 'fleet_purchase_cancelled', 'The fleet purchase was cancelled before payment.', extra)
    elseif order.status == 'payment_review' then
        extra.review = true
        return Result(false, 'fleet_payment_review', 'The society debit result needs staff review before this job can purchase again.', extra)
    elseif order.status == 'refund_review' then
        extra.review = true
        return Result(false, 'fleet_refund_review', 'The society refund result needs staff review.', extra)
    elseif order.status == 'creation_review' then
        extra.review = true
        extra.retryable = FleetCreationReviewIsRetryable(order)
        return Result(false, 'fleet_creation_review', 'Fleet creation is awaiting an idempotent retry or staff review.', extra)
    end
    extra.retryable = true
    return Result(false, 'fleet_purchase_processing', 'The society fleet purchase is still being processed.', extra)
end

local function ProcessFleetRefund(order, reason)
    if not order or not order.order_id then
        return Result(false, 'fleet_refund_unavailable', 'The fleet refund record is unavailable.')
    end
    local orderId = order.order_id
    if FleetRefundProcessing[orderId] then
        return Result(false, 'fleet_refund_processing', 'The society refund is already being processed.', {
            orderId = orderId, retryable = true
        })
    end

    FleetRefundProcessing[orderId] = true
    local ok, result = xpcall(function()
        order = GetFleetOrderById(orderId)
        if not order then return Result(false, 'fleet_refund_unavailable', 'The fleet refund record is unavailable.') end
        if order.status == 'refunded' then return FleetOrderResult(order, true) end
        if order.status ~= 'refund_due' then return FleetOrderResult(order, true) end
        if not UpdateFleetOrder(order.order_id, 'refund_processing', {
            reason = reason or order.failure_reason or 'fleet_creation_failed'
        }, 'refund_due') then
            return Result(false, 'fleet_refund_claim_failed', 'The society refund could not be claimed safely.', {
                orderId = order.order_id, review = true
            })
        end

        local provider = ResolveFleetBankProvider(order.bank_provider)
        if not provider or provider ~= order.bank_provider then
            UpdateFleetOrder(order.order_id, 'refund_due', { reason = 'refund_provider_unavailable' }, 'refund_processing')
            return Result(false, 'fleet_bank_unavailable', 'The original society bank provider is unavailable for the refund.', {
                orderId = order.order_id, retryable = true
            })
        end

        local refunded, refundError = AddSocietyFunds(
            provider,
            order.account,
            tonumber(order.amount) or 0,
            ('drs-fleet-refund-%s'):format(order.order_id)
        )
        if refunded == true then
            if UpdateFleetOrder(order.order_id, 'refunded', { clearReason = true }, 'refund_processing') then
                local refreshed = GetFleetOrderById(order.order_id)
                return FleetOrderResult(refreshed or order, true)
            end
            print(('[drs_vehicleshop] CRITICAL: society refund completed but fleet order %s could not be finalized.'):format(
                tostring(order.order_id)
            ))
            UpdateFleetOrder(order.order_id, 'refund_review', {
                reason = 'refund_confirmed_journal_finalize_failed'
            }, 'refund_processing')
            return Result(false, 'fleet_refund_review', 'The society refund completed but its journal needs staff review.', {
                orderId = order.order_id, review = true
            })
        elseif refunded == false then
            UpdateFleetOrder(order.order_id, 'refund_due', {
                reason = ('refund_rejected:%s'):format(tostring(refundError or 'unknown'))
            }, 'refund_processing')
            return Result(false, 'fleet_refund_retry', 'The society refund was rejected and remains queued.', {
                orderId = order.order_id, retryable = true
            })
        end

        UpdateFleetOrder(order.order_id, 'refund_review', {
            reason = ('refund_result_unknown:%s'):format(tostring(refundError or 'unknown'))
        }, 'refund_processing')
        return Result(false, 'fleet_refund_review', 'The society refund result is unknown and needs staff review.', {
            orderId = order.order_id, review = true
        })
    end, debug.traceback)
    FleetRefundProcessing[orderId] = nil
    if not ok then
        print(('[drs_vehicleshop] Fleet refund failed for order %s: %s'):format(
            tostring(orderId), tostring(result)
        ))
        UpdateFleetOrder(orderId, 'refund_review', { reason = 'refund_exception' }, 'refund_processing')
        return Result(false, 'fleet_refund_review', 'The society refund needs staff review after an internal error.', {
            orderId = orderId, review = true
        })
    end
    return result
end

local function ProcessDueFleetRefunds()
    if not FleetOrdersReady then return true end
    local refunds = MySQL.query.await(([[
        SELECT %s
        FROM drs_vehicle_shop_fleet_orders
        WHERE status = 'refund_due'
        ORDER BY id ASC
        LIMIT 20
    ]]):format(FLEET_ORDER_FIELDS)) or {}
    for _, order in ipairs(refunds) do
        local result = ProcessFleetRefund(order, order.failure_reason)
        if not result.ok and result.review then
            print(('[drs_vehicleshop] Fleet refund order %s needs staff review (%s).'):format(
                tostring(order.order_id), tostring(result.code)
            ))
        end
    end
    return true
end

local function ProcessFleetCreation(order, actorSource)
    order = order and GetFleetOrderById(order.order_id) or nil
    if not order then return Result(false, 'fleet_order_unavailable', 'The fleet order could not be read safely.') end
    if order.status == 'stored' then return FleetOrderResult(order, true) end
    if order.status ~= 'debited' and order.status ~= 'creation_review' then
        return FleetOrderResult(order, true)
    end

    local data, authCode, authMessage = ValidateFleetBoss(actorSource, order.job, order.minimum_grade)
    if not data or data.citizenid ~= order.actor_citizenid then
        if order.status == 'debited' and UpdateFleetOrder(order.order_id, 'refund_due', {
            reason = authCode or 'actor_identity_changed_before_creation'
        }, 'debited') then
            return ProcessFleetRefund(GetFleetOrderById(order.order_id), authCode)
        end
        return Result(false, authCode or 'fleet_creation_review', authMessage or 'Fleet creation needs staff review.', {
            orderId = order.order_id, review = order.status == 'creation_review'
        })
    end

    local ready, runtimeCode, runtimeMessage, _, garageResource = FleetRuntimeReady(false)
    if not ready then
        return Result(false, runtimeCode, runtimeMessage, { orderId = order.order_id, retryable = true })
    end
    if not UpdateFleetOrder(order.order_id, 'creation_processing', {
        reason = 'garage_creation_in_progress'
    }, { 'debited', 'creation_review' }) then
        local refreshed = GetFleetOrderById(order.order_id)
        return FleetOrderResult(refreshed or order, true)
    end

    local called, garageResult = pcall(function()
        return exports[garageResource]:CreateJobFleetVehicle({
            requestId = order.request_id,
            actorSource = actorSource,
            action = 'society_purchase',
            job = order.job,
            model = order.model,
            vehicleType = order.vehicle_type,
            garageIndex = tonumber(order.garage_index),
            minGrade = tonumber(order.minimum_grade) or 0,
            reason = order.purchase_reason or ('Society purchase through DRS Vehicle Shop (%s)'):format(order.order_id)
        })
    end)

    if not called or type(garageResult) ~= 'table' then
        UpdateFleetOrder(order.order_id, 'creation_review', {
            reason = ('garage_result_unknown:%s'):format(tostring(garageResult))
        }, 'creation_processing')
        return Result(false, 'fleet_creation_review', 'DRS Garages did not provide a conclusive creation result.', {
            orderId = order.order_id, review = true, retryable = true
        })
    end

    -- `committed` is authoritative even when DRS Garages also reports a journal
    -- finalization warning through ok=false.
    if garageResult.committed == true then
        local vehicleId = tonumber(garageResult.vehicleId)
        local plate = NormalizePlate(garageResult.plate)
        local operationId = type(garageResult.operationId) == 'string'
            and garageResult.operationId:sub(1, 96) or nil
        if not vehicleId or vehicleId < 1 or not plate or plate == '' or not operationId then
            UpdateFleetOrder(order.order_id, 'creation_review', {
                reason = 'committed_garage_result_missing_identity'
            }, 'creation_processing')
            return Result(false, 'fleet_creation_review', 'The job vehicle exists but its shop journal needs staff review.', {
                orderId = order.order_id, committed = true, review = true
            })
        end
        if UpdateFleetOrder(order.order_id, 'stored', {
            vehicleId = math.floor(vehicleId),
            plate = plate,
            garageOperationId = operationId,
            clearReason = true
        }, 'creation_processing') then
            return FleetOrderResult(GetFleetOrderById(order.order_id) or order, false)
        end
        UpdateFleetOrder(order.order_id, 'creation_review', {
            reason = 'committed_garage_result_journal_finalize_failed'
        }, 'creation_processing')
        return Result(false, 'fleet_creation_review', 'The job vehicle was created, but the shop journal needs staff review.', {
            orderId = order.order_id, vehicleId = vehicleId, plate = plate,
            operationId = operationId, committed = true, review = true
        })
    end

    local garageCode = tostring(garageResult.code or 'garage_creation_failed'):sub(1, 96)
    if garageResult.safeToRefund == true and garageResult.retryable == true then
        UpdateFleetOrder(order.order_id, 'debited', {
            reason = ('garage_retry:%s'):format(garageCode)
        }, 'creation_processing')
        return Result(false, 'fleet_creation_retry', garageResult.message or 'Fleet creation can be retried safely.', {
            orderId = order.order_id, retryable = true
        })
    elseif garageResult.safeToRefund == true then
        if UpdateFleetOrder(order.order_id, 'refund_due', {
            reason = ('garage_safe_failure:%s'):format(garageCode)
        }, 'creation_processing') then
            return ProcessFleetRefund(GetFleetOrderById(order.order_id), garageCode)
        end
        return Result(false, 'fleet_refund_review', 'The safe creation failure could not be queued for refund.', {
            orderId = order.order_id, review = true
        })
    end

    UpdateFleetOrder(order.order_id, 'creation_review', {
        reason = ('%s:%s'):format(
            garageResult.retryable == true and 'garage_attention_retryable' or 'garage_attention',
            garageCode
        )
    }, 'creation_processing')
    return Result(false, 'fleet_creation_review', garageResult.message or 'Fleet creation needs staff review.', {
        orderId = order.order_id,
        operationId = garageResult.operationId,
        vehicleId = tonumber(garageResult.vehicleId),
        plate = garageResult.plate and NormalizePlate(garageResult.plate) or nil,
        review = true,
        retryable = garageResult.retryable == true
    })
end

local function ProcessFleetPayment(order, actorSource)
    order = order and GetFleetOrderById(order.order_id) or nil
    if not order then return Result(false, 'fleet_order_unavailable', 'The fleet order could not be read safely.') end
    if order.status ~= 'pending' then return FleetOrderResult(order, true) end

    local runtimeReady, runtimeCode, runtimeMessage = FleetRuntimeReady(true)
    if not runtimeReady then
        return Result(false, runtimeCode, runtimeMessage, { orderId = order.order_id, retryable = true })
    end

    local data, authCode, authMessage = ValidateFleetBoss(actorSource, order.job, order.minimum_grade)
    if not data or data.citizenid ~= order.actor_citizenid then
        UpdateFleetOrder(order.order_id, 'cancelled', {
            reason = authCode or 'actor_identity_changed_before_payment'
        }, 'pending')
        return Result(false, authCode or 'fleet_purchase_cancelled', authMessage or 'The acting player changed before payment.')
    end

    local provider = ResolveFleetBankProvider(order.bank_provider)
    if not provider or provider ~= order.bank_provider then
        return Result(false, 'fleet_bank_unavailable', 'The selected society bank provider is unavailable.', {
            orderId = order.order_id, retryable = true
        })
    end
    local balance = GetSocietyBalance(provider, order.account)
    if balance == nil then
        return Result(false, 'fleet_bank_unavailable', 'The society balance could not be verified.', {
            orderId = order.order_id, retryable = true
        })
    end
    if balance < (tonumber(order.amount) or 0) then
        UpdateFleetOrder(order.order_id, 'payment_failed', { reason = 'insufficient_society_funds' }, 'pending')
        return FleetOrderResult(GetFleetOrderById(order.order_id) or order, false)
    end
    if not UpdateFleetOrder(order.order_id, 'payment_processing', {
        reason = 'society_debit_in_progress'
    }, 'pending') then
        return FleetOrderResult(GetFleetOrderById(order.order_id) or order, true)
    end

    data, authCode, authMessage = ValidateFleetBoss(actorSource, order.job, order.minimum_grade)
    if not data or data.citizenid ~= order.actor_citizenid then
        UpdateFleetOrder(order.order_id, 'cancelled', {
            reason = authCode or 'actor_identity_changed_before_debit'
        }, 'payment_processing')
        return Result(false, authCode or 'fleet_purchase_cancelled', authMessage or 'The acting player changed before payment.')
    end

    -- QB Banking's society debit does not perform its own sufficient-funds
    -- check. Re-read after claiming the order and completing final actor auth so
    -- another withdrawal during those yields cannot turn this purchase negative.
    local finalBalance, finalBalanceError = GetSocietyBalance(provider, order.account)
    if finalBalance == nil then
        local restored = UpdateFleetOrder(order.order_id, 'pending', {
            reason = ('final_balance_unavailable:%s'):format(tostring(finalBalanceError or 'unknown'))
        }, 'payment_processing')
        if not restored then
            UpdateFleetOrder(order.order_id, 'payment_review', {
                reason = 'final_balance_unavailable_journal_restore_failed'
            }, 'payment_processing')
        end
        return Result(false, restored and 'fleet_bank_unavailable' or 'fleet_payment_review',
            restored and 'The society balance could not be rechecked; retry this order.'
                or 'The payment journal needs staff review before retrying.', {
                orderId = order.order_id, retryable = restored == true, review = restored ~= true
            })
    end
    if finalBalance < (tonumber(order.amount) or 0) then
        UpdateFleetOrder(order.order_id, 'payment_failed', {
            reason = 'insufficient_society_funds_at_debit'
        }, 'payment_processing')
        return FleetOrderResult(GetFleetOrderById(order.order_id) or order, false)
    end

    local debited, debitError = RemoveSocietyFunds(
        provider,
        order.account,
        tonumber(order.amount) or 0,
        ('drs-fleet-purchase-%s'):format(order.order_id)
    )
    if debited == false then
        UpdateFleetOrder(order.order_id, 'payment_failed', {
            reason = ('society_debit_rejected:%s'):format(tostring(debitError or 'unknown'))
        }, 'payment_processing')
        return FleetOrderResult(GetFleetOrderById(order.order_id) or order, false)
    elseif debited ~= true then
        UpdateFleetOrder(order.order_id, 'payment_review', {
            reason = ('society_debit_result_unknown:%s'):format(tostring(debitError or 'unknown'))
        }, 'payment_processing')
        return FleetOrderResult(GetFleetOrderById(order.order_id) or order, false)
    end
    if not UpdateFleetOrder(order.order_id, 'debited', { clearReason = true }, 'payment_processing') then
        UpdateFleetOrder(order.order_id, 'payment_review', {
            reason = 'society_debit_confirmed_journal_finalize_failed'
        }, 'payment_processing')
        return Result(false, 'fleet_payment_review', 'Society funds were debited, but the journal needs staff review.', {
            orderId = order.order_id, review = true
        })
    end
    return ProcessFleetCreation(GetFleetOrderById(order.order_id), actorSource)
end

local function ResumeFleetOrder(order, actorSource)
    if order.status == 'pending' then return ProcessFleetPayment(order, actorSource) end
    if order.status == 'debited' then
        return ProcessFleetCreation(order, actorSource)
    end
    if order.status == 'creation_review' then
        if FleetCreationReviewIsRetryable(order) then return ProcessFleetCreation(order, actorSource) end
    end
    if order.status == 'refund_due' then return ProcessFleetRefund(order, order.failure_reason) end
    return FleetOrderResult(order, true)
end

local function ReconcileFleetOrders()
    if not FleetOrdersReady then return true end
    local transitions = {
        { from = 'pending', to = 'cancelled', reason = 'resource_restart_before_society_debit' },
        { from = 'payment_processing', to = 'payment_review', reason = 'restart_during_society_debit' },
        -- Creation is called only after this journal is advanced from debited to
        -- creation_processing, so a leftover debited row is conclusively safe to refund.
        { from = 'debited', to = 'refund_due', reason = 'restart_before_fleet_creation' },
        { from = 'creation_processing', to = 'creation_review', reason = 'restart_during_fleet_creation' },
        { from = 'refund_processing', to = 'refund_review', reason = 'restart_during_society_refund' }
    }
    for _, transition in ipairs(transitions) do
        local ok, errorMessage = pcall(MySQL.update.await, [[
            UPDATE drs_vehicle_shop_fleet_orders
            SET status = ?, failure_reason = ?
            WHERE status = ?
        ]], { transition.to, transition.reason, transition.from })
        if not ok then error(('fleet journal recovery failed: %s'):format(tostring(errorMessage))) end
    end

    return ProcessDueFleetRefunds()
end

local function GetFleetCatalogExport(request)
    local caller = GetAuthorizedFleetCaller()
    if not caller then return Result(false, 'fleet_caller_denied', 'This resource cannot access fleet checkout.') end
    if type(request) ~= 'table' then return Result(false, 'invalid_request', 'Invalid fleet catalogue request.') end
    for key in pairs(request) do
        if key ~= 'actorSource' and key ~= 'job' then
            return Result(false, 'invalid_request_field', 'Invalid fleet catalogue request.')
        end
    end
    local actorSource = FleetInteger(request.actorSource, 1, 2147483647)
    local job = CleanFleetName(request.job, 50)
    if not actorSource or not job then
        return Result(false, 'invalid_request', 'Invalid fleet catalogue request.')
    end
    local ready, code, message = FleetRuntimeReady(false)
    if not ready then return Result(false, code, message) end

    local rule = GetFleetCatalogRule(job)
    if not rule then return Result(false, 'fleet_job_not_configured', 'This job has no fleet purchasing catalogue.') end
    local minimumGrade = math.max(0, math.floor(tonumber(rule.minimumGrade) or 0))
    local data, authCode, authMessage = ValidateFleetBoss(actorSource, job, minimumGrade)
    if not data then return Result(false, authCode, authMessage) end
    local vehicles, catalogError = BuildFleetCatalog(job)
    if not vehicles then return Result(false, catalogError, 'The fleet catalogue configuration is invalid.') end

    local unresolved, unresolvedError = GetUnresolvedFleetOrder(job)
    if unresolvedError then
        return Result(false, 'fleet_order_guard_unavailable', 'Previous fleet orders could not be checked safely.')
    end
    if unresolved then
        local order, orderError = GetFleetOrderById(unresolved.order_id)
        if not order then
            return Result(false, 'fleet_journal_unavailable', 'The unresolved fleet purchase could not be read safely.', {
                detail = tostring(orderError or 'unknown')
            })
        end
        local actorMatches = order.caller_resource == caller and order.actor_citizenid == data.citizenid
            and tostring(order.job):lower() == job
        local recoveryAllowed = order.status == 'pending' or order.status == 'debited'
            or FleetCreationReviewIsRetryable(order)
        if actorMatches and recoveryAllowed then
            local modelAvailable = false
            for _, item in ipairs(vehicles) do
                if item.model == tostring(order.model):lower() then modelAvailable = true break end
            end
            if not modelAvailable then
                return Result(false, 'fleet_recovery_model_unavailable',
                    'The paid fleet order needs staff review because its model is no longer allowlisted.', {
                        orderId = order.order_id, requestId = order.request_id,
                        status = order.status, review = true
                    })
            end

            local recoveryProvider = ResolveFleetBankProvider(order.bank_provider)
            local recoveryBalance = recoveryProvider and GetSocietyBalance(recoveryProvider, order.account) or nil
            return Result(true, 'fleet_catalog_recovery',
                order.status == 'pending'
                    and 'An interrupted fleet order is ready to resume with its original request ID.'
                    or 'A previously paid fleet order is ready for a safe idempotent retry.', {
                    job = job,
                    account = order.account,
                    bankProvider = order.bank_provider,
                    balance = recoveryBalance or 0,
                    balanceUnavailable = recoveryBalance == nil,
                    vehicles = vehicles,
                    recovery = {
                        requestId = order.request_id,
                        model = tostring(order.model):lower(),
                        garageIndex = tonumber(order.garage_index),
                        status = order.status,
                        retryable = true
                    }
                })
        end

        return Result(false, 'fleet_unresolved_order',
            'This job already has a fleet purchase awaiting completion or staff review.', {
                orderId = order.order_id,
                requestId = order.request_id,
                status = order.status,
                review = order.status == 'payment_review' or order.status == 'creation_review'
                    or order.status == 'refund_review'
            })
    end

    if #vehicles == 0 then
        return Result(false, 'fleet_catalog_empty', 'No vehicles are configured for this job fleet.')
    end
    local provider = ResolveFleetBankProvider()
    if not provider then
        return Result(false, 'fleet_bank_unavailable', 'No supported society banking provider is available.')
    end
    local account = CleanFleetName(rule.account or job, 64)
    if not account then return Result(false, 'fleet_account_invalid', 'This job has an invalid society account configuration.') end
    local balance, balanceError = GetSocietyBalance(provider, account)
    if balance == nil then
        return Result(false, 'fleet_bank_unavailable', 'The society balance could not be verified.', {
            detail = tostring(balanceError or 'unknown')
        })
    end
    return Result(true, 'fleet_catalog', 'Fleet catalogue ready.', {
        job = job,
        account = account,
        bankProvider = provider,
        balance = balance,
        vehicles = vehicles
    })
end

local function PurchaseFleetVehicleExport(request)
    local caller = GetAuthorizedFleetCaller()
    if not caller then return Result(false, 'fleet_caller_denied', 'This resource cannot access fleet checkout.') end
    local normalized, requestError = NormalizeFleetPurchaseRequest(request)
    if not normalized then return Result(false, requestError, 'Invalid society fleet purchase request.') end
    local fleet = GetFleetConfig()
    if fleet.Enabled ~= true then return Result(false, 'fleet_disabled', 'Society fleet checkout is disabled.') end
    if not FleetServiceReady then
        return Result(false, 'fleet_service_unavailable', 'Society fleet checkout is still starting or needs database attention.')
    end
    if GetFramework() ~= 'qbox' then
        return Result(false, 'fleet_framework_unsupported', 'Paid society fleet purchases currently require Qbox.')
    end

    local initialData, authCode, authMessage = ValidateFleetBoss(normalized.actorSource, normalized.job, 0)
    if not initialData then return Result(false, authCode, authMessage) end
    local existing, existingError = GetFleetOrderByRequest(normalized.requestId)
    if existingError then
        return Result(false, 'fleet_journal_unavailable', 'The fleet purchase journal could not be read safely.')
    end
    if existing and not FleetOrderMatchesRequest(existing, caller, initialData, normalized) then
        return Result(false, 'fleet_request_conflict', 'This request id belongs to a different fleet purchase.')
    end

    if FleetRequestOperations[normalized.requestId] or FleetJobOperations[normalized.job] then
        return Result(false, 'fleet_purchase_processing', 'A fleet purchase for this job is already being processed.', {
            requestId = normalized.requestId, retryable = true
        })
    end

    if not existing then
        local now = GetGameTimer()
        local cooldown = math.max(0, math.floor(tonumber(fleet.PurchaseCooldown) or 2500))
        local last = FleetPurchaseCooldowns[normalized.actorSource]
        if last and now - last < cooldown then
            return Result(false, 'fleet_purchase_cooldown', 'Please wait a moment before another fleet purchase.', {
                retryable = true
            })
        end
        FleetPurchaseCooldowns[normalized.actorSource] = now
    end

    FleetRequestOperations[normalized.requestId] = true
    FleetJobOperations[normalized.job] = normalized.requestId
    local ok, result = xpcall(function()
        if existing then
            local data, existingAuthCode, existingAuthMessage = ValidateFleetBoss(
                normalized.actorSource, normalized.job, existing.minimum_grade
            )
            if not data or data.citizenid ~= existing.actor_citizenid then
                return Result(false, existingAuthCode or 'fleet_actor_changed',
                    existingAuthMessage or 'The original fleet purchaser is no longer authorized.')
            end
            return ResumeFleetOrder(existing, normalized.actorSource)
        end

        local ready, runtimeCode, runtimeMessage, provider = FleetRuntimeReady(true)
        if not ready then return Result(false, runtimeCode, runtimeMessage) end
        local resolved, resolveCode, rule = ResolveFleetCatalogVehicle(normalized.job, normalized.model)
        if not resolved then
            return Result(false, resolveCode, 'This vehicle is not available to the current job fleet.')
        end
        local minimumGrade = math.max(0, math.floor(tonumber(rule.minimumGrade) or 0))
        local data, newAuthCode, newAuthMessage = ValidateFleetBoss(
            normalized.actorSource, normalized.job, minimumGrade
        )
        if not data or data.citizenid ~= initialData.citizenid then
            return Result(false, newAuthCode or 'fleet_actor_changed',
                newAuthMessage or 'The acting player changed before the purchase began.')
        end
        local account = CleanFleetName(rule.account or normalized.job, 64)
        if not account then
            return Result(false, 'fleet_account_invalid', 'This job has an invalid society account configuration.')
        end
        local balance = GetSocietyBalance(provider, account)
        if balance == nil then
            return Result(false, 'fleet_bank_unavailable', 'The society balance could not be verified.')
        end
        if balance < resolved.price then
            return Result(false, 'fleet_insufficient_funds', 'The society account cannot afford this vehicle.', {
                amount = resolved.price, balance = balance
            })
        end

        local unresolved, guardError = GetUnresolvedFleetOrder(normalized.job)
        if guardError then
            return Result(false, 'fleet_order_guard_unavailable', 'Previous fleet orders could not be checked safely.')
        elseif unresolved then
            return Result(false, 'fleet_unresolved_order', 'This job already has a fleet purchase awaiting completion or review.', {
                orderId = unresolved.order_id, status = unresolved.status
            })
        end

        local order, createError = CreateFleetOrder(
            caller, data, normalized, resolved, rule, provider, account
        )
        if not order then
            return Result(false, 'fleet_journal_unavailable', 'The fleet purchase could not be journaled safely.', {
                detail = tostring(createError or 'unknown')
            })
        end
        if not FleetOrderMatchesRequest(order, caller, data, normalized) then
            return Result(false, 'fleet_request_conflict', 'This request id belongs to a different fleet purchase.')
        end
        return ResumeFleetOrder(order, normalized.actorSource)
    end, debug.traceback)
    FleetRequestOperations[normalized.requestId] = nil
    if FleetJobOperations[normalized.job] == normalized.requestId then FleetJobOperations[normalized.job] = nil end

    if not ok then
        print(('[drs_vehicleshop] Fleet purchase request %s failed: %s'):format(
            normalized.requestId, tostring(result)
        ))
        local order = GetFleetOrderByRequest(normalized.requestId)
        if order then
            if order.status == 'payment_processing' then
                UpdateFleetOrder(order.order_id, 'payment_review', { reason = 'fleet_purchase_exception_during_debit' }, 'payment_processing')
            elseif order.status == 'creation_processing' then
                UpdateFleetOrder(order.order_id, 'creation_review', { reason = 'fleet_purchase_exception_during_creation' }, 'creation_processing')
            elseif order.status == 'refund_processing' then
                UpdateFleetOrder(order.order_id, 'refund_review', { reason = 'fleet_purchase_exception_during_refund' }, 'refund_processing')
            end
        end
        return Result(false, 'fleet_internal_error', 'The fleet purchase stopped safely and may need staff review.', {
            requestId = normalized.requestId, review = order ~= nil
        })
    end
    return result
end

local function GetFleetServiceStatusExport()
    local caller = GetAuthorizedFleetCaller()
    if not caller then
        return Result(false, 'fleet_caller_denied', 'This resource cannot inspect fleet checkout.')
    end

    local fleet = GetFleetConfig()
    local ready, code, message, provider, garageResource = FleetRuntimeReady(true)
    local statusQueryOk = false
    local statusQueryDetail = FleetOrdersReady and 'fleet order status query has not completed'
        or 'fleet order journal is not ready'
    local reviewOrders, unresolvedOrders = 0, 0

    if FleetOrdersReady then
        local queryOk, counts = pcall(MySQL.single.await, [[
            SELECT
                COALESCE(SUM(CASE WHEN `status` IN ('payment_review', 'creation_review', 'refund_review') THEN 1 ELSE 0 END), 0) AS `review_orders`,
                COALESCE(SUM(CASE WHEN `status` NOT IN ('stored', 'refunded', 'cancelled', 'payment_failed') THEN 1 ELSE 0 END), 0) AS `unresolved_orders`
            FROM `drs_vehicle_shop_fleet_orders`
        ]])
        if queryOk and type(counts) == 'table'
            and tonumber(counts.review_orders) and tonumber(counts.unresolved_orders)
        then
            statusQueryOk = true
            reviewOrders = math.max(0, math.floor(tonumber(counts.review_orders)))
            unresolvedOrders = math.max(0, math.floor(tonumber(counts.unresolved_orders)))
            statusQueryDetail = ('%d unresolved fleet order(s), %d requiring review'):format(
                unresolvedOrders,
                reviewOrders
            )
        else
            statusQueryDetail = queryOk and 'fleet order status query returned invalid data'
                or ('fleet order status query failed: %s'):format(tostring(counts))
        end
    end

    if ready and not statusQueryOk then
        ready = false
        code = 'fleet_journal_status_unavailable'
        message = statusQueryDetail
    end

    return {
        ok = ready == true,
        ready = ready == true,
        enabled = fleet.Enabled == true,
        code = code,
        message = message,
        detail = message,
        bankProvider = provider,
        garageResource = garageResource,
        journalReady = FleetOrdersReady == true,
        statusQueryOk = statusQueryOk,
        statusQueryDetail = statusQueryDetail,
        reviewOrders = reviewOrders,
        unresolvedOrders = unresolvedOrders,
        bankMutationDurable = provider == 'qb-banking',
        bankDurabilityDetail = provider == 'qb-banking'
            and 'QB Banking awaits and returns the affected-row result for society balance mutations.'
            or provider == 'renewed-banking'
                and 'Renewed Banking acknowledges before its asynchronous balance update is durably confirmed.'
                or 'No supported bank provider is active.'
    }
end

exports('GetFleetCatalog', GetFleetCatalogExport)
exports('PurchaseFleetVehicle', PurchaseFleetVehicleExport)
exports('GetFleetServiceStatus', GetFleetServiceStatusExport)

lib.callback.register('drs_vehicleshop:server:quoteVehicle', QuoteVehicle)
lib.callback.register('drs_vehicleshop:server:purchaseVehicle', PurchaseVehicle)
lib.callback.register('drs_vehicleshop:server:acknowledgeDelivery', AcknowledgeDelivery)
lib.callback.register('drs_vehicleshop:server:startTestDrive', StartTestDrive)
lib.callback.register('drs_vehicleshop:server:acknowledgeTestDrive', AcknowledgeTestDrive)

RegisterNetEvent('drs_vehicleshop:server:endTestDrive', function(_, clientReturned, expectedSession)
    expectedSession = tonumber(expectedSession)
    if not expectedSession or expectedSession % 1 ~= 0 then return end

    -- Client-supplied reasons never influence lifecycle behavior. In particular,
    -- clients cannot spoof resource/player shutdown reasons to bypass returning.
    EndTestDrive(source, 'client_request', expectedSession, clientReturned == true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    EndTestDrive(src, 'player_dropped')
    local handoffToken = PendingHandoffsBySource[src]
    local handoff = handoffToken and PendingHandoffs[handoffToken]
    if handoff then RecoverOwnedPurchase(handoff, 'player_dropped_during_handoff') end
    if Operations[src] then Operations[src].dropped = true end
    TestDriveCooldowns[src] = nil
    PurchaseCooldowns[src] = nil
    FleetPurchaseCooldowns[src] = nil
    CheckoutQuoteCooldowns[src] = nil
    local quoteId = CheckoutQuoteBySource[src]
    local quote = quoteId and CheckoutQuotes[quoteId]
    if quote and quote.status ~= 'processing' then CheckoutQuotes[quoteId] = nil end
    CheckoutQuoteBySource[src] = nil
end)

AddEventHandler('entityRemoved', function(entity)
    for plate, delivery in pairs(ActiveDeliveries) do
        if delivery.entity == entity then ActiveDeliveries[plate] = nil end
    end

    for token, handoff in pairs(PendingHandoffs) do
        if handoff.entity == entity then
            RecoverOwnedPurchase(handoff, 'delivery_entity_removed')
        end
    end

    for src, session in pairs(TestDrives) do
        if session.entity == entity then EndTestDrive(src, 'entity_removed', session.id) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, session in pairs(TestDrives) do
        EndTestDrive(src, 'resource_stopped', session.id)
    end
    local handoffs = {}
    for _, handoff in pairs(PendingHandoffs) do handoffs[#handoffs + 1] = handoff end
    for _, handoff in ipairs(handoffs) do
        RecoverOwnedPurchase(handoff, 'resource_stopped_during_handoff')
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local maxDistance = tonumber((Config.TestDrive and Config.TestDrive.maxDistance) or Config.TestDriveMaxDistance) or 750.0

        for src, session in pairs(TestDrives) do
            local entity = session.entity
            local ped = GetPlayerPed(src)

            if session.returning then
                -- The session-scoped fallback or matching client acknowledgement
                -- is now the sole finalizer for this return.
            elseif not entity or entity == 0 or not DoesEntityExist(entity) then
                EndTestDrive(src, 'entity_lost', session.id)
            elseif not ped or ped == 0 or not DoesEntityExist(ped) then
                EndTestDrive(src, 'player_lost', session.id)
            elseif GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entity) then
                EndTestDrive(src, 'bucket_changed', session.id)
            elseif os.time() >= session.handoffUntil
                and (session.ready ~= true
                    or (not (Config.TestDrive and Config.TestDrive.cancelOnExit == false)
                        and GetVehiclePedIsIn(ped, false) ~= entity)) then
                EndTestDrive(src, 'exited_vehicle', session.id)
            elseif maxDistance > 0 and #(GetEntityCoords(entity) - session.origin) > maxDistance then
                EndTestDrive(src, 'geofence', session.id)
            elseif os.time() >= session.expiresAt then
                EndTestDrive(src, 'timeout', session.id)
            end
        end
    end
end)

CreateThread(function()
    BuildVehicleCatalog()
    CleanupOrphanedTestVehicles()

    while not GetFramework() do
        print('[drs_vehicleshop] Waiting for a configured Qbox/QB framework...')
        Wait(5000)
    end

    local databaseReady, databaseError = false, nil
    for attempt = 1, 12 do
        local connected, result = pcall(MySQL.scalar.await, 'SELECT 1', {})
        if connected then
            databaseReady = true
            break
        end
        databaseError = result
        if attempt == 1 or attempt % 3 == 0 then
            print(('[drs_vehicleshop] Waiting for the database before automatic migration (%d/12): %s'):format(
                attempt, tostring(result)
            ))
        end
        Wait(5000)
    end
    if not databaseReady then
        print(('[drs_vehicleshop] Purchase service disabled: database did not become ready: %s'):format(
            tostring(databaseError)
        ))
        return
    end

    local initialized, ready, code = xpcall(function()
        return EnsureServiceReady()
    end, debug.traceback)
    if not initialized or not ready then
        if not initialized then code = ready end
        print(('[drs_vehicleshop] Purchase service disabled: %s'):format(tostring(code)))
        return
    end

    local reconciled, reconcileError = xpcall(ReconcileOrders, debug.traceback)
    if not reconciled then
        ServiceReady = false
        print(('[drs_vehicleshop] Purchase service disabled because order recovery failed: %s'):format(
            tostring(reconcileError)
        ))
        return
    end

    ServiceReady = true
    print(('[drs_vehicleshop] Secure purchase service ready using %s.'):format(GetFramework()))

    if GetFleetConfig().Enabled == true then
        if GetFramework() ~= 'qbox' then
            print('[drs_vehicleshop] Society fleet checkout disabled: the Qbox ownership path is required. Personal purchases remain available.')
        else
            local fleetInitialized, fleetReady, fleetCode = xpcall(EnsureFleetOrderTable, debug.traceback)
            if fleetInitialized and fleetReady then
                local fleetReconciled, fleetReconcileError = xpcall(ReconcileFleetOrders, debug.traceback)
                if fleetReconciled then
                    FleetServiceReady = true
                    print('[drs_vehicleshop] Durable society fleet checkout journal ready (runtime providers are verified per request).')
                else
                    print(('[drs_vehicleshop] Society fleet checkout disabled because recovery failed: %s. Personal purchases remain available.'):format(
                        tostring(fleetReconcileError)
                    ))
                end
            else
                if not fleetInitialized then fleetCode = fleetReady end
                print(('[drs_vehicleshop] Society fleet checkout disabled: %s. Personal purchases remain available.'):format(
                    tostring(fleetCode)
                ))
            end
        end
    else
        print('[drs_vehicleshop] Society fleet checkout disabled by configuration.')
    end

    while true do
        Wait(30000)
        local now = os.time()
        for quoteId, quote in pairs(CheckoutQuotes) do
            local expiredReady = quote.status == 'ready' and now > quote.expiresAt
            local expiredResult = quote.status == 'completed' and now > (quote.resultUntil or quote.expiresAt)
            if expiredReady or expiredResult then
                CheckoutQuotes[quoteId] = nil
                if CheckoutQuoteBySource[quote.src] == quoteId then
                    CheckoutQuoteBySource[quote.src] = nil
                end
            end
        end
        for token, acknowledgement in pairs(DeliveryAcknowledgements) do
            if now > acknowledgement.expiresAt then DeliveryAcknowledgements[token] = nil end
        end
        for _, playerId in ipairs(GetPlayers()) do
            ProcessRefunds(tonumber(playerId))
        end
        if FleetServiceReady then
            local refundsOk, refundsError = xpcall(ProcessDueFleetRefunds, debug.traceback)
            if not refundsOk then
                print(('[drs_vehicleshop] Automatic society refund retry failed: %s'):format(tostring(refundsError)))
            end
        end
    end
end)
