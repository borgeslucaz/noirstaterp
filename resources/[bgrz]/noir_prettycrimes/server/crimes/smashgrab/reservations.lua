---Smash & Grab — a máquina de estados do objeto.
---
---    available ──reserve──> reserved ──claim──> claimed
---        ^                      │                (final)
---        └──── release ─────────┘
---                (ou expiração)
---
---Dois jogadores podem chegar na mesma mochila ao mesmo tempo. O que garante que
---só um leve é este arquivo: `reserve` lê e escreve **sem ceder a thread**, então
---entre a checagem e a marcação não existe janela. Lua de servidor é um fio só; a
---atomicidade vem daí, não de sorte.
---
---Duas verdades, de propósito:
---
---  * a tabela em memória é a autoridade — é ela que decide quem pode;
---  * a state bag da entidade é a fachada — é o que os clients leem para apagar o
---    prop e esconder o alvo.
---
---A state bag sozinha não serviria como autoridade (ela é replicada, e o servidor
---escreve nela de forma assíncrona do ponto de vista dos clients). A tabela
---sozinha não serviria como fachada (ninguém a enxerga). As duas andam juntas, e
---quem manda é sempre a primeira.

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local CrimeConfig = require 'config.smashgrab'
local ServerConfig = require 'config.smashgrab_server'

local CRIME = Constants.crimes.smashgrab
local DebugPrint = Utils.debugPrint(CRIME)
local STATE = Constants.state.smashGrab

local Reservations = {}

---[netId] = { source, expires, propKey, seatKey }
---Só contém objeto reservado AGORA. Reserva que expira some daqui na primeira
---leitura seguinte; nada fica pendurado esperando timer.
local active = {}

---[netId] = true — objetos já levados. Vive enquanto a entidade viver.
local claimed = {}

---Publica o estado na entidade.
---
---O valor é uma STRING, não uma tabela: o §11.2 do SCRIPT_GOOD_PRACTICES pede
---state bag rasa, porque getter/setter serializam o estado inteiro e mutação
---aninhada não replica como esperado. Aqui não há nada a aninhar — quem reservou
---fica na tabela do servidor, que é a autoridade, e state bag de entidade é pública.
---@param vehicle number
---@param status 'reserved'|'claimed'|nil
local function publish(vehicle, status)
    if not DoesEntityExist(vehicle) then return end
    Entity(vehicle).state:set(STATE, status, true)
end

---Descarta uma reserva expirada e **limpa a fachada**.
---
---Publicar o nil aqui não é detalhe: o client esconde os dois alvos enquanto a
---state bag não for nil, então uma reserva que morre sem limpar deixa o objeto
---visível e intocável — e ninguém chama `reserve` de novo para a expiração
---preguiçosa ser notada. O objeto ficaria travado até o carro despawnar.
---@param netId number
local function expire(netId)
    active[netId] = nil
    if not claimed[netId] then
        publish(NetworkGetEntityFromNetworkId(netId), nil)
    end
    DebugPrint('reserva expirada no netId', netId)
end

---@param netId number
---@return table? reservation
local function liveReservation(netId)
    local reservation = active[netId]
    if not reservation then return nil end

    if GetGameTimer() >= reservation.expires then
        expire(netId)
        return nil
    end

    return reservation
end

---@param netId number
---@return 'available'|'reserved'|'claimed'
function Reservations.status(netId)
    if claimed[netId] then return 'claimed' end
    return liveReservation(netId) and 'reserved' or 'available'
end

---@param netId number
---@return number? source
function Reservations.holder(netId)
    local reservation = liveReservation(netId)
    return reservation and reservation.source or nil
end

---Tranca o objeto para um jogador.
---
---Não há `Wait`, `await` nem chamada a outro resource entre a checagem e a
---escrita: é isso que torna a operação indivisível.
---@param netId number
---@param vehicle number
---@param source number
---@param propKey string
---@param seatKey string
---@return boolean ok
---@return string? errorCode
function Reservations.reserve(netId, vehicle, source, propKey, seatKey)
    if claimed[netId] then return false, 'already_taken' end

    local existing = liveReservation(netId)
    if existing then
        -- Repetir a própria reserva é inofensivo (clique duplo, reconexão de UI).
        if existing.source == source then
            existing.expires = GetGameTimer() + ServerConfig.reservationTimeout
            return true
        end
        return false, 'reserved'
    end

    local now = GetGameTimer()
    active[netId] = {
        source = source,
        propKey = propKey,
        seatKey = seatKey,
        reservedAt = now,
        expires = now + ServerConfig.reservationTimeout,
    }
    publish(vehicle, 'reserved')

    -- A expiração preguiçosa (na leitura) não basta sozinha: quem faria a leitura
    -- seria um `reserve` novo, e o client não oferece o alvo enquanto a state bag
    -- disser 'reserved'. Este timer é quem garante que a trava cai. É idempotente
    -- — se a reserva já virou claim ou release, não acha nada e não faz nada.
    SetTimeout(ServerConfig.reservationTimeout + 50, function()
        local current = active[netId]
        if current and current.reservedAt == now and GetGameTimer() >= current.expires then
            expire(netId)
        end
    end)
    DebugPrint(('netId %d reservado por %s'):format(netId, source))
    return true
end

---Devolve o objeto para quem cancelou ou saiu.
---@param netId number
---@param source number? nil ignora o dono (usado na limpeza)
---@param vehicle number?
---@return boolean
function Reservations.release(netId, source, vehicle)
    local reservation = active[netId]
    if not reservation then return false end
    if source and reservation.source ~= source then return false end

    active[netId] = nil
    if not claimed[netId] then
        publish(vehicle or NetworkGetEntityFromNetworkId(netId), nil)
    end
    DebugPrint('netId liberado:', netId)
    return true
end

---Fecha a reserva. Só o dono dela fecha, uma vez, e não antes da hora.
---
---A checagem de tempo decorrido é o que impede reservar e entregar no mesmo
---instante chamando os eventos à mão: o §17.4 diz que o servidor não concede
---resultado só porque o client informou que a animação acabou. Aqui ele mede.
---@param netId number
---@param vehicle number
---@param source number
---@param minElapsed number ms que precisam ter passado desde a reserva
---@return boolean ok
---@return string? errorCode
function Reservations.claim(netId, vehicle, source, minElapsed)
    if claimed[netId] then return false, 'already_taken' end

    local reservation = liveReservation(netId)
    if not reservation then return false, 'expired' end
    if reservation.source ~= source then return false, 'reserved' end

    local elapsed = GetGameTimer() - reservation.reservedAt
    if minElapsed and elapsed < minElapsed then
        DebugPrint(('entrega cedo demais: %dms de %dms'):format(elapsed, minElapsed))
        return false, 'too_soon'
    end

    active[netId] = nil
    claimed[netId] = true
    publish(vehicle, 'claimed')
    DebugPrint(('netId %d levado por %s'):format(netId, source))
    return true
end

---Desconexão solta tudo que o jogador estava segurando, na hora — sem esperar o
---timeout. É o caso que o timeout existe para cobrir, mas cobrir rápido é melhor.
---@param source number
function Reservations.releaseAllFor(source)
    local netIds = {}
    for netId, reservation in pairs(active) do
        if reservation.source == source then netIds[#netIds + 1] = netId end
    end
    for index = 1, #netIds do Reservations.release(netIds[index], source) end
end

---Esquece um netId que não corresponde mais a um veículo vivo. Sem isso, `claimed`
---cresceria para sempre em um servidor de uptime longo.
---@param netId number
function Reservations.forget(netId)
    active[netId] = nil
    claimed[netId] = nil
end

---Varre os netIds guardados e descarta os que já não existem. Roda em intervalo
---longo; é manutenção, não caminho quente.
---@return integer removed
function Reservations.prune()
    local dead = {}
    for netId in pairs(claimed) do
        if not NetworkGetEntityFromNetworkId(netId) or NetworkGetEntityFromNetworkId(netId) == 0 then
            dead[#dead + 1] = netId
        end
    end
    for netId in pairs(active) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if not entity or entity == 0 then dead[#dead + 1] = netId end
    end
    for index = 1, #dead do Reservations.forget(dead[index]) end
    return #dead
end

---@return integer reserved
---@return integer claimed
function Reservations.counts()
    local reservedCount, claimedCount = 0, 0
    for netId in pairs(active) do
        if liveReservation(netId) then reservedCount = reservedCount + 1 end
    end
    for _ in pairs(claimed) do claimedCount = claimedCount + 1 end
    return reservedCount, claimedCount
end

return Reservations
