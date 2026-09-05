CreateThread(function()
    for k,v in pairs(Config.CabLocations) do
        CORE:SafeRequestModel(v.PedModel, 5000)
        local ped = CreatePed(4, v.PedModel, v.AccesCoord.x, v.AccesCoord.y, v.AccesCoord.z - 1.0, 0.0, false, true)
        SetEntityHeading(ped, v.AccesCoord.w)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 17, true)
        SetPedCanBeTargetted(ped, false)
        SetEntityInvincible(ped, true)
        SetPedCanBeDraggedOut(ped, false)
        SetPedCanRagdoll(ped, false)
        SetCanAttackFriendly(ped, false, false)
        if Config.Interaction == "target" then
            exports["ox_target"]:addBoxZone({
                coords = vec3(v.AccesCoord.x, v.AccesCoord.y, v.AccesCoord.z),
                size = vec3(1, 1, 1),
                drawSprite = true,
                options = {
                    {
                        name = "taxi_job" .. k,
                        label = Config.locales[Config.Locale].ui.open_taxi_menu,
                        icon = "fa-solid fa-atom",
                        canInteract = function()
                            local srvId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(PlayerPedId()))
                            if Player(srvId).state["qbx_medical:deathState"] == 3 or Player(srvId).state["qbx_medical:deathState"] == 2 then return false end
                            return true
                        end,
                        onSelect = function()
                            TriggerEvent('ak4y-taxi:Open')
                        end,
                    }
                }
            })
        end
    end
end)

GiveVehicleKeys = function(plate, model)
    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
end

PathTaken = function(distance)
end

SatisfiedTrip = function()
end

DissatisfiedTrip = function()
    
end

FinishJob = function()
end

EarnedMoney = function(money)
end

function SetFuelFunction(veh)
    SetVehicleFuelLevel(veh, 100.0)
end