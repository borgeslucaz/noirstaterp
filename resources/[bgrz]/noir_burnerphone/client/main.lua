local isOpen = false
local isOpening = false
local activeAnimDict
local activeAnimName = 'cellphone_text_read_base'
local readFlags = 1 | 8 | 16 | 32
local phoneDisabled = false
local inputThreadRunning = false
local nextAvailabilityCheck = 0

local function notify(message, kind)
    lib.notify({ description = message, type = kind or 'inform' })
end

local function playPhoneAnimation()
    local ped = PlayerPedId()
    local animDict = IsPedInAnyVehicle(ped, true) and 'cellphone@in_car@ds' or 'cellphone@'

    CreateThread(function()
        RequestAnimDict(animDict)
        local timeout = GetGameTimer() + 1000
        while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do Wait(0) end
        if not isOpen or not HasAnimDictLoaded(animDict) then return end

        TaskPlayAnim(PlayerPedId(), animDict, activeAnimName, 8.0, -8.0, -1,
            readFlags, 0.0, false, false, false)
        activeAnimDict = animDict
        RemoveAnimDict(animDict)
    end)
end

local function stopPhoneAnimation()
    if not activeAnimDict then return end
    StopAnimTask(PlayerPedId(), activeAnimDict, activeAnimName, 1.0)
    activeAnimDict = nil
end

local function closeBurnerPhone()
    local wasOpen = isOpen
    isOpen = false
    isOpening = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'burner:close' })
    stopPhoneAnimation()
    if wasOpen then TriggerEvent('noir_burnerphone:client:openState', false) end
end

local function startInputThread()
    if inputThreadRunning then return end
    inputThreadRunning = true
    CreateThread(function()
        while isOpen do
            if GetGameTimer() >= nextAvailabilityCheck and GetResourceState('sd-phone') == 'started' then
                nextAvailabilityCheck = GetGameTimer() + 500
                local ok, disabled = pcall(function() return exports['sd-phone']:isDisabled() end)
                if ok and disabled then closeBurnerPhone() break end
            end

            local ped = PlayerPedId()
            if IsPauseMenuActive()
                or (BurnerPhoneConfig.blockWhileDead and IsEntityDead(ped))
                or (BurnerPhoneConfig.blockWhileSwimming and IsPedSwimming(ped)) then
                closeBurnerPhone()
                break
            end

            if BurnerPhoneConfig.allowMovement then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 37, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
                DisablePlayerFiring(PlayerId(), true)
            end
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        end
        inputThreadRunning = false
    end)
end

local function openBurnerPhone()
    if isOpen or isOpening then return end
    if not BurnerPhoneConfig.enabled or phoneDisabled then
        notify('Você não pode usar o burner phone agora.', 'error')
        return
    end

    local ped = PlayerPedId()
    if BurnerPhoneConfig.blockWhileDead and IsEntityDead(ped) then
        notify('Você não pode usar o telefone desacordado.', 'error')
        return
    end
    if BurnerPhoneConfig.blockWhileSwimming and IsPedSwimming(ped) then
        notify('Você não pode usar o telefone enquanto nada.', 'error')
        return
    end

    isOpening = true
    local payload, reason = lib.callback.await('noir_burnerphone:server:getState', false)
    isOpening = false
    if not payload then
        notify(reason == 'missing_phone' and 'Você precisa ter um burner phone no bolso.'
            or 'Não foi possível acessar o burner phone agora.', 'error')
        return
    end
    if exports.ox_inventory:GetItemCount(BurnerPhoneConfig.itemName) < 1 then
        notify('Você precisa ter um burner phone no bolso.', 'error')
        return
    end

    if GetResourceState('sd-phone') == 'started' then
        local disabledOk, disabled = pcall(function() return exports['sd-phone']:isDisabled() end)
        if disabledOk and disabled then
            notify('Você não pode usar o telefone agora.', 'error')
            return
        end
        local openOk, regularOpen = pcall(function() return exports['sd-phone']:isOpen() end)
        if openOk and regularOpen then pcall(function() exports['sd-phone']:close() end) end
    end

    isOpen = true
    playPhoneAnimation()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(BurnerPhoneConfig.allowMovement == true)
    startInputThread()
    SendNUIMessage({
        action = 'burner:open',
        state = payload.state,
        activities = payload.activities,
        contracts = payload.contracts,
    })
    TriggerEvent('noir_burnerphone:client:openState', true)
end

local function toggleBurnerPhone()
    if isOpen then closeBurnerPhone() else openBurnerPhone() end
end

exports('useDevice', toggleBurnerPhone)
exports('open', openBurnerPhone)
exports('close', closeBurnerPhone)
exports('isOpen', function() return isOpen end)
exports('isDisabled', function() return phoneDisabled end)
exports('setDisabled', function(disabled)
    phoneDisabled = disabled == true
    if phoneDisabled then closeBurnerPhone() end
end)

RegisterNUICallback('ready', function(_, cb)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if isOpen then
        isOpen = false
        openBurnerPhone()
    else
        SendNUIMessage({ action = 'burner:close' })
    end
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeBurnerPhone()
    cb({ ok = true })
end)

RegisterNUICallback('startActivity', function(data, cb)
    local activityId = type(data) == 'table' and data.id or nil
    if not isOpen or type(activityId) ~= 'string' then cb({ ok = false }) return end

    local authorized = lib.callback.await('noir_burnerphone:server:authorizeActivity', false, activityId)
    if not authorized then
        notify('Essa atividade não está disponível.', 'error')
        cb({ ok = false })
        return
    end

    if activityId == 'drugSales' then
        if GetResourceState('op-drugselling') ~= 'started' then
            notify('Esse canal está indisponível.', 'error')
            cb({ ok = false })
            return
        end
        closeBurnerPhone()
        ExecuteCommand('venderdrogas')
        cb({ ok = true })
        return
    end

    cb({ ok = false })
end)

-- Contracts: the NUI only ever sees the snapshot the server produced. Every
-- action goes server -> provider and returns a fresh snapshot on success.
RegisterNUICallback('loadContracts', function(_, cb)
    if not isOpen then cb({ ok = false }) return end
    local contracts = lib.callback.await('noir_burnerphone:server:getContracts', false)
    cb({ ok = contracts ~= nil, contracts = contracts })
end)

local function contractAction(action)
    return function(data, cb)
        local contractId = type(data) == 'table' and data.id or nil
        if not isOpen or type(contractId) ~= 'string' then cb({ ok = false, error = 'Ação inválida.' }) return end

        local ok, payload = lib.callback.await('noir_burnerphone:server:contractAction', false, action, contractId)
        if not ok then
            cb({ ok = false, error = type(payload) == 'string' and payload or 'Não foi possível concluir a ação.' })
            return
        end
        cb({ ok = true, contracts = payload })
    end
end

RegisterNUICallback('acceptContract', contractAction('accept'))
RegisterNUICallback('resumeContract', contractAction('resume'))
RegisterNUICallback('abandonContract', contractAction('abandon'))

RegisterNetEvent('noir_burnerphone:client:contractsChanged', function(contracts)
    if not isOpen or type(contracts) ~= 'table' then return end
    SendNUIMessage({ action = 'burner:contracts', contracts = contracts })
end)

CreateThread(function()
    Wait(250)
    closeBurnerPhone()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', closeBurnerPhone)
RegisterNetEvent('qbx_core:client:playerLoggedOut', closeBurnerPhone)

RegisterNetEvent('noir_burnerphone:client:stateUpdated', function(payload)
    if not isOpen or type(payload) ~= 'table' then return end
    SendNUIMessage({
        action = 'burner:state',
        state = payload.state,
        activities = payload.activities,
    })
end)

AddEventHandler('ox_inventory:updateInventory', function()
    if isOpen and exports.ox_inventory:GetItemCount(BurnerPhoneConfig.itemName) < 1 then
        closeBurnerPhone()
        notify('O burner phone não está mais no seu bolso.', 'error')
    end
end)

AddEventHandler('sd-phone:client:openState', function(open)
    if open and isOpen then closeBurnerPhone() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeBurnerPhone() end
end)
