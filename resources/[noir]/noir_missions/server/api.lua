---API para outros resources (§52 do pedido).
---
---    exports.noir_missions:startMission('meth_elysian_precursors', { leaderSource, ... })
---    exports.noir_missions:offerMission('meth_elysian_precursors', source)
---
---Eventos locais do servidor (AddEventHandler):
---    noir_missions:missionStarted   (instanceId, missionId, participants)
---    noir_missions:stepStarted      (instanceId, missionId, stepId)
---    noir_missions:stepCompleted    (instanceId, missionId, stepId)
---    noir_missions:cargoCollected   (instanceId, missionId, cargoId, source)
---    noir_missions:alarmTriggered   (instanceId, missionId)
---    noir_missions:missionCompleted (instanceId, missionId, participants, reason)
---    noir_missions:missionFailed    (instanceId, missionId, participants, reason)
---    noir_missions:event            (instanceId, missionId, eventName, payload) — todos os eventos
local Utils = require 'shared.utils.core'
local Runtime = require 'server.instances.runtime'
local Starter = require 'server.instances.starter'
local Offers = require 'server.offers'

---Começa uma missão publicada. O primeiro da lista é o líder.
---@param missionId string
---@param participants integer[]
---@return integer? instanceId
---@return string? code
exports('startMission', function(missionId, participants)
    if not Utils.isId(missionId) or type(participants) ~= 'table' or type(participants[1]) ~= 'number' then
        return nil, 'invalid_id'
    end
    local inst, code = Starter.start(missionId, {
        source = participants[1], participants = participants, origin = GetInvokingResource() or 'export',
    })
    return inst and inst.id or nil, code
end)

---Liga para o jogador oferecendo a missão (ACEITAR/RECUSAR).
---@param missionId string
---@param source integer
---@return boolean ok
---@return string? code
exports('offerMission', function(missionId, source)
    if not Utils.isId(missionId) then return false, 'invalid_id' end
    return Offers.offer(missionId, source)
end)

---@param source integer
---@return integer? instanceId
exports('getPlayerInstance', function(source)
    local inst = Runtime.forPlayer(source)
    return inst and inst.id or nil
end)

---@param instanceId integer
---@return table? summary
exports('getInstance', function(instanceId)
    local inst = Runtime.get(instanceId)
    if not inst then return nil end
    return {
        instanceId = inst.id, missionId = inst.missionId, status = inst.status,
        step = inst.step and inst.step.id or nil, participants = Runtime.participantList(inst),
        vars = Utils.deepCopy(inst.vars),
    }
end)

---Variável da execução, vinda de fora (evento de outro sistema). Dispara `var_changed`.
---@param instanceId integer
---@param name string
---@param value any
---@return boolean
exports('setVariable', function(instanceId, name, value)
    local inst = Runtime.get(instanceId)
    if not Runtime.isActive(inst) or type(name) ~= 'string' then return false end
    Runtime.setVar(inst, name, value, { actor = nil })
    return true
end)

---@param instanceId integer
---@param reason? string
---@return boolean
exports('endMission', function(instanceId, reason)
    local inst = Runtime.get(instanceId)
    if not inst then return false end
    Runtime.finish(inst, 'CANCELLED', type(reason) == 'string' and reason or 'export')
    return true
end)

-- Eventos nomeados a partir do evento genérico do runtime.
AddEventHandler('noir_missions:event', function(instanceId, missionId, name, payload)
    if name == 'step_started' then
        TriggerEvent('noir_missions:stepStarted', instanceId, missionId, payload.step)
    elseif name == 'step_completed' then
        TriggerEvent('noir_missions:stepCompleted', instanceId, missionId, payload.step)
    elseif name == 'cargo_picked' then
        TriggerEvent('noir_missions:cargoCollected', instanceId, missionId, payload.cargo, payload.actor)
    elseif name == 'var_changed' and payload.var == 'alarm_active' then
        local inst = Runtime.get(instanceId)
        if inst and inst.vars.alarm_active == true then
            TriggerEvent('noir_missions:alarmTriggered', instanceId, missionId)
        end
    end
end)
