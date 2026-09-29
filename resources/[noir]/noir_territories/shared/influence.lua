-- Influência de gang dentro de um bairro.
--
-- Cada bairro tem um pool fixo de pontos — `Config.Influence.Total`, 1000. As gangs dividem
-- esse pool entre si e o que ninguém tomou é neutro: `neutral = Total - soma(gangs)`. Um
-- bairro virgem é 1000 de neutro e nada mais.
--
-- O pool é fechado de propósito, e é a decisão que sustenta o resto. Com acúmulo
-- independente — cada gang somando pontos próprios até passar de um limiar — o 1000 seria só
-- um número de corrida, duas gangs poderiam "dominar" o mesmo bairro ao mesmo tempo e tomar
-- a rua de alguém seria indistinguível de trabalhar num terreno vazio. Fechado, o mapa é uma
-- soma zero: todo ponto que alguém ganha saiu do neutro ou de outra gang.
--
-- Este arquivo é só aritmética, e é compartilhado porque as duas pontas fazem a mesma
-- pergunta. O servidor é o dono do registro e o único que escreve; o cliente guarda uma cópia
-- para a tela do mapa e para responder sem viagem de rede.

NoirInfluence = { zones = {} }

local function total()
    return Config.Influence.Total
end

---O limiar em pontos. Mora aqui, e não no config, porque o config guarda a porcentagem: é
---assim que se diz "maioria" uma vez só, em vez de escrever 510 em três arquivos e deixar dois
---deles para trás no dia em que o pool mudar.
---@return number
function NoirInfluence.required()
    return math.ceil(total() * Config.Influence.RequiredPercent / 100)
end

local function clamp(points)
    if points < 0 then return 0 end
    local max = total()
    if points > max then return max end
    return points
end

local function zoneTable(zone)
    local byGang = NoirInfluence.zones[zone]
    if not byGang then
        byGang = {}
        NoirInfluence.zones[zone] = byGang
    end
    return byGang
end

---Quanto uma gang tem num bairro.
---@return number
function NoirInfluence.get(zone, gang)
    if type(zone) ~= 'string' or type(gang) ~= 'string' then return 0 end
    local byGang = NoirInfluence.zones[zone]
    return byGang and byGang[gang] or 0
end

---A fatia de cada gang num bairro. A tabela é a de dentro: quem lê não escreve nela.
---@return table<string, number>
function NoirInfluence.of(zone)
    if type(zone) ~= 'string' then return {} end
    return NoirInfluence.zones[zone] or {}
end

---@return number tomado por todas as gangs, number neutro
function NoirInfluence.sumOf(zone)
    local sum = 0
    for _, points in pairs(NoirInfluence.of(zone)) do sum = sum + points end
    return sum, math.max(0, total() - sum)
end

---Escreve a fatia de uma gang sem tirar de ninguém. É o carregamento do banco e o espelho no
---cliente — não é jogo. Quem joga usa `grant`, que respeita o pool.
function NoirInfluence.set(zone, gang, points)
    if type(zone) ~= 'string' or type(gang) ~= 'string' or gang == '' then return 0 end

    local value = clamp(math.floor(tonumber(points) or 0))
    local byGang = zoneTable(zone)

    -- Zero não é um valor, é a ausência dele: guardar `0` encheria o registro de gangs que
    -- passaram por ali uma vez e encheria o mapa de fatias invisíveis.
    byGang[gang] = value > 0 and value or nil
    return value
end

---Troca de uma vez o quadro inteiro de um bairro.
function NoirInfluence.replaceZone(zone, byGang)
    if type(zone) ~= 'string' then return end
    NoirInfluence.zones[zone] = nil
    for gang, points in pairs(byGang or {}) do NoirInfluence.set(zone, gang, points) end
end

---Troca de uma vez o registro inteiro. É como o cliente recebe o espelho no login.
function NoirInfluence.replaceAll(zones)
    NoirInfluence.zones = {}
    for zone, byGang in pairs(zones or {}) do NoirInfluence.replaceZone(zone, byGang) end
end

---Quem paga, em ordem estável: o neutro e cada rival, do maior para o menor.
---
---O neutro entra como mais um pagador, e não como uma reserva a ser gasta antes dos outros.
---Num bairro quase virgem ele é o maior de todos e banca quase tudo sozinho; à medida que as
---gangs tomam o bairro, ele encolhe e passa a pagar menos — quem paga é sempre o neutro e
---quem tem mais, e quem tem menos paga menos.
---
---`pairs` não garante ordem, e sem ordenar o mesmo ganho tiraria de uma gang diferente em
---cada máquina — o servidor decidiria uma coisa e o mapa do cliente mostraria outra. Empate
---resolve pelo nome, e o neutro vem antes de qualquer gang porque não tem nome para comparar.
local function payersByStrength(zone, gang)
    local _, neutral = NoirInfluence.sumOf(zone)
    local payers = { { neutral = true, points = neutral } }

    for name, points in pairs(NoirInfluence.of(zone)) do
        if name ~= gang then payers[#payers + 1] = { name = name, points = points } end
    end

    table.sort(payers, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        if a.neutral then return true end
        if b.neutral then return false end
        return a.name < b.name
    end)

    return payers
end

---Tira `needed` pontos de quem tem, proporcionalmente ao que cada um tem.
---
---Quem tem mais paga mais, quem tem menos paga menos — e "menos" aqui é de verdade: numa
---divisão em partes iguais, uma gang com 22 pontos pagaria os mesmos 5 que uma com 800, ou
---seja 23% de tudo que ela tem contra 0,6% do gigante. Era isso que tornava impossível entrar
---num bairro dominado: não o quanto se ganhava, o quanto se apanhava por existir. No
---proporcional a mesma atividade tira 1 ponto dela.
---
---Durante a trava de domínio ninguém de fora chega aqui: `NoirOwnership.protects` recusa o
---movimento antes, em `server/influence.lua`. Este arquivo continua sabendo só de aritmética.
---
---O neutro entra na divisão como mais um pagador, e num bairro quase virgem ele é o maior de
---todos e banca quase tudo sozinho. O que ele paga não vira linha em tabela nenhuma: o neutro
---é `Total - soma(gangs)` e encolhe sozinho quando a fatia de quem ganhou cresce.
---
---O resto da divisão inteira é distribuído um ponto por vez, do maior pagador para o menor:
---sem uma ordem fixa, o mesmo ganho tiraria um ponto de uma gang diferente em cada máquina e o
---mapa do cliente discordaria do servidor.
---
---@return table<string, number> taken quanto saiu de cada gang, number total tirado (com o neutro)
local function drainFrom(zone, gang, needed)
    local payers = payersByStrength(zone, gang)

    local pool = 0
    for i = 1, #payers do pool = pool + payers[i].points end
    if pool <= 0 then return {}, 0 end

    local want = math.min(needed, pool)
    local taken, given = {}, 0

    for i = 1, #payers do
        taken[i] = math.floor(want * payers[i].points / pool)
        given = given + taken[i]
    end

    -- A divisão inteira sempre tira menos do que devia — no máximo um ponto por pagador. Duas
    -- passadas bastam: a parte de cada um é o piso da fração, então todo mundo tem ao menos um
    -- ponto de folga sobre o que já foi cobrado dele.
    local step = 1
    while given < want and step <= #payers * 2 do
        local i = ((step - 1) % #payers) + 1
        if payers[i].points > taken[i] then
            taken[i] = taken[i] + 1
            given = given + 1
        end
        step = step + 1
    end

    local result = {}
    for i = 1, #payers do
        if not payers[i].neutral and taken[i] > 0 then result[payers[i].name] = taken[i] end
    end

    return result, given
end

---Move influência dentro do pool de um bairro.
---
---Ganho sai do neutro e das outras gangs ao mesmo tempo, dividido o mais por igual que a conta
---permitir (`drainFrom`). Num bairro quase virgem o neutro é o maior e banca quase tudo; num
---bairro já repartido, quem tem mais paga mais e quem tem menos paga menos — tomar a rua
---custa a rua de quem já estava lá.
---
---Perda volta para o neutro, e não para o segundo colocado: quem perde terreno não entrega o
---bairro para o rival, ele solta a rua.
---
---@param amount number positivo ganha, negativo perde
---@return table<string, number> changes o quadro depois, só de quem mudou — é o que o servidor
---persiste e espelha, para não reescrever o bairro inteiro a cada ponto.
function NoirInfluence.grant(zone, gang, amount)
    local changes = {}
    if type(zone) ~= 'string' or type(gang) ~= 'string' or gang == '' or gang == 'none' then
        return changes
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return changes end

    local current = NoirInfluence.get(zone, gang)

    if amount < 0 then
        local after = clamp(current + amount)
        if after == current then return changes end
        changes[gang] = NoirInfluence.set(zone, gang, after)
        return changes
    end

    local room = math.min(amount, total() - current)
    if room <= 0 then return changes end

    local taken, gained = drainFrom(zone, gang, room)

    for name, points in pairs(taken) do
        changes[name] = NoirInfluence.set(zone, name, NoirInfluence.get(zone, name) - points)
    end

    -- O que não coube não foi ganho: se ninguém tinha de onde tirar, o ganho para aqui em vez
    -- de inventar ponto fora do pool.
    if gained <= 0 then return changes end

    changes[gang] = NoirInfluence.set(zone, gang, current + gained)
    return changes
end

---Quanto uma atividade vale para esta gang neste bairro.
---
---Base multiplicada pela distância até quem lidera: quanto mais concentrado o bairro está na
---mão de um, mais vale cada ação de quem não é ele. Empatados, não há bônus; líder não recebe
---bônus; bairro sem gang nenhuma também não — não se é azarão contra ninguém.
---@return number pontos inteiros
function NoirInfluence.effective(zone, gang, base)
    local k = tonumber(Config.Influence.Underdog) or 0
    base = math.floor(tonumber(base) or 0)
    if k <= 0 or base <= 0 then return base end

    local best = 0
    for _, points in pairs(NoirInfluence.of(zone)) do
        if points > best then best = points end
    end

    local gap = (best - NoirInfluence.get(zone, gang)) / total()
    if gap <= 0 then return base end

    return math.floor(base * (1 + k * gap) + 0.5)
end

---Quanto cada gang perde num passo de esfriamento.
---
---Proporcional ao que cada uma tem, pela mesma razão do rateio de quem paga: a fatia some, mas o
---desenho da disputa fica de pé enquanto some. Num passo achatado — todo mundo perde 10 — a gang
---com 20 pontos evaporaria em dois passos e a com 800 não sentiria, e o bairro abandonado
---terminaria como um duelo em vez de terra de ninguém.
---
---O mínimo de um ponto existe para o esfriamento terminar. Sem ele, 5% de 19 é zero e a gang
---ficaria pendurada em 19 para sempre.
---
---`keepAtThreshold` é o dono do bairro, quando ele tem piso: a influência dele desce até o
---limiar e para. Acima do limiar é gordura e derrete; a posse em si não. Quem tira um bairro de
---alguém é sempre outra gang, nunca um cronômetro — e ninguém perde território por ter passado
---o fim de semana fora.
---
---O piso é só do dono. Quem não é dono não tem posse para proteger: a fatia parada de um rival
---é exatamente a presença velha que deveria voltar para o neutro, e congelá-la deixaria o pool
---preso para sempre em pedaços que ninguém defende.
---@param keepAtThreshold? string gang que não desce do limiar
---@return table<string, number> losses quanto tirar de cada gang
function NoirInfluence.decayStep(zone, percent, keepAtThreshold)
    local losses = {}
    percent = tonumber(percent) or 0
    if percent <= 0 then return losses end

    local threshold = NoirInfluence.required()

    for gang, points in pairs(NoirInfluence.of(zone)) do
        local floor = gang == keepAtThreshold and threshold or 0

        if points > floor then
            local loss = math.floor(points * percent / 100)
            if loss < 1 then loss = 1 end
            if loss > points - floor then loss = points - floor end
            losses[gang] = loss
        end
    end

    return losses
end

-- Quem é dono do bairro não se decide aqui. A partir da trava de domínio isso deixou de ser
-- uma conta sobre a distribuição e virou estado guardado — quem tomou, e quando —, e mora em
-- `shared/ownership.lua`. Este arquivo responde só quanto cada um tem.
