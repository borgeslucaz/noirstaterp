---Smash & Grab — a interação: target no objeto e o fluxo do roubo.
---
---O target fica no VEÍCULO, filtrado pelo osso da janela daquele assento — não no
---prop. O motivo é o raycast: o ox_target atira um shapetest da câmera e pega a
---primeira entidade no caminho, que olhando um carro de fora é sempre a carroceria.
---Um prop no banco de trás fica atrás dela e nunca seria mirado. É por isso que o
---próprio ox_target põe as opções de porta e assento no veículo, com `bones`.
---
---São duas opções na mesma janela, e nunca as duas ao mesmo tempo:
---
---  * "Quebrar vidro" — enquanto o vidro daquela porta estiver inteiro;
---  * "Roubar <objeto>" — depois que ele estiver quebrado.
---
---A quebra é uma ação própria, com sua própria animação. Ela não acontece de
---brinde quando o jogador escolhe o loot: são dois gestos separados, e é o
---primeiro que faz barulho e chama o alarme.

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local CrimeConfig = require 'config.smashgrab'
local Integrations = require 'client.integrations'

local CRIME = Constants.crimes.smashgrab
local DebugPrint = Utils.debugPrint(CRIME)
local STATE = Constants.state.smashGrab

local EVENT_RESERVE = Constants.event('server', CRIME, 'reserve')
local EVENT_RELEASE = Constants.event('server', CRIME, 'release')
local EVENT_CLAIM = Constants.event('server', CRIME, 'claim')

local EVENT_BREAK = Constants.event('server', CRIME, 'break')
local EVENT_BROKEN = Constants.event('client', CRIME, 'windowBroken')

local OPTION_BREAK = ('%s:%s:break'):format(Constants.resource, CRIME)
local OPTION_STEAL = ('%s:%s:steal'):format(Constants.resource, CRIME)

local Interaction = {}

---Trava local de reentrada. A trava que vale é a do servidor; esta só evita que o
---mesmo jogador abra duas progress ao mesmo tempo.
local busy = false

---Dicionário de animação -> existe neste build. São DOIS dicionários (quebrar e
---roubar), então o cache é por dicionário: com uma flag só, o primeiro conferido
---respondia pelos dois e o outro nunca era validado.
---@type table<string, boolean>
local animChecked = {}


---Código de recusa do servidor -> chave de locale. Os códigos são estáveis e
---legíveis por máquina; o texto é localizado aqui (§20.1).
local CODE_LOCALE = {
    busy = 'sg_reason_busy',
    cooldown = 'sg_reason_busy',
    too_far = 'sg_reason_too_far',
    reserved = 'sg_reason_reserved',
    already_taken = 'sg_reason_already_taken',
    window_intact = 'sg_reason_window_intact',
    not_eligible = 'sg_reason_not_eligible',
    too_soon = 'sg_reason_too_soon',
    expired = 'sg_reason_expired',
    window_broken = 'sg_reason_window_broken',
    provider_unavailable = 'sg_reason_provider_unavailable',
    no_loot = 'sg_reason_already_taken',
    mismatch = 'sg_failed',
}

---@return table? anim
local function animOption(anim)
    if type(anim) ~= 'table' or type(anim.dict) ~= 'string' then return nil end

    if animChecked[anim.dict] == nil then
        animChecked[anim.dict] = DoesAnimDictExist(anim.dict)
        if not animChecked[anim.dict] then
            lib.print.warn(('dicionário de animação ausente neste build: %s'):format(anim.dict))
        end
    end

    return animChecked[anim.dict] and anim or nil
end

---@param entry table
---@return boolean
local function available(entry)
    return Entity(entry.vehicle).state[STATE] == nil
end

---@param entry table
---@return boolean
local function windowBroken(entry)
    return not IsVehicleWindowIntact(entry.vehicle, entry.windowIndex)
end

---@param entry table
---@return boolean
local function withinReach(entry)
    if not DoesEntityExist(entry.vehicle) then return false end
    -- Medido até o osso da janela, e não até o centro do carro: num veículo grande
    -- o centro fica metros longe da porta em que o jogador está encostado.
    local bone = GetEntityBoneIndexByName(entry.vehicle, entry.loot.seat.bone)
    local coords = bone ~= -1 and GetEntityBonePosition_2(entry.vehicle, bone)
        or GetEntityCoords(entry.vehicle)
    return #(GetEntityCoords(cache.ped) - coords) <= CrimeConfig.maxDistance
end

---Vigia a cena durante a progress e cancela quando ela deixa de fazer sentido.
---A progress do ox_lib não sabe nada sobre o carro; é esta thread que sabe. Ela
---vive só enquanto a barra estiver na tela.
---@param entry table
---@param breaking boolean? true durante a quebra, quando o vidro AINDA está inteiro
local function watchProgress(entry, breaking)
    CreateThread(function()
        while lib.progressActive() do
            local glassWrong = breaking and windowBroken(entry) or
                (not breaking and not windowBroken(entry))
            if not withinReach(entry)
                or IsEntityDead(cache.ped)
                or cache.vehicle
                or glassWrong then
                lib.cancelProgress()
                return
            end
            Wait(200)
        end
    end)
end

---@param entry table
local function steal(entry)
    if busy then return end
    busy = true

    -- Reserva primeiro. O servidor confere tudo e tranca o objeto para este
    -- jogador; sem isso, dois jogadores fariam a animação inteira lado a lado
    -- para um só levar, e o outro ia sentir que o jogo mentiu.
    local reserved = lib.callback.await(EVENT_RESERVE, CrimeConfig.callbackTimeout,
        entry.netId, entry.loot.propKey, entry.loot.seatKey)

    if type(reserved) ~= 'table' or not reserved.ok then
        busy = false
        local code = type(reserved) == 'table' and reserved.code or nil
        DebugPrint('reserva recusada:', code)
        return Integrations.notify(locale(CODE_LOCALE[code] or 'sg_failed'), 'error')
    end

    watchProgress(entry)

    local completed = lib.progressCircle({
        label = locale('sg_progress', locale(entry.loot.prop.label)),
        duration = CrimeConfig.duration,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = animOption(CrimeConfig.anim),
    })

    if not completed or not withinReach(entry) then
        -- Devolve o objeto para a prateleira em vez de deixá-lo trancado até o
        -- timeout. Quem cancelou não deve atrapalhar quem está do lado.
        lib.callback.await(EVENT_RELEASE, CrimeConfig.callbackTimeout, entry.netId)
        busy = false
        return
    end

    local result = lib.callback.await(EVENT_CLAIM, CrimeConfig.callbackTimeout, entry.netId)
    busy = false

    if type(result) ~= 'table' or not result.ok then
        local code = type(result) == 'table' and result.code or nil
        DebugPrint('entrega recusada:', code)
        return Integrations.notify(locale(CODE_LOCALE[code] or 'sg_failed'), 'error')
    end

    -- O prop some pela state bag que o servidor acabou de marcar, para todo mundo
    -- ao mesmo tempo. A notificação do que veio dentro também é do servidor.
end

---Aplica a quebra que o servidor autorizou.
---
---Chega ao DONO DE REDE do veículo, que não é necessariamente quem bateu: o native
---só replica a partir dele. Por isso nada aqui é decisão — janela e alarme vêm
---prontos do servidor.
---@param netId number
---@param windowIndex number
---@param alarmDuration number? nil = sem alarme
local function applyBreak(netId, windowIndex, alarmDuration)
    if not Utils.isPositiveInteger(netId) or not Utils.isInteger(windowIndex) then return end

    local vehicle = NetToVeh(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    SmashVehicleWindow(vehicle, windowIndex)

    if Utils.isFinite(alarmDuration) and alarmDuration > 0 then
        -- Os três natives têm papéis distintos, e a ordem importa:
        --   1. dar um alarme ao veículo — sem isto não há o que tocar, e é aqui
        --      que eu errei antes copiando um `false` de outro resource;
        --   2. definir por quanto tempo ele apita;
        --   3. disparar.
        -- Só o dono de rede consegue fazer isso replicar, e é justamente a ele
        -- que o servidor manda este evento.
        SetVehicleAlarm(vehicle, true)
        SetVehicleAlarmTimeLeft(vehicle, alarmDuration)
        StartVehicleAlarm(vehicle)
    end
end

---@param entry table
local function breakWindow(entry)
    if busy then return end
    busy = true

    watchProgress(entry, true)

    local completed = lib.progressCircle({
        label = locale('sg_progress_break'),
        duration = CrimeConfig.breakDuration,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = animOption(CrimeConfig.breakAnim),
    })

    if not completed or not withinReach(entry) or windowBroken(entry) then
        busy = false
        return
    end

    local result = lib.callback.await(EVENT_BREAK, CrimeConfig.callbackTimeout, entry.netId)
    busy = false

    if type(result) ~= 'table' or not result.ok then
        local code = type(result) == 'table' and result.code or nil
        DebugPrint('quebra recusada:', code)
        return Integrations.notify(locale(CODE_LOCALE[code] or 'sg_failed'), 'error')
    end

    -- O vidro estoura pelo evento que o servidor manda ao dono de rede, para todo
    -- mundo por perto ao mesmo tempo. Nada a fazer aqui.
end

RegisterNetEvent(EVENT_BROKEN, applyBreak)

---@param entry table
function Interaction.attach(entry)
    local label = locale(entry.loot.prop.label)

    Integrations.addEntityTarget(entry.netId, {
        {
            name = OPTION_BREAK,
            icon = 'fa-solid fa-hand-fist',
            label = locale('sg_target_break'),
            bones = entry.loot.seat.targetBones,
            distance = CrimeConfig.maxDistance,
            canInteract = function()
                if busy or lib.progressActive() or cache.vehicle then return false end
                if not Integrations.isLoggedIn() then return false end
                return not windowBroken(entry) and available(entry)
            end,
            onSelect = function()
                breakWindow(entry)
            end,
        },
        {
            name = OPTION_STEAL,
            icon = 'fa-solid fa-hand',
            label = locale('sg_target_steal', label),
            bones = entry.loot.seat.targetBones,
            distance = CrimeConfig.maxDistance,
            canInteract = function()
                if busy or lib.progressActive() or cache.vehicle then return false end
                if not Integrations.isLoggedIn() then return false end
                return windowBroken(entry) and available(entry)
            end,
            onSelect = function()
                steal(entry)
            end,
        },
    })
end

---@param entry table
function Interaction.detach(entry)
    if not entry.netId then return end
    Integrations.removeEntityTarget(entry.netId, { OPTION_BREAK, OPTION_STEAL })
end

return Interaction
