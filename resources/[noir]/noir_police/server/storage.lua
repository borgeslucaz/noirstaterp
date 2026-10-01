---Único ponto de SQL do resource. Só toca as tabelas `noir_police_*`.

local Storage = {}

local ready = false

local MIGRATIONS = { 'migrations/001_initial.sql', 'migrations/002_layout.sql', 'migrations/003_dna.sql',
    'migrations/004_seizure_bonus.sql' }

---Roda as migrations em ordem. Só `CREATE TABLE IF NOT EXISTS` é aceito.
function Storage.migrate()
    for _, file in ipairs(MIGRATIONS) do
        local sql = LoadResourceFile(GetCurrentResourceName(), file)
        if not sql or sql == '' then error(('%s não encontrada'):format(file)) end
        sql = sql:gsub('%-%-[^\n]*', '')
        for raw in sql:gmatch('([^;]+);') do
            local statement = raw:match('^%s*(.-)%s*$')
            if statement ~= '' then
                if not statement:upper():match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+') then
                    error(('comando não permitido na migration: %s'):format(statement:sub(1, 80)))
                end
                MySQL.query.await(statement)
            end
        end
    end
    ready = true
end

function Storage.isReady() return ready end

-- Pendências -------------------------------------------------------------------------

---@return integer? id
function Storage.addSeizure(entry)
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO noir_police_seizures (officer_cid, target_cid, department, item, count, serial, coords)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { entry.officer, entry.target, entry.department, entry.item, entry.count, entry.serial, entry.coords })
    return ok and id or nil
end

---@return { id: integer, target_cid: string, item: string, count: integer, created_at: any }[]
function Storage.pendingByOfficer(officerCid)
    return MySQL.query.await([[
        SELECT id, target_cid, item, count, serial, created_at FROM noir_police_seizures
        WHERE officer_cid = ? AND status = 'pending' ORDER BY id LIMIT 500
    ]], { officerCid }) or {}
end

---@param ids integer[]
---@param depositId integer
function Storage.resolveSeizures(ids, depositId)
    if #ids == 0 then return end
    MySQL.update.await([[
        UPDATE noir_police_seizures SET status = 'deposited', deposit_id = ?, resolved_at = CURRENT_TIMESTAMP
        WHERE id IN (?) AND status = 'pending'
    ]], { depositId, ids })
end

---Pendências vencidas: viram 'flagged' (desvio) uma vez só.
---@param hours integer
---@return table[] rows
function Storage.flagOverdue(hours)
    local rows = MySQL.query.await([[
        SELECT id, officer_cid, target_cid, department, item, count, serial, created_at FROM noir_police_seizures
        WHERE status = 'pending' AND created_at < (CURRENT_TIMESTAMP - INTERVAL ? HOUR) LIMIT 200
    ]], { hours }) or {}
    local ids = {}
    for index = 1, #rows do ids[index] = rows[index].id end
    if #ids > 0 then
        MySQL.update.await("UPDATE noir_police_seizures SET status = 'flagged' WHERE id IN (?) AND status = 'pending'", { ids })
    end
    return rows
end

-- Depósitos --------------------------------------------------------------------------

---@return integer? id, string? err
function Storage.addDeposit(entry)
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO noir_police_deposits (box_id, department, officer_cid, target_cid, reason, contents, unmatched)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { entry.boxId, entry.department, entry.officer, entry.target, entry.reason,
        json.encode(entry.contents), json.encode(entry.unmatched or {}) })
    if not ok then
        return nil, tostring(id):find('Duplicate', 1, true) and 'box_already_deposited' or 'storage_failed'
    end
    return id
end

---@return boolean
function Storage.boxDeposited(boxId)
    return MySQL.scalar.await('SELECT 1 FROM noir_police_deposits WHERE box_id = ? LIMIT 1', { boxId }) ~= nil
end

---@return table[] rows
function Storage.storedDeposits(department)
    return MySQL.query.await([[
        SELECT id, officer_cid, target_cid, reason, contents, unmatched, created_at FROM noir_police_deposits
        WHERE department = ? AND status = 'stored' ORDER BY id DESC LIMIT 100
    ]], { department }) or {}
end

---@return table? row
function Storage.getDeposit(id)
    return MySQL.single.await([[
        SELECT id, department, officer_cid, target_cid, contents, unmatched, status FROM noir_police_deposits WHERE id = ?
    ]], { id })
end

---Fecha o depósito só se ainda estiver guardado. Devolve true para quem ganhou a corrida.
---@return boolean
function Storage.resolveDeposit(id, status, resolvedBy)
    local affected = MySQL.update.await([[
        UPDATE noir_police_deposits SET status = ?, resolved_by = ?, resolved_at = CURRENT_TIMESTAMP
        WHERE id = ? AND status = 'stored'
    ]], { status, resolvedBy, id })
    return type(affected) == 'number' and affected > 0
end

-- Bônus de apreensão -------------------------------------------------------------------

---Quanto o policial já ganhou de bônus na última hora (pago ou a receber).
---@return integer
function Storage.bonusLastHour(officerCid)
    return math.tointeger(tonumber(MySQL.scalar.await([[
        SELECT COALESCE(SUM(amount), 0) FROM noir_police_seizure_bonus
        WHERE officer_cid = ? AND created_at >= NOW() - INTERVAL 1 HOUR
    ]], { officerCid })) or 0) or 0
end

---Registra o bônus do depósito. false quando o depósito já tinha bônus.
---@return boolean
function Storage.addBonus(depositId, officerCid, amount, baseValue)
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO noir_police_seizure_bonus (deposit_id, officer_cid, amount, base_value) VALUES (?, ?, ?, ?)
    ]], { depositId, officerCid, amount, baseValue })
    return ok and id ~= nil
end

---Marca um bônus como pago. true só para quem ganhou a corrida.
---@return boolean
function Storage.markBonusPaid(depositId)
    local affected = MySQL.update.await([[
        UPDATE noir_police_seizure_bonus SET paid = 1, paid_at = CURRENT_TIMESTAMP WHERE deposit_id = ? AND paid = 0
    ]], { depositId })
    return type(affected) == 'number' and affected > 0
end

---Volta um bônus para "a receber" (o crédito no banco falhou).
function Storage.unmarkBonusPaid(depositId)
    MySQL.update.await('UPDATE noir_police_seizure_bonus SET paid = 0, paid_at = NULL WHERE deposit_id = ?', { depositId })
end

---@return { deposit_id: integer, amount: integer }[]
function Storage.owedBonuses(officerCid)
    return MySQL.query.await([[
        SELECT deposit_id, amount FROM noir_police_seizure_bonus WHERE officer_cid = ? AND paid = 0 ORDER BY deposit_id
    ]], { officerCid }) or {}
end

---Volta um depósito para 'stored' (compensação quando a entrega do item falha).
function Storage.reopenDeposit(id)
    MySQL.update.await("UPDATE noir_police_deposits SET status = 'stored', resolved_by = NULL, resolved_at = NULL WHERE id = ?", { id })
end

-- Layout -----------------------------------------------------------------------------

---@return table<string, string> kind -> json
function Storage.loadLayout()
    local rows = MySQL.query.await('SELECT kind, data FROM noir_police_layout') or {}
    local map = {}
    for index = 1, #rows do map[rows[index].kind] = rows[index].data end
    return map
end

function Storage.saveLayout(kind, data, updatedBy)
    MySQL.insert.await([[
        INSERT INTO noir_police_layout (kind, data, updated_by) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)
    ]], { kind, data, updatedBy })
end

function Storage.deleteLayout(kind)
    MySQL.update.await('DELETE FROM noir_police_layout WHERE kind = ?', { kind })
end

-- Banco de DNA ---------------------------------------------------------------------

function Storage.registerDna(code, citizenId, takenBy)
    MySQL.insert.await([[
        INSERT INTO noir_police_dna (dna_code, citizen_id, taken_by) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE taken_by = VALUES(taken_by), taken_at = CURRENT_TIMESTAMP
    ]], { code, citizenId, takenBy })
end

---@return string? citizenId
function Storage.findDna(code)
    return MySQL.scalar.await('SELECT citizen_id FROM noir_police_dna WHERE dna_code = ? LIMIT 1', { code })
end

-- Placas marcadas --------------------------------------------------------------------

---@return table<string, table>
function Storage.loadFlaggedPlates()
    local rows = MySQL.query.await('SELECT plate, reason, officer_cid FROM noir_police_flagged_plates') or {}
    local map = {}
    for index = 1, #rows do map[rows[index].plate] = rows[index] end
    return map
end

function Storage.flagPlate(plate, reason, officerCid)
    MySQL.insert.await([[
        INSERT INTO noir_police_flagged_plates (plate, reason, officer_cid) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE reason = VALUES(reason), officer_cid = VALUES(officer_cid)
    ]], { plate, reason, officerCid })
end

function Storage.unflagPlate(plate)
    MySQL.update.await('DELETE FROM noir_police_flagged_plates WHERE plate = ?', { plate })
end

return Storage
