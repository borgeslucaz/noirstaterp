---Grupos de NPC: criação, hostilidade, aviso, morte. Passo "Neutralizar NPCs".
---
---Grupo é a unidade de comportamento: quando um fica hostil, o grupo inteiro fica. Tripulações
---de reforço e perseguição também entram aqui (kind = 'crew'), para morte e combate seguirem a
---mesma regra; só os grupos da definição disparam eventos `group_*`.
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Security = require 'server.security'
local Config = require 'config.server'

local Npc = {}

local WARN_COOLDOWN_MS = 15000 -- entre uma fala e outra para o mesmo jogador
local WARN_RELEASE_MS = 3000   -- todos fora do raio por este tempo: o guarda abaixa a arma

---@param inst table
---@param key string
---@param def table?
---@param kind 'group'|'crew'
---@return table group
function Npc.ensureGroup(inst, key, def, kind)
    local group = inst.groups[key]
    if group then return group end
    group = {
        key = key, id = def and def.id or key, def = def, kind = kind,
        spawned = false, hostile = false, peds = {}, emittedDead = false, warnedAt = {},
    }
    inst.groups[key] = group
    return group
end

---@param group table
---@return integer alive
---@return integer dead
local function counts(group)
    local alive, dead = 0, 0
    for index = 1, #group.peds do
        if group.peds[index].dead then dead = dead + 1 else alive = alive + 1 end
    end
    return alive, dead
end
Npc.counts = counts

---@param inst table
---@param group table
---@return boolean
local function alarmActive(inst, group)
    local def = group.def
    if not def or not def.hostileOnAlarm then return false end
    local value = Runtime.resolve(inst, def.alarmVar or 'alarm_active')
    return value ~= nil and value ~= false and value ~= 0 and value ~= 'false' and value ~= ''
end

---@param inst table
---@param key string
---@param hostile boolean
---@param reason? string
function Npc.setHostile(inst, key, hostile, reason)
    local group = inst.groups[key]
    if not group or group.hostile == hostile then return end
    group.hostile = hostile
    group.warning = nil
    for index = 1, #group.peds do
        local record = group.peds[index]
        if not record.dead then
            local task = World.getTask(record)
            -- Quem está dirigindo continua dirigindo; a tripulação decide a hora de descer.
            if not (task and (task.n == 'drive_to' or task.n == 'chase' or task.n == 'ride' or task.n == 'driveby')) then
                World.setTask(record, hostile and { n = 'combat' } or { n = 'idle' })
            end
        end
    end
    if group.kind == 'group' then
        Runtime.emit(inst, 'group_hostile', { group = group.id, reason = reason })
        if hostile and group.def and group.def.alarmOnHostile then
            Runtime.setVar(inst, group.def.alarmVar or 'alarm_active', true)
        end
    end
    Runtime.markDirty(inst)
end

---@param inst table
---@param groupId string
---@return boolean
function Npc.spawnGroup(inst, groupId)
    local def = Utils.findById(inst.def.pedGroups, groupId)
    if not def then return false end
    local key = 'group:' .. groupId
    local group = Npc.ensureGroup(inst, key, def, 'group')
    if group.spawned then return true end
    group.spawned = true
    group.hostile = def.behavior == 'hostile' or alarmActive(inst, group)
    local task = group.hostile and { n = 'combat' } or { n = 'idle' }
    for index = 1, #def.peds do
        local ped = def.peds[index]
        local record = World.createPed(inst, key, ped, ped.coords, task)
        if record then
            record.anchor = vector3(ped.coords.x, ped.coords.y, ped.coords.z)
            group.peds[#group.peds + 1] = record
        end
    end
    Runtime.markDirty(inst)
    return true
end

---@param inst table
---@param groupId string
function Npc.despawnGroup(inst, groupId)
    local group = inst.groups['group:' .. groupId]
    if not group then return end
    for index = 1, #group.peds do World.delete(group.peds[index]) end
    inst.groups['group:' .. groupId] = nil
    Runtime.markDirty(inst)
end

---Coloca um ped já criado num grupo (tripulação de reforço/perseguição).
---@param inst table
---@param key string
---@param record table
function Npc.addPed(inst, key, record)
    local group = Npc.ensureGroup(inst, key, nil, 'crew')
    group.spawned = true
    group.peds[#group.peds + 1] = record
end

---@param inst table
---@param key string
---@return integer
function Npc.aliveCount(inst, key)
    local group = inst.groups[key]
    if not group then return 0 end
    return (counts(group))
end

---Aviso de guarda. Com alguém dentro do raio, o grupo inteiro aponta a arma — cada guarda
---para o intruso mais perto dele — e continua apontando enquanto houver alguém lá; sai todo
---mundo, abaixam depois de um instante. Só o guarda mais perto fala, com intervalo por
---jogador. Quem decide hostilidade continua sendo zona, tiro, dano e alarme.
---@param inst table
---@param group table
---@param intruders table<integer, vector3> participantes dentro do raio de algum guarda
local function tickWarning(inst, group, intruders)
    local now = Runtime.io.now()

    if next(intruders) == nil then
        if group.warning and now - group.warning.lastSeen > WARN_RELEASE_MS then
            for record in pairs(group.warning.targets) do
                if not record.dead then World.setTask(record, { n = 'idle' }) end
            end
            group.warning = nil
        end
        return
    end

    local warning = group.warning or { targets = {} }
    group.warning = warning
    warning.lastSeen = now

    local speaker, speakerDistance, speakerTarget, speakerPosition
    for index = 1, #group.peds do
        local record = group.peds[index]
        local coords = not record.dead and World.coords(record)
        if coords then
            local target, targetDistance, targetPosition
            for source, position in pairs(intruders) do
                local distance = #(coords - position)
                if not targetDistance or distance < targetDistance then
                    target, targetDistance, targetPosition = source, distance, position
                end
            end
            if warning.targets[record] ~= target then
                warning.targets[record] = target
                World.setTask(record, { n = 'warn', target = target })
            end
            if not speakerDistance or targetDistance < speakerDistance then
                speaker, speakerDistance, speakerTarget, speakerPosition = record, targetDistance, target, targetPosition
            end
        end
    end

    if speaker and (group.warnedAt[speakerTarget] or 0) <= now then
        group.warnedAt[speakerTarget] = now + WARN_COOLDOWN_MS
        local texts = group.def.warnText
        if type(texts) == 'table' and #texts > 0 then
            for participant, coords in pairs(inst.positions) do
                if #(coords - speakerPosition) <= 40.0 then
                    Runtime.io.send(participant, 'noir_missions:client:pedSay', speaker.netId, texts, 'alert')
                end
            end
        end
    end
end

---@param inst table
---@param group table
local function tickGroup(inst, group)
    local def = group.def
    local anyDamaged = false

    for index = 1, #group.peds do
        local record = group.peds[index]
        if not record.dead then
            local state, health = World.pedState(record)
            if state == 'dead' then
                record.dead = true
                if group.kind == 'group' then Runtime.emit(inst, 'ped_killed', { group = group.id }) end
                anyDamaged = true
            elseif state == 'alive' and health then
                -- Dano só conta depois que o dono aplicou a vida configurada; antes disso a
                -- vida ainda é a padrão do modelo, e cair para a configurada não é tiro.
                if Entity(record.entity).state[World.STATE_INIT] then
                    if record.maxHealth and health < record.maxHealth - 2 then anyDamaged = true end
                    if not record.maxHealth or health > record.maxHealth then record.maxHealth = health end
                end
            end
        end
    end

    if inst.status ~= 'ACTIVE' then return end

    local alive = counts(group)
    if alive == 0 and #group.peds > 0 and not group.emittedDead then
        group.emittedDead = true
        if group.kind == 'group' then Runtime.emit(inst, 'group_dead', { group = group.id }) end
        Runtime.markDirty(inst)
        return
    end

    if group.kind ~= 'group' or group.hostile or not def then return end

    if anyDamaged and def.hostileOnDamage ~= false then
        Npc.setHostile(inst, group.key, true, 'damage')
        return
    end

    if def.hostileZone then
        local zone = Utils.findById(inst.def.zones, def.hostileZone)
        if zone then
            for _, position in pairs(inst.positions) do
                if Utils.distance2d(position, zone.coords) <= zone.radius then
                    Npc.setHostile(inst, group.key, true, 'zone')
                    return
                end
            end
        end
    end

    if def.behavior == 'guard' and (def.warnRadius or 0) > 0 then
        local intruders = {}
        for source, position in pairs(inst.positions) do
            for index = 1, #group.peds do
                local record = group.peds[index]
                if not record.dead and record.anchor and #(record.anchor - position) <= def.warnRadius then
                    intruders[source] = position
                    break
                end
            end
        end
        tickWarning(inst, group, intruders)
    end
end

---Centro aproximado de cada grupo criado, para o cliente saber onde um tiro conta.
---@param inst table
---@return table[]
function Npc.areas(inst)
    local areas = {}
    for _, group in pairs(inst.groups) do
        if group.kind == 'group' and group.spawned and group.def then
            local record = group.peds[1]
            if record and record.anchor then
                areas[#areas + 1] = {
                    x = record.anchor.x, y = record.anchor.y, z = record.anchor.z,
                    r = math.min(Config.distances.missionArea, (group.def.shotRadius or 60) + 30),
                }
            end
        end
    end
    return areas
end

MissionComponents.register('npc', {
    init = function(inst)
        inst.groups = {}
    end,

    start = function(inst)
        for index = 1, #inst.def.pedGroups do
            if inst.def.pedGroups[index].spawnOnStart then Npc.spawnGroup(inst, inst.def.pedGroups[index].id) end
        end
    end,

    tick = function(inst)
        for _, group in pairs(inst.groups) do
            if inst.status ~= 'ACTIVE' then return end
            tickGroup(inst, group)
        end
    end,

    event = function(inst, name, payload)
        if name == 'var_changed' then
            for _, group in pairs(inst.groups) do
                if group.kind == 'group' and group.spawned and not group.hostile and group.def
                    and payload.var == (group.def.alarmVar or 'alarm_active') and alarmActive(inst, group) then
                    Npc.setHostile(inst, group.key, true, 'alarm')
                end
            end
        elseif name == 'shot_fired' and payload.coords then
            for _, group in pairs(inst.groups) do
                if group.kind == 'group' and group.spawned and not group.hostile and group.def
                    and group.def.hostileOnShot ~= false then
                    for index = 1, #group.peds do
                        local record = group.peds[index]
                        if not record.dead and record.anchor
                            and #(record.anchor - payload.coords) <= (group.def.shotRadius or 60) then
                            Npc.setHostile(inst, group.key, true, 'shot')
                            break
                        end
                    end
                end
            end
        end
    end,

    resolve = function(inst, parts)
        if parts[1] ~= 'group' or #parts ~= 3 then return false end
        local group = inst.groups['group:' .. parts[2]]
        local field = parts[3]
        if not group then
            if field == 'alive' or field == 'dead' then return true, 0 end
            if field == 'hostile' then return true, false end
            return false
        end
        local alive, dead = counts(group)
        if field == 'alive' then return true, alive end
        if field == 'dead' then return true, dead end
        if field == 'hostile' then return true, group.hostile end
        return false
    end,

    areas = function(inst, list)
        for _, area in ipairs(Npc.areas(inst)) do list[#list + 1] = area end
    end,

    view = function(inst, view)
        view.areas = MissionComponents.areas(inst)
    end,

    debug = function(inst, out)
        out.groups = {}
        for key, group in pairs(inst.groups) do
            local alive, dead = counts(group)
            out.groups[#out.groups + 1] = ('%s vivos=%d mortos=%d hostil=%s'):format(key, alive, dead, tostring(group.hostile))
        end
    end,

    actions = {
        spawn_group = function(inst, action)
            Npc.spawnGroup(inst, action.group)
        end,
        despawn_group = function(inst, action)
            Npc.despawnGroup(inst, action.group)
        end,
        set_hostile = function(inst, action)
            local key = 'group:' .. action.group
            if not inst.groups[key] then Npc.spawnGroup(inst, action.group) end
            Npc.setHostile(inst, key, action.hostile ~= false, 'action')
        end,
    },

    steps = {
        eliminate = {
            start = function(inst, step)
                for index = 1, #(step.groups or {}) do Npc.spawnGroup(inst, step.groups[index]) end
            end,
            tick = function(inst, step)
                for index = 1, #(step.groups or {}) do
                    local group = inst.groups['group:' .. step.groups[index]]
                    if not group or counts(group) > 0 then return end
                end
                Runtime.completeStep(inst, step)
            end,
            objective = function(inst, step)
                local total, dead = 0, 0
                for index = 1, #(step.groups or {}) do
                    local group = inst.groups['group:' .. step.groups[index]]
                    if group then
                        local a, d = counts(group)
                        total, dead = total + a + d, dead + d
                    end
                end
                return { progress = { current = dead, max = total } }
            end,
        },
    },
})

-- Tiro do participante dentro da área da missão (o cliente percebe pela munição que caiu).
-- Só piora a situação de quem atirou, então o cliente não ganha nada mentindo; mesmo assim a
-- posição usada é a do servidor.
RegisterNetEvent('noir_missions:server:shot', function()
    local src = source
    local inst = Runtime.forPlayer(src)
    if not Runtime.isActive(inst) then return end
    if not Security.consume(src, 'shot') then return end
    local coords = Security.playerCoords(src)
    if not coords then return end
    local near = false
    for _, area in ipairs(MissionComponents.areas(inst)) do
        if #(coords - vector3(area.x, area.y, area.z)) <= area.r then
            near = true
            break
        end
    end
    if not near then return end
    Runtime.emit(inst, 'shot_fired', { coords = coords, actor = src })
end)

return Npc
