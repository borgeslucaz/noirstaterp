-- Regras do catálogo: o que o editor aceita, as contas de tempo e pagamento e o sorteio de
-- ponto na área de espera.

local T = dofile('tests/testlib.lua')
local Rules = dofile('shared/rules.lua')
local seed = dofile('data/seed.lua')

-- Seed inteiro passa pelas mesmas regras do editor -------------------------------------

local settings, code = Rules.normalizeSettings(seed, seed)
T.truthy(settings, 'ajustes do seed: ' .. tostring(code))
local levels = Rules.normalizeLevels(seed.levels)
T.truthy(levels, 'níveis do seed')
T.equal(#levels, 10, 'dez níveis')

local stops, vehicles = {}, {}
for _, entry in ipairs(seed.stops) do
    local stop, stopCode = Rules.normalizeStop(entry)
    T.truthy(stop, ('parada %d: %s'):format(entry.id, tostring(stopCode)))
    stops[entry.id] = stop
end
for _, entry in ipairs(seed.vehicles) do
    local vehicle = Rules.normalizeVehicle(entry)
    T.truthy(vehicle, 'veículo ' .. entry.model)
    vehicles[vehicle.model] = vehicle
end
local routes = {}
for _, entry in ipairs(seed.routes) do
    local route, routeCode = Rules.normalizeRoute(entry, { stops = stops, vehicles = vehicles })
    T.truthy(route, ('linha %s: %s'):format(entry.id, tostring(routeCode)))
    route.id, route.enabled = entry.id, true
    routes[entry.id] = route
    -- Toda linha tem veículo liberado no próprio nível mínimo.
    local unlocked = false
    for _, model in ipairs(route.vehicles) do
        if vehicles[model].minLevel <= route.minLevel then unlocked = true end
    end
    T.truthy(unlocked, entry.id .. ' não tem veículo liberado no nível mínimo')
end

-- Validação -----------------------------------------------------------------------------

T.falsy(Rules.normalizeStop({ name = 'x', dock = { x = 0 / 0, y = 0, z = 0, w = 0 } }), 'NaN na posição')
T.falsy(Rules.normalizeStop({ name = '', dock = { x = 1, y = 1, z = 1, w = 0 } }), 'nome vazio')
T.falsy(Rules.normalizeStop({ name = 'x', dock = { x = 99999, y = 1, z = 1, w = 0 } }), 'fora do mundo')
local stop = Rules.normalizeStop({ name = '  <b>Praça</b>  ', dock = { x = 1, y = 2, z = 3, w = 370 } })
T.equal(stop.name, 'bPraça/b', 'marcação retirada do nome')
T.equal(stop.dock.w, 10.0, 'heading normalizado')
T.falsy(Rules.normalizeStop({ name = 'x', dock = { x = 1, y = 1, z = 1, w = 0 }, zone = { x = 1, y = 1, z = 1, length = 100, width = 2, height = 2, rotation = 0 } }), 'área grande demais')

local known = { stops = stops, vehicles = vehicles }
local base = { code = 'Z1', name = 'Teste', minLevel = 1, basePay = 10, baseXp = 10, stops = { 3, 5 }, vehicles = { 'bus' } }
T.truthy(Rules.normalizeRoute(base, known), 'linha mínima válida')
T.equal(select(2, Rules.normalizeRoute({ code = 'Z1', name = 'T', minLevel = 1, basePay = 1, baseXp = 1, stops = { 3, 999 }, vehicles = { 'bus' } }, known)), 'unknown_stop', 'parada desconhecida')
T.equal(select(2, Rules.normalizeRoute({ code = 'Z1', name = 'T', minLevel = 1, basePay = 1, baseXp = 1, stops = { 3, 3 }, vehicles = { 'bus' } }, known)), 'repeated_stop', 'parada repetida em seguida')
T.equal(select(2, Rules.normalizeRoute({ code = 'Z1', name = 'T', minLevel = 1, basePay = 1, baseXp = 1, stops = { 3, 5 }, vehicles = { 'adder' } }, known)), 'unknown_vehicle', 'veículo fora do catálogo')
T.equal(select(2, Rules.normalizeRoute({ code = 'Z1', name = 'T', minLevel = 1, basePay = -5, baseXp = 1, stops = { 3, 5 }, vehicles = { 'bus' } }, known)), 'invalid_reward', 'pagamento negativo')
local restricted = Rules.normalizeRoute({ code = 'Z1', name = 'T', minLevel = 1, basePay = 1, baseXp = 1, stops = { 3, 5 }, vehicles = { 'bus' }, access = { groups = { Police = 2 } } }, known)
T.equal(restricted.access.groups.police, 2, 'grupo em minúsculas com cargo')
T.equal(Rules.routeId('A07 Aeroporto!'), 'a07_aeroporto', 'chave da linha')

T.equal(select(2, Rules.normalizeLevels({ { xp = 10, title = 'A' } })), 'first_level_xp', 'nível 1 começa em 0')
T.equal(select(2, Rules.normalizeLevels({ { xp = 0, title = 'A' }, { xp = 0, title = 'B' } })), 'levels_order', 'XP crescente')
T.equal(select(2, Rules.normalizeVehicle({ model = 'bus;drop', label = 'x', capacity = 5, minLevel = 1 })), 'invalid_model', 'model com caractere estranho')

local changed = Rules.normalizeSettings({ passenger = { spawnDistance = 150, minDemand = 3, maxDemand = 1, exitDespawnMs = 1000, models = { 'a' .. 'b' } } }, settings)
T.falsy(changed, 'demanda mínima acima da máxima')

-- Contas --------------------------------------------------------------------------------

-- As três voltas reais do banco (payout antigo: $5 por passageiro).
local payout = { perPassenger = 5, passengerCap = 0.25, scoreCap = 0.20, xpPerPassenger = 2, xpCap = 0.15 }
local pay, xp = Rules.reward({ basePay = 220, baseXp = 150 }, payout, 80.13, 18)
T.equal(pay, 275, 'industry 18 passageiros: pagamento do banco')
T.equal(xp, 172, 'industry 18 passageiros: XP do banco')
pay, xp = Rules.reward({ basePay = 180, baseXp = 120 }, payout, 79.15, 7)
T.equal(pay, 215, 'small_metro: pagamento do banco')
T.equal(xp, 128, 'small_metro: XP do banco')
pay, xp = Rules.reward({ basePay = 220, baseXp = 150 }, payout, 79.00, 19)
T.equal(pay, 275, 'industry 19 passageiros: pagamento do banco')
T.equal(xp, 165, 'industry 19 passageiros: XP do banco')

local timing = settings.timing
T.equal(Rules.roadDistance(1000, 1400, timing), 1400, 'traçado em dia: distância da estrada')
T.equal(Rules.roadDistance(1000, nil, timing), 1000 * timing.roadFactor, 'sem traçado: linha reta × fator')
T.equal(Rules.roadDistance(1000, 0, timing), 1000 * timing.roadFactor, 'traçado vazio conta como sem traçado')
do
    local old = { secondsPerKm = 80, secondsPerStop = 35, tolerance = 1.15, minFraction = 0.35 }
    local migrated = assert(Rules.normalizeSettings({ timing = old }, settings))
    T.equal(migrated.timing.roadFactor, Rules.ROAD_FACTOR, 'ajuste gravado antes do fator ganha o padrão')
end
T.equal(Rules.punctuality(100, 100, timing), 100, 'no tempo')
T.equal(Rules.punctuality(115, 100, timing), 100, 'dentro da tolerância')
T.equal(Rules.punctuality(200, 100, timing), 60, 'no dobro')
T.equal(Rules.punctuality(999, 100, timing), 60, 'piso de 60')
local mid = Rules.punctuality(157.5, 100, timing)
T.truthy(mid > 60 and mid < 100, 'entre a tolerância e o dobro')

local distance = Rules.routeDistance(routes.small_metro, stops, settings.depot)
T.truthy(distance > 1500 and distance < 1700, 'M01 com ~1,6 km em linha reta: ' .. distance)

T.equal(Rules.levelFor(levels, 0), 1, 'nível 1 no zero')
T.equal(Rules.levelFor(levels, 1500), 2, 'nível 2 no limiar')
T.equal(Rules.levelFor(levels, 99999999), 10, 'teto no último nível')

local unlocks = Rules.unlocksByLevel(routes, vehicles)
T.truthy(unlocks[4] and #unlocks[4] >= 2, 'nível 4 libera a A07 e o airbus')

-- Área de espera ------------------------------------------------------------------------

local zone = Rules.zone({ x = 100, y = 200, z = 30, length = 6, width = 2, height = 3, rotation = 37 })
local seedValue = 7
local function random()
    seedValue = (seedValue * 1103515245 + 12345) % 2147483648
    return seedValue / 2147483648
end
for _ = 1, 500 do
    local point = Rules.randomPointInZone(zone, random)
    point.z = zone.z
    T.truthy(Rules.pointInZone(zone, point), 'ponto sorteado fora da área')
end
T.falsy(Rules.pointInZone(zone, { x = 100, y = 200, z = 40 }), 'acima da área')
-- Comprimento segue o heading: com rotação 0, a ponta está em +Y.
local straight = Rules.zone({ x = 0, y = 0, z = 0, length = 10, width = 2, height = 2, rotation = 0 })
T.truthy(Rules.pointInZone(straight, { x = 0, y = 4.9, z = 0 }), 'comprimento no eixo do heading')
T.falsy(Rules.pointInZone(straight, { x = 4.9, y = 0, z = 0 }), 'largura no eixo lateral')

print('rules_spec: ok')
