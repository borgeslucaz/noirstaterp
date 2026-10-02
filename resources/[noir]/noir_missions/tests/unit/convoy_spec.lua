-- Comboio: formação, ataque, carga dentro do caminhão e transferência para o
-- carro dos jogadores. Missão montada só com dados, como o editor montaria.
local T = dofile('tests/testlib.lua')
require = T.require()
local Json = dofile('dev/json.lua')

local MISSION = 'teste_comboio'

local function crew(count)
    local list = {}
    for index = 1, count do list[index] = { model = 's_m_m_security_01', weapon = 'WEAPON_PISTOL' } end
    return list
end

local function mission(onAttack)
    return {
        id = MISSION, name = 'Teste de comboio', minPlayers = 1, maxPlayers = 4,
        variables = {},
        vehicles = { {
            id = 'getaway', label = 'Carro de fuga', model = 'speedo',
            coords = { x = 0, y = -50, z = 10, w = 0 }, spawnOnStart = true, cargoCapacity = 4,
        } },
        convoys = { {
            id = 'c1', label = 'Comboio', spawnOnStart = false, speed = 16, formationDistance = 12,
            onAttack = onAttack, attackRadius = 50, endBehavior = 'stop',
            route = {
                { x = 0, y = 0, z = 10 }, { x = 0, y = 200, z = 10 }, { x = 0, y = 400, z = 10 },
            },
            vehicles = {
                { role = 'lead', model = 'granger', crew = crew(2) },
                { role = 'cargo', model = 'mule', crew = crew(2) },
                { role = 'escort', model = 'granger', crew = crew(2) },
            },
        } },
        cargo = { {
            id = 'chem', label = 'Galões', model = 'prop_barrel_02a', mode = 'carry', quantity = 3,
            startConvoy = 'c1', startConvoyVehicle = 2, revealed = true,
            requireVehicle = true, vehicleMode = 'any',
        } },
        steps = {
            { id = 'spawn', type = 'actions', label = 'Comboio sai', onStart = {
                { type = 'spawn_convoy', convoy = 'c1' },
            } },
            { id = 'ambush', type = 'condition', label = 'Interceptar',
                ['until'] = { rules = { { var = 'convoy.c1.alive', op = 'eq', value = '0' } } } },
            { id = 'transfer', type = 'cargo', label = 'Transferir', cargo = 'chem', target = 'loaded', count = 0 },
        },
    }
end

local function boot(onAttack)
    local S = T.server()
    require = T.require()
    local Definition = require 'shared.types.definition'
    local def, errors = Definition.normalize(mission(onAttack))
    for _, err in ipairs(errors) do print('erro', err.path, err.message) end
    T.equal(#errors, 0, 'definição do comboio válida')
    S.files['missions/index.json'] = Json.encode({ missions = { MISSION } })
    S.files['missions/' .. MISSION .. '.json'] = Json.encode({ id = MISSION, status = 'draft', draft = def })
    require 'server.main'
    S.addPlayer(1, 30.0, -60.0, 10.0, { name = 'ballas', grade = 1 })
    local Runtime = require 'server.instances.runtime'
    local Monitor = require 'server.instances.monitor'
    local result = S.call('noir_missions:server:editorTest', 1, MISSION, 'full')
    T.truthy(result.ok, 'teste começou: ' .. tostring(result.code))
    return S, Runtime, Monitor, Runtime.get(result.instanceId)
end

local function tick(S, Monitor, inst, times)
    for _ = 1, times or 1 do
        S.advance(1000)
        Monitor.tickInstance(inst)
    end
    S.advance(200)
end

local World

-- Formação, rota, ataque e transferência ------------------------------------
do
    local S, Runtime, Monitor, inst = boot('stop_and_fight')
    World = require 'server.instances.world'
    local Cargo = require 'server.components.cargo'
    local run = inst.convoys.c1
    T.truthy(run, 'comboio nasceu')
    T.equal(#run.units, 3, 'três veículos')
    T.equal(inst.step.id, 'ambush', 'passo de interceptar')

    local lead, truck, rear = run.units[1], run.units[2], run.units[3]
    T.equal(World.getTask(lead.crew[1]).n, 'drive_to', 'o primeiro conduz')
    T.equal(World.getTask(lead.crew[1]).y, 200, 'para o segundo ponto da rota')
    T.equal(World.getTask(truck.crew[1]).n, 'escort', 'o caminhão segue')
    T.equal(World.getTask(truck.crew[1]).target, lead.vehicle.netId, 'segue o da frente')
    T.equal(World.getTask(rear.crew[1]).target, truck.vehicle.netId, 'a escolta de trás segue o caminhão')
    T.truthy(S.entities[rear.vehicle.entity].coords.y < S.entities[lead.vehicle.entity].coords.y, 'fila atrás do líder')

    -- Carga nasce no caminhão e não conta como "no veículo" ainda.
    T.equal(#Cargo.loadedByVehicle(inst, 'chem'), 0, 'carga no comboio não conta')
    T.equal(Cargo.count(inst, 'chem', 'loaded'), 0, 'zero carregadas')

    -- Rota: líder chega no ponto 2, vai para o 3.
    S.moveEntity(lead.vehicle.entity, 0, 195, 10)
    tick(S, Monitor, inst)
    T.equal(run.waypoint, 3, 'próximo ponto')
    T.equal(World.getTask(lead.crew[1]).y, 400, 'ordem para o terceiro ponto')

    -- Tiro perto: todos descem para defender.
    _G.source = 1
    S.moveTo(1, 0, 180, 10)
    Monitor.updatePositions(inst)
    S.netEvents['noir_missions:server:shot']()
    T.truthy(run.attacked, 'tiro perto do comboio = ataque')
    T.equal(World.getTask(rear.crew[1]).n, 'exit', 'escolta desce')
    T.equal(World.getTask(rear.crew[1]).engage, true, 'e luta')
    T.equal(World.getTask(truck.crew[1]).n, 'exit', 'no "param e defendem", a carga também desce')

    -- Neutralizados: o passo de interceptar conclui.
    for _, unit in ipairs(run.units) do
        for _, record in ipairs(unit.crew) do S.entities[record.entity].health = 0 end
    end
    tick(S, Monitor, inst, 2)
    T.equal(Runtime.resolve(inst, 'convoy.c1.alive'), 0, 'ninguém vivo')
    T.equal(inst.step.id, 'transfer', 'interceptado: transferir a carga')

    -- Tira do caminhão e põe no carro de fuga, três vezes.
    local getaway = inst.vehicles.getaway.record
    local truckCoords = S.entities[truck.vehicle.entity].coords
    for number = 1, 3 do
        S.advance(700)
        S.moveTo(1, truckCoords.x + 2, truckCoords.y, truckCoords.z)
        local unload = S.call('noir_missions:server:cargoUnload', 1, inst.id, truck.vehicle.netId)
        T.truthy(unload.ok, 'tirou do caminhão: ' .. tostring(unload.code))
        S.advance(700)
        local getawayCoords = S.entities[getaway.entity].coords
        S.moveTo(1, getawayCoords.x + 2, getawayCoords.y, getawayCoords.z)
        local load = S.call('noir_missions:server:cargoLoad', 1, inst.id, getaway.netId)
        T.truthy(load.ok, 'pôs no carro: ' .. tostring(load.code))
        T.equal(Cargo.count(inst, 'chem', 'picked'), number, 'tirar do comboio conta como pegar')
    end
    T.equal(inst.status, 'COMPLETED', 'três no carro de fuga: missão concluída')
end

-- Carga foge, escoltas lutam ------------------------------------------------------------------
do
    local S, _, Monitor, inst = boot('truck_flees')
    World = require 'server.instances.world'
    local run = inst.convoys.c1
    local Convoy = require 'server.components.convoy'
    Convoy.attack(inst, run, 'teste')
    local truck = run.units[2]
    T.equal(World.getTask(truck.crew[1]).n, 'drive_to', 'caminhão foge')
    T.equal(World.getTask(truck.crew[1]).y, 400, 'para o fim da rota')
    T.equal(World.getTask(truck.crew[2]).n, 'ride', 'passageiro do caminhão fica dentro')
    T.equal(World.getTask(run.units[1].crew[1]).n, 'exit', 'escolta desce para lutar')
    tick(S, Monitor, inst)
end

print('convoy_spec: ok')
