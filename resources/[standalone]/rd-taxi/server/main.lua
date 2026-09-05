local QBCore = nil
local ESX    = nil

if Config.Framework == "qbcore" then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == "esx" then
    ESX = exports["es_extended"]:getSharedObject()
end

local activeTaxis   = {}  
local reservedTaxis = {}  
local demandedTaxis = {}  

if Config.Framework == "qbcore" then
    QBCore.Functions.CreateCallback('rd-taxi:server:processPayment', function(source, cb, amount)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then cb(false, "Player not found") return end

        local cash = Player.PlayerData.money.cash or 0
        local bank = Player.PlayerData.money.bank or 0

        if cash >= amount then
            Player.Functions.RemoveMoney('cash', amount, "taxi-service")
            cb(true, "Paid from cash")
        elseif bank >= amount then
            Player.Functions.RemoveMoney('bank', amount, "taxi-service")
            cb(true, "Paid from bank")
        else
            cb(false, L("PAYMENT_FAIL", amount))
        end
    end)
end

if Config.Framework == "esx" then
    ESX.RegisterServerCallback('rd-taxi:server:processPayment', function(source, cb, amount)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then cb(false, "Player not found") return end

        local cash = xPlayer.getMoney()
        local bank = xPlayer.getAccount('bank').money

        if cash >= amount then
            xPlayer.removeMoney(amount)
            cb(true, "Paid from cash")
        elseif bank >= amount then
            xPlayer.removeAccountMoney('bank', amount)
            cb(true, "Paid from bank")
        else
            cb(false, L("PAYMENT_FAIL", amount))
        end
    end)
end

function GetStopByName(stopName)
    for _, stop in pairs(Config.TaxiStops) do
        if stop.name == stopName then return stop end
    end
    return nil
end

function UpdateTaxiStatus(taxiId, newStatus)
    local taxi = activeTaxis[taxiId]
    if not taxi then return end

    if taxi.status ~= newStatus then
        taxi.status          = newStatus
        taxi.lastStatusChange = GetGameTimer()
        TriggerClientEvent('rd-taxi:client:updateStatus', -1, taxiId, newStatus, 0)
    end
end

function SpawnTaxi(driver, stopData)
    local spawn = stopData.spawnCoords

    activeTaxis[driver.id] = {
        id               = driver.id,
        name             = driver.name,
        pedModel         = driver.pedModel,
        driverImage      = driver.driverImage,
        vehicleModel     = driver.vehicleModel,
        vehicleImage     = driver.vehicleImage,
        voiceFile        = driver.voiceFile,
        color            = driver.color,
        assignedStop     = driver.assignedStop,
        status           = Config.Status.AVAILABLE,
        vehicle          = nil,
        ped              = nil,
        spawnCoords      = spawn,
        currentPassenger = nil,
        destination      = nil,
        lastStatusChange = GetGameTimer()
    }

    TriggerClientEvent('rd-taxi:client:spawnTaxi', -1, driver.id, driver, spawn)
end

Citizen.CreateThread(function()
    Citizen.Wait(2000)

    for _, driver in pairs(Config.TaxiDrivers) do
        local stopData = GetStopByName(driver.assignedStop)
        if stopData then
            SpawnTaxi(driver, stopData)
        else
            print("[RD-Taxi] WARNING: driver " .. driver.name .. " has unknown assignedStop: " .. tostring(driver.assignedStop))
        end
    end

    
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Config.UpdateInterval)
            UpdateAllTaxiStatus()
        end
    end)

    
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(5000)
            CheckReservedTimeouts()
        end
    end)
end)

RegisterServerEvent('rd-taxi:server:taxiSpawned')
AddEventHandler('rd-taxi:server:taxiSpawned', function(taxiId, vehNetId, pedNetId)
    if activeTaxis[taxiId] then
        activeTaxis[taxiId].vehicle = vehNetId
        activeTaxis[taxiId].ped     = pedNetId
    end
end)

RegisterNetEvent('rd-taxi:server:requestTaxiData')
AddEventHandler('rd-taxi:server:requestTaxiData', function()
    
end)

RegisterNetEvent('rd-taxi:server:requestTaxiList')
AddEventHandler('rd-taxi:server:requestTaxiList', function(stopName)
    local src   = source
    local taxis = {}

    for _, taxi in pairs(activeTaxis) do
        local isDemandedByPlayer = demandedTaxis[taxi.id] == src

        table.insert(taxis, {
            id           = taxi.id,
            name         = taxi.name,
            driverImage  = taxi.driverImage,
            vehicleImage = taxi.vehicleImage,
            voiceFile    = taxi.voiceFile,
            color        = taxi.color,
            status       = taxi.status,
            eta          = 0,
            stopsHere    = taxi.assignedStop == stopName,
            demandedByMe = isDemandedByPlayer
        })
    end

    local stopData  = GetStopByName(stopName)
    local stopLabel = stopData and stopData.label or stopName

    TriggerClientEvent('rd-taxi:client:openUI', src, taxis, stopLabel)
end)

RegisterNetEvent('rd-taxi:server:notifyTaxi')
AddEventHandler('rd-taxi:server:notifyTaxi', function(taxiId, notifyType)
    local src  = source
    local taxi = activeTaxis[taxiId]

    if not taxi then return end

    
    if notifyType == "demand" then
        if taxi.status ~= Config.Status.RETURNING then return end

        demandedTaxis[taxiId]    = src
        taxi.currentPassenger    = src

        TriggerClientEvent('chat:addMessage', src, {
            color     = {138, 43, 226},
            multiline = true,
            args      = {"Taxi Service", L("TAXI_RESERVED")}
        })

        TriggerClientEvent('rd-taxi:client:updateDemandStatus', -1, taxiId, src)
        return
    end

    
    if notifyType == "normal" then
        if taxi.status ~= Config.Status.AVAILABLE then return end
    end

    
    if notifyType == "waiting" then
        if taxi.status ~= Config.Status.JUST_FINISHED then return end
    end

    
    if not taxi.vehicle then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 80, 80},
            args  = {"Taxi Service", "This taxi is not ready yet. Please wait a moment."}
        })
        return
    end

    reservedTaxis[taxiId] = {
        playerId  = src,
        timestamp = GetGameTimer()
    }

    UpdateTaxiStatus(taxiId, Config.Status.EN_ROUTE)
    taxi.currentPassenger = src

    TriggerClientEvent('rd-taxi:client:driveToPlayer', -1, taxiId, taxi.vehicle, src, taxi.name)
end)

RegisterServerEvent('rd-taxi:server:playerEnteredTaxi')
AddEventHandler('rd-taxi:server:playerEnteredTaxi', function(taxiId)
    local src  = source

    reservedTaxis[taxiId] = nil

    if demandedTaxis[taxiId] == src then
        demandedTaxis[taxiId] = nil
        TriggerClientEvent('rd-taxi:client:updateDemandStatus', -1, taxiId, nil)
    end
end)

RegisterNetEvent('rd-taxi:server:taxiArrivedAtPlayer')
AddEventHandler('rd-taxi:server:taxiArrivedAtPlayer', function(taxiId)
    local taxi = activeTaxis[taxiId]
    if not taxi then return end

    if taxi.currentPassenger then
        TriggerClientEvent('rd-taxi:client:playDriverVoice', taxi.currentPassenger, taxiId, taxi.vehicle, taxi.voiceFile)
    end

    
    Citizen.CreateThread(function()
        Citizen.Wait(Config.ReservedTimeout * 1000)

        if taxi.status == Config.Status.EN_ROUTE and reservedTaxis[taxiId] then
            reservedTaxis[taxiId]    = nil
            taxi.status              = Config.Status.AVAILABLE
            taxi.currentPassenger    = nil
            TriggerClientEvent('rd-taxi:client:returnToSpawn', -1, taxiId, taxi.vehicle, taxi.spawnCoords, taxi.name)
        end
    end)
end)

RegisterNetEvent('rd-taxi:server:setDestination')
AddEventHandler('rd-taxi:server:setDestination', function(taxiId, coords)
    local src  = source
    local taxi = activeTaxis[taxiId]

    if not taxi or taxi.currentPassenger ~= src then return end
    if not taxi.vehicle then return end

    taxi.status      = Config.Status.DELIVERING
    taxi.destination = coords

    reservedTaxis[taxiId] = nil

    TriggerClientEvent('rd-taxi:client:driveToDestination', -1, taxiId, taxi.vehicle, coords, taxi.name)
end)

RegisterNetEvent('rd-taxi:server:deliveryComplete')
AddEventHandler('rd-taxi:server:deliveryComplete', function(taxiId)
    local taxi = activeTaxis[taxiId]
    if not taxi then return end

    UpdateTaxiStatus(taxiId, Config.Status.JUST_FINISHED)

    if taxi.currentPassenger then
        TriggerClientEvent('rd-taxi:client:deliveryComplete', taxi.currentPassenger)
    end
end)

RegisterServerEvent('rd-taxi:server:playerExitedTaxi')
AddEventHandler('rd-taxi:server:playerExitedTaxi', function(taxiId)
    local src  = source
    local taxi = activeTaxis[taxiId]

    if not taxi then return end

    TriggerClientEvent('rd-taxi:client:removeBlip', src, taxiId)

    taxi.currentPassenger = nil
    taxi.destination      = nil

    UpdateTaxiStatus(taxiId, Config.Status.RETURNING)

    if not taxi.vehicle then return end

    SetTimeout(2000, function()
        TriggerClientEvent('rd-taxi:client:returnToSpawn', -1, taxiId, taxi.vehicle, taxi.spawnCoords, taxi.name)
    end)
end)

RegisterNetEvent('rd-taxi:server:taxiReturnedToSpawn')
AddEventHandler('rd-taxi:server:taxiReturnedToSpawn', function(taxiId)
    local taxi = activeTaxis[taxiId]
    if not taxi then return end

    if demandedTaxis[taxiId] then
        local demandPlayerId = demandedTaxis[taxiId]

        TriggerClientEvent('rd-taxi:client:playDriverVoice', demandPlayerId, taxiId, taxi.vehicle, taxi.voiceFile)

        UpdateTaxiStatus(taxiId, Config.Status.AVAILABLE)
        reservedTaxis[taxiId] = {
            playerId  = demandPlayerId,
            timestamp = GetGameTimer()
        }

        TriggerClientEvent('rd-taxi:client:demandedTaxiReady', demandPlayerId, taxiId, taxi.vehicle)
    else
        UpdateTaxiStatus(taxiId, Config.Status.AVAILABLE)
        taxi.currentPassenger = nil
    end

    taxi.destination = nil
end)

RegisterNetEvent('rd-taxi:server:playerDisconnected')
AddEventHandler('rd-taxi:server:playerDisconnected', function(taxiId)
    local taxi = activeTaxis[taxiId]
    if not taxi then return end

    taxi.currentPassenger = nil
    if taxi.vehicle then
        TriggerClientEvent('rd-taxi:client:returnToSpawn', -1, taxiId, taxi.vehicle, taxi.spawnCoords, taxi.name)
    end
end)

RegisterNetEvent('rd-taxi:server:demandTimeout')
AddEventHandler('rd-taxi:server:demandTimeout', function(taxiId)
    local taxi = activeTaxis[taxiId]
    if not taxi then return end

    reservedTaxis[taxiId] = nil
    demandedTaxis[taxiId] = nil
    taxi.currentPassenger = nil
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    for taxiId, taxi in pairs(activeTaxis) do
        if taxi.currentPassenger == src then
            taxi.currentPassenger = nil
            taxi.destination      = nil
            reservedTaxis[taxiId] = nil
            if taxi.vehicle then
                TriggerClientEvent('rd-taxi:client:returnToSpawn', -1, taxiId, taxi.vehicle, taxi.spawnCoords, taxi.name)
            end
            UpdateTaxiStatus(taxiId, Config.Status.RETURNING)
        end
        if demandedTaxis[taxiId] == src then
            demandedTaxis[taxiId] = nil
            TriggerClientEvent('rd-taxi:client:updateDemandStatus', -1, taxiId, nil)
        end
    end
end)

function UpdateAllTaxiStatus()
    for _, taxi in pairs(activeTaxis) do
        if taxi.status == Config.Status.JUST_FINISHED then
            local elapsed = (GetGameTimer() - taxi.lastStatusChange) / 1000
            if elapsed > 300 and taxi.vehicle then
                TriggerClientEvent('rd-taxi:client:returnToSpawn', -1, taxi.id, taxi.vehicle, taxi.spawnCoords, taxi.name)
                UpdateTaxiStatus(taxi.id, Config.Status.RETURNING)
            end
        end
    end
end

function CheckReservedTimeouts()
    for taxiId, reservation in pairs(reservedTaxis) do
        local elapsed = (GetGameTimer() - reservation.timestamp) / 1000
        if elapsed > Config.ReservedTimeout then
            reservedTaxis[taxiId] = nil
            local taxi = activeTaxis[taxiId]
            if taxi then
                taxi.status          = Config.Status.AVAILABLE
                taxi.currentPassenger = nil
            end
        end
    end
end