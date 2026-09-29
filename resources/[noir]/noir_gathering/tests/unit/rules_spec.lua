local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local Config = require 'config.shared'
local Rules = require 'shared.rules'

local known = { orange = true, knife = true, leaf = true }
local function isKnown(name) return known[name] == true end

local function validRoute()
    return {
        name = '  Laranjal  ',
        mode = 'shift',
        start = { x = 1.23456, y = 2, z = 3 },
        groups = { farmer = 1 },
        police = { enabled = true, chance = 10 },
        items = {
            orange = {
                min = 3, max = 1, time = 5000,
                tool = { name = 'knife', cost = 5 },
                stress = { min = 0, max = 2 },
                extras = { leaf = { min = 0, max = 2 } },
                points = { { x = 1, y = 1, z = 1 }, { 2, 2, 2 } },
            },
        },
    }
end

-- Normalização --------------------------------------------------------------------------

local route, err = Rules.normalizeRoute(validRoute(), Config.limits, isKnown)
T.truthy(route, 'rota válida aceita: ' .. tostring(err))
T.equal(route.name, 'Laranjal', 'nome aparado')
T.equal(route.start.x, 1.235, 'coordenada arredondada')
T.equal(route.items.orange.min, 1, 'min e max trocados quando invertidos')
T.equal(route.items.orange.max, 3, 'max depois da troca')
T.equal(route.items.orange.points[2].y, 2, 'ponto em forma de lista aceito')
T.equal(route.afk, false, 'afk só vale em rota sem início')

local input = validRoute()
input.items.orange.tool.name = 'bazooka'
T.equal(select(2, Rules.normalizeRoute(input, Config.limits, isKnown)), 'invalid_tool', 'ferramenta desconhecida recusada')

input = validRoute()
input.items.ghost = { min = 1, max = 1 }
T.equal(select(2, Rules.normalizeRoute(input, Config.limits, isKnown)), 'invalid_item', 'item desconhecido recusado')

input = validRoute()
input.items.orange.max = Config.limits.amount + 1
T.equal(select(2, Rules.normalizeRoute(input, Config.limits, isKnown)), 'invalid_amount', 'quantidade acima do teto recusada')

input = validRoute()
input.items.orange.time = 10
T.equal(select(2, Rules.normalizeRoute(input, Config.limits, isKnown)), 'invalid_time', 'tempo abaixo do piso recusado')

input = validRoute()
input.items.orange.points[1] = { x = 0 / 0, y = 0, z = 0 }
T.equal(select(2, Rules.normalizeRoute(input, Config.limits, isKnown)), 'invalid_points', 'NaN em ponto recusado')

input = validRoute()
input.groups = { ['drop table'] = 0 }
T.equal(select(2, Rules.normalizeRoute(input, Config.limits, isKnown)), 'invalid_groups', 'nome de grupo fora do formato recusado')

input = validRoute()
input.mode = 'teleport'
T.equal(select(2, Rules.normalizeRoute(input, Config.limits, isKnown)), 'invalid_mode', 'modo desconhecido recusado')

input = validRoute()
input.items.orange.stress = { min = 0, max = 0 }
T.equal(Rules.normalizeRoute(input, Config.limits, isKnown).items.orange.stress, nil, 'stress zerado some')

-- Jogável e visão pública ---------------------------------------------------------------

T.truthy(Rules.isPlayable(route), 'turno com início e pontos é jogável')
local noStart = Rules.normalizeRoute(validRoute(), Config.limits, isKnown)
noStart.start = nil
T.falsy(Rules.isPlayable(noStart), 'turno sem início não é publicado')
noStart.mode = 'free'
T.truthy(Rules.isPlayable(noStart), 'rota sem início não precisa de início')

local view = Rules.publicView(7, route)
T.equal(view.id, 7, 'id na visão pública')
T.equal(view.items.orange.min, nil, 'quantidade não vai para o client')
T.equal(view.items.orange.extras, nil, 'extras não vão para o client')
T.equal(view.items.orange.stress, nil, 'stress não vai para o client')
T.equal(view.police, nil, 'alerta não vai para o client')
T.equal(view.items.orange.tool, 'knife', 'só o nome da ferramenta vai, para o menu')

-- Próximo ponto -------------------------------------------------------------------------

local sequential = { points = { 1, 2, 3 }, random = false, unlimited = false }
T.equal(Rules.nextPoint(sequential, nil, 0), 1, 'sequência começa no 1')
T.equal(Rules.nextPoint(sequential, 1, 1), 2, 'sequência avança')
T.equal(Rules.nextPoint(sequential, 3, 3), nil, 'sequência acaba no último')

local endless = { points = { 1, 2, 3 }, random = false, unlimited = true }
T.equal(Rules.nextPoint(endless, 3, 3), 1, 'sem fim volta ao primeiro')

local random = { points = { 1, 2, 3 }, random = true, unlimited = true }
for last = 1, 3 do
    for draw = 1, 2 do
        local picked = Rules.nextPoint(random, last, 1, function() return draw end)
        T.truthy(picked ~= last, 'sorteio não repete o ponto recém-coletado')
    end
end
T.equal(Rules.nextPoint({ points = { 1 }, random = true, unlimited = true }, 1, 5), 1, 'um ponto só repete')

local randomFinite = { points = { 1, 2 }, random = true, unlimited = false }
T.equal(Rules.nextPoint(randomFinite, 1, 2), nil, 'sorteio sem fim para depois de N coletas')

-- Chance --------------------------------------------------------------------------------

T.equal(Rules.alertChance(route, { police = { chance = 0 } }), 0, 'chance do item zero vence a da rota')
T.equal(Rules.alertChance(route, {}), 10, 'sem chance própria usa a da rota')
T.equal(Rules.alertChance({ police = { enabled = false, chance = 50 } }, {}), 0, 'rota desligada não alerta')
T.falsy(Rules.chance(0), 'chance zero nunca')
T.truthy(Rules.chance(100), 'chance cem sempre')
T.truthy(Rules.chance(30, function() return 0.29 end), 'rolagem abaixo da chance dispara')
T.falsy(Rules.chance(30, function() return 0.30 end), 'rolagem igual à chance não dispara')

-- Rota de carga -------------------------------------------------------------------------

local catalog = {
    item = isKnown,
    category = function(id) return id == 'drug' or id == 'weapons' end,
    unlock = function(key) return key == 'contact_meth' end,
    prop = function(model) return model == 'prop_boxpile_07d' end,
    reputationCap = 100,
}

local function haulRoute()
    return {
        name = 'Porto',
        mode = 'haul',
        start = { x = 0, y = 0, z = 0, w = 370 },
        npc = { model = 'S_M_M_DockWork_01' },
        vehicle = 'burrito3',
        vehicleSpawn = { x = 5, y = 0, z = 0, w = 90 },
        requirement = { unlock = 'contact_meth', category = 'drug', level = 2 },
        police = { enabled = true, chance = 40, radius = 200 },
        haul = {
            stack = { x = 10, y = 0, z = 0, w = 0 },
            prop = 'prop_boxpile_07d',
            count = 5,
            dropoff = { x = 500, y = 0, z = 0, w = 0 },
            rewards = { orange = { min = 2, max = 4 } },
            category = 'drug',
            reputation = 25,
            cooldown = 10,
            scout = { enabled = true, chance = 50, radius = 300 },
        },
    }
end

local haulOk, haulErr = Rules.normalizeRoute(haulRoute(), Config.limits, catalog)
T.truthy(haulOk, 'rota de carga válida aceita: ' .. tostring(haulErr))
T.equal(haulOk.start.w, 10, 'direção normalizada em 0..360')
T.equal(haulOk.npc.model, 's_m_m_dockwork_01', 'model do NPC em minúsculas')
T.equal(haulOk.vehicleSpawn.w, 90, 'vaga do veículo guarda a direção')
T.equal(haulOk.requirement.level, 2, 'requisito de nível guardado')
T.equal(haulOk.police.radius, 200, 'raio do alerta guardado')
T.truthy(Rules.isPlayable(haulOk), 'carga com início, veículo, pilha e destino é jogável')

local function haulError(mutate)
    local input = haulRoute()
    mutate(input)
    return select(2, Rules.normalizeRoute(input, Config.limits, catalog))
end

T.equal(haulError(function(r) r.haul.count = 0 end), 'invalid_count', 'carga sem caixa recusada')
T.equal(haulError(function(r) r.haul.count = Config.limits.haul.boxes + 1 end), 'invalid_count', 'caixas acima do teto recusadas')
T.equal(haulError(function(r) r.haul.prop = 'prop_que_nao_existe' end), 'invalid_stack', 'prop fora da lista recusada')
T.equal(haulError(function(r) r.haul.reputation = 101 end), 'invalid_reputation', 'reputação acima do teto do core recusada')
T.equal(haulError(function(r) r.haul.category = nil end), 'invalid_reputation', 'reputação sem categoria recusada')
T.equal(haulError(function(r) r.haul.category = 'boosting' end), 'invalid_category', 'categoria que o core não tem recusada')
T.equal(haulError(function(r) r.haul.reputation = 0; r.haul.category = nil end), 'invalid_scout',
    'olheiro sem categoria não sabe quem avisar')
T.equal(haulError(function(r) r.haul.rewards = { ghost = { min = 1, max = 1 } } end), 'invalid_rewards', 'item de recompensa desconhecido recusado')
T.equal(haulError(function(r) r.requirement = { unlock = 'contact_coke' } end), 'invalid_requirement', 'desbloqueio desconhecido recusado')
T.equal(haulError(function(r) r.requirement = { category = 'drug' } end), 'invalid_requirement', 'nível sem número recusado')
T.equal(haulError(function(r) r.police.radius = 5 end), 'invalid_police', 'área do alerta pequena demais recusada')
T.equal(haulError(function(r) r.npc = { model = 'bad model' } end), 'invalid_npc', 'model de NPC inválido recusado')

local unfinished = haulRoute()
unfinished.haul.dropoff = nil
T.falsy(Rules.isPlayable(assert(Rules.normalizeRoute(unfinished, Config.limits, catalog))), 'carga sem destino salva, mas não aparece')
local noVehicle = haulRoute()
noVehicle.vehicle, noVehicle.vehicleSpawn = nil, nil
T.falsy(Rules.isPlayable(assert(Rules.normalizeRoute(noVehicle, Config.limits, catalog))), 'carga sem veículo não aparece')

local shiftWithSpawn = validRoute()
shiftWithSpawn.vehicle, shiftWithSpawn.vehicleSpawn = 'burrito3', { x = 1, y = 1, z = 1 }
T.falsy(assert(Rules.normalizeRoute(shiftWithSpawn, Config.limits, isKnown)).vehicleSpawn,
    'só a carga entrega veículo')

local view = Rules.publicView(9, haulOk)
T.equal(view.haul.count, 5, 'o client sabe quantas caixas')
T.truthy(view.haul.stack and view.haul.dropoff, 'e onde ficam pilha e destino')
T.falsy(view.haul.rewards, 'recompensa não vai para o client')
T.falsy(view.haul.reputation or view.haul.scout, 'nem reputação nem olheiro')
T.falsy(view.requirement or view.police or view.vehicleSpawn, 'nem requisito, alerta ou vaga')

local center = { x = 100, y = 100, z = 5 }
for _, draw in ipairs({ 0, 0.25, 0.5, 0.999 }) do
    local blurred = Rules.blurCoords(center, 200, function() return draw end)
    local distance = math.sqrt((blurred.x - 100) ^ 2 + (blurred.y - 100) ^ 2)
    T.truthy(distance <= 120.001, 'centro do alerta fica dentro de 60% do raio')
end

print('rules_spec: ok')
