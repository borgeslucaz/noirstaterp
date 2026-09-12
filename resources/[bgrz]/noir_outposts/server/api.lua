-- Superfície client → server. Todo callback valida ator, rate limit e payload antes de agir.
-- O client envia apenas intenção e identificadores opacos.
NoirOutposts = NoirOutposts or {}

local Api = {}
NoirOutposts.Api = Api

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Sessions = NoirOutposts.Sessions
local Security = NoirOutposts.Security
local Repositories = NoirOutposts.Repositories
local Services = NoirOutposts.Services

local function fail(code)
    return { ok = false, code = code }
end

---Wrapper padrão: resolve ator, aplica rate limit e captura exceções.
---@param action string
---@param handler fun(actor: OutpostActor, payload: table): table
---@return fun(source: number, payload: any): table
local function guarded(action, handler)
    return function(source, payload)
        local src = source
        if not Security.consumeRateLimit(src, action) then return fail('rate_limited') end
        if payload ~= nil and type(payload) ~= 'table' then return fail('invalid_payload') end

        local actor, actorError = Security.resolveActor(src)
        if not actor then return fail(actorError or 'invalid_player') end

        local ok, result = pcall(handler, actor, payload or {})
        if not ok then
            Log.error('callback_failed', { action = action, source = src, error = tostring(result) })
            return fail('internal_error')
        end
        return result or fail('internal_error')
    end
end

---Snapshot do painel para um jogador, revalidando permissão e proximidade.
---@param source number
---@param outpostId string
---@return table? snapshot
function Api.buildPanelSnapshot(source, outpostId)
    local actor = Security.resolveActor(source)
    if not actor then return nil end
    local entry = State.get(outpostId)
    if not entry then return nil end

    local definition = shared.outposts[outpostId]
    if not Security.isNear(source, definition.computer, shared.interaction.computerDistance) then return nil end

    local permissions = Security.permissionMap(actor)
    local online, police, cooldownUntil = Services.Claim.requirements(actor)
    local isOwner = Security.isOwner(actor, entry.row)

    return State.panelSnapshot(entry, actor, permissions, {
        online = online,
        police = police,
        cooldownUntil = cooldownUntil,
        carried = isOwner and permissions.stock and Services.Stock.carriedProducts(source) or nil,
        history = isOwner and permissions.view
            and Repositories.Operation.recent(outpostId, config.limits.maxHistoryEntries) or nil,
    })
end

lib.callback.register(C.Callbacks.GET_CONTEXT, guarded('refresh', function(actor)
    local permissions = Security.permissionMap(actor)
    return {
        ok = true,
        data = {
            organizationId = actor.organization and actor.organization.id or nil,
            permissions = permissions,
            outposts = State.publicSnapshot(),
        },
    }
end))

lib.callback.register(C.Callbacks.OPEN_PANEL, guarded('openPanel', function(actor, payload)
    local outpostId = Security.outpostId(payload.outpostId)
    if not outpostId then return fail('invalid_payload') end

    local entry = State.get(outpostId)
    if not entry then return fail('unknown_outpost') end
    if entry.row.status == C.OutpostStatus.INACTIVE then return fail('outpost_inactive') end

    local snapshot = Api.buildPanelSnapshot(actor.source, outpostId)
    if not snapshot then return fail('too_far') end

    Sessions.openPanel(actor.source, outpostId)
    return { ok = true, data = snapshot }
end))

lib.callback.register(C.Callbacks.REFRESH_PANEL, guarded('refresh', function(actor)
    local panel = Sessions.panel(actor.source)
    if not panel then return fail('invalid_session') end
    local snapshot = Api.buildPanelSnapshot(actor.source, panel.outpostId)
    if not snapshot then
        Sessions.closePanel(actor.source, 'too_far')
        return fail('too_far')
    end
    return { ok = true, data = snapshot }
end))

lib.callback.register(C.Callbacks.CLOSE_PANEL, guarded('refresh', function(actor)
    Sessions.closePanel(actor.source, 'client')
    return { ok = true }
end))

lib.callback.register(C.Callbacks.CLAIM_START, guarded('claim', function(actor, payload)
    local outpostId = Security.outpostId(payload.outpostId)
    if not outpostId then return fail('invalid_payload') end
    return Services.Claim.start(actor, outpostId)
end))

lib.callback.register(C.Callbacks.CLAIM_COMPLETE, guarded('claim', function(actor, payload)
    local sessionId = Security.sessionId(payload.sessionId)
    if not sessionId then return fail('invalid_payload') end
    return Services.Claim.complete(actor, sessionId)
end))

lib.callback.register(C.Callbacks.CLAIM_CANCEL, guarded('claim', function(actor, payload)
    local sessionId = Security.sessionId(payload.sessionId)
    if not sessionId then return fail('invalid_payload') end
    return Services.Claim.cancel(actor, sessionId)
end))

lib.callback.register(C.Callbacks.HIRE, guarded('hire', function(actor, payload)
    local outpostId = Security.outpostId(payload.outpostId)
    local profileKey = payload.profileKey
    local requestId = Security.requestId(payload.requestId)
    if not outpostId or not requestId or type(profileKey) ~= 'string' then return fail('invalid_payload') end
    return Services.Dealer.hire(actor, outpostId, profileKey, requestId)
end))

lib.callback.register(C.Callbacks.FIRE, guarded('fire', function(actor, payload)
    local outpostId = Security.outpostId(payload.outpostId)
    local dealerId = Security.dealerId(payload.dealerId)
    local requestId = Security.requestId(payload.requestId)
    if not outpostId or not dealerId or not requestId then return fail('invalid_payload') end
    return Services.Dealer.fire(actor, outpostId, dealerId, requestId)
end))

lib.callback.register(C.Callbacks.DEPOSIT, guarded('deposit', function(actor, payload)
    local outpostId = Security.outpostId(payload.outpostId)
    local amount = Security.amount(payload.amount, config.limits.maxStockPerDeposit)
    local requestId = Security.requestId(payload.requestId)
    if not outpostId or not amount or not requestId or type(payload.productId) ~= 'string' then
        return fail('invalid_payload')
    end
    return Services.Stock.deposit(actor, outpostId, payload.productId, amount, requestId)
end))

lib.callback.register(C.Callbacks.COLLECT, guarded('collect', function(actor, payload)
    local outpostId = Security.outpostId(payload.outpostId)
    local requestId = Security.requestId(payload.requestId)
    if not outpostId or not requestId then return fail('invalid_payload') end
    return Services.Stock.collect(actor, outpostId, requestId)
end))

lib.callback.register(C.Callbacks.INSPECT, guarded('inspect', function(actor, payload)
    local dealerId = Security.dealerId(payload.dealerId)
    local netId = Security.netId(payload.netId)
    if not dealerId or not netId then return fail('invalid_payload') end
    return Services.Dealer.inspect(actor, dealerId, netId)
end))

lib.callback.register(C.Callbacks.HOLDUP, guarded('holdup', function(actor, payload)
    local dealerId = Security.dealerId(payload.dealerId)
    local netId = Security.netId(payload.netId)
    if not dealerId or not netId then return fail('invalid_payload') end
    return Services.Holdup.start(actor, dealerId, netId)
end))

lib.callback.register(C.Callbacks.ROBBERY_START, guarded('robbery', function(actor, payload)
    local dealerId = Security.dealerId(payload.dealerId)
    local netId = Security.netId(payload.netId)
    if not dealerId or not netId then return fail('invalid_payload') end
    return Services.Robbery.start(actor, dealerId, netId)
end))

lib.callback.register(C.Callbacks.ROBBERY_COMPLETE, guarded('robbery', function(actor, payload)
    local sessionId = Security.sessionId(payload.sessionId)
    if not sessionId then return fail('invalid_payload') end
    return Services.Robbery.complete(actor, sessionId)
end))

lib.callback.register(C.Callbacks.ROBBERY_CANCEL, guarded('robbery', function(actor, payload)
    local sessionId = Security.sessionId(payload.sessionId)
    if not sessionId then return fail('invalid_payload') end
    return Services.Robbery.cancel(actor, sessionId)
end))

---Diagnóstico: o que o SERVIDOR enxerga de um corredor. Só devolve o que já é visível ao
---próprio jogador, e serve para comparar com o que o client vê.
lib.callback.register(C.Callbacks.DEBUG_TARGET, guarded('debug', function(actor, payload)
    local dealerId = Security.dealerId(payload.dealerId)
    local netId = Security.netId(payload.netId)
    if not dealerId or not netId then return fail('invalid_payload') end

    local dealer = State.dealer(dealerId)
    if not dealer then return { ok = true, data = { problem = 'corredor não existe no estado' } } end

    local entity = NoirOutposts.Entities.validate(dealerId, netId)
    if not entity then
        return { ok = true, data = { problem = 'net ID não resolve para o ped registrado' } }
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(actor.source))
    local corner = Services.Dealer.cornerOf(dealer)
    local tolerance = config.validation.maxDistanceTolerance

    -- O ponto que autoriza: o gravado na rendição se houver, senão a leitura do momento.
    local anchor = Services.Holdup.surrenderAnchor(dealerId)
    local coords, trusted
    if anchor then
        coords, trusted = anchor.coords, anchor.trusted
    else
        coords, trusted = Services.Dealer.observedPosition(dealer, entity)
    end

    local slack = Services.Dealer.wanderSlack()
    local origin = anchor and 'gravado na rendição'
        or (trusted and 'leitura do ped' or 'esquina cadastrada')

    return {
        ok = true,
        data = {
            dealerStatus = dealer.status,
            holdupState = Services.Holdup.stateOf(dealerId) or 'nenhum',
            measuredAgainst = origin,
            positionTrusted = trusted,
            positionSyncProven = Services.Dealer.positionSyncProven(),
            distance = math.floor(#(playerCoords - coords) * 100) / 100,
            robberyLimit = V.dealerReach(trusted, config.robbery.interactionDistance, slack) + tolerance,
            holdupLimit = V.dealerReach(trusted, config.holdup.maxDistance, slack) + tolerance,
            sameBucket = Security.sameBucket(actor.source, entity),
            dealerAt = ('%.1f, %.1f (esquina %s em %.1f, %.1f)'):format(
                coords.x, coords.y, tostring(dealer.corner_index),
                corner and corner.x or 0.0, corner and corner.y or 0.0),
            playerAt = ('%.1f, %.1f, %.1f'):format(playerCoords.x, playerCoords.y, playerCoords.z),
        },
    }
end))

lib.callback.register(C.Callbacks.PHONE_STATE, guarded('phone', function(actor)
    return { ok = true, data = State.phoneSnapshot(actor, Security.permissionMap(actor)) }
end))

lib.callback.register(C.Callbacks.PHONE_FEED_CLEAR, guarded('settings', function(actor)
    return Services.Settings.clearFeed(actor)
end))

lib.callback.register(C.Callbacks.PHONE_SETTINGS, guarded('settings', function(actor)
    return Services.Settings.snapshot(actor)
end))

lib.callback.register(C.Callbacks.PHONE_SETTINGS_SET, guarded('settings', function(actor, payload)
    if type(payload.alerts) ~= 'table' then return fail('invalid_payload') end
    return Services.Settings.setAlerts(actor, payload.alerts)
end))

lib.callback.register(C.Callbacks.PHONE_FEED, guarded('feed', function(actor, payload)
    -- Cursor ausente é a primeira página; cursor malformado é recusado, não ignorado.
    if payload.cursor ~= nil then
        local cursor = Security.feedCursor(payload.cursor)
        if not cursor then return fail('invalid_payload') end
        return Services.Feed.page(actor, cursor)
    end
    return Services.Feed.page(actor, nil)
end))
