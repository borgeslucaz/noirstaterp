local T = dofile('tests/testlib.lua')

-- Stubs dos construtores de vetor usados por config/shared.lua.
function vector3(x, y, z) return { x = x, y = y, z = z } end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end

local shared = T.loadConfig('config/shared.lua')
local server = T.loadConfig('config/server.lua')
local client = T.loadConfig('config/client.lua')

local function read(path)
    local file = assert(io.open(path, 'r'))
    local content = file:read('*a')
    file:close()
    return content
end

-- Sigilo: nada econômico no config público -------------------------------------------

local sharedSource = read('config/shared.lua')
for _, forbidden in ipairs({ 'unitPrice', 'hirePrice', 'dispatchChance', 'pursePercent', 'adminAce' }) do
    assert(not sharedSource:find(forbidden, 1, true),
        ('config/shared.lua must not contain %s'):format(forbidden))
end

local manifest = read('fxmanifest.lua')
assert(manifest:find("'config/shared.lua'", 1, true), 'shared config must be downloadable')
assert(manifest:find("'config/client.lua'", 1, true), 'client config must be downloadable')
assert(not manifest:find("'config/server.lua'", 1, true), 'server config must not be in files')
assert(not manifest:find('ox_target', 1, true), 'providers are bgrz_core dependencies, not ours')
assert(not manifest:find('sd-phone', 1, true), 'phone provider is a bgrz_core dependency')
assert(manifest:find("'bgrz_core'", 1, true), 'bridge dependency declared')
assert(not manifest:find('noir_illegal_core', 1, true), 'progression bridge must not be a dependency')
assert(not manifest:find('noir_gangs', 1, true), 'gang provider is reached through bgrz_core')

-- Locais ------------------------------------------------------------------------------

local outpostCount = 0
for id, definition in pairs(shared.outposts) do
    outpostCount = outpostCount + 1
    assert(type(definition.label) == 'string' and #definition.label > 0, id .. ' needs a label')
    assert(type(definition.description) == 'string' and #definition.description > 0,
        id .. ' needs a description')
    -- `computer` deixou de existir no posto: ele vive na planta do interior. Coordenada obsoleta
    -- que ninguém lê foi o que manteve o ponto de validação enterrado sob o piso por dias.
    assert(definition.computer == nil, id .. ' must not carry a computer coord; it lives in the shell')
    assert(definition.entrance, id .. ' needs an entrance coord')
    assert(#definition.dealerCorners >= 6, id .. ' needs at least six corners')
    assert(#definition.dealerCorners >= server.limits.maxDealersPerOutpost,
        id .. ' needs more corners than dealers')
    assert(#definition.typePool > 0, id .. ' needs a type pool')

    local seen = {}
    for index = 1, #definition.dealerCorners do
        local corner = definition.dealerCorners[index]
        local key = ('%s:%s'):format(corner.x, corner.y)
        assert(not seen[key], id .. ' has duplicate corners')
        seen[key] = true
    end
end
assert(outpostCount >= 3, 'at least three outposts must be registered')

local drugCapable = 0
for _, definition in pairs(shared.outposts) do
    for index = 1, #definition.typePool do
        if definition.typePool[index] == 'drug' then drugCapable = drugCapable + 1 break end
    end
end
assert(drugCapable >= server.rotation.activeDrugOutposts, 'not enough drug-capable outposts')

-- Perfis e economia ----------------------------------------------------------------------

assert(#shared.dealerProfiles >= 6, 'at least six dealer profiles for the MVP')
local profileKeys = {}
for index = 1, #shared.dealerProfiles do
    local profile = shared.dealerProfiles[index]
    assert(not profileKeys[profile.key], 'duplicate profile key ' .. profile.key)
    profileKeys[profile.key] = true
    assert(type(server.dealerHirePrice[profile.key]) == 'number', profile.key .. ' needs a hire price')
    for _, stat in ipairs({ 'speed', 'capacity', 'negotiation', 'split' }) do
        local value = profile.stats[stat]
        assert(type(value) == 'number' and value >= 0 and value <= 100,
            ('%s.%s must be between 0 and 100'):format(profile.key, stat))
    end
end

for index = 1, #shared.products do
    local product = shared.products[index]
    local rule = server.products[product.id]
    assert(rule, product.id .. ' needs a server-side rule')
    assert(rule.unitPrice > 0, product.id .. ' needs a positive price')
    assert(rule.quantity.min >= 1 and rule.quantity.max >= rule.quantity.min,
        product.id .. ' has an invalid quantity range')
end

-- Venda passiva deve render menos que a venda ativa do op-drugselling ------------------------
-- Referência do op-drugselling: weed_brick 50-100, meth 150-250, cokebaggy 450-700.
local activeFloor = { weed_brick = 50, meth = 150, cokebaggy = 450 }
for id, floorPrice in pairs(activeFloor) do
    local rule = server.products[id]
    if rule then
        assert(rule.unitPrice >= floorPrice, id .. ' passive price fell below the active floor')
        assert(rule.unitPrice <= floorPrice * 1.2,
            id .. ' passive price should stay close to the active floor')
    end
end

-- Limites coerentes ---------------------------------------------------------------------------

assert(server.limits.maxStockPerDeposit <= server.limits.maxStockTotal, 'deposit cap above total cap')
assert(server.limits.maxDealersPerOutpost == shared.limits.maxDealersPerOutpost,
    'dealer limit must match between shared and server config')
assert(server.limits.maxStockTotal == shared.limits.maxStockTotal, 'stock limit mismatch')
assert(server.limits.maxStockPerDeposit == shared.limits.maxStockPerDeposit, 'deposit limit mismatch')
assert(server.sales.minimumIntervalSeconds >= 30, 'minimum sale interval must be at least 30s')
assert(server.sales.baseIntervalSeconds >= server.sales.minimumIntervalSeconds, 'base below minimum')
assert(server.sales.maxStartupCatchupSalesPerDealer <= 1, 'startup catch-up must stay bounded')
assert(server.sales.dispatchChance >= 0 and server.sales.dispatchChance <= 100, 'invalid dispatch chance')
assert(server.sales.dispatchCooldownSeconds > 0, 'dispatch needs a cooldown')
assert(server.operationRetention.days == 15, 'operation retention must be 15 days')
assert(server.operationRetention.intervalSeconds == 12 * 60 * 60, 'operation prune must run every 12 hours')
assert(server.operationRetention.batchSize > 0, 'operation prune batch must be positive')
assert(server.operationRetention.maxBatchesPerRun > 0, 'operation prune run must be bounded')
assert(server.robbery.cooldownSeconds > 0, 'robbery needs a cooldown')
assert(server.dealers.downCooldownSeconds > 0, 'a kill needs a cooldown')
assert(server.dealers.dispatchChance >= 0 and server.dealers.dispatchChance <= 100,
    'invalid kill dispatch chance')
-- Sem chamado, executar os corredores é a forma silenciosa de atacar um posto: não rende loot,
-- não acorda a polícia e o dono só descobre pelo telefone.
assert(server.dealers.dispatchChance > 0, 'killing a runner must be able to call the police')
assert(type(server.dispatch.downCode) == 'string' and #server.dispatch.downCode > 0,
    'the kill dispatch needs a code of its own')
-- Executar quem já foi revistado não acrescenta tempo: ele fica no cooldown do roubo, e a morte
-- só põe o corpo no chão e chama a polícia. Não há prazo próprio para esse caminho, e a chave que
-- existia foi removida junto com as duas anteriores que tentaram o mesmo.
assert(server.dealers.downAfterRobberyCooldownSeconds == nil
    and server.dealers.robbedGraceSeconds == nil
    and server.dealers.robbedDownCooldownSeconds == nil,
    'a kill after a robbery keeps the robbery cooldown; it has no timer of its own')
-- Morte limpa é de propósito curta: matar não é a forma de tirar um posto de operação, e precisa
-- custar menos que o roubo, senão atirar vira o caminho barato para o mesmo resultado.
assert(server.dealers.downCooldownSeconds < server.robbery.cooldownSeconds,
    'a plain kill must cost less than robbing the runner')
assert(server.robbery.pursePercent.max <= 100 and server.robbery.stockPercent.max <= 100,
    'robbery percentages must stay within 0-100')
assert(server.robbery.pursePercent.min <= server.robbery.pursePercent.max, 'invalid purse percent range')

-- Trava de assalto por identidade. Ela é outra coisa que `cooldownSeconds`: aquele tira o corredor
-- de operação para todo mundo, este impede QUEM JÁ ROUBOU de roubar o mesmo de novo.
assert(type(server.robbery.gangLockSeconds) == 'number' and server.robbery.gangLockSeconds > 0,
    'robbery.gangLockSeconds must be a positive duration')
assert(type(server.robbery.soloLockSeconds) == 'number' and server.robbery.soloLockSeconds > 0,
    'robbery.soloLockSeconds must be a positive duration')
-- Sem gang o jogador espera mais: não tem com quem dividir o alvo nem a quem responder.
assert(server.robbery.soloLockSeconds >= server.robbery.gangLockSeconds,
    'a lone robber must wait at least as long as a crew does')
-- E a trava precisa durar bem mais que a recuperação, senão não muda nada: o corredor voltaria a
-- ser roubável pelo mesmo detentor antes de ela vencer.
assert(server.robbery.gangLockSeconds > server.robbery.cooldownSeconds,
    'the identity lock must outlast the recovery window, or it changes nothing')

-- Gang offline: não rende e não perde. As duas metades andam juntas, e é a combinação que
-- importa. Venda travada com roubo liberado transforma a madrugada em perda unilateral para
-- quem não tem ninguém online — foi para fechar isso que a proteção existe.
assert(type(server.ownerOffline.protectDealers) == 'boolean',
    'offline protection must be an explicit boolean')
if server.sales.requireOwnerMemberOnline then
    assert(server.ownerOffline.protectDealers,
        'if an offline crew earns nothing, it must not lose anything either')
end
assert(server.claim.durationMs >= 10000, 'claim must take a meaningful amount of time')
assert(server.claim.ownerDurationHours > 0, 'control duration must be positive')
assert(client.minigames.claim.typewriterCount > 0, 'claim typewriter needs at least one character')
assert(client.minigames.claim.typewriterTimeMs > 0, 'claim typewriter needs a positive time limit')

-- Bucket por outpost. Um local sem entrada cairia no mundo compartilhado por omissão, o que hoje
-- não muda nada — mas no dia em que o interior tiver número próprio, seria um posto cujo painel
-- é validado contra o bucket errado e não abre para ninguém.
assert(type(server.buckets) == 'table', 'buckets block missing')
for id in pairs(shared.outposts) do
    assert(type(server.buckets[id]) == 'number' and server.buckets[id] >= 0,
        id .. ' needs an explicit routing bucket')
end
for id in pairs(server.buckets) do
    assert(shared.outposts[id], ('buckets points at unknown outpost %s'):format(tostring(id)))
end

-- Buckets não-zero têm que ser distintos. Postos compartilham a mesma planta de interior, então lá
-- dentro o bucket é a ÚNICA coisa separando um do outro: repetir o número daria a um jogador o
-- painel do posto errado. `0` pode repetir à vontade — é o mundo compartilhado, onde todos estão
-- enquanto o terminal for a céu aberto.
-- E precisam ser diferentes de zero: `0` é o mundo compartilhado, então um posto ali teria o
-- interior acessível a partir de qualquer outro.
local seenBucket = {}
for id, bucket in pairs(server.buckets) do
    assert(bucket ~= 0, id .. ' cannot live in the shared world once it has an interior')
    assert(not seenBucket[bucket],
        ('bucket %d is shared by %s and %s'):format(bucket, tostring(seenBucket[bucket]), id))
    seenBucket[bucket] = id
end

-- Plantas de interior --------------------------------------------------------------------------

assert(type(shared.shells) == 'table' and next(shared.shells) ~= nil, 'shells block missing')
for name, shell in pairs(shared.shells) do
    assert(type(shell.model) == 'string' and shell.model:match('^[%w_]+$'),
        ('shell %s needs a plain model name'):format(name))
    for _, field in ipairs({ 'origin', 'door', 'computer' }) do
        local coord = shell[field]
        assert(type(coord) == 'table' and type(coord.x) == 'number' and type(coord.w) == 'number',
            ('shell %s needs a vector4 for %s'):format(name, field))
    end
    -- O jogador nasce na porta, então ela não pode estar dentro do alcance do computador: o painel
    -- abriria sozinho no instante da entrada, sem ninguém andar até a mesa.
    local dx, dy = shell.door.x - shell.computer.x, shell.door.y - shell.computer.y
    assert(math.sqrt(dx * dx + dy * dy) > shared.interaction.computerDistance,
        ('shell %s puts the door inside the computer reach'):format(name))
    local computerProps = 0
    for index = 1, #(shell.props or {}) do
        local prop = shell.props[index]
        assert(type(prop.model) == 'string',
            ('shell %s prop %d needs a model name'):format(name, index))
        assert(type(prop.coords) == 'table' and type(prop.coords.w) == 'number',
            ('shell %s prop %d needs a vector4'):format(name, index))
        if math.abs(prop.coords.x - shell.computer.x) < 0.01
            and math.abs(prop.coords.y - shell.computer.y) < 0.01 then
            computerProps = computerProps + 1
        end
    end

    -- O alvo do painel fica pendurado no prop que está em `computer`, então tem que existir
    -- exatamente um ali. As duas coordenadas já viveram separadas, e mover o laptop deixou o ponto
    -- de validação do servidor para trás, enterrado sob o piso, com o painel abrindo por tolerância.
    assert(computerProps == 1,
        ('shell %s must have exactly one prop sitting on `computer`, found %d')
            :format(name, computerProps))
end

-- Todo posto aponta para uma planta que existe.
for id, definition in pairs(shared.outposts) do
    assert(type(definition.shell) == 'string',
        id .. ' needs a shell reference')
    assert(shared.shells[definition.shell],
        ('%s points at unknown shell %s'):format(id, tostring(definition.shell)))
    -- `entrance` virou vec4: o retorno ao sair é um teleporte, e teleporte sem heading larga o
    -- jogador virado para qualquer lado.
    assert(type(definition.entrance.w) == 'number', id .. ' entrance needs a heading')
end

for _, action in ipairs({ 'view', 'stock', 'hire', 'fire', 'collect', 'claim' }) do
    assert(type(server.permissions[action]) == 'number', 'missing permission for ' .. action)
end
assert(server.permissions.claim >= server.permissions.stock, 'claim must not be easier than stocking')
assert(server.permissions.collect >= server.permissions.stock, 'collect must not be easier than stocking')

-- O atendente do terminal foi removido: a porta do interior tomou o lugar dele, e com ela o alvo
-- passou a ser um lugar de verdade em vez de uma esfera suspensa no ar.
assert(shared.terminalNpc == nil,
    'the terminal attendant was replaced by the interior door; drop the terminalNpc block')

-- Caminhada do corredor: precisa ser desligável e caber na área da esquina.
local wander = shared.dealerWander
assert(type(wander) == 'table', 'dealerWander block missing')
assert(type(wander.enabled) == 'boolean', 'dealerWander.enabled must be a boolean')
-- O raio também é a folga que o servidor concede quando NÃO confia na posição do ped: sem
-- reporte fresco, `V.dealerReach` mede contra a esquina cadastrada e soma este raio. Crescer aqui
-- afrouxa essa recusa na mesma medida, e é por isso que existe um teto.
assert(type(wander.radius) == 'number' and wander.radius > 0 and wander.radius <= 60,
    'dealerWander.radius must stay within a plausible corner')
assert(wander.minimalLength > 0 and wander.minimalLength < wander.radius,
    'a wander leg must be shorter than the radius')
assert(wander.timeBetweenWalks >= 0, 'invalid pause between walks')

-- Parada por jogador perto. `0` desliga, e desligada é como está: quem mantém a posição honesta
-- passou a ser o reporte do dono de rede, não o ped estar imóvel. Ligada, continua valendo a
-- regra antiga — parar antes de o jogador alcançar a distância da revista.
assert(type(wander.pauseNearPlayers) == 'number' and wander.pauseNearPlayers >= 0,
    'pauseNearPlayers must be a distance or 0 to disable')
if wander.pauseNearPlayers > 0 then
    assert(wander.pauseNearPlayers > server.robbery.interactionDistance,
        'the runner must stop well before a player can reach robbery range')
    assert(wander.pauseNearPlayers >= server.holdup.maxDistance * 0.75,
        'stopping range should cover most of the holdup range')
end

-- Com a parada desligada, o assalto mede contra uma leitura de até um reporte de idade. Ela
-- precisa caber com folga no alcance da revista, senão a recusa vira sorte.
if wander.pauseNearPlayers <= 0 then
    local staleness = 2.0 * (wander.reportIntervalMs / 1000)
    assert(staleness < server.robbery.interactionDistance + server.validation.maxDistanceTolerance,
        'a walking runner would drift out of robbery range between reports')
end

-- Reação a evento enquanto anda. Parado o bloqueio entra sempre, sem passar pelo config.
assert(type(wander.blockEvents) == 'boolean', 'dealerWander.blockEvents must be a boolean')

-- Coleira: puxar o corredor de volta antes do raio transformaria cada trecho normal da caminhada
-- numa volta para casa, e o ped ficaria colado na esquina.
assert(type(wander.leashDistance) == 'number' and wander.leashDistance > wander.radius,
    'dealerWander.leashDistance must sit beyond the wander radius')

-- Reporte de posição. Raro demais e a validação mede contra um ponto velho; frequente demais e
-- vira tráfego à toa, já que o corredor anda devagar.
assert(type(wander.reportIntervalMs) == 'number'
    and wander.reportIntervalMs >= 250 and wander.reportIntervalMs <= 5000,
    'dealerWander.reportIntervalMs must sit between 250ms and 5s')
assert(server.validation.reportedPositionTtlSeconds * 1000 > wander.reportIntervalMs * 2,
    'the reported position must outlive at least two report intervals')
assert(server.rateLimits.position < wander.reportIntervalMs,
    'the position rate limit must not throttle the configured report interval')

-- O orçamento de um intervalo de reporte precisa cobrir um ped correndo, senão o corredor que
-- foge é rejeitado justamente quando mais importa saber onde ele está.
local perReport = server.validation.reportedPositionMaxSpeed * (wander.reportIntervalMs / 1000)
    + server.validation.reportedPositionSlack
assert(perReport >= 8.0, 'one report interval must cover a sprinting ped')
assert(server.validation.reportedPositionMaxSpeed <= 20.0,
    'the speed budget must stay below what a vehicle could cover')
assert(server.validation.reportedPositionMaxGapSeconds >= 1,
    'the gap cap must allow at least one second of movement')

-- Rotação fixada. É ferramenta de teste, então o que importa é que aponte para postos reais:
-- um id errado aqui desativaria todos e deixaria o sistema sem nenhum posto ativo.
local forced = server.rotation.forced
assert(forced == nil or type(forced) == 'table', 'rotation.forced must be a table when set')
if type(forced) == 'table' then
    for id, operationType in pairs(forced) do
        assert(shared.outposts[id], ('rotation.forced points at unknown outpost %s'):format(tostring(id)))
        assert(operationType == 'drug' or operationType == 'money',
            ('rotation.forced[%s] must be drug or money'):format(tostring(id)))
        local pool = shared.outposts[id].typePool
        local allowed = false
        for index = 1, #pool do
            if pool[index] == operationType then allowed = true end
        end
        assert(allowed, ('%s does not accept operation type %s'):format(id, operationType))
    end
end

-- Esquinas não podem coincidir. Guarda contra o erro de digitação que põe duas no mesmo ponto,
-- o que empilharia dois corredores sob o mesmo alvo do ox_target. O alvo ao cadastrar um local
-- novo é 50 m, dois raios de perambulação, para que as áreas nem se toquem; os três postos
-- originais ainda são coordenada placeholder e ficam abaixo disso.
for id, definition in pairs(shared.outposts) do
    local corners = definition.dealerCorners
    assert(#corners >= server.limits.maxDealersPerOutpost,
        id .. ' needs at least one corner per runner')
    for i = 1, #corners do
        for j = i + 1, #corners do
            local dx, dy = corners[i].x - corners[j].x, corners[i].y - corners[j].y
            local gap = math.sqrt(dx * dx + dy * dy)
            assert(gap >= 20.0,
                ('%s corners %d and %d are %.1fm apart; runners would stack'):format(id, i, j, gap))
        end
    end
end

-- A tomada sorteia uma identidade para cada perfil, sem repetir nomes ou modelos no elenco.
local identities = shared.dealerIdentities
assert(type(identities) == 'table', 'dealer identities must exist')
for _, field in ipairs({ 'names', 'models' }) do
    local list = identities[field]
    assert(type(list) == 'table' and #list >= #shared.dealerProfiles,
        ('identity list %s must cover every profile drawn on claim'):format(field))
    local seen = {}
    for index = 1, #list do
        local value = list[index]
        assert(type(value) == 'string' and value ~= '', ('identity %s entry must be a string'):format(field))
        assert(not seen[value], ('identity %s must not repeat %s'):format(field, value))
        seen[value] = true
    end
end

-- A reação chega por evento e por state bag, e o bag costuma atrasar. A janela precisa cobrir
-- esse atraso sem chegar perto da duração da rendição, senão uma reação velha se arrastaria.
assert(type(client.holdup.reactionGraceMs) == 'number' and client.holdup.reactionGraceMs > 0,
    'the reaction grace window must be a positive number')
assert(client.holdup.reactionGraceMs < server.holdup.surrenderSeconds * 1000,
    'the grace window must be far shorter than a surrender')

-- Cenários de ócio sorteados: removidos. Parado é parado, no cenário fixo de esquina. O sorteio
-- era a animação aleatória que aparecia por cima da rendição enquanto o dicionário carregava.
assert(wander.idle == nil,
    'the random idle scenarios were removed; standing still uses client.dealerScenario')

-- Salto de altura aceito da malha. Precisa ser pequeno o bastante para recusar o andar de baixo
-- (no píer a diferença entre deck e areia é de onze metros) e folgado o bastante para o desnível
-- normal entre a coordenada cadastrada e o piso onde o ped de fato assenta, medido em ~1,5 m.
assert(type(wander.maxHeightOffset) == 'number' and wander.maxHeightOffset > 0,
    'dealerWander.maxHeightOffset must be a positive distance')
assert(wander.maxHeightOffset <= 5.0,
    'a height offset this large would accept the floor below as a walkable corner')

-- Caminhar não pode levar o corredor para fora do alcance do próprio assalto.
assert(wander.radius >= server.robbery.interactionDistance,
    'a radius below the robbery distance would make the walk pointless')

assert(type(shared.phone.identifier) == 'string' and shared.phone.identifier:match('^[%w_-]+$'),
    'phone identifier must be a plain slug')
assert(type(shared.phone.defaultApp) == 'boolean', 'phone.defaultApp must be a boolean')

-- Cenários do corredor parado: de pé na esquina em serviço, agachado com medo fora dela. Os dois
-- são obrigatórios porque `holdGround` sempre recebe um dos dois, e cenário vazio deixa o ped sem
-- postura nenhuma justamente nos estados em que ele fica mais tempo à vista.
assert(type(client.dealerScenario) == 'string' and client.dealerScenario ~= '',
    'dealerScenario missing')
assert(type(client.cowerScenario) == 'string' and client.cowerScenario ~= '',
    'cowerScenario missing')

assert(type(client.animations.claim.dict) == 'string', 'claim animation dictionary missing')
assert(client.progress.depositDurationMs > 0, 'deposit progress duration missing')
assert(shared.payoutItem == server.payout.item, 'payout item mismatch between configs')

-- Locales ---------------------------------------------------------------------------------------

local ptbr = read('locales/pt-br.json')
local en = read('locales/en.json')
for _, key in ipairs({
    'target', 'progress', 'dealer', 'claim', 'robbery', 'phone', 'dispatch', 'error',
}) do
    assert(ptbr:find('"' .. key .. '"', 1, true), 'pt-br locale missing section ' .. key)
    assert(en:find('"' .. key .. '"', 1, true), 'en locale missing section ' .. key)
end

print('config_spec: ok')
