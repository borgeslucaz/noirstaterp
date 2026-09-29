---Rate limit e distância do jeito que o servidor vê o jogador.

local Config = require 'config.server'

local Security = {}

---[source][ação] = instante em que o próximo pedido passa a ser aceito.
local nextAllowed = {}

---Carimbo gravado antes de qualquer trabalho: pedido recusado também custa espera.
---@return boolean
function Security.rateLimit(source, action)
    local now = GetGameTimer()
    local bySource = nextAllowed[source]
    if not bySource then
        bySource = {}
        nextAllowed[source] = bySource
    end
    if (bySource[action] or 0) > now then return false end
    bySource[action] = now + (Config.rateLimitMs[action] or 500)
    return true
end

function Security.forget(source)
    nextAllowed[source] = nil
end

---@param coords { x: number, y: number, z: number }
---@return boolean
function Security.near(source, coords, radius)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= radius
end

return Security
