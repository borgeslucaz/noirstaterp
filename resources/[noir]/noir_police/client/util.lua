---Ajudas de cliente: alvo, jogador de um ped, animações com timeout.

local Util = {}

---Server id do jogador dono do ped, ou nil se o ped não é de jogador.
---@param ped integer
---@return integer?
function Util.serverIdFromPed(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not IsPedAPlayer(ped) then return nil end
    local player = NetworkGetPlayerIndexFromPed(ped)
    if player == -1 then return nil end
    return GetPlayerServerId(player)
end

---Jogador mais próximo dentro do raio.
---@param radius number
---@return integer? serverId, integer? ped
function Util.closestPlayer(radius)
    local player, ped = lib.getClosestPlayer(GetEntityCoords(cache.ped), radius, false)
    if not player then return nil end
    return GetPlayerServerId(player), ped
end

---@param dict string
---@return boolean
function Util.loadDict(dict)
    local ok = pcall(lib.requestAnimDict, dict, 3000)
    return ok
end

---Estado replicado de outro jogador (só para UX; o servidor decide).
---@param serverId integer
---@param key string
function Util.playerState(serverId, key)
    local player = Player(serverId)
    return player and player.state and player.state[key]
end

---@param serverId integer
---@return boolean
function Util.isCuffed(serverId)
    return Util.playerState(serverId, 'isCuffed') == true
end

---@param code string?
---@return string
function Util.errorText(code)
    return locale('error.' .. tostring(code or 'unknown'))
end

return Util
