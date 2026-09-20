local T = dofile('tests/testlib.lua')

function vec3(x, y, z) return { x = x, y = y, z = z } end
dofile('shared/config.lua')

local function read(path)
    local file = assert(io.open(path, 'r'))
    local content = file:read('*a')
    file:close()
    return content
end

-- Acoplamento: o framework e os providers chegam pelo bridge ---------------------------
local manifest = read('fxmanifest.lua')
T.truthy(manifest:find("'bgrz_core'", 1, true), 'bridge declarado como dependência')
T.truthy(manifest:find("'server/state.lua'", 1, true), 'o módulo de estado carrega antes do main')
T.truthy(manifest:find("'server/state.lua', 'server/main.lua'", 1, true),
    'state.lua precisa vir antes do main.lua, que depende do NoirGangs')
for _, forbidden in ipairs({ "'qbx_core'", "'ox_target'" }) do
    T.falsy(manifest:find(forbidden, 1, true),
        ('%s é dependência do bgrz_core, não nossa'):format(forbidden))
end

for _, path in ipairs({ 'client/main.lua', 'client/ui.lua', 'server/main.lua', 'server/state.lua' }) do
    local source = read(path)
    T.falsy(source:find('exports.qbx_core', 1, true), path .. ' não fala com o framework direto')
    T.falsy(source:find('exports.ox_target', 1, true), path .. ' não fala com o target direto')
    T.falsy(source:find('QBCore:', 1, true), path .. ' usa os eventos do bgrz_core, não os do Qbox')
end

-- NUI ------------------------------------------------------------------------------------
-- A tela some inteira, sem erro no console, quando um arquivo que ela pede não é servido:
-- o CEF só não carrega. Então o que a página referencia tem que existir no disco E estar em
-- `files`, e as duas coisas são conferidas aqui.
T.truthy(manifest:find("ui_page 'html/index.html'", 1, true), 'a tela precisa estar declarada no manifest')

local shippedFiles = {}
for path in manifest:gmatch("'(html/[^']+)'") do shippedFiles[#shippedFiles + 1] = path end
T.truthy(#shippedFiles > 0, 'o manifest precisa servir os arquivos da tela')

---Um `*` no `files` cobre um diretório inteiro; comparar só por igualdade acusaria falta
---onde não há.
local function isShipped(target)
    for _, entry in ipairs(shippedFiles) do
        if entry == target then return true end
        local prefix, suffix = entry:match('^(.-)%*(.*)$')
        if prefix and target:sub(1, #prefix) == prefix
            and (suffix == '' or target:sub(- #suffix) == suffix) then
            return true
        end
    end
    return false
end

local function exists(path)
    local file = io.open(path, 'r')
    if not file then return false end
    file:close()
    return true
end

local function checkReference(reference, origin)
    if reference:find('^%a+:') or reference:find('^#') or reference:find('^data:') then return end
    local target = 'html/' .. reference
    T.truthy(exists(target), ('%s aponta para um arquivo que não existe: %s'):format(origin, target))
    T.truthy(isShipped(target), ('%s pede %s, que o manifest não serve'):format(origin, target))
end

-- Só o nosso CSS: o do Leaflet aponta para sprites de controles que não usamos e que,
-- por isso, não são empacotados.
local page, styles = read('html/index.html'), read('html/main.css')
for reference in page:gmatch('src="([^"]+)"') do checkReference(reference, 'index.html') end
for reference in page:gmatch('href="([^"]+)"') do checkReference(reference, 'index.html') end
for reference in styles:gmatch('url%("([^"]+)"%)') do checkReference(reference, 'main.css') end

-- Nada de CDN: a tela abre com o jogo, e uma dependência remota some junto com a internet
-- do jogador. A única URL montada no código é a do próprio resource, em `GetParentResourceName`.
for _, path in ipairs({ 'html/index.html', 'html/main.css', 'html/app.js' }) do
    local source = read(path)
    T.falsy(source:find('https?://%w'), path .. ' não pode depender de arquivo remoto')
end
T.truthy(read('html/app.js'):find('GetParentResourceName', 1, true),
    'o callback da página usa o nome real do resource, não um nome fixo')

-- Toda permissão do catálogo precisa de frase em português na tela. Sem isso o editor
-- mostraria o id cru para o jogador marcar, que é o mesmo que não explicar nada.
local appSource = read('html/app.js')
local permissionText = appSource:match('PERMISSION_TEXT%s*=%s*{(.-)\n%s*}')
T.truthy(permissionText, 'a tela precisa do mapa de permissões em português')
for _, permission in ipairs(Config.Permissions) do
    T.truthy(permissionText:find(permission .. ':', 1, true),
        ('html/app.js não tem texto para a permissão %s'):format(permission))
end

-- Permissões e cargos --------------------------------------------------------------------
-- `manage_permissions` continua fora: ela nunca teve UI nem handler. `manage_ranks` voltou
-- junto com o editor de cargos, e por isso é cobrada aqui dos dois lados — catálogo e
-- handler. Permissão sem handler é a mesma armadilha de antes: ela aparece na tela,
-- alguém marca, e nada acontece.
--
-- Acima disso vale a regra de sempre: permissão é POR CARGO, declarada no arquétipo, sem
-- herança por nível.
T.falsy(Config.DefaultPermissions, 'o mapa por nível semântico deu lugar aos arquétipos')

local catalog = {}
for _, permission in ipairs(Config.Permissions) do
    T.falsy(catalog[permission], 'permissão repetida no catálogo: ' .. permission)
    catalog[permission] = true
end
for _, dead in ipairs({ 'manage_permissions' }) do
    T.falsy(catalog[dead], 'permissão morta de volta no catálogo: ' .. dead)
end
T.truthy(catalog.manage_ranks, 'o editor de cargos precisa da permissão no catálogo')

-- Toda permissão que o código consulta precisa existir no catálogo, senão ela nunca é
-- verdadeira e o erro só aparece no dia em que alguém precisar dela.
local serverCode = read('server/main.lua')
for permission in serverCode:gmatch("allowed%([%w%.]+, '([%w_]+)'%)") do
    T.truthy(catalog[permission], ('server/main.lua usa permissão fora do catálogo: %s'):format(permission))
end
for permission in read('server/state.lua'):gmatch("permissions%.([%w_]+)") do
    T.truthy(catalog[permission] or permission == 'view_members', permission .. ' fora do catálogo')
end

-- Transferir liderança saiu do catálogo: trocar quem lidera é operação de admin
-- (`/setgang`), não mecanismo de jogador.
T.falsy(catalog.transfer_leadership, 'transferir liderança não é permissão de jogador')

-- Cada arquétipo precisa de exatamente um cargo de chefe, e ele tem que ser o mais alto.
-- É o `isBoss` que torna o cargo intocável: se dois cargos fossem chefe, dois grupos de
-- membros ficariam imunes a desligamento; se nenhum fosse, ninguém seria protegido.
for name, archetype in pairs(Config.RankArchetypes) do
    T.truthy(#archetype.ranks >= 2, name .. ' precisa de pelo menos dois cargos')

    local top, bosses, seen = nil, 0, {}
    for _, rank in ipairs(archetype.ranks) do
        T.falsy(seen[rank.level], ('%s repete o nível %s'):format(name, tostring(rank.level)))
        seen[rank.level] = true
        T.truthy(type(rank.label) == 'string' and rank.label ~= '', name .. ' tem cargo sem rótulo')
        if not top or rank.level > top.level then top = rank end
        if rank.isBoss then bosses = bosses + 1 end
        for _, permission in ipairs(rank.permissions) do
            T.truthy(catalog[permission], ('%s: permissão desconhecida %s'):format(name, permission))
        end
    end
    T.equal(bosses, 1, name .. ' precisa de exatamente um cargo de chefe')
    T.truthy(top.isBoss, name .. ': o chefe tem que ser o cargo mais alto')

    -- O editor não mexe no cargo de chefe nem no cargo de quem está usando. Se o chefe não
    -- nascesse com `manage_ranks`, ninguém na gang poderia editar cargo nenhum, e a
    -- permissão não teria como ser concedida a mais ninguém.
    local bossManages = false
    for _, permission in ipairs(top.permissions) do
        if permission == 'manage_ranks' then bossManages = true end
    end
    T.truthy(bossManages, name .. ': o chefe precisa poder gerir os cargos, senão ninguém pode')

    -- O cargo logo abaixo do chefe é o teto real de promoção, já que ninguém é promovido
    -- a chefe. Se ele não pudesse nada, a gang não teria quem gerisse além do chefe.
    local below
    for _, rank in ipairs(archetype.ranks) do
        if rank.level < top.level and (not below or rank.level > below.level) then below = rank end
    end
    local belowCanManage = false
    for _, permission in ipairs(below.permissions) do
        if permission == 'promote' or permission == 'remove_member' then belowCanManage = true end
    end
    T.truthy(belowCanManage,
        name .. ': o cargo abaixo do chefe precisa poder gerir, senão só o chefe gere a gang')
end

-- Gangs e produtos -------------------------------------------------------------------------
T.truthy(Config.RankArchetypes[Config.FallbackArchetype], 'o arquétipo padrão precisa existir')
for gangName, definition in pairs(Config.Gangs) do
    T.truthy(Config.RankArchetypes[definition.archetype],
        ('%s aponta para arquétipo inexistente'):format(gangName))
    local seen = {}
    for _, product in ipairs(definition.products or {}) do
        T.truthy(Config.ProductTypes[product], ('%s opera produto desconhecido: %s'):format(gangName, product))
        T.falsy(seen[product], ('%s repete o produto %s'):format(gangName, product))
        seen[product] = true
    end
end

-- O `shared/gangs.lua` do Qbox é espelho: quem existe é dado nosso, e nós o reescrevemos
-- pela API dele a cada start, depois dos cargos publicados.
--
-- O que este teste cobra é a única propriedade daquele arquivo que pode destruir dado. O
-- provider apaga de `player_groups` toda linha cujo CARGO não exista, então uma gang
-- gravada com escada vazia apaga a membresia de todo mundo dela no boot seguinte — em
-- silêncio, e sem volta. Foi o que quase aconteceu ao gravar o arquivo junto do registro,
-- antes dos cargos.
local qbxGangs = read('../../[qbx]/qbx_core/shared/gangs.lua')
local gangBlocks = {}
for gangName, body in qbxGangs:gmatch("%['([%w_]+)'%]%s*=%s*{(.-)\n%s*},?\n") do
    gangBlocks[gangName] = body
end
T.truthy(next(gangBlocks), 'o arquivo do provider precisa ter pelo menos a gang vazia')

for gangName, body in pairs(gangBlocks) do
    local levels = 0
    for _ in body:gmatch('%[%d+%]%s*=%s*{') do levels = levels + 1 end
    T.truthy(levels > 0,
        ('shared/gangs.lua tem %s sem cargo nenhum: isso apaga a membresia dela no próximo boot'):format(gangName))
end

-- `none` é do próprio Qbox — o estado de quem não tem gang. Ela não é do registro e nunca
-- pode sumir do arquivo.
T.truthy(gangBlocks.none, 'a gang vazia do provider precisa continuar no arquivo')

-- E toda gang semeada precisa de rótulo, cor e arquétipo que existam.
for gangName, definition in pairs(Config.Gangs) do
    T.truthy(type(definition.label) == 'string' and definition.label ~= '',
        ('%s precisa de rótulo na semente'):format(gangName))
    T.truthy(Config.Colors[definition.color], ('%s tem cor fora da paleta'):format(gangName))
end
T.truthy(Config.Colors[Config.FallbackColor], 'a cor padrão precisa existir na paleta')
T.truthy(Config.Gang.max >= 6, 'o teto de gangs precisa caber as que já existem')

-- Reputação ---------------------------------------------------------------------------------
T.truthy(Config.Reputation.min < 0, 'a reputação precisa poder ficar negativa')
T.truthy(Config.Reputation.max > 0, 'e crescer')
T.truthy(Config.Reputation.maxDelta > 0, 'um ajuste sozinho precisa de teto')
T.truthy(Config.Reputation.maxDelta < Config.Reputation.max,
    'o teto por ajuste tem que ser menor que o total, senão não limita nada')

-- Convites -----------------------------------------------------------------------------
T.truthy(Config.Invitation.maxDistance > 0, 'convite precisa de uma distância máxima')
T.truthy(Config.Invitation.duration > Config.Invitation.cooldown,
    'um convite precisa durar mais que o intervalo entre envios')
T.truthy(Config.ActivityLimit > 0, 'o histórico precisa de um teto')

-- Schema -------------------------------------------------------------------------------
-- Roda a cada start, então todo statement tem que ser idempotente e não destrutivo.
local schema = read('migrations/noir_gangs.sql'):gsub('%-%-[^\r\n]*', '')
local statements = 0
for rawStatement in schema:gmatch('([^;]+);') do
    local statement = rawStatement:gsub('^%s*(.-)%s*$', '%1')
    if statement ~= '' then
        statements = statements + 1
        local upper = statement:upper()
        T.truthy(upper:match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS')
            or upper:match('^CREATE%s+INDEX%s+IF%s+NOT%s+EXISTS')
            or upper:match('^ALTER%s+TABLE%s+[%w_`]+%s+ADD%s+COLUMN%s+IF%s+NOT%s+EXISTS'),
            'statement não idempotente: ' .. statement:sub(1, 60))
    end
end
T.equal(statements, 7, 'locations, activity, state, products, ranks e as duas colunas do registro')



-- README -----------------------------------------------------------------------------------
-- Documentação que mente é pior que documentação ausente, e as partes que mais envelhecem são
-- as listas: exports, permissões, cargos, comandos e tabelas. Prende cada uma no código.
local readme = read('README.md')

for _, permission in ipairs(Config.Permissions) do
    T.truthy(readme:find(permission, 1, true), 'README não lista a permissão ' .. permission)
end

for exportName in read('server/main.lua'):gmatch("exports%('([%w_]+)'") do
    T.truthy(readme:find('noir_gangs:' .. exportName, 1, true),
        ('README não documenta o export %s'):format(exportName))
end

for command in read('server/main.lua'):gmatch("RegisterCommand%('([%w_]+)'") do
    T.truthy(readme:find('/' .. command, 1, true), ('README não documenta /%s'):format(command))
end

for tableName in read('migrations/noir_gangs.sql'):gmatch('CREATE TABLE IF NOT EXISTS `([%w_]+)`') do
    T.truthy(readme:find(tableName, 1, true), ('README não documenta a tabela %s'):format(tableName))
end

for name, archetype in pairs(Config.RankArchetypes) do
    T.truthy(readme:find(name, 1, true), ('README não cita o arquétipo %s'):format(name))
    for _, rank in ipairs(archetype.ranks) do
        T.truthy(readme:find(rank.label, 1, true),
            ('README não lista o cargo %s de %s'):format(rank.label, name))
    end
end

for gangName, definition in pairs(Config.Gangs) do
    T.truthy(readme:find(gangName, 1, true), ('README não cita a gang %s'):format(gangName))
    for _, product in ipairs(definition.products or {}) do
        T.truthy(readme:find(product, 1, true), ('README não cita o produto %s'):format(product))
    end
end

-- As ações do histórico também são contrato: outro resource pode ler a tabela.
local serverSource = read('server/main.lua')
for _, pattern in ipairs({ "'(member_%a+)'", "'(rank_%a+)'" }) do
    for action in serverSource:gmatch(pattern) do
        T.truthy(readme:find(action, 1, true), ('README não lista a ação de log %s'):format(action))
    end
end

print('config_spec: ok')
