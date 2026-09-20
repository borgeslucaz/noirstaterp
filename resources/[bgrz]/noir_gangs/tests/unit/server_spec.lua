-- Carrega server/main.lua com o runtime do FiveM e o bgrz_core stubados, e exercita as
-- regras que não dá para ver lendo: hierarquia, sucessão, saída e limpeza de convite.
local T = dofile('tests/testlib.lua')

function vec3(x, y, z) return { x = x, y = y, z = z } end
dofile('shared/config.lua')

-- Mundo controlado pelo teste ------------------------------------------------------------
local FULL = { 'view_members', 'view_offline_members', 'invite', 'remove_member', 'promote', 'demote',
    'view_reputation', 'view_products' }

local function rank(label, permissions, isBoss)
    local set = {}
    for i = 1, #permissions do set[permissions[i]] = true end
    return { label = label, permissions = set, isBoss = isBoss == true }
end

local world = {
    gangs = {
        ballas = { label = 'Ballas', ranks = {
            [0] = rank('Novato', { 'view_members' }),
            [1] = rank('Soldado', { 'view_members' }),
            [2] = rank('Tenente', { 'view_members', 'invite' }),
            [3] = rank('Braço direito', FULL),
            [4] = rank('Chefe', FULL, true) } },
        duo = { label = 'Dupla', ranks = {
            [0] = rank('Membro', { 'view_members' }),
            [1] = rank('Chefe', FULL, true) } },
        -- Cargos esparsos: o Qbox aceita, e `level + 1` não acerta nenhum deles.
        trio = { label = 'Trio', ranks = {
            [0] = rank('Base', { 'view_members' }),
            [2] = rank('Meio', FULL),
            [5] = rank('Topo', FULL, true) } },
    },
    characters = {},
    online = {},
    membership = {},
    reputation = { ballas = 0, duo = 0, trio = 0 },
    products = { ballas = { drugs = true }, duo = {}, trio = { weapons = true, ammo = true } },
    distance = 0.5,
}

local function addCharacter(citizenId, source, name)
    world.characters[citizenId] = { citizenId = citizenId, source = source, name = { full = name } }
    if source then world.online[source] = citizenId end
    world.membership[citizenId] = world.membership[citizenId] or {}
end

local notifications = {}

-- Stub do bridge -------------------------------------------------------------------------
local core = {}

function core:Notify(source, text, kind)
    notifications[#notifications + 1] = { source = source, text = text, kind = kind }
end

function core:GetCharacter(source)
    local citizenId = world.online[source]
    return citizenId and world.characters[citizenId] or nil
end

function core:GetCharacterSource(citizenId)
    local character = world.characters[citizenId]
    return character and character.source or nil
end

function core:GetCharacterGangs(citizenId)
    local gangs = {}
    for name, grade in pairs(world.membership[citizenId] or {}) do gangs[name] = grade end
    return gangs
end

function core:GetCharacterNames(citizenIds)
    local names = {}
    for i = 1, #citizenIds do
        local character = world.characters[citizenIds[i]]
        if character then names[citizenIds[i]] = character.name.full end
    end
    return names
end

---Gang primária: a de maior cargo entre as do personagem, como o Qbox mantém depois de
---`SetPlayerPrimaryGang`.
function core:GetGang(source)
    local citizenId = world.online[source]
    if not citizenId then return nil end
    local best, bestGrade
    for name, grade in pairs(world.membership[citizenId] or {}) do
        if not bestGrade or grade > bestGrade then best, bestGrade = name, grade end
    end
    if not best then return { name = 'none', label = 'Sem gang', grade = 0 } end
    local info = world.gangs[best]
    return { name = best, label = info.label, grade = bestGrade,
        gradeName = info.ranks[bestGrade].label }
end

function core:GetGangInfo(name)
    local gang = world.gangs[name]
    if not gang then return nil end
    return { name = name, label = gang.label }
end

function core:GetGangList()
    local list = {}
    for name, gang in pairs(world.gangs) do list[#list + 1] = { name = name, label = gang.label } end
    return list
end

function core:RegisterGangs() return true end

function core:GetGangMembers(name)
    local members = {}
    for citizenId, gangs in pairs(world.membership) do
        if gangs[name] then members[#members + 1] = { citizenId = citizenId, grade = gangs[name] } end
    end
    table.sort(members, function(a, b) return a.citizenId < b.citizenId end)
    return members
end

function core:SetGangGrade(citizenId, gangName, grade)
    local info = world.gangs[gangName]
    if not info or not info.ranks[grade] then return false, 'invalid_grade' end
    world.membership[citizenId] = world.membership[citizenId] or {}
    world.membership[citizenId][gangName] = grade
    return true
end

function core:RemoveFromGang(citizenId, gangName)
    if not world.membership[citizenId] then return false, 'invalid_character' end
    world.membership[citizenId][gangName] = nil
    return true
end

-- NoirGangs: stub do módulo de estado. A lógica dele tem spec próprio (state_spec);
-- aqui só precisamos que ele responda cargo, permissão e topo a partir do mundo.
NoirGangs = {}

function NoirGangs.bootstrap() return true end
function NoirGangs.republishToProvider() end

---O registro é do state_spec; aqui ele é só a lista que o main lê para montar o diretório
---e o snapshot da administração.
function NoirGangs.gangList()
    local list = {}
    for name, gang in pairs(world.gangs) do
        list[#list + 1] = { name = name, label = gang.label, color = 'roxo', archetype = 'gueto' }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function NoirGangs.gangInfo(name)
    local gang = world.gangs[name]
    if not gang then return nil end
    return { name = name, label = gang.label, color = 'roxo', archetype = 'gueto' }
end

function NoirGangs.gangColor() return '#BE78FF' end

function NoirGangs.rankCount(gangName)
    local total, plain = 0, 0
    for _, rank in pairs(NoirGangs.ranksOf(gangName)) do
        total = total + 1
        if not rank.isBoss then plain = plain + 1 end
    end
    return total, plain
end

local gangWrites = {}

function NoirGangs.createGang(name, label, archetype, color)
    gangWrites[#gangWrites + 1] = { op = 'create', name = name, label = label,
        archetype = archetype, color = color }
    world.gangs[name] = { label = label, ranks = world.gangs.duo.ranks }
    return name
end

function NoirGangs.updateGang(name, data)
    if not world.gangs[name] then return false, 'gang_not_found' end
    gangWrites[#gangWrites + 1] = { op = 'update', name = name, label = data.label }
    return true
end

function NoirGangs.rank(gangName, level)
    local gang = world.gangs[gangName]
    return gang and gang.ranks[level] or nil
end

function NoirGangs.ranksOf(gangName)
    return world.gangs[gangName] and world.gangs[gangName].ranks or {}
end

function NoirGangs.topLevel(gangName)
    local top
    for level in pairs(NoirGangs.ranksOf(gangName)) do
        if not top or level > top then top = level end
    end
    return top or 0
end

function NoirGangs.levelAbove(gangName, level)
    local best
    for candidate in pairs(NoirGangs.ranksOf(gangName)) do
        if candidate > level and (not best or candidate < best) then best = candidate end
    end
    return best
end

function NoirGangs.levelBelow(gangName, level)
    local best
    for candidate in pairs(NoirGangs.ranksOf(gangName)) do
        if candidate < level and (not best or candidate > best) then best = candidate end
    end
    return best
end

function NoirGangs.can(gangName, level, permission)
    local r = NoirGangs.rank(gangName, level)
    return r ~= nil and r.permissions[permission] == true
end

function NoirGangs.reputationOf(gangName) return world.reputation[gangName] or 0 end

function NoirGangs.productsOf(gangName)
    local list = {}
    for product in pairs(world.products[gangName] or {}) do list[#list + 1] = product end
    table.sort(list)
    return list
end

function NoirGangs.hasProduct(gangName, productType)
    return (world.products[gangName] or {})[productType] == true
end

---O editor de verdade tem spec próprio (state_spec). Aqui ele é um contador de chamadas:
---o que este arquivo cobre é quem tem direito de chamar, não o que a chamada faz.
local rankCalls = {}

function NoirGangs.bottomLevel(gangName)
    local bottom
    for level in pairs(NoirGangs.ranksOf(gangName)) do
        if not bottom or level < bottom then bottom = level end
    end
    return bottom
end

function NoirGangs.createRank(gangName, label)
    rankCalls[#rankCalls + 1] = { op = 'create', gang = gangName, label = label }
    return 99
end

function NoirGangs.updateRank(gangName, level, data)
    rankCalls[#rankCalls + 1] = { op = 'update', gang = gangName, level = level, data = data }
    return true
end

function NoirGangs.deleteRank(gangName, level)
    rankCalls[#rankCalls + 1] = { op = 'delete', gang = gangName, level = level }
    return true
end

function NoirGangs.addReputation(gangName, delta)
    if world.reputation[gangName] == nil then return nil, 'gang_not_found' end
    world.reputation[gangName] = world.reputation[gangName] + delta
    return world.reputation[gangName]
end

-- Runtime stubado ---------------------------------------------------------------------------
exports = T.exports({ bgrz_core = core })

local netEvents, registerNet = T.handlers()
RegisterNetEvent = registerNet
local eventHandlers, registerEvent = T.handlers()
AddEventHandler = registerEvent
local callbacks, registerCallback = T.handlers()

lib = {
    print = { info = function() end, error = function() end },
    callback = { register = registerCallback },
}

json = { encode = function() return '{}' end, decode = function() return {} end }

-- `MySQL.insert` é chamado como função (log) e como `.await` (locations), então o stub
-- precisa ser uma tabela chamável, igual ao oxmysql.
local insert = setmetatable({ await = function() return 1 end },
    { __call = function() return 1 end })

MySQL = {
    ready = function(fn) fn() end,
    insert = insert,
    query = { await = function() return {} end },
    single = { await = function() return nil end },
    update = { await = function() return true end },
}

TriggerClientEvent = function() end
RegisterCommand = function() end
IsPlayerAceAllowed = function() return false end
GetCurrentResourceName = function() return 'noir_gangs' end
LoadResourceFile = function(_, path)
    local file = assert(io.open(path, 'r'), 'missing ' .. path)
    local content = file:read('*a')
    file:close()
    return content
end
GetPlayerPed = function(source) return source end
GetPlayerName = function(source) return 'jogador' .. tostring(source) end

-- `near` faz `#(a - b)`, então as coordenadas precisam do mesmo comportamento do vector3
-- nativo. Cada ped fica a `world.distance` do anterior no eixo X.
local vectorMeta
vectorMeta = {
    __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vectorMeta) end,
    __len = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
}
GetEntityCoords = function(ped)
    return setmetatable({ x = ped * world.distance, y = 0, z = 0 }, vectorMeta)
end

dofile('server/main.lua')

-- O schema mora no state.lua e é validado lá; aqui só garantimos que o main não
-- reintroduziu DDL.
local serverSource = io.open('server/main.lua', 'r')
local serverCode = serverSource:read('*a')
serverSource:close()
T.falsy(serverCode:upper():find('CREATE TABLE', 1, true), 'schema não pode voltar para o main')

-- Helpers ------------------------------------------------------------------------------------
local function callEvent(name, src, ...)
    source = src
    local handler = assert(eventHandlers[name], 'handler não registrado: ' .. name)
    handler(...)
end

---As acoes de gestao viraram callback: quem age recebe um codigo, e a tela traduz. O
---teste passou a ler o codigo em vez da frase, que era o que ele realmente queria saber.
local function callAction(name, src, ...)
    local handler = assert(callbacks[name], 'callback nao registrado: ' .. name)
    return handler(src, ...)
end

---Quem age le o codigo de retorno; quem sofre a acao continua recebendo notificacao,
---porque nao esta com a tela aberta. E a unica coisa que avisa essa pessoa.
local function lastNotification()
    return notifications[#notifications]
end

-- Cenário: chefe(4), braço direito(3), soldado(1) ---------------------------------------------
addCharacter('BOSS', 1, 'Ana Chefe')
addCharacter('RIGHT', 2, 'Beto Braço')
addCharacter('SOLDIER', 3, 'Caio Soldado')
addCharacter('FREE', 4, 'Dina Livre')
world.membership.BOSS.ballas = 4
world.membership.RIGHT.ballas = 3
world.membership.SOLDIER.ballas = 1

-- Permissões -----------------------------------------------------------------------------------
local state = callbacks['noir_gangs:server:getState'](1)
T.truthy(state.inGang, 'chefe está em gang')
T.equal(state.rankLabel, 'Chefe', 'o rótulo do cargo vem da nossa tabela')
T.falsy(state.permissions.transfer_leadership, 'transferir liderança não é mais permissão de jogador')

state = callbacks['noir_gangs:server:getState'](2)
T.truthy(state.permissions.promote, 'braço direito promove')
T.truthy(state.permissions.remove_member, 'e desliga')

state = callbacks['noir_gangs:server:getState'](3)
T.falsy(state.permissions.invite, 'soldado não convida')
T.truthy(state.permissions.view_members, 'todo membro vê a lista')
T.equal(state.rankLabel, 'Soldado', 'o rótulo do cargo vem da nossa tabela')

-- Reputação e produto só viajam para quem tem a permissão.
T.falsy(state.reputation, 'soldado não vê reputação')
T.falsy(state.products, 'soldado não vê os produtos')

state = callbacks['noir_gangs:server:getState'](1)
T.equal(state.reputation, 0, 'o chefe vê a reputação')
T.equal(#state.products, 1, 'e vê o produto que a gang opera')
T.equal(state.products[1].id, 'drugs', 'com o id do produto')

-- Regras de cargo -------------------------------------------------------------------------
-- Não há comparação entre o cargo de quem age e o de quem recebe: quem tem a permissão,
-- usa. A única barreira estrutural é o chefe.
local ok, code = callAction('noir_gangs:server:memberAction', 2, 'BOSS', 'demote')
T.equal(world.membership.BOSS.ballas, 4, 'o chefe não muda de cargo')
T.falsy(ok, 'e a tentativa é recusada')
T.equal(code, 'boss_protected', 'com o motivo, para a tela dizer qual foi')

callAction('noir_gangs:server:memberAction', 2, 'BOSS', 'remove')
T.equal(world.membership.BOSS.ballas, 4, 'o chefe não é desligado')

ok, code = callAction('noir_gangs:server:memberAction', 2, 'RIGHT', 'promote')
T.equal(world.membership.RIGHT.ballas, 3, 'ninguém age sobre si mesmo')
T.equal(code, 'self_action', 'e o motivo é esse')

notifications = {}
local _, _, newRank = callAction('noir_gangs:server:memberAction', 2, 'SOLDIER', 'promote')
T.equal(world.membership.SOLDIER.ballas, 2, 'promoção normal sobe um cargo')
T.equal(newRank, 'Tenente', 'o novo cargo volta junto, para a tela dizer qual é')
T.equal(lastNotification().source, 3, 'quem mudou de cargo é avisado')
T.truthy(lastNotification().text:find('Tenente', 1, true), 'e a mensagem diz qual cargo')

-- Promover PARA chefe não existe: seria passar liderança por mecanismo de jogador.
world.membership.SOLDIER.ballas = 3
ok, code = callAction('noir_gangs:server:memberAction', 2, 'SOLDIER', 'promote')
T.equal(world.membership.SOLDIER.ballas, 3, 'ninguém é promovido a chefe pelo menu')
T.falsy(ok, 'e a recusa é explícita')
T.equal(code, 'boss_not_promotable', 'com o motivo certo')

-- Rebaixar continua andando para baixo normalmente.
callAction('noir_gangs:server:memberAction', 2, 'SOLDIER', 'demote')
T.equal(world.membership.SOLDIER.ballas, 2, 'rebaixamento desce um cargo')
world.membership.SOLDIER.ballas = 1

-- Sem a permissão, nada acontece: é o arquétipo que controla quem pode, não a hierarquia.
ok, code = callAction('noir_gangs:server:memberAction', 3, 'FREE', 'promote')
T.falsy(ok, 'soldado sem a permissão não promove')
T.equal(code, 'no_permission', 'e o motivo é a permissão, não a hierarquia')

-- Com a permissão, o cargo baixo age sobre alguém acima dele: é o desenho pedido.
world.gangs.ballas.ranks[1].permissions.promote = true
world.membership.FREE.ballas = 1
callAction('noir_gangs:server:memberAction', 3, 'RIGHT', 'demote')
world.gangs.ballas.ranks[1].permissions.demote = true
callAction('noir_gangs:server:memberAction', 3, 'RIGHT', 'demote')
T.equal(world.membership.RIGHT.ballas, 2, 'quem tem a permissão age sobre cargo mais alto')
world.gangs.ballas.ranks[1].permissions.promote = nil
world.gangs.ballas.ranks[1].permissions.demote = nil
world.membership.RIGHT.ballas = 3
world.membership.FREE.ballas = nil

-- Saída -------------------------------------------------------------------------------------
-- Sem transferência de liderança, o chefe não pode ficar preso: exigir que ele passasse o
-- cargo antes não deixaria caminho nenhum para sair.
T.truthy(callAction('noir_gangs:server:leaveGang', 3), 'membro comum sai quando quer')
T.falsy(world.membership.SOLDIER.ballas, 'e some da gang')

T.truthy(callAction('noir_gangs:server:leaveGang', 1), 'o chefe também sai')
T.falsy(world.membership.BOSS.ballas, 'recompor a gang é com a administração')
world.membership.BOSS.ballas = 4

-- Convite ---------------------------------------------------------------------------------------
-- Uma gang por personagem é a regra do servidor. O convite recusa quem já consta em
-- `gangs` mesmo que a primária esteja vazia: aceitar levaria a uma entrada que o
-- `AddPlayerToGang` recusaria de qualquer forma, só que com a mensagem errada.
world.membership.BOSS.ballas = 4
world.membership.FREE.duo = 0

ok, code = callAction('noir_gangs:server:invite', 1, 4)
T.falsy(ok, 'quem já consta em uma gang não recebe convite')
T.equal(code, 'already_in_gang', 'e o motivo diz qual é o impedimento')

-- Sem gang nenhuma, o convite passa e o cooldown fecha o segundo envio.
world.membership.FREE.duo = nil
local sent, _, invitedName = callAction('noir_gangs:server:invite', 1, 4)
T.truthy(sent, 'convite válido é enviado')
T.equal(invitedName, 'Dina Livre', 'com o nome de quem recebeu, para a tela confirmar')

addCharacter('OTHER', 5, 'Elo Outro')
ok, code = callAction('noir_gangs:server:invite', 1, 5)
T.falsy(ok, 'cooldown bloqueia o convite seguinte')
T.equal(code, 'cooldown', 'e diz que é espera, não impedimento')

-- `playerDropped` limpa o cooldown: o FiveM reaproveita ids de source, e sem isso o
-- próximo jogador a entrar nesse id herdava a espera de quem saiu.
callEvent('playerDropped', 1)
world.online[1] = nil
addCharacter('NEWCOMER', 1, 'Fábio Novato')
world.membership.NEWCOMER.ballas = 4
T.truthy(callAction('noir_gangs:server:invite', 1, 5), 'source reaproveitado começa sem cooldown')

-- Lista de membros ------------------------------------------------------------------------------------
world.membership.SOLDIER.ballas = 1
world.characters.SOLDIER.source = nil
world.online[3] = nil

-- A tela desenha a partir de um snapshot só, então ele precisa trazer tudo: quem é a
-- gang, quem está nela, os cargos e o histórico. Faltar um campo aqui é uma região da
-- tela que nasce vazia sem erro nenhum.
local snapshot = callbacks['noir_gangs:server:getSnapshot'](1)
local members = { members = snapshot.members }
T.truthy(snapshot.inGang, 'o chefe enxerga a gestão')
T.truthy(snapshot.members, 'o snapshot traz os membros')
T.truthy(snapshot.ranks, 'e os cargos')
T.truthy(snapshot.activity, 'e o histórico')
T.equal(snapshot.actorCitizenId, 'NEWCOMER', 'e quem está olhando, para a tela não oferecer ação sobre si mesmo')

-- `memberCount` é o tamanho da gang; `members` é o que esta pessoa pode ver. Os dois
-- coincidem para quem vê offline, e é justamente por isso que são campos separados.
T.equal(snapshot.memberCount, #core:GetGangMembers('ballas'), 'o total conta a gang inteira')
T.truthy(snapshot.onlineCount <= snapshot.memberCount, 'e quem está online é um subconjunto dela')

local topRank = snapshot.ranks[1]
T.truthy(topRank.isBoss, 'os cargos vêm do topo para a base')
T.truthy(topRank.count >= 1, 'com quanta gente visível ocupa cada um')
local sawOffline = false
for i = 1, #members.members do
    if members.members[i].citizenid == 'SOLDIER' then
        sawOffline = true
        T.falsy(members.members[i].online, 'o membro offline aparece marcado como offline')
    end
end
T.truthy(sawOffline, 'cargo alto vê membros offline')
local bossEntry
for i = 1, #members.members do
    if members.members[i].citizenid == 'BOSS' then bossEntry = members.members[i] end
end
T.truthy(bossEntry.isBoss, 'a lista marca o chefe para a UI esconder as ações')
T.falsy(bossEntry.canPromote, 'e não oferece promoção a partir do chefe')

-- Cargos não contíguos ----------------------------------------------------------------------
-- Uma gang com grades 0, 2 e 5 é válida no Qbox. Somar ou subtrair 1 cairia num cargo que
-- não existe, e na transferência `topGrade - 1` deixaria duas pessoas no topo.
addCharacter('T_TOP', 10, 'Gil Topo')
addCharacter('T_MID', 11, 'Hugo Meio')
addCharacter('T_LOW', 12, 'Ivo Base')
world.membership.T_TOP.trio = 5
world.membership.T_MID.trio = 2
world.membership.T_LOW.trio = 0

callAction('noir_gangs:server:memberAction', 10, 'T_LOW', 'promote')
T.equal(world.membership.T_LOW.trio, 2, 'promoção pula para o próximo cargo que existe')

callAction('noir_gangs:server:memberAction', 10, 'T_LOW', 'demote')
T.equal(world.membership.T_LOW.trio, 0, 'rebaixamento volta para o cargo anterior que existe')

-- Promover no trio pula de 0 para 2, e para antes do topo, que é chefe.
world.membership.T_LOW.trio = 2
callAction('noir_gangs:server:memberAction', 10, 'T_LOW', 'promote')
T.equal(world.membership.T_LOW.trio, 2, 'o cargo acima do meio é o chefe, então a promoção para')
world.membership.T_LOW.trio = 0

-- Lista de pontos -------------------------------------------------------------------------------
-- Quem pede é o client, então o pedido tem teto. Sair do servidor zera o teto junto com o
-- cooldown de convite, senão o próximo dono do source já nasceria travado.
T.truthy(callbacks['noir_gangs:server:getLocations'](10), 'o primeiro pedido responde')
T.falsy(callbacks['noir_gangs:server:getLocations'](10), 'o pedido seguinte cai no cooldown')
callEvent('playerDropped', 10)
T.truthy(callbacks['noir_gangs:server:getLocations'](10), 'source reaproveitado pede de novo')

-- Editor de cargos ------------------------------------------------------------------------
-- O que muda o que os outros podem fazer precisa do mesmo cuidado que a ação sobre membro:
-- permissão primeiro, e ninguém mexe no próprio cargo.

local function callRank(name, src, ...)
    local handler = assert(callbacks['noir_gangs:server:' .. name], 'callback não registrado: ' .. name)
    return handler(src, ...)
end

-- Cenário: NEWCOMER é o chefe de ballas (cargo 4), RIGHT é braço direito (3).
world.gangs.ballas.ranks[4].permissions.manage_ranks = true

rankCalls = {}
local rankOk, rankCode = callRank('createRank', 2, 'Tenente')
T.falsy(rankOk, 'braço direito não gere cargos sem a permissão')
T.equal(rankCode, 'no_permission', 'e o motivo é a permissão')
T.equal(#rankCalls, 0, 'a recusa acontece antes de tocar no estado')

local created, _, newLevel = callRank('createRank', 1, 'Tenente')
T.truthy(created, 'o chefe gere os cargos')
T.equal(newLevel, 99, 'e o nível do cargo novo volta para a tela abrir nele')
T.equal(rankCalls[1].label, 'Tenente', 'o rótulo chega inteiro no estado')

-- Ninguém edita o próprio cargo: seria marcar todas as permissões para si mesmo.
rankCalls = {}
rankOk, rankCode = callRank('updateRank', 1, 4, { label = 'Chefão', permissions = {} })
T.falsy(rankOk, 'nem o chefe edita o cargo em que ele está')
T.equal(rankCode, 'own_rank', 'com o motivo explícito')
T.equal(#rankCalls, 0, 'e nada foi gravado')

rankOk, rankCode = callRank('deleteRank', 1, 4)
T.falsy(rankOk, 'nem exclui o próprio cargo')
T.equal(rankCode, 'own_rank', 'pelo mesmo motivo')

-- Outro cargo, com a permissão, passa.
T.truthy(callRank('updateRank', 1, 1, { label = 'Soldado', permissions = { 'view_members' } }),
    'editar outro cargo funciona')
T.equal(rankCalls[1].level, 1, 'no cargo pedido')
T.truthy(callRank('deleteRank', 1, 1), 'excluir outro cargo também')

world.gangs.ballas.ranks[4].permissions.manage_ranks = nil

-- Administração ------------------------------------------------------------------------------
-- O `/gangsetup` é de admin, e a tela não é prova de nada: cada callback atravessa o portão
-- de ace de novo. Sem isso, bastaria um evento forjado para criar gang.
T.falsy(callbacks['noir_gangs:server:getSetup'](1), 'sem ace, o snapshot da administração não sai')

local setupOk, setupCode = callbacks['noir_gangs:server:createGang'](1,
    { name = 'nova', label = 'Nova', archetype = 'gueto', color = 'roxo' })
T.falsy(setupOk, 'e criar gang é recusado')
T.equal(setupCode, 'no_permission', 'com o motivo certo')

setupOk, setupCode = callbacks['noir_gangs:server:updateGang'](1, { name = 'ballas', label = 'X' })
T.falsy(setupOk, 'editar gang também')
T.equal(setupCode, 'no_permission', 'pelo mesmo motivo')
T.equal(#gangWrites, 0, 'nada chegou ao registro')

-- Com o ace, passa.
IsPlayerAceAllowed = function() return true end

local snapshotAdmin = callbacks['noir_gangs:server:getSetup'](1)
T.truthy(snapshotAdmin, 'com ace, o snapshot sai')
T.truthy(#snapshotAdmin.gangs > 0, 'com as gangs registradas')
T.truthy(#snapshotAdmin.archetypes > 0, 'os arquétipos para escolher')
T.truthy(#snapshotAdmin.colors > 0, 'e a paleta de cores')
T.truthy(snapshotAdmin.colors[1].hex:match('^#%x%x%x%x%x%x$'), 'a cor chega em hexadecimal, pronta para a tela')

local ok3, _, newName = callbacks['noir_gangs:server:createGang'](1,
    { name = 'nova', label = 'Nova', archetype = 'gueto', color = 'roxo' })
T.truthy(ok3, 'criar gang funciona com ace')
T.equal(newName, 'nova', 'e o identificador volta para a tela abrir nela')
T.equal(gangWrites[#gangWrites].op, 'create', 'o registro recebeu a criação')

IsPlayerAceAllowed = function() return false end

print('server_spec: ok')
