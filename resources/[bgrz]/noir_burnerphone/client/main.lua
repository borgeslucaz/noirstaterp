-- Minimal lifecycle following sd-phone's order: acquire focus, show its NUI;
-- on close, release focus before hiding the NUI.
local isOpen = false
local activeAnimDict
local activeAnimName = 'cellphone_text_read_base'
local readFlags = 1 | 8 | 16 | 32
local messages = {}
local phoneDisabled = false
local inputThreadRunning = false
local nextAvailabilityCheck = 0
local typingInPhone = false

local function playPhoneAnimation()
    local ped = PlayerPedId()
    local animDict = IsPedInAnyVehicle(ped, true) and 'cellphone@in_car@ds' or 'cellphone@'

    CreateThread(function()
        RequestAnimDict(animDict)
        local timeout = GetGameTimer() + 1000

        while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do
            Wait(0)
        end

        if not isOpen or not HasAnimDictLoaded(animDict) then return end

        local currentPed = PlayerPedId()
        TaskPlayAnim(currentPed, animDict, activeAnimName, 8.0, -8.0, -1, readFlags, 0.0, false, false, false)
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
    typingInPhone = false
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
                if ok and disabled then
                    closeBurnerPhone()
                    break
                end
            end

            if IsPauseMenuActive()
                or (BurnerPhoneConfig.blockWhileDead and IsEntityDead(PlayerPedId()))
                or (BurnerPhoneConfig.blockWhileSwimming and IsPedSwimming(PlayerPedId())) then
                closeBurnerPhone()
                break
            end

            if typingInPhone then
                DisableControlAction(0, 19, true)  -- Left Alt / targeting
                DisableControlAction(0, 30, true)  -- left/right
                DisableControlAction(0, 31, true)  -- forward/back
                DisableControlAction(0, 32, true)  -- W
                DisableControlAction(0, 33, true)  -- S
                DisableControlAction(0, 34, true)  -- A
                DisableControlAction(0, 35, true)  -- D
                DisableControlAction(0, 44, true)  -- cover
                DisableControlAction(0, 245, true) -- chat / T
                DisableControlAction(0, 249, true) -- push-to-talk
            elseif BurnerPhoneConfig.allowMovement then
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
    if isOpen then return end

    if not BurnerPhoneConfig.enabled or phoneDisabled then
        lib.notify({ description = 'Você não pode usar o burner phone agora.', type = 'error' })
        return
    end

    local ped = PlayerPedId()
    if BurnerPhoneConfig.blockWhileDead and IsEntityDead(ped) then
        lib.notify({ description = 'Você não pode usar o telefone desacordado.', type = 'error' })
        return
    end
    if BurnerPhoneConfig.blockWhileSwimming and IsPedSwimming(ped) then
        lib.notify({ description = 'Você não pode usar o telefone enquanto nada.', type = 'error' })
        return
    end

    if GetResourceState('sd-phone') == 'started' then
        local disabledOk, disabled = pcall(function() return exports['sd-phone']:isDisabled() end)
        if disabledOk and disabled then
            lib.notify({ description = 'Você não pode usar o telefone agora.', type = 'error' })
            return
        end
        local openOk, regularOpen = pcall(function() return exports['sd-phone']:isOpen() end)
        if openOk and regularOpen then pcall(function() exports['sd-phone']:close() end) end
    end

    isOpen = true
    typingInPhone = false
    playPhoneAnimation()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(BurnerPhoneConfig.allowMovement == true)
    startInputThread()
    SendNUIMessage({
        action = 'burner:open',
        messages = messages,
        contact = BurnerPhoneConfig.houseRobberyContact,
        contractsEnabled = BurnerPhoneConfig.activities.contracts,
    })
    TriggerEvent('noir_burnerphone:client:openState', true)
end

-- ox_inventory item client.export = 'noir_burnerphone.useDevice'.
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

RegisterNUICallback('typing', function(data, cb)
    typingInPhone = isOpen and type(data) == 'table' and data.active == true
    if isOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(BurnerPhoneConfig.allowMovement == true and not typingInPhone)
    end
    cb({ ok = true })
end)

RegisterNUICallback('startStreetSale', function(_, cb)
    closeBurnerPhone()

    if GetResourceState('op-drugselling') ~= 'started' then
        cb({ ok = false, error = 'op-drugselling indisponível' })
        return
    end

    -- Uses the exact same entry point as /venderdrogas, preserving the
    -- existing sale state, cooldown and nearby-ped behaviour.
    ExecuteCommand('venderdrogas')
    cb({ ok = true })
end)

RegisterNUICallback('sendHouseMessage', function(data, cb)
    local message = type(data) == 'table' and data.message or nil
    if type(message) ~= 'string' or message == '' then cb({ ok = false }) return end
    messages[#messages + 1] = { outgoing = true, message = message, timestamp = GetGameTimer() }
    TriggerServerEvent('noir_burnerphone:server:sendHouseMessage', message)
    cb({ ok = true })
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    local location = type(data) == 'table' and data.location or nil
    if location and tonumber(location.x) and tonumber(location.y) then
        SetNewWaypoint(tonumber(location.x), tonumber(location.y))
        cb({ ok = true })
        return
    end
    cb({ ok = false })
end)

RegisterNetEvent('noir_burnerphone:client:contactMessage', function(data)
    if type(data) ~= 'table' or type(data.message) ~= 'string' then return end
    messages[#messages + 1] = data
    SendNUIMessage({ action = 'burner:message', message = data })
    if data.location then
        SetNewWaypoint(data.location.x + 0.0, data.location.y + 0.0)
        lib.notify({ description = 'Nova localização recebida no burner phone.', type = 'success' })
    end
end)

-- A client resource can survive character logout while its NUI and focus remain
-- active. Always reset both sides of the state during startup and logout.
CreateThread(function()
    Wait(250)
    closeBurnerPhone()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', closeBurnerPhone)
RegisterNetEvent('qbx_core:client:playerLoggedOut', closeBurnerPhone)

AddEventHandler('sd-phone:client:openState', function(open)
    if open and isOpen then closeBurnerPhone() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeBurnerPhone() end
end)
