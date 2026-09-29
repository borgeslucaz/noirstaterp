---Editor in-game (/editoronibus): tudo passa pela ACE, pelo rate limit e pelas regras do
---`shared/rules.lua`. A tela monta o rascunho; aqui ele é validado inteiro de novo.

local Config = require 'config.server'
local Rules = require 'shared.rules'
local Storage = require 'server.storage'
local Catalog = require 'server.catalog'
local Security = require 'server.security'
local Integrations = require 'server.integrations'

---Número inteiro vindo da NUI: o JSON pode chegar como 5.0.
---@return integer?
local function intId(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

local function isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.adminAce)
end

---@return table? refusal
local function guard(source, action)
    if not isAdmin(source) then return { ok = false, code = 'not_allowed' } end
    if not Storage.isReady() or not Catalog.isReady() then return { ok = false, code = 'storage_unavailable' } end
    if not Security.rateLimit(source, action or 'editor') then return { ok = false, code = 'busy' } end
end

local function audit(source, action, entity, entityId, data)
    local player = Integrations.character(source)
    Storage.log(player and player.citizenId or nil, GetPlayerName(source), action, entity, entityId, data and json.encode(data) or nil)
    lib.print.info(('editor: %s %s %s por %s'):format(action, entity, tostring(entityId), GetPlayerName(source)))
end

local function saved(extra)
    local result = { ok = true, catalog = Catalog.adminView() }
    for key, value in pairs(extra or {}) do result[key] = value end
    return result
end

lib.callback.register('noir_busjob:server:editor:data', function(source)
    local refused = guard(source)
    if refused then return refused end
    return saved()
end)

lib.callback.register('noir_busjob:server:editor:saveStop', function(source, id, stop)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    if id ~= nil then
        id = intId(id)
        if not id then return { ok = false, code = 'invalid_payload' } end
    end
    local savedId, code = Catalog.saveStop(id, stop)
    if not savedId then return { ok = false, code = code } end
    audit(source, id and 'update' or 'create', 'stop', savedId, Catalog.stops[savedId])
    return saved({ id = savedId })
end)

lib.callback.register('noir_busjob:server:editor:deleteStop', function(source, id)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    id = intId(id)
    if not id then return { ok = false, code = 'invalid_payload' } end
    local ok, code, usedBy = Catalog.deleteStop(id)
    if not ok then return { ok = false, code = code, usedBy = usedBy } end
    audit(source, 'delete', 'stop', id)
    return saved()
end)

lib.callback.register('noir_busjob:server:editor:saveRoute', function(source, id, route)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    if id ~= nil and (type(id) ~= 'string' or #id > Rules.LIMITS.routeId) then return { ok = false, code = 'invalid_payload' } end
    local savedId, code = Catalog.saveRoute(id, route)
    if not savedId then return { ok = false, code = code } end
    audit(source, id and 'update' or 'create', 'route', savedId, Catalog.routes[savedId])
    return saved({ id = savedId })
end)

lib.callback.register('noir_busjob:server:editor:deleteRoute', function(source, id)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    if type(id) ~= 'string' or #id > Rules.LIMITS.routeId then return { ok = false, code = 'invalid_payload' } end
    local ok, code = Catalog.deleteRoute(id)
    if not ok then return { ok = false, code = code } end
    audit(source, 'delete', 'route', id)
    return saved()
end)

lib.callback.register('noir_busjob:server:editor:saveVehicle', function(source, isNew, vehicle)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    local model, code = Catalog.saveVehicle(isNew == true, vehicle)
    if not model then return { ok = false, code = code } end
    audit(source, isNew and 'create' or 'update', 'vehicle', model, Catalog.vehicles[model])
    return saved({ id = model })
end)

lib.callback.register('noir_busjob:server:editor:deleteVehicle', function(source, model)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    if type(model) ~= 'string' or #model > Rules.LIMITS.model then return { ok = false, code = 'invalid_payload' } end
    local ok, code, usedBy = Catalog.deleteVehicle(model)
    if not ok then return { ok = false, code = code, usedBy = usedBy } end
    audit(source, 'delete', 'vehicle', model)
    return saved()
end)

lib.callback.register('noir_busjob:server:editor:saveLevels', function(source, levels)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    local ok, code = Catalog.saveLevels(levels)
    if not ok then return { ok = false, code = code } end
    audit(source, 'update', 'levels', 'all', Catalog.levels)
    return saved()
end)

lib.callback.register('noir_busjob:server:editor:saveSettings', function(source, settings)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    local ok, code = Catalog.saveSettings(settings)
    if not ok then return { ok = false, code = code } end
    audit(source, 'update', 'settings', 'all', Catalog.settings)
    return saved()
end)

---"Ir até": o cliente teleporta, mas só depois de o servidor confirmar que é admin e que o
---destino é uma parada ou o depósito do catálogo.
---Ponto livre (centro de uma área ainda não salva) só vale perto de uma parada ou da Central.
local TELEPORT_NEAR = 80.0

lib.callback.register('noir_busjob:server:editor:teleport', function(source, kind, id, point)
    local refused = guard(source)
    if refused then return refused end
    id = intId(id)
    if kind == 'stop' and id and Catalog.stops[id] then
        return { ok = true, point = Catalog.stops[id].dock }
    elseif kind == 'depot' then
        return { ok = true, point = Catalog.settings.depot.ped }
    elseif kind == 'point' then
        local target = Rules.point(point)
        if not target then return { ok = false, code = 'invalid_payload' } end
        local depot = Catalog.settings.depot.ped
        local near = Rules.planar(target, depot) <= TELEPORT_NEAR
        for _, stop in pairs(Catalog.stops) do
            if near then break end
            near = Rules.planar(target, stop.dock) <= TELEPORT_NEAR
        end
        if not near then return { ok = false, code = 'too_far' } end
        target.w = type(point.w) == 'number' and point.w or 0.0
        return { ok = true, point = target }
    end
    return { ok = false, code = 'invalid_payload' }
end)

lib.addCommand(Config.adminCommand, { help = locale('editor.command_help') }, function(source)
    if not isAdmin(source) then
        Integrations.notify(source, locale('editor.not_allowed'), 'error')
        return
    end
    if not Catalog.isReady() then
        Integrations.notify(source, locale('editor.not_ready'), 'error')
        return
    end
    TriggerClientEvent('noir_busjob:client:openEditor', source)
end)

---Mapa de debug das linhas (/onibusmap ou "Mapa das linhas" no editor): paradas, áreas e o
---trajeto de cada linha sobre os tiles do GTA.
local function mapData()
    local view = Catalog.adminView()
    -- Traçados salvos e em dia: o mapa desenha pela estrada em vez da linha reta.
    local roads = {}
    for id, route in pairs(Catalog.routes) do
        local trace = Catalog.traceFor(route)
        if trace then roads[id] = trace.points end
    end
    return { stops = view.stops, routes = view.routes, depot = Catalog.settings.depot, roads = roads }
end

lib.callback.register('noir_busjob:server:editor:mapData', function(source)
    local refused = guard(source)
    if refused then return refused end
    return { ok = true, map = mapData() }
end)

lib.addCommand(Config.mapCommand, { help = locale('editor.map_help') }, function(source)
    if not isAdmin(source) then
        Integrations.notify(source, locale('editor.not_allowed'), 'error')
        return
    end
    if not Catalog.isReady() then
        Integrations.notify(source, locale('editor.not_ready'), 'error')
        return
    end
    TriggerClientEvent('noir_busjob:client:openMap', source, mapData())
end)

---Traçado pela estrada (/onibusrota <código|all> [save]): manda ao client os pontos de cada
---linha na ordem (saída do ônibus, paradas, Central). O client leva o admin trecho a trecho,
---lê o caminho do GPS e, com `save`, devolve o traçado para gravar.
local function tracePayload(route)
    local depot = Catalog.settings.depot
    local points = { { x = depot.spawn.x, y = depot.spawn.y, z = depot.spawn.z } }
    for _, id in ipairs(route.stops) do
        local stop = Catalog.stops[id]
        if stop then points[#points + 1] = { x = stop.dock.x, y = stop.dock.y, z = stop.dock.z } end
    end
    points[#points + 1] = { x = depot.ped.x, y = depot.ped.y, z = depot.ped.z }
    return { id = route.id, code = route.code, points = points, straight = math.floor(Catalog.routeTiming(route)) }
end

lib.addCommand(Config.traceCommand, {
    help = locale('editor.trace_help'),
    params = {
        { name = 'linha', type = 'string', help = locale('editor.trace_param') },
        { name = 'acao', type = 'string', help = locale('editor.trace_save_param'), optional = true },
    },
}, function(source, args)
    if not isAdmin(source) then
        Integrations.notify(source, locale('editor.not_allowed'), 'error')
        return
    end
    local wanted = tostring(args.linha or ''):lower()
    local routes = {}
    if wanted == 'all' or wanted == 'todas' then
        for _, route in pairs(Catalog.routes) do routes[#routes + 1] = route end
        table.sort(routes, function(a, b) return a.code < b.code end)
    else
        local route = Catalog.routes[wanted]
        if not route then
            for _, candidate in pairs(Catalog.routes) do
                if candidate.code:lower() == wanted then route = candidate break end
            end
        end
        if not route then
            Integrations.notify(source, locale('editor.trace_unknown', wanted), 'error')
            return
        end
        routes[1] = route
    end
    local payload = { routes = {}, save = tostring(args.acao or ''):lower() == 'save', map = mapData() }
    for index, route in ipairs(routes) do payload.routes[index] = tracePayload(route) end
    TriggerClientEvent('noir_busjob:client:traceRoute', source, payload)
end)

lib.callback.register('noir_busjob:server:editor:saveTrace', function(source, routeId, samples, stats)
    local refused = guard(source, 'editorSave')
    if refused then return refused end
    if type(routeId) ~= 'string' or #routeId > Rules.LIMITS.routeId then return { ok = false, code = 'invalid_payload' } end
    local ok, code = Catalog.saveTrace(routeId, samples, stats, GetPlayerName(source))
    if not ok then return { ok = false, code = code } end
    local trace = Catalog.traces[routeId]
    audit(source, 'update', 'trace', routeId, { roadMeters = trace.roadMeters, failedLegs = trace.failedLegs })
    return { ok = true, roadMeters = trace.roadMeters }
end)
