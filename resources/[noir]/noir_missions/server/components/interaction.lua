---Interações: computador para hackear, gaveta para revistar, painel genérico.
---Passo "Interação".
---
---Fluxo, com o servidor medindo tudo (§17.4):
---  1. cliente pede `interactBegin`: o servidor confere participante, revelada, não feita, livre,
---     distância e item; reserva para quem pediu e anota o instante;
---  2. cliente roda barra de progresso + minigame e manda `interactFinish` com o resultado;
---  3. o servidor confere que é a mesma reserva, que passou o tempo mínimo e que a pessoa ainda
---     está perto, e só então aplica sucesso ou falha.
---O resultado do minigame é do cliente; o que o servidor garante é que ninguém pula a etapa.
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Flow = require 'server.components.flow'
local Config = require 'config.server'

local Interaction = {}

local RESERVATION_SLACK_MS = 90000

---@param inst table
---@param id string
---@return table? def
---@return table? state
local function get(inst, id)
    local def = Utils.findById(inst.def.interactions, id)
    return def, def and inst.interactions[id] or nil
end

---@param inst table
---@param id string
---@param revealed boolean
function Interaction.setRevealed(inst, id, revealed)
    local _, state = get(inst, id)
    if not state or state.revealed == revealed then return end
    state.revealed = revealed
    Runtime.markDirty(inst)
end

MissionComponents.register('interaction', {
    init = function(inst)
        inst.interactions = {}
        for index = 1, #inst.def.interactions do
            local def = inst.def.interactions[index]
            inst.interactions[def.id] = { revealed = def.revealed ~= false, done = false, failed = 0 }
        end
    end,

    start = function(inst)
        for index = 1, #inst.def.interactions do
            local def = inst.def.interactions[index]
            if def.model then
                inst.interactions[def.id].prop = World.createObject(inst, 'interaction:' .. def.id, def.model, def.coords, true)
            end
        end
    end,

    view = function(inst, view)
        for index = 1, #inst.def.interactions do
            local def = inst.def.interactions[index]
            local state = inst.interactions[def.id]
            if state.revealed and not state.done then
                view.interactions[#view.interactions + 1] = {
                    id = def.id, label = def.label, kind = def.kind, coords = def.coords,
                    distance = def.distance or 1.5,
                    netId = state.prop and state.prop.netId or nil,
                    busy = state.busyBy ~= nil,
                }
            end
        end
    end,

    resolve = function(inst, parts)
        if parts[1] ~= 'interaction' or #parts ~= 3 or parts[3] ~= 'done' then return false end
        local state = inst.interactions[parts[2]]
        return true, state ~= nil and state.done == true
    end,

    participantLeft = function(inst, source)
        for _, state in pairs(inst.interactions) do
            if state.busyBy == source then state.busyBy = nil end
        end
    end,

    actions = {
        reveal_interaction = function(inst, action) Interaction.setRevealed(inst, action.interaction, true) end,
        hide_interaction = function(inst, action) Interaction.setRevealed(inst, action.interaction, false) end,
    },

    steps = {
        interact = {
            start = function(inst, step)
                Interaction.setRevealed(inst, step.interaction, true)
                local _, state = get(inst, step.interaction)
                -- Já feita antes do passo (por gatilho ou teste pulando passos): conclui.
                if state and state.done then Runtime.completeStep(inst, step) end
            end,
            event = function(inst, step, _, name, payload)
                if payload.interaction ~= step.interaction then return end
                if name == 'interaction_success' or (name == 'interaction_failed' and step.complete == 'any') then
                    Runtime.completeStep(inst, step, { actor = payload.actor })
                end
            end,
            view = function(inst, step, _, view)
                if not step.showBlip then return end
                local def = get(inst, step.interaction)
                if def then
                    view.blips[#view.blips + 1] = {
                        id = 'step:' .. step.id, coords = def.coords, sprite = 521, color = 5, label = def.label,
                    }
                end
            end,
        },
    },
})

lib.callback.register('noir_missions:server:interactBegin', function(source, instanceId, interactionId)
    if not Security.consume(source, 'interact') then return { ok = false, code = 'rate_limited' } end
    if not Security.isInstanceId(instanceId) or not Security.isKey(interactionId) then
        return { ok = false, code = 'invalid_id' }
    end
    local inst = Runtime.get(instanceId)
    if not Runtime.isActive(inst) or not Runtime.isParticipant(inst, source) then
        return { ok = false, code = 'no_instance' }
    end
    local def, state = get(inst, interactionId)
    if not def or not state.revealed or state.done then return { ok = false, code = 'not_found' } end

    local now = Runtime.io.now()
    if state.busyBy and state.busyBy ~= source and (state.busyUntil or 0) > now then
        return { ok = false, code = 'busy' }
    end
    if not Security.isNear(source, def.coords, (def.distance or 1.5) + Config.distances.interactionSlack) then
        return { ok = false, code = 'too_far' }
    end
    if def.requiredItem and Integrations.itemCount(source, def.requiredItem) < 1 then
        return { ok = false, code = 'missing_item', item = def.requiredItem }
    end

    state.busyBy = source
    state.startedAt = now
    state.busyUntil = now + (def.duration or 0) * 1000 + RESERVATION_SLACK_MS
    Runtime.markDirty(inst)
    return {
        ok = true, kind = def.kind, duration = def.duration or 0, label = def.label,
        minigame = def.minigame, difficulty = def.difficulty or 2,
    }
end)

lib.callback.register('noir_missions:server:interactFinish', function(source, instanceId, interactionId, passed)
    if not Security.isInstanceId(instanceId) or not Security.isKey(interactionId) then
        return { ok = false, code = 'invalid_id' }
    end
    local inst = Runtime.get(instanceId)
    if not Runtime.isActive(inst) or not Runtime.isParticipant(inst, source) then
        return { ok = false, code = 'no_instance' }
    end
    local def, state = get(inst, interactionId)
    if not def or state.busyBy ~= source or state.done then return { ok = false, code = 'expired' } end

    -- `passed == nil` é desistência: libera sem contar como falha.
    if passed == nil then
        state.busyBy = nil
        Runtime.markDirty(inst)
        return { ok = true, cancelled = true }
    end

    local elapsed = Runtime.io.now() - (state.startedAt or 0)
    local minimum = (def.duration or 0) * 1000 * Config.minInteractionFraction
    if elapsed < minimum then
        state.busyBy = nil
        Runtime.markDirty(inst)
        lib.print.warn(('[noir_missions] interação %s rápida demais (%d ms de %d) por %s'):format(
            interactionId, elapsed, minimum, source))
        return { ok = false, code = 'too_fast' }
    end
    if not Security.isNear(source, def.coords, (def.distance or 1.5) + Config.distances.interactionSlack + 1.0) then
        state.busyBy = nil
        Runtime.markDirty(inst)
        return { ok = false, code = 'too_far' }
    end

    state.busyBy = nil
    local ctx = { actor = source }
    if passed == true then
        if def.requiredItem and def.consumeItem then
            if not Integrations.removeItem(source, def.requiredItem, 1) then
                Runtime.markDirty(inst)
                return { ok = false, code = 'missing_item', item = def.requiredItem }
            end
        end
        state.done = def.once ~= false
        if def.infoTitle and def.infoTitle ~= '' then Flow.showInfo(inst, def.infoTitle, def.infoLines) end
        Runtime.runActions(inst, def.onSuccess, ctx)
        Runtime.emit(inst, 'interaction_success', { interaction = def.id, actor = source })
    else
        state.failed = state.failed + 1
        if not def.retry then state.done = true end
        Runtime.runActions(inst, def.onFailure, ctx)
        Runtime.emit(inst, 'interaction_failed', { interaction = def.id, actor = source })
    end
    Runtime.markDirty(inst)
    return { ok = true, passed = passed == true }
end)

return Interaction
