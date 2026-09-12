BGRZ = BGRZ or {}

local notificationFields = {
    app = 64,
    appId = 64,
    title = 96,
    body = 512,
    image = 2048,
    time = 32,
}


local function normalizePayload(payload)
    if type(payload) ~= 'table' or type(payload.title) ~= 'string'
        or #payload.title == 0 or #payload.title > notificationFields.title then
        return nil
    end
    local normalized = {}
    for field, maximum in pairs(notificationFields) do
        local value = payload[field]
        if value ~= nil then
            if type(value) ~= 'string' or #value > maximum then return nil end
            normalized[field] = value
        end
    end
    return normalized
end

---@param source number
---@param payload table
---@return boolean ok
---@return string? errorCode
function BGRZ.SendPhoneNotification(source, payload)
    if type(source) ~= 'number' or source <= 0 or source % 1 ~= 0 then
        return false, 'invalid_source'
    end
    local normalized = normalizePayload(payload)
    if not normalized then return false, 'invalid_payload' end

    local provider = BGRZ.Provider.name('phone')
    if not BGRZ.Provider.isAvailable('phone') then return false, 'provider_unavailable' end
    local called, sent = pcall(function()
        return exports[provider]:notify(source, normalized)
    end)
    if not called then return false, 'provider_unavailable' end
    if sent ~= true then return false, 'notification_failed' end
    return true
end

exports('SendPhoneNotification', BGRZ.SendPhoneNotification)
