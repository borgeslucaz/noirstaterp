local Repository = {}
NoirIllegal.Repositories.Unlock = Repository

function Repository.list(scope, subjectId, query, forUpdate)
    local suffix = forUpdate and ' FOR UPDATE' or ''
    return NoirIllegal.Database.rows(query, ([[
        SELECT unlock_key, state, source, granted_by, reason,
               UNIX_TIMESTAMP(granted_at) AS granted_at_epoch,
               UNIX_TIMESTAMP(revoked_at) AS revoked_at_epoch
        FROM noir_illegal_unlocks
        WHERE subject_type = ? AND subject_id = ?%s
    ]]):format(suffix), { scope, subjectId })
end

function Repository.find(scope, subjectId, unlockKey, query, forUpdate)
    local suffix = forUpdate and ' FOR UPDATE' or ''
    return NoirIllegal.Database.single(query, ([[
        SELECT unlock_key, state, source, granted_by, reason
        FROM noir_illegal_unlocks
        WHERE subject_type = ? AND subject_id = ? AND unlock_key = ?%s
    ]]):format(suffix), { scope, subjectId, unlockKey })
end

function Repository.upsert(scope, subjectId, unlockKey, state, sourceName, actorId, reason, metadata, query)
    local revokedAt = state == 'revoked' and 'UTC_TIMESTAMP()' or 'NULL'
    NoirIllegal.Database.execute(query, ([[
        INSERT INTO noir_illegal_unlocks
            (subject_type, subject_id, unlock_key, state, source, granted_by, reason, metadata, granted_at, revoked_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(), %s)
        ON DUPLICATE KEY UPDATE
            state = VALUES(state), source = VALUES(source), granted_by = VALUES(granted_by),
            reason = VALUES(reason), metadata = VALUES(metadata),
            granted_at = IF(VALUES(state) = 'granted', UTC_TIMESTAMP(), granted_at),
            revoked_at = IF(VALUES(state) = 'revoked', UTC_TIMESTAMP(), NULL)
    ]]):format(revokedAt), {
        scope, subjectId, unlockKey, state, sourceName, actorId, reason,
        json.encode(metadata or {}),
    })
end
