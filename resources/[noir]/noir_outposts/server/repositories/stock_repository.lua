NoirOutposts = NoirOutposts or {}
NoirOutposts.Repositories = NoirOutposts.Repositories or {}

local Repo = {}
NoirOutposts.Repositories.Stock = Repo

local Db = NoirOutposts.Db

---@param outpostId string
---@return table[] rows { item_name, quantity }
function Repo.listByOutpost(outpostId)
    return Db.rows('SELECT item_name, quantity FROM noir_outpost_stock WHERE outpost_id = ?', { outpostId }) or {}
end

---@return table[] rows { outpost_id, item_name, quantity }
function Repo.listAll()
    return Db.rows('SELECT outpost_id, item_name, quantity FROM noir_outpost_stock') or {}
end

---Garante uma linha por produto (quantidade zero) para permitir UPDATEs condicionais.
---@param outpostId string
---@param items string[]
function Repo.ensureProducts(outpostId, items)
    for index = 1, #items do
        Db.insert('INSERT IGNORE INTO noir_outpost_stock (outpost_id, item_name, quantity) VALUES (?, ?, 0)',
            { outpostId, items[index] })
    end
end

---Depósito condicionado ao limite total do outpost.
---@param outpostId string
---@param item string
---@param amount integer
---@param maxTotal integer
---@return boolean applied
function Repo.deposit(outpostId, item, amount, maxTotal)
    local affected = Db.update([[
        UPDATE noir_outpost_stock s
        JOIN (SELECT COALESCE(SUM(quantity), 0) AS total FROM noir_outpost_stock WHERE outpost_id = ?) totals
        SET s.quantity = s.quantity + ?
        WHERE s.outpost_id = ? AND s.item_name = ? AND totals.total + ? <= ?
    ]], { outpostId, amount, outpostId, item, amount, maxTotal })
    return (affected or 0) > 0
end

---Compensação (devolve unidades ao estoque após falha de entrega).
---@param outpostId string
---@param item string
---@param amount integer
function Repo.restore(outpostId, item, amount)
    return Db.update([[
        UPDATE noir_outpost_stock SET quantity = quantity + ? WHERE outpost_id = ? AND item_name = ?
    ]], { amount, outpostId, item })
end

---@param outpostId string
function Repo.clearByOutpost(outpostId)
    return Db.update('DELETE FROM noir_outpost_stock WHERE outpost_id = ?', { outpostId })
end
