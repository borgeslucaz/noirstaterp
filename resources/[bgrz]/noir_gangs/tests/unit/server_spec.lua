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

json = { encode = function() return '{}' end }

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
local function callNet(name, src, ...)
    source = src
    local handler = assert(netEvents[name], 'evento não registrado: ' .. name)
    handler(...)
end

local function callEvent(name, src, ...)
    source = src
    local handler = assert(eventHandlers[name], 'handler não registrado: ' .. name)
    handler(...)
end

local function lastNotification()
    return notifications[#notifications]
end

local function resetNotifications() notifications = {} end

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
resetNotifications()
callNet('noir_gangs:server:memberAction', 2, 'BOSS', 'demote')
T.equal(world.membership.BOSS.ballas, 4, 'o chefe não muda de cargo')
T.equal(lastNotification().kind, 'error', 'e a tentativa avisa erro')

resetNotifications()
callNet('noir_gangs:server:memberAction', 2, 'BOSS', 'remove')
T.equal(world.membership.BOSS.ballas, 4, 'o chefe não é desligado')

resetNotifications()
callNet('noir_gangs:server:memberAction', 2, 'RIGHT', 'promote')
T.equal(world.membership.RIGHT.ballas, 3, 'ninguém age sobre si mesmo')

resetNotifications()
callNet('noir_gangs:server:memberAction', 2, 'SOLDIER', 'promote')
T.equal(world.membership.SOLDIER.ballas, 2, 'promoção normal sobe um cargo')

-- Promover PARA chefe não existe: seria passar liderança por mecanismo de jogador.
world.membership.SOLDIER.ballas = 3
resetNotifications()
callNet('noir_gangs:server:memberAction', 2, 'SOLDIER', 'promote')
T.equal(world.membership.SOLDIER.ballas, 3, 'ninguém é promovido a chefe pelo menu')
T.equal(lastNotification().kind, 'error', 'e a recusa é explícita')

-- Rebaixar continua andando para baixo normalmente.
resetNotifications()
callNet('noir_gangs:server:memberAction', 2, 'SOLDIER', 'demote')
T.equal(world.membership.SOLDIER.ballas, 2, 'rebaixamento desce um cargo')
world.membership.SOLDIER.ballas = 1

-- Sem a permissão, nada acontece: é o arquétipo que controla quem pode, não a hierarquia.
resetNotifications()
callNet('noir_gangs:server:memberAction', 3, 'FREE', 'promote')
T.equal(lastNotification().kind, 'error', 'soldado sem a permissão não promove')

-- Com a permissão, o cargo baixo age sobre alguém acima dele: é o desenho pedido.
world.gangs.ballas.ranks[1].permissions.promote = true
world.membership.FREE.ballas = 1
resetNotifications()
callNet('noir_gangs:server:memberAction', 3, 'RIGHT', 'demote')
world.gangs.ballas.ranks[1].permissions.demote = true
resetNotifications()
callNet('noir_gangs:server:memberAction', 3, 'RIGHT', 'demote')
T.equal(world.membership.RIGHT.ballas, 2, 'quem tem a permissão age sobre cargo mais alto')
world.gangs.ballas.ranks[1].permissions.promote = nil
world.gangs.ballas.ranks[1].permissions.demote = nil
world.membership.RIGHT.ballas = 3
world.membership.FREE.ballas = nil

-- Saída -------------------------------------------------------------------------------------
-- Sem transferência de liderança, o chefe não pode ficar preso: exigir que ele passasse o
-- cargo antes não deixaria caminho nenhum para sair.
resetNotifications()
callNet('noir_gangs:server:leaveGang', 3)
T.falsy(world.membership.SOLDIER.ballas, 'membro comum sai quando quer')

resetNotifications()
callNet('noir_gangs:server:leaveGang', 1)
T.falsy(world.membership.BOSS.ballas, 'o chefe também sai; recompor a gang é com a administração')
world.membership.BOSS.ballas = 4

-- Convite ---------------------------------------------------------------------------------------
-- Uma gang por personagem é a regra do servidor. O convite recusa quem já consta em
-- `gangs` mesmo que a primária esteja vazia: aceitar levaria a uma entrada que o
-- `AddPlayerToGang` recusaria de qualquer forma, só que com a mensagem errada.
world.membership.BOSS.ballas = 4
world.membership.FREE.duo = 0

resetNotifications()
callNet('noir_gangs:server:invite', 1, 4)
T.equal(lastNotification().kind, 'error', 'quem já consta em uma gang não recebe convite')

-- Sem gang nenhuma, o convite passa e o cooldown fecha o segundo envio.
world.membership.FREE.duo = nil
resetNotifications()
callNet('noir_gangs:server:invite', 1, 4)
T.equal(lastNotification().kind, 'success', 'convite válido é enviado')

addCharacter('OTHER', 5, 'Elo Outro')
resetNotifications()
callNet('noir_gangs:server:invite', 1, 5)
T.equal(lastNotification().kind, 'error', 'cooldown bloqueia o convite seguinte')

-- `playerDropped` limpa o cooldown: o FiveM reaproveita ids de source, e sem isso o
-- próximo jogador a entrar nesse id herdava a espera de quem saiu.
callEvent('playerDropped', 1)
world.online[1] = nil
addCharacter('NEWCOMER', 1, 'Fábio Novato')
world.membership.NEWCOMER.ballas = 4
resetNotifications()
callNet('noir_gangs:server:invite', 1, 5)
T.equal(lastNotification().kind, 'success', 'source reaproveitado começa sem cooldown')

-- Lista de membros ------------------------------------------------------------------------------------
world.membership.SOLDIER.ballas = 1
world.characters.SOLDIER.source = nil
world.online[3] = nil

local members = callbacks['noir_gangs:server:getMembers'](1)
T.truthy(members, 'o chefe enxerga a lista')
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

resetNotifications()
callNet('noir_gangs:server:memberAction', 10, 'T_LOW', 'promote')
T.equal(world.membership.T_LOW.trio, 2, 'promoção pula para o próximo cargo que existe')

resetNotifications()
callNet('noir_gangs:server:memberAction', 10, 'T_LOW', 'demote')
T.equal(world.membership.T_LOW.trio, 0, 'rebaixamento volta para o cargo anterior que existe')

-- Promover no trio pula de 0 para 2, e para antes do topo, que é chefe.
world.membership.T_LOW.trio = 2
resetNotifications()
callNet('noir_gangs:server:memberAction', 10, 'T_LOW', 'promote')
T.equal(world.membership.T_LOW.trio, 2, 'o cargo acima do meio é o chefe, então a promoção para')
world.membership.T_LOW.trio = 0

-- Lista de pontos -------------------------------------------------------------------------------
-- Quem pede é o client, então o pedido tem teto. Sair do servidor zera o teto junto com o
-- cooldown de convite, senão o próximo dono do source já nasceria travado.
T.truthy(callbacks['noir_gangs:server:getLocations'](10), 'o primeiro pedido responde')
T.falsy(callbacks['noir_gangs:server:getLocations'](10), 'o pedido seguinte cai no cooldown')
callEvent('playerDropped', 10)
T.truthy(callbacks['noir_gangs:server:getLocations'](10), 'source reaproveitado pede de novo')

print('server_spec: ok')
