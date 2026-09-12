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
function Repo.prune(olderThan, limit)
    return Db.update('DELETE FROM noir_outpost_operations WHERE created_at < ? LIMIT ?', { olderThan, limit })
end
