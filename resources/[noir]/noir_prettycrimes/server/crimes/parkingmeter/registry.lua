---Parquímetro — a memória do servidor: que poste está vazio e quem já arrombou
---quantos.
---
---Duas tabelas, dois relógios diferentes, e a diferença é deliberada:
---
---  * `emptied` conta em SEGUNDOS com `os.time`, porque meia hora de cooldown
---    precisa fazer sentido como duração de relógio (§9.4);
---  * a expiração é PREGUIÇOSA — nada é agendado, e uma chave morta some na
---    primeira leitura que a encontra. Um `SetTimeout` por poste arrombado seria
---    um timer por moeda do mapa, e não há nada de urgente em esquecer uma chave
---    no instante exato.
---
---O `heat` é o teto por jogador numa janela deslizante, e é a peça que segura
---este crime. Ele é indexado por **citizenId**, não por `source`: o §12.6 é
---explícito, e na prática reconectar não pode zerar o contador.

local Utils = require 'shared.utils'
local Constants = require 'shared.constants'
local ServerConfig = require 'config.parkingmeter_server'

local CRIME = Constants.crimes.parkingmeter
local DebugPrint = Utils.debugPrint(CRIME)

local Registry = {}

---[meterKey] = timestamp (os.time) em que o poste volta a ter moedas
local emptied = {}

---[citizenId] = lista de timestamps (os.time) de arrombamentos concluídos
local heat = {}

---@return integer
local function now()
    return os.time()
end

-- ---------------------------------------------------------------------------
-- Postes esvaziados
-- ---------------------------------------------------------------------------

---Segundos que faltam para o poste voltar. 0 = disponível.
---
---Descarta a chave morta que encontrar: é aqui que a expiração preguiçosa
---acontece, e é por isso que não existe timer nenhum neste arquivo.
---@param key string
---@return integer seconds
function Registry.remaining(key)
    local expiresAt = emptied[key]
    if not expiresAt then return 0 end

    local left = expiresAt - now()
    if left <= 0 then
        emptied[key] = nil
        return 0
    end
    return left
end

---@param key string
---@return boolean
function Registry.isEmptied(key)
    return Registry.remaining(key) > 0
end

---Marca o poste como esvaziado e devolve por quanto tempo.
---@param key string
---@return integer seconds
function Registry.markEmptied(key)
    local duration = ServerConfig.meterCooldown
    if not Utils.isFinite(duration) or duration <= 0 then duration = 1 end
    duration = math.floor(duration)

    emptied[key] = now() + duration
    DebugPrint(('poste %s esvaziado por %ds'):format(key, duration))
    return duration
end

---Tudo que ainda está vazio, em MILISSEGUNDOS restantes.
---
---Milissegundos porque é o que o client usa: do lado de lá a contagem é
---`GetGameTimer`, e converter aqui evita que o client precise saber que o
---servidor conta em segundos.
---@return table<string, integer> key -> ms restantes
function Registry.snapshot()
    local snapshot = {}
    local dead = {}

    for key, expiresAt in pairs(emptied) do
        local left = expiresAt - now()
        if left > 0 then
            snapshot[key] = left * 1000
        else
            dead[#dead + 1] = key
        end
    end

    for index = 1, #dead do emptied[dead[index]] = nil end
    return snapshot
end

-- ---------------------------------------------------------------------------
-- Teto por jogador
-- ---------------------------------------------------------------------------

---Quantos arrombamentos o jogador concluiu dentro da janela.
---
---Compacta a lista na leitura: sem isso, um jogador de sessão longa acumularia
---um timestamp por arrombamento até o restart.
---@param citizenId string
---@return integer count
function Registry.heatCount(citizenId)
    local entries = heat[citizenId]
    if not entries then return 0 end

    local window = ServerConfig.heatWindow
    if not Utils.isFinite(window) or window <= 0 then window = 3600 end

    local cutoff = now() - window
    local kept = {}
    for index = 1, #entries do
        if entries[index] > cutoff then kept[#kept + 1] = entries[index] end
    end

    if #kept == 0 then
        heat[citizenId] = nil
        return 0
    end

    heat[citizenId] = kept
    return #kept
end

---@param citizenId string
---@return boolean allowed
---@return integer count quantos já foram, depois da compactação
function Registry.underCap(citizenId)
    local cap = ServerConfig.maxPerHour
    local count = Registry.heatCount(citizenId)
    if not Utils.isFinite(cap) or cap <= 0 then return true, count end
    return count < cap, count
end

---Segundos que faltam para o jogador poder arrombar de novo.
---
---Sai da MESMA lista do teto, e não de um segundo contador: o último timestamp
---dela é, por construção, o último arrombamento concluído. Duas tabelas para a
---mesma verdade é como elas divergem.
---
---E é por isso que o cooldown conta a partir do que DEU CERTO, não a partir da
---tentativa: recusar um poste vazio não pode custar ao jogador o mesmo minuto que
---esvaziar um custou. O anti-spam de evento é outra coisa, e é barato.
---@param citizenId string
---@return integer seconds
function Registry.claimCooldownLeft(citizenId)
    local cooldown = ServerConfig.playerCooldown
    if not Utils.isFinite(cooldown) or cooldown <= 0 then return 0 end

    -- A leitura compacta a janela; o que sobra está em ordem de chegada.
    if Registry.heatCount(citizenId) == 0 then return 0 end

    local entries = heat[citizenId]
    local last = entries[#entries]
    local left = math.floor(last + cooldown - now())
    return left > 0 and left or 0
end

---@param citizenId string
function Registry.addHeat(citizenId)
    local entries = heat[citizenId]
    if not entries then
        entries = {}
        heat[citizenId] = entries
    end
    entries[#entries + 1] = now()
end

-- ---------------------------------------------------------------------------
-- Manutenção
-- ---------------------------------------------------------------------------

---Descarta o que já venceu nas duas tabelas. Roda em intervalo longo; a
---expiração preguiçosa já cobre a correção, isto é só para a memória não crescer
---com chaves que ninguém mais vai ler.
---@return integer removed
function Registry.prune()
    local removed = 0

    local deadKeys = {}
    local current = now()
    for key, expiresAt in pairs(emptied) do
        if expiresAt <= current then deadKeys[#deadKeys + 1] = key end
    end
    for index = 1, #deadKeys do
        emptied[deadKeys[index]] = nil
        removed = removed + 1
    end

    local citizenIds = {}
    for citizenId in pairs(heat) do citizenIds[#citizenIds + 1] = citizenId end
    for index = 1, #citizenIds do
        -- A própria leitura compacta e apaga a entrada vazia.
        if Registry.heatCount(citizenIds[index]) == 0 then removed = removed + 1 end
    end

    return removed
end

---@param key string
function Registry.forget(key)
    emptied[key] = nil
end

---@return integer emptiedCount
---@return integer trackedPlayers
function Registry.counts()
    local emptiedCount, players = 0, 0
    for _ in pairs(emptied) do emptiedCount = emptiedCount + 1 end
    for _ in pairs(heat) do players = players + 1 end
    return emptiedCount, players
end

return Registry
