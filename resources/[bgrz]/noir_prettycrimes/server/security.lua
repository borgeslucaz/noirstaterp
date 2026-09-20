---Validações que todo crime precisa fazer antes de conceder qualquer coisa.
---
---Existe para que um módulo novo não precise reescrever (nem esquecer) rate limit,
---resolução de entidade e checagem de distância. A ordem das checagens é de
---propósito: o que é barato e não toca o mundo vem primeiro, para que spam de
---evento morra antes de custar uma busca de entidade.

local Config = require 'config.server'
local Utils = require 'shared.utils'

local DebugPrint = Utils.debugPrint('security')

local Security = {}

---[source][key] = timestamp em que o próximo pedido passa a ser aceito.
local nextAllowed = {}

---@param source any
---@return boolean
function Security.isValidPlayer(source)
    if not Utils.isPositiveInteger(source) then return false end
    -- GetPlayerPed devolve 0 para quem não está mais conectado.
    local ped = GetPlayerPed(source)
    return ped ~= nil and ped ~= 0 and DoesEntityExist(ped)
end

---Trava de spam por jogador e por ação.
---
---O carimbo é gravado ANTES de qualquer trabalho, e não depois de dar certo: um
---pedido recusado também precisa custar cooldown, senão a recusa vira o caminho
---barato para martelar o servidor.
---@param source number
---@param key string identificador da ação, normalmente o id do crime
---@param interval? number ms; nunca abaixo do piso do config compartilhado
---@return boolean allowed
function Security.rateLimit(source, key, interval)
    if not Utils.isPositiveInteger(source) then return false end

    local floor = Config.rateLimit.default
    local wait = (Utils.isFinite(interval) and interval > floor) and interval or floor

    local now = GetGameTimer()
    local bySource = nextAllowed[source]
    if bySource and bySource[key] and now < bySource[key] then
        DebugPrint(('rate limit: %s bloqueado em %s por mais %dms')
            :format(source, key, bySource[key] - now))
        return false
    end

    if not bySource then
        bySource = {}
        nextAllowed[source] = bySource
    end
    bySource[key] = now + wait
    return true
end

---Resolve o netId que o client mandou em uma entidade de verdade, do tipo certo e
---perto o suficiente do jogador.
---
---A distância é medida com as coordenadas que o SERVIDOR tem, não com as que o
---client mandou — é o que impede saque à distância.
---@param source number
---@param netId any
---@param entityType integer 1 = ped, 2 = veículo, 3 = objeto
---@param maxDistance? number
---@return number? entity
---@return string? errorCode
function Security.resolveEntity(source, netId, entityType, maxDistance)
    if not Security.isValidPlayer(source) then return nil, 'invalid_player' end
    if not Utils.isPositiveInteger(netId) then return nil, 'invalid_entity' end

    if not NetworkGetEntityFromNetworkId then return nil, 'invalid_entity' end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil, 'invalid_entity'
    end
    if GetEntityType(entity) ~= entityType then return nil, 'invalid_entity' end

    local limit = maxDistance or Config.limits.maxInteractDistance
    if limit > Config.limits.maxInteractDistance then
        limit = Config.limits.maxInteractDistance
    end

    local distance = #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(entity))
    if distance > limit then
        DebugPrint(('%s longe demais: %.1fm > %.1fm'):format(source, distance, limit))
        return nil, 'too_far'
    end

    return entity
end

---Atalho para veículos, que é o caso de quase todo petty crime.
---@param source number
---@param netId any
---@param maxDistance? number
---@return number? vehicle
---@return string? errorCode
function Security.resolveVehicle(source, netId, maxDistance)
    return Security.resolveEntity(source, netId, 2, maxDistance)
end

---Diz se há algum JOGADOR dentro do veículo. NPC não é visto daqui: o servidor não
---enxerga ped de ambiente, então essa metade da checagem fica com o client, no
---`canInteract`. Aqui cobrimos o caso que importa para grief — assaltar o carro de
---alguém que está dentro dele.
---Veículos com jogador dentro, em UMA passada por todos os jogadores.
---
---Existe para o survey: conferir veículo a veículo custava (lote x jogadores) —
---com lote de 40 e 64 jogadores, até 2.560 chamadas por consulta. Montando o
---conjunto uma vez, a consulta inteira custa uma passada e o resto é lookup.
---@return table<number, boolean> veículo -> ocupado
function Security.occupiedVehicles()
    local occupied = {}
    local players = GetPlayers()
    for index = 1, #players do
        local playerId = tonumber(players[index])
        if playerId then
            local ped = GetPlayerPed(playerId)
            if ped ~= 0 then
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle and vehicle ~= 0 then occupied[vehicle] = true end
            end
        end
    end
    return occupied
end

---@param vehicle number
---@return boolean
function Security.hasPlayerInside(vehicle)
    local players = GetPlayers()
    for index = 1, #players do
        local playerId = tonumber(players[index])
        if playerId then
            local ped = GetPlayerPed(playerId)
            if ped ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle then return true end
        end
    end
    return false
end

---Esquece o que foi guardado para um jogador que saiu.
---@param source number
function Security.forget(source)
    nextAllowed[source] = nil
end

return Security
