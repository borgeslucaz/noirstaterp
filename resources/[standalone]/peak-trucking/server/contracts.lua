-- ============================================================
-- CONTRACTS — aquisição global atômica, sessão server-authoritative,
-- avaliação S–D, pagamento explicado e transições de falha.
-- ============================================================
Contracts = Contracts or {}

local ActiveJobs = {}            -- [src] = session
local SessionsByIdentifier = {}  -- [identifier] = session
local Suspended = {}             -- [identifier] = { session = , droppedAt = }

local PHASE_ORDER = { starting = 0, to_pickup = 1, in_transit = 2, returning = 3, completing = 4, done = 5 }

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

local function Err(key, ...)
    return { ok = false, error = key, message = L(key, ...) }
end

local function Vec3(v)
    return vector3(v.x, v.y, v.z)
end

local function PedDistance(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    local pcoords = GetEntityCoords(ped)
    return #(pcoords - Vec3(coords))
end

local function GenerateToken(identifier)
    local seed = ('%s|%d|%d|%d'):format(identifier or 'x', os.time(), GetGameTimer(), math.random(1, 2 ^ 30))
    return ('nt-%08x-%08x'):format(GetHashKey(seed) & 0xffffffff, math.random(0, 0xffffffff))
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Round2(v)
    return math.floor(v * 100 + 0.5) / 100
end

local function Log(fmt, ...)
    Peak.Utils.print(('[contracts] ' .. fmt):format(...))
end

function Contracts.GetSession(src)
    return ActiveJobs[src]
end

function Contracts.GetSessionByIdentifier(identifier)
    return SessionsByIdentifier[identifier]
end

-- ------------------------------------------------------------
-- Elegibilidade (única fonte de verdade para NUI e início)
-- ------------------------------------------------------------

local function MissionAvailable(profile, mission)
    if (Config.ContractBoard.starterMissions or {})[mission.id] then return true, nil end
    local level = tonumber(profile.level) or 1
    if mission.reqLevel then
        if level < mission.reqLevel then
            return false, { key = 'lock_mission_level', args = { mission.reqLevel }, err = 'err_mission_level', errArgs = { mission.reqLevel } }
        end
        return true, nil
    end
    local rep = tonumber((profile.points or {})[tostring(mission.companyIndex)]) or 0
    local need = tonumber(mission.reqPoint) or 0
    if rep < need then
        local company = Config.Companies[mission.companyIndex] or ''
        return false, { key = 'lock_reputation', args = { need }, err = 'err_reputation', errArgs = { need, company } }
    end
    return true, nil
end

--- @return boolean eligible, string[] reasons (texto), table|nil firstError {key,args}
function Contracts.CheckEligibility(profile, identifier, offer, activeSession)
    local reasons = {}
    local firstError = nil
    local function block(entry)
        reasons[#reasons + 1] = L(entry.key, table.unpack(entry.args or {}))
        if not firstError then firstError = { key = entry.err or entry.key, args = entry.errArgs or entry.args or {} } end
    end

    if offer.status ~= 'available' then
        return false, reasons, { key = offer.status == 'expired' and 'err_offer_expired' or 'err_offer_taken', args = {} }
    end

    local mission, route = ResolveCatalogRoute(offer.missionId, offer.routeIndex)
    if not mission or not route then
        return false, reasons, { key = 'err_offer_not_found', args = {} }
    end

    local level = tonumber(profile.level) or 1

    if Rotation.HasStarted(offer.rotationId, identifier) then
        block({ key = 'lock_used_rotation', err = 'err_rotation_used' })
    end

    if activeSession then
        block({ key = 'lock_active_session', err = 'err_active_session' })
    end

    local band = (Config.ContractBoard.global.levelBands or {})[offer.tier] or {}
    local bandMin = tonumber(band.min) or 1
    local bandMax = band.max and tonumber(band.max) or nil
    if level < bandMin or (bandMax and level > bandMax) then
        if bandMax then
            block({ key = 'lock_level_band', args = { bandMin, bandMax }, err = 'err_level_band', errArgs = { bandMin, bandMax } })
        else
            block({ key = 'lock_level_band_min', args = { bandMin }, err = 'err_level_band_min', errArgs = { bandMin } })
        end
    end

    local okMission, missionBlock = MissionAvailable(profile, mission)
    if not okMission then block(missionBlock) end

    if route.reqPoint then
        local rep = tonumber((profile.points or {})[tostring(mission.companyIndex)]) or 0
        if rep < route.reqPoint then
            local company = Config.Companies[mission.companyIndex] or ''
            block({ key = 'lock_route_reputation', args = { route.reqPoint }, err = 'err_route_reputation', errArgs = { route.reqPoint, company } })
        end
    end

    local anyTruck = false
    for _, name in ipairs(route.vehicle or {}) do
        for _, truck in ipairs(Config.Trucks) do
            if truck.name == name and level >= (tonumber(truck.level) or 1) then
                anyTruck = true
                break
            end
        end
        if anyTruck then break end
    end
    if not anyTruck then
        block({ key = 'lock_no_truck', err = 'err_truck_level', errArgs = { '?' } })
    end

    return #reasons == 0, reasons, firstError
end

-- ------------------------------------------------------------
-- Spawn físico (validação server-side antes da aquisição)
-- ------------------------------------------------------------

local function FindFreeTrailerSpawn(route)
    local coords = route.trailerSpawnAvaliableCoords
    if not coords then return nil, true end

    local vehicles = GetAllVehicles()
    local free = {}
    for idx, spot in ipairs(coords) do
        local occupied = false
        local spotVec = Vec3(spot)
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) and #(GetEntityCoords(veh) - spotVec) < 5.0 then
                occupied = true
                break
            end
        end
        if not occupied then free[#free + 1] = idx end
    end

    if #free == 0 then return nil, false end
    return free[math.random(1, #free)], true
end

-- ------------------------------------------------------------
-- Início autoritativo
-- ------------------------------------------------------------

function Contracts.Start(src, data)
    if type(data) ~= 'table' then return Err('err_invalid') end
    local rotationId = data.rotationId and tostring(data.rotationId) or nil
    local offerId = data.offerId and tostring(data.offerId) or nil
    local truckModel = data.truckModel and tostring(data.truckModel) or nil
    if not rotationId or not offerId or not truckModel then return Err('err_invalid') end

    local profile = GetPlayerJobData(src)
    if not profile then return Err('err_invalid') end
    local identifier = profile.identifier

    if ActiveJobs[src] or SessionsByIdentifier[identifier] then return Err('err_active_session') end
    if Suspended[identifier] then Contracts.ResolveSuspended(src, identifier) end

    local current = Rotation.Ensure()
    if not current then return Err('err_db') end
    if current.id ~= rotationId then return Err('err_offer_expired') end

    local offer = current.offers[offerId]
    if not offer then return Err('err_offer_not_found') end
    if offer.status ~= 'available' then return Err('err_offer_taken') end

    local eligible, _, firstError = Contracts.CheckEligibility(profile, identifier, offer, nil)
    if not eligible then
        local e = firstError or { key = 'err_invalid', args = {} }
        return Err(e.key, table.unpack(e.args or {}))
    end

    local mission, route = ResolveCatalogRoute(offer.missionId, offer.routeIndex)

    -- Caminhão: lista da rota + nível de Config.Trucks (revalidados aqui)
    local allowed = false
    for _, name in ipairs(route.vehicle or {}) do
        if name == truckModel then allowed = true break end
    end
    if not allowed then return Err('err_truck_not_allowed') end

    local truckCfg = nil
    for _, truck in ipairs(Config.Trucks) do
        if truck.name == truckModel then truckCfg = truck break end
    end
    if not truckCfg then return Err('err_truck_not_allowed') end
    if (tonumber(profile.level) or 1) < (tonumber(truckCfg.level) or 1) then
        return Err('err_truck_level', truckCfg.level)
    end

    -- Proximidade da central
    if PedDistance(src, Config.NpcLocation.coords) > (tonumber(Config.ContractBoard.startDistance) or 35.0) then
        return Err('err_too_far_central')
    end

    if ServerCanStartMission and not ServerCanStartMission(src, { missionId = offer.missionId, routeIndex = offer.routeIndex, tier = offer.tier }) then
        return Err('notaccessjob')
    end

    -- Disponibilidade física imediatamente antes da transição atômica
    local spawnIndex, spawnOk = FindFreeTrailerSpawn(route)
    if not spawnOk then return Err('err_spawn_full') end

    -- Transição atômica: somente um UPDATE pode afetar a oferta
    local affected = ExecuteSqlUpdate(
        "UPDATE peak_trucking_global_offers SET status = 'in_progress', driver_identifier = ?, started_at = NOW() WHERE offer_id = ? AND rotation_id = ? AND status = 'available'",
        { identifier, offerId, rotationId }
    )
    if affected == nil then
        Log('Banco indisponível na aquisição de %s por %s — falha fechada.', offerId, identifier)
        return Err('err_db')
    end
    if affected == 0 then
        -- Outro motorista venceu (ou o mesmo já iniciou nesta rotação → unique key)
        offer.status = 'in_progress'
        Log('Conflito de início em %s (%s perdeu).', offerId, identifier)
        return Err('err_offer_taken')
    end

    -- Vencedor confirmado
    offer.status = 'in_progress'
    offer.driverIdentifier = identifier
    Rotation.MarkStarted(rotationId, identifier)

    local meta = GetRouteMeta(offer.missionId, offer.routeIndex) or {}
    local session = {
        sessionId = GenerateToken(identifier),
        identifier = identifier,
        source = src,
        rotationId = rotationId,
        rotationExpiresAt = current.expiresAt,
        offerId = offerId,
        missionId = offer.missionId,
        routeIndex = offer.routeIndex,
        tier = offer.tier,
        truckModel = truckModel,
        truckNetId = nil,
        trailerSpawnIndex = spawnIndex,
        startedAt = os.time(),
        phase = 'starting',
        pickupConfirmedAt = nil,
        destinationConfirmedAt = nil,
        returningAt = nil,
        illegal = nil,
        completed = false,
        result = nil,
        estimatedMinutes = tonumber(meta.estimatedMinutes) or 20,
        baseXP = tonumber(meta.baseXP) or 400,
    }

    ActiveJobs[src] = session
    SessionsByIdentifier[identifier] = session

    local inserted = ExecuteSqlUpdate(
        "INSERT INTO peak_trucking_deliveries (session_id, identifier, rotation_id, offer_id, mission_id, route_index, tier, status, started_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'in_progress', NOW())",
        { session.sessionId, identifier, rotationId, offerId, offer.missionId, offer.routeIndex, offer.tier }
    )
    if not inserted then
        Log('Falha ao registrar entrega %s (sessão continua; conclusão exigirá reconciliação).', session.sessionId)
    end

    Rotation.PublishStatus(rotationId, offerId, 'in_progress')
    Log('%s iniciou %s (%s:%s, %s) sessão %s', identifier, offerId, offer.missionId, offer.routeIndex, offer.tier, session.sessionId)

    return {
        ok = true,
        sessionId = session.sessionId,
        missionId = session.missionId,
        routeIndex = session.routeIndex,
        truckModel = truckModel,
        trailerSpawnIndex = spawnIndex,
        tier = session.tier,
        estimatedMinutes = session.estimatedMinutes,
        routeLabel = route.label,
        title = mission.header,
    }
end

-- ------------------------------------------------------------
-- Fases
-- ------------------------------------------------------------

local function SessionFor(src, sessionId)
    local session = ActiveJobs[src]
    if not session or session.sessionId ~= tostring(sessionId) then return nil end
    return session
end

function Contracts.RegisterVehicle(src, sessionId, netId)
    local session = SessionFor(src, sessionId)
    if not session or session.phase ~= 'starting' then return false end
    netId = tonumber(netId)
    if not netId or netId == 0 then return false end

    local entity = NetworkGetEntityFromNetworkId(netId)
    local attempts = 0
    while (entity == 0 or not DoesEntityExist(entity)) and attempts < 50 do
        attempts = attempts + 1
        Wait(100)
        entity = NetworkGetEntityFromNetworkId(netId)
    end
    if entity == 0 or not DoesEntityExist(entity) then
        Log('Veículo netId %s da sessão %s não existe no servidor.', netId, session.sessionId)
        return false
    end
    if GetEntityModel(entity) ~= GetHashKey(session.truckModel) then
        Log('Modelo do veículo não confere na sessão %s.', session.sessionId)
        return false
    end

    session.truckNetId = netId
    local _, route = ResolveCatalogRoute(session.missionId, session.routeIndex)
    if session.missionId ~= 16 and not route.trailerSpawnAvaliableCoords then
        -- Missões sem carreta: a carga já está no caminhão.
        session.phase = 'in_transit'
        session.pickupConfirmedAt = os.time()
    else
        session.phase = 'to_pickup'
    end
    return true
end

function Contracts.ConfirmPickup(src, sessionId)
    local session = SessionFor(src, sessionId)
    if not session or session.phase ~= 'to_pickup' then return false end

    local _, route = ResolveCatalogRoute(session.missionId, session.routeIndex)
    local anchor = nil
    local maxDist = 200.0
    if session.missionId == 16 and route.board then
        anchor = route.board
        maxDist = 80.0
    elseif route.trailerSpawnAvaliableCoords and session.trailerSpawnIndex then
        anchor = route.trailerSpawnAvaliableCoords[session.trailerSpawnIndex]
    end
    if anchor and PedDistance(src, anchor) > maxDist then
        Log('Pickup fora de alcance na sessão %s.', session.sessionId)
        return false
    end

    session.phase = 'in_transit'
    session.pickupConfirmedAt = os.time()
    return true
end

function Contracts.ConfirmDestination(src, sessionId)
    local session = SessionFor(src, sessionId)
    if not session or session.phase ~= 'in_transit' then return false end

    local _, route = ResolveCatalogRoute(session.missionId, session.routeIndex)
    if PedDistance(src, route.destination) > (tonumber(Config.ContractBoard.destinationDistance) or 30.0) then
        Log('Destino fora de alcance na sessão %s.', session.sessionId)
        return false
    end

    session.phase = 'returning'
    session.destinationConfirmedAt = os.time()
    session.returningAt = session.destinationConfirmedAt
    return true
end

-- ------------------------------------------------------------
-- Avaliação
-- ------------------------------------------------------------

local function GradeFor(score)
    for _, g in ipairs(Config.Grading.grades) do
        if score >= g.min then return g end
    end
    return Config.Grading.grades[#Config.Grading.grades]
end

local function ReadVehicleHealth(entity, clientHealth)
    local pct = nil
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        local ok, body = pcall(GetVehicleBodyHealth, entity)
        if ok and type(body) == 'number' and body > 0 then
            pct = body / 10
        end
    end
    if pct == nil then
        pct = tonumber(clientHealth) or 0
    end
    return Clamp(pct, 0, 100)
end

function Contracts.Evaluate(session, integrityPct, returnDistance, vehicleIntact)
    local w = Config.Grading.weights
    local finishedAt = os.time()

    local integrity = (w.integrity or 40) * (integrityPct / 100)

    local elapsedMin = (finishedAt - session.startedAt) / 60
    local est = session.estimatedMinutes
    local lateFactor = tonumber(Config.Grading.lateFactor) or 2.0
    local punctRatio = 1.0
    if elapsedMin > est then
        local window = est * (lateFactor - 1)
        punctRatio = window > 0 and Clamp(1 - (elapsedMin - est) / window, 0, 1) or 0
    end
    local punctuality = (w.punctuality or 25) * punctRatio

    local stepsRatio = (session.pickupConfirmedAt and session.destinationConfirmedAt) and 1.0 or 0.5
    local steps = (w.steps or 20) * stepsRatio

    local handoverRatio = 1.0
    if not vehicleIntact then handoverRatio = 0.4 end
    if integrityPct < 30 then handoverRatio = math.min(handoverRatio, 0.5) end
    if returnDistance > 10.0 then handoverRatio = math.min(handoverRatio, 0.7) end
    local handover = (w.handover or 15) * handoverRatio

    local score = Round2(Clamp(integrity + punctuality + steps + handover, 0, 100))
    local grade = GradeFor(score)

    return {
        score = score,
        grade = grade.grade,
        gradeMoney = grade.money,
        gradeXp = grade.xp,
        gradeReputation = grade.reputation or 0,
        breakdown = {
            integrity = Round2(integrity),
            punctuality = Round2(punctuality),
            steps = Round2(steps),
            handover = Round2(handover),
        },
        elapsedMinutes = Round2(elapsedMin),
        integrityPct = Round2(integrityPct),
        finishedAt = finishedAt,
    }
end

function Contracts.ComputeReward(session, evaluation)
    local basePay = Rotation.BasePay(session.missionId, session.routeIndex, session.tier)
    local bonuses = Rotation.Bonuses(session.tier)

    local marketBonus = math.floor(basePay * bonuses.money)
    local qualityDelta = math.floor((basePay + marketBonus) * (evaluation.gradeMoney - 1))
    local damagePenalty = math.floor(basePay * ((100 - evaluation.integrityPct) / 100) * (tonumber(Config.Economy.damagePenaltyRate) or 0.25))

    local illegalValid = session.illegal ~= nil and (session.illegal.boxes or 0) >= 10
    local illegalBonus = illegalValid and (tonumber(Config.IllegalNPC.money) or 0) or 0
    local illegalXp = illegalValid and (tonumber(Config.IllegalNPC.xp_bonus) or 0) or 0

    local total = math.max(0, basePay + marketBonus + qualityDelta - damagePenalty + illegalBonus)
    local xp = math.floor(session.baseXP * (1 + bonuses.xp) * evaluation.gradeXp) + illegalXp
    local reputation = 1 + bonuses.reputation + evaluation.gradeReputation

    return {
        basePay = basePay,
        marketBonus = marketBonus,
        marketBonusPercent = math.floor(bonuses.money * 100 + 0.5),
        qualityDelta = qualityDelta,
        qualityPercent = math.floor((evaluation.gradeMoney - 1) * 100 + 0.5),
        damagePenalty = damagePenalty,
        illegalBonus = illegalBonus,
        illegalValid = illegalValid,
        total = total,
        xp = xp,
        reputation = reputation,
    }
end

-- ------------------------------------------------------------
-- Conclusão (idempotente)
-- ------------------------------------------------------------

local function ClearSession(session)
    if session.source and ActiveJobs[session.source] == session then
        ActiveJobs[session.source] = nil
    end
    if SessionsByIdentifier[session.identifier] == session then
        SessionsByIdentifier[session.identifier] = nil
    end
end

function Contracts.Finish(src, sessionId, clientHealth)
    local session = SessionFor(src, sessionId)
    if not session then return Err('no_active_job') end

    if session.completed and session.result then
        -- Repetição de conclusão: mesmo resultado, sem segundo pagamento.
        return { ok = true, duplicate = true, result = session.result }
    end
    if session.phase ~= 'returning' then
        Log('Conclusão fora de fase (%s) na sessão %s.', session.phase, session.sessionId)
        return Err('err_finish_phase')
    end

    local profile = GetPlayerJobData(src)
    if not profile or profile.identifier ~= session.identifier then return Err('err_invalid') end

    local mission, route = ResolveCatalogRoute(session.missionId, session.routeIndex)
    if not mission or not route then return Err('err_offer_not_found') end

    local minSeconds = session.estimatedMinutes * 60 * (tonumber(Config.ContractBoard.minCompletionRatio) or 0.25)
    local elapsed = os.time() - session.startedAt
    if elapsed < minSeconds then
        Log('Conclusão rápida demais na sessão %s (%ss de %ds mínimos).', session.sessionId, elapsed, math.floor(minSeconds))
        return Err('err_finish_too_fast', math.ceil((minSeconds - elapsed) / 60))
    end

    local returnDistance = PedDistance(src, Config.VehSpawn)
    if returnDistance > (tonumber(Config.ContractBoard.returnDistance) or 25.0) then
        Log('Devolução fora da área na sessão %s.', session.sessionId)
        return Err('err_finish_area')
    end

    local entity = session.truckNetId and NetworkGetEntityFromNetworkId(session.truckNetId) or 0
    local vehicleIntact = false
    if entity ~= 0 and DoesEntityExist(entity) then
        if GetEntityModel(entity) ~= GetHashKey(session.truckModel) then
            Log('Veículo devolvido não corresponde ao registrado (sessão %s).', session.sessionId)
            return Err('err_finish_vehicle')
        end
        if #(GetEntityCoords(entity) - Vec3(Config.VehSpawn)) > 40.0 then
            Log('Veículo registrado longe da devolução (sessão %s).', session.sessionId)
            return Err('err_finish_vehicle')
        end
        local okEngine, engine = pcall(GetVehicleEngineHealth, entity)
        vehicleIntact = (not okEngine) or (type(engine) ~= 'number') or engine > 0
    else
        Log('Veículo registrado inexistente na devolução (sessão %s).', session.sessionId)
        return Err('err_finish_vehicle')
    end

    session.phase = 'completing'

    local integrityPct = ReadVehicleHealth(entity, clientHealth)
    local evaluation = Contracts.Evaluate(session, integrityPct, returnDistance, vehicleIntact)
    local reward = Contracts.ComputeReward(session, evaluation)

    -- Grava o resultado ANTES do pagamento lógico (idempotência por session_id)
    local affected = nil
    for attempt = 1, 3 do
        affected = ExecuteSqlUpdate(
            "UPDATE peak_trucking_deliveries SET status = 'completed', grade = ?, score = ?, base_payment = ?, bonus_payment = ?, penalty_payment = ?, final_payment = ?, xp_awarded = ?, reputation_awarded = ?, result_reason = 'completed', finished_at = NOW() WHERE session_id = ? AND status = 'in_progress'",
            {
                evaluation.grade, evaluation.score, reward.basePay,
                reward.marketBonus + math.max(0, reward.qualityDelta) + reward.illegalBonus,
                reward.damagePenalty + math.max(0, -reward.qualityDelta),
                reward.total, reward.xp, reward.reputation, session.sessionId,
            }
        )
        if affected ~= nil then break end
        Wait(1500)
    end

    if affected == nil then
        session.phase = 'returning'
        Log('Banco indisponível ao concluir a sessão %s — sem pagamento.', session.sessionId)
        return Err('err_db')
    end
    if affected == 0 then
        -- Já registrada como concluída anteriormente: não paga de novo.
        session.completed = true
        ClearSession(session)
        return { ok = true, duplicate = true, result = session.result }
    end

    local result = {
        sessionId = session.sessionId,
        offerId = session.offerId,
        rotationId = session.rotationId,
        missionId = session.missionId,
        routeIndex = session.routeIndex,
        tier = session.tier,
        title = mission.header,
        routeLabel = route.label,
        companyIndex = mission.companyIndex,
        companyName = Config.Companies[mission.companyIndex] or '',
        grade = evaluation.grade,
        score = evaluation.score,
        scoreBreakdown = evaluation.breakdown,
        elapsedMinutes = evaluation.elapsedMinutes,
        estimatedMinutes = session.estimatedMinutes,
        integrityPct = evaluation.integrityPct,
        basePay = reward.basePay,
        marketBonus = reward.marketBonus,
        marketBonusPercent = reward.marketBonusPercent,
        qualityDelta = reward.qualityDelta,
        qualityPercent = reward.qualityPercent,
        damagePenalty = reward.damagePenalty,
        illegalBonus = reward.illegalBonus,
        total = reward.total,
        xp = reward.xp,
        reputation = reward.reputation,
        completedAt = evaluation.finishedAt,
        completedBeforeExpiry = evaluation.finishedAt < (session.rotationExpiresAt or 0),
    }

    session.completed = true
    session.result = result
    session.phase = 'done'

    -- Pagamento lógico (uma única vez)
    local paid = addMoney(src, reward.total)
    if not paid then
        Log('addMoney falhou para %s na sessão %s (valor %s) — registrado para reconciliação.', session.identifier, session.sessionId, reward.total)
        ExecuteSqlAsync("UPDATE peak_trucking_deliveries SET result_reason = 'payment_failed' WHERE session_id = ?", { session.sessionId })
    end

    -- Progressão
    local companyKey = tostring(mission.companyIndex)
    profile.points = profile.points or {}
    profile.points[companyKey] = math.max(0, (tonumber(profile.points[companyKey]) or 0) + reward.reputation)
    profile.totalEarnings = (tonumber(profile.totalEarnings) or 0) + reward.total
    profile.completedJobs = (tonumber(profile.completedJobs) or 0) + 1
    profile.globalCompleted = (tonumber(profile.globalCompleted) or 0) + 1

    ExecuteSqlAsync(
        'UPDATE peak_trucking SET `totalEarnings` = :earnings, `points` = :points, `completedJobs` = :jobs, `globalCompleted` = :gc WHERE `identifier` = :id',
        {
            earnings = profile.totalEarnings,
            points = json.encode(profile.points),
            jobs = profile.completedJobs,
            gc = profile.globalCompleted,
            id = profile.identifier,
        }
    )
    ExecuteSqlAsync(
        "UPDATE peak_trucking_global_offers SET status = 'completed', finished_at = NOW(), result_reason = 'completed' WHERE offer_id = ? AND rotation_id = ?",
        { session.offerId, session.rotationId }
    )

    AddXP(src, reward.xp)

    SyncPlayerDataByKey(src, 'points', profile.points)
    SyncPlayerDataByKey(src, 'totalEarnings', profile.totalEarnings)
    SyncPlayerDataByKey(src, 'completedJobs', profile.completedJobs)
    SyncPlayerDataByKey(src, 'globalCompleted', profile.globalCompleted)

    if DailyMissions and DailyMissions.OnDelivery then
        DailyMissions.OnDelivery(src, profile, result)
    end

    Rotation.PublishStatus(session.rotationId, session.offerId, 'completed')
    ClearSession(session)

    if reward.damagePenalty > 0 then
        TriggerClientEvent('peak-trucking:createNotification', src, L('you_charged', Peak.Utils.FormatNumber(reward.damagePenalty)))
    end
    TriggerClientEvent('peak-trucking:jobResult', src, result)
    SyncRecentDeliveries(src, profile)

    if OnServerMissionCompleted then
        pcall(OnServerMissionCompleted, src, session.missionId, reward.total, result)
    end

    Log('%s concluiu %s: nota %s (%.1f) total $%d xp %d rep +%d em %.1f min',
        session.identifier, session.offerId, evaluation.grade, evaluation.score, reward.total, reward.xp, reward.reputation, evaluation.elapsedMinutes)

    return { ok = true, result = result }
end

-- ------------------------------------------------------------
-- Falhas
-- ------------------------------------------------------------

--- @param session table
--- @param status 'failed'|'failed_system'
--- @param reason string
function Contracts.Fail(session, status, reason)
    if session.completed then return end
    session.completed = true
    session.phase = 'done'

    ExecuteSqlAsync(
        "UPDATE peak_trucking_deliveries SET status = ?, result_reason = ?, finished_at = NOW() WHERE session_id = ? AND status = 'in_progress'",
        { status, reason, session.sessionId }
    )
    ExecuteSqlAsync(
        "UPDATE peak_trucking_global_offers SET status = ?, finished_at = NOW(), result_reason = ? WHERE offer_id = ? AND rotation_id = ? AND status = 'in_progress'",
        { status, reason, session.offerId, session.rotationId }
    )

    local src = session.source
    local profile = src and GetPlayerJobData(src) or nil
    if status == 'failed' and profile and profile.identifier == session.identifier then
        profile.failedJobs = (tonumber(profile.failedJobs) or 0) + 1
        profile.globalFailed = (tonumber(profile.globalFailed) or 0) + 1
        ExecuteSqlAsync(
            'UPDATE peak_trucking SET `failedJobs` = :fj, `globalFailed` = :gf WHERE `identifier` = :id',
            { fj = profile.failedJobs, gf = profile.globalFailed, id = profile.identifier }
        )
        SyncPlayerDataByKey(src, 'failedJobs', profile.failedJobs)
        SyncPlayerDataByKey(src, 'globalFailed', profile.globalFailed)
    elseif status == 'failed' then
        ExecuteSqlAsync(
            'UPDATE peak_trucking SET `failedJobs` = `failedJobs` + 1, `globalFailed` = `globalFailed` + 1 WHERE `identifier` = :id',
            { id = session.identifier }
        )
    end

    Rotation.PublishStatus(session.rotationId, session.offerId, 'failed')
    ClearSession(session)

    if src and GetPlayerPed(src) ~= 0 then
        TriggerClientEvent('peak-trucking:jobFailed', src, { status = status, reason = reason, sessionId = session.sessionId })
        if profile then SyncRecentDeliveries(src, profile) end
    end

    if OnServerMissionFailed then
        pcall(OnServerMissionFailed, src, session.missionId, reason)
    end

    Log('%s encerrou %s como %s (%s).', session.identifier, session.offerId, status, reason)
end

function Contracts.Cancel(src, sessionId, reason)
    local session = SessionFor(src, sessionId)
    if not session then return false end
    reason = tostring(reason or 'cancelled')

    if session.phase == 'starting' and reason:find('spawn') then
        Contracts.Fail(session, 'failed_system', reason)
    else
        Contracts.Fail(session, 'failed', reason)
    end
    return true
end

-- ------------------------------------------------------------
-- Desconexão / reconexão / restart
-- ------------------------------------------------------------

function Contracts.OnDrop(src)
    local session = ActiveJobs[src]
    if not session then return end

    ActiveJobs[src] = nil
    session.source = nil
    Suspended[session.identifier] = { session = session, droppedAt = os.time() }

    local grace = tonumber(Config.ContractBoard.reconnectGraceSeconds) or 180
    SetTimeout(grace * 1000, function()
        local entry = Suspended[session.identifier]
        if entry and entry.session == session then
            Suspended[session.identifier] = nil
            Contracts.Fail(session, 'failed', 'disconnect')
        end
    end)
end

--- Política explícita de recuperação: dentro da janela, a sessão é
--- encerrada como falha técnica (sem penalidade); a carga não volta ao quadro.
function Contracts.ResolveSuspended(src, identifier)
    local entry = Suspended[identifier]
    if not entry then return end
    Suspended[identifier] = nil
    entry.session.source = src
    Contracts.Fail(entry.session, 'failed_system', 'reconnect_no_recovery')
    TriggerClientEvent('peak-trucking:createNotification', src, L('job_recovered_closed'))
end

function Contracts.OnResourceStop()
    for _, session in pairs(ActiveJobs) do
        if not session.completed then
            session.completed = true
            ExecuteSqlUpdate(
                "UPDATE peak_trucking_deliveries SET status = 'failed_system', result_reason = 'resource_stop', finished_at = NOW() WHERE session_id = ? AND status = 'in_progress'",
                { session.sessionId }
            )
            ExecuteSqlUpdate(
                "UPDATE peak_trucking_global_offers SET status = 'failed_system', finished_at = NOW(), result_reason = 'resource_stop' WHERE offer_id = ? AND status = 'in_progress'",
                { session.offerId }
            )
        end
    end
    for _, entry in pairs(Suspended) do
        ExecuteSqlUpdate(
            "UPDATE peak_trucking_deliveries SET status = 'failed_system', result_reason = 'resource_stop', finished_at = NOW() WHERE session_id = ? AND status = 'in_progress'",
            { entry.session.sessionId }
        )
        ExecuteSqlUpdate(
            "UPDATE peak_trucking_global_offers SET status = 'failed_system', finished_at = NOW(), result_reason = 'resource_stop' WHERE offer_id = ? AND status = 'in_progress'",
            { entry.session.offerId }
        )
    end
end

--- Reconciliação no start: nenhuma sessão sobrevive a um restart.
function Contracts.ReconcileAfterStart()
    ExecuteSqlUpdate("UPDATE peak_trucking_deliveries SET status = 'failed_system', result_reason = 'resource_restart', finished_at = NOW() WHERE status = 'in_progress'")
    ExecuteSqlUpdate("UPDATE peak_trucking_global_offers SET status = 'failed_system', finished_at = NOW(), result_reason = 'resource_restart' WHERE status = 'in_progress'")
end

-- ------------------------------------------------------------
-- Carga ilegal (ramo opcional dentro de sessão válida)
-- ------------------------------------------------------------

function Contracts.AcceptIllegal(src)
    local session = ActiveJobs[src]
    if not session or session.illegal then return false end
    if session.phase ~= 'to_pickup' and session.phase ~= 'in_transit' then return false end

    local allowed = Config.ContractBoard.illegalAllowedTiers
    if allowed and allowed[session.tier] == false then return false end

    session.illegal = { boxes = 0, acceptedAt = os.time(), lastBoxAt = 0 }
    return true
end

function Contracts.IllegalBox(src)
    local session = ActiveJobs[src]
    if not session or not session.illegal then return false end
    if session.illegal.boxes >= 10 then return false end

    local now = GetGameTimer()
    if now - (session.illegal.lastBoxAt or 0) < (tonumber(Config.ContractBoard.illegalBoxIntervalMs) or 1200) then
        return false
    end
    if PedDistance(src, Config.IllegalNPC.boardLocation) > (tonumber(Config.ContractBoard.illegalBoardDistance) or 80.0) then
        return false
    end

    session.illegal.lastBoxAt = now
    session.illegal.boxes = session.illegal.boxes + 1
    return true, session.illegal.boxes
end

-- ------------------------------------------------------------
-- Observabilidade simples
-- ------------------------------------------------------------

function Contracts.ActiveCount()
    local n = 0
    for _ in pairs(ActiveJobs) do n = n + 1 end
    return n
end
