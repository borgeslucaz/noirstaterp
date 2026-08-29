NoirIllegal.Migrations = {}

local function trim(value)
    return value:match('^%s*(.-)%s*$')
end

local function isAllowed(statement)
    local normalized = statement:upper()
    return normalized:match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+') ~= nil
        or normalized:match('^INSERT%s+IGNORE%s+INTO%s+') ~= nil
end

function NoirIllegal.Migrations.run()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_initial.sql')
    if not sql or sql == '' then
        error('Unable to load migrations/001_initial.sql.')
    end

    local executed = 0
    for rawStatement in sql:gmatch('([^;]+);') do
        local statement = trim(rawStatement)
        if statement ~= '' then
            if not isAllowed(statement) then
                error(('Migration contains a disallowed statement: %s'):format(
                    statement:sub(1, 80)))
            end
            MySQL.query.await(statement)
            executed = executed + 1
        end
    end

    if executed == 0 then
        error('Migration file did not contain executable statements.')
    end

    NoirIllegal.Logger.info('migration_checked', {
        version = '001_initial',
        statements = executed,
    })
end
