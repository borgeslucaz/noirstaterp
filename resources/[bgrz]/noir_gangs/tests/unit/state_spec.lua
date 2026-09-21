-- Exercita server/state.lua contra um banco em memória: schema, validação do config,
-- seed dos cargos a partir do arquétipo, publicação do rótulo no provider, permissão por
-- cargo, produtos, os limites da reputação e o editor de cargos.
local T = dofile('tests/testlib.lua')

function vec3(x, y, z) return { x = x, y = y, z = z } end
dofile('shared/config.lua')

-- Banco em memória ---------------------------------------------------------------------
local tables = { noir_gang_ranks = {}, noir_gang_products = {}, noir_gang_state = {},
    noir_gang_members = {} }
local schemaStatements = {}

local function key(row, columns)
    local parts = {}
    for i = 1, #columns do parts[i] = tostring(row[columns[i]]) end
    return table.concat(parts, '|')
end

---Interpretador mínimo de SQL: só as formas que o state.lua realmente emite.
local function execute(query, values)
    values = values or {}
    local upper = query:upper()

    if upper:match('^CREATE%s+TABLE') then
        schemaStatements[#schemaStatements + 1] = query
        return {}
    end

    if query:find('INSERT INTO noir_gang_ranks', 1, true) then
        local row = { gang_name = values[1], level = values[2], label = values[3],
            is_boss = values[4], bank_auth = values[5], permissions = values[6] }
        tables.noir_gang_ranks[key(row, { 'gang_name', 'level' })] = row
        return 1
    end
    if query:find('UPDATE noir_gang_ranks SET level', 1, true) then
        local newLevel, gangName, oldLevel = values[1], values[2], values[3]
        local id = key({ gang_name = gangName, level = oldLevel }, { 'gang_name', 'level' })
        local row = tables.noir_gang_ranks[id]
        if row then
            tables.noir_gang_ranks[id] = nil
            row.level = newLevel
            tables.noir_gang_ranks[key(row, { 'gang_name', 'level' })] = row
        end
        return 1
    end
    -- O editor apaga um nível só; o seed apaga tudo que não está no arquétipo. As duas
    -- formas chegam aqui, e confundi-las apagaria a gang inteira num teste verde.
    if query:find('DELETE FROM noir_gang_ranks', 1, true) and not upper:find('NOT IN') then
        tables.noir_gang_ranks[key({ gang_name = values[1], level = values[2] }, { 'gang_name', 'level' })] = nil
        return 1
    end
    if query:find('DELETE FROM noir_gang_ranks', 1, true) then
        local gangName, keep = values[1], {}
        for i = 2, #values do keep[values[i]] = true end
        for id, row in pairs(tables.noir_gang_ranks) do
            if row.gang_name == gangName and not keep[row.level] then tables.noir_gang_ranks[id] = nil end
        end
        return 1
    end
    if query:find('INSERT IGNORE INTO noir_gang_products', 1, true) then
        local row = { gang_name = values[1], product_type = values[2] }
        tables.noir_gang_products[key(row, { 'gang_name', 'product_type' })] = row
        return 1
    end
    if query:find('DELETE FROM noir_gang_products', 1, true) then
        for id, row in pairs(tables.noir_gang_products) do
            if row.gang_name == values[1] then tables.noir_gang_products[id] = nil end
        end
        return 1
    end
    if query:find('INSERT INTO noir_gang_members', 1, true) then
        tables.noir_gang_members[values[1]] =
            { citizenid = values[1], gang_name = values[2], level = values[3] }
        return 1
    end
    if query:find('DELETE FROM noir_gang_members WHERE citizenid', 1, true) then
        tables.noir_gang_members[values[1]] = nil
        return 1
    end
    if query:find('DELETE FROM noir_gang_members WHERE gang_name', 1, true) then
        for id, row in pairs(tables.noir_gang_members) do
            if row.gang_name == values[1] then tables.noir_gang_members[id] = nil end
        end
        return 1
    end
    if query:find('INSERT IGNORE INTO noir_gang_state', 1, true) then
        local id = values[1]
        if not tables.noir_gang_state[id] then
            tables.noir_gang_state[id] = { gang_name = id, reputation = 0,
                label = values[2], color = values[3], archetype = values[4] }
        end
        return 1
    end
    if query:find('INSERT INTO noir_gang_state', 1, true) then
        tables.noir_gang_state[values[1]] = { gang_name = values[1], reputation = 0,
            label = values[2], color = values[3], archetype = values[4] }
        return 1
    end
    if query:find('DELETE FROM noir_gang_state', 1, true) then
        tables.noir_gang_state[values[1]] = nil
        return 1
    end
    if query:find('UPDATE noir_gang_state SET label = ?, color = ?, archetype', 1, true) then
        local row = tables.noir_gang_state[values[4]]
        if row then row.label, row.color, row.archetype = values[1], values[2], values[3] end
        return 1
    end
    if query:find('UPDATE noir_gang_state SET next_rank_level', 1, true) then
        local row = tables.noir_gang_state[values[2]]
        if row then row.next_rank_level = values[1] end
        return 1
    end
    if query:find('UPDATE noir_gang_state SET label', 1, true) then
        local row = tables.noir_gang_state[values[2]]
        if row and (row.label == nil or row.label == '') then row.label = values[1] end
        return 1
    end
    if query:find('UPDATE noir_gang_state SET color', 1, true) then
        local row = tables.noir_gang_state[values[2]]
        if row and (row.color == nil or row.color == '') then row.color = values[1] end
        return 1
    end
    if query:find('UPDATE noir_gang_state SET archetype', 1, true) then
        local row = tables.noir_gang_state[values[2]]
        if row then row.archetype = values[1] end
        return 1
    end
    if query:find('UPDATE noir_gang_state SET reputation', 1, true) then
        local row = tables.noir_gang_state[values[2]]
        if row then row.reputation = values[1] end
        return 1
    end

    local name = query:match('FROM%s+([%w_]+)')
    local rows = {}
    for _, row in pairs(tables[name] or {}) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b)
        return tostring(a.gang_name) .. tostring(a.level or '') < tostring(b.gang_name) .. tostring(b.level or '')
    end)
    return rows
end

MySQL = {
    query = { await = execute },
    update = { await = execute },
    insert = setmetatable({ await = execute }, { __call = function(_, q, v) return execute(q, v) end }),
    single = { await = function(q, v) return execute(q, v)[1] end },
    scalar = { await = function(q, v)
        -- Marca d'água do próximo nível de cargo. Antes vinha do provider, que nunca
        -- esquecia um grade publicado; com o Qbox fora, a memória é nossa.
        if q:find('next_rank_level', 1, true) then
            local row = tables.noir_gang_state[v[1]]
            return row and row.next_rank_level or 0
        end
        -- A outra: quantos cargos a gang já tem.
        local gangName, total = v[1], 0
        for _, row in pairs(tables.noir_gang_ranks) do
            if row.gang_name == gangName then total = total + 1 end
        end
        return total
    end },
    transaction = { await = function(writes)
        for i = 1, #writes do execute(writes[i].query, writes[i].values) end
        return true
    end },
}

-- Provider stubado ---------------------------------------------------------------------
local published = {}

---O dicionário do provider, modelado de verdade. É ele que decide se o teste enxerga a
---diferença entre `RegisterGangs` (atribui, zera a escada) e `UpsertGangData` (mescla).
local provider = {}
local commits = {}

local core = {}
---O provider recebe a lista de quem existe; o registro é nosso. O teste guarda o que foi
---enviado para conferir que a gang chega lá antes dos cargos dela.
local registered = {}
-- `PlayerData.gang` de quem está online, separado da membresia (que é o `player_groups`).
-- Os dois existem aqui porque o bug que este bloco cobre mexe em um e não no outro.
local onlineGang = {}

-- Reproduz o que o qbx_core faz com quem está online sempre que a escada de uma gang
-- muda: cada jogador procura o PRÓPRIO nível na escada nova e, não achando, é rebaixado
-- para 0 com `isboss` e `bankAuth` desligados. É a regra real de `onGangUpdate`.
local function notifyGangUpdate(gangName)
    local grades = provider[gangName] and provider[gangName].grades or {}
    for _, gang in pairs(onlineGang) do
        if gang.name == gangName and not grades[gang.level] then gang.level = 0 end
    end
end

function core:RegisterGangs(list)
    registered = {}
    for i = 1, #list do
        registered[list[i].name] = list[i].label
        -- Igual ao provider: ATRIBUI a entrada, não mescla. O que vier em `grades` é a
        -- escada inteira daquela gang a partir daqui -- inclusive se vier vazia.
        local grades = {}
        for level, grade in pairs(list[i].grades or {}) do
            grades[level] = { name = grade.label or grade.name, isboss = grade.isBoss == true }
        end
        provider[list[i].name] = { label = list[i].label, grades = grades }
        notifyGangUpdate(list[i].name)
    end
    return true
end
function core:UpsertGangGrade(gangName, level, data)
    published[#published + 1] = { gang = gangName, level = level, label = data.label, isBoss = data.isBoss }
    provider[gangName] = provider[gangName] or { label = gangName, grades = {} }
    provider[gangName].grades[level] = { name = data.label }
    notifyGangUpdate(gangName)
    return true
end

-- O provider nunca esquece um grade: `deleteRank` deixa o órfão lá de propósito. É por
-- isso que ele serve de marca d'água do maior nível que a gang já teve.
function core:GetGangInfo(gangName)
    local entry = provider[gangName]
    if not entry then return nil end
    local topGrade = 0
    for level in pairs(entry.grades) do
        if level > topGrade then topGrade = level end
    end
    return { name = gangName, label = entry.label, grades = entry.grades, topGrade = topGrade }
end

function core:UpsertGangData(gangName, label)
    if provider[gangName] then
        provider[gangName].label = label
    else
        provider[gangName] = { label = label, grades = {} }
    end
    return true
end

---Grava o arquivo: guarda uma foto de como o dicionário estava naquele instante. É sobre
---essa foto que a invariante é cobrada.
function core:CommitGangsToFile()
    local snapshot = {}
    for name, gang in pairs(provider) do
        local levels = 0
        for _ in pairs(gang.grades) do levels = levels + 1 end
        snapshot[name] = levels
    end
    commits[#commits + 1] = snapshot
    return true
end

---O provider apaga do `player_groups` toda linha cujo cargo não exista. Um arquivo gravado
---com gang de escada vazia significa, no boot seguinte, a membresia de todo mundo apagada.
---Nenhuma gravação pode conter uma.
local function assertNoEmptyLadderOnCommit(label)
    T.truthy(#commits > 0, label .. ': nada foi gravado')
    for i = 1, #commits do
        for name, levels in pairs(commits[i]) do
            T.truthy(levels > 0,
                ('%s: o arquivo saiu com %s sem cargo nenhum — isso apaga a membresia no próximo boot'):format(label, name))
        end
    end
end

-- Membros: o editor precisa deles para recusar excluir cargo ocupado, e para mover o chefe
-- quando abre espaço abaixo dele.
local membership = {}

function core:GetGangMembers(gangName)
    local list = {}
    for citizenId, entry in pairs(membership) do
        if entry.gang == gangName then list[#list + 1] = { citizenId = citizenId, grade = entry.grade } end
    end
    table.sort(list, function(a, b) return a.citizenId < b.citizenId end)
    return list
end

function core:GetCharacterSource() return nil end
function core:GetCitizenId() return nil end

function core:SetGangGrade(citizenId, gangName, grade)
    local entry = membership[citizenId]
    if not entry or entry.gang ~= gangName then return false end
    entry.grade = grade
    return true
end

exports = T.exports({ bgrz_core = core })

local errors = {}
lib = { print = { info = function() end, error = function(msg) errors[#errors + 1] = msg end } }

json = {
    encode = function(list)
        local parts = {}
        for i = 1, #list do parts[i] = list[i] end
        return table.concat(parts, ',')
    end,
    decode = function(raw)
        local list = {}
        for item in tostring(raw):gmatch('[^,]+') do list[#list + 1] = item end
        return list
    end,
}

GetCurrentResourceName = function() return 'noir_gangs' end
LoadResourceFile = function(_, path)
    local file = assert(io.open(path, 'r'), 'missing ' .. path)
    local content = file:read('*a')
    file:close()
    return content
end

-- O state bag é como o servidor publica a gang para o client. No teste basta existir.
local published = published or {}
Player = function(source)
    return { state = { set = function(_, key, value) published[source] = { key = key, value = value } end } }
end
TriggerClientEvent = TriggerClientEvent or function() end
AddEventHandler = AddEventHandler or function() end

dofile('server/state.lua')
dofile('server/members.lua')

-- Schema ---------------------------------------------------------------------------------
T.truthy(NoirGangs.bootstrap(), 'bootstrap completo: ' .. (errors[1] or ''))
T.equal(#schemaStatements, 6, 'as seis tabelas saem do migrations/.sql')

-- Config -----------------------------------------------------------------------------------
T.truthy(NoirGangs.validateConfig(), 'o config que vai para produção é válido')

-- Permissão desconhecida derruba o start: ela nunca seria verdadeira, e o erro só
-- apareceria no dia em que alguém precisasse dela.
local saved = Config.RankArchetypes.gueto.ranks[1].permissions
Config.RankArchetypes.gueto.ranks[1].permissions = { 'view_members', 'promver_membros' }
T.falsy(NoirGangs.validateConfig(), 'permissão fora do catálogo é recusada')
Config.RankArchetypes.gueto.ranks[1].permissions = saved

local savedArchetype = Config.Gangs.ballas.archetype
Config.Gangs.ballas.archetype = 'inexistente'
T.falsy(NoirGangs.validateConfig(), 'arquétipo inexistente é recusado')
Config.Gangs.ballas.archetype = savedArchetype

local savedProducts = Config.Gangs.ballas.products
Config.Gangs.ballas.products = { 'plutonio' }
T.falsy(NoirGangs.validateConfig(), 'produto fora do catálogo é recusado')
Config.Gangs.ballas.products = savedProducts

T.truthy(NoirGangs.validateConfig(), 'config volta ao normal depois das mutações')

-- Cargos ------------------------------------------------------------------------------------
T.equal(NoirGangs.rank('ballas', 0).label, 'Recruit', 'gueto semeia os cargos de hoje')
T.equal(NoirGangs.topLevel('ballas'), 3, 'gueto tem quatro cargos, topo em 3')
T.equal(NoirGangs.rank('lostmc', 5).label, 'President', 'MC semeia o arquétipo próprio')
T.equal(NoirGangs.topLevel('lostmc'), 5, 'MC tem seis cargos, topo em 5')
T.truthy(NoirGangs.rank('lostmc', 5).isBoss, 'o topo do MC é boss')

-- A gang não é mais registrada no provider; o registro dela é a nossa própria tabela.

-- Linha com arquétipo que não existe mais (versão antiga, edição à mão) cai no padrão em
-- vez de derrubar o start.
MySQL.query.await('INSERT IGNORE INTO noir_gang_state (gang_name, label, color, archetype) VALUES (?, ?, ?, ?)',
    { 'semconfig', 'Sem Config', 'cinza', 'arquetipo_que_sumiu' })
NoirGangs.bootstrap()
T.equal(NoirGangs.topLevel('semconfig'), 3, 'arquétipo desconhecido recebe o padrão')
T.equal(#NoirGangs.productsOf('semconfig'), 0, 'e gang fora do config fica sem produto')

-- Permissões ----------------------------------------------------------------------------------
T.falsy(NoirGangs.can('ballas', 3, 'transfer_leadership'),
    'transferir liderança não existe mais como permissão')
T.falsy(NoirGangs.can('ballas', 0, 'invite'), 'recruta não convida')
T.truthy(NoirGangs.can('ballas', 2, 'invite'), 'shot caller convida')
T.truthy(NoirGangs.can('ballas', 2, 'promote'), 'o cargo abaixo do chefe gere a gang')
-- Sem herança entre cargos: o que está escrito no cargo é o que ele pode.
T.falsy(NoirGangs.can('lostmc', 1, 'promote'), 'member não herda o poder dos cargos acima')
T.falsy(NoirGangs.can('ballas', 99, 'view_members'), 'cargo inexistente não pode nada')

-- `isBoss` é o que torna o cargo intocável, então precisa sobreviver ao seed.
T.truthy(NoirGangs.rank('ballas', 3).isBoss, 'o topo do gueto é chefe')
T.falsy(NoirGangs.rank('ballas', 2).isBoss, 'o cargo abaixo não é')

-- Níveis esparsos do MC continuam navegáveis pelos vizinhos reais.
T.equal(NoirGangs.levelAbove('ballas', 0), 1, 'próximo cargo acima')
T.equal(NoirGangs.levelBelow('ballas', 3), 2, 'próximo cargo abaixo')
T.falsy(NoirGangs.levelAbove('ballas', 3), 'acima do topo não há nada')

-- Produtos --------------------------------------------------------------------------------------
T.truthy(NoirGangs.hasProduct('ballas', 'drugs'), 'ballas opera drogas')
T.falsy(NoirGangs.hasProduct('ballas', 'weapons'), 'ballas não opera armas')
T.truthy(NoirGangs.hasProduct('lostmc', 'weapons'), 'lostmc opera armas')
T.equal(#NoirGangs.productsOf('ballas'), 1, 'uma gang normalmente tem um produto')

-- Mais de um produto precisa funcionar sem mudar nada além do config.
Config.Gangs.ballas.products = { 'drugs', 'ammo' }
NoirGangs.bootstrap()
T.equal(#NoirGangs.productsOf('ballas'), 2, 'duas linhas, dois produtos')
T.truthy(NoirGangs.hasProduct('ballas', 'ammo'), 'o segundo produto responde igual ao primeiro')
Config.Gangs.ballas.products = savedProducts
NoirGangs.bootstrap()
T.equal(#NoirGangs.productsOf('ballas'), 1, 'tirar do config tira do banco')

-- O rótulo do cargo não viaja mais para o Qbox: quem lê cargo lê daqui.

-- Reputação --------------------------------------------------------------------------------------
T.equal(NoirGangs.reputationOf('ballas'), 0, 'gang nova começa em zero')

local total = NoirGangs.addReputation('ballas', 250)
T.equal(total, 250, 'somar pontos')
T.equal(NoirGangs.reputationOf('ballas'), 250, 'e o cache acompanha')

total = NoirGangs.addReputation('ballas', -100)
T.equal(total, 150, 'tirar pontos é o mesmo caminho, com delta negativo')

local ok, err = NoirGangs.addReputation('ballas', 0)
T.falsy(ok, 'delta zero não é ajuste')
T.equal(err, 'invalid_delta', 'e diz o porquê')

ok, err = NoirGangs.addReputation('ballas', 1.5)
T.falsy(ok, 'reputação é inteiro')
T.equal(err, 'invalid_delta', 'fração é recusada')

ok, err = NoirGangs.addReputation('ballas', Config.Reputation.maxDelta + 1)
T.falsy(ok, 'um ajuste sozinho não pode ser ilimitado')
T.equal(err, 'delta_too_large', 'o teto por ajuste protege contra o zero a mais')

ok, err = NoirGangs.addReputation('inexistente', 10)
T.falsy(ok, 'gang desconhecida não acumula reputação')
T.equal(err, 'gang_not_found', 'com o erro certo')

-- O total fica preso no limite em vez de passar dele.
for _ = 1, 12 do NoirGangs.addReputation('ballas', Config.Reputation.maxDelta) end
T.equal(NoirGangs.reputationOf('ballas'), Config.Reputation.max, 'o total para no teto')
total, err = NoirGangs.addReputation('ballas', 1)
T.equal(err, 'at_limit', 'e avisa que já está no limite')

-- Reseed não apaga reputação: cargo e produto vêm do config, reputação é dado vivo.
NoirGangs.bootstrap()
T.equal(NoirGangs.reputationOf('ballas'), Config.Reputation.max, 'o reseed preserva a reputação')

-- Como o TINYINT chega do driver ------------------------------------------------------------
-- O mesmo `1` chega como número, como `true` ou como string dependendo do driver e da
-- versão. Ler errado aqui significa gang sem chefe: chefia desprotegida e editor de cargos
-- que nunca abre para ninguém.
for _, raw in ipairs({ 1, true, '1' }) do
    MySQL.query.await(
        'INSERT INTO noir_gang_ranks (gang_name, level, label, is_boss, bank_auth, permissions) VALUES (?, ?, ?, ?, ?, ?)',
        { 'vagos', 3, 'Boss', raw, raw, json.encode({ 'view_members' }) })
    NoirGangs.bootstrap()
    local boss = NoirGangs.bossRank('vagos')
    T.truthy(boss, ('is_boss chegando como %s ainda é chefe'):format(type(raw)))
    T.equal(boss.level, 3, 'no nível certo')
    T.truthy(boss.bankAuth, ('bank_auth chegando como %s ainda dá acesso ao banco'):format(type(raw)))
end

for _, raw in ipairs({ 0, false, '0' }) do
    MySQL.query.await(
        'INSERT INTO noir_gang_ranks (gang_name, level, label, is_boss, bank_auth, permissions) VALUES (?, ?, ?, ?, ?, ?)',
        { 'vagos', 2, 'Shot Caller', raw, raw, json.encode({ 'view_members' }) })
    NoirGangs.bootstrap()
    T.falsy(NoirGangs.rank('vagos', 2).isBoss, ('%s falso não vira chefe'):format(type(raw)))
    T.falsy(NoirGangs.rank('vagos', 2).bankAuth, ('%s falso não abre o banco'):format(type(raw)))
end

-- Chefe sempre gere os cargos ---------------------------------------------------------------
-- Cenário do upgrade, e ele passa pelo start inteiro de propósito: a gang já tinha cargos
-- gravados de antes de `manage_ranks` existir. Como o config agora vale só como semente,
-- nada reescreveria aquelas linhas — e o cargo de chefe é justamente o único que o editor
-- não conserta, então a gang ficaria trancada fora do editor para sempre.
local bossLevel = NoirGangs.topLevel('ballas')
MySQL.query.await(
    'INSERT INTO noir_gang_ranks (gang_name, level, label, is_boss, bank_auth, permissions) VALUES (?, ?, ?, ?, ?, ?)',
    { 'ballas', bossLevel, 'Boss', 1, 1, json.encode({ 'view_members', 'promote' }) })

NoirGangs.bootstrap()
T.truthy(NoirGangs.can('ballas', bossLevel, 'manage_ranks'), 'o start conserta o chefe trancado')
T.truthy(NoirGangs.can('ballas', bossLevel, 'promote'), 'sem perder o que ele já tinha')
T.truthy(NoirGangs.rank('ballas', bossLevel).isBoss, 'e ele continua sendo o chefe')
T.falsy(NoirGangs.can('ballas', 2, 'manage_ranks'), 'nenhum outro cargo foi tocado')
T.equal(NoirGangs.repairBossRanks(), 0, 'e rodar de novo não mexe em nada')

-- Editor de cargos ------------------------------------------------------------------------
-- O gueto entra aqui com 0..3, chefe em 3. Cada bloco confere uma das regras que protegem
-- quem já está ocupando um cargo.

-- A membresia é do resource agora, então a fixture entra pela API dele em vez de uma
-- tabela paralela: é o mesmo caminho que o jogo usa.
NoirGangs.setMember('BOSS', 'ballas', 3)
NoirGangs.setMember('SOLDADO', 'ballas', 1)

-- Criar: o cargo nasce logo abaixo do chefe NA ESCADA, mas com um identificador novo.
--
-- É a regressão que motivou separar `level` de `sort_order`. Antes, "abrir espaço abaixo
-- do chefe" significava subir o chefe de NÍVEL, e isso obrigava a mover cada membro da
-- chefia para outro grade nos dois lados do Qbox. Foi assim que um cargo criado no meio da
-- escada do vagos dessincronizou `player_groups` e `players.gang`.
local level, createErr = NoirGangs.createRank('ballas', '  Tenente  ')
T.equal(createErr, nil, 'criar cargo válido não dá erro')
T.equal(level, 4, 'o cargo novo recebe o próximo identificador livre, não um lugar no meio')
T.equal(NoirGangs.rank('ballas', 4).label, 'Tenente', 'com o rótulo já sem os espaços das pontas')

-- As três asserções que importam: ninguém foi renumerado.
T.equal(NoirGangs.gangOfCitizen('BOSS').grade, 3, 'quem está na chefia NÃO mudou de nível')
T.equal(NoirGangs.gangOfCitizen('SOLDADO').grade, 1, 'e ninguém mais mudou de nível')
T.equal(NoirGangs.rank('ballas', 3).level, 3, 'o chefe continua no nível em que nasceu')

-- E a escada continua contando a história certa, agora por posição.
T.equal(NoirGangs.topLevel('ballas'), 3, 'o topo da escada continua sendo o chefe')
T.truthy(NoirGangs.rank('ballas', 3).isBoss, 'que segue sendo chefe')
T.equal(NoirGangs.levelAbove('ballas', 4), 3, 'o cargo novo fica logo abaixo do chefe')
T.equal(NoirGangs.levelBelow('ballas', 4), 2, 'e logo acima do que era o segundo')
T.truthy(NoirGangs.rank('ballas', 3).sortOrder > NoirGangs.rank('ballas', 4).sortOrder,
    'o chefe foi empurrado na ORDEM, que é de graça, não no nível')

T.falsy(next(NoirGangs.rank('ballas', 4).permissions), 'cargo novo nasce sem permissão nenhuma')
T.falsy(NoirGangs.rank('ballas', 4).isBoss, 'e nasce sem ser chefe')

-- Identificador de cargo apagado NÃO volta a circular. Reaproveitar o número faria um
-- membro antigo, com o grade velho gravado em algum lugar, reaparecer no cargo errado.
T.truthy(NoirGangs.deleteRank('ballas', 4), 'cargo vazio sai sem discussão')
local reused = NoirGangs.createRank('ballas', 'Tenente')
T.equal(reused, 5, 'o número do cargo apagado não é reaproveitado')
T.equal(NoirGangs.topLevel('ballas'), 3, 'e o chefe segue onde sempre esteve')
T.equal(NoirGangs.gangOfCitizen('BOSS').grade, 3, 'sem mover ninguém')
T.equal(NoirGangs.levelAbove('ballas', 5), 3, 'o cargo novo também nasce abaixo do chefe')

-- Rótulo: vazio, só espaço e longo demais são recusados antes de tocar o banco.
for _, bad in ipairs({ '', '   ', string.rep('x', Config.Ranks.labelMaxLength + 1) }) do
    local ok, err = NoirGangs.updateRank('ballas', 5, { label = bad, permissions = {} })
    T.falsy(ok, 'rótulo inválido é recusado')
    T.equal(err, 'invalid_label', 'com o motivo certo')
end
T.equal(NoirGangs.rank('ballas', 5).label, 'Tenente', 'e o cargo fica como estava')

-- Permissão fora do catálogo não entra em silêncio: a gravação inteira é recusada.
local ok, err = NoirGangs.updateRank('ballas', 5, { label = 'Tenente', permissions = { 'view_members', 'voar' } })
T.falsy(ok, 'permissão inventada não passa')
T.equal(err, 'invalid_permission', 'e diz que foi a permissão')
T.falsy(NoirGangs.can('ballas', 5, 'view_members'), 'nem a permissão válida da mesma chamada entrou')

ok = NoirGangs.updateRank('ballas', 5, { label = 'Tenente', permissions = { 'invite', 'view_members' }, bankAuth = true })
T.truthy(ok, 'permissões do catálogo entram')
T.truthy(NoirGangs.can('ballas', 5, 'invite'), 'e passam a valer na hora')
T.truthy(NoirGangs.rank('ballas', 5).bankAuth, 'acesso ao banco acompanha')

-- O rótulo e o `bankAuth` ficam AQUI. Antes viajavam para o Qbox, porque era de lá que o
-- resto do servidor lia o nome do cargo e o banco decidia quem move dinheiro. Agora quem
-- pergunta, pergunta para este resource -- inclusive o `Renewed-Banking`, pelo bridge.
T.equal(NoirGangs.rank('ballas', 5).label, 'Tenente', 'o rótulo novo vale na hora')
T.truthy(NoirGangs.rank('ballas', 5).bankAuth, 'e o acesso ao banco sai do nosso cargo')

-- O chefe é intocável pelo editor: é o `isBoss` dele que torna a chefia intocável.
-- Ele continua no nível 3, onde nasceu -- criar cargo não o move mais.
ok, err = NoirGangs.updateRank('ballas', 3, { label = 'Outro', permissions = {} })
T.falsy(ok, 'o cargo de chefe não é editável')
T.equal(err, 'boss_protected', 'com o motivo explícito')
ok, err = NoirGangs.deleteRank('ballas', 3)
T.falsy(ok, 'nem excluído')
T.equal(err, 'boss_protected', 'pelo mesmo motivo')

-- Cargo ocupado não é excluído: essas pessoas cairiam num nível sem cargo, sem permissão
-- nenhuma e sem promoção que as tirasse de lá.
local occupied
ok, err, occupied = NoirGangs.deleteRank('ballas', 1)
T.falsy(ok, 'cargo com gente dentro não sai')
T.equal(err, 'rank_occupied', 'e o motivo é a ocupação')
T.equal(occupied, 1, 'dizendo quantas pessoas estão lá')

-- Teto de cargos: cada um vira também um grade no provider, que nunca é removido de lá.
while select(1, NoirGangs.rankCount('ballas')) < Config.Ranks.max do
    T.truthy(NoirGangs.createRank('ballas', 'Extra'), 'criar até o teto')
end
local blocked, limitErr = NoirGangs.createRank('ballas', 'Mais um')
T.falsy(blocked, 'passar do teto é recusado')
T.equal(limitErr, 'rank_limit', 'com o motivo certo')

-- A gang precisa sobrar com pelo menos um cargo além do chefe: sem isso, quem aceitasse um
-- convite entraria direto na chefia, ou em nível nenhum. `semconfig` entra aqui com 0..3 e
-- sem ninguém dentro.
T.truthy(NoirGangs.deleteRank('semconfig', 0), 'primeiro cargo comum sai')
T.truthy(NoirGangs.deleteRank('semconfig', 1), 'o segundo também')
local lastOk, lastErr = NoirGangs.deleteRank('semconfig', 2)
T.falsy(lastOk, 'o último cargo comum não sai')
T.equal(lastErr, 'last_rank', 'porque a gang ficaria sem porta de entrada')
T.equal(select(2, NoirGangs.rankCount('semconfig')), 1, 'e ele continua lá')

-- Porta de entrada: o menor cargo que existe, e não uma constante.
T.equal(NoirGangs.bottomLevel('lostmc'), 0, 'o MC entra pelo cargo zero')
T.truthy(NoirGangs.deleteRank('lostmc', 0), 'apagando o cargo mais baixo do MC')
T.equal(NoirGangs.bottomLevel('lostmc'), 1, 'a porta passa a ser o próximo que existe')

-- Restart com o banco mandando: o que foi editado em jogo sobrevive. É a razão de
-- `Config.RanksFromConfig` existir como `false`.
T.falsy(Config.RanksFromConfig, 'o padrão é o banco mandar')
NoirGangs.bootstrap()
T.equal(NoirGangs.rank('ballas', 5).label, 'Tenente', 'o cargo criado em jogo sobreviveu ao restart')
T.truthy(NoirGangs.can('ballas', 5, 'invite'), 'com as permissões que receberam lá')
T.equal(NoirGangs.bottomLevel('lostmc'), 1, 'e o cargo apagado continua apagado')

-- Com a chave ligada, o config volta a mandar: é o caminho para desfazer uma bagunça.
Config.RanksFromConfig = true
NoirGangs.bootstrap()
T.equal(NoirGangs.topLevel('ballas'), 3, 'o arquétipo reescreveu a escada')
T.equal(NoirGangs.rank('ballas', 3).label, 'Boss', 'e o topo voltou a ser o do config')
T.falsy(NoirGangs.rank('ballas', 5), 'os cargos criados em jogo saíram com a reescrita')
T.equal(NoirGangs.bottomLevel('lostmc'), 0, 'o cargo apagado voltou')
Config.RanksFromConfig = false

-- O bloco que cobria a republicação no provider saiu: nada mais é publicado lá. A
-- regressão que ele protegia -- membro online rebaixado quando a escada chegava vazia --
-- deixou de ser possível, porque o Qbox não tem mais escada nem membresia para rebaixar.

-- O arquivo `shared/gangs.lua` não é mais escrito por este resource: o Qbox deixou de ser
-- dono de gang. O bloco que verificava aquela gravação saiu junto com a funcionalidade.

-- Registro de gangs -------------------------------------------------------------------------
-- Criar, editar e o que o registro recusa. O identificador é o que vai para o provider e
-- para a linha do personagem, então ele é o campo mais guardado dos três.

for _, bad in ipairs({ '', '   ', 'none', '9gang', 'com espaço no meio', 'acento-ç',
                       string.rep('x', Config.Gang.nameMaxLength + 1) }) do
    local created, err = NoirGangs.createGang(bad, 'Nome', 'gueto', 'roxo')
    T.falsy(created, ('identificador inválido recusado: %q'):format(bad))
    T.equal(err, 'invalid_name', 'e o motivo é o identificador')
end

local created, err = NoirGangs.createGang('  Nova_Gang  ', '  Gangue Nova  ', 'mc', 'azul')
T.equal(created, 'nova_gang', 'o identificador é normalizado: minúsculo e sem espaço nas pontas')
T.equal(NoirGangs.gangInfo('nova_gang').label, 'Gangue Nova', 'o rótulo também')
T.equal(NoirGangs.gangInfo('nova_gang').color, 'azul', 'a cor escolhida fica')
-- Criar uma gang não pode encostar nas outras. Quando isto passava pelo Qbox, mandar a
-- lista inteira zerava a escada de todas -- hoje o registro é nosso e a garantia é local.
local balladLadder = 0
for _ in pairs(NoirGangs.ranksOf('ballas')) do balladLadder = balladLadder + 1 end
T.truthy(balladLadder > 0, 'ballas tem escada antes de criar a gang nova')
local stillThere = 0
for _ in pairs(NoirGangs.ranksOf('ballas')) do stillThere = stillThere + 1 end
T.equal(stillThere, balladLadder, 'e a escada das outras gangs ficou intacta')

-- Criar já semeia a escada do arquétipo escolhido, senão a gang nasce sem porta de entrada.
T.equal(NoirGangs.topLevel('nova_gang'), 5, 'o arquétipo mc deu seis cargos')
T.equal(NoirGangs.rank('nova_gang', 0).label, 'Prospect', 'com os rótulos dele')
T.truthy(NoirGangs.bossRank('nova_gang'), 'e com chefe')
T.truthy(NoirGangs.can('nova_gang', 5, 'manage_ranks'), 'que já gere os cargos')

created, err = NoirGangs.createGang('nova_gang', 'Outra', 'gueto', 'roxo')
T.falsy(created, 'identificador repetido é recusado')
T.equal(err, 'name_taken', 'com o motivo certo')

T.equal(select(2, NoirGangs.createGang('outra', '', 'gueto', 'roxo')), 'invalid_label', 'rótulo vazio não passa')
T.equal(select(2, NoirGangs.createGang('outra', 'Outra', 'inexistente', 'roxo')), 'invalid_archetype', 'arquétipo fora do catálogo não passa')
T.equal(select(2, NoirGangs.createGang('outra', 'Outra', 'gueto', 'turquesa')), 'invalid_color', 'cor fora da paleta não passa')

-- Editar: rótulo e cor sempre; arquétipo só com a gang vazia, porque trocá-lo reescreve a
-- escada e moveria quem está dentro para um nível que talvez não exista.
T.truthy(NoirGangs.updateGang('nova_gang', { label = 'Renomeada', color = 'rosa', archetype = 'mc' }),
    'rótulo e cor mudam')
T.equal(NoirGangs.gangInfo('nova_gang').label, 'Renomeada', 'o rótulo novo fica')
T.equal(NoirGangs.gangList()[1] ~= nil, true, 'e a lista pública reflete o registro')

T.truthy(NoirGangs.updateGang('nova_gang', { label = 'Renomeada', color = 'rosa', archetype = 'gueto' }),
    'gang vazia troca de arquétipo')
T.equal(NoirGangs.topLevel('nova_gang'), 3, 'e a escada é reescrita')

NoirGangs.setMember('NOVATO', 'nova_gang', 0)
local ok, updateErr, members = NoirGangs.updateGang('nova_gang', { label = 'Renomeada', color = 'rosa', archetype = 'mc' })
T.falsy(ok, 'com gente dentro, o arquétipo não muda')
T.equal(updateErr, 'gang_occupied', 'e o motivo é a ocupação')
T.equal(members, 1, 'dizendo quantas pessoas estão lá')
T.equal(NoirGangs.topLevel('nova_gang'), 3, 'a escada ficou como estava')

T.truthy(NoirGangs.updateGang('nova_gang', { label = 'Com Gente', color = 'verde' }),
    'mas rótulo e cor continuam editáveis')
NoirGangs.removeMember('NOVATO')

T.equal(select(2, NoirGangs.updateGang('nao_existe', { label = 'X', color = 'roxo' })), 'gang_not_found',
    'gang desconhecida é recusada')

-- Cor: sempre hexadecimal, inclusive para quem não está no registro.
T.equal(NoirGangs.gangColor('nova_gang'), '#72CC72', 'a cor sai em hexadecimal')
T.equal(NoirGangs.gangColor('nao_existe'), NoirGangs.gangColor('__qualquer__'), 'gang desconhecida cai no padrão')

-- Cor livre --------------------------------------------------------------------------------
-- Além da paleta, a cor pode ser escolhida a dedo. Livre, mas não invisível: a tela e o mapa
-- são quase pretos, e o piso de contraste é o que impede uma gang de sumir dentro deles.
T.equal(NoirGangs.normalizeColor('roxo'), 'roxo', 'nome da paleta passa como está')
T.equal(NoirGangs.normalizeColor('#ff8800'), '#FF8800', 'hexadecimal é canonizado em maiúsculo')

for _, bad in ipairs({ 'ff8800', '#ff88', '#gggggg', 'turquesa', 42, '' }) do
    T.falsy(NoirGangs.normalizeColor(bad), ('cor malformada recusada: %s'):format(tostring(bad)))
end

-- O piso é o contraste do WCAG para objeto gráfico, medido contra o fundo do mapa.
local dark, darkErr = NoirGangs.normalizeColor('#101014')
T.falsy(dark, 'preto sobre preto não passa')
T.equal(darkErr, 'color_too_dark', 'e o motivo diz que é escuro demais, não malformado')
T.falsy(NoirGangs.normalizeColor('#000000'), 'nem o preto puro')
T.truthy(NoirGangs.normalizeColor('#FFFFFF'), 'branco passa')

-- Toda cor da paleta precisa passar pela própria régua, senão o config entregaria de fábrica
-- uma cor que o editor recusaria.
for name, color in pairs(Config.Colors) do
    T.truthy(NoirGangs.colorContrast(color.r, color.g, color.b) >= Config.CustomColor.minContrast,
        ('a cor %s da paleta não alcança o próprio piso de contraste'):format(name))
end

-- E a cor livre atravessa a criação e a leitura inteiras.
T.truthy(NoirGangs.createGang('livre', 'Cor Livre', 'gueto', '#00e5ff'), 'gang com cor livre é criada')
T.equal(NoirGangs.gangInfo('livre').color, '#00E5FF', 'guardada já canônica')
T.equal(NoirGangs.gangColor('livre'), '#00E5FF', 'e devolvida em hexadecimal')

T.equal(select(2, NoirGangs.createGang('escura', 'Escura', 'gueto', '#0a0a0c')), 'color_too_dark',
    'criar com cor invisível é recusado')
T.equal(select(2, NoirGangs.updateGang('livre', { label = 'Cor Livre', color = '#050505' })), 'color_too_dark',
    'editar para uma cor invisível também')

print('state_spec: ok')
