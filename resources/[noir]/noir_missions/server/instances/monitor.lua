---Volta única do servidor sobre as instâncias ativas: posição dos participantes, zonas,
---tempo limite, ganchos `tick` dos componentes e do passo atual. Sem instância, a volta só
---dorme.
local Utils = require 'shared.utils.core'
local Config = require 'config.server'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'

local Monitor = {}

---@type table<integer, boolean> admins com o painel de debug ligado
local debugSubscribers = {}

---@param source integer
---@param enabled boolean
function Monitor.setDebug(source, enabled)
    debugSubscribers[source] = enabled or nil
end

---@param source integer
function Monitor.forget(source)
    debugSubscribers[source] = nil
end

---@param inst table
function Monitor.updatePositions(inst)
    for source in pairs(inst.participants) do
        local ped = GetPlayerPed(source)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            inst.positions[source] = GetEntityCoords(ped)
        end
    end
end

---@param inst table
local function tickZones(inst)
    inst.zoneState = inst.zoneState or {}
    for index = 1, #inst.def.zones do
        local zone = inst.def.zones[index]
        local inside = false
        for _, position in pairs(inst.positions) do
            if Utils.distance2d(position, zone.coords) <= zone.radius then
                inside = true
                break
            end
        end
        local before = inst.zoneState[zone.id] == true
        if inside ~= before then
            inst.zoneState[zone.id] = inside
            Runtime.emit(inst, inside and 'zone_enter' or 'zone_exit', { zone = zone.id })
            if inst.status ~= 'ACTIVE' then return end
        end
    end
end

---@param inst table
local function tickInstance(inst)
    Monitor.updatePositions(inst)

    local limit = inst.def.timeLimitMinutes or 0
    if limit > 0 and not inst.sandbox and Runtime.io.now() - inst.startedMs > limit * 60000 then
        Runtime.finish(inst, 'FAILED', 'time_limit')
        return
    end

    tickZones(inst)
    if inst.status ~= 'ACTIVE' then return end

    MissionComponents.each('tick', inst)
    if inst.status ~= 'ACTIVE' then return end

    local step = inst.step
    local handler = step and MissionComponents.step(step.type)
    if handler and handler.tick then
        local ok, err = pcall(handler.tick, inst, step, inst.stepState)
        if not ok then Runtime.io.log('error', ('#%d passo %s tick: %s'):format(inst.id, step.id, err)) end
    end

    -- Objetivo com contagem (carga 3/4, entrega) muda sem evento próprio às vezes; o retrato
    -- só sai se o texto mudou.
    if inst.status == 'ACTIVE' then
        local objective = Runtime.objective(inst)
        local signature = ('%s|%s|%s'):format(objective.text or '',
            objective.progress and objective.progress.current or '', objective.progress and objective.progress.max or '')
        if signature ~= inst.objectiveSignature then
            inst.objectiveSignature = signature
            Runtime.markDirty(inst)
        end
    end
end

Monitor.tickInstance = tickInstance

local function pushDebug()
    if next(debugSubscribers) == nil then return end
    for source in pairs(debugSubscribers) do
        local inst = Runtime.forPlayer(source)
        if not inst then
            for _, candidate in pairs(Runtime.instances) do
                inst = candidate
                break
            end
        end
        TriggerClientEvent('noir_missions:client:debug', source, inst and Runtime.debug(inst) or false)
    end
end

function Monitor.run()
    CreateThread(function()
        while true do
            local list = {}
            for _, inst in pairs(Runtime.instances) do list[#list + 1] = inst end
            for index = 1, #list do
                local inst = list[index]
                if inst.status == 'ACTIVE' then
                    local ok, err = pcall(tickInstance, inst)
                    if not ok then Runtime.io.log('error', ('#%d monitor: %s'):format(inst.id, err)) end
                end
            end
            pushDebug()
            Wait(Config.tickMs)
        end
    end)
end

return Monitor
