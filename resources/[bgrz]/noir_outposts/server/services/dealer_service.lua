-- Contratação e demissão de dealers. Pagamento, limite e corner resolvidos no servidor.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Dealer = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
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

---Sorteia nome e ped do corredor novo.
---Evita repetir o que já está na rua neste posto: dois corredores com o mesmo rosto e o mesmo
---nome na mesma esquina entregam de graça que são script.
---@param entry table
---@return string? name, string? model
local function drawIdentity(entry)
    local identities = shared.dealerIdentities
    if type(identities) ~= 'table' then return nil, nil end

    local takenNames, takenModels = {}, {}
    for _, dealer in pairs(entry.dealers) do
        if dealer.display_name then takenNames[dealer.display_name] = true end
        if dealer.ped_model then takenModels[dealer.ped_model] = true end
    end

    local names = V.freeIdentityPool(identities.names, takenNames)
    local models = V.freeIdentityPool(identities.models, takenModels)
    if #names == 0 or #models == 0 then return nil, nil end

    return names[math.random(#names)], models[math.random(#models)]
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

    local displayName, pedModel = drawIdentity(entry)
    if not displayName or not pedModel then return { ok = false, code = 'internal_error' } end

    local price = config.dealerHirePrice[profileKey] or 0
    local paid, chargeError = charge(actor, price, 'noir_outposts:hire:fee')
    if not paid then return { ok = false, code = chargeError } end

    local now = os.time()
    local dealerId = Repositories.Dealer.insert({
        outpostId = outpostId,
        profileKey = profileKey,
        displayName = displayName,
        pedModel = pedModel,
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
        payload = {
            profileKey = profileKey,
            cornerIndex = cornerIndex,
            dealerName = displayName,
            pedModel = pedModel,
        },
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
    Service.forgetRobbery(dealerId)

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
        payload = { profileKey = dealer.profile_key, dealerName = State.dealerName(dealer) },
    })

    State.reload(outpostId)
    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(outpostId)
    Log.info('dealer_fired', { outpostId = outpostId, dealerId = dealerId, citizenId = actor.citizenId })

    return { ok = true, data = { refund = refundValue } }
end

---Momento do último assalto por corredor. Só importa dentro da janela de graça, então
---memória basta: perder isso num restart não muda nada depois de um minuto.
---@type table<integer, integer>
local robbedAt = {}

---@param dealerId integer
function Service.markRobbed(dealerId)
    robbedAt[dealerId] = os.time()
end

---@param dealerId integer
function Service.forgetRobbery(dealerId)
    robbedAt[dealerId] = nil
end

---Coordenada da esquina cadastrada de um corredor. É o único ponto que o servidor conhece
---sem depender de nada do client.
---@param dealer table
---@return vector3?
function Service.cornerOf(dealer)
    local definition = shared.outposts[dealer.outpost_id]
    local corner = definition and definition.dealerCorners[dealer.corner_index or 0]
    if not corner then return nil end
    return vector3(corner.x, corner.y, corner.z)
end

---Até onde um corredor pode ter se afastado da própria esquina.
---@return number
function Service.wanderSlack()
    local wander = shared.dealerWander
    if type(wander) == 'table' and wander.enabled == true then return wander.radius end
    return 0.0
end

-- Quando é `true`, alguma leitura já saiu da esquina de spawn e portanto o servidor recebe a
-- posição dos peds. Vale para o resource inteiro: é uma propriedade da sincronização, não de um
-- corredor. Volta a `false` no restart, que é quando a hipótese precisa ser provada de novo.
local positionSyncProven = false

---@return boolean
function Service.positionSyncProven()
    return positionSyncProven
end

---Onde o servidor acredita que o corredor está, e se essa crença é fato ou palpite.
---@param dealer table
---@param entity number?
---@return vector3? coords, boolean trusted
function Service.observedPosition(dealer, entity)
    local corner = Service.cornerOf(dealer)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return corner, false
    end

    local coords = GetEntityCoords(entity)
    -- A prova é medida no plano. Logo após o spawn o ped assenta no chão, e esse ajuste de Z
    -- não diz nada sobre sincronização; andar, que é o que interessa, acontece em X e Y.
    local drift = corner
        and #(vector3(coords.x, coords.y, 0.0) - vector3(corner.x, corner.y, 0.0))
        or nil
    if V.provesPositionSync(drift, config.validation.positionSyncEpsilon) then
        if not positionSyncProven then
            positionSyncProven = true
            Log.info('position_sync_proven', { dealerId = dealer.id })
        end
        return coords, true
    end

    -- Leitura em cima da esquina: só serve como posição real se a sincronização já se provou.
    return coords, positionSyncProven
end

---Alvo válido para uma ação de rival (abordagem ou assalto).
---@param actor OutpostActor
---@param dealerId integer
---@param netId integer
---@param maxDistance number
---@param anchor table? { coords: vector3, trusted: boolean } posição gravada na rendição
---@return table? context { dealer, entry, entity, coords, trusted, reach }, string? code
function Service.rivalTarget(actor, dealerId, netId, maxDistance, anchor)
    if not Security.isActorAble(actor) then return nil, 'player_unavailable' end

    local dealer = State.dealer(dealerId)
    if not dealer then return nil, 'unknown_dealer' end
    if dealer.status ~= C.DealerStatus.DEPLOYED then return nil, 'dealer_unavailable' end

    local now = os.time()
    if dealer.robbed_until and dealer.robbed_until > now then return nil, 'dealer_cooldown' end

    local entry = State.get(dealer.outpost_id)
    if not entry then return nil, 'unknown_outpost' end
    if entry.row.status ~= C.OutpostStatus.CONTROLLED then return nil, 'invalid_state' end
    if Security.isOwner(actor, entry.row) then return nil, 'own_outpost' end

    local entity = Entities.validate(dealerId, netId)
    if not entity then return nil, 'invalid_entity' end
    if not Security.sameBucket(actor.source, entity) then return nil, 'invalid_entity' end

    -- `anchor` é a posição gravada no instante da rendição. A revista mede contra ela, e não
    -- contra uma leitura nova: o corredor rendido não anda, e congelar o ponto impede que
    -- alguém arraste o alvo para perto de si durante a janela.
    local coords, trusted
    if anchor and anchor.coords then
        coords, trusted = anchor.coords, anchor.trusted == true
    else
        coords, trusted = Service.observedPosition(dealer, entity)
    end
    if not coords then return nil, 'invalid_entity' end

    -- Sem posição confiável sobra a esquina cadastrada mais o raio de caminhada. É frouxo, mas
    -- continua prendendo a ação à área do posto: sem checagem nenhuma, um client modificado
    -- drenaria a carteira da organização de qualquer lugar do mapa.
    local reach = V.dealerReach(trusted, maxDistance, Service.wanderSlack())
    if not Security.isNear(actor.source, coords, reach) then return nil, 'too_far' end

    return {
        dealer = dealer,
        entry = entry,
        entity = entity,
        coords = coords,
        trusted = trusted,
        reach = reach,
    }
end

---Corredor morto sai de operação pelo cooldown configurado. Detectado pela varredura do
---scheduler, nunca por aviso do client.
---@param dealerId integer
---@return boolean applied
function Service.markDown(dealerId)
    local dealer = State.dealer(dealerId)
    if not dealer or dealer.status ~= C.DealerStatus.DEPLOYED then return false end

    local entry = State.get(dealer.outpost_id)
    if not entry then return false end

    local now = os.time()
    local sinceRobbery = robbedAt[dealerId] and now - robbedAt[dealerId] or nil
    local cooldown = V.downCooldown(
        sinceRobbery,
        config.dealers.downCooldownSeconds,
        config.dealers.robbedGraceSeconds,
        config.dealers.robbedDownCooldownSeconds)

    local downUntil = now + cooldown
    local nextSaleAt = downUntil + State.intervalFor(dealer.profile_key)

    if not Repositories.Dealer.markDown(dealer.id, dealer.version, downUntil, nextSaleAt) then
        State.reload(dealer.outpost_id)
        return false
    end

    -- O corpo fica caído onde estava, e some sozinho quando a área esvaziar.
    Entities.markCorpse(dealerId)

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
        payload = {
            profileKey = dealer.profile_key,
            dealerName = State.dealerName(dealer),
            downUntil = downUntil,
            cooldown = cooldown,
            afterRobbery = sinceRobbery ~= nil and sinceRobbery <= config.dealers.robbedGraceSeconds,
        },
    })

    State.reload(dealer.outpost_id)

    local definition = shared.outposts[dealer.outpost_id]
    Notification.notifyOrganization(organizationId, 'security', {
        title = locale('phone.dealer_down_title'),
        body = locale('phone.dealer_down_body',
            State.dealerName(dealer), definition.label),
    })
    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(dealer.outpost_id)

    Log.info('dealer_down', {
        outpostId = dealer.outpost_id,
        dealerId = dealer.id,
        downUntil = downUntil,
        cooldown = cooldown,
        sinceRobbery = sinceRobbery,
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
                if affected and affected > 0 then
                    Service.forgetRobbery(dealerId)
                    changed = true
                end
            end
        end
        if changed then
            State.reload(outpostId)
            for dealerId, dealer in pairs(State.get(outpostId).dealers) do
                if dealer.status == C.DealerStatus.DEPLOYED then
                    if Entities.isAlive(dealerId) then
                        -- Voltou de assalto: o mesmo corredor retoma o posto.
                        Entities.setState(dealerId, C.DealerStatus.DEPLOYED)
                    else
                        -- Voltou de morte: remove o que sobrou do corpo e traz um substituto.
                        Entities.despawnDealer(dealerId)
                        Entities.spawnDealer(outpostId, dealer)
                    end
                end
            end
            Notification.broadcastPublicSnapshot()
            Notification.refreshPanels(outpostId)
        end
    end
end

---Devolve imediatamente todos os corredores em recuperação de um outpost.
---Uso administrativo: encurta o cooldown em vez de esperar.
---@param outpostId string
---@return integer recovered
function Service.forceRecover(outpostId)
    State.reload(outpostId)
    local entry = State.get(outpostId)
    if not entry then return 0 end

    local now = os.time()
    local count = 0
    for dealerId, dealer in pairs(entry.dealers) do
        if dealer.status == C.DealerStatus.RECOVERING
            and Repositories.Dealer.expireRecovery(dealerId, now) then
            count = count + 1
        end
    end

    if count > 0 then
        State.reload(outpostId)
        Service.recoverDue()
    end
    return count
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
        name = State.dealerName(dealer),
        profileName = profile and profile.name or dealer.profile_key,
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
