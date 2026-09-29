---Único ponto do servidor que conhece outro resource pelo nome. Tudo do Qbox e do
---inventário passa pelo `bgrz_core` (§2.1); com a ponte fora do ar, a ação é recusada.

local Rules = require 'shared.rules'

local CORE = 'bgrz_core'

local Integrations = {}

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

---@param source number
---@param message string
---@param kind? 'inform'|'success'|'error'
function Integrations.notify(source, message, kind)
    if not coreReady() then return end
    exports[CORE]:Notify(source, message, kind or 'inform')
end

---@param source number
---@return string? citizenId
function Integrations.citizenId(source)
    if not coreReady() then return nil end
    return exports[CORE]:GetCitizenId(source)
end

---@param source number
---@param jobs table<string, boolean>
---@param requireDuty boolean
---@return boolean
function Integrations.hasAnyJob(source, jobs, requireDuty)
    if not coreReady() then return false end
    for name in pairs(jobs) do
        if exports[CORE]:HasJob(source, name, requireDuty) then return true end
    end
    return false
end

---@param source number
---@param item string
---@return integer
function Integrations.count(source, item)
    if not coreReady() then return 0 end
    return tonumber(exports[CORE]:GetItemCount(source, item)) or 0
end

---@param source number
---@param item string
---@param amount integer
---@return boolean
function Integrations.canCarry(source, item, amount)
    if not coreReady() then return false end
    return exports[CORE]:CanCarryItem(source, item, amount) == true
end

---Validade de cada item em minutos (false = sem validade), lida uma vez da ponte.
---O `items.lua` do inventário continua sendo o único lugar onde ela é definida.
local degradeOf = {}

---Metadata com a validade arredondada para a hora cheia: o que sai no mesmo lote empilha.
---@param item string
---@return table?
local function expiryMetadata(item)
    local degrade = degradeOf[item]
    if degrade == nil then
        local minutes, err = exports[CORE]:GetItemDegrade(item)
        if err then return nil end -- não cacheia falha: tenta de novo na próxima
        degrade = minutes or false
        degradeOf[item] = degrade
    end
    if not degrade then return nil end
    return { durability = Rules.expiry(os.time(), degrade, 3600), degrade = degrade }
end

---@param source number
---@param item string
---@param amount integer
---@return boolean ok
---@return string? errorCode
function Integrations.addItem(source, item, amount)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:AddItem(source, item, amount, expiryMetadata(item))
end

---@param source number
---@param item string
---@param amount integer
---@return boolean ok
---@return string? errorCode
function Integrations.removeItem(source, item, amount)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:RemoveItem(source, item, amount)
end

---O holder tem o item com pelo menos `cost` de durabilidade?
---@param source number
---@param item string
---@param cost number
---@return boolean ok
---@return string? errorCode `not_enough_items` | `low_durability` | ...
function Integrations.hasDurability(source, item, cost)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:HasItemDurability(source, item, cost)
end

---@param source number
---@param item string
---@param cost number
---@return boolean ok
---@return string? errorCode
function Integrations.useDurability(source, item, cost)
    if not coreReady() then return false, 'provider_unavailable' end
    local ok, err = exports[CORE]:ConsumeItemDurability(source, item, cost)
    return ok == true, err
end

return Integrations
