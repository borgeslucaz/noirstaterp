-- Guardas estruturais: acoplamento, segurança e as coisas que quebram em silêncio
-- (arquivo de UI que não existe, CDN dentro da NUI, DDL destrutivo na migração).
local T = dofile('tests/testlib.lua')

dofile('shared/config.lua')
dofile('shared/xp.lua')

local function read(path)
    local file = assert(io.open(path, 'r'), 'arquivo ausente: ' .. path)
    local content = file:read('*a')
    file:close()
    return content
end

local function exists(path)
    local file = io.open(path, 'r')
    if file then file:close() return true end
    return false
end

-- Acoplamento: o framework chega pelo bridge ---------------------------------------------
local manifest = read('fxmanifest.lua')
T.truthy(manifest:find("'bgrz_core'", 1, true), 'bridge declarado como dependência')
for _, forbidden in ipairs({ "'qbx_core'", "'qb-core'", "'es_extended'", "'ox_core'" }) do
    T.falsy(manifest:find(forbidden, 1, true),
        ('%s é dependência do bgrz_core, não nossa'):format(forbidden))
end

for _, path in ipairs({ 'client/main.lua', 'server/main.lua', 'server/store.lua', 'shared/xp.lua' }) do
    local source = read(path)
    T.falsy(source:find('exports.qbx_core', 1, true), path .. ' não fala com o framework direto')
    T.falsy(source:find('QBCore:', 1, true), path .. ' usa os eventos do bgrz_core, não os do Qbox')
    T.falsy(source:find('GetCoreObject', 1, true), path .. ' não busca objeto de framework')
end

-- Segurança: XP nasce no servidor ------------------------------------------------------------
-- O upstream já era assim e precisa continuar: um `RegisterNetEvent` que concede XP é um
-- comando de admin para qualquer jogador com executor.
local serverCode = read('server/main.lua')
T.falsy(serverCode:find('RegisterNetEvent', 1, true),
    'o servidor não aceita evento do cliente; ganho de XP vem de export de outro resource')

-- Ordem de carga --------------------------------------------------------------------------
T.truthy(manifest:find("'shared/xp.lua'", 1, true), 'a curva é shared: os dois lados calculam igual')
T.truthy(manifest:find("'shared/config.lua',\n    'shared/xp.lua'", 1, true),
    'shared/xp.lua carrega depois do config, que é o que ele lê')
T.truthy(manifest:find("'server/store.lua',\n    'server/main.lua'", 1, true),
    'store.lua carrega antes do main, que depende dele')

-- UI ----------------------------------------------------------------------------------------
local uiPage = manifest:match("ui_page%s+'([^']+)'")
T.equal(uiPage, 'web/build/index.html', 'ui_page aponta para o build')
T.truthy(exists(uiPage), 'o build da UI está versionado: sem ele a NUI abre em branco')
T.truthy(manifest:find("'web/build/%*%*/%*'"), 'os assets do build são publicados')

local builtPage = read(uiPage)
T.truthy(builtPage:find('./assets/', 1, true), 'o build usa caminho relativo, exigência da nui://')

-- Nada de CDN: o cliente pode não ter internet, e a falha é silenciosa — fonte com serifa,
-- ícone quadrado, e ninguém relaciona isso com a rede. Por isso ícones e fontes são locais.
local webFiles = { 'web/index.html', 'web/src/app.css', 'web/src/App.svelte',
    'web/src/lib/Icon.svelte', 'web/src/lib/SkillCard.svelte' }

for _, path in ipairs(webFiles) do
    local source = read(path)
    T.falsy(source:find('https://', 1, true), path .. ' não pode puxar recurso da internet')
    T.falsy(source:find('font%-awesome'), path .. ' não depende de fonte de ícone remota')
end

-- Guia de design v3 (resources/docs/DESIGN_v3.md) ------------------------------------------
local css = read('web/src/app.css')
T.truthy(css:find("url('./fonts/Poppins-400.woff2')", 1, true), 'Poppins empacotada no resource')
for _, weight in ipairs({ '400', '500', '600', '700' }) do
    T.truthy(exists('web/src/fonts/Poppins-' .. weight .. '.woff2'),
        'peso ' .. weight .. ' da Poppins precisa estar no resource')
end
T.truthy(exists('web/src/fonts/OFL-Poppins.txt'), 'a licença da fonte acompanha os arquivos')

local fontShipped = false
local buildDir = io.popen('ls web/build/assets 2>/dev/null')
for line in buildDir:lines() do
    if line:find('Poppins', 1, true) then fontShipped = true end
end
buildDir:close()
T.truthy(fontShipped, 'a fonte precisa sair no build, senão a NUI cai no fallback')

-- Raiz transparente é regra crítica da NUI: fundo opaco no documento pinta a cena de preto
-- mesmo com o painel fechado, e `color-scheme` faz o mesmo no CEF.
for _, path in ipairs({ 'web/index.html', 'web/src/app.css' }) do
    local source = read(path)
    T.truthy(source:find('background: transparent !important', 1, true),
        path .. ' precisa declarar a raiz transparente')
    -- Procura a declaração, não a palavra: o comentário que explica a regra cita o termo.
    T.falsy(source:find('color%-scheme%s*:'), path .. ' não pode declarar color-scheme')
end

for _, path in ipairs(webFiles) do
    local source = read(path)
    T.falsy(source:find('backdrop%-filter%s*:'), path .. ' não usa blur: no FiveM ele pinta a cena de preto')
end

-- Tipografia dimensionada só em vw/vh é antipadrão da v3 (texto some em ultrawide).
T.falsy(css:find('font%-size:%s*[%d.]+vw'), 'o tamanho de fonte não é medido em vw')
T.falsy(css:find('font%-size:%s*[%d.]+vh'), 'o tamanho de fonte não é medido em vh')

-- Só a lista rola; o painel inteiro nunca ganha barra de rolagem.
local app = read('web/src/App.svelte')
T.truthy(app:find('overflow%-y: auto'), 'a lista rola por dentro')
T.truthy(app:find('prefers%-reduced%-motion') or css:find('prefers%-reduced%-motion'),
    'movimento respeita prefers-reduced-motion')

-- Migração -------------------------------------------------------------------------------------
-- O arquivo roda inteiro a cada start, então nada ali pode apagar ou reescrever dado.
local sql = read('migrations/noir_skills.sql'):gsub('%-%-[^\r\n]*', '')
local statements = 0
for statement in sql:gmatch('([^;]+);') do
    statement = statement:gsub('^%s*(.-)%s*$', '%1')
    if statement ~= '' then
        statements = statements + 1
        T.truthy(statement:upper():match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+')
            or statement:upper():match('^CREATE%s+INDEX%s+IF%s+NOT%s+EXISTS%s+')
            or statement:upper():match('^ALTER%s+TABLE%s+[%w_`]+%s+ADD%s+COLUMN%s+IF%s+NOT%s+EXISTS%s+'),
            'statement não idempotente na migração: ' .. statement:sub(1, 60))
    end
end
T.truthy(statements > 0, 'a migração precisa ter statements')
T.truthy(sql:find('PRIMARY KEY (`citizenid`, `skill`)', 1, true),
    'uma linha por personagem e habilidade, senão o upsert duplica')

-- Config --------------------------------------------------------------------------------------
T.truthy(type(Config.AdminAce) == 'string' and Config.AdminAce ~= '', 'os comandos precisam de um ace')
T.truthy(type(Config.Command) == 'string' and Config.Command ~= '', 'o painel precisa de um comando')
T.truthy(type(Config.Hotkey) == 'string' and Config.Hotkey ~= '', 'e de uma tecla padrão')

-- Ícone desconhecido não quebra a UI, mas quase sempre é erro de digitação no config.
local iconSource = read('web/src/lib/Icon.svelte')
for skill, conf in pairs(Config.Skills) do
    T.truthy(iconSource:find(("%s: '"):format(conf.icon), 1, true),
        ('%s usa um ícone que a UI não tem: %s'):format(skill, conf.icon))
end

print('config_spec: ok')
