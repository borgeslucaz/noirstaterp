local Wrapping = {}
local Framework = require 'shared.framework'
local Validation = require 'server.modules.validation'
local Database = require 'server.modules.database'

local function isShopMember(Player, shopId)
    if not Validation.IsPositiveInteger(shopId, 1) then return false end
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

---@param material string
---@return boolean
local function isValidMaterial(material)
    return Config.Wrapping.materials[material] ~= nil
end

---@param colorIndex number
---@return boolean
local function isValidColorIndex(colorIndex)
    return Validation.IsPositiveInteger(colorIndex, 0, 160)
end

local function normalizeCatalogEntry(row)
    if type(row) ~= 'table' then return nil end
    local id = tonumber(row.id)
    local primary = tonumber(row.primary_color)
    local secondary = tonumber(row.secondary_color)
    local paintType = tonumber(row.paint_type)
    local pearl = row.pearlescent_color ~= nil and tonumber(row.pearlescent_color) or nil
    local price = tonumber(row.price)
    if not Validation.IsPositiveInteger(id, 1)
        or type(row.name) ~= 'string' or #row.name < 1 or #row.name > 100
        or not isValidColorIndex(primary) or not isValidColorIndex(secondary)
        or not Validation.IsPositiveInteger(paintType, 0, 5)
        or (pearl ~= nil and not isValidColorIndex(pearl))
        or not Validation.IsPositiveInteger(price, 1, 1000000) then
        return nil
    end
    return {
        id = id,
        name = row.name,
        primary_color = primary,
        secondary_color = secondary,
        paint_type = paintType,
        pearlescent_color = pearl,
        price = price,
        shop_id = tonumber(row.shop_id)
    }
end

---@param material string
---@return number
local function calculatePrice(material)
    local matData = Config.Wrapping.materials[material]
    local mult = matData and matData.priceMultiplier or 1.0
    return math.floor(Config.Wrapping.basePrice * mult)
end

---@param shopId number|nil
---@return table
local function getWrapCatalog(shopId)
    local query = 'SELECT * FROM wrap_catalog WHERE shop_id IS NULL'
    local params = {}
    if shopId then
        query = query .. ' OR shop_id = ?'
        params = { shopId }
    end
    local result = MySQL.query.await(query, params) or {}
    local catalog = {}
    for _, row in ipairs(result) do
        local entry = normalizeCatalogEntry(row)
        if entry then catalog[#catalog + 1] = entry end
    end
    return catalog
end

lib.callback.register('mechanic:server:getWrapCatalog', function(source, shopId)
    if not Config.Wrapping.enabled then return {} end
    local Player = Framework.GetPlayer(source)
    if not Player then return {} end
    if not Validation.IsMechanic(Player) then return {} end
    if shopId ~= nil and not isShopMember(Player, shopId) then return {} end
    return getWrapCatalog(shopId)
end)

lib.callback.register('mechanic:server:applyWrap', function(source, netId, primaryColor, secondaryColor, material, liveryIndex)
    local src = source
    if not Config.Wrapping.enabled then return false end
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'wrapping', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'wrapping', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'wrapping', 'rate_limited')
        return false
    end

    if not isValidMaterial(material) then
        Validation.LogDenied(src, 'wrapping', 'invalid_material')
        return false
    end

    if primaryColor ~= -1 and not isValidColorIndex(primaryColor) then
        Validation.LogDenied(src, 'wrapping', 'invalid_primary_color')
        return false
    end

    if secondaryColor ~= -1 and not isValidColorIndex(secondaryColor) then
        Validation.LogDenied(src, 'wrapping', 'invalid_secondary_color')
        return false
    end


    primaryColor = tonumber(primaryColor)
    secondaryColor = tonumber(secondaryColor)

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.Wrapping.maxDistance) then
        Validation.LogDenied(src, 'wrapping', 'vehicle_invalid_or_far')
        return false
    end


    if Config.Wrapping.requireLift and not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(src, 'wrapping', 'vehicle_not_on_lift')
        return false
    end
    if Config.Wrapping.requireBooth
        and not Validation.IsEntityNearShopZone(vehicle, 'paint', Config.Wrapping.boothDistance) then
        Validation.LogDenied(src, 'wrapping', 'vehicle_outside_booth')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'wrapping', 'vehicle_unowned')
        return false
    end

    local price = calculatePrice(material)
    local account = Config.Economy.payWithCash and 'cash' or 'bank'

    if not Player.Functions.RemoveMoney(account, price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('wrap_insufficient_funds'),
            type = 'error'
        })
        return false
    end

    local matData = Config.Wrapping.materials[material]
    local props = {}

    if primaryColor >= 0 then
        props.color1 = primaryColor
    end
    if secondaryColor >= 0 then
        props.color2 = secondaryColor
    end

    if matData then
        props.paintType1 = matData.paintType
        props.paintType2 = matData.paintType
        if matData.pearlescent and primaryColor >= 0 then
            props.pearlescentColor = primaryColor
        end
    end

    local numericLivery = tonumber(liveryIndex)
    if Validation.IsPositiveInteger(numericLivery, 0, 199) then
        if numericLivery >= 100 then
            props.modLivery = numericLivery - 100
        else
            props.livery = numericLivery
        end
    end

    if not Database.MergeVehicleProperties(Validation.NormalizePlate(plate), props) then
        Player.Functions.AddMoney(account, price, 'mechanic-wrap-refund')
        Validation.LogDenied(src, 'wrapping', 'database_update_failed')
        return false
    end

    lib.setVehicleProperties(vehicle, props)

    local vehicleCoords = GetEntityCoords(vehicle)
    local vehNetId = NetworkGetNetworkIdFromEntity(vehicle)
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(playerId))
        if ped and DoesEntityExist(ped) then
            local playerCoords = GetEntityCoords(ped)
            if #(playerCoords - vehicleCoords) < 300.0 then
                TriggerClientEvent('mechanic:client:syncVehicleProperties', tonumber(playerId), vehNetId, props)
            end
        end
    end

    return true
end)

lib.callback.register('mechanic:server:applyWrapCatalog', function(source, netId, catalogId)
    local src = source
    if not Config.Wrapping.enabled then return false end
    local Player = Framework.GetPlayer(src)
    if not Player then return false end

    if not Validation.IsMechanic(Player) then
        Validation.LogDenied(src, 'wrapping', 'not_mechanic')
        return false
    end

    if not Validation.CheckRateLimit(src, 'wrapping_catalog', Config.Security.rateLimits.vehiclePropsMs) then
        Validation.LogDenied(src, 'wrapping_catalog', 'rate_limited')
        return false
    end

    local numericId = tonumber(catalogId)
    if not Validation.IsPositiveInteger(numericId, 1) then
        Validation.LogDenied(src, 'wrapping_catalog', 'invalid_catalog_id')
        return false
    end

    local result = MySQL.query.await('SELECT * FROM wrap_catalog WHERE id = ?', { numericId })
    if not result or not result[1] then
        Validation.LogDenied(src, 'wrapping_catalog', 'catalog_not_found')
        return false
    end

    local catalogEntry = normalizeCatalogEntry(result[1])
    if not catalogEntry then
        Validation.LogDenied(src, 'wrapping_catalog', 'invalid_catalog_data')
        return false
    end
    if catalogEntry.shop_id and not isShopMember(Player, catalogEntry.shop_id) then
        Validation.LogDenied(src, 'wrapping_catalog', 'not_shop_member')
        return false
    end

    local vehicle = Validation.GetVehicleByNetId(netId)
    if not vehicle or not Validation.IsPlayerNearEntity(src, vehicle, Config.Wrapping.maxDistance) then
        Validation.LogDenied(src, 'wrapping_catalog', 'vehicle_invalid_or_far')
        return false
    end


    if Config.Wrapping.requireLift and not Validation.IsVehicleOnConfiguredLift(vehicle) then
        Validation.LogDenied(src, 'wrapping_catalog', 'vehicle_not_on_lift')
        return false
    end
    if Config.Wrapping.requireBooth
        and not Validation.IsEntityNearShopZone(vehicle, 'paint', Config.Wrapping.boothDistance) then
        Validation.LogDenied(src, 'wrapping_catalog', 'vehicle_outside_booth')
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not Validation.IsVehicleOwned(plate) then
        Validation.LogDenied(src, 'wrapping_catalog', 'vehicle_unowned')
        return false
    end

    local account = Config.Economy.payWithCash and 'cash' or 'bank'
    if not Player.Functions.RemoveMoney(account, catalogEntry.price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('wrap_insufficient_funds'),
            type = 'error'
        })
        return false
    end

    local props = {
        color1 = catalogEntry.primary_color,
        color2 = catalogEntry.secondary_color,
        paintType1 = catalogEntry.paint_type,
        paintType2 = catalogEntry.paint_type
    }

    if catalogEntry.pearlescent_color then
        props.pearlescentColor = catalogEntry.pearlescent_color
    end

    if not Database.MergeVehicleProperties(Validation.NormalizePlate(plate), props) then
        Player.Functions.AddMoney(account, catalogEntry.price, 'mechanic-wrap-refund')
        Validation.LogDenied(src, 'wrapping_catalog', 'database_update_failed')
        return false
    end

    lib.setVehicleProperties(vehicle, props)

    local vehicleCoords = GetEntityCoords(vehicle)
    local vehNetId = NetworkGetNetworkIdFromEntity(vehicle)
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(playerId))
        if ped and DoesEntityExist(ped) then
            local playerCoords = GetEntityCoords(ped)
            if #(playerCoords - vehicleCoords) < 300.0 then
                TriggerClientEvent('mechanic:client:syncVehicleProperties', tonumber(playerId), vehNetId, props)
            end
        end
    end

    return true
end)

return Wrapping
