-- Exercita server/state.lua contra um banco em memória: schema, validação do config,
-- seed dos cargos a partir do arquétipo, publicação do rótulo no provider, permissão por
-- cargo, produtos e os limites da reputação.
local T = dofile('tests/testlib.lua')

function vec3(x, y, z) return { x = x, y = y, z = z } end
dofile('shared/config.lua')

-- Banco em memória ---------------------------------------------------------------------
local tables = { noir_gang_ranks = {}, noir_gang_products = {}, noir_gang_state = {} }
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
    if query:find('INSERT IGNORE INTO noir_gang_state', 1, true) then
        local id = values[1]
        if not tables.noir_gang_state[id] then
            tables.noir_gang_state[id] = { gang_name = id, reputation = 0, archetype = values[2] }
        end
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
    transaction = { await = function(writes)
        for i = 1, #writes do execute(writes[i].query, writes[i].values) end
        return true
    end },
}

-- Provider stubado ---------------------------------------------------------------------
local published = {}
local core = {}
function core:GetGangList()
    return { { name = 'ballas', label = 'Ballas' }, { name = 'lostmc', label = 'The Lost MC' },
        { name = 'semconfig', label = 'Sem Config' } }
end
function core:UpsertGangGrade(gangName, level, data)
    published[#published + 1] = { gang = gangName, level = level, label = data.label, isBoss = data.isBoss }
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

dofile('server/state.lua')

-- Schema ---------------------------------------------------------------------------------
T.truthy(NoirGangs.bootstrap(), 'bootstrap completo: ' .. (errors[1] or ''))
T.equal(#schemaStatements, 5, 'as cinco tabelas saem do migrations/.sql')

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

-- Gang que existe no Qbox mas não está no config cai no fallback, sem quebrar.
T.equal(NoirGangs.topLevel('semconfig'), 3, 'gang fora do config recebe o arquétipo padrão')
T.equal(#NoirGangs.productsOf('semconfig'), 0, 'e fica sem produto')

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

-- Publicação do rótulo no provider ------------------------------------------------------------
-- Sem isto, `/gang` e qualquer resource de terceiro mostram o nome antigo, e o
-- AddPlayerToGang recusa um nível que só exista aqui.
local publishedTop
for i = 1, #published do
    if published[i].gang == 'lostmc' and published[i].level == 5 then publishedTop = published[i] end
end
T.truthy(publishedTop, 'o cargo novo do MC foi publicado no provider')
T.equal(publishedTop.label, 'President', 'com o rótulo da nossa tabela')

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

print('state_spec: ok')
