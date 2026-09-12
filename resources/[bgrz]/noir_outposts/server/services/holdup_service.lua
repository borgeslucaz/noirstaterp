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
-- Corredores que ficaram abalados depois da abordagem. É só encenação no client: nenhuma regra
-- lê este estado, e quem recusa a abordagem seguinte continua sendo o cooldown acima.
---@type table<integer, boolean>
local shaken = {}

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
    if holdup then return holdup.state end
    -- O abalado não é abordagem em curso, mas aparece no diagnóstico: é ele que explica um
    -- corredor agachado sem ninguém por perto.
    return shaken[dealerId] and C.HoldupState.SHAKEN or nil
end

---Publica um estado de corredor para os clients: state bag para quem chegar depois, evento para
---quem já está vendo. O bag atrasa, e a encenação precisa do evento.
---@param dealerId integer
---@param state string
local function publish(dealerId, state)
    Entities.setState(dealerId, state)
    local _, netId = Entities.resolve(dealerId)
    if not netId then return end
    TriggerClientEvent(C.Events.DEALER_REACTION, -1, { netId = netId, state = state })
end

---Tira o corredor do estado de abalado e o devolve ao estado real dele.
---@param dealerId integer
local function unshake(dealerId)
    if not shaken[dealerId] then return end
    shaken[dealerId] = nil
    local dealer = State.dealer(dealerId)
    if dealer then publish(dealerId, dealer.status) end
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
        -- Enquanto o cooldown corre ele não volta a caminhar como se nada tivesse acontecido:
        -- fica agachado com medo. É a única pista visível de que apontar a arma de novo agora
        -- não vai dar em nada, e sem ela a recusa se lê como corredor quebrado.
        local state = dealer.status
        if dealer.status == C.DealerStatus.DEPLOYED and (cooldowns[dealerId] or 0) > os.time() then
            state = C.HoldupState.SHAKEN
            shaken[dealerId] = true
        else
            shaken[dealerId] = nil
        end
        publish(dealerId, state)
    end
    Log.debug('holdup_released', { dealerId = dealerId, reason = reason, state = shaken[dealerId] and 'shaken' or nil })
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
    local current = active[dealerId]
    if current then
        -- Ele já reagiu: dizer "está sendo abordado" para quem está levando tiro dele não
        -- descreve nada. De mãos para o alto, sim, a abordagem está em curso, e a janela
        -- pertence a quem a abriu.
        return {
            ok = false,
            code = current.state == C.HoldupState.HOSTILE and 'holdup_done' or 'holdup_in_progress',
        }
    end

    local now = os.time()
    if (cooldowns[dealerId] or 0) > now then
        -- Código próprio: 'dealer_cooldown' é o do assalto, e usar o mesmo nos dois fazia a
        -- mensagem dizer "já foi roubado" para quem só tinha abordado.
        return { ok = false, code = 'holdup_cooldown' }
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

    -- Cooldown vencido: quem estava agachado se levanta e volta à caminhada. Nada mais toca este
    -- estado, então sem esta volta ele ficaria abalado até o próximo restart.
    local settled = {}
    for dealerId in pairs(shaken) do
        if not cooldowns[dealerId] and not active[dealerId] then settled[#settled + 1] = dealerId end
    end
    for index = 1, #settled do unshake(settled[index]) end
end

---@param source number
function Service.releaseForSource(source)
    local ids = {}
    for dealerId, holdup in pairs(active) do
        if holdup.source == source then ids[#ids + 1] = dealerId end
    end
    for index = 1, #ids do release(ids[index], 'source_gone') end
end

---Zera tudo que é transitório de um corredor: abordagem em curso, cooldown de abordagem e medo.
---Chamado quando o ped é recriado, porque o corredor novo não pode herdar nada do ped anterior —
---uma abordagem em curso que sobrevive ao ped recusa toda abordagem seguinte até vencer sozinha,
---e foi isso que fez o "já está sendo abordado" aparecer sem ninguém abordando.
---O cooldown de roubo não está aqui: ele é do corredor, não do ped, e vive na linha do banco.
---@param dealerId integer
function Service.resetDealer(dealerId)
    active[dealerId] = nil
    cooldowns[dealerId] = nil
    shaken[dealerId] = nil
end

---Zera os cooldowns de abordagem. Uso administrativo.
---@return integer cleared
function Service.clearCooldowns()
    local count = 0
    for dealerId in pairs(cooldowns) do
        cooldowns[dealerId] = nil
        count = count + 1
    end

    -- Sem o cooldown não há por que continuar agachado.
    local ids = {}
    for dealerId in pairs(shaken) do ids[#ids + 1] = dealerId end
    for index = 1, #ids do unshake(ids[index]) end
    return count
end

function Service.clear()
    active = {}
    cooldowns = {}
    shaken = {}
end
