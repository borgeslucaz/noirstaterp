-- Rota de carga no servidor, com ponte, rotas e mundo falsos.
--
-- Cada bloco tenta receber sem ter feito o trabalho: guardar sem ter pegado, pegar da
-- pilha de longe, guardar em outro veículo, descarregar longe do destino, entregar
-- de uma vez, repetir a entrega, abrir a mesma rota duas vezes.

local T = dofile('tests/testlib.lua')
T.natives()

-- Mundo ---------------------------------------------------------------------------------

local now = 0
GetGameTimer = function() return now end
-- O intervalo entre saídas usa relógio e KVP; os dois andam com o `now` do teste.
os.time = function() return math.floor(now / 1000) end
local kvp = {}
SetResourceKvpInt = function(key, value) kvp[key] = value end
GetResourceKvpInt = function(key) return kvp[key] or 0 end
DeleteResourceKvp = function(key) kvp[key] = nil end

local peds = { [1] = 101, [2] = 102 }
local coordsOf = { [101] = vector3(0, 0, 0), [102] = vector3(0, 0, 0) }
local modelOf, netOf, seats = {}, {}, {}

GetPlayerPed = function(source) return peds[source] or 0 end
DoesEntityExist = function(entity) return coordsOf[entity] ~= nil end
GetEntityCoords = function(entity) return coordsOf[entity] end
GetEntityModel = function(entity) return modelOf[entity] end
NetworkGetEntityFromNetworkId = function(netId) return netOf[netId] or 0 end
GetPedInVehicleSeat = function(vehicle, seat) return (seats[vehicle] or {})[seat] or 0 end
GetPlayerName = function(source) return 'p' .. source end
GetAllVehicles = function()
    local list = {}
    for entity in pairs(modelOf) do list[#list + 1] = entity end
    return list
end
IsPedAPlayer = function(ped) return ped == 101 or ped == 102 end
local warped = {}
TaskWarpPedIntoVehicle = function(ped, vehicle, seat) warped[#warped + 1] = { ped, vehicle, seat } end
local nextPed = 500
CreatePed = function(_, _, x, y, z)
    nextPed = nextPed + 1
    coordsOf[nextPed] = vector3(x, y, z)
    return nextPed
end
NetworkGetNetworkIdFromEntity = function(entity) return entity + 1000 end
local deleted = {}
DeleteEntity = function(entity) deleted[entity] = true; coordsOf[entity] = nil; modelOf[entity] = nil end

local clientEvents = {}
TriggerClientEvent = function(name, target, ...) clientEvents[#clientEvents + 1] = { name, target, ... } end
AddEventHandler = function() end
local threads = {}
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function(ms) now = now + (ms or 0) end
locale = function(key) return key end
local carryState = {}
Player = function(source)
    return { state = { set = function(_, key, value) carryState[source] = key == 'noirGatheringCarry' and value or nil end } }
end

local handlers = {}
lib.callback = { register = function(name, fn) handlers[name:gsub('^noir_gathering:server:', '')] = fn end }

-- Ponte e rotas falsas ------------------------------------------------------------------

local given, reported, dispatched, phoned, scouted = {}, {}, 0, {}, 0
local keys = {}
local cleared = {}
GetPlayers = function() return { '1', '2' } end
local canCarry, requirementOk, nextVehicle = true, true, 900
local Integrations = {
    coreReady = function() return true end,
    isLoaded = function() return true end,
    hasGroupAccess = function() return true end,
    meetsRequirement = function(_, requirement) return requirement == nil or requirementOk end,
    canCarry = function() return canCarry end,
    addItem = function(source, item, amount) given[#given + 1] = { source, item, amount }; return true end,
    notify = function() end,
    itemLabel = function(name) return name end,
    dispatch = function() dispatched = dispatched + 1 end,
    reportDelivery = function(source, routeId, name, category, amount)
        reported[#reported + 1] = { source = source, category = category, amount = amount }
    end,
    rivalsWithProduct = function(_, product) return product == 'drugs' and { 2 } or {} end,
    phoneMessage = function(target) phoned[#phoned + 1] = target end,
    giveVehicleKey = function(source, plate) keys[source] = plate; return true end,
    removeVehicleKey = function(source, plate) if keys[source] == plate then keys[source] = nil end end,
    clearVehicleKeys = function(source) cleared[#cleared + 1] = source; keys[source] = nil end,
    progressionCatalog = function() return { categories = { { id = 'drug', product = 'drugs' } } } end,
    spawnVehicle = function(_, model, placement)
        nextVehicle = nextVehicle + 1
        modelOf[nextVehicle] = joaat(model)
        coordsOf[nextVehicle] = vector3(placement.x, placement.y, placement.z)
        netOf[nextVehicle + 1000] = nextVehicle
        return nextVehicle + 1000, nextVehicle
    end,
}

local routeTable = {}
local changeListeners = {}
local Routes = {
    get = function(id) return routeTable[id] end,
    onChange = function(listener) changeListeners[#changeListeners + 1] = listener end,
}
local shiftBusy = false
local Sessions = {
    isActive = function() return shiftBusy end,
    canUseRoute = function() return true end,
}

require = T.require({ ['server.integrations'] = Integrations, ['server.routes'] = Routes, ['server.sessions'] = Sessions })
local Hauls = require 'server.hauls'
Hauls.register()
table.remove(threads, 1)()
T.equal(#cleared, 2, 'no start, a chave de carga de todo jogador online é recolhida')
local watchdog = table.remove(threads, 1)

local function point(x, y) return { x = x, y = y or 0, z = 0, w = 0 } end

local function haulRoute(overrides)
    local route = {
        name = 'Porto', mode = 'haul', start = point(0), groups = {}, vehicle = 'burrito3',
        vehicleSpawn = point(0, 20), requirement = { unlock = 'contact_meth' },
        police = { enabled = true, chance = 100, radius = 150 },
        haul = {
            stack = point(10), prop = 'prop_boxpile_07d', count = 2, dropoff = point(1000),
            rewards = { weed = { min = 3, max = 3 } }, category = 'drug', reputation = 25, cooldown = 0,
            scout = { enabled = true, chance = 100, radius = 300 },
        },
    }
    for key, value in pairs(overrides or {}) do route[key] = value end
    return route
end
routeTable[1] = haulRoute()

local function move(source, x, y) coordsOf[peds[source]] = vector3(x, y or 0, 0) end
local function moveEntity(entity, x, y) coordsOf[entity] = vector3(x, y or 0, 0) end
local function tick(ms) now = now + ms end
local function call(name, ...)
    tick(1000) -- fora do rate limit e do tempo mínimo com a caixa na mão
    return handlers[name](...)
end

-- Abrir a rota ---------------------------------------------------------------------------

move(1, 30)
T.equal(call('haulStart', 1, 1).error, 'too_far', 'a carga abre no NPC')

move(1, 0)
requirementOk = false
T.equal(call('haulStart', 1, 1).error, 'locked', 'gang sem o requisito não abre')
requirementOk = true

shiftBusy = true
T.equal(call('haulStart', 1, 1).error, 'already_active', 'quem está num turno não abre carga')
shiftBusy = false

modelOf[800], coordsOf[800] = joaat('sultan'), vector3(0, 21, 0)
T.equal(call('haulStart', 1, 1).error, 'spawn_blocked', 'vaga ocupada não entrega veículo')
modelOf[800], coordsOf[800] = nil, nil

-- Falha no spawn solta a rota; jogador que cai durante o spawn não deixa veículo órfão.
local realSpawn = Integrations.spawnVehicle
Integrations.spawnVehicle = function() return nil end
T.equal(call('haulStart', 1, 1).error, 'spawn_failed', 'spawn que falha é informado')
Integrations.spawnVehicle = function(...)
    local netId, entity = realSpawn(...)
    Hauls.forget(1)
    return netId, entity
end
T.equal(call('haulStart', 1, 1).error, 'route_changed', 'quem caiu no meio do spawn não fica com a corrida')
T.truthy(deleted[nextVehicle], 'e o veículo que chegou depois é apagado')
Integrations.spawnVehicle = realSpawn

local started = call('haulStart', 1, 1)
T.truthy(started.ok, 'carga abre no NPC, com a vaga livre')
T.equal(started.count, 2, 'o client sabe quantas caixas')
local vehicle = netOf[started.netId]
T.truthy(vehicle, 'a rota entregou o veículo')
T.truthy(keys[1] and keys[1]:match('^CRG%d%d%d%d%d$'), 'e a chave física dele, no inventário')
T.equal(call('haulStart', 1, 1).error, 'already_active', 'uma carga por vez')

move(2, 0)
T.equal(call('haulStart', 2, 1).error, 'route_busy', 'a mesma rota não roda duas vezes ao mesmo tempo')

-- Carregar -------------------------------------------------------------------------------

T.equal(call('haulLoad', 1, started.netId).error, 'wrong_step', 'guardar sem ter pegado não conta')

move(1, 5)
T.equal(call('haulTake', 1).error, 'too_far', 'pegar da pilha exige estar nela')
move(1, 10)
T.truthy(call('haulTake', 1).ok, 'pega a caixa na pilha')
T.equal(carryState[1], true, 'a caixa na mão vai para o state bag, para todos verem')
moveEntity(vehicle, 12)
tick(500)
T.equal(handlers.haulLoad(1, started.netId).error, 'too_soon', 'guardar logo depois de pegar não conta')
T.equal(call('haulTake', 1).error, 'wrong_step', 'uma caixa na mão por vez')

modelOf[850], coordsOf[850], netOf[1850] = joaat('burrito3'), vector3(11, 0, 0), 850
T.equal(call('haulLoad', 1, 1850).error, 'wrong_vehicle', 'outro veículo do mesmo model não é o da carga')
T.equal(call('haulLoad', 1, 99999).error, 'wrong_vehicle', 'netId que não existe é recusado')

moveEntity(vehicle, 40)
T.equal(call('haulLoad', 1, started.netId).error, 'too_far', 'guardar exige estar perto do veículo')
moveEntity(vehicle, 12)

local loaded = call('haulLoad', 1, started.netId)
T.truthy(loaded.ok and loaded.loaded == 1 and not loaded.full, 'primeira caixa guardada')
T.equal(carryState[1], nil, 'guardada, a caixa sai da mão para todos')

call('haulTake', 1)
clientEvents = {}
local full = call('haulLoad', 1, started.netId)
T.truthy(full.full, 'segunda caixa completa a carga')
T.equal(dispatched, 1, 'alerta policial sai quando a carga fica completa')
T.equal(phoned[1], 2, 'o olheiro avisa a gang rival do mesmo produto')
T.equal(clientEvents[1][1], 'noir_gathering:client:scout', 'com a área no mapa')
T.equal(clientEvents[1][4], 300, 'do tamanho configurado')

T.equal(call('haulTake', 1).error, 'wrong_step', 'carga completa não aceita mais caixa da pilha')

-- Descarregar ---------------------------------------------------------------------------

move(1, 12)
T.equal(call('haulUnload', 1, started.netId).error, 'vehicle_far', 'descarregar exige o veículo no destino')

moveEntity(vehicle, 990)
move(1, 992)
T.equal(call('haulDrop', 1).error, 'wrong_step', 'entregar sem caixa na mão não conta')

local unloaded = call('haulUnload', 1, started.netId)
T.truthy(unloaded.ok and unloaded.loaded == 1, 'tira uma caixa do veículo no destino')
T.equal(call('haulUnload', 1, started.netId).error, 'wrong_step', 'uma caixa na mão por vez')

T.equal(call('haulDrop', 1).error, 'too_far', 'entregar exige estar no ponto de entrega')
move(1, 1000)
local dropped = call('haulDrop', 1)
T.truthy(dropped.ok and dropped.delivered == 1 and not dropped.finished, 'primeira caixa entregue')
T.equal(#given, 0, 'nada pago antes da última caixa')

move(1, 992)
call('haulUnload', 1, started.netId)
move(1, 1000)
canCarry = false
local pending = call('haulDrop', 1)
T.truthy(pending.pending, 'sem espaço, o pagamento fica pendente')
T.equal(#given, 0, 'e nada é pago pela metade')
T.equal(#reported, 0, 'nem a reputação')
T.equal(call('haulPay', 1).error, 'inventory_full', 'receber continua recusado sem espaço')

canCarry = true
T.truthy(call('haulPay', 1).finished, 'com espaço, recebe no ponto de entrega')
T.equal(given[1][2], 'weed', 'os itens da rota')
T.equal(given[1][3], 3, 'na quantidade sorteada no servidor')
T.equal(reported[1].category, 'drug', 'a reputação vai para a categoria da rota')
T.equal(reported[1].amount, 25, 'no valor da rota')
T.equal(call('haulPay', 1).error, 'no_run', 'receber de novo não paga')
T.equal(keys[1], nil, 'na entrega a chave sai do inventário')

-- O veículo da rota some com a carga, mas não com alguém dentro.
seats[vehicle] = { [-1] = 101 }
local deadline = now + 5 * 60 * 1000
table.remove(threads)()
T.falsy(deleted[vehicle], 'com alguém dentro, o veículo fica')
T.truthy(now >= deadline, 'e a limpeza desiste no prazo')

move(1, 0)
local spare = call('haulStart', 1, 1)
local spareVehicle = netOf[spare.netId]
T.truthy(keys[1], 'nova carga, nova chave')
call('haulStop', 1)
T.equal(keys[1], nil, 'desistir também tira a chave')
table.remove(threads)()
T.truthy(deleted[spareVehicle], 'vazio, o veículo entregue pela rota é apagado')

-- Motorista na entrega: o veículo sai dirigindo em vez de sumir --------------------------

routeTable[3] = haulRoute()
routeTable[3].haul.count = 1
routeTable[3].haul.driverSpawn = point(1005)
move(1, 0)
local driven = call('haulStart', 1, 3)
local drivenVehicle = netOf[driven.netId]
move(1, 10); call('haulTake', 1)
moveEntity(drivenVehicle, 12); call('haulLoad', 1, driven.netId)
moveEntity(drivenVehicle, 990); move(1, 992); call('haulUnload', 1, driven.netId)
move(1, 1000)
clientEvents = {}
T.truthy(call('haulDrop', 1).finished, 'carga com motorista entregue')
local order = clientEvents[#clientEvents]
T.equal(order[1], 'noir_gathering:client:driveAway', 'quem entregou recebe a ordem de mandar o motorista')
local driverPed = order[3] - 1000
T.equal(order[4], driven.netId, 'para o veículo da rota')
T.truthy(coordsOf[driverPed], 'o motorista foi criado pelo servidor')
T.falsy(deleted[drivenVehicle], 'e o veículo não some na hora')

local cleanupThread = table.remove(threads)
local warpThread = table.remove(threads)
warpThread()
T.equal(warped[1][1], driverPed, 'motorista que não entrou a tempo vai direto para o banco')
cleanupThread()
T.truthy(deleted[driverPed] and deleted[drivenVehicle], 'depois de dirigir um tempo, motorista e veículo são apagados')

-- Rota livre de novo, e agora sem veículo entregue ------------------------------------------

routeTable[2] = haulRoute()
routeTable[2].vehicleSpawn = nil
routeTable[2].haul.cooldown = 5
move(2, 0)
local own = call('haulStart', 2, 2)
T.truthy(own.ok and own.netId == nil, 'rota sem vaga: o jogador traz o veículo')
move(2, 10)
call('haulTake', 2)
modelOf[860], coordsOf[860], netOf[1860] = joaat('sultan'), vector3(11, 0, 0), 860
T.equal(call('haulLoad', 2, 1860).error, 'wrong_vehicle', 'veículo de outro model não serve')
modelOf[861], coordsOf[861], netOf[1861] = joaat('burrito3'), vector3(11, 0, 0), 861
T.truthy(call('haulLoad', 2, 1861).ok, 'o primeiro do model em que guardar vira o da carga')
call('haulTake', 2)
T.equal(call('haulLoad', 2, 1850).error, 'wrong_vehicle', 'e depois nenhum outro serve')

T.equal(carryState[2], true, 'segunda caixa na mão')
call('haulStop', 2)
T.equal(carryState[2], nil, 'desistir tira a caixa da mão')
T.falsy(deleted[861], 'veículo do jogador nunca é apagado')
move(2, 0)
T.equal(call('haulStart', 2, 2).error, 'route_cooldown', 'a rota respeita o intervalo entre saídas')

-- Rota editada e veículo perdido --------------------------------------------------------

move(1, 0)
local again = call('haulStart', 1, 1)
T.truthy(again.ok, 'rota sem intervalo abre de novo')
clientEvents = {}
for _, listener in ipairs(changeListeners) do listener(1) end
T.equal(clientEvents[1][1], 'noir_gathering:client:haulEnded', 'rota editada encerra a carga')
T.equal(clientEvents[1][3], 'route_changed', 'com o motivo')
table.remove(threads)() -- limpeza do veículo da carga encerrada

move(1, 0)
again = call('haulStart', 1, 1)
T.truthy(again.ok, 'a vaga ficou livre para a próxima')
DeleteEntity(netOf[again.netId])
clientEvents = {}
-- O vigia é um laço sem fim: o Wait da segunda volta interrompe o teste depois da primeira.
local rounds = 0
Wait = function() rounds = rounds + 1; if rounds > 1 then error('uma volta') end end
pcall(watchdog)
T.equal(clientEvents[1][3], 'vehicle_lost', 'veículo perdido encerra a carga')

-- Queda no meio da carga: a chave não é mexida (não há inventário), e sai no próximo login.
move(1, 0)
local interrupted = call('haulStart', 1, 1)
T.truthy(interrupted.ok and keys[1], 'carga com chave')
local handlers_ = {}
AddEventHandler = function(name, fn) handlers_[name] = fn end
Hauls.register()
cleared = {}
source = 1
handlers_.playerDropped()
T.truthy(keys[1], 'quem caiu fica com a chave no inventário salvo')
handlers_['bgrz_core:server:playerLoaded'](1)
T.equal(keys[1], nil, 'e no próximo login ela é recolhida')

print('hauls_spec: ok')
