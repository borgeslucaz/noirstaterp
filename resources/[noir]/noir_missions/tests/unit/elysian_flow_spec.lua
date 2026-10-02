-- A missão Elysian inteira, do telefonema à recompensa, no runtime de verdade.
--
-- Cada cenário é um caminho que precisa funcionar sem código específico da missão: tudo o
-- que acontece aqui vem da definição em missions/meth_elysian_precursors.json.
local T = dofile('tests/testlib.lua')
require = T.require()

local MISSION = 'meth_elysian_precursors'
-- Posições tiradas da própria semente: o admin reposiciona a missão no jogo, e o teste
-- acompanha em vez de depender de coordenada fixa.
local SEED
local function offset(coords, dx, dy) return coords.x + (dx or 0), coords.y + (dy or 0), coords.z end
local function stepById(id)
    for _, step in ipairs(SEED.steps) do if step.id == id then return step end end
end
local function arrival() return offset(stepById('go_elysian').coords, 10, 10) end
local function office() return offset(SEED.interactions[1].coords) end
-- Perto do guarda externo, mas do lado de FORA da área restrita (lá dentro é ataque direto).
local function guardPost()
    local ped = SEED.pedGroups[1].peds[1].coords
    local zone = SEED.zones[2].coords
    local dx, dy = ped.x - zone.x, ped.y - zone.y
    local length = math.max(0.1, math.sqrt(dx * dx + dy * dy))
    return ped.x + dx / length * 4, ped.y + dy / length * 4, ped.z
end
local function outsideEscape(dy)
    local step = stepById('escape')
    return offset(step.coords, step.radius + 250, dy)
end

---Servidor novo, Elysian publicada, dois membros da mesma gang perto um do outro.
local function boot(randomValue)
    local S = T.server()
    require = T.require()
    -- A semente fixa, não o arquivo ao vivo: o admin reposiciona a missão no jogo e as
    -- coordenadas deste teste deixariam de bater.
    local Json = dofile('dev/json.lua')
    local Definition = require 'shared.types.definition'
    local seed = Definition.normalize(dofile('dev/seed/meth_elysian_precursors.lua'))
    SEED = seed
    S.files['missions/index.json'] = Json.encode({ missions = { MISSION } })
    S.files['missions/' .. MISSION .. '.json'] = Json.encode({ id = MISSION, status = 'draft', draft = seed })
    require 'server.main'
    local Runtime = require 'server.instances.runtime'
    local Repository = require 'server.missions.repository'
    local Monitor = require 'server.instances.monitor'
    if randomValue then
        Runtime.io.random = function(min, max)
            if not min then return 0.5 end
            if not max then return 1 end
            return math.max(min, math.min(max, randomValue))
        end
    end
    local _, code, errors = Repository.setStatus(MISSION, 'published', 'teste')
    T.equal(code, nil, 'publicar (' .. (errors and errors[1] and errors[1].path .. ' ' .. errors[1].message or '') .. ')')
    S.addPlayer(1, 400.0, -1500.0, 30.0, { name = 'ballas', grade = 2 })
    S.addPlayer(2, 410.0, -1500.0, 30.0, { name = 'ballas', grade = 0 })
    S.addPlayer(3, 405.0, -1505.0, 30.0, { name = 'vagos', grade = 0 })
    return S, Runtime, Monitor
end

local function tick(S, Runtime, Monitor, inst, times)
    for _ = 1, times or 1 do
        S.advance(1000)
        if Runtime.get(inst.id) then Monitor.tickInstance(inst) end
    end
    S.advance(200)
end

---Aceita a oferta e devolve a instância.
local function acceptOffer(S, Runtime)
    local Offers = require 'server.offers'
    local ok, code = Offers.offer(MISSION, 1)
    T.truthy(ok, 'oferta: ' .. tostring(code))
    local offer = S.findSent('noir_missions:client:offer', 1)
    T.truthy(offer, 'oferta chegou ao cliente')
    local result = S.call('noir_missions:server:offerAnswer', 1, offer.args[1].offerId, true)
    T.truthy(result.ok, 'aceitar: ' .. tostring(result.code))
    local inst = Runtime.get(result.instanceId)
    -- Primeiro passo: pegar a van.
    T.equal(inst.step.id, 'get_van', 'primeiro passo é pegar a van')
    S.enterVehicle(1, inst.vehicles.van.record.entity, -1)
    local Monitor = require 'server.instances.monitor'
    Monitor.tickInstance(inst)
    S.moveTo(1, 400.0, -1500.0, 30.0)
    return inst
end

local function correctPieces(inst)
    local list = {}
    for _, piece in ipairs(inst.cargo.barrels.pieces) do
        if piece.correct then list[#list + 1] = piece end
    end
    return list
end

local function decoyPiece(inst)
    for _, piece in ipairs(inst.cargo.barrels.pieces) do
        if not piece.correct then return piece end
    end
end

local function hackOffice(S, Runtime, inst, passed)
    S.moveTo(1, office())
    local begin = S.call('noir_missions:server:interactBegin', 1, inst.id, 'office_pc')
    T.truthy(begin.ok, 'começar hack: ' .. tostring(begin.code))
    T.equal(begin.minigame, SEED.interactions[1].minigame, 'minigame do hack')
    -- Terminar antes do tempo é recusado.
    local early = S.call('noir_missions:server:interactFinish', 1, inst.id, 'office_pc', true)
    T.equal(early.code, 'too_fast', 'hack rápido demais')
    S.advance(1000) -- rate limit entre pedidos
    begin = S.call('noir_missions:server:interactBegin', 1, inst.id, 'office_pc')
    T.truthy(begin.ok, 'recomeçar hack: ' .. tostring(begin.code))
    S.advance(6000)
    local finish = S.call('noir_missions:server:interactFinish', 1, inst.id, 'office_pc', passed)
    T.truthy(finish.ok, 'terminar hack: ' .. tostring(finish.code))
end

local function loadBarrel(S, inst, source, piece)
    local van = inst.vehicles.van.record
    S.advance(700) -- andar até o tambor
    S.moveTo(source, piece.coords.x + 1, piece.coords.y, piece.coords.z)
    local inspect = S.call('noir_missions:server:cargoInspect', source, inst.id, 'barrels', piece.index)
    T.truthy(inspect.ok, 'inspecionar: ' .. tostring(inspect.code))
    T.truthy(inspect.label:find(inst.vars.cargo_batch, 1, true), 'etiqueta da certa mostra o lote sorteado')
    local pick = S.call('noir_missions:server:cargoPickup', source, inst.id, 'barrels', piece.index)
    T.truthy(pick.ok, 'pegar: ' .. tostring(pick.code))
    T.truthy(S.players[source].state['noir_missions:carry'], 'state bag de carregar ligado')
    S.advance(700) -- andar até a van
    local vanCoords = S.entities[van.entity].coords
    S.moveTo(source, vanCoords.x + 2, vanCoords.y, vanCoords.z)
    local load = S.call('noir_missions:server:cargoLoad', source, inst.id, van.netId)
    T.truthy(load.ok, 'carregar na van: ' .. tostring(load.code))
    T.equal(S.players[source].state['noir_missions:carry'], nil, 'state bag desligado depois de carregar')
end

-- Cenário 1: caminho limpo -----------------------------------------------------------------
do
    local S, Runtime, Monitor = boot(1) -- random sempre no mínimo: chance de 60% sai
    local inst = acceptOffer(S, Runtime)
    T.truthy(inst, 'instância criada')
    T.truthy(inst.participants[1] and inst.participants[2], 'membro da gang perto entrou junto')
    T.falsy(inst.participants[3], 'gang rival não entrou')
    T.equal(inst.step.id, 'go_elysian', 'com a van na mão, vai até a ilha')
    T.truthy(inst.vehicles.van and S.entities[inst.vehicles.van.record.entity], 'van nasceu')
    T.equal(#S.core.keys, 2, 'chave para os dois participantes')
    T.equal(S.countEntities(function(e) return e.kind == 'object' end), 9, '8 tambores + notebook')
    T.truthy(S.kvp['noir_missions:cooldown:' .. MISSION] > 0, 'cooldown começou')

    -- Segunda oferta da mesma missão: cooldown.
    local Offers = require 'server.offers'
    local ok, code = Offers.offer(MISSION, 3)
    T.falsy(ok, 'oferta em cooldown')
    T.equal(code, 'cooldown', 'código de cooldown')

    -- Chega na ilha: o gatilho de zona cria os seguranças; o passo de ir até lá conclui.
    S.moveTo(1, arrival())
    local ax, ay, az = arrival()
    S.moveTo(2, ax + 2, ay, az)
    tick(S, Runtime, Monitor, inst)
    T.equal(inst.step.id, 'find_manifest', 'passo do manifesto')
    T.equal(#inst.groups['group:ext_guards'].peds, 3, 'seguranças externos criados')
    T.falsy(inst.groups['group:ext_guards'].hostile, 'seguranças ainda não atiram')

    -- Hack com sucesso: alarme desligado, manifesto mostrado, carga revelada.
    hackOffice(S, Runtime, inst, true)
    T.equal(inst.vars.hack_success, true, 'hack_success')
    T.equal(inst.vars.alarm_active, false, 'alarme desligado')
    T.truthy(S.findSent('noir_missions:client:info', 1), 'manifesto enviado')
    T.equal(inst.step.id, 'load_barrels', 'passo de carregar')
    T.truthy(inst.cargo.barrels.revealed, 'carga revelada')

    -- Isca não pode ser pega.
    local decoy = decoyPiece(inst)
    S.moveTo(1, decoy.coords.x, decoy.coords.y, decoy.coords.z)
    local inspect = S.call('noir_missions:server:cargoInspect', 1, inst.id, 'barrels', decoy.index)
    T.falsy(inspect.label:find(inst.vars.cargo_batch, 1, true), 'isca mostra outro lote')
    S.advance(700)
    local wrong = S.call('noir_missions:server:cargoPickup', 1, inst.id, 'barrels', decoy.index)
    T.equal(wrong.code, 'wrong_cargo', 'isca recusada')

    -- Quatro tambores na van, dois jogadores; o mesmo tambor não sai duas vezes.
    local pieces = correctPieces(inst)
    T.equal(#pieces, 4, 'quatro certos')
    loadBarrel(S, inst, 1, pieces[1])
    S.advance(700)
    local again = S.call('noir_missions:server:cargoPickup', 2, inst.id, 'barrels', pieces[1].index)
    T.equal(again.code, 'not_found', 'tambor já carregado não é pego de novo')
    loadBarrel(S, inst, 2, pieces[2])
    loadBarrel(S, inst, 1, pieces[3])
    tick(S, Runtime, Monitor, inst)
    T.equal(inst.step.id, 'load_barrels', 'três de quatro ainda é o passo de carregar')
    local objective = Runtime.objective(inst)
    T.equal(objective.progress.current, 3, 'objetivo 3 / 4')
    loadBarrel(S, inst, 2, pieces[4])
    T.equal(inst.step.id, 'escape', 'quatro carregados: fuga')

    -- Sai da ilha dirigindo a van.
    local van = inst.vehicles.van.record
    S.enterVehicle(1, van.entity, -1)
    S.moveEntity(van.entity, outsideEscape())
    S.moveTo(2, outsideEscape(5))
    tick(S, Runtime, Monitor, inst)
    T.equal(inst.step.id, 'deliver', 'fora da área: entrega')
    T.equal(#S.core.sms, 2, 'SMS para os dois')
    T.truthy(inst.places.delivery_location, 'local de entrega sorteado')
    T.equal(inst.vars.delivery_location, inst.places.delivery_location.label, 'variável com o nome do local')

    -- A chance de 60% saiu (random no mínimo): depois de 20 s a perseguição nasce num ponto
    -- cadastrado que esteja na faixa de distância e longe de todo participante.
    local place = inst.places.delivery_location
    local spawnA = SEED.chases[1].spawnPoints[1]
    S.moveEntity(van.entity, spawnA.x, spawnA.y - 250, spawnA.z)  -- 250 m do ponto A
    S.moveTo(2, spawnA.x + 3, spawnA.y - 250, spawnA.z)
    tick(S, Runtime, Monitor, inst, 21)
    T.equal(#inst.chases, 1, 'perseguição começou')
    local chase = inst.chases[1]
    T.truthy(#chase.vehicles >= 1, 'veículo da perseguição criado')
    T.equal(chase.target, 1, 'alvo é quem dirige a van')
    local driverTask = (require 'server.instances.world').getTask(chase.crew[1])
    T.equal(driverTask.n, 'chase', 'motorista persegue')

    -- Tripulação morta: onda acaba derrotada, e a segunda (motos) vem 15 s depois.
    for _, record in ipairs(chase.crew) do S.entities[record.entity].health = 0 end
    tick(S, Runtime, Monitor, inst, 2)
    T.truthy(chase.ended, 'primeira onda derrotada')
    tick(S, Runtime, Monitor, inst, SEED.chases[1].waves[1].delaySeconds + 1)
    local second
    for _, run in ipairs(inst.chases) do if run.wave == 1 then second = run end end
    T.truthy(second, 'segunda onda nasceu')
    T.equal(S.entities[second.vehicles[1].entity].model, joaat('bati'), 'segunda onda é de moto')

    -- Despiste: longe demais por 8 s acaba a onda sem chamar outra.
    S.moveEntity(van.entity, spawnA.x + 3000, spawnA.y, spawnA.z)
    S.moveTo(2, spawnA.x + 3003, spawnA.y, spawnA.z)
    tick(S, Runtime, Monitor, inst, 10)
    T.truthy(second.ended, 'segunda onda despistada')
    T.equal(#S.core.items, 0, 'nada pago antes da entrega')

    -- Entrega: van no local, com o motorista ainda dentro — o NPC só pega a van vazia.
    local spot = place.parkCoords or place.coords -- a vaga, quando o local tem uma
    S.moveEntity(van.entity, spot.x, spot.y, spot.z)
    S.moveTo(2, place.coords.x + 2, place.coords.y, place.coords.z)
    tick(S, Runtime, Monitor, inst, 5)
    T.equal(inst.step.id, 'deliver', 'com gente na van, não entrega')
    T.equal(Runtime.objective(inst).text, 'Desçam do veículo para entregar.', 'objetivo pede para descer')

    -- Desceram: 3 s parada, o NPC leva a van.
    S.moveTo(1, place.coords.x + 3, place.coords.y + 2, place.coords.z)
    tick(S, Runtime, Monitor, inst, 5)
    T.equal(inst.status, 'COMPLETED', 'missão concluída')
    local World = require 'server.instances.world'
    T.truthy(S.entities[van.entity], 'van não some no fim da missão: o NPC está levando')
    local driverTask
    for _, desc in pairs(World.snapshot()) do
        if desc.t and desc.t.n == 'drive_off' then driverTask = desc.t end
    end
    T.truthy(driverTask and driverTask.veh == van.netId, 'NPC recebeu a ordem de levar a van')
    S.advance(16000)
    T.equal(S.entities[van.entity].seats[-1] ~= nil, true, 'sem entrar sozinho, o servidor põe no volante')
    S.advance(60000)
    T.equal(S.entities[van.entity], nil, 'van some depois do tempo')
    T.equal(#S.core.items, 2, 'recompensa para os dois')
    T.equal(S.core.items[1].item, 'chemical_precursor', 'item da recompensa')
    T.equal(S.core.items[1].amount, 2, 'quantidade da recompensa')
    T.equal(Runtime.get(inst.id), nil, 'instância removida')
    S.advance(1000)
    T.equal(S.countEntities(function(e) return e.state['noir_missions:instance'] == inst.id end), 0,
        'nenhuma entidade da missão sobrou')
    T.truthy(S.findSent('noir_missions:client:ended', 1), 'fim avisado ao cliente')
end

-- Cenário 2: hack falha, alarme, reforço -----------------------------------------------------
do
    local S, Runtime, Monitor = boot(100) -- random no máximo: chance de 60% não sai
    local inst = acceptOffer(S, Runtime)
    S.moveTo(1, arrival())
    local ax, ay, az = arrival()
    S.moveTo(2, ax + 2, ay, az)
    tick(S, Runtime, Monitor, inst)
    -- Dono confirma que os guardas estão vivos antes de qualquer coisa.
    tick(S, Runtime, Monitor, inst)

    hackOffice(S, Runtime, inst, false)
    T.equal(inst.vars.alarm_active, true, 'alarme ligado na falha')
    T.truthy(inst.groups['group:warehouse_guards'].hostile, 'guardas hostis com o alarme')
    T.equal(inst.step.id, 'load_barrels', 'falha também avança (conclui com qualquer resultado)')

    local pieces = correctPieces(inst)
    S.moveTo(1, pieces[1].coords.x, pieces[1].coords.y, pieces[1].coords.z)
    S.advance(700)
    S.call('noir_missions:server:cargoInspect', 1, inst.id, 'barrels', pieces[1].index)
    S.advance(700)
    local pick = S.call('noir_missions:server:cargoPickup', 1, inst.id, 'barrels', pieces[1].index)
    T.truthy(pick.ok, 'pegou o primeiro')
    T.equal(inst.vars.reinforcement_called, true, 'gatilho marcou o reforço')
    T.equal(#inst.reinforcements, 0, 'reforço espera 30 s')
    tick(S, Runtime, Monitor, inst, 31)
    T.equal(#inst.reinforcements, 1, 'um reforço só, mesmo com dois gatilhos')
    local run = inst.reinforcements[1]
    T.equal(#run.crew, 4, 'quatro na SUV')

    -- Chegada: tripulação desce.
    S.moveEntity(run.vehicle.entity, run.def.destination.x, run.def.destination.y, run.def.destination.z)
    tick(S, Runtime, Monitor, inst)
    T.truthy(run.arrived, 'reforço chegou')

    -- Quem carregava desconecta: o tambor volta ao chão onde ele estava.
    local carried = inst.carrying[1]
    T.truthy(carried, 'jogador 1 carregando')
    S.dropPlayer(1)
    local piece = inst.cargo.barrels.pieces[carried.index]
    T.equal(piece.state, 'world', 'tambor largado no disconnect')
    T.truthy(piece.record and S.entities[piece.record.entity], 'tambor de volta ao mundo')
    T.equal(inst.status, 'ACTIVE', 'missão continua com o outro')

    S.dropPlayer(2)
    T.equal(inst.status, 'FAILED', 'todos saíram: falha')
    S.advance(1000)
    T.equal(S.countEntities(function(e) return e.state['noir_missions:instance'] == inst.id end), 0,
        'limpeza depois de todos saírem')
end

-- Cenário 3: tiro perto dos guardas os deixa hostis -----------------------------------------
do
    local S, Runtime, Monitor = boot(100)
    local inst = acceptOffer(S, Runtime)
    S.moveTo(1, arrival())
    tick(S, Runtime, Monitor, inst)
    S.moveTo(1, guardPost())
    T.falsy(inst.groups['group:ext_guards'].hostile, 'calmos antes do tiro')

    -- Aviso: aponta e continua apontando enquanto há alguém no raio; abaixa quando sai.
    local World = require 'server.instances.world'
    local guards = inst.groups['group:ext_guards']
    local function allTasks(name)
        for _, record in ipairs(guards.peds) do
            if World.getTask(record).n ~= name then return false end
        end
        return true
    end
    tick(S, Runtime, Monitor, inst)
    T.truthy(allTasks('warn'), 'o grupo inteiro aponta')
    T.equal(World.getTask(guards.peds[2]).target, 1, 'cada guarda aponta para o intruso')
    tick(S, Runtime, Monitor, inst, 10)
    T.truthy(allTasks('warn'), 'continuam apontando com o jogador no raio')
    local gx, gy, gz = guardPost()
    S.moveTo(1, gx + 60, gy, gz)
    tick(S, Runtime, Monitor, inst, 5)
    T.truthy(allTasks('idle'), 'abaixam depois que todos saem do raio')
    S.moveTo(1, guardPost())
    _G.source = 1
    S.netEvents['noir_missions:server:shot']()
    T.truthy(inst.groups['group:ext_guards'].hostile, 'tiro deixou hostil')
    T.equal(inst.vars.alarm_active, true, 'hostilidade liga o alarme (alarmOnHostile)')
end

-- Cenário 4: teste do editor a partir de um passo, sem gang e sem cooldown --------------------
do
    local S, Runtime = boot()
    local result = S.call('noir_missions:server:editorTest', 3, MISSION, 'step', 'load_barrels')
    T.truthy(result.ok, 'teste a partir do passo: ' .. tostring(result.code))
    local inst = Runtime.get(result.instanceId)
    T.truthy(inst.test, 'instância de teste')
    T.equal(inst.step.id, 'load_barrels', 'começou no passo pedido')
    T.truthy(inst.cargo.barrels.revealed, 'ações dos passos pulados rodaram (carga revelada)')
    T.equal(S.kvp['noir_missions:cooldown:' .. MISSION], nil, 'teste não grava cooldown')
    local reset = S.call('noir_missions:server:editorTestTool', 3, MISSION, 'reset')
    T.truthy(reset.ok, 'reset do teste')
    T.equal(Runtime.get(result.instanceId), nil, 'teste encerrado')
end

-- Cenário 5: perseguição aleatória na estrada ------------------------------------------------
do
    local S, Runtime, Monitor = boot(1)
    local inst = acceptOffer(S, Runtime)
    inst.def.chases[1].spawnMode = 'road' -- só aleatório
    local van = inst.vehicles.van.record
    S.enterVehicle(1, van.entity, -1)
    S.moveEntity(van.entity, 2000.0, 0.0, 30.0)
    S.moveTo(2, 2003.0, 0.0, 30.0)
    Monitor.updatePositions(inst)

    -- O cliente do alvo devolve três vagas: duas boas e uma colada no jogador 2.
    S.clientHandlers['noir_missions:client:chaseSpawn'] = function(target, requestId, minDistance, maxDistance, count)
        T.equal(target, 1, 'vaga pedida a quem dirige')
        T.equal(count, 1, 'uma vaga por carro (random no mínimo: 1 carro)')
        _G.source = target
        S.netEvents['noir_missions:server:chaseSpawn'](requestId, {
            { x = 2000.0, y = -250.0, z = 30.0, w = 0.0 },
            { x = 2000.0, y = -262.0, z = 30.0, w = 0.0 },
        })
    end
    local Chase = require 'server.components.chase'
    Chase.start(inst, inst.def.chases[1], 0, 0)
    T.equal(#inst.chases, 1, 'perseguição nasceu na estrada')
    local run = inst.chases[1]
    T.equal(#run.vehicles, 1, 'random mínimo: um carro')
    local spawned = S.entities[run.vehicles[1].entity].coords
    T.equal(spawned.y, -250.0, 'nasceu na vaga devolvida pelo cliente')

    -- Vaga perto de um participante é recusada pelo servidor.
    S.clientHandlers['noir_missions:client:chaseSpawn'] = function(target, requestId)
        _G.source = target
        S.netEvents['noir_missions:server:chaseSpawn'](requestId, { { x = 2003.0, y = -40.0, z = 30.0, w = 0.0 } })
    end
    local accepted = Chase.requestRoadSpawn(inst, 1, vector3(2000.0, 0.0, 30.0), inst.def.chases[1], 1)
    T.equal(#accepted, 0, 'vaga perto de jogador descartada')
end

-- Cenário 6: bancos e veículo recém-nascido -------------------------------------------------
do
    local S, Runtime, Monitor = boot(100)
    local inst = acceptOffer(S, Runtime)
    -- O cliente responde tipo e bancos: granger 4, bati 2.
    S.clientHandlers['noir_missions:client:vehicleType'] = function(target, requestId, model)
        _G.source = target
        local seats = { granger = 4, bati = 2, speedo = 2 }
        S.netEvents['noir_missions:server:vehicleType'](requestId, model == 'bati' and 'bike' or 'automobile', seats[model])
    end
    local World = require 'server.instances.world'
    T.equal(World.seatExists('bati', 0, 1), true, 'garupa da moto existe')
    T.equal(World.seatExists('bati', 1, 1), false, 'terceiro banco da moto não existe')

    local def = inst.def.chases[1]
    def.spawnMode = 'points'
    local spawnA = def.spawnPoints[1]
    local van = inst.vehicles.van.record
    S.enterVehicle(1, van.entity, -1)
    S.moveEntity(van.entity, spawnA.x, spawnA.y - 250, spawnA.z)
    S.moveTo(2, spawnA.x + 3, spawnA.y - 250, spawnA.z)
    Monitor.updatePositions(inst)

    local Chase = require 'server.components.chase'
    Chase.start(inst, def, 1, 0) -- onda de motos direto
    local run = inst.chases[1]
    T.truthy(run and #run.vehicles >= 1, 'motos nasceram')
    T.equal(#run.crew, #run.vehicles * 2, 'só dois NPCs por moto (tripulação tem três)')

    -- Vida zerada logo ao nascer (dono ainda não mandou o estado): não é destruição.
    for _, vehicle in ipairs(run.vehicles) do S.entities[vehicle.entity].health = 0 end
    tick(S, Runtime, Monitor, inst)
    T.falsy(run.ended, 'onda não acaba por vida zerada de veículo recém-nascido')
    for _, vehicle in ipairs(run.vehicles) do S.entities[vehicle.entity].health = 1000 end
    tick(S, Runtime, Monitor, inst)
    for _, vehicle in ipairs(run.vehicles) do S.entities[vehicle.entity].health = 0 end
    tick(S, Runtime, Monitor, inst)
    T.truthy(run.ended, 'destruído depois de visto inteiro: onda acaba')
end

-- Cenário 7: SMS com atraso ----------------------------------------------------------------
do
    local S, Runtime = boot(100)
    local inst = acceptOffer(S, Runtime)
    local before = #S.core.sms
    Runtime.runActions(inst, {
        { type = 'send_sms', text = 'mais tarde', delaySeconds = 30 },
        { type = 'set_var', var = 'hack_success', value = 'true' },
    }, {})
    T.equal(inst.vars.hack_success, true, 'ação seguinte não espera o SMS')
    T.equal(#S.core.sms, before, 'SMS ainda não saiu')
    S.advance(29000)
    T.equal(#S.core.sms, before, 'SMS ainda não saiu aos 29 s')
    S.advance(2000)
    T.equal(#S.core.sms, before + 2, 'SMS saiu aos 30 s para os dois')
end

print('elysian_flow_spec: ok')
