-- Estoque virtual: depósito com compensação e coleta idempotente da carteira.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Stock = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Security = NoirOutposts.Security
local Integration = NoirOutposts.Integration
local Repositories = NoirOutposts.Repositories
local Notification = NoirOutposts.Services.Notification
local Rotation = NoirOutposts.Services.Rotation
local Dealer = NoirOutposts.Services.Dealer

---Depósito: remove do inventário, incrementa estoque e compensa quando o SQL falha.
---@param actor OutpostActor
---@param outpostId string
---@param productId string
---@param amount integer
---@param requestId string
---@return table result
function Service.deposit(actor, outpostId, productId, amount, requestId)
    local entry, code = Dealer.ownedEntry(actor, outpostId, 'stock')
    if not entry then return { ok = false, code = code } end

    local product = Security.product(productId)
    if not product then return { ok = false, code = 'unknown_product' } end

    if amount > config.limits.maxStockPerDeposit then return { ok = false, code = 'amount_too_large' } end
    if State.stockTotal(outpostId) + amount > config.limits.maxStockTotal then
        return { ok = false, code = 'stock_full' }
    end

    local existing = Repositories.Operation.findByRequest(actor.citizenId, requestId)
    if existing then return { ok = false, code = 'already_processed' } end
    if Security.claimRequestId(actor.citizenId, requestId) == 'duplicate' then
        return { ok = false, code = 'already_processed' }
    end

    local carried = Integration.getItemCount(actor.source, productId)
    if carried < amount then return { ok = false, code = 'not_enough_items' } end

    local now = os.time()
    local operationId = Rotation.uuid()
    local recorded = Repositories.Operation.insert({
        id = operationId,
        type = C.OperationKind.DEPOSIT,
        outpostId = outpostId,
        citizenId = actor.citizenId,
        organizationId = actor.organization.id,
        item = productId,
        quantity = amount,
        status = C.OperationStatus.PREPARED,
        requestId = requestId,
        createdAt = now,
    })
    if not recorded then return { ok = false, code = 'internal_error' } end

    local removed, removeError = Integration.removeItem(actor.source, productId, amount)
    if not removed then
        Repositories.Operation.setStatus(operationId, C.OperationStatus.FAILED, now, { reason = removeError })
        return { ok = false, code = removeError == 'provider_unavailable' and 'provider_unavailable' or 'not_enough_items' }
    end

    local applied = Repositories.Stock.deposit(outpostId, productId, amount, config.limits.maxStockTotal)
    if not applied then
        local returned = Integration.addItem(actor.source, productId, amount)
        Repositories.Operation.setStatus(operationId, C.OperationStatus.COMPENSATED, os.time(), {
            compensated = returned == true,
        })
        if not returned then
            Log.error('deposit_compensation_failed', {
                operationId = operationId,
                citizenId = actor.citizenId,
                item = productId,
                quantity = amount,
            })
        end
        State.reload(outpostId)
        return { ok = false, code = 'stock_full' }
    end

    Repositories.Operation.setStatus(operationId, C.OperationStatus.COMMITTED, os.time())
    State.reload(outpostId)
    Notification.refreshPanels(outpostId)
    Log.info('stock_deposited', {
        outpostId = outpostId,
        operationId = operationId,
        citizenId = actor.citizenId,
        item = productId,
        quantity = amount,
    })

    return { ok = true, data = { item = productId, quantity = amount, stockTotal = State.stockTotal(outpostId) } }
end

---Coleta: carteira vai para pending, item é entregue, pending é liquidado ou restaurado.
---@param actor OutpostActor
---@param outpostId string
---@param requestId string
---@return table result
function Service.collect(actor, outpostId, requestId)
    local entry, code = Dealer.ownedEntry(actor, outpostId, 'collect')
    if not entry then return { ok = false, code = code } end

    local existing = Repositories.Operation.findByRequest(actor.citizenId, requestId)
    if existing then return { ok = false, code = 'already_processed' } end
    if Security.claimRequestId(actor.citizenId, requestId) == 'duplicate' then
        return { ok = false, code = 'already_processed' }
    end

    local available = math.min(tonumber(entry.row.purse_available) or 0, config.payout.maxPerCollection)
    if available <= 0 then return { ok = false, code = 'empty_purse' } end

    local canCarry = Integration.canCarryItem(actor.source, config.payout.item, available)
    if not canCarry then return { ok = false, code = 'cannot_carry' } end

    local moved = Repositories.Outpost.movePurseToPending(outpostId, actor.organization.id, available)
    if not moved or moved == 0 then
        State.reload(outpostId)
        return { ok = false, code = 'purse_changed' }
    end

    local now = os.time()
    local operationId = Rotation.uuid()
    Repositories.Operation.insert({
        id = operationId,
        type = C.OperationKind.COLLECT,
        outpostId = outpostId,
        citizenId = actor.citizenId,
        organizationId = actor.organization.id,
        item = config.payout.item,
        quantity = available,
        net = available,
        status = C.OperationStatus.PENDING,
        requestId = requestId,
        createdAt = now,
    })

    local delivered = Integration.addItem(actor.source, config.payout.item, available)
    if not delivered then
        Repositories.Outpost.restorePending(outpostId, available)
        Repositories.Operation.setStatus(operationId, C.OperationStatus.COMPENSATED, os.time())
        State.reload(outpostId)
        Notification.refreshPanels(outpostId)
        return { ok = false, code = 'cannot_carry' }
    end

    Repositories.Outpost.settlePending(outpostId, available)
    Repositories.Operation.setStatus(operationId, C.OperationStatus.PAID, os.time())
    State.reload(outpostId)
    Notification.refreshPanels(outpostId)
    Log.info('purse_collected', {
        outpostId = outpostId,
        operationId = operationId,
        citizenId = actor.citizenId,
        amount = available,
    })

    return { ok = true, data = { amount = available, item = config.payout.item } }
end

---Quantidades carregadas pelo jogador, para exibir no painel.
---@param source number
---@return table<string, integer>
function Service.carriedProducts(source)
    local carried = {}
    for index = 1, #shared.products do
        local productId = shared.products[index].id
        if config.products[productId] then
            carried[productId] = Integration.getItemCount(source, productId)
        end
    end
    return carried
end
