---Único ponto do client que conhece outro resource pelo nome.
---
---Notificação passa pelo `bgrz_core` (§2.1). O alvo fala com o `ox_target` direto (§2.5), as
---teclas visíveis dos modos do editor vêm do `noir_lib` e os tiles do mapa de debug, do
---`noir_territories`.

local CORE = 'bgrz_core'
local TARGET = 'ox_target'
local KEYS = 'noir_lib'
local TERRITORIES = 'noir_territories'

local Integrations = {}

---@param message string
---@param kind? 'inform'|'success'|'warning'|'error'
function Integrations.notify(message, kind)
    if GetResourceState(CORE) ~= 'started' then return end
    exports[CORE]:Notify(message, kind or 'inform')
end

---Alvo na entidade local do atendente.
---@param entity integer
---@param options table[]
function Integrations.addEntityTarget(entity, options)
    if GetResourceState(TARGET) ~= 'started' then return end
    pcall(function() exports[TARGET]:addLocalEntity(entity, options) end)
end

---@param entity integer
---@param names string|string[]
function Integrations.removeEntityTarget(entity, names)
    if GetResourceState(TARGET) ~= 'started' then return end
    pcall(function() exports[TARGET]:removeLocalEntity(entity, names) end)
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

---Projeção e tiles do mapa do GTA, do /territorymap: o caminho `nui://noir_territories/...`
---e as constantes da pirâmide andam juntos lá. Nil com o resource fora do ar.
---@return table?
function Integrations.territoryMap()
    if GetResourceState(TERRITORIES) ~= 'started' then return nil end
    local ok, result = pcall(function() return exports[TERRITORIES]:GetTerritoryMap() end)
    return ok and type(result) == 'table' and result.map or nil
end

return Integrations
