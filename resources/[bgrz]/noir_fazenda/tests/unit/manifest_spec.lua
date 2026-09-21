-- Rode de dentro de resources/[bgrz]/noir_fazenda:
--   lua5.4 tests/unit/manifest_spec.lua
--
-- Este spec não testa comportamento: testa as regras de arquitetura que só
-- quebram em produção, meses depois, quando alguém "só adicionou uma chamadinha".

local Test = dofile('tests/testlib.lua')

local function read(path)
    local handle = assert(io.open(path, 'r'), 'não consegui ler ' .. path)
    local content = handle:read('a')
    handle:close()
    return content
end

local function listFiles(directory)
    local found = {}
    local pipe = io.popen(('find %s -type f -name "*.lua" 2>/dev/null'):format(directory))
    for line in pipe:lines() do found[#found + 1] = line end
    pipe:close()
    return found
end

-- Comentários podem citar qualquer coisa; as regras abaixo valem para código.
local function stripComments(content)
    local lines = {}
    for line in content:gmatch('[^\n]*') do
        lines[#lines + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(lines, '\n')
end

local manifest = read('fxmanifest.lua')

-- Todo arquivo Lua de shared/ e server/ precisa estar no manifest. Arquivo órfão
-- é o erro que não dá erro: o resource sobe, e a função simplesmente não existe.
for _, path in ipairs(listFiles('shared')) do
    Test.truthy(manifest:find(path, 1, true), path .. ' não está no fxmanifest')
end
for _, path in ipairs(listFiles('server')) do
    Test.truthy(manifest:find(path, 1, true), path .. ' não está no fxmanifest')
end

Test.truthy(manifest:find("server_only 'yes'", 1, true), 'resource é server_only')
Test.truthy(manifest:find("'bgrz_core'", 1, true), 'bgrz_core declarado como dependência')

-- server/init.lua tem que ser o último server_script: ele marca Ready e chama os
-- serviços, então precisa que tudo já esteja carregado.
local initPosition = manifest:find("'server/init.lua'", 1, true)
Test.truthy(initPosition, 'init.lua está no manifest')
for _, path in ipairs(listFiles('server')) do
    if path ~= 'server/init.lua' then
        Test.truthy(manifest:find(path, 1, true) < initPosition,
            path .. ' precisa vir antes de server/init.lua')
    end
end

-- A regra que dá sentido ao bridge: este resource não pode conhecer o nome do
-- provider de banking. Já trocamos de banco duas vezes neste servidor; cada
-- menção direta aqui seria uma quebra a cada troca.
local forbidden = { 'Renewed%-Banking', 'muhaddil', 'qbx_core', 'ox_inventory' }
local sources = {}
for _, path in ipairs(listFiles('shared')) do sources[#sources + 1] = path end
for _, path in ipairs(listFiles('server')) do sources[#sources + 1] = path end
sources[#sources + 1] = 'fxmanifest.lua'

for _, path in ipairs(sources) do
    local content = stripComments(read(path))
    for _, pattern in ipairs(forbidden) do
        Test.falsy(content:find(pattern),
            ('%s menciona %s fora de comentário -- deve passar pelo bgrz_core'):format(
                path, pattern:gsub('%%', '')))
    end
end

-- Nenhuma tabela de outro resource pode aparecer em SQL nosso (§12.1).
local storage = stripComments(read('server/storage.lua'))
for _, table in ipairs({ 'bank_accounts_new', 'player_transactions', 'players', 'mdt_' }) do
    Test.falsy(storage:find(table, 1, true),
        'storage.lua consulta tabela de outro resource: ' .. table)
end

-- Todo SQL do resource mora em storage.lua e migrations (§12.2).
for _, path in ipairs(listFiles('server')) do
    if path ~= 'server/storage.lua' and path ~= 'server/migrations.lua'
        and path ~= 'server/init.lua' then
        local content = stripComments(read(path))
        Test.falsy(content:find('MySQL%.'), path .. ' tem SQL fora do storage')
    end
end

-- A cobrança precisa nascer desligada: é a diferença entre "medimos a economia"
-- e "tiramos dinheiro de todo mundo sem avisar".
dofile('shared/constants.lua')
dofile('shared/config.lua')
Test.falsy(NoirFazenda.Config.Tax.collectionEnabled, 'cobrança nasce desligada')
Test.falsy(NoirFazenda.Config.Assessment.autoClose, 'fechamento automático nasce desligado')

print('manifest_spec: ok')
