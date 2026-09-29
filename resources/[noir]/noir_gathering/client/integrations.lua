---Único ponto do client que conhece outro resource pelo nome.
---
---Notificação, login, job e gang passam pelo `bgrz_core` (§2.1). O alvo fala com o
---`ox_target` direto (§2.5), e as teclas visíveis vêm do `noir_lib`.

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

---Alvo pelo `ox_target` direto (§2.5). As options já vêm com o namespace do resource.
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

---Alvo numa entidade local (NPC do início).
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

---Alvo em todo veículo de um model: o da rota, entregue por ela ou trazido pelo jogador.
---Quem confere que é o veículo da corrida é o servidor.
---@param model string
---@param options table[]
function Integrations.addModelTarget(model, options)
    if GetResourceState(TARGET) ~= 'started' then return end
    pcall(function() exports[TARGET]:addModel(joaat(model), options) end)
end

---@param model string
---@param names string[]
function Integrations.removeModelTarget(model, names)
    if GetResourceState(TARGET) ~= 'started' then return end
    pcall(function() exports[TARGET]:removeModel(joaat(model), names) end)
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
