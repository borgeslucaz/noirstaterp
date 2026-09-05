-- Entrada do servidor: disponibilidade do taxista, pausa, clima, central (depósito) e cleanup.
lib.locale(Config.Locale)

local RL = ServerConfig.RateLimits
local C = Config.Climate

local function notify(src, key, ntype, ...)
    exports.bgrz_core:Notify(src, locale(key, ...), ntype or 'inform')
end

-- ───────────────────────── disponibilidade ─────────────────────────

lib.callback.register('noir_taxijob:server:setAvailable', function(src, vehicleNetId)
    if not Security.rateLimit(src, 'setAvailable', RL.setAvailable) then return { ok = false, reason = 'rate' } end
    local netId = Security.sanitizeInt(vehicleNetId, 1)
    if not netId then return { ok = false, reason = 'vehicle' } end

    if not exports.bgrz_core:HasJob(src, Config.Job, false) then return { ok = false, reason = 'job' } end
    if Config.RequireDuty and not exports.bgrz_core:HasJob(src, Config.Job, true) then return { ok = false, reason = 'duty' } end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return { ok = false, reason = 'vehicle' } end
    if not Config.IsAllowedVehicle(GetEntityModel(veh)) then return { ok = false, reason = 'vehicle' } end
    if not Sessions.isDriverSeated(src, veh) then return { ok = false, reason = 'seat' } end

    local driver = Drivers[src]
    if driver then
        -- Voltou ao táxi (ou trocou de táxi) com sessão existente.
        if ActiveFares[src] and driver.vehicleNetId ~= netId then
            Sessions.cancelFare(src, 'vehicle_changed')
        end
        driver.vehicleNetId = netId
        driver.awaySince = nil
        return { ok = true, resume = true, status = driver.status }
    end

    Drivers[src] = {
        source = src,
        vehicleNetId = netId,
        status = 'available',
        nextOfferAt = 0,
    }
    Dispatch.scheduleNext(Drivers[src])
    Sessions.debug('driver available src=%s netId=%s', src, netId)
    return { ok = true, status = 'available' }
end)

RegisterNetEvent('noir_taxijob:server:setUnavailable', function(reason)
    Sessions.removeDriver(source, type(reason) == 'string' and reason:sub(1, 32) or 'left_vehicle')
end)

-- Cancelamento pedido pelo próprio client (sem assento, embarque falhou).
local clientCancelReasons = { no_seat = true, boarding_failed = true, passenger_left = true }
RegisterNetEvent('noir_taxijob:server:cancelFare', function(reason)
    local src = source
    local fare = ActiveFares[src]
    if not fare or (fare.status ~= 'accepted' and fare.status ~= 'hired') then return end
    if type(reason) ~= 'string' or not clientCancelReasons[reason] then reason = 'client_cancel' end
    Sessions.cancelFare(src, reason)
end)

RegisterNetEvent('noir_taxijob:server:setPaused', function(paused)
    local src = source
    local driver = Drivers[src]
    if not driver then return end
    if ActiveFares[src] then
        notify(src, 'notify.cannot_pause', 'error')
        return
    end
    if paused == true then
        driver.status = 'paused'
    else
        driver.status = 'available'
        Dispatch.scheduleNext(driver)
    end
    TriggerClientEvent('noir_taxijob:client:paused', src, paused == true)
end)

-- ───────────────────────── clima (validação) ─────────────────────────

RegisterNetEvent('noir_taxijob:server:climate', function(temp, fan)
    local src = source
    if not Security.rateLimit(src, 'climate', RL.climate) then return end
    local driver = Drivers[src]
    if not driver then return end

    local t = Security.sanitizeNumber(temp, C.MinTemp, C.MaxTemp)
    local f = Security.sanitizeInt(fan, 0, C.MaxFan)
    if not t or not f then
        return Security.report(src, 'climate', 'invalid_values', { temp = temp, fan = fan })
    end

    local now = Sessions.now()
    local prev = driver.climate
    if prev then
        local elapsed = math.max(1.0, (now - prev.at) / 1000.0)
        local maxDelta = ServerConfig.ClimateMaxDeltaPerSecond * elapsed + 0.5
        if math.abs(t - prev.temp) > maxDelta then
            Security.report(src, 'climate', 'implausible_delta', { from = prev.temp, to = t, elapsed = elapsed })
            -- mantém a tendência, mas limitada ao delta plausível
            t = prev.temp + (t > prev.temp and maxDelta or -maxDelta)
        end
    end
    driver.climate = { temp = t, fan = f, at = now }
end)

-- ───────────────────────── central / depósito ─────────────────────────

local function findFreeSpawnPoint()
    local vehicles = GetAllVehicles()
    for _, point in ipairs(Config.Depot.spawnPoints) do
        local free = true
        for _, veh in ipairs(vehicles) do
            if #(GetEntityCoords(veh) - vec3(point.x, point.y, point.z)) < 2.5 then
                free = false
                break
            end
        end
        if free then return point end
    end
    return nil
end

lib.callback.register('noir_taxijob:server:takeVehicle', function(src)
    if not Security.rateLimit(src, 'depot', RL.depot) then return { ok = false, reason = 'rate' } end
    if not Security.isNearCoords(src, Config.Depot.coords, Config.Depot.interactDistance + 5.0) then
        Security.report(src, 'takeVehicle', 'not_near_depot')
        return { ok = false, reason = 'failed' }
    end

    local job = exports.bgrz_core:GetJob(src)
    if not job then return { ok = false, reason = 'failed' } end

    local hired = false
    if job.name == Config.StarterJob then
        if not exports.qbx_core:SetJob(src, Config.Job, 0) then
            return { ok = false, reason = 'failed' }
        end
        hired = true
        job = exports.bgrz_core:GetJob(src)
        if not job or job.name ~= Config.Job then
            return { ok = false, reason = 'failed' }
        end
    elseif job.name ~= Config.Job then
        return { ok = false, reason = 'job' }
    end

    if Config.RequireDuty and not job.onDuty then
        exports.qbx_core:SetJobDuty(src, true)
    end

    if not exports.bgrz_core:HasJob(src, Config.Job, Config.RequireDuty) then
        return { ok = false, reason = 'duty' }
    end

    local existing = DepotVehicles[src]
    if existing then
        local veh = NetworkGetEntityFromNetworkId(existing)
        if veh ~= 0 and DoesEntityExist(veh) then
            return { ok = false, reason = 'already' }
        end
        DepotVehicles[src] = nil
    end

    local point = findFreeSpawnPoint()
    if not point then return { ok = false, reason = 'no_space' } end

    local plate = ('TAXI%04d'):format(math.random(0, 9999))
    local netId = exports.bgrz_core:SpawnVehicle(src, Config.Depot.vehicleModel, point, true, plate)
    if not netId then return { ok = false, reason = 'failed' } end

    DepotVehicles[src] = netId
    return { ok = true, netId = netId, hired = hired }
end)

lib.callback.register('noir_taxijob:server:returnVehicle', function(src, vehicleNetId)
    if not Security.rateLimit(src, 'depot', RL.depot) then return { ok = false, reason = 'rate' } end
    local netId = Security.sanitizeInt(vehicleNetId, 1)
    if not netId then return { ok = false, reason = 'not_yours' } end
    if DepotVehicles[src] ~= netId then return { ok = false, reason = 'not_yours' } end
    if not Security.isNearCoords(src, Config.Depot.coords, Config.Depot.returnRadius) then
        return { ok = false, reason = 'not_near' }
    end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then
        DepotVehicles[src] = nil
        return { ok = false, reason = 'not_yours' }
    end
    if #(GetEntityCoords(veh) - Security.getCoords(src)) > 10.0 then
        return { ok = false, reason = 'not_near' }
    end

    if ActiveFares[src] then
        Sessions.cancelFare(src, 'vehicle_returned')
    end
    Sessions.removeDriver(src, 'vehicle_returned')
    DeleteEntity(veh)
    DepotVehicles[src] = nil
    return { ok = true }
end)

-- ───────────────────────── cleanup ─────────────────────────

local function dropDepotVehicle(src)
    local netId = DepotVehicles[src]
    if not netId then return end
    DepotVehicles[src] = nil
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
end

AddEventHandler('playerDropped', function()
    local src = source
    Sessions.removeDriver(src, 'disconnect')
    dropDepotVehicle(src)
    Security.clearPlayer(src)
end)

AddEventHandler('bgrz_core:server:jobUpdated', function(src, job)
    if not job or job.name ~= Config.Job then
        Sessions.removeDriver(src, 'job_changed')
    elseif Config.RequireDuty and not job.onDuty then
        Sessions.removeDriver(src, 'off_duty')
    end
end)

AddEventHandler('bgrz_core:server:dutyUpdated', function(src, onDuty)
    if Config.RequireDuty and not onDuty then
        Sessions.removeDriver(src, 'off_duty')
    end
end)

AddEventHandler('bgrz_core:server:playerUnloaded', function(src)
    Sessions.removeDriver(src, 'unloaded')
    dropDepotVehicle(src)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Sessions.cleanupAll()
end)

-- ───────────────────────── loop principal (~1 Hz) ─────────────────────────

CreateThread(function()
    local last = GetGameTimer()
    while true do
        Wait(Config.Meter.UpdateInterval)
        local now = GetGameTimer()
        local dt = (now - last) / 1000.0
        last = now
        Dispatch.tick(now)
        Meter.tick(now, dt)
    end
end)
