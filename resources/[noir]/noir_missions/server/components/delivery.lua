---Entregas: sortear o local num grupo e o passo "Entregar".
---
---"Sortear entrega" guarda o local em `inst.places[variável]` e o nome dele na variável, para
---o texto `{{delivery_location}}` mostrar "Cypress Flats" e o passo achar a coordenada.
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Integrations = require 'server.integrations'
local Cargo = require 'server.components.cargo'

local Delivery = {}

---@param inst table
---@param groupId string
---@param var string
---@return table? place
function Delivery.pick(inst, groupId, var)
    local deliveryGroup = Utils.findById(inst.def.deliveryGroups, groupId)
    if not deliveryGroup or #deliveryGroup.points == 0 then return nil end
    local point = Utils.pick(deliveryGroup.points, Runtime.io.random)
    local place = { coords = point.coords, radius = point.radius or 8, label = point.label, group = groupId }
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
        return { coords = step.coords, radius = step.radius or 8, label = step.blipLabel }
    end
    return inst.places[step.var or 'delivery_location']
end

---@param inst table
---@param step table
---@param state table
---@param place table
local function spawnReceiver(inst, step, state, place)
    if not step.npcModel or state.npc then return end
    local offset = step.npcOffset or 3
    local heading = math.rad(place.coords.w or 0.0)
    local coords = {
        x = place.coords.x - math.sin(heading) * offset,
        y = place.coords.y + math.cos(heading) * offset,
        z = place.coords.z,
        w = ((place.coords.w or 0.0) + 180.0) % 360,
    }
    state.npc = World.createPed(inst, 'delivery:' .. step.id, {
        model = step.npcModel, movement = 'scenario', scenario = 'WORLD_HUMAN_SMOKING', health = 200,
    }, coords, { n = 'idle' })
end

---@param inst table
---@param step table
---@param state table
local function say(inst, step, state)
    if state.said or not state.npc or type(step.npcText) ~= 'table' or #step.npcText == 0 then return end
    state.said = true
    Runtime.broadcast(inst, 'noir_missions:client:pedSay', state.npc.netId, step.npcText, 'neutral')
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
            if Utils.distance2d(coords, place.coords) <= radius + 2.0 and entry.count > bestCount then
                best, bestCount = entry, entry.count
            end
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
                if have < need then
                    state.holdSince = nil
                    return
                end
                local now = Runtime.io.now()
                state.holdSince = state.holdSince or now
                if now - state.holdSince < (step.holdSeconds or 0) * 1000 then return end
                consume(inst, step, need, detail)
                Runtime.completeStep(inst, step)
            end,
            stop = function(inst, _, state)
                -- O NPC que recebe vai embora junto com o passo, depois de um tempo.
                if state.npc then
                    local npc = state.npc
                    World.setTask(npc, { n = 'wander' })
                    Runtime.io.setTimeout(20000, function() World.delete(npc) end)
                end
            end,
            objective = function(inst, step, state)
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
                    id = 'step:' .. step.id, coords = place.coords, sprite = 501, color = 2,
                    label = Runtime.render(inst, step.blipLabel or 'Entrega'), route = true, radius = place.radius,
                }
                view.deliveries[#view.deliveries + 1] = { coords = place.coords, radius = place.radius }
            end,
        },
    },
})

return Delivery
