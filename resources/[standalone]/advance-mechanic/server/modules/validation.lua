local Validation = {}
local Framework = require 'shared.framework'

local rateLimits = {}
local allowedProps = {
    bodyHealth = true,
    engineHealth = true,
    fuelLevel = true,
    dirtLevel = true,
    color1 = true,
    color2 = true,
    paintType1 = true,
    paintType2 = true,
    pearlescentColor = true,
    wheelColor = true,
    wheels = true,
    windowTint = true,
    neonEnabled = true,
    neonColor = true,
    extras = true,
    tyreSmokeColor = true,
    modEngine = true,
    modBrakes = true,
    modTransmission = true,
    modSuspension = true,
    modTurbo = true,
    modArmor = true,
    modFrontWheels = true,
    modBackWheels = true,
    modHorns = true,
    modPlateHolder = true,
    modVanityPlate = true,
    modTrimA = true,
    modOrnaments = true,
    modDashboard = true,
    modDial = true,
    modDoorSpeaker = true,
    modSeats = true,
    modSteeringWheel = true,
    modShifterLeavers = true,
    modAPlate = true,
    modSpeakers = true,
    modTrunk = true,
    modHydrolic = true,
    modEngineBlock = true,
    modAirFilter = true,
    modStruts = true,
    modArchCover = true,
    modAerials = true,
    modTrimB = true,
    modTank = true,
    modWindows = true,
    modLivery = true,
    modRoof = true
}

local function isSafeKey(key)
    if type(key) ~= 'string' then return false end
    return allowedProps[key] or key:match('^mod%u')
end

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function sanitizeTable(value, depth)
    if type(value) ~= 'table' then return nil end
    if depth > 2 then return nil end

    local sanitized = {}
    local count = 0

    for k, v in pairs(value) do
        count = count + 1
        if count > 64 then
            return nil
        end

        local vType = type(v)
        if vType == 'number' or vType == 'boolean' or vType == 'string' then
            sanitized[k] = v
        elseif vType == 'table' then
            local nested = sanitizeTable(v, depth + 1)
            if nested then
                sanitized[k] = nested
            end
        end
    end

    return sanitized
end

function Validation.LogDenied(source, action, reason)
    if not Config.Debug then return end
    local safeAction = action or 'unknown'
    local safeReason = reason or 'unspecified'
    print(('[Advanced Mechanic] Denied %s from %s: %s'):format(safeAction, source or 'unknown', safeReason))
end

function Validation.ClampNumber(value, minValue, maxValue, fallback)
    if not isFiniteNumber(value) then
        return fallback
    end
    if minValue and value < minValue then
        return minValue
    end
    if maxValue and value > maxValue then
        return maxValue
    end
    return value
end

function Validation.IsPositiveInteger(value, minValue, maxValue)
    local numeric = tonumber(value)
    if not isFiniteNumber(numeric) or numeric % 1 ~= 0 then
        return false
    end
    if minValue and numeric < minValue then return false end
    if maxValue and numeric > maxValue then return false end
    return true
end

function Validation.IsValidCoords(coords)
    if type(coords) == 'vector3' then
        return isFiniteNumber(coords.x) and isFiniteNumber(coords.y) and isFiniteNumber(coords.z)
    end
    if type(coords) == 'vector4' then
        return isFiniteNumber(coords.x) and isFiniteNumber(coords.y) and isFiniteNumber(coords.z)
            and isFiniteNumber(coords.w)
    end
    if type(coords) ~= 'table' then return false end
    return isFiniteNumber(coords.x) and isFiniteNumber(coords.y) and isFiniteNumber(coords.z)
        and (coords.w == nil or isFiniteNumber(coords.w))
end

function Validation.NormalizeCoords(coords)
    if type(coords) == 'vector3' then
        return Validation.IsValidCoords(coords) and coords or nil
    end
    if type(coords) == 'vector4' then
        return Validation.IsValidCoords(coords) and vec3(coords.x, coords.y, coords.z) or nil
    end
    if type(coords) ~= 'table' then return nil end
    if not isFiniteNumber(coords.x) or not isFiniteNumber(coords.y) or not isFiniteNumber(coords.z) then
        return nil
    end
    return vec3(coords.x, coords.y, coords.z)
end

function Validation.IsValidPlate(plate)
    local normalized = Validation.NormalizePlate(plate)
    return normalized ~= nil and #normalized >= 1 and #normalized <= 15
        and normalized:match('^[%w %-]+$') ~= nil
end

function Validation.NormalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    local normalized = plate:match('^%s*(.-)%s*$')
    if not normalized or normalized == '' then return nil end
    return normalized:upper()
end

function Validation.IsValidCitizenId(citizenid)
    return type(citizenid) == 'string' and #citizenid >= 1 and #citizenid <= 64
end

function Validation.CheckRateLimit(source, key, intervalMs)
    if not source or not key or type(intervalMs) ~= 'number' then
        return false
    end

    rateLimits[source] = rateLimits[source] or {}
    local now = GetGameTimer()
    local last = rateLimits[source][key]
    if last and now >= last and now - last < intervalMs then
        return false
    end
    rateLimits[source][key] = now
    return true
end

function Validation.ClearRateLimit(source)
    if not source then return end
    rateLimits[source] = nil
end

function Validation.IsNumberInRange(value, minValue, maxValue)
    if not isFiniteNumber(value) then return false end
    if minValue and value < minValue then return false end
    if maxValue and value > maxValue then return false end
    return true
end

function Validation.IsMechanic(player)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == Config.JobName
end

function Validation.IsAdmin(source)
    return Framework.HasPermission(source, 'admin')
end

function Validation.GetVehicleByNetId(netId)
    if type(netId) ~= 'number' then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and DoesEntityExist(vehicle) then
        return vehicle
    end
    return nil
end

function Validation.GetVehicleByPlate(plate)
    plate = Validation.NormalizePlate(plate)
    if not plate then return nil end
    for _, vehicle in ipairs(GetAllVehicles()) do
        if Validation.NormalizePlate(GetVehicleNumberPlateText(vehicle)) == plate then
            return vehicle
        end
    end
    return nil
end

function Validation.IsPlayerNearEntity(source, entity, maxDistance)
    if not entity or not DoesEntityExist(entity) then return false end
    local ped = GetPlayerPed(source)
    if not ped or not DoesEntityExist(ped) then return false end
    local playerCoords = GetEntityCoords(ped)
    local entityCoords = GetEntityCoords(entity)
    return #(playerCoords - entityCoords) <= (maxDistance or 10.0)
end

function Validation.IsPlayerNearCoords(source, coords, maxDistance)
    local normalized = Validation.NormalizeCoords(coords)
    if not normalized then return false end
    local ped = GetPlayerPed(source)
    if not ped or not DoesEntityExist(ped) then return false end
    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - normalized) <= (maxDistance or 10.0)
end

function Validation.IsVehicleOnConfiguredLift(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    local state = Entity(vehicle).state
    local shopId = tonumber(state.shopId)
    local liftId = tonumber(state.liftId)
    if state.onLift ~= true or not Validation.IsPositiveInteger(shopId, 1)
        or not Validation.IsPositiveInteger(liftId, 1) then
        return false
    end

    local encoded = MySQL.scalar.await('SELECT lifts FROM mechanic_shops WHERE id = ?', { shopId })
    if type(encoded) ~= 'string' then return false end
    local ok, lifts = pcall(json.decode, encoded)
    if not ok or type(lifts) ~= 'table' then return false end

    local lift = lifts[liftId]
    local liftCoords = type(lift) == 'table' and Validation.NormalizeCoords(lift.pos) or nil
    if not liftCoords then return false end

    local maxDistance = (Config.Lifts.maxHeight or 2.0) + 2.0
    return #(GetEntityCoords(vehicle) - liftCoords) <= maxDistance
end

function Validation.IsEntityNearShopZone(entity, zoneName, maxDistance)
    if not entity or not DoesEntityExist(entity) or type(zoneName) ~= 'string' then return false end

    local rows = MySQL.query.await('SELECT zones FROM mechanic_shops') or {}
    local entityCoords = GetEntityCoords(entity)
    for _, row in ipairs(rows) do
        if type(row.zones) == 'string' then
            local ok, zones = pcall(json.decode, row.zones)
            local zoneCoords = ok and type(zones) == 'table' and Validation.NormalizeCoords(zones[zoneName]) or nil
            if zoneCoords and #(entityCoords - zoneCoords) <= (maxDistance or 10.0) then
                return true
            end
        end
    end

    return false
end

function Validation.IsVehicleOwned(plate)
    plate = Validation.NormalizePlate(plate)
    if not plate then return false, nil end
    local result = MySQL.query.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', {plate})
    if result and result[1] then
        return true, result[1].citizenid
    end
    return false, nil
end

function Validation.IsVehicleOwnedBy(plate, citizenid)
    if not citizenid then return false end
    plate = Validation.NormalizePlate(plate)
    if not plate then return false end
    local result = MySQL.query.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', {plate})
    return result and result[1] and result[1].citizenid == citizenid
end

function Validation.SanitizeProps(props)
    if type(props) ~= 'table' then return nil end
    local sanitized = {}

    for key, value in pairs(props) do
        if isSafeKey(key) then
            local valueType = type(value)
            if valueType == 'number' or valueType == 'boolean' or valueType == 'string' then
                sanitized[key] = value
            elseif valueType == 'table' then
                local nested = sanitizeTable(value, 1)
                if nested then
                    sanitized[key] = nested
                end
            end
        end
    end

    if next(sanitized) == nil then
        return nil
    end

    return sanitized
end

function Validation.NormalizeFluidData(data)
    if type(data) ~= 'table' then return nil end

    local normalized = {}
    local fields = {
        'oilLevel', 'coolantLevel', 'brakeFluidLevel', 'transmissionFluidLevel',
        'powerSteeringLevel', 'tireWear', 'batteryLevel', 'gearBoxHealth'
    }

    for _, field in ipairs(fields) do
        local value = tonumber(data[field])
        if not Validation.IsNumberInRange(value, 0, 100) then return nil end
        normalized[field] = value
    end

    return normalized
end

function Validation.IsPlausibleFluidUpdate(current, proposed)
    if type(current) ~= 'table' or type(proposed) ~= 'table' then return false end

    local decreasing = {
        'oilLevel', 'coolantLevel', 'brakeFluidLevel', 'transmissionFluidLevel',
        'powerSteeringLevel', 'batteryLevel', 'gearBoxHealth'
    }
    for _, field in ipairs(decreasing) do
        if proposed[field] > (tonumber(current[field]) or 100) + 0.001 then return false end
    end

    return proposed.tireWear >= (tonumber(current.tireWear) or 0) - 0.001
end

function Validation.NormalizeImpactData(data)
    if type(data) ~= 'table' then return nil end

    local side = type(data.side) == 'string' and data.side or ''
    local allowedSides = { [''] = true, ['front-left'] = true, ['front-right'] = true,
        ['rear-left'] = true, ['rear-right'] = true }
    if not allowedSides[side] then return nil end

    return {
        side = side,
        severity = Validation.ClampNumber(tonumber(data.severity), 0, 10, 0),
        wheelDamage = data.wheelDamage == true
    }
end

function Validation.CalculatePerformanceModPrice(modType, level)
    local config = Config.Tuning and Config.Tuning.performanceMods and Config.Tuning.performanceMods[modType]
    if not config then return nil end
    if not Validation.IsNumberInRange(level, 0, config.maxLevel) then return nil end
    return config.basePrice * (level + 1)
end

function Validation.CalculateVisualModPrice(modType, modIndex)
    local config = Config.Tuning and Config.Tuning.visualMods and Config.Tuning.visualMods[modType]
    if not config then return nil end
    if type(modIndex) ~= 'number' or modIndex % 1 ~= 0 or modIndex < -1 or modIndex > 100 then
        return nil
    end
    if modIndex == -1 then
        return 0
    end
    return config.basePrice + (modIndex * 500)
end

function Validation.GetMaxPartUnitPrice()
    local maxPrice = 0
    for _, item in pairs(Config.MaintenanceItems or {}) do
        local price = math.floor((item.price or 0) * (Config.Economy.partMarkup or 1))
        if price > maxPrice then
            maxPrice = price
        end
    end
    for _, part in pairs(Config.VehicleParts or {}) do
        local price = math.floor((part.price or 0) * (Config.Economy.partMarkup or 1))
        if price > maxPrice then
            maxPrice = price
        end
    end
    if maxPrice == 0 then
        maxPrice = Config.Billing.parts.fallbackMaxUnitPrice
    end
    return maxPrice
end

function Validation.NormalizeInvoice(invoice)
    if type(invoice) ~= 'table' then return nil end
    if not Validation.IsPositiveInteger(invoice.targetPlayer, 1, 65535) then return nil end
    if type(invoice.items) ~= 'table' then return nil end

    local normalized = {
        items = {},
        labor = 0,
        parts = 0,
        total = 0,
        targetPlayer = tonumber(invoice.targetPlayer)
    }

    local maxPartUnitPrice = Validation.GetMaxPartUnitPrice()
    local laborConfig = Config.Billing.labor
    local partsConfig = Config.Billing.parts

    if #invoice.items > 50 then return nil end

    for _, item in ipairs(invoice.items) do
        if type(item) == 'table' and type(item.type) == 'string' and type(item.label) == 'string'
            and #item.label >= 1 and #item.label <= 100 then
            if item.type == 'labor' then
                local hours = tonumber(item.quantity)
                local rate = tonumber(item.price)
                if Validation.IsNumberInRange(hours, laborConfig.minHours, laborConfig.maxHours)
                    and Validation.IsNumberInRange(rate, laborConfig.minRate, laborConfig.maxRate) then
                    local total = math.floor((hours * rate) + 0.5)
                    table.insert(normalized.items, {
                        type = 'labor',
                        label = item.label,
                        quantity = hours,
                        price = rate,
                        total = total
                    })
                    normalized.labor = normalized.labor + total
                end
            elseif item.type == 'part' then
                local quantity = tonumber(item.quantity)
                local price = tonumber(item.price)
                if Validation.IsPositiveInteger(quantity, partsConfig.minQuantity, partsConfig.maxQuantity)
                    and Validation.IsNumberInRange(price, 1, maxPartUnitPrice) then
                    quantity = tonumber(quantity)
                    local total = math.floor((quantity * price) + 0.5)
                    table.insert(normalized.items, {
                        type = 'part',
                        label = item.label,
                        quantity = quantity,
                        price = price,
                        total = total
                    })
                    normalized.parts = normalized.parts + total
                end
            end
        end
    end

    normalized.total = normalized.labor + normalized.parts

    if normalized.total <= 0 then
        return nil
    end

    if Config.Billing.maxInvoiceTotal and normalized.total > Config.Billing.maxInvoiceTotal then
        return nil
    end

    return normalized
end

return Validation
