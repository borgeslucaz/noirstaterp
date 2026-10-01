---Executa uma interação de missão: pede ao servidor, barra de progresso com animação,
---minigame, e devolve o resultado. Quem decide se valeu é o servidor (tempo e distância).
local SharedConfig = require 'config.shared'
local Integrations = require 'client.integrations'

local Interact = {}

local busy = false

local MESSAGES = {
    busy = 'Alguém já está mexendo nisso.',
    too_far = 'Chegue mais perto.',
    missing_item = 'Falta o que precisa para isso.',
    too_fast = 'Rápido demais. Tente de novo.',
    expired = 'A interação expirou.',
    not_found = 'Não dá mais para fazer isso.',
    rate_limited = 'Calma.',
}

---@param code string?
local function fail(code)
    Integrations.notify(MESSAGES[code] or 'Não deu certo.', 'error')
end

---Animação só se o dicionário existe neste build (Enhanced derruba o cliente sem ele).
---@param kind string
---@return table?
local function animFor(kind)
    local anim = SharedConfig.interactionAnims[kind]
    if not anim or not DoesAnimDictExist(anim.dict) then return nil end
    return { dict = anim.dict, clip = anim.clip, flag = anim.flag }
end

---@param instanceId integer
---@param interactionId string
function Interact.run(instanceId, interactionId)
    if busy then return end
    busy = true

    local begin = lib.callback.await('noir_missions:server:interactBegin', false, instanceId, interactionId)
    if not begin or not begin.ok then
        busy = false
        return fail(begin and begin.code)
    end

    local completed = true
    if (begin.duration or 0) > 0 then
        completed = lib.progressBar({
            duration = begin.duration * 1000,
            label = begin.label,
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = animFor(begin.kind),
        })
    end

    if not completed then
        lib.callback.await('noir_missions:server:interactFinish', false, instanceId, interactionId, nil)
        busy = false
        return
    end

    local passed = true
    if begin.minigame then passed = Integrations.playMinigame(begin.minigame, begin.difficulty or 2) end

    local result = lib.callback.await('noir_missions:server:interactFinish', false, instanceId, interactionId, passed)
    busy = false
    if not result or not result.ok then return fail(result and result.code) end
    if not result.passed then Integrations.notify('Falhou.', 'error') end
end

return Interact
