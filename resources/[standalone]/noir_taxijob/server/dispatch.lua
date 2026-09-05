-- Central de chamadas NPC: gera ofertas, controla aceite, spawn do passageiro e embarque.
Dispatch = {}

local D = Config.Dispatch
local P = Config.Passenger
local M = Config.Meter
local CL = Config.Climate
local RL = ServerConfig.RateLimits

local function fareFor(meters)
    return M.StartingFare + (meters / 1000.0) * M.PricePerKm
end

local function vec(v)
    return { x = v.x, y = v.y, z = v.z }
end

---Escolhe um ponto de coleta em função da posição do taxista.
---@return number|nil pointIndex
local function pickPickup(driverCoords)
    local near, far = {}, {}
    for i, p in ipairs(Config.PointList) do
        if not ReservedPickups[i] then
            local d = #(driverCoords - p.coords)
            if d >= D.MinPickupDistance and d <= D.MaxPickupDistance then
                if d <= D.IdealPickupDistance then
                    near[#near + 1] = i
                else
                    far[#far + 1] = i
                end
            end
        end
    end

    local pool
    if #near > 0 and (#far == 0 or math.random() < D.NearPickupWeight) then
        pool = near
    elseif #far > 0 then
        pool = far
    else
        pool = near
    end
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

---Escolhe um destino a uma distância plausível da coleta.
---@return number|nil pointIndex
local function pickDropoff(pickupIndex)
    local origin = Config.PointList[pickupIndex].coords
    local pool, fallback = {}, {}
    for i, p in ipairs(Config.PointList) do
        if i ~= pickupIndex then
            local d = #(origin - p.coords)
            if d >= D.MinTripDistance then
                if d <= D.MaxTripDistance then
                    pool[#pool + 1] = i
                else
                    fallback[#fallback + 1] = i
                end
            end
        end
    end
    if #pool == 0 then pool = fallback end
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

local function randomDelay()
    return math.random(D.MinDelay, D.MaxDelay)
end

---@param src number
---@param driver TaxiDriver
---@param veh number
function Dispatch.createOffer(src, driver, veh)
    local now = Sessions.now()
    local coords = GetEntityCoords(veh)

    local pickupIndex = pickPickup(coords)
    if not pickupIndex then
        driver.nextOfferAt = now + D.MinDelay
        return
    end
    local dropoffIndex = pickDropoff(pickupIndex)
    if not dropoffIndex then
        driver.nextOfferAt = now + D.MinDelay
        return
    end

    local pickup = Config.PointList[pickupIndex]
    local dropoff = Config.PointList[dropoffIndex]
    local expected = #(pickup.coords - dropoff.coords) * D.RouteFactor
    local maxBillable = math.min(expected * M.MaxRouteMultiplier + M.ExtraDistanceTolerance, M.AbsoluteMaxBillable)

    local id = Sessions.newFareId()
    -- Preferência térmica individual: desvio aleatório (±ComfortVariation °C) sobre a faixa global.
    local band = CL.ComfortMax - CL.ComfortMin
    local spread = math.floor(CL.ComfortVariation * 100 + 0.5)
    local offset = (math.random(-spread, spread) / 100.0)
    local prefMin = math.max(CL.MinTemp, math.min(CL.MaxTemp - band, CL.ComfortMin + offset))
    ---@type TaxiFare
    local fare = {
        id = id,
        source = src,
        status = 'offered',
        pickupIndex = pickupIndex,
        dropoffIndex = dropoffIndex,
        pickup = pickup.coords,
        pickupHeading = pickup.heading,
        dropoff = dropoff.coords,
        createdAt = now,
        expiresAt = now + D.OfferTimeout,
        expectedDistance = expected,
        maxBillableDistance = maxBillable,
        vehicleNetId = driver.vehicleNetId,
        distanceMeters = 0.0,
        currentFare = 0.0,
        comfort = 100.0,
        comfortMin = prefMin,
        comfortMax = prefMin + band,
        fear = 0.0,
        ignoredJumps = 0,
        paid = false,
    }

    ActiveFares[src] = fare
    Sessions.reservePickup(pickupIndex, id)
    driver.status = 'offered'
    Sessions.debug('offer src=%s id=%s pickup=%s dropoff=%s expected=%.0f', src, id, pickupIndex, dropoffIndex, expected)

    TriggerClientEvent('noir_taxijob:client:offer', src, {
        id = id,
        pickup = vec(pickup.coords),
        distanceToPickup = math.floor(#(coords - pickup.coords)),
        estimateMin = math.floor(fareFor(expected * 0.9)),
        estimateMax = math.ceil(fareFor(expected * 1.25)),
        expiresIn = D.OfferTimeout,
    })
end

---@param src number
---@param driver TaxiDriver
---@param fare TaxiFare
function Dispatch.expireOffer(src, driver, fare)
    Sessions.releasePickup(fare.pickupIndex)
    ActiveFares[src] = nil
    driver.status = 'available'
    driver.nextOfferAt = Sessions.now() + D.CooldownAfterTimeout
    TriggerClientEvent('noir_taxijob:client:offerExpired', src)
end

---@param now number
function Dispatch.tick(now)
    for src, driver in pairs(Drivers) do
        local fare = ActiveFares[src]
        if driver.status == 'offered' then
            if not fare then
                driver.status = 'available'
            elseif now >= fare.expiresAt then
                Dispatch.expireOffer(src, driver, fare)
            end
        elseif driver.status == 'available' and now >= driver.nextOfferAt then
            local veh = Sessions.getVehicle(driver)
            if veh == 0 then
                Sessions.removeDriver(src, 'vehicle_lost')
            elseif not Sessions.isDriverSeated(src, veh) or Sessions.hasPlayerPassenger(veh) then
                driver.nextOfferAt = now + 5000
            else
                Dispatch.createOffer(src, driver, veh)
            end
        end
    end
end

function Dispatch.scheduleNext(driver)
    driver.nextOfferAt = Sessions.now() + randomDelay()
end

-- ───────────────────────── callbacks client → server ─────────────────────────

lib.callback.register('noir_taxijob:server:acceptOffer', function(src, fareId)
    if not Security.rateLimit(src, 'accept', RL.accept) then return false end
    local id = Security.sanitizeInt(fareId, 1)
    local driver, fare = Drivers[src], ActiveFares[src]
    if not id or not driver or not fare then return false end
    if fare.status ~= 'offered' or fare.id ~= id then
        return Security.deny(src, 'acceptOffer', 'wrong_state', { id = id, status = fare.status })
    end
    if Sessions.now() > fare.expiresAt + 1000 then
        Dispatch.expireOffer(src, driver, fare)
        return false
    end
    if not Sessions.isEligible(src, driver.vehicleNetId) then
        Sessions.removeDriver(src, 'vehicle_lost')
        return false
    end

    fare.status = 'accepted'
    driver.status = 'accepted'
    return { ok = true, pickup = vec(fare.pickup), heading = fare.pickupHeading }
end)

lib.callback.register('noir_taxijob:server:requestPassenger', function(src, fareId)
    if not Security.rateLimit(src, 'requestPassenger', RL.requestPassenger) then return false end
    local id = Security.sanitizeInt(fareId, 1)
    local driver, fare = Drivers[src], ActiveFares[src]
    if not id or not driver or not fare or fare.id ~= id or fare.status ~= 'accepted' then return false end

    if fare.npcEntity and DoesEntityExist(fare.npcEntity) then
        return { netId = fare.npcNetId, model = fare.npcModel }
    end

    if not Security.isNearCoords(src, fare.pickup, P.SpawnDistance + ServerConfig.PickupSpawnTolerance) then
        return Security.deny(src, 'requestPassenger', 'too_far', { id = id })
    end

    local model = P.Models[math.random(#P.Models)]
    local ped = CreatePed(4, joaat(model), fare.pickup.x, fare.pickup.y, fare.pickup.z, fare.pickupHeading, true, true)
    local ok = pcall(lib.waitFor, function()
        if DoesEntityExist(ped) then return true end
    end, 'passenger ped was not created', 3000)
    if not ok or not DoesEntityExist(ped) then
        Security.report(src, 'requestPassenger', 'spawn_failed', { id = id })
        return false
    end

    fare.npcEntity = ped
    fare.npcNetId = NetworkGetNetworkIdFromEntity(ped)
    fare.npcModel = model
    Entity(ped).state:set('noirTaxi:fareId', fare.id, true)
    Entity(ped).state:set('noirTaxi:driver', src, true)
    Sessions.debug('passenger spawned src=%s id=%s netId=%s', src, id, fare.npcNetId)

    return { netId = fare.npcNetId, model = model }
end)

-- Último recurso do embarque: o servidor coloca o ped no veículo quando o client não tem controle da entidade.
lib.callback.register('noir_taxijob:server:warpPassenger', function(src, fareId, seat)
    if not Security.rateLimit(src, 'warpPassenger', RL.boarded) then return false end
    local id = Security.sanitizeInt(fareId, 1)
    local seatIndex = Security.sanitizeInt(seat, 0, 6)
    local driver, fare = Drivers[src], ActiveFares[src]
    if not id or not seatIndex or not driver or not fare or fare.id ~= id or fare.status ~= 'accepted' then return false end

    local veh = Sessions.getVehicle(driver)
    local npc = Sessions.getNpc(fare)
    if veh == 0 or npc == 0 then return false end
    if not Sessions.isDriverSeated(src, veh) then return false end
    if #(GetEntityCoords(veh) - fare.pickup) > P.BoardingDistance * 4 then
        return Security.deny(src, 'warpPassenger', 'too_far', { id = id })
    end
    if GetVehiclePedIsIn(npc, false) == veh then return true end

    SetPedIntoVehicle(npc, veh, seatIndex)
    local inside = pcall(lib.waitFor, function()
        if GetVehiclePedIsIn(npc, false) == veh then return true end
    end, 'npc not in vehicle after warp', 2000)
    return inside == true
end)

lib.callback.register('noir_taxijob:server:passengerBoarded', function(src, fareId)
    if not Security.rateLimit(src, 'boarded', RL.boarded) then return false end
    local id = Security.sanitizeInt(fareId, 1)
    local driver, fare = Drivers[src], ActiveFares[src]
    if not id or not driver or not fare or fare.id ~= id or fare.status ~= 'accepted' then return false end

    local veh = Sessions.getVehicle(driver)
    local npc = Sessions.getNpc(fare)
    if veh == 0 or npc == 0 then return false end

    -- O servidor pode ver o ped entrar alguns décimos de segundo depois do client: espera antes de negar.
    local inside = pcall(lib.waitFor, function()
        if GetVehiclePedIsIn(npc, false) == veh then return true end
    end, 'npc not in vehicle', 3000)
    if not inside then
        return Security.deny(src, 'passengerBoarded', 'npc_not_in_vehicle', { id = id })
    end
    if not Sessions.isDriverSeated(src, veh) then
        return Security.deny(src, 'passengerBoarded', 'driver_not_seated', { id = id })
    end

    local now = Sessions.now()
    fare.status = 'hired'
    driver.status = 'hired'
    fare.startedAt = now
    fare.currentFare = M.StartingFare
    fare.distanceMeters = 0.0
    fare.comfort = 100.0
    fare.lastCoords = GetEntityCoords(veh)
    Sessions.releasePickup(fare.pickupIndex)

    return { ok = true, dropoff = vec(fare.dropoff), snapshot = Sessions.snapshot(fare, driver) }
end)
