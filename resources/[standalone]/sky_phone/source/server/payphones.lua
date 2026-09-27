SkyPhonePayphones = {}

local maximum_horizontal_coordinate = 10000.0
local maximum_vertical_coordinate = 2000.0

local function finite_number(value)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end

local function normalize_coordinates(value, allow_vector)
    local value_type = type(value)
    local supported_vector = value_type == "vector3" or value_type == "vector4"
    if value_type ~= "table" and (not allow_vector or not supported_vector) then
        return nil
    end

    local x = finite_number(value.x)
    local y = finite_number(value.y)
    local z = finite_number(value.z)
    if not x or not y or not z
        or math.abs(x) > maximum_horizontal_coordinate
        or math.abs(y) > maximum_horizontal_coordinate
        or math.abs(z) > maximum_vertical_coordinate
    then
        return nil
    end

    return { x = x, y = y, z = z }
end

local function normalize_location(location, allowed_models)
    if type(location) ~= "table" or type(location.model) ~= "string" or not allowed_models[location.model] then
        return nil
    end

    local coords = normalize_coordinates(location.coords, false)
    if not coords then
        return nil
    end

    return {
        model = location.model,
        coords = coords,
    }
end

function SkyPhonePayphones.ValidateDetected(location, allowed_models, player_coords, maximum_distance)
    if type(allowed_models) ~= "table" then
        return nil
    end

    local normalized = normalize_location(location, allowed_models)
    local coords = normalize_coordinates(player_coords, true)
    local distance = finite_number(maximum_distance)
    if not normalized or not coords or not distance or distance <= 0 then
        return nil
    end

    local dx = coords.x - normalized.coords.x
    local dy = coords.y - normalized.coords.y
    local dz = coords.z - normalized.coords.z
    if dx * dx + dy * dy + dz * dz > distance * distance then
        return nil
    end

    return normalized
end
