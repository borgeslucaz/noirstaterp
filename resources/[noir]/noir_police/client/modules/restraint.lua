---Mãos para cima, algema, zip tie, escolta, carregar no ombro e viatura (lado do cliente).
---
---O cliente só apresenta: pede ao servidor e toca a animação. Quem decide se a
---algema fecha é o servidor (server/modules/restraint.lua).

local Config = require 'config.shared'
local Departments = require 'shared.departments'
local Integrations = require 'client.integrations'
local Util = require 'client.util'

local Restraint = {}

local cuffAnims = {
    back = { dict = 'mp_arresting', name = 'idle' },
    front = { dict = 'anim@move_m@prisoner_cuffed', name = 'idle' },
}

local cuffOffsets = {
    cuffs = {
        back = { pos = vec3(0.0, 0.07, 0.03), rot = vec3(10.0, 115.0, -65.0) },
        front = { pos = vec3(-0.025, 0.0, 0.085), rot = vec3(10.0, 75.0, 0.0) },
    },
    zipties = {
        back = { pos = vec3(0.01, 0.06, 0.035), rot = vec3(-90.0, 110.0, -65.0) },
        front = { pos = vec3(-0.02, 0.0, 0.085), rot = vec3(100.0, 75.0, 0.0) },
    },
}

local handsAnim = {
    hu = { dict = 'missminuteman_1ig_2', name = 'handsup_enter' },
    huk = { dict = 'random@arrests@busted', name = 'idle_c' },
}

local disabledWhileCuffed = { 140, 141, 142, 25, 24, 257, 263, 59, 22, 21 }
local disabledWhileHandsUp = { 140, 141, 142, 25, 24, 257 }
local disabledWhileKneeling = { 30, 31, 32, 33, 34, 35, 21, 22, 23, 36, 44 }

local cuffed = false
local cuffProp = nil
local handsUp = false
local holdingKey = false
local escortThread = false
local carryThread = false
local actionBusy = false
local warpingUntil = 0
-- Pílula de tecla (definida mais abaixo; setHandsUp chama antes).
local refreshKeys

-- Props ----------------------------------------------------------------------------

---Modelo do prop, ou nil. Prop ausente derruba o cliente no Enhanced: só cria o que
---o jogo confirma que existe.
local function propModel(cuffType)
    local model
    if Config.cuffs.customProps then
        model = cuffType == 'zipties' and `police_zip_tie_positioned` or `police_cuffs`
    elseif cuffType == 'cuffs' then
        model = joaat(Config.cuffs.vanillaCuffModel)
    end
    if not model or not IsModelInCdimage(model) then return nil end
    return model
end

local function deleteCuffProp()
    local prop = cuffProp
    cuffProp = nil
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, false)
        SetEntityAsMissionEntity(prop, true, true)
        DeleteObject(prop)
    end
end

local function createCuffProp(cuffType, angle)
    deleteCuffProp()
    local model = propModel(cuffType)
    if not model then return end
    local ok = pcall(lib.requestModel, model, 3000)
    if not ok then return end
    local offset = cuffOffsets[cuffType][angle]
    local ped = cache.ped
    local prop = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    SetModelAsNoLongerNeeded(model)
    if not prop or prop == 0 then return end
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 0x49D9), offset.pos.x, offset.pos.y, offset.pos.z,
        offset.rot.x, offset.rot.y, offset.rot.z, true, true, false, true, 1, true)
    cuffProp = prop
end

local function playSound(name)
    if Config.cuffs.customSound then
        -- O banco `nd_police` só existe quando o áudio do ND estiver no manifest.
        local deadline = GetGameTimer() + 2000
        while not RequestScriptAudioBank('audiodirectory/nd_police', false) do
            if GetGameTimer() > deadline then return end
            Wait(0)
        end
        local soundId = GetSoundId()
        PlaySoundFromEntity(soundId, name, cache.ped, 'nd_police_soundset', true, 0)
        ReleaseSoundId(soundId)
        ReleaseNamedScriptAudioBank('audiodirectory/nd_police')
    else
        PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
    end
end

-- Mãos para cima -------------------------------------------------------------------

---Sai da rendição. Do ajoelhado, levanta com a animação do jogo em vez de só cortar a
---pose (cortar deixava o personagem preso no chão).
---@param wasKneeling? boolean
local function stopHandsUp(wasKneeling)
    local ped = cache.ped
    for _, anim in pairs(handsAnim) do
        if IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) then
            StopAnimTask(ped, anim.dict, anim.name, 4.0)
        end
    end
    DisablePlayerFiring(cache.playerId, false)
    Integrations.disableTargeting(false)
    if not wasKneeling or IsEntityDead(ped) or cuffed then return end

    if Util.loadDict('random@arrests@busted') then
        TaskPlayAnim(ped, 'random@arrests@busted', 'exit', 2.0, 2.0, -1, 2, 0, false, false, false)
        Wait(1200)
    end
    if handsUp or cuffed then return end
    if Util.loadDict('random@arrests') then
        TaskPlayAnim(ped, 'random@arrests', 'kneeling_arrest_get_up', 2.0, 2.0, -1, 0, 0, false, false, false)
        Wait(2600)
    end
    if handsUp or cuffed then return end
    ClearPedTasks(ped)
end

---@param silent? boolean sair sem a animação de levantar (algemação, unload)
local function setHandsUp(kind, silent)
    if cuffed or LocalPlayer.state.isEscorted or LocalPlayer.state.isCarried then return end
    local previous = handsUp
    handsUp = kind
    LocalPlayer.state:set('handsUp', kind or false, true)
    if refreshKeys then refreshKeys() end

    if not kind then return stopHandsUp(previous == 'huk' and not silent) end

    local ped = cache.ped
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    if kind == 'huk' then
        if Util.loadDict('random@arrests') then
            TaskPlayAnim(ped, 'random@arrests', 'kneeling_arrest_idle', 1.0, 1.0, -1, 2, 0, false, false, false)
            Wait(1000)
        end
        if handsUp ~= kind then return end
        if Util.loadDict('random@arrests@busted') then
            TaskPlayAnim(ped, 'random@arrests@busted', 'enter', 1.0, 1.0, -1, 2, 0, false, false, false)
            Wait(1000)
        end
        if handsUp ~= kind then return end
    end

    local anim = handsAnim[kind]
    if not Util.loadDict(anim.dict) then return end
    local function play()
        TaskPlayAnim(cache.ped, anim.dict, anim.name, kind == 'huk' and 1.5 or 8.0, 8.0, -1, kind == 'huk' and 1 or 50,
            0, false, false, false)
    end
    play()
    DisablePlayerFiring(cache.playerId, true)
    Integrations.disableTargeting(true)

    CreateThread(function()
        local nextCheck = 0
        while handsUp == kind do
            for index = 1, #disabledWhileHandsUp do DisableControlAction(0, disabledWhileHandsUp[index], true) end
            -- Ajoelhado não anda, não corre, não pula e não entra em carro: só o J levanta.
            if kind == 'huk' then
                for index = 1, #disabledWhileKneeling do DisableControlAction(0, disabledWhileKneeling[index], true) end
            end
            DisablePlayerFiring(cache.playerId, true)
            -- Algo cortou a animação (ESC/menu de pausa, outro script): volta a pose. O
            -- jogador continua rendido até soltar pela tecla.
            if GetGameTimer() >= nextCheck then
                nextCheck = GetGameTimer() + 500
                if not IsEntityPlayingAnim(cache.ped, anim.dict, anim.name, 3) and not IsPedRagdoll(cache.ped)
                    and not IsEntityDead(cache.ped) then
                    play()
                end
            end
            Wait(0)
        end
    end)
end

lib.addKeybind({
    name = 'noir_police_handsup',
    description = locale('keybind.hands_up'),
    defaultKey = Config.handsUp.key,
    -- Toque: levanta ou abaixa as mãos. Segurar: ajoelha, de pé ou já de mãos para cima.
    onPressed = function()
        -- Ajoelhado fica travado: só o J levanta.
        if handsUp == 'huk' then return end
        if not handsUp and (cache.vehicle or LocalPlayer.state.blockHandsUp or IsPedFalling(cache.ped)
            or GetPedParachuteState(cache.ped) > 0 or IsEntityDead(cache.ped)) then
            return
        end
        holdingKey = true
        local pressedAt = GetGameTimer()
        while holdingKey and GetGameTimer() - pressedAt < Config.handsUp.kneelHoldMs do Wait(0) end
        if holdingKey then
            setHandsUp('huk')
        elseif handsUp then
            setHandsUp(false)
        else
            setHandsUp('hu')
        end
    end,
    onReleased = function()
        holdingKey = false
    end,
})

-- Algemado (próprio jogador) -------------------------------------------------------

-- Cada algemação ganha uma geração; um laço só age enquanto a geração dele é a atual.
-- Sem isso, um laço parado esperando a animação carregar voltava depois do desalgemar
-- e religava o SetEnableHandcuffs, e o ox_inventory (IsPedCuffed) travava a mira de vez.
local cuffGeneration = 0

local function disableList(list)
    for index = 1, #list do DisableControlAction(0, list[index], true) end
end

local function applyCuffedLoop(cuffType, angle)
    cuffGeneration = cuffGeneration + 1
    local mine = cuffGeneration
    local anim = cuffAnims[angle] or cuffAnims.back
    local function current() return cuffed and cuffGeneration == mine end
    Integrations.disableTargeting(true)

    CreateThread(function()
        while current() do
            disableList(disabledWhileCuffed)
            local ped = cache.ped
            -- Algemado não entra em carro sozinho, exceto quando o servidor mandou sentar.
            local entering = GetVehiclePedIsEntering(ped)
            if entering ~= 0 and GetGameTimer() > warpingUntil then ClearPedTasks(ped) end
            if cache.vehicle then
                DisableControlAction(0, 23, true)
                DisableControlAction(0, 75, true)
            end
            Wait(0)
        end
    end)

    CreateThread(function()
        while current() do
            local ped = cache.ped
            if not IsEntityPlayingAnim(ped, anim.dict, anim.name, 3) and not LocalPlayer.state.isCarried
                and not IsPedDeadOrDying(ped, true) then
                if Util.loadDict(anim.dict) and current() then
                    TaskPlayAnim(ped, anim.dict, anim.name, 8.0, -8.0, -1, 49, 0.0, false, false, false)
                end
            end
            -- Confere de novo: o loadDict acima pode ter cedido a thread.
            if not current() then break end
            SetEnableHandcuffs(ped, true)
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            if IsPedUsingActionMode(ped) then SetPedUsingActionMode(ped, false, -1, 'DEFAULT_ACTION') end
            Wait(250)
        end
    end)
end

---Solta tudo o que a algema prende no cliente. Idempotente: roda mesmo se o estado
---local já achava que estava solto.
local function releaseCuffEffects()
    cuffGeneration = cuffGeneration + 1
    local ped = cache.ped
    deleteCuffProp()
    Integrations.disableTargeting(false)
    SetEnableHandcuffs(ped, false)
    DisablePlayerFiring(cache.playerId, false)
end

local function setCuffed(enabled, cuffType, angle)
    if enabled then
        if handsUp then setHandsUp(false, true) end
        if cuffed then deleteCuffProp() end
        cuffed = true
        ClearPedTasksImmediately(cache.ped)
        createCuffProp(cuffType, angle)
        playSound('cuff')
        applyCuffedLoop(cuffType, angle)
        return
    end

    local wasCuffed = cuffed
    cuffed = false
    releaseCuffEffects()
    if not wasCuffed then return end
    local ped = cache.ped
    playSound('uncuff')
    ClearPedTasks(ped)
    if Util.loadDict('mp_arresting') then
        TaskPlayAnim(ped, 'mp_arresting', 'b_uncuff', 8.0, 8.0, 1300, 33, 0.0, false, false, false)
    end
end

-- Rede de segurança: o servidor diz que está solto, mas o ped segue marcado como
-- algemado (ou o contrário não importa aqui). Destrava a mira.
CreateThread(function()
    while true do
        Wait(1000)
        if not cuffed and not LocalPlayer.state.isCuffed and IsPedCuffed(cache.ped) then
            SetEnableHandcuffs(cache.ped, false)
        end
    end
end)

RegisterNetEvent('noir_police:client:setCuffed', function(enabled, cuffType, angle)
    if source ~= 65535 then return end
    setCuffed(enabled == true, cuffType == 'zipties' and 'zipties' or 'cuffs', angle == 'front' and 'front' or 'back')
end)

---Algemação agressiva: animação de quem é derrubado e, se ainda puder, a chance de fugir.
RegisterNetEvent('noir_police:client:beingCuffed', function(token, officerHeading, canEscape, windowMs)
    if source ~= 65535 then return end
    if handsUp then setHandsUp(false, true) end
    local ped = cache.ped
    SetEntityHeading(ped, officerHeading + 0.0)
    if Util.loadDict('mp_arrest_paired') then
        TaskPlayAnim(ped, 'mp_arrest_paired', 'crook_p2_back_left', 8.0, -8.0, windowMs, 33, 0, false, false, false)
    end

    local escaped = false
    if canEscape then
        local done = false
        SetTimeout(windowMs - 250, function()
            if not done then lib.cancelSkillCheck() end
        end)
        escaped = lib.skillCheck({ 'medium', 'hard' }, { 'w', 'a', 's', 'd' }) == true
        done = true
        if escaped then StopAnimTask(ped, 'mp_arrest_paired', 'crook_p2_back_left', 2.0) end
    end
    TriggerServerEvent('noir_police:server:cuffEscape', token, escaped)
end)

RegisterNetEvent('noir_police:client:cuffAborted', function()
    if source ~= 65535 then return end
    StopAnimTask(cache.ped, 'mp_arrest_paired', 'crook_p2_back_left', 2.0)
end)

-- Escoltado e carregado (próprio jogador) ------------------------------------------

local function detachSelf()
    local ped = cache.ped
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    StopAnimTask(ped, 'anim@move_m@prisoner_cuffed', 'walk', -8.0)
    StopAnimTask(ped, 'anim@move_m@trash', 'run', -8.0)
    StopAnimTask(ped, 'nm', 'firemans_carry', -8.0)
end

local function followEscort(escorter)
    if escortThread then return end
    escortThread = true
    TriggerEvent('hospital:client:isEscorted', true)
    CreateThread(function()
        local walk, run = 'anim@move_m@prisoner_cuffed', 'anim@move_m@trash'
        Util.loadDict(walk)
        Util.loadDict(run)
        while LocalPlayer.state.isEscorted == escorter do
            local player = GetPlayerFromServerId(escorter)
            local ped = player ~= -1 and GetPlayerPed(player) or 0
            if ped == 0 then break end
            if not IsEntityAttachedToEntity(cache.ped, ped) then
                AttachEntityToEntity(cache.ped, ped, 11816, 0.38, 0.4, 0.0, 0.0, 0.0, 0.0, false, false, true, true, 2, true)
            end
            if IsPedWalking(ped) then
                if not IsEntityPlayingAnim(cache.ped, walk, 'walk', 3) then
                    TaskPlayAnim(cache.ped, walk, 'walk', 8.0, -8, -1, 1, 0.0, false, false, false)
                end
            elseif IsPedRunning(ped) or IsPedSprinting(ped) then
                if not IsEntityPlayingAnim(cache.ped, run, 'run', 3) then
                    TaskPlayAnim(cache.ped, run, 'run', 8.0, -8, -1, 1, 0.0, false, false, false)
                end
            else
                StopAnimTask(cache.ped, walk, 'walk', -8.0)
                StopAnimTask(cache.ped, run, 'run', -8.0)
            end
            Wait(0)
        end
        detachSelf()
        escortThread = false
        TriggerEvent('hospital:client:isEscorted', false)
    end)
end

local function followCarry(carrier)
    if carryThread then return end
    carryThread = true
    CreateThread(function()
        Util.loadDict('nm')
        while LocalPlayer.state.isCarried == carrier do
            local player = GetPlayerFromServerId(carrier)
            local ped = player ~= -1 and GetPlayerPed(player) or 0
            if ped == 0 then break end
            if not IsEntityAttachedToEntity(cache.ped, ped) then
                AttachEntityToEntity(cache.ped, ped, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
            end
            if not IsEntityPlayingAnim(cache.ped, 'nm', 'firemans_carry', 3) then
                TaskPlayAnim(cache.ped, 'nm', 'firemans_carry', 8.0, -8.0, -1, 33, 0, false, false, false)
            end
            Wait(250)
        end
        detachSelf()
        carryThread = false
    end)
end

-- O handler só agenda: nada de criar/apagar entidade dentro dele.
AddStateBagChangeHandler('isEscorted', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then SetTimeout(0, function() followEscort(value) end) end
end)

AddStateBagChangeHandler('isCarried', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then SetTimeout(0, function() followCarry(value) end) end
end)

RegisterNetEvent('noir_police:client:enterVehicle', function(netId, seat)
    if source ~= 65535 then return end
    warpingUntil = GetGameTimer() + 4000
    detachSelf()
    SetTimeout(750, function()
        if cache.vehicle then return end
        local vehicle = NetToVeh(netId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            TaskWarpPedIntoVehicle(cache.ped, vehicle, seat)
        end
    end)
end)

-- Ações de quem algema/escolta -----------------------------------------------------

local escortAnim = { dict = 'amb@world_human_drinking@coffee@female@base', name = 'base' }
local carryAnim = { dict = 'missfinale_c2mcs_1', name = 'fin_c2_mcs_1_camman' }

local function stopOwnAnim(anim)
    StopAnimTask(cache.ped, anim.dict, anim.name, 2.0)
end

RegisterNetEvent('noir_police:client:escortEnded', function()
    if source ~= 65535 then return end
    stopOwnAnim(escortAnim)
    LocalPlayer.state:set('blockHandsUp', false, false)
end)

RegisterNetEvent('noir_police:client:carryEnded', function()
    if source ~= 65535 then return end
    stopOwnAnim(carryAnim)
    LocalPlayer.state:set('blockHandsUp', false, false)
end)

local function report(result)
    if result and result.ok then return true end
    Integrations.notify(Util.errorText(result and result.code), 'error')
    return false
end

local function withBusy(fn)
    if actionBusy then return end
    actionBusy = true
    local ok, err = pcall(fn)
    actionBusy = false
    if not ok then lib.print.error(err) end
end

---@param target integer server id
---@param cuffType 'cuffs'|'zipties'
function Restraint.cuff(target, cuffType)
    withBusy(function()
        local ped = GetPlayerPed(GetPlayerFromServerId(target))
        local aggressive = Util.playerState(target, 'handsUp') ~= 'hu'
            and not IsPedDeadOrDying(ped, true)
        if aggressive then
            if Util.loadDict('mp_arrest_paired') then
                TaskPlayAnim(cache.ped, 'mp_arrest_paired', 'cop_p2_back_left', 8.0, -8.0, 4000, 33, 0, false, false, false)
            end
        elseif Util.loadDict('mp_arresting') then
            TaskPlayAnim(cache.ped, 'mp_arresting', 'a_uncuff', 5.0, 5.0, -1, 49, 0, false, false, false)
        end

        local result = lib.callback.await('noir_police:server:cuff', false, target, cuffType)
        stopOwnAnim({ dict = 'mp_arrest_paired', name = 'cop_p2_back_left' })
        stopOwnAnim({ dict = 'mp_arresting', name = 'a_uncuff' })
        if report(result) then playSound(cuffType == 'zipties' and 'zip' or 'cuff') end
    end)
end

---@param target integer
function Restraint.uncuff(target)
    withBusy(function()
        if Util.loadDict('mp_arresting') then
            TaskPlayAnim(cache.ped, 'mp_arresting', 'a_uncuff', 5.0, 5.0, -1, 49, 0, false, false, false)
        end
        Wait(1000)
        stopOwnAnim({ dict = 'mp_arresting', name = 'a_uncuff' })
        report(lib.callback.await('noir_police:server:uncuff', false, target))
    end)
end

---@param target integer
function Restraint.lockpick(target)
    withBusy(function()
        local start = lib.callback.await('noir_police:server:lockpickStart', false, target)
        if not report(start) then return end
        local progressed = lib.progressBar({
            duration = 8500,
            label = locale('progress.lockpicking'),
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 },
        })
        local success = progressed and lib.skillCheck({ 'medium', 'hard', 'hard' }, { 'w', 'a', 's', 'd' }) == true
        local result = lib.callback.await('noir_police:server:lockpickFinish', false, start.token, success)
        if report(result) then Integrations.notify(locale('success.lockpicked'), 'success') end
    end)
end

---@param target integer
function Restraint.escort(target)
    withBusy(function()
        local result = lib.callback.await('noir_police:server:escort', false, target)
        if not report(result) then return end
        if result.released then
            stopOwnAnim(escortAnim)
            LocalPlayer.state:set('blockHandsUp', false, false)
        elseif Util.loadDict(escortAnim.dict) then
            LocalPlayer.state:set('blockHandsUp', true, false)
            TaskPlayAnim(cache.ped, escortAnim.dict, escortAnim.name, 8.0, 8.0, -1, 50, 0, false, false, false)
        end
    end)
end

---@param target integer
function Restraint.carry(target)
    withBusy(function()
        local result = lib.callback.await('noir_police:server:carry', false, target)
        if not report(result) then return end
        if result.released then
            stopOwnAnim(carryAnim)
            LocalPlayer.state:set('blockHandsUp', false, false)
        elseif Util.loadDict(carryAnim.dict) then
            LocalPlayer.state:set('blockHandsUp', true, false)
            TaskPlayAnim(cache.ped, carryAnim.dict, carryAnim.name, 8.0, -8.0, -1, 49, 0, false, false, false)
        end
    end)
end

---Banco livre mais perto: traseiros primeiro, depois o do passageiro.
local function freeSeat(vehicle)
    local coords = GetEntityCoords(cache.ped)
    local best, bestDistance
    local bones = { [1] = 'seat_dside_r', [2] = 'seat_pside_r' }
    for seat, bone in pairs(bones) do
        local index = GetEntityBoneIndexByName(vehicle, bone)
        if index ~= -1 and IsVehicleSeatFree(vehicle, seat) then
            local distance = #(coords - GetWorldPositionOfEntityBone(vehicle, index))
            if not bestDistance or distance < bestDistance then best, bestDistance = seat, distance end
        end
    end
    if not best and IsVehicleSeatFree(vehicle, 0) then best = 0 end
    return best
end

function Restraint.putInVehicle()
    withBusy(function()
        local target = LocalPlayer.state.noirPoliceEscorting
        if not target then return end
        local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
        if not vehicle then return Integrations.notify(Util.errorText('no_vehicle'), 'error') end
        local seat = freeSeat(vehicle)
        if not seat then return Integrations.notify(Util.errorText('seat_taken'), 'error') end
        local result = lib.callback.await('noir_police:server:putInVehicle', false, target, VehToNet(vehicle), seat)
        if report(result) then
            stopOwnAnim(escortAnim)
            stopOwnAnim(carryAnim)
            LocalPlayer.state:set('blockHandsUp', false, false)
        end
    end)
end

---@param vehicle integer
function Restraint.putInTrunk(vehicle)
    withBusy(function()
        local target = LocalPlayer.state.noirPoliceEscorting
        if not target or not vehicle or vehicle == 0 then return end
        local result = lib.callback.await('noir_police:server:putInTrunk', false, target, VehToNet(vehicle))
        if report(result) then
            stopOwnAnim(carryAnim)
            LocalPlayer.state:set('blockHandsUp', false, false)
        end
    end)
end

---@param vehicle integer
---@param seat integer
function Restraint.takeOut(vehicle, seat)
    withBusy(function()
        local result = lib.callback.await('noir_police:server:takeOutOfVehicle', false, VehToNet(vehicle), seat)
        if report(result) and Util.loadDict(escortAnim.dict) then
            LocalPlayer.state:set('blockHandsUp', true, false)
            TaskPlayAnim(cache.ped, escortAnim.dict, escortAnim.name, 8.0, 8.0, -1, 50, 0, false, false, false)
        end
    end)
end

---Revista: a tela nativa do ox_inventory. O próprio ox decide se pode abrir.
---@param target integer
function Restraint.search(target)
    Integrations.openInventory('player', target)
end

-- Quem estou escoltando (só UX; espelha a resposta do servidor) ---------------------

local function escortingTarget()
    for _, playerId in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(playerId)
        local state = Player(serverId).state
        if state.isEscorted == cache.serverId or state.isCarried == cache.serverId then return serverId end
    end
end

-- Com alguém no ombro ou escoltado, o target do outro ped fica difícil de mirar: a
-- pílula mostra a tecla, e a tecla solta.
local shownKeys = nil
local keyLabels = { kneel = 'keys.get_up', carry = 'keys.put_down', escort = 'keys.release' }

refreshKeys = function()
    local target = LocalPlayer.state.noirPoliceEscorting
    local mode
    if handsUp == 'huk' and not cuffed then
        mode = 'kneel'
    elseif target then
        mode = Util.playerState(target, 'isCarried') == cache.serverId and 'carry' or 'escort'
    end
    if mode == shownKeys then return end
    shownKeys = mode
    if not mode then return Integrations.hideKeys() end
    Integrations.showKeys({ { key = Config.release.key, label = locale(keyLabels[mode]) } })
end

CreateThread(function()
    while true do
        local target = escortingTarget()
        if LocalPlayer.state.noirPoliceEscorting ~= target then
            LocalPlayer.state:set('noirPoliceEscorting', target, false)
        end
        refreshKeys()
        Wait(target and 500 or 1500)
    end
end)

lib.addKeybind({
    name = 'noir_police_release',
    description = locale('keybind.release'),
    defaultKey = Config.release.key,
    onPressed = function()
        -- Ajoelhado em rendição: o J é o único jeito de levantar.
        if handsUp == 'huk' then return setHandsUp(false) end
        local target = LocalPlayer.state.noirPoliceEscorting
        if not target then return end
        if Util.playerState(target, 'isCarried') == cache.serverId then
            Restraint.carry(target)
        else
            Restraint.escort(target)
        end
    end,
})

-- Targets --------------------------------------------------------------------------

local function targetId(entity) return Util.serverIdFromPed(entity) end

local function isDowned(entity) return IsPedDeadOrDying(entity, true) or IsPedFatallyInjured(entity) end

local function isOnDutyPolice() return Departments.isOnDutyPolice(Integrations.getJob()) end

Integrations.addGlobalPlayer({
    {
        name = 'noir_police:restraint:cuff',
        icon = 'fas fa-handcuffs',
        label = locale('target.cuff'),
        distance = Config.cuffs.interactDistance,
        items = Config.items.cuffs,
        canInteract = function(entity)
            local id = targetId(entity)
            return id and not cuffed and not Util.isCuffed(id)
                and (Util.playerState(id, 'handsUp') or isDowned(entity) or isOnDutyPolice())
        end,
        onSelect = function(data) Restraint.cuff(targetId(data.entity), 'cuffs') end,
    },
    {
        name = 'noir_police:restraint:ziptie',
        icon = 'fas fa-link',
        label = locale('target.ziptie'),
        distance = Config.cuffs.interactDistance,
        items = Config.items.zipties,
        canInteract = function(entity)
            local id = targetId(entity)
            return id and not cuffed and not Util.isCuffed(id)
                and (Util.playerState(id, 'handsUp') or isDowned(entity))
        end,
        onSelect = function(data) Restraint.cuff(targetId(data.entity), 'zipties') end,
    },
    {
        name = 'noir_police:restraint:uncuff',
        icon = 'fas fa-key',
        label = locale('target.uncuff'),
        distance = Config.cuffs.interactDistance,
        items = Config.items.cuffKey,
        canInteract = function(entity)
            local id = targetId(entity)
            return id and not cuffed and Util.playerState(id, 'cuffType') == 'cuffs'
        end,
        onSelect = function(data) Restraint.uncuff(targetId(data.entity)) end,
    },
    {
        name = 'noir_police:restraint:cut',
        icon = 'fas fa-scissors',
        label = locale('target.cut_ziptie'),
        distance = Config.cuffs.interactDistance,
        items = Config.items.cutters,
        canInteract = function(entity)
            local id = targetId(entity)
            return id and not cuffed and Util.playerState(id, 'cuffType') == 'zipties'
        end,
        onSelect = function(data) Restraint.uncuff(targetId(data.entity)) end,
    },
    {
        name = 'noir_police:restraint:lockpick',
        icon = 'fas fa-unlock',
        label = locale('target.lockpick_cuffs'),
        distance = Config.cuffs.interactDistance,
        items = Config.cuffs.lockpickItem,
        canInteract = function(entity)
            local id = targetId(entity)
            return id and not cuffed and Util.playerState(id, 'cuffType') == 'cuffs' and not isOnDutyPolice()
        end,
        onSelect = function(data) Restraint.lockpick(targetId(data.entity)) end,
    },
    {
        name = 'noir_police:restraint:escort',
        icon = 'fas fa-hands-bound',
        label = locale('target.escort'),
        distance = Config.cuffs.interactDistance,
        canInteract = function(entity)
            local id = targetId(entity)
            if not id or cuffed or LocalPlayer.state.noirPoliceEscorting then return false end
            if Util.playerState(id, 'isEscorted') or Util.playerState(id, 'isCarried') then return false end
            return Util.isCuffed(id) or isDowned(entity)
        end,
        onSelect = function(data) Restraint.escort(targetId(data.entity)) end,
    },
    {
        name = 'noir_police:restraint:release',
        icon = 'fas fa-hand',
        label = locale('target.release'),
        distance = Config.cuffs.interactDistance,
        canInteract = function(entity)
            local id = targetId(entity)
            return id and Util.playerState(id, 'isEscorted') == cache.serverId
        end,
        onSelect = function(data) Restraint.escort(targetId(data.entity)) end,
    },
    {
        name = 'noir_police:restraint:carry',
        icon = 'fas fa-person-carry-box',
        label = locale('target.carry'),
        distance = Config.cuffs.interactDistance,
        canInteract = function(entity)
            local id = targetId(entity)
            if not id or cuffed or LocalPlayer.state.noirPoliceEscorting then return false end
            if Util.playerState(id, 'isEscorted') or Util.playerState(id, 'isCarried') then return false end
            return Util.isCuffed(id) or isDowned(entity)
        end,
        onSelect = function(data) Restraint.carry(targetId(data.entity)) end,
    },
    {
        name = 'noir_police:restraint:drop',
        icon = 'fas fa-person-falling',
        label = locale('target.put_down'),
        distance = Config.cuffs.interactDistance,
        canInteract = function(entity)
            local id = targetId(entity)
            return id and Util.playerState(id, 'isCarried') == cache.serverId
        end,
        onSelect = function(data) Restraint.carry(targetId(data.entity)) end,
    },
    {
        name = 'noir_police:restraint:search',
        icon = 'fas fa-magnifying-glass',
        label = locale('target.search'),
        distance = Config.cuffs.interactDistance,
        canInteract = function(entity)
            local id = targetId(entity)
            if not id or cuffed or handsUp then return false end
            if isOnDutyPolice() then return true end
            return Util.isCuffed(id) or Util.playerState(id, 'handsUp') or isDowned(entity)
        end,
        onSelect = function(data) Restraint.search(targetId(data.entity)) end,
    },
})

Integrations.addGlobalVehicle({
    {
        name = 'noir_police:restraint:putInTrunk',
        icon = 'fa-solid fa-car-rear',
        label = locale('target.put_in_trunk'),
        distance = 2.5,
        bones = { 'boot' },
        canInteract = function()
            local target = LocalPlayer.state.noirPoliceEscorting
            return target ~= nil and Util.playerState(target, 'isCarried') == cache.serverId
        end,
        onSelect = function(data) Restraint.putInTrunk(data.entity) end,
    },
    {
        name = 'noir_police:restraint:takeOutOfTrunk',
        icon = 'fa-solid fa-car-rear',
        label = locale('target.take_out_of_trunk'),
        distance = 2.5,
        bones = { 'boot' },
        canInteract = function(entity)
            return not cuffed and Entity(entity).state.noirTrunk ~= nil
                and not LocalPlayer.state.noirPoliceEscorting
        end,
        onSelect = function(data)
            local result = lib.callback.await('noir_police:server:takeOutOfTrunk', false, VehToNet(data.entity))
            report(result)
        end,
    },
    {
        name = 'noir_police:restraint:putInVehicle',
        icon = 'fa-solid fa-right-to-bracket',
        label = locale('target.put_in_vehicle'),
        distance = 3.0,
        canInteract = function() return LocalPlayer.state.noirPoliceEscorting ~= nil end,
        onSelect = function() Restraint.putInVehicle() end,
    },
    {
        name = 'noir_police:restraint:takeOutLeft',
        icon = 'fa-solid fa-right-from-bracket',
        label = locale('target.take_out_vehicle'),
        distance = 2.0,
        bones = { 'seat_dside_r' },
        canInteract = function(entity)
            local ped = GetPedInVehicleSeat(entity, 1)
            local id = Util.serverIdFromPed(ped)
            return id and not cuffed and (Util.isCuffed(id) or isDowned(ped))
        end,
        onSelect = function(data) Restraint.takeOut(data.entity, 1) end,
    },
    {
        name = 'noir_police:restraint:takeOutRight',
        icon = 'fa-solid fa-right-from-bracket',
        label = locale('target.take_out_vehicle'),
        distance = 2.0,
        bones = { 'seat_pside_r' },
        canInteract = function(entity)
            local ped = GetPedInVehicleSeat(entity, 2)
            local id = Util.serverIdFromPed(ped)
            return id and not cuffed and (Util.isCuffed(id) or isDowned(ped))
        end,
        onSelect = function(data) Restraint.takeOut(data.entity, 2) end,
    },
    {
        name = 'noir_police:restraint:takeOutFront',
        icon = 'fa-solid fa-right-from-bracket',
        label = locale('target.take_out_vehicle'),
        distance = 2.0,
        bones = { 'seat_pside_f' },
        canInteract = function(entity)
            local ped = GetPedInVehicleSeat(entity, 0)
            local id = Util.serverIdFromPed(ped)
            return id and not cuffed and (Util.isCuffed(id) or isDowned(ped))
        end,
        onSelect = function(data) Restraint.takeOut(data.entity, 0) end,
    },
})

-- Itens (ox_inventory chama estes exports) ------------------------------------------

local function nearestTarget()
    local id = Util.closestPlayer(Config.cuffs.interactDistance)
    if not id then Integrations.notify(Util.errorText('no_target'), 'error') end
    return id
end

exports('useCuffs', function()
    if cache.vehicle then return end
    local id = nearestTarget()
    if id then Restraint.cuff(id, 'cuffs') end
end)

exports('useZipties', function()
    if cache.vehicle then return end
    local id = nearestTarget()
    if id then Restraint.cuff(id, 'zipties') end
end)

exports('useCuffKey', function()
    if cache.vehicle then return end
    local id = nearestTarget()
    if id then Restraint.uncuff(id) end
end)

exports('useCutters', function()
    if cache.vehicle then return end
    local id = nearestTarget()
    if id then Restraint.uncuff(id) end
end)

-- Radial (qbx_radialmenu chama estes eventos locais) --------------------------------

local function jail(id)
    if not isOnDutyPolice() then return Integrations.notify(Util.errorText('not_police'), 'error') end
    if not Util.isCuffed(id) then return Integrations.notify(Util.errorText('not_cuffed'), 'error') end
    local input = lib.inputDialog(locale('jail.title'), {
        { type = 'number', label = locale('jail.months'), required = true, min = 1, max = 120 },
    })
    if not input then return end
    Integrations.jail(id, math.floor(input[1]))
end

local radialActions = {
    cuff = function(id) Restraint.cuff(id, Integrations.itemCount(Config.items.cuffs) > 0 and 'cuffs' or 'zipties') end,
    escort = function(id) Restraint.escort(id) end,
    carry = function(id) Restraint.carry(id) end,
    search = function(id) Restraint.search(id) end,
    rob = function() Integrations.openNearbyInventory() end,
    jail = jail,
}

AddEventHandler('noir_police:client:radial', function(action)
    if cuffed then return end
    if action == 'putInVehicle' then return Restraint.putInVehicle() end
    if action == 'putInTrunk' then
        local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
        if not vehicle then return Integrations.notify(Util.errorText('no_vehicle'), 'error') end
        return Restraint.putInTrunk(vehicle)
    end
    if action == 'takeOutVehicle' then
        local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 4.0, false)
        if not vehicle then return Integrations.notify(Util.errorText('no_vehicle'), 'error') end
        for _, seat in ipairs({ 1, 2, 0 }) do
            local ped = GetPedInVehicleSeat(vehicle, seat)
            if ped ~= 0 and IsPedAPlayer(ped) then return Restraint.takeOut(vehicle, seat) end
        end
        return Integrations.notify(Util.errorText('seat_empty'), 'error')
    end
    local fn = radialActions[action]
    if not fn then return end
    if action == 'rob' then return fn() end
    local id = nearestTarget()
    if id then fn(id) end
end)

-- API ------------------------------------------------------------------------------

exports('IsHandcuffed', function() return cuffed end)

---Reaplica o visual se o resource reiniciar com o jogador algemado.
CreateThread(function()
    if LocalPlayer.state.isCuffed then
        setCuffed(true, LocalPlayer.state.cuffType or 'cuffs', LocalPlayer.state.cuffAngle or 'back')
    end
    if LocalPlayer.state.isEscorted then followEscort(LocalPlayer.state.isEscorted) end
    if LocalPlayer.state.isCarried then followCarry(LocalPlayer.state.isCarried) end
    if LocalPlayer.state.handsUp then LocalPlayer.state:set('handsUp', false, true) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if shownKeys then Integrations.hideKeys() end
    deleteCuffProp()
    detachSelf()
    if handsUp then stopHandsUp() end
    LocalPlayer.state:set('handsUp', false, true)
    Integrations.disableTargeting(false)
end)

AddEventHandler('bgrz_core:client:playerUnloaded', function()
    if handsUp then setHandsUp(false, true) end
    setCuffed(false)
end)

return Restraint
