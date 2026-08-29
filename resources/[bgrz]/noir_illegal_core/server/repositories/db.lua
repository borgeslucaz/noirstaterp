NoirIllegal.Repositories = NoirIllegal.Repositories or {}
NoirIllegal.Database = {}

function NoirIllegal.Database.awaitTransactionQuery(query, sql, parameters)
    local raw = Citizen.Await(query(sql, parameters or {}))
    if type(raw) == 'table' and raw[2] ~= nil then return raw[1] end
    return raw
end

function NoirIllegal.Database.rows(query, sql, parameters)
    if query then
        return NoirIllegal.Database.awaitTransactionQuery(query, sql, parameters) or {}
    end
    return MySQL.query.await(sql, parameters or {}) or {}
end

function NoirIllegal.Database.single(query, sql, parameters)
    local rows = NoirIllegal.Database.rows(query, sql, parameters)
    return rows and rows[1] or nil
end

function NoirIllegal.Database.execute(query, sql, parameters)
    if query then
        return NoirIllegal.Database.awaitTransactionQuery(query, sql, parameters)
    end
    return MySQL.query.await(sql, parameters or {})
end
