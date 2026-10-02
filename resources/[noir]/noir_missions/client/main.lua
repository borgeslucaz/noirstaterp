---Entrada do cliente: liga os módulos aos eventos do servidor e cuida do ciclo de vida.
local SharedConfig = require 'config.shared'
local Integrations = require 'client.integrations'
local State = require 'client.runtime.state'
local Nui = require 'client.runtime.nui'
local Hud = require 'client.runtime.hud'
local Blips = require 'client.runtime.blips'
local Shots = require 'client.runtime.shots'
local Markers = require 'client.runtime.markers'
local Starters = require 'client.runtime.starters'
local Targets = require 'client.interactions.targets'
local Carry = require 'client.cargo.carry'
local Registry = require 'client.entities.registry'
local Ai = require 'client.npc.ai'
local Editor = require 'client.editor.editor'
local Debug = require 'client.editor.debug'
require 'client.chase.spawn'

Ai.setupRelationships()

State.onChange(function(view)
    Hud.objective(view)
    Blips.sync(view and view.blips or nil)
    Targets.sync(view)
    if view then
        Shots.start()
        Markers.start()
    end
end)

local ENDED = {
    COMPLETED = { 'Missão concluída: %s', 'success' },
    FAILED = { 'Missão falhou: %s', 'error' },
    CANCELLED = { 'Missão encerrada: %s', 'inform' },
    LEFT = { 'Você saiu da missão: %s', 'inform' },
}

local REASONS = {
    time_limit = 'o tempo acabou.',
    vehicle_destroyed = 'o veículo foi destruído.',
    abandoned = 'todos saíram.',
}

RegisterNetEvent('noir_missions:client:sync', function(view)
    if source ~= 65535 or type(view) ~= 'table' then return end
    local first = State.view == nil or State.view.instanceId ~= view.instanceId
    State.set(view)
    if first then Carry.scan() end
end)

RegisterNetEvent('noir_missions:client:ended', function(payload)
    if source ~= 65535 or type(payload) ~= 'table' then return end
    if State.view and State.view.instanceId ~= payload.instanceId then return end
    State.set(nil)
    Hud.reset()
    local message = ENDED[payload.status] or ENDED.CANCELLED
    local text = message[1]:format(payload.title or '')
    if payload.status == 'FAILED' and REASONS[payload.reason] then
        text = ('Missão falhou: %s'):format(REASONS[payload.reason])
    end
    Integrations.notify(text, message[2])
end)

RegisterNetEvent('noir_missions:client:info', function(payload)
    if source ~= 65535 or type(payload) ~= 'table' then return end
    Hud.info(payload)
end)

RegisterNetEvent('noir_missions:client:offer', function(payload)
    if source ~= 65535 or type(payload) ~= 'table' then return end
    Hud.offer(payload)
end)

RegisterNetEvent('noir_missions:client:offerClose', function(offerId)
    if source ~= 65535 then return end
    Hud.closeOffer(offerId)
end)

RegisterNetEvent('noir_missions:client:sound', function(name, set)
    if source ~= 65535 or type(name) ~= 'string' then return end
    PlaySoundFrontend(-1, name, type(set) == 'string' and set or nil, true)
end)

RegisterNetEvent('noir_missions:client:pedSay', function(netId, texts, tone)
    if source ~= 65535 or type(texts) ~= 'table' or #texts == 0 then return end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local ped = NetworkGetEntityFromNetworkId(netId)
    if ped ~= 0 and DoesEntityExist(ped) then Integrations.pedSay(ped, texts, tone) end
end)

-- Comandos --------------------------------------------------------------------------------

RegisterCommand(SharedConfig.commands.editor, function()
    Editor.open()
end, false)

RegisterCommand(SharedConfig.commands.debug, function()
    Debug.toggleInstance()
end, false)

-- Ciclo de vida ---------------------------------------------------------------------------

local function boot()
    Registry.load()
    Starters.fetch()
    Carry.scan()
end

AddEventHandler('bgrz_core:client:playerLoaded', boot)

AddEventHandler('bgrz_core:client:playerUnloaded', function()
    State.set(nil)
    Hud.reset()
    Starters.clear()
end)

CreateThread(function()
    -- Restart do resource com o jogador já dentro: não vai ter `playerLoaded`.
    if Integrations.isLoggedIn() then boot() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Nui.releaseAll()
    Targets.clear()
    Blips.clear()
    Carry.cleanup()
    Starters.clear()
    Editor.cleanup()
    Integrations.hideKeys()
end)
