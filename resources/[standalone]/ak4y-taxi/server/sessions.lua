-- Estado server-side: taxistas disponíveis, corridas ativas e reservas de pontos.
Sessions = {}

---@class TaxiDriver
---@field source number
---@field vehicleNetId number
---@field status 'available'|'paused'|'offered'|'accepted'|'hired'|'completing'
---@field nextOfferAt number
---@field climate { temp: number, fan: number, at: number }|nil
---@field awaySince number|nil

---@class TaxiFare
---@field id number
---@field source number
---@field status 'offered'|'accepted'|'hired'|'completing'
---@field pickupIndex number
---@field dropoffIndex number
---@field pickup vector3
---@field pickupHeading number
---@field dropoff vector3
---@field createdAt number
---@field expiresAt number
---@field expectedDistance number
---@field maxBillableDistance number
---@field vehicleNetId number
---@field npcNetId number|nil
---@field npcEntity number|nil
---@field startedAt number|nil
---@field distanceMeters number
---@field currentFare number
---@field lastCoords vector3|nil
---@field comfort number
---@field ignoredJumps number
---@field paid boolean

Drivers = {}        ---@type table<number, TaxiDriver>
ActiveFares = {}    ---@type table<number, TaxiFare>
ReservedPickups = {}---@type table<number, number> pointIndex → fareId
DepotVehicles = {}  ---@type table<number, number> source → netId

local fareCounter = 0

function Sessions.now()
    return GetGameTimer()
end

function Sessions.debug(fmt, ...)
    if not Config.Debug then return end
    print(('[ak4y-taxi] ' .. fmt):format(...))
end

function Sessions.newFareId()
    fareCounter = fareCounter + 1
    return fareCounter
end

---@return boolean
function Sessions.isValidDriver(src)
    return exports.bgrz_core:HasJob(src, Config.Job, Config.RequireDuty) == true
end

---@param driver TaxiDriver
---@return number vehicle entity (0 se não existir)
function Sessions.getVehicle(driver)
    if not driver or not driver.vehicleNetId or driver.vehicleNetId == 0 then return 0 end
    local veh = NetworkGetEntityFromNetworkId(driver.vehicleNetId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0 end
    return veh
end

---@return boolean
function Sessions.isDriverSeated(src, veh)
    if veh == 0 then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return GetPedInVehicleSeat(veh, -1) == ped
end

---@return boolean
function Sessions.hasPlayerPassenger(veh)
    if veh == 0 then return false end
    for seat = 0, 6 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped and ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

---@param fare TaxiFare
---@return number npc entity (0 se não existir)
function Sessions.getNpc(fare)
    if not fare or not fare.npcEntity then return 0 end
    if not DoesEntityExist(fare.npcEntity) then return 0 end
    return fare.npcEntity
end

function Sessions.reservePickup(index, fareId)
    ReservedPickups[index] = fareId
end

function Sessions.releasePickup(index)
    if index then ReservedPickups[index] = nil end
end

---@param fare TaxiFare
---@param delayMs? number
function Sessions.deleteNpc(fare, delayMs)
    local npc = fare and fare.npcEntity
    if not npc then return end
    fare.npcEntity = nil
    fare.npcNetId = nil
    if not delayMs or delayMs <= 0 then
        if DoesEntityExist(npc) then DeleteEntity(npc) end
        return
    end
    SetTimeout(delayMs, function()
        if DoesEntityExist(npc) then DeleteEntity(npc) end
    end)
end

---@param src number
---@param reason string
---@param npcDespawnDelay? number
function Sessions.cancelFare(src, reason, npcDespawnDelay)
    local fare = ActiveFares[src]
    if not fare then return end
    Sessions.debug('cancelFare src=%s id=%s reason=%s', src, fare.id, reason)
    Sessions.releasePickup(fare.pickupIndex)
    Sessions.deleteNpc(fare, npcDespawnDelay)
    ActiveFares[src] = nil

    local driver = Drivers[src]
    if driver then
        driver.status = 'available'
        driver.awaySince = nil
        driver.nextOfferAt = Sessions.now() + Config.Dispatch.CooldownAfterTimeout
    end
    TriggerClientEvent('ak4y-taxi:client:fareCancelled', src, reason)
end

---@param src number
---@param reason string
function Sessions.removeDriver(src, reason)
    if ActiveFares[src] then
        Sessions.cancelFare(src, reason)
    end
    if Drivers[src] then
        Sessions.debug('removeDriver src=%s reason=%s', src, reason)
        Drivers[src] = nil
        TriggerClientEvent('ak4y-taxi:client:deactivated', src, reason)
    end
end

---@param fare TaxiFare
---@param driver TaxiDriver
---@return 'happy'|'hot'|'cold'|'unhappy'|'neutral'
function Sessions.mood(fare, driver)
    local climate = Config.Climate
    if fare.comfort <= climate.UnhappyThreshold then return 'unhappy' end
    local c = driver and driver.climate
    if not c or (Sessions.now() - c.at) > ServerConfig.ClimateStaleMs then return 'neutral' end
    if c.temp < climate.ComfortMin then return 'cold' end
    if c.temp > climate.ComfortMax then return 'hot' end
    return 'happy'
end

---@param fare TaxiFare
---@param driver TaxiDriver
function Sessions.snapshot(fare, driver)
    return {
        fare = math.floor(fare.currentFare * 100 + 0.5) / 100,
        distance = math.floor(fare.distanceMeters),
        comfort = math.floor(fare.comfort),
        mood = Sessions.mood(fare, driver),
    }
end

function Sessions.cleanupAll()
    for src, fare in pairs(ActiveFares) do
        Sessions.deleteNpc(fare)
        ActiveFares[src] = nil
    end
    for src in pairs(Drivers) do
        Drivers[src] = nil
    end
    ReservedPickups = {}
end
