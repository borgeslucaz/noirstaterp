BGRZ = BGRZ or {}

---@return table capabilities
function BGRZ.GetCapabilities()
    local inventory = BGRZ.Provider.name('inventory')
    local target = BGRZ.Provider.name('target')
    local phone = BGRZ.Provider.name('phone')
    local dispatch = BGRZ.Provider.name('dispatch')
    local fallback = BGRZ.Provider.name('dispatchFallback')
    local dispatchProvider
    if BGRZ.Provider.isStarted(dispatch) then
        dispatchProvider = dispatch
    elseif BGRZ.Provider.isStarted(fallback) then
        dispatchProvider = fallback
    end

    return {
        version = BGRZConfig and BGRZConfig.Version or '0.5.0',
        inventory = {
            available = BGRZ.Provider.isStarted(inventory),
            provider = inventory,
            maxItemAmount = BGRZConfig and BGRZConfig.Limits and BGRZConfig.Limits.maxItemAmount or 100000,
        },
        target = { available = BGRZ.Provider.isStarted(target), provider = target },
        phone = { available = BGRZ.Provider.isStarted(phone), provider = phone },
        dispatch = { available = dispatchProvider ~= nil, provider = dispatchProvider },
    }
end

exports('GetCapabilities', BGRZ.GetCapabilities)
