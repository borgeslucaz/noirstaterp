-- Gera dev/mock.json a partir do data/seed.lua, pelas mesmas regras do servidor, para o
-- preview no navegador mostrar o catálogo real.
--
--     cd resources/[noir]/noir_busjob && lua5.4 dev/mock.lua > dev/mock.json

local Rules = dofile('shared/rules.lua')
local seed = dofile('data/seed.lua')

local function encode(value)
    local kind = type(value)
    if kind == 'nil' then return 'null' end
    if kind == 'boolean' then return tostring(value) end
    if kind == 'number' then
        if value ~= value then return 'null' end
        if math.type(value) == 'integer' then return tostring(value) end
        return string.format('%.4f', value):gsub('0+$', ''):gsub('%.$', '')
    end
    if kind == 'string' then
        return '"' .. value:gsub('[%c"\\]', function(c) return string.format('\\u%04x', c:byte()) end) .. '"'
    end
    local isArray = #value > 0 or next(value) == nil
    local parts = {}
    if isArray and next(value) ~= nil then
        for _, item in ipairs(value) do parts[#parts + 1] = encode(item) end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    if next(value) == nil then return '{}' end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = encode(tostring(key)) .. ':' .. encode(value[key]) end
    return '{' .. table.concat(parts, ',') .. '}'
end

local settings = assert(Rules.normalizeSettings(seed, seed))
local levels = assert(Rules.normalizeLevels(seed.levels))
local stops, vehicles, routes = {}, {}, {}
for _, entry in ipairs(seed.stops) do
    local stop = assert(Rules.normalizeStop(entry))
    stop.id = entry.id
    stops[entry.id] = stop
end
-- Uma parada sem área, para o preview ter os dois estados.
stops[5].zone = nil
for _, entry in ipairs(seed.vehicles) do
    local vehicle = assert(Rules.normalizeVehicle(entry))
    vehicles[vehicle.model] = vehicle
end
for _, entry in ipairs(seed.routes) do
    local route = assert(Rules.normalizeRoute(entry, { stops = stops, vehicles = vehicles }))
    route.id = entry.id
    routes[entry.id] = route
end

local usage = {}
local routeList = {}
for id, route in pairs(routes) do
    for _, stopId in ipairs(route.stops) do
        usage[stopId] = usage[stopId] or {}
        table.insert(usage[stopId], route.code)
    end
    local distance = Rules.routeDistance(route, stops, settings.depot)
    routeList[#routeList + 1] = {
        id = id, code = route.code, name = route.name, minLevel = route.minLevel, basePay = route.basePay, baseXp = route.baseXp,
        stops = route.stops, vehicles = route.vehicles, access = { groups = {} }, enabled = true,
        distance = math.floor(distance), expected = math.floor(Rules.expectedSeconds(distance, #route.stops, settings.timing)), usable = true,
    }
end
table.sort(routeList, function(a, b)
    if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
    return a.code < b.code
end)
local stopList = {}
for id, stop in pairs(stops) do
    table.sort(usage[id] or {})
    stopList[#stopList + 1] = { id = id, name = stop.name, dock = stop.dock, zone = stop.zone, enabled = true, usedBy = usage[id] or {} }
end
table.sort(stopList, function(a, b) return a.id < b.id end)
local vehicleList = {}
for _, vehicle in pairs(vehicles) do vehicleList[#vehicleList + 1] = vehicle end
table.sort(vehicleList, function(a, b)
    if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
    return a.model < b.model
end)

-- Tela do jogador no nível 4.
local playerLevel = 4
local unlocks = Rules.unlocksByLevel(routes, vehicles)
local progression = {}
for index, level in ipairs(levels) do
    progression[index] = { level = level.level, xp = level.xp, title = level.title, unlocks = unlocks[level.level] or {} }
end
local menuRoutes = {}
for _, route in ipairs(routeList) do
    local names = {}
    for index, id in ipairs(route.stops) do names[index] = stops[id].name end
    local options, unlocked = {}, false
    for _, model in ipairs(route.vehicles) do
        local vehicle = vehicles[model]
        options[#options + 1] = { model = model, label = vehicle.label, capacity = vehicle.capacity, minLevel = vehicle.minLevel, unlocked = playerLevel >= vehicle.minLevel }
        if playerLevel >= vehicle.minLevel then unlocked = true end
    end
    menuRoutes[#menuRoutes + 1] = {
        id = route.id, code = route.code, name = route.name, minimumLevel = route.minLevel, vehicle = options[1].label, vehicles = options,
        stopCount = #route.stops, stops = names, baseXp = route.baseXp, restricted = false, allowed = true,
        available = playerLevel >= route.minLevel and unlocked,
    }
end

io.write(encode({
    catalog = { stops = stopList, routes = routeList, vehicles = vehicleList, levels = levels, settings = settings },
    menu = {
        profile = { displayName = 'Lucas Borges', level = playerLevel, title = levels[playerLevel].title, xp = 6200, nextXp = levels[playerLevel + 1].xp, routes = 23, rank = 4 },
        routes = menuRoutes,
        progression = progression,
        leaderboard = {
            { rank = 1, name = 'Ana Ribeiro', level = 7, xp = 24100, routes = 88, averageScore = 91.2 },
            { rank = 2, name = 'Caio Menezes', level = 6, xp = 17800, routes = 61, averageScore = 88.4 },
            { rank = 3, name = 'Rafa Duarte', level = 5, xp = 11020, routes = 40, averageScore = 86.9 },
            { rank = 4, name = 'Lucas Borges', level = 4, xp = 6200, routes = 23, averageScore = 84.1 },
        },
    },
}))
