local Database = {}

local function decodeJson(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or fallback
end

-- Retrieves all mechanic shops from the database
function Database.GetAllShops()
    local result = MySQL.query.await('SELECT * FROM mechanic_shops')
    if result then
        for _, shop in ipairs(result) do
            shop.zones = decodeJson(shop.zones, {})
            shop.lifts = decodeJson(shop.lifts, {})
            shop.vehicleSpawns = decodeJson(shop.vehicleSpawns, {})
            shop.storage = decodeJson(shop.storage, {})
            shop.payrollEnabled = shop.payrollEnabled == true or shop.payrollEnabled == 1
        end
    end
    return result or {}
end

-- Updates a mechanic shop with new data
function Database.UpdateShop(shopId, data)
    local query = 'UPDATE mechanic_shops SET zones = ?, lifts = ?, vehicleSpawns = ? WHERE id = ?'
    local params = {json.encode(data.zones), json.encode(data.lifts), json.encode(data.vehicleSpawns), shopId}
    return MySQL.update.await(query, params) > 0
end

-- Creates a new mechanic shop
function Database.CreateShop(data)
    local query = 'INSERT INTO mechanic_shops (name, price, zones, lifts, vehicleSpawns) VALUES (?, ?, ?, ?, ?)'
    local params = {data.name, data.price, json.encode(data.zones), json.encode(data.lifts), json.encode(data.vehicleSpawns)}
    return MySQL.insert.await(query, params)
end

function Database.UpdateShopStorage(shopId, storage)
    local query = 'UPDATE mechanic_shops SET storage = ? WHERE id = ?'
    return MySQL.update.await(query, {json.encode(storage or {}), shopId}) > 0
end

-- Updates the vehicle data, including colors and other properties
function Database.UpdateVehicleProperties(plate, properties)
    if type(plate) ~= 'string' or type(properties) ~= 'table' then return false end
    local query = 'UPDATE player_vehicles SET props = ?, mods = ? WHERE plate = ?'
    local encoded = json.encode(properties)
    local params = {encoded, encoded, plate}
    return MySQL.update.await(query, params) > 0
end

-- Merges partial changes (paint, wrap, suspension, etc.) into the complete
-- Qbox vehicle properties instead of replacing the entire mods document.
function Database.MergeVehicleProperties(plate, changes)
    if type(changes) ~= 'table' then return false end

    local row = MySQL.single.await('SELECT mods, props FROM player_vehicles WHERE plate = ?', { plate })
    if not row then return false end

    local properties = decodeJson(row.mods, nil) or decodeJson(row.props, {})
    for key, value in pairs(changes) do
        properties[key] = value
    end

    return Database.UpdateVehicleProperties(plate, properties)
end

return Database
