---Único ponto do client que conhece outro resource pelo nome.
---
---Notificação, login e job passam pelo `bgrz_core` (§2.1). O alvo fala com o
---`ox_target` direto (§2.5).

local CORE = 'bgrz_core'
local TARGET = 'ox_target'

local Integrations = {}

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

---@param message string
---@param kind? 'inform'|'success'|'error'
function Integrations.notify(message, kind)
    if not coreReady() then return end
    exports[CORE]:Notify(message, kind or 'inform')
end

---@return boolean
function Integrations.isLoggedIn()
    return coreReady() and exports[CORE]:IsLoggedIn() == true
end

---Só para decidir o que MOSTRAR. Quem autoriza é o servidor.
---@param jobs table<string, boolean>
---@return boolean
function Integrations.onDutyIn(jobs)
    if not coreReady() then return false end
    local job = exports[CORE]:GetJob()
    return job ~= nil and jobs[job.name] == true and job.onDuty == true
end

---@param entity integer
---@param options table[]
function Integrations.addEntityTarget(entity, options)
    if GetResourceState(TARGET) ~= 'started' then return end
    pcall(function() exports[TARGET]:addLocalEntity(entity, options) end)
end

---@param entity integer
function Integrations.removeEntityTarget(entity)
    if GetResourceState(TARGET) ~= 'started' then return end
    pcall(function() exports[TARGET]:removeLocalEntity(entity) end)
end

return Integrations
