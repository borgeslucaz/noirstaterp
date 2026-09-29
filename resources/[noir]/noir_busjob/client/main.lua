local Config = require 'config.shared'
local Rules = require 'shared.rules'
local Integrations = require 'client.integrations'

local ui = { open = false, closing = false, busy = false, menu = nil }
local catalog = nil ---@type table? visão pública vinda do servidor
local routeSession = nil
local depotPed, depotBlip, currentBlip, waitingPeds, onboardPeds = nil, nil, nil, {}, {}
local closeToken = nil

local TARGET_NAME = 'noir_busjob:central:open'
local DEPOT_SPAWN_DISTANCE, DEPOT_DESPAWN_DISTANCE = 80.0, 100.0

---Contexto dividido com o editor (client/editor.lua), sem global.
local Bus = {}

local function notify(message, kind)
    Integrations.notify(message, kind or 'inform')
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end
Bus.send = send

local function removeBlip()
    if currentBlip then RemoveBlip(currentBlip); currentBlip = nil end
end

local function removeDepotBlip()
    if depotBlip then RemoveBlip(depotBlip); depotBlip = nil end
end

-- O blip da Central marca onde o trabalho começa. Durante uma linha ele sai do mapa:
-- o objetivo da vez já é marcado por `destination`, e no retorno os dois cairiam nas
-- mesmas coordenadas da garagem.
local function createDepotBlip()
    if not catalog or depotBlip or routeSession then return end
    local blip, coords = catalog.depot.blip, catalog.depot.ped
    if not blip.enabled then return end
    depotBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(depotBlip, blip.sprite)
    SetBlipColour(depotBlip, blip.color)
    SetBlipScale(depotBlip, blip.scale)
    SetBlipAsShortRange(depotBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blip.label)
    EndTextCommandSetBlipName(depotBlip)
end

local function clearPedList(peds)
    for _, ped in ipairs(peds) do if DoesEntityExist(ped) then DeletePed(ped) end end
end

local function clearWaitingPeds()
    clearPedList(waitingPeds)
    waitingPeds = {}
end

local function clearOnboardPeds()
    clearPedList(onboardPeds)
    onboardPeds = {}
end

local function clearPeds()
    clearWaitingPeds()
    clearOnboardPeds()
end

local function cleanup()
    local vehicle = routeSession and NetToVeh(routeSession.netId)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then FreezeEntityPosition(vehicle, false) end
    routeSession = nil
    removeBlip()
    createDepotBlip()
    clearPeds()
    send('bus:setRouteHud', { visible = false })
end

local function destination(coords, label)
    removeBlip()
    currentBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(currentBlip, 1); SetBlipColour(currentBlip, 3); SetBlipRoute(currentBlip, true); SetBlipRouteColour(currentBlip, 3)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(label); EndTextCommandSetBlipName(currentBlip)
end

local function finalizeClose()
    ui.open, ui.closing, ui.busy, ui.menu = false, false, false, nil
    closeToken = nil
    SetNuiFocus(false, false)
end

local function beginClose(notifyNui)
    if not ui.open or ui.closing then return end
    ui.closing = true
    if notifyNui then send('busMenu:close', { immediate = false }) end
    local token = {}
    closeToken = token
    SetTimeout(1200, function()
        if closeToken == token then finalizeClose() end
    end)
end

local function forceClose()
    if ui.open or ui.closing then send('busMenu:close', { immediate = true }) end
    finalizeClose()
end

local function openMenu()
    if ui.open or ui.closing or cache.vehicle or Bus.editorOpen then return end
    local response = lib.callback.await('noir_busjob:server:openMenu', false)
    if not response or not response.ok then return notify(locale('central.open_failed'), 'error') end
    ui.open, ui.closing, ui.busy, ui.menu = true, false, false, response
    SetNuiFocus(true, true); SetNuiFocusKeepInput(false)
    send('busMenu:open', response.data)
end

-- Passageiros -------------------------------------------------------------------------

---Model de passageiro conferido antes do request: model ausente derruba o cliente no
---Enhanced.
local function passengerModel(index)
    local models = catalog and catalog.passenger.models or {}
    if #models == 0 then return nil end
    local model = joaat(models[(index - 1) % #models + 1])
    if not IsModelInCdimage(model) or not IsModelAPed(model) then return nil end
    return model
end

---Ponto de espera: sorteado dentro da área da parada, no chão; sem área, no círculo em
---volta de onde o ônibus encosta (o jeito antigo).
local function waitingPoint(stop)
    if stop.zone then
        local point = Rules.randomPointInZone(stop.zone, math.random)
        local top = stop.zone.z + stop.zone.height / 2
        local found, ground = GetGroundZFor_3dCoord(point.x, point.y, top, false)
        return vec3(point.x, point.y, found and ground or stop.zone.z - stop.zone.height / 2)
    end
    local angle, radius = math.random() * math.pi * 2, Config.fallbackSpawnRadius
    return vec3(stop.dock.x + math.cos(angle) * radius, stop.dock.y + math.sin(angle) * radius, stop.dock.z - 1.0)
end

---@param stop table { dock, zone? }
function Bus.spawnWaitingPassengers(count, stop)
    clearWaitingPeds()
    if not stop or count <= 0 then return end
    for i = 1, count do
        local model = passengerModel(i)
        if model and lib.requestModel(model, 3000) then
            local point = waitingPoint(stop)
            -- De frente para onde o ônibus encosta.
            local heading = GetHeadingFromVector_2d(stop.dock.x - point.x, stop.dock.y - point.y)
            local ped = CreatePed(4, model, point.x, point.y, point.z, heading, false, false)
            SetBlockingOfNonTemporaryEvents(ped, true); TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
            waitingPeds[#waitingPeds + 1] = ped
            SetModelAsNoLongerNeeded(model)
        end
    end
end

function Bus.clearWaitingPassengers()
    clearWaitingPeds()
end

local function currentStop()
    return routeSession and routeSession.route.stops[routeSession.stopIndex]
end

-- NUI ---------------------------------------------------------------------------------

RegisterNUICallback('uiReady', function(_, cb)
    cb({ ok = true })
    if ui.open and not ui.closing and ui.menu then send('busMenu:open', ui.menu.data) end
    if Bus.onUiReady then Bus.onUiReady() end
end)
RegisterNUICallback('closeMenu', function(_, cb)
    if not ui.open or ui.closing or ui.busy then cb({ ok = false }); return end
    beginClose(false)
    cb({ ok = true })
end)
RegisterNUICallback('closeComplete', function(_, cb)
    cb({ ok = true })
    finalizeClose()
end)
RegisterNUICallback('startRoute', function(data, cb)
    if not ui.open or ui.closing or ui.busy or not ui.menu or type(data) ~= 'table' or type(data.routeId) ~= 'string' then cb({ ok = false, code = 'invalid_session' }); return end
    local model = type(data.vehicle) == 'string' and data.vehicle or nil
    ui.busy = true
    local response = lib.callback.await('noir_busjob:server:startRoute', false, ui.menu.sessionId, data.routeId, model)
    if not response or not response.ok then ui.busy = false; cb(response or { ok = false, code = 'internal_error' }); return end
    local vehicle, attempts = 0, 0
    while attempts < 50 and vehicle == 0 do vehicle = NetToVeh(response.netId); attempts = attempts + 1; Wait(100) end
    if vehicle == 0 then
        TriggerServerEvent('noir_busjob:server:cancel')
        ui.busy = false
        cb({ ok = false, code = 'spawn_failed' })
        return
    end
    routeSession = { netId = response.netId, route = response.route, doors = response.doors or {}, stopIndex = 1, capacity = response.capacity, doorsOpen = false, docked = false, waitingRequested = false, lastHud = 0 }
    removeDepotBlip()
    local first = response.route.stops[1]
    destination(first.dock, locale('route.next_stop'))
    send('bus:setRouteHud', { visible = true, routeCode = response.route.code, routeName = response.route.name, stopName = first.name, stopIndex = 1, stopCount = response.route.stopCount, passengers = 0, capacity = response.capacity })
    ui.busy = false
    cb({ ok = true })
    beginClose(true)
end)
RegisterNUICallback('returnVehicle', function(_, cb)
    if not ui.open or ui.closing or ui.busy or not ui.menu then cb({ ok = false, code = 'invalid_session' }); return end
    ui.busy = true
    local response = lib.callback.await('noir_busjob:server:returnVehicle', false, ui.menu.sessionId)
    ui.busy = false
    if not response or not response.ok then cb(response or { ok = false, code = 'internal_error' }); return end
    cleanup()
    ui.menu.data = response.data
    notify(locale('central.returned'), 'success')
    cb(response)
end)

-- Serviço da parada -------------------------------------------------------------------

RegisterNetEvent('noir_busjob:client:waitingPassengers', function(data)
    if not routeSession or type(data) ~= 'table' or data.stopIndex ~= routeSession.stopIndex then return end
    Bus.spawnWaitingPassengers(data.board, currentStop())
end)

local function waitForTasks(peds, vehicle, entering, timeout)
    local deadline = GetGameTimer() + timeout
    while GetGameTimer() < deadline do
        local complete = true
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) and (IsPedInVehicle(ped, vehicle, false) ~= entering) then complete = false break end
        end
        if complete then return end
        Wait(100)
    end
end

local function freePassengerSeat(vehicle, reservedSeats)
    for seat = 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if not reservedSeats[seat] and IsVehicleSeatFree(vehicle, seat) then return seat end
    end
end

local function servicePassengers(data)
    if not routeSession or routeSession.servicing or data.stopIndex ~= routeSession.stopIndex then return end
    local vehicle = NetToVeh(routeSession.netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local stopSettings = catalog.stop

    routeSession.docked, routeSession.doorsOpen, routeSession.servicing = true, true, true
    FreezeEntityPosition(vehicle, true)
    for _, door in ipairs(routeSession.doors) do
        if GetIsDoorValid(vehicle, door) then SetVehicleDoorOpen(vehicle, door, false, false) end
    end
    local stop = currentStop()
    send('bus:setRouteHud', { visible = true, mode = 'boarding', stopName = stop.name, distance = 0, passengers = routeSession.passengers or 0, capacity = data.capacity, routeCode = routeSession.route.code, stopIndex = routeSession.stopIndex, stopCount = #routeSession.route.stops, service = true, serviceTimeoutMs = data.timeoutMs })

    CreateThread(function()
        local leaving = {}
        for i = #onboardPeds, 1, -1 do
            if #leaving >= data.drop then break end
            local ped = table.remove(onboardPeds, i)
            if DoesEntityExist(ped) then
                ClearPedTasks(ped)
                TaskLeaveVehicle(ped, vehicle, 0)
                leaving[#leaving + 1] = ped
            end
        end
        waitForTasks(leaving, vehicle, false, stopSettings.pedExitTimeoutMs)
        for _, ped in ipairs(leaving) do
            if DoesEntityExist(ped) then
                TaskWanderStandard(ped, 10.0, 10)
                SetTimeout(catalog.passenger.exitDespawnMs, function()
                    if DoesEntityExist(ped) then DeletePed(ped) end
                end)
            end
        end

        local boarding = {}
        local reservedSeats = {}
        local maximum = math.min(data.board, #waitingPeds)
        for _ = 1, maximum do
            local ped = table.remove(waitingPeds, 1)
            local seat = freePassengerSeat(vehicle, reservedSeats)
            if ped and DoesEntityExist(ped) and seat then
                reservedSeats[seat] = true
                ClearPedTasks(ped)
                TaskEnterVehicle(ped, vehicle, stopSettings.pedEnterTimeoutMs, seat, 1.0, 1, 0)
                boarding[#boarding + 1] = { ped = ped, seat = seat }
            elseif ped and DoesEntityExist(ped) then
                DeletePed(ped)
            end
        end
        local boardingPeds = {}
        for _, entry in ipairs(boarding) do boardingPeds[#boardingPeds + 1] = entry.ped end
        waitForTasks(boardingPeds, vehicle, true, stopSettings.pedEnterTimeoutMs)
        for _, entry in ipairs(boarding) do
            if DoesEntityExist(entry.ped) then
                if not IsPedInVehicle(entry.ped, vehicle, false) and IsVehicleSeatFree(vehicle, entry.seat) then SetPedIntoVehicle(entry.ped, vehicle, entry.seat) end
                if IsPedInVehicle(entry.ped, vehicle, false) then onboardPeds[#onboardPeds + 1] = entry.ped else DeletePed(entry.ped) end
            end
        end
        clearWaitingPeds()
        if routeSession and routeSession.servicing then TriggerServerEvent('noir_busjob:server:completeStopService') end
    end)
end

RegisterNetEvent('noir_busjob:client:serviceStop', servicePassengers)
RegisterNetEvent('noir_busjob:client:stopCompleted', function(data)
    if not routeSession then return end
    clearWaitingPeds(); routeSession.docked, routeSession.doorsOpen, routeSession.servicing = false, false, false
    routeSession.passengers = data.passengers or routeSession.passengers
    local vehicle = NetToVeh(routeSession.netId)
    if vehicle ~= 0 then
        FreezeEntityPosition(vehicle, false)
        for _, door in ipairs(routeSession.doors) do
            if GetIsDoorValid(vehicle, door) then SetVehicleDoorShut(vehicle, door, false) end
        end
    end
    notify(data.timedOut and locale('route.stop_timeout') or (data.score >= 95 and locale('route.stop_perfect') or locale('route.stop_done')), data.score >= 95 and 'success' or 'inform')
    if data.returning then
        destination(catalog.depot.ped, locale('route.return_depot'))
        send('bus:setRouteHud', { visible = true, mode = 'returning', routeCode = routeSession.route.code, passengers = 0, capacity = routeSession.capacity })
    else
        routeSession.stopIndex = routeSession.stopIndex + 1
        routeSession.waitingRequested = false
        local stop = currentStop()
        destination(stop.dock, locale('route.next_stop'))
        send('bus:setRouteHud', { visible = true, routeCode = routeSession.route.code, stopName = stop.name, stopIndex = routeSession.stopIndex, stopCount = #routeSession.route.stops, passengers = routeSession.passengers or 0, capacity = routeSession.capacity })
    end
end)
RegisterNetEvent('noir_busjob:client:cleanup', function()
    if source ~= 65535 then return end
    cleanup()
end)

-- Atendente da Central ----------------------------------------------------------------

local function deleteDepotPed()
    if not depotPed then return end
    Integrations.removeEntityTarget(depotPed, TARGET_NAME)
    if DoesEntityExist(depotPed) then DeletePed(depotPed) end
    depotPed = nil
end

local function createDepotPed()
    if depotPed or not catalog then return end
    local depot = catalog.depot
    local model = joaat(depot.pedModel)
    if not IsModelInCdimage(model) or not IsModelAPed(model) then
        lib.print.error(('model do atendente inválido: %s'):format(depot.pedModel))
        return
    end
    if not lib.requestModel(model, 10000) then return end

    local coords = depot.ped
    local ped = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    SetModelAsNoLongerNeeded(model)
    if ped == 0 then return end
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    depotPed = ped

    Integrations.addEntityTarget(ped, {
        {
            name = TARGET_NAME,
            icon = 'fa-solid fa-bus',
            label = locale('target.open_central'),
            distance = 3.0,
            canInteract = function()
                return not ui.open and not ui.closing and not cache.vehicle and not Bus.editorOpen
            end,
            onSelect = openMenu,
        },
    })
end

---O atendente nasce ao chegar perto e some ao sair (v4 §11).
CreateThread(function()
    while true do
        local sleep = 1500
        if catalog then
            local distance = #(GetEntityCoords(cache.ped) - vec3(catalog.depot.ped.x, catalog.depot.ped.y, catalog.depot.ped.z))
            if distance <= DEPOT_SPAWN_DISTANCE then
                createDepotPed()
                sleep = 750
            elseif distance >= DEPOT_DESPAWN_DISTANCE then
                deleteDepotPed()
            end
        end
        Wait(sleep)
    end
end)

---Catálogo novo (editor salvou ou o servidor subiu): refaz atendente e blip.
local function applyCatalog(view)
    if type(view) ~= 'table' or type(view.depot) ~= 'table' then return end
    local moved = not catalog or catalog.depot.pedModel ~= view.depot.pedModel
        or catalog.depot.ped.x ~= view.depot.ped.x or catalog.depot.ped.y ~= view.depot.ped.y
        or catalog.depot.ped.z ~= view.depot.ped.z or catalog.depot.ped.w ~= view.depot.ped.w
    catalog = view
    Bus.catalog = view
    if moved then deleteDepotPed() end
    removeDepotBlip()
    createDepotBlip()
end

RegisterNetEvent('noir_busjob:client:catalog', function(view)
    if source ~= 65535 then return end
    applyCatalog(view)
end)

CreateThread(function()
    for _ = 1, 30 do
        local view = lib.callback.await('noir_busjob:server:catalog', false)
        if view then applyCatalog(view) return end
        Wait(2000)
    end
    lib.print.error('catálogo do ônibus não chegou do servidor')
end)

-- Laço da linha -----------------------------------------------------------------------

CreateThread(function()
    local previousSpeed = 0
    while true do
        if not routeSession or not catalog then Wait(1000) else
            local vehicle = NetToVeh(routeSession.netId)
            if vehicle == 0 or not DoesEntityExist(vehicle) then TriggerServerEvent('noir_busjob:server:cancel'); cleanup() else
                if not routeSession.cancelling and (not IsVehicleDriveable(vehicle, false) or GetVehicleEngineHealth(vehicle) <= catalog.vehicleFailure.engineHealth) then
                    routeSession.cancelling = true
                    notify(locale('route.bus_broken'), 'error')
                    TriggerServerEvent('noir_busjob:server:cancel')
                    Wait(1000)
                else
                    local coords, speed = GetEntityCoords(vehicle), GetEntitySpeed(vehicle) * 3.6
                    local stop = currentStop()
                    local distanceToStop = #(coords - vec3(stop.dock.x, stop.dock.y, stop.dock.z))
                    if not routeSession.waitingRequested and not routeSession.docked and distanceToStop <= catalog.passenger.spawnDistance then
                        routeSession.waitingRequested = true
                        TriggerServerEvent('noir_busjob:server:prepareStopPassengers')
                    end
                    if not routeSession.docked and distanceToStop <= catalog.stop.radius then TriggerServerEvent('noir_busjob:server:arriveStop') end
                    if routeSession.doorsOpen and speed > catalog.stop.maxDoorSpeedKmh + 2 then TriggerServerEvent('noir_busjob:server:telemetry', 'hardAcceleration') end
                    if HasEntityCollidedWithAnything(vehicle) then TriggerServerEvent('noir_busjob:server:telemetry', 'collision') end
                    if speed - previousSpeed > 45 then TriggerServerEvent('noir_busjob:server:telemetry', 'hardAcceleration') elseif previousSpeed - speed > 45 then TriggerServerEvent('noir_busjob:server:telemetry', 'hardBrake') end
                    previousSpeed = speed
                    if routeSession.lastHud + 500 < GetGameTimer() then
                        routeSession.lastHud = GetGameTimer()
                        if routeSession.stopIndex and not routeSession.docked then send('bus:setRouteHud', { visible = true, routeCode = routeSession.route.code, stopName = stop.name, stopIndex = routeSession.stopIndex, stopCount = #routeSession.route.stops, distance = math.floor(distanceToStop), passengers = routeSession.passengers or 0, capacity = routeSession.capacity }) end
                    end
                    local depot = catalog.depot.ped
                    if routeSession.stopIndex == #routeSession.route.stops and routeSession.docked == false and #(coords - vec3(depot.x, depot.y, depot.z)) <= catalog.depot.radius then
                        local result = lib.callback.await('noir_busjob:server:park', false)
                        if result and result.ok then send('bus:summary', result.summary); cleanup()
                        elseif result and result.code == 'too_fast' then notify(locale('route.too_fast'), 'error'); cleanup() end
                    end
                    Wait(250)
                end
            end
        end
    end
end)

function Bus.hasRoute()
    return routeSession ~= nil
end

AddEventHandler('bgrz_core:client:playerUnloaded', function() forceClose(); cleanup() end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    forceClose()
    cleanup()
    removeDepotBlip()
    deleteDepotPed()
end)

require 'client.editor'(Bus)
