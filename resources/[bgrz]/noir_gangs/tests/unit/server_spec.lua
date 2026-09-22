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

-- Membresia: agora é do NoirGangs, não do bridge. O stub opera sobre o mesmo
-- `world.membership` que os `core:` acima, para as fixtures do spec continuarem valendo.
local function gangOf(citizenId)
    for name, grade in pairs(world.membership[citizenId] or {}) do return name, grade end
end

function NoirGangs.gangOfCitizen(citizenId)
    local name, grade = gangOf(citizenId)
    if not name then return nil end
    local info = world.gangs[name]
    if not info then return nil end
    local rank = info.ranks[grade]
    return { name = name, label = info.label, grade = grade,
        gradeName = rank and rank.label, isBoss = rank ~= nil and rank.isBoss == true,
        bankAuth = rank ~= nil and rank.bankAuth == true }
end

function NoirGangs.gangOfSource(source)
    local citizenId = world.online[source]
    return citizenId and NoirGangs.gangOfCitizen(citizenId) or nil
end

function NoirGangs.hasAnyGang(citizenId)
    return gangOf(citizenId) ~= nil
end

function NoirGangs.membersOf(gangName)
    local members = {}
    for citizenId, gangs in pairs(world.membership) do
        if gangs[gangName] then members[#members + 1] = { citizenId = citizenId, grade = gangs[gangName] } end
    end
    table.sort(members, function(a, b) return a.citizenId < b.citizenId end)
    return members
end

function NoirGangs.countAtLevel(gangName, level)
    local total = 0
    for _, entry in ipairs(NoirGangs.membersOf(gangName)) do
        if entry.grade == level then total = total + 1 end
    end
    return total
end

function NoirGangs.setMember(citizenId, gangName, level)
    local info = world.gangs[gangName]
    if not info or not info.ranks[level] then return false, 'invalid_grade' end
    world.membership[citizenId] = { [gangName] = level }
    return true
end

function NoirGangs.removeMember(citizenId)
    -- Tabela vazia em vez de nil: no banco a linha some, mas o spec indexa
    -- `world.membership.X.gang` para conferir ausência, e nil quebraria a leitura.
    world.membership[citizenId] = {}
    return true
end

function NoirGangs.publishFor() end
function NoirGangs.publishSource() end
function NoirGangs.loadMembers() end


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

-- `level` é identidade e a escada é `sortOrder`. O stub reproduz isso: sem `sortOrder`
-- gravado, a posição é o próprio nível -- que é exatamente o que o carregador real faz
-- com linha antiga.
--
-- As três funções abaixo derivam da escada, como as de verdade. Um stub com algoritmo
-- próprio testaria um comportamento que produção não tem.
function NoirGangs.ladder(gangName)
    local ordered = {}
    for level, rank in pairs(NoirGangs.ranksOf(gangName)) do
        rank.level = rank.level or level
        ordered[#ordered + 1] = rank
    end
    table.sort(ordered, function(a, b)
        local sa, sb = a.sortOrder or a.level, b.sortOrder or b.level
        if sa == sb then return a.level < b.level end
        return sa < sb
    end)
    return ordered
end

function NoirGangs.topLevel(gangName)
    local ordered = NoirGangs.ladder(gangName)
    local top = ordered[#ordered]
    return top and top.level or 0
end

function NoirGangs.levelAbove(gangName, level)
    local ordered = NoirGangs.ladder(gangName)
    for i = 1, #ordered do
        if ordered[i].level == level then return ordered[i + 1] and ordered[i + 1].level end
    end
end

function NoirGangs.levelBelow(gangName, level)
    local ordered = NoirGangs.ladder(gangName)
    for i = 1, #ordered do
        if ordered[i].level == level then return ordered[i - 1] and ordered[i - 1].level end
    end
end

function NoirGangs.can(gangName, level, permission)
    local r = NoirGangs.rank(gangName, level)
    return r ~= nil and r.permissions[permission] == true
end

function NoirGangs.bossRank(gangName)
    for level, rank in pairs(NoirGangs.ranksOf(gangName)) do
        if rank.isBoss then return { level = level, label = rank.label, isBoss = true } end
    end
    return nil
end

local productWrites = {}

function NoirGangs.setProducts(gangName, list)
    if not world.gangs[gangName] then return false, 'gang_not_found' end
    local set = {}
    for i = 1, #list do
        if not Config.ProductTypes[list[i]] then return false, 'invalid_product' end
        set[list[i]] = true
    end
    world.products[gangName] = set
    productWrites[#productWrites + 1] = { gang = gangName, list = list }
    return true
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
    print = { info = function() end, error = function() end, warn = function() end },
    callback = { register = registerCallback },
}

json = { encode = function() return '{}' end, decode = function() return {} end }

-- `MySQL.insert` é chamado como função (log) e como `.await` (locations), então o stub
-- precisa ser uma tabela chamável, igual ao oxmysql.
local locationWrites = {}
local insert = setmetatable({ await = function(query, values)
    if query:find('noir_gang_locations', 1, true) then
        locationWrites[#locationWrites + 1] = { query = query, values = values }
    end
    return 1
end }, { __call = function() return 1 end })

-- A poda do histórico roda no start e volta de tempos em tempos. O stub registra o que
-- ela pediu, para o teste conferir o corte em vez de só deixar o código passar.
local activityPrunes, activityDeletes = {}, {}

MySQL = {
    ready = function(fn) fn() end,
    insert = insert,
    query = { await = function() return {} end },
    single = { await = function(query)
        if query:find('noir_gang_locations', 1, true) then return { gang_name = 'ballas' } end
        return nil
    end },
    scalar = { await = function(query, params)
        if not query:find('noir_gang_activity', 1, true) then return nil end
        activityPrunes[#activityPrunes + 1] = { query = query, gang = params[1] }
        return 1000
    end },
    update = { await = function(query, params)
        if query:find('noir_gang_locations', 1, true) then
            locationWrites[#locationWrites + 1] = { query = query, values = params }
            return 1
        end
        if not query:find('DELETE FROM noir_gang_activity', 1, true) then return true end
        activityDeletes[#activityDeletes + 1] = { gang = params[1], cutoff = params[2] }
        return 7
    end },
}

-- A poda periódica vive numa thread; aqui ela não roda, e o que o teste cobre é a do start.
CreateThread = function() end
Wait = function() end

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
---A tela de setup pergunta quem está online para oferecer o primeiro chefe.
GetPlayers = function()
    local list = {}
    for src in pairs(world.online) do list[#list + 1] = tostring(src) end
    table.sort(list)
    return list
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

-- Retenção do histórico ---------------------------------------------------------------------
-- A tabela só cresce, e a leitura fica cara junto. A poda entra no start, por gang, e corta
-- pelo `id` — o mesmo caminho que o índice da leitura serve.
local gangCount = #NoirGangs.gangList()
if Config.ActivityRetention > 0 then
    T.equal(#activityPrunes, gangCount, 'a poda roda no start, uma vez por gang')
    T.truthy(activityPrunes[1].query:find('OFFSET ' .. math.floor(Config.ActivityRetention), 1, true),
        'o corte é a linha que passa do teto de retenção')
    T.truthy(activityPrunes[1].query:find('ORDER BY id DESC', 1, true),
        'e é achado pelo id, para usar o índice da leitura')
    T.equal(#activityDeletes, gangCount, 'cada gang com excedente perde o que passou do teto')
    T.equal(activityDeletes[1].cutoff, 1000, 'apagando da linha de corte para trás')
else
    T.equal(#activityPrunes, 0, 'retenção zero guarda tudo: a poda não chega a consultar')
end

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

---A tela manda o CARGO escolhido, não uma direção -- `setGrade` com o nível.
---
---Os cenários abaixo continuam escritos em "promover/rebaixar" porque é isso que eles
---testam: quem pode mover quem. O helper traduz a intenção para o nível concreto, um
---degrau acima ou abaixo na escada da gang de quem recebe.
local function memberAction(source, citizenId, direction)
    if direction == 'remove' then
        return callAction('noir_gangs:server:memberAction', source, citizenId, 'remove')
    end

    local gangName, grade
    for name, level in pairs(world.membership[citizenId] or {}) do gangName, grade = name, level end

    local target
    if gangName and world.gangs[gangName] then
        local ladder = {}
        for level in pairs(world.gangs[gangName].ranks) do ladder[#ladder + 1] = level end
        table.sort(ladder)
        for i = 1, #ladder do
            if ladder[i] == grade then
                target = direction == 'promote' and ladder[i + 1] or ladder[i - 1]
                break
            end
        end
    end

    -- Sem degrau calculável (alvo sem gang, por exemplo) manda 0 mesmo: o cenário quer
    -- chegar às checagens de permissão e de membresia, não parar na validação do payload.
    return callAction('noir_gangs:server:memberAction', source, citizenId, 'setGrade', target or 0)
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
-- A tela veste o rail com a cor da gang; sem ela no estado, todas ficam vermelhas.
T.equal(state.gangColor, '#BE78FF', 'a cor da gang viaja com o estado, em hexadecimal')
T.falsy(state.permissions.transfer_leadership, 'transferir liderança não é mais permissão de jogador')

state = callbacks['noir_gangs:server:getState'](2)
T.truthy(state.permissions.promote, 'braço direito promove')
T.truthy(state.permissions.remove_member, 'e desliga')
-- É por esta chave derivada que a tela decide mostrar o botão de alterar cargo. Ela não
-- está em `Config.Permissions`, então já ficou de fora do estado uma vez -- e o botão
-- sumiu para todo mundo, mesmo com `promote` no cargo.
T.truthy(state.permissions.changeGrade, 'e, promovendo, enxerga o botão de alterar cargo')

state = callbacks['noir_gangs:server:getState'](3)
T.falsy(state.permissions.invite, 'soldado não convida')
T.falsy(state.permissions.changeGrade, 'nem promove ou rebaixa, então não vê o botão')
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
local ok, code = memberAction(2, 'BOSS', 'demote')
T.equal(world.membership.BOSS.ballas, 4, 'o chefe não muda de cargo')
T.falsy(ok, 'e a tentativa é recusada')
T.equal(code, 'boss_protected', 'com o motivo, para a tela dizer qual foi')

memberAction(2, 'BOSS', 'remove')
T.equal(world.membership.BOSS.ballas, 4, 'o chefe não é desligado')

ok, code = memberAction(2, 'RIGHT', 'promote')
T.equal(world.membership.RIGHT.ballas, 3, 'ninguém age sobre si mesmo')
T.equal(code, 'self_action', 'e o motivo é esse')

notifications = {}
local _, _, newRank = memberAction(2, 'SOLDIER', 'promote')
T.equal(world.membership.SOLDIER.ballas, 2, 'promoção normal sobe um cargo')
T.equal(newRank, 'Tenente', 'o novo cargo volta junto, para a tela dizer qual é')
T.equal(lastNotification().source, 3, 'quem mudou de cargo é avisado')
T.truthy(lastNotification().text:find('Tenente', 1, true), 'e a mensagem diz qual cargo')

-- Promover PARA chefe não existe: seria passar liderança por mecanismo de jogador.
world.membership.SOLDIER.ballas = 3
ok, code = memberAction(2, 'SOLDIER', 'promote')
T.equal(world.membership.SOLDIER.ballas, 3, 'ninguém é promovido a chefe pelo menu')
T.falsy(ok, 'e a recusa é explícita')
T.equal(code, 'boss_not_promotable', 'com o motivo certo')

-- Rebaixar continua andando para baixo normalmente.
memberAction(2, 'SOLDIER', 'demote')
T.equal(world.membership.SOLDIER.ballas, 2, 'rebaixamento desce um cargo')
world.membership.SOLDIER.ballas = 1

-- Escolher o cargo, e não um degrau ---------------------------------------------------------
-- A tela manda `setGrade` com o nível. Pular degraus é o caso normal: com um cargo no meio
-- da escada, "o próximo" podia ser exatamente o que ninguém queria.
local function setGrade(source, citizenId, level)
    return callAction('noir_gangs:server:memberAction', source, citizenId, 'setGrade', level)
end

world.membership.SOLDIER.ballas = 1
ok = setGrade(2, 'SOLDIER', 3)
T.truthy(ok, 'dá para mover direto para um cargo distante')
T.equal(world.membership.SOLDIER.ballas, 3, 'e a pessoa vai para o cargo escolhido, não um acima')

ok, code = setGrade(2, 'SOLDIER', 3)
T.falsy(ok, 'mover para o cargo em que a pessoa já está é recusado')
T.equal(code, 'same_rank', 'com o motivo certo, em vez de uma escrita à toa')

ok, code = setGrade(2, 'SOLDIER', 99)
T.falsy(ok, 'nível que não existe é recusado')
T.equal(code, 'no_rank_available', 'e não vira cargo fantasma')

local bossLevel = NoirGangs.topLevel('ballas')
ok, code = setGrade(2, 'SOLDIER', bossLevel)
T.falsy(ok, 'ninguém é movido PARA o cargo de chefe')
T.equal(code, 'boss_not_promotable', 'a liderança continua sendo operação de fora')

-- A direção decide qual permissão é exigida: quem só rebaixa não promove pelo mesmo botão.
world.membership.SOLDIER.ballas = 2
world.gangs.ballas.ranks[world.membership.RIGHT.ballas].permissions.promote = nil
ok, code = setGrade(2, 'SOLDIER', 3)
T.falsy(ok, 'sem `promote`, subir é recusado')
T.equal(code, 'no_permission', 'mesmo com o botão aberto pela outra permissão')
T.truthy(setGrade(2, 'SOLDIER', 1), 'e descer continua valendo, porque `demote` está lá')
world.gangs.ballas.ranks[world.membership.RIGHT.ballas].permissions.promote = true
world.membership.SOLDIER.ballas = 1

-- Sem a permissão, nada acontece: é o arquétipo que controla quem pode, não a hierarquia.
ok, code = memberAction(3, 'FREE', 'promote')
T.falsy(ok, 'soldado sem a permissão não promove')
T.equal(code, 'no_permission', 'e o motivo é a permissão, não a hierarquia')

-- Com a permissão, o cargo baixo age sobre alguém acima dele: é o desenho pedido.
world.gangs.ballas.ranks[1].permissions.promote = true
world.membership.FREE.ballas = 1
memberAction(3, 'RIGHT', 'demote')
world.gangs.ballas.ranks[1].permissions.demote = true
memberAction(3, 'RIGHT', 'demote')
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

memberAction(10, 'T_LOW', 'promote')
T.equal(world.membership.T_LOW.trio, 2, 'promoção pula para o próximo cargo que existe')

memberAction(10, 'T_LOW', 'demote')
T.equal(world.membership.T_LOW.trio, 0, 'rebaixamento volta para o cargo anterior que existe')

-- Promover no trio pula de 0 para 2, e para antes do topo, que é chefe.
world.membership.T_LOW.trio = 2
memberAction(10, 'T_LOW', 'promote')
T.equal(world.membership.T_LOW.trio, 2, 'o cargo acima do meio é o chefe, então a promoção para')
world.membership.T_LOW.trio = 0

-- Lista de pontos -------------------------------------------------------------------------------
-- Quem pede é o client, então o pedido tem teto. Sair do servidor zera o teto junto com o
-- cooldown de convite, senão o próximo dono do source já nasceria travado.
T.truthy(callbacks['noir_gangs:server:getLocations'](10), 'o primeiro pedido responde')
T.falsy(callbacks['noir_gangs:server:getLocations'](10), 'o pedido seguinte cai no cooldown')
callEvent('playerDropped', 10)
T.truthy(callbacks['noir_gangs:server:getLocations'](10), 'source reaproveitado pede de novo')

-- Amplificação de consulta ----------------------------------------------------------------
-- O snapshot é a leitura mais cara daqui: roster, nomes e histórico. A tela tranca o clique
-- repetido em `BUSY`, mas essa tranca é do cliente — quem segura o pedido repetido tem de
-- ser o servidor. Cenário: NEWCOMER (source 1) é chefe de ballas e SOLDIER está offline.
local dbTouches = 0
-- O snapshot lê a membresia do NoirGangs, não mais do bridge -- o gancho segue o dado.
local realGangMembers, realNames, realQuery = NoirGangs.membersOf, core.GetCharacterNames, MySQL.query.await

NoirGangs.membersOf = function(name)
    dbTouches = dbTouches + 1
    return realGangMembers(name)
end
core.GetCharacterNames = function(self, ids)
    dbTouches = dbTouches + 1
    return realNames(self, ids)
end
MySQL.query.await = function(...)
    dbTouches = dbTouches + 1
    return realQuery(...)
end

-- A ação derruba o cache por dentro, no `log()`: é assim que o snapshot seguinte sai novo.
memberAction(1, 'SOLDIER', 'promote')

dbTouches = 0
callbacks['noir_gangs:server:getSnapshot'](1)
T.truthy(dbTouches > 0, 'o snapshot depois de uma mudança lê o banco')

dbTouches = 0
T.truthy(callbacks['noir_gangs:server:getSnapshot'](1), 'o pedido repetido continua respondendo')
T.equal(dbTouches, 0, 'e sai do cache sem tocar o banco de novo')

-- O cache é de matéria-prima, e não de tela pronta: com o material da gang quente, quem não
-- pode ver offline continua sem ver. Cachear o snapshot montado entregaria a lista do chefe
-- para o cargo de baixo, que foi quem pediu depois.
local rightGrade = world.membership.RIGHT.ballas
world.membership.RIGHT.ballas = 1
local narrow = callbacks['noir_gangs:server:getSnapshot'](2)
world.membership.RIGHT.ballas = rightGrade
T.truthy(#narrow.members > 0, 'o cargo de baixo enxerga a gang')
for i = 1, #narrow.members do
    T.truthy(narrow.members[i].online, 'mas só quem está online, mesmo lendo o material do cache')
end

memberAction(1, 'SOLDIER', 'demote')
dbTouches = 0
local afterChange = callbacks['noir_gangs:server:getSnapshot'](1)
T.truthy(dbTouches > 0, 'mudar a gang derruba o cache')
for i = 1, #afterChange.members do
    if afterChange.members[i].citizenid == 'SOLDIER' then
        T.equal(afterChange.members[i].grade, 1, 'e a tela lê o cargo novo, não o que estava cacheado')
    end
end

-- No servidor de verdade a montagem cede no meio, porque as consultas são `await`: dá para
-- pedir de novo antes de a primeira terminar. Aqui a cessão é imitada de dentro do stub.
memberAction(1, 'SOLDIER', 'promote')
local reentryTried, reentryResult = false, nil
NoirGangs.membersOf = function(name)
    if not reentryTried then
        reentryTried = true
        reentryResult = callbacks['noir_gangs:server:getSnapshot'](1)
    end
    return realGangMembers(name)
end
callbacks['noir_gangs:server:getSnapshot'](1)
T.truthy(reentryTried, 'o pedido concorrente chegou a ser tentado')
T.falsy(reentryResult, 'e não abriu uma segunda montagem para o mesmo source')

-- Um erro no meio da montagem não pode deixar a porta trancada para o resto da sessão. A
-- ação antes dele existe para derrubar o cache: com material válido em mãos, a montagem
-- nem chega ao banco para falhar.
memberAction(1, 'SOLDIER', 'demote')
NoirGangs.membersOf = function() error('banco caiu') end
T.falsy(pcall(callbacks['noir_gangs:server:getSnapshot'], 1), 'o erro sobe para quem chamou')
NoirGangs.membersOf, core.GetCharacterNames, MySQL.query.await = realGangMembers, realNames, realQuery
T.truthy(callbacks['noir_gangs:server:getSnapshot'](1), 'e o pedido seguinte ainda é atendido')

world.membership.SOLDIER.ballas = 1

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

-- Pontos de gestão: o payload vem da tela, e a tela é do cliente -------------------------
-- As colunas de coordenada são `DOUBLE NOT NULL`. Payload torto que passa daqui não vira
-- recusa, vira erro de SQL com o ponto pela metade — então a recusa acontece antes de
-- escrever, e nada chega ao banco.
local function createPoint(data) return callbacks['noir_gangs:server:createLocation'](1, 'ballas', data) end

locationWrites = {}
T.falsy(createPoint(nil), 'payload ausente é recusado')
T.falsy(createPoint({}), 'payload sem coordenada também')
T.falsy(createPoint({ x = 1.0, y = 2.0 }), 'faltando um eixo, idem')
T.falsy(createPoint({ x = 1.0, y = 2.0, z = '3' }), 'coordenada em texto não vira número por conta própria')
T.falsy(createPoint({ x = 0 / 0, y = 2.0, z = 3.0 }), 'NaN não é coordenada')
T.falsy(createPoint({ x = math.huge, y = 2.0, z = 3.0 }), 'infinito também não')
T.falsy(createPoint({ x = 1.0, y = 2.0, z = 3.0, heading = 'norte' }), 'heading torto é recusa, e não 0 em silêncio')
T.falsy(createPoint({ x = 99999.0, y = 2.0, z = 3.0 }), 'ponto fora do mapa é recusado')
T.equal(#locationWrites, 0, 'nenhum payload inválido chegou ao banco')

local pointId = createPoint({ x = 1.5, y = -2.5, z = 3.0 })
T.truthy(pointId, 'payload completo é aceito')
T.equal(#locationWrites, 1, 'e só ele escreve')
T.equal(locationWrites[1].values[7], 'NEWCOMER', 'gravando quem criou')

-- Heading é normalizado, e não recusado: 450 graus é a mesma direção que 90.
locationWrites = {}
T.truthy(createPoint({ x = 1.0, y = 2.0, z = 3.0, heading = 450.0 }), 'heading fora de volta é aceito')
T.equal(locationWrites[1].values[6], 90.0, 'depois de dar a volta')

-- Id de ponto: a consulta é `WHERE id = ?`, então tabela e texto não podem descer até lá.
locationWrites = {}
T.falsy(callbacks['noir_gangs:server:updateLocation'](1, nil, { x = 1.0, y = 2.0, z = 3.0 }), 'mover sem id é recusado')
T.falsy(callbacks['noir_gangs:server:updateLocation'](1, {}, { x = 1.0, y = 2.0, z = 3.0 }), 'id que é tabela também')
T.falsy(callbacks['noir_gangs:server:updateLocation'](1, 1.5, { x = 1.0, y = 2.0, z = 3.0 }), 'id quebrado também')
T.falsy(callbacks['noir_gangs:server:updateLocation'](1, 1, nil), 'mover para lugar nenhum é recusado')
T.falsy(callbacks['noir_gangs:server:deleteLocation'](1, 'todos'), 'apagar com id em texto é recusado')
T.equal(#locationWrites, 0, 'e nada disso tocou o banco')

T.truthy(callbacks['noir_gangs:server:updateLocation'](1, 7, { x = 1.0, y = 2.0, z = 3.0 }), 'com id e ponto válidos, move')
T.truthy(callbacks['noir_gangs:server:deleteLocation'](1, '7'), 'e o id numérico em texto ainda é aceito, já convertido')

-- Entre o pedido e a escrita há consulta, e consulta cede: o admin pode cair no meio. Sem
-- a checagem, `actor.citizenId` é índice de nil depois de a linha já ter sido gravada.
locationWrites = {}
local realCharacter = core.GetCharacter
core.GetCharacter = function() return nil end
T.falsy(createPoint({ x = 1.0, y = 2.0, z = 3.0 }), 'quem saiu no meio não cria ponto')
T.falsy(callbacks['noir_gangs:server:updateLocation'](1, 7, { x = 1.0, y = 2.0, z = 3.0 }), 'nem move')
T.falsy(callbacks['noir_gangs:server:deleteLocation'](1, 7), 'nem apaga')
T.equal(#locationWrites, 0, 'e nada foi escrito pela metade')
core.GetCharacter = realCharacter

-- Produtos ---------------------------------------------------------------------------------
-- O config era dono: reescrevia a lista a cada start, e gang criada em jogo ficava sem
-- produto para sempre. Agora ele é semente e a tela grava.
productWrites = {}
local prodOk, prodCode = callbacks['noir_gangs:server:updateGang'](1,
    { name = 'ballas', label = 'Ballas', products = { 'drugs', 'weapons' } })
T.truthy(prodOk, 'a tela grava os produtos da gang')
T.equal(#productWrites, 1, 'numa escrita só, com a lista inteira')
T.truthy(world.products.ballas.weapons, 'e o produto novo passa a valer')

prodOk, prodCode = callbacks['noir_gangs:server:updateGang'](1,
    { name = 'ballas', label = 'Ballas', products = { 'plutonio' } })
T.falsy(prodOk, 'produto fora do catálogo é recusado')
T.equal(prodCode, 'invalid_product', 'com o motivo certo')
T.equal(#productWrites, 1, 'e a recusa acontece antes de gravar')

T.truthy(callbacks['noir_gangs:server:updateGang'](1, { name = 'ballas', label = 'Ballas', products = {} }),
    'lista vazia é aceita')
T.falsy(next(world.products.ballas), 'não operar nada também é escolha, e ela é gravada')

-- Tela antiga não manda o campo; nesse caso a lista fica como está, e não some.
world.products.ballas = { drugs = true }
T.truthy(callbacks['noir_gangs:server:updateGang'](1, { name = 'ballas', label = 'Ballas' }))
T.truthy(world.products.ballas.drugs, 'sem o campo, a lista não é tocada')

productWrites = {}
local madeOk, _, madeName = callbacks['noir_gangs:server:createGang'](1,
    { name = 'nova2', label = 'Nova 2', archetype = 'gueto', color = 'roxo', products = { 'items' } })
T.truthy(madeOk, 'a gang nasce com produto escolhido na mesma tela')
T.equal(madeName, 'nova2', 'e a tela recebe o identificador para abrir nela')
T.truthy(world.products.nova2.items, 'sem passar pelo config nem pelo restart')

-- Primeiro chefe ----------------------------------------------------------------------------
-- A gang criada pela tela nasce com a escada montada e ninguém dentro. Definir o primeiro
-- chefe aqui evita a volta pelo `/setgang`; trocar quem lidera continua não sendo desta tela.
local bossOk, bossCode = callbacks['noir_gangs:server:assignBoss'](1, 'ballas', 5)
T.falsy(bossOk, 'gang que já tem chefe não recebe outro por aqui')
T.equal(bossCode, 'boss_exists', 'e o motivo aponta para fora da tela')

bossOk, bossCode = callbacks['noir_gangs:server:assignBoss'](1, 'nova', 2)
T.falsy(bossOk, 'quem já tem gang não assume outra')
T.equal(bossCode, 'already_in_gang', 'pela mesma regra do convite')

local _, _, bossName = callbacks['noir_gangs:server:assignBoss'](1, 'nova', 5)
T.equal(bossName, 'Elo Outro', 'gang sem chefe recebe o primeiro, e a tela mostra quem é')
T.truthy(world.membership.OTHER.nova, 'e a pessoa entra na gang')
T.equal(world.membership.OTHER.nova, NoirGangs.bossRank('nova').level, 'no cargo de chefe')

bossOk, bossCode = callbacks['noir_gangs:server:assignBoss'](1, 'nova', 5)
T.falsy(bossOk, 'e a segunda vez já não passa')
T.equal(bossCode, 'boss_exists', 'porque agora existe chefe')

local setupWithBoss = callbacks['noir_gangs:server:getSetup'](1)
local novaCard
for i = 1, #setupWithBoss.gangs do
    if setupWithBoss.gangs[i].name == 'nova' then novaCard = setupWithBoss.gangs[i] end
end
T.equal(novaCard.bossName, 'Elo Outro', 'o setup mostra quem lidera, para não oferecer de novo')
T.truthy(#setupWithBoss.products > 0, 'e traz o catálogo de produtos para a tela desenhar')

world.membership.OTHER.nova = nil

-- Ações concorrentes ------------------------------------------------------------------------
-- A tranca é da gang, e não de quem pediu: o teto de cargos é lido da memória antes da
-- escrita, e a escrita cede o controle. Dois pedidos ao mesmo tempo passavam os dois.
-- Quem grava o cargo agora é `NoirGangs.setMember`, não o bridge: o gancho segue a
-- escrita, senão a cessão simulada nunca acontece e o teste passaria sem testar nada.
local reentryTriedMember, reentryMemberCode = false, nil
local realSetGrade = NoirGangs.setMember
NoirGangs.setMember = function(citizenId, gangName, grade)
    if not reentryTriedMember then
        reentryTriedMember = true
        local _, code = memberAction(1, 'SOLDIER', 'promote')
        reentryMemberCode = code
    end
    return realSetGrade(citizenId, gangName, grade)
end
memberAction(1, 'SOLDIER', 'promote')
NoirGangs.setMember = realSetGrade
T.truthy(reentryTriedMember, 'o pedido concorrente chegou a ser tentado')
T.equal(reentryMemberCode, 'busy', 'e a segunda ação na mesma gang é recusada, não enfileirada')
world.membership.SOLDIER.ballas = 1

-- Bootstrap falhado -------------------------------------------------------------------------
-- Registro vazio não é "servidor sem gangs": é gang nenhuma publicada no provider, com o
-- Qbox descartando em silêncio a gang de quem loga. O resource recusa em vez de servir o
-- vazio. O bloco recarrega o servidor com o bootstrap reprovando, então fica por último:
-- daqui para baixo os callbacks são os do chunk que recusa.
NoirGangs.bootstrap = function() return false end
dofile('server/main.lua')

local brokenState = callbacks['noir_gangs:server:getSnapshot'](1)
T.falsy(brokenState.inGang, 'sem bootstrap, o snapshot não finge que a pessoa está sem gang por escolha')
T.truthy(brokenState.notReady, 'ele diz que a causa é o resource, para a tela não culpar a permissão')

local _, brokenCode = memberAction(1, 'SOLDIER', 'promote')
T.equal(brokenCode, 'not_ready', 'ação de membro recusa')

_, brokenCode = callRank('createRank', 1, 'Tenente')
T.equal(brokenCode, 'not_ready', 'editor de cargos recusa')

_, brokenCode = callbacks['noir_gangs:server:createGang'](1,
    { name = 'fantasma', label = 'Fantasma', archetype = 'gueto', color = 'roxo' })
T.equal(brokenCode, 'not_ready', 'criar gang recusa mesmo com ace: o registro não foi lido')

T.falsy(callbacks['noir_gangs:server:createLocation'](1, 'ballas', { x = 1.0, y = 2.0, z = 3.0 }),
    'e ponto de gestão também')

IsPlayerAceAllowed = function() return false end

print('server_spec: ok')
