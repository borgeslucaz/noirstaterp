-- Domínio de bairro por graffiti.
--
-- O modelo é o mais simples que existe: cada bairro do Zone Manager pede um número fixo de
-- tags, e a gang com mais tags dentro dele — desde que tenha alcançado esse número — é a
-- dona. Sem peso, sem decaimento, sem influência progressiva.
--
-- Isto já foi um círculo de raio fixo por graffiti, e a troca por bairro não encostou no
-- noir_graffiti: ele continua registrando só "existe uma tag da gang X nesta coordenada". Era
-- essa a fronteira que o desenho protegia, e ela pagou.
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

---Situação de um bairro.
---
---Quem tem mais tags leva, desde que tenha alcançado o número exigido. Empate no topo entre
---duas gangs que alcançaram vira disputa — e é o único jeito de `contested` acontecer, porque
---contestar de verdade é apagar a tag do rival e pôr a sua, não sobrepor área.
---@return table { zone, required, counts, total, state, gang?, gangs? }
function NoirClaims.getZoneStatus(zone)
    local counts, total = NoirClaims.countsIn(zone)
    local status = {
        zone = zone,
        required = Config.RequiredGraffiti,
        counts = counts,
        total = total,
        state = 'neutral',
    }

    local best, leaders = 0, {}
    for gang, count in pairs(counts) do
        if count > best then
            best, leaders = count, { gang }
        elseif count == best then
            leaders[#leaders + 1] = gang
        end
    end

    if best < Config.RequiredGraffiti then return status end

    if #leaders > 1 then
        table.sort(leaders)
        status.state = 'contested'
        status.gangs = leaders
    else
        status.state = 'controlled'
        status.gang = leaders[1]
    end

    return status
end

---Quem domina uma coordenada. Fora de bairro mapeado, ninguém.
---@return table { state: 'neutral'|'controlled'|'contested', gang?, gangs?, zone?, counts?, required? }
local function getTerritoryAt(coords)
    local zone = NoirClaims.zoneAt and NoirClaims.zoneAt(coords)
    if not zone then return { state = 'neutral' } end
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

NoirClaims.getTerritoryAt = getTerritoryAt
NoirClaims.getGraffitiTerritoriesNear = getGraffitiTerritoriesNear
NoirClaims.isInsideGangTerritory = isInsideGangTerritory

exports('getTerritoryAt', getTerritoryAt)
exports('getGraffitiTerritoriesNear', getGraffitiTerritoriesNear)
exports('isInsideGangTerritory', isInsideGangTerritory)
exports('getZoneStatus', function(zone) return NoirClaims.getZoneStatus(zone) end)
