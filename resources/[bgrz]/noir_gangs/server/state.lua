-- Os três atributos que o Qbox não tem: reputação, cargos com permissão e produtos.
-- Nada aqui precisa do framework, exceto publicar o RÓTULO do cargo — que é o único
-- campo que o resto do servidor lê de fora (`PlayerData.gang.grade.name`).
NoirGangs = NoirGangs or {}

local core = exports.bgrz_core

-- Cache em memória. Tudo aqui é lido a cada menu aberto e a cada checagem de permissão,
-- e muda raramente: seed no start, e depois só por ação de admin.
local ranks = {}       -- gangName -> { [level] = { level, label, isBoss, bankAuth, permissions = set } }
local products = {}    -- gangName -> { [productType] = true }
local reputation = {}  -- gangName -> integer

local permissionSet = {}
for i = 1, #Config.Permissions do permissionSet[Config.Permissions[i]] = true end

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------
-- Só DDL idempotente e não destrutivo passa. `DROP`, `MODIFY` e `RENAME` ficam de fora
-- de propósito: o arquivo roda a cada start, então nada aqui pode apagar dado.
local ALLOWED_STATEMENTS = {
    '^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+',
    '^CREATE%s+INDEX%s+IF%s+NOT%s+EXISTS%s+',
    '^ALTER%s+TABLE%s+[%w_`]+%s+ADD%s+COLUMN%s+IF%s+NOT%s+EXISTS%s+',
}

local function isAllowedStatement(statement)
    local upper = statement:upper()
    for i = 1, #ALLOWED_STATEMENTS do
        if upper:match(ALLOWED_STATEMENTS[i]) then return true end
    end
    return false
end

---@return boolean ok
function NoirGangs.runSchema()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/noir_gangs.sql')
    if not sql or sql == '' then
        lib.print.error('[noir_gangs] migrations/noir_gangs.sql não encontrado')
        return false
    end

    -- Tira comentários antes de separar por `;`, senão um ponto e vírgula dentro de
    -- comentário vira o começo de um statement falso.
    sql = sql:gsub('%-%-[^\r\n]*', '')

    local executed = 0
    for rawStatement in sql:gmatch('([^;]+);') do
        local statement = rawStatement:gsub('^%s*(.-)%s*$', '%1')
        if statement ~= '' then
            if not isAllowedStatement(statement) then
                lib.print.error(('[noir_gangs] statement recusado: %s'):format(statement:sub(1, 80)))
                return false
            end
            MySQL.query.await(statement)
            executed = executed + 1
        end
    end

    if executed == 0 then
        lib.print.error('[noir_gangs] migrations/noir_gangs.sql não tem statements')
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Validação do config
-- ---------------------------------------------------------------------------
-- Permissão com erro de digitação falha em silêncio: nunca é verdadeira, e ninguém
-- descobre até precisar dela. Então um nome fora do catálogo derruba o start.
---@return boolean ok
function NoirGangs.validateConfig()
    local ok = true

    for name, archetype in pairs(Config.RankArchetypes) do
        if type(archetype.ranks) ~= 'table' or #archetype.ranks == 0 then
            lib.print.error(('[noir_gangs] arquétipo %s não tem cargos'):format(name))
            ok = false
        end
        local seenLevel = {}
        for _, rank in ipairs(archetype.ranks or {}) do
            if type(rank.level) ~= 'number' or rank.level < 0 or rank.level % 1 ~= 0 then
                lib.print.error(('[noir_gangs] arquétipo %s tem nível inválido'):format(name))
                ok = false
            elseif seenLevel[rank.level] then
                lib.print.error(('[noir_gangs] arquétipo %s repete o nível %d'):format(name, rank.level))
                ok = false
            else
                seenLevel[rank.level] = true
            end
            if type(rank.label) ~= 'string' or rank.label == '' then
                lib.print.error(('[noir_gangs] arquétipo %s tem cargo sem rótulo'):format(name))
                ok = false
            end
            for _, permission in ipairs(rank.permissions or {}) do
                if not permissionSet[permission] then
                    lib.print.error(('[noir_gangs] arquétipo %s: permissão desconhecida "%s"'):format(name, permission))
                    ok = false
                end
            end
        end
    end

    if not Config.RankArchetypes[Config.FallbackArchetype] then
        lib.print.error(('[noir_gangs] FallbackArchetype "%s" não existe'):format(tostring(Config.FallbackArchetype)))
        ok = false
    end

    for gangName, definition in pairs(Config.Gangs) do
        if not Config.RankArchetypes[definition.archetype] then
            lib.print.error(('[noir_gangs] gang %s aponta para arquétipo inexistente "%s"')
                :format(gangName, tostring(definition.archetype)))
            ok = false
        end
        for _, product in ipairs(definition.products or {}) do
            if not Config.ProductTypes[product] then
                lib.print.error(('[noir_gangs] gang %s opera produto desconhecido "%s"'):format(gangName, product))
                ok = false
            end
        end
    end

    return ok
end

-- ---------------------------------------------------------------------------
-- Seed e carga
-- ---------------------------------------------------------------------------
local function archetypeFor(gangName)
    local definition = Config.Gangs[gangName]
    local name = definition and definition.archetype or Config.FallbackArchetype
    return name, Config.RankArchetypes[name]
end

---Escreve os cargos do arquétipo no banco e publica os rótulos no Qbox. Níveis que o
---arquétipo não tem são removidos daqui, mas nunca do Qbox: alguém pode estar ocupando o
---cargo, e tirá-lo de lá deixaria o personagem com um nível que o provider recusa.
local function seedRanks(gangName)
    local archetypeName, archetype = archetypeFor(gangName)
    if not archetype then return end

    local writes, levels = {}, {}
    for _, rank in ipairs(archetype.ranks) do
        levels[#levels + 1] = rank.level
        writes[#writes + 1] = {
            query = 'INSERT INTO noir_gang_ranks (gang_name, level, label, is_boss, bank_auth, permissions) VALUES (?, ?, ?, ?, ?, ?) '
                .. 'ON DUPLICATE KEY UPDATE label = VALUES(label), is_boss = VALUES(is_boss), bank_auth = VALUES(bank_auth), permissions = VALUES(permissions)',
            values = { gangName, rank.level, rank.label, rank.isBoss and 1 or 0, rank.bankAuth and 1 or 0,
                json.encode(rank.permissions or {}) },
        }
    end

    local placeholders = ('?, '):rep(#levels - 1) .. '?'
    writes[#writes + 1] = {
        query = ('DELETE FROM noir_gang_ranks WHERE gang_name = ? AND level NOT IN (%s)'):format(placeholders),
        values = { gangName, table.unpack(levels) },
    }
    MySQL.transaction.await(writes)

    MySQL.update.await('UPDATE noir_gang_state SET archetype = ? WHERE gang_name = ?', { archetypeName, gangName })
end

local function seedProducts(gangName)
    local definition = Config.Gangs[gangName]
    local list = definition and definition.products or {}

    local writes = { { query = 'DELETE FROM noir_gang_products WHERE gang_name = ?', values = { gangName } } }
    for _, product in ipairs(list) do
        writes[#writes + 1] = {
            query = 'INSERT IGNORE INTO noir_gang_products (gang_name, product_type) VALUES (?, ?)',
            values = { gangName, product },
        }
    end
    MySQL.transaction.await(writes)
end

local function loadRanks()
    ranks = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM noir_gang_ranks') or {}) do
        local permissions = row.permissions
        if type(permissions) == 'string' then permissions = json.decode(permissions) end

        local set = {}
        for _, permission in ipairs(permissions or {}) do set[permission] = true end

        ranks[row.gang_name] = ranks[row.gang_name] or {}
        ranks[row.gang_name][row.level] = { level = row.level, label = row.label,
            isBoss = row.is_boss == 1, bankAuth = row.bank_auth == 1, permissions = set }
    end
end

local function loadProducts()
    products = {}
    for _, row in ipairs(MySQL.query.await('SELECT gang_name, product_type FROM noir_gang_products') or {}) do
        products[row.gang_name] = products[row.gang_name] or {}
        products[row.gang_name][row.product_type] = true
    end
end

local function loadReputation()
    reputation = {}
    for _, row in ipairs(MySQL.query.await('SELECT gang_name, reputation FROM noir_gang_state') or {}) do
        reputation[row.gang_name] = row.reputation
    end
end

---Publica no Qbox o rótulo de cada cargo que conhecemos. Sem isto, `/gang` e qualquer
---resource de terceiro mostram o nome antigo de shared/gangs.lua, e `AddPlayerToGang`
---recusa um nível que só exista aqui.
local function publishRanksToProvider()
    for gangName, levels in pairs(ranks) do
        for level, rank in pairs(levels) do
            local ok, err = core:UpsertGangGrade(gangName, level, rank)
            if not ok then
                lib.print.error(('[noir_gangs] não publiquei %s cargo %d: %s'):format(gangName, level, tostring(err)))
            end
        end
    end
end

---@return boolean ok
function NoirGangs.bootstrap()
    if not NoirGangs.validateConfig() then return false end
    if not NoirGangs.runSchema() then return false end

    -- Toda gang que o Qbox conhece ganha linha de estado, inclusive as que não estão no
    -- config: sem a linha, a reputação não teria onde crescer.
    for _, gang in ipairs(core:GetGangList()) do
        MySQL.query.await('INSERT IGNORE INTO noir_gang_state (gang_name, archetype) VALUES (?, ?)',
            { gang.name, (archetypeFor(gang.name)) })
        if Config.RanksFromConfig then
            seedRanks(gang.name)
            seedProducts(gang.name)
        end
    end

    loadRanks()
    loadProducts()
    loadReputation()
    publishRanksToProvider()

    lib.print.info(('[noir_gangs] %d gangs carregadas'):format(#core:GetGangList()))
    return true
end

-- ---------------------------------------------------------------------------
-- Leitura
-- ---------------------------------------------------------------------------
---@return table|nil rank { level, label, isBoss, bankAuth, permissions }
function NoirGangs.rank(gangName, level)
    return ranks[gangName] and ranks[gangName][level] or nil
end

---@return table<integer, table> cargos da gang, por nível
function NoirGangs.ranksOf(gangName)
    return ranks[gangName] or {}
end

---Maior nível que a gang tem. É quem lidera.
---@return integer
function NoirGangs.topLevel(gangName)
    local top
    for level in pairs(ranks[gangName] or {}) do
        if not top or level > top then top = level end
    end
    return top or 0
end

---Nível imediatamente acima/abaixo entre os que existem. Os cargos não precisam ser
---contíguos, então somar 1 erraria o alvo.
---@return integer|nil
function NoirGangs.levelAbove(gangName, level)
    local best
    for candidate in pairs(ranks[gangName] or {}) do
        if candidate > level and (not best or candidate < best) then best = candidate end
    end
    return best
end

---@return integer|nil
function NoirGangs.levelBelow(gangName, level)
    local best
    for candidate in pairs(ranks[gangName] or {}) do
        if candidate < level and (not best or candidate > best) then best = candidate end
    end
    return best
end

---@return boolean
function NoirGangs.can(gangName, level, permission)
    local rank = NoirGangs.rank(gangName, level)
    return rank ~= nil and rank.permissions[permission] == true
end

---@return string[] produtos da gang, ordenados
function NoirGangs.productsOf(gangName)
    local list = {}
    for product in pairs(products[gangName] or {}) do list[#list + 1] = product end
    table.sort(list)
    return list
end

---@return boolean
function NoirGangs.hasProduct(gangName, productType)
    return products[gangName] ~= nil and products[gangName][productType] == true
end

---@return integer
function NoirGangs.reputationOf(gangName)
    return reputation[gangName] or 0
end

-- ---------------------------------------------------------------------------
-- Escrita
-- ---------------------------------------------------------------------------
---Soma (ou subtrai) reputação, com o total preso entre `Config.Reputation.min/max`.
---@param gangName string
---@param delta integer
---@return integer|nil novoTotal
---@return string? errorCode
function NoirGangs.addReputation(gangName, delta)
    if type(gangName) ~= 'string' or gangName == '' or gangName == 'none' then return nil, 'invalid_gang' end
    if reputation[gangName] == nil then return nil, 'gang_not_found' end

    delta = tonumber(delta)
    if not delta or delta ~= delta or delta % 1 ~= 0 or delta == 0 then return nil, 'invalid_delta' end
    if math.abs(delta) > Config.Reputation.maxDelta then return nil, 'delta_too_large' end

    local current = reputation[gangName]
    local updated = math.max(Config.Reputation.min, math.min(Config.Reputation.max, current + delta))
    if updated == current then return current, 'at_limit' end

    MySQL.update.await('UPDATE noir_gang_state SET reputation = ? WHERE gang_name = ?', { updated, gangName })
    reputation[gangName] = updated
    return updated
end
