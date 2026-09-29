-- Sessões autoritativas de interação (claim, roubo) e painéis abertos.
-- Máquina de estado explícita, TTL e cleanup idempotente.
NoirOutposts = NoirOutposts or {}

local Sessions = {}
NoirOutposts.Sessions = Sessions

local config = require 'config.server'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
local Log = NoirOutposts.Log

local sessions = {}
local bySource = {}
local panels = {}
local abortHandlers = {}
local counter = 0

local function opaqueId()
    counter = counter + 1
    return ('%08x-%08x-%08x-%08x'):format(
        os.time() % 0xFFFFFFFF,
        GetGameTimer() % 0xFFFFFFFF,
        math.random(0, 0xFFFFFFFF),
        (counter * 2654435761) % 0xFFFFFFFF
    )
end

---@param action string
---@param handler fun(session: table, reason: string)
function Sessions.onAbort(action, handler)
    abortHandlers[action] = handler
end

---@param actor OutpostActor
---@param action string
---@param data table { outpostId, dealerId?, durationMs }
---@return table session
function Sessions.create(actor, action, data)
    local now = GetGameTimer()
    local session = {
        id = opaqueId(),
        source = actor.source,
        citizenId = actor.citizenId,
        organizationId = actor.organization and actor.organization.id or nil,
        action = action,
        outpostId = data.outpostId,
        dealerId = data.dealerId,
        durationMs = data.durationMs,
        startedAt = now,
        expiresAt = now + data.durationMs + config.claim.completionGraceMs,
        createdAt = os.time(),
        state = C.SessionState.OPENING,
    }
    sessions[session.id] = session
    bySource[actor.source] = bySource[actor.source] or {}
    bySource[actor.source][action] = session
    return session
end

---@param sessionId string
---@return table? session
function Sessions.get(sessionId)
    return sessions[sessionId]
end

---@param source number
---@param action string
---@return table? session
function Sessions.bySource(source, action)
    local map = bySource[source]
    return map and map[action] or nil
end

---@param session table
---@param to string
---@return boolean
function Sessions.transition(session, to)
    if not V.canTransitionSession(session.state, to) then
        Log.warn('session_invalid_transition', { id = session.id, from = session.state, to = to })
        return false
    end
    session.state = to
    return true
end

---@param session table
---@return integer elapsedMs
function Sessions.elapsed(session)
    return GetGameTimer() - session.startedAt
end

---@param session table
---@return boolean
function Sessions.isExpired(session)
    return GetGameTimer() > session.expiresAt
end

local function detach(session)
    sessions[session.id] = nil
    local map = bySource[session.source]
    if map and map[session.action] == session then
        map[session.action] = nil
        if next(map) == nil then bySource[session.source] = nil end
    end
end

---Encerramento normal (idempotente).
---@param session table
function Sessions.close(session)
    if session.state ~= C.SessionState.CLOSED then session.state = C.SessionState.CLOSED end
    detach(session)
end

---Aborta e executa o cleanup registrado para a ação (idempotente).
---@param session table
---@param reason string
function Sessions.abort(session, reason)
    if session.state == C.SessionState.CLOSED or session.state == C.SessionState.ABORTED then
        detach(session)
        return
    end
    session.state = C.SessionState.ABORTED
    detach(session)
    local handler = abortHandlers[session.action]
    if handler then
        local ok, err = pcall(handler, session, reason)
        if not ok then Log.error('session_abort_handler_failed', { action = session.action, error = tostring(err) }) end
    end
    if reason ~= 'resource_stop' and GetPlayerPed(session.source) ~= 0 then
        TriggerClientEvent(C.Events.SESSION_ABORTED, session.source, { action = session.action, reason = reason })
    end
    session.state = C.SessionState.CLOSED
end

---@param source number
---@param reason string
function Sessions.abortForSource(source, reason)
    local map = bySource[source]
    if not map then return end
    local list = {}
    for _, session in pairs(map) do list[#list + 1] = session end
    for index = 1, #list do Sessions.abort(list[index], reason) end
end

---@param outpostId string
---@param reason string
function Sessions.abortForOutpost(outpostId, reason)
    local list = {}
    for _, session in pairs(sessions) do
        if session.outpostId == outpostId then list[#list + 1] = session end
    end
    for index = 1, #list do Sessions.abort(list[index], reason) end
end

---@param dealerId integer
---@return table? session
function Sessions.activeForDealer(dealerId)
    for _, session in pairs(sessions) do
        if session.dealerId == dealerId and session.state ~= C.SessionState.CLOSED then return session end
    end
    return nil
end

---@param outpostId string
---@param action string
---@return table? session
function Sessions.activeForOutpost(outpostId, action)
    for _, session in pairs(sessions) do
        if session.outpostId == outpostId and session.action == action
            and session.state ~= C.SessionState.CLOSED then
            return session
        end
    end
    return nil
end

function Sessions.tick()
    local expired = {}
    for _, session in pairs(sessions) do
        if Sessions.isExpired(session) then expired[#expired + 1] = session end
    end
    for index = 1, #expired do Sessions.abort(expired[index], 'timeout') end

    local now = os.time()
    for source, panel in pairs(panels) do
        if panel.openedAt + config.sessions.panelTtlSeconds < now then Sessions.closePanel(source, 'timeout') end
    end
end

function Sessions.abortAll(reason)
    local list = {}
    for _, session in pairs(sessions) do list[#list + 1] = session end
    for index = 1, #list do Sessions.abort(list[index], reason) end
    for source in pairs(panels) do Sessions.closePanel(source, reason) end
end

-- Painéis ------------------------------------------------------------------------------

---@param source number
---@param outpostId string
function Sessions.openPanel(source, outpostId)
    panels[source] = { outpostId = outpostId, openedAt = os.time() }
end

---@param source number
---@return table? panel
function Sessions.panel(source)
    return panels[source]
end

---@param source number
---@param reason string
function Sessions.closePanel(source, reason)
    local panel = panels[source]
    if not panel then return end
    panels[source] = nil
    if reason ~= 'client' and reason ~= 'resource_stop' and GetPlayerPed(source) ~= 0 then
        TriggerClientEvent(C.Events.PANEL_CLOSE, source, { reason = reason })
    end
end

---@param outpostId string
---@return number[] sources
function Sessions.panelViewers(outpostId)
    local list = {}
    for source, panel in pairs(panels) do
        if panel.outpostId == outpostId then list[#list + 1] = source end
    end
    return list
end
