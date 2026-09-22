-- Harness: carrega o shared/claims.lua real, que é lógica pura, e exercita a resposta que o
-- resto do servidor consome — o veredito vindo da influência, as tags que continuam sendo
-- reportadas sem decidir nada, e o que o `Config.FixedZones` tira do jogo.
--
-- A aritmética do pool tem spec próprio: tests/unit/influence_spec.lua.
local RES = (os.getenv('RES') or './')

function vec3(x, y, z) return { x = x, y = y, z = z } end

-- `exports('nome', fn)` no runtime registra; aqui só recebe e guarda.
local registered = {}
exports = setmetatable({}, { __call = function(_, name, fn) registered[name] = fn end })

dofile(RES .. 'shared/config.lua')
dofile(RES .. 'shared/influence.lua')
dofile(RES .. 'shared/ownership.lua')
dofile(RES .. 'shared/claims.lua')

local fails = 0
local function check(ok, label)
    if not ok then fails = fails + 1 end
    print(('  [%s] %s'):format(ok and 'ok' or 'FALHOU', label))
end

---Reconstrói o registro de tags com `n` tags de cada gang num bairro. As tags não concedem
---influência aqui: quem concede é `server/claims.lua`, no momento em que a tag nasce.
local function seedTags(zone, byGang)
    local list, id = {}, 0
    for gang, count in pairs(byGang) do
        for _ = 1, count do
            id = id + 1
            list[#list + 1] = { id = id, gang = gang, coords = vec3(0.0, 0.0, 0.0), zone = zone }
        end
    end
    NoirClaims.replace('graffiti', list)
end

---A placa é estado guardado, e quem escreve nela é o servidor. Aqui o teste carimba na mão o
---resultado que o servidor teria gravado.
local function seedInfluence(zone, byGang, owner)
    NoirInfluence.replaceAll({ [zone] = byGang })
    NoirOwnership.replaceAll(owner and { [zone] = { owner = owner, takenAt = 0 } } or {})
end

Config.FixedZones = {}

-- O que uma tag carrega, escrito onde falha. Ela já teve `radius`, e o desenho de diagnóstico
-- continuou lendo esse campo por dois modelos depois de ele sumir — não quebrava teste nenhum,
-- não quebrava o servidor, e só apareceu como crash quando alguém ligou o /territorydebug perto
-- de uma tag. Quem for consumir uma tag consulta esta lista.
print('contrato da tag:')
local claim = NoirClaims.add({
    id = 1, gang = 'ballas', coords = vec3(1.0, 2.0, 3.0), zone = 'davis', radius = 25.0,
})
check(claim.radius == nil, 'raio nao existe: dominio e por bairro, e quem desenhar circulo le nil')

local fields = {}
for key in pairs(claim) do fields[#fields + 1] = key end
table.sort(fields)
check(table.concat(fields, ',') == 'coords,gang,id,type,zone',
    'ela carrega exatamente: ' .. table.concat(fields, ', '))

print('bairro conquistavel:')
seedInfluence('davis', { ballas = 600, vagos = 200 }, 'ballas')
seedTags('davis', { ballas = 6, vagos = 2 })
local status = NoirClaims.getZoneStatus('davis')
check(status.state == 'controlled' and status.gang == 'ballas', 'o dono da placa e o dono')
check(status.conquerable == true, 'e a flag diz que esta em jogo')
check(status.influence.ballas == 600 and status.neutral == 200, 'o placar viaja junto')
check(status.total == 1000 and status.required == 510, 'com o pool e o limiar, para a tela nao refazer a conta')
check(status.counts.ballas == 6 and status.tags == 8, 'as tags continuam reportadas, sem decidir nada')

seedInfluence('davis', { ballas = 300 })
check(NoirClaims.getZoneStatus('davis').state == 'neutral', 'bairro sem placa nao tem dono')

-- O desafiante viaja junto do estado, e nao no lugar dele: o bairro segue `controlled` e o
-- dono segue dono, senao todo consumidor teria de aprender um estado novo para nao regredir.
seedInfluence('davis', { ballas = 400, vagos = 560 }, 'ballas')
status = NoirClaims.getZoneStatus('davis')
check(status.state == 'controlled' and status.gang == 'ballas', 'sob desafio, o dono segue dono')
check(status.challenger == 'vagos', 'e quem esta batendo na porta vai anunciado')
check(status.lockedUntil == Config.OwnershipLockSeconds, 'com a hora em que a trava cai')

print('tag sozinha nao domina:')
seedInfluence('davis', {})
seedTags('davis', { ballas = 20 })
check(NoirClaims.getZoneStatus('davis').state == 'neutral',
    'vinte tags sem influencia no livro-caixa nao valem o bairro')

print('bairro fixo e de ninguem:')
Config.FixedZones = { davis = true }
seedInfluence('davis', { ballas = 1000 }, 'ballas')
seedTags('davis', { ballas = 20 })
status = NoirClaims.getZoneStatus('davis')
check(status.state == 'neutral' and status.gang == nil, 'influencia nao toma o que nao esta em jogo')
check(status.conquerable == false, 'e a flag diz por que')
check(status.influence.ballas == 1000, 'o que ja estava guardado nao e apagado: fica congelado')
check(status.tags == 20, 'as tags continuam contadas: elas existem, so nao valem dominio')
check(NoirClaims.isConquerable('davis') == false, 'isConquerable acompanha')

print('bairro fixo com dono:')
Config.FixedZones = { davis = 'families' }
seedInfluence('davis', { ballas = 1000 }, 'ballas')
status = NoirClaims.getZoneStatus('davis')
check(status.state == 'controlled' and status.gang == 'families', 'o dono vem do config, nao da rua')
check(status.conquerable == false, 'e segue fora de disputa')
-- Quem consome domínio pergunta por coordenada, não por nome de bairro: o dono fixo tem
-- de chegar até lá também.
NoirClaims.zoneAt = function() return 'davis' end
check(NoirClaims.isInsideGangTerritory(vec3(0.0, 0.0, 0.0), 'families') == true,
    'e vale para quem pergunta por coordenada')
check(NoirClaims.isInsideGangTerritory(vec3(0.0, 0.0, 0.0), 'ballas') == false,
    'quem pichou ali continua de fora')

print('bairro fixo ignora a placa:')
seedInfluence('davis', { ballas = 900 }, 'ballas')
check(NoirClaims.getZoneStatus('davis').gang == 'families',
    'o config ganha da placa guardada, e nao ha duas respostas para a mesma pergunta')

print('bairro nunca declarado:')
Config.FixedZones = {}
check(NoirClaims.isConquerable('bairro_novo') == true, 'o padrao e a rua valer')

print('fora de bairro mapeado:')
NoirClaims.zoneAt = function() return nil end
status = NoirClaims.getTerritoryAt(vec3(0.0, 0.0, 0.0))
check(status.state == 'neutral' and status.conquerable == false, 'nao ha o que tomar onde nao ha bairro')

print('')
print(fails == 0 and 'claims_spec: ok' or ('claims_spec: ' .. fails .. ' falha(s)'))
os.exit(fails == 0 and 0 or 1)
