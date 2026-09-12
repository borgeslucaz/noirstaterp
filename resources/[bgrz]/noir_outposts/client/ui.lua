-- NUI do computador: foco após autorização, snapshot completo, callbacks sempre respondem.
NoirOutposts = NoirOutposts or {}

local Ui = {}
NoirOutposts.Ui = Ui

local shared = require 'config.shared'
local clientConfig = require 'config.client'
local C = NoirOutposts.Constants

local state = { open = false, closing = false, busy = false, outpostId = nil, snapshot = nil }
local ready = false
local closeToken = nil

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function finalizeClose()
    state.open, state.closing, state.busy, state.outpostId, state.snapshot = false, false, false, nil, nil
    closeToken = nil
    SetNuiFocus(false, false)
end

---Fechamento animado com timeout de segurança.
---@param notifyNui boolean
local function beginClose(notifyNui)
    if not state.open or state.closing then return end
    state.closing = true
    if notifyNui then send('outposts:close', { immediate = false }) end
    local token = {}
    closeToken = token
    SetTimeout(clientConfig.ui.closeTimeoutMs, function()
        if closeToken == token then finalizeClose() end
    end)
end

function Ui.forceClose()
    if state.open or state.closing then
        send('outposts:close', { immediate = true })
        lib.callback.await(C.Callbacks.CLOSE_PANEL, false)
    end
    finalizeClose()
end

---@param outpostId string
---@param snapshot table
function Ui.open(outpostId, snapshot)
    state.open, state.closing, state.busy = true, false, false
    state.outpostId, state.snapshot = outpostId, snapshot
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    send('outposts:open', snapshot)
end

---@param snapshot table
function Ui.update(snapshot)
    if not state.open or state.closing then return end
    state.snapshot = snapshot
    send('outposts:update', snapshot)
end

---Chama o servidor a partir da NUI, bloqueando envios concorrentes.
---@param callback string
---@param payload table
---@return table response
local function request(callback, payload)
    if state.busy then return { ok = false, code = 'request_in_progress' } end
    state.busy = true
    local response = lib.callback.await(callback, false, payload)
    state.busy = false
    return response or { ok = false, code = 'internal_error' }
end

---Reaplica o snapshot depois de uma ação bem-sucedida.
local function refresh()
    local response = lib.callback.await(C.Callbacks.REFRESH_PANEL, false)
    if response and response.ok then
        Ui.update(response.data)
        return
    end
    Ui.forceClose()
end

RegisterNUICallback('uiReady', function(_, cb)
    ready = true
    cb({ ok = true })
    if state.open and not state.closing and state.snapshot then
        send('outposts:open', state.snapshot)
    end
end)

RegisterNUICallback('close', function(_, cb)
    if not state.open or state.closing or state.busy then
        cb({ ok = false, code = 'invalid_state' })
        return
    end
    cb({ ok = true })
    lib.callback.await(C.Callbacks.CLOSE_PANEL, false)
    beginClose(false)
end)

RegisterNUICallback('closeComplete', function(_, cb)
    cb({ ok = true })
    finalizeClose()
end)

RegisterNUICallback('refresh', function(_, cb)
    if not state.open or state.closing then
        cb({ ok = false, code = 'invalid_state' })
        return
    end
    local response = lib.callback.await(C.Callbacks.REFRESH_PANEL, false)
    if response and response.ok then
        state.snapshot = response.data
        cb({ ok = true, data = response.data })
        return
    end
    cb(response or { ok = false, code = 'internal_error' })
end)

RegisterNUICallback('hire', function(data, cb)
    if not state.open or state.closing or not state.outpostId then
        cb({ ok = false, code = 'invalid_state' })
        return
    end
    if type(data) ~= 'table' or type(data.profileKey) ~= 'string' then
        cb({ ok = false, code = 'invalid_payload' })
        return
    end
    local response = request(C.Callbacks.HIRE, {
        outpostId = state.outpostId,
        profileKey = data.profileKey,
        requestId = NoirOutposts.Interaction.requestId(),
    })
    cb(response)
    if response.ok then refresh() end
end)

RegisterNUICallback('fire', function(data, cb)
    if not state.open or state.closing or not state.outpostId then
        cb({ ok = false, code = 'invalid_state' })
        return
    end
    if type(data) ~= 'table' or type(data.dealerId) ~= 'number' then
        cb({ ok = false, code = 'invalid_payload' })
        return
    end
    local response = request(C.Callbacks.FIRE, {
        outpostId = state.outpostId,
        dealerId = data.dealerId,
        requestId = NoirOutposts.Interaction.requestId(),
    })
    cb(response)
    if response.ok then refresh() end
end)

RegisterNUICallback('deposit', function(data, cb)
    if not state.open or state.closing or not state.outpostId then
        cb({ ok = false, code = 'invalid_state' })
        return
    end
    if type(data) ~= 'table' or type(data.productId) ~= 'string' or type(data.amount) ~= 'number' then
        cb({ ok = false, code = 'invalid_payload' })
        return
    end

    local outpostId = state.outpostId
    state.busy = true
    local completed = NoirOutposts.Interaction.runProgress(
        locale('progress.deposit'), clientConfig.progress.depositDurationMs, clientConfig.animations.deposit)
    state.busy = false
    if not completed then
        cb({ ok = false, code = 'cancelled' })
        return
    end

    local response = request(C.Callbacks.DEPOSIT, {
        outpostId = outpostId,
        productId = data.productId,
        amount = math.floor(data.amount),
        requestId = NoirOutposts.Interaction.requestId(),
    })
    cb(response)
    if response.ok then refresh() end
end)

RegisterNUICallback('collect', function(_, cb)
    if not state.open or state.closing or not state.outpostId then
        cb({ ok = false, code = 'invalid_state' })
        return
    end

    local outpostId = state.outpostId
    state.busy = true
    local completed = NoirOutposts.Interaction.runProgress(
        locale('progress.collect'), clientConfig.progress.collectDurationMs, clientConfig.animations.collect)
    state.busy = false
    if not completed then
        cb({ ok = false, code = 'cancelled' })
        return
    end

    local response = request(C.Callbacks.COLLECT, {
        outpostId = outpostId,
        requestId = NoirOutposts.Interaction.requestId(),
    })
    cb(response)
    if response.ok then refresh() end
end)

RegisterNUICallback('claim', function(_, cb)
    if not state.open or state.closing or not state.outpostId then
        cb({ ok = false, code = 'invalid_state' })
        return
    end

    local outpostId = state.outpostId

    -- Libera o foco desta NUI antes de abrir a NUI do minigame.
    cb({ ok = true, data = { closing = true } })
    beginClose(true)

    CreateThread(function()
        local closeDeadline = GetGameTimer() + clientConfig.ui.closeTimeoutMs + 250
        while (state.open or state.closing) and GetGameTimer() < closeDeadline do Wait(50) end

        local minigame = clientConfig.minigames.claim
        local ok, minigameCompleted = pcall(function()
            return exports.peuren_minigames:StartTypewriter(
                minigame.typewriterCount, minigame.typewriterTimeMs)
        end)

        if not ok or minigameCompleted ~= true then
            NoirOutposts.Client.notify(locale('claim.minigame_failed'), 'error')
            return
        end

        -- O tempo configurado começa apenas depois do sucesso no Typewriter.
        local started = lib.callback.await(C.Callbacks.CLAIM_START, false, { outpostId = outpostId })
        if not NoirOutposts.Client.handleFailure(started) then return end

        local sessionId = started.data.sessionId
        local completed = NoirOutposts.Interaction.runProgress(
            locale('progress.claim'), started.data.durationMs, clientConfig.animations.claim)

        if not completed then
            lib.callback.await(C.Callbacks.CLAIM_CANCEL, false, { sessionId = sessionId })
            NoirOutposts.Client.notify(locale('claim.cancelled'), 'inform')
            return
        end

        local result = lib.callback.await(C.Callbacks.CLAIM_COMPLETE, false, { sessionId = sessionId })
        if not NoirOutposts.Client.handleFailure(result) then return end
        NoirOutposts.Client.notify(locale('claim.success', shared.outposts[outpostId].label), 'success')
    end)
end)

RegisterNetEvent(C.Events.PANEL_UPDATE, function(snapshot)
    if source ~= 65535 then return end
    Ui.update(snapshot)
end)

RegisterNetEvent(C.Events.PANEL_CLOSE, function(payload)
    if source ~= 65535 then return end
    if type(payload) == 'table' and payload.reason and payload.reason ~= 'client' then
        NoirOutposts.Client.notify(NoirOutposts.Client.message(payload.reason), 'inform')
    end
    Ui.forceClose()
end)

-- Fecha quando o jogador se afasta, morre ou entra em veículo.
local CLOSE_DISTANCE = shared.interaction.computerDistance + 2.0

CreateThread(function()
    while true do
        local sleep = 1000
        if state.open and not state.closing then
            sleep = 500
            local definition = state.outpostId and shared.outposts[state.outpostId] or nil
            local distance
            if definition then
                local target = vector3(definition.computer.x, definition.computer.y, definition.computer.z)
                distance = #(GetEntityCoords(cache.ped) - target)
            end
            -- cache.vehicle é `false` a pé, então precisa de teste de verdade, não de nil.
            local facts = {
                dead = IsEntityDead(cache.ped) == true,
                inVehicle = (cache.vehicle or 0) ~= 0,
                distance = distance,
            }
            if NoirOutposts.Validators.shouldClosePanel(facts, CLOSE_DISTANCE) then
                Ui.forceClose()
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
