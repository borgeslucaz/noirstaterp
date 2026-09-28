---Único ponto do client que conhece outro resource pelo nome.
---
---Notificação, login, job e gang passam pelo `bgrz_core` (§2.1). O alvo fala com o
---`ox_target` direto, pela exceção do §2.5, e as teclas visíveis vêm do `noir_lib`.

local CORE = 'bgrz_core'
local TARGET = 'ox_target'
local KEYS = 'noir_lib'

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

---Só para decidir o que MOSTRAR. Quem libera a rota é o servidor.
---@param groups table<string, integer>
---@return boolean
function Integrations.hasGroup(groups)
    if not coreReady() then return false end
    local job = exports[CORE]:GetJob()
    if job and groups[job.name] and (job.grade or 0) >= groups[job.name] then return true end
    local gang = exports[CORE]:GetGang()
    if gang and groups[gang.name] and (gang.grade or 0) >= groups[gang.name] then return true end
    return false
end

---@param data { name: string, coords: vector3, radius: number, options: table[] }
---@return integer? zoneId
function Integrations.addZone(data)
    if GetResourceState(TARGET) ~= 'started' then return nil end
    local ok, id = pcall(function()
        return exports[TARGET]:addSphereZone({
            name = data.name,
            coords = data.coords,
            radius = data.radius,
            options = data.options,
        })
    end)
    return ok and id or nil
end

---@param id integer?
function Integrations.removeZone(id)
    if not id or GetResourceState(TARGET) ~= 'started' then return end
    pcall(function() exports[TARGET]:removeZone(id) end)
end

---@param keys { key: string, label: string }[]
function Integrations.showKeys(keys)
    if GetResourceState(KEYS) ~= 'started' then return end
    exports[KEYS]:ShowKeyHints({ position = 'baixo', keys = keys })
end

function Integrations.hideKeys()
    if GetResourceState(KEYS) ~= 'started' then return end
    exports[KEYS]:HideKeyHints()
end

return Integrations
