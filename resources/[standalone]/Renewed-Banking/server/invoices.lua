-- PATCH NOIR: faturas e multas no banco (ver PATCHES-NOIR.md, item 9).
--
-- Uma fatura é uma cobrança pendente: o dinheiro só sai quando o devedor paga, pelo banco ou
-- pelo app Faturas do celular (que lê e paga daqui). Multa (`kind = 'fine'`) é uma fatura que
-- **bloqueia**: com multa aberta, a conta pessoal não saca nem transfere.
--
-- O pagamento cai numa conta de organização do próprio banco (`issuer_account`), com
-- lançamento nos dois extratos. Por isso uma fatura só pode ser emitida para uma conta que o
-- banco conhece (job, gang ou compartilhada).
--
-- Formato de saída (`dto`) é o mesmo do app Faturas do sky_phone, para o celular exibir sem
-- tradução.

-- Lido na hora do uso: o main.lua faz `await` no banco de dados antes de definir o
-- NoirBankInternal, e este arquivo carrega nesse intervalo.
local Internal = setmetatable({}, {
    __index = function(_, key) return NoirBankInternal and NoirBankInternal[key] end,
})

local PAGE_SIZE = 30
local URGENT_LIMIT = 5
local MIN_AMOUNT, MAX_AMOUNT = 1, 1000000
local DEFAULT_DUE_DAYS = 7
local KINDS = { fine = true, invoice = true }

local ready = false

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bank_invoices` (
            `id` CHAR(36) NOT NULL,
            `recipient_cid` VARCHAR(64) NOT NULL,
            `issuer_cid` VARCHAR(64) NULL,
            `issuer_account` VARCHAR(64) NOT NULL,
            `issuer_label` VARCHAR(80) NOT NULL,
            `kind` VARCHAR(16) NOT NULL DEFAULT 'invoice',
            `blocking` TINYINT(1) NOT NULL DEFAULT 0,
            `title` VARCHAR(160) NOT NULL,
            `description` VARCHAR(1000) NOT NULL DEFAULT '',
            `amount` INT UNSIGNED NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'open',
            `read_at` TIMESTAMP NULL DEFAULT NULL,
            `due_at` TIMESTAMP NULL DEFAULT NULL,
            `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `paid_at` TIMESTAMP NULL DEFAULT NULL,
            `payment_reference` VARCHAR(64) NULL,
            `closed_by` VARCHAR(64) NULL,
            PRIMARY KEY (`id`),
            KEY `idx_bank_invoices_recipient` (`recipient_cid`, `status`),
            KEY `idx_bank_invoices_issuer` (`issuer_cid`, `status`)
        ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci
    ]])
    ready = true
end)

-- Utilidades -------------------------------------------------------------------------

local function uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return ('%x'):format(v)
    end))
end

local function trimmed(value, maximum)
    if type(value) ~= 'string' then return nil end
    local result = value:match('^%s*(.-)%s*$')
    if result == '' or #result > maximum then return nil end
    return result
end

local function validAmount(value)
    local amount = tonumber(value)
    if not amount or amount ~= amount or amount % 1 ~= 0 then return nil end
    if amount < MIN_AMOUNT or amount > MAX_AMOUNT then return nil end
    return math.floor(amount)
end

local function validId(value)
    return type(value) == 'string' and #value == 36 and value:match('^[0-9a-fA-F%-]+$') ~= nil
end

local function affected(result)
    if type(result) == 'number' then return result end
    return type(result) == 'table' and tonumber(result.affectedRows) or 0
end

local SELECT = [[
    SELECT `id`, `recipient_cid`, `issuer_cid`, `issuer_account`, `issuer_label`, `kind`, `blocking`,
        `title`, `description`, `amount`, `status`, `read_at`, `payment_reference`,
        UNIX_TIMESTAMP(`issued_at`) AS `issued_at_unix`,
        UNIX_TIMESTAMP(`due_at`) AS `due_at_unix`,
        UNIX_TIMESTAMP(`paid_at`) AS `paid_at_unix`
    FROM `bank_invoices`
]]

local function query(where, params)
    return MySQL.query.await(SELECT .. ' WHERE ' .. where, params) or {}
end

---Formato do app Faturas do sky_phone (datas em milissegundos).
local function dto(row, cid)
    local due = tonumber(row.due_at_unix)
    local paid = tonumber(row.paid_at_unix)
    local direction = row.recipient_cid == cid and 'inbox' or 'sent'
    local status = row.status or 'open'
    local isFine = row.kind == 'fine'
    return {
        id = row.id,
        amount = tonumber(row.amount) or 0,
        currency = '$',
        description = row.description or '',
        direction = direction,
        dueAt = due and due * 1000 or nil,
        issuedAt = (tonumber(row.issued_at_unix) or 0) * 1000,
        issuerAccount = row.issuer_account or '',
        issuerLabel = row.issuer_label or '',
        isOverdue = status == 'open' and due ~= nil and due < os.time(),
        isUnread = direction == 'inbox' and row.read_at == nil,
        paidAt = paid and paid * 1000 or nil,
        paymentReference = row.payment_reference or '',
        status = status,
        title = row.title or '',
        kind = row.kind or 'invoice',
        isFine = isFine,
        blocking = row.blocking == 1 or row.blocking == true,
        canPay = direction == 'inbox' and status == 'open',
        -- Multa não se contesta pelo app: vai para a delegacia, no RP.
        canDispute = direction == 'inbox' and status == 'open' and not isFine,
    }
end

local function sourceOf(cid)
    local Player = GetPlayerObjectFromID(cid)
    if not Player then return nil end
    return Player.PlayerData and Player.PlayerData.source or Player.source
end

local function notifyChanged(cid)
    local src = cid and sourceOf(cid)
    if src then TriggerEvent('Renewed-Banking:noir:invoicesChanged', src, cid) end
end

-- API ----------------------------------------------------------------------------------

local Invoices = {}

---Emite uma fatura. `issuerAccount` precisa ser conta de organização do banco.
---`silent = true` pula o aviso do banco (quem cobra avisa com texto próprio); o push do celular sai igual.
---@param data { silent?: boolean, recipientCid?: string, recipientSource?: number, issuerAccount: string, issuerLabel?: string, issuerCid?: string, issuerSource?: number, kind?: 'fine'|'invoice', blocking?: boolean, title: string, description?: string, amount: number, dueDays?: number }
---@return string? id, string? err
function Invoices.create(data)
    if not ready then return nil, 'not_ready' end
    if type(data) ~= 'table' then return nil, 'invalid_request' end

    local recipient = trimmed(data.recipientCid, 64)
    if not recipient and tonumber(data.recipientSource) then
        local Player = GetPlayerObject(tonumber(data.recipientSource))
        recipient = Player and GetIdentifier(Player)
    end
    local issuerCid = trimmed(data.issuerCid, 64)
    if not issuerCid and tonumber(data.issuerSource) then
        local Player = GetPlayerObject(tonumber(data.issuerSource))
        issuerCid = Player and GetIdentifier(Player)
    end

    local account = trimmed(data.issuerAccount, 64)
    local org = account and Internal.account(account)
    if not org then return nil, 'invalid_account' end

    local kind = KINDS[data.kind] and data.kind or 'invoice'
    local blocking = data.blocking
    if blocking == nil then blocking = kind == 'fine' end
    local title = trimmed(data.title, 160)
    local description = type(data.description) == 'string' and data.description:sub(1, 1000) or ''
    local amount = validAmount(data.amount)
    local label = trimmed(data.issuerLabel, 80) or org.name or account
    if not recipient or not title or not amount then return nil, 'invalid_request' end
    local dueDays = math.max(0, math.min(365, math.floor(tonumber(data.dueDays) or DEFAULT_DUE_DAYS)))

    local id = uuid()
    local inserted = MySQL.insert.await([[
        INSERT INTO `bank_invoices`
            (`id`, `recipient_cid`, `issuer_cid`, `issuer_account`, `issuer_label`, `kind`, `blocking`,
             `title`, `description`, `amount`, `due_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))
    ]], { id, recipient, issuerCid, account, label, kind, blocking and 1 or 0, title, description, amount, dueDays })
    if inserted == nil then return nil, 'request_failed' end

    local src = sourceOf(recipient)
    if src and not data.silent then
        Notify(src, {
            title = locale('bank_name'),
            description = locale(kind == 'fine' and 'invoice_new_fine' or 'invoice_new', label, amount),
            type = 'inform',
        })
    end
    notifyChanged(recipient)
    if src then
        -- Para o celular avisar (sky_phone escuta); evento local do servidor.
        TriggerEvent('Renewed-Banking:noir:invoiceCreated', src, { amount = amount, issuer = label, kind = kind })
    end
    return id
end

---@return boolean
function Invoices.cancel(id, actor)
    if not validId(id) then return false end
    local rows = query('`id` = ? LIMIT 1', { id })
    if not rows[1] then return false end
    local result = MySQL.update.await([[
        UPDATE `bank_invoices` SET `status` = 'cancelled', `closed_by` = ?
        WHERE `id` = ? AND `status` IN ('open', 'disputed')
    ]], { type(actor) == 'string' and actor or nil, id })
    if affected(result) ~= 1 then return false end
    notifyChanged(rows[1].recipient_cid)
    notifyChanged(rows[1].issuer_cid)
    return true
end

---Soma das faturas que bloqueiam saque e transferência.
---@return integer total, integer count
function Invoices.blockingDebt(cid)
    if not ready or type(cid) ~= 'string' then return 0, 0 end
    local row = MySQL.single.await([[
        SELECT COUNT(*) AS `count`, COALESCE(SUM(`amount`), 0) AS `total`
        FROM `bank_invoices` WHERE `recipient_cid` = ? AND `blocking` = 1 AND `status` IN ('open', 'processing', 'disputed')
    ]], { cid }) or {}
    return tonumber(row.total) or 0, tonumber(row.count) or 0
end

function Invoices.summary(cid, direction)
    local column = direction == 'sent' and 'issuer_cid' or 'recipient_cid'
    local row = MySQL.single.await(([[
        SELECT COUNT(CASE WHEN `status` = 'open' THEN 1 END) AS `open_count`,
            COALESCE(SUM(CASE WHEN `status` = 'open' THEN `amount` ELSE 0 END), 0) AS `open_total`,
            COUNT(CASE WHEN `status` = 'open' AND `due_at` < NOW() THEN 1 END) AS `overdue_count`,
            COUNT(CASE WHEN `read_at` IS NULL THEN 1 END) AS `unread_count`
        FROM `bank_invoices` WHERE `%s` = ?
    ]]):format(column), { cid }) or {}
    local urgent = {}
    for _, r in ipairs(query(('`%s` = ? AND `status` = \'open\' ORDER BY (`due_at` IS NULL), `due_at`, `issued_at` DESC LIMIT ?'):format(column), { cid, URGENT_LIMIT })) do
        urgent[#urgent + 1] = dto(r, cid)
    end
    local blockingTotal, blockingCount = Invoices.blockingDebt(cid)
    return {
        currency = '$',
        openCount = tonumber(row.open_count) or 0,
        openTotal = tonumber(row.open_total) or 0,
        overdueCount = tonumber(row.overdue_count) or 0,
        unreadCount = direction == 'sent' and 0 or (tonumber(row.unread_count) or 0),
        blockingTotal = blockingTotal,
        blockingCount = blockingCount,
        supportsDisputes = true,
        supportsSent = true,
        urgentInvoices = urgent,
    }
end

---@param options { direction?: 'inbox'|'sent', filter?: 'all'|'open'|'overdue'|'paid', offset?: number, search?: string, pageSize?: number }
function Invoices.list(cid, options)
    options = type(options) == 'table' and options or {}
    local column = options.direction == 'sent' and 'issuer_cid' or 'recipient_cid'
    local where, params = { ('`%s` = ?'):format(column) }, { cid }
    local filter = options.filter or 'all'
    if filter == 'open' then
        where[#where + 1] = "`status` = 'open'"
    elseif filter == 'overdue' then
        where[#where + 1] = "`status` = 'open' AND `due_at` < NOW()"
    elseif filter == 'paid' then
        where[#where + 1] = "`status` IN ('paid', 'disputed', 'cancelled')"
    end
    local search = type(options.search) == 'string' and options.search:sub(1, 80) or ''
    if search ~= '' then
        where[#where + 1] = '(`title` LIKE ? OR `issuer_label` LIKE ? OR `description` LIKE ?)'
        local pattern = '%' .. search .. '%'
        params[#params + 1], params[#params + 2], params[#params + 3] = pattern, pattern, pattern
    end
    local pageSize = math.max(1, math.min(100, math.floor(tonumber(options.pageSize) or PAGE_SIZE)))
    local offset = math.max(0, math.floor(tonumber(options.offset) or 0))
    params[#params + 1], params[#params + 2] = pageSize + 1, offset
    local rows = query(table.concat(where, ' AND ') .. ' ORDER BY `issued_at` DESC, `id` DESC LIMIT ? OFFSET ?', params)
    local hasMore = #rows > pageSize
    if hasMore then rows[#rows] = nil end
    local invoices = {}
    for _, r in ipairs(rows) do invoices[#invoices + 1] = dto(r, cid) end
    return { invoices = invoices, hasMore = hasMore, nextOffset = offset + #invoices }
end

function Invoices.get(cid, id)
    if not validId(id) then return nil end
    local row = query('`id` = ? AND (`recipient_cid` = ? OR `issuer_cid` = ?) LIMIT 1', { id, cid, cid })[1]
    return row and dto(row, cid) or nil
end

function Invoices.markRead(cid, id)
    if not validId(id) then return false end
    MySQL.update.await('UPDATE `bank_invoices` SET `read_at` = COALESCE(`read_at`, NOW()) WHERE `id` = ? AND `recipient_cid` = ?', { id, cid })
    return true
end

function Invoices.dispute(cid, id)
    if not validId(id) then return nil, 'invoice_not_found' end
    local result = MySQL.update.await([[
        UPDATE `bank_invoices` SET `status` = 'disputed', `read_at` = COALESCE(`read_at`, NOW())
        WHERE `id` = ? AND `recipient_cid` = ? AND `status` = 'open' AND `kind` <> 'fine'
    ]], { id, cid })
    if affected(result) ~= 1 then return nil, 'dispute_unavailable' end
    notifyChanged(cid)
    return Invoices.get(cid, id)
end

---Paga com o saldo bancário de quem está conectado. O valor cai na conta emissora.
---@return table? invoice, string? err
function Invoices.pay(source, id)
    if not ready then return nil, 'not_ready' end
    local Player = GetPlayerObject(source)
    if not Player then return nil, 'invalid_player' end
    local cid = GetIdentifier(Player)
    if not validId(id) then return nil, 'invoice_not_found' end

    local row = query('`id` = ? AND `recipient_cid` = ? LIMIT 1', { id, cid })[1]
    if not row then return nil, 'invoice_not_found' end
    if row.status == 'paid' then return nil, 'invoice_already_paid' end
    if row.status ~= 'open' then return nil, 'invoice_not_payable' end
    local org = Internal.account(row.issuer_account)
    if not org then return nil, 'invalid_account' end

    -- Trava a fatura antes de mexer em dinheiro: dois cliques não pagam duas vezes.
    local claim = MySQL.update.await("UPDATE `bank_invoices` SET `status` = 'processing' WHERE `id` = ? AND `status` = 'open'", { id })
    if affected(claim) ~= 1 then return nil, 'payment_in_progress' end

    local amount = tonumber(row.amount) or 0
    local funds = GetFunds(Player)
    local name = GetCharacterName(Player)
    if (funds.bank or 0) < amount or not RemoveMoney(Player, amount, 'bank', ('Fatura: %s'):format(row.title)) then
        MySQL.update.await("UPDATE `bank_invoices` SET `status` = 'open' WHERE `id` = ? AND `status` = 'processing'", { id })
        return nil, 'insufficient_funds'
    end

    AddAccountMoney(row.issuer_account, amount)
    local message = ('%s: %s'):format(row.title, row.description ~= '' and row.description or row.issuer_label)
    local transaction = Internal.handleTransaction(cid, locale('personal_acc') .. cid, amount, message, name, org.name, 'withdraw')
    Internal.handleTransaction(row.issuer_account, locale('personal_acc') .. cid, amount, message, name, org.name, 'deposit',
        transaction and transaction.trans_id or nil)

    MySQL.update.await([[
        UPDATE `bank_invoices` SET `status` = 'paid', `paid_at` = NOW(), `read_at` = COALESCE(`read_at`, NOW()),
            `payment_reference` = ?
        WHERE `id` = ? AND `status` = 'processing'
    ]], { transaction and transaction.trans_id or nil, id })

    notifyChanged(cid)
    notifyChanged(row.issuer_cid)
    return Invoices.get(cid, id)
end

-- Exports (quem cobra: bgrz_core, sky_phone; server-side apenas) -----------------------

exports('CreateInvoice', Invoices.create)
exports('CancelInvoice', Invoices.cancel)
exports('GetBlockingDebt', Invoices.blockingDebt)
exports('GetInvoiceSummary', Invoices.summary)
exports('ListInvoices', Invoices.list)
exports('GetInvoice', Invoices.get)
exports('MarkInvoiceRead', Invoices.markRead)
exports('DisputeInvoice', Invoices.dispute)
exports('PayInvoice', Invoices.pay)

NoirBankInvoices = Invoices

-- Banco (NUI) --------------------------------------------------------------------------

lib.callback.register('Renewed-Banking:server:payInvoice', function(source, data)
    local invoice, err = Invoices.pay(source, type(data) == 'table' and data.id or nil)
    if not invoice then
        Notify(source, { title = locale('bank_name'), description = locale('invoice_' .. (err or 'failed')), type = 'error' })
        return false
    end
    Notify(source, { title = locale('bank_name'), description = locale('invoice_paid', invoice.amount), type = 'success' })
    return Internal.getBankData(source)
end)
