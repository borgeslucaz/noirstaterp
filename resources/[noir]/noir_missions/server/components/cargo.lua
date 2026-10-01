---Carga: peças no mundo, inspeção de etiqueta, pegar, carregar nas mãos, largar, pôr e tirar
---do veículo, entregar. Passo "Carga".
---
---Cada peça tem um estado só, no servidor:
---    world → carried → loaded → delivered
---    world → collected                 (modo inventário ou só interação)
---e volta para `world` quando é largada. Dois jogadores pedindo a mesma peça: o primeiro
---pedido muda o estado, o segundo encontra a peça fora de `world` e é recusado (§40).
---
---Quem carrega fica marcado num state bag do jogador (escalar, escrito só pelo servidor).
---Cada cliente vê a marca e cria o objeto na mão daquele jogador, localmente — não há objeto
---de rede carregado, então troca de dono não tem o que quebrar.
local Utils = require 'shared.utils.core'
local Template = require 'shared.utils.template'
local SharedConfig = require 'config.shared'
local Config = require 'config.server'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Security = require 'server.security'
local Integrations = require 'server.integrations'

local Cargo = {}

-- Estado ----------------------------------------------------------------------------------

---@param inst table
---@param cargoId string
---@return table? group
local function group(inst, cargoId)
    return inst.cargo[cargoId]
end

---@param inst table
---@param cargoId string
---@return integer
function Cargo.total(inst, cargoId)
    local entry = group(inst, cargoId)
    return entry and entry.total or 0
end

---@param inst table
---@param cargoId string
---@param what 'picked'|'loaded'|'delivered'|'carried'|'collected'
---@return integer
function Cargo.count(inst, cargoId, what)
    local entry = group(inst, cargoId)
    if not entry then return 0 end
    local total = 0
    for index = 1, #entry.pieces do
        local piece = entry.pieces[index]
        if piece.correct then
            if what == 'picked' then
                if piece.everPicked then total = total + 1 end
            elseif what == 'delivered' then
                if piece.state == 'delivered' or (piece.state == 'collected' and piece.deliveredItem) then total = total + 1 end
            elseif piece.state == what then
                total = total + 1
            end
        end
    end
    return total
end

---Veículos com peças desta carga, e quantas cada um leva.
---@param inst table
---@param cargoId string
---@return { record: table, netId: integer, count: integer }[]
function Cargo.loadedByVehicle(inst, cargoId)
    local entry = group(inst, cargoId)
    local byNet, list = {}, {}
    if not entry then return list end
    for index = 1, #entry.pieces do
        local piece = entry.pieces[index]
        if piece.state == 'loaded' and piece.correct and piece.vehicle and DoesEntityExist(piece.vehicle.entity) then
            local slot = byNet[piece.vehicle.netId]
            if not slot then
                slot = { record = piece.vehicle, netId = piece.vehicle.netId, count = 0 }
                byNet[piece.vehicle.netId] = slot
                list[#list + 1] = slot
            end
            slot.count = slot.count + 1
        end
    end
    return list
end

---Texto do state bag de quem carrega: `modelo;osso;ox,oy,oz;rx,ry,rz;dict;anim;corre`.
---@param def table
---@return string
function Cargo.carryString(def)
    local preset = SharedConfig.carryPresets[def.carryPreset]
    local bone, offset, rotation, dict, anim
    if preset then
        bone, dict, anim = preset.bone, preset.dict, preset.anim
        offset = ('%.3f,%.3f,%.3f'):format(preset.offset[1], preset.offset[2], preset.offset[3])
        rotation = ('%.3f,%.3f,%.3f'):format(preset.rotation[1], preset.rotation[2], preset.rotation[3])
    else
        bone = math.floor(tonumber(def.carryBone) or 28422)
        offset = def.carryOffset or '0,0,0'
        rotation = def.carryRotation or '0,0,0'
        dict = def.carryDict or SharedConfig.carryPresets.box.dict
        anim = def.carryAnim or SharedConfig.carryPresets.box.anim
    end
    return table.concat({ def.model, tostring(bone), offset, rotation, dict, anim, def.canSprint and '1' or '0' }, ';')
end

---@param inst table
---@param entry table
---@param piece table
local function spawnPiece(inst, entry, piece)
    if piece.record and World.exists(piece.record) then return end
    piece.record = World.createObject(inst, ('cargo:%s:%d'):format(entry.def.id, piece.index),
        entry.def.model, piece.coords, true)
end

---@param source integer
---@param value string?
local function setCarryState(source, value)
    if GetPlayerName(source) then
        Player(source).state:set(World.STATE_CARRY, value, true)
    end
end

---Larga a peça que o jogador carrega, onde ele está (ou num ponto dado).
---@param inst table
---@param source integer
---@param coords? vector3
---@return boolean
function Cargo.dropCarried(inst, source, coords)
    local carrying = inst.carrying[source]
    if not carrying then return false end
    inst.carrying[source] = nil
    setCarryState(source, nil)
    local entry = group(inst, carrying.cargo)
    local piece = entry and entry.pieces[carrying.index]
    if not piece or piece.state ~= 'carried' then return false end

    coords = coords or Security.playerCoords(source)
    if coords then
        -- A origem do ped fica perto de um metro acima do chão.
        piece.coords = { x = coords.x, y = coords.y, z = coords.z - 0.98, w = piece.coords.w or 0.0 }
    end
    piece.state = 'world'
    piece.carrier = nil
    spawnPiece(inst, entry, piece)
    Runtime.emit(inst, 'cargo_dropped', { cargo = entry.def.id, actor = source })
    Runtime.markDirty(inst)
    return true
end

---Entrega peças carregadas num veículo. Devolve quantas entregou.
---@param inst table
---@param cargoId string
---@param vehicleNetId integer
---@param max integer
---@param actor? integer
---@return integer
function Cargo.deliverFromVehicle(inst, cargoId, vehicleNetId, max, actor)
    local entry = group(inst, cargoId)
    if not entry then return 0 end
    local delivered = 0
    for index = 1, #entry.pieces do
        local piece = entry.pieces[index]
        if delivered >= max then break end
        if piece.correct and piece.state == 'loaded' and piece.vehicle and piece.vehicle.netId == vehicleNetId then
            piece.state = 'delivered'
            delivered = delivered + 1
        end
    end
    if delivered > 0 then
        Runtime.emit(inst, 'cargo_delivered', { cargo = cargoId, actor = actor })
        Runtime.markDirty(inst)
    end
    return delivered
end

---Peças da carga que o jogo tem no mundo, para conferir distância pela posição real.
---@param piece table
---@return table
local function pieceCoords(piece)
    local coords = piece.record and World.coords(piece.record)
    if coords then return coords end
    return vector3(piece.coords.x, piece.coords.y, piece.coords.z)
end

---@param inst table
---@param cargoId string
---@param revealed boolean
function Cargo.setRevealed(inst, cargoId, revealed)
    local entry = group(inst, cargoId)
    if not entry or entry.revealed == revealed then return end
    entry.revealed = revealed
    Runtime.markDirty(inst)
end

-- Validação do veículo --------------------------------------------------------------------

---@param inst table
---@param def table
---@param entity integer
---@param netId integer
---@return boolean ok
---@return string? code
local function vehicleAllowed(inst, def, entity, netId)
    if not def.requireVehicle then return true end
    local mode = def.vehicleMode or 'mission'
    if mode == 'any' then return true end
    if mode == 'mission' then
        local vehicle = inst.vehicles[def.vehicleId]
        if vehicle and vehicle.record and vehicle.record.netId == netId then return true end
        return false, 'wrong_vehicle'
    end
    local model = GetEntityModel(entity)
    if mode == 'models' then
        for index = 1, #(def.vehicleModels or {}) do
            if joaat(def.vehicleModels[index]) == model then return true end
        end
        return false, 'wrong_vehicle'
    end
    if mode == 'class' then
        local class = Integrations.vehicleClass(model)
        for index = 1, #(def.vehicleClasses or {}) do
            if tonumber(def.vehicleClasses[index]) == class then return true end
        end
        return false, 'wrong_vehicle'
    end
    return false, 'wrong_vehicle'
end

---Quantas peças (de qualquer carga desta instância) estão no veículo.
---@param inst table
---@param netId integer
---@return integer
local function loadedIn(inst, netId)
    local total = 0
    for _, entry in pairs(inst.cargo) do
        for index = 1, #entry.pieces do
            local piece = entry.pieces[index]
            if piece.state == 'loaded' and piece.vehicle and piece.vehicle.netId == netId then total = total + 1 end
        end
    end
    return total
end

---@param inst table
---@param netId integer
---@return integer?
local function capacityOf(inst, netId)
    for _, vehicle in pairs(inst.vehicles) do
        if vehicle.record and vehicle.record.netId == netId then
            return (vehicle.def.cargoCapacity or 0) > 0 and vehicle.def.cargoCapacity or nil
        end
    end
    return nil
end

-- Componente ------------------------------------------------------------------------------

---@param inst table
---@param step table
local function checkStep(inst, step)
    local needed = (step.count or 0) > 0 and step.count or Cargo.total(inst, step.cargo)
    if Cargo.count(inst, step.cargo, step.target or 'loaded') >= needed then
        Runtime.completeStep(inst, step)
    end
end

MissionComponents.register('cargo', {
    init = function(inst)
        inst.cargo = {}
        inst.carrying = {}
        for index = 1, #inst.def.cargo do
            local def = inst.def.cargo[index]
            local quantity = math.min(def.quantity or 1, #def.pieces)

            local order = {}
            for pieceIndex = 1, #def.pieces do order[pieceIndex] = pieceIndex end
            if def.randomizeCorrect ~= false then order = Utils.shuffle(order, Runtime.io.random) end
            local correct = {}
            for pick = 1, quantity do correct[order[pick]] = true end

            -- Iscas mostram outro valor da mesma lista de sorteio.
            local alternatives = {}
            local decoyVar = def.decoyVar and Utils.findById(inst.def.variables, def.decoyVar)
            if decoyVar and type(decoyVar.random) == 'table' then
                local current = inst.vars[decoyVar.id]
                for valueIndex = 1, #decoyVar.random do
                    if decoyVar.random[valueIndex] ~= current then alternatives[#alternatives + 1] = decoyVar.random[valueIndex] end
                end
            end

            local pieces = {}
            for pieceIndex = 1, #def.pieces do
                pieces[pieceIndex] = {
                    index = pieceIndex,
                    coords = Utils.deepCopy(def.pieces[pieceIndex]),
                    correct = correct[pieceIndex] == true,
                    decoyValue = not correct[pieceIndex] and Utils.pick(alternatives, Runtime.io.random) or nil,
                    state = 'world',
                    everPicked = false,
                    inspected = false,
                }
            end
            inst.cargo[def.id] = { def = def, revealed = def.revealed == true, pieces = pieces, total = quantity }
        end
    end,

    start = function(inst)
        for _, entry in pairs(inst.cargo) do
            for index = 1, #entry.pieces do spawnPiece(inst, entry, entry.pieces[index]) end
        end
    end,

    tick = function(inst)
        -- Quem caiu carregando larga a peça.
        for source in pairs(inst.carrying) do
            if Integrations.isDowned(source) then Cargo.dropCarried(inst, source) end
        end
    end,

    view = function(inst, view)
        view.carrying = {}
        view.vehicleCargo = {}
        local perVehicle = {}
        for cargoId, entry in pairs(inst.cargo) do
            local def = entry.def
            for index = 1, #entry.pieces do
                local piece = entry.pieces[index]
                if entry.revealed and piece.state == 'world' and piece.record then
                    view.cargo[#view.cargo + 1] = {
                        cargo = cargoId, index = index, netId = piece.record.netId, mode = def.mode,
                        name = def.label, label = piece.inspected and piece.label or nil,
                        needsInspect = def.inspect == true and not piece.inspected,
                    }
                elseif piece.state == 'loaded' and piece.vehicle then
                    local slot = perVehicle[piece.vehicle.netId]
                    if not slot then
                        slot = { netId = piece.vehicle.netId, count = 0, cargo = cargoId, name = def.label }
                        perVehicle[piece.vehicle.netId] = slot
                        view.vehicleCargo[#view.vehicleCargo + 1] = slot
                    end
                    slot.count = slot.count + 1
                end
            end
        end
        for source, carrying in pairs(inst.carrying) do
            local entry = inst.cargo[carrying.cargo]
            view.carrying[#view.carrying + 1] = {
                source = source, cargo = carrying.cargo, name = entry and entry.def.label or carrying.cargo,
            }
        end
    end,

    resolve = function(inst, parts)
        if parts[1] ~= 'cargo' or #parts ~= 3 then return false end
        if not inst.cargo[parts[2]] then return false end
        if parts[3] == 'total' then return true, Cargo.total(inst, parts[2]) end
        if parts[3] == 'picked' or parts[3] == 'loaded' or parts[3] == 'delivered' or parts[3] == 'carried' then
            return true, Cargo.count(inst, parts[2], parts[3])
        end
        return false
    end,

    participantLeft = function(inst, source, lastCoords)
        if inst.carrying[source] then Cargo.dropCarried(inst, source, lastCoords) end
    end,

    cleanup = function(inst)
        for source in pairs(inst.carrying) do setCarryState(source, nil) end
        inst.carrying = {}
    end,

    debug = function(inst, out)
        out.cargo = {}
        for cargoId, entry in pairs(inst.cargo) do
            out.cargo[#out.cargo + 1] = ('%s pegas=%d carregando=%d veículo=%d entregues=%d / %d'):format(
                cargoId, Cargo.count(inst, cargoId, 'picked'), Cargo.count(inst, cargoId, 'carried'),
                Cargo.count(inst, cargoId, 'loaded'), Cargo.count(inst, cargoId, 'delivered'), entry.total)
        end
    end,

    actions = {
        reveal_cargo = function(inst, action) Cargo.setRevealed(inst, action.cargo, true) end,
    },

    steps = {
        cargo = {
            start = function(inst, step)
                if step.reveal ~= false then Cargo.setRevealed(inst, step.cargo, true) end
                checkStep(inst, step)
            end,
            tick = checkStep,
            event = function(inst, step, _, name, payload)
                if payload.cargo == step.cargo and name:sub(1, 6) == 'cargo_' then checkStep(inst, step) end
            end,
            objective = function(inst, step)
                local needed = (step.count or 0) > 0 and step.count or Cargo.total(inst, step.cargo)
                return { progress = { current = math.min(needed, Cargo.count(inst, step.cargo, step.target or 'loaded')), max = needed } }
            end,
            view = function(inst, step, _, view)
                local entry = group(inst, step.cargo)
                if not entry or step.target ~= 'loaded' or entry.def.vehicleMode ~= 'mission' then return end
                local vehicle = inst.vehicles[entry.def.vehicleId]
                if vehicle and vehicle.record and not vehicle.destroyed then
                    view.blips[#view.blips + 1] = {
                        id = 'vehicle:' .. vehicle.id, netId = vehicle.record.netId, sprite = 67, color = 3,
                        label = vehicle.def.label,
                    }
                end
            end,
        },
    },
})

-- Pedidos do cliente ----------------------------------------------------------------------

---Um balde de rate limit por pedido: inspecionar e logo pegar é o uso normal.
---@param source integer
---@param instanceId any
---@param action string
---@return table? inst
---@return string? code
local function participantInstance(source, instanceId, action)
    if not Security.consume(source, 'cargo:' .. action, Config.rateLimits.cargo) then return nil, 'rate_limited' end
    if not Security.isInstanceId(instanceId) then return nil, 'invalid_id' end
    local inst = Runtime.get(instanceId)
    if not Runtime.isActive(inst) or not Runtime.isParticipant(inst, source) then return nil, 'no_instance' end
    return inst
end

---@param inst table
---@param cargoId any
---@param index any
---@return table? entry
---@return table? piece
local function worldPiece(inst, cargoId, index)
    if not Security.isKey(cargoId) or not Security.isIndex(index) then return nil end
    local entry = group(inst, cargoId)
    local piece = entry and entry.pieces[index]
    if not piece or not entry.revealed or piece.state ~= 'world' then return nil end
    return entry, piece
end

lib.callback.register('noir_missions:server:cargoInspect', function(source, instanceId, cargoId, index)
    local inst, code = participantInstance(source, instanceId, 'inspect')
    if not inst then return { ok = false, code = code } end
    local entry, piece = worldPiece(inst, cargoId, index)
    if not entry then return { ok = false, code = 'not_found' } end
    if not Security.isNear(source, pieceCoords(piece), Config.distances.cargoPickup) then return { ok = false, code = 'too_far' } end

    if not piece.inspected then
        piece.inspected = true
        local def = entry.def
        if piece.correct then
            piece.label = Runtime.render(inst, def.correctLabel or def.label)
        else
            piece.label = Template.render(def.correctLabel or def.label, function(name)
                if name == def.decoyVar then return piece.decoyValue or '???' end
                return Runtime.resolve(inst, name)
            end)
        end
        Runtime.markDirty(inst)
    end
    return { ok = true, label = piece.label }
end)

lib.callback.register('noir_missions:server:cargoPickup', function(source, instanceId, cargoId, index)
    local inst, code = participantInstance(source, instanceId, 'pickup')
    if not inst then return { ok = false, code = code } end
    local entry, piece = worldPiece(inst, cargoId, index)
    if not entry then return { ok = false, code = 'not_found' } end
    local def = entry.def
    if inst.carrying[source] then return { ok = false, code = 'already_carrying' } end
    if not Security.isNear(source, pieceCoords(piece), Config.distances.cargoPickup) then return { ok = false, code = 'too_far' } end
    if def.inspect and not piece.inspected then return { ok = false, code = 'inspect_first' } end
    if not piece.correct then return { ok = false, code = 'wrong_cargo' } end

    if def.mode == 'inventory' then
        local added, addCode = Integrations.addItem(source, def.item, def.amount or 1)
        if not added then return { ok = false, code = addCode or 'cannot_carry' } end
        piece.state = 'collected'
    elseif def.mode == 'interact' then
        piece.state = 'collected'
    else
        piece.state = 'carried'
        piece.carrier = source
        inst.carrying[source] = { cargo = def.id, index = piece.index }
        setCarryState(source, Cargo.carryString(def))
    end

    World.delete(piece.record)
    piece.record = nil
    piece.everPicked = true
    Runtime.emit(inst, 'cargo_picked', { cargo = def.id, actor = source })
    Runtime.markDirty(inst)
    return { ok = true, mode = def.mode }
end)

lib.callback.register('noir_missions:server:cargoDrop', function(source, instanceId)
    local inst, code = participantInstance(source, instanceId, 'drop')
    if not inst then return { ok = false, code = code } end
    if not Cargo.dropCarried(inst, source) then return { ok = false, code = 'not_carrying' } end
    return { ok = true }
end)

lib.callback.register('noir_missions:server:cargoLoad', function(source, instanceId, vehicleNetId)
    local inst, code = participantInstance(source, instanceId, 'load')
    if not inst then return { ok = false, code = code } end
    local carrying = inst.carrying[source]
    if not carrying then return { ok = false, code = 'not_carrying' } end
    if not Security.isNetId(vehicleNetId) then return { ok = false, code = 'invalid_id' } end
    local entity = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return { ok = false, code = 'not_found' }
    end
    local entry = group(inst, carrying.cargo)
    local piece = entry and entry.pieces[carrying.index]
    if not piece or piece.state ~= 'carried' then return { ok = false, code = 'not_carrying' } end

    local allowed, reason = vehicleAllowed(inst, entry.def, entity, vehicleNetId)
    if not allowed then return { ok = false, code = reason } end
    if not Security.isNear(source, GetEntityCoords(entity), Config.distances.vehicleLoad) then
        return { ok = false, code = 'too_far' }
    end
    local capacity = capacityOf(inst, vehicleNetId)
    if capacity and loadedIn(inst, vehicleNetId) >= capacity then return { ok = false, code = 'vehicle_full' } end

    inst.carrying[source] = nil
    setCarryState(source, nil)
    piece.state = 'loaded'
    piece.carrier = nil
    piece.vehicle = { entity = entity, netId = vehicleNetId }
    Runtime.emit(inst, 'cargo_loaded', { cargo = entry.def.id, actor = source })
    Runtime.markDirty(inst)
    return { ok = true }
end)

lib.callback.register('noir_missions:server:cargoUnload', function(source, instanceId, vehicleNetId)
    local inst, code = participantInstance(source, instanceId, 'unload')
    if not inst then return { ok = false, code = code } end
    if inst.carrying[source] then return { ok = false, code = 'already_carrying' } end
    if not Security.isNetId(vehicleNetId) then return { ok = false, code = 'invalid_id' } end
    local entity = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return { ok = false, code = 'not_found' } end
    if not Security.isNear(source, GetEntityCoords(entity), Config.distances.vehicleLoad) then
        return { ok = false, code = 'too_far' }
    end

    for cargoId, entry in pairs(inst.cargo) do
        if entry.def.mode == 'carry' then
            for index = #entry.pieces, 1, -1 do
                local piece = entry.pieces[index]
                if piece.state == 'loaded' and piece.vehicle and piece.vehicle.netId == vehicleNetId then
                    piece.state = 'carried'
                    piece.carrier = source
                    piece.vehicle = nil
                    inst.carrying[source] = { cargo = cargoId, index = index }
                    setCarryState(source, Cargo.carryString(entry.def))
                    Runtime.markDirty(inst)
                    return { ok = true }
                end
            end
        end
    end
    return { ok = false, code = 'vehicle_empty' }
end)

return Cargo
