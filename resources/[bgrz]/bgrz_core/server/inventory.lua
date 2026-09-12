BGRZ = BGRZ or {}

local function isFinite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function validateHolder(holder)
    if type(holder) == 'number' then
        return isFinite(holder) and holder > 0 and holder % 1 == 0
    end
    return type(holder) == 'string' and #holder > 0 and #holder <= 128
end

local function validateItemArguments(holder, item, amount, metadata)
    if not validateHolder(holder) then return false, 'invalid_holder' end
    if type(item) ~= 'string' or #item == 0 or #item > 64 then
        return false, 'invalid_item'
    end
    local maximum = BGRZConfig
        and BGRZConfig.Limits
        and BGRZConfig.Limits.maxItemAmount
        or 100000
    if amount ~= nil and (not isFinite(amount) or amount % 1 ~= 0
        or amount < 1 or amount > maximum) then
        return false, 'invalid_amount'
    end
    if metadata ~= nil and type(metadata) ~= 'table' then
        return false, 'invalid_metadata'
    end
    return true
end

local knownProviderErrors = {
    inventory_full = true,
    invalid_inventory = true,
    invalid_item = true,
    not_enough_items = true,
    not_enough_items_in_slot = true,
    no_item_in_slot = true,
}

local function providerError(value, fallback)
    if type(value) == 'string' and knownProviderErrors[value] then return value end
    return fallback
end

---@param holder number|string
---@param item string
---@param amount integer
---@param metadata? table
---@return boolean ok
---@return string? errorCode
function BGRZ.AddItem(holder, item, amount, metadata)
    local valid, validationError = validateItemArguments(holder, item, amount, metadata)
    if not valid then return false, validationError end
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return false, 'provider_unavailable' end

    local called, ok, result = pcall(function()
        return exports[provider]:AddItem(holder, item, amount, metadata)
    end)
    if not called then return false, 'provider_unavailable' end
    if ok ~= true then return false, providerError(result, 'operation_failed') end
    return true
end

---@param holder number|string
---@param item string
---@param amount integer
---@param metadata? table
---@return boolean ok
---@return string? errorCode
function BGRZ.RemoveItem(holder, item, amount, metadata)
    local valid, validationError = validateItemArguments(holder, item, amount, metadata)
    if not valid then return false, validationError end
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return false, 'provider_unavailable' end

    local called, ok, result = pcall(function()
        return exports[provider]:RemoveItem(holder, item, amount, metadata)
    end)
    if not called then return false, 'provider_unavailable' end
    if ok ~= true then return false, providerError(result, 'operation_failed') end
    return true
end

---@param holder number|string
---@param item string
---@param metadata? table
---@return integer? count
---@return string? errorCode
function BGRZ.GetItemCount(holder, item, metadata)
    local valid, validationError = validateItemArguments(holder, item, nil, metadata)
    if not valid then return nil, validationError end
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return nil, 'provider_unavailable' end

    local called, count = pcall(function()
        return exports[provider]:GetItemCount(holder, item, metadata)
    end)
    if not called then return nil, 'provider_unavailable' end
    if not isFinite(count) or count < 0 then return nil, 'operation_failed' end
    return math.floor(count)
end

---@param holder number|string
---@param item string
---@param amount integer
---@param metadata? table
---@return boolean canCarry
---@return string? errorCode
function BGRZ.CanCarryItem(holder, item, amount, metadata)
    local valid, validationError = validateItemArguments(holder, item, amount, metadata)
    if not valid then return false, validationError end
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return false, 'provider_unavailable' end

    local called, canCarry = pcall(function()
        return exports[provider]:CanCarryItem(holder, item, amount, metadata)
    end)
    if not called then return false, 'provider_unavailable' end
    if canCarry ~= true then return false, 'cannot_carry' end
    return true
end

exports('AddItem', BGRZ.AddItem)
exports('RemoveItem', BGRZ.RemoveItem)
exports('GetItemCount', BGRZ.GetItemCount)
exports('CanCarryItem', BGRZ.CanCarryItem)
