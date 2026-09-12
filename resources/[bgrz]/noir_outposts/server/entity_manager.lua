-- Peds de dealer criados pelo servidor (OneSync). Somente state bags pequenos e não sensíveis.
NoirOutposts = NoirOutposts or {}

local Entities = {}
NoirOutposts.Entities = Entities

local shared = require 'config.shared'
local C = NoirOutposts.Constants
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local V = NoirOutposts.Validators

local registry = {}
local byNetId = {}

local function waitForEntity(entity)
    local attempts = 0
    while not DoesEntityExist(entity) and attempts < 50 do
        attempts = attempts + 1
        Wait(20)
    end
    return DoesEntityExist(entity)
end

local function forget(dealerId)
    local record = registry[dealerId]
    if not record then return end
    registry[dealerId] = nil
    if record.netId then byNetId[record.netId] = nil end
end

---@param outpostId string
---@param dealer table linha do dealer
---@return integer? netId
function Entities.spawnDealer(outpostId, dealer)
    Entities.despawnDealer(dealer.id)
    local definition = shared.outposts[outpostId]
    local corner = definition and definition.dealerCorners[dealer.corner_index or 0]
    local modelName = State.dealerModel(dealer)
    if not corner or not modelName then
        Log.warn('dealer_spawn_invalid', { dealerId = dealer.id, outpostId = outpostId, corner = dealer.corner_index })
        return nil
    end

    local model = joaat(modelName)
    local ped = CreatePed(4, model, corner.x, corner.y, corner.z, corner.w, true, true)
    if not ped or ped == 0 or not waitForEntity(ped) then
        Log.error('dealer_spawn_failed', { dealerId = dealer.id, outpostId = outpostId })
        if ped and ped ~= 0 and DoesEntityExist(ped) then DeleteEntity(ped) end
        return nil
    end

    pcall(SetEntityOrphanMode, ped, 2)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    local state = Entity(ped).state
    -- `noir:dealerId` é o gatilho que monta o ped no client, então tudo que ele precisa
    -- para montar vai antes. A ordem de chegada não é garantida, e por isso o client
    -- também reage à esquina chegando depois.
    state:set(C.StateBag.OUTPOST, outpostId, true)
    state:set(C.StateBag.DEALER_CORNER, dealer.corner_index, true)
    state:set(C.StateBag.DEALER_STATE, dealer.status, true)
    state:set(C.StateBag.DEALER, dealer.id, true)

    registry[dealer.id] = { entity = ped, netId = netId, outpostId = outpostId, model = model }
    byNetId[netId] = dealer.id
    Log.debug('dealer_spawned', { dealerId = dealer.id, outpostId = outpostId, netId = netId })
    return netId
end

---@param dealerId integer
function Entities.despawnDealer(dealerId)
    local record = registry[dealerId]
    if not record then return end
    if record.entity and DoesEntityExist(record.entity) then
        local state = Entity(record.entity).state
        state:set(C.StateBag.DEALER_CORNER, nil, true)
        state:set(C.StateBag.DEALER_STATE, nil, true)
        state:set(C.StateBag.DEALER, nil, true)
        state:set(C.StateBag.OUTPOST, nil, true)
        DeleteEntity(record.entity)
    end
    forget(dealerId)
end

---Quantos peds deste outpost estão registrados agora.
---@param outpostId string
---@return integer
function Entities.count(outpostId)
    local total = 0
    for _, record in pairs(registry) do
        if record.outpostId == outpostId and DoesEntityExist(record.entity) then
            total = total + 1
        end
    end
    return total
end

---@param outpostId string
function Entities.despawnOutpost(outpostId)
    local ids = {}
    for dealerId, record in pairs(registry) do
        if record.outpostId == outpostId then ids[#ids + 1] = dealerId end
    end
    for index = 1, #ids do Entities.despawnDealer(ids[index]) end
end

function Entities.despawnAll()
    local ids = {}
    for dealerId in pairs(registry) do ids[#ids + 1] = dealerId end
    for index = 1, #ids do Entities.despawnDealer(ids[index]) end
end

---@param dealerId integer
---@param status string
function Entities.setState(dealerId, status)
    local record = registry[dealerId]
    if not record or not DoesEntityExist(record.entity) then return end
    Entity(record.entity).state:set(C.StateBag.DEALER_STATE, status, true)
end

local ownerNativeWarned = false

---Há algum client transmitindo a entidade. Sem dono, a vida lida no servidor não vale.
---@param entity integer
---@return boolean
local function hasOwner(entity)
    local ok, owner = pcall(NetworkGetEntityOwner, entity)
    if not ok then
        if not ownerNativeWarned then
            ownerNativeWarned = true
            Log.warn('owner_native_unavailable', { detail = 'morte de corredor não será detectada' })
        end
        return false
    end
    return type(owner) == 'number' and owner >= 0
end

---Peds registrados que morreram. O corpo continua existindo, então só a vida distingue,
---e ela só é lida quando algum client está transmitindo o ped.
---@return integer[] dealerIds
function Entities.deadDealers()
    local dead = {}
    for dealerId, record in pairs(registry) do
        if DoesEntityExist(record.entity) then
            local owned = hasOwner(record.entity)
            local health = GetEntityHealth(record.entity)
            if owned and health > 0 then record.seenAlive = true end
            if V.isDealerDown(owned, record.seenAlive == true, health) then
                dead[#dead + 1] = dealerId
            end
        end
    end
    table.sort(dead)
    return dead
end

---@param dealerId integer
---@return boolean
function Entities.isAlive(dealerId)
    local record = registry[dealerId]
    if not record or not DoesEntityExist(record.entity) then return false end
    return GetEntityHealth(record.entity) > 0
end

---Corredor morto: o corpo fica onde caiu em vez de sumir na hora. Deixa de ser mantido à
---força, então o próprio jogo o limpa quando ninguém mais estiver por perto. Na recuperação
---o que sobrar é removido e um ped novo assume o posto.
---@param dealerId integer
function Entities.markCorpse(dealerId)
    local record = registry[dealerId]
    if not record or not DoesEntityExist(record.entity) then return end
    pcall(SetEntityOrphanMode, record.entity, 0)
    Entity(record.entity).state:set(C.StateBag.DEALER_STATE, C.DealerStatus.RECOVERING, true)
end

---@param dealerId integer
---@return integer? entity, integer? netId
function Entities.resolve(dealerId)
    local record = registry[dealerId]
    if not record then return nil end
    if not DoesEntityExist(record.entity) then
        forget(dealerId)
        return nil
    end
    return record.entity, record.netId
end

---Valida que o net ID enviado pelo client resolve para a entidade registrada do dealer.
---@param dealerId integer
---@param netId integer
---@return integer? entity
function Entities.validate(dealerId, netId)
    local record = registry[dealerId]
    if not record or record.netId ~= netId then return nil end
    if byNetId[netId] ~= dealerId then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or entity ~= record.entity or not DoesEntityExist(entity) then return nil end
    if GetEntityType(entity) ~= 1 or GetEntityModel(entity) ~= record.model then return nil end
    -- Mesma ressalva: só recusa por morte quando a vida é observável.
    if hasOwner(entity) and GetEntityHealth(entity) <= 0 then return nil end
    return entity
end

---Garante um ped vivo para cada corredor em operação. Quem está em recuperação por
---morte fica sem ped até voltar, que é o sinal visual de que ele saiu de circulação.
function Entities.syncAll()
    for outpostId, entry in pairs(State.outposts) do
        for dealerId, dealer in pairs(entry.dealers) do
            if dealer.status == C.DealerStatus.DEPLOYED and not Entities.resolve(dealerId) then
                Entities.spawnDealer(outpostId, dealer)
            end
        end
    end
    local stale = {}
    for dealerId in pairs(registry) do
        if not State.dealer(dealerId) then stale[#stale + 1] = dealerId end
    end
    for index = 1, #stale do Entities.despawnDealer(stale[index]) end
end

AddEventHandler('entityRemoved', function(entity)
    local dealerId = nil
    for id, record in pairs(registry) do
        if record.entity == entity then dealerId = id break end
    end
    if dealerId then
        Log.debug('dealer_entity_removed', { dealerId = dealerId })
        forget(dealerId)
    end
end)
