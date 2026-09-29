---Rate limit e leitura da posição do jogador, do jeito que o servidor vê.

local Config = require 'config.server'

local Security = {}

---[source][ação] = instante em que o próximo pedido passa a ser aceito.
local nextAllowed = {}

---Carimbo gravado antes de qualquer trabalho: pedido recusado também custa espera,
---senão a recusa vira o caminho barato para martelar o servidor.
---@param source number
---@param action string
---@param intervalMs? integer
---@return boolean
function Security.rateLimit(source, action, intervalMs)
    local now = GetGameTimer()
    local bySource = nextAllowed[source]
    if not bySource then
        bySource = {}
        nextAllowed[source] = bySource
    end
    if (bySource[action] or 0) > now then return false end
    bySource[action] = now + (intervalMs or Config.rateLimitMs)
    return true
end

---@param source number
function Security.forget(source)
    nextAllowed[source] = nil
end

---@param source number
---@return vector3? coords
---@return integer? ped
function Security.pedCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped), ped
end

---@param point { x: number, y: number, z: number }
---@return vector3
function Security.toVector(point)
    return vector3(point.x, point.y, point.z)
end

---Hash de model sem sinal. `joaat` e `GetEntityModel` podem discordar no sinal do
---mesmo model; comparar os dois crus falharia com o veículo certo.
---@param hash integer
---@return integer
local function unsigned(hash)
    return hash & 0xFFFFFFFF
end

---A pé e, se a rota exige veículo, com um veículo daquele model por perto.
---
---Não usa o "último veículo do ped": o servidor não devolveu o burrito3 com que o
---jogador tinha acabado de chegar. Procurar o model perto do jogador é o que a regra
---quer dizer na prática — veio de van, a van está ali.
---@param ped integer
---@param coords vector3
---@param model string?
---@return boolean ok
---@return string? errorCode
function Security.checkVehicle(ped, coords, model)
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'in_vehicle' end
    if not model then return true end

    local wanted = unsigned(joaat(model))
    local maxDistance = Config.distance.vehicle
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and unsigned(GetEntityModel(vehicle)) == wanted
            and #(GetEntityCoords(vehicle) - coords) <= maxDistance then
            return true
        end
    end
    return false, 'wrong_vehicle'
end

return Security
