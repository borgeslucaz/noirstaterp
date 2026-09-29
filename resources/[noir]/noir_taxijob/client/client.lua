-- Entrada do client: detecção do táxi alugado, keybinds, missão (coleta → destino) e cleanup.
-- A capacidade de trabalhar vem do aluguel ativo (Rental); emprego, grade e duty não são consultados.
lib.locale(Config.Locale)

local P = Config.Passenger
local awaySince = nil

---@param key string chave do locale
---@param ntype? string
function Notify(key, ntype, ...)
    exports.bgrz_core:Notify(locale(key, ...), ntype or 'inform')
end

---Reflete a sessão de aluguel devolvida pelo servidor.
---@return boolean
function Taxi.canWork()
    return Rental.active()
end

local function isJobVehicle(veh)
    return veh and veh ~= 0 and Rental.isRentalVehicle(veh) and Config.IsAllowedVehicle(GetEntityModel(veh))
end

local function speedKmh(entity)
    return GetEntitySpeed(entity) * 3.6
end

-- ───────────────────────── ativação / desativação ─────────────────────────

local deactivateMessages = {
    driver_left = 'notify.driver_left',
}

---Limpa tudo no client e volta para HIDDEN.
---@param reason? string
function Taxi.deactivateLocal(reason)
    Climate.stop()
    NPC.release()
    Dispatch.clearBlip()
    local veh = Taxi.vehicle
    if veh ~= 0 and DoesEntityExist(veh) then
        FreezeEntityPosition(veh, false)
    end
    Taxi.vehicle = 0
    Taxi.inVehicle = false
    Taxi.fare = nil
    Taxi.offer = nil
    Taxi.result = nil
    Taxi.routeDistance = 0
    Taxi.meter = { fare = 0, distance = 0 }
    Taxi.passenger = { mood = 'none', comfort = 100, fear = nil }
    awaySince = nil
    UI.setVisible(false)
    SetTaxiState(TAXI_STATE.HIDDEN)

    local key = reason and deactivateMessages[reason]
    if key then Notify(key, 'error') end
end

RegisterNetEvent('noir_taxijob:client:deactivated', function(reason)
    if Taxi.is(TAXI_STATE.HIDDEN) then return end
    Taxi.deactivateLocal(reason)
end)

local activating = false

---@param veh number
local function tryActivate(veh)
    if activating then return end
    if not Taxi.canWork() then return end
    if not NetworkGetEntityIsNetworked(veh) then return end
    activating = true

    local res = lib.callback.await('noir_taxijob:server:setAvailable', false, NetworkGetNetworkIdFromEntity(veh))
    activating = false
    if not res or not res.ok then
        if res and res.reason == 'rental' then
            Notify('notify.rental_invalid', 'error')
            Rental.clear()
        elseif res and res.reason == 'vehicle' then
            Notify('notify.vehicle_not_allowed', 'error')
        elseif res and res.reason ~= 'rate' then
            Notify('notify.activation_failed', 'error')
        end
        return
    end

    Taxi.vehicle = veh
    Taxi.inVehicle = true
    awaySince = nil
    UI.setVisible(true)
    Climate.start()

    if res.resume and not Taxi.is(TAXI_STATE.HIDDEN) then
        -- Voltou ao táxi durante uma corrida: mantém o estado local.
        UI.render()
        return
    end

    Taxi.fare = nil
    Taxi.offer = nil
    Taxi.result = nil
    SetTaxiState(res.status == 'paused' and TAXI_STATE.PAUSED or TAXI_STATE.AVAILABLE)
end

local function onLeftDriverSeat()
    Taxi.inVehicle = false
    UI.setVisible(false)
    Climate.stop()

    if Taxi.inMission() then
        awaySince = GetGameTimer()
        Notify('notify.return_to_taxi', 'error', math.floor(P.DriverAwayGraceMs / 1000))
        return
    end

    TriggerServerEvent('noir_taxijob:server:setUnavailable', 'left_vehicle')
    Taxi.deactivateLocal()
end

-- Detecção do banco do motorista (500 ms; sem Wait(0)).
CreateThread(function()
    while true do
        Wait(500)
        local veh, seat = cache.vehicle, cache.seat
        local driving = veh and veh ~= 0 and seat == -1 and isJobVehicle(veh)

        if driving then
            if Taxi.is(TAXI_STATE.HIDDEN) then
                tryActivate(veh)
            elseif not Taxi.inVehicle or veh ~= Taxi.vehicle then
                tryActivate(veh)
            end
        elseif not Taxi.is(TAXI_STATE.HIDDEN) then
            if Taxi.inVehicle then
                onLeftDriverSeat()
            elseif awaySince and (GetGameTimer() - awaySince) > P.DriverAwayGraceMs then
                TriggerServerEvent('noir_taxijob:server:setUnavailable', 'driver_left')
                Taxi.deactivateLocal('driver_left')
            end
        end
    end
end)

-- ───────────────────────── missão: coleta → embarque → destino ─────────────────────────

local function cancelFare(reason)
    TriggerServerEvent('noir_taxijob:server:cancelFare', reason)
end

local function boardPassenger(fare, veh)
    SetTaxiState(TAXI_STATE.BOARDING)

    local seat = NPC.findSeat(veh)
    if not seat then
        cancelFare('no_seat')
        return
    end

    local fareId = fare.id
    local ok = NPC.board(fare.npc, veh, seat, function()
        return not Taxi.fare or Taxi.fare.id ~= fareId or not Taxi.is(TAXI_STATE.BOARDING)
    end, function()
        return lib.callback.await('noir_taxijob:server:warpPassenger', false, fareId, seat) == true
    end)
    if not Taxi.fare or Taxi.fare.id ~= fareId then return end
    if not ok then
        cancelFare('boarding_failed')
        return
    end

    local res = lib.callback.await('noir_taxijob:server:passengerBoarded', false, fareId)
    if not Taxi.fare or Taxi.fare.id ~= fareId then return end
    if not res or not res.ok then
        cancelFare('boarding_failed')
        return
    end

    fare.dropoff = vec3(res.dropoff.x, res.dropoff.y, res.dropoff.z)
    fare.destination = Dispatch.zoneName(fare.dropoff)
    Taxi.meter = { fare = res.snapshot.fare, distance = res.snapshot.distance }
    Taxi.passenger = { mood = res.snapshot.mood, comfort = res.snapshot.comfort, fear = res.snapshot.fear }
    SetTaxiState(TAXI_STATE.HIRED)
end

local function completeFare(fare, veh)
    SetTaxiState(TAXI_STATE.COMPLETING)

    local res = lib.callback.await('noir_taxijob:server:completeFare', false, fare.id)
    if not Taxi.fare or Taxi.fare.id ~= fare.id then return false end
    if not res or not res.ok then
        Notify('notify.complete_failed', 'error')
        SetTaxiState(TAXI_STATE.HIRED)
        return false
    end

    Taxi.result = { fare = res.fare, confidence = res.confidence, mood = res.mood, satisfaction = res.satisfaction, bonus = res.calmBonus or 0 }
    Taxi.passenger = { mood = res.mood, comfort = res.satisfaction, fear = nil }
    Taxi.meter = { fare = res.fare, distance = res.distance }
    UI.render()

    -- Táxi parado enquanto o passageiro desce.
    local hold = DoesEntityExist(veh) and Taxi.inVehicle
    if hold then
        SetVehicleHandbrake(veh, true)
        FreezeEntityPosition(veh, true)
    end
    NPC.exit(fare.npc, veh)
    Wait(P.DropoffHoldMs)
    if hold and DoesEntityExist(veh) then
        FreezeEntityPosition(veh, false)
        SetVehicleHandbrake(veh, false)
    end

    NPC.release()
    Taxi.fare = nil
    Taxi.routeDistance = 0
    Taxi.meter = { fare = 0, distance = 0 }
    Taxi.passenger = { mood = 'none', comfort = 100, fear = nil }

    -- Mantém o resultado (+dinheiro/confiança) visível por ResultHoldMs no total.
    Wait(math.max(0, (P.ResultHoldMs or 6000) - P.DropoffHoldMs))
    Taxi.result = nil
    if not Taxi.is(TAXI_STATE.HIDDEN) then
        SetTaxiState(TAXI_STATE.AVAILABLE)
    end
    return true
end

-- Detector de batida forte: perda súbita de velocidade entre medições.
-- Uma perda grande dispensa confirmar colisão; a intermediária exige contato (diferencia freada de impacto).
local crashWatch = { speed = nil }

local function checkCrash(veh)
    local F = Config.Fear
    local speed = GetEntitySpeed(veh)
    local last = crashWatch.speed
    crashWatch.speed = speed
    if not last then return end
    local loss = last - speed
    if loss < F.CrashDeltaSpeed then return end
    if loss < F.CrashDeltaHard and not HasEntityCollidedWithAnything(veh) then return end
    TriggerServerEvent('noir_taxijob:server:passengerScared')
end

local function missionLoop(fare)
    local fareId = fare.id
    local parkedSince = nil
    local requesting = false
    crashWatch.speed = nil

    while Taxi.fare and Taxi.fare.id == fareId and Taxi.inMission() do
        Wait(250)
        if Taxi.inVehicle and Taxi.vehicle ~= 0 and DoesEntityExist(Taxi.vehicle) then
            local veh = Taxi.vehicle
            local coords = GetEntityCoords(veh)

            if Taxi.is(TAXI_STATE.EN_ROUTE) then
                local dist = #(coords - fare.pickup)
                Taxi.routeDistance = dist
                UI.updateRoute(dist)

                if fare.npc == 0 and not requesting and dist <= P.SpawnDistance then
                    requesting = true
                    local res = lib.callback.await('noir_taxijob:server:requestPassenger', false, fareId)
                    if Taxi.fare and Taxi.fare.id == fareId and res and res.netId then
                        local ped = NPC.attach(res.netId)
                        if ped ~= 0 then
                            fare.npc = ped
                            fare.npcNetId = res.netId
                        end
                    end
                    requesting = false
                end

                if fare.npc ~= 0 and DoesEntityExist(fare.npc)
                    and dist <= P.BoardingDistance and speedKmh(veh) <= P.MaxBoardingSpeed then
                    boardPassenger(fare, veh)
                end
            elseif Taxi.is(TAXI_STATE.HIRED) and fare.dropoff then
                checkCrash(veh)
                local dist = #(coords - fare.dropoff)
                if dist <= P.DropoffDistance and speedKmh(veh) <= P.MaxDropoffSpeed
                    and fare.npc ~= 0 and IsPedInVehicle(fare.npc, veh, false) then
                    parkedSince = parkedSince or GetGameTimer()
                    if GetGameTimer() - parkedSince >= P.ArrivalHoldMs then
                        parkedSince = nil
                        completeFare(fare, veh)
                    end
                else
                    parkedSince = nil
                end
            end
        end
    end
end

Taxi.onEnter(TAXI_STATE.EN_ROUTE, function(previous)
    if previous == TAXI_STATE.EN_ROUTE then return end
    local fare = Taxi.fare
    if fare then CreateThread(function() missionLoop(fare) end) end
end)

-- ───────────────────────── keybinds ─────────────────────────

RegisterCommand('taxi_fan', function()
    if Taxi.is(TAXI_STATE.HIDDEN) or not Taxi.inVehicle then return end
    Climate.cycleFan()
end, false)
RegisterKeyMapping('taxi_fan', Config.Keybinds.fan.label, 'keyboard', Config.Keybinds.fan.key)

RegisterCommand('taxi_accept', function()
    if not Taxi.is(TAXI_STATE.OFFER) then return end
    Dispatch.accept()
end, false)
RegisterKeyMapping('taxi_accept', Config.Keybinds.accept.label, 'keyboard', Config.Keybinds.accept.key)

RegisterCommand('taxi_pause', function()
    if Taxi.is(TAXI_STATE.HIDDEN) then return end
    if Taxi.is(TAXI_STATE.AVAILABLE) then
        TriggerServerEvent('noir_taxijob:server:setPaused', true)
    elseif Taxi.is(TAXI_STATE.PAUSED) then
        TriggerServerEvent('noir_taxijob:server:setPaused', false)
    else
        Notify('notify.cannot_pause', 'error')
    end
end, false)
RegisterKeyMapping('taxi_pause', Config.Keybinds.pause.label, 'keyboard', Config.Keybinds.pause.key)

-- ───────────────────────── sessão ─────────────────────────

-- Motor morto ou veículo destruído encerra o trabalho; o servidor confirma e limpa o aluguel.
CreateThread(function()
    while true do
        Wait(500)
        local veh = Taxi.vehicle
        if veh ~= 0 and DoesEntityExist(veh) and not Taxi.is(TAXI_STATE.HIDDEN) then
            if GetVehicleEngineHealth(veh) <= 0 or GetEntityHealth(veh) <= 0 then
                TriggerServerEvent('noir_taxijob:server:vehicleBroken')
                Wait(3000) -- evita spam enquanto o servidor processa o cleanup
            end
        end
    end
end)

AddEventHandler('bgrz_core:client:playerUnloaded', function()
    if not Taxi.is(TAXI_STATE.HIDDEN) then Taxi.deactivateLocal() end
end)

-- Mudança de emprego ou duty não desativa a atividade: o Taxi V2 é renda extra independente.

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Climate.stop()
    Dispatch.clearBlip()
    local veh = Taxi.vehicle
    if veh ~= 0 and DoesEntityExist(veh) then FreezeEntityPosition(veh, false) end
    UI.setVisible(false)
end)
