NoirOutposts = NoirOutposts or {}
NoirOutposts.Repositories = NoirOutposts.Repositories or {}

local Repo = {}
NoirOutposts.Repositories.Outpost = Repo

local Db = NoirOutposts.Db
local S = NoirOutposts.Constants.OutpostStatus

local COLUMNS = table.concat({
    'id', 'status', 'operation_type', 'rotation_id', 'owner_organization_id', 'kingpin_citizenid',
    'claimed_at', 'expires_at', 'claim_session_id', 'claim_organization_id', 'claim_started_at',
    'purse_available', 'purse_pending', 'last_corner_rotation_at', 'expiry_warned_at', 'version',
}, ', ')

---@param ids string[]
function Repo.ensureRows(ids)
    for index = 1, #ids do
        Db.insert('INSERT IGNORE INTO noir_outposts (id, status) VALUES (?, ?)', { ids[index], S.INACTIVE })
    end
end

---@return table[]
function Repo.getAll()
    return Db.rows(('SELECT %s FROM noir_outposts'):format(COLUMNS)) or {}
end

---@param id string
---@return table?
function Repo.get(id)
    return Db.single(('SELECT %s FROM noir_outposts WHERE id = ?'):format(COLUMNS), { id })
end

---Reseta claims em andamento (sessões vivem apenas em memória).
function Repo.resetStaleClaims()
    return Db.update([[
        UPDATE noir_outposts
        SET status = ?, claim_session_id = NULL, claim_organization_id = NULL, claim_started_at = NULL,
            version = version + 1
        WHERE status = ?
    ]], { S.AVAILABLE, S.CLAIMING })
end

---@param id string
---@param operationType string
---@param rotationId integer
function Repo.activate(id, operationType, rotationId)
    return Db.update([[
        UPDATE noir_outposts
        SET status = ?, operation_type = ?, rotation_id = ?, owner_organization_id = NULL,
            kingpin_citizenid = NULL, claimed_at = NULL, expires_at = NULL, claim_session_id = NULL,
            claim_organization_id = NULL, claim_started_at = NULL, purse_available = 0, purse_pending = 0,
            last_corner_rotation_at = NULL, expiry_warned_at = NULL, version = version + 1
        WHERE id = ?
    ]], { S.AVAILABLE, operationType, rotationId, id })
end

---@param id string
function Repo.deactivate(id)
    return Db.update([[
        UPDATE noir_outposts
        SET status = ?, operation_type = NULL, rotation_id = NULL, owner_organization_id = NULL,
            kingpin_citizenid = NULL, claimed_at = NULL, expires_at = NULL, claim_session_id = NULL,
            claim_organization_id = NULL, claim_started_at = NULL, purse_available = 0, purse_pending = 0,
            last_corner_rotation_at = NULL, expiry_warned_at = NULL, version = version + 1
        WHERE id = ?
    ]], { S.INACTIVE, id })
end

---Libera o controle (expiração/admin) mantendo o outpost ativo.
---@param id string
function Repo.release(id)
    return Db.update([[
        UPDATE noir_outposts
        SET status = ?, owner_organization_id = NULL, kingpin_citizenid = NULL, claimed_at = NULL,
            expires_at = NULL, claim_session_id = NULL, claim_organization_id = NULL, claim_started_at = NULL,
            purse_available = 0, purse_pending = 0, last_corner_rotation_at = NULL, expiry_warned_at = NULL,
            version = version + 1
        WHERE id = ? AND status IN (?, ?)
    ]], { S.AVAILABLE, id, S.CONTROLLED, S.CLAIMING })
end

---@param id string
---@param sessionId string
---@param organizationId string
---@param now integer
---@return integer? affected
function Repo.startClaim(id, sessionId, organizationId, now)
    return Db.update([[
        UPDATE noir_outposts
        SET status = ?, claim_session_id = ?, claim_organization_id = ?, claim_started_at = ?,
            version = version + 1
        WHERE id = ? AND status = ?
    ]], { S.CLAIMING, sessionId, organizationId, now, id, S.AVAILABLE })
end

---@param id string
---@param sessionId string
---@return integer? affected
function Repo.cancelClaim(id, sessionId)
    return Db.update([[
        UPDATE noir_outposts
        SET status = ?, claim_session_id = NULL, claim_organization_id = NULL, claim_started_at = NULL,
            version = version + 1
        WHERE id = ? AND status = ? AND claim_session_id = ?
    ]], { S.AVAILABLE, id, S.CLAIMING, sessionId })
end

---@param id string
---@param sessionId string
---@param organizationId string
---@param citizenId string
---@param now integer
---@param expiresAt integer
---@return integer? affected
function Repo.completeClaim(id, sessionId, organizationId, citizenId, now, expiresAt)
    return Db.update([[
        UPDATE noir_outposts
        SET status = ?, owner_organization_id = ?, kingpin_citizenid = ?, claimed_at = ?, expires_at = ?,
            claim_session_id = NULL, claim_organization_id = NULL, claim_started_at = NULL,
            purse_available = 0, purse_pending = 0, last_corner_rotation_at = ?, expiry_warned_at = NULL,
            version = version + 1
        WHERE id = ? AND status = ? AND claim_session_id = ?
    ]], { S.CONTROLLED, organizationId, citizenId, now, expiresAt, now, id, S.CLAIMING, sessionId })
end

---@param id string
---@param organizationId string
---@param amount integer
---@return integer? affected
function Repo.movePurseToPending(id, organizationId, amount)
    return Db.update([[
        UPDATE noir_outposts
        SET purse_available = purse_available - ?, purse_pending = purse_pending + ?, version = version + 1
        WHERE id = ? AND status = ? AND owner_organization_id = ? AND purse_available >= ?
    ]], { amount, amount, id, S.CONTROLLED, organizationId, amount })
end

---@param id string
---@param amount integer
function Repo.settlePending(id, amount)
    return Db.update([[
        UPDATE noir_outposts
        SET purse_pending = purse_pending - ?, version = version + 1
        WHERE id = ? AND purse_pending >= ?
    ]], { amount, id, amount })
end

---@param id string
---@param amount integer
function Repo.restorePending(id, amount)
    return Db.update([[
        UPDATE noir_outposts
        SET purse_pending = purse_pending - ?, purse_available = purse_available + ?, version = version + 1
        WHERE id = ? AND purse_pending >= ?
    ]], { amount, amount, id, amount })
end

---@param id string
---@param amount integer
function Repo.restorePurse(id, amount)
    return Db.update([[
        UPDATE noir_outposts
        SET purse_available = purse_available + ?, version = version + 1
        WHERE id = ?
    ]], { amount, id })
end

---@param id string
---@param now integer
function Repo.setCornerRotation(id, now)
    return Db.update('UPDATE noir_outposts SET last_corner_rotation_at = ? WHERE id = ?', { now, id })
end

---@param id string
---@param now integer
function Repo.setExpiryWarned(id, now)
    return Db.update('UPDATE noir_outposts SET expiry_warned_at = ? WHERE id = ?', { now, id })
end

-- Organizações -----------------------------------------------------------------------

---@param organizationId string
---@return table?
function Repo.getOrganization(organizationId)
    return Db.single(
        'SELECT organization_id, claim_cooldown_until, last_claim_at FROM noir_outpost_organizations WHERE organization_id = ?',
        { organizationId })
end

---@param organizationId string
---@param cooldownUntil integer
---@param lastClaimAt? integer
function Repo.setOrganizationCooldown(organizationId, cooldownUntil, lastClaimAt)
    return Db.insert([[
        INSERT INTO noir_outpost_organizations (organization_id, claim_cooldown_until, last_claim_at)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE claim_cooldown_until = VALUES(claim_cooldown_until),
            last_claim_at = COALESCE(VALUES(last_claim_at), last_claim_at)
    ]], { organizationId, cooldownUntil, lastClaimAt })
end
