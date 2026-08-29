local Repository = {}
NoirIllegal.Repositories.Heat = Repository

function Repository.ensure(citizenId, query)
    NoirIllegal.Database.execute(query,
        'INSERT IGNORE INTO noir_illegal_player_heat (citizenid, value, last_decay_at) VALUES (?, 0, UTC_TIMESTAMP())',
        { citizenId })
end

function Repository.get(citizenId, query, forUpdate)
    local suffix = forUpdate and ' FOR UPDATE' or ''
    return NoirIllegal.Database.single(query, ([[
        SELECT value, UNIX_TIMESTAMP(last_decay_at) AS last_decay_epoch
        FROM noir_illegal_player_heat WHERE citizenid = ?%s
    ]]):format(suffix), { citizenId })
end

function Repository.set(citizenId, value, decayAt, query)
    NoirIllegal.Database.execute(query, [[
        INSERT INTO noir_illegal_player_heat (citizenid, value, last_decay_at)
        VALUES (?, ?, FROM_UNIXTIME(?))
        ON DUPLICATE KEY UPDATE value = VALUES(value), last_decay_at = VALUES(last_decay_at)
    ]], { citizenId, value, decayAt })
end
