local display = false

local first = vector3(60.93, -945.21, 29.81)
local second = vector3(60.93, -945.21, 38.34)
local third = vector3(60.93, -945.21, 46.88)
local forth = vector3(60.93, -945.21, 55.42)
local fifth = vector3(60.93, -945.21, 63.96)
local sixth = vector3(60.93, -945.21, 72.51)

RegisterNUICallback("exit", function(data)
    SetDisplay(false)
end)

RegisterNUICallback("floor1", function()
    SetEntityCoords(GetPlayerPed(-1), first)
    SetDisplay(false)
end)

RegisterNUICallback("floor2", function()
    SetEntityCoords(GetPlayerPed(-1), second)
    SetDisplay(false)
end)

RegisterNUICallback("floor3", function()
    SetEntityCoords(GetPlayerPed(-1), third)
    SetDisplay(false)
end)

RegisterNUICallback("floor4", function()
    SetEntityCoords(GetPlayerPed(-1), forth)
    SetDisplay(false)
end)

RegisterNUICallback("floor5", function()
    SetEntityCoords(GetPlayerPed(-1), fifth)
    SetDisplay(false)
end)

RegisterNUICallback("floor6", function()
    SetEntityCoords(GetPlayerPed(-1), sixth)
    SetDisplay(false)
end)

function SetDisplay(bool)
    display = bool
    SetNuiFocus(bool, bool)
    SendNUIMessage({
        type = "ui",
        status = bool,
    })
end

Citizen.CreateThread(function()
    while display do
        Citizen.Wait(0)
        DisableControlAction(0, 1, display)
        DisableControlAction(0, 2, display)
        DisableControlAction(0, 142, display)
        DisableControlAction(0, 18, display)
        DisableControlAction(0, 322, display)
        DisableControlAction(0, 106, display)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        coords = GetEntityCoords(GetPlayerPed(-1))
        if GetDistanceBetweenCoords(coords, first) < 1 then
            SetTextComponentFormat("STRING")
            AddTextComponentString("Press ~INPUT_CONTEXT~ to open menu")
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)
            if IsControlJustPressed(0, 38) then
                SetDisplay(not display)
            end
        end
    end
end)