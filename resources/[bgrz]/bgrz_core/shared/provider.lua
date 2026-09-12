BGRZ = BGRZ or {}
BGRZ.Provider = BGRZ.Provider or {}

local defaults = {
    inventory = 'ox_inventory',
    target = 'ox_target',
    phone = 'sd-phone',
    dispatch = 'sd-phone',
    dispatchFallback = 'qbx_police',
}

---@param capability string
---@return string? resource
function BGRZ.Provider.name(capability)
    return BGRZConfig
        and BGRZConfig.Providers
        and BGRZConfig.Providers[capability]
        or defaults[capability]
end

---@param resource string?
---@return boolean started
function BGRZ.Provider.isStarted(resource)
    return type(resource) == 'string'
        and resource ~= ''
        and type(GetResourceState) == 'function'
        and GetResourceState(resource) == 'started'
end

---@param capability string
---@return boolean available
function BGRZ.Provider.isAvailable(capability)
    local resource = BGRZ.Provider.name(capability)
    return BGRZ.Provider.isStarted(resource)
        and exports ~= nil
        and exports[resource] ~= nil
end
