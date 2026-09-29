-- Rode de dentro de resources/[bgrz]/noir_fazenda:
--   lua5.4 tests/unit/migrations_spec.lua
--
-- Este spec existe porque o runner rejeitou o próprio migration em produção: ele
-- corta o arquivo em `;` e cada pedaço vinha com o bloco de comentário colado,
-- então "começava" com `--` e não com `CREATE TABLE`. O resource subiu e se matou.
--
-- A lição não é "comentário quebra regex" -- é que a validação nunca tinha sido
-- rodada contra o arquivo REAL. Aqui ela é.

local Test = dofile('tests/testlib.lua')

local executed = {}

function LoadResourceFile(_, path)
    local handle = assert(io.open(path, 'r'), 'não consegui ler ' .. path)
    local content = handle:read('a')
    handle:close()
    return content
end

function GetCurrentResourceName() return 'noir_fazenda' end

MySQL = { query = { await = function(sql) executed[#executed + 1] = sql end } }
json = { encode = function() return '{}' end }

dofile('shared/constants.lua')
dofile('shared/config.lua')
dofile('server/logger.lua')
dofile('server/migrations.lua')

-- 1. o arquivo real passa pela allowlist inteiro
local ok, err = pcall(NoirFazenda.Migrations.run)
Test.truthy(ok, '001_initial.sql foi rejeitado pelo próprio runner: ' .. tostring(err))

-- 2. e executou o que devia: 4 CREATE TABLE + 1 INSERT IGNORE
Test.equal(#executed, 5, 'número de statements executados')

local creates = 0
for _, sql in ipairs(executed) do
    if sql:upper():match('^CREATE%s+TABLE') then creates = creates + 1 end
    Test.falsy(sql:match('^%s*%-%-'), 'statement chegou ao banco começando com comentário')
end
Test.equal(creates, 4, 'quatro tabelas criadas')

-- 3. as tabelas que o init exige são as mesmas que o migration cria
for _, name in ipairs({ 'noir_fazenda_schema_migrations', 'noir_fazenda_ledger',
    'noir_fazenda_assessments', 'noir_fazenda_payments' }) do
    local found = false
    for _, sql in ipairs(executed) do
        if sql:find(name, 1, true) then found = true break end
    end
    Test.truthy(found, name .. ' não é criada pelo migration')
end

-- 4. a allowlist continua barrando o que precisa barrar: um migration já aplicado
--    é imutável, e editar um para incluir DROP/UPDATE tem que falhar no start
local danger = { 'DROP TABLE noir_fazenda_ledger;', 'UPDATE noir_fazenda_ledger SET amount = 0;',
    'DELETE FROM noir_fazenda_assessments;', 'GRANT ALL ON *.* TO fivem;' }
for _, statement in ipairs(danger) do
    local original = LoadResourceFile
    LoadResourceFile = function() return statement end
    local blocked = not pcall(NoirFazenda.Migrations.run)
    LoadResourceFile = original
    Test.truthy(blocked, 'allowlist deixou passar: ' .. statement)
end

-- 5. comentário não pode virar um jeito de esconder statement proibido
local original = LoadResourceFile
LoadResourceFile = function() return '-- CREATE TABLE IF NOT EXISTS ok (id INT)\nDROP TABLE x;' end
Test.truthy(not pcall(NoirFazenda.Migrations.run),
    'comentário disfarçando DROP passou pela allowlist')
LoadResourceFile = original

print('migrations_spec: ok')
