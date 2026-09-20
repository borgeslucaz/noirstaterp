---Único ponto do client que conhece outro resource pelo nome.
---
---Quase tudo passa pelo `bgrz_core`, como manda o §2.1 do
---SCRIPT_GOOD_PRACTICES: notificação, login e target de entidade.
---
---**A exceção é o target por MODEL**, que fala com o `ox_target` direto, por
---decisão do dono do servidor. O ponto de manter a exceção NESTE arquivo é que
---ele continua sendo o único lugar do client que cita outro resource pelo nome:
---a regra e a exceção moram juntas, e trocar de provider de target continua
---sendo mexer em um arquivo só.

local Utils = require 'shared.utils'

local DebugPrint = Utils.debugPrint('integrations')

local CORE = 'bgrz_core'
local TARGET = 'ox_target'

local Integrations = {}

---@return boolean
local function coreReady()
    return GetResourceState(CORE) == 'started'
end

---@param message string
---@param kind? 'inform'|'success'|'error'
function Integrations.notify(message, kind)
    if not coreReady() then
        DebugPrint('bgrz_core não está started; notificação descartada')
        return
    end
    exports[CORE]:Notify(message, kind or 'inform')
end

---@return boolean
function Integrations.isLoggedIn()
    if not coreReady() then return false end
    return exports[CORE]:IsLoggedIn() == true
end

---Target em uma entidade DE REDE (o veículo), filtrado por osso.
---
---É onde os alvos do smash & grab moram: o raycast do ox_target acerta a carroceria
---antes de alcançar o prop dentro do carro, então a opção tem que estar no veículo.
---@param netId number
---@param options table[]
---@return boolean ok
---@return string? errorCode
function Integrations.addEntityTarget(netId, options)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:AddEntityTarget(netId, options)
end

---@param netId number
---@param names string|string[]
function Integrations.removeEntityTarget(netId, names)
    if not coreReady() then return end
    exports[CORE]:RemoveEntityTarget(netId, names)
end

---Target em todo objeto de um MODEL, incluindo os que vêm do mapa.
---
---É o que o parquímetro usa, e é o que ele PRECISA usar: prop de mapa não tem
---netId nem handle estável, então não há entidade para passar às duas funções
---acima. Registrando por model, o alvo vale também para os postes que o streaming
---trouxer depois — sem thread de varredura nenhuma.
---@param models string|string[]
---@param options table[]
---@return boolean ok
---@return string? errorCode
---**Esta é a única chamada do resource que NÃO passa pelo `bgrz_core`**, por
---decisão do dono do servidor. É exceção consciente ao §2.1, e está escrita aqui
---em vez de escondida dentro do módulo do crime de propósito: quem for auditar
---encontra a exceção no mesmo arquivo em que encontraria a regra.
---
---Duas consequências práticas de chamar direto:
---
---  * o `GetInvokingResource()` que o ox_target enxerga passa a ser
---    `noir_prettycrimes`, então o cleanup no stop é NATIVO dele
---    (`api.lua`, `onClientResourceStop`) e não depende mais da contabilidade
---    de posse do bridge;
---  * o namespace da option passa a ser por nossa conta. O bridge prefixava com
---    o nome do caller; aqui `OPTION_ROB` já nasce como
---    `noir_prettycrimes:parkingmeter:rob`, que cumpre o mesmo papel.
function Integrations.addModelTarget(models, options)
    if GetResourceState(TARGET) ~= 'started' then
        DebugPrint('ox_target não está started; alvo por model não registrado')
        return false, 'provider_unavailable'
    end

    local called, err = pcall(function()
        exports[TARGET]:addModel(models, options)
    end)
    if not called then return false, tostring(err) end

    return true
end

-- ---------------------------------------------------------------------------
-- Sondas, para o diagnóstico
-- ---------------------------------------------------------------------------
--
-- Existem para que o `/meterdiag` possa relatar o estado da cadeia sem citar
-- `bgrz_core` nem `ox_target` pelo nome. Sem elas, o diagnóstico virava o
-- segundo arquivo do client a conhecer outro resource — justamente o arquivo
-- que existe para explicar quando essa fiação quebra.

---@return string
function Integrations.coreState()
    return GetResourceState(CORE)
end

---@return string
function Integrations.targetState()
    return GetResourceState(TARGET)
end

---O provider de target expõe mesmo a API por model?
---
---Pergunta ao runtime em vez de deduzir pelo sintoma: uma versão antiga do
---ox_target sem `addModel` falharia igualzinho a um ox_target parado.
---@return boolean
function Integrations.hasModelTarget()
    if GetResourceState(TARGET) ~= 'started' then return false end
    local ok, api = pcall(function() return exports[TARGET].addModel end)
    return ok and api ~= nil
end

---@param models string|string[]
---@param names string|string[]
function Integrations.removeModelTarget(models, names)
    if GetResourceState(TARGET) ~= 'started' then return end
    -- Silencioso de propósito: isto roda no stop, onde não há mais nada a fazer
    -- com a falha além de não atrapalhar o resto do stop.
    pcall(function()
        exports[TARGET]:removeModel(models, names)
    end)
end


return Integrations
