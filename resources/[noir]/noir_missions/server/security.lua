---Rate limit e checagens de payload do servidor (§7.5, §7.2).
local Config = require 'config.server'

local Security = {}

local nextAllowedAt = {}

---@param source integer
---@param action string
---@param intervalMs? integer
---@return boolean
function Security.consume(source, action, intervalMs)
    local now = GetGameTimer()
    local byAction = nextAllowedAt[source]
    if not byAction then
        byAction = {}
        nextAllowedAt[source] = byAction
    end
    if (byAction[action] or 0) > now then return false end
    byAction[action] = now + (intervalMs or Config.rateLimits[action] or 500)
    return true
end

---@param source integer
function Security.forget(source)
    nextAllowedAt[source] = nil
end

---@param value any
---@return boolean
function Security.isInstanceId(value)
    return type(value) == 'number' and value > 0 and value % 1 == 0 and value < 2 ^ 31
end

---@param value any
---@param maxLength? integer
---@return boolean
function Security.isKey(value, maxLength)
    return type(value) == 'string' and #value > 0 and #value <= (maxLength or 64)
        and value:match('^[%w_%-%.:]+$') ~= nil
end

---@param value any
---@return boolean
function Security.isIndex(value)
    return type(value) == 'number' and value >= 1 and value <= 256 and value % 1 == 0
end

---@param value any
---@return boolean
function Security.isNetId(value)
    return type(value) == 'number' and value > 0 and value % 1 == 0 and value < 65536
end

---Coordenadas do ped do jogador no servidor (§7.3). nil se ainda não existe.
---@param source integer
---@return vector3?
function Security.playerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

---@param source integer
---@param target table|vector3
---@param maxDistance number
---@return boolean
function Security.isNear(source, target, maxDistance)
    local coords = Security.playerCoords(source)
    if not coords then return false end
    return #(coords - vector3(target.x, target.y, target.z)) <= maxDistance
end

return Security
