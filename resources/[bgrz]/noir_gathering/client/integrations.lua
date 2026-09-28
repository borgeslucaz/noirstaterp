---Único ponto do client que conhece outro resource pelo nome.
---
---Notificação, login, job, gang e alvo passam pelo `bgrz_core` (§2.1); as teclas
---visíveis vêm do `noir_lib`.

local CORE = 'bgrz_core'
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

---O bridge dá nome próprio por resource às zonas e opções, e limpa tudo sozinho quando
---este resource para.
---@param data { name: string, coords: vector3, radius: number, options: table[] }
---@return string? zoneName
function Integrations.addZone(data)
    if not coreReady() then return nil end
    local called, ok = pcall(function()
        return exports[CORE]:AddSphereZoneTarget({
            name = data.name,
            coords = data.coords,
            radius = data.radius,
            options = data.options,
        })
    end)
    return (called and ok) and data.name or nil
end

---@param name string?
function Integrations.removeZone(name)
    if not name or not coreReady() then return end
    pcall(function() exports[CORE]:RemoveZoneTarget(name) end)
end

---Alvo numa entidade local (NPC do início, pilha de caixas).
---@param entity integer
---@param options table[]
function Integrations.addEntityTarget(entity, options)
    if not coreReady() then return end
    pcall(function() exports[CORE]:AddLocalEntityTarget(entity, options) end)
end

---@param entity integer
function Integrations.removeEntityTarget(entity)
    if not coreReady() then return end
    pcall(function() exports[CORE]:RemoveLocalEntityTarget(entity) end)
end

---Alvo em todo veículo de um model: o da rota, entregue por ela ou trazido pelo jogador.
---Quem confere que é o veículo da corrida é o servidor.
---@param model string
---@param options table[]
function Integrations.addModelTarget(model, options)
    if not coreReady() then return end
    pcall(function() exports[CORE]:AddModelTarget(model, options) end)
end

---@param model string
---@param names string[]
function Integrations.removeModelTarget(model, names)
    if not coreReady() then return end
    pcall(function() exports[CORE]:RemoveModelTarget(model, names) end)
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
