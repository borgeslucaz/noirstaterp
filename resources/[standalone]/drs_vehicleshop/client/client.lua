local Framework = nil
local QBCore = nil
local testDriveVeh = nil
local testDriveNetId = nil
local inTestDrive = false
local vehicleShopPeds = {}
local vehicleShopTargets = {}
local shopBlips = {}
local activeShopId = Config.DefaultShop
local testDriveShopId = nil
local testDriveEndsAt = nil
local testDriveProtection = nil
local testDriveSession = 0
local testDrivePending = false
local testDriveServerSessionId = nil
local serverEndedTestDriveSessionId = nil
local quotePending = false
local quotePendingToken = nil
local purchasePending = false
local testDriveRequestToken = 0
local quoteRequestToken = 0
local purchaseRequestToken = 0
local handoffTransitionSession = 0
local activeHandoffTransition = nil

local function GetFramework()
    if Framework then return Framework end

    local configured = Config.Framework or 'auto'

    if (configured == 'qbox' and GetResourceState('qbx_core') == 'started')
        or (configured == 'auto' and GetResourceState('qbx_core') == 'started') then
        Framework = 'qbox'
    elseif (configured == 'qb' and GetResourceState('qb-core') == 'started')
        or (configured == 'auto' and GetResourceState('qb-core') == 'started') then
        Framework = 'qb'
        QBCore = exports['qb-core']:GetCoreObject()
    else
        -- Do not cache this fallback: an auto-detected framework may still be starting.
        return 'standalone'
    end

    return Framework
end

local function Notify(message, notifyType)
    notifyType = notifyType or 'inform'

    if GetResourceState('qbx_core') == 'started' then
        exports.qbx_core:Notify(message, notifyType)
        return
    end

    if GetResourceState('ox_lib') == 'started' and lib then
        lib.notify({
            description = message,
            type = notifyType
        })
        return
    end

    if GetFramework() == 'qb' and QBCore then
        QBCore.Functions.Notify(message, notifyType == 'inform' and 'primary' or notifyType)
        return
    end

    print(('[drs_vehicleshop] %s'):format(message))
end

local function GetTarget()
    local configured = Config.Target or 'auto'

    if configured == 'ox_target' or (configured == 'auto' and GetResourceState('ox_target') == 'started') then
        return 'ox_target'
    end

    if configured == 'qb-target' or (configured == 'auto' and GetResourceState('qb-target') == 'started') then
        return 'qb-target'
    end

    if Config.UseOxTarget and GetResourceState('ox_target') == 'started' then
        return 'ox_target'
    end

    return nil
end

local function GetLegacyShop()
    return {
        label = 'Vehicle Shop',
        type = 'car',
        ped = {
            model = Config.PedModel or 'cs_siemonyetarian',
            coords = Config.PedLocation or vector4(-55.57, -1097.98, 26.42, 351.45)
        },
        dealership = Config.DealershipCoords or vector3(-56.05, -1096.37, 26.42),
        testDrive = Config.TestDriveCoords or vector4(-47.6, -1080.99, 26.28, 70.38),
        spawn = Config.VehicleSpawnCoords or vector4(-18.2, -1103.5, 26.2, 159.75),
        targetLabel = Config.BrowseLabel or 'Browse Vehicles'
    }
end

local function GetShop(shopId)
    if type(Config.Shops) == 'table' then
        if shopId and Config.Shops[shopId] then
            return Config.Shops[shopId], shopId
        end

        local defaultShop = Config.DefaultShop
        if defaultShop and Config.Shops[defaultShop] then
            return Config.Shops[defaultShop], defaultShop
        end

        for id, shop in pairs(Config.Shops) do
            return shop, id
        end
    end

    return GetLegacyShop(), 'default'
end

local vehiclePresentationByModel
local vehiclePresentationByHash

local function CleanVehiclePresentationModel(value)
    if type(value) ~= 'string' then return end

    local model = value:match('^%s*([%w_-]+)%s*$')
    if not model or #model > 64 then return end

    return model:lower()
end

local function CleanVehiclePresentationText(value, maxLength)
    if type(value) ~= 'string' and type(value) ~= 'number' then return end

    local text = tostring(value):gsub('[%z\1-\31\127]', '')
    if #text > (maxLength or 96) then text = text:sub(1, maxLength or 96) end

    return text ~= '' and text or nil
end

local function CleanVehiclePresentationImage(value)
    if type(value) ~= 'string' or #value > 128 then return end

    local filename = value:match('([^/\\]+)$')
    if not filename or not filename:match('^[%w_.-]+$') then return end

    local extension = filename:match('%.([%w]+)$')
    if not extension then
        filename = filename .. '.webp'
        extension = 'webp'
    end

    extension = extension:lower()
    if extension ~= 'webp' and extension ~= 'png' then return end

    return filename
end

local function NormalizeVehiclePresentationHash(value)
    local hash = tonumber(value)
    if not hash then return end

    return math.floor(hash) % 4294967296
end

local function BuildVehiclePresentationIndex()
    if vehiclePresentationByModel then return end

    vehiclePresentationByModel = {}
    vehiclePresentationByHash = {}
    local resourceName = GetCurrentResourceName()

    for _, categoryVehicles in pairs(type(Config.Vehicles) == 'table' and Config.Vehicles or {}) do
        for vehicleKey, vehicle in pairs(type(categoryVehicles) == 'table' and categoryVehicles or {}) do
            if type(vehicle) == 'table' then
                local model = CleanVehiclePresentationModel(vehicle.model or vehicleKey)

                if model then
                    local candidates, seen = {}, {}
                    local function AddCandidate(url)
                        if not url or seen[url] then return end

                        seen[url] = true
                        candidates[#candidates + 1] = url
                    end
                    local function AddLocalImage(filename)
                        filename = CleanVehiclePresentationImage(filename)
                        if filename then
                            AddCandidate(('https://cfx-nui-%s/html/assets/vehicles/%s'):format(resourceName, filename))
                        end
                    end

                    AddLocalImage(vehicle.image)

                    if vehicle.isAddon == true then
                        AddLocalImage(model .. '.webp')
                        AddCandidate(('https://docs.fivem.net/vehicles/%s.webp'):format(model))
                    else
                        AddCandidate(('https://docs.fivem.net/vehicles/%s.webp'):format(model))
                        AddLocalImage(model .. '.webp')
                    end

                    local presentation = {
                        model = model,
                        name = CleanVehiclePresentationText(vehicle.name, 96),
                        brand = CleanVehiclePresentationText(vehicle.brand, 48),
                        isAddon = vehicle.isAddon == true,
                        candidates = candidates
                    }

                    vehiclePresentationByModel[model] = presentation

                    local hashFunction = joaat or GetHashKey
                    local ok, hash = pcall(hashFunction, model)
                    hash = ok and NormalizeVehiclePresentationHash(hash) or nil
                    if hash then vehiclePresentationByHash[hash] = presentation end
                end
            end
        end
    end
end

local function ResolveVehiclePresentation(value)
    BuildVehiclePresentationIndex()

    local presentation
    if type(value) == 'number' then
        presentation = vehiclePresentationByHash[NormalizeVehiclePresentationHash(value)]
    else
        local model = CleanVehiclePresentationModel(value)
        presentation = model and vehiclePresentationByModel[model] or nil
    end

    if not presentation then return end

    local candidates = {}
    for i = 1, #presentation.candidates do candidates[i] = presentation.candidates[i] end

    return {
        model = presentation.model,
        name = presentation.name,
        brand = presentation.brand,
        isAddon = presentation.isAddon,
        candidates = candidates
    }
end

exports('ResolveVehiclePresentation', ResolveVehiclePresentation)

local shopPresentationDefaults = {
    auto = {
        image = 'assets/shops/auto.webp',
        logo = 'assets/shops/pdm.svg',
        eyebrow = 'Vehicle showroom',
        title = 'Choose a vehicle to begin',
        description = 'Select a vehicle from the catalogue to view its details and available actions.',
        details = {
            { label = 'Showroom', value = 'Browse the available road vehicle inventory' },
            { label = 'Test drives', value = 'Preview a vehicle before committing to a purchase' },
            { label = 'Delivery', value = 'Receive it directly or stage it safely in a garage' }
        }
    },
    boat = {
        image = 'assets/shops/boat.webp',
        logo = 'assets/shops/pds.svg',
        eyebrow = 'Marina sales',
        title = 'Choose a vessel to begin',
        description = 'Select a vessel from the catalogue to view its details and available actions.',
        details = {
            { label = 'Marina', value = 'Browse the available watercraft inventory' },
            { label = 'Water tests', value = 'Preview a vessel from the marina launch' },
            { label = 'Boathouse', value = 'Store purchases at a configured marina garage' }
        }
    },
    air = {
        image = 'assets/shops/air.webp',
        logo = 'assets/shops/lsa.svg',
        eyebrow = 'Aircraft sales',
        title = 'Choose an aircraft to begin',
        description = 'Select an aircraft from the catalogue to view its details and available actions.',
        details = {
            { label = 'Hangar', value = 'Browse helicopters and fixed-wing aircraft' },
            { label = 'Flight tests', value = 'Preview an aircraft from the airport apron' },
            { label = 'Storage', value = 'Store purchases at a configured airport hangar' }
        }
    }
}

local function CleanPresentationText(value, fallback, maximumLength)
    if type(value) ~= 'string' then
        value = fallback
    end

    value = type(value) == 'string' and value or ''
    value = value:gsub('%c', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''

    if value == '' and type(fallback) == 'string' then
        value = fallback:gsub('%c', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    end

    return value:sub(1, maximumLength)
end

local function BuildShopPresentation(shop, shopId)
    local shopType = shop and shop.type or 'car'
    local defaultKey = 'auto'

    if shopId == 'boat' or shopType == 'boat' then
        defaultKey = 'boat'
    elseif shopId == 'air' or shopType == 'air' then
        defaultKey = 'air'
    end

    local defaults = shopPresentationDefaults[defaultKey]
    local configured = type(shop and shop.presentation) == 'table' and shop.presentation or {}
    local configuredDetails = type(configured.details) == 'table' and configured.details or {}
    local details = {}

    for index, defaultDetail in ipairs(defaults.details) do
        local configuredDetail = type(configuredDetails[index]) == 'table' and configuredDetails[index] or {}

        details[index] = {
            label = CleanPresentationText(configuredDetail.label, defaultDetail.label, 32),
            value = CleanPresentationText(configuredDetail.value, defaultDetail.value, 112)
        }
    end

    local logo = CleanPresentationText(configured.logo, defaults.logo, 96)

    local validLogo = logo:match('^assets/shops/[%w_-]+%.svg$')
        or logo:match('^assets/shops/[%w_-]+%.webp$')

    if not validLogo then
        logo = defaults.logo
    end

    local image = CleanPresentationText(configured.image, defaults.image, 96)

    if not image:match('^assets/shops/[%w_-]+%.webp$') then
        image = defaults.image
    end

    return {
        image = image,
        logo = logo,
        eyebrow = CleanPresentationText(configured.eyebrow, defaults.eyebrow, 48),
        title = CleanPresentationText(configured.title, defaults.title, 72),
        description = CleanPresentationText(configured.description, defaults.description, 240),
        details = details
    }
end

local function CleanCheckoutId(value, maximumLength)
    if type(value) ~= 'string' then return nil end

    value = value:match('^%s*(.-)%s*$') or ''
    if value == '' or #value > maximumLength or not value:match('^[A-Za-z0-9_-]+$') then
        return nil
    end

    return value
end

local function CleanCheckoutPlateImage(value)
    if type(value) ~= 'string' or #value > 96 then return nil end

    return value:match('^assets/plates/[%w_-]+%.png$')
        or value:match('^assets/plates/[%w_-]+%.webp$')
end

local function BuildCheckoutOptionList(configuredOptions, optionType, maximumOptions)
    local options = {}
    local optionIds = {}

    if type(configuredOptions) ~= 'table' then return options, optionIds end

    for _, configuredOption in ipairs(configuredOptions) do
        if #options >= maximumOptions then break end

        if type(configuredOption) == 'table' then
            local id = CleanCheckoutId(configuredOption.id, 64)

            if id and not optionIds[id] then
                local option = {
                    id = id,
                    label = CleanPresentationText(configuredOption.label, id, 48)
                }

                if optionType == 'color' then
                    local swatch = type(configuredOption.swatch) == 'string'
                        and configuredOption.swatch:match('^#%x%x%x%x%x%x$')
                        or nil

                    if swatch then option.swatch = swatch:upper() end
                elseif optionType == 'plateStyle' then
                    option.preview = CleanPresentationText(configuredOption.preview, option.label, 48)
                    option.image = CleanCheckoutPlateImage(configuredOption.image)
                elseif optionType == 'delivery' then
                    option.description = CleanPresentationText(configuredOption.description, '', 128)
                end

                options[#options + 1] = option
                optionIds[id] = true
            end
        end
    end

    return options, optionIds
end

local function BuildFeaturedCheckoutColors(options, configuredIds, requiredIds, maximumOptions)
    maximumOptions = math.max(1, math.floor(tonumber(maximumOptions) or 5))

    local optionsById = {}
    local featured = {}
    local featuredIds = {}
    local requiredIdSet = {}

    for _, option in ipairs(options) do
        optionsById[option.id] = option
    end

    local function AddOption(id)
        id = CleanCheckoutId(id, 64)

        if not id or featuredIds[id] or not optionsById[id] or #featured >= maximumOptions then
            return false
        end

        featured[#featured + 1] = optionsById[id]
        featuredIds[id] = true
        return true
    end

    if type(requiredIds) == 'table' then
        for _, id in ipairs(requiredIds) do
            id = CleanCheckoutId(id, 64)
            if id and optionsById[id] then requiredIdSet[id] = true end
        end
    end

    if type(configuredIds) == 'table' then
        for _, id in ipairs(configuredIds) do
            AddOption(id)
        end
    end

    -- Invalid or incomplete presentation lists fall back to the authoritative
    -- color order rather than leaving the checkout with too few choices.
    for _, option in ipairs(options) do
        AddOption(option.id)
    end

    -- Defaults must remain selectable even if an administrator later chooses a
    -- default that is not in the featured list. Replace the lowest-priority
    -- non-default slot when all five presentation slots are already occupied.
    for _, id in ipairs(requiredIds or {}) do
        id = CleanCheckoutId(id, 64)

        if id and optionsById[id] and not featuredIds[id] then
            local replacementIndex

            for index = #featured, 1, -1 do
                if not requiredIdSet[featured[index].id] then
                    replacementIndex = index
                    break
                end
            end

            if replacementIndex then
                featuredIds[featured[replacementIndex].id] = nil
                featured[replacementIndex] = optionsById[id]
                featuredIds[id] = true
            elseif #featured < maximumOptions then
                AddOption(id)
            end
        end
    end

    return featured, featuredIds
end

local function CheckoutDefaultId(value, optionIds, options)
    local id = CleanCheckoutId(value, 64)
    if id and optionIds[id] then return id end
    return options[1] and options[1].id or nil
end

local function BuildCheckoutPresentation(shop)
    local configured = type(Config.Checkout) == 'table' and Config.Checkout or {}
    local configuredDefaults = type(configured.defaults) == 'table' and configured.defaults or {}
    local configuredCapabilities = type(configured.capabilities) == 'table' and configured.capabilities or {}
    local configuredPlatePrefix = type(configured.platePrefix) == 'table' and configured.platePrefix or {}
    local shopType = type(shop) == 'table' and shop.type or 'car'
    local supportsRoadPlates = shopType ~= 'boat' and shopType ~= 'air'
    local requiredColorIds = {}

    if configuredDefaults.primaryColorId ~= nil then
        requiredColorIds[#requiredColorIds + 1] = configuredDefaults.primaryColorId
    end

    if configuredDefaults.secondaryColorId ~= nil then
        requiredColorIds[#requiredColorIds + 1] = configuredDefaults.secondaryColorId
    end

    local allColors = BuildCheckoutOptionList(configured.colors, 'color', 64)
    local colors, colorIds = BuildFeaturedCheckoutColors(
        allColors,
        configured.featuredColorIds,
        requiredColorIds,
        5
    )
    local plateStyles, plateStyleIds = BuildCheckoutOptionList(configured.plateStyles, 'plateStyle', 16)
    local deliveryModes, deliveryModeIds = BuildCheckoutOptionList(configured.deliveryModes, 'delivery', 8)
    local shopHasSpawn = type(shop) == 'table' and (
        shop.spawn ~= nil
        or (type(shop.locations) == 'table' and shop.locations.spawn ~= nil)
    )
    local driveawayAvailable = configuredCapabilities.delivery ~= false
        and Config.DeliverPurchasedVehicles ~= false
        and tonumber(Config.PurchasedVehicleState or 0) == 0
        and shopHasSpawn

    if not driveawayAvailable and deliveryModeIds.driveaway then
        local filteredModes = {}
        deliveryModeIds = {}

        for _, deliveryMode in ipairs(deliveryModes) do
            if deliveryMode.id ~= 'driveaway' then
                filteredModes[#filteredModes + 1] = deliveryMode
                deliveryModeIds[deliveryMode.id] = true
            end
        end

        deliveryModes = filteredModes
    end

    local capabilities = {
        colors = configuredCapabilities.colors ~= false and #colors > 0,
        secondaryColor = configuredCapabilities.secondaryColor ~= false and #colors > 0,
        platePrefix = supportsRoadPlates
            and configuredCapabilities.platePrefix ~= false
            and configuredPlatePrefix.enabled ~= false,
        plateStyles = supportsRoadPlates and configuredCapabilities.plateStyles ~= false and #plateStyles > 0,
        delivery = configuredCapabilities.delivery ~= false and #deliveryModes > 0
    }

    local plateMode = configuredDefaults.plateMode == 'prefix' and capabilities.platePrefix and 'prefix' or 'standard'
    local deliveryDefault = CheckoutDefaultId(configuredDefaults.deliveryMode, deliveryModeIds, deliveryModes)

    if not driveawayAvailable then
        deliveryDefault = 'garage'
    end

    local safeDeliveryAvailable = deliveryDefault ~= nil
        and (driveawayAvailable or deliveryModeIds.garage == true)

    return {
        enabled = configured.enabled ~= false and safeDeliveryAvailable,
        colors = colors,
        plateStyles = plateStyles,
        deliveryModes = deliveryModes,
        defaults = {
            primaryColorId = CheckoutDefaultId(configuredDefaults.primaryColorId, colorIds, colors),
            secondaryColorId = CheckoutDefaultId(configuredDefaults.secondaryColorId, colorIds, colors),
            plateMode = plateMode,
            plateStyleId = CheckoutDefaultId(configuredDefaults.plateStyleId, plateStyleIds, plateStyles),
            deliveryMode = deliveryDefault
        },
        capabilities = capabilities
    }
end

local function SanitizeCheckoutCustomization(value)
    local configured = type(Config.Checkout) == 'table' and Config.Checkout or {}
    local prefixConfig = type(configured.platePrefix) == 'table' and configured.platePrefix or {}
    local prefixMaximum = tonumber(prefixConfig.maxLength) or 3
    prefixMaximum = math.max(1, math.min(3, math.floor(prefixMaximum)))
    value = type(value) == 'table' and value or {}

    local customization = {
        primaryColorId = CleanCheckoutId(value.primaryColorId, 64),
        secondaryColorId = CleanCheckoutId(value.secondaryColorId, 64),
        plateStyleId = CleanCheckoutId(value.plateStyleId, 64),
        deliveryMode = CleanCheckoutId(value.deliveryMode, 64)
    }

    if value.plateMode == 'standard' or value.plateMode == 'prefix' then
        customization.plateMode = value.plateMode
    end

    if type(value.platePrefix) == 'string' then
        local prefix = value.platePrefix:upper():match('^%s*(.-)%s*$') or ''
        if #prefix <= prefixMaximum and prefix:match('^[A-Z0-9]*$') then
            customization.platePrefix = prefix
        end
    end

    return customization
end

local function GetPedCoords(shop)
    local ped = shop and shop.ped

    if ped and ped.x then return ped end
    if type(ped) == 'table' then
        return ped.coords or ped.location or ped.position
    end

    return shop and (shop.pedCoords or shop.PedLocation or shop.dealership or shop.coords) or nil
end

local function GetPedModel(shop)
    local ped = shop and shop.ped

    if type(ped) == 'table' and ped.model then
        return ped.model
    end

    return shop and (shop.pedModel or shop.model) or Config.PedModel or 'cs_siemonyetarian'
end

local function GetCoords(name, shopId)
    local shop = GetShop(shopId)

    if shop then
        if shop.locations and shop.locations[name] then
            return shop.locations[name]
        end

        if name == 'testDrive' then
            return shop.testDrive or Config.TestDriveCoords or vector4(-47.6, -1080.99, 26.28, 70.38)
        elseif name == 'spawn' then
            return shop.spawn or Config.VehicleSpawnCoords or vector4(-18.2, -1103.5, 26.2, 159.75)
        elseif name == 'dealership' then
            return shop.dealership or shop.coords or GetPedCoords(shop) or Config.DealershipCoords or vector3(-56.05, -1096.37, 26.42)
        end
    end

    if Config.Locations and Config.Locations[name] then
        return Config.Locations[name]
    end

    if name == 'testDrive' then
        return Config.TestDriveCoords or vector4(-47.6, -1080.99, 26.28, 70.38)
    elseif name == 'spawn' then
        return Config.VehicleSpawnCoords or vector4(-18.2, -1103.5, 26.2, 159.75)
    elseif name == 'dealership' then
        return Config.DealershipCoords or vector3(-56.05, -1096.37, 26.42)
    end
end

local function ShopAllowsCategory(shop, category)
    local categories = shop and shop.categories

    if type(categories) ~= 'table' then return true end
    if categories[category] == true then return true end

    for _, allowedCategory in pairs(categories) do
        if allowedCategory == category then
            return true
        end
    end

    return false
end

local vehiclePerformanceCache = {}
local METRES_PER_SECOND_TO_MPH = 2.236936

local function BoundedInteger(value, multiplier, maximum)
    value = tonumber(value)

    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end

    value = value * (multiplier or 1.0)
    value = math.max(0.0, math.min(maximum, value))

    return math.floor(value + 0.5)
end

local function SafeModelMetric(metric, modelHash)
    local success, value = pcall(metric, modelHash)

    if not success then return nil end

    value = tonumber(value)

    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end

    return value
end

local function GetVehiclePerformance(model)
    local modelHash

    if type(model) == 'number' and model == model and model ~= math.huge and model ~= -math.huge then
        modelHash = math.floor(model)
    elseif type(model) == 'string' and model ~= '' then
        modelHash = joaat(model)
    end

    if not modelHash or modelHash == 0 then
        return { available = false, supported = false }
    end

    if vehiclePerformanceCache[modelHash] then
        return vehiclePerformanceCache[modelHash]
    end

    local performance = { available = false, supported = false }
    vehiclePerformanceCache[modelHash] = performance

    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        return performance
    end

    performance.supported = true

    -- The speed native returns metres per second. GTA's other model metrics use
    -- compact handling ranges, so convert them to stable 0-100 presentation bars.
    local topSpeedMph = BoundedInteger(
        SafeModelMetric(GetVehicleModelEstimatedMaxSpeed, modelHash),
        METRES_PER_SECOND_TO_MPH,
        400
    )
    local acceleration = BoundedInteger(SafeModelMetric(GetVehicleModelAcceleration, modelHash), 100, 100)
    local braking = BoundedInteger(SafeModelMetric(GetVehicleModelMaxBraking, modelHash), 100, 100)
    local traction = BoundedInteger(SafeModelMetric(GetVehicleModelMaxTraction, modelHash), 25, 100)
    local classId = SafeModelMetric(GetVehicleClassFromName, modelHash)

    if classId then
        classId = math.floor(classId)

        if classId < 0 or classId > 22 then
            classId = nil
        end
    end

    if topSpeedMph and acceleration and braking and traction then
        performance.available = true
        performance.topSpeedMph = topSpeedMph
        performance.acceleration = acceleration
        performance.braking = braking
        performance.traction = traction
        performance.classId = classId
    end

    return performance
end

local function BuildShopInventory(shop)
    local categories = {}
    local vehicles = {}

    for category, categoryVehicles in pairs(Config.Vehicles or {}) do
        if ShopAllowsCategory(shop, category) then
            categories[category] = (Config.Categories and Config.Categories[category]) or category
            vehicles[category] = {}

            for vehicleKey, vehicle in pairs(categoryVehicles) do
                if type(vehicle) == 'table' then
                    local enrichedVehicle = {}

                    for key, value in pairs(vehicle) do
                        enrichedVehicle[key] = value
                    end

                    enrichedVehicle.performance = GetVehiclePerformance(enrichedVehicle.model or vehicleKey)
                    vehicles[category][vehicleKey] = enrichedVehicle
                else
                    vehicles[category][vehicleKey] = vehicle
                end
            end
        end
    end

    return categories, vehicles
end

local function CleanCategoryId(value)
    if type(value) ~= 'string' then return nil end

    value = value:match('^%s*(.-)%s*$') or ''

    if value == '' or #value > 64 or not value:match('^[A-Za-z0-9_-]+$') then
        return nil
    end

    return value
end

local function CategoryHasInventory(category, categories, vehicles)
    return category ~= nil
        and categories[category] ~= nil
        and type(vehicles[category]) == 'table'
        and next(vehicles[category]) ~= nil
end

local function BuildCategoryOrder(shop, categories, vehicles)
    local categoryOrder = {}
    local included = {}

    local function AddCategory(value)
        local category = CleanCategoryId(value)

        if not category or included[category] or not CategoryHasInventory(category, categories, vehicles) then
            return
        end

        categoryOrder[#categoryOrder + 1] = category
        included[category] = true
    end

    -- Array-style shop categories retain the deliberate ordering from config.
    if type(shop and shop.categories) == 'table' then
        for _, category in ipairs(shop.categories) do
            AddCategory(category)
        end
    end

    -- Unrestricted and map-style legacy configurations get a deterministic
    -- fallback rather than inheriting Lua/JSON map iteration order.
    local remaining = {}

    for rawCategory in pairs(categories) do
        local category = CleanCategoryId(rawCategory)

        if category and not included[category] and CategoryHasInventory(category, categories, vehicles) then
            remaining[#remaining + 1] = category
        end
    end

    table.sort(remaining)

    for _, category in ipairs(remaining) do
        AddCategory(category)
    end

    return categoryOrder
end

local function ResolveDefaultCategory(shop, categoryOrder, categories, vehicles)
    local configured = CleanCategoryId(shop and shop.defaultCategory)

    if configured and CategoryHasInventory(configured, categories, vehicles) then
        return configured
    end

    return categoryOrder[1]
end

local function LoadModel(model)
    local modelHash = type(model) == 'number' and model or joaat(model)

    if not IsModelInCdimage(modelHash) then
        return nil
    end

    RequestModel(modelHash)

    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) do
        Wait(0)

        if GetGameTimer() > timeout then
            return nil
        end
    end

    return modelHash
end

local function SetFuel(vehicle, amount)
    amount = amount or 100.0

    local fuelScript = Config.FuelScript or Config.Fuel or 'auto'

    if fuelScript == 'auto' then
        if GetResourceState('ox_fuel') == 'started' then
            fuelScript = 'ox_fuel'
        elseif GetResourceState('LegacyFuel') == 'started' then
            fuelScript = 'LegacyFuel'
        elseif GetResourceState('ps-fuel') == 'started' then
            fuelScript = 'ps-fuel'
        elseif GetResourceState('cdn-fuel') == 'started' then
            fuelScript = 'cdn-fuel'
        else
            fuelScript = 'native'
        end
    end

    if fuelScript == 'ox_fuel' then
        Entity(vehicle).state.fuel = amount
    elseif fuelScript == 'LegacyFuel' and GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, amount)
    elseif fuelScript == 'ps-fuel' and GetResourceState('ps-fuel') == 'started' then
        exports['ps-fuel']:SetFuel(vehicle, amount)
    elseif fuelScript == 'cdn-fuel' and GetResourceState('cdn-fuel') == 'started' then
        exports['cdn-fuel']:SetFuel(vehicle, amount)
    else
        SetVehicleFuelLevel(vehicle, amount + 0.0)
    end
end

local function BuildNuiResponse(ok, code, message)
    return {
        ok = ok == true,
        code = code,
        message = message
    }
end

local function AwaitServerCallback(name, ...)
    if not lib or not lib.callback or not lib.callback.await then
        return {
            ok = false,
            code = 'ox_lib_unavailable',
            message = 'The vehicle shop service is unavailable.'
        }
    end

    local args = { ... }
    local ok, response = pcall(function()
        return lib.callback.await(name, false, table.unpack(args))
    end)

    if not ok then
        print(('[drs_vehicleshop] Callback %s failed: %s'):format(name, tostring(response)))
        return {
            ok = false,
            code = 'callback_failed',
            message = 'The vehicle shop did not respond. Please try again.'
        }
    end

    if type(response) ~= 'table' then
        return {
            ok = false,
            code = 'invalid_response',
            message = 'The vehicle shop returned an invalid response.'
        }
    end

    return response
end

local function BoundedHandoffDuration(value, fallback, maximum)
    value = tonumber(value)

    if not value or value ~= value or value == math.huge or value == -math.huge then
        value = fallback
    end

    return math.max(0, math.min(maximum, math.floor(value)))
end

local function GetHandoffTransitionSettings()
    local configured = type(Config.HandoffTransition) == 'table' and Config.HandoffTransition or {}
    local settings = {
        enabled = configured.enabled == true,
        fadeOut = BoundedHandoffDuration(configured.fadeOut, 350, 2000),
        fadeIn = BoundedHandoffDuration(configured.fadeIn, 650, 3000),
        settle = BoundedHandoffDuration(configured.settle, 400, 2000),
        collisionTimeout = BoundedHandoffDuration(configured.collisionTimeout, 2500, 5000),
        spinner = configured.spinner == true
    }

    local entityTimeout = BoundedHandoffDuration(Config.EntityHandoffTimeout, 10000, 30000)
    local minimumBlackout = math.min(45000,
        entityTimeout + settings.collisionTimeout + settings.settle + 1000)
    settings.maxBlackout = math.max(
        minimumBlackout,
        BoundedHandoffDuration(configured.maxBlackout, 18000, 45000)
    )

    return settings
end

local function StopHandoffLoadScene(transition)
    if not transition or not transition.loadSceneStarted then return end

    transition.loadSceneStarted = false
    pcall(NewLoadSceneStop)
end

local function RestoreHandoffVisuals(transition, immediate)
    if not transition or transition.finished then return end

    transition.finished = true
    StopHandoffLoadScene(transition)

    if transition.spinnerStarted then
        transition.spinnerStarted = false
        pcall(BusyspinnerOff)
    end

    if transition.ownsFade and not IsScreenFadedIn() then
        DoScreenFadeIn(immediate and 0 or transition.settings.fadeIn)
    end

    if activeHandoffTransition == transition then
        activeHandoffTransition = nil
    end
end

local function ForceRestoreHandoffTransition()
    handoffTransitionSession = handoffTransitionSession + 1

    local transition = activeHandoffTransition
    activeHandoffTransition = nil
    RestoreHandoffVisuals(transition, true)
end

local function HandoffRequestIsValid(transition, requestStillValid)
    return transition
        and not transition.finished
        and transition.session == handoffTransitionSession
        and (not requestStillValid or requestStillValid())
end

local function BeginHandoffTransition(label, requestStillValid)
    local settings = GetHandoffTransitionSettings()
    if not settings.enabled then return nil end
    if requestStillValid and not requestStillValid() then return nil, 'cancelled' end

    ForceRestoreHandoffTransition()
    handoffTransitionSession = handoffTransitionSession + 1

    local transition = {
        session = handoffTransitionSession,
        settings = settings,
        finished = false,
        ownsFade = not IsScreenFadedOut() and not IsScreenFadingOut(),
        spinnerStarted = false,
        loadSceneStarted = false
    }
    activeHandoffTransition = transition

    if settings.spinner then
        local statusOk, spinnerAlreadyActive = pcall(BusyspinnerIsOn)
        local spinnerOk = statusOk and not spinnerAlreadyActive and pcall(function()
            BeginTextCommandBusyspinnerOn('STRING')
            AddTextComponentSubstringPlayerName(label or 'Preparing your vehicle...')
            EndTextCommandBusyspinnerOn(4)
        end)
        transition.spinnerStarted = spinnerOk == true
    end

    if transition.ownsFade then
        DoScreenFadeOut(settings.fadeOut)

        local fadeDeadline = GetGameTimer() + settings.fadeOut + 1000
        while not IsScreenFadedOut() and GetGameTimer() < fadeDeadline do
            if not HandoffRequestIsValid(transition, requestStillValid) then
                RestoreHandoffVisuals(transition)
                return nil, 'cancelled'
            end

            Wait(0)
        end
    end

    CreateThread(function()
        local deadline = GetGameTimer() + settings.maxBlackout

        while activeHandoffTransition == transition
            and not transition.finished
            and GetGameTimer() < deadline do
            Wait(100)
        end

        if activeHandoffTransition == transition and not transition.finished then
            transition.watchdogExpired = true
            RestoreHandoffVisuals(transition)
        end
    end)

    return transition
end

local function PrepareHandoffDestination(transition, entity, requestStillValid)
    if not transition then return true end
    if not HandoffRequestIsValid(transition, requestStillValid) then return false, 'cancelled' end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false, 'entity_lost' end

    local coords = GetEntityCoords(entity)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local sceneOk, sceneStarted = pcall(
        NewLoadSceneStartSphere,
        coords.x,
        coords.y,
        coords.z,
        50.0,
        0
    )
    transition.loadSceneStarted = sceneOk and sceneStarted == true

    local deadline = GetGameTimer() + transition.settings.collisionTimeout

    repeat
        if not HandoffRequestIsValid(transition, requestStillValid) then
            StopHandoffLoadScene(transition)
            return false, 'cancelled'
        end

        if not DoesEntityExist(entity) then
            StopHandoffLoadScene(transition)
            return false, 'entity_lost'
        end

        RequestCollisionAtCoord(coords.x, coords.y, coords.z)

        local collisionReady = HasCollisionLoadedAroundEntity(entity)
        local sceneReady = not transition.loadSceneStarted or IsNewLoadSceneLoaded()
        if collisionReady and sceneReady then
            StopHandoffLoadScene(transition)
            return true
        end

        Wait(50)
    until GetGameTimer() >= deadline

    StopHandoffLoadScene(transition)
    return false, 'collision_timeout'
end

local function SettleHandoffVehicle(transition, vehicle, requestStillValid)
    if not transition then return true end

    local ped = PlayerPedId()
    local deadline = GetGameTimer() + transition.settings.settle

    repeat
        if not HandoffRequestIsValid(transition, requestStillValid) then return false, 'cancelled' end
        if not DoesEntityExist(ped) or IsEntityDead(ped) then return false, 'player_unavailable' end
        if not vehicle or not DoesEntityExist(vehicle) then return false, 'entity_lost' end
        if not IsPedInVehicle(ped, vehicle, false) then return false, 'seat_lost' end

        if GetGameTimer() >= deadline then break end
        Wait(50)
    until false

    return true
end

local function FinishHandoffTransition(transition, immediate)
    if not transition then return end

    RestoreHandoffVisuals(transition, immediate)

    if immediate or not transition.ownsFade then return end

    local fadeDeadline = GetGameTimer() + transition.settings.fadeIn + 1000
    while not IsScreenFadedIn() and GetGameTimer() < fadeDeadline do
        Wait(0)
    end

    if not IsScreenFadedIn() then
        DoScreenFadeIn(0)
    end
end

local function AwaitNetworkVehicle(netId, expectedModel, requestStillValid)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil, 'invalid_net_id' end

    local expectedHash = nil
    if expectedModel then
        expectedHash = type(expectedModel) == 'number' and expectedModel or joaat(expectedModel)
    end

    local timeout = GetGameTimer() + (tonumber(Config.EntityHandoffTimeout) or 10000)

    while GetGameTimer() < timeout do
        if requestStillValid and not requestStillValid() then return nil, 'cancelled' end

        if NetworkDoesEntityExistWithNetworkId(netId) then
            local vehicle = NetToVeh(netId)

            if vehicle ~= 0 and DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
                if expectedHash and GetEntityModel(vehicle) ~= expectedHash then
                    return nil, 'model_mismatch'
                end

                return vehicle
            end
        end

        Wait(50)
    end

    return nil, 'entity_timeout'
end

local function NormalizePlate(plate)
    if type(plate) ~= 'string' then return nil end

    plate = plate:upper():match('^%s*(.-)%s*$')
    if not plate or plate == '' or #plate > 8 or not plate:match('^[A-Z0-9 ]+$') then return nil end

    return plate
end

local function ValidateDeliveryVehicle(vehicle, expectedModel, expectedPlate)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then
        return false, 'entity_lost'
    end

    local expectedHash = type(expectedModel) == 'number' and expectedModel or joaat(expectedModel)
    if GetEntityModel(vehicle) ~= expectedHash then return false, 'model_mismatch' end

    expectedPlate = NormalizePlate(expectedPlate)
    if not expectedPlate or NormalizePlate(GetVehicleNumberPlateText(vehicle)) ~= expectedPlate then
        return false, 'plate_mismatch'
    end

    return true
end

local function RequestVehicleControl(vehicle, requestStillValid)
    if requestStillValid and not requestStillValid() then return false, 'cancelled' end
    if NetworkHasControlOfEntity(vehicle) then return true end

    local timeout = GetGameTimer() + 2000
    NetworkRequestControlOfEntity(vehicle)

    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
        Wait(0)
        if requestStillValid and not requestStillValid() then return false, 'cancelled' end
        NetworkRequestControlOfEntity(vehicle)
    end

    return NetworkHasControlOfEntity(vehicle)
end

local function StrictBoundedInteger(value, minimum, maximum)
    value = tonumber(value)

    if not value or value ~= value or value == math.huge or value == -math.huge
        or value % 1 ~= 0 or value < minimum or value > maximum then
        return nil
    end

    return math.floor(value)
end

local function ApplyServerVehicleData(vehicle, vehicleData, isTestDrive, requestStillValid)
    vehicleData = type(vehicleData) == 'table' and vehicleData or {}

    local hasControl = RequestVehicleControl(vehicle, requestStillValid)
    if requestStillValid and not requestStillValid() then return false end
    if requestStillValid and not hasControl then return false end

    local entityState = Entity(vehicle).state
    local initData = entityState.drsVehicleShopInit or entityState.qrVehicleShopInit
    if type(initData) ~= 'table' then initData = {} end
    local resultProps = type(vehicleData.props) == 'table' and vehicleData.props or {}

    local plate = vehicleData.plate or initData.plate
    if type(plate) == 'string' and plate ~= '' then
        SetVehicleNumberPlateText(vehicle, plate)
    end

    SetVehicleModKit(vehicle, 0)

    local color1 = StrictBoundedInteger(initData.color1, 0, 160)
        or StrictBoundedInteger(resultProps.color1, 0, 160)
    local color2 = StrictBoundedInteger(initData.color2, 0, 160)
        or StrictBoundedInteger(resultProps.color2, 0, 160)

    if color1 or color2 then
        local currentColor1, currentColor2 = GetVehicleColours(vehicle)
        SetVehicleColours(vehicle, color1 or currentColor1, color2 or currentColor2)
    end

    local plateIndex = StrictBoundedInteger(initData.plateIndex, 0, 5)
        or StrictBoundedInteger(resultProps.plateIndex, 0, 5)
    if plateIndex then SetVehicleNumberPlateTextIndex(vehicle, plateIndex) end

    SetVehicleDirtLevel(vehicle, tonumber(initData.dirtLevel) or 0.0)
    SetVehicleEngineHealth(vehicle, tonumber(initData.engineHealth) or 1000.0)
    SetVehicleBodyHealth(vehicle, tonumber(initData.bodyHealth) or 1000.0)
    SetFuel(vehicle, tonumber(initData.fuelLevel) or 100.0)

    local shop = GetShop(vehicleData.shopId)
    if not shop or shop.type == nil or shop.type == 'car' then
        SetVehicleOnGroundProperly(vehicle)
    end

    if not isTestDrive then
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    end

    return true
end

local function WarpIntoVehicle(vehicle, requestStillValid)
    if requestStillValid and not requestStillValid() then return false, 'cancelled' end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    if not IsVehicleSeatFree(vehicle, -1) then return false end

    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    local timeout = GetGameTimer() + 2000
    while not IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < timeout do
        Wait(0)
        if requestStillValid and not requestStillValid() then return false, 'cancelled' end
    end

    if requestStillValid and not requestStillValid() then return false, 'cancelled' end
    if not IsPedInVehicle(ped, vehicle, false) then return false end

    SetVehicleEngineOn(vehicle, true, true, false)
    return true
end

local function ApplyTestDriveProtection(vehicle)
    local ped = PlayerPedId()
    local playerWasInvincible = not GetEntityCanBeDamaged(ped)
    local vehicleWasInvincible = not GetEntityCanBeDamaged(vehicle)
    local protectPlayer = Config.TestDrive == nil or Config.TestDrive.invinciblePlayer ~= false
    local protectVehicle = Config.TestDrive == nil or Config.TestDrive.invincibleVehicle ~= false

    testDriveProtection = {
        ped = ped,
        vehicle = vehicle,
        changedPlayer = protectPlayer and not playerWasInvincible,
        changedVehicle = protectVehicle and not vehicleWasInvincible
    }

    if testDriveProtection.changedPlayer then
        SetEntityInvincible(ped, true)
    end

    if testDriveProtection.changedVehicle then
        SetEntityInvincible(vehicle, true)
    end
end

local function RestoreTestDriveProtection()
    local protection = testDriveProtection
    testDriveProtection = nil
    if not protection then return end

    if protection.changedPlayer and protection.ped and DoesEntityExist(protection.ped) then
        SetEntityInvincible(protection.ped, false)
    end

    if protection.changedVehicle and protection.vehicle and DoesEntityExist(protection.vehicle) then
        SetEntityInvincible(protection.vehicle, false)
    end
end

local allowedShopTargetIcons = {
    car = true,
    helicopter = true,
    ship = true
}

local shopTargetIconDefaults = {
    car = 'car',
    boat = 'ship',
    air = 'helicopter'
}

local function GetShopIcon(shop, target)
    local shopType = type(shop and shop.type) == 'string' and shop.type:lower() or 'car'
    local icon = type(shop and shop.targetIcon) == 'string' and shop.targetIcon:lower() or ''

    -- Accept either the documented icon name or an existing FA class string, but
    -- only pass known shop icons through to target resources.
    icon = icon:match('fa%-([%w-]+)$') or icon:match('^([%w-]+)$') or ''

    if not allowedShopTargetIcons[icon] then
        icon = shopTargetIconDefaults[shopType] or shopTargetIconDefaults.car
    end

    if target == 'ox_target' then
        return ('fa-solid fa-%s'):format(icon)
    end

    return ('fas fa-%s'):format(icon)
end

local function CreateShopBlip(shopId, shop)
    local blipConfig = shop and shop.blip
    if type(blipConfig) ~= 'table' or blipConfig.enabled == false then return end

    local coords = GetCoords('dealership', shopId)
    if not coords then return end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipConfig.sprite or 326)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipConfig.scale or 0.65)
    SetBlipColour(blip, blipConfig.color or 3)
    SetBlipAsShortRange(blip, blipConfig.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipConfig.label or shop.label or 'Vehicle Shop')
    EndTextCommandSetBlipName(blip)

    shopBlips[#shopBlips + 1] = blip
end

local function InitializeShopPed(shopId, shop, target)
    local pedCoords = GetPedCoords(shop)

    if not pedCoords then
        print(('[drs_vehicleshop] Missing ped coords for shop "%s".'):format(shopId))
        return
    end

    local modelHash = LoadModel(GetPedModel(shop))
    if not modelHash then
        print(('[drs_vehicleshop] Failed to load ped model for shop "%s".'):format(shopId))
        return
    end

    local ped = CreatePed(4, modelHash, pedCoords.x, pedCoords.y, pedCoords.z - 1.0, pedCoords.w or 0.0, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(modelHash)

    vehicleShopPeds[shopId] = ped

    local label = shop.targetLabel or Config.BrowseLabel or 'Browse Vehicles'
    local distance = shop.targetDistance or Config.TargetDistance or 2.5
    local icon = GetShopIcon(shop, target)
    local optionName = ('drs_vehicle_shop_%s'):format(shopId)

    if target == 'ox_target' then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = optionName,
                icon = icon,
                label = label,
                onSelect = function()
                    TriggerEvent('drs_vehicleshop:client:openShop', shopId)
                end,
                distance = distance,
            }
        })

        vehicleShopTargets[shopId] = {
            system = target,
            option = optionName
        }
    elseif target == 'qb-target' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = icon,
                    label = label,
                    action = function()
                        TriggerEvent('drs_vehicleshop:client:openShop', shopId)
                    end,
                }
            },
            distance = distance,
        })

        vehicleShopTargets[shopId] = {
            system = target,
            option = label
        }
    end
end

local function InitializeShops()
    local target = GetTarget()

    if not target then
        print('[drs_vehicleshop] No supported target found. Set Config.Target or start ox_target/qb-target.')
    end

    if type(Config.Shops) == 'table' then
        for shopId, shop in pairs(Config.Shops) do
            InitializeShopPed(shopId, shop, target)
            CreateShopBlip(shopId, shop)
        end
        return
    end

    local shop, shopId = GetShop()
    InitializeShopPed(shopId, shop, target)
end

local function OpenShopUi(shopId)
    local shop, resolvedShopId = GetShop(shopId)

    if inTestDrive or testDrivePending then
        Notify('Finish your test drive first!', 'error')
        return false
    end

    if purchasePending then
        Notify('Please wait for your purchase to finish.', 'warning')
        return false
    end

    local categories, vehicles = BuildShopInventory(shop)
    local categoryOrder = BuildCategoryOrder(shop, categories, vehicles)
    local defaultCategory = ResolveDefaultCategory(shop, categoryOrder, categories, vehicles)

    if not defaultCategory then
        Notify('This shop has no vehicles configured.', 'error')
        return false
    end

    activeShopId = resolvedShopId
    quoteRequestToken = quoteRequestToken + 1
    quotePending = false
    quotePendingToken = nil

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        categories = categories,
        vehicles = vehicles,
        checkout = BuildCheckoutPresentation(shop),
        shop = {
            id = resolvedShopId,
            label = shop.label or 'Vehicle Shop',
            type = shop.type or 'car',
            defaultCategory = defaultCategory,
            categoryOrder = categoryOrder,
            presentation = BuildShopPresentation(shop, resolvedShopId)
        }
    })

    return true
end

local function EndTestDrive(serverReason, message, notifyType, teleportPlayer, expectedSession, existingTransition)
    if not inTestDrive then return false end

    local ped = PlayerPedId()
    local vehicle = testDriveVeh
    local returnShopId = testDriveShopId or activeShopId
    local serverSessionId = tonumber(expectedSession) or testDriveServerSessionId

    inTestDrive = false
    testDriveVeh = nil
    testDriveNetId = nil
    testDriveShopId = nil
    testDriveEndsAt = nil
    testDriveServerSessionId = nil

    RestoreTestDriveProtection()

    SendNUIMessage({ action = 'testDriveEnded' })
    SendNUIMessage({ action = 'resetTestDrive' })

    local endEventSent = false

    if teleportPlayer ~= false then
        local transition = existingTransition
            or BeginHandoffTransition('Returning to the showroom...')

        if vehicle and DoesEntityExist(vehicle) and IsPedInVehicle(ped, vehicle, false) then
            TaskLeaveVehicle(ped, vehicle, 16)

            if transition then
                local leaveDeadline = GetGameTimer() + 750
                while IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < leaveDeadline do
                    Wait(0)
                end
            else
                Wait(0)
            end
        end

        local dealershipCoords = GetCoords('dealership', returnShopId)
        if dealershipCoords then
            SetEntityCoords(ped, dealershipCoords.x, dealershipCoords.y, dealershipCoords.z, false, false, false, false)
            if dealershipCoords.w then
                SetEntityHeading(ped, dealershipCoords.w)
            end

            PrepareHandoffDestination(transition, ped)
        end

        if serverSessionId then
            TriggerServerEvent(
                'drs_vehicleshop:server:endTestDrive',
                serverReason or 'completed',
                true,
                serverSessionId
            )
        end
        endEventSent = true
        FinishHandoffTransition(transition)
    end

    if not endEventSent and serverSessionId then
        TriggerServerEvent(
            'drs_vehicleshop:server:endTestDrive',
            serverReason or 'completed',
            false,
            serverSessionId
        )
    end

    if message ~= false then
        Notify(message or 'Test drive completed!', notifyType or 'success')
    end

    return true
end

local serverTestDriveEndFeedback = {
    timeout = {
        message = 'Test drive completed!',
        notifyType = 'success'
    },
    exited_vehicle = {
        message = 'You exited the vehicle. Test drive cancelled.',
        notifyType = 'error'
    },
    geofence = {
        message = 'You left the permitted test-drive area. Test drive cancelled.',
        notifyType = 'error'
    },
    entity_lost = {
        message = 'The test-drive vehicle is no longer available.',
        notifyType = 'error'
    },
    entity_removed = {
        message = 'The test-drive vehicle is no longer available.',
        notifyType = 'error'
    },
    player_lost = {
        message = 'Test drive cancelled.',
        notifyType = 'error'
    },
    player_dead = {
        message = 'Test drive cancelled.',
        notifyType = 'error'
    },
    bucket_changed = {
        message = 'Your session changed. Test drive cancelled.',
        notifyType = 'error'
    }
}

RegisterNetEvent('drs_vehicleshop:client:endTestDrive', function(reason, expectedSession)
    -- Network events sent by the server use the reserved server source. Reject
    -- local resource calls so only the authoritative session owner can request
    -- this transition.
    if source ~= 65535 then return end

    expectedSession = tonumber(expectedSession)
    if not expectedSession or expectedSession % 1 ~= 0
        or expectedSession ~= testDriveServerSessionId then return end

    local resolvedReason = type(reason) == 'string' and reason or 'server_ended'
    local feedback = serverTestDriveEndFeedback[resolvedReason] or {
        message = 'Test drive ended.',
        notifyType = 'inform'
    }

    -- The server can end the exact session in the narrow interval after its
    -- seated ACK but before the callback marks the drive active locally. Reuse
    -- the already-black handoff transition in that case.
    if not inTestDrive then
        if not testDriveVeh then return end
        serverEndedTestDriveSessionId = expectedSession
        testDrivePending = false
        inTestDrive = true
    end

    -- EndTestDrive clears inTestDrive before yielding. This event and the local
    -- monitor are therefore idempotent: whichever runs first owns the return.
    EndTestDrive(
        resolvedReason,
        feedback.message,
        feedback.notifyType,
        true,
        expectedSession,
        activeHandoffTransition
    )
end)

local function StartTestDriveCountdown(duration)
    duration = math.max(1, math.floor(tonumber(duration) or (Config.TestDrive and Config.TestDrive.time) or Config.TestDriveTime or 300))

    testDriveSession = testDriveSession + 1
    local session = testDriveSession

    inTestDrive = true
    testDriveEndsAt = GetGameTimer() + (duration * 1000)

    SendNUIMessage({
        action = 'updateTestDriveTime',
        time = duration
    })

    CreateThread(function()
        local lastDisplayed = duration

        while inTestDrive and testDriveSession == session do
            local timeLeft = math.max(0, math.ceil((testDriveEndsAt - GetGameTimer()) / 1000))

            if timeLeft ~= lastDisplayed then
                lastDisplayed = timeLeft
                SendNUIMessage({
                    action = 'updateTestDriveTime',
                    time = timeLeft
                })
            end

            if timeLeft <= 0 then
                EndTestDrive('timeout', 'Test drive completed!', 'success')
                break
            end

            Wait(250)
        end
    end)
end

CreateThread(function()
    while true do
        if inTestDrive then
            local vehicle = testDriveVeh
            local ped = PlayerPedId()

            if not vehicle or not DoesEntityExist(vehicle) then
                local nearDeadline = testDriveEndsAt and GetGameTimer() >= testDriveEndsAt - 1000
                EndTestDrive(
                    nearDeadline and 'timeout' or 'entity_lost',
                    nearDeadline and 'Test drive completed!' or 'The test-drive vehicle is no longer available.',
                    nearDeadline and 'success' or 'error'
                )
            elseif IsEntityDead(ped) then
                EndTestDrive('player_dead', 'Test drive cancelled.', 'error')
            elseif not (Config.TestDrive and Config.TestDrive.cancelOnExit == false) and not IsPedInVehicle(ped, vehicle, false) then
                EndTestDrive('exited_vehicle', 'You exited the vehicle. Test drive cancelled.', 'error')
            end

            Wait(500)
        else
            Wait(1000)
        end
    end
end)

RegisterNUICallback('quoteVehicle', function(data, cb)
    local shopId = activeShopId
    local model = type(data) == 'table' and CleanCheckoutId(data.model, 64) or nil

    if quotePending then
        cb(BuildNuiResponse(false, 'quote_pending', 'A vehicle quote is already being prepared.'))
        return
    end

    if purchasePending then
        cb(BuildNuiResponse(false, 'purchase_pending', 'Please wait for your purchase to finish.'))
        return
    end

    if inTestDrive or testDrivePending then
        cb(BuildNuiResponse(false, 'test_drive_active', 'Finish your test drive before requesting a quote.'))
        return
    end

    if not model then
        cb(BuildNuiResponse(false, 'invalid_model', 'Invalid vehicle selected.'))
        return
    end

    local customization = SanitizeCheckoutCustomization(data.customization)
    quoteRequestToken = quoteRequestToken + 1
    local requestToken = quoteRequestToken
    quotePending = true
    quotePendingToken = requestToken

    local result = AwaitServerCallback('drs_vehicleshop:server:quoteVehicle', model, shopId, customization)

    if quotePendingToken == requestToken then
        quotePending = false
        quotePendingToken = nil
    end

    if requestToken ~= quoteRequestToken or shopId ~= activeShopId then
        cb(BuildNuiResponse(false, 'cancelled', 'Vehicle quote cancelled.'))
        return
    end

    if not result.ok then
        Notify(result.message or 'Unable to prepare this vehicle quote.', 'error')
    end

    cb(result)
end)

RegisterNUICallback('testDrive', function(data, cb)
    local shopId = activeShopId
    local model = type(data) == 'table' and data.model or nil

    if inTestDrive or testDrivePending then
        local message = "You're already starting or using a test drive."
        Notify(message, 'error')
        cb(BuildNuiResponse(false, 'test_drive_active', message))
        return
    end

    if purchasePending then
        local message = 'Please wait for your purchase to finish.'
        Notify(message, 'warning')
        cb(BuildNuiResponse(false, 'purchase_pending', message))
        return
    end

    if quotePending then
        local message = 'Please wait for your vehicle quote to finish.'
        Notify(message, 'warning')
        cb(BuildNuiResponse(false, 'quote_pending', message))
        return
    end

    if not model then
        local message = 'Invalid vehicle selected.'
        SendNUIMessage({ action = 'resetTestDrive' })
        Notify(message, 'error')
        OpenShopUi(shopId)
        cb(BuildNuiResponse(false, 'invalid_model', message))
        return
    end

    testDrivePending = true
    testDriveServerSessionId = nil
    serverEndedTestDriveSessionId = nil
    testDriveRequestToken = testDriveRequestToken + 1
    local requestToken = testDriveRequestToken
    local transition = nil
    local requestServerSessionId = nil
    local function OwnsTestDriveRequest()
        return requestToken == testDriveRequestToken
    end

    local function FailTestDrive(code, message, serverReason)
        local ownsRequest = OwnsTestDriveRequest()
        local serverSessionId = requestServerSessionId
        local ownsState = ownsRequest
            or (serverSessionId and testDriveServerSessionId == serverSessionId)

        if ownsRequest then
            testDrivePending = false
        end

        if serverReason and serverSessionId then
            TriggerServerEvent(
                'drs_vehicleshop:server:endTestDrive',
                serverReason,
                false,
                serverSessionId
            )
        end

        if ownsState then
            testDriveVeh = nil
            testDriveNetId = nil
            testDriveShopId = nil
            testDriveEndsAt = nil
            testDriveServerSessionId = nil
            RestoreTestDriveProtection()
            SendNUIMessage({ action = 'resetTestDrive' })
        end

        FinishHandoffTransition(transition)

        if ownsState then
            Notify(message, 'error')
        end

        if ownsRequest then
            OpenShopUi(shopId)
        end

        cb(BuildNuiResponse(false, code, message))
    end

    -- The browser hides as soon as a test drive is requested. Release its
    -- invisible input capture while the server prepares the vehicle; failures
    -- reopen the showroom and restore focus below.
    SetNuiFocus(false, false)
    local result = AwaitServerCallback('drs_vehicleshop:server:startTestDrive', model, shopId)

    if not OwnsTestDriveRequest() then
        if result.ok then
            local cancelledSession = tonumber(result.sessionId)
                or tonumber(type(result.vehicle) == 'table' and result.vehicle.sessionId)
            if cancelledSession then
                TriggerServerEvent(
                    'drs_vehicleshop:server:endTestDrive',
                    'client_cancelled',
                    false,
                    cancelledSession
                )
            end
        end

        cb(BuildNuiResponse(false, 'cancelled', 'Test drive cancelled.'))
        return
    end

    if not result.ok then
        local message = result.message or 'Unable to start the test drive.'
        testDrivePending = false
        SendNUIMessage({ action = 'resetTestDrive' })
        Notify(message, 'error')
        OpenShopUi(shopId)
        cb(BuildNuiResponse(false, result.code or 'test_drive_failed', message))
        return
    end

    local vehicleData = type(result.vehicle) == 'table' and result.vehicle or nil
    local serverSessionId = tonumber(result.sessionId)
        or tonumber(vehicleData and vehicleData.sessionId)
    if not serverSessionId or serverSessionId % 1 ~= 0 then
        FailTestDrive(
            'invalid_test_drive_session',
            'The test-drive session could not be verified.',
            nil
        )
        return
    end
    requestServerSessionId = serverSessionId
    testDriveServerSessionId = serverSessionId

    if not vehicleData or not vehicleData.netId then
        FailTestDrive(
            'invalid_handoff',
            'The test-drive vehicle could not be delivered.',
            'invalid_handoff'
        )
        return
    end

    local transitionError
    transition, transitionError = BeginHandoffTransition(
        'Preparing your test drive...',
        OwnsTestDriveRequest
    )
    if transitionError == 'cancelled' then
        FailTestDrive('cancelled', 'Test drive cancelled.', 'client_cancelled')
        return
    end

    local vehicle, handoffError = AwaitNetworkVehicle(
        vehicleData.netId,
        vehicleData.model or model,
        OwnsTestDriveRequest
    )
    if not vehicle then
        FailTestDrive(
            handoffError or 'handoff_failed',
            'The test-drive vehicle did not arrive. Please try again.',
            handoffError or 'handoff_failed'
        )
        return
    end

    local destinationReady, destinationError = PrepareHandoffDestination(
        transition,
        vehicle,
        OwnsTestDriveRequest
    )
    if not destinationReady then
        FailTestDrive(
            destinationError or 'destination_not_ready',
            'The test-drive area did not load safely. Please try again.',
            destinationError or 'destination_not_ready'
        )
        return
    end

    local appliedVehicleData = ApplyServerVehicleData(
        vehicle,
        vehicleData,
        true,
        OwnsTestDriveRequest
    )
    if not appliedVehicleData then
        FailTestDrive(
            'vehicle_setup_failed',
            'The test-drive vehicle could not be prepared. Please try again.',
            'vehicle_setup_failed'
        )
        return
    end

    if not WarpIntoVehicle(vehicle, OwnsTestDriveRequest) then
        FailTestDrive(
            'warp_failed',
            'The driver seat is unavailable. Please try again.',
            'warp_failed'
        )
        return
    end

    local settled, settleError = SettleHandoffVehicle(
        transition,
        vehicle,
        OwnsTestDriveRequest
    )
    if not settled then
        FailTestDrive(
            settleError or 'handoff_unstable',
            'The test-drive handoff did not finish safely. Please try again.',
            settleError or 'handoff_unstable'
        )
        return
    end

    -- Publish the exact server session/entity before the acknowledgement yields,
    -- so an authoritative end in that narrow interval can reuse this transition.
    testDriveVeh = vehicle
    testDriveNetId = tonumber(vehicleData.netId)
    testDriveShopId = vehicleData.shopId or shopId

    local acknowledgement = AwaitServerCallback(
        'drs_vehicleshop:server:acknowledgeTestDrive',
        serverSessionId
    )

    if serverEndedTestDriveSessionId == serverSessionId then
        serverEndedTestDriveSessionId = nil
        cb(BuildNuiResponse(false, 'test_drive_ended', 'The test drive has ended.'))
        return
    end

    if not OwnsTestDriveRequest() then
        FailTestDrive('cancelled', 'Test drive cancelled.', 'client_cancelled')
        return
    end

    if not acknowledgement.ok then
        local acknowledgementMessage = acknowledgement.message
            or 'The test-drive handoff could not be confirmed. Please try again.'
        FailTestDrive(
            acknowledgement.code or 'handoff_confirmation_failed',
            acknowledgementMessage,
            acknowledgement.code or 'handoff_confirmation_failed'
        )
        return
    end

    testDrivePending = false
    ApplyTestDriveProtection(vehicle)
    StartTestDriveCountdown(result.duration)

    local duration = math.max(1, math.floor(tonumber(result.duration) or (Config.TestDrive and Config.TestDrive.time) or Config.TestDriveTime or 300))
    local message = acknowledgement.message
        or result.message
        or ('Test drive started! You have %s seconds.'):format(duration)
    cb(BuildNuiResponse(true, result.code or 'test_drive_started', message))
    FinishHandoffTransition(transition)
    Notify(message, 'inform')
end)

RegisterNUICallback('buyVehicle', function(data, cb)
    local shopId = activeShopId
    local model = type(data) == 'table' and CleanCheckoutId(data.model, 64) or nil
    local quoteId = type(data) == 'table' and CleanCheckoutId(data.quoteId, 100) or nil

    if purchasePending then
        local message = 'Your purchase is already being processed.'
        Notify(message, 'warning')
        cb(BuildNuiResponse(false, 'purchase_pending', message))
        return
    end

    if inTestDrive or testDrivePending then
        local message = 'Finish your test drive before purchasing a vehicle.'
        Notify(message, 'error')
        cb(BuildNuiResponse(false, 'test_drive_active', message))
        return
    end

    if quotePending then
        local message = 'Please wait for your vehicle quote to finish.'
        Notify(message, 'warning')
        cb(BuildNuiResponse(false, 'quote_pending', message))
        return
    end

    if not model then
        local message = 'Invalid vehicle selected.'
        Notify(message, 'error')
        cb(BuildNuiResponse(false, 'invalid_model', message))
        return
    end

    if not quoteId then
        local message = 'Your vehicle quote is missing or invalid. Please request a new quote.'
        Notify(message, 'error')
        cb(BuildNuiResponse(false, 'invalid_quote', message))
        return
    end

    purchaseRequestToken = purchaseRequestToken + 1
    local requestToken = purchaseRequestToken
    purchasePending = true
    local responseSent = false
    local transition = nil
    local function OwnsPurchaseRequest()
        return requestToken == purchaseRequestToken
    end

    local function FinishPurchase(response)
        if responseSent then return end
        responseSent = true

        if OwnsPurchaseRequest() then
            purchasePending = false
        end

        local ok, callbackError = pcall(cb, response)
        if not ok then
            print(('[drs_vehicleshop] Purchase NUI callback failed: %s'):format(tostring(callbackError)))
        end

        -- Resolve the NUI request before revealing the world so Chromium has
        -- already hidden the checkout when the fade lifts.
        FinishHandoffTransition(transition)
        transition = nil
    end

    local function AbortStalePurchase()
        if OwnsPurchaseRequest() then return false end

        FinishPurchase(BuildNuiResponse(false, 'cancelled', 'Vehicle purchase response cancelled.'))
        return true
    end

    local result = AwaitServerCallback('drs_vehicleshop:server:purchaseVehicle', model, shopId, quoteId)

    if AbortStalePurchase() then return end

    if not result.ok then
        local message = result.message or 'Vehicle purchase failed.'
        Notify(message, 'error')
        FinishPurchase(result)
        return
    end

    SetNuiFocus(false, false)

    local vehicleData = type(result.vehicle) == 'table' and result.vehicle or {}
    if result.fallbackStored or not vehicleData.netId then
        local message = result.message or 'Vehicle purchased and delivered to your garage.'

        local response = BuildNuiResponse(true, result.code or 'stored', message)
        response.fallbackStored = true
        FinishPurchase(response)
        Notify(message, 'success')
        return
    end

    local handoffToken = type(result.handoffToken) == 'string'
        and result.handoffToken ~= ''
        and result.handoffToken
        or nil

    local function FinalizeDelivery()
        if AbortStalePurchase() then return end

        if not handoffToken then
            local message = 'Purchase completed, but delivery confirmation was unavailable. Your vehicle will be returned to storage.'

            local response = BuildNuiResponse(true, 'delivery_token_missing', message)
            response.fallbackStored = true
            FinishPurchase(response)
            Notify(message, 'warning')
            return
        end

        local acknowledgement = AwaitServerCallback(
            'drs_vehicleshop:server:acknowledgeDelivery',
            handoffToken
        )

        if AbortStalePurchase() then return end

        if not acknowledgement.ok then
            local message = 'Purchase completed, but delivery could not be confirmed. Your vehicle will be returned to storage.'

            local response = BuildNuiResponse(true, acknowledgement.code or 'delivery_confirmation_failed', message)
            response.fallbackStored = true
            FinishPurchase(response)
            Notify(message, 'warning')
            return
        end

        local message = acknowledgement.message
            or result.message
            or 'Congratulations on your purchase! Your vehicle is ready.'
        local delivered = acknowledgement.code == 'delivered' and acknowledgement.fallbackStored ~= true
        FinishPurchase(acknowledgement)
        Notify(message, delivered and 'success' or 'warning')
    end

    local expectedModel = vehicleData.model or model
    if GetHandoffTransitionSettings().enabled then
        SendNUIMessage({ action = 'handoffStarting' })
        Wait(0)
    end

    local transitionError
    transition, transitionError = BeginHandoffTransition(
        'Preparing your new vehicle...',
        OwnsPurchaseRequest
    )
    if transitionError == 'cancelled' then
        AbortStalePurchase()
        return
    end

    local vehicle = AwaitNetworkVehicle(vehicleData.netId, expectedModel, OwnsPurchaseRequest)
    if AbortStalePurchase() then return end

    if not vehicle then
        FinalizeDelivery()
        return
    end

    local deliveryValid = ValidateDeliveryVehicle(vehicle, expectedModel, vehicleData.plate)
    if not deliveryValid then
        FinalizeDelivery()
        return
    end

    local destinationReady = PrepareHandoffDestination(
        transition,
        vehicle,
        OwnsPurchaseRequest
    )
    if AbortStalePurchase() then return end

    if not destinationReady then
        FinalizeDelivery()
        return
    end

    local hasVehicleControl = RequestVehicleControl(vehicle, OwnsPurchaseRequest)
    if AbortStalePurchase() then return end

    if not hasVehicleControl then
        FinalizeDelivery()
        return
    end

    local appliedVehicleData = ApplyServerVehicleData(vehicle, vehicleData, false, OwnsPurchaseRequest)
    if AbortStalePurchase() then return end

    if not appliedVehicleData then
        FinalizeDelivery()
        return
    end

    local warpedIntoVehicle = WarpIntoVehicle(vehicle, OwnsPurchaseRequest)
    if AbortStalePurchase() then return end

    if not warpedIntoVehicle then
        FinalizeDelivery()
        return
    end

    deliveryValid = ValidateDeliveryVehicle(vehicle, expectedModel, vehicleData.plate)
    if not deliveryValid or not NetworkHasControlOfEntity(vehicle) or not IsPedInVehicle(PlayerPedId(), vehicle, false) then
        FinalizeDelivery()
        return
    end

    local settled = SettleHandoffVehicle(transition, vehicle, OwnsPurchaseRequest)
    if AbortStalePurchase() then return end

    if not settled then
        FinalizeDelivery()
        return
    end

    FinalizeDelivery()
end)

RegisterNUICallback('close', function(_, cb)
    if purchasePending then
        cb(BuildNuiResponse(false, 'purchase_pending', 'Please wait for your purchase to finish.'))
        return
    end

    quoteRequestToken = quoteRequestToken + 1
    quotePending = false
    quotePendingToken = nil

    if testDrivePending then
        testDriveRequestToken = testDriveRequestToken + 1
        testDrivePending = false
        ForceRestoreHandoffTransition()
        if testDriveServerSessionId then
            TriggerServerEvent(
                'drs_vehicleshop:server:endTestDrive',
                'client_cancelled',
                false,
                testDriveServerSessionId
            )
        end
        SendNUIMessage({ action = 'resetTestDrive' })
    elseif inTestDrive then
        EndTestDrive('client_cancelled', 'Test drive cancelled.', 'inform')
    end

    SetNuiFocus(false, false)
    cb(BuildNuiResponse(true, 'closed'))
end)

local function HandleOpenShopEvent(shopId)
    OpenShopUi(shopId)
end

RegisterNetEvent('drs_vehicleshop:client:openShop', HandleOpenShopEvent)

-- Temporary compatibility entry point for integrations upgrading from the completed
-- QR build. Internal DRS calls use only the drs_vehicleshop namespace.
RegisterNetEvent('qr-vehicleshop:client:openShop', HandleOpenShopEvent)

local function HandlePlayerUnload()
    quoteRequestToken = quoteRequestToken + 1
    quotePending = false
    quotePendingToken = nil
    purchaseRequestToken = purchaseRequestToken + 1
    purchasePending = false
    ForceRestoreHandoffTransition()

    if testDrivePending then
        testDriveRequestToken = testDriveRequestToken + 1
        testDrivePending = false
        if testDriveServerSessionId then
            TriggerServerEvent(
                'drs_vehicleshop:server:endTestDrive',
                'player_unloaded',
                false,
                testDriveServerSessionId
            )
        end
        testDriveServerSessionId = nil
        SendNUIMessage({ action = 'resetTestDrive' })
    elseif inTestDrive then
        EndTestDrive('player_unloaded', false, nil, false)
    end

    SetNuiFocus(false, false)
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', HandlePlayerUnload)
RegisterNetEvent('qbx_core:client:playerLoggedOut', HandlePlayerUnload)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local hadTestDrive = inTestDrive or testDrivePending
    quoteRequestToken = quoteRequestToken + 1
    quotePending = false
    quotePendingToken = nil
    purchaseRequestToken = purchaseRequestToken + 1
    purchasePending = false
    testDriveRequestToken = testDriveRequestToken + 1
    testDrivePending = false
    ForceRestoreHandoffTransition()

    if hadTestDrive then
        if testDriveServerSessionId then
            TriggerServerEvent(
                'drs_vehicleshop:server:endTestDrive',
                'resource_stopped',
                false,
                testDriveServerSessionId
            )
        end
    end

    for shopId, ped in pairs(vehicleShopPeds) do
        if ped and DoesEntityExist(ped) then
            local target = vehicleShopTargets[shopId]

            if target and target.system == 'ox_target' and GetResourceState('ox_target') == 'started' then
                pcall(function()
                    exports.ox_target:removeLocalEntity(ped, target.option)
                end)
            elseif target and target.system == 'qb-target' and GetResourceState('qb-target') == 'started' then
                pcall(function()
                    exports['qb-target']:RemoveTargetEntity(ped, target.option)
                end)
            end

            DeleteEntity(ped)
        end
    end

    for _, blip in ipairs(shopBlips) do
        if blip then
            RemoveBlip(blip)
        end
    end

    RestoreTestDriveProtection()
    inTestDrive = false
    testDriveVeh = nil
    testDriveNetId = nil
    testDriveShopId = nil
    testDriveEndsAt = nil
    testDriveServerSessionId = nil
    serverEndedTestDriveSessionId = nil
    SetNuiFocus(false, false)
end)

CreateThread(function()
    GetFramework()
    InitializeShops()
end)
