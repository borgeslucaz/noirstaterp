local T = dofile('tests/testlib.lua')
local N = T.loadShared()

-- Runtime mínimo do FXServer usado por server/sessions.lua.
local gameTimer = 0
GetGameTimer = function() return gameTimer end
GetPlayerPed = function(source) return source > 0 and source * 10 or 0 end

local clientEvents = {}
TriggerClientEvent = function(name, target, payload)
    clientEvents[#clientEvents + 1] = { name = name, target = target, payload = payload }
end

local handlers = {}
AddEventHandler = function(name, callback)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = callback
end

local prints = {}
lib = {
    print = {
        debug = function(message) prints[#prints + 1] = message end,
        info = function(message) prints[#prints + 1] = message end,
        warn = function(message) prints[#prints + 1] = message end,
        error = function(message) prints[#prints + 1] = message end,
    },
}
json = { encode = function() return '{}' end }

package.loaded['config.server'] = {
    claim = { completionGraceMs = 15000 },
    sessions = { panelTtlSeconds = 900, requestIdTtlSeconds = 300 },
}
require = function(name) return package.loaded[name] end

dofile('server/log.lua')
dofile('server/sessions.lua')

local Sessions = N.Sessions
local C = N.Constants

local actor = { source = 5, citizenId = 'ABC12345', organization = { id = 'ballas', grade = 3 } }

-- Criação e transições ------------------------------------------------------------------

local session = Sessions.create(actor, C.SessionAction.CLAIM, { outpostId = 'docks', durationMs = 45000 })
T.equal(session.state, C.SessionState.OPENING, 'session starts opening')
T.equal(session.citizenId, 'ABC12345', 'session stores the citizen id')
T.equal(session.organizationId, 'ballas', 'session stores the organization id')
T.truthy(#session.id >= 32, 'session id is opaque and long')
T.equal(Sessions.get(session.id), session, 'session is addressable by id')
T.equal(Sessions.bySource(actor.source, C.SessionAction.CLAIM), session, 'session is addressable by source')

T.equal(Sessions.transition(session, C.SessionState.READY), true, 'opening moves to ready')
T.equal(Sessions.transition(session, C.SessionState.PROCESSING), true, 'ready moves to processing')
T.equal(Sessions.transition(session, C.SessionState.OPENING), false, 'processing cannot reopen')
T.equal(session.state, C.SessionState.PROCESSING, 'rejected transition keeps the state')
T.equal(Sessions.transition(session, C.SessionState.READY), true, 'processing returns to ready')

-- Duas ações concorrentes não compartilham a mesma sessão ---------------------------------

local other = Sessions.create(actor, C.SessionAction.ROBBERY, { outpostId = 'docks', dealerId = 7, durationMs = 12500 })
T.equal(Sessions.bySource(actor.source, C.SessionAction.CLAIM), session, 'claim session preserved')
T.equal(Sessions.activeForDealer(7), other, 'robbery session is found by dealer')
T.equal(Sessions.activeForOutpost('docks', C.SessionAction.ROBBERY), other, 'robbery found by outpost')

-- Abort executa o handler registrado e é idempotente ----------------------------------------

local aborts = 0
Sessions.onAbort(C.SessionAction.CLAIM, function(aborted, reason)
    aborts = aborts + 1
    T.equal(aborted.id, session.id, 'abort handler receives the session')
    T.equal(reason, 'timeout', 'abort handler receives the reason')
end)

Sessions.abort(session, 'timeout')
T.equal(aborts, 1, 'abort handler ran once')
T.equal(session.state, C.SessionState.CLOSED, 'aborted session ends closed')
T.equal(Sessions.get(session.id), nil, 'aborted session is detached')

Sessions.abort(session, 'timeout')
T.equal(aborts, 1, 'repeated abort does not run the handler again')

-- Expiração --------------------------------------------------------------------------------

gameTimer = 0
local expiring = Sessions.create(actor, C.SessionAction.CLAIM, { outpostId = 'docks', durationMs = 1000 })
Sessions.transition(expiring, C.SessionState.READY)
T.equal(Sessions.isExpired(expiring), false, 'fresh session is not expired')
gameTimer = 1000 + 15000 + 1
T.equal(Sessions.isExpired(expiring), true, 'session expires after duration plus grace')
T.equal(Sessions.elapsed(expiring), gameTimer, 'elapsed measures from the start')

aborts = 0
Sessions.tick()
T.equal(aborts, 1, 'tick aborts the expired session')
T.equal(Sessions.bySource(actor.source, C.SessionAction.CLAIM), nil, 'expired session is gone')

-- Cleanup por jogador e por outpost ------------------------------------------------------------

Sessions.create(actor, C.SessionAction.CLAIM, { outpostId = 'docks', durationMs = 45000 })
Sessions.create(actor, C.SessionAction.ROBBERY, { outpostId = 'docks', dealerId = 9, durationMs = 12500 })
Sessions.abortForSource(actor.source, 'player_dropped')
T.equal(Sessions.bySource(actor.source, C.SessionAction.CLAIM), nil, 'drop clears the claim session')
T.equal(Sessions.bySource(actor.source, C.SessionAction.ROBBERY), nil, 'drop clears the robbery session')
T.equal(Sessions.activeForDealer(9), nil, 'dealer is free after the drop')

Sessions.create(actor, C.SessionAction.CLAIM, { outpostId = 'docks', durationMs = 45000 })
Sessions.abortForOutpost('docks', 'outpost_rotated')
T.equal(Sessions.bySource(actor.source, C.SessionAction.CLAIM), nil, 'rotation clears outpost sessions')

-- Painéis ----------------------------------------------------------------------------------------

Sessions.openPanel(11, 'docks')
Sessions.openPanel(12, 'docks')
Sessions.openPanel(13, 'cypress')
local viewers = Sessions.panelViewers('docks')
table.sort(viewers)
T.equal(#viewers, 2, 'two viewers on the docks panel')
T.equal(viewers[1], 11, 'first docks viewer')
T.equal(viewers[2], 12, 'second docks viewer')

Sessions.closePanel(11, 'client')
T.equal(#Sessions.panelViewers('docks'), 1, 'closing a panel removes the viewer')
T.equal(Sessions.panel(11), nil, 'closed panel is gone')

local before = #clientEvents
Sessions.closePanel(11, 'client')
T.equal(#clientEvents, before, 'closing an unknown panel is silent')

Sessions.closePanel(12, 'too_far')
T.equal(clientEvents[#clientEvents].name, N.Constants.Events.PANEL_CLOSE, 'server-side close notifies the client')

-- Resource stop encerra tudo -------------------------------------------------------------------------

Sessions.create(actor, C.SessionAction.CLAIM, { outpostId = 'docks', durationMs = 45000 })
Sessions.abortAll('resource_stop')
T.equal(Sessions.bySource(actor.source, C.SessionAction.CLAIM), nil, 'resource stop clears sessions')
T.equal(#Sessions.panelViewers('cypress'), 0, 'resource stop clears panels')

print('sessions_spec: ok')
