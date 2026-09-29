---Turno e coleta, com o servidor como fonte da verdade.
---
---O client só pede: começar turno, começar coleta num ponto, terminar a coleta,
---cancelar. Ponto atual, tempo de coleta, quantidade, ferramenta, stress e alerta
---são decididos aqui. Coleta concluída antes do tempo, longe do ponto ou fora de uma
---coleta aberta não paga nada.
---
---Estados de uma sessão:
---    ACTIVE      turno aberto esperando o jogador chegar ao ponto atual
---    COLLECTING  barra de progresso correndo num ponto
---    PROCESSING  entregando a coleta (trava contra pedido repetido)
---Sessão `free` é de rota sem início: nasce no COLLECTING e morre ao fim da coleta.

local Config = require 'config.server'
local SharedConfig = require 'config.shared'
local Rules = require 'shared.rules'
local Routes = require 'server.routes'
local Security = require 'server.security'
local Integrations = require 'server.integrations'

local State = { ACTIVE = 'ACTIVE', COLLECTING = 'COLLECTING', PROCESSING = 'PROCESSING' }

local Sessions = {}

---@type table<integer, table>
local sessions = {}

local function debugPrint(...)
    if SharedConfig.debug then lib.print.info('[sessions]', ...) end
end

local function fail(code)
    return { ok = false, error = code }
end

---Tira a sessão do jogador e avisa o client, que limpa blip, alvo e marcador.
---@param source integer
---@param reason string
local function endSession(source, reason)
    if not sessions[source] then return end
    sessions[source] = nil
    TriggerClientEvent('noir_gathering:client:sessionEnded', source, reason)
end

---Volta de uma coleta que não pagou: o turno segue no mesmo ponto; a sessão livre acaba.
local function resetCollect(source, session)
    if session.free then
        sessions[source] = nil
    else
        session.state = State.ACTIVE
        session.touchedAt = GetGameTimer()
    end
end

---Rota, item e ponto que o client apontou, resolvidos na config do servidor.
local function resolve(routeId, itemName, pointIndex)
    local route = Routes.get(routeId)
    if not route then return nil end
    local item = Rules.isName(itemName) and route.items[itemName] or nil
    if not item then return nil end
    if pointIndex == nil then return route, item end
    local point = Rules.isInteger(pointIndex) and item.points[pointIndex] or nil
    if not point then return nil end
    return route, item, point
end

local function canUseRoute(source, route)
    return Rules.isPublic(route.groups) or Integrations.hasGroupAccess(source, route.groups)
end
Sessions.canUseRoute = canUseRoute

---@param source integer
---@param routeId integer
---@param itemName string
local function startShift(source, routeId, itemName)
    if not Security.rateLimit(source, 'start') then return fail('busy') end
    if not Integrations.coreReady() then return fail('provider_unavailable') end

    local route, item = resolve(routeId, itemName)
    if not route or route.mode ~= 'shift' or not route.start or #item.points == 0 then
        return fail('invalid_route')
    end
    if sessions[source] or Sessions.busyElsewhere(source) then return fail('already_active') end
    if not Integrations.isLoaded(source) then return fail('not_loaded') end
    if not canUseRoute(source, route) then return fail('not_allowed') end
    if not Integrations.meetsRequirement(source, route.requirement) then return fail('locked') end

    local coords = Security.pedCoords(source)
    if not coords or #(coords - Security.toVector(route.start)) > Config.distance.start then
        return fail('too_far')
    end

    local first = Rules.nextPoint(item, nil, 0)
    sessions[source] = {
        routeId = routeId,
        item = itemName,
        point = first,
        collected = 0,
        state = State.ACTIVE,
        free = false,
        touchedAt = GetGameTimer(),
    }
    debugPrint(source, 'turno aberto', route.name, itemName, 'ponto', first)
    return { ok = true, point = first }
end

---@param source integer
---@param routeId integer
---@param itemName string
---@param pointIndex integer
local function beginCollect(source, routeId, itemName, pointIndex)
    if not Security.rateLimit(source, 'begin') then return fail('busy') end
    if not Integrations.coreReady() then return fail('provider_unavailable') end

    local route, item, point = resolve(routeId, itemName, pointIndex)
    if not route then return fail('invalid_route') end

    local session = sessions[source]
    if session then
        if session.free or session.state ~= State.ACTIVE then return fail('busy') end
        if session.routeId ~= routeId or session.item ~= itemName or session.point ~= pointIndex then
            return fail('wrong_point')
        end
    elseif route.mode ~= 'free' then
        return fail('no_shift')
    elseif Sessions.busyElsewhere(source) then
        return fail('already_active')
    end

    if not Integrations.isLoaded(source) then return fail('not_loaded') end
    if not canUseRoute(source, route) then return fail('not_allowed') end
    if not session and not Integrations.meetsRequirement(source, route.requirement) then return fail('locked') end

    local coords, ped = Security.pedCoords(source)
    if not coords or #(coords - Security.toVector(point)) > Config.distance.point then return fail('too_far') end

    local vehicleOk, vehicleErr = Security.checkVehicle(ped, coords, route.vehicle)
    if not vehicleOk then return fail(vehicleErr) end

    if item.tool then
        local hasTool, toolErr = Integrations.hasTool(source, item.tool.name, item.tool.cost)
        if not hasTool then return fail(toolErr == 'low_durability' and 'low_durability' or 'no_tool') end
    end

    if not session then
        session = { routeId = routeId, item = itemName, point = pointIndex, collected = 0, free = true }
        sessions[source] = session
    end
    session.state = State.COLLECTING
    session.startedAt = GetGameTimer()
    session.touchedAt = session.startedAt
    session.duration = item.time
    return { ok = true, duration = item.time }
end

---Entrega os extras que couberem. Extra que não cabe some sem travar a coleta principal.
local function giveExtras(source, item)
    for name, range in pairs(item.extras) do
        local amount = Rules.roll(range)
        if amount > 0 and Integrations.canCarry(source, name, amount) then
            local ok, err = Integrations.addItem(source, name, amount)
            if not ok then lib.print.warn(('extra %s x%d não entregue a %d: %s'):format(name, amount, source, err)) end
        end
    end
end

---@param source integer
local function finishCollect(source)
    if not Security.rateLimit(source, 'finish') then return fail('busy') end

    local session = sessions[source]
    if not session or session.state ~= State.COLLECTING then return fail('no_collect') end

    local route, item, point = resolve(session.routeId, session.item, session.point)
    if not route then
        endSession(source, 'route_changed')
        return fail('route_changed')
    end

    local elapsed = GetGameTimer() - session.startedAt
    if elapsed < session.duration * Config.minCollectFraction then
        debugPrint(source, 'coleta cedo demais', elapsed, session.duration)
        resetCollect(source, session)
        return fail('too_soon')
    end
    if elapsed > session.duration + Config.collectGraceMs then
        resetCollect(source, session)
        return fail('expired')
    end

    local coords = Security.pedCoords(source)
    if not coords or #(coords - Security.toVector(point)) > Config.distance.point + Config.distance.finishSlack then
        resetCollect(source, session)
        return fail('too_far')
    end

    session.state = State.PROCESSING

    local amount = Rules.roll(item)
    if amount > 0 and not Integrations.canCarry(source, session.item, amount) then
        resetCollect(source, session)
        return fail('inventory_full')
    end

    -- A ferramenta só gasta depois de tudo conferido: cancelar ou falhar não custa nada.
    if item.tool then
        local used, toolErr = Integrations.useTool(source, item.tool.name, item.tool.cost)
        if not used then
            resetCollect(source, session)
            return fail(toolErr == 'low_durability' and 'low_durability' or 'no_tool')
        end
    end

    if amount > 0 then
        local added, addErr = Integrations.addItem(source, session.item, amount)
        if not added then
            lib.print.warn(('coleta de %s x%d não entregue a %d: %s'):format(session.item, amount, source, addErr))
            resetCollect(source, session)
            return fail('inventory_full')
        end
        Integrations.notify(source, locale('collected', amount, item.label or Integrations.itemLabel(session.item)), 'success')
    end

    giveExtras(source, item)
    if item.stress then Integrations.addStress(source, Rules.roll(item.stress), SharedConfig.limits.stress) end

    if Rules.chance(Rules.alertChance(route, item)) then
        Integrations.dispatch(Rules.blurCoords(coords, route.police.radius), locale('dispatch_title'),
            locale('dispatch_message'), route.police.radius)
        debugPrint(source, 'alerta policial', route.name)
    end

    if session.free then
        sessions[source] = nil
        return { ok = true }
    end

    session.collected = session.collected + 1
    local nextPoint = Rules.nextPoint(item, session.point, session.collected)
    if not nextPoint then
        sessions[source] = nil
        return { ok = true, finished = true }
    end

    session.point = nextPoint
    session.state = State.ACTIVE
    session.touchedAt = GetGameTimer()
    return { ok = true, point = nextPoint }
end

---@param source integer
local function cancelCollect(source)
    local session = sessions[source]
    if session and session.state == State.COLLECTING then resetCollect(source, session) end
    return { ok = true }
end

---@param source integer
local function stopShift(source)
    sessions[source] = nil
    return { ok = true }
end

---Rota de carga aberta, respondida pelo módulo dela (`main.lua` liga os dois).
---@type fun(source: integer): boolean
Sessions.busyElsewhere = function() return false end

---Turno ou coleta aberta: quem está numa não abre rota de carga, e vice-versa.
---@param source integer
---@return boolean
function Sessions.isActive(source)
    return sessions[source] ~= nil
end

---@param source integer
function Sessions.forget(source)
    sessions[source] = nil
    Security.forget(source)
end

function Sessions.register()
    lib.callback.register('noir_gathering:server:startShift', startShift)
    lib.callback.register('noir_gathering:server:beginCollect', beginCollect)
    lib.callback.register('noir_gathering:server:finishCollect', finishCollect)
    lib.callback.register('noir_gathering:server:cancelCollect', cancelCollect)
    lib.callback.register('noir_gathering:server:stopShift', stopShift)

    -- Rota editada ou apagada: quem estava nela recomeça pelo menu, com a config nova.
    Routes.onChange(function(routeId)
        for source, session in pairs(sessions) do
            if session.routeId == routeId then endSession(source, 'route_changed') end
        end
    end)

    AddEventHandler('playerDropped', function() Sessions.forget(source) end)
    AddEventHandler('bgrz_core:server:playerUnloaded', function(playerId)
        Sessions.forget(tonumber(playerId) or source)
    end)

    -- TTL: coleta que nunca terminou e turno esquecido não ficam na memória.
    -- PROCESSING entra aqui também: se a entrega estourar no meio, a trava não fica presa.
    CreateThread(function()
        while true do
            Wait(60000)
            local now = GetGameTimer()
            for source, session in pairs(sessions) do
                if session.state ~= State.ACTIVE and now - session.startedAt > session.duration + Config.collectGraceMs then
                    resetCollect(source, session)
                elseif now - (session.touchedAt or now) > Config.sessionIdleMs then
                    endSession(source, 'idle')
                end
            end
        end
    end)
end

return Sessions
