-- De quem é o bairro.
--
-- Isto já foi uma conta: quem tivesse a maior fatia acima do limiar era dono, e a resposta
-- saía nova a cada pergunta. Com a trava de domínio deixou de dar: "há quanto tempo esta gang
-- é dona" não está escrito em lugar nenhum da distribuição de pontos. Então ownership virou
-- estado guardado — quem tomou, e quando — e a influência voltou a ser só influência.
--
-- Três regras, nesta ordem:
--
--   1. Dono que zera perdeu o bairro. Não se é dono de onde não se está, e um bairro com dono
--      de zero ponto seria uma placa sem rua atrás. A trava não protege contra isso: quem foi
--      varrido do mapa some da placa na hora.
--   2. Bairro sem dono é de quem alcançar o limiar. Sem trava — não houve tomada ainda.
--   3. Bairro com dono só troca quando outra gang alcança o limiar E a trava já caiu. Cair
--      abaixo do limiar não devolve o bairro para ninguém: o dono segue dono até alguém tomar.
--
-- O servidor é o único que decide e escreve. O cliente recebe a placa pronta, para desenhar.

NoirOwnership = { zones = {} }

---Relógio do servidor, em segundos. Cada lado preenche do seu jeito, como o `NoirClaims.zoneAt`
---faz com a pergunta "que bairro é este": no servidor é `os.time`; no cliente a biblioteca `os`
---simplesmente não existe, e a hora chega junto do espelho da placa.
---
---Zero é "ainda não sei": quem desenha trata isso como trava sem contagem, em vez de inventar
---um número a partir de um relógio que não existe.
---@type fun(): number
NoirOwnership.now = function() return 0 end

---@return string? owner, number? takenAt
function NoirOwnership.get(zone)
    local state = type(zone) == 'string' and NoirOwnership.zones[zone] or nil
    if not state then return end
    return state.owner, state.takenAt
end

function NoirOwnership.set(zone, owner, takenAt)
    if type(zone) ~= 'string' then return end

    if type(owner) ~= 'string' or owner == '' or owner == 'none' then
        NoirOwnership.zones[zone] = nil
        return
    end

    NoirOwnership.zones[zone] = { owner = owner, takenAt = math.floor(tonumber(takenAt) or 0) }
end

function NoirOwnership.replaceAll(zones)
    NoirOwnership.zones = {}
    for zone, state in pairs(zones or {}) do
        if type(state) == 'table' then NoirOwnership.set(zone, state.owner, state.takenAt) end
    end
end

---Quando a trava deste bairro cai. `nil` quando não há dono.
---@return number? timestamp
function NoirOwnership.lockedUntil(zone)
    local owner, takenAt = NoirOwnership.get(zone)
    if not owner or not takenAt then return end
    return takenAt + Config.OwnershipLockSeconds
end

---@param now? number relógio do servidor; o cliente passa o dele só para desenhar
function NoirOwnership.isLocked(zone, now)
    local expires = NoirOwnership.lockedUntil(zone)
    return expires ~= nil and (tonumber(now) or NoirOwnership.now()) < expires
end

---A gang que já tem o suficiente para tomar o bairro e não é a dona.
---
---Duas ao mesmo tempo é impossível por aritmética enquanto o limiar for maioria: 510 + 510
---passa do pool. A comparação por maior existe para o caso de alguém baixar o limiar no config.
---@return string? gang
function NoirOwnership.challengerOf(zone)
    local owner = NoirOwnership.get(zone)
    local required, best, challenger = NoirInfluence.required(), 0, nil

    for gang, points in pairs(NoirInfluence.of(zone)) do
        if gang ~= owner and points >= required and points > best then
            best, challenger = points, gang
        end
    end

    return challenger
end

---O bairro recusa este movimento de influência por estar protegido pela trava?
---
---Durante a trava o bairro está parado para o dono: ele não perde — nem por tag apagada, nem
---por nada — e também não ganha. As quatro horas são de posse garantida, não de vantagem: sem
---isso o dono usaria a janela em que ninguém pode revidar para engordar a fatia, e sairia da
---trava mais forte do que entrou, com o trabalho todo feito a salvo.
---
---De fora, o que a trava segura é o ganho: ganhar ali é tirar do dono, direta ou indiretamente.
---A perda de quem não é dono passa — ela não toca no dono, e é assim que a tag de um invasor
---apagada por outro invasor continua valendo o que vale.
---@param amount number positivo ganha, negativo perde
---@param now? number relógio do servidor
---@return boolean
function NoirOwnership.protects(zone, gang, amount, now)
    local owner = NoirOwnership.get(zone)
    if not owner or not NoirOwnership.isLocked(zone, now) then return false end
    if gang == owner then return true end
    return amount > 0
end

---Quem **deveria** ser dono agora. Função pura: não escreve nada, e é o servidor que compara o
---resultado com o que está guardado e decide se houve troca.
---@return string? owner nil significa bairro sem dono
function NoirOwnership.desiredOwner(zone, now)
    local current = NoirOwnership.get(zone)

    -- Regra 1: dono varrido do bairro deixa de ser dono, e a partir daqui o bairro é tratado
    -- como sem dono — inclusive para a trava, que protegia uma posse que não existe mais.
    if current and NoirInfluence.get(zone, current) <= 0 then current = nil end

    local required, best, leader = NoirInfluence.required(), 0, nil
    for gang, points in pairs(NoirInfluence.of(zone)) do
        if points >= required and points > best then best, leader = points, gang end
    end

    if not current then return leader end                     -- regra 2
    if not leader or leader == current then return current end -- ninguém alcançou: dono segue
    if NoirOwnership.isLocked(zone, now) then return current end -- regra 3, trava de pé
    return leader
end
