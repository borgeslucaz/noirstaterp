-- Roubo de dealer por rival. Loot, alvo e cooldown resolvidos no servidor.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Robbery = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Sessions = NoirOutposts.Sessions
local Security = NoirOutposts.Security
local Entities = NoirOutposts.Entities
local Integration = NoirOutposts.Integration
local Repositories = NoirOutposts.Repositories
local Notification = NoirOutposts.Services.Notification
local Rotation = NoirOutposts.Services.Rotation

---Revistar só é possível com o corredor rendido, e a rendição vem da abordagem armada.
---@param actor OutpostActor
---@param dealerId integer
---@param netId integer
---@return table? context { dealer, entry, entity }, string? code
local function validate(actor, dealerId, netId)
    -- Mede contra a posição gravada na rendição, não contra uma leitura nova. Sem rendição o
    -- âncora é nulo e `rivalTarget` cai na leitura do momento, o que preserva os códigos de
    -- recusa mais específicos (posto próprio, entidade inválida) antes do `not_surrendered`.
    local anchor = NoirOutposts.Services.Holdup.surrenderAnchor(dealerId)
    local context, code = NoirOutposts.Services.Dealer.rivalTarget(
        actor, dealerId, netId, config.robbery.interactionDistance, anchor)
    if not context then return nil, code end
    if not NoirOutposts.Services.Holdup.isSurrendered(dealerId) then
        return nil, 'not_surrendered'
    end
    return context
end

---@param actor OutpostActor
---@param dealerId integer
---@param netId integer
---@return table result
function Service.start(actor, dealerId, netId)
    if Sessions.bySource(actor.source, C.SessionAction.ROBBERY) then
        return { ok = false, code = 'request_in_progress' }
    end
    if Sessions.activeForDealer(dealerId) then return { ok = false, code = 'dealer_busy' } end

    local context, code = validate(actor, dealerId, netId)
    if not context then return { ok = false, code = code } end

    local session = Sessions.create(actor, C.SessionAction.ROBBERY, {
        outpostId = context.dealer.outpost_id,
        dealerId = dealerId,
        durationMs = config.robbery.durationMs,
    })
    session.netId = netId
    Sessions.transition(session, C.SessionState.READY)

    Log.info('robbery_started', {
        dealerId = dealerId,
        outpostId = context.dealer.outpost_id,
        citizenId = actor.citizenId,
        sessionId = session.id,
    })

    return { ok = true, data = { sessionId = session.id, durationMs = config.robbery.durationMs } }
end

---@param actor OutpostActor
---@param sessionId string
---@return table result
function Service.cancel(actor, sessionId)
    local session = Sessions.get(sessionId)
    if not session or session.source ~= actor.source or session.action ~= C.SessionAction.ROBBERY then
        return { ok = false, code = 'invalid_session' }
    end
    Sessions.close(session)
    return { ok = true }
end

---@param actor OutpostActor
---@param sessionId string
---@return table result
function Service.complete(actor, sessionId)
    local session = Sessions.get(sessionId)
    if not session or session.source ~= actor.source or session.action ~= C.SessionAction.ROBBERY then
        return { ok = false, code = 'invalid_session' }
    end
    if session.state ~= C.SessionState.READY then return { ok = false, code = 'invalid_state' } end
    if Sessions.isExpired(session) then
        Sessions.abort(session, 'timeout')
        return { ok = false, code = 'session_expired' }
    end
    if Sessions.elapsed(session) + config.claim.completionToleranceMs < session.durationMs then
        Sessions.abort(session, 'too_fast')
        Log.warn('robbery_completed_too_fast', {
            sessionId = sessionId,
            citizenId = actor.citizenId,
            elapsedMs = Sessions.elapsed(session),
        })
        return { ok = false, code = 'invalid_state' }
    end

    if not Sessions.transition(session, C.SessionState.PROCESSING) then
        return { ok = false, code = 'request_in_progress' }
    end

    local context, code = validate(actor, session.dealerId, session.netId)
    if not context then
        Sessions.transition(session, C.SessionState.READY)
        Sessions.abort(session, code or 'invalid_state')
        return { ok = false, code = code }
    end

    local dealer, entry = context.dealer, context.entry
    local now = os.time()

    -- Alvo e valores resolvidos no servidor; o client não envia item nem quantidade.
    local candidates = {}
    for index = 1, #State.productIds do
        local productId = State.productIds[index]
        if (entry.stock[productId] or 0) > 0 then candidates[#candidates + 1] = productId end
    end
    local productId = #candidates > 0 and candidates[math.random(#candidates)] or nil
    local stock = productId and entry.stock[productId] or 0

    local pursePercent = config.robbery.pursePercent.min
        + math.random() * (config.robbery.pursePercent.max - config.robbery.pursePercent.min)
    local stockPercent = config.robbery.stockPercent.min
        + math.random() * (config.robbery.stockPercent.max - config.robbery.stockPercent.min)
    local purseLoot, stockLoot = V.robberyLoot(
        tonumber(entry.row.purse_available) or 0, stock, pursePercent, stockPercent, config.robbery.maxStockUnits)

    if purseLoot <= 0 and stockLoot <= 0 then
        Sessions.close(session)
        return { ok = false, code = 'nothing_to_steal' }
    end

    if purseLoot > 0 and not Integration.canCarryItem(actor.source, config.payout.item, purseLoot) then
        purseLoot = 0
    end
    if stockLoot > 0 and productId and not Integration.canCarryItem(actor.source, productId, stockLoot) then
        stockLoot = 0
    end
    if purseLoot <= 0 and stockLoot <= 0 then
        Sessions.close(session)
        return { ok = false, code = 'cannot_carry' }
    end

    local nextSaleAt = now + config.robbery.cooldownSeconds + State.intervalFor(dealer.profile_key)
    local applied = Repositories.Dealer.applyRobbery({
        dealerId = dealer.id,
        dealerVersion = dealer.version,
        outpostId = dealer.outpost_id,
        purseLoot = purseLoot,
        item = stockLoot > 0 and productId or nil,
        stockLoot = stockLoot,
        robbedUntil = now + config.robbery.cooldownSeconds,
        nextSaleAt = nextSaleAt,
    })
    if not applied then
        Sessions.transition(session, C.SessionState.READY)
        Sessions.abort(session, 'conflict')
        State.reload(dealer.outpost_id)
        return { ok = false, code = 'invalid_state' }
    end

    local operationId = Rotation.uuid()
    Repositories.Operation.insert({
        id = operationId,
        type = C.OperationKind.ROBBERY,
        outpostId = dealer.outpost_id,
        dealerId = dealer.id,
        citizenId = actor.citizenId,
        organizationId = entry.row.owner_organization_id,
        item = stockLoot > 0 and productId or nil,
        quantity = stockLoot > 0 and stockLoot or nil,
        net = purseLoot,
        status = C.OperationStatus.PENDING,
        createdAt = now,
    })

    -- Entrega com compensação: o que não couber volta para o outpost.
    local deliveredPurse, deliveredStock = 0, 0
    if purseLoot > 0 then
        if Integration.addItem(actor.source, config.payout.item, purseLoot) then
            deliveredPurse = purseLoot
        else
            Repositories.Outpost.restorePurse(dealer.outpost_id, purseLoot)
            Log.warn('robbery_purse_compensated', { operationId = operationId, amount = purseLoot })
        end
    end
    if stockLoot > 0 and productId then
        if Integration.addItem(actor.source, productId, stockLoot) then
            deliveredStock = stockLoot
        else
            Repositories.Stock.restore(dealer.outpost_id, productId, stockLoot)
            Log.warn('robbery_stock_compensated', { operationId = operationId, item = productId, quantity = stockLoot })
        end
    end

    Repositories.Operation.setStatus(operationId, C.OperationStatus.PAID, os.time(), {
        purse = deliveredPurse,
        stock = deliveredStock,
        item = productId,
        profileKey = dealer.profile_key,
        dealerName = State.dealerName(dealer),
    })

    local ownerOrganizationId = entry.row.owner_organization_id
    -- Marca a janela em que executar o rendido vale pouco.
    NoirOutposts.Services.Dealer.markRobbed(dealer.id)
    Sessions.close(session)
    Entities.setState(dealer.id, C.DealerStatus.RECOVERING)
    State.reload(dealer.outpost_id)

    local definition = shared.outposts[dealer.outpost_id]
    Notification.notifyOrganization(ownerOrganizationId, 'security', {
        title = locale('phone.robbery_title'),
        body = locale('phone.robbery_body', State.dealerName(dealer), definition.label),
    })
    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(dealer.outpost_id)
    Notification.maybeDispatch(dealer, 'robbery', config.robbery.dispatchChance)

    Log.info('robbery_completed', {
        outpostId = dealer.outpost_id,
        dealerId = dealer.id,
        operationId = operationId,
        citizenId = actor.citizenId,
        purse = deliveredPurse,
        stock = deliveredStock,
    })

    return {
        ok = true,
        data = { purse = deliveredPurse, item = deliveredStock > 0 and productId or nil, quantity = deliveredStock },
    }
end

Sessions.onAbort(C.SessionAction.ROBBERY, function() end)
