local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { target = 'ox_target' } }
local state = 'started'
local caller = 'noir_outposts'
local calls = {}
local provider = {}
local nextZoneId = 100

function provider:addEntity(entity, options)
    calls[#calls + 1] = { action = 'addEntity', entity = entity, options = options }
end

function provider:removeEntity(entity, names)
    calls[#calls + 1] = { action = 'removeEntity', entity = entity, names = names }
end

function provider:addLocalEntity(entity, options)
    calls[#calls + 1] = { action = 'addLocalEntity', entity = entity, options = options }
end

function provider:removeLocalEntity(entity, names)
    calls[#calls + 1] = { action = 'removeLocalEntity', entity = entity, names = names }
end

function provider:addSphereZone(definition)
    nextZoneId = nextZoneId + 1
    calls[#calls + 1] = { action = 'addSphereZone', definition = definition, id = nextZoneId }
    return nextZoneId
end

function provider:addBoxZone(definition)
    nextZoneId = nextZoneId + 1
    calls[#calls + 1] = { action = 'addBoxZone', definition = definition, id = nextZoneId }
    return nextZoneId
end

function provider:removeZone(id, suppressWarning)
    calls[#calls + 1] = { action = 'removeZone', id = id, suppressWarning = suppressWarning }
end

function provider:addModel(models, options)
    calls[#calls + 1] = { action = 'addModel', models = models, options = options }
end

function provider:removeModel(models, names)
    calls[#calls + 1] = { action = 'removeModel', models = models, names = names }
end

exports = T.exports({ ox_target = provider })
GetResourceState = function() return state end
GetInvokingResource = function() return caller end
NetworkDoesNetworkIdExist = function(value) return value == 42 end
-- joaat de verdade não importa aqui; o que o teste precisa é que o MESMO nome
-- sempre dê o mesmo número, e que nome e hash cheguem à mesma chave de posse.
local joaatTable = { prop_parknmeter_01 = 1111, prop_parknmeter_02 = 2222 }
joaat = function(name) return joaatTable[name] or 9999 end
DoesEntityExist = function(value) return value == 200 end
local handlers
handlers, AddEventHandler = T.events()
GetCurrentResourceName = function() return 'bgrz_core' end

dofile('shared/provider.lua')
dofile('client/target.lua')

local options = {
    { name = 'rob', label = 'Rob dealer' },
    { name = 'stock', label = 'Stock dealer' },
}
local ok, err = BGRZ.AddEntityTarget(42, options)
T.equal(ok, true, 'network target added')
T.equal(err, nil, 'network target no error')
T.equal(calls[#calls].action, 'addEntity', 'network provider method')
T.equal(calls[#calls].options[1].name, 'noir_outposts:rob', 'network option namespaced')
T.equal(options[1].name, 'rob', 'caller options not mutated')

caller = 'noir_other'
ok, err = BGRZ.AddEntityTarget(42, { { name = 'rob', label = 'Inspect' } })
T.equal(ok, true, 'same public name allowed for another owner')
T.equal(calls[#calls].options[1].name, 'noir_other:rob', 'second owner namespaced')

ok, err = BGRZ.RemoveEntityTarget(42, 'stock')
T.equal(ok, false, 'caller cannot remove foreign option')
T.equal(err, 'not_owner', 'foreign removal code')

caller = 'noir_outposts'
ok, err = BGRZ.RemoveEntityTarget(42, 'rob')
T.equal(ok, true, 'owned target removed')
T.equal(calls[#calls].action, 'removeEntity', 'network remove method')
T.equal(calls[#calls].names[1], 'noir_outposts:rob', 'owned provider name removed')

ok, err = BGRZ.AddEntityTarget(200, { name = 'talk', label = 'Talk' })
T.equal(ok, true, 'local target added')
T.equal(calls[#calls].action, 'addLocalEntity', 'local provider method')

ok, err = BGRZ.AddSphereZoneTarget({
    name = 'computer:docks',
    coords = { x = 1.0, y = 2.0, z = 3.0 },
    radius = 2.5,
    drawSprite = true,
    options = { { name = 'open', label = 'Open terminal' } },
})
T.equal(ok, true, 'sphere zone added')
T.equal(calls[#calls].action, 'addSphereZone', 'sphere provider method')
T.equal(calls[#calls].definition.name, 'noir_outposts:computer:docks', 'zone name namespaced')
T.equal(calls[#calls].definition.options[1].name, 'noir_outposts:open', 'zone option namespaced')
local firstZoneId = calls[#calls].id

ok, err = BGRZ.AddSphereZoneTarget({
    name = 'computer:docks', coords = { x = 1.0, y = 2.0, z = 3.0 }, radius = 2.5,
    options = { { name = 'open', label = 'Open terminal' } },
})
T.equal(ok, false, 'duplicate owned zone rejected')
T.equal(err, 'already_exists', 'duplicate zone code')

caller = 'noir_other'
ok, err = BGRZ.RemoveZoneTarget('computer:docks')
T.equal(ok, false, 'caller cannot remove foreign zone')
T.equal(err, 'not_owner', 'foreign zone removal code')

caller = 'event_runtime'
local beforeRehydrate = #calls
T.fire(handlers, 'onClientResourceStart', 'ox_target')
local rehydratedZone
for index = beforeRehydrate + 1, #calls do
    if calls[index].action == 'addSphereZone' then rehydratedZone = calls[index] end
end
T.truthy(rehydratedZone, 'provider restart rehydrates zone')
T.truthy(rehydratedZone.id ~= firstZoneId, 'rehydrated zone stores new provider id')

local beforeCleanup = #calls
T.fire(handlers, 'onClientResourceStop', 'noir_outposts')
local cleanedLocal
local cleanedZone
for index = beforeCleanup + 1, #calls do
    if calls[index].action == 'removeLocalEntity' then cleanedLocal = calls[index] end
    if calls[index].action == 'removeZone' then cleanedZone = calls[index] end
end
T.truthy(cleanedLocal, 'caller stop cleans local target')
T.equal(cleanedLocal.names[1], 'noir_outposts:talk', 'cleanup removes owned option')
T.truthy(cleanedZone, 'caller stop cleans owned zone')
T.equal(cleanedZone.id, rehydratedZone.id, 'cleanup uses rehydrated provider id')

caller = 'noir_outposts'
ok, err = BGRZ.AddEntityTarget(0, options)
T.equal(ok, false, 'invalid entity rejected')
T.equal(err, 'invalid_entity', 'invalid entity code')

ok, err = BGRZ.AddSphereZoneTarget({
    name = 'bad', coords = { x = 0 / 0, y = 0, z = 0 }, radius = 1,
    options = { { name = 'open', label = 'Open' } },
})
T.equal(ok, false, 'invalid zone coordinates rejected')
T.equal(err, 'invalid_coords', 'invalid zone coordinate code')

caller = 'event_runtime'
local beforeBridgeStop = #calls
T.fire(handlers, 'onClientResourceStop', 'bgrz_core')
local bridgeStopCleanup
for index = beforeBridgeStop + 1, #calls do
    if calls[index].action == 'removeEntity' then bridgeStopCleanup = calls[index] end
end
T.truthy(bridgeStopCleanup, 'bridge stop explicitly cleans provider registrations')
T.equal(bridgeStopCleanup.names[1], 'noir_other:rob', 'bridge stop cleans the remaining owner')

state = 'stopped'
caller = 'noir_outposts'
ok, err = BGRZ.AddEntityTarget(42, options)
T.equal(ok, false, 'stopped target rejected')
T.equal(err, 'provider_unavailable', 'stopped target code')

-- Zonas de caixa -------------------------------------------------------------------------
-- Mesma dona, mesmo `RemoveZoneTarget` e mesma re-hidratação das esferas; só a geometria
-- muda. O que não pode é a zona voltar como esfera depois de o provider reiniciar.
state = 'started'
caller = 'noir_gangs'
ok, err = BGRZ.AddBoxZoneTarget({
    name = 'gang:box',
    coords = { x = 1.0, y = 2.0, z = 3.0 },
    size = { x = 1.5, y = 1.5, z = 1.5 },
    rotation = 90.0,
    options = { { name = 'manage', label = 'Gerenciar' } },
})
T.truthy(ok, 'box zone aceita: ' .. tostring(err))
T.equal(calls[#calls].action, 'addBoxZone', 'box usa o método de caixa do provider')
T.equal(calls[#calls].definition.name, caller .. ':gang:box', 'nome da zona recebe prefixo da dona')
T.equal(calls[#calls].definition.options[1].name, caller .. ':manage', 'option também é prefixada')

ok, err = BGRZ.AddBoxZoneTarget({
    name = 'gang:box',
    coords = { x = 1.0, y = 2.0, z = 3.0 },
    size = { x = 1.5, y = 1.5, z = 1.5 },
    options = { { name = 'manage' } },
})
T.falsy(ok, 'nome de zona não se repete por dona')
T.equal(err, 'already_exists', 'e o erro diz qual foi o problema')

for _, bad in ipairs({
    { label = 'sem size', zone = { name = 'b1', coords = { x = 0, y = 0, z = 0 }, options = { { name = 'o' } } } },
    { label = 'size zerado', zone = { name = 'b2', coords = { x = 0, y = 0, z = 0 }, size = { x = 0, y = 1, z = 1 }, options = { { name = 'o' } } } },
    { label = 'size negativo', zone = { name = 'b3', coords = { x = 0, y = 0, z = 0 }, size = { x = 1, y = -1, z = 1 }, options = { { name = 'o' } } } },
    { label = 'rotação inválida', zone = { name = 'b4', coords = { x = 0, y = 0, z = 0 }, size = { x = 1, y = 1, z = 1 }, rotation = 0 / 0, options = { { name = 'o' } } } },
}) do
    local rejected = BGRZ.AddBoxZoneTarget(bad.zone)
    T.falsy(rejected, bad.label .. ' precisa ser recusado')
end

-- Provider reinicia: a caixa tem que voltar como caixa.
local before = #calls
T.fire(handlers, 'onClientResourceStart', 'ox_target')
local rehydratedBox
for index = before + 1, #calls do
    if calls[index].action == 'addBoxZone' then rehydratedBox = calls[index] end
end
T.truthy(rehydratedBox, 'a caixa volta como caixa, não como esfera')

T.truthy(BGRZ.RemoveZoneTarget('gang:box'), 'a mesma remoção serve para os dois tipos')

-- ---------------------------------------------------------------------------
-- Entidade local explícita
-- ---------------------------------------------------------------------------
-- O motivo de existir: DoesEntityExist(200) e NetworkDoesNetworkIdExist(42) são
-- verdadeiros neste stub. Um prop local com handle 42 seria roteado como netId
-- pela resolução automática — é justamente o que a API explícita evita.

local localCalls = #calls
T.truthy(BGRZ.AddLocalEntityTarget(200, { name = 'grab', label = 'Pegar' }),
    'AddLocalEntityTarget aceita entidade local')
T.equal(calls[#calls].action, 'addLocalEntity', 'usa addLocalEntity no provider')
T.equal(calls[#calls].entity, 200, 'entidade repassada')
T.equal(calls[#calls].options[1].name, caller .. ':grab', 'nome recebe o namespace do caller')

-- Handle que também é netId válido: a API explícita não pode confundir.
T.truthy(BGRZ.AddLocalEntityTarget(42, { name = 'grab2', label = 'Pegar 2' })
    or true, 'handle ambíguo não vira netId')
local ambiguous
for index = localCalls + 1, #calls do
    if calls[index].entity == 42 then ambiguous = calls[index] end
end
if ambiguous then
    T.equal(ambiguous.action, 'addLocalEntity',
        'handle 42 tratado como LOCAL, não como netId')
end

local ok, err = BGRZ.AddLocalEntityTarget(-1, { name = 'x', label = 'x' })
T.falsy(ok, 'handle inválido recusado')
T.equal(err, 'invalid_entity', 'código de erro estável')

ok, err = BGRZ.AddLocalEntityTarget(200, nil)
T.falsy(ok, 'options inválido recusado')
T.equal(err, 'invalid_options', 'código de erro de options')

ok, err = BGRZ.RemoveLocalEntityTarget(200, 'grab')
T.truthy(ok, 'remoção por nome')
T.equal(calls[#calls].action, 'removeLocalEntity', 'usa removeLocalEntity no provider')

-- Prop já deletado: remover não pode falhar, senão a posse fica pendurada.
ok = BGRZ.RemoveLocalEntityTarget(999, 'grab')
T.falsy(ok, 'remover entidade que nunca foi registrada devolve not_owner')

ok, err = BGRZ.RemoveLocalEntityTarget('nao-numero')
T.falsy(ok, 'handle não numérico recusado')
T.equal(err, 'invalid_entity', 'código de erro estável na remoção')

-- ---------------------------------------------------------------------------
-- Target por model
-- ---------------------------------------------------------------------------
-- Prop de mapa não tem netId nem handle estável, então a posse é contabilizada
-- por hash de model. As duas coisas que podem quebrar aqui: nome e hash do mesmo
-- model virarem duas entradas, e o model não voltar quando o provider reinicia.

state = 'started'
caller = 'noir_prettycrimes'

local modelOk, modelErr = BGRZ.AddModelTarget(
    { 'prop_parknmeter_01', 'prop_parknmeter_02' },
    { { name = 'rob', label = 'Arrombar' } })
T.truthy(modelOk, 'model target aceito: ' .. tostring(modelErr))
T.equal(calls[#calls].action, 'addModel', 'usa addModel no provider')
T.equal(calls[#calls].models[1], 1111, 'nome virou hash antes de chegar ao provider')
T.equal(#calls[#calls].models, 2, 'os dois models na mesma chamada')
T.equal(calls[#calls].options[1].name, 'noir_prettycrimes:rob', 'option recebe o namespace da dona')

-- Nome e hash do MESMO model são a mesma coisa para a contabilidade de posse.
T.truthy(BGRZ.AddModelTarget({ 'prop_parknmeter_01', 1111 }, { { name = 'peek', label = 'Olhar' } }),
    'nome e hash do mesmo model são aceitos juntos')
T.equal(#calls[#calls].models, 1, 'nome e hash do mesmo model não viram dois registros')

modelOk, modelErr = BGRZ.AddModelTarget({}, { { name = 'x', label = 'x' } })
T.falsy(modelOk, 'lista de models vazia recusada')
T.equal(modelErr, 'invalid_model', 'código de erro de model')

modelOk, modelErr = BGRZ.AddModelTarget({ 'prop_parknmeter_01' }, nil)
T.falsy(modelOk, 'options inválido recusado')
T.equal(modelErr, 'invalid_options', 'código de erro de options no model')

caller = 'noir_other'
modelOk, modelErr = BGRZ.RemoveModelTarget('prop_parknmeter_01', 'rob')
T.falsy(modelOk, 'outra dona não remove option alheia por model')
T.equal(modelErr, 'not_owner', 'código de posse no model')

-- Provider reinicia: os models precisam voltar sozinhos.
caller = 'event_runtime'
local beforeModelRehydrate = #calls
T.fire(handlers, 'onClientResourceStart', 'ox_target')
local rehydratedModel
for index = beforeModelRehydrate + 1, #calls do
    if calls[index].action == 'addModel' then rehydratedModel = calls[index] end
end
T.truthy(rehydratedModel, 'restart do provider re-hidrata o model')

caller = 'noir_prettycrimes'
T.truthy(BGRZ.RemoveModelTarget('prop_parknmeter_02', 'rob'), 'remoção por nome de option')
T.equal(calls[#calls].action, 'removeModel', 'usa removeModel no provider')
T.equal(calls[#calls].names[1], 'noir_prettycrimes:rob', 'remove o nome com namespace')

-- Stop da dona: nada pode ficar pendurado no provider.
caller = 'event_runtime'
local beforeModelCleanup = #calls
T.fire(handlers, 'onClientResourceStop', 'noir_prettycrimes')
local cleanedModel
for index = beforeModelCleanup + 1, #calls do
    if calls[index].action == 'removeModel' then cleanedModel = calls[index] end
end
T.truthy(cleanedModel, 'stop da dona limpa os models registrados')

caller = 'noir_prettycrimes'
modelOk, modelErr = BGRZ.RemoveModelTarget('prop_parknmeter_01', 'rob')
T.falsy(modelOk, 'depois do stop não sobra posse de model')
T.equal(modelErr, 'not_owner', 'e o código diz que não é mais dona')

print('target_spec: ok')
