-- Domínio de bairro.
--
-- Quem decide de quem é o bairro é a influência (`shared/influence.lua`): cada bairro tem um
-- pool de pontos, cada gang tem a sua fatia, e quem passa do limiar sozinho é dono. Este
-- arquivo cuida das tags de graffiti — onde elas estão, em que bairro caem — e junta as duas
-- coisas na resposta que o resto do servidor consome.
--
-- O graffiti deixou de ser A regra e virou uma fonte de influência entre outras: ele, a venda de
-- droga e o que vier valem o que o `Config.Influence.Rates` disser, e a rua é tomada por quem
-- juntar 51% do pool e esperar a trava de quatro horas da última tomada.
-- Quanto cada fato vale está em `Config.Influence.Rates`, e a concessão acontece em
-- `server/claims.lua`, no momento em que a tag nasce ou morre — a influência é um livro-caixa
-- persistido, não um retrato das tags vivas.
--
-- Nem todo bairro entra nessa conta. O `Config.FixedZones` marca os que não estão em jogo, e
-- a resposta de cada bairro carrega `conquerable` para que quem desenha ou avisa saiba a
-- diferença entre "ninguém tomou ainda" e "aqui não se toma".
--
-- O arquivo é compartilhado porque as perguntas são as mesmas dos dois lados. O servidor é
-- dono do registro; o cliente guarda uma cópia para responder sem viagem de rede e para a
-- tela do mapa saber de quem é cada bairro.

NoirClaims = { list = {} }

---Qual bairro contém uma coordenada. Cada lado preenche do seu jeito: o servidor pergunta ao
---Zone Manager, o cliente testa o polígono que já recebeu. É a única parte que difere.
---@type fun(coords: table): string?
NoirClaims.zoneAt = nil

local function key(claimType, id) return ('%s:%s'):format(claimType, id) end

local function readCoords(coords)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y then return end
    return x, y, z or 0.0
end

---Uma reivindicação sem gang não existe: tag de quem não pertence a nenhuma gang é pichação,
---não é domínio de rua. Sem bairro também não: tag fora de área mapeada não reivindica nada.
---@return table? claim
function NoirClaims.normalize(data)
    if type(data) ~= 'table' or data.id == nil then return end

    local gang = data.gang
    if type(gang) ~= 'string' or gang == '' or gang == 'none' then return end

    local x, y, z = readCoords(data.coords)
    if not x then return end

    return {
        id = data.id,
        type = type(data.type) == 'string' and data.type or 'graffiti',
        gang = gang,
        coords = vec3(x, y, z),
        -- Resolvido uma vez, quando a tag nasce. Contar o domínio de um bairro não pode
        -- custar um teste de polígono por tag a cada pergunta.
        zone = type(data.zone) == 'string' and data.zone or nil,
    }
end

function NoirClaims.add(data)
    local claim = NoirClaims.normalize(data)
    if not claim then return end
    NoirClaims.list[key(claim.type, claim.id)] = claim
    return claim
end

function NoirClaims.remove(claimType, id)
    if id == nil then return false end
    local k = key(claimType or 'graffiti', id)
    if not NoirClaims.list[k] then return false end
    NoirClaims.list[k] = nil
    return true
end

---Troca de uma vez todas as áreas de um tipo. É como o registro é reconstruído quando o
---resource sobe: não há tabela própria no banco, o domínio sai dos graffitis que existem.
function NoirClaims.replace(claimType, entries)
    claimType = claimType or 'graffiti'

    for k, claim in pairs(NoirClaims.list) do
        if claim.type == claimType then NoirClaims.list[k] = nil end
    end

    for i = 1, #(entries or {}) do NoirClaims.add(entries[i]) end
end

-- API --------------------------------------------------------------------------------

---Bairro fixo é o que não está em jogo: as tags continuam existindo e continuam contadas,
---mas não decidem nada ali dentro. O `Config.FixedZones` diz quais são, e de quem — `true`
---para "de ninguém, para sempre", nome de gang para "desta gang, sem ter de pichar".
---@return boolean fixed, string? owner
local function fixedZone(zone)
    local entry = type(zone) == 'string' and Config.FixedZones[zone] or nil
    if not entry then return false end
    if type(entry) == 'string' and entry ~= '' and entry ~= 'none' then return true, entry end
    return true
end

---Se um bairro está em disputa no mapa. Bairro que ninguém declarou fixo é conquistável:
---o padrão é a rua valer.
---@return boolean
local function isConquerable(zone)
    return not (fixedZone(zone))
end

---Quantas tags cada gang tem dentro de um bairro.
---@return table<string, number> counts, number total
function NoirClaims.countsIn(zone)
    local counts, total = {}, 0
    if type(zone) ~= 'string' then return counts, total end

    for _, claim in pairs(NoirClaims.list) do
        if claim.zone == zone then
            counts[claim.gang] = (counts[claim.gang] or 0) + 1
            total = total + 1
        end
    end

    return counts, total
end

---Situação de um bairro: tudo que uma tela ou um alerta precisam saber sobre ele.
---
---Bairro fixo responde direto do config e nem chega à conta: ou é neutro para sempre, ou é da
---gang declarada lá. Nos outros, o dono vem da placa (`shared/ownership.lua`) e a influência
---diz quanto cada um tem.
---
---`challenger` é quem já alcançou o limiar e não é o dono — quem está esperando a trava cair.
---Ele não é um estado: o bairro continua `controlled` e o dono continua dono, com tudo que isso
---implica para quem consome. É informação para a tela e para o aviso, não para o veredito.
---
---Os números de influência viajam mesmo em bairro fixo. Marcar um bairro como fixo não apaga
---o que as gangs já tinham conquistado nele: o registro fica onde está, congelado, e volta a
---valer no dia em que alguém tirar o bairro da lista.
---@return table { zone, state, conquerable, influence, neutral, total, required, counts, tags, gang?, challenger?, lockedUntil? }
function NoirClaims.getZoneStatus(zone)
    local counts, tags = NoirClaims.countsIn(zone)
    local fixed, owner = fixedZone(zone)
    local _, neutral = NoirInfluence.sumOf(zone)

    local status = {
        zone = zone,
        state = 'neutral',
        -- A flag viaja junto com a situação, e não numa consulta à parte: quem desenha o
        -- mapa ou decide um alerta precisa saber, no mesmo lugar, se aquilo é alvo ou
        -- cenário. `state` continua sendo o que o bairro é agora — bairro fixo com dono é
        -- `controlled` como qualquer outro, senão todo consumidor teria de aprender um
        -- estado novo para continuar funcionando igual.
        conquerable = not fixed,
        -- A fatia de cada gang e o que ninguém tomou. É o que o mapa desenha e o que responde
        -- "quanto falta" sem que a tela precise refazer a aritmética do pool.
        influence = NoirInfluence.of(zone),
        neutral = neutral,
        total = Config.Influence.Total,
        required = NoirInfluence.required(),
        -- As tags continuam no pacote porque continuam sendo o que se vê na rua. Elas não
        -- decidem mais nada sozinhas: são a origem de parte da influência, não o placar.
        counts = counts,
        tags = tags,
    }

    if fixed then
        if owner then
            status.state = 'controlled'
            status.gang = owner
        end
        return status
    end

    status.gang = NoirOwnership.get(zone)
    status.state = status.gang and 'controlled' or 'neutral'
    status.challenger = NoirOwnership.challengerOf(zone)
    status.lockedUntil = NoirOwnership.lockedUntil(zone)
    return status
end

---Quem domina uma coordenada. Fora de bairro mapeado, ninguém.
---@return table { state: 'neutral'|'controlled', conquerable: boolean, gang?, challenger?, lockedUntil?, zone?, influence?, neutral?, total?, required? }
local function getTerritoryAt(coords)
    local zone = NoirClaims.zoneAt and NoirClaims.zoneAt(coords)
    -- Fora de bairro mapeado não há o que tomar: é neutro e continua neutro.
    if not zone then return { state = 'neutral', conquerable = false } end
    return NoirClaims.getZoneStatus(zone)
end

---Tags de graffiti cujo centro está dentro de `distance` da coordenada. Continua sendo por
---distância, e não por bairro: quem pergunta isso quer saber o que está por perto.
---@return table[] claims
local function getGraffitiTerritoriesNear(coords, distance)
    local x, y = readCoords(coords)
    distance = tonumber(distance) or 100.0
    if not x then return {} end

    local limit = distance * distance
    local near = {}

    for _, claim in pairs(NoirClaims.list) do
        if claim.type == 'graffiti' then
            local dx, dy = x - claim.coords.x, y - claim.coords.y
            if (dx * dx + dy * dy) <= limit then near[#near + 1] = claim end
        end
    end

    return near
end

---Verdadeiro só quando a gang **domina** o ponto. Bairro em disputa não é de ninguém.
---@return boolean
local function isInsideGangTerritory(coords, gang)
    if type(gang) ~= 'string' or gang == '' then return false end
    return getTerritoryAt(coords).gang == gang
end

NoirClaims.isConquerable = isConquerable
NoirClaims.getTerritoryAt = getTerritoryAt
NoirClaims.getGraffitiTerritoriesNear = getGraffitiTerritoriesNear
NoirClaims.isInsideGangTerritory = isInsideGangTerritory

exports('getTerritoryAt', getTerritoryAt)
exports('getGraffitiTerritoriesNear', getGraffitiTerritoriesNear)
exports('isInsideGangTerritory', isInsideGangTerritory)
exports('getZoneStatus', function(zone) return NoirClaims.getZoneStatus(zone) end)
exports('isConquerable', isConquerable)
