CORE = exports["ak4y-core"]
open = false
first = true
workzone = nil
openzone = nil
vehicle = nil
injob = false
taximeteron = false
airscreenon = false
price = 0
distanceKm = 0
earnedmoney = 0
starttime = GetGameTimer()
clientblip = false
earnedxp= 0
takecustomer = false
satisfaction = 100
vehiclelevel = 1
totalclient = 0
client = false
zero = false
finishcoord = nil
currentdistance = nil
ActiveJobDetails = {
    vacant = false,
    hired = false,
    time = false
}

local function SyncJobState()
    ActiveJobDetails.npcInTaxi = isnpcinvehicle == true
    TriggerServerEvent("ak4y-taxi:UpdateJobState", ActiveJobDetails)
end

local function ClearCustomerBlip()
    if clientblip and DoesBlipExist(clientblip) then
        RemoveBlip(clientblip)
    end
    clientblip = false
end

local function SetCustomerBlip(coords, label)
    ClearCustomerBlip()
    clientblip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(clientblip, 280)
    SetBlipDisplay(clientblip, 2)
    SetBlipScale(clientblip, 0.6)
    SetBlipColour(clientblip, 46)
    SetBlipAsShortRange(clientblip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label or "Customer")
    EndTextCommandSetBlipName(clientblip)
end
distanceTravelled = 0
isnpcinvehicle = false
lastBilledPassengerId = nil
lastInvoiceTryAt = 0
npcPickupCoord = nil
npcDropCoord = nil

airOn = false
fanlevel = 1 
satisfiedcustomer = 0
dissatisfiedcustomer = 0

minComfortTemp = 21.0
maxComfortTemp = 24.0

mintempwithair = 16.0
maxtempwithair = 30.0

insideTemp = 22.0

heaterOn = true
acOn = false

airOn = false
focusActive = false
remoteTaximeterActive = false
remoteTaximeterLastSync = 0
remoteTaximeterVehicleNet = 0
uiTaximeterVisible = false
driverManualTaximeter = false

local function SetTaxiMeterVisible(visible)
    local v = visible == true
    if uiTaximeterVisible == v then return end
    uiTaximeterVisible = v
    taximeteron = v
    SendNUIMessage({
        action = "TaxiMeter",
        bool = v
    })
end

CreateThread(function()
    Wait(3000)
    SendNUIMessage({
        action = "init",
        data = Config,
        locales = Config.locales[Config.Locale]
    })
end)


RegisterCommand('openfocuss', function()
    if not injob then return end
    focusActive = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    while focusActive do
        Wait(0)
            DisableAllControlActions(0, true)
            EnableControlAction(0, 30, true)
            EnableControlAction(0, 31, true)
            EnableControlAction(0, 32, true)
            EnableControlAction(0, 33, true)
            EnableControlAction(0, 34, true)
            EnableControlAction(0, 35, true)
            EnableControlAction(0, 59, true)
            EnableControlAction(0, 64, true)
            EnableControlAction(0, 75, true)
            EnableControlAction(0, 76, true)
            EnableControlAction(0, 79, true)
            EnableControlAction(0, 23, true)
            EnableControlAction(0, 72, true)
            EnableControlAction(0, 71, true)
            DisableControlAction(0, 157, true)
            DisableControlAction(0, 177, true)
            DisableControlAction(0, 158, true)
            DisableControlAction(0, 160, true)
            DisableControlAction(0, 164, true)
            DisableControlAction(0, 165, true)
            DisablePlayerFiring(PlayerPedId(), true)
    end
end)

RegisterKeyMapping('openfocuss', Config.Keys["mouse"].desc, "keyboard", Config.Keys["mouse"].key)

RegisterCommand('opentaximeterr', function()
    if not injob then return end
    local currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if currentVehicle == 0 then return end
    if GetEntityModel(currentVehicle) ~= GetHashKey('taxi') then return end
    if not vehicle or vehicle == 0 or currentVehicle ~= vehicle then return end
    driverManualTaximeter = not driverManualTaximeter
    SetTaxiMeterVisible(driverManualTaximeter or (ActiveJobDetails.hired == true))
end)

RegisterKeyMapping('opentaximeterr', Config.Keys["taximeter"].desc, "keyboard", Config.Keys["taximeter"].key)

RegisterCommand('airscreenn', function()
    if not injob then return end
    if IsPedInAnyVehicle(PlayerPedId()) then
        airscreenon = not airscreenon
        SendNUIMessage({
            action = "AirScreen",
            bool = airscreenon
        })
    end
end)

RegisterKeyMapping('airscreenn', Config.Keys["air"].desc, "keyboard", Config.Keys["air"].key)

RegisterNetEvent('ak4y-taxi:Open', function()
    if Config.Job then
        if exports["ak4y-core"]:GetPlayerJob() == Config.Job then
        else
            Notify(Config.locales[Config.Locale].game["false_job"], "error")
            return
        end
    end
    if not injob then
        openzone = nil
        open = true
        if first then
            first = false
            SendNUIMessage({
                action = "SetFocusKey",
                key = GetKeyCode(Config.Keys["mouse"].key),
            })
            SendNUIMessage({
                action = "init",
                data = Config,
                locales = Config.locales[Config.Locale]
            })
        end
        local newdata = CORE:Trigger('ak4y-taxi:GetPlayerData')
        zone = nil
        for k,v in pairs(Config.CabLocations) do
            if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), v.AccesCoord, false) < 50 then
                zone = k
            end
        end
        if zone then
            openzone = zone
            SendNUIMessage({
                action = "OpenMenu",
                data = newdata
            })
            SetNuiFocus(true, true)
        else
            open = false
            Notify(Config.locales[Config.Locale].game["not_in_zone"], "error")
        end
    else
        Notify(Config.locales[Config.Locale].game["already_in_job"], "error")
    end
end)

RegisterNUICallback('closeMenu', function()
    open = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    focusActive = false
end)

RegisterNUICallback('startJob', function(data)
    open = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    focusActive = false
    SendNUIMessage({
        action = "DistancePrice",
        distance = 0,
        price = 0
    })
    workzone = data.route
    if openzone then
        local vehicleIndex = (tonumber(data.vehicle) or 0) + 1
        local startRes = CORE:Trigger('ak4y-taxi:StartJob', workzone, vehicleIndex)
        local veh = nil
        local spawncoords = nil
        local vehicleCoordsList = Config.CabLocations[openzone].VehicleCoords
        if not vehicleCoordsList or type(vehicleCoordsList) ~= "table" then
            Notify(Config.locales[Config.Locale].game["no_spawn"], "error")
            return
        end
        for _, v in pairs(vehicleCoordsList) do
            if IsSpawnPointClear(v, 2.5) then
                spawncoords = v
                break
            end
        end

        if spawncoords == nil then
            Wait(1000)
            Notify(Config.locales[Config.Locale].game["no_spawn"], "error")
            return
        end
        earnedmoney = 0
        earnedxp = 0
        totalclient = 0
        satisfiedcustomer = 0
        dissatisfiedcustomer = 0
        price = 0
        distanceKm = 0
        distanceTravelled = 0
        currentdistance = 0
        finishcoord = nil
        npcPickupCoord = nil
        npcDropCoord = nil
        lastBilledPassengerId = nil
        zero = false
        ClearCustomerBlip()
        isnpcinvehicle = false
        ActiveJobDetails.vacant = false
        ActiveJobDetails.hired = false
        ActiveJobDetails.time = false
        SyncJobState()
        SendNUIMessage({
            action = "SetTaximeterDetails",
            data = ActiveJobDetails,
        })
        TriggerEvent('ak4y-taxi:StartJobWithLoops')
        starttime = GetGameTimer()
        vehiclelevel = Config.Vehicles[vehicleIndex].priceMultiplier
        exports["ak4y-core"]:SpawnVehicle(Config.Vehicles[vehicleIndex].model,
        function(araba)
            veh = araba
            vehicle = araba
            SetFuelFunction(veh)
            local modTypes = { 11, 12, 13, 15 }
            SetVehicleModKit(veh, 0)
            for _, modType in ipairs(modTypes) do
                local numMods = GetNumVehicleMods(veh, modType)
                if numMods and numMods > 0 then
                    SetVehicleMod(veh, modType, numMods - 1, false)
                end
            end
        end, spawncoords, true, true)
        SetVehicleDoorsLocked(vehicle, 1)
        GiveVehicleKeys(GetVehicleNumberPlateText(veh), Config.Vehicles[vehicleIndex].model)
        injob = true

        while IsPedInAnyVehicle(PlayerPedId()) == false do
            Wait(1)
            Draw3DText({
                text = "Araca Bin",
                coords = GetEntityCoords(veh),
            })
        end
        SendNUIMessage({
            action = "InVehicle",
        })
    end
end)

IsSpawnPointClear = function(coords, radius)
	local vehicles = GetVehiclesInArea(coords, radius)

	return #vehicles == 0
end

GetVehiclesInArea = function(coords, area)
	local vehicles       = GetGamePool('CVehicle')
	local vehiclesInArea = {}

	for i=1, #vehicles, 1 do
		local vehicleCoords = GetEntityCoords(vehicles[i])
		local distance      = GetDistanceBetweenCoords(vehicleCoords, coords.x, coords.y, coords.z, true)

		if distance <= area then
			table.insert(vehiclesInArea, vehicles[i])
		end
	end

	return vehiclesInArea
end

function Draw3DText(data)
    local text = data.text
    local x = data.coords.x
    local y = data.coords.y
    local z = data.coords.z
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

RegisterNUICallback('ChangeDetails', function(data)
    local prevHired = ActiveJobDetails and ActiveJobDetails.hired == true
    if data.data.hired then
        if data.data.vacant then
            data.data.hired = false
        end
    end
    ActiveJobDetails = data.data
    if (not prevHired) and ActiveJobDetails.hired then
        lastBilledPassengerId = nil
    end
    if injob then
        SyncJobState()
    end
end)

RegisterNUICallback('CancelJob', function()
    dissatisfiedcustomer = dissatisfiedcustomer + 1
    SetNewWaypoint(GetEntityCoords(PlayerPedId()).x, GetEntityCoords(PlayerPedId()).y)
    TriggerServerEvent("ak4y-taxi:CancelJob")
    ClearCustomerBlip()

    finishcoord = nil
    npcPickupCoord = nil
    npcDropCoord = nil
    currentdistance = nil
    distanceKm = 0
    distanceTravelled = 0
    price = 0
    zero = true
    isnpcinvehicle = false
    takecustomer = false
    ActiveJobDetails.hired = false
    ActiveJobDetails.time = false
    SyncJobState()


    if client then
        DeleteEntity(client)
        takecustomer = false
    end
end)

CreateThread(function()
    while true do
        if injob then
            if ActiveJobDetails.hired then
                if vehicle and IsPedInAnyVehicle(PlayerPedId(), false) then
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    local seats = GetVehicleMaxNumberOfPassengers(vehicle)
                    for i = -1, seats - 1 do
                        local ped = GetPedInVehicleSeat(vehicle, i)
                        if ped and ped ~= PlayerPedId() and NetworkIsPlayerActive(NetworkGetPlayerIndexFromPed(ped)) then
                            local playerServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
                            TriggerServerEvent("ak4y-taxi:SendTaximeterToPlayer", playerServerId, ActiveJobDetails)
                        end
                    end
                end
            elseif ActiveJobDetails.vacant then
                if injob then
                    if workzone then
                        local hasPlayerPassenger = false
                        local currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                        if currentVehicle and currentVehicle ~= 0 then
                            local maxSeats = GetVehicleMaxNumberOfPassengers(currentVehicle)
                            for seat = 0, maxSeats - 1 do
                                local ped = GetPedInVehicleSeat(currentVehicle, seat)
                                if ped and ped ~= 0 and ped ~= PlayerPedId() then
                                    local idx = NetworkGetPlayerIndexFromPed(ped)
                                    if idx and idx ~= -1 and NetworkIsPlayerActive(idx) then
                                        hasPlayerPassenger = true
                                        break
                                    end
                                end
                            end
                        end

                        if hasPlayerPassenger then
                            Wait(1000)
                        elseif math.random(1, 100) <= 80 then
                            ActiveJobDetails.vacant = false
                            ActiveJobDetails.hired = true
                            takecustomer = true
                            SendNUIMessage({
                                action = "SetTaximeterDetails",
                                data = ActiveJobDetails,
                            })
                            local coord = Config.WorkZones[workzone].coords[math.random(1, #Config.WorkZones[workzone].coords)]
                            npcPickupCoord = vec3(coord.x, coord.y, coord.z)
                            currentdistance = GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), coord, false)
                            SetNewWaypoint(coord.x, coord.y)
                            SetCustomerBlip(coord, "Customer")

                            while GetDistanceBetweenCoords(vec3(coord.x, coord.y, coord.z), GetEntityCoords(PlayerPedId()), false) > 50 and ActiveJobDetails.hired do
                                Wait(100)
                            end

                            if ActiveJobDetails.hired then
                                zero = true
                                SendNUIMessage({
                                    action = "DistancePrice",
                                    distance = distanceKm,
                                    price = price
                                })
                                Notify(Config.locales[Config.Locale].game["go_to_client"], "success")
                                local randomped = Config.Peds[math.random(1, #Config.Peds)]
                                RequestModel(randomped)
                                while not HasModelLoaded(randomped) do print("random ped loading", randomped) Wait(100) end
                                client = CreatePed(4, randomped, coord.x, coord.y, coord.z, 0.0, true, true)
                                SetEntityAsMissionEntity(client, true, true)
                                -- MakePedNetworked(client)
                                SetEntityHeading(client, coord.w)
                                SetBlockingOfNonTemporaryEvents(client, true)
                                SetPedFleeAttributes(client, 0, false)
                                SetPedCombatAttributes(client, 17, true)
                                SetPedCanBeTargetted(client, false)
                                SetEntityInvincible(client, true)
                                SetPedCanBeDraggedOut(client, false)
                                SetPedCanRagdoll(client, false)
                                SetCanAttackFriendly(client, false, false)
                                if not DoesRelationshipGroupExist("TAXI_CUSTOMER") then
                                    AddRelationshipGroup("TAXI_CUSTOMER")
                                end
                                SetPedRelationshipGroupHash(client, GetHashKey("TAXI_CUSTOMER"))
                                SetRelationshipBetweenGroups(0, GetHashKey("TAXI_CUSTOMER"), GetHashKey("PLAYER"))
                                SetRelationshipBetweenGroups(0, GetHashKey("PLAYER"), GetHashKey("TAXI_CUSTOMER"))
                                
                                while GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), coord, false) > 10 and takecustomer do
                                    Wait(1000)
                                end
                                while GetEntitySpeed(PlayerPedId()) > 1.0 and takecustomer do
                                    Wait(1000)
                                end
                                print("enter")
                                EnsureControlOfEntity(client)
                                EnsureControlOfEntity(vehicle)
                                local seat = GetFreeSeat(vehicle)
                                if not seat then seat = 0 end
                                TriggerEvent('ak4y-busjob:IsEntered', client, vehicle, seat)
                                TaskEnterVehicle(client, vehicle, -1, seat, 1.0, 1, 0)
                                local waitEnd = GetGameTimer() + 5000
                                while GetGameTimer() < waitEnd and not IsPedInVehicle(client, vehicle) and takecustomer do
                                    Wait(100)
                                end
                                if not IsPedInVehicle(client, vehicle) and takecustomer then
                                    print("binmedi hala")
                                    local warpTries = 10
                                    for _ = 1, warpTries do
                                        print("deneme", _)
                                        local warpWaitEnd = GetGameTimer() - 5
                                        if IsPedInVehicle(client, vehicle) or not takecustomer then 
                                            print("bindi geç")
                                        else
                                            print("binmedi bindir")
                                            EnsureControlOfEntity(client)
                                            seat = GetFreeSeat(vehicle)
                                            print("boş koltuk", seat)
                                            if seat == nil then seat = 0 end
                                            TaskWarpPedIntoVehicle(client, vehicle, seat)
                                            warpWaitEnd = GetGameTimer() + 500
                                        end
                                        while GetGameTimer() < warpWaitEnd and not IsPedInVehicle(client, vehicle) and takecustomer do
                                            print("bekle binmedi olayı")
                                            Wait(100)
                                        end
                                    end
                                end
                                -- 3) Hâlâ binmediyse farklı koltuklarla dene
                                if not IsPedInVehicle(client, vehicle) and takecustomer then
                                    local freeSeats = GetFreeSeats(vehicle)
                                    for i = 1, #freeSeats do
                                        if IsPedInVehicle(client, vehicle) or not takecustomer then break end
                                        EnsureControlOfEntity(client)
                                        TaskWarpPedIntoVehicle(client, vehicle, freeSeats[i])
                                        Wait(500)
                                    end
                                end
                                while not IsPedInVehicle(client, vehicle) and takecustomer do
                                    Wait(100)
                                end
                                if takecustomer then
                                    satisfaction = 100
                                    isnpcinvehicle = true
                                    TriggerServerEvent("ak4y-taxi:ResetNpcMeter")
                                    -- Müşteri bindiğinde taksimetreyi sıfırla
                                    price = 0
                                    distanceKm = 0
                                    distanceTravelled = 0
                                    zero = false
                                    ActiveJobDetails.time = true
                                    SyncJobState()
                                    SendNUIMessage({
                                        action = "DistancePrice",
                                        distance = 0,
                                        price = 0
                                    })
                                    SendNUIMessage({
                                        action = "SetTaximeterDetails",
                                        data = ActiveJobDetails,
                                    })
                                    -- Varış noktası müşteri alınan yerden farklı olsun (en az 100m uzak)
                                    local pickupPos = vec3(coord.x, coord.y, coord.z)
                                    local coord2 = Config.WorkZones[workzone].coords[math.random(1, #Config.WorkZones[workzone].coords)]
                                    local minDistance = 100.0
                                    for _ = 1, 25 do
                                        local c = Config.WorkZones[workzone].coords[math.random(1, #Config.WorkZones[workzone].coords)]
                                        if GetDistanceBetweenCoords(pickupPos, vec3(c.x, c.y, c.z), false) >= minDistance then
                                            coord2 = c
                                            break
                                        end
                                    end
                                    finishcoord = vec3(coord2.x, coord2.y, coord2.z)
                                    npcDropCoord = vec3(coord2.x, coord2.y, coord2.z)
                                    currentdistance = currentdistance + GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), finishcoord, false)
                                    SetNewWaypoint(coord2.x, coord2.y)
                                    SetCustomerBlip(coord2, "Customer")

                                    while GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), coord2, false) > 30 do
                                        Wait(1000)
                                    end
                                    Notify(Config.locales[Config.Locale].game["end_trip_notify"])
                                    while IsPedInVehicle(client, vehicle) do
                                        Wait(1)
                                        DrawMarker(
                                            2,
                                            coord2.x,
                                            coord2.y,
                                            coord2.z,
                                            0.0, 0.0, 0.0,
                                            0.0, 0.0, 0.0,
                                            0.7, 0.7, 0.7,
                                            255, 255, 255, 210,
                                            false, false, 2, false,
                                            nil, nil, false
                                        )
                                    end
                                end
                            end
                        else
                            Wait(math.random(3000, 15000))
                        end
                    end
                end
            end
        end
        Wait(1000)
    end
end)

function IsPlayerInVehicleExceptDriver(vehicle)
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = 0, maxSeats - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 and ped ~= PlayerPedId() and NetworkIsPlayerActive(NetworkGetPlayerIndexFromPed(ped)) then
            return GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
        end
    end
    return nil
end

local function GetNpcPassengerInVehicle(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 1
    for seat = 0, maxSeats do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 and ped ~= PlayerPedId() then
            local playerIdx = NetworkGetPlayerIndexFromPed(ped)
            local isPlayerPed = playerIdx and playerIdx ~= -1 and NetworkIsPlayerActive(playerIdx)
            if not isPlayerPed then
                return ped
            end
        end
    end
    return nil
end

pricewillpay = 0
pricewillsrc = 0
invoiceToken = nil
RegisterNetEvent("ak4y-taxi:ShowInvoice", function(price, distance, data, pid, token)
    pricewillpay = math.floor(price)
    pricewillsrc = pid
    invoiceToken = token
    SendNUIMessage({
        action = "ShowInvoice",
        price = math.floor(price),
        distance = distance,
        data = data,
    })
    SetNuiFocus(true, true)
end)

local function HandleEndTrip()
    if not injob then return end
    local currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if currentVehicle == 0 then
        Notify(Config.locales[Config.Locale].game["not_in_vehicle"], "error")
        return
    end

    local npcPed = GetNpcPassengerInVehicle(currentVehicle)
    local hasActiveNpcCustomer = npcPed and takecustomer and ActiveJobDetails.hired
    if hasActiveNpcCustomer and (not client or not DoesEntityExist(client)) then
        client = npcPed
    end

    local passengerId = IsPlayerInVehicleExceptDriver(currentVehicle)
    if not hasActiveNpcCustomer and not passengerId then
        if not client or not isnpcinvehicle or not takecustomer or not ActiveJobDetails.hired then
            Notify(Config.locales[Config.Locale].game["no_passenger_in_vehicle"], "error")
            return
        end
    end

    if not hasActiveNpcCustomer and passengerId then
        local nowMs = GetGameTimer()
        if lastBilledPassengerId == passengerId and (nowMs - (lastInvoiceTryAt or 0)) < 1200 then
            return
        end
        lastInvoiceTryAt = nowMs
        local invoiceRequested = CORE:Trigger("ak4y-taxi:RequestInvoiceCb", passengerId)
        if not invoiceRequested then
            Notify(Config.locales[Config.Locale].game["invoice_failed"], "error")
            return
        end
        lastBilledPassengerId = passengerId
        earnedxp = earnedxp + math.random(Config.WorkZones[workzone].xp.min, Config.WorkZones[workzone].xp.max)
        totalclient = totalclient + 1
        PathTaken(math.floor(distanceKm))
        ActiveJobDetails.hired = false
        ActiveJobDetails.time = false
        SyncJobState()
        SendNUIMessage({
            action = "SetTaximeterDetails",
            data = ActiveJobDetails,
        })
        zero = true
        distanceTravelled = 0
        return
    end

    if hasActiveNpcCustomer then
        isnpcinvehicle = true
    end

    if not ActiveJobDetails.time then
        Notify(Config.locales[Config.Locale].game["taximeter_time_off"], "error")
        return
    end

    if not finishcoord then return end

    if #(finishcoord - GetEntityCoords(PlayerPedId())) < 10 then 
        local tripResult = CORE:Trigger("ak4y-taxi:CompleteNpcTrip", {
            pickup = npcPickupCoord and { x = npcPickupCoord.x, y = npcPickupCoord.y, z = npcPickupCoord.z } or nil,
            drop = npcDropCoord and { x = npcDropCoord.x, y = npcDropCoord.y, z = npcDropCoord.z } or nil,
            satisfaction = satisfaction,
        })
        if not tripResult or not tripResult.ok then
            Notify(Config.locales[Config.Locale].game["trip_verify_failed"], "error")
            return
        end

        local outcome = tostring(tripResult.outcome or "satisfied")
        if outcome == "overcharge" then
            local percentageText = math.floor(tonumber(tripResult.overchargePercent) or 0)
            Notify(string.format(Config.locales[Config.Locale].game["overcharge_warning"], percentageText), "error")
            SendNUIMessage({
                action = "DissatisfiedCustomer",
            })
            DissatisfiedTrip()
            dissatisfiedcustomer = dissatisfiedcustomer + 1
        elseif outcome == "dissatisfied" then
            dissatisfiedcustomer = dissatisfiedcustomer + 1
            SendNUIMessage({
                action = "DissatisfiedCustomer",
            })
            DissatisfiedTrip()
        else
            satisfiedcustomer = satisfiedcustomer + 1
            SendNUIMessage({
                action = "SatisfiedCustomer",
            })
            SatisfiedTrip()
        end

        local tripAmount = tonumber(tripResult.amount) or 0
        earnedmoney = earnedmoney + tripAmount
        earnedxp = earnedxp + (tonumber(tripResult.xp) or 0)

        ClearCustomerBlip()

        totalclient = totalclient + 1
        SendNUIMessage({
            action = "DistancePrice",
            distance = 88.88,
            price = 88.88
        })

        PathTaken(math.floor(distanceKm))
        TaskLeaveVehicle(client, vehicle, 0)
        distanceTravelled = 0
        isnpcinvehicle = false
        ActiveJobDetails.hired = false
        ActiveJobDetails.time = false
        npcPickupCoord = nil
        npcDropCoord = nil
        TaskGoToCoordAnyMeans(client, GetEntityCoords(client).x + math.random(-10, 10), GetEntityCoords(client).y + math.random(-10, 10),  GetEntityCoords(client).z, 1.0)

        SendNUIMessage({
            action = "SetTaximeterDetails",
            data = ActiveJobDetails,
        })
        Wait(3000)
        DeleteEntity(client)
    else
        Notify(Config.locales[Config.Locale].game["too_far"], "error")
    end
end

RegisterNUICallback('EndTrip', function()
    HandleEndTrip()
end)

RegisterNetEvent('ak4y-taxi:IsEntered', function(ped, vehicle, seat)
    Wait(7000)
    if not IsPedInVehicle(ped, vehicle) then
        TaskWarpPedIntoVehicle(ped, vehicle, seat)
    end
end)

function GetFreeSeat(vehicle)
    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 1 -- 0-based index
    for seat = 0, maxSeats do
        if IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end
    return nil -- Boş koltuk yoksa
end

function GetFreeSeats(vehicle)
    local list = {}
    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 1
    for seat = 0, maxSeats do
        if IsVehicleSeatFree(vehicle, seat) then
            list[#list + 1] = seat
        end
    end
    return list
end

CreateThread(function()
    local lastPlayerCoords = GetEntityCoords(PlayerPedId())

    while true do
        if injob then
            local playerPed = PlayerPedId()
            local currentCoords = GetEntityCoords(playerPed)
            local dx = currentCoords.x - lastPlayerCoords.x
            local dy = currentCoords.y - lastPlayerCoords.y
            local dz = currentCoords.z - lastPlayerCoords.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            if zero then
                dist = 0
                distanceTravelled = 0
                zero = false
            end
            if ActiveJobDetails.hired then
                if ActiveJobDetails.time then
                    distanceTravelled = distanceTravelled + dist
                    distanceKm = distanceTravelled / 1000
                    price = distanceKm * Config.PricePerMile
                    SendNUIMessage({
                        action = "DistancePrice",
                        distance = distanceKm,
                        price = price
                    })
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
                    local playerIds = {}
                    for seat = -1, maxSeats - 1 do
                        local ped = GetPedInVehicleSeat(vehicle, seat)
                        if ped and ped ~= 0 and ped ~= PlayerPedId() then
                            local player = NetworkGetPlayerIndexFromPed(ped)
                            if player and NetworkIsPlayerActive(player) then
                                local serverId = GetPlayerServerId(player)
                                table.insert(playerIds, serverId)
                            end
                        end
                    end
                    TriggerServerEvent("ak4y-taxi:DistributeMeterData", playerIds, distanceKm, price)
                end
            elseif ActiveJobDetails.vacant then
                
            end

            lastPlayerCoords = currentCoords
        end
        Wait(1000)
    end
end)

local maxDistance = 100.0
local graceSeconds = 60

local awaySince = nil          
local warnedThisAway = false   

CreateThread(function()
    while true do
        Wait(1000)

        if injob then
            if DoesEntityExist(vehicle) then
                local ped = PlayerPedId()
                local dist = #(GetEntityCoords(ped) - GetEntityCoords(vehicle))

                if dist > maxDistance then
                    if awaySince == nil then
                        awaySince = GetGameTimer()
                        warnedThisAway = false
                    end

                    if not warnedThisAway then
                        warnedThisAway = true
                        Notify(string.format(Config.locales[Config.Locale].game["return_to_vehicle_grace"], graceSeconds), "error")
                    end

                    local elapsed = (GetGameTimer() - awaySince) / 1000.0
                    if elapsed >= graceSeconds then
                        DeleteVehicle(vehicle)

                        injob = false
                        TriggerServerEvent("ak4y-taxi:CancelJob", true)
                        totalclient = 0

                        awaySince = nil
                        warnedThisAway = false

                        Notify(Config.locales[Config.Locale].game["canceled_job"], "error")
                    end
                else
                    awaySince = nil
                    warnedThisAway = false
                end
            else
                injob = false
                totalclient = 0
                TriggerServerEvent("ak4y-taxi:CancelJob", true)

                awaySince = nil
                warnedThisAway = false

                Notify(Config.locales[Config.Locale].game["canceled_job"], "error")
            end
        else
            awaySince = nil
            warnedThisAway = false
        end
    end
end)

local sleep = 1000
CreateThread(function()
    while true do
        Wait(sleep)
        if injob then
            if openzone then
                local finishCoord = Config.CabLocations[openzone].FinishJob
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distFinish = GetDistanceBetweenCoords(playerCoords, finishCoord, false)
                if distFinish < 50 then
                    sleep = 1
                    if distFinish < 10 then
                        DrawMarker(
                            2,
                            finishCoord.x,
                            finishCoord.y,
                            finishCoord.z,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            0.7, 0.7, 0.7,
                            255, 255, 255, 210,
                            false, false, 2, false,
                            nil, nil, false
                        )
                        if distFinish < 4 then
                            Draw3DText({
                                text = Config.locales[Config.Locale].ui.finish_job_3d,
                                coords = finishCoord,
                            })
                            if IsControlJustReleased(0, 38) then
                                if GetVehicleNumberPlateText(GetVehiclePedIsIn(PlayerPedId())) == GetVehicleNumberPlateText(vehicle) then
                                    DeleteVehicle(vehicle)
                                    injob = false
                                    open = false
                                    SetNuiFocus(false, false)
                                    SetNuiFocusKeepInput(false)
                                    focusActive = false
                                    totaltime = convertMillis(GetGameTimer() - starttime)
                                    local finishRes = CORE:Trigger('ak4y-taxi:FinishJob')
                                    local serverEarned = math.floor(earnedmoney)
                                    if finishRes and finishRes.ok and finishRes.money then
                                        serverEarned = math.floor(finishRes.money)
                                    end
                                    SendNUIMessage({
                                        action = "FinishJob",
                                        dissatisfiedcustomer = dissatisfiedcustomer,
                                        satisfiedcustomer = satisfiedcustomer,
                                        totaltime = totaltime,
                                        totalclient = totalclient,
                                        earnedmoney = serverEarned,
                                    })
                                    totalclient = 0
                                    FinishJob()
                                    Wait(3000)
                                    EarnedMoney(earnedmoney)
                                else
                                    Notify(Config.locales[Config.Locale].game["false_car"], "error")
                                end
                            end
                        end
                    end
                else
                    sleep = 1000
                end
            else
                sleep = 1000
            end
        else
            sleep = 1000
        end
    end
end)

function convertMillis(ms)
    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local sure = minutes .. " min " .. seconds .. " sec"
    return sure
end

RegisterNUICallback('SetAir', function(data)
    airOn = data.airon
    acOn = data.airon
end)

RegisterNUICallback('SetSliderLevel', function(data)
    fanlevel = data.level
end)

local lastHealth = 1000
RegisterNetEvent('ak4y-taxi:StartJobWithLoops', function()
    insideTemp = math.random(21, 24)
    
    while injob do 
        if IsPedInAnyVehicle(PlayerPedId(), false) then 
            if client then
                if IsPedInAnyVehicle(client) then
                    local currentHealth = GetVehicleEngineHealth(vehicle)
                    
                    if lastHealth == nil then
                        lastHealth = 1000
                    end
                    
                    if currentHealth < lastHealth then
                        local damageTaken = lastHealth - currentHealth
                        local damagePercent = (damageTaken / 1000) * 100
                        satisfaction = satisfaction - damagePercent
                        lastHealth = currentHealth
                        Notify(Config.locales[Config.Locale].game["on_vehicle_damage"], "error")
                    end
                end
            end
        end
        if IsPedInAnyVehicle(PlayerPedId()) then
            if not controlopen then
                controlopen = true
                SendNUIMessage({
                    action = "OpenControlMenu",
                })
            end
            if vehicle then
                if GetVehicleNumberPlateText(GetVehiclePedIsIn(PlayerPedId())) == GetVehicleNumberPlateText(vehicle) then
                else
                    Notify(Config.locales[Config.Locale].game["false_car_finish"], "error")
                    injob = false
                    TriggerServerEvent("ak4y-taxi:CancelJob", true)

                    break
                end
            end
        else
            if controlopen then
                controlopen = false
                SendNUIMessage({
                    action = "CloseControlMenu",
                })
            end
        end

        outsideTemp = GetWeather()
    
        if airOn then
            if mintempwithair <= insideTemp - 0.02 then
                insideTemp = insideTemp - (fanlevel / 100)
            end
            if maxtempwithair >= insideTemp + 0.02 then
                insideTemp = insideTemp + 0.02
            end
        else
            if insideTemp + 0.02 < maxtempwithair then
                insideTemp = insideTemp + 0.02
            end
        end

        local percent = 0

        if insideTemp < minComfortTemp then
            satisfaction = satisfaction - 0.2
            SendNUIMessage({
                action = "NotSatisfied",
                degree = insideTemp,
            })
        elseif insideTemp > maxComfortTemp then
            SendNUIMessage({
                action = "NotSatisfied",
                degree = insideTemp,
            })
            satisfaction = satisfaction - 0.2
        else
            SendNUIMessage({
                action = "Satisfied",
                degree = insideTemp,
            })
            if satisfaction + 0.2 <= 100 then
                satisfaction = satisfaction + 0.2
            end
        end
        Wait(2500)
    end
end)

RegisterNUICallback('GetLeaderBoard', function(data, cb)
    local newdata = CORE:Trigger('ak4y-taxi:GetLeaderBoard')
    if newdata then
        cb(newdata)
    else
        cb(false)
    end
end)

RegisterNetEvent("ak4y-taxi:ReceiveTaximeterDetails", function(data)
    if first then
        first = false
        SendNUIMessage({
            action = "SetFocusKey",
            key = GetKeyCode(Config.Keys["mouse"].key),
        })
        SendNUIMessage({
            action = "init",
            data = Config,
            locales = Config.locales[Config.Locale]
        })
    end
    remoteTaximeterActive = (type(data) == "table" and data.hired == true)
    remoteTaximeterLastSync = GetGameTimer()
    local currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if currentVehicle and currentVehicle ~= 0 then
        remoteTaximeterVehicleNet = NetworkGetNetworkIdFromEntity(currentVehicle) or 0
    else
        remoteTaximeterVehicleNet = 0
    end
    SendNUIMessage({
        action = "SetTaximeterDetails",
        data = data,
    })
end)

RegisterNetEvent("ak4y-taxi:UpdateMeterDisplay", function(distance, price)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return end
    if not injob then
        remoteTaximeterActive = true
        remoteTaximeterLastSync = GetGameTimer()
        remoteTaximeterVehicleNet = NetworkGetNetworkIdFromEntity(vehicle) or 0
    end
    SendNUIMessage({
        action = "DistancePrice",
        distance = distance,
        price = price
    })
end)

CreateThread(function()
    while true do
        Wait(200)
        local ped = PlayerPedId()
        local inAnyVehicle = IsPedInAnyVehicle(ped)
        local inJobTaxi = injob and vehicle and vehicle ~= 0 and IsPedInVehicle(ped, vehicle)
        local driverShouldSee = inJobTaxi
        local remoteFresh = (GetGameTimer() - (remoteTaximeterLastSync or 0)) <= 2500
        local currentVeh = GetVehiclePedIsIn(ped, false)
        local currentVehNet = 0
        if currentVeh and currentVeh ~= 0 then
            currentVehNet = NetworkGetNetworkIdFromEntity(currentVeh) or 0
        end
        local passengerShouldSee = (not injob)
            and remoteTaximeterActive
            and remoteFresh
            and inAnyVehicle
            and currentVehNet ~= 0
            and currentVehNet == (remoteTaximeterVehicleNet or 0)
        local shouldShow = driverShouldSee or passengerShouldSee

        if not inAnyVehicle then
            remoteTaximeterActive = false
            remoteTaximeterLastSync = 0
            remoteTaximeterVehicleNet = 0
            driverManualTaximeter = false
            shouldShow = false
            SetTaxiMeterVisible(shouldShow)
        end
    end
end)


RegisterNUICallback('PayBill', function(data, cb)
    local newdata = false
    if invoiceToken then
        newdata = CORE:Trigger('ak4y-taxi:paybill', invoiceToken)
    end
    cb(newdata)
end)

CreateThread(function()
    while true do
        Wait(1000)
        if injob then
            if not IsPedInAnyVehicle(PlayerPedId()) then
                SetTaxiMeterVisible(false)
                airscreenon = false
                SendNUIMessage({
                    action = "AirScreen",
                    bool = airscreenon
                })
                SendNUIMessage({
                    action = "OutVehicle",
                })
                while injob and not IsPedInAnyVehicle(PlayerPedId()) do
                    Wait(500)
                end
                if injob and IsPedInAnyVehicle(PlayerPedId()) then
                    SendNUIMessage({
                        action = "AgainInvehicle",
                    })
                end
            end
        end
        if ActiveJobDetails.hired then
            if IsPedInVehicle(PlayerPedId(), vehicle) then
            else
                SetTaxiMeterVisible(false)
                airscreenon = false
                SendNUIMessage({
                    action = "AirScreen",
                    bool = airscreenon
                })
            end
        end

        if vehicle and lastBilledPassengerId then
            local currentPassengerId = IsPlayerInVehicleExceptDriver(vehicle)
            if not currentPassengerId or currentPassengerId ~= lastBilledPassengerId then
                lastBilledPassengerId = nil
            end
        end
    end
end)

function Notify(text, type)
    TriggerEvent('QBCore:Notify', text, type)
end

CreateThread(function()
    for k,v in pairs(Config.CabLocations) do
        if v.blip then
            local blip = AddBlipForCoord(v.AccesCoord)
            SetBlipSprite(blip, v.blip.sprite)
            SetBlipDisplay(blip, 2)
            SetBlipScale(blip, 0.6)
            SetBlipColour(blip, v.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.locales[Config.Locale].ui.cab_blip_name or v.blip.name)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

function GetKeyCode(key)
    local keys = {
        ["a"] = 65, ["b"] = 66, ["c"] = 67, ["d"] = 68, ["e"] = 69,
        ["f"] = 70, ["g"] = 71, ["h"] = 72, ["i"] = 73, ["j"] = 74,
        ["k"] = 75, ["l"] = 76, ["m"] = 77, ["n"] = 78, ["o"] = 79,
        ["p"] = 80, ["q"] = 81, ["r"] = 82, ["s"] = 83, ["t"] = 84,
        ["u"] = 85, ["v"] = 86, ["w"] = 87, ["x"] = 88, ["y"] = 89,
        ["z"] = 90,
    }
    return keys[string.lower(key)] or 0
end

function EnsureControlOfEntity(entity)
    if not NetworkHasControlOfEntity(entity) then
        NetworkRequestControlOfEntity(entity)
        local timeout = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(entity) and DoesEntityExist(entity) and GetGameTimer() < timeout do
            NetworkRequestControlOfEntity(entity)
            Wait(0)
        end
    end
end

function MakePedNetworked(myLocalPed)
    if DoesEntityExist(myLocalPed) then
        if NetworkGetEntityIsNetworked(myLocalPed) then 
            print("Bu ped zaten networklü!")
            return 
        end

        NetworkRegisterEntityAsNetworked(myLocalPed)

        local netId = NetworkGetNetworkIdFromEntity(myLocalPed)
        
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)

        print("Ped artık Networked! NetID: " .. netId)
    else
        print("Ped bulunamadı!")
    end
end

exports('taksiciSayi', function() 
    return CORE:Trigger('ak4y-taxi:taksiciSayi')
end)

RegisterCommand('end_trip2', function()
    HandleEndTrip()
end, false)

RegisterCommand('taximeter_bos', function()
    if not injob then return end

    finishcoord = nil
    npcPickupCoord = nil
    npcDropCoord = nil
    currentdistance = nil
    distanceKm = 0
    distanceTravelled = 0
    price = 0
    zero = true
    isnpcinvehicle = false
    takecustomer = false
    if client then
        DeleteEntity(client)
        client = false
    end

    ActiveJobDetails.vacant = true
    ActiveJobDetails.hired = false
    ActiveJobDetails.time = false
    
    SyncJobState()
    SendNUIMessage({
        action = "SetTaximeterDetails",
        data = ActiveJobDetails,
    })
    SendNUIMessage({
        action = "DistancePrice",
        distance = 0,
        price = 0
    })
end, false)

RegisterCommand('taximeter_dolu', function()
    if not injob then return end
    ActiveJobDetails.vacant = false
    ActiveJobDetails.hired = true
    ActiveJobDetails.time = true
    SyncJobState()
    SendNUIMessage({
        action = "SetTaximeterDetails",
        data = ActiveJobDetails,
    })
end, false)

RegisterCommand('taximeter_sure', function()
    if not injob then return end
    ActiveJobDetails.time = not ActiveJobDetails.time
    SyncJobState()
    SendNUIMessage({
        action = "SetTaximeterDetails",
        data = ActiveJobDetails,
    })
end, false)

RegisterKeyMapping('taximeter_bos', Config.locales[Config.Locale].ui.key_taximeter_empty, "keyboard", "NUMPAD1")
RegisterKeyMapping('taximeter_dolu', Config.locales[Config.Locale].ui.key_taximeter_hired, "keyboard", "NUMPAD2")
RegisterKeyMapping('taximeter_sure', Config.locales[Config.Locale].ui.key_time_toggle, "keyboard", "NUMPAD3")
RegisterKeyMapping('end_trip2', Config.locales[Config.Locale].ui.key_end_trip, "keyboard", "NUMPAD4")