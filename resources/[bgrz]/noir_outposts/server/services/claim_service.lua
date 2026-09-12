-- Tomada de outpost: sessão autoritativa, lock persistido e revalidação na conclusão.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Claim = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Sessions = NoirOutposts.Sessions
local Security = NoirOutposts.Security
local Integration = NoirOutposts.Integration
local Repositories = NoirOutposts.Repositories
local Notification = NoirOutposts.Services.Notification
local Rotation = NoirOutposts.Services.Rotation

---@param organizationId string
---@return integer cooldownUntil
function Service.cooldownUntil(organizationId)
    if not organizationId then return 0 end
    local row = Repositories.Outpost.getOrganization(organizationId)
    return row and tonumber(row.claim_cooldown_until) or 0
end

local function requirements(actor)
    local online = Integration.onlinePlayerCount()
    local police = Integration.onDutyPoliceCount()
    local cooldownUntil = Service.cooldownUntil(actor.organization and actor.organization.id or nil)
    return online, police, cooldownUntil
end

Service.requirements = requirements

---Validações comuns ao início e à conclusão do claim.
---@param actor OutpostActor
---@param outpostId string
---@return boolean ok, string? code
local function validate(actor, outpostId)
    if not Security.isActorAble(actor) then return false, 'player_unavailable' end
    local allowed, permissionError = Security.requirePermission(actor, 'claim')
    if not allowed then return false, permissionError end

    local entry = State.get(outpostId)
    if not entry then return false, 'unknown_outpost' end

    local definition = shared.outposts[outpostId]
    if not Security.isNear(actor.source, definition.computer, config.claim.interactionDistance) then
        return false, 'too_far'
    end

    local online, police, cooldownUntil = requirements(actor)
    if online < config.claim.minOnlinePlayers then return false, 'not_enough_players' end
    if police < config.claim.minPolice then return false, 'not_enough_police' end
    if cooldownUntil > os.time() then return false, 'organization_cooldown' end

    return true
end

---@param actor OutpostActor
---@param outpostId string
---@return table result { ok, code?, data? }
function Service.start(actor, outpostId)
    local entry = State.get(outpostId)
    if not entry then return { ok = false, code = 'unknown_outpost' } end
    -- Uma tomada em andamento merece mensagem própria; o resto é estado inválido.
    if entry.row.status == C.OutpostStatus.CLAIMING then
        return { ok = false, code = 'claim_in_progress' }
    end
    if entry.row.status ~= C.OutpostStatus.AVAILABLE then return { ok = false, code = 'invalid_state' } end

    local existing = Sessions.bySource(actor.source, C.SessionAction.CLAIM)
    if existing then return { ok = false, code = 'request_in_progress' } end
    if Sessions.activeForOutpost(outpostId, C.SessionAction.CLAIM) then
        return { ok = false, code = 'claim_in_progress' }
    end

    local ok, code = validate(actor, outpostId)
    if not ok then return { ok = false, code = code } end

    local session = Sessions.create(actor, C.SessionAction.CLAIM, {
        outpostId = outpostId,
        durationMs = config.claim.durationMs,
    })

    local affected = Repositories.Outpost.startClaim(
        outpostId, session.id, actor.organization.id, os.time())
    if not affected or affected == 0 then
        Sessions.close(session)
        State.reload(outpostId)
        return { ok = false, code = 'claim_in_progress' }
    end

    Sessions.transition(session, C.SessionState.READY)
    State.reload(outpostId)
    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(outpostId)
    Log.info('claim_started', {
        outpostId = outpostId,
        organizationId = actor.organization.id,
        citizenId = actor.citizenId,
        sessionId = session.id,
    })

    return {
        ok = true,
        data = { sessionId = session.id, durationMs = config.claim.durationMs },
    }
end

---Libera o lock persistido de um claim abandonado.
---@param session table
local function unlock(session)
    local affected = Repositories.Outpost.cancelClaim(session.outpostId, session.id)
    if affected and affected > 0 then
        State.reload(session.outpostId)
        Notification.broadcastPublicSnapshot()
        Notification.refreshPanels(session.outpostId)
    end
end

---@param actor OutpostActor
---@param sessionId string
---@return table result
function Service.cancel(actor, sessionId)
    local session = Sessions.get(sessionId)
    if not session or session.source ~= actor.source or session.action ~= C.SessionAction.CLAIM then
        return { ok = false, code = 'invalid_session' }
    end
    unlock(session)
    Sessions.close(session)
    Log.debug('claim_cancelled', { outpostId = session.outpostId, sessionId = sessionId })
    return { ok = true }
end

---@param actor OutpostActor
---@param sessionId string
---@return table result
function Service.complete(actor, sessionId)
    local session = Sessions.get(sessionId)
    if not session or session.source ~= actor.source or session.action ~= C.SessionAction.CLAIM then
        return { ok = false, code = 'invalid_session' }
    end
    if session.state ~= C.SessionState.READY then return { ok = false, code = 'invalid_state' } end
    if Sessions.isExpired(session) then
        Sessions.abort(session, 'timeout')
        return { ok = false, code = 'session_expired' }
    end
    if Sessions.elapsed(session) + config.claim.completionToleranceMs < session.durationMs then
        Sessions.abort(session, 'too_fast')
        Log.warn('claim_completed_too_fast', {
            sessionId = sessionId,
            citizenId = actor.citizenId,
            elapsedMs = Sessions.elapsed(session),
        })
        return { ok = false, code = 'invalid_state' }
    end
    if not actor.organization or actor.organization.id ~= session.organizationId then
        Sessions.abort(session, 'organization_changed')
        return { ok = false, code = 'organization_changed' }
    end

    if not Sessions.transition(session, C.SessionState.PROCESSING) then
        return { ok = false, code = 'request_in_progress' }
    end

    local ok, code = validate(actor, session.outpostId)
    if not ok then
        Sessions.transition(session, C.SessionState.READY)
        Sessions.abort(session, code or 'invalid_state')
        return { ok = false, code = code }
    end

    local now = os.time()
    local expiresAt = now + config.claim.ownerDurationHours * 3600
    local entry = State.get(session.outpostId)
    local previousOwner = entry and entry.row.owner_organization_id or nil

    -- A identidade de todos os perfis nasce junto com este domínio e permanece estável até
    -- o controle acabar. Uma nova tomada gera outro conjunto de nomes e rostos.
    local dealerRoster = V.drawIdentityRoster(shared.dealerProfiles, shared.dealerIdentities)
    if not dealerRoster then
        Sessions.transition(session, C.SessionState.READY)
        Sessions.abort(session, 'identity_pool_unavailable')
        Log.error('claim_identity_draw_failed', { outpostId = session.outpostId })
        return { ok = false, code = 'internal_error' }
    end

    local affected = Repositories.Outpost.completeClaim(
        session.outpostId, session.id, actor.organization.id, actor.citizenId, now, expiresAt, dealerRoster)
    if not affected or affected == 0 then
        Sessions.transition(session, C.SessionState.READY)
        Sessions.abort(session, 'invalid_state')
        State.reload(session.outpostId)
        return { ok = false, code = 'invalid_state' }
    end

    Repositories.Outpost.setOrganizationCooldown(
        actor.organization.id, now + config.claim.organizationCooldownMinutes * 60, now)

    local operationId = Rotation.uuid()
    Repositories.Operation.insert({
        id = operationId,
        type = C.OperationKind.CLAIM,
        outpostId = session.outpostId,
        citizenId = actor.citizenId,
        organizationId = actor.organization.id,
        status = C.OperationStatus.COMMITTED,
        createdAt = now,
        committedAt = now,
        payload = { previousOwnerId = previousOwner },
    })

    Sessions.close(session)
    State.reload(session.outpostId)

    local definition = shared.outposts[session.outpostId]
    Notification.notifyOrganization(actor.organization.id, 'control', {
        title = locale('phone.claim_title'),
        body = locale('phone.claim_body', definition.label),
    })
    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(session.outpostId)

    Log.info('claim_completed', {
        outpostId = session.outpostId,
        organizationId = actor.organization.id,
        citizenId = actor.citizenId,
        operationId = operationId,
    })

    return { ok = true, data = { expiresAt = expiresAt } }
end

Sessions.onAbort(C.SessionAction.CLAIM, function(session)
    unlock(session)
end)
