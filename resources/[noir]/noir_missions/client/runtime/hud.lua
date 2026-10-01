---HUD da missão (objetivo discreto), cartão de informação revelada e oferta (ligação).
local ClientConfig = require 'config.client'
local Nui = require 'client.runtime.nui'
local State = require 'client.runtime.state'
local Integrations = require 'client.integrations'

local Hud = {}

local currentOffer = nil ---@type string?

---@param view table?
function Hud.objective(view)
    if not view or not view.objective then
        Nui.send('hud:objective', { visible = false })
        return
    end
    local objective = view.objective
    Nui.send('hud:objective', {
        visible = objective.visible == true,
        title = objective.title or view.title,
        text = objective.text,
        progress = objective.progress,
        timer = objective.timer,
    })
end

---@param payload { title: string, lines: table[] }
function Hud.info(payload)
    Nui.send('hud:info', { title = payload.title, lines = payload.lines, seconds = ClientConfig.hud.infoSeconds })
end

---@param payload table
function Hud.offer(payload)
    currentOffer = payload.offerId
    Nui.send('hud:offer', payload)
    Nui.focus('offer', true)
end

---@param offerId string?
function Hud.closeOffer(offerId)
    if offerId and currentOffer ~= offerId then return end
    currentOffer = nil
    Nui.send('hud:offerClose', { offerId = offerId })
    Nui.focus('offer', false)
end

function Hud.reset()
    currentOffer = nil
    Nui.send('hud:reset')
    Nui.focus('offer', false)
end

local CODES = {
    cooldown = 'Esse trabalho não está disponível agora.',
    gang_required = 'Esse trabalho é só para gang.',
    gang_grade = 'Seu cargo na gang não pode aceitar isso.',
    not_enough_players = 'Precisa de mais gente da gang por perto.',
    busy = 'Você já está em outro trabalho.',
    max_instances = 'Muita coisa acontecendo na cidade. Tente mais tarde.',
    expired = 'A ligação caiu.',
    mission_disabled = 'Esse trabalho não está disponível.',
}

RegisterNUICallback('offerAnswer', function(data, cb)
    local offerId = type(data) == 'table' and data.offerId or nil
    local accept = type(data) == 'table' and data.accept == true
    Hud.closeOffer(offerId)
    if type(offerId) ~= 'string' then
        cb({ ok = false, code = 'invalid_id' })
        return
    end
    local result = lib.callback.await('noir_missions:server:offerAnswer', false, offerId, accept)
    if result and not result.ok and accept then
        Integrations.notify(CODES[result.code] or 'Não deu para aceitar.', 'error')
    end
    cb(result or { ok = false, code = 'internal_error' })
end)

RegisterNUICallback('infoClose', function(_, cb)
    cb({ ok = true })
end)

Nui.onReady(function()
    Hud.objective(State.view)
end)

Hud.CODES = CODES
return Hud
