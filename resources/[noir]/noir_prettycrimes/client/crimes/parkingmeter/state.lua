---Parquímetro — a lista local de postes já esvaziados.
---
---É a fachada do client, e ela existe porque a fachada normal não existe: o smash
---& grab publica o estado numa state bag da entidade e todo client por perto lê;
---prop de mapa não tem entidade em que publicar. O que chega aqui vem por evento
---— um snapshot quando o jogador entra e um aviso por poste depois disso.
---
---**Nada aqui é autoridade.** A lista serve para esconder o alvo de um poste que
---já foi arrombado, nada além. Quem decide continua sendo o servidor, que tem a
---sua própria tabela e revalida tudo no `reserve` e no `claim`. Um client que
---apagasse esta lista inteira só conseguiria ver alvos que o servidor recusaria.
---
---A contagem é `GetGameTimer`, e o servidor manda DURAÇÃO em vez de timestamp: os
---dois relógios não são o mesmo, e converter um instante do servidor para o
---relógio local exigiria estimar a latência. Duração não exige nada.

local Utils = require 'shared.utils'
local Constants = require 'shared.constants'
local CrimeConfig = require 'config.parkingmeter'

local CRIME = Constants.crimes.parkingmeter
local DebugPrint = Utils.debugPrint(CRIME)

local State = {}

---[meterKey] = GetGameTimer() em que o poste volta a ter moedas
local emptied = {}

---@param key any
---@param duration any ms; 0 ou menos limpa a chave
function State.markEmptied(key, duration)
    if type(key) ~= 'string' or key == '' or #key > 64 then return end

    if not Utils.isFinite(duration) or duration <= 0 then
        emptied[key] = nil
        return
    end

    -- Teto de segurança: o servidor manda a duração real, mas um número absurdo
    -- vindo de um evento deixaria o poste escondido até o restart do client.
    if duration > CrimeConfig.emptiedFallback then duration = CrimeConfig.emptiedFallback end
    emptied[key] = GetGameTimer() + math.floor(duration)
end

---@param key string?
---@return boolean
function State.isEmptied(key)
    if type(key) ~= 'string' then return false end

    local expires = emptied[key]
    if not expires then return false end

    -- Expiração preguiçosa, como no servidor: a chave morta some na leitura que a
    -- encontrar, e não existe timer nenhum neste arquivo.
    if GetGameTimer() >= expires then
        emptied[key] = nil
        return false
    end
    return true
end

---Substitui a lista inteira pelo que o servidor respondeu.
---
---Substitui em vez de mesclar de propósito: o snapshot é a verdade completa no
---momento em que foi tirado, e mesclar deixaria de fora justamente o caso que o
---snapshot existe para corrigir — um poste que voltou a ter moedas enquanto o
---client estava desconectado.
---
---Uma resposta que NÃO é tabela sai antes de tocar em qualquer coisa. Isso não é
---paranoia de tipo: o `sync` tem rate limit no servidor, e um pedido recusado
---volta como nil. Limpar a lista nesse caminho faria a recusa apagar tudo que o
---client sabia — e o sintoma seria o jogador vendo alvo em poste vazio, bem na
---hora em que ele pediu a lista duas vezes seguidas.
---@param snapshot any table<string, number>
function State.applySnapshot(snapshot)
    if type(snapshot) ~= 'table' then
        DebugPrint('snapshot não veio; a lista atual continua valendo')
        return
    end
    emptied = {}

    local count = 0
    for key, duration in pairs(snapshot) do
        State.markEmptied(key, duration)
        count = count + 1
    end
    DebugPrint(('snapshot: %d postes vazios'):format(count))
end

function State.clear()
    emptied = {}
end

---@return integer
function State.count()
    local count = 0
    for key in pairs(emptied) do
        if State.isEmptied(key) then count = count + 1 end
    end
    return count
end

return State
