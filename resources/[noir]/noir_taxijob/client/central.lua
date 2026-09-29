-- Central do táxi (NUI com foco): abertura autorizada pelo servidor, callbacks da NUI, ESC e liberação segura do foco.
-- Exceção deliberada à regra de HUD sem foco: o foco existe apenas aqui, fora do veículo e perto do atendente.
Central = { state = 'CLOSED', session = nil }

local D = Config.Depot
local CLOSE_TIMEOUT_MS = 1200   -- segurança: libera o foco mesmo se o browser não responder closeComplete
local closeToken = nil

local openErrors = {
    not_loaded = 'notify.central_not_loaded',
    not_near = 'notify.central_not_near',
    activity_restricted = 'notify.central_restricted',
    internal_error = 'notify.central_failed',
}

function Central.isOpen()
    return Central.state ~= 'CLOSED'
end

local function finalizeClose()
    if Central.state == 'CLOSED' then return end
    Central.state = 'CLOSED'
    Central.session = nil
    closeToken = nil
    SetNuiFocus(false, false)
    UI.closeMenu()
    TriggerEvent('noir_taxijob:client:menuClosed')
end

---Inicia a coreografia de saída na NUI; o foco é liberado em closeComplete ou pelo timeout de segurança.
local function beginClose()
    Central.state = 'CLOSING'
    TriggerServerEvent('noir_taxijob:server:closeCentral')
    local token = {}
    closeToken = token
    SetTimeout(CLOSE_TIMEOUT_MS, function()
        if closeToken == token then finalizeClose() end
    end)
end

---Fechamento imediato (resource stop, unload, morte, afastamento).
function Central.forceClose()
    if Central.state == 'CLOSED' then return end
    TriggerServerEvent('noir_taxijob:server:closeCentral')
    UI.send('taxiMenu:close', { immediate = true })
    finalizeClose()
end

function Central.open()
    if Central.state ~= 'CLOSED' then return end
    if cache.vehicle then return end
    if not exports.bgrz_core:IsLoggedIn() then return end

    Central.state = 'OPENING'
    local res = lib.callback.await('noir_taxijob:server:openCentral', false)
    if Central.state ~= 'OPENING' then return end
    if not res or not res.ok then
        Central.state = 'CLOSED'
        local key = res and openErrors[res.code]
        if key then Notify(key, 'error') end
        return
    end

    Central.session = res.sessionId
    Central.state = 'READY'
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    UI.openMenu(res)

    -- Sem loop de distância permanente: só enquanto a central está aberta.
    CreateThread(function()
        while Central.state ~= 'CLOSED' do
            Wait(500)
            if Central.state == 'READY' then
                local ped = cache.ped
                local far = #(GetEntityCoords(ped) - vec3(D.coords.x, D.coords.y, D.coords.z)) > D.interactDistance + 5.0
                if far or IsEntityDead(ped) or cache.vehicle then
                    Central.forceClose()
                end
            end
        end
    end)
end

-- ───────────────────────── callbacks da NUI (sempre respondem) ─────────────────────────

RegisterNUICallback('closeMenu', function(_, cb)
    if Central.state == 'RENTING' or Central.state == 'RETURNING' then
        cb({ ok = false })
        return
    end
    if Central.state == 'READY' then beginClose() end
    cb({ ok = true })
end)

RegisterNUICallback('closeComplete', function(_, cb)
    cb({})
    finalizeClose()
end)

RegisterNUICallback('requestRanking', function(_, cb)
    if Central.state ~= 'READY' or not Central.session then
        cb({ ok = false, code = 'invalid_session' })
        return
    end
    local res = lib.callback.await('noir_taxijob:server:getRanking', false, Central.session)
    cb(res or { ok = false, code = 'internal_error' })
end)

RegisterNUICallback('retryBootstrap', function(_, cb)
    if Central.state ~= 'READY' or not Central.session then
        cb({ ok = false, code = 'invalid_session' })
        return
    end
    local res = lib.callback.await('noir_taxijob:server:retryBootstrap', false, Central.session)
    if res and res.ok then UI.rememberMenu(res) end
    cb(res or { ok = false, code = 'internal_error' })
end)

RegisterNUICallback('rentVehicle', function(data, cb)
    if Central.state ~= 'READY' or not Central.session then
        cb({ ok = false, code = 'request_in_progress' })
        return
    end
    local vehicleId = type(data) == 'table' and data.vehicleId or nil
    if type(vehicleId) ~= 'string' or #vehicleId == 0 or #vehicleId > 32 then
        cb({ ok = false, code = 'invalid_vehicle' })
        return
    end

    Central.state = 'RENTING'
    local res = lib.callback.await('noir_taxijob:server:rentVehicle', false, Central.session, vehicleId)
    if Central.state ~= 'RENTING' then
        cb({ ok = false, code = 'session_expired' })
        return
    end
    if not res or not res.ok then
        Central.state = 'READY'
        cb(res or { ok = false, code = 'internal_error' })
        return
    end

    Rental.onRented(res)
    cb({ ok = true })
    beginClose()
end)

RegisterNUICallback('returnVehicle', function(_, cb)
    if Central.state ~= 'READY' or not Central.session then
        cb({ ok = false, code = 'invalid_session' })
        return
    end
    if not Rental.active() then
        cb({ ok = false, code = 'not_yours' })
        return
    end

    Central.state = 'RETURNING'
    local res = lib.callback.await('noir_taxijob:server:returnVehicle', false, Rental.netId)
    if Central.state ~= 'RETURNING' then
        cb({ ok = false, code = 'session_expired' })
        return
    end
    if not res or not res.ok then
        Central.state = 'READY'
        local code = res and res.code or 'internal_error'
        if code == 'not_yours' then Rental.clear() end
        cb({ ok = false, code = code })
        return
    end

    -- Devolução confirmada: o servidor encerrou o duty (Sessions.removeDriver) e apagou o veículo.
    Rental.clear()
    Notify('notify.rental_returned', 'success')
    local fresh = lib.callback.await('noir_taxijob:server:retryBootstrap', false, Central.session)
    Central.state = 'READY'
    if fresh and fresh.ok then
        UI.rememberMenu(fresh)
        cb({ ok = true, data = fresh })
    else
        cb({ ok = true })
    end
end)

-- ───────────────────────── cleanup ─────────────────────────

AddEventHandler('bgrz_core:client:playerUnloaded', function()
    Central.forceClose()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Central.state ~= 'CLOSED' then
        Central.state = 'CLOSED'
        Central.session = nil
    end
    SetNuiFocus(false, false)
end)
