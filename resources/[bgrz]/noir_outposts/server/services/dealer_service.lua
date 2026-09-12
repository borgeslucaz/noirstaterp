-- Contratação e demissão de dealers. Pagamento, limite e corner resolvidos no servidor.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Dealer = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Sessions = NoirOutposts.Sessions
local Security = NoirOutposts.Security
local Entities = NoirOutposts.Entities
local Integration = NoirOutposts.Integration
local Repositories = NoirOutposts.Repositories
local Notification = NoirOutposts.Services.Notification
local Rotation = NoirOutposts.Services.Rotation

---@param actor OutpostActor
---@param outpostId string
---@param action string
---@return table? entry, string? code
local function ownedEntry(actor, outpostId, action)
    local entry = State.get(outpostId)
    if not entry then return nil, 'unknown_outpost' end
    if entry.row.status ~= C.OutpostStatus.CONTROLLED then return nil, 'invalid_state' end
    if not Security.isOwner(actor, entry.row) then return nil, 'not_owner' end
    local allowed, permissionError = Security.requirePermission(actor, action)
    if not allowed then return nil, permissionError end
    local definition = shared.outposts[outpostId]
    if not Security.isNear(actor.source, definition.computer, shared.interaction.computerDistance) then
        return nil, 'too_far'
    end
    return entry
end

Service.ownedEntry = ownedEntry

---@param actor OutpostActor
---@param price integer
---@param reason string
---@return boolean ok, string? code
local function charge(actor, price, reason)
    if price <= 0 then return true end
    local payment = config.hire.payment
    if payment.type == 'item' then
        local ok = Integration.removeItem(actor.source, payment.item, price)
        if not ok then return false, 'insufficient_funds' end
        return true
    end
    local ok = Integration.removeMoney(actor.source, payment.account, price, reason)
    if not ok then return false, 'insufficient_funds' end
    return true
end

---@param actor OutpostActor
---@param price integer
---@param reason string
local function refund(actor, price, reason)
    if price <= 0 then return end
    local payment = config.hire.payment
    if payment.type == 'item' then
        Integration.addItem(actor.source, payment.item, price)
        return
    end
    Integration.addMoney(actor.source, payment.account, price, reason)
end

---@param actor OutpostActor
---@param outpostId string
---@param profileKey string
---@param requestId string
---@return table result
function Service.hire(actor, outpostId, profileKey, requestId)
    local entry, code = ownedEntry(actor, outpostId, 'hire')
    if not entry then return { ok = false, code = code } end

    local profile = Security.profile(profileKey)
    if not profile then return { ok = false, code = 'unknown_profile' } end

    -- Idempotência em duas camadas: ledger (sobrevive a restart) e memória (duplo clique).
    if Repositories.Operation.findByRequest(actor.citizenId, requestId) then
        return { ok = false, code = 'already_processed' }
    end
    if Security.claimRequestId(actor.citizenId, requestId) == 'duplicate' then
        return { ok = false, code = 'already_processed' }
    end

    if State.dealerCount(outpostId) >= config.limits.maxDealersPerOutpost then
        return { ok = false, code = 'dealer_limit' }
    end
    for _, dealer in pairs(entry.dealers) do
        if dealer.profile_key == profileKey then return { ok = false, code = 'already_hired' } end
    end

    local corners = State.freeCorners(outpostId)
    if #corners == 0 then return { ok = false, code = 'no_corner' } end
    local cornerIndex = corners[math.random(#corners)]

    local price = config.dealerHirePrice[profileKey] or 0
    local paid, chargeError = charge(actor, price, 'noir_outposts:hire:fee')
    if not paid then return { ok = false, code = chargeError } end

    local now = os.time()
    local dealerId = Repositories.Dealer.insert({
        outpostId = outpostId,
        profileKey = profileKey,
        cornerIndex = cornerIndex,
        hiredBy = actor.citizenId,
        hiredAt = now,
        nextSaleAt = now + State.intervalFor(profileKey),
    }, config.limits.maxDealersPerOutpost)

    if not dealerId then
        refund(actor, price, 'noir_outposts:hire:refund')
        State.reload(outpostId)
        return { ok = false, code = 'dealer_limit' }
    end

    Repositories.Operation.insert({
        id = Rotation.uuid(),
        type = C.OperationKind.HIRE,
        outpostId = outpostId,
        dealerId = dealerId,
        citizenId = actor.citizenId,
        organizationId = actor.organization.id,
        gross = price,
        status = C.OperationStatus.COMMITTED,
        requestId = requestId,
        createdAt = now,
        committedAt = now,
        payload = { profileKey = profileKey, cornerIndex = cornerIndex },
    })

    State.reload(outpostId)
    local dealer = State.dealer(dealerId)
    if dealer then Entities.spawnDealer(outpostId, dealer) end

    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(outpostId)
    Log.info('dealer_hired', {
        outpostId = outpostId,
        dealerId = dealerId,
        profileKey = profileKey,
        citizenId = actor.citizenId,
        price = price,
    })

    return { ok = true, data = { dealerId = dealerId } }
end

---@param actor OutpostActor
---@param outpostId string
---@param dealerId integer
---@param requestId string
---@return table result
function Service.fire(actor, outpostId, dealerId, requestId)
    local entry, code = ownedEntry(actor, outpostId, 'fire')
    if not entry then return { ok = false, code = code } end

    local dealer = entry.dealers[dealerId]
    if not dealer then return { ok = false, code = 'unknown_dealer' } end

    if Repositories.Operation.findByRequest(actor.citizenId, requestId) then
        return { ok = false, code = 'already_processed' }
    end
    if Security.claimRequestId(actor.citizenId, requestId) == 'duplicate' then
        return { ok = false, code = 'already_processed' }
    end

    local session = Sessions.activeForDealer(dealerId)
    if session then return { ok = false, code = 'dealer_busy' } end

    local affected = Repositories.Dealer.delete(dealerId)
    if not affected or affected == 0 then
        State.reload(outpostId)
        return { ok = false, code = 'unknown_dealer' }
    end

    Entities.despawnDealer(dealerId)

    local now = os.time()
    local refundValue = 0
    if config.hire.refundOnFire then
        refundValue = math.floor((config.dealerHirePrice[dealer.profile_key] or 0) / 2)
        refund(actor, refundValue, 'noir_outposts:fire:refund')
    end

    Repositories.Operation.insert({
        id = Rotation.uuid(),
        type = C.OperationKind.FIRE,
        outpostId = outpostId,
        dealerId = dealerId,
        citizenId = actor.citizenId,
        organizationId = actor.organization.id,
        net = refundValue,
        status = C.OperationStatus.COMMITTED,
        requestId = requestId,
        createdAt = now,
        committedAt = now,
        payload = { profileKey = dealer.profile_key },
    })

    State.reload(outpostId)
    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(outpostId)
    Log.info('dealer_fired', { outpostId = outpostId, dealerId = dealerId, citizenId = actor.citizenId })

    return { ok = true, data = { refund = refundValue } }
end

---Corredor morto sai de operação pelo cooldown configurado. Detectado pela varredura do
---scheduler, nunca por aviso do client.
---@param dealerId integer
---@return boolean applied
function Service.markDown(dealerId)
    local dealer = State.dealer(dealerId)
    if not dealer or dealer.status ~= C.DealerStatus.DEPLOYED then
        Entities.despawnDealer(dealerId)
        return false
    end

    local entry = State.get(dealer.outpost_id)
    if not entry then
        Entities.despawnDealer(dealerId)
        return false
    end

    local now = os.time()
    local downUntil = now + config.dealers.downCooldownSeconds
    local nextSaleAt = downUntil + State.intervalFor(dealer.profile_key)

    if not Repositories.Dealer.markDown(dealer.id, dealer.version, downUntil, nextSaleAt) then
        State.reload(dealer.outpost_id)
        return false
    end

    -- O corpo sai de cena: durante a recuperação não existe ped naquela posição.
    Entities.despawnDealer(dealerId)

    local organizationId = entry.row.owner_organization_id
    Repositories.Operation.insert({
        id = Rotation.uuid(),
        type = C.OperationKind.DOWN,
        outpostId = dealer.outpost_id,
        dealerId = dealer.id,
        organizationId = organizationId,
        status = C.OperationStatus.COMMITTED,
        createdAt = now,
        committedAt = now,
        payload = { profileKey = dealer.profile_key, downUntil = downUntil },
    })

    State.reload(dealer.outpost_id)

    local profile = State.profiles[dealer.profile_key]
    local definition = shared.outposts[dealer.outpost_id]
    Notification.notifyOrganization(organizationId, {
        title = locale('phone.dealer_down_title'),
        body = locale('phone.dealer_down_body',
            profile and profile.name or dealer.profile_key, definition.label),
    })
    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(dealer.outpost_id)

    Log.info('dealer_down', {
        outpostId = dealer.outpost_id,
        dealerId = dealer.id,
        downUntil = downUntil,
    })
    return true
end

---Corredores que cumpriram o cooldown voltam a operar e reaparecem no posto.
---Cobre tanto assalto quanto morte.
function Service.recoverDue()
    local now = os.time()
    for outpostId, entry in pairs(State.outposts) do
        local changed = false
        for dealerId, dealer in pairs(entry.dealers) do
            if dealer.status == C.DealerStatus.RECOVERING
                and dealer.robbed_until and dealer.robbed_until <= now then
                local nextSaleAt = now + State.intervalFor(dealer.profile_key)
                local affected = Repositories.Dealer.recover(dealerId, now, nextSaleAt)
                if affected and affected > 0 then changed = true end
            end
        end
        if changed then
            State.reload(outpostId)
            for dealerId, dealer in pairs(State.get(outpostId).dealers) do
                if dealer.status == C.DealerStatus.DEPLOYED then
                    if Entities.resolve(dealerId) then
                        Entities.setState(dealerId, C.DealerStatus.DEPLOYED)
                    else
                        Entities.spawnDealer(outpostId, dealer)
                    end
                end
            end
            Notification.broadcastPublicSnapshot()
            Notification.refreshPanels(outpostId)
        end
    end
end

---Dados públicos de um dealer, para quem não é dono.
---@param actor OutpostActor
---@param dealerId integer
---@param netId integer
---@return table result
function Service.inspect(actor, dealerId, netId)
    local dealer = State.dealer(dealerId)
    if not dealer then return { ok = false, code = 'unknown_dealer' } end
    local entity = Entities.validate(dealerId, netId)
    if not entity then return { ok = false, code = 'invalid_entity' } end
    if not Security.sameBucket(actor.source, entity) then return { ok = false, code = 'invalid_entity' } end
    if not Security.isNearEntity(actor.source, entity, shared.interaction.dealerDistance) then
        return { ok = false, code = 'too_far' }
    end

    local entry = State.get(dealer.outpost_id)
    if not entry then return { ok = false, code = 'unknown_outpost' } end
    local profile = State.profiles[dealer.profile_key]
    local isOwner = Security.isOwner(actor, entry.row)

    local data = {
        dealerId = dealer.id,
        name = profile and profile.name or dealer.profile_key,
        status = dealer.status,
        outpostLabel = shared.outposts[dealer.outpost_id].label,
        isOwner = isOwner,
    }
    if isOwner then
        data.nextSaleAt = dealer.next_sale_at
        data.lifetimeSales = dealer.lifetime_sales
        data.stockTotal = State.stockTotal(dealer.outpost_id)
    end
    return { ok = true, data = data }
end
