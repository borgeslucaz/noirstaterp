---Entidades de missão criadas pelo servidor (OneSync) e o registro que os clientes leem para
---conduzir a IA delas.
---
---Por que um registro e não tarefa dada pelo servidor: a IA de um ped só roda no dono de rede,
---e tarefa dada a ele morre quando o dono muda (jogador se afasta, desconecta). Aqui cada
---entidade tem uma descrição — configuração + tarefa atual + versão — replicada para todos os
---clientes. Quem for dono aplica; quem passar a ser dono reaplica. A missão não depende de
---quem começou, nem de quem está perto agora (§41 do pedido, §10.3 das boas práticas).
---
---A descrição é pública (modelo, arma, destino). Nada de recompensa ou regra.
local World = {}

---@type table<integer, table> netId -> descrição pública
local registry = {}
---@type table<integer, table> netId -> { entity, netId, kind, instanceId, key }
local records = {}
---@type table<integer, table|false>
local pending = {}
local flushScheduled = false

local STATE_INSTANCE = 'noir_missions:instance'
local STATE_INIT = 'noir_missions:init'
local STATE_CARRY = 'noir_missions:carry'

World.STATE_INIT = STATE_INIT
World.STATE_CARRY = STATE_CARRY

local function flush()
    flushScheduled = false
    if next(pending) == nil then return end
    local patch = pending
    pending = {}
    TriggerClientEvent('noir_missions:client:entities', -1, patch)
end

---@param netId integer
---@param desc table|false
local function publish(netId, desc)
    pending[netId] = desc
    if flushScheduled then return end
    flushScheduled = true
    SetTimeout(100, flush)
end

---@param entity integer
---@return boolean
local function waitExists(entity)
    if not entity or entity == 0 then return false end
    for _ = 1, 50 do
        if DoesEntityExist(entity) then return true end
        Wait(20)
    end
    return DoesEntityExist(entity)
end

---Entidade de missão não pode sumir porque ninguém está perto: ela some no cleanup.
---@param entity integer
local function keep(entity)
    pcall(SetEntityOrphanMode, entity, 2)
end

---@param inst table
---@param entity integer
---@param kind 'ped'|'vehicle'|'object'
---@param key string
---@param desc table?
---@return table? record
local function register(inst, entity, kind, key, desc)
    keep(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then
        DeleteEntity(entity)
        return nil
    end
    Entity(entity).state:set(STATE_INSTANCE, inst.id, true)
    local record = { entity = entity, netId = netId, kind = kind, instanceId = inst.id, key = key }
    records[netId] = record
    if desc then
        desc.k = kind
        desc.i = inst.id
        desc.g = key
        desc.v = 1
        registry[netId] = desc
        publish(netId, desc)
    end
    return record
end

---Configuração que o dono aplica no ped.
---@param cfg table
---@param coords table?
---@return table
local function pedConfig(cfg, coords)
    return {
        weapon = cfg.weapon,
        armor = cfg.armor or 0,
        health = cfg.health or 200,
        accuracy = cfg.accuracy or 35,
        combatAbility = cfg.combatAbility or 1,
        combatRange = cfg.combatRange or 1,
        movement = cfg.movement or 'static',
        scenario = cfg.scenario,
        patrolRadius = cfg.patrolRadius or 10,
        anchor = coords and { x = coords.x, y = coords.y, z = coords.z, w = coords.w or 0.0 } or nil,
    }
end

---@param inst table
---@param key string grupo lógico (ex.: `group:ext_guards`)
---@param cfg table ped do esquema
---@param coords table { x, y, z, w }
---@param task? table tarefa inicial
---@return table? record
function World.createPed(inst, key, cfg, coords, task)
    local ped = CreatePed(4, joaat(cfg.model), coords.x, coords.y, coords.z, coords.w or 0.0, true, true)
    if not waitExists(ped) then
        lib.print.error(('[noir_missions] ped %s não nasceu (%s)'):format(cfg.model, key))
        return nil
    end
    return register(inst, ped, 'ped', key, { cfg = pedConfig(cfg, coords), t = task or { n = 'idle' } })
end

---Ped que vai num banco de veículo. Não usa `CreatePedInsideVehicle`: é native RPC, executado
---pelo dono de rede do veículo, e um veículo recém-criado ainda não tem dono — o ped nunca
---nascia (reforço da Elysian, 2026-10-01). Nasce ao lado, e o dono de rede do ped o põe no
---banco quando aplica a tarefa (client/npc/ai.lua), como faz com o resto da configuração.
---@param inst table
---@param key string
---@param cfg table
---@param vehicle table record do veículo
---@param seat integer -1 motorista, 0.. passageiros
---@param task? table
---@return table? record
function World.createPedInVehicle(inst, key, cfg, vehicle, seat, task)
    if not vehicle or not DoesEntityExist(vehicle.entity) then return nil end
    local origin = GetEntityCoords(vehicle.entity)
    local ped = CreatePed(4, joaat(cfg.model), origin.x, origin.y, origin.z + 1.0, GetEntityHeading(vehicle.entity), true, true)
    if not waitExists(ped) then
        lib.print.error(('[noir_missions] ped %s do banco %d não nasceu (%s)'):format(cfg.model, seat, key))
        return nil
    end
    local record = register(inst, ped, 'ped', key, {
        cfg = pedConfig(cfg, nil), t = task or { n = 'ride', veh = vehicle.netId }, seat = seat,
    })
    if record then record.seat = seat end
    return record
end

---@param inst table
---@param key string
---@param model string
---@param vehicleType string
---@param coords table
---@param opts? { plate?: string, locked?: boolean, npc?: boolean }
---@return table? record
function World.createVehicle(inst, key, model, vehicleType, coords, opts)
    opts = opts or {}
    local vehicle = CreateVehicleServerSetter(joaat(model), vehicleType, coords.x, coords.y, coords.z, coords.w or 0.0)
    if not waitExists(vehicle) then
        lib.print.error(('[noir_missions] veículo %s não nasceu (%s)'):format(model, key))
        return nil
    end
    if opts.plate then SetVehicleNumberPlateText(vehicle, opts.plate) end
    SetVehicleDoorsLocked(vehicle, opts.locked and 2 or 1)
    local record = register(inst, vehicle, 'vehicle', key, { cfg = { npc = opts.npc == true }, t = { n = 'none' } })
    if record then record.plate = opts.plate end
    return record
end

---@param inst table
---@param key string
---@param model string
---@param coords table
---@param frozen boolean
---@return table? record
function World.createObject(inst, key, model, coords, frozen)
    local object = CreateObjectNoOffset(joaat(model), coords.x, coords.y, coords.z, true, true, false)
    if not waitExists(object) then
        lib.print.error(('[noir_missions] objeto %s não nasceu (%s)'):format(model, key))
        return nil
    end
    SetEntityHeading(object, coords.w or 0.0)
    FreezeEntityPosition(object, frozen ~= false)
    -- Objeto não precisa de IA; não entra no registro público.
    return register(inst, object, 'object', key, nil)
end

---Troca a tarefa. O dono atual reaplica na próxima volta; um dono futuro também.
---@param record table?
---@param task table
function World.setTask(record, task)
    if not record then return end
    local desc = registry[record.netId]
    if not desc then return end
    desc.t = task
    desc.v = (desc.v or 0) + 1
    publish(record.netId, desc)
end

---@param record table?
---@return table? task
function World.getTask(record)
    local desc = record and registry[record.netId]
    return desc and desc.t or nil
end

---@param record table?
function World.delete(record)
    if not record then return end
    if records[record.netId] == record then
        records[record.netId] = nil
        if registry[record.netId] then
            registry[record.netId] = nil
            publish(record.netId, false)
        end
    end
    if record.entity and DoesEntityExist(record.entity) then
        DeleteEntity(record.entity)
    end
end

---Tira a entidade da instância e apaga depois de `seconds`, sem nunca apagar veículo com
---jogador dentro (tenta de novo a cada 5 s por até um minuto). Serve para o que sai de cena
---dirigindo: o fim da missão não pode fazer a van sumir na frente de ninguém.
---@param record table?
---@param seconds number
function World.release(record, seconds)
    if not record then return end
    record.instanceId = nil
    local desc = registry[record.netId]
    if desc then desc.i = nil end
    local attempts = 0
    local function try()
        if not DoesEntityExist(record.entity) then return World.delete(record) end
        local busy = false
        if record.kind == 'vehicle' then
            for seat = -1, 6 do
                local ped = GetPedInVehicleSeat(record.entity, seat)
                if ped ~= 0 and IsPedAPlayer(ped) then busy = true break end
            end
        end
        attempts = attempts + 1
        if busy and attempts < 12 then return SetTimeout(5000, try) end
        World.delete(record)
    end
    SetTimeout(math.floor(seconds * 1000), try)
end

---@param record table?
---@return boolean
function World.exists(record)
    return record ~= nil and record.entity ~= nil and DoesEntityExist(record.entity)
        and records[record.netId] == record
end

---@param record table
---@return vector3?
function World.coords(record)
    if not World.exists(record) then return nil end
    return GetEntityCoords(record.entity)
end

---Há um cliente transmitindo a entidade. Sem dono, a vida lida no servidor não vale
---(aprendido no noir_outposts).
---@param entity integer
---@return boolean
local function hasOwner(entity)
    local ok, owner = pcall(NetworkGetEntityOwner, entity)
    return ok and type(owner) == 'number' and owner >= 0
end

---Estado de vida de um ped de missão.
---  'dead'    — sumiu, ou dono confirmou vida zero depois de já ter visto vivo;
---  'alive'   — dono confirma vida;
---  'unknown' — sem dono, a leitura não vale.
---@param record table
---@return 'alive'|'dead'|'unknown' state
---@return integer? health
function World.pedState(record)
    if not World.exists(record) then return 'dead', 0 end
    if not hasOwner(record.entity) then return 'unknown', nil end
    local health = GetEntityHealth(record.entity)
    if health > 0 then
        record.seenAlive = true
        return 'alive', health
    end
    if record.seenAlive then return 'dead', 0 end
    return 'unknown', nil
end

---Veículo destruído: sumiu, ou o dono confirma motor/carroceria no fim DEPOIS de já ter
---confirmado o veículo inteiro. Logo que nasce, antes de o primeiro dono mandar o estado, a
---vida lida no servidor pode vir zerada — e uma onda de perseguição acabava "derrotada" um
---segundo depois de nascer (2026-10-02).
---@param record table
---@return boolean
function World.vehicleDestroyed(record)
    if not World.exists(record) then return true end
    if not hasOwner(record.entity) then return false end
    local engine = GetVehicleEngineHealth(record.entity)
    local health = GetEntityHealth(record.entity)
    local wrecked = engine <= -3999.0 or health <= 0
    if not wrecked then
        record.seenIntact = true
        return false
    end
    return record.seenIntact == true
end

---@param inst table
function World.cleanupInstance(inst)
    local list = {}
    for _, record in pairs(records) do
        if record.instanceId == inst.id then list[#list + 1] = record end
    end
    for index = 1, #list do World.delete(list[index]) end
end

---@return table<integer, table>
function World.snapshot()
    return registry
end

function World.cleanupAll()
    local list = {}
    for _, record in pairs(records) do list[#list + 1] = record end
    for index = 1, #list do World.delete(list[index]) end
end

-- Inicialização única por entidade ------------------------------------------------------
-- Vida e colete são aplicados pelo primeiro dono e não podem ser reaplicados quando o dono
-- muda (seria curar no meio do tiroteio). O primeiro dono avisa; o servidor confere que ele
-- é mesmo o dono e grava a marca no state bag, que só o servidor escreve.

RegisterNetEvent('noir_missions:server:entityReady', function(netId)
    local src = source
    if type(netId) ~= 'number' then return end
    local record = records[netId]
    if not record or not DoesEntityExist(record.entity) then return end
    if NetworkGetEntityOwner(record.entity) ~= src then return end
    Entity(record.entity).state:set(STATE_INIT, true, true)
end)

lib.callback.register('noir_missions:server:entitySnapshot', function()
    return registry
end)

-- Tipo de veículo -------------------------------------------------------------------------
-- `CreateVehicleServerSetter` precisa do tipo ('automobile', 'bike', 'boat'...), que o
-- servidor não sabe pelo modelo. Pergunta a um cliente uma vez por modelo e guarda.

local vehicleTypes = {}
local vehicleSeats = {}
local typeRequests = {}
local VALID_TYPES = {
    automobile = true, bike = true, boat = true, heli = true, plane = true,
    submarine = true, trailer = true, train = true,
}

RegisterNetEvent('noir_missions:server:vehicleType', function(requestId, vehicleType, seats)
    local request = typeRequests[requestId]
    if not request or request.source ~= source then return end
    if VALID_TYPES[vehicleType] then request.result = vehicleType end
    if type(seats) == 'number' and seats >= 1 and seats <= 16 and seats % 1 == 0 then request.seats = seats end
    request.done = true
end)

---Pergunta ao cliente o tipo do modelo e quantos bancos ele tem (motorista incluído).
---Uma vez por modelo; o resultado fica guardado.
---@param model string
---@param askSource integer?
local function learn(model, askSource)
    if vehicleTypes[model] or not askSource or not GetPlayerName(askSource) then return end
    local requestId = ('%s:%d'):format(model, GetGameTimer())
    local request = { source = askSource }
    typeRequests[requestId] = request
    TriggerClientEvent('noir_missions:client:vehicleType', askSource, requestId, model)
    for _ = 1, 30 do
        if request.done then break end
        Wait(100)
    end
    typeRequests[requestId] = nil
    if request.result then
        vehicleTypes[model] = request.result
        vehicleSeats[model] = request.seats
    end
end

---@param model string
---@param askSource integer?
---@return string
function World.vehicleType(model, askSource)
    learn(model, askSource)
    if vehicleTypes[model] then return vehicleTypes[model] end
    lib.print.warn(('[noir_missions] tipo do veículo %s desconhecido; usando automobile'):format(model))
    return 'automobile'
end

---Bancos do modelo, motorista incluído; nil quando ninguém soube dizer.
---@param model string
---@param askSource integer?
---@return integer?
function World.vehicleSeats(model, askSource)
    learn(model, askSource)
    return vehicleSeats[model]
end

---O banco existe no modelo? -1 é o motorista, 0.. passageiros. Sem a contagem, deixa passar e
---quem senta (o dono do ped) confere de novo.
---@param model string
---@param seat integer
---@param askSource integer?
---@return boolean
function World.seatExists(model, seat, askSource)
    local seats = World.vehicleSeats(model, askSource)
    if not seats then return true end
    return seat + 2 <= seats
end

---Placa de veículo de missão: 8 caracteres, sem colidir com o formato de placa de jogador.
---@return string
function World.randomPlate()
    local chars = 'ABCDEFGHJKLMNPRSTUVWXYZ'
    local out = { 'N', 'M' }
    for _ = 1, 2 do
        local index = math.random(1, #chars)
        out[#out + 1] = chars:sub(index, index)
    end
    out[#out + 1] = tostring(math.random(1000, 9999))
    return table.concat(out)
end

---Ponto mais próximo de qualquer participante; usado para escolher alvo de ataque/perseguição.
---@param inst table
---@param coords vector3
---@return integer? source
---@return number distance
function World.nearestParticipant(inst, coords)
    local best, bestDistance = nil, math.huge
    for source, position in pairs(inst.positions) do
        local distance = #(position - coords)
        if distance < bestDistance then best, bestDistance = source, distance end
    end
    return best, bestDistance
end


return World
