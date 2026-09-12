-- Abordagem à mão armada. O client só informa que está mirando; a chance de reação,
-- o resultado e a duração são resolvidos aqui.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Holdup = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Entities = NoirOutposts.Entities
local Repositories = NoirOutposts.Repositories
local Notification = NoirOutposts.Services.Notification
local Rotation = NoirOutposts.Services.Rotation
local Dealer = NoirOutposts.Services.Dealer

---@type table<integer, { state: string, source: number, citizenId: string, expiresAt: integer, coords: vector3?, trusted: boolean }>
local active = {}
---@type table<integer, integer>
local cooldowns = {}

---@param dealerId integer
---@return boolean
function Service.isSurrendered(dealerId)
    local holdup = active[dealerId]
    return holdup ~= nil and holdup.state == C.HoldupState.SURRENDERED
end

---Onde o corredor estava no instante em que levantou as mãos.
---A revista mede contra este ponto: rendido ele não anda, e um ponto congelado não pode ser
---arrastado para perto de quem está roubando.
---@param dealerId integer
---@return table? anchor { coords: vector3, trusted: boolean }
function Service.surrenderAnchor(dealerId)
    local holdup = active[dealerId]
    if not holdup or holdup.state ~= C.HoldupState.SURRENDERED or not holdup.coords then
        return nil
    end
    return { coords = holdup.coords, trusted = holdup.trusted }
end

---Corredor sob abordagem não vende: está ocupado com um cano apontado para ele.
---@param dealerId integer
---@return boolean
function Service.isBusy(dealerId)
    return active[dealerId] ~= nil
end

---@param dealerId integer
---@return string? state
function Service.stateOf(dealerId)
    local holdup = active[dealerId]
    return holdup and holdup.state or nil
end

---Devolve o corredor ao comportamento normal.
---@param dealerId integer
---@param reason string
local function release(dealerId, reason)
    local holdup = active[dealerId]
    if not holdup then return end
    active[dealerId] = nil

    local dealer = State.dealer(dealerId)
    if dealer then
        Entities.setState(dealerId, dealer.status)
        if Entities.resolve(dealerId) then
            TriggerClientEvent(C.Events.DEALER_REACTION, -1, {
                netId = select(2, Entities.resolve(dealerId)),
                state = dealer.status,
            })
        end
    end
    Log.debug('holdup_released', { dealerId = dealerId, reason = reason })
end

---@param dealerId integer
function Service.release(dealerId)
    release(dealerId, 'external')
end

---@param actor OutpostActor
---@param dealerId integer
---@param netId integer
---@return table result
function Service.start(actor, dealerId, netId)
    if active[dealerId] then
        return { ok = false, code = 'holdup_in_progress' }
    end

    local now = os.time()
    if (cooldowns[dealerId] or 0) > now then
        return { ok = false, code = 'dealer_cooldown' }
    end

    local context, code = Dealer.rivalTarget(actor, dealerId, netId, config.holdup.maxDistance)
    if not context then return { ok = false, code = code } end

    local reacted = V.holdupReacts(math.random(100), config.holdup.reactionChance)
    local state = reacted and C.HoldupState.HOSTILE or C.HoldupState.SURRENDERED
    local duration = reacted and config.holdup.hostileSeconds or config.holdup.surrenderSeconds

    -- A posição vem da checagem que acabou de autorizar a abordagem, ou seja, do instante do
    -- resultado. `trusted` diz se o servidor mediu o ped de fato ou caiu na esquina cadastrada;
    -- é dela que sai a folga do alcance na revista.
    active[dealerId] = {
        state = state,
        source = actor.source,
        citizenId = actor.citizenId,
        expiresAt = now + duration,
        coords = context.coords,
        trusted = context.trusted,
    }
    cooldowns[dealerId] = now + config.holdup.cooldownSeconds

    Entities.setState(dealerId, state)
    TriggerClientEvent(C.Events.DEALER_REACTION, -1, {
        netId = netId,
        state = state,
        targetServerId = actor.source,
        weapon = reacted and shared.dealerWeapon or nil,
    })

    Repositories.Operation.insert({
        id = Rotation.uuid(),
        type = C.OperationKind.HOLDUP,
        outpostId = context.dealer.outpost_id,
        dealerId = dealerId,
        citizenId = actor.citizenId,
        organizationId = context.entry.row.owner_organization_id,
        status = C.OperationStatus.COMMITTED,
        createdAt = now,
        committedAt = now,
        payload = {
            reacted = reacted,
            profileKey = context.dealer.profile_key,
            dealerName = State.dealerName(context.dealer),
        },
    })

    local definition = shared.outposts[context.dealer.outpost_id]
    Notification.notifyOrganization(context.entry.row.owner_organization_id, 'security', {
        title = locale('phone.holdup_title'),
        body = locale('phone.holdup_body',
            State.dealerName(context.dealer), definition.label),
    })

    Log.info('holdup_started', {
        dealerId = dealerId,
        outpostId = context.dealer.outpost_id,
        citizenId = actor.citizenId,
        reacted = reacted,
    })

    return {
        ok = true,
        data = { reacted = reacted, durationMs = duration * 1000 },
    }
end

---Encerra abordagens vencidas. Chamado pelo scheduler.
function Service.tick()
    local now = os.time()
    local expired = {}
    for dealerId, holdup in pairs(active) do
        if holdup.expiresAt <= now or not State.dealer(dealerId) then
            expired[#expired + 1] = dealerId
        end
    end
    for index = 1, #expired do release(expired[index], 'expired') end

    for dealerId, until_ in pairs(cooldowns) do
        if until_ <= now then cooldowns[dealerId] = nil end
    end
end

---@param source number
function Service.releaseForSource(source)
    local ids = {}
    for dealerId, holdup in pairs(active) do
        if holdup.source == source then ids[#ids + 1] = dealerId end
    end
    for index = 1, #ids do release(ids[index], 'source_gone') end
end

---Zera os cooldowns de abordagem. Uso administrativo.
---@return integer cleared
function Service.clearCooldowns()
    local count = 0
    for dealerId in pairs(cooldowns) do
        cooldowns[dealerId] = nil
        count = count + 1
    end
    return count
end

function Service.clear()
    active = {}
    cooldowns = {}
end
