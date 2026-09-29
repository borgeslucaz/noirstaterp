---Registro das ações e o fluxo begin/finish que todas usam.
---
---O `begin` valida e anota a hora; o `finish` confere que a duração da animação passou
---(§17.4), valida tudo de novo — o mundo pode ter mudado nesses segundos — e só então
---mexe em item, planta ou mesa.
---
---Cada ação registrada tem:
---  check(source, citizenId, payload, extra?) -> ok, code?, context   (begin e finish)
---  apply(source, citizenId, context, extra?, elapsedMs) -> ok, code?, result    (só no finish)
---  duration?(payload) -> ms   quando não é a de `Shared.durations[nome]`
---`extra` é o que o client manda no finish (o lugar novo, ao mover; quantos embalou).

local Shared = require 'config.shared'
local Config = require 'config.server'
local Integrations = require 'server.integrations'

local Actions = { ready = false }

local registry = {}
---[source] = { action, payload, startedAt, duration }
local pending = {}
---[source] = instante em que o próximo pedido passa
local nextAllowed = {}

---Ações em que o jogador escolhe um lugar ou joga um minigame depois do begin ganham
---mais prazo.
local SLOW = { move = true, pack = true }

---@param name string
---@param def table
function Actions.register(name, def)
    registry[name] = def
end

---@param source number
---@return boolean
local function rateLimit(source)
    local now = GetGameTimer()
    if (nextAllowed[source] or 0) > now then return false end
    nextAllowed[source] = now + Config.rateLimitMs
    return true
end

lib.callback.register('noir_weed:server:begin', function(source, action, payload)
    local def = type(action) == 'string' and registry[action] or nil
    if not def or not Actions.ready then return { ok = false, code = 'invalid_request' } end
    if not rateLimit(source) then return { ok = false, code = 'rate_limited' } end
    -- Ação anterior que nunca terminou (client caiu no meio sem desconectar) deixa de
    -- travar depois de um tempo.
    local previous = pending[source]
    local grace = previous and (SLOW[previous.action] and 300000 or 15000)
    if previous and GetGameTimer() - previous.startedAt < previous.duration + grace then
        return { ok = false, code = 'busy' }
    end

    local citizenId = Integrations.citizenId(source)
    if not citizenId then return { ok = false, code = 'not_loaded' } end

    local ok, code = def.check(source, citizenId, payload)
    if not ok then return { ok = false, code = code } end

    local duration = def.duration and def.duration(payload) or Shared.durations[action] or 0
    pending[source] = {
        action = action,
        payload = payload,
        startedAt = GetGameTimer(),
        duration = duration,
    }
    return { ok = true, duration = duration }
end)

lib.callback.register('noir_weed:server:finish', function(source, action, extra)
    local session = pending[source]
    pending[source] = nil
    if not session or session.action ~= action then return { ok = false, code = 'invalid_request' } end
    local def = registry[action]
    local elapsed = GetGameTimer() - session.startedAt
    if elapsed < session.duration - Config.durationSlackMs then
        return { ok = false, code = 'too_fast' }
    end

    local citizenId = Integrations.citizenId(source)
    if not citizenId then return { ok = false, code = 'not_loaded' } end

    local ok, code, context = def.check(source, citizenId, session.payload, extra)
    if not ok then return { ok = false, code = code } end

    local applied, applyCode, result = def.apply(source, citizenId, context, extra, elapsed)
    if not applied then return { ok = false, code = applyCode } end
    return { ok = true, result = result }
end)

RegisterNetEvent('noir_weed:server:cancel', function()
    pending[source] = nil
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
    nextAllowed[source] = nil
end)

return Actions
