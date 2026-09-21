NoirFazenda = NoirFazenda or {}
NoirFazenda.Migrations = {}

NoirFazenda.Migrations.files = {
    '001_initial',
}

local function trim(value)
    return value:match('^%s*(.-)%s*$')
end

-- Remove as linhas de comentário antes da allowlist.
--
-- Sem isto, um migration comentado se auto-rejeita: o arquivo é cortado em `;` e
-- cada pedaço carrega junto o bloco de comentário que vem acima da tabela, então
-- o statement "começa" com `--` e não com `CREATE TABLE`.
--
-- O runner veio do noir_illegal_core, cujo SQL não tem um único comentário. Lá
-- o bug não existia por acidente, não por desenho.
local function stripComments(statement)
    local kept = {}
    for line in statement:gmatch('[^\n]*') do
        if not line:match('^%s*%-%-') then kept[#kept + 1] = line end
    end
    return trim(table.concat(kept, '\n'))
end

-- Allowlist de DDL. O runner não é um executor de SQL arbitrário: se alguém
-- editar um migration já aplicado para incluir um DROP ou um UPDATE, o start
-- falha em vez de rodar. Migration aplicado é imutável (§12.5).
local function isAllowed(statement)
    local normalized = statement:upper()
    return normalized:match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+') ~= nil
        or normalized:match('^INSERT%s+IGNORE%s+INTO%s+') ~= nil
end

local function runFile(version)
    local path = ('migrations/%s.sql'):format(version)
    local sql = LoadResourceFile(GetCurrentResourceName(), path)
    if not sql or sql == '' then
        error(('Não foi possível ler %s.'):format(path))
    end

    local executed = 0
    for rawStatement in sql:gmatch('([^;]+);') do
        local statement = stripComments(rawStatement)
        if statement ~= '' then
            if not isAllowed(statement) then
                error(('%s contém statement não permitido: %s'):format(
                    path, statement:sub(1, 80)))
            end
            MySQL.query.await(statement)
            executed = executed + 1
        end
    end

    if executed == 0 then
        error(('%s não continha statements executáveis.'):format(path))
    end
    return executed
end

function NoirFazenda.Migrations.run()
    local total = 0
    for i = 1, #NoirFazenda.Migrations.files do
        total = total + runFile(NoirFazenda.Migrations.files[i])
    end
    NoirFazenda.Logger.info('migration_checked', {
        versions = NoirFazenda.Migrations.files,
        statements = total,
    })
end
