local isUIOpen         = false
local inTaxi           = false
local currentTaxiId    = nil
local waypointSelected = false
local waypointCoords   = nil
local kickedFromTaxi   = false
local kickTime         = 0
local waypointTimer    = nil
local exitTimer        = nil
local activeTaxiBlips  = {}
local QBCore           = nil
local ESX              = nil

Citizen.CreateThread(function()
    if Config.Framework == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == "esx" then
        ESX = exports["es_extended"]:getSharedObject()
    end
end)

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    CreateTaxiZones()
    TriggerServerEvent('rd-taxi:server:requestTaxiData')
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if IsInTaxiZone() and not isUIOpen and not inTaxi then
            if not IsPlayerKicked() then
                DisplayHelpText(L("HELP_PRESS_TO_OPEN"))

                if IsControlJustReleased(0, 38) then  
                    OpenTaxiUI()
                end
            else
                local remaining = GetRemainingCooldown()
                DisplayHelpText(L("HELP_ON_COOLDOWN", remaining))
            end
        else
            Citizen.Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if inTaxi and not waypointSelected then
            local playerPed = PlayerPedId()

            
            if not IsPedInAnyVehicle(playerPed, false) then
                local taxiIdToSend = currentTaxiId

                if taxiIdToSend then
                    
                    LockTaxiById(taxiIdToSend, true)
                end

                inTaxi           = false
                waypointSelected = false
                ClearTimers()

                if taxiIdToSend then
                    TriggerServerEvent('rd-taxi:server:playerExitedTaxi', taxiIdToSend)
                    currentTaxiId = nil
                end

                Citizen.Wait(500)
            else
                
                if IsWaypointActive() then
                    local waypoint = GetFirstBlipInfoId(8)
                    if DoesBlipExist(waypoint) then
                        local coords = GetBlipInfoIdCoord(waypoint)

                        
                        local foundGround, groundZ = GetGroundZFor_3dCoord(
                            coords.x, coords.y, coords.z + 500.0, false
                        )
                        if foundGround then
                            coords = vector3(coords.x, coords.y, groundZ + 1.0)
                        else
                            coords = vector3(coords.x, coords.y, 30.0)
                        end

                        ShowWaypointConfirmation(coords)
                        Citizen.Wait(5000)   
                    end
                end

                Citizen.Wait(200)
            end
        else
            Citizen.Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local playerPed = PlayerPedId()

        if not inTaxi and not IsPedInAnyVehicle(playerPed, false) then
            if IsControlJustReleased(0, 47) then  
                local coords = GetEntityCoords(playerPed)

                for vehicle in EnumerateVehicles() do
                    local plate = GetVehicleNumberPlateText(vehicle)

                    if string.find(plate, "TAXI") then
                        local vehCoords = GetEntityCoords(vehicle)
                        local distance  = #(coords - vehCoords)

                        if distance < 5.0 then
                            local taxiIdFromPlate = tonumber(string.match(plate, "TAXI(%d+)"))

                            
                            if taxiIdFromPlate and taxiIdFromPlate == currentTaxiId then
                                
                                SetVehicleDoorsLocked(vehicle, 1)
                                SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
                                for i = 0, 5 do
                                    SetVehicleIndividualDoorsLocked(vehicle, i, 0)
                                end

                                TaskEnterVehicle(playerPed, vehicle, 10000, 1, 1.5, 1, 0)

                                TriggerEvent('chat:addMessage', {
                                    color = {138, 43, 226},
                                    args  = {"Taxi", "Entering your reserved taxi..."}
                                })
                            else
                                TriggerEvent('chat:addMessage', {
                                    color = {255, 80, 80},
                                    args  = {"Taxi", "This taxi is not reserved for you."}
                                })
                            end

                            break
                        end
                    end
                end
            end
        else
            Citizen.Wait(200)
        end
    end
end)

RegisterNetEvent('rd-taxi:client:spawnTaxi')
AddEventHandler('rd-taxi:client:spawnTaxi', function(taxiId, driver, spawn)
    Citizen.CreateThread(function()
        local vehicleHash = GetHashKey(driver.vehicleModel)
        local pedHash     = GetHashKey(driver.pedModel)

        
        RequestModel(vehicleHash)
        RequestModel(pedHash)
        local timeout = 0
        while (not HasModelLoaded(vehicleHash) or not HasModelLoaded(pedHash)) and timeout < 100 do
            Citizen.Wait(100)
            timeout = timeout + 1
        end

        if not HasModelLoaded(vehicleHash) or not HasModelLoaded(pedHash) then
            print("[RD-Taxi] ERROR: models failed to load for driver " .. driver.name)
            return
        end

        
        local vehicle = CreateVehicle(vehicleHash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
        timeout = 0
        while not DoesEntityExist(vehicle) and timeout < 50 do
            Citizen.Wait(100)
            timeout = timeout + 1
        end
        if not DoesEntityExist(vehicle) then
            print("[RD-Taxi] ERROR: vehicle entity failed to create for driver " .. driver.name)
            return
        end

        
        SetEntityVisible(vehicle, false, false)
        SetEntityAlpha(vehicle, 0, false)
        FreezeEntityPosition(vehicle, true)

        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleEngineOn(vehicle, false, false, false)

        
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)

        SetVehicleColours(vehicle, 1, 1)
        SetVehicleNumberPlateText(vehicle, "TAXI" .. taxiId)

        
        SetEntityInvincible(vehicle, true)
        SetEntityProofs(vehicle, true, true, true, true, true, true, true, true)
        SetVehicleCanBeVisiblyDamaged(vehicle, false)
        SetVehicleCanBreak(vehicle, false)
        SetVehicleTyresCanBurst(vehicle, false)
        SetVehicleWheelsCanBreak(vehicle, false)
        SetVehicleStrong(vehicle, true)
        SetVehicleFixed(vehicle)

        
        local ped = CreatePedInsideVehicle(vehicle, 4, pedHash, -1, true, true)
        timeout = 0
        while not DoesEntityExist(ped) and timeout < 50 do
            Citizen.Wait(100)
            timeout = timeout + 1
        end
        if not DoesEntityExist(ped) then
            DeleteEntity(vehicle)
            print("[RD-Taxi] ERROR: ped failed to create for driver " .. driver.name)
            return
        end

        SetEntityVisible(ped, false, false)
        SetEntityAlpha(ped, 0, false)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 17, true)
        SetPedCombatAttributes(ped, 46, true)
        SetEntityInvincible(ped, true)
        SetPedCanBeDraggedOut(ped, false)
        SetEntityProofs(ped, true, true, true, true, true, true, true, true)
        SetPedCanRagdoll(ped, false)
        SetPedSuffersCriticalHits(ped, false)

        Citizen.Wait(500)

        
        SetEntityVisible(vehicle, true, false)
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(vehicle)
        ResetEntityAlpha(ped)
        FreezeEntityPosition(vehicle, false)
        SetVehicleOnGroundProperly(vehicle)

        
        Citizen.CreateThread(function()
            while DoesEntityExist(vehicle) do
                Citizen.Wait(2000)
                local driverSeat = GetPedInVehicleSeat(vehicle, -1)
                if driverSeat ~= ped and DoesEntityExist(driverSeat) and not IsPedAPlayer(driverSeat) then
                    TaskLeaveVehicle(driverSeat, vehicle, 16)
                end
            end
        end)

        
        Citizen.CreateThread(function()
            while DoesEntityExist(vehicle) and DoesEntityExist(ped) do
                Citizen.Wait(5000)
                SetEntityInvincible(ped, true)
                SetEntityHealth(ped, 200)
                SetEntityInvincible(vehicle, true)
                SetVehicleFixed(vehicle)
                SetVehicleDirtLevel(vehicle, 0.0)
                SetVehicleEngineHealth(vehicle, 1000.0)
                SetVehicleBodyHealth(vehicle, 1000.0)
                SetVehiclePetrolTankHealth(vehicle, 1000.0)
            end
        end)

        
        local vehNetId = NetworkGetNetworkIdFromEntity(vehicle)
        local pedNetId = NetworkGetNetworkIdFromEntity(ped)

        TriggerServerEvent('rd-taxi:server:taxiSpawned', taxiId, vehNetId, pedNetId)

        SetModelAsNoLongerNeeded(vehicleHash)
        SetModelAsNoLongerNeeded(pedHash)
    end)
end)

RegisterNetEvent('rd-taxi:client:driveToPlayer')
AddEventHandler('rd-taxi:client:driveToPlayer', function(taxiId, vehicleNetId, targetPlayerId, driverName)
    Citizen.CreateThread(function()
        
        local vehicle = nil
        for _ = 1, 50 do
            vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
            if DoesEntityExist(vehicle) then break end
            Citizen.Wait(100)
        end

        if not vehicle or not DoesEntityExist(vehicle) then
            return
        end

        local ped = GetPedInVehicleSeat(vehicle, -1)

        
        if not DoesEntityExist(ped) then
            for _ = 1, 20 do
                Citizen.Wait(100)
                ped = GetPedInVehicleSeat(vehicle, -1)
                if DoesEntityExist(ped) then break end
            end
        end

        if not DoesEntityExist(ped) then return end

        
        if targetPlayerId == GetPlayerServerId(PlayerId()) and Config.ShowBlipWhenEnRoute then
            CreateTaxiTrackingBlip(taxiId, vehicleNetId, (driverName or "Taxi") .. " (Coming)", 5)
        end

        local targetPed = GetPlayerPed(GetPlayerFromServerId(targetPlayerId))
        if not DoesEntityExist(targetPed) then return end

        local pedCoords     = GetEntityCoords(ped)
        local targetCoords  = GetEntityCoords(targetPed)
        local initialDistance = #(pedCoords - targetCoords)

        SetVehicleEngineOn(vehicle, true, true, false)

        
        if initialDistance < 20.0 then
            UnlockTaxiForPassenger(vehicle, taxiId, vehicleNetId, targetPlayerId)
            TriggerServerEvent('rd-taxi:server:taxiArrivedAtPlayer', taxiId)
            return
        end

        
        local drivingStyle = Config.RespectTrafficLights and 786603 or 786475
        TaskVehicleDriveToCoordLongrange(
            ped, vehicle,
            targetCoords.x, targetCoords.y, targetCoords.z,
            20.0, drivingStyle, 5.0
        )

        local lastDistance = initialDistance
        while true do
            Citizen.Wait(1000)

            
            if not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then break end
            if not DoesEntityExist(targetPed) then break end

            pedCoords    = GetEntityCoords(ped)
            targetCoords = GetEntityCoords(targetPed)
            local distance = #(pedCoords - targetCoords)

            if distance < 15.0 or (distance > lastDistance and distance < 30.0) then
                ClearPedTasks(ped)
                SetVehicleForwardSpeed(vehicle, 0.0)

                UnlockTaxiForPassenger(vehicle, taxiId, vehicleNetId, targetPlayerId)
                TriggerServerEvent('rd-taxi:server:taxiArrivedAtPlayer', taxiId)
                break
            end

            lastDistance = distance
        end
    end)
end)

function UnlockTaxiForPassenger(vehicle, taxiId, vehicleNetId, targetPlayerId)
    
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleIndividualDoorsLocked(vehicle, 2, 0)  
    SetVehicleIndividualDoorsLocked(vehicle, 3, 0)  

    if targetPlayerId == GetPlayerServerId(PlayerId()) then
        StartVehicleHorn(vehicle, 2000, GetHashKey("NORMAL"), false)

        TriggerEvent('chat:addMessage', {
            color      = {138, 43, 226},
            multiline  = true,
            args       = {"Taxi Service", L("TAXI_ARRIVED")}
        })

        TriggerEvent('rd-taxi:client:taxiArrived', taxiId, vehicleNetId)
    end
end

RegisterNetEvent('rd-taxi:client:taxiArrived')
AddEventHandler('rd-taxi:client:taxiArrived', function(taxiId, vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)

    
    currentTaxiId = taxiId

    if not DoesEntityExist(vehicle) then return end

    Citizen.CreateThread(function()
        local startTime   = GetGameTimer()
        local timeoutMs   = Config.ReservedTimeout * 1000

        while (GetGameTimer() - startTime) < timeoutMs do
            Citizen.Wait(500)

            local playerPed = PlayerPedId()
            if IsPedInVehicle(playerPed, vehicle, false) then
                TriggerServerEvent('rd-taxi:server:playerEnteredTaxi', taxiId)
                TriggerEvent('rd-taxi:client:enterTaxi', taxiId, vehicleNetId)
                return
            end
        end

        
        currentTaxiId = nil
    end)
end)

RegisterNetEvent('rd-taxi:client:enterTaxi')
AddEventHandler('rd-taxi:client:enterTaxi', function(taxiId, vehicleNetId)
    currentTaxiId    = taxiId
    inTaxi           = true
    waypointSelected = false

    RemoveTaxiTrackingBlip(taxiId)

    TriggerEvent('chat:addMessage', {
        color     = {138, 43, 226},
        multiline = true,
        args      = {"Taxi Service", L("WELCOME_SET_WAYPOINT")}
    })

    waypointTimer = GetGameTimer()

    
    Citizen.CreateThread(function()
        local localTimer = GetGameTimer()

        while inTaxi and not waypointSelected do
            Citizen.Wait(1000)

            local elapsed   = (GetGameTimer() - localTimer) / 1000
            local remaining = Config.WaypointTimeout - elapsed

            if remaining <= 0 then
                TriggerEvent('chat:addMessage', {
                    color     = {255, 0, 0},
                    multiline = true,
                    args      = {"Taxi Service", L("WAYPOINT_TIMEOUT")}
                })
                KickPlayerFromTaxi(true)
                break
            end

            if remaining <= 30 then
                DisplayHelpText("~r~Select a waypoint! " .. L("HELP_ON_COOLDOWN", math.floor(remaining)))
            else
                DisplayHelpText("~y~Open your map and set a waypoint to your destination.")
            end
        end
    end)
end)

RegisterNetEvent('rd-taxi:client:driveToDestination')
AddEventHandler('rd-taxi:client:driveToDestination', function(taxiId, vehicleNetId, destination, driverName)
    Citizen.CreateThread(function()
        
        local vehicle = nil
        for _ = 1, 50 do
            vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
            if DoesEntityExist(vehicle) then break end
            Citizen.Wait(100)
        end
        if not vehicle or not DoesEntityExist(vehicle) then return end

        local ped = GetPedInVehicleSeat(vehicle, -1)
        if not DoesEntityExist(ped) then return end

        if Config.ShowBlipWhenDelivering then
            CreateTaxiTrackingBlip(taxiId, vehicleNetId, (driverName or "Taxi") .. " (Delivering)", 3)
        end

        
        SetVehicleDoorsLocked(vehicle, 4)
        SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), true)

        
        local preventExit = true
        Citizen.CreateThread(function()
            while inTaxi and waypointSelected and preventExit do
                Citizen.Wait(0)
                local playerPed = PlayerPedId()
                local pedCoords = GetEntityCoords(ped)
                local dist      = #(pedCoords - destination)

                if dist < 20.0 then
                    preventExit = false
                    break
                end

                DisableControlAction(0, 75, true)  
                DisableControlAction(0, 23, true)  

                if not IsPedInVehicle(playerPed, vehicle, false) then
                    TaskWarpPedIntoVehicle(playerPed, vehicle, 1)
                end
            end
        end)

        TriggerEvent('chat:addMessage', {
            color     = {138, 43, 226},
            multiline = true,
            args      = {"Taxi Service", L("DOORS_LOCKED_FOR_RIDE")}
        })

        
        SetDriverAbility(ped, 1.0)
        SetDriverAggressiveness(ped, 0.0)
        SetVehicleEngineOn(vehicle, true, true, false)

        local drivingStyle = Config.RespectTrafficLights and 786603 or 786475
        TaskVehicleDriveToCoordLongrange(
            ped, vehicle,
            destination.x, destination.y, destination.z,
            15.0, drivingStyle, 10.0
        )

        
        local arrived = false
        while not arrived do
            Citizen.Wait(500)

            if not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then break end

            local pedCoords = GetEntityCoords(ped)
            local dist      = #(pedCoords - destination)

            if dist < 20.0 then
                
                ClearPedTasks(ped)
                TaskVehicleDriveToCoord(
                    ped, vehicle,
                    destination.x, destination.y, destination.z,
                    10.0, 0,
                    GetHashKey(GetEntityModel(vehicle)),
                    drivingStyle, 5.0, true
                )

                Citizen.Wait(3000)

                pedCoords = GetEntityCoords(ped)
                dist      = #(pedCoords - destination)
                if dist < 15.0 then
                    arrived = true
                end
            end
        end

        
        ClearPedTasks(ped)
        SetVehicleEngineOn(vehicle, true, true, true)
        SetVehicleBrake(vehicle, true)
        SetVehicleHandbrake(vehicle, true)
        Citizen.Wait(500)
        SetVehicleHandbrake(vehicle, false)

        
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
        for i = 0, 5 do
            SetVehicleIndividualDoorsLocked(vehicle, i, 0)
        end

        RemoveTaxiTrackingBlip(taxiId)
        TriggerServerEvent('rd-taxi:server:deliveryComplete', taxiId)
    end)
end)

RegisterNetEvent('rd-taxi:client:deliveryComplete')
AddEventHandler('rd-taxi:client:deliveryComplete', function()
    if not inTaxi then return end

    SetWaypointOff()

    if Config.PaymentEnabled and Config.PaymentTiming == "on_arrival" and Config.Framework ~= "standalone" then
        ProcessTaxiPayment(function(success)
            if success then
                NotifyArrival()
            else
                TriggerEvent('chat:addMessage', {
                    color = {255, 0, 0},
                    multiline = true,
                    args  = {"Taxi Service", L("PAYMENT_FAIL_KICKED")}
                })
                KickPlayerFromTaxi(false)
            end
        end)
    else
        NotifyArrival()
    end
end)

function NotifyArrival()
    TriggerEvent('chat:addMessage', {
        color     = {0, 255, 0},
        multiline = true,
        args      = {"Taxi Service", L("ARRIVED_EXIT_VEHICLE")}
    })

    exitTimer = GetGameTimer()

    Citizen.CreateThread(function()
        local localTimer = GetGameTimer()

        while inTaxi do
            Citizen.Wait(1000)

            local playerPed = PlayerPedId()

            if not IsPedInAnyVehicle(playerPed, false) then
                local taxiIdToSend = currentTaxiId
                if taxiIdToSend then LockTaxiById(taxiIdToSend, true) end

                inTaxi           = false
                waypointSelected = false
                ClearTimers()

                if taxiIdToSend then
                    TriggerServerEvent('rd-taxi:server:playerExitedTaxi', taxiIdToSend)
                    currentTaxiId = nil
                end
                break
            end

            local elapsed   = (GetGameTimer() - localTimer) / 1000
            local remaining = Config.ExitTimeout - elapsed

            if remaining <= 0 then
                TriggerEvent('chat:addMessage', {
                    color     = {255, 0, 0},
                    multiline = true,
                    args      = {"Taxi Service", L("EXIT_TIMEOUT")}
                })
                KickPlayerFromTaxi(true)
                break
            end

            if remaining <= 30 then
                DisplayHelpText(L("EXIT_URGENT", math.floor(remaining)))
            else
                DisplayHelpText(L("EXIT_REMINDER"))
            end
        end
    end)
end

RegisterNetEvent('rd-taxi:client:returnToSpawn')
AddEventHandler('rd-taxi:client:returnToSpawn', function(taxiId, vehicleNetId, spawnCoords, driverName)
    Citizen.CreateThread(function()
        local vehicle = nil
        for _ = 1, 50 do
            vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
            if DoesEntityExist(vehicle) then break end
            Citizen.Wait(100)
        end
        if not vehicle or not DoesEntityExist(vehicle) then return end

        local ped = GetPedInVehicleSeat(vehicle, -1)
        if not DoesEntityExist(ped) then return end

        if Config.ShowBlipWhenReturning then
            CreateTaxiTrackingBlip(taxiId, vehicleNetId, (driverName or "Taxi") .. " (Returning)", 2)
        end

        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleEngineOn(vehicle, true, true, false)
        SetDriverAbility(ped, 1.0)
        SetDriverAggressiveness(ped, 0.0)

        local drivingStyle = Config.RespectTrafficLights and 786603 or 786475
        TaskVehicleDriveToCoordLongrange(
            ped, vehicle,
            spawnCoords.x, spawnCoords.y, spawnCoords.z,
            20.0, drivingStyle, 5.0
        )

        while true do
            Citizen.Wait(1000)

            if not DoesEntityExist(vehicle) or not DoesEntityExist(ped) then
                RemoveTaxiTrackingBlip(taxiId)
                break
            end

            local dist = #(GetEntityCoords(ped) - vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z))

            if dist < 15.0 then
                RemoveTaxiTrackingBlip(taxiId)
                ClearPedTasks(ped)
                ClearPedTasksImmediately(ped)
                SetVehicleForwardSpeed(vehicle, 0.0)
                SetVehicleEngineOn(vehicle, false, true, true)

                Citizen.Wait(800)

                SetEntityCoords(vehicle, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
                SetEntityHeading(vehicle, spawnCoords.w)
                TaskWarpPedIntoVehicle(ped, vehicle, -1)

                Citizen.Wait(500)

                SetVehicleDoorsLocked(vehicle, 2)
                SetVehicleEngineOn(vehicle, false, true, true)
                SetVehicleOnGroundProperly(vehicle)
                TaskSetBlockingOfNonTemporaryEvents(ped, true)
                SetPedConfigFlag(ped, 184, true)

                TriggerServerEvent('rd-taxi:server:taxiReturnedToSpawn', taxiId)
                break
            end
        end
    end)
end)

RegisterNetEvent('rd-taxi:client:demandedTaxiReady')
AddEventHandler('rd-taxi:client:demandedTaxiReady', function(taxiId, vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return end

    currentTaxiId = taxiId

    RemoveTaxiTrackingBlip(taxiId)

    
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    SetVehicleIndividualDoorsLocked(vehicle, 2, 0)
    SetVehicleIndividualDoorsLocked(vehicle, 3, 0)

    TriggerEvent('chat:addMessage', {
        color     = {0, 255, 0},
        multiline = true,
        args      = {"Taxi Service", "Your reserved taxi has arrived! Press G near the back door to enter."}
    })

    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        local timeoutMs = Config.ReservedTimeout * 1000

        while (GetGameTimer() - startTime) < timeoutMs do
            Citizen.Wait(500)
            local playerPed = PlayerPedId()
            if IsPedInVehicle(playerPed, vehicle, false) then
                TriggerServerEvent('rd-taxi:server:playerEnteredTaxi', taxiId)
                TriggerEvent('rd-taxi:client:enterTaxi', taxiId, vehicleNetId)
                return
            end
        end

        currentTaxiId = nil
    end)
end)

RegisterNetEvent('rd-taxi:client:openUI')
AddEventHandler('rd-taxi:client:openUI', function(taxis, stopName)
    isUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "openUI", taxis = taxis, stopName = stopName })
end)

RegisterNetEvent('rd-taxi:client:updateStatus')
AddEventHandler('rd-taxi:client:updateStatus', function(taxiId, status, eta)
    if isUIOpen then
        SendNUIMessage({ action = "updateStatus", taxiId = taxiId, status = status, eta = eta })
    end
end)

RegisterNetEvent('rd-taxi:client:updateDemandStatus')
AddEventHandler('rd-taxi:client:updateDemandStatus', function(taxiId, demandPlayerId)
    if isUIOpen then
        SendNUIMessage({ action = "updateDemandStatus", taxiId = taxiId, demandPlayerId = demandPlayerId })
    end
end)

RegisterNetEvent('rd-taxi:client:removeBlip')
AddEventHandler('rd-taxi:client:removeBlip', function(taxiId)
    RemoveTaxiTrackingBlip(taxiId)
end)

RegisterNetEvent('rd-taxi:client:playDriverVoice')
AddEventHandler('rd-taxi:client:playDriverVoice', function(taxiId, vehicleNetId, voiceFile)
    if not voiceFile or voiceFile == "none" or voiceFile == "" then return end

    Citizen.CreateThread(function()
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        if not DoesEntityExist(vehicle) then return end

        local ped = GetPedInVehicleSeat(vehicle, -1)
        if not DoesEntityExist(ped) then return end

        local pedCoords = GetEntityCoords(ped)
        SendNUIMessage({
            action       = "play3DAudio",
            audioFile    = voiceFile,
            coords       = { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z },
            vehicleNetId = vehicleNetId
        })
    end)
end)

RegisterNetEvent('rd-taxi:client:enterZone')
AddEventHandler('rd-taxi:client:enterZone', function(stop)
    
end)

RegisterNetEvent('rd-taxi:client:exitZone')
AddEventHandler('rd-taxi:client:exitZone', function()
    if isUIOpen then
        SendNUIMessage({ action = "close" })
        isUIOpen = false
        SetNuiFocus(false, false)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if inTaxi and currentTaxiId then
            TriggerServerEvent('rd-taxi:server:playerDisconnected', currentTaxiId)
        end
    end
end)

RegisterNUICallback('close', function(data, cb)
    isUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('notifyTaxi', function(data, cb)
    local taxiId    = data.taxiId
    local notifyType = data.notifyType or "normal"

    TriggerServerEvent('rd-taxi:server:notifyTaxi', taxiId, notifyType)

    isUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('confirmWaypoint', function(data, cb)
    
    SetNuiFocus(false, false)

    if data.confirmed and waypointCoords then
        if Config.PaymentEnabled and Config.PaymentTiming == "on_confirm" and Config.Framework ~= "standalone" then
            ProcessTaxiPayment(function(success)
                if success then
                    waypointSelected = true
                    TriggerServerEvent('rd-taxi:server:setDestination', currentTaxiId, waypointCoords)
                    TriggerEvent('chat:addMessage', {
                        color = {138, 43, 226}, multiline = true,
                        args  = {"Taxi Service", L("DESTINATION_CONFIRMED")}
                    })
                else
                    TriggerEvent('chat:addMessage', {
                        color = {255, 0, 0}, multiline = true,
                        args  = {"Taxi Service", L("PAYMENT_FAIL", Config.TaxiFare)}
                    })
                    KickPlayerFromTaxi(false)
                    SetWaypointOff()
                    waypointCoords = nil
                end
            end)
        else
            waypointSelected = true
            TriggerServerEvent('rd-taxi:server:setDestination', currentTaxiId, waypointCoords)
            TriggerEvent('chat:addMessage', {
                color = {138, 43, 226}, multiline = true,
                args  = {"Taxi Service", L("DESTINATION_CONFIRMED")}
            })
        end
    else
        SetWaypointOff()
        waypointCoords = nil
        TriggerEvent('chat:addMessage', {
            color = {255, 165, 0}, multiline = true,
            args  = {"Taxi Service", L("DESTINATION_CANCELLED")}
        })
    end

    cb('ok')
end)

RegisterNUICallback('getPlayerAndVehicleCoords', function(data, cb)
    local playerPed    = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local vehicle      = NetworkGetEntityFromNetworkId(data.vehicleNetId)
    local vehicleCoords = vector3(0, 0, 0)
    if DoesEntityExist(vehicle) then
        vehicleCoords = GetEntityCoords(vehicle)
    end

    cb({
        playerCoords  = { x = playerCoords.x,  y = playerCoords.y,  z = playerCoords.z },
        vehicleCoords = { x = vehicleCoords.x, y = vehicleCoords.y, z = vehicleCoords.z }
    })
end)

function OpenTaxiUI()
    if IsPlayerKicked() then return end
    local zoneData = GetCurrentZoneData()
    if not zoneData then return end
    TriggerServerEvent('rd-taxi:server:requestTaxiList', zoneData.name)
end

function ShowWaypointConfirmation(coords)
    waypointCoords = coords
    SendNUIMessage({ action = "showConfirmation", message = "Drive to waypoint location?" })
    SetNuiFocus(true, true)
end

function KickPlayerFromTaxi(applyPenalty)
    local playerPed = PlayerPedId()

    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, vehicle, 16)
    end

    local taxiIdToSend = currentTaxiId

    inTaxi           = false
    currentTaxiId    = nil
    waypointSelected = false
    ClearTimers()

    if applyPenalty then
        kickedFromTaxi = true
        kickTime       = GetGameTimer()
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0}, multiline = true,
            args  = {"Taxi Service", L("KICKED_COOLDOWN")}
        })
    end

    if taxiIdToSend then
        TriggerServerEvent('rd-taxi:server:playerExitedTaxi', taxiIdToSend)
    end
end

function LockTaxiById(taxiId, locked)
    for vehicle in EnumerateVehicles() do
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate == "TAXI" .. taxiId then
            if locked then
                SetVehicleDoorsLocked(vehicle, 2)
                SetVehicleDoorsLockedForAllPlayers(vehicle, true)
                for i = 0, 5 do
                    SetVehicleIndividualDoorsLocked(vehicle, i, 1)
                end
            else
                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                for i = 0, 5 do
                    SetVehicleIndividualDoorsLocked(vehicle, i, 0)
                end
            end
            break
        end
    end
end

function ClearTimers()
    waypointTimer = nil
    exitTimer     = nil
end

function IsPlayerKicked()
    if not kickedFromTaxi then return false end
    local elapsed = (GetGameTimer() - kickTime) / 1000
    if elapsed >= Config.CooldownAfterKick then
        kickedFromTaxi = false
        return false
    end
    return true
end

function GetRemainingCooldown()
    if not kickedFromTaxi then return 0 end
    local elapsed   = (GetGameTimer() - kickTime) / 1000
    local remaining = Config.CooldownAfterKick - elapsed
    return math.max(0, math.floor(remaining))
end

function DisplayHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function CreateTaxiTrackingBlip(taxiId, vehicleNetId, taxiName, color)
    RemoveTaxiTrackingBlip(taxiId)

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return end

    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, Config.MovingTaxiBlipSprite)
    SetBlipColour(blip, color or Config.MovingTaxiBlipColor)
    SetBlipScale(blip, Config.MovingTaxiBlipScale)
    SetBlipAsShortRange(blip, false)
    ShowHeadingIndicatorOnBlip(blip, true)
    SetBlipRotation(blip, math.ceil(GetEntityHeading(vehicle)))

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(taxiName or "Your Taxi")
    EndTextCommandSetBlipName(blip)

    activeTaxiBlips[taxiId] = blip

    Citizen.CreateThread(function()
        while DoesBlipExist(blip) and DoesEntityExist(vehicle) do
            Citizen.Wait(100)
            SetBlipRotation(blip, math.ceil(GetEntityHeading(vehicle)))
        end
    end)

    return blip
end

function RemoveTaxiTrackingBlip(taxiId)
    if activeTaxiBlips[taxiId] then
        local blip = activeTaxiBlips[taxiId]
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        activeTaxiBlips[taxiId] = nil
    end
end

function ProcessTaxiPayment(callback)
    if not Config.PaymentEnabled or Config.Framework == "standalone" then
        callback(true)
        return
    end

    if Config.Framework == "qbcore" then
        QBCore.Functions.TriggerCallback('rd-taxi:server:processPayment', function(success, message)
            if success then
                TriggerEvent('chat:addMessage', {
                    color = {0, 255, 0}, multiline = true,
                    args  = {"Taxi Service", L("PAYMENT_SUCCESS", Config.TaxiFare)}
                })
                callback(true)
            else
                TriggerEvent('chat:addMessage', {
                    color = {255, 0, 0}, multiline = true,
                    args  = {"Taxi Service", message or L("PAYMENT_FAIL", Config.TaxiFare)}
                })
                callback(false)
            end
        end, Config.TaxiFare)

    elseif Config.Framework == "esx" then
        ESX.TriggerServerCallback('rd-taxi:server:processPayment', function(success, message)
            if success then
                TriggerEvent('chat:addMessage', {
                    color = {0, 255, 0}, multiline = true,
                    args  = {"Taxi Service", L("PAYMENT_SUCCESS", Config.TaxiFare)}
                })
                callback(true)
            else
                TriggerEvent('chat:addMessage', {
                    color = {255, 0, 0}, multiline = true,
                    args  = {"Taxi Service", message or L("PAYMENT_FAIL", Config.TaxiFare)}
                })
                callback(false)
            end
        end, Config.TaxiFare)
    end
end

function EnumerateVehicles()
    return coroutine.wrap(function()
        local handle, vehicle = FindFirstVehicle()
        local success
        repeat
            coroutine.yield(vehicle)
            success, vehicle = FindNextVehicle(handle)
        until not success
        EndFindVehicle(handle)
    end)
end