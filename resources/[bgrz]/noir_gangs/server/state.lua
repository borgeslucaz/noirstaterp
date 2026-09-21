-- Os três atributos que o Qbox não tem: reputação, cargos com permissão e produtos.
-- Nada aqui precisa do framework, exceto publicar o RÓTULO do cargo — que é o único
-- campo que o resto do servidor lê de fora (`PlayerData.gang.grade.name`).
NoirGangs = NoirGangs or {}

local core = exports.bgrz_core

-- Cache em memória. Tudo aqui é lido a cada menu aberto e a cada checagem de permissão,
-- e muda raramente: seed no start, e depois só por ação de admin.
local registry = {}    -- gangName -> { name, label, color, archetype }
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
-- Registro de gangs
-- ---------------------------------------------------------------------------
-- Quais gangs existem é dado nosso, em `noir_gang_state`. O Qbox recebe a lista a cada
-- start e monta com ela o dicionário que o resto do servidor lê em `PlayerData.gang` —
-- rótulo, cargo, `isboss` e `bankAuth` saem de lá, não da linha do personagem.
--
-- Isso traz uma obrigação: a lista precisa estar registrada ANTES de qualquer personagem
-- carregar. O login que não encontra a gang no dicionário descarta a gang da pessoa em
-- silêncio, com um aviso no console e nada mais. É por isso que o registro acontece no
-- começo do bootstrap, e por isso que o `server/main.lua` reregistra quando o provider
-- reinicia sozinho.

---Nome cru vira rótulo legível, para uma linha antiga que ainda não tem rótulo gravado.
local function prettyName(name)
    return (tostring(name):gsub('_', ' '):gsub('(%a)([%w]*)', function(first, rest)
        return first:upper() .. rest
    end))
end

---`TINYINT(1)` não tem uma representação só do lado do Lua: dependendo do driver e da
---versão, o mesmo `1` chega como número, como `true` ou como string. Comparar com `1` puro
---acerta numa e falha em silêncio nas outras.
---
---O caso mais caro é o `is_boss`: errar ali é gang sem chefe, com a chefia deixando de ser
---intocável e o editor de cargos sem aparecer para ninguém. O `products_seeded` erra mais
---barato — reescreveria a lista de produtos no start —, mas erra pelo mesmo motivo. Por
---isso a conversão acontece num lugar só, na fronteira em que a linha entra na memória.
local function truthy(value)
    return value == true or value == 1 or value == '1'
end

local function loadRegistry()
    registry = {}
    for _, row in ipairs(MySQL.query.await(
        'SELECT gang_name, label, color, archetype, products_seeded FROM noir_gang_state') or {}) do
        local label = row.label
        if type(label) ~= 'string' or label == '' then label = prettyName(row.gang_name) end

        registry[row.gang_name] = {
            name = row.gang_name,
            label = label,
            -- Cor e arquétipo desconhecidos caem no padrão em vez de derrubar o start: a
            -- linha pode ter vindo de uma versão que tinha outra paleta. Cor livre é
            -- aceita como está: a régua de contraste valeu na hora de gravar.
            color = (Config.Colors[row.color] or (type(row.color) == 'string' and row.color:match('^#%x%x%x%x%x%x$')))
                and row.color or Config.FallbackColor,
            archetype = Config.RankArchetypes[row.archetype] and row.archetype or Config.FallbackArchetype,
            productsSeeded = truthy(row.products_seeded),
        }
    end
end

---O config semeia a gang que ainda não está no banco, e preenche rótulo e cor de linhas
---antigas — elas nasceram quando `noir_gang_state` só guardava reputação.
local function seedRegistry()
    for name, definition in pairs(Config.Gangs) do
        local label = definition.label or prettyName(name)
        local color = Config.Colors[definition.color] and definition.color or Config.FallbackColor

        MySQL.query.await(
            'INSERT IGNORE INTO noir_gang_state (gang_name, label, color, archetype) VALUES (?, ?, ?, ?)',
            { name, label, color, definition.archetype or Config.FallbackArchetype })
        MySQL.query.await("UPDATE noir_gang_state SET label = ? WHERE gang_name = ? AND label = ''", { label, name })
        MySQL.query.await("UPDATE noir_gang_state SET color = ? WHERE gang_name = ? AND color = ''", { color, name })
    end
end

-- As gangs NÃO são mais publicadas no Qbox.
--
-- Enquanto eram, o mesmo dado vivia nos dois lados: a escada aqui e uma cópia lá, a
-- membresia aqui e `player_groups` + `players.gang` lá. O Qbox rebaixava jogador sozinho a
-- cada republicação, e o login relia a cópia errada. Agora `shared/gangs.lua` não é mais
-- espelho de nada -- o dono da gang é este resource, ponto.
--
-- O que sumiu junto: `publishGangsToProvider`, `publishGang`, `commitGangsToFile`,
-- `publishRanksOf`, `publishRanksToProvider` e `republishToProvider`.

---@return { name: string, label: string, color: string, archetype: string }[]
function NoirGangs.gangList()
    local list = {}
    for _, gang in pairs(registry) do
        list[#list + 1] = { name = gang.name, label = gang.label, color = gang.color, archetype = gang.archetype }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

---@return table|nil { name, label, color, archetype }
function NoirGangs.gangInfo(gangName)
    return registry[gangName]
end

-- ---------------------------------------------------------------------------
-- Cor
-- ---------------------------------------------------------------------------
-- A cor é guardada de duas formas: o nome de uma da paleta, ou `#RRGGBB` quando foi
-- escolhida livremente. O nome é preferível quando serve — mudar a paleta no config
-- repinta todas as gangs que a usam — e o hexadecimal existe para o que a paleta não cobre.

---@return integer r, integer g, integer b
local function hexToRgb(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

---Luminância relativa do WCAG. A curva não é linear de propósito: o olho não enxerga o
---dobro de brilho quando o valor dobra.
local function channelLuminance(value)
    local c = value / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(r, g, b)
    return 0.2126 * channelLuminance(r) + 0.7152 * channelLuminance(g) + 0.0722 * channelLuminance(b)
end

---Contraste entre a cor e a superfície mais escura em que ela aparece.
---@return number razão, de 1 (invisível) para cima
function NoirGangs.colorContrast(r, g, b)
    local against = Config.CustomColor.against
    local a = luminance(r, g, b) + 0.05
    local other = luminance(against.r, against.g, against.b) + 0.05
    if a < other then a, other = other, a end
    return a / other
end

---Aceita nome da paleta ou `#RRGGBB`. Devolve o valor já canônico, para o banco não guardar
---`#abc123` numa linha e `#ABC123` na outra.
---@return string|nil valor
---@return string? errorCode
function NoirGangs.normalizeColor(value)
    if type(value) ~= 'string' then return nil, 'invalid_color' end
    if Config.Colors[value] then return value end

    local hex = value:upper()
    if not hex:match('^#%x%x%x%x%x%x$') then return nil, 'invalid_color' end

    if NoirGangs.colorContrast(hexToRgb(hex)) < Config.CustomColor.minContrast then
        return nil, 'color_too_dark'
    end
    return hex
end

---A cor em hexadecimal, que é o formato que qualquer tela usa.
---@return string
function NoirGangs.gangColor(gangName)
    local entry = registry[gangName]
    local value = entry and entry.color

    if type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') then return value end

    local color = Config.Colors[value] or Config.Colors[Config.FallbackColor]
    return ('#%02X%02X%02X'):format(color.r, color.g, color.b)
end

-- ---------------------------------------------------------------------------
-- Seed e carga
-- ---------------------------------------------------------------------------
---O arquétipo sai do registro, que é o banco. O config só participa quando a gang ainda
---não existe lá — ele é semente, não verdade.
local function archetypeFor(gangName)
    local entry = registry[gangName]
    local name = entry and entry.archetype
    if not name or not Config.RankArchetypes[name] then name = Config.FallbackArchetype end
    return name, Config.RankArchetypes[name]
end

---Escreve os cargos do arquétipo no banco e publica os rótulos no Qbox. Níveis que o
---arquétipo não tem são removidos daqui, mas nunca do Qbox: alguém pode estar ocupando o
---cargo, e tirá-lo de lá deixaria o personagem com um nível que o provider recusa.
---
---Com `Config.RanksFromConfig = false` isto roda uma vez só por gang, quando ela ainda não
---tem cargo nenhum: daí em diante quem manda é o editor em jogo.
local function seedRanks(gangName)
    local archetypeName, archetype = archetypeFor(gangName)
    if not archetype then return end

    local writes, levels = {}, {}
    for _, rank in ipairs(archetype.ranks) do
        levels[#levels + 1] = rank.level
        writes[#writes + 1] = {
            -- A semente usa `level` como posição inicial porque no arquétipo os dois
            -- ainda coincidem: a escada nasce contígua. Daí em diante elas andam
            -- separadas, e `sort_order` não é reescrito por semeadura nenhuma.
            query = 'INSERT INTO noir_gang_ranks (gang_name, level, label, is_boss, bank_auth, permissions, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?) '
                .. 'ON DUPLICATE KEY UPDATE label = VALUES(label), is_boss = VALUES(is_boss), bank_auth = VALUES(bank_auth), permissions = VALUES(permissions)',
            values = { gangName, rank.level, rank.label, rank.isBoss and 1 or 0, rank.bankAuth and 1 or 0,
                json.encode(rank.permissions or {}), rank.level },
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

---Marca que o config já semeou esta gang. É o que separa "nunca foi semeada" de "foi
---esvaziada de propósito pelo editor": sem a marca, tirar o último produto em jogo seria
---desfeito pelo seed do start seguinte, e ninguém entenderia por quê.
local function markProductsSeeded(gangName)
    MySQL.update.await('UPDATE noir_gang_state SET products_seeded = 1 WHERE gang_name = ?', { gangName })
    if registry[gangName] then registry[gangName].productsSeeded = true end
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
    markProductsSeeded(gangName)
end

local function loadRanks()
    ranks = {}
    local backfill = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM noir_gang_ranks') or {}) do
        local permissions = row.permissions
        if type(permissions) == 'string' then permissions = json.decode(permissions) end

        local set = {}
        for _, permission in ipairs(permissions or {}) do set[permission] = true end

        local level = tonumber(row.level)

        -- `sort_order` -1 é linha gravada antes da coluna existir. Assumir `level` preserva
        -- exatamente a ordem que a gang já mostrava, e a gravação abaixo faz isso valer só
        -- uma vez -- no start seguinte a coluna já tem valor próprio.
        local sortOrder = tonumber(row.sort_order)
        if not sortOrder or sortOrder < 0 then
            sortOrder = level
            backfill[#backfill + 1] = { query = 'UPDATE noir_gang_ranks SET sort_order = ? '
                .. 'WHERE gang_name = ? AND level = ?', values = { sortOrder, row.gang_name, level } }
        end

        ranks[row.gang_name] = ranks[row.gang_name] or {}
        ranks[row.gang_name][level] = { level = level, sortOrder = sortOrder, label = row.label,
            isBoss = truthy(row.is_boss), bankAuth = truthy(row.bank_auth), permissions = set }
    end

    if #backfill > 0 then MySQL.transaction.await(backfill) end
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

---@return boolean ok
function NoirGangs.bootstrap()
    if not NoirGangs.validateConfig() then return false end
    if not NoirGangs.runSchema() then return false end

    -- O registro primeiro. `seedRanks` abaixo só escreve no banco -- não fala com o
    -- provider -- então a publicação pode (e precisa) esperar os cargos estarem carregados.
    seedRegistry()
    loadRegistry()

    for gangName in pairs(registry) do
        -- Cargos: o config reescreve sempre, ou semeia só a gang que ainda não tem nenhum.
        -- A segunda forma é o que permite editar em jogo sem perder tudo no restart.
        local existing = MySQL.scalar.await('SELECT COUNT(*) FROM noir_gang_ranks WHERE gang_name = ?',
            { gangName }) or 0
        if Config.RanksFromConfig or existing == 0 then seedRanks(gangName) end

        -- Produtos seguem o mesmo acordo dos cargos desde que o editor existe: o config é
        -- semente, não dono. Gang do config que nunca foi semeada recebe a lista de lá;
        -- depois disso, quem manda é o que foi editado em jogo. `ProductsFromConfig`
        -- devolve o comportamento antigo, de reescrever tudo a cada start.
        if Config.Gangs[gangName] and (Config.ProductsFromConfig or not registry[gangName].productsSeeded) then
            seedProducts(gangName)
        end
    end

    loadRanks()
    NoirGangs.loadMembers()

    NoirGangs.repairBossRanks()
    loadProducts()
    loadReputation()

    lib.print.info(('[noir_gangs] %d gangs carregadas'):format(#NoirGangs.gangList()))
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

---Escada da gang, do cargo mais baixo ao mais alto, por POSIÇÃO.
---
---A escada é `sort_order`, nunca `level`. `level` é só identidade -- depois que um cargo
---nasce, o número dele não muda mais, e por isso não diz nada sobre quem está acima de
---quem. Confundir os dois é o que obrigava a renumerar cargos, e renumerar cargo significa
---mover membro de nível nos dois lados do Qbox.
---@return table[] ranks
function NoirGangs.ladder(gangName)
    local ordered = {}
    for _, rank in pairs(ranks[gangName] or {}) do ordered[#ordered + 1] = rank end
    table.sort(ordered, function(a, b)
        if a.sortOrder == b.sortOrder then return a.level < b.level end
        return a.sortOrder < b.sortOrder
    end)
    return ordered
end

---Nível do cargo mais alto da escada. É quem lidera.
---@return integer
function NoirGangs.topLevel(gangName)
    local ordered = NoirGangs.ladder(gangName)
    local top = ordered[#ordered]
    return top and top.level or 0
end

---Nível do cargo imediatamente acima/abaixo na escada.
---
---Antes isto era aritmética sobre `level`; agora é um passo na ordem de exibição. Para
---quem usa, o comportamento é o mesmo -- promover continua sendo "o próximo degrau".
---@return integer|nil
function NoirGangs.levelAbove(gangName, level)
    local ordered = NoirGangs.ladder(gangName)
    for i = 1, #ordered do
        if ordered[i].level == level then return ordered[i + 1] and ordered[i + 1].level end
    end
end

---@return integer|nil
function NoirGangs.levelBelow(gangName, level)
    local ordered = NoirGangs.ladder(gangName)
    for i = 1, #ordered do
        if ordered[i].level == level then return ordered[i - 1] and ordered[i - 1].level end
    end
end

---O cargo de chefe da gang, se existir. É ele que define o topo da escada e o que o
---editor não pode encostar.
---@return table|nil rank
function NoirGangs.bossRank(gangName)
    for _, rank in pairs(ranks[gangName] or {}) do
        if rank.isBoss then return rank end
    end
end

---Menor nível que existe de verdade. É a porta de entrada de quem aceita um convite —
---antes era a constante `Config.DefaultGrade`, o que quebraria no dia em que o editor
---apagasse o cargo mais baixo.
---@return integer|nil
function NoirGangs.bottomLevel(gangName)
    local bottom = NoirGangs.ladder(gangName)[1]
    return bottom and bottom.level
end

---@return integer total, integer semChefe
function NoirGangs.rankCount(gangName)
    local total, plain = 0, 0
    for _, rank in pairs(ranks[gangName] or {}) do
        total = total + 1
        if not rank.isBoss then plain = plain + 1 end
    end
    return total, plain
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
---Grava a lista inteira de produtos de uma gang: o editor manda o estado final, e não a
---diferença, porque a tela mostra caixas marcadas e é isso que ela sabe dizer.
---@param list string[]
---@return boolean ok
---@return string? errorCode
function NoirGangs.setProducts(gangName, list)
    if not registry[gangName] then return false, 'gang_not_found' end
    if type(list) ~= 'table' then return false, 'invalid_product' end

    local set, wanted = {}, {}
    for i = 1, #list do
        local product = list[i]
        if type(product) ~= 'string' or not Config.ProductTypes[product] then return false, 'invalid_product' end
        if not set[product] then
            set[product] = true
            wanted[#wanted + 1] = product
        end
    end

    local writes = { { query = 'DELETE FROM noir_gang_products WHERE gang_name = ?', values = { gangName } } }
    for i = 1, #wanted do
        writes[#writes + 1] = {
            query = 'INSERT INTO noir_gang_products (gang_name, product_type) VALUES (?, ?)',
            values = { gangName, wanted[i] },
        }
    end
    MySQL.transaction.await(writes)

    products[gangName] = set
    -- Lista vazia também é escolha, e o seed do próximo start não pode desfazê-la.
    markProductsSeeded(gangName)
    return true
end

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

-- ---------------------------------------------------------------------------
-- Cargos: escrita
-- ---------------------------------------------------------------------------
-- O editor em jogo mexe em três coisas do cargo: rótulo, permissões e acesso ao banco.
-- Nível e `isBoss` ficam de fora, e não por falta de tempo:
--
-- * `isBoss` é o que torna o chefe intocável. Se o editor pudesse desmarcá-lo, qualquer um
--   com `manage_ranks` desligaria o chefe em dois passos — exatamente o caminho de jogador
--   para tomar a liderança que o resource inteiro existe para não ter.
-- * mudar o nível de um cargo é mover todo mundo que está nele. O único movimento que
--   acontece aqui é o do chefe subindo um degrau para abrir espaço, e ele é compensado se
--   falhar no meio.
--
-- Rótulo e `bankAuth` viajam para o Qbox, porque `PlayerData.gang.grade.name` é o que o
-- resto do servidor lê e o Renewed-Banking decide o acesso ao dinheiro por `bankAuth`.
-- Permissões não viajam: o provider não tem conceito delas.

local function normalizeLabel(label)
    if type(label) ~= 'string' then return nil end
    label = label:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if label == '' or #label > Config.Ranks.labelMaxLength then return nil end
    return label
end

---Só o que está no catálogo entra, sem repetição e em ordem estável. Permissão inventada
---não estoura: ela simplesmente não existiria, e o cargo ficaria sem ela em silêncio.
---@return string[]|nil
local function normalizePermissions(list)
    if list ~= nil and type(list) ~= 'table' then return nil end

    local wanted = {}
    for _, permission in ipairs(list or {}) do
        if type(permission) ~= 'string' or not permissionSet[permission] then return nil end
        wanted[permission] = true
    end

    local ordered = {}
    for i = 1, #Config.Permissions do
        if wanted[Config.Permissions[i]] then ordered[#ordered + 1] = Config.Permissions[i] end
    end
    return ordered
end

---Grava o cargo, publica no provider e atualiza o cache na mesma ordem sempre, para não
---existir caminho em que um dos três fique para trás.
---@param sortOrder integer? nil preserva a posição atual do cargo
local function persistRank(gangName, level, label, isBoss, bankAuth, permissions, sortOrder)
    -- Editar um cargo não pode mexer na escada. Só quem cria informa posição; todo o
    -- resto herda a que o cargo já tinha.
    local current = ranks[gangName] and ranks[gangName][level]
    sortOrder = sortOrder or (current and current.sortOrder) or level

    MySQL.query.await(
        'INSERT INTO noir_gang_ranks (gang_name, level, label, is_boss, bank_auth, permissions, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE label = VALUES(label), is_boss = VALUES(is_boss), bank_auth = VALUES(bank_auth), permissions = VALUES(permissions), sort_order = VALUES(sort_order)',
        { gangName, level, label, isBoss and 1 or 0, bankAuth and 1 or 0, json.encode(permissions), sortOrder })

    local set = {}
    for _, permission in ipairs(permissions) do set[permission] = true end

    ranks[gangName] = ranks[gangName] or {}
    ranks[gangName][level] = { level = level, sortOrder = sortOrder, label = label, isBoss = isBoss == true,
        bankAuth = bankAuth == true, permissions = set }

    return ranks[gangName][level]
end

---Cria um cargo logo abaixo do chefe.
---
---Duas coisas acontecem aqui, e elas são independentes de propósito:
---
---  * o `level` é o próximo IDENTIFICADOR livre, sempre acima de todos os que já
---    existiram. Nunca reaproveita número de cargo apagado e nunca se intromete entre
---    dois cargos existentes;
---  * a POSIÇÃO é logo abaixo do chefe, empurrando o chefe uma casa para cima.
---
---A versão antiga fazia as duas com o mesmo número, e por isso abrir espaço abaixo do
---chefe exigia SUBIR O CHEFE DE NÍVEL -- o que obrigava a mover cada membro da chefia
---para outro grade, no `player_groups` e no `players.gang` do Qbox, com uma compensação
---manual caso falhasse no meio. Foi esse caminho que dessincronizou o vagos quando um
---cargo "TESTE" nasceu no nível 3.
---
---Empurrar `sort_order` é de graça: ninguém persiste contra essa coluna. Nenhum membro
---muda de cargo, e a função inteira deixou de precisar de rollback.
---@return integer|nil level
---@return string? errorCode
function NoirGangs.createRank(gangName, label)
    label = normalizeLabel(label)
    if not label then return nil, 'invalid_label' end

    local boss = NoirGangs.bossRank(gangName)
    if not boss then return nil, 'no_boss' end

    local total = NoirGangs.rankCount(gangName)
    if total >= Config.Ranks.max then return nil, 'rank_limit' end

    -- O próximo identificador sai do MAIOR nível já usado, não do maior que existe agora.
    --
    -- A diferença aparece quando um cargo é apagado: reaproveitar o número dele faria o
    -- histórico mentir, porque `noir_gang_activity` grava `oldGrade`/`newGrade` como
    -- números -- "promovido para o cargo 4" passaria a significar dois cargos diferentes
    -- em épocas diferentes.
    --
    -- A memória fica em `noir_gang_state.next_rank_level`. Antes vinha do provider, que
    -- nunca esquecia um grade publicado -- mas nada mais é publicado lá.
    local level = 0
    for existing in pairs(ranks[gangName] or {}) do
        if existing >= level then level = existing + 1 end
    end

    local watermark = tonumber(MySQL.scalar.await(
        'SELECT next_rank_level FROM noir_gang_state WHERE gang_name = ?', { gangName })) or 0
    if watermark > level then level = watermark end

    MySQL.update.await('UPDATE noir_gang_state SET next_rank_level = ? WHERE gang_name = ?',
        { level + 1, gangName })

    local sortOrder = boss.sortOrder
    MySQL.query.await('UPDATE noir_gang_ranks SET sort_order = sort_order + 1 '
        .. 'WHERE gang_name = ? AND sort_order >= ?', { gangName, sortOrder })
    for _, rank in pairs(ranks[gangName] or {}) do
        if rank.sortOrder >= sortOrder then rank.sortOrder = rank.sortOrder + 1 end
    end

    persistRank(gangName, level, label, false, false, {}, sortOrder)
    return level
end

---@param data table { label, permissions, bankAuth }
---@return boolean ok
---@return string? errorCode
function NoirGangs.updateRank(gangName, level, data)
    local rank = NoirGangs.rank(gangName, level)
    if not rank then return false, 'rank_not_found' end
    if rank.isBoss then return false, 'boss_protected' end
    if type(data) ~= 'table' then return false, 'invalid_label' end

    local label = normalizeLabel(data.label)
    if not label then return false, 'invalid_label' end

    local permissions = normalizePermissions(data.permissions)
    if not permissions then return false, 'invalid_permission' end

    persistRank(gangName, level, label, false, data.bankAuth == true, permissions)
    return true
end

---@return boolean ok
---@return string? errorCode
function NoirGangs.deleteRank(gangName, level)
    local rank = NoirGangs.rank(gangName, level)
    if not rank then return false, 'rank_not_found' end
    if rank.isBoss then return false, 'boss_protected' end

    -- Uma gang sem nenhum cargo comum não tem porta de entrada: quem aceitasse um convite
    -- entraria direto na chefia, ou em nível nenhum.
    local _, plain = NoirGangs.rankCount(gangName)
    if plain <= 1 then return false, 'last_rank' end

    -- Apagar um cargo ocupado deixaria essas pessoas num nível sem cargo: sem permissão
    -- nenhuma, sem rótulo, e sem promoção que as tire de lá. Quem move é gente, antes.
    local occupied = NoirGangs.countAtLevel(gangName, level)
    if occupied > 0 then return false, 'rank_occupied', occupied end

    MySQL.query.await('DELETE FROM noir_gang_ranks WHERE gang_name = ? AND level = ?', { gangName, level })
    ranks[gangName][level] = nil

    -- O grade continua existindo no Qbox de propósito: não há como removê-lo de lá sem
    -- arriscar deixar algum personagem num nível que o provider recusa. Ele fica órfão e
    -- inofensivo — ninguém está nele, e nada nosso aponta para ele.
    return true
end

---O cargo de chefe é o único que o editor não edita — e por isso é o único que ninguém
---conserta de dentro do jogo. Um chefe sem `manage_ranks` tranca a gang inteira fora do
---editor, para sempre, e a única saída seria mexer no banco à mão.
---
---É também por aqui que uma permissão nova chega a quem já tinha cargos gravados: com o
---config valendo só como semente, nada mais reescreve aquelas linhas. Roda a cada start,
---não faz nada quando já está certo, e não encosta em nenhum outro cargo.
---@return integer gangs corrigidas
function NoirGangs.repairBossRanks()
    local repaired = 0

    for gangName in pairs(ranks) do
        local boss = NoirGangs.bossRank(gangName)

        -- Gang sem chefe não é um estado que o resource saiba produzir: ou a linha foi
        -- editada à mão, ou o `is_boss` não está sendo lido. Nos dois casos a gang está com
        -- a chefia desprotegida, e ficar calado aqui foi o que fez o problema demorar a
        -- aparecer.
        if not boss then
            lib.print.error(('[noir_gangs] %s não tem cargo de chefe: a chefia está desprotegida e o editor de cargos não abre')
                :format(gangName))
        elseif not boss.permissions.manage_ranks then
            local permissions = {}
            for i = 1, #Config.Permissions do
                local permission = Config.Permissions[i]
                if boss.permissions[permission] or permission == 'manage_ranks' then
                    permissions[#permissions + 1] = permission
                end
            end

            persistRank(gangName, boss.level, boss.label, true, boss.bankAuth, permissions)
            lib.print.info(('[noir_gangs] %s: cargo de chefe (%s) recebeu manage_ranks')
                :format(gangName, boss.label))
            repaired = repaired + 1
        end
    end

    return repaired
end

-- ---------------------------------------------------------------------------
-- Registro de gangs: escrita
-- ---------------------------------------------------------------------------
-- O `name` é identidade: ele é o que vai para o `player_groups` do Qbox, e é por ele que
-- toda linha de personagem aponta para a gang. Por isso ele é normalizado na criação e
-- **nunca** muda depois — renomear deixaria órfã cada pessoa que já está dentro. O que se
-- edita é o rótulo, que é só apresentação.

---@return string|nil
local function normalizeGangName(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower():gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', '_')
    if name == '' or name == 'none' or #name > Config.Gang.nameMaxLength then return nil end
    -- Começa por letra e só aceita o que sobrevive a um identificador: o nome viaja para o
    -- provider, para o banco e para comandos de admin.
    if not name:match('^%a[%w_]*$') then return nil end
    return name
end

---@return string|nil
local function normalizeGangLabel(label)
    if type(label) ~= 'string' then return nil end
    label = label:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if label == '' or #label > Config.Gang.labelMaxLength then return nil end
    return label
end

---@return integer
local function memberCount(gangName)
    return #NoirGangs.membersOf(gangName)
end

---Cria a gang, registra no provider e semeia os cargos do arquétipo escolhido.
---@return string|nil gangName
---@return string? errorCode
function NoirGangs.createGang(name, label, archetype, color)
    name = normalizeGangName(name)
    if not name then return nil, 'invalid_name' end
    if registry[name] then return nil, 'name_taken' end

    label = normalizeGangLabel(label)
    if not label then return nil, 'invalid_label' end

    if not Config.RankArchetypes[archetype] then return nil, 'invalid_archetype' end

    local normalizedColor, colorErr = NoirGangs.normalizeColor(color)
    if not normalizedColor then return nil, colorErr end
    color = normalizedColor

    local total = 0
    for _ in pairs(registry) do total = total + 1 end
    if total >= Config.Gang.max then return nil, 'gang_limit' end

    MySQL.query.await(
        'INSERT INTO noir_gang_state (gang_name, label, color, archetype) VALUES (?, ?, ?, ?)',
        { name, label, color, archetype })
    registry[name] = { name = name, label = label, color = color, archetype = archetype }

    -- O provider precisa conhecer a gang antes de receber os cargos dela, senão o
    -- `UpsertGangGrade` de cada nível é recusado e a gang nasce sem escada nenhuma. Publica
    -- só esta: mandar a lista inteira zeraria a escada de todas as outras.

    seedRanks(name)
    loadRanks()
    -- Sem isto a gang nasce com a escada vazia no provider: ninguém entra nela, e o arquivo
    -- sairia sem cargo nenhum, o que apagaria membresia no boot seguinte.
    return name
end

---Rótulo, cor e — só enquanto ninguém entrou — arquétipo.
---@return boolean ok
---@return string? errorCode
---@return integer? membros quando a recusa foi por gang ocupada
function NoirGangs.updateGang(gangName, data)
    local entry = registry[gangName]
    if not entry then return false, 'gang_not_found' end
    if type(data) ~= 'table' then return false, 'invalid_label' end

    local label = normalizeGangLabel(data.label)
    if not label then return false, 'invalid_label' end

    local color, colorErr = NoirGangs.normalizeColor(data.color)
    if not color then return false, colorErr end

    local archetype = data.archetype or entry.archetype
    if not Config.RankArchetypes[archetype] then return false, 'invalid_archetype' end

    -- Trocar o arquétipo é reescrever a escada inteira. Com gente dentro, isso move cada
    -- pessoa para um nível que talvez não exista no arquétipo novo — ou some com o cargo
    -- dela. Com a gang vazia não há ninguém para mover, e a troca é só uma reescrita.
    local changingArchetype = archetype ~= entry.archetype
    if changingArchetype then
        local members = memberCount(gangName)
        if members > 0 then return false, 'gang_occupied', members end
    end

    MySQL.update.await('UPDATE noir_gang_state SET label = ?, color = ?, archetype = ? WHERE gang_name = ?',
        { label, color, archetype, gangName })
    entry.label, entry.color, entry.archetype = label, color, archetype

    -- O rótulo vive no dicionário do provider: sem republicar, `PlayerData.gang.label`
    -- continua mostrando o nome antigo para o servidor inteiro. Só esta gang, de novo.

    if changingArchetype then
        MySQL.query.await('DELETE FROM noir_gang_ranks WHERE gang_name = ?', { gangName })
        seedRanks(gangName)
        loadRanks()
    end

    return true
end
