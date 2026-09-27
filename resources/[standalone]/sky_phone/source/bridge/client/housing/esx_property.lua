if Bridge.Framework.GetName() ~= "esx" then
    return
end

if GetResourceState("esx_property") ~= "started" then
    Bridge.Debug("warn", "[sky_phone] esx_property is not started; the housing provider is disabled.")
    return
end

local ESX = exports["es_extended"]:getSharedObject()

local callback_names = {
    grant_key = "esx_property:GiveKey",
    revoke_key = "esx_property:RemoveKey",
    toggle_lock = "esx_property:toggleLock",
}

local function await_callback(name, arguments)
    local request = promise.new()
    local settled = false
    ESX.TriggerServerCallback(name, function(success)
        if settled then
            return
        end
        settled = true
        request:resolve(success and true or false)
    end, table.unpack(arguments))
    SetTimeout(Config.Bridge.CallbackTimeout, function()
        if settled then
            return
        end
        settled = true
        Bridge.Debug("error", "[sky_phone] Housing provider callback '%s' timed out.", name)
        request:resolve(false)
    end)
    return Citizen.Await(request)
end

Bridge.Housing.RegisterClientProvider("esx_property", {
    execute = function(action, data)
        local callback_name = callback_names[action]
        if not callback_name or GetResourceState("esx_property") ~= "started" then
            return false, "provider_unavailable"
        end

        local property_id = tonumber(data.providerId)
        if not property_id or property_id < 1 or property_id ~= math.floor(property_id) then
            return false, "invalid_property"
        end

        local arguments = { property_id }
        if action == "grant_key" then
            arguments[2] = tonumber(data.target)
        elseif action == "revoke_key" then
            arguments[2] = data.identifier
        end
        if (action == "grant_key" and not arguments[2])
            or (action == "revoke_key" and type(arguments[2]) ~= "string")
        then
            return false, "invalid_request"
        end

        if await_callback(callback_name, arguments) then
            return true
        end
        return false, "provider_rejected"
    end,
})
