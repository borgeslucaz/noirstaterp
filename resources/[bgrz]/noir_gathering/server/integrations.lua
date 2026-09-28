---Único ponto do servidor que conhece outro resource pelo nome. Tudo passa pelo
---`bgrz_core` (§2.1); com a ponte fora do ar, a ação é recusada.

local Config = require 'config.server'

local CORE = 'bgrz_core'

local Integrations = {}

---@return boolean
function Integrations.coreReady()
    return GetResourceState(CORE) == 'started'
end

local coreReady = Integrations.coreReady

---@param source number
---@param message string
---@param kind? 'inform'|'success'|'error'
function Integrations.notify(source, message, kind)
    if not coreReady() then return end
    exports[CORE]:Notify(source, message, kind or 'inform')
end

---Personagem carregado?
---@param source number
---@return boolean
function Integrations.isLoaded(source)
    if not coreReady() then return false end
    return exports[CORE]:GetCitizenId(source) ~= nil
end

---Job primário ou qualquer gang do personagem com cargo mínimo.
---@param source number
---@param groups table<string, integer>
---@return boolean
function Integrations.hasGroupAccess(source, groups)
    if not coreReady() then return false end
    return exports[CORE]:HasGroupAccess(source, groups) == true
end

---@return { name: string, label: string }[]
function Integrations.itemList()
    if not coreReady() then return {} end
    return exports[CORE]:GetItemList() or {}
end

---@return { name: string, label: string }[]
function Integrations.jobList()
    if not coreReady() then return {} end
    local list = {}
    for _, job in ipairs(exports[CORE]:GetJobList() or {}) do
        list[#list + 1] = { name = job.name, label = job.label }
    end
    return list
end

---@return { name: string, label: string }[]
function Integrations.gangList()
    if not coreReady() then return {} end
    return exports[CORE]:GetGangList() or {}
end

---@param item string
---@return string
function Integrations.itemLabel(item)
    if not coreReady() then return item end
    local label = exports[CORE]:GetItemLabel(item)
    return type(label) == 'string' and label or item
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
---@param cost integer
---@return boolean ok
---@return string? errorCode
function Integrations.hasTool(source, item, cost)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:HasItemDurability(source, item, cost)
end

---@param source number
---@param item string
---@param cost integer
---@return boolean ok
---@return string? errorCode
function Integrations.useTool(source, item, cost)
    if not coreReady() then return false, 'provider_unavailable' end
    local ok, err = exports[CORE]:ConsumeItemDurability(source, item, cost)
    return ok == true, err
end

---Soma stress, preso entre 0 e o teto. O Qbox replica o valor no state bag do
---jogador, que é de onde a HUD lê.
---@param source number
---@param amount integer
---@param ceiling integer
function Integrations.addStress(source, amount, ceiling)
    if amount <= 0 or not coreReady() then return end
    local current = tonumber(exports[CORE]:GetMetadata(source, 'stress')) or 0
    exports[CORE]:SetMetadata(source, 'stress', math.max(0, math.min(ceiling, current + amount)))
end

---Alerta policial. `coords` sai do servidor, nunca do client.
---@param coords vector3
---@param title string
---@param message string
---@return boolean
function Integrations.dispatch(coords, title, message)
    if not coreReady() then return false end
    local ok = exports[CORE]:SendDispatch({
        title = title,
        message = message,
        coords = coords,
        code = Config.dispatch.code,
        jobs = Config.dispatch.jobs,
        duration = Config.dispatch.duration,
        priority = Config.dispatch.priority,
    })
    return ok == true
end

return Integrations
