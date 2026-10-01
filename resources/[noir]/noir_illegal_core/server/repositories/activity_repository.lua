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

---Soma do ganho positivo em `gang` de uma organização na janela (uma activity, ou todas).
---@return number
function Repository.sumOrganizationGain(organizationId, activityKey, windowSeconds, query)
    local filter = activityKey and ' AND activity_key = ?' or ''
    local parameters = { organizationId }
    if activityKey then parameters[#parameters + 1] = activityKey end
    parameters[#parameters + 1] = windowSeconds
    local row = NoirIllegal.Database.single(query, ([[
        SELECT COALESCE(SUM(GREATEST(CAST(JSON_UNQUOTE(JSON_EXTRACT(applied_organization, '$.gang'))
            AS DECIMAL(12,4)), 0)), 0) AS total
        FROM noir_illegal_activity_ledger
        WHERE status = 'accepted' AND organization_id = ?%s
          AND occurred_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND)
    ]]):format(filter), parameters)
    return tonumber(row and row.total) or 0
end

---Já houve registro aceito desta activity para a organização com este valor de metadata na
---janela? É o que impede a gang de retomar o próprio outpost e ganhar de novo.
---@return boolean
function Repository.recentForOrganization(organizationId, activityKey, metadataKey, metadataValue, windowSeconds, query)
    local row = NoirIllegal.Database.single(query, [[
        SELECT 1 AS found FROM noir_illegal_activity_ledger
        WHERE status = 'accepted' AND organization_id = ? AND activity_key = ?
          AND JSON_UNQUOTE(JSON_EXTRACT(metadata, ?)) = ?
          AND occurred_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? SECOND)
        LIMIT 1
    ]], { organizationId, activityKey, '$.' .. metadataKey, tostring(metadataValue), windowSeconds })
    return row ~= nil
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
