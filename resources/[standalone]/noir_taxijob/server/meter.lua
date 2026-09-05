-- Taxímetro server-authoritative: integra distância a ~1 Hz, aplica limites e paga a corrida.
Meter = {}

local M = Config.Meter
local C = Config.Climate
local P = Config.Passenger
local RL = ServerConfig.RateLimits

local function fareFor(meters)
    return M.StartingFare + (meters / 1000.0) * M.PricePerKm
end

---@param src number
---@param driver TaxiDriver
---@param fare TaxiFare
---@param now number
---@param dtSec number
local function tickFare(src, driver, fare, now, dtSec)
    local veh = Sessions.getVehicle(driver)
    if veh == 0 or GetEntityHealth(veh) <= 0 then
        return Sessions.cancelFare(src, 'vehicle_lost')
    end

    local npc = Sessions.getNpc(fare)
    if npc == 0 or GetEntityHealth(npc) <= 0 then
        return Sessions.cancelFare(src, 'passenger_left')
    end

    local seated = Sessions.isDriverSeated(src, veh)
    if seated then
        driver.awaySince = nil
    else
        driver.awaySince = driver.awaySince or now
        if (now - driver.awaySince) > P.DriverAwayGraceMs then
            return Sessions.cancelFare(src, 'driver_left')
        end
    end

    local npcInside = GetVehiclePedIsIn(npc, false) == veh
    local coords = GetEntityCoords(veh)

    if fare.lastCoords then
        local delta = #(coords - fare.lastCoords)
        if delta > M.MaxValidDeltaPerTick * math.max(1.0, dtSec) then
            fare.ignoredJumps = fare.ignoredJumps + 1
            Security.report(src, 'meter', 'impossible_delta', { delta = math.floor(delta), jumps = fare.ignoredJumps })
            if fare.ignoredJumps >= M.MaxIgnoredJumps then
                return Sessions.cancelFare(src, 'impossible_movement')
            end
        elseif seated and npcInside then
            fare.distanceMeters = fare.distanceMeters + delta
        end
    end
    fare.lastCoords = coords

    local billable = math.min(fare.distanceMeters, fare.maxBillableDistance)
    fare.currentFare = math.min(fareFor(billable), M.MaxFare)

    -- Conforto do passageiro (temperatura sincronizada pelo client e validada em server.lua)
    if npcInside then
        local climate = driver.climate
        if climate and (now - climate.at) <= ServerConfig.ClimateStaleMs then
            if climate.temp >= C.ComfortMin and climate.temp <= C.ComfortMax then
                fare.comfort = math.min(100.0, fare.comfort + C.ComfortGain * dtSec)
            else
                fare.comfort = math.max(0.0, fare.comfort - C.ComfortLoss * dtSec)
            end
        end
    end

    TriggerClientEvent('noir_taxijob:client:meter', src, Sessions.snapshot(fare, driver))
end

---@param now number
---@param dtSec number
function Meter.tick(now, dtSec)
    for src, fare in pairs(ActiveFares) do
        if fare.status == 'hired' then
            local driver = Drivers[src]
            if driver then
                tickFare(src, driver, fare, now, dtSec)
            else
                Sessions.cancelFare(src, 'driver_missing')
            end
        end
    end
end

-- ───────────────────────── conclusão e pagamento ─────────────────────────

lib.callback.register('noir_taxijob:server:completeFare', function(src, fareId)
    if not Security.rateLimit(src, 'complete', RL.complete) then return false end
    local id = Security.sanitizeInt(fareId, 1)
    local driver, fare = Drivers[src], ActiveFares[src]
    if not id or not driver or not fare then return false end
    if fare.id ~= id or fare.status ~= 'hired' or fare.paid then
        return Security.deny(src, 'completeFare', 'wrong_state', { id = id, status = fare.status, paid = fare.paid })
    end
    if not Sessions.isValidDriver(src) then
        Sessions.removeDriver(src, 'job_changed')
        return false
    end

    local veh = Sessions.getVehicle(driver)
    if veh == 0 or not Sessions.isDriverSeated(src, veh) then
        return Security.deny(src, 'completeFare', 'driver_not_seated', { id = id })
    end
    local npc = Sessions.getNpc(fare)
    if npc == 0 or GetVehiclePedIsIn(npc, false) ~= veh then
        return Security.deny(src, 'completeFare', 'npc_not_in_vehicle', { id = id })
    end
    local distToDrop = #(GetEntityCoords(veh) - fare.dropoff)
    if distToDrop > P.DropoffDistance + ServerConfig.DropoffTolerance then
        return Security.deny(src, 'completeFare', 'not_at_dropoff', { id = id, dist = math.floor(distToDrop) })
    end
    local now = Sessions.now()
    if fare.distanceMeters < M.MinTripMeters or (now - (fare.startedAt or now)) < M.MinTripSeconds * 1000 then
        return Security.deny(src, 'completeFare', 'trip_too_short', { id = id, meters = math.floor(fare.distanceMeters) })
    end

    -- A partir daqui a corrida não pode ser paga duas vezes.
    fare.status = 'completing'
    fare.paid = true

    local satisfaction = fare.comfort
    local multiplier, tip = 1.0, 0.0
    if satisfaction <= C.UnhappyThreshold then
        multiplier = Config.Payout.UnhappyMultiplier
    elseif satisfaction < C.SatisfiedThreshold then
        multiplier = Config.Payout.NeutralMultiplier
    else
        tip = fare.currentFare * (Config.Payout.SatisfiedTipPercent / 100.0)
    end
    local finalFare = math.floor(math.min(fare.currentFare * multiplier + tip, M.MaxFare))

    local repDelta = Config.Reputation.BasePerFare
    if satisfaction >= C.SatisfiedThreshold then
        repDelta = repDelta + Config.Reputation.SatisfiedBonus
    elseif satisfaction <= C.UnhappyThreshold then
        repDelta = math.max(0, repDelta - Config.Reputation.UnhappyPenalty)
    end

    if finalFare > 0 then
        exports.bgrz_core:AddMoney(src, 'cash', finalFare, 'taxi-npc-fare')
    end
    local totalRep = exports.bgrz_core:AddJobReputation(src, Config.Job, repDelta)
    local mood = Sessions.mood(fare, driver)

    Sessions.debug('fare paid src=%s id=%s meters=%.0f fare=%s satisfaction=%.0f rep=+%s', src, id, fare.distanceMeters, finalFare, satisfaction, repDelta)

    -- O ped sai do veículo no client; o servidor remove a entidade depois.
    Sessions.releasePickup(fare.pickupIndex)
    Sessions.deleteNpc(fare, P.DespawnDelay)
    ActiveFares[src] = nil
    driver.status = 'available'
    driver.awaySince = nil
    driver.nextOfferAt = now + Config.Dispatch.CooldownAfterFare

    return {
        ok = true,
        fare = finalFare,
        reputation = repDelta,
        totalReputation = totalRep,
        satisfaction = math.floor(satisfaction),
        mood = mood,
        distance = math.floor(fare.distanceMeters),
    }
end)
