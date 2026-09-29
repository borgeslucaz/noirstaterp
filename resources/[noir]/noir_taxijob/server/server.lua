-- Entrada do servidor: disponibilidade do taxista, pausa, clima, cleanup e loop principal.
-- A capacidade de trabalhar vem do aluguel ativo (ActiveRentals); emprego, grade e duty nunca são lidos ou alterados.
lib.locale(Config.Locale)

local RL = ServerConfig.RateLimits
local C = Config.Climate

local function notify(src, key, ntype, ...)
    exports.bgrz_core:Notify(src, locale(key, ...), ntype or 'inform')
end

-- ───────────────────────── validação de configuração ─────────────────────────

do
    local seen = {}
    for _, v in ipairs(Config.RentalVehicles) do
        if type(v.id) ~= 'string' or v.id == '' then
            error('[noir_taxijob] Config.RentalVehicles: entrada sem id')
        end
        if seen[v.id] then error(('[noir_taxijob] Config.RentalVehicles: id duplicado `%s`'):format(v.id)) end
        seen[v.id] = true
        if not Config.IsAllowedVehicle(v.model) then
            error(('[noir_taxijob] Config.RentalVehicles: model `%s` (%s) não consta em Config.AllowedVehicles'):format(v.model, v.id))
        end
        if type(v.requiredLevel) ~= 'number' or v.requiredLevel < 1 then
            error(('[noir_taxijob] Config.RentalVehicles: requiredLevel inválido em `%s`'):format(v.id))
        end
    end
end

-- ───────────────────────── disponibilidade ─────────────────────────

lib.callback.register('noir_taxijob:server:setAvailable', function(src, vehicleNetId)
    if not Security.rateLimit(src, 'setAvailable', RL.setAvailable) then return { ok = false, reason = 'rate' } end
    local netId = Security.sanitizeInt(vehicleNetId, 1)
    if not netId then return { ok = false, reason = 'vehicle' } end

    if not Sessions.isEligible(src, netId) then return { ok = false, reason = 'rental' } end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return { ok = false, reason = 'vehicle' } end
    if not Config.IsAllowedVehicle(GetEntityModel(veh)) then return { ok = false, reason = 'vehicle' } end
    if not Sessions.isDriverSeated(src, veh) then return { ok = false, reason = 'seat' } end

    local driver = Drivers[src]
    if driver then
        -- Voltou ao táxi com sessão existente.
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

-- ───────────────────────── cleanup ─────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    Rental.cleanup(src, 'disconnect')
    Security.clearPlayer(src)
end)

AddEventHandler('bgrz_core:server:playerUnloaded', function(src)
    Rental.cleanup(src, 'unloaded')
end)

-- Mudança de emprego ou duty não interfere na atividade: o Taxi V2 é renda extra independente.

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Sessions.cleanupAll()
    Rental.cleanupAll()
end)

-- ───────────────────────── loop principal (~1 Hz) ─────────────────────────

CreateThread(function()
    local last = GetGameTimer()
    while true do
        Wait(Config.Meter.UpdateInterval)
        local now = GetGameTimer()
        local dt = (now - last) / 1000.0
        last = now
        if next(Drivers) ~= nil then
            Dispatch.tick(now)
            Meter.tick(now, dt)
        end
    end
end)
