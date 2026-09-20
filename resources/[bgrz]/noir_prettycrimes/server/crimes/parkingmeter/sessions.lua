---Parquímetro — a máquina de estados de um arrombamento.
---
---    available ──reserve──> reserved ──claim──> (esvaziado, vai para o registry)
---        ^                      │
---        └──── release ─────────┘
---                (ou expiração)
---
---É a mesma forma da reserva do smash & grab, com duas diferenças que vêm de o
---alvo ser prop de mapa:
---
---  * não há state bag. O smash & grab publica `reserved` na entidade e todo
---    client por perto esconde o alvo; aqui não existe entidade para publicar
---    nada. Enquanto um jogador trabalha num poste, os outros só descobrem que
---    ele está ocupado ao tentar — e o servidor recusa com `reserved`. É uma
---    corrida curta (segundos) e o custo de perder é um aviso, não uma animação
---    inteira perdida: o pedido é a PRIMEIRA coisa que acontece, antes das barras;
---  * a chave é a célula da grade, não um netId.
---
---`reserve` lê e escreve **sem ceder a thread**, então entre a checagem e a
---marcação não existe janela. Lua de servidor é um fio só; a atomicidade vem
---daí, não de sorte.

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local ServerConfig = require 'config.parkingmeter_server'

local CRIME = Constants.crimes.parkingmeter
local DebugPrint = Utils.debugPrint(CRIME)

local Sessions = {}

---[meterKey] = { source, citizenId, reservedAt, expires }
local active = {}

---@param key string
---@return table? session
local function liveSession(key)
    local session = active[key]
    if not session then return nil end

    if GetGameTimer() >= session.expires then
        active[key] = nil
        DebugPrint('reserva expirada no poste', key)
        return nil
    end

    return session
end

---@param key string
---@return 'available'|'reserved'
function Sessions.status(key)
    return liveSession(key) and 'reserved' or 'available'
end

---@param key string
---@return number? source
function Sessions.holder(key)
    local session = liveSession(key)
    return session and session.source or nil
end

---O poste que este jogador já está trabalhando, se houver.
---
---Existe para impedir o caso que a trava por poste sozinha não pega: um client
---adulterado reservando dez postes de uma vez para travá-los todos para os
---outros. Um jogador segura um poste por vez.
---@param source number
---@return string? key
function Sessions.activeFor(source)
    for key in pairs(active) do
        local session = liveSession(key)
        if session and session.source == source then return key end
    end
    return nil
end

---Tranca o poste para um jogador.
---@param key string
---@param source number
---@param citizenId string
---@return boolean ok
---@return string? errorCode
function Sessions.reserve(key, source, citizenId)
    local existing = liveSession(key)
    if existing then
        -- Repetir a própria reserva é inofensivo (clique duplo, reconexão de UI).
        if existing.source == source then
            existing.expires = GetGameTimer() + ServerConfig.reservationTimeout
            return true
        end
        return false, 'reserved'
    end

    local busyWith = Sessions.activeFor(source)
    if busyWith then
        DebugPrint(('%s já está no poste %s'):format(source, busyWith))
        return false, 'busy'
    end

    local timer = GetGameTimer()
    active[key] = {
        source = source,
        citizenId = citizenId,
        reservedAt = timer,
        expires = timer + ServerConfig.reservationTimeout,
    }
    DebugPrint(('poste %s reservado por %s'):format(key, source))
    return true
end

---Devolve o poste para quem cancelou ou saiu.
---@param key string
---@param source number? nil ignora o dono (usado na limpeza)
---@return boolean
function Sessions.release(key, source)
    local session = active[key]
    if not session then return false end
    if source and session.source ~= source then return false end

    active[key] = nil
    DebugPrint('poste liberado:', key)
    return true
end

---Fecha a reserva. Só o dono dela fecha, uma vez, e não antes da hora.
---
---A checagem de tempo decorrido é o que impede reservar e entregar no mesmo
---instante chamando os eventos à mão: o §17.4 diz que o servidor não concede
---resultado só porque o client informou que a animação acabou. Aqui ele mede.
---@param key string
---@param source number
---@param minElapsed number ms que precisam ter passado desde a reserva
---@return boolean ok
---@return string? errorCode
---@return string? citizenId o da RESERVA, não o de agora
function Sessions.claim(key, source, minElapsed)
    local session = liveSession(key)
    if not session then return false, 'expired' end
    if session.source ~= source then return false, 'reserved' end

    local elapsed = GetGameTimer() - session.reservedAt
    if Utils.isFinite(minElapsed) and elapsed < minElapsed then
        DebugPrint(('entrega cedo demais: %dms de %dms'):format(elapsed, minElapsed))
        return false, 'too_soon'
    end

    -- Sai da tabela ANTES de qualquer concessão: daqui para baixo o poste já é
    -- deste pedido, e nenhum segundo `claim` passa por cima.
    active[key] = nil
    DebugPrint(('poste %s levado por %s'):format(key, source))
    return true, nil, session.citizenId
end

---Desconexão solta tudo que o jogador estava segurando, na hora — sem esperar o
---timeout. É o caso que o timeout existe para cobrir, mas cobrir rápido é melhor.
---@param source number
function Sessions.releaseAllFor(source)
    local keys = {}
    for key, session in pairs(active) do
        if session.source == source then keys[#keys + 1] = key end
    end
    for index = 1, #keys do Sessions.release(keys[index], source) end
end

---Descarta reservas vencidas. Roda em intervalo longo; a expiração preguiçosa já
---cobre a correção, isto é só para a memória não crescer.
---@return integer removed
function Sessions.prune()
    local dead = {}
    local timer = GetGameTimer()
    for key, session in pairs(active) do
        if timer >= session.expires then dead[#dead + 1] = key end
    end
    for index = 1, #dead do active[dead[index]] = nil end
    return #dead
end

---@return integer reserved
function Sessions.counts()
    local count = 0
    for key in pairs(active) do
        if liveSession(key) then count = count + 1 end
    end
    return count
end

return Sessions
