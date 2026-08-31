-- Minimal lifecycle following sd-phone's order: acquire focus, show its NUI;
-- on close, release focus before hiding the NUI.
local isOpen = false
local activeAnimDict
local activeAnimName = 'cellphone_text_read_base'
local readFlags = 1 | 8 | 16 | 32

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
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'burner:close' })
    stopPhoneAnimation()
end

local function openBurnerPhone()
    if isOpen then return end

    isOpen = true
    playPhoneAnimation()
    SetNuiFocus(true, true)
    -- This test UI does not support movement while open, so game input is not
    -- forwarded and cannot contend with another focused NUI.
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'burner:open' })
end

-- ox_inventory item client.export = 'noir_burnerphone.useDevice'.
exports('useDevice', openBurnerPhone)

RegisterNUICallback('close', function(_, cb)
    closeBurnerPhone()
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

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeBurnerPhone() end
end)
