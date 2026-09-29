-- Fluxo de turno e coleta no servidor, com ponte, rotas e mundo falsos.
--
-- Cada bloco é um jeito de tentar receber item sem ter coletado: pedir o fim sem ter
-- começado, terminar antes do tempo, coletar longe, repetir o fim, coletar o ponto
-- errado, usar rota de turno sem turno. O mri_Qfarm aceitava todos.

local T = dofile('tests/testlib.lua')
T.natives()

-- Mundo ---------------------------------------------------------------------------------

local now = 0
GetGameTimer = function() return now end

local peds = { [1] = 101, [2] = 102 }
local pedCoords = { [101] = vector3(0, 0, 0), [102] = vector3(0, 0, 0) }
local pedVehicle = {}
local vehicleModel, vehicleCoords = {}, {}

GetPlayerPed = function(source) return peds[source] or 0 end
DoesEntityExist = function(entity) return pedCoords[entity] ~= nil or vehicleModel[entity] ~= nil end
GetEntityCoords = function(entity) return pedCoords[entity] or vehicleCoords[entity] end
GetVehiclePedIsIn = function(ped) return pedVehicle[ped] or 0 end
GetEntityModel = function(entity) return vehicleModel[entity] end
GetAllVehicles = function()
    local list = {}
    for vehicle in pairs(vehicleModel) do list[#list + 1] = vehicle end
    return list
end

local clientEvents = {}
TriggerClientEvent = function(name, target, ...) clientEvents[#clientEvents + 1] = { name, target, ... } end
AddEventHandler = function() end
CreateThread = function() end
Wait = function() end
locale = function(key) return key end

local handlers = {}
lib.callback = { register = function(name, fn) handlers[name:gsub('^noir_gathering:server:', '')] = fn end }

-- Ponte e rotas falsas ------------------------------------------------------------------

local given, toolUses, dispatched, stress = {}, {}, 0, 0
local hasTool, canCarry, groupOk, requirementOk = true, true, true, true
local Integrations = {
    coreReady = function() return true end,
    isLoaded = function() return true end,
    hasGroupAccess = function() return groupOk end,
    meetsRequirement = function(_, requirement) return requirement == nil or requirementOk end,
    hasTool = function() return hasTool, hasTool and nil or 'not_enough_items' end,
    useTool = function(_, name, cost) toolUses[#toolUses + 1] = { name, cost }; return hasTool end,
    canCarry = function() return canCarry end,
    addItem = function(source, item, amount) given[#given + 1] = { source, item, amount }; return true end,
    addStress = function(_, amount) stress = stress + amount end,
    dispatch = function() dispatched = dispatched + 1; return true end,
    notify = function() end,
    itemLabel = function(name) return name end,
}

local routeTable = {}
local changeListener
local Routes = {
    get = function(id) return routeTable[id] end,
    onChange = function(listener) changeListener = listener end,
}

require = T.require({ ['server.integrations'] = Integrations, ['server.routes'] = Routes })
local Sessions = require 'server.sessions'
Sessions.register()

local function point(x) return { x = x, y = 0, z = 0 } end

routeTable[1] = {
    name = 'Laranjal', mode = 'shift', start = point(0), groups = {}, police = { enabled = true, chance = 100, radius = 150 },
    items = {
        orange = {
            min = 2, max = 2, time = 5000, random = false, unlimited = false,
            tool = { name = 'knife', cost = 5 }, stress = { min = 1, max = 1 },
            extras = {}, points = { point(10), point(20) },
        },
    },
}
routeTable[2] = {
    name = 'Mato', mode = 'free', afk = true, groups = { farmer = 0 }, police = { enabled = false, chance = 0, radius = 150 },
    items = { leaf = { min = 1, max = 1, time = 2000, random = false, unlimited = false, extras = {}, points = { point(50) } } },
}

local function move(source, x) pedCoords[peds[source]] = vector3(x, 0, 0) end
local function tick(ms) now = now + ms end
local function call(name, ...)
    tick(1000) -- fora do rate limit
    return handlers[name](...)
end

-- Turno ---------------------------------------------------------------------------------

move(1, 30)
T.equal(call('startShift', 1, 1, 'orange').error, 'too_far', 'turno exige estar no início')

move(1, 0)
local started = call('startShift', 1, 1, 'orange')
T.truthy(started.ok, 'turno abre no início')
T.equal(started.point, 1, 'primeiro ponto é o 1')
T.equal(call('startShift', 1, 1, 'orange').error, 'already_active', 'um turno por vez')

T.equal(call('finishCollect', 1).error, 'no_collect', 'terminar sem ter começado não paga')

move(1, 20)
T.equal(call('beginCollect', 1, 1, 'orange', 2).error, 'wrong_point', 'ponto que não é o atual é recusado')

move(1, 5)
T.equal(call('beginCollect', 1, 1, 'orange', 1).error, 'too_far', 'coleta exige estar no ponto')

move(1, 10)
pedVehicle[101] = 900
T.equal(call('beginCollect', 1, 1, 'orange', 1).error, 'in_vehicle', 'coleta exige estar a pé')
pedVehicle[101] = nil

hasTool = false
T.equal(call('beginCollect', 1, 1, 'orange', 1).error, 'no_tool', 'coleta exige a ferramenta')
hasTool = true

local begun = call('beginCollect', 1, 1, 'orange', 1)
T.truthy(begun.ok, 'coleta começa no ponto certo')
T.equal(begun.duration, 5000, 'duração vem da config do servidor')

tick(2000)
T.equal(handlers.finishCollect(1).error, 'too_soon', 'terminar antes do tempo não paga')
T.equal(#given, 0, 'nada entregue antes do tempo')
T.equal(#toolUses, 0, 'ferramenta não gasta em coleta recusada')

call('beginCollect', 1, 1, 'orange', 1)
tick(5000)
move(1, 18)
T.equal(handlers.finishCollect(1).error, 'too_far', 'terminar longe do ponto não paga')

move(1, 10)
call('beginCollect', 1, 1, 'orange', 1)
tick(5000)
local finished = handlers.finishCollect(1)
T.truthy(finished.ok, 'coleta paga depois do tempo, no ponto')
T.equal(finished.point, 2, 'turno avança para o ponto 2')
T.equal(given[1][3], 2, 'quantidade decidida no servidor')
T.equal(toolUses[1][2], 5, 'ferramenta gasta com o desgaste da config')
T.equal(stress, 1, 'stress aplicado')
T.equal(dispatched, 1, 'alerta a 100% dispara')

T.equal(call('finishCollect', 1).error, 'no_collect', 'repetir o fim não paga de novo')
T.equal(#given, 1, 'uma entrega por coleta')

-- Cancelar não custa ferramenta e mantém o ponto.
move(1, 20)
call('beginCollect', 1, 1, 'orange', 2)
call('cancelCollect', 1)
T.equal(#toolUses, 1, 'cancelar não gasta ferramenta')

-- Inventário cheio não gasta ferramenta.
call('beginCollect', 1, 1, 'orange', 2)
tick(5000)
canCarry = false
T.equal(handlers.finishCollect(1).error, 'inventory_full', 'sem espaço não entrega')
T.equal(#toolUses, 1, 'sem espaço não gasta ferramenta')
canCarry = true

call('beginCollect', 1, 1, 'orange', 2)
tick(5000)
T.truthy(handlers.finishCollect(1).finished, 'último ponto encerra o turno')
T.equal(call('beginCollect', 1, 1, 'orange', 1).error, 'no_shift', 'depois do fim não há turno')

-- Veículo exigido ----------------------------------------------------------------------

routeTable[3] = {
    name = 'Entrega', mode = 'free', groups = {}, vehicle = 'burrito3', police = { enabled = false, chance = 0, radius = 150 },
    items = { box = { min = 1, max = 1, time = 2000, random = false, unlimited = false, extras = {}, points = { point(100) } } },
}
move(2, 100)
T.equal(call('beginCollect', 2, 3, 'box', 1).error, 'wrong_vehicle', 'sem o veículo da rota por perto é recusado')
vehicleModel[900], vehicleCoords[900] = joaat('burrito2'), vector3(105, 0, 0)
T.equal(call('beginCollect', 2, 3, 'box', 1).error, 'wrong_vehicle', 'model diferente não serve')
vehicleModel[901], vehicleCoords[901] = joaat('burrito3') - 0x100000000, vector3(400, 0, 0)
T.equal(call('beginCollect', 2, 3, 'box', 1).error, 'wrong_vehicle', 'model certo longe não serve')
vehicleCoords[901] = vector3(110, 0, 0)
T.truthy(call('beginCollect', 2, 3, 'box', 1).ok, 'model certo por perto serve, mesmo com hash com sinal')
call('cancelCollect', 2)

-- Requisito da gang ---------------------------------------------------------------------

routeTable[4] = {
    name = 'Porto', mode = 'shift', start = point(0), groups = {}, requirement = { unlock = 'contact_meth' },
    police = { enabled = false, chance = 0, radius = 150 },
    items = { crate = { min = 1, max = 1, time = 2000, random = false, unlimited = false, extras = {}, points = { point(10) } } },
}
move(2, 0)
requirementOk = false
T.equal(call('startShift', 2, 4, 'crate').error, 'locked', 'gang sem o desbloqueio não abre o turno')
requirementOk = true
T.truthy(call('startShift', 2, 4, 'crate').ok, 'com o desbloqueio, abre')
call('stopShift', 2)

Sessions.busyElsewhere = function(source) return source == 2 end
T.equal(call('startShift', 2, 4, 'crate').error, 'already_active', 'quem está numa carga não abre turno')
Sessions.busyElsewhere = function() return false end

-- Rota sem início -----------------------------------------------------------------------

move(2, 50)
groupOk = false
T.equal(call('beginCollect', 2, 2, 'leaf', 1).error, 'not_allowed', 'rota com grupo confere acesso no servidor')
groupOk = true

T.truthy(call('beginCollect', 2, 2, 'leaf', 1).ok, 'rota sem início coleta sem turno')
tick(2000)
T.truthy(handlers.finishCollect(2).ok, 'coleta livre paga')
T.equal(call('finishCollect', 2).error, 'no_collect', 'coleta livre não repete o fim')

-- Rota alterada -------------------------------------------------------------------------

move(1, 0)
call('startShift', 1, 1, 'orange')
clientEvents = {}
changeListener(1)
T.equal(clientEvents[1][1], 'noir_gathering:client:sessionEnded', 'turno da rota alterada é encerrado')
T.equal(clientEvents[1][3], 'route_changed', 'motivo informado ao client')

-- Rate limit ----------------------------------------------------------------------------

move(1, 0)
tick(1000)
handlers.startShift(1, 1, 'orange')
handlers.stopShift(1)
T.equal(handlers.startShift(1, 1, 'orange').error, 'busy', 'pedidos em rajada são barrados')

print('sessions_spec: ok')
