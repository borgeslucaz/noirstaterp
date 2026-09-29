-- Taxímetro server-authoritative: integra distância a ~1 Hz, aplica limites e paga a corrida.
Meter = {}

local M = Config.Meter
local C = Config.Climate
local P = Config.Passenger
local RL = ServerConfig.RateLimits

-- Limiares dos níveis de medo: batida forte sobe para ASSUSTADO; atingir DESPERADO trava o medo.
local F = Config.Fear
local SCARED_MIN, DESPERATE_MIN = math.huge, math.huge
for _, lv in ipairs(F.Levels) do
    if lv.key == 'scared' then SCARED_MIN = lv.min end
    if lv.key == 'desperate' then DESPERATE_MIN = lv.min end
end

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
    if veh == 0 or GetEntityHealth(veh) <= 0 or GetVehicleEngineHealth(veh) <= 0 then
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
    -- Cada passageiro tem uma faixa de conforto própria, gerada no aceite da chamada.
    if npcInside then
        local climate = driver.climate
        if climate and (now - climate.at) <= ServerConfig.ClimateStaleMs then
            local prefMin = fare.comfortMin or C.ComfortMin
            local prefMax = fare.comfortMax or C.ComfortMax
            if climate.temp >= prefMin and climate.temp <= prefMax then
                fare.comfort = math.min(100.0, fare.comfort + C.ComfortGain * dtSec)
            else
                fare.comfort = math.max(0.0, fare.comfort - C.ComfortLoss * dtSec)
            end
        end
    end

    -- Batida forte: queda brusca da lataria (body health) entre medições assusta o passageiro.
    local crashed = false
    local body = GetVehicleBodyHealth(veh)
    if npcInside and fare.bodyHealth and (fare.bodyHealth - body) >= F.CrashDamage then
        crashed = true
        if (fare.fear or 0.0) < SCARED_MIN then
            fare.fear = SCARED_MIN
        end
    end
    fare.bodyHealth = body

    -- Medo do passageiro: velocidade acima do limite assusta; dirigir tranquilo acalma.
    -- Ao atingir DESESPERADO o susto é permanente: o medo não diminui mais nesta corrida.
    if npcInside then
        local speedKmh = GetEntitySpeed(veh) * 3.6
        local desperate = (fare.fear or 0.0) >= DESPERATE_MIN
        if speedKmh > F.SpeedLimit then
            local intensity = math.min(1.0, (speedKmh - F.SpeedLimit) / math.max(1.0, F.HardSpeed - F.SpeedLimit))
            fare.fear = math.min(100.0, (fare.fear or 0.0) + F.GainPerSecond * (0.3 + 0.7 * intensity) * dtSec)
        elseif not desperate and not crashed then
            fare.fear = math.max(0.0, (fare.fear or 0.0) - F.CalmPerSecond * dtSec)
        end
    end

    TriggerClientEvent('noir_taxijob:client:meter', src, Sessions.snapshot(fare, driver))
end

---Avisa o servidor sobre uma batida forte detectada no client (perda súbita de velocidade).
---O medo sobe para o nível ASSUSTADO; a autoridade do valor continua no servidor.
RegisterNetEvent('noir_taxijob:server:passengerScared', function()
    local src = source
    if not Security.rateLimit(src, 'scare', ServerConfig.RateLimits.scare) then return end
    local driver = Drivers[src]
    local fare = ActiveFares[src]
    if not driver or not fare or fare.status ~= 'hired' then return end
    if not Sessions.isEligible(src, driver.vehicleNetId) then return end
    if (fare.fear or 0.0) < SCARED_MIN then
        fare.fear = SCARED_MIN
        TriggerClientEvent('noir_taxijob:client:meter', src, Sessions.snapshot(fare, driver))
    end
end)

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
    if not Sessions.isEligible(src, driver.vehicleNetId) then
        Sessions.removeDriver(src, 'vehicle_lost')
        return false
    end
    local character = Central.identity(src)
    local rental = ActiveRentals[src]
    if not character or not rental or rental.citizenid ~= character.citizenId then
        return Security.deny(src, 'completeFare', 'identity_mismatch', { id = id })
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

    -- A partir daqui a corrida não pode ser paga nem pontuada duas vezes.
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

    -- Bônus de calma: entrega com o ar dentro da faixa térmica do passageiro (mood 'happy')
    -- e sentimento TRANQUILO (medo nunca passou do primeiro nível).
    local calmBonus = 0.0
    if Sessions.mood(fare, driver) == 'happy' and Sessions.fearLevel(fare).key == 'calm' then
        calmBonus = Config.Payout.CalmBonusPercent / 100.0
    end
    local bonusAmount = math.floor(fare.currentFare * multiplier * calmBonus + 0.5)
    local finalFare = math.floor(math.min(fare.currentFare * multiplier * (1.0 + calmBonus) + tip, M.MaxFare))
    local confidenceDelta = Progression.confidenceFor(satisfaction)
    local mood = Sessions.mood(fare, driver)
    local distance = math.floor(fare.distanceMeters)

    -- Ledger + perfil + diário em uma transação; só depois o pagamento.
    local persisted, row = false, nil
    if finalFare > 0 or ServerConfig.Progression.CountZeroFare then
        persisted, row = Progression.recordFare(character.citizenId, Sessions.fareKey(fare.id), finalFare, confidenceDelta, distance, satisfaction)
    end
    if not persisted then
        confidenceDelta = 0
        if ServerConfig.Progression.PayWhenPersistFails then
            print(('[noir_taxijob] progressão não persistida src=%s fare=%s (pagamento mantido)'):format(src, fare.id))
            exports.bgrz_core:Notify(src, locale('notify.progress_not_saved'), 'error')
        else
            finalFare = 0
            exports.bgrz_core:Notify(src, locale('notify.progress_not_saved'), 'error')
        end
    end
    if finalFare > 0 then
        exports.bgrz_core:AddMoney(src, 'cash', finalFare, 'taxi-npc-fare')
    end

    Sessions.debug('fare_progress cid=%s fareId=%s confidence=+%s earned=%s satisfaction=%.0f', character.citizenId, fare.id, confidenceDelta, finalFare, satisfaction)

    -- O ped sai do veículo no client; o servidor remove a entidade depois.
    Sessions.releasePickup(fare.pickupIndex)
    Sessions.deleteNpc(fare, P.DespawnDelay)
    if ActiveFares[src] == fare then ActiveFares[src] = nil end
    if Drivers[src] == driver then
        driver.status = 'available'
        driver.awaySince = nil
        driver.nextOfferAt = Sessions.now() + Config.Dispatch.CooldownAfterFare
    end

    local progress = row and Progression.view(row, Progression.earnedToday(character.citizenId)) or nil
    return {
        ok = true,
        fare = finalFare,
        confidence = confidenceDelta,
        satisfaction = math.floor(satisfaction),
        mood = mood,
        distance = distance,
        calmBonus = bonusAmount,
        progress = progress,
    }
end)
