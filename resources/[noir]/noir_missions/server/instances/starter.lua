---Começar uma execução: escolhe a definição (publicada, ou rascunho em teste), confere limite,
---cooldown, gang e jogadores, cria a instância com uma cópia da definição e dá a partida.
local Config = require 'config.server'
local Repository = require 'server.missions.repository'
local Runtime = require 'server.instances.runtime'
local Participants = require 'server.participants.participants'
local Monitor = require 'server.instances.monitor'
local Integrations = require 'server.integrations'

local Starter = {}

---@class StartOptions
---@field source integer quem começa (líder)
---@field participants? integer[] lista explícita (export)
---@field test? boolean usa o rascunho, sem requisitos, sem cooldown e sem recompensa
---@field sandbox? boolean teste sem passos, só para criar entidades
---@field fromStep? string teste a partir de um passo
---@field origin? string

---Confere se a missão pode ser oferecida/começada por esta pessoa, sem criar nada.
---@param missionId string
---@param source integer
---@return table? definition
---@return string? code
function Starter.check(missionId, source)
    local def, code = Repository.publishedDefinition(missionId)
    if not def then return nil, code end
    if Runtime.forPlayer(source) then return nil, 'busy' end
    if Runtime.count() >= Config.maxInstances then return nil, 'max_instances' end
    if Repository.cooldownRemaining(missionId) > 0 then return nil, 'cooldown' end
    local _, gangCode = Participants.checkGang(def, source)
    if gangCode then return nil, gangCode end
    return def
end

---@param missionId string
---@param opts StartOptions
---@return table? inst
---@return string? code
---@return table? errors
function Starter.start(missionId, opts)
    local leader = opts.source
    if type(leader) ~= 'number' or not GetPlayerName(leader) then return nil, 'invalid_player' end

    local def, code, errors
    if opts.test then
        def, code, errors = Repository.draftDefinition(missionId)
        if not def then return nil, code, errors end
        if Runtime.forPlayer(leader) then return nil, 'busy' end
        if Runtime.count() >= Config.maxInstances then return nil, 'max_instances' end
    else
        def, code = Starter.check(missionId, leader)
        if not def then return nil, code end
    end

    local list
    if opts.test then
        list = { leader }
    else
        list = Participants.gather(def, leader, opts.participants)
        if #list < (def.minPlayers or 1) then return nil, 'not_enough_players' end
    end

    local inst = Runtime.create(def, { test = opts.test, sandbox = opts.sandbox, origin = opts.origin })
    for index = 1, #list do
        local character = Integrations.getCharacter(list[index])
        if character then Runtime.addParticipant(inst, list[index], character) end
    end
    if inst.leader == nil then
        Runtime.finish(inst, 'CANCELLED', 'no_participants')
        return nil, 'not_enough_players'
    end
    Monitor.updatePositions(inst)

    if not opts.test then Repository.startCooldown(missionId, def.cooldownMinutes) end

    for index = 1, #list do
        if inst.participants[list[index]] then
            Integrations.notify(list[index], ('Missão iniciada: %s'):format(def.name), 'success')
        end
    end

    Runtime.start(inst, opts.fromStep)
    TriggerEvent('noir_missions:missionStarted', inst.id, missionId, Runtime.participantList(inst))
    Runtime.markDirty(inst)
    return inst
end

return Starter
