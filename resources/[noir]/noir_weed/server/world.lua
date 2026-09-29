---Posição do jogador como o servidor vê, e as conferências de lugar que plantas e mesas
---compartilham.

local Config = require 'config.server'
local Rules = require 'shared.rules'

local World = {}

---@param source number
---@param point { x: number, y: number, z: number }
---@return number
function World.distanceTo(source, point)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return math.huge end
    return #(GetEntityCoords(ped) - vector3(point.x, point.y, point.z))
end

---Vaga para posicionar algo: perto do jogador, fora das zonas proibidas e a pelo menos
---`spacing` de tudo em `others`.
---@param source number
---@param placement { x: number, y: number, z: number, w: number }
---@param others table<integer, { x: number, y: number, z: number }>
---@param spacing number
---@param ignoreId? integer o próprio objeto, quando está sendo movido
---@return boolean ok
---@return string? code
function World.checkSpot(source, placement, others, spacing, ignoreId)
    if not Rules.isPlacement(placement) then return false, 'invalid_request' end
    if World.distanceTo(source, placement) > Config.distance.place then return false, 'too_far' end
    if Rules.inBlacklist(placement, Config.blacklistZones) then return false, 'blacklisted_zone' end
    local spot = vector3(placement.x, placement.y, placement.z)
    for id, other in pairs(others) do
        if id ~= ignoreId and #(spot - vector3(other.x, other.y, other.z)) < spacing then
            return false, 'too_close'
        end
    end
    return true
end

---@param list table<integer, { owner: string }>
---@param citizenId string
---@return integer
function World.ownedCount(list, citizenId)
    local count = 0
    for _, entry in pairs(list) do
        if entry.owner == citizenId then count += 1 end
    end
    return count
end

return World
