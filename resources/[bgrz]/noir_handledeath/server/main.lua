local config = require 'config.shared'
local serverConfig = require 'config.server'

local STATE_ENROUTE = 'enroute'
local STATE_TREATING = 'treating'

---@class DoctorSession
---@field state 'enroute'|'treating'
---@field calledAt integer GetGameTimer
---@field arrivedAt? integer GetGameTimer

---@type table<integer, DoctorSession>
local sessions = {}
---@type table<integer, integer> os.time da ultima chamada do medico aceita
local lastCall = {}
---@type table<integer, integer> os.time do ultimo chamado de EMS
local lastAlert = {}
---@type table<integer, integer> os.time em que o jogador caiu
local downedAt = {}

local function log(message, ...)
    print(('[noir_handledeath] ' .. message):format(...))
end

---@return integer? count nil quando o provider nao responde
local function countEms()
    return exports.bgrz_core:CountOnDutyJob(serverConfig.emsJob)
end

---@param src integer
---@return integer? seconds nil quando o jogador nao esta caido
local function getDoctorWait(src)
    if not exports.bgrz_core:IsPlayerDowned(src) then return nil end
    if not downedAt[src] then downedAt[src] = os.time() end
    return math.max(0, config.doctorCallDelay - (os.time() - downedAt[src]))
end

---@param src integer
---@return DoctorSession?
local function getSession(src)
    local session = sessions[src]
    if session and GetGameTimer() - session.calledAt > serverConfig.sessionTtl then
        sessions[src] = nil
        return nil
    end
    return session
end

---@param src integer
---@return boolean
local function canPay(src)
    return exports.bgrz_core:GetMoney(src, 'cash') >= config.price
        or exports.bgrz_core:GetMoney(src, 'bank') >= config.price
end

---Cobra do dinheiro vivo e, se nao der, do banco.
---@param src integer
---@return 'cash'|'bank'|nil account
local function charge(src)
    for _, account in ipairs({ 'cash', 'bank' }) do
        if exports.bgrz_core:GetMoney(src, account) >= config.price
            and exports.bgrz_core:RemoveMoney(src, account, config.price, 'noir_handledeath-revive') then
            return account
        end
    end
end

-- Tela de morte: quantos paramedicos em servico e se o medico NPC atende.
lib.callback.register('noir_handledeath:server:getStatus', function(source)
    local emsOnDuty = countEms()
    local doctorWait = getDoctorWait(source) or config.doctorCallDelay
    return {
        emsOnDuty = emsOnDuty or 0,
        doctorAvailable = emsOnDuty ~= nil and emsOnDuty <= serverConfig.maxEmsOnDuty,
        doctorWait = doctorWait,
    }
end)

lib.callback.register('noir_handledeath:server:alertEms', function(source)
    local src = source
    if not exports.bgrz_core:IsPlayerDowned(src) then return false, 'not_downed' end

    local now = os.time()
    if lastAlert[src] and now - lastAlert[src] < config.alertCooldown then return false, 'cooldown' end

    local emsOnDuty = countEms()
    if not emsOnDuty then return false, 'unavailable' end
    if emsOnDuty == 0 then return false, 'no_ems' end

    local ped = GetPlayerPed(src)
    if ped == 0 then return false, 'unavailable' end

    lastAlert[src] = now
    local ok = exports.bgrz_core:SendDispatch({
        code = serverConfig.alert.code,
        title = serverConfig.alert.title,
        message = serverConfig.alert.message,
        coords = GetEntityCoords(ped),
        jobs = { serverConfig.emsJob },
    })
    if not ok then return false, 'unavailable' end
    return true
end)

lib.callback.register('noir_handledeath:server:callDoctor', function(source)
    local src = source
    if getSession(src) then return false, 'already_called' end
    if not exports.bgrz_core:IsPlayerDowned(src) then return false, 'not_downed' end
    -- 1 s de folga: a contagem da tela e local e pode zerar um pouco antes da do servidor.
    if (getDoctorWait(src) or config.doctorCallDelay) > 1 then return false, 'doctor_too_soon' end

    local now = os.time()
    if lastCall[src] and now - lastCall[src] < serverConfig.callCooldown then
        return false, 'cooldown'
    end
    local emsOnDuty = countEms()
    if not emsOnDuty then return false, 'unavailable' end
    if emsOnDuty > serverConfig.maxEmsOnDuty then return false, 'ems_online' end
    if not canPay(src) then return false, 'no_money' end

    lastCall[src] = now
    sessions[src] = { state = STATE_ENROUTE, calledAt = GetGameTimer() }
    return true
end)

RegisterNetEvent('noir_handledeath:server:doctorArrived', function()
    local src = source
    local session = getSession(src)
    if not session or session.state ~= STATE_ENROUTE then return end
    if GetGameTimer() - session.calledAt < serverConfig.minTravelTime then return end

    session.state = STATE_TREATING
    session.arrivedAt = GetGameTimer()
end)

lib.callback.register('noir_handledeath:server:doctorFinish', function(source)
    local src = source
    local session = getSession(src)
    if not session or session.state ~= STATE_TREATING then return false, 'failed' end
    -- 1 s de folga para a latencia entre o evento de chegada e o fim da massagem.
    if GetGameTimer() - session.arrivedAt < config.reviveTime - 1000 then return false, 'failed' end

    -- Encerra antes de qualquer chamada: uma segunda requisicao nao acha sessao e nao cobra de novo.
    sessions[src] = nil

    if not exports.bgrz_core:IsPlayerDowned(src) then return false, 'failed' end

    local account = charge(src)
    if not account then return false, 'no_money' end

    local revived = exports.bgrz_core:RevivePlayer(src)
    if not revived then
        exports.bgrz_core:AddMoney(src, account, config.price, 'noir_handledeath-refund')
        log('reanimacao falhou para %s; $%d devolvidos (%s)', src, config.price, account)
        return false, 'unavailable'
    end

    log('%s (%s) reanimado pelo medico NPC, pagou $%d (%s)',
        GetPlayerName(src), exports.bgrz_core:GetCitizenId(src) or '?', config.price, account)
    return true, config.price
end)

RegisterNetEvent('noir_handledeath:server:doctorCancel', function()
    sessions[source] = nil
end)

-- Levantou por outro caminho (EMS, respawn no hospital, admin): o medico vai embora sem cobrar.
AddStateBagChangeHandler('isDead', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end
    if value then
        downedAt[src] = downedAt[src] or os.time()
        return
    end

    downedAt[src] = nil
    if not sessions[src] then return end
    sessions[src] = nil
    TriggerClientEvent('noir_handledeath:client:doctorAbort', src)
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastCall[source] = nil
    lastAlert[source] = nil
    downedAt[source] = nil
end)
