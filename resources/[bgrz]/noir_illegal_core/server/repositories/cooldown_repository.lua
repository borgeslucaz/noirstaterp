local Repository = {}
NoirIllegal.Repositories.Cooldown = Repository

function Repository.get(scope, subjectId, cooldownKey, query, forUpdate)
    local suffix = forUpdate and ' FOR UPDATE' or ''
    return NoirIllegal.Database.single(query, ([[
        SELECT UNIX_TIMESTAMP(expires_at) AS expires_at_epoch
        FROM noir_illegal_cooldowns
        WHERE subject_type = ? AND subject_id = ? AND cooldown_key = ?%s
    ]]):format(suffix), { scope, subjectId, cooldownKey })
end

function Repository.set(scope, subjectId, cooldownKey, expiresAt, query)
    NoirIllegal.Database.execute(query, [[
        INSERT INTO noir_illegal_cooldowns (subject_type, subject_id, cooldown_key, expires_at)
        VALUES (?, ?, ?, FROM_UNIXTIME(?))
        ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at)
    ]], { scope, subjectId, cooldownKey, expiresAt })
end
