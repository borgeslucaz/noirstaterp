-- Chamadas da central no client: oferta, aceite, blips/GPS e eventos de cancelamento.
Dispatch = {}

local blip = nil

function Dispatch.clearBlip()
    if blip then
        RemoveBlip(blip)
        blip = nil
    end
end

---@param coords vector3
---@param label string
---@param color number
function Dispatch.setBlip(coords, label, color)
    Dispatch.clearBlip()
    blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, color)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, color)
end

---@param coords vector3
---@return string
function Dispatch.zoneName(coords)
    local zone = GetNameOfZone(coords.x, coords.y, coords.z)
    local label = zone and GetLabelText(zone) or nil
    if not label or label == 'NULL' or label == '' then
        local street = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        label = GetStreetNameFromHashKey(street)
    end
    return label or '—'
end

---Aceita a oferta atual (tecla E em OFFER).
function Dispatch.accept()
    if not Taxi.is(TAXI_STATE.OFFER) or not Taxi.offer then return end
    local offer = Taxi.offer
    Taxi.offer = nil

    local res = lib.callback.await('noir_taxijob:server:acceptOffer', false, offer.id)
    if not res or not res.ok then
        Notify('notify.accept_failed', 'error')
        if Taxi.is(TAXI_STATE.OFFER) then SetTaxiState(TAXI_STATE.AVAILABLE) end
        return
    end

    Taxi.fare = {
        id = offer.id,
        pickup = vec3(res.pickup.x, res.pickup.y, res.pickup.z),
        heading = res.heading or 0.0,
        origin = offer.origin,
        dropoff = nil,
        destination = nil,
        npc = 0,
        npcNetId = nil,
    }
    Taxi.routeDistance = offer.distanceToPickup
    SetTaxiState(TAXI_STATE.EN_ROUTE)
end

RegisterNetEvent('noir_taxijob:client:offer', function(offer)
    if not Taxi.is(TAXI_STATE.AVAILABLE) or not Taxi.inVehicle then return end
    local pickup = vec3(offer.pickup.x, offer.pickup.y, offer.pickup.z)
    Taxi.offer = {
        id = offer.id,
        pickup = pickup,
        origin = Dispatch.zoneName(pickup),
        distanceToPickup = offer.distanceToPickup,
        estimateMin = offer.estimateMin,
        estimateMax = offer.estimateMax,
        expiresAt = GetGameTimer() + (offer.expiresIn or Config.Dispatch.OfferTimeout),
    }
    SetTaxiState(TAXI_STATE.OFFER)

    local id = offer.id
    CreateThread(function()
        while Taxi.is(TAXI_STATE.OFFER) and Taxi.offer and Taxi.offer.id == id do
            UI.updateOffer(math.max(0, Taxi.offer.expiresAt - GetGameTimer()))
            Wait(250)
        end
    end)
end)

RegisterNetEvent('noir_taxijob:client:offerExpired', function()
    if not Taxi.is(TAXI_STATE.OFFER) then return end
    Taxi.offer = nil
    Notify('notify.offer_expired', 'inform')
    SetTaxiState(TAXI_STATE.AVAILABLE)
end)

local cancelMessages = {
    vehicle_lost = 'notify.vehicle_lost',
    passenger_left = 'notify.passenger_left',
    driver_left = 'notify.driver_left',
    impossible_movement = 'notify.impossible_movement',
    boarding_failed = 'notify.boarding_failed',
    no_seat = 'notify.no_seat',
}

RegisterNetEvent('noir_taxijob:client:fareCancelled', function(reason)
    local vehicle = Taxi.vehicle
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        FreezeEntityPosition(vehicle, false)
    end
    NPC.release()
    Dispatch.clearBlip()
    Taxi.fare = nil
    Taxi.offer = nil
    Taxi.result = nil
    Taxi.meter = { fare = 0, distance = 0 }
    Taxi.passenger = { mood = 'none', comfort = 100, fear = nil }

    local key = cancelMessages[reason]
    if key then Notify(key, 'error') end

    if not Taxi.is(TAXI_STATE.HIDDEN) then
        SetTaxiState(TAXI_STATE.AVAILABLE)
    end
end)

RegisterNetEvent('noir_taxijob:client:paused', function(paused)
    if Taxi.is(TAXI_STATE.HIDDEN) or Taxi.inMission() then return end
    Notify(paused and 'notify.calls_paused' or 'notify.calls_resumed', 'inform')
    SetTaxiState(paused and TAXI_STATE.PAUSED or TAXI_STATE.AVAILABLE)
end)

RegisterNetEvent('noir_taxijob:client:meter', function(snapshot)
    if not Taxi.is(TAXI_STATE.HIRED) then return end
    Taxi.meter = { fare = snapshot.fare, distance = snapshot.distance }
    Taxi.passenger = { mood = snapshot.mood, comfort = snapshot.comfort, fear = snapshot.fear }
    UI.updateMeter(snapshot.fare, snapshot.distance)
    UI.updatePassenger(snapshot.mood, snapshot.comfort, snapshot.fear)
end)

-- Blips: no máximo um (coleta ou destino), removido em toda transição.
Taxi.onEnter(TAXI_STATE.EN_ROUTE, function()
    if Taxi.fare then Dispatch.setBlip(Taxi.fare.pickup, locale('blip.pickup'), 5) end
end)
Taxi.onEnter(TAXI_STATE.HIRED, function()
    if Taxi.fare and Taxi.fare.dropoff then Dispatch.setBlip(Taxi.fare.dropoff, locale('blip.dropoff'), 2) end
end)
for _, state in ipairs({ TAXI_STATE.AVAILABLE, TAXI_STATE.PAUSED, TAXI_STATE.HIDDEN, TAXI_STATE.COMPLETING, TAXI_STATE.OFFER }) do
    Taxi.onEnter(state, Dispatch.clearBlip)
end
