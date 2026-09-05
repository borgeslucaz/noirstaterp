local SuspensionSetup = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'

local function isShopMember(Player, shopId)
    local citizenid = Player.PlayerData.citizenid
    return MySQL.scalar.await([[
        SELECT 1 FROM mechanic_shops s
        WHERE s.id = ? AND (
            s.owner = ? OR EXISTS (
                SELECT 1 FROM mechanic_employees e
                WHERE e.shop_id = s.id AND e.citizenid = ?
            )
        ) LIMIT 1
    ]], { shopId, citizenid, citizenid }) ~= nil
end

---@param data table
---@return table|nil
local function validateSuspensionData(data)
    if type(data) ~= 'table' then return nil end

    local ranges = Config.Suspension.ranges
    local validated = {}

    for param, range in pairs(ranges) do
        local value = tonumber(data[param])
        if not Validation.IsNumberInRange(value, range.min, range.max) then return nil end
        validated[param] = value
    end

    return validated
end

local function normalizeStoredData(row)
    if type(row) ~= 'table' then return nil end
    return {
        id = tonumber(row.id),
        plate = row.plate,
        front_height = tonumber(row.front_height) or 0,
        rear_height = tonumber(row.rear_height) or 0,
        stiffness = tonumber(row.stiffness) or 50,
        front_camber = tonumber(row.front_camber) or 0,
        rear_camber = tonumber(row.rear_camber) or 0,
        front_toe = tonumber(row.front_toe) or 0,
        rear_toe = tonumber(row.rear_toe) or 0
    }
end

---@param data table
---@return number
local function calculatePrice(data)
    local changes = 0
    local defaults = { frontHeight = 0, rearHeight = 0, stiffness = 50, frontCamber = 0, rearCamber = 0, frontToe = 0, rearToe = 0 }

    for param, default in pairs(defaults) do
        if data[param] and math.abs(data[param] - default) > 0.01 then
            changes = changes + 1
        end
    end

    return Config.Suspension.basePrice + (changes * Config.Suspension.perParameterCost)
end

---@param plate string
---@return table|nil
function SuspensionSetup.GetData(plate)
    plate = Validation.NormalizePlate(plate)
    local result = MySQL.query.await('SELECT * FROM vehicle_suspension WHERE plate = ?', { plate })
    if result and result[1] then
        return normalizeStoredData(result[1])
    end
    return nil
end

---@param plate string
---@param data table
---@return boolean
function SuspensionSetup.SaveData(plate, data)
    plate = Validation.NormalizePlate(plate)
    local existing = SuspensionSetup.GetData(plate)
    if existing then
        return MySQL.update.await(
            'UPDATE vehicle_suspension SET front_height = ?, rear_height = ?, stiffness = ?, front_camber = ?, rear_camber = ?, front_toe = ?, rear_toe = ? WHERE plate = ?',
            { data.frontHeight, data.rearHeight, data.stiffness, data.frontCamber, data.rearCamber, data.frontToe, data.rearToe, plate }
        ) > 0
    else
        return MySQL.insert.await(
            'INSERT INTO vehicle_suspension (plate, front_height, rear_height, stiffness, front_camber, rear_camber, front_toe, rear_toe) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { plate, data.frontHeight, data.rearHeight, data.stiffness, data.frontCamber, data.rearCamber, data.frontToe, data.rearToe }
        ) > 0
    end
end

lib.callback.register('mechanic:server:getSuspensionData', function(source, plate)
    if not Config.Suspension.enabled then return nil end
    local Player = Framework.GetPlayer(source)
    if not Player then return nil end
    if not Validation.IsMechanic(Player) or not Validation.IsValidPlate(plate) then return nil end
    local vehicle = Validation.GetVehicleByPlate(plate)
    if not vehicle or not Validation.IsPlayerNearEntity(source, vehicle, Config.Suspension.maxDistance) then return nil end
    return SuspensionSetup.GetData(plate)
end)

lib.callback.register('mechanic:server:applySuspension', function(source, netId, suspensionData)
    local src = source
    if not Config.Suspension.enabled then return false end
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'suspension', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'suspension', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'suspension', 'rate_limited')
        return false
    end

    local validated = validateSuspensionData(suspensionData)
    if not validated then
        Validation.LogDenied(src, 'suspension', 'invalid_data')
        return false
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.Suspension.maxDistance) then
        Validation.LogDenied(src, 'suspension', 'vehicle_invalid_or_far')
        return false
    end

    if Config.Suspension.requireLift and not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(src, 'suspension', 'vehicle_not_on_lift')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'suspension', 'vehicle_unowned')
        return false
    end

    local price = calculatePrice(validated)
    local account = Config.Economy.payWithCash and 'cash' or 'bank'

    if not Player.Functions.RemoveMoney(account, price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('suspension_insufficient_funds'),
            type = 'error'
        })
        return false
    end

    if not SuspensionSetup.SaveData(plate, validated) then
        Player.Functions.AddMoney(account, price, 'mechanic-suspension-refund')
        return false
    end

    Entity(vehicle).state:set('suspensionData', validated, true)

    return true, validated
end)

lib.callback.register('mechanic:server:getSuspensionPresets', function(source, shopId)
    if not Config.Suspension.enabled then return {} end
    local Player = Framework.GetPlayer(source)
    if not Player then return {} end
    if not Validation.IsMechanic(Player) then return {} end
    if not Validation.IsPositiveInteger(shopId, 1) then return {} end
    if not isShopMember(Player, shopId) then return {} end

    local result = MySQL.query.await('SELECT id, name, data, created_by FROM suspension_presets WHERE shop_id = ? ORDER BY name', { shopId })
    if not result then return {} end

    local presets = {}
    for _, row in ipairs(result) do
        local ok, parsed = pcall(json.decode, row.data)
        local validated = ok and validateSuspensionData(parsed) or nil
        if validated then
            presets[#presets + 1] = {
                id = row.id,
                name = row.name,
                data = validated,
                createdBy = row.created_by
            }
        end
    end

    return presets
end)

lib.callback.register('mechanic:server:saveSuspensionPreset', function(source, shopId, presetName, presetData)
    local src = source
    if not Config.Suspension.enabled then return false end
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'suspension_preset', 'not_mechanic')
        return false
    end

    if not Validation.IsPositiveInteger(shopId, 1) then return false end
    if not isShopMember(Player, shopId) then
        Validation.LogDenied(src, 'suspension_preset', 'not_shop_member')
        return false
    end
    if type(presetName) ~= 'string' then return false end
    presetName = presetName:match('^%s*(.-)%s*$')
    if #presetName < 1 or #presetName > 50 or presetName:find('[%c]') then return false end

    local validated = validateSuspensionData(presetData)
    if not validated then return false end

    local existingId = MySQL.scalar.await(
        'SELECT id FROM suspension_presets WHERE shop_id = ? AND name = ? LIMIT 1',
        { shopId, presetName }
    )
    if not existingId then
        local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM suspension_presets WHERE shop_id = ?', { shopId })) or 0
        if count >= Config.Suspension.maxPresets then return false end
    end

    local citizenid = Player.PlayerData.citizenid
    MySQL.insert.await(
        'INSERT INTO suspension_presets (shop_id, name, data, created_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), created_by = VALUES(created_by)',
        { shopId, presetName, json.encode(validated), citizenid }
    )

    return true
end)

return SuspensionSetup
