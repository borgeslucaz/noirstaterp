---Callbacks do editor. Todos exigem a ACE de admin no servidor; abrir a NUI no cliente não
---prova nada.
local Utils = require 'shared.utils.core'
local Definition = require 'shared.types.definition'
local Config = require 'config.server'
local Repository = require 'server.missions.repository'
local Runtime = require 'server.instances.runtime'
local Starter = require 'server.instances.starter'
local Monitor = require 'server.instances.monitor'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Offers = require 'server.offers'
local Npc = require 'server.components.npc'
local Vehicles = require 'server.components.vehicles'
local Reinforcement = require 'server.components.reinforcement'
local Chase = require 'server.components.chase'

local Editor = {}

---@param source integer
---@return boolean
function Editor.isAdmin(source)
    return Integrations.isAceAllowed(source, Config.adminAce)
end

---@param source integer
---@return string
local function actorName(source)
    local character = Integrations.getCharacter(source)
    return ('%s (%s)'):format(GetPlayerName(source) or '?', character and character.citizenId or '-')
end

---Registra um callback do editor com ACE e rate limit.
---@param name string
---@param handler fun(source: integer, ...): table
local function register(name, handler)
    lib.callback.register('noir_missions:server:' .. name, function(source, ...)
        if not Editor.isAdmin(source) then return { ok = false, code = 'not_allowed' } end
        if not Security.consume(source, 'editor:' .. name, Config.rateLimits.editor) then
            return { ok = false, code = 'rate_limited' }
        end
        local ok, result = pcall(handler, source, ...)
        if not ok then
            lib.print.error(('[noir_missions] editor %s: %s'):format(name, result))
            return { ok = false, code = 'internal_error' }
        end
        return result
    end)
end

register('editorOpen', function()
    return {
        ok = true,
        missions = Repository.summaries(),
        instances = Runtime.summaries(),
        items = Integrations.itemList(),
    }
end)

register('editorLoad', function(_, id)
    if not Utils.isId(id) then return { ok = false, code = 'invalid_id' } end
    local record = Repository.get(id)
    if not record then return { ok = false, code = 'not_found' } end
    local _, errors = Definition.normalize(record.draft)
    return { ok = true, record = Repository.recordInfo(record), definition = record.draft, errors = errors }
end)

register('editorCreate', function(source, id, name)
    local record, code = Repository.create(id, name, actorName(source))
    if not record then return { ok = false, code = code } end
    lib.print.info(('[noir_missions] %s criou a missão %s'):format(actorName(source), id))
    local _, errors = Definition.normalize(record.draft)
    return { ok = true, record = Repository.recordInfo(record), definition = record.draft, errors = errors }
end)

register('editorSave', function(source, definition)
    if type(definition) ~= 'table' then return { ok = false, code = 'invalid_definition' } end
    local record, code, errors, def = Repository.saveDraft(definition, actorName(source))
    if not record then return { ok = false, code = code, errors = errors } end
    return {
        ok = true, record = Repository.recordInfo(record), definition = def, errors = errors,
        missions = Repository.summaries(),
    }
end)

register('editorDuplicate', function(source, id, newId, newName)
    local record, code = Repository.duplicate(id, newId, newName, actorName(source))
    if not record then return { ok = false, code = code } end
    return { ok = true, missions = Repository.summaries() }
end)

register('editorDelete', function(source, id)
    local ok, code = Repository.remove(id)
    if not ok then return { ok = false, code = code } end
    lib.print.info(('[noir_missions] %s apagou a missão %s'):format(actorName(source), id))
    Offers.broadcastStarters()
    return { ok = true, missions = Repository.summaries() }
end)

register('editorSetStatus', function(source, id, status)
    local record, code, errors = Repository.setStatus(id, status, actorName(source))
    if not record then return { ok = false, code = code, errors = errors, missions = Repository.summaries() } end
    lib.print.info(('[noir_missions] %s mudou %s para %s'):format(actorName(source), id, status))
    Offers.broadcastStarters()
    return { ok = true, record = Repository.recordInfo(record), missions = Repository.summaries() }
end)

register('editorDraft', function(_, id)
    local record = Repository.get(id)
    if not record then return { ok = false, code = 'not_found' } end
    return { ok = true, definition = record.draft }
end)

register('editorInstances', function()
    return { ok = true, instances = Runtime.summaries() }
end)

register('editorStopInstance', function(source, instanceId)
    local inst = Security.isInstanceId(instanceId) and Runtime.get(instanceId) or nil
    if not inst then return { ok = false, code = 'no_instance', instances = Runtime.summaries() } end
    lib.print.info(('[noir_missions] %s encerrou a instância #%d'):format(actorName(source), instanceId))
    Runtime.finish(inst, 'CANCELLED', 'admin')
    return { ok = true, instances = Runtime.summaries() }
end)

register('editorTest', function(source, id, mode, step)
    if not Utils.isId(id) then return { ok = false, code = 'invalid_id' } end
    local current = Runtime.forPlayer(source)
    if current and current.test then Runtime.finish(current, 'CANCELLED', 'test_restart') end
    local inst, code, errors = Starter.start(id, {
        source = source, test = true, sandbox = mode == 'sandbox',
        fromStep = mode == 'step' and step or nil, origin = 'editor',
    })
    if not inst then return { ok = false, code = code, errors = errors } end
    return { ok = true, instanceId = inst.id }
end)

---Posição representativa de um passo, para "teleportar para o passo".
---@param def table
---@param inst table?
---@param step table
---@return table?
local function stepPosition(def, inst, step)
    if step.coords then return step.coords end
    if step.type == 'interact' then
        local interaction = Utils.findById(def.interactions, step.interaction)
        return interaction and interaction.coords
    end
    if step.type == 'cargo' then
        local cargo = Utils.findById(def.cargo, step.cargo)
        return cargo and cargo.pieces[1]
    end
    if step.type == 'eliminate' then
        local group = Utils.findById(def.pedGroups, step.groups and step.groups[1])
        return group and group.peds[1] and group.peds[1].coords
    end
    if step.type == 'deliver' then
        local place = inst and inst.places and inst.places[step.var or 'delivery_location']
        if place then return place.coords end
        local first = def.deliveryGroups[1]
        return first and first.points[1] and first.points[1].coords
    end
    return nil
end

register('editorTestTool', function(source, id, tool, ref)
    if not Utils.isId(id) then return { ok = false, code = 'invalid_id' } end
    local def, code, errors = Repository.draftDefinition(id)
    if not def then return { ok = false, code = code, errors = errors } end

    local inst = Runtime.forPlayer(source)
    if tool == 'reset' then
        if inst then Runtime.finish(inst, 'CANCELLED', 'test_reset') end
        return { ok = true }
    end

    if tool == 'teleport_step' then
        local step = Utils.findById(def.steps, ref)
        local coords = step and stepPosition(def, inst, step)
        if not coords then return { ok = false, code = 'not_found' } end
        TriggerClientEvent('noir_missions:client:teleport', source, coords)
        return { ok = true }
    end

    if tool == 'delivery' then
        for index = 1, #def.steps do
            if def.steps[index].type == 'deliver' then
                if inst then Runtime.finish(inst, 'CANCELLED', 'test_restart') end
                local started, startCode = Starter.start(id, { source = source, test = true, fromStep = def.steps[index].id, origin = 'editor' })
                return { ok = started ~= nil, code = startCode }
            end
        end
        return { ok = false, code = 'not_found' }
    end

    -- Ferramentas de criação usam a execução de teste em curso; sem ela, abrem um sandbox
    -- (missão sem passos) só para ter onde pendurar as entidades.
    if not inst or inst.missionId ~= id or not inst.test then
        if inst then Runtime.finish(inst, 'CANCELLED', 'test_restart') end
        local startCode
        inst, startCode = Starter.start(id, { source = source, test = true, sandbox = true, origin = 'editor' })
        if not inst then return { ok = false, code = startCode } end
    end

    if not Security.isKey(ref, 48) then return { ok = false, code = 'invalid_id' } end
    if tool == 'spawn_group' then
        return { ok = Npc.spawnGroup(inst, ref) }
    elseif tool == 'spawn_vehicle' then
        return { ok = Vehicles.spawn(inst, ref) ~= nil }
    elseif tool == 'spawn_prop' then
        Vehicles.spawnProp(inst, ref)
        return { ok = true }
    elseif tool == 'reinforcement' then
        return { ok = Reinforcement.send(inst, ref) ~= nil }
    elseif tool == 'chase' then
        local chase = Utils.findById(inst.def.chases, ref)
        if not chase then return { ok = false, code = 'not_found' } end
        Chase.start(inst, chase, 0, 0)
        return { ok = true }
    end
    return { ok = false, code = 'invalid_id' }
end)

register('debugSubscribe', function(source, enabled)
    Monitor.setDebug(source, enabled == true)
    return { ok = true }
end)

return Editor
