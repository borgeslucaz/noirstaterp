local resource_name = "qbx_properties"

local function decode_array(value)
    if type(value) == "table" then
        return value
    end
    if type(value) ~= "string" or value == "" then
        return {}
    end
    local success, decoded = pcall(json.decode, value)
    return success and type(decoded) == "table" and decoded or {}
end

local function query_properties(identifier)
    local success, properties = pcall(function()
        return MySQL.query.await([[
            SELECT id, property_name, owner, keyholders, coords, garage
            FROM properties
            WHERE owner = ? OR JSON_CONTAINS(keyholders, JSON_QUOTE(?))
            ORDER BY property_name ASC, id ASC
        ]], { identifier, identifier })
    end)
    if not success or type(properties) ~= "table" then
        Bridge.Debug("error", "[sky_phone] qbx_properties overview query failed: %s", tostring(properties))
        return nil
    end
    return properties
end

local function query_property(property_id)
    local success, property = pcall(function()
        return MySQL.single.await([[
            SELECT id, property_name, owner, keyholders, coords, garage
            FROM properties
            WHERE id = ?
        ]], { property_id })
    end)
    if not success then
        Bridge.Debug("error", "[sky_phone] qbx_properties property query failed: %s", tostring(property))
        return nil, "provider_error"
    end
    if type(property) ~= "table" then
        return nil, "property_not_found"
    end
    return property
end

local function online_source(identifier)
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        if Bridge.Framework.GetIdentifier(player_source) == identifier then
            return player_source
        end
    end
    return nil
end

local function character_name(identifier)
    local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
        or exports.qbx_core:GetOfflinePlayer(identifier)
    local character = player and player.PlayerData and player.PlayerData.charinfo
    if character then
        local name = ("%s %s"):format(character.firstname or "", character.lastname or "")
            :match("^%s*(.-)%s*$")
        if name ~= "" then
            return name
        end
    end
    return identifier
end

local function access_for(property, identifier)
    if property.owner == identifier then
        return "owner"
    end
    for _, keyholder in ipairs(decode_array(property.keyholders)) do
        if keyholder == identifier then
            return "keyholder"
        end
    end
    return nil
end

local function valid_coords(value)
    return type(value) == "table"
        and tonumber(value.x) ~= nil
        and tonumber(value.y) ~= nil
        and tonumber(value.z) ~= nil
end

local function garage_name(property_name)
    return "property_" .. string.gsub(string.lower(property_name), " ", "_")
end

local function garage_counts(identifier)
    if GetResourceState("qbx_garages") ~= "started" then
        return {}
    end
    local success, rows = pcall(function()
        return MySQL.query.await([[
            SELECT garage, COUNT(*) AS stored_count
            FROM player_vehicles
            WHERE citizenid = ? AND state = 1 AND garage IS NOT NULL
            GROUP BY garage
        ]], { identifier })
    end)
    if not success or type(rows) ~= "table" then
        Bridge.Debug("error", "[sky_phone] qbx_properties garage status query failed: %s", tostring(rows))
        return {}
    end
    local counts = {}
    for _, row in ipairs(rows) do
        if type(row.garage) == "string" then
            counts[row.garage] = tonumber(row.stored_count) or 0
        end
    end
    return counts
end

local function normalized_keys(property)
    local keys = {}
    for _, identifier in ipairs(decode_array(property.keyholders)) do
        if type(identifier) == "string" and identifier ~= "" then
            keys[#keys + 1] = {
                identifier = identifier,
                name = character_name(identifier),
                online = online_source(identifier) ~= nil,
                revocable = true,
            }
        end
    end
    table.sort(keys, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return keys
end

local function normalized_property(property, access, counts)
    local coords = decode_array(property.coords)
    local garage = property.garage and decode_array(property.garage) or nil
    local garage_configured = garage and valid_coords(garage)
    local garage_enabled = garage_configured
        and GetResourceState("qbx_garages") == "started"
    return {
        id = ("qbx_properties:%s"):format(property.id),
        providerId = tostring(property.id),
        name = tostring(property.property_name or ("Property %s"):format(property.id)),
        access = access,
        locked = false,
        entrance = {
            x = tonumber(coords.x),
            y = tonumber(coords.y),
            z = tonumber(coords.z),
        },
        capabilities = {
            lock = false,
            keys = access == "owner",
            waypoint = true,
            cctv = false,
            garageStatus = garage_configured and true or false,
        },
        cctv = { enabled = false },
        garage = garage_configured and {
            enabled = garage_enabled and true or false,
            storedVehicles = counts[garage_name(property.property_name)] or 0,
        } or nil,
        keys = access == "owner" and normalized_keys(property) or nil,
    }
end

local function parse_property_id(value)
    if type(value) ~= "string" then
        return nil
    end
    local property_id = tonumber(value:match("^qbx_properties:(%d+)$"))
    if not property_id or property_id < 1 or property_id ~= math.floor(property_id) then
        return nil
    end
    return property_id
end

local function resolve_property(source, data)
    local property_id = parse_property_id(data and data.propertyId)
    if not property_id then
        return nil, nil, nil, "invalid_property"
    end
    local property, error_code = query_property(property_id)
    if not property then
        return nil, nil, nil, error_code
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    local access = identifier and access_for(property, identifier) or nil
    local coords = decode_array(property.coords)
    if not access then
        return nil, nil, nil, "property_access_denied"
    end
    if not valid_coords(coords) then
        return nil, nil, nil, "invalid_coordinates"
    end
    return property, property_id, access
end

local function player_property_id(player)
    local metadata = player and player.PlayerData and player.PlayerData.metadata
    return metadata and tonumber(metadata.currentPropertyId) or nil
end

local function key_candidates(source, property, property_id)
    local candidates = {}
    for _, target in ipairs(Bridge.Framework.GetPlayers()) do
        local player = exports.qbx_core:GetPlayer(target)
        local identifier = player and player.PlayerData and player.PlayerData.citizenid
        if target ~= source and identifier and player_property_id(player) == property_id
            and not access_for(property, identifier)
        then
            candidates[#candidates + 1] = {
                id = target,
                name = character_name(identifier),
            }
        end
    end
    table.sort(candidates, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return candidates
end

local function execute_key_action(source, action, data)
    if not SkyPhone.AllowOperation(source, "housing_qbx_action", Config.Housing.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if action ~= "grant_key" and action ~= "revoke_key" then
        return { success = false, error = "invalid_action" }
    end

    local property_id = tonumber(data and data.providerId)
    if not property_id or property_id < 1 or property_id ~= math.floor(property_id) then
        return { success = false, error = "invalid_property" }
    end
    local property, error_code = query_property(property_id)
    if not property then
        return { success = false, error = error_code }
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier or property.owner ~= identifier then
        return { success = false, error = "owner_required" }
    end

    if action == "grant_key" then
        local target = tonumber(data.target)
        local target_player = target and exports.qbx_core:GetPlayer(target) or nil
        local target_identifier = target_player and target_player.PlayerData
            and target_player.PlayerData.citizenid or nil
        if not target_identifier or target == source or player_property_id(target_player) ~= property_id then
            return { success = false, error = "target_not_in_property" }
        end
        if access_for(property, target_identifier) then
            return { success = false, error = "key_already_exists" }
        end
        local affected = MySQL.update.await([[
            UPDATE properties
            SET keyholders = JSON_ARRAY_APPEND(
                CASE WHEN JSON_TYPE(keyholders) = 'ARRAY' THEN keyholders ELSE JSON_ARRAY() END,
                '$', ?
            )
            WHERE id = ? AND owner = ?
              AND NOT JSON_CONTAINS(
                  CASE WHEN JSON_TYPE(keyholders) = 'ARRAY' THEN keyholders ELSE JSON_ARRAY() END,
                  JSON_QUOTE(?)
              )
        ]], { target_identifier, property_id, identifier, target_identifier })
        return affected == 1 and { success = true } or { success = false, error = "action_failed" }
    end

    local target_identifier = data.identifier
    if type(target_identifier) ~= "string" or target_identifier == "" then
        return { success = false, error = "invalid_target" }
    end
    local affected = MySQL.update.await([[
        UPDATE properties
        SET keyholders = JSON_REMOVE(
            keyholders,
            JSON_UNQUOTE(JSON_SEARCH(keyholders, 'one', ?))
        )
        WHERE id = ? AND owner = ?
          AND JSON_SEARCH(keyholders, 'one', ?) IS NOT NULL
    ]], { target_identifier, property_id, identifier, target_identifier })
    return affected == 1 and { success = true } or { success = false, error = "key_not_found" }
end

Bridge.Housing.RegisterProvider("qbx_properties", {
    resource_name = resource_name,
    is_available = function()
        return Bridge.Framework.GetName() == "qbox"
            and GetResourceState(resource_name) == "started"
    end,
    get_overview = function(source)
        local identifier = Bridge.Framework.GetIdentifier(source)
        if not identifier then
            return nil, "housing_unavailable"
        end
        local properties = query_properties(identifier)
        if not properties then
            return nil, "provider_error"
        end
        local counts = garage_counts(identifier)
        local result = {}
        for _, property in ipairs(properties) do
            local access = access_for(property, identifier)
            local coords = decode_array(property.coords)
            if access and valid_coords(coords) then
                result[#result + 1] = normalized_property(property, access, counts)
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
        local property, property_id, access, error_code = resolve_property(source, data)
        if not property then
            return nil, error_code
        end
        if action == "set_waypoint" then
            local coords = decode_array(property.coords)
            return { coords = { x = tonumber(coords.x), y = tonumber(coords.y), z = tonumber(coords.z) } }
        end
        if action == "key_candidates" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            return { candidates = key_candidates(source, property, property_id) }
        end
        if action == "grant_key" or action == "revoke_key" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            return {
                providerId = tostring(property_id),
                target = data.target,
                identifier = data.identifier,
            }
        end
        if action == "toggle_lock" then
            return nil, "capability_unavailable"
        end
        if action == "open_cctv" then
            return nil, "cctv_unavailable"
        end
        return nil, "invalid_action"
    end,
})

Bridge.Callbacks.Register("sky_phone:housing:qbx_properties:execute", function(source, data)
    if type(data) ~= "table" or type(data.action) ~= "string" then
        return { success = false, error = "invalid_request" }
    end
    return execute_key_action(source, data.action, data)
end)
