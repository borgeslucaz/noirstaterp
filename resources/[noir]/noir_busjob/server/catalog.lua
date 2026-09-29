---Catálogo em memória (paradas, linhas, veículos, níveis e ajustes). O banco é a fonte; o
---editor grava lá e aqui, e cada mudança sai para os clientes numa visão pública.

local Rules = require 'shared.rules'
local Storage = require 'server.storage'

local Catalog = {
    stops = {},    ---@type table<integer, table>
    routes = {},   ---@type table<string, table>
    vehicles = {}, ---@type table<string, table>
    levels = {},   ---@type table[]
    settings = {}, ---@type table
    traces = {},   ---@type table<string, table> traçado pela estrada de cada linha
    version = 0,
}

local SETTING_KEYS = { 'depot', 'stop', 'passenger', 'payout', 'timing', 'peak', 'vehicleFailure' }
local ready = false

---@return boolean
function Catalog.isReady()
    return ready
end

local function known()
    return { stops = Catalog.stops, vehicles = Catalog.vehicles }
end

-- Seed --------------------------------------------------------------------------------

---Converte o `data/seed.lua` para linhas do banco, passando tudo pelas mesmas regras do
---editor: seed inválido não entra.
local function seedRows()
    local seed = require 'data.seed'
    local rows = { stops = {}, routes = {}, vehicles = {}, settings = {} }

    local settings, code = Rules.normalizeSettings(seed, seed)
    if not settings then error(('seed: ajustes inválidos (%s)'):format(code)) end
    local levels, levelCode = Rules.normalizeLevels(seed.levels)
    if not levels then error(('seed: níveis inválidos (%s)'):format(levelCode)) end
    for _, key in ipairs(SETTING_KEYS) do
        rows.settings[#rows.settings + 1] = { key = key, data = json.encode(settings[key]) }
    end
    rows.settings[#rows.settings + 1] = { key = 'levels', data = json.encode(levels) }

    local stops, vehicles = {}, {}
    for _, entry in ipairs(seed.vehicles) do
        local vehicle, vehicleCode = Rules.normalizeVehicle(entry)
        if not vehicle then error(('seed: veículo %s inválido (%s)'):format(tostring(entry.model), vehicleCode)) end
        vehicles[vehicle.model] = vehicle
        rows.vehicles[#rows.vehicles + 1] = { model = vehicle.model, data = json.encode(vehicle) }
    end
    for _, entry in ipairs(seed.stops) do
        local stop, stopCode = Rules.normalizeStop(entry)
        if not stop then error(('seed: parada %s inválida (%s)'):format(tostring(entry.id), stopCode)) end
        stops[entry.id] = stop
        rows.stops[#rows.stops + 1] = { id = entry.id, data = json.encode(stop) }
    end
    for _, entry in ipairs(seed.routes) do
        local route, routeCode = Rules.normalizeRoute(entry, { stops = stops, vehicles = vehicles })
        if not route then error(('seed: linha %s inválida (%s)'):format(entry.id, routeCode)) end
        rows.routes[#rows.routes + 1] = { id = entry.id, data = json.encode(route) }
    end
    return rows
end

-- Carga -------------------------------------------------------------------------------

local function decode(raw, label)
    local ok, value = pcall(json.decode, raw)
    if not ok or type(value) ~= 'table' then
        lib.print.error(('%s com JSON inválido; ignorado'):format(label))
        return nil
    end
    return value
end

---Lê o banco inteiro. Registro que não passa nas regras é ignorado com erro no log, em vez
---de derrubar o job todo.
function Catalog.load()
    if Storage.catalogEmpty() then
        if not Storage.seed(seedRows()) then error('seed do catálogo falhou') end
        lib.print.info('catálogo inicial gravado a partir de data/seed.lua')
    end

    local rows = Storage.loadCatalog()
    local settings, levels = {}, nil
    for _, row in ipairs(rows.settings) do
        local value = decode(row.data, 'ajuste ' .. row.key)
        if value then
            if row.key == 'levels' then levels = value else settings[row.key] = value end
        end
    end
    local seed = require 'data.seed'
    for _, key in ipairs(SETTING_KEYS) do settings[key] = settings[key] or seed[key] end
    local normalized, code = Rules.normalizeSettings(settings, settings)
    if not normalized then error(('ajustes do banco inválidos (%s)'):format(code)) end
    Catalog.settings = normalized
    Catalog.levels = Rules.normalizeLevels(levels or {}) or Rules.normalizeLevels(seed.levels)

    Catalog.vehicles = {}
    for _, row in ipairs(rows.vehicles) do
        local vehicle = Rules.normalizeVehicle(decode(row.data, 'veículo ' .. row.model) or {})
        if vehicle then Catalog.vehicles[vehicle.model] = vehicle else lib.print.error(('veículo %s inválido no banco'):format(row.model)) end
    end

    Catalog.stops = {}
    for _, row in ipairs(rows.stops) do
        local stop = Rules.normalizeStop(decode(row.data, 'parada ' .. row.id) or {})
        if stop then
            stop.id = tonumber(row.id)
            Catalog.stops[stop.id] = stop
        else
            lib.print.error(('parada %s inválida no banco'):format(row.id))
        end
    end

    Catalog.routes = {}
    for _, row in ipairs(rows.routes) do
        local route, routeCode = Rules.normalizeRoute(decode(row.data, 'linha ' .. row.id) or {}, known())
        if route then
            route.id = row.id
            Catalog.routes[route.id] = route
        else
            lib.print.error(('linha %s inválida no banco (%s)'):format(row.id, tostring(routeCode)))
        end
    end

    Catalog.traces = {}
    for _, row in ipairs(Storage.loadTraces()) do
        local points = decode(row.points, 'traçado ' .. row.route_id)
        if points then
            Catalog.traces[row.route_id] = {
                signature = row.signature, roadMeters = tonumber(row.road_meters) or 0, straightMeters = tonumber(row.straight_meters) or 0,
                failedLegs = tonumber(row.failed_legs) or 0, points = points, tracedBy = row.traced_by,
            }
        end
    end

    Catalog.version = Catalog.version + 1
    ready = true
end

---Assinatura do que o traçado depende: a Central e o encosto de cada parada, na ordem.
---Mudou uma parada da linha, o traçado salvo fica desatualizado.
---@return string
function Catalog.routeSignature(route)
    local depot = Catalog.settings.depot
    local parts = { ('%.0f,%.0f;%.0f,%.0f'):format(depot.spawn.x, depot.spawn.y, depot.ped.x, depot.ped.y) }
    for _, id in ipairs(route.stops) do
        local stop = Catalog.stops[id]
        parts[#parts + 1] = stop and ('%d:%.0f,%.0f'):format(id, stop.dock.x, stop.dock.y) or tostring(id)
    end
    local text = table.concat(parts, '|')
    -- Hash curto (djb2) para caber na coluna.
    local hash = 5381
    for index = 1, #text do hash = (hash * 33 + text:byte(index)) % 4294967296 end
    return ('%08x%04x'):format(hash, #text % 65536)
end

---Traçado salvo e ainda válido para a linha, ou nil.
---@return table?
function Catalog.traceFor(route)
    local trace = Catalog.traces[route.id]
    if not trace or trace.signature ~= Catalog.routeSignature(route) then return nil end
    return trace
end

---@return boolean ok
---@return string? code
function Catalog.saveTrace(routeId, samples, stats, tracedBy)
    local route = Catalog.routes[routeId]
    if not route then return false, 'unknown_route' end
    if type(samples) ~= 'table' or #samples < 2 or #samples > 20000 then return false, 'invalid_trace' end
    local points = {}
    for index, point in ipairs(samples) do
        local x, y = type(point) == 'table' and tonumber(point.x), type(point) == 'table' and tonumber(point.y)
        if not x or not y or x ~= x or y ~= y or math.abs(x) > 20000 or math.abs(y) > 20000 then return false, 'invalid_trace' end
        points[index] = { x = math.floor(x * 10 + 0.5) / 10, y = math.floor(y * 10 + 0.5) / 10 }
    end
    local road = 0.0
    for index = 2, #points do
        road = road + Rules.planar(points[index - 1], points[index])
    end
    local straight = Catalog.routeTiming(route)
    local entry = {
        routeId = routeId, signature = Catalog.routeSignature(route), roadMeters = math.floor(road), straightMeters = math.floor(straight),
        failedLegs = math.max(0, math.min(255, math.floor(tonumber(stats and stats.failedLegs) or 0))),
        points = json.encode(points), tracedBy = tracedBy,
    }
    if not Storage.saveTrace(entry) then return false, 'storage_failed' end
    Catalog.traces[routeId] = {
        signature = entry.signature, roadMeters = entry.roadMeters, straightMeters = entry.straightMeters,
        failedLegs = entry.failedLegs, points = points, tracedBy = tracedBy,
    }
    return true
end

-- Consultas ---------------------------------------------------------------------------

---@return integer level
---@return table entry
function Catalog.levelFor(xp)
    return Rules.levelFor(Catalog.levels, xp)
end

---Distância em linha reta e tempo esperado da linha.
---@return number meters
---@return number seconds
function Catalog.routeTiming(route)
    local distance = Rules.routeDistance(route, Catalog.stops, Catalog.settings.depot)
    return distance, Rules.expectedSeconds(distance, #route.stops, Catalog.settings.timing)
end

---A linha só roda se todas as paradas existem, estão ativas e há veículo ativo.
---@return boolean
function Catalog.routeUsable(route)
    if not route or not route.enabled then return false end
    for _, id in ipairs(route.stops) do
        local stop = Catalog.stops[id]
        if not stop or not stop.enabled then return false end
    end
    for _, model in ipairs(route.vehicles) do
        local vehicle = Catalog.vehicles[model]
        if vehicle and vehicle.enabled then return true end
    end
    return false
end

---Veículos da linha que o nível já liberou, na ordem da linha.
---@return table[]
function Catalog.vehiclesFor(route, level)
    local result = {}
    for _, model in ipairs(route.vehicles) do
        local vehicle = Catalog.vehicles[model]
        if vehicle and vehicle.enabled and level >= vehicle.minLevel then result[#result + 1] = vehicle end
    end
    return result
end

---Cópia da linha com as paradas resolvidas, guardada na sessão: editar o catálogo no meio
---de uma volta não muda a volta.
---@return table
function Catalog.snapshotRoute(route)
    local stops = {}
    for index, id in ipairs(route.stops) do
        local stop = Catalog.stops[id]
        stops[index] = { id = id, name = stop.name, dock = stop.dock, zone = stop.zone }
    end
    local distance, expected = Catalog.routeTiming(route)
    return {
        id = route.id, code = route.code, name = route.name, basePay = route.basePay, baseXp = route.baseXp,
        stops = stops, distance = distance, expected = expected,
    }
end

---O que todo cliente recebe: atendente, ajustes de parada e passageiro. Paradas e linhas
---vão só na sessão (ou para o editor).
---@return table
function Catalog.publicView()
    local settings = Catalog.settings
    return {
        version = Catalog.version,
        depot = settings.depot,
        stop = settings.stop,
        passenger = { spawnDistance = settings.passenger.spawnDistance, models = settings.passenger.models, exitDespawnMs = settings.passenger.exitDespawnMs },
        vehicleFailure = settings.vehicleFailure,
    }
end

---Tudo, para o editor.
---@return table
function Catalog.adminView()
    local stops, routes, vehicles = {}, {}, {}
    local usage = {}
    for id, route in pairs(Catalog.routes) do
        for _, stopId in ipairs(route.stops) do
            usage[stopId] = usage[stopId] or {}
            usage[stopId][#usage[stopId] + 1] = route.code
        end
        local distance, expected = Catalog.routeTiming(route)
        routes[#routes + 1] = {
            id = id, code = route.code, name = route.name, minLevel = route.minLevel, basePay = route.basePay, baseXp = route.baseXp,
            stops = route.stops, vehicles = route.vehicles, access = route.access, enabled = route.enabled,
            distance = math.floor(distance), expected = math.floor(expected), usable = Catalog.routeUsable(route),
            road = Catalog.traces[id] and {
                meters = Catalog.traces[id].roadMeters, failedLegs = Catalog.traces[id].failedLegs,
                current = Catalog.traceFor(route) ~= nil,
            } or nil,
        }
    end
    for id, stop in pairs(Catalog.stops) do
        stops[#stops + 1] = { id = id, name = stop.name, dock = stop.dock, zone = stop.zone, enabled = stop.enabled, usedBy = usage[id] or {} }
    end
    for _, vehicle in pairs(Catalog.vehicles) do vehicles[#vehicles + 1] = vehicle end
    table.sort(stops, function(a, b) return a.id < b.id end)
    table.sort(routes, function(a, b)
        if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
        return a.code < b.code
    end)
    table.sort(vehicles, function(a, b)
        if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
        return a.model < b.model
    end)
    return { stops = stops, routes = routes, vehicles = vehicles, levels = Catalog.levels, settings = Catalog.settings }
end

---Níveis com o que cada um libera, para a tela de progressão.
---@return table[]
function Catalog.progression()
    local unlocks = Rules.unlocksByLevel(Catalog.routes, Catalog.vehicles)
    local result = {}
    for index, level in ipairs(Catalog.levels) do
        result[index] = { level = level.level, xp = level.xp, title = level.title, unlocks = unlocks[level.level] or {} }
    end
    return result
end

-- Escrita (editor) --------------------------------------------------------------------

local function changed()
    Catalog.version = Catalog.version + 1
    TriggerClientEvent('noir_busjob:client:catalog', -1, Catalog.publicView())
end

---@return integer? id
---@return string? code
function Catalog.saveStop(id, input)
    if id ~= nil and not Catalog.stops[id] then return nil, 'unknown_stop' end
    local stop, code = Rules.normalizeStop(input)
    if not stop then return nil, code end
    local savedId = Storage.saveStop(id, json.encode(stop))
    if not savedId then return nil, 'storage_failed' end
    stop.id = savedId
    Catalog.stops[savedId] = stop
    changed()
    return savedId
end

---@return boolean ok
---@return string? code
---@return string[]? usedBy
function Catalog.deleteStop(id)
    if not Catalog.stops[id] then return false, 'unknown_stop' end
    local usedBy = {}
    for _, route in pairs(Catalog.routes) do
        for _, stopId in ipairs(route.stops) do
            if stopId == id then usedBy[#usedBy + 1] = route.code break end
        end
    end
    if #usedBy > 0 then return false, 'stop_in_use', usedBy end
    if not Storage.deleteStop(id) then return false, 'storage_failed' end
    Catalog.stops[id] = nil
    changed()
    return true
end

---@param id string? nil = linha nova (a chave sai do código)
---@return string? id
---@return string? code
function Catalog.saveRoute(id, input)
    local route, code = Rules.normalizeRoute(input, known())
    if not route then return nil, code end
    local routeId = id
    if routeId == nil then
        routeId = Rules.routeId(route.code)
        if not routeId then return nil, 'invalid_code' end
        if Catalog.routes[routeId] then return nil, 'route_exists' end
    elseif not Catalog.routes[routeId] then
        return nil, 'unknown_route'
    end
    for otherId, other in pairs(Catalog.routes) do
        if otherId ~= routeId and other.code == route.code then return nil, 'code_in_use' end
    end
    if not Storage.saveRoute(routeId, json.encode(route)) then return nil, 'storage_failed' end
    route.id = routeId
    Catalog.routes[routeId] = route
    changed()
    return routeId
end

---@return boolean ok
---@return string? code
function Catalog.deleteRoute(id)
    if not Catalog.routes[id] then return false, 'unknown_route' end
    if not Storage.deleteRoute(id) then return false, 'storage_failed' end
    Catalog.routes[id] = nil
    changed()
    return true
end

---@param isNew boolean
---@return string? model
---@return string? code
function Catalog.saveVehicle(isNew, input)
    local vehicle, code = Rules.normalizeVehicle(input)
    if not vehicle then return nil, code end
    if isNew and Catalog.vehicles[vehicle.model] then return nil, 'vehicle_exists' end
    if not isNew and not Catalog.vehicles[vehicle.model] then return nil, 'unknown_vehicle' end
    if not Storage.saveVehicle(vehicle.model, json.encode(vehicle)) then return nil, 'storage_failed' end
    Catalog.vehicles[vehicle.model] = vehicle
    changed()
    return vehicle.model
end

---@return boolean ok
---@return string? code
---@return string[]? usedBy
function Catalog.deleteVehicle(model)
    if not Catalog.vehicles[model] then return false, 'unknown_vehicle' end
    local usedBy = {}
    for _, route in pairs(Catalog.routes) do
        for _, name in ipairs(route.vehicles) do
            if name == model then usedBy[#usedBy + 1] = route.code break end
        end
    end
    if #usedBy > 0 then return false, 'vehicle_in_use', usedBy end
    if not Storage.deleteVehicle(model) then return false, 'storage_failed' end
    Catalog.vehicles[model] = nil
    changed()
    return true
end

---@return boolean ok
---@return string? code
function Catalog.saveLevels(input)
    local levels, code = Rules.normalizeLevels(input)
    if not levels then return false, code end
    if not Storage.saveSetting('levels', json.encode(levels)) then return false, 'storage_failed' end
    Catalog.levels = levels
    changed()
    return true
end

---@return boolean ok
---@return string? code
function Catalog.saveSettings(input)
    local settings, code = Rules.normalizeSettings(input, Catalog.settings)
    if not settings then return false, code end
    for _, key in ipairs(SETTING_KEYS) do
        if not Storage.saveSetting(key, json.encode(settings[key])) then return false, 'storage_failed' end
    end
    Catalog.settings = settings
    changed()
    return true
end

return Catalog
