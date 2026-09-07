local Config = require 'config'
local ui = { open = false, closing = false, busy = false, menu = nil }
local routeSession = nil
local depotPed, currentBlip, waitingPeds, onboardPeds = nil, nil, {}, {}
local closeToken = nil

local function notify(message, kind)
    exports.bgrz_core:Notify(message, kind or 'inform')
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function removeBlip()
    if currentBlip then RemoveBlip(currentBlip); currentBlip = nil end
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
    if ui.open or ui.closing or cache.vehicle then return end
    local response = lib.callback.await('noir_busjob:server:openMenu', false)
    if not response or not response.ok then return notify('Não foi possível abrir a Central de Transporte.', 'error') end
    ui.open, ui.closing, ui.busy, ui.menu = true, false, false, response
    SetNuiFocus(true, true); SetNuiFocusKeepInput(false)
    send('busMenu:open', response.data)
end

local function spawnWaitingPassengers(count, targetStop)
    clearWaitingPeds()
    local stop = targetStop or (routeSession and Config.stops[routeSession.route.stops[routeSession.stopIndex]])
    if not stop or count <= 0 then return end
    for i = 1, count do
        local model = joaat(i % 2 == 0 and 'a_f_y_business_01' or 'a_m_y_business_01')
        if lib.requestModel(model, 3000) then
            local angle, radius = math.random() * math.pi * 2, Config.passenger.spawnRadius
            local ped = CreatePed(4, model, stop.coords.x + math.cos(angle) * radius, stop.coords.y + math.sin(angle) * radius, stop.coords.z - 1.0, stop.coords.w, false, false)
            SetBlockingOfNonTemporaryEvents(ped, true); TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
            waitingPeds[#waitingPeds + 1] = ped
            SetModelAsNoLongerNeeded(model)
        end
    end
end

local function nearestSpawnStop()
    local coords = GetEntityCoords(cache.ped)
    local nearest, nearestDistance
    for _, stop in pairs(Config.stops) do
        local distance = #(coords - stop.coords.xyz)
        if distance <= Config.passenger.spawnDistance and (not nearestDistance or distance < nearestDistance) then
            nearest, nearestDistance = stop, distance
        end
    end
    return nearest, nearestDistance
end

RegisterNUICallback('uiReady', function(_, cb)
    cb({ ok = true })
    if ui.open and not ui.closing and ui.menu then send('busMenu:open', ui.menu.data) end
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
    ui.busy = true
    local response = lib.callback.await('noir_busjob:server:startRoute', false, ui.menu.sessionId, data.routeId)
    if not response or not response.ok then ui.busy = false; cb(response or { ok = false, code = 'internal_error' }); return end
    local vehicle, attempts = 0, 0
    while attempts < 50 and vehicle == 0 do vehicle = NetToVeh(response.netId); attempts = attempts + 1; Wait(100) end
    if vehicle == 0 then
        TriggerServerEvent('noir_busjob:server:cancel')
        ui.busy = false
        cb({ ok = false, code = 'spawn_failed' })
        return
    end
    routeSession = { netId = response.netId, route = Config.routes[data.routeId], stopIndex = 1, capacity = response.capacity, doorsOpen = false, docked = false, waitingRequested = false, lastHud = 0 }
    destination(Config.stops[routeSession.route.stops[1]].coords, 'Próxima parada')
    send('bus:setRouteHud', { visible = true, routeCode = response.route.code, routeName = response.route.name, stopName = response.route.stops[1], stopIndex = 1, stopCount = response.route.stopCount, passengers = 0, capacity = response.capacity })
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
    notify('Ônibus devolvido. Serviço cancelado sem pagamento ou XP.', 'success')
    cb(response)
end)

RegisterCommand('test_bus_stop', function()
    if routeSession then
        return notify('Finalize ou devolva o ônibus antes de testar uma parada.', 'error')
    end

    local stop, distance = nearestSpawnStop()
    if not stop then
        return notify(('Nenhuma parada encontrada em até %dm.'):format(Config.passenger.spawnDistance), 'error')
    end

    local count = math.max(1, math.random(Config.passenger.minDemand, Config.passenger.maxDemand))
    spawnWaitingPassengers(count, stop)
    notify(('%d NPC(s) criados em %s (%.1f m do centro).'):format(count, stop.name, distance), 'success')
end, false)

RegisterNetEvent('noir_busjob:client:waitingPassengers', function(data)
    if not routeSession or type(data) ~= 'table' or data.stopIndex ~= routeSession.stopIndex then return end
    spawnWaitingPassengers(data.board)
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

    routeSession.docked, routeSession.doorsOpen, routeSession.servicing = true, true, true
    FreezeEntityPosition(vehicle, true)
    for _, door in ipairs(Config.vehicleProfiles[routeSession.route.vehicle].doors) do
        if GetIsDoorValid(vehicle, door) then SetVehicleDoorOpen(vehicle, door, false, false) end
    end
    local stop = Config.stops[routeSession.route.stops[routeSession.stopIndex]]
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
        waitForTasks(leaving, vehicle, false, Config.stop.pedExitTimeoutMs)
        for _, ped in ipairs(leaving) do
            if DoesEntityExist(ped) then
                TaskWanderStandard(ped, 10.0, 10)
                SetTimeout(Config.passenger.exitDespawnMs, function()
                    if DoesEntityExist(ped) then DeletePed(ped) end
                end)
            end
        end

        local boarding = {}
        local reservedSeats = {}
        local maximum = math.min(data.board, #waitingPeds)
        for i = 1, maximum do
            local ped = table.remove(waitingPeds, 1)
            local seat = freePassengerSeat(vehicle, reservedSeats)
            if ped and DoesEntityExist(ped) and seat then
                reservedSeats[seat] = true
                ClearPedTasks(ped)
                TaskEnterVehicle(ped, vehicle, Config.stop.pedEnterTimeoutMs, seat, 1.0, 1, 0)
                boarding[#boarding + 1] = { ped = ped, seat = seat }
            elseif ped and DoesEntityExist(ped) then
                DeletePed(ped)
            end
        end
        local boardingPeds = {}
        for _, entry in ipairs(boarding) do boardingPeds[#boardingPeds + 1] = entry.ped end
        waitForTasks(boardingPeds, vehicle, true, Config.stop.pedEnterTimeoutMs)
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
        for _, door in ipairs(Config.vehicleProfiles[routeSession.route.vehicle].doors) do
            if GetIsDoorValid(vehicle, door) then SetVehicleDoorShut(vehicle, door, false) end
        end
    end
    notify(data.timedOut and 'Tempo da parada encerrado.' or (data.score >= 95 and 'Parada perfeita.' or 'Parada concluída.'), data.score >= 95 and 'success' or 'inform')
    if data.returning then
        destination(Config.Depot.coords, 'Retorne à garagem')
        send('bus:setRouteHud', { visible = true, mode = 'returning', routeCode = routeSession.route.code, passengers = 0, capacity = routeSession.capacity })
    else
        routeSession.stopIndex = routeSession.stopIndex + 1
        routeSession.waitingRequested = false
        local stop = Config.stops[routeSession.route.stops[routeSession.stopIndex]]
        destination(stop.coords, 'Próxima parada')
        send('bus:setRouteHud', { visible = true, routeCode = routeSession.route.code, stopName = stop.name, stopIndex = routeSession.stopIndex, stopCount = #routeSession.route.stops, passengers = routeSession.passengers or 0, capacity = routeSession.capacity })
    end
end)
RegisterNetEvent('noir_busjob:client:cleanup', cleanup)

CreateThread(function()
    local model = joaat(Config.Depot.pedModel)
    if not lib.requestModel(model, 10000) then
        return notify('Não foi possível carregar o atendente da Central.', 'error')
    end

    local coords = Config.Depot.coords
    depotPed = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    SetEntityAsMissionEntity(depotPed, true, true)
    FreezeEntityPosition(depotPed, true)
    SetEntityInvincible(depotPed, true)
    SetBlockingOfNonTemporaryEvents(depotPed, true)
    TaskStartScenarioInPlace(depotPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(model)

    exports.ox_target:addLocalEntity(depotPed, {
        {
            name = 'noir_busjob_central',
            icon = 'fa-solid fa-bus',
            label = locale('target.open_central'),
            distance = 3.0,
            canInteract = function()
                return not ui.open and not ui.closing and not cache.vehicle
            end,
            onSelect = openMenu,
        },
    })
end)

CreateThread(function()
    local previousSpeed = 0
    while true do
        if not routeSession then Wait(1000) else
            local vehicle = NetToVeh(routeSession.netId)
            if vehicle == 0 or not DoesEntityExist(vehicle) then TriggerServerEvent('noir_busjob:server:cancel'); cleanup() else
                if not routeSession.cancelling and (not IsVehicleDriveable(vehicle, false) or GetVehicleEngineHealth(vehicle) <= Config.vehicleFailure.engineHealth) then
                    routeSession.cancelling = true
                    notify('O ônibus quebrou. O serviço foi cancelado.', 'error')
                    TriggerServerEvent('noir_busjob:server:cancel')
                    Wait(1000)
                else
                    local coords, speed = GetEntityCoords(vehicle), GetEntitySpeed(vehicle) * 3.6
                    local stop = Config.stops[routeSession.route.stops[routeSession.stopIndex]]
                    local distanceToStop = #(coords - stop.coords.xyz)
                    if not routeSession.waitingRequested and not routeSession.docked and distanceToStop <= Config.passenger.spawnDistance then
                        routeSession.waitingRequested = true
                        TriggerServerEvent('noir_busjob:server:prepareStopPassengers')
                    end
                    if not routeSession.docked and distanceToStop <= Config.stop.radius then TriggerServerEvent('noir_busjob:server:arriveStop') end
                    if routeSession.doorsOpen and speed > Config.stop.maxDoorSpeedKmh + 2 then TriggerServerEvent('noir_busjob:server:telemetry', 'hardAcceleration') end
                    if HasEntityCollidedWithAnything(vehicle) then TriggerServerEvent('noir_busjob:server:telemetry', 'collision') end
                    if speed - previousSpeed > 45 then TriggerServerEvent('noir_busjob:server:telemetry', 'hardAcceleration') elseif previousSpeed - speed > 45 then TriggerServerEvent('noir_busjob:server:telemetry', 'hardBrake') end
                    previousSpeed = speed
                    if routeSession.lastHud + 500 < GetGameTimer() then
                        routeSession.lastHud = GetGameTimer()
                        if routeSession.stopIndex and not routeSession.docked then send('bus:setRouteHud', { visible = true, routeCode = routeSession.route.code, stopName = stop.name, stopIndex = routeSession.stopIndex, stopCount = #routeSession.route.stops, distance = math.floor(distanceToStop), passengers = routeSession.passengers or 0, capacity = routeSession.capacity }) end
                    end
                    if routeSession.stopIndex == #routeSession.route.stops and routeSession.docked == false and #(coords - Config.Depot.coords.xyz) <= Config.Depot.radius then
                        local result = lib.callback.await('noir_busjob:server:park', false)
                        if result and result.ok then send('bus:summary', result.summary); cleanup() end
                    end
                    Wait(250)
                end
            end
        end
    end
end)

AddEventHandler('bgrz_core:client:playerUnloaded', function() forceClose(); cleanup() end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    forceClose()
    cleanup()
    if depotPed and DoesEntityExist(depotPed) then
        exports.ox_target:removeLocalEntity(depotPed, 'noir_busjob_central')
        DeletePed(depotPed)
    end
end)
