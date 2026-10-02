---Entregas: sortear o local num grupo e o passo "Entregar".
---
---"Sortear entrega" guarda o local em `inst.places[variável]` e o nome dele na variável, para
---o texto `{{delivery_location}}` mostrar "Cypress Flats" e o passo achar a coordenada.
---
---Entrega de veículo com passagem para o NPC (como no noir_gathering): a van para na vaga, todo
---mundo desce, o NPC que recebe entra, sai dirigindo e some depois de um tempo, longe da vista.
---A van e o NPC saem da instância nessa hora, então o fim da missão não os apaga na cara de
---ninguém.
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Integrations = require 'server.integrations'
local Cargo = require 'server.components.cargo'
local Vehicles = require 'server.components.vehicles'

local Delivery = {}

local DEFAULT_DRIVER = 'g_m_m_chicold_01'
local ENTER_TIMEOUT_MS = 15000

---@param inst table
---@param groupId string
---@param var string
---@return table? place
function Delivery.pick(inst, groupId, var)
    local deliveryGroup = Utils.findById(inst.def.deliveryGroups, groupId)
    if not deliveryGroup or #deliveryGroup.points == 0 then return nil end
    local point = Utils.pick(deliveryGroup.points, Runtime.io.random)
    local place = {
        coords = point.coords, radius = point.radius or 8, label = point.label, group = groupId,
        parkCoords = point.parkCoords, npcCoords = point.npcCoords,
    }
    inst.places[var] = place
    Runtime.setVar(inst, var, point.label)
    Runtime.markDirty(inst)
    return place
end

---@param inst table
---@param step table
---@return table? place
local function placeOf(inst, step)
    if step.source == 'fixed' then
        if not step.coords then return nil end
        return {
            coords = step.coords, radius = step.radius or 8, label = step.blipLabel,
            parkCoords = step.parkCoords, npcCoords = step.npcCoords,
        }
    end
    return inst.places[step.var or 'delivery_location']
end

---Onde o NPC espera: ponto marcado, ou alguns metros à frente do local, virado para ele.
---@param step table
---@param place table
---@return table coords
local function receiverSpot(step, place)
    if place.npcCoords then return place.npcCoords end
    local offset = step.npcOffset or 3
    local heading = math.rad(place.coords.w or 0.0)
    return {
        x = place.coords.x - math.sin(heading) * offset,
        y = place.coords.y + math.cos(heading) * offset,
        z = place.coords.z,
        w = ((place.coords.w or 0.0) + 180.0) % 360,
    }
end

---@param inst table
---@param step table
---@param state table
---@param place table
local function spawnReceiver(inst, step, state, place)
    if not step.npcModel or state.npc then return end
    state.npc = World.createPed(inst, 'delivery:' .. step.id, {
        model = step.npcModel, movement = 'scenario', scenario = 'WORLD_HUMAN_SMOKING', health = 200,
    }, receiverSpot(step, place), { n = 'idle' })
end

---@param inst table
---@param step table
---@param state table
local function say(inst, step, state)
    if state.said or not state.npc or type(step.npcText) ~= 'table' or #step.npcText == 0 then return end
    state.said = true
    Runtime.broadcast(inst, 'noir_missions:client:pedSay', state.npc.netId, step.npcText, 'neutral')
end

---Algum jogador dentro do veículo?
---@param entity integer
---@return boolean
local function occupied(entity)
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(entity, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

---Quanto está no local, segundo o modo do passo.
---@param inst table
---@param step table
---@param place table
---@return integer have
---@return integer need
---@return table? detail
local function measure(inst, step, place)
    local radius = place.radius or 8
    if step.mode == 'vehicle' then
        local need = (step.required or 0) > 0 and step.required or Cargo.total(inst, step.cargo)
        local best, bestCount = nil, 0
        for _, entry in ipairs(Cargo.loadedByVehicle(inst, step.cargo)) do
            local coords = GetEntityCoords(entry.record.entity)
            local inPlace
            if place.parkCoords then
                -- Com vaga marcada, tem que estar na vaga, não só no raio.
                inPlace = Utils.distance2d(coords, place.parkCoords) <= (step.parkRadius or 4)
            else
                inPlace = Utils.distance2d(coords, place.coords) <= radius + 2.0
            end
            if inPlace and entry.count > bestCount then best, bestCount = entry, entry.count end
        end
        return bestCount, need, best
    end
    if step.mode == 'item' then
        local need = math.max(1, step.required or 1)
        local have, holders = 0, {}
        for source, position in pairs(inst.positions) do
            if Utils.distance2d(position, place.coords) <= radius then
                local count = Integrations.itemCount(source, step.item)
                if count > 0 then
                    have = have + count
                    holders[#holders + 1] = { source = source, count = count }
                end
            end
        end
        return have, need, holders
    end
    -- presença
    for _, position in pairs(inst.positions) do
        if Utils.distance2d(position, place.coords) <= radius then return 1, 1, nil end
    end
    return 0, 1, nil
end

---@param inst table
---@param step table
---@param need integer
---@param detail table?
local function consume(inst, step, need, detail)
    if not step.consume then return end
    if step.mode == 'vehicle' and detail then
        Cargo.deliverFromVehicle(inst, step.cargo, detail.netId, need)
    elseif step.mode == 'item' and type(detail) == 'table' then
        local remaining = need
        for index = 1, #detail do
            if remaining <= 0 then break end
            local take = math.min(remaining, detail[index].count)
            if Integrations.removeItem(detail[index].source, step.item, take) then remaining = remaining - take end
        end
    end
end

---A van vai embora com o NPC. Só veículo DA MISSÃO: carro de jogador nunca é levado.
---@param inst table
---@param step table
---@param state table
---@param place table
---@param vehicleNetId integer
---@return boolean handed
local function handoff(inst, step, state, place, vehicleNetId)
    local vehicle = Vehicles.byNetId(inst, vehicleNetId)
    if not vehicle or not World.exists(vehicle.record) then return false end

    local driver = state.npc
    if not driver or not World.exists(driver) then
        driver = World.createPed(inst, 'delivery:' .. step.id, {
            model = step.npcModel or DEFAULT_DRIVER, health = 200,
        }, receiverSpot(step, place), { n = 'idle' })
        if not driver then return false end
    end
    state.npc = nil

    -- Sai da instância: o fim da missão não apaga os dois; quem apaga é o tempo.
    Vehicles.forget(inst, vehicle.id)
    SetVehicleDoorsLocked(vehicle.record.entity, 1)
    World.setTask(driver, { n = 'drive_off', veh = vehicle.record.netId })
    local seconds = step.driveAwaySeconds or 45
    World.release(vehicle.record, seconds)
    World.release(driver, seconds)

    -- Se o NPC não conseguir entrar a tempo (porta obstruída), vai direto para o banco.
    local vehicleEntity, driverEntity = vehicle.record.entity, driver.entity
    SetTimeout(ENTER_TIMEOUT_MS, function()
        if DoesEntityExist(driverEntity) and DoesEntityExist(vehicleEntity)
            and GetPedInVehicleSeat(vehicleEntity, -1) == 0 then
            TaskWarpPedIntoVehicle(driverEntity, vehicleEntity, -1)
        end
    end)
    Runtime.trace(inst, ('entrega: %s levou o veículo %s (some em %ds)'):format(step.id, vehicle.id, seconds))
    return true
end

MissionComponents.register('delivery', {
    init = function(inst)
        inst.places = {}
    end,

    actions = {
        pick_delivery = function(inst, action)
            Delivery.pick(inst, action.group, action.var or 'delivery_location')
        end,
    },

    steps = {
        deliver = {
            start = function(inst, step, state)
                local place = placeOf(inst, step)
                if not place and step.source ~= 'fixed' then
                    -- Ninguém sorteou antes: sorteia do primeiro grupo de entrega, para a missão
                    -- não travar por um esquecimento de configuração.
                    local first = inst.def.deliveryGroups[1]
                    place = first and Delivery.pick(inst, first.id, step.var or 'delivery_location')
                end
                if not place then
                    Runtime.io.log('error', ('#%d passo %s sem local de entrega'):format(inst.id, step.id))
                    return
                end
                state.place = place
                spawnReceiver(inst, step, state, place)
            end,
            tick = function(inst, step, state)
                local place = state.place or placeOf(inst, step)
                if not place then return end
                state.place = place
                spawnReceiver(inst, step, state, place)

                for _, position in pairs(inst.positions) do
                    if Utils.distance2d(position, place.coords) <= (place.radius or 8) * 3 then
                        say(inst, step, state)
                        break
                    end
                end

                local have, need, detail = measure(inst, step, place)
                local waitingExit = false
                if have >= need and step.mode == 'vehicle' and step.handoff ~= false and detail then
                    -- Na vaga, mas com gente dentro: o NPC só entra com a van vazia.
                    waitingExit = occupied(detail.record.entity)
                end
                if waitingExit ~= (state.waitingExit == true) then
                    state.waitingExit = waitingExit
                    Runtime.markDirty(inst)
                end
                if have < need or waitingExit then
                    state.holdSince = nil
                    return
                end
                local now = Runtime.io.now()
                state.holdSince = state.holdSince or now
                if now - state.holdSince < (step.holdSeconds or 0) * 1000 then return end
                consume(inst, step, need, detail)
                if step.mode == 'vehicle' and step.handoff ~= false and detail then
                    handoff(inst, step, state, place, detail.netId)
                end
                Runtime.completeStep(inst, step)
            end,
            stop = function(inst, _, state)
                -- NPC que não levou nada vai embora a pé.
                if state.npc then
                    local npc = state.npc
                    World.setTask(npc, { n = 'wander' })
                    World.release(npc, 20)
                    state.npc = nil
                end
            end,
            objective = function(inst, step, state)
                if state.waitingExit then return { text = 'Desçam do veículo para entregar.' } end
                if step.mode ~= 'vehicle' then return nil end
                local place = state.place
                local have = place and select(1, measure(inst, step, place)) or 0
                local need = (step.required or 0) > 0 and step.required or Cargo.total(inst, step.cargo)
                if have == 0 then return nil end
                return { progress = { current = math.min(have, need), max = need } }
            end,
            view = function(inst, step, state, view)
                local place = state.place or placeOf(inst, step)
                if not place then return end
                view.blips[#view.blips + 1] = {
                    id = 'step:' .. step.id, coords = place.parkCoords or place.coords, sprite = 501, color = 2,
                    label = Runtime.render(inst, step.blipLabel or 'Entrega'), route = true,
                    radius = not place.parkCoords and place.radius or nil,
                }
                view.deliveries[#view.deliveries + 1] = {
                    coords = place.coords, radius = place.radius,
                    park = place.parkCoords, parkRadius = step.parkRadius or 4,
                }
            end,
        },
    },
})

return Delivery
