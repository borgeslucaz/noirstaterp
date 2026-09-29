local Repository = {}
NoirIllegal.Repositories.Audit = Repository

function Repository.insert(data, query)
    NoirIllegal.Database.execute(query, [[
        INSERT INTO noir_illegal_audit_log (
            action, actor_type, actor_id, target_type, target_id, transaction_id,
            before_state, after_state, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.action, data.actorType, data.actorId, data.targetType, data.targetId,
        data.transactionId,
        data.beforeState and json.encode(data.beforeState) or nil,
        data.afterState and json.encode(data.afterState) or nil,
        data.metadata and json.encode(data.metadata) or nil,
    })
end
