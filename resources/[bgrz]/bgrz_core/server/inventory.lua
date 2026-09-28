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

---Rótulo de exibição de um item, para o resource montar texto sem conhecer o
---provider. Item desconhecido devolve o próprio nome: quem chamou sempre tem algo
---legível para mostrar.
---@param item string
---@return string? label
---@return string? errorCode
function BGRZ.GetItemLabel(item)
    if type(item) ~= 'string' or #item == 0 or #item > 64 then return nil, 'invalid_item' end
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return item, 'provider_unavailable' end

    local called, data = pcall(function()
        return exports[provider]:Items(item)
    end)
    if not called or type(data) ~= 'table' or type(data.label) ~= 'string' then
        return item, 'unknown_item'
    end
    return data.label
end

---Catálogo de itens como `{ name, label }`, ordenado por rótulo, para menus de
---admin escolherem item sem conhecer o provider.
---@return { name: string, label: string }[]? items
---@return string? errorCode
function BGRZ.GetItemList()
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return nil, 'provider_unavailable' end

    local called, data = pcall(function()
        return exports[provider]:Items()
    end)
    if not called or type(data) ~= 'table' then return nil, 'provider_unavailable' end

    local list = {}
    for name, item in pairs(data) do
        if type(name) == 'string' then
            local label = type(item) == 'table' and type(item.label) == 'string' and item.label or name
            list[#list + 1] = { name = name, label = label }
        end
    end
    table.sort(list, function(a, b)
        if a.label == b.label then return a.name < b.name end
        return a.label < b.label
    end)
    return list
end

-- Durabilidade de ferramenta ------------------------------------------------------------
--
-- A escala é a do ox_inventory: 0 a 100. Acima de 100 o provider guarda um instante de
-- validade (item com `degrade`), que não é "desgaste por uso"; esses slots são ignorados
-- em vez de terem um timestamp subtraído. Slot sem `durability` conta como novo (100),
-- que é como o provider trata o item recém-criado.

local FULL_DURABILITY = 100

local function validateDurabilityArguments(holder, item, cost)
    if not validateHolder(holder) then return false, 'invalid_holder' end
    if type(item) ~= 'string' or #item == 0 or #item > 64 then return false, 'invalid_item' end
    if not isFinite(cost) or cost < 0 or cost > FULL_DURABILITY then return false, 'invalid_amount' end
    return true
end

---Primeiro slot do item com durabilidade suficiente para `cost`.
local function findDurableSlot(provider, holder, item, cost)
    local called, slots = pcall(function()
        return exports[provider]:Search(holder, 'slots', item)
    end)
    if not called then return nil, nil, 'provider_unavailable' end
    if type(slots) ~= 'table' or #slots == 0 then return nil, nil, 'not_enough_items' end

    for index = 1, #slots do
        local slot = slots[index]
        local metadata = type(slot) == 'table' and slot.metadata or nil
        local durability = type(metadata) == 'table' and metadata.durability or nil
        if durability == nil then durability = FULL_DURABILITY end
        if isFinite(durability) and durability <= FULL_DURABILITY and durability >= cost
            and type(slot.slot) == 'number' then
            return slot.slot, durability
        end
    end
    return nil, nil, 'low_durability'
end

---O holder tem o item com pelo menos `cost` de durabilidade?
---@param holder number|string
---@param item string
---@param cost number 0 a 100; 0 só exige posse
---@return boolean ok
---@return string? errorCode `not_enough_items` | `low_durability` | validação | provider
function BGRZ.HasItemDurability(holder, item, cost)
    local valid, validationError = validateDurabilityArguments(holder, item, cost)
    if not valid then return false, validationError end
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return false, 'provider_unavailable' end

    local slot, _, err = findDurableSlot(provider, holder, item, cost)
    if not slot then return false, err end
    return true
end

---Gasta `cost` de durabilidade do primeiro slot do item que aguenta o gasto.
---@param holder number|string
---@param item string
---@param cost number 0 a 100; 0 só confere posse e não mexe no slot
---@return boolean ok
---@return string? errorCode
---@return number? remaining durabilidade que sobrou no slot usado
function BGRZ.ConsumeItemDurability(holder, item, cost)
    local valid, validationError = validateDurabilityArguments(holder, item, cost)
    if not valid then return false, validationError end
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return false, 'provider_unavailable' end

    local slot, durability, err = findDurableSlot(provider, holder, item, cost)
    if not slot then return false, err end
    if cost == 0 then return true, nil, durability end

    local remaining = durability - cost
    local called = pcall(function()
        exports[provider]:SetDurability(holder, slot, remaining)
    end)
    if not called then return false, 'provider_unavailable' end
    return true, nil, remaining
end

exports('GetItemList', BGRZ.GetItemList)
exports('HasItemDurability', BGRZ.HasItemDurability)
exports('ConsumeItemDurability', BGRZ.ConsumeItemDurability)
exports('GetItemLabel', BGRZ.GetItemLabel)
exports('AddItem', BGRZ.AddItem)
exports('RemoveItem', BGRZ.RemoveItem)
exports('GetItemCount', BGRZ.GetItemCount)
exports('CanCarryItem', BGRZ.CanCarryItem)
