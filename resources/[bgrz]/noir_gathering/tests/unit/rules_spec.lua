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

print('rules_spec: ok')
