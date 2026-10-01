---Quem entra numa execução: quem aceitou e, em missão de gang, os membros da mesma gang que
---estão por perto. Gang vem do bridge (noir_gangs por trás), nunca da coluna `players.gang`.
local Runtime = require 'server.instances.runtime'
local Integrations = require 'server.integrations'
local Security = require 'server.security'

local Participants = {}

---@param source integer
---@return boolean
local function available(source)
    return GetPlayerName(source) ~= nil and Runtime.forPlayer(source) == nil
        and Integrations.getCharacter(source) ~= nil
end

---Requisito de gang de quem aceitou.
---@param def table
---@param source integer
---@return table? gang
---@return string? code
function Participants.checkGang(def, source)
    if not def.gangRequired then return nil end
    local gang = Integrations.getGang(source)
    if not gang then return nil, 'gang_required' end
    if gang.grade < (def.gangMinGrade or 0) then return nil, 'gang_grade' end
    return gang
end

---Monta a lista de participantes. Com lista explícita (export), valida cada um; sem lista,
---puxa membros da gang de quem aceitou que estão no raio.
---@param def table
---@param leader integer
---@param explicit? integer[]
---@return integer[] participants
function Participants.gather(def, leader, explicit)
    local list, seen = {}, {}
    local max = def.maxPlayers or 4

    local function add(source)
        if #list >= max or seen[source] or not available(source) then return end
        seen[source] = true
        list[#list + 1] = source
    end

    add(leader)
    if explicit then
        for index = 1, #explicit do
            if type(explicit[index]) == 'number' then add(explicit[index]) end
        end
        return list
    end

    if not def.gangRequired then return list end
    local leaderGang = Integrations.getGang(leader)
    if not leaderGang then return list end
    local radius = def.participantRadius or 0
    local origin = Security.playerCoords(leader)
    if radius <= 0 or not origin then return list end

    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        if source and source ~= leader and #list < max then
            local coords = Security.playerCoords(source)
            if coords and #(coords - origin) <= radius then
                local gang = Integrations.getGang(source)
                if gang and gang.name == leaderGang.name then add(source) end
            end
        end
    end
    return list
end

return Participants
