if Bridge.Framework.GetName() ~= "qbox" then
    return
end

Bridge.Housing.RegisterClientProvider("qbx_properties", {
    execute = function(action, data)
        if action ~= "grant_key" and action ~= "revoke_key" then
            return false, "capability_unavailable"
        end
        if GetResourceState("qbx_properties") ~= "started" then
            return false, "provider_unavailable"
        end
        local result = Bridge.Callbacks.Trigger("sky_phone:housing:qbx_properties:execute", {
            action = action,
            providerId = data.providerId,
            target = data.target,
            identifier = data.identifier,
        })
        if result and result.success then
            return true
        end
        return false, result and result.error or "provider_rejected"
    end,
})
