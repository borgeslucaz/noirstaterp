NoirOutposts = NoirOutposts or {}
NoirOutposts.Repositories = NoirOutposts.Repositories or {}

local Repo = {}
NoirOutposts.Repositories.Operation = Repo

local Db = NoirOutposts.Db

---@param op table { id, type, outpostId, dealerId?, citizenId?, organizationId?, item?, quantity?, gross?, net?, status, requestId?, payload?, createdAt, committedAt? }
---@return boolean ok
function Repo.insert(op)
    local id = Db.insert([[
        INSERT INTO noir_outpost_operations
            (operation_id, operation_type, outpost_id, dealer_id, citizenid, organization_id, item_name, quantity,
             gross_amount, net_amount, status, request_id, payload, created_at, committed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        op.id, op.type, op.outpostId, op.dealerId, op.citizenId, op.organizationId, op.item, op.quantity,
        op.gross, op.net, op.status, op.requestId, op.payload and json.encode(op.payload) or nil,
        op.createdAt, op.committedAt,
    })
    return id ~= nil
end

---@param operationId string
---@param status string
---@param committedAt? integer
---@param payload? table
function Repo.setStatus(operationId, status, committedAt, payload)
    if payload then
        return Db.update(
            'UPDATE noir_outpost_operations SET status = ?, committed_at = ?, payload = ? WHERE operation_id = ?',
            { status, committedAt, json.encode(payload), operationId })
    end
    return Db.update('UPDATE noir_outpost_operations SET status = ?, committed_at = ? WHERE operation_id = ?',
        { status, committedAt, operationId })
end

---@param outpostId string
---@param limit integer
---@return table[]
function Repo.recent(outpostId, limit)
    return Db.rows([[
        SELECT operation_id, operation_type, dealer_id, citizenid, item_name, quantity, gross_amount, net_amount,
               status, created_at
        FROM noir_outpost_operations
        WHERE outpost_id = ? AND status IN ('committed', 'paid')
        ORDER BY created_at DESC, operation_id DESC
        LIMIT ?
    ]], { outpostId, limit }) or {}
end

---Página do feed de uma organização, mais recente primeiro.
---Paginação por keyset: o cursor é a última linha vista, então inserções concorrentes
---não deslocam a janela como o OFFSET faria.
---@param organizationId string
---@param limit integer
---@param cursor table? { at: integer, id: string }
---@param since integer? só entrega o que veio depois de o jogador limpar o feed
---@return table[] rows (até limit + 1, para saber se há próxima página)
function Repo.feed(organizationId, limit, cursor, since)
    local sql = [[
        SELECT operation_id, operation_type, outpost_id, dealer_id, item_name, quantity,
               gross_amount, net_amount, payload, created_at
        FROM noir_outpost_operations
        WHERE organization_id = ? AND status IN ('committed', 'paid')
    ]]
    local parameters = { organizationId }

    if since and since > 0 then
        sql = sql .. ' AND created_at > ?'
        parameters[#parameters + 1] = since
    end

    if cursor then
        sql = sql .. ' AND (created_at < ? OR (created_at = ? AND operation_id < ?))'
        parameters[#parameters + 1] = cursor.at
        parameters[#parameters + 1] = cursor.at
        parameters[#parameters + 1] = cursor.id
    end

    sql = sql .. ' ORDER BY created_at DESC, operation_id DESC LIMIT ?'
    parameters[#parameters + 1] = limit + 1

    return Db.rows(sql, parameters) or {}
end

---@param citizenId string
---@param requestId string
---@return table?
function Repo.findByRequest(citizenId, requestId)
    return Db.single([[
        SELECT operation_id, operation_type, status, net_amount, quantity, item_name
        FROM noir_outpost_operations
        WHERE citizenid = ? AND request_id = ?
        ORDER BY created_at DESC LIMIT 1
    ]], { citizenId, requestId })
end

---Operações mais antigas que `olderThan` (retenção).
---@param olderThan integer epoch
---@param limit integer
---@return integer? affectedRows, string? error
function Repo.prune(olderThan, limit)
    return Db.update(
        'DELETE FROM noir_outpost_operations WHERE created_at < ? ORDER BY created_at ASC LIMIT ?',
        { olderThan, limit })
end
