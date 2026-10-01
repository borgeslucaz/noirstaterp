-- Funções puras: condições, template, esquema/validação, escolha de ponto de perseguição.
local T = dofile('tests/testlib.lua')
lib = { print = { info = function() end, warn = function() end, error = function() end } }
require = T.require()

local Conditions = require 'shared.utils.conditions'
local Template = require 'shared.utils.template'
local Definition = require 'shared.types.definition'
local SpawnPoints = require 'shared.utils.spawnpoints'

-- Condições -------------------------------------------------------------------------------
local vars = { alarm_active = true, cargo_loaded = 3, name = 'C-17', zero = 0 }
local resolve = function(name) return vars[name] end
local function rule(var, op, value) return { rules = { { var = var, op = op, value = value } } } end

T.truthy(Conditions.evaluate(nil, resolve), 'sem condição é verdadeiro')
T.truthy(Conditions.evaluate(rule('alarm_active', 'eq', 'true'), resolve), 'booleano vindo como texto')
T.truthy(Conditions.evaluate(rule('cargo_loaded', 'gte', '2'), resolve), 'número vindo como texto')
T.falsy(Conditions.evaluate(rule('cargo_loaded', 'gt', '3'), resolve), 'maior estrito')
T.truthy(Conditions.evaluate(rule('missing', 'lt', '1'), resolve), 'variável ausente conta como 0')
T.truthy(Conditions.evaluate(rule('zero', 'false'), resolve), '0 é falso')
T.truthy(Conditions.evaluate(rule('name', 'neq', 'B-04'), resolve), 'texto diferente')
T.falsy(Conditions.evaluate({ mode = 'all', rules = {
    { var = 'alarm_active', op = 'true' }, { var = 'cargo_loaded', op = 'gte', value = 4 },
} }, resolve), 'todas as regras')
T.truthy(Conditions.evaluate({ mode = 'any', rules = {
    { var = 'alarm_active', op = 'false' }, { var = 'cargo_loaded', op = 'gte', value = 3 },
} }, resolve), 'qualquer regra')
T.falsy(Conditions.evaluate(rule('x', 'drop table', 1), resolve), 'operador desconhecido é falso')

-- Template --------------------------------------------------------------------------------
T.equal(Template.render('Lote {{name}} — {{ cargo_loaded }}/4', resolve), 'Lote C-17 — 3/4', 'template')
T.equal(Template.render('{{alarm_active}} {{nada}}', resolve), 'sim ', 'booleano e ausente')
T.equal(Template.render('{{os.exit()}}', resolve), '{{os.exit()}}', 'nada é executado')

-- Definição -------------------------------------------------------------------------------
local def, errors = Definition.normalize({
    id = 'teste_x', name = 'Teste', minPlayers = '3', maxPlayers = 2,
    zones = { { id = 'z1', label = 'Z', coords = { x = 1, y = 2, z = 3 }, radius = 9999 } },
    steps = {
        { id = 's1', type = 'goto', label = 'Ir', coords = { x = 1, y = 2, z = 3 } },
        { id = 's2', type = 'interact', label = 'Hack', interaction = 'nao_existe' },
        { id = 's1', type = 'nope', label = 'X' },
    },
    triggers = { { id = 't1', label = 'T', on = 'zone_enter', match = 'z1', actions = {
        { type = 'if', condition = { rules = { { var = 'a', op = 'true' } } }, ['then'] = { { type = 'notify', text = 'oi' } } },
        { type = 'explode_server' },
    } } },
})
local byPath = {}
for _, err in ipairs(errors) do byPath[err.path] = err.message end
T.equal(def.minPlayers, 3, 'número vindo como texto')
T.truthy(byPath.maxPlayers, 'máximo menor que mínimo')
T.equal(def.zones[1].radius, 2000, 'raio limitado ao máximo do esquema')
T.truthy(byPath['steps[2].interaction'], 'referência inexistente')
T.truthy(byPath['steps[3]'], 'tipo de passo desconhecido')
T.truthy(byPath['triggers[1].actions[2]'], 'ação desconhecida')
T.equal(def.triggers[1].actions[1]['then'][1].type, 'notify', 'ação aninhada normalizada')
T.equal(def.steps[1].radius, 100, 'default do esquema aplicado')

-- Campo escondido guarda o valor sem acusar erro.
local hidden = Definition.normalize({ id = 'h1', name = 'H', cargo = { {
    id = 'c', label = 'C', model = 'prop_box_wood05a', mode = 'interact', item = 'bad item!',
    pieces = { { x = 0, y = 0, z = 0 } }, quantity = 1, requireVehicle = false,
} } })
T.equal(hidden.cargo[1].item, nil, 'item inválido escondido some')

-- A semente da Elysian é válida.
local Json = dofile('dev/json.lua')
local record = Json.decode(assert(io.open('missions/meth_elysian_precursors.json')):read('a'))
local _, elysianErrors = Definition.normalize(record.draft)
T.equal(#elysianErrors, 0, 'Elysian sem erros')

-- Ponto de perseguição -------------------------------------------------------------------
local forward = SpawnPoints.forward(nil, 0.0) -- norte
T.truthy(math.abs(forward.y - 1) < 1e-6, 'heading 0 aponta para o norte')
local candidates = {
    { x = 0, y = 300, z = 0 },   -- à frente
    { x = 0, y = -300, z = 0 },  -- atrás
    { x = 0, y = -50, z = 0 },   -- perto demais
    { x = 0, y = -900, z = 0 },  -- longe demais
}
local index = SpawnPoints.choose(candidates, {
    target = { x = 0, y = 0, z = 0 }, forward = forward, players = { { x = 0, y = 0, z = 0 } },
    minDistance = 120, maxDistance = 450,
})
T.equal(index, 2, 'escolhe o ponto atrás, na faixa')
T.equal(SpawnPoints.choose({ candidates[3], candidates[4] }, {
    target = { x = 0, y = 0, z = 0 }, forward = forward, players = { { x = 0, y = 0, z = 0 } },
    minDistance = 120, maxDistance = 450,
}), nil, 'nenhum ponto válido')

print('pure_spec: ok')
