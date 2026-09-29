local Config = require 'config.server'
local Rules = require 'shared.rules'
local Storage = require 'server.storage'
local Catalog = require 'server.catalog'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
require 'server.editor'

local sessions, menuSessions, starting, returning, leaderboard = {}, {}, {}, {}, { at = 0, entries = {} }
local schemaReady = false

MySQL.ready(function()
    local ok, err = pcall(function()
        local executed = Storage.migrate()
        Catalog.load()
        lib.print.info(('banco preparado (%d tabelas verificadas), catálogo com versão %d'):format(executed, Catalog.version))
    end)
    if not ok then
        lib.print.error(('falha ao preparar o banco ou o catálogo: %s'):format(err))
        return
    end
    schemaReady = true
    TriggerClientEvent('noir_busjob:client:catalog', -1, Catalog.publicView())
end)

local State = { IDLE = 'IDLE', DEADHEAD = 'DEADHEAD', DOCKED = 'DOCKED', BOARDING = 'BOARDING', DEPARTING = 'DEPARTING', RETURNING_DEPOT = 'RETURNING_DEPOT', PARKING = 'PARKING', COMPLETING = 'COMPLETING', SUMMARY = 'SUMMARY', CANCELLED = 'CANCELLED' }
local transitions = {
    [State.IDLE] = { [State.DEADHEAD] = true }, [State.DEADHEAD] = { [State.DOCKED] = true },
    [State.DOCKED] = { [State.BOARDING] = true }, [State.BOARDING] = { [State.DEPARTING] = true },
    [State.DEPARTING] = { [State.DOCKED] = true, [State.RETURNING_DEPOT] = true }, [State.RETURNING_DEPOT] = { [State.PARKING] = true },
    [State.PARKING] = { [State.COMPLETING] = true }, [State.COMPLETING] = { [State.SUMMARY] = true },
}

local function setBusState(session, nextState)
    if not transitions[session.state] or not transitions[session.state][nextState] then return false end
    session.state = nextState
    return true
end

local function getProfile(source)
    local player = Integrations.character(source)
    if not player then return nil end
    local row = Storage.profile(player.citizenId)
    if not row then
        Storage.createProfile(player.citizenId, player.name.full)
        row = { citizenid = player.citizenId, last_known_name = player.name.full, xp_total = 0, routes_completed = 0 }
    elseif row.last_known_name ~= player.name.full then
        Storage.renameProfile(player.citizenId, player.name.full)
    end
    row.level = Catalog.levelFor(tonumber(row.xp_total) or 0)
    return row, player
end

---O que a tela da Central mostra de uma linha, já com o que falta para o jogador.
local function routeView(source, route, level)
    local stops = {}
    for index, id in ipairs(route.stops) do stops[index] = Catalog.stops[id] and Catalog.stops[id].name or '?' end
    local vehicles = {}
    for _, model in ipairs(route.vehicles) do
        local vehicle = Catalog.vehicles[model]
        if vehicle and vehicle.enabled then
            vehicles[#vehicles + 1] = { model = model, label = vehicle.label, capacity = vehicle.capacity, minLevel = vehicle.minLevel, unlocked = level >= vehicle.minLevel }
        end
    end
    local unlockedVehicle = #Catalog.vehiclesFor(route, level) > 0
    local allowed = Integrations.hasGroupAccess(source, route.access.groups)
    return {
        id = route.id, code = route.code, name = route.name, minimumLevel = route.minLevel,
        vehicle = vehicles[1] and vehicles[1].label or '—', vehicles = vehicles,
        stopCount = #route.stops, stops = stops, baseXp = route.baseXp,
        restricted = next(route.access.groups) ~= nil, allowed = allowed,
        available = level >= route.minLevel and unlockedVehicle and allowed,
    }
end

local function rankingFor(citizenid)
    local now = GetGameTimer()
    if now - leaderboard.at > 45000 then
        leaderboard.entries = {}
        for i, row in ipairs(Storage.leaderboard()) do
            leaderboard.entries[i] = { rank = i, name = row.last_known_name, level = row.level, xp = row.xp_total, routes = row.routes_completed, averageScore = tonumber(row.average_score) or 0 }
        end
        leaderboard.at = now
    end
    return leaderboard.entries, Storage.rankOf(citizenid)
end

local function menuSnapshot(source)
    local profile, player = getProfile(source)
    if not profile then return nil end
    local routes = {}
    for _, route in pairs(Catalog.routes) do
        -- Linha restrita a grupo só aparece para quem é do grupo.
        if Catalog.routeUsable(route) and (next(route.access.groups) == nil or Integrations.hasGroupAccess(source, route.access.groups)) then
            routes[#routes + 1] = routeView(source, route, profile.level)
        end
    end
    table.sort(routes, function(a, b)
        if a.minimumLevel ~= b.minimumLevel then return a.minimumLevel < b.minimumLevel end
        local aNumber = tonumber(a.code:match('%d+')) or math.huge
        local bNumber = tonumber(b.code:match('%d+')) or math.huge
        if aNumber ~= bNumber then return aNumber < bNumber end
        return a.code < b.code
    end)
    local entries, rank = rankingFor(player.citizenId)
    local level, tier = Catalog.levelFor(tonumber(profile.xp_total) or 0)
    local active = sessions[source]
    local progression = Catalog.progression()
    return {
        profile = {
            displayName = player.name.full,
            level = level,
            title = tier.title,
            xp = profile.xp_total,
            nextXp = progression[level + 1] and progression[level + 1].xp or nil,
            routes = profile.routes_completed,
            rank = rank,
        },
        routes = routes,
        progression = progression,
        leaderboard = entries,
        activeRoute = active and {
            id = active.route.id,
            code = active.route.code,
            name = active.route.name,
            vehicle = active.vehicle.model,
            state = active.state,
        } or nil,
    }
end

local function validBus(source, session)
    local vehicle = NetworkGetEntityFromNetworkId(session.vehicleNetId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    if GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(source) then return nil end
    return vehicle
end

---Hora do servidor dentro de uma janela de pico?
local function peakNow()
    local peak = Catalog.settings.peak
    if not peak.enabled then return false end
    local hour = tonumber(os.date('%H'))
    for _, window in ipairs(peak.windows) do
        if hour >= window.from and hour < window.to then return true end
    end
    return false
end

local function prepareStopPassengers(session)
    if session.preparedStop and session.preparedStop.index == session.currentStopIndex then
        return session.preparedStop
    end

    local dropped = 0
    for i = 1, #session.passengers do
        if session.passengers[i].destination == session.currentStopIndex then dropped = dropped + 1 end
    end

    local passenger = Catalog.settings.passenger
    local capacity = session.vehicle.capacity
    local remaining = #session.passengers - dropped
    local board = 0
    if session.currentStopIndex < #session.route.stops then
        local maxDemand = passenger.maxDemand
        if peakNow() then maxDemand = math.ceil(maxDemand * Catalog.settings.peak.demandMultiplier) end
        board = math.max(0, math.min(capacity - remaining, math.random(passenger.minDemand, math.max(passenger.minDemand, maxDemand))))
    end

    session.preparedStop = { index = session.currentStopIndex, board = board, drop = dropped }
    return session.preparedStop
end

local function cleanup(source)
    local session = sessions[source]
    if not session then return end
    local vehicle = NetworkGetEntityFromNetworkId(session.vehicleNetId or 0)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    sessions[source] = nil
    returning[source] = nil
    TriggerClientEvent('noir_busjob:client:cleanup', source)
end

lib.callback.register('noir_busjob:server:catalog', function()
    if not Catalog.isReady() then return nil end
    return Catalog.publicView()
end)

lib.callback.register('noir_busjob:server:openMenu', function(source)
    if not schemaReady then return { ok = false, code = 'storage_unavailable' } end
    if not Security.rateLimit(source, 'menu') then return { ok = false, code = 'busy' } end
    if not Security.near(source, Catalog.settings.depot.ped, 10.0) then return { ok = false, code = 'too_far' } end
    local snapshot = menuSnapshot(source)
    if not snapshot then return { ok = false, code = 'profile_unavailable' } end
    local token = ('%x%x%x'):format(GetGameTimer(), source, math.random(0xFFFF))
    menuSessions[source] = token
    return { ok = true, sessionId = token, data = snapshot }
end)

lib.callback.register('noir_busjob:server:returnVehicle', function(source, token)
    if menuSessions[source] ~= token then return { ok = false, code = 'invalid_session' } end
    if returning[source] then return { ok = false, code = 'request_in_progress' } end
    if not sessions[source] then return { ok = false, code = 'no_active_route' } end

    returning[source] = true
    cleanup(source)

    local snapshot = menuSnapshot(source)
    if not snapshot then return { ok = false, code = 'profile_unavailable' } end
    return { ok = true, data = snapshot }
end)

lib.callback.register('noir_busjob:server:startRoute', function(source, token, routeId, model)
    if menuSessions[source] ~= token or sessions[source] or starting[source] or type(routeId) ~= 'string' or #routeId > Rules.LIMITS.routeId then
        return { ok = false, code = 'invalid_session' }
    end
    if model ~= nil and (type(model) ~= 'string' or #model > Rules.LIMITS.model) then return { ok = false, code = 'invalid_vehicle' } end
    if not Security.rateLimit(source, 'start') then return { ok = false, code = 'busy' } end
    starting[source] = true

    local function refuse(code)
        starting[source] = nil
        return { ok = false, code = code }
    end

    local profile, player = getProfile(source)
    local route = Catalog.routes[routeId]
    if not profile or not Catalog.routeUsable(route) or profile.level < route.minLevel then return refuse('route_locked') end
    if not Integrations.hasGroupAccess(source, route.access.groups) then return refuse('route_restricted') end

    local choices = Catalog.vehiclesFor(route, profile.level)
    local vehicle = choices[1]
    if model then
        vehicle = nil
        for _, choice in ipairs(choices) do
            if choice.model == model then vehicle = choice break end
        end
    end
    if not vehicle then return refuse('vehicle_locked') end

    local depot = Catalog.settings.depot
    local netId = Integrations.spawnVehicle(source, vehicle.model, vec4(depot.spawn.x, depot.spawn.y, depot.spawn.z, depot.spawn.w), ('%s%04d'):format(Config.platePrefix, math.random(9999)))
    if not netId then return refuse('spawn_failed') end

    local snapshot = Catalog.snapshotRoute(route)
    local session = {
        id = token, citizenid = player.citizenId, route = snapshot, state = State.IDLE, vehicleNetId = netId,
        vehicle = { model = vehicle.model, capacity = vehicle.capacity, doors = vehicle.doors },
        startedAt = os.time(), currentStopIndex = 1, completedStops = 0, passengers = {}, passengerCount = 0,
        totalBoarded = 0, totalDropped = 0, stopScores = {}, safetyPenalty = 0, servicePenalty = 0, finalized = false,
    }
    if not setBusState(session, State.DEADHEAD) then return refuse('invalid_state') end
    sessions[source], menuSessions[source] = session, nil
    starting[source] = nil
    return {
        ok = true, netId = netId, capacity = vehicle.capacity, doors = vehicle.doors,
        route = { id = snapshot.id, code = snapshot.code, name = snapshot.name, stops = snapshot.stops, stopCount = #snapshot.stops },
    }
end)

RegisterNetEvent('noir_busjob:server:prepareStopPassengers', function()
    local source, session = source, sessions[source]
    if not session or (session.state ~= State.DEADHEAD and session.state ~= State.DEPARTING) then return end

    local now = GetGameTimer()
    if session.lastPassengerPrepare and session.lastPassengerPrepare + 1000 > now then return end

    local stop = session.route.stops[session.currentStopIndex]
    local vehicle = validBus(source, session)
    if not vehicle or not Security.near(source, stop.dock, Catalog.settings.passenger.spawnDistance) then return end

    session.lastPassengerPrepare = now
    local prepared = prepareStopPassengers(session)
    TriggerClientEvent('noir_busjob:client:waitingPassengers', source, {
        stopIndex = session.currentStopIndex,
        board = prepared.board,
    })
end)

local finishStopService

RegisterNetEvent('noir_busjob:server:arriveStop', function()
    local source, session = source, sessions[source]
    if not session or session.state ~= State.DEADHEAD and session.state ~= State.DEPARTING then return end
    local stop = session.route.stops[session.currentStopIndex]
    local stopSettings = Catalog.settings.stop
    local vehicle = validBus(source, session)
    if not vehicle or not Security.near(source, stop.dock, stopSettings.radius) or GetEntitySpeed(vehicle) * 3.6 > stopSettings.maxDockSpeedKmh then return end
    if not setBusState(session, State.DOCKED) then return end
    session.dockDistance = #(GetEntityCoords(vehicle) - vec3(stop.dock.x, stop.dock.y, stop.dock.z))
    session.dockSpeed = GetEntitySpeed(vehicle) * 3.6
    local prepared = prepareStopPassengers(session)
    if not setBusState(session, State.BOARDING) then return end

    local token = ('%x%x%x'):format(GetGameTimer(), source, math.random(0xFFFF))
    session.service = {
        token = token,
        stopIndex = session.currentStopIndex,
        board = prepared.board,
        drop = prepared.drop,
    }
    TriggerClientEvent('noir_busjob:client:serviceStop', source, {
        stopIndex = session.currentStopIndex,
        board = prepared.board,
        drop = prepared.drop,
        capacity = session.vehicle.capacity,
        timeoutMs = stopSettings.serviceTimeoutMs,
    })

    SetTimeout(stopSettings.serviceTimeoutMs, function()
        local current = sessions[source]
        if current == session and current.state == State.BOARDING and current.service and current.service.token == token then
            finishStopService(source, true)
        end
    end)
end)

finishStopService = function(source, timedOut)
    local session = sessions[source]
    if not session or session.state ~= State.BOARDING or not session.service then return end

    local service = session.service
    local stopCount = #session.route.stops
    local dropped = 0
    for i = #session.passengers, 1, -1 do
        if session.passengers[i].destination == session.currentStopIndex then
            table.remove(session.passengers, i)
            dropped = dropped + 1
        end
    end

    local demand = math.min(session.vehicle.capacity - #session.passengers, service.board)
    for _ = 1, demand do
        session.passengers[#session.passengers + 1] = { boardedAt = session.currentStopIndex, destination = math.random(session.currentStopIndex + 1, stopCount) }
    end
    session.preparedStop, session.service = nil, nil
    session.passengerCount = #session.passengers
    session.totalBoarded, session.totalDropped = session.totalBoarded + demand, session.totalDropped + dropped

    local positionScore = session.dockDistance <= 2.5 and 100 or session.dockDistance <= 5.0 and 85 or 70
    local speedScore = session.dockSpeed <= 2.0 and 100 or 70
    local procedureScore = math.max(0, 100 - session.servicePenalty)
    local score = math.max(50, positionScore * .50 + speedScore * .25 + procedureScore * .25)
    session.stopScores[#session.stopScores + 1] = score
    session.completedStops = session.completedStops + 1
    if session.currentStopIndex == stopCount then
        setBusState(session, State.DEPARTING)
        setBusState(session, State.RETURNING_DEPOT)
    else
        setBusState(session, State.DEPARTING)
        session.currentStopIndex = session.currentStopIndex + 1
    end
    TriggerClientEvent('noir_busjob:client:stopCompleted', source, {
        score = score,
        returning = session.state == State.RETURNING_DEPOT,
        timedOut = timedOut == true,
        passengers = session.passengerCount,
    })
end

RegisterNetEvent('noir_busjob:server:completeStopService', function()
    local source, session = source, sessions[source]
    if not session or session.state ~= State.BOARDING or not session.service then return end
    local stop = session.route.stops[session.currentStopIndex]
    local vehicle = validBus(source, session)
    if not vehicle or not Security.near(source, stop.dock, Catalog.settings.stop.radius) then return end
    finishStopService(source, false)
end)

RegisterNetEvent('noir_busjob:server:telemetry', function(kind)
    local session = sessions[source]
    if not session or type(kind) ~= 'string' or (session.lastTelemetry or 0) + 1000 > GetGameTimer() then return end
    session.lastTelemetry = GetGameTimer()
    if kind == 'collision' then session.safetyPenalty = math.min(35, session.safetyPenalty + 4) elseif kind == 'hardBrake' or kind == 'hardAcceleration' then session.safetyPenalty = math.min(35, session.safetyPenalty + 2) end
end)

lib.callback.register('noir_busjob:server:park', function(source)
    local session = sessions[source]
    local vehicle = session and validBus(source, session)
    local depot = Catalog.settings.depot
    if not session or session.state ~= State.RETURNING_DEPOT or session.completedStops ~= #session.route.stops
        or not Security.near(source, depot.ped, depot.radius) or not vehicle
        or GetEntitySpeed(vehicle) * 3.6 > Catalog.settings.stop.maxDoorSpeedKmh then
        return { ok = false, code = 'invalid_completion' }
    end
    if session.finalized then return { ok = false, code = 'invalid_state' } end

    local timing = Catalog.settings.timing
    local duration = os.time() - session.startedAt
    if duration < session.route.expected * timing.minFraction then
        lib.print.warn(('%s fechou %s em %ds (esperado %ds); volta recusada'):format(session.citizenid, session.route.code, duration, math.floor(session.route.expected)))
        cleanup(source)
        return { ok = false, code = 'too_fast' }
    end
    if not setBusState(session, State.PARKING) or not setBusState(session, State.COMPLETING) then return { ok = false, code = 'invalid_state' } end
    session.finalized = true

    local sum = 0 for _, score in ipairs(session.stopScores) do sum = sum + score end
    local stopScore = sum / math.max(1, #session.stopScores)
    local safetyScore = math.max(0, 100 - session.safetyPenalty)
    local punctualityScore = Rules.punctuality(duration, session.route.expected, timing)
    local serviceScore = math.max(0, 100 - session.servicePenalty)
    local finalScore = stopScore * .35 + safetyScore * .30 + punctualityScore * .20 + serviceScore * .15
    local pay, xp = Rules.reward(session.route, Catalog.settings.payout, finalScore, session.totalDropped)

    local oldXp = Storage.profileXp(session.citizenid) or 0
    local oldLevel = Catalog.levelFor(oldXp)
    local newXp = oldXp + xp
    local newLevel = Catalog.levelFor(newXp)
    local ok = Storage.completeRoute({
        citizenId = session.citizenid, routeId = session.route.id, vehicleModel = session.vehicle.model, startedAt = session.startedAt,
        duration = duration, stops = session.completedStops, passengers = session.totalDropped,
        perfectStops = stopScore >= 95 and session.completedStops or 0, distance = math.floor(session.route.distance),
        stopScore = stopScore, safetyScore = safetyScore, punctualityScore = punctualityScore, serviceScore = serviceScore,
        finalScore = finalScore, pay = pay, xp = xp, xpTotal = newXp, level = newLevel,
    })
    if not ok then
        -- Nada foi gravado: a volta continua estacionando e pode tentar de novo.
        session.finalized = false
        session.state = State.RETURNING_DEPOT
        return { ok = false, code = 'storage_failed' }
    end
    if not Integrations.addMoney(source, pay, 'noir_busjob:route:credit') then
        lib.print.error(('pagamento de $%d a %s falhou depois de gravar a volta %s'):format(pay, session.citizenid, session.route.code))
    end
    leaderboard.at = 0
    setBusState(session, State.SUMMARY)
    cleanup(source)
    return { ok = true, summary = { payout = pay, xp = xp, finalScore = finalScore, stops = session.completedStops, passengers = session.totalDropped, level = newLevel, leveledUp = newLevel > oldLevel } }
end)

local function forget(source)
    cleanup(source)
    menuSessions[source] = nil
    starting[source] = nil
    returning[source] = nil
    Security.forget(source)
end

RegisterNetEvent('noir_busjob:server:cancel', function() cleanup(source) end)
AddEventHandler('playerDropped', function() forget(source) end)
AddEventHandler('bgrz_core:server:playerUnloaded', function(source) forget(source) end)
AddEventHandler('onResourceStop', function(resource) if resource == GetCurrentResourceName() then for source in pairs(sessions) do cleanup(source) end end end)
