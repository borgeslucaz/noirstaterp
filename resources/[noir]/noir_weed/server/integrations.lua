---Único ponto do servidor que conhece outro resource pelo nome. Tudo do Qbox e do
---inventário passa pelo `bgrz_core` (§2.1); com a ponte fora do ar, a ação é recusada.

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

---@param source number
---@param item string
---@param amount integer
---@return boolean ok
---@return string? errorCode
function Integrations.addItem(source, item, amount)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:AddItem(source, item, amount)
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

return Integrations
