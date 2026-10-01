---Registro das entidades de missão e o laço do dono de rede.
---
---Todo cliente recebe o registro (descrição de cada ped/veículo de missão). Só quem é dono de
---rede de uma entidade age sobre ela; quem passa a ser dono reaplica configuração e tarefa.
---É isso que mantém a missão de pé quando o jogador que estava perto se afasta ou cai.
---Fora isso, o laço só dorme: sem entidade de missão, nada roda.
local ClientConfig = require 'config.client'
local Ai = require 'client.npc.ai'

local Registry = {}

---@type table<integer, table>
local registry = {}
---@type table<integer, { entity: integer, version: integer, owned: boolean, maint: table }>
local applied = {}
local loopRunning = false

local STATE_INIT = 'noir_missions:init'

---@param netId integer
---@param desc table
local function step(netId, desc)
    if not NetworkDoesNetworkIdExist(netId) then
        if applied[netId] then applied[netId].owned = false end
        return
    end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return end

    local mine = NetworkGetEntityOwner(entity) == cache.playerId
    local current = applied[netId]
    if not mine then
        if current then current.owned = false end
        return
    end

    if desc.k ~= 'ped' then return end
    if IsPedDeadOrDying(entity, true) then return end

    if not current or not current.owned or current.entity ~= entity or current.version ~= desc.v then
        if not Entity(entity).state[STATE_INIT] then
            Ai.firstSetup(entity, desc.cfg or {})
            TriggerServerEvent('noir_missions:server:entityReady', netId)
        end
        Ai.apply(entity, desc)
        applied[netId] = { entity = entity, version = desc.v, owned = true, maint = {} }
        return
    end
    Ai.maintain(entity, desc, current.maint)
end

local function ensureLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        while next(registry) do
            for netId, desc in pairs(registry) do
                local ok, err = pcall(step, netId, desc)
                if not ok then lib.print.error(('[noir_missions] entidade %s: %s'):format(netId, err)) end
            end
            Wait(ClientConfig.entityLoopMs)
        end
        loopRunning = false
    end)
end

---@param patch table<integer|string, table|false>
function Registry.apply(patch)
    for key, desc in pairs(patch) do
        local netId = tonumber(key)
        if netId then
            if desc then
                registry[netId] = desc
            else
                registry[netId] = nil
                applied[netId] = nil
            end
        end
    end
    if next(registry) then ensureLoop() end
end

function Registry.load()
    local snapshot = lib.callback.await('noir_missions:server:entitySnapshot', false)
    registry = {}
    applied = {}
    if type(snapshot) == 'table' then Registry.apply(snapshot) end
end

---@return integer
function Registry.count()
    local total = 0
    for _ in pairs(registry) do total = total + 1 end
    return total
end

RegisterNetEvent('noir_missions:client:entities', function(patch)
    if source ~= 65535 or type(patch) ~= 'table' then return end
    Registry.apply(patch)
end)

return Registry
