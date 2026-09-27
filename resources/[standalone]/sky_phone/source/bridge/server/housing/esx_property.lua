local resource_name = "esx_property"

local function property_list()
    local success, properties = pcall(function()
        return exports[resource_name]:GetProperties()
    end)
    if not success or type(properties) ~= "table" then
        Bridge.Debug("error", "[sky_phone] esx_property:GetProperties failed: %s", tostring(properties))
        return nil
    end
    return properties
end

local function online_source(identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return nil
    end
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        if Bridge.Framework.GetIdentifier(player_source) == identifier then
            return player_source
        end
    end
    return nil
end

local function player_name(player_source)
    local first_name = Bridge.Framework.GetFirstname(player_source)
    local last_name = Bridge.Framework.GetLastname(player_source)
    local name = table.concat({ tostring(first_name or ""), tostring(last_name or "") }, " ")
        :match("^%s*(.-)%s*$")
    if name ~= "" then
        return name
    end
    return GetPlayerName(player_source) or tostring(player_source)
end

local function valid_coords(value)
    return type(value) == "table"
        and tonumber(value.x) ~= nil
        and tonumber(value.y) ~= nil
        and tonumber(value.z) ~= nil
end

local function valid_camera(property)
    local cctv = property.cctv
    return type(cctv) == "table"
        and cctv.enabled == true
        and valid_coords(property.Entrance)
        and valid_coords(cctv.rot)
end

local function access_for(property, identifier)
    if property.Owned ~= true then
        return nil
    end
    if property.Owner == identifier then
        return "owner"
    end
    if type(property.Keys) == "table" and property.Keys[identifier] then
        return "keyholder"
    end
    return nil
end

local function normalized_keys(property)
    local keys = {}
    if type(property.Keys) ~= "table" then
        return keys
    end
    for identifier, value in pairs(property.Keys) do
        if type(identifier) == "string" and type(value) == "table" then
            local online = online_source(identifier) ~= nil
            keys[#keys + 1] = {
                identifier = identifier,
                name = tostring(value.name or identifier),
                online = online,
                revocable = online,
            }
        end
    end
    table.sort(keys, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return keys
end

local function normalized_property(index, property, access)
    local entrance = property.Entrance
    local garage = type(property.garage) == "table" and property.garage or nil
    local stored_vehicles = garage and type(garage.StoredVehicles) == "table"
        and #garage.StoredVehicles or 0
    return {
        id = ("esx_property:%s"):format(index),
        providerId = tostring(index),
        name = tostring(property.setName and property.setName ~= "" and property.setName or property.Name or ("Property %s"):format(index)),
        access = access,
        locked = property.Locked == true,
        entrance = {
            x = tonumber(entrance.x),
            y = tonumber(entrance.y),
            z = tonumber(entrance.z),
        },
        capabilities = {
            lock = true,
            keys = access == "owner",
            waypoint = true,
            cctv = valid_camera(property),
            garageStatus = garage ~= nil,
        },
        cctv = {
            enabled = valid_camera(property),
        },
        garage = garage and {
            enabled = garage.enabled == true,
            storedVehicles = stored_vehicles,
        } or nil,
        keys = access == "owner" and normalized_keys(property) or nil,
    }
end

local function resolve_property(source, data)
    if type(data) ~= "table" or type(data.propertyId) ~= "string" then
        return nil, nil, nil, "invalid_request"
    end
    local provider_id = data.propertyId:match("^esx_property:(%d+)$")
    local index = tonumber(provider_id)
    if not index or index < 1 or index ~= math.floor(index) then
        return nil, nil, nil, "invalid_property"
    end
    local properties = property_list()
    local property = properties and properties[index]
    if type(property) ~= "table" or not valid_coords(property.Entrance) then
        return nil, nil, nil, "property_not_found"
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    local access = identifier and access_for(property, identifier) or nil
    if not access then
        return nil, nil, nil, "property_access_denied"
    end
    return property, tostring(index), access
end

local function key_candidates(source, property)
    local candidates = {}
    local seen = {}
    for _, value in pairs(property.plysinside or {}) do
        local target = tonumber(value)
        local target_identifier = target and Bridge.Framework.GetIdentifier(target) or nil
        if target and target ~= source and target_identifier and not seen[target]
            and target_identifier ~= property.Owner
            and not (type(property.Keys) == "table" and property.Keys[target_identifier])
        then
            seen[target] = true
            candidates[#candidates + 1] = {
                id = target,
                name = player_name(target),
            }
        end
    end
    table.sort(candidates, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return candidates
end

Bridge.Housing.RegisterProvider("esx_property", {
    resource_name = resource_name,
    is_available = function()
        return Bridge.Framework.GetName() == "esx"
            and GetResourceState(resource_name) == "started"
    end,
    get_overview = function(source)
        local identifier = Bridge.Framework.GetIdentifier(source)
        if not identifier then
            return nil, "housing_unavailable"
        end
        local properties = property_list()
        if not properties then
            return nil, "provider_error"
        end
        local result = {}
        for index, property in ipairs(properties) do
            local access = type(property) == "table" and access_for(property, identifier) or nil
            if access and valid_coords(property.Entrance) then
                result[#result + 1] = normalized_property(index, property, access)
                if #result >= Config.Housing.MaximumProperties then
                    break
                end
            end
        end
        table.sort(result, function(left, right)
            if left.access ~= right.access then
                return left.access == "owner"
            end
            return string.lower(left.name) < string.lower(right.name)
        end)
        return result
    end,
    prepare = function(source, action, data)
        local property, provider_id, access, error_code = resolve_property(source, data)
        if not property then
            return nil, error_code
        end

        if action == "key_candidates" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            return { candidates = key_candidates(source, property) }
        end
        if action == "toggle_lock" then
            return { providerId = provider_id }
        end
        if action == "set_waypoint" then
            return {
                coords = {
                    x = tonumber(property.Entrance.x),
                    y = tonumber(property.Entrance.y),
                    z = tonumber(property.Entrance.z),
                },
            }
        end
        if action == "open_cctv" then
            if not valid_camera(property) then
                return nil, "cctv_unavailable"
            end
            return {
                camera = {
                    coords = {
                        x = tonumber(property.Entrance.x),
                        y = tonumber(property.Entrance.y),
                        z = tonumber(property.Entrance.z) + Config.Housing.Camera.HeightAboveEntrance,
                    },
                    rotation = {
                        x = tonumber(property.cctv.rot.x),
                        y = tonumber(property.cctv.rot.y),
                        z = tonumber(property.cctv.rot.z),
                    },
                    maximumLeft = tonumber(property.cctv.maxleft),
                    maximumRight = tonumber(property.cctv.maxright),
                },
            }
        end
        if access ~= "owner" then
            return nil, "owner_required"
        end
        if action == "grant_key" then
            local target = tonumber(data.target)
            if not target then
                return nil, "invalid_target"
            end
            local candidates = key_candidates(source, property)
            for _, candidate in ipairs(candidates) do
                if candidate.id == target then
                    return { providerId = provider_id, target = target }
                end
            end
            return nil, "target_not_in_property"
        end
        if action == "revoke_key" then
            local identifier = data.identifier
            if type(identifier) ~= "string" or type(property.Keys) ~= "table" or not property.Keys[identifier] then
                return nil, "key_not_found"
            end
            if not online_source(identifier) then
                return nil, "keyholder_offline"
            end
            return { providerId = provider_id, identifier = identifier }
        end
        return nil, "invalid_action"
    end,
})
