-- Venda passiva: preço, quantidade e payout resolvidos no servidor, aplicados em um único UPDATE condicional.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Sale = Service

local config = require 'config.server'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Integration = NoirOutposts.Integration
local Repositories = NoirOutposts.Repositories
local Notification = NoirOutposts.Services.Notification
local Rotation = NoirOutposts.Services.Rotation

local processing = {}

---Produtos com estoque, filtrados pelo tipo de operação do outpost.
---@param entry table
---@return string[]
local function availableProducts(entry)
    local list = {}
    for index = 1, #State.productIds do
        local productId = State.productIds[index]
        if (entry.stock[productId] or 0) > 0 then list[#list + 1] = productId end
    end
    return list
end

---@param entry table
---@param now integer
---@return boolean ok, string? reason
local function canSell(entry, now)
    local row = entry.row
    if row.status ~= C.OutpostStatus.CONTROLLED then return false, 'not_controlled' end
    if not row.owner_organization_id then return false, 'no_owner' end
    if row.expires_at and row.expires_at <= now then return false, 'expired' end
    if config.sales.requireOwnerMemberOnline
        and not Integration.hasOnlineMember(row.owner_organization_id) then
        return false, 'no_member_online'
    end
    return true
end

Service.canSell = canSell

---Processa uma venda de um dealer. Chamado apenas pelo scheduler.
---@param dealer table linha do dealer
---@return boolean sold, string? reason
function Service.process(dealer)
    if processing[dealer.id] then return false, 'busy' end
    processing[dealer.id] = true

    local sold, reason = false, nil
    local ok, err = pcall(function()
        local entry = State.get(dealer.outpost_id)
        if not entry then reason = 'unknown_outpost' return end

        local now = os.time()
        local allowed, blockReason = canSell(entry, now)
        if not allowed then reason = blockReason return end

        if NoirOutposts.Services.Holdup.isBusy(dealer.id) then reason = 'holdup' return end

        local products = availableProducts(entry)
        if #products == 0 then reason = 'no_stock' return end

        local profile = State.profiles[dealer.profile_key]
        if not profile then reason = 'unknown_profile' return end

        local productId = products[math.random(#products)]
        local rule = config.products[productId]
        local stock = entry.stock[productId] or 0
        local lot = V.dealerLot(profile.stats.capacity, config.sales.capacityLotDivisor)
        local quantity = V.saleQuantity(rule.quantity, lot, stock, math.random())
        if quantity <= 0 then reason = 'no_stock' return end

        local jitterRange = config.sales.priceJitter
        local jitter = jitterRange.min + math.random() * (jitterRange.max - jitterRange.min)
        local amounts = V.saleAmounts(
            rule.unitPrice, quantity, jitter, profile.stats.negotiation, profile.stats.split)

        local interval = State.intervalFor(dealer.profile_key)
        local applied = Repositories.Dealer.applySale({
            dealerId = dealer.id,
            dealerVersion = dealer.version,
            outpostId = dealer.outpost_id,
            organizationId = entry.row.owner_organization_id,
            item = productId,
            quantity = quantity,
            net = amounts.net,
            gross = amounts.gross,
            nextSaleAt = now + interval,
            now = now,
        })
        if not applied then
            State.reload(dealer.outpost_id)
            reason = 'conflict'
            return
        end

        local operationId = Rotation.uuid()
        Repositories.Operation.insert({
            id = operationId,
            type = C.OperationKind.SALE,
            outpostId = dealer.outpost_id,
            dealerId = dealer.id,
            organizationId = entry.row.owner_organization_id,
            item = productId,
            quantity = quantity,
            gross = amounts.gross,
            net = amounts.net,
            status = C.OperationStatus.COMMITTED,
            createdAt = now,
            committedAt = now,
            payload = {
                unitPrice = amounts.unitPrice,
                commission = amounts.commission,
                profileKey = dealer.profile_key,
                dealerName = State.dealerName(dealer),
            },
        })

        local organizationId = entry.row.owner_organization_id
        State.reload(dealer.outpost_id)

        -- Fora da transação: notificação e dispatch nunca revertem a venda.
        Notification.queueSale(dealer.outpost_id, organizationId, amounts.net)
        Notification.checkStockAlerts(dealer.outpost_id)
        Notification.refreshPanels(dealer.outpost_id)
        Notification.maybeDispatch(dealer.outpost_id, 'sale', config.sales.dispatchChance)

        Log.debug('sale_committed', {
            outpostId = dealer.outpost_id,
            dealerId = dealer.id,
            operationId = operationId,
            item = productId,
            quantity = quantity,
            net = amounts.net,
        })
        sold = true
    end)

    processing[dealer.id] = nil
    if not ok then
        Log.error('sale_failed', { dealerId = dealer.id, error = tostring(err) })
        return false, 'internal_error'
    end
    return sold, reason
end

---Reagenda um dealer que não pôde vender, evitando varredura repetida a cada tick.
---@param dealer table
---@param now integer
function Service.defer(dealer, now)
    local nextSaleAt = now + State.intervalFor(dealer.profile_key)
    if Repositories.Dealer.reschedule(dealer.id, nextSaleAt) then
        dealer.next_sale_at = nextSaleAt
    end
end

function Service.clear()
    processing = {}
end
