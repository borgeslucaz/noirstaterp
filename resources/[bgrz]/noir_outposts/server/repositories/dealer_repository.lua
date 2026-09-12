NoirOutposts = NoirOutposts or {}
NoirOutposts.Repositories = NoirOutposts.Repositories or {}

local Repo = {}
NoirOutposts.Repositories.Dealer = Repo

local Db = NoirOutposts.Db
local D = NoirOutposts.Constants.DealerStatus
local S = NoirOutposts.Constants.OutpostStatus

local COLUMNS = table.concat({
    'id', 'outpost_id', 'profile_key', 'display_name', 'ped_model', 'status', 'corner_index',
    'hired_by_citizenid', 'hired_at',
    'next_sale_at', 'robbed_until', 'lifetime_sales', 'lifetime_gross', 'version',
}, ', ')

---@return table[]
function Repo.listAll()
    return Db.rows(('SELECT %s FROM noir_outpost_dealers ORDER BY id'):format(COLUMNS)) or {}
end

---@param outpostId string
---@return table[]
function Repo.listByOutpost(outpostId)
    return Db.rows(('SELECT %s FROM noir_outpost_dealers WHERE outpost_id = ? ORDER BY id'):format(COLUMNS),
        { outpostId }) or {}
end

---@param dealerId integer
---@return table?
function Repo.get(dealerId)
    return Db.single(('SELECT %s FROM noir_outpost_dealers WHERE id = ?'):format(COLUMNS), { dealerId })
end

---Insere respeitando o limite por outpost e o perfil único (falha silenciosa retorna nil).
---@param dealer table { outpostId, profileKey, displayName, pedModel, cornerIndex, hiredBy, hiredAt, nextSaleAt }
---@param maxDealers integer
---@return integer? insertId
function Repo.insert(dealer, maxDealers)
    local id = Db.insert([[
        INSERT INTO noir_outpost_dealers
            (outpost_id, profile_key, display_name, ped_model, status, corner_index,
             hired_by_citizenid, hired_at, next_sale_at)
        SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?
        FROM (SELECT COUNT(*) AS total FROM noir_outpost_dealers WHERE outpost_id = ?) counted
        WHERE counted.total < ?
    ]], {
        dealer.outpostId, dealer.profileKey, dealer.displayName, dealer.pedModel,
        D.DEPLOYED, dealer.cornerIndex, dealer.hiredBy,
        dealer.hiredAt, dealer.nextSaleAt, dealer.outpostId, maxDealers,
    })
    if not id or id == 0 then return nil end
    return id
end

---@param dealerId integer
---@return integer? affected
function Repo.delete(dealerId)
    return Db.update('DELETE FROM noir_outpost_dealers WHERE id = ?', { dealerId })
end

---@param outpostId string
function Repo.deleteByOutpost(outpostId)
    return Db.update('DELETE FROM noir_outpost_dealers WHERE outpost_id = ?', { outpostId })
end

---@param dealerId integer
---@param cornerIndex integer
function Repo.setCorner(dealerId, cornerIndex)
    return Db.update('UPDATE noir_outpost_dealers SET corner_index = ? WHERE id = ?', { cornerIndex, dealerId })
end

---Reagenda a próxima venda sem alterar estoque/carteira (dealer bloqueado por regra de negócio).
---@param dealerId integer
---@param nextSaleAt integer
function Repo.reschedule(dealerId, nextSaleAt)
    return Db.update('UPDATE noir_outpost_dealers SET next_sale_at = ? WHERE id = ?', { nextSaleAt, dealerId })
end

---Dealer em recuperação volta a operar quando o cooldown expira.
---@param dealerId integer
---@param now integer
---@param nextSaleAt integer
---@return integer? affected
function Repo.recover(dealerId, now, nextSaleAt)
    return Db.update([[
        UPDATE noir_outpost_dealers
        SET status = ?, next_sale_at = ?, version = version + 1
        WHERE id = ? AND status = ? AND robbed_until IS NOT NULL AND robbed_until <= ?
    ]], { D.DEPLOYED, nextSaleAt, dealerId, D.RECOVERING, now })
end

---Encerra o cooldown de um corredor em recuperação, para uso administrativo.
---@param dealerId integer
---@param now integer
---@return boolean applied
function Repo.expireRecovery(dealerId, now)
    local affected = Db.update([[
        UPDATE noir_outpost_dealers SET robbed_until = ?
        WHERE id = ? AND status = ?
    ]], { now - 1, dealerId, D.RECOVERING })
    return (affected or 0) > 0
end

---Corredor derrubado: sai de operação sem tocar em carteira nem estoque.
---@param dealerId integer
---@param dealerVersion integer
---@param downUntil integer
---@param nextSaleAt integer
---@return boolean applied
function Repo.markDown(dealerId, dealerVersion, downUntil, nextSaleAt)
    local affected = Db.update([[
        UPDATE noir_outpost_dealers
        SET status = ?, robbed_until = ?, next_sale_at = ?, version = version + 1
        WHERE id = ? AND status = ? AND version = ?
    ]], { D.RECOVERING, downUntil, nextSaleAt, dealerId, D.DEPLOYED, dealerVersion })
    return (affected or 0) > 0
end

---Venda atômica: estoque, carteira e agenda em um único statement condicional.
---@param sale table { dealerId, dealerVersion, outpostId, organizationId, item, quantity, net, gross, nextSaleAt, now }
---@return boolean applied
function Repo.applySale(sale)
    local affected = Db.update([[
        UPDATE noir_outpost_stock s
        JOIN noir_outposts o ON o.id = s.outpost_id
        JOIN noir_outpost_dealers d ON d.outpost_id = o.id AND d.id = ?
        SET s.quantity = s.quantity - ?,
            o.purse_available = o.purse_available + ?,
            o.version = o.version + 1,
            d.next_sale_at = ?,
            d.lifetime_sales = d.lifetime_sales + 1,
            d.lifetime_gross = d.lifetime_gross + ?,
            d.version = d.version + 1
        WHERE s.outpost_id = ? AND s.item_name = ? AND s.quantity >= ?
            AND o.status = ? AND o.owner_organization_id = ? AND (o.expires_at IS NULL OR o.expires_at > ?)
            AND d.status = ? AND d.version = ?
    ]], {
        sale.dealerId, sale.quantity, sale.net, sale.nextSaleAt, sale.gross,
        sale.outpostId, sale.item, sale.quantity,
        S.CONTROLLED, sale.organizationId, sale.now,
        D.DEPLOYED, sale.dealerVersion,
    })
    return (affected or 0) > 0
end

---Roubo atômico: debita carteira (e opcionalmente estoque) e coloca o dealer em recuperação.
---@param robbery table { dealerId, dealerVersion, outpostId, purseLoot, item?, stockLoot, robbedUntil, nextSaleAt }
---@return boolean applied
function Repo.applyRobbery(robbery)
    local affected
    if robbery.item and robbery.stockLoot > 0 then
        affected = Db.update([[
            UPDATE noir_outposts o
            JOIN noir_outpost_dealers d ON d.outpost_id = o.id AND d.id = ?
            JOIN noir_outpost_stock s ON s.outpost_id = o.id AND s.item_name = ?
            SET o.purse_available = o.purse_available - ?,
                o.version = o.version + 1,
                d.status = ?, d.robbed_until = ?, d.next_sale_at = ?, d.version = d.version + 1,
                s.quantity = s.quantity - ?
            WHERE o.id = ? AND o.status = ? AND o.purse_available >= ?
                AND d.status = ? AND d.version = ?
                AND s.quantity >= ?
        ]], {
            robbery.dealerId, robbery.item, robbery.purseLoot,
            D.RECOVERING, robbery.robbedUntil, robbery.nextSaleAt, robbery.stockLoot,
            robbery.outpostId, S.CONTROLLED, robbery.purseLoot,
            D.DEPLOYED, robbery.dealerVersion, robbery.stockLoot,
        })
    else
        affected = Db.update([[
            UPDATE noir_outposts o
            JOIN noir_outpost_dealers d ON d.outpost_id = o.id AND d.id = ?
            SET o.purse_available = o.purse_available - ?,
                o.version = o.version + 1,
                d.status = ?, d.robbed_until = ?, d.next_sale_at = ?, d.version = d.version + 1
            WHERE o.id = ? AND o.status = ? AND o.purse_available >= ?
                AND d.status = ? AND d.version = ?
        ]], {
            robbery.dealerId, robbery.purseLoot,
            D.RECOVERING, robbery.robbedUntil, robbery.nextSaleAt,
            robbery.outpostId, S.CONTROLLED, robbery.purseLoot,
            D.DEPLOYED, robbery.dealerVersion,
        })
    end
    return (affected or 0) > 0
end
