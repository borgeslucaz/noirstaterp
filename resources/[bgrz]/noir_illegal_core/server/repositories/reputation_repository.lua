local Repository = {}
NoirIllegal.Repositories.Reputation = Repository

local function tableFor(scope)
    if scope == 'player' then
        return 'noir_illegal_player_reputation', 'citizenid'
    end
    return 'noir_illegal_organization_reputation', 'organization_id'
end

local function toMap(rows)
    local result = {}
    for i = 1, #rows do result[rows[i].category] = tonumber(rows[i].value) or 0 end
    return result
end

function Repository.list(scope, subjectId, query, forUpdate)
    local tableName, idColumn = tableFor(scope)
    local suffix = forUpdate and ' FOR UPDATE' or ''
    return toMap(NoirIllegal.Database.rows(query,
        ('SELECT category, value FROM %s WHERE %s = ?%s'):format(tableName, idColumn, suffix),
        { subjectId }))
end

function Repository.ensureCategory(scope, subjectId, category, query)
    local tableName, idColumn = tableFor(scope)
    NoirIllegal.Database.execute(query,
        ('INSERT IGNORE INTO %s (%s, category, value) VALUES (?, ?, 0)'):format(tableName, idColumn),
        { subjectId, category })
end

function Repository.add(scope, subjectId, category, delta, query)
    local tableName, idColumn = tableFor(scope)
    NoirIllegal.Database.execute(query, ([[
        INSERT INTO %s (%s, category, value) VALUES (?, ?, GREATEST(0, ?))
        ON DUPLICATE KEY UPDATE value = GREATEST(0, value + VALUES(value))
    ]]):format(tableName, idColumn), { subjectId, category, delta })
end

function Repository.set(scope, subjectId, category, value, query)
    local tableName, idColumn = tableFor(scope)
    NoirIllegal.Database.execute(query, ([[
        INSERT INTO %s (%s, category, value) VALUES (?, ?, GREATEST(0, ?))
        ON DUPLICATE KEY UPDATE value = VALUES(value)
    ]]):format(tableName, idColumn), { subjectId, category, value })
end
