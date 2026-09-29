-- Contas da planta: estágio, ciclo, colheita, zona proibida e coordenada do client.

local T = dofile('tests/testlib.lua')
local Rules = dofile('shared/rules.lua')

local stages = { { from = 0 }, { from = 40 }, { from = 70 } }
T.equal(Rules.stageFor(stages, 0), 1, 'recém-plantada')
T.equal(Rules.stageFor(stages, 39.9), 1, 'antes do segundo estágio')
T.equal(Rules.stageFor(stages, 40), 2, 'no limite do segundo')
T.equal(Rules.stageFor(stages, 100), 3, 'pronta')

local growth = { loseWater = 1.5, loseFertilizer = 1.5, loseHealth = 1.0, gain = 2.0 }

local plant = { growth = 0, health = 30, water = 30, fertilizer = 30 }
T.truthy(Rules.tick(plant, growth, 100), 'ciclo muda a planta')
T.equal(plant.growth, 2.0, 'cresce com tudo acima de zero')
T.equal(plant.water, 28.5, 'perde água')

local dry = { growth = 10, health = 30, water = 1, fertilizer = 30 }
Rules.tick(dry, growth, 100)
T.equal(dry.water, 0, 'água não fica negativa')
T.equal(dry.growth, 10, 'sem água não cresce')

local sick = { growth = 10, health = 0.5, water = 50, fertilizer = 50 }
Rules.tick(sick, growth, 100)
T.equal(sick.growth, 10, 'saúde zerada não cresce')

local almost = { growth = 99, health = 50, water = 50, fertilizer = 50 }
Rules.tick(almost, growth, 100)
T.equal(almost.growth, 100, 'crescimento para no ponto de colheita')
T.falsy(Rules.tick(almost, growth, 100), 'planta pronta para de mudar')
T.equal(almost.water, 48.5, 'planta pronta não perde mais água')

local range = { min = 2, max = 10 }
T.equal(Rules.reward(range, 0), 2, 'saúde zero dá o mínimo')
T.equal(Rules.reward(range, 100), 10, 'saúde cheia dá o máximo')
T.equal(Rules.reward(range, 50), 6, 'meio a meio')
T.equal(Rules.reward(range, 150), 10, 'saúde acima de 100 não passa do máximo')

local zones = { { coords = { x = 0, y = 0, z = 0 }, radius = 50 } }
T.truthy(Rules.inBlacklist({ x = 10, y = 0, z = 0 }, zones), 'dentro da zona')
T.falsy(Rules.inBlacklist({ x = 60, y = 0, z = 0 }, zones), 'fora da zona')

T.truthy(Rules.isPlacement({ x = 1, y = 2, z = 3, w = 90 }), 'coordenada válida')
T.falsy(Rules.isPlacement({ x = 1, y = 2, z = 3 }), 'sem heading')
T.falsy(Rules.isPlacement({ x = 0 / 0, y = 2, z = 3, w = 0 }), 'NaN')
T.falsy(Rules.isPlacement({ x = math.huge, y = 2, z = 3, w = 0 }), 'infinito')
T.falsy(Rules.isPlacement('1,2,3'), 'não é tabela')

print('rules_spec ok')
