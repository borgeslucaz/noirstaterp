-- Tela de morte: abre enquanto o jogador esta caido ou morto e prende mouse e teclado na NUI.
-- Chat, voz, celular e qualquer tecla do jogo ficam fora; so os botoes da tela agem.
local config = require 'config.shared'
local Doctor = require 'client.doctor'

local STATUS_REFRESH = 15000

local isOpen = false
-- Depois do respawn o jogador vai para a cama do hospital ainda com isDead; a tela so volta
-- quando ele levantar e cair de novo.
local suppressed = false
local status = { emsOnDuty = 0, doctorAvailable = false, doctorWait = 0 }
local doctorStage = { stage = 'idle' }
local lastStatusAt = 0

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function shouldShow()
    return LocalPlayer.state.isLoggedIn == true and LocalPlayer.state.isDead == true and not suppressed
end

---@param info { state: string, seconds: integer }?
local function canRespawn(info)
    if not info or info.state ~= 'dead' or Doctor.isActive() then return false end
    return status.emsOnDuty == 0 or info.seconds <= 0
end

local function getDoctorWait()
    local wait = status.doctorWait or 0
    if wait <= 0 then return 0 end
    return math.max(0, wait - math.floor((GetGameTimer() - lastStatusAt) / 1000))
end

local function snapshot()
    local info = exports.bgrz_core:GetDownedInfo()
    -- Com paramedico em servico o medico nao atende de qualquer jeito: sem contagem, que
    -- prometeria um atendimento que nao vem.
    local doctorWait = status.doctorAvailable and getDoctorWait() or 0
    return {
        state = info and info.state or 'laststand',
        seconds = info and info.seconds or 0,
        canRespawn = canRespawn(info),
        emsOnDuty = status.emsOnDuty,
        doctorAvailable = status.doctorAvailable and doctorWait <= 0,
        doctorWait = doctorWait,
        price = config.price,
        reviveTime = config.reviveTime,
        alertCooldown = config.alertCooldown,
        doctor = doctorStage,
    }
end

local function refreshStatus()
    lastStatusAt = GetGameTimer()
    local result = lib.callback.await('noir_handledeath:server:getStatus', false)
    if type(result) == 'table' then status = result end
end

local function holdFocus()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end

local function openScreen()
    isOpen = true
    doctorStage = { stage = Doctor.isActive() and 'enroute' or 'idle' }
    holdFocus()
    send('open', snapshot())

    CreateThread(function()
        refreshStatus()
        while isOpen do
            if GetGameTimer() - lastStatusAt > STATUS_REFRESH then refreshStatus() end
            if not isOpen then break end
            send('update', snapshot())
            -- Outro resource pode soltar o foco (fechar a propria NUI); a tela retoma.
            if not IsNuiFocused() then holdFocus() end
            Wait(1000)
        end
    end)
end

local function closeScreen()
    isOpen = false
    SetNuiFocus(false, false)
    send('close')
end

local function sync()
    if not LocalPlayer.state.isDead then suppressed = false end
    local show = shouldShow()
    if show and not isOpen then
        openScreen()
    elseif not show and isOpen then
        closeScreen()
    end
    if not LocalPlayer.state.isDead and Doctor.isActive() then
        Doctor.abort(true)
    end
end

Doctor.setReporter(function(stage, data)
    doctorStage = { stage = stage, reason = data and data.reason and locale('error.' .. data.reason) or nil,
        duration = data and data.duration or nil }
    if isOpen then send('doctor', doctorStage) end
end)

---@param ok boolean
---@param reason? string codigo de erro (locales error.*)
---@param message? string texto pronto; tem prioridade sobre o codigo
local function result(ok, reason, message)
    return { ok = ok, message = message or (reason and locale('error.' .. reason)) or nil }
end

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
    if isOpen then send('open', snapshot()) end
end)

RegisterNUICallback('alertEms', function(_, cb)
    local ok, reason = lib.callback.await('noir_handledeath:server:alertEms', false)
    cb(result(ok, reason, ok and locale('alert_sent') or nil))
end)

RegisterNUICallback('callDoctor', function(_, cb)
    local ok, reason = Doctor.call()
    cb(result(ok, reason))
end)

RegisterNUICallback('respawn', function(_, cb)
    if not canRespawn(exports.bgrz_core:GetDownedInfo()) then
        cb(result(false, 'respawn_locked'))
        return
    end
    local ok = exports.bgrz_core:RequestRespawn()
    cb(result(ok, ok and nil or 'respawn_locked'))
end)

AddEventHandler('bgrz_core:client:playerRespawned', function()
    suppressed = true
    Doctor.abort(false)
    sync()
end)

RegisterNetEvent('noir_handledeath:client:doctorAbort', function()
    Doctor.abort(true)
end)

-- Os handlers de state bag rodam antes de o valor local mudar: le no tick seguinte.
local playerBag = ('player:%s'):format(cache.serverId)
AddStateBagChangeHandler('isDead', playerBag, function() SetTimeout(0, sync) end)
AddStateBagChangeHandler('isLoggedIn', playerBag, function() SetTimeout(0, sync) end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if isOpen then SetNuiFocus(false, false) end
    Doctor.abort(false)
end)

CreateThread(sync)
