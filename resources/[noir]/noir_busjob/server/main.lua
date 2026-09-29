local Config = require 'config'
local sessions, menuSessions, starting, returning, leaderboard = {}, {}, {}, {}, { at = 0, entries = {} }
local schemaReady = false

local function runMigrations()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_initial.sql')
    if not sql or sql == '' then
        error('Não foi possível carregar migrations/001_initial.sql.')
    end

    local executed = 0
    for rawStatement in sql:gmatch('([^;]+);') do
        local statement = rawStatement:match('^%s*(.-)%s*$')
        if statement ~= '' then
            if not statement:upper():match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+') then
                error(('Comando não permitido na migration: %s'):format(statement:sub(1, 80)))
            end
            MySQL.query.await(statement)
            executed = executed + 1
        end
    end

    if executed == 0 then
        error('A migration não contém comandos executáveis.')
    end

    schemaReady = true
    print(('[noir_busjob] Banco preparado (%d tabelas verificadas).'):format(executed))
end

MySQL.ready(function()
    local ok, migrationError = pcall(runMigrations)
    if not ok then
        print(('[noir_busjob] ^1Falha ao preparar o banco: %s^0'):format(migrationError))
    end
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

local function levelFor(xp)
    local current = Config.progression[1]
    for i = 1, #Config.progression do
        if xp >= Config.progression[i].xp then current = Config.progression[i] else break end
    end
    return current.level, current
end

local function near(source, coords, radius)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= radius
end

local function character(source)
    return exports.bgrz_core:GetCharacter(source)
end

local function getProfile(source)
    local player = character(source)
    if not player then return nil end
    local row = MySQL.single.await('SELECT * FROM busjob_driver_profiles WHERE citizenid = ?', { player.citizenId })
    if not row then
        MySQL.insert.await('INSERT INTO busjob_driver_profiles (citizenid, last_known_name) VALUES (?, ?)', { player.citizenId, player.name.full })
        row = { citizenid = player.citizenId, last_known_name = player.name.full, level = 1, xp_total = 0, routes_completed = 0, stops_completed = 0, passengers_transported = 0, perfect_stops = 0, total_earned = 0, score_sum = 0 }
    elseif row.last_known_name ~= player.name.full then
        MySQL.update.await('UPDATE busjob_driver_profiles SET last_known_name = ? WHERE citizenid = ?', { player.name.full, player.citizenId })
        row.last_known_name = player.name.full
    end
    row.level = levelFor(tonumber(row.xp_total) or 0)
    return row, player
end

local function routeView(routeId, level)
    local route = Config.routes[routeId]
    local stops = {}
    for i, stopId in ipairs(route.stops) do stops[i] = Config.stops[stopId].name end
    return { id = routeId, code = route.code, name = route.name, minimumLevel = route.minimumLevel, vehicle = route.vehicle, stopCount = #route.stops, stops = stops, baseXp = route.reward.baseXp, available = level >= route.minimumLevel }
end

local function rankingFor(citizenid)
    local now = GetGameTimer()
    if now - leaderboard.at > 45000 then
        local rows = MySQL.query.await([[SELECT last_known_name, level, xp_total, routes_completed, score_sum / NULLIF(routes_completed, 0) average_score
            FROM busjob_driver_profiles ORDER BY xp_total DESC, routes_completed DESC, average_score DESC, passengers_transported DESC LIMIT 50]]) or {}
        leaderboard.entries = {}
        for i, row in ipairs(rows) do leaderboard.entries[i] = { rank = i, name = row.last_known_name, level = row.level, xp = row.xp_total, routes = row.routes_completed, averageScore = tonumber(row.average_score) or 0 } end
        leaderboard.at = now
    end
    local position = MySQL.scalar.await([[SELECT COUNT(*) + 1 FROM busjob_driver_profiles o JOIN busjob_driver_profiles p ON p.citizenid = ?
        WHERE o.xp_total > p.xp_total OR (o.xp_total = p.xp_total AND o.routes_completed > p.routes_completed)
        OR (o.xp_total = p.xp_total AND o.routes_completed = p.routes_completed AND (o.score_sum / NULLIF(o.routes_completed, 0)) > (p.score_sum / NULLIF(p.routes_completed, 0))) ]], { citizenid }) or 1
    return leaderboard.entries, position
end

local function menuSnapshot(source)
    local profile, player = getProfile(source)
    if not profile then return nil end
    local routes = {}
    for id in pairs(Config.routes) do routes[#routes + 1] = routeView(id, profile.level) end
    table.sort(routes, function(a, b)
        if a.minimumLevel ~= b.minimumLevel then return a.minimumLevel < b.minimumLevel end
        local aNumber = tonumber(a.code:match('%d+')) or math.huge
        local bNumber = tonumber(b.code:match('%d+')) or math.huge
        if aNumber ~= bNumber then return aNumber < bNumber end
        return a.code < b.code
    end)
    local entries, rank = rankingFor(player.citizenId)
    local level, tier = levelFor(profile.xp_total)
    local active = sessions[source]
    local activeRoute = active and Config.routes[active.routeId] or nil
    return {
        profile = {
            displayName = player.name.full,
            level = level,
            title = tier.title,
            xp = profile.xp_total,
            nextXp = Config.progression[level + 1] and Config.progression[level + 1].xp or nil,
            routes = profile.routes_completed,
            rank = rank,
        },
        routes = routes,
        progression = Config.progression,
        leaderboard = entries,
        activeRoute = activeRoute and {
            id = active.routeId,
            code = activeRoute.code,
            name = activeRoute.name,
            vehicle = active.vehicleModel,
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

local function prepareStopPassengers(session, route)
    if session.preparedStop and session.preparedStop.index == session.currentStopIndex then
        return session.preparedStop
    end

    local dropped = 0
    for i = 1, #session.passengers do
        if session.passengers[i].destination == session.currentStopIndex then dropped = dropped + 1 end
    end

    local capacity = Config.vehicleProfiles[route.vehicle].capacity
    local remaining = #session.passengers - dropped
    local board = 0
    if session.currentStopIndex < #route.stops then
        board = math.min(capacity - remaining, math.random(Config.passenger.minDemand, Config.passenger.maxDemand))
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

lib.callback.register('noir_busjob:server:openMenu', function(source)
    if not schemaReady then return { ok = false, code = 'storage_unavailable' } end
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

lib.callback.register('noir_busjob:server:startRoute', function(source, token, routeId)
    if menuSessions[source] ~= token or sessions[source] or starting[source] or type(routeId) ~= 'string' then return { ok = false, code = 'invalid_session' } end
    starting[source] = true
    local profile, player = getProfile(source)
    local route = Config.routes[routeId]
    if not profile or not route or profile.level < route.minimumLevel then starting[source] = nil return { ok = false, code = 'route_locked' } end
    local netId = exports.bgrz_core:SpawnVehicle(source, route.vehicle, Config.Depot.spawn, true, ('NOIR%04d'):format(math.random(9999)))
    if not netId then starting[source] = nil return { ok = false, code = 'spawn_failed' } end
    local session = { id = token, citizenid = player.citizenId, routeId = routeId, state = State.IDLE, vehicleNetId = netId, vehicleModel = route.vehicle, startedAt = os.time(), currentStopIndex = 1, completedStops = 0, passengers = {}, passengerCount = 0, totalBoarded = 0, totalDropped = 0, stopScores = {}, safetyPenalty = 0, servicePenalty = 0, finalized = false }
    if not setBusState(session, State.DEADHEAD) then starting[source] = nil return { ok = false, code = 'invalid_state' } end
    sessions[source], menuSessions[source] = session, nil
    starting[source] = nil
    return { ok = true, netId = netId, route = routeView(routeId, profile.level), capacity = Config.vehicleProfiles[route.vehicle].capacity }
end)

RegisterNetEvent('noir_busjob:server:prepareStopPassengers', function()
    local source, session = source, sessions[source]
    if not session or (session.state ~= State.DEADHEAD and session.state ~= State.DEPARTING) then return end

    local now = GetGameTimer()
    if session.lastPassengerPrepare and session.lastPassengerPrepare + 1000 > now then return end

    local route = Config.routes[session.routeId]
    local stop = Config.stops[route.stops[session.currentStopIndex]]
    local vehicle = validBus(source, session)
    if not vehicle or not near(source, stop.coords, Config.passenger.spawnDistance) then return end

    session.lastPassengerPrepare = now
    local prepared = prepareStopPassengers(session, route)
    TriggerClientEvent('noir_busjob:client:waitingPassengers', source, {
        stopIndex = session.currentStopIndex,
        board = prepared.board,
    })
end)

local finishStopService

RegisterNetEvent('noir_busjob:server:arriveStop', function()
    local source, session = source, sessions[source]
    if not session or session.state ~= State.DEADHEAD and session.state ~= State.DEPARTING then return end
    local route, stop = Config.routes[session.routeId], nil
    stop = Config.stops[route.stops[session.currentStopIndex]]
    local vehicle = validBus(source, session)
    if not vehicle or not near(source, stop.coords, Config.stop.radius) or GetEntitySpeed(vehicle) * 3.6 > Config.stop.maxDockSpeedKmh then return end
    if not setBusState(session, State.DOCKED) then return end
    session.dockDistance = #(GetEntityCoords(vehicle) - stop.coords.xyz)
    session.dockSpeed = GetEntitySpeed(vehicle) * 3.6
    local prepared = prepareStopPassengers(session, route)
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
        capacity = Config.vehicleProfiles[route.vehicle].capacity,
        timeoutMs = Config.stop.serviceTimeoutMs,
    })

    SetTimeout(Config.stop.serviceTimeoutMs, function()
        local current = sessions[source]
        if current == session and current.state == State.BOARDING and current.service and current.service.token == token then
            finishStopService(source, true)
        end
    end)
end)

finishStopService = function(source, timedOut)
    local session = sessions[source]
    if not session or session.state ~= State.BOARDING or not session.service then return end

    local route = Config.routes[session.routeId]
    local service = session.service
    local dropped = 0
    for i = #session.passengers, 1, -1 do
        if session.passengers[i].destination == session.currentStopIndex then
            table.remove(session.passengers, i)
            dropped = dropped + 1
        end
    end

    local capacity = Config.vehicleProfiles[route.vehicle].capacity
    local demand = math.min(capacity - #session.passengers, service.board)
    for i = 1, demand do
        session.passengers[#session.passengers + 1] = { boardedAt = session.currentStopIndex, destination = math.random(session.currentStopIndex + 1, #route.stops) }
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
    if session.currentStopIndex == #route.stops then
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
    local route = Config.routes[session.routeId]
    local stop = Config.stops[route.stops[session.currentStopIndex]]
    local vehicle = validBus(source, session)
    if not vehicle or not near(source, stop.coords, Config.stop.radius) then return end
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
    if not session or session.state ~= State.RETURNING_DEPOT or session.completedStops ~= #Config.routes[session.routeId].stops or not near(source, Config.Depot.coords, Config.Depot.radius) or not vehicle or GetEntitySpeed(vehicle) * 3.6 > Config.stop.maxDoorSpeedKmh then return { ok = false, code = 'invalid_completion' } end
    if not setBusState(session, State.PARKING) or not setBusState(session, State.COMPLETING) or session.finalized then return { ok = false, code = 'invalid_state' } end
    session.finalized = true
    local sum = 0 for _, score in ipairs(session.stopScores) do sum = sum + score end
    local stopScore = sum / math.max(1, #session.stopScores)
    local safetyScore, punctualityScore, serviceScore = math.max(0, 100 - session.safetyPenalty), 85, math.max(0, 100 - session.servicePenalty)
    local finalScore = stopScore * .35 + safetyScore * .30 + punctualityScore * .20 + serviceScore * .15
    local reward = Config.routes[session.routeId].reward
    local quality = finalScore >= 95 and 1.15 or finalScore >= 90 and 1.10 or finalScore >= 80 and 1 or finalScore >= 70 and .95 or finalScore >= 60 and .85 or .75
    local xp = math.floor(reward.baseXp * quality + math.min(reward.baseXp * .15, session.totalDropped * 2))
    local pay = math.floor(reward.basePay + math.min(reward.basePay * .25, session.totalDropped * 5) + math.min(reward.basePay * .20, reward.basePay * math.max(0, finalScore - 80) / 100))
    local profile = MySQL.single.await('SELECT xp_total FROM busjob_driver_profiles WHERE citizenid = ?', { session.citizenid })
    local oldLevel = levelFor(profile.xp_total)
    local newXp, newLevel = profile.xp_total + xp, levelFor(profile.xp_total + xp)
    local ok = MySQL.transaction.await({
        { query = 'UPDATE busjob_driver_profiles SET xp_total=?, level=?, routes_completed=routes_completed+1, stops_completed=stops_completed+?, passengers_transported=passengers_transported+?, perfect_stops=perfect_stops+?, total_earned=total_earned+?, score_sum=score_sum+?, best_score=GREATEST(best_score, ?), last_route_id=?, last_route_at=NOW() WHERE citizenid=?', values = { newXp, newLevel, session.completedStops, session.totalDropped, stopScore >= 95 and session.completedStops or 0, pay, finalScore, finalScore, session.routeId, session.citizenid } },
        { query = 'INSERT INTO busjob_route_history (citizenid,route_id,vehicle_model,started_at,completed_at,duration_seconds,stops_completed,passengers_transported,stop_score,safety_score,punctuality_score,service_score,final_score,payout,xp_earned) VALUES (?, ?, ?, FROM_UNIXTIME(?), NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', values = { session.citizenid, session.routeId, session.vehicleModel, session.startedAt, os.time() - session.startedAt, session.completedStops, session.totalDropped, stopScore, safetyScore, punctualityScore, serviceScore, finalScore, pay, xp } },
    })
    if not ok then session.finalized = false return { ok = false, code = 'storage_failed' } end
    exports.bgrz_core:AddMoney(source, 'cash', pay, 'noir_busjob:route:credit')
    leaderboard.at = 0
    setBusState(session, State.SUMMARY)
    cleanup(source)
    return { ok = true, summary = { payout = pay, xp = xp, finalScore = finalScore, stops = session.completedStops, passengers = session.totalDropped, level = newLevel, leveledUp = newLevel > oldLevel } }
end)

RegisterNetEvent('noir_busjob:server:cancel', function() cleanup(source) end)
AddEventHandler('playerDropped', function() cleanup(source); menuSessions[source] = nil; starting[source] = nil; returning[source] = nil end)
AddEventHandler('bgrz_core:server:playerUnloaded', function(source) cleanup(source); menuSessions[source] = nil; starting[source] = nil; returning[source] = nil end)
AddEventHandler('onResourceStop', function(resource) if resource == GetCurrentResourceName() then for source in pairs(sessions) do cleanup(source) end end end)
