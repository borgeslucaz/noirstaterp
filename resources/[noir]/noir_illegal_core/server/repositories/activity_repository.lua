local Repository = {}
NoirIllegal.Repositories.Activity = Repository

function Repository.findByTransaction(transactionId, query, forUpdate)
    local suffix = forUpdate and ' FOR UPDATE' or ''
    return NoirIllegal.Database.single(query, ([[
        SELECT transaction_id, activity_key, caller_resource, citizenid,
               organization_id, status, rejection_code, result_payload
        FROM noir_illegal_activity_ledger
        WHERE transaction_id = ?%s
    ]]):format(suffix), { transactionId })
end

function Repository.countAccepted(citizenId, organizationId, activityKey, windowSeconds, keyMode, query)
    local sql, parameters
    if keyMode == 'organization:activity' and organizationId then
        sql = [[
            SELECT COUNT(*) AS count FROM noir_illegal_activity_ledger
            WHERE status = 'accepted' AND organization_id = ? AND activity_key = ?
              AND occurred_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND)
        ]]
        parameters = { organizationId, activityKey, windowSeconds }
    else
        sql = [[
            SELECT COUNT(*) AS count FROM noir_illegal_activity_ledger
            WHERE status = 'accepted' AND citizenid = ? AND activity_key = ?
              AND occurred_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND)
        ]]
        parameters = { citizenId, activityKey, windowSeconds }
    end
    local row = NoirIllegal.Database.single(query, sql, parameters)
    return tonumber(row and row.count) or 0
end

function Repository.insert(data, query)
    NoirIllegal.Database.execute(query, [[
        INSERT INTO noir_illegal_activity_ledger (
            transaction_id, activity_key, caller_resource, citizenid, organization_id,
            status, rejection_code, base_personal, applied_personal,
            base_organization, applied_organization, base_heat, applied_heat,
            diminishing_multiplier, metadata, result_payload, occurred_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], {
        data.transactionId, data.activityKey, data.callerResource, data.citizenId,
        data.organizationId, data.status, data.rejectionCode,
        json.encode(data.basePersonal or {}), json.encode(data.appliedPersonal or {}),
        json.encode(data.baseOrganization or {}), json.encode(data.appliedOrganization or {}),
        data.baseHeat or 0, data.appliedHeat or 0, data.multiplier or 1,
        json.encode(data.metadata or {}), json.encode(data.resultPayload or {}),
        data.occurredAt,
    })
end
