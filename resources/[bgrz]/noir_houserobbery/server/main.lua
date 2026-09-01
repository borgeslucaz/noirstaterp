local config = require 'config.server'
local shared = require 'config.shared'

local housesById = {}
local houseState = {}
local activeContracts = {}
local robberiesById = {}
local archivedRobberies = {}
local contractsBySource = {}
local playerCooldowns = {}
local activeCarry = {}
local startedLoot = {}
local startedPickup = {}
local allocatedBuckets = {}
local releasedBuckets = {}
local sequence = 0
local nextRoutingBucket = shared.baseRoutingBucket

local LOOT_TRANSITIONS = {
    available = { claiming = true, removed = true },
    dropped = { claiming = true, removed = true },
    claiming = { available = true, dropped = true, carried = true, removed = true },
    carried = { dropped = true, storing = true, removed = true },
    storing = { carried = true, stored = true, removed = true },
    stored = { sold = true, removed = true },
    sold = {},
    removed = {},
}

local function transitionLoot(pickup, nextState)
    local allowed = pickup and LOOT_TRANSITIONS[pickup.state]
    if not allowed or not allowed[nextState] then
        print(('^1[noir_houserobbery] Transição inválida %s/%s: %s -> %s^0'):format(
            pickup?.robberyId or 'unknown', pickup?.id or 'unknown', pickup?.state or 'nil', nextState
        ))
        return false
    end
    local previousState = pickup.state
    pickup.state = nextState
    if shared.debug then
        print(('[noir_houserobbery][robbery:%s][loot:%s] %s -> %s'):format(
            pickup.robberyId or 'unknown', pickup.id or 'unknown', previousState, nextState
        ))
    end
    return true
end

for index, house in ipairs(shared.houses) do
    housesById[house.id] = { index = index, config = house }
    houseState[house.id] = { status = 'available', cooldownUntil = 0, contractId = nil, loot = {}, pickups = {} }
end

local function now()
    return os.time()
end

local function debugLog(contract, pickup, message, ...)
    if not shared.debug then return end
    local prefix = ('[noir_houserobbery][robbery:%s]'):format(contract?.id or 'unknown')
    if pickup then prefix = prefix .. ('[loot:%s]'):format(pickup.id or 'unknown') end
    print((prefix .. ' ' .. message):format(...))
end

local function allocateRoutingBucket()
    local bucket = table.remove(releasedBuckets)
    if not bucket then
        bucket = nextRoutingBucket
        nextRoutingBucket += 1
    end
    allocatedBuckets[bucket] = true
    SetRoutingBucketEntityLockdownMode(bucket, 'strict')
    SetRoutingBucketPopulationEnabled(bucket, false)
    return bucket
end

local function releaseRoutingBucket(bucket)
    if not bucket or not allocatedBuckets[bucket] then return end
    allocatedBuckets[bucket] = nil
    SetRoutingBucketEntityLockdownMode(bucket, 'inactive')
    SetRoutingBucketPopulationEnabled(bucket, true)
    releasedBuckets[#releasedBuckets + 1] = bucket
end

local function notify(source, message, kind)
    exports.qbx_core:Notify(source, message, kind or 'inform')
end

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getCitizenId(source)
    return getPlayer(source)?.PlayerData.citizenid
end

local function getContract(source)
    local robberyId = contractsBySource[source]
    local citizenId = getCitizenId(source)
    local contract = robberyId and robberiesById[robberyId] or citizenId and activeContracts[citizenId]
    if contract and not contract.players[source] then
        contract.players[source] = { citizenId = citizenId, inside = false }
        contractsBySource[source] = contract.id
        if citizenId == contract.citizenId then contract.ownerSource = source end
    end
    return contract, citizenId
end

local function distanceTo(source, coords)
    local ped = GetPlayerPed(source)
    if ped <= 0 then return math.huge end
    return #(GetEntityCoords(ped) - coords)
end

local function makeId(source)
    sequence += 1
    return ('hr:%d:%d:%d'):format(now(), source, sequence)
end

local function shuffledIndexes(length)
    local result = {}
    for i = 1, length do result[i] = i end
    for i = length, 2, -1 do
        local j = math.random(i)
        result[i], result[j] = result[j], result[i]
    end
    return result
end

local function selectRuntimeEntries(entries, minimum, maximum)
    local result = {}
    local indexes = shuffledIndexes(#entries)
    local count = math.min(#entries, math.random(math.min(minimum, #entries), math.min(maximum, #entries)))
    for i = 1, count do
        local entry = entries[indexes[i]]
        result[#result + 1] = {
            id = i,
            configIndex = indexes[i],
            coords = entry.coords,
            pool = entry.pool,
            noise = entry.noise,
            model = entry.model,
            reward = entry.reward,
            rotation = entry.rotation,
            status = 'available',
            busyBy = nil,
        }
    end
    return result
end

local function chooseReaction()
    local roll, total = math.random(100), 0
    for _, reaction in ipairs(shared.residents.reactions) do
        total += reaction.chance
        if roll <= total then return reaction.name end
    end
    return 'flee'
end

local function setupHouse(contract)
    local house = housesById[contract.houseId].config
    local interior = shared.interiors[house.interior]
    local tier = shared.tiers[house.tier]
    local state = houseState[house.id]
    state.loot = selectRuntimeEntries(interior.loot, tier.loot.min, tier.loot.max)
    contract.searchPoints = state.loot
    local selectedPickups = selectRuntimeEntries(interior.pickups, tier.pickups.min, tier.pickups.max)
    contract.loot = {}
    state.pickups = contract.loot
    for _, pickup in ipairs(selectedPickups) do
        local lootId = ('pickup_%02d'):format(pickup.configIndex)
        contract.loot[lootId] = {
            id = lootId,
            robberyId = contract.id,
            configIndex = pickup.configIndex,
            coords = pickup.coords,
            model = pickup.model,
            reward = pickup.reward,
            rotation = pickup.rotation,
            state = 'available',
            carrier = nil,
            vehicle = nil,
            netId = nil,
            entity = nil,
            location = 'inside',
            dropped = false,
            currentBucket = nil,
            lastCoords = pickup.coords,
            lastHeading = pickup.rotation,
            lastBucket = contract.routingBucket,
        }
    end
    contract.resident = nil

    if #interior.residents > 0 and math.random() <= (house.residentChance or tier.residentChance) then
        local definition = interior.residents[math.random(#interior.residents)]
        contract.resident = {
            coords = definition.coords,
            model = definition.models[math.random(#definition.models)],
            reaction = chooseReaction(),
            state = 'sleeping',
            calledPolice = false,
            entity = nil,
            netId = nil,
            currentBucket = nil,
        }
    end
end

local function clientContract(contract, source)
    local house = housesById[contract.houseId].config
    local state = houseState[contract.houseId]
    return {
        id = contract.id,
        houseId = contract.houseId,
        tier = contract.tier,
        status = contract.status,
        coords = house.coords,
        interior = house.interior,
        routingBucket = contract.routingBucket,
        loot = contract.searchPoints,
        pickups = (function()
            local pickups = {}
            for lootId, pickup in pairs(contract.loot) do
                pickups[lootId] = {
                    id = pickup.id,
                    robberyId = pickup.robberyId,
                    coords = pickup.coords,
                    model = pickup.model,
                    rotation = pickup.rotation,
                    state = pickup.state,
                    carrier = pickup.carrier,
                    vehicle = pickup.vehicle,
                    netId = pickup.netId,
                    location = pickup.location,
                    dropped = pickup.dropped,
                    currentBucket = pickup.currentBucket,
                }
            end
            return pickups
        end)(),
        resident = contract.resident and {
            coords = contract.resident.coords,
            model = contract.resident.model,
            reaction = contract.resident.reaction,
            state = contract.resident.state,
            calledPolice = contract.resident.calledPolice,
            netId = contract.resident.netId,
        } or nil,
        inside = contract.players[source]?.inside == true,
    }
end

local function syncContract(contract)
    if not contract then return end
    for source in pairs(contract.players) do
        if GetPlayerName(source) then
            TriggerClientEvent('noir_houserobbery:client:syncContract', source, clientContract(contract, source))
        end
    end
end

local function registerSessionEntity(contract, entity, kind, logicalId, bucket)
    contract.entities[entity] = { kind = kind, logicalId = logicalId, bucket = bucket }
end

local function unregisterSessionEntity(contract, entity)
    if contract?.entities and entity then contract.entities[entity] = nil end
end

local function deleteEntityWithRetry(contract, entity, reason)
    if not entity then return true end
    for attempt = 1, 3 do
        if not DoesEntityExist(entity) then
            unregisterSessionEntity(contract, entity)
            return true
        end
        DeleteEntity(entity)
        if not DoesEntityExist(entity) then
            unregisterSessionEntity(contract, entity)
            return true
        end
        if attempt < 3 then Wait(50) end
    end
    debugLog(contract, nil, 'warning: entity=%s não foi removida reason=%s', entity, reason or 'unknown')
    return false
end

local function robberyBucketIsClean(contract)
    for entity, metadata in pairs(contract.entities) do
        if DoesEntityExist(entity) then
            local bucket = GetEntityRoutingBucket(entity)
            if bucket == contract.routingBucket or metadata.bucket == contract.routingBucket then return false end
        elseif metadata.bucket == contract.routingBucket then
            unregisterSessionEntity(contract, entity)
        end
    end
    return true
end

local function removeLootEntity(contract, pickup, reason)
    local entity = pickup.entity
    pickup.entity, pickup.netId, pickup.currentBucket = nil, nil, nil
    if entity then
        debugLog(contract, pickup, 'delete entity=%s reason=%s', entity, reason or 'unknown')
        return deleteEntityWithRetry(contract, entity, reason)
    end
    return true
end

local function applyLootStateBag(contract, pickup)
    local entity = pickup.entity
    if not entity or not DoesEntityExist(entity) then return end
    local state = Entity(entity).state
    state:set('robbery:id', contract.id, true)
    state:set('loot:id', pickup.id, true)
    state:set('loot:carrier', pickup.carrier or 0, true)
    state:set('loot:rotation', pickup.rotation or 0.0, true)
    state:set('loot:dropped', pickup.dropped == true, true)
    state:set('loot:state', pickup.state, true)
    state:set('loot:bucket', pickup.currentBucket or 0, true)
end

local function spawnLootEntity(contract, pickup, bucket, coords)
    removeLootEntity(contract, pickup, 'representation_replaced')
    local model = type(pickup.model) == 'number' and pickup.model or joaat(pickup.model)
    local position = coords or pickup.coords
    local entity = CreateObjectNoOffset(model, position.x, position.y, position.z, true, true, false)
    if entity == 0 or not DoesEntityExist(entity) then
        print(('^1[noir_houserobbery] Falha ao criar entidade %s/%s^0'):format(contract.id, pickup.id))
        return false
    end

    SetEntityOrphanMode(entity, 2)
    SetEntityRoutingBucket(entity, bucket)
    SetEntityHeading(entity, pickup.rotation or 0.0)
    FreezeEntityPosition(entity, pickup.state == 'available' or pickup.state == 'claiming')
    pickup.entity = entity
    pickup.netId = NetworkGetNetworkIdFromEntity(entity)
    pickup.currentBucket = bucket
    pickup.lastCoords = vec3(position.x, position.y, position.z)
    pickup.lastHeading = pickup.rotation or 0.0
    pickup.lastBucket = bucket
    registerSessionEntity(contract, entity, 'loot', pickup.id, bucket)
    applyLootStateBag(contract, pickup)
    debugLog(contract, pickup, 'create entity=%s netId=%s bucket=%s state=%s', entity, pickup.netId, bucket, pickup.state)
    return true
end

local function lootEntityIsValid(contract, pickup, expectedBucket)
    local entity = pickup.entity
    if not entity or not DoesEntityExist(entity) then return false end
    local state = Entity(entity).state
    if state['robbery:id'] ~= contract.id or state['loot:id'] ~= pickup.id then return false end
    local bucket = GetEntityRoutingBucket(entity)
    return expectedBucket == nil or bucket == expectedBucket
end

local function updateLootRepresentation(contract, pickup)
    if not lootEntityIsValid(contract, pickup, pickup.currentBucket) then return false end
    FreezeEntityPosition(pickup.entity, pickup.state == 'available' or pickup.state == 'claiming')
    applyLootStateBag(contract, pickup)
    return true
end

local function moveLootEntityToBucket(contract, pickup, bucket, coords, heading)
    local entity = pickup.entity
    if entity and DoesEntityExist(entity) then
        pcall(DetachEntity, entity, true, true)
        SetEntityRoutingBucket(entity, bucket)
        if coords then SetEntityCoords(entity, coords.x, coords.y, coords.z, false, false, false, false) end
        if heading then SetEntityHeading(entity, heading) end
        if DoesEntityExist(entity) and GetEntityRoutingBucket(entity) == bucket then
            pickup.currentBucket = bucket
            pickup.lastBucket = bucket
            if coords then
                pickup.coords = vec3(coords.x, coords.y, coords.z)
                pickup.lastCoords = pickup.coords
            end
            if heading then
                pickup.rotation = heading
                pickup.lastHeading = heading
            end
            if contract.entities[entity] then
                contract.entities[entity].bucket = bucket
            else
                registerSessionEntity(contract, entity, 'loot', pickup.id, bucket)
            end
            updateLootRepresentation(contract, pickup)
            debugLog(contract, pickup, 'bucket -> %s entity=%s netId=%s', bucket, entity, pickup.netId)
            return true
        end
    end
    return spawnLootEntity(contract, pickup, bucket, coords or pickup.lastCoords or pickup.coords)
end

local function ensureLootEntity(contract, pickup)
    local physical = pickup.state == 'available' or pickup.state == 'claiming'
        or pickup.state == 'dropped' or pickup.state == 'carried'
    if not physical then
        if pickup.entity then removeLootEntity(contract, pickup, 'non_physical_state') end
        return false
    end
    local bucket = pickup.currentBucket or pickup.lastBucket
        or (pickup.location == 'inside' and contract.routingBucket or 0)
    if lootEntityIsValid(contract, pickup, bucket) then
        updateLootRepresentation(contract, pickup)
        return true
    end
    return spawnLootEntity(contract, pickup, bucket, pickup.lastCoords or pickup.coords)
end

local function spawnInteriorLoot(contract)
    for _, pickup in pairs(contract.loot) do
        if pickup.location == 'inside' and (pickup.state == 'available' or pickup.state == 'claiming' or pickup.state == 'dropped') then
            pickup.currentBucket = contract.routingBucket
            pickup.lastBucket = contract.routingBucket
            ensureLootEntity(contract, pickup)
        end
    end
end

local function spawnResidentEntity(contract)
    local resident = contract.resident
    if not resident or resident.entity and DoesEntityExist(resident.entity) then return end
    local coords = resident.coords
    local model = type(resident.model) == 'number' and resident.model or joaat(resident.model)
    local entity = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, true, true)
    if entity == 0 or not DoesEntityExist(entity) then
        debugLog(contract, nil, 'warning: falha ao criar resident ped')
        return
    end
    SetEntityOrphanMode(entity, 2)
    SetEntityRoutingBucket(entity, contract.routingBucket)
    resident.entity = entity
    resident.netId = NetworkGetNetworkIdFromEntity(entity)
    resident.currentBucket = contract.routingBucket
    registerSessionEntity(contract, entity, 'resident', 'resident', contract.routingBucket)
    local state = Entity(entity).state
    state:set('robbery:id', contract.id, true)
    state:set('robbery:resident', true, true)
    debugLog(contract, nil, 'create resident entity=%s netId=%s bucket=%s', entity, resident.netId, contract.routingBucket)
end

local function cleanupRobberyEntities(contract, interiorOnly, reason)
    local bucket = contract.routingBucket
    for _, pickup in pairs(contract.loot) do
        local entity = pickup.entity
        local actualBucket = entity and DoesEntityExist(entity) and GetEntityRoutingBucket(entity) or pickup.currentBucket
        if not interiorOnly or actualBucket == bucket or pickup.currentBucket == bucket then
            removeLootEntity(contract, pickup, reason or 'session_cleanup')
        end
    end
    if contract.resident?.entity then
        deleteEntityWithRetry(contract, contract.resident.entity, reason or 'session_cleanup')
        contract.resident.entity, contract.resident.netId, contract.resident.currentBucket = nil, nil, nil
    end
    for entity, metadata in pairs(contract.entities) do
        local actualBucket = DoesEntityExist(entity) and GetEntityRoutingBucket(entity) or metadata.bucket
        if not interiorOnly or actualBucket == bucket or metadata.bucket == bucket then
            deleteEntityWithRetry(contract, entity, reason or 'registry_cleanup')
        end
    end
end

local function getPickup(contract, robberyId, lootId)
    if not contract or contract.id ~= robberyId or type(lootId) ~= 'string' then return nil end
    return contract.loot[lootId]
end

local function getCarriedPickup(source, contract)
    local carry = activeCarry[source]
    if not carry or carry.robberyId ~= contract?.id then return nil, nil end
    return contract.loot[carry.lootId], carry
end

local function recreateCarriedLoot(source, contract, bucket, targetCoords, targetHeading)
    local pickup = getCarriedPickup(source, contract)
    if not pickup or pickup.state ~= 'carried' or pickup.carrier ~= source then return end
    local ped = GetPlayerPed(source)
    if ped <= 0 then return end
    local coords = targetCoords or GetEntityCoords(ped)
    local heading = targetHeading or GetEntityHeading(ped)
    if moveLootEntityToBucket(contract, pickup, bucket, coords, heading) then
        TriggerClientEvent('noir_houserobbery:client:carryEntity', source, {
            robberyId = contract.id,
            lootId = pickup.id,
            netId = pickup.netId,
        })
    end
end

local function cooldownHouse(houseId)
    local state = houseState[houseId]
    state.status = 'cooldown'
    state.contractId = nil
    state.cooldownUntil = now() + config.cooldowns.house
    state.loot = {}
    state.pickups = {}
end

local function finalizeRobbery(contract, reason, completed)
    if not contract or contract.status == 'closing' or contract.status == 'closed' then return false end

    contract.status = 'closing'
    debugLog(contract, nil, 'session closing bucket=%s completed=%s', contract.routingBucket, completed == true)
    local preserveCarry = {}

    -- Resolve carries before cleaning the interior. A normal close lets carriers leave;
    -- a forced close removes loot that is still physically inside the session.
    for playerSource, participant in pairs(contract.players) do
        local pickup = getCarriedPickup(playerSource, contract)
        if pickup and pickup.state == 'carried' then
            if participant.inside and completed == true then
                local house = housesById[contract.houseId].config
                local outside = vec3(house.coords.x, house.coords.y, house.coords.z)
                pickup.location = 'outside'
                pickup.lastCoords = outside
                pickup.lastBucket = 0
                moveLootEntityToBucket(contract, pickup, 0, outside, pickup.lastHeading)
                preserveCarry[playerSource] = true
            elseif participant.inside then
                transitionLoot(pickup, 'removed')
                pickup.carrier = nil
                pickup.location = 'removed'
                removeLootEntity(contract, pickup, 'forced_close_carried_inside')
                activeCarry[playerSource] = nil
            else
                preserveCarry[playerSource] = true
            end
        end
    end

    -- Anything that still belongs physically to the house is removed. External
    -- carried/dropped loot and stored loot deliberately survive in the archive.
    for _, pickup in pairs(contract.loot) do
        local entity = pickup.entity
        local bucket = entity and DoesEntityExist(entity) and GetEntityRoutingBucket(entity) or pickup.currentBucket
        if bucket == contract.routingBucket or pickup.currentBucket == contract.routingBucket then
            if pickup.state ~= 'removed' and pickup.state ~= 'sold' and pickup.state ~= 'stored' then
                transitionLoot(pickup, 'removed')
            end
            pickup.carrier = nil
            pickup.location = 'removed'
        end
    end
    cleanupRobberyEntities(contract, true, 'session_cleanup')

    for citizenId in pairs(contract.members) do
        playerCooldowns[citizenId] = now() + config.cooldowns.player
        activeContracts[citizenId] = nil
    end
    for playerSource, participant in pairs(contract.players) do
        if not preserveCarry[playerSource] then activeCarry[playerSource] = nil end
        startedLoot[playerSource] = nil
        startedPickup[playerSource] = nil
        contractsBySource[playerSource] = nil
        if participant.citizenId then playerCooldowns[participant.citizenId] = now() + config.cooldowns.player end
        if GetPlayerName(playerSource) then
            if participant.inside then
                local house = housesById[contract.houseId].config
                local ped = GetPlayerPed(playerSource)
                exports.qbx_core:SetPlayerBucket(playerSource, 0)
                if ped > 0 then
                    SetEntityCoords(ped, house.coords.x, house.coords.y, house.coords.z, false, false, false, false)
                    participant.inside = false
                end
            else
                exports.qbx_core:SetPlayerBucket(playerSource, 0)
            end
        end
    end

    cooldownHouse(contract.houseId)
    robberiesById[contract.id] = nil
    archivedRobberies[contract.id] = contract
    contract.status = 'closed'
    if robberyBucketIsClean(contract) then
        releaseRoutingBucket(contract.routingBucket)
        debugLog(contract, nil, 'bucket cleanup complete bucket=%s; session closed', contract.routingBucket)
    else
        -- Keep the bucket allocated/quarantined: a dirty bucket is never reused.
        debugLog(contract, nil, 'warning: bucket=%s permanece alocado por entity leak', contract.routingBucket)
    end

    for playerSource in pairs(contract.players) do
        if GetPlayerName(playerSource) then
            TriggerClientEvent('noir_houserobbery:client:contractEnded', playerSource,
                reason or 'Contrato encerrado.', completed == true, preserveCarry[playerSource] == true,
                preserveCarry[playerSource] and clientContract(contract, playerSource) or nil)
        end
    end
    return true
end

local function finalizeContract(source, reason, completed)
    return finalizeRobbery(getContract(source), reason, completed)
end

local function allLootResolved(contract)
    for _, loot in ipairs(contract.searchPoints) do
        if loot.status ~= 'opened' then return false end
    end
    for _, pickup in pairs(contract.loot) do
        if pickup.state ~= 'stored' then return false end
    end
    return true
end

local function requestContract(source)
    local player = getPlayer(source)
    if not player then return end
    local citizenId = player.PlayerData.citizenid

    if activeContracts[citizenId] then
        NoirBurnerIntegration.sendMessage(source, 'Você já tem um endereço. Termine o serviço primeiro.')
        return
    end
    if playerCooldowns[citizenId] and playerCooldowns[citizenId] > now() then
        NoirBurnerIntegration.sendMessage(source, 'Nada por enquanto. Fique fora do radar.')
        return
    end

    local eligible = {}
    for _, house in ipairs(shared.houses) do
        local state = houseState[house.id]
        if state.status == 'cooldown' and state.cooldownUntil <= now() then state.status = 'available' end
        if house.tier == 1 and shared.tiers[house.tier].enabled and state.status == 'available' then
            eligible[#eligible + 1] = house
        end
    end
    if #eligible == 0 then
        NoirBurnerIntegration.sendMessage(source, 'Não tenho nenhum lugar seguro agora.')
        return
    end

    local house = eligible[math.random(#eligible)]
    local contract = {
        id = makeId(source), houseId = house.id, tier = house.tier, status = 'assigned',
        createdAt = now(), enteredAt = nil, ownerSource = source, citizenId = citizenId,
        routingBucket = allocateRoutingBucket(),
        players = { [source] = { citizenId = citizenId, inside = false } },
        members = { [citizenId] = true },
        entities = {},
    }
    activeContracts[citizenId] = contract
    robberiesById[contract.id] = contract
    contractsBySource[source] = contract.id
    houseState[house.id].status = 'reserved'
    houseState[house.id].contractId = contract.id
    setupHouse(contract)
    TriggerClientEvent('noir_houserobbery:client:contractAssigned', source, clientContract(contract, source))
    NoirBurnerIntegration.sendLocation(source, { coords = house.coords, id = contract.id })
end

exports('RequestHouseContract', requestContract)

local function addParticipant(contract, source)
    source = tonumber(source)
    local player = source and getPlayer(source)
    if not contract or contract.status == 'closing' or contract.status == 'closed' or not player then return false end
    local citizenId = player.PlayerData.citizenid
    if contract.members[citizenId] then
        contract.players[source] = { citizenId = citizenId, inside = false }
        contractsBySource[source] = contract.id
        return true
    end
    local count = 0
    for _ in pairs(contract.members) do count += 1 end
    if count >= config.maxPlayers or activeContracts[citizenId] then return false end

    contract.members[citizenId] = true
    contract.players[source] = { citizenId = citizenId, inside = false }
    activeContracts[citizenId] = contract
    contractsBySource[source] = contract.id
    TriggerClientEvent('noir_houserobbery:client:contractAssigned', source, clientContract(contract, source))
    syncContract(contract)
    return true
end

-- Server-only integration point for the future party/invite flow.
exports('AddParticipant', function(ownerSource, targetSource)
    local contract = getContract(tonumber(ownerSource))
    if not contract or contract.citizenId ~= getCitizenId(tonumber(ownerSource)) then return false end
    return addParticipant(contract, targetSource)
end)

lib.callback.register('noir_houserobbery:server:getContract', function(source)
    local contract = getContract(source)
    return contract and clientContract(contract, source) or nil
end)

local function startSkillcheck(source, houseId)
    local contract = getContract(source)
    local houseData = housesById[houseId]
    if not contract or not houseData or contract.houseId ~= houseId or contract.status ~= 'assigned' then return false end
    local state = houseState[houseId]
    if state.contractId ~= contract.id or state.status ~= 'reserved' then return false end
    if distanceTo(source, houseData.config.coords) > config.maxExteriorDistance then return false end

    local police = exports.qbx_core:GetDutyCountType('leo')
    if police < config.minimumPolice then
        notify(source, ('São necessários %d policiais em serviço.'):format(config.minimumPolice), 'error')
        return false
    end
    contract.status = 'breaching'
    return shared.interiors[houseData.config.interior].skillcheck
end

local function enterHouse(source, contract)
    local house = housesById[contract.houseId].config
    local interior = shared.interiors[house.interior]
    local ped = GetPlayerPed(source)
    local participant = contract.players[source]
    if not participant then return end
    spawnInteriorLoot(contract)
    spawnResidentEntity(contract)
    recreateCarriedLoot(source, contract, contract.routingBucket, interior.entry.xyz, interior.entry.w)
    exports.qbx_core:SetPlayerBucket(source, contract.routingBucket)
    SetEntityCoords(ped, interior.entry.x, interior.entry.y, interior.entry.z, false, false, false, false)
    SetEntityHeading(ped, interior.entry.w)
    participant.inside = true
    contract.status = 'active'
    contract.enteredAt = contract.enteredAt or now()
    houseState[contract.houseId].status = 'active'
    TriggerClientEvent('noir_houserobbery:client:enteredHouse', source, clientContract(contract, source))
    syncContract(contract)
end

local function processSkillcheckResult(src, houseId, success)
    local contract = getContract(src)
    if not contract or contract.houseId ~= houseId or contract.status ~= 'breaching' then return end
    if distanceTo(src, housesById[houseId].config.coords) > config.maxExteriorDistance then return end
    if success ~= true then
        contract.status = 'assigned'
        notify(src, 'A gazua escapou. Isso fez barulho.', 'error')
        TriggerClientEvent('noir_houserobbery:client:addNoise', src, shared.noise.actions.failedSkillcheck)
        return
    end
    notify(src, 'A fechadura cedeu.', 'success')
    enterHouse(src, contract)
end

local function attemptBreach(playerSource, isAdvanced)
    local contract = getContract(playerSource)
    if not contract or contract.status ~= 'assigned' then return end
    local house = housesById[contract.houseId].config
    if distanceTo(playerSource, house.coords) > config.maxExteriorDistance then return end
    local player = getPlayer(playerSource)
    local requiredItem = isAdvanced and config.requiredItems.advanced or config.requiredItems.basic
    if not player or not player.Functions.GetItemByName(requiredItem) then return end
    local difficulty = startSkillcheck(playerSource, contract.houseId)
    if not difficulty then return end
    TriggerClientEvent('noir_houserobbery:client:startSkillcheck', playerSource, difficulty)
end

RegisterNetEvent('noir_houserobbery:server:skillcheckResult', function(success)
    local src = source
    local contract = getContract(src)
    if not contract then return end
    processSkillcheckResult(src, contract.houseId, success == true)
end)

RegisterNetEvent('noir_houserobbery:server:attemptEntry', function()
    local src = source
    local player = getPlayer(src)
    if not player then return end
    local hasAdvanced = player.Functions.GetItemByName(config.requiredItems.advanced) ~= nil
    local hasBasic = player.Functions.GetItemByName(config.requiredItems.basic) ~= nil
    if not hasAdvanced and not hasBasic then
        notify(src, 'Você precisa de uma gazua.', 'error')
        return
    end
    attemptBreach(src, hasAdvanced)
end)

RegisterNetEvent('noir_houserobbery:server:enterHouse', function(houseId)
    local src = source
    local contract = getContract(src)
    if not contract or contract.houseId ~= houseId or contract.status ~= 'active' or contract.players[src]?.inside then return end
    if distanceTo(src, housesById[houseId].config.coords) > config.maxExteriorDistance then return end
    enterHouse(src, contract)
end)

RegisterNetEvent('noir_houserobbery:server:leaveHouse', function()
    local src = source
    local contract = getContract(src)
    local participant = contract and contract.players[src]
    if not contract or contract.status ~= 'active' or not participant?.inside then return end
    local house = housesById[contract.houseId].config
    local exit = shared.interiors[house.interior].exit.xyz
    if distanceTo(src, exit) > config.maxInteriorDistance then return end
    local ped = GetPlayerPed(src)
    recreateCarriedLoot(src, contract, 0, house.coords, GetEntityHeading(ped))
    exports.qbx_core:SetPlayerBucket(src, 0)
    SetEntityCoords(ped, house.coords.x, house.coords.y, house.coords.z, false, false, false, false)
    participant.inside = false
    TriggerClientEvent('noir_houserobbery:client:leftHouse', src, clientContract(contract, src))
    syncContract(contract)
end)

local function validInside(source, contract, coords)
    return contract and contract.status == 'active'
        and contract.players[source]?.inside == true
        and GetPlayerRoutingBucket(source) == contract.routingBucket
        and distanceTo(source, coords) <= config.maxInteriorDistance
end

local function validPickupLocation(source, contract, pickup)
    if not contract or not pickup then return false end
    if pickup.location == 'outside' then
        return contract.status == 'active'
            and contract.players[source]?.inside == false
            and GetPlayerRoutingBucket(source) == 0
            and distanceTo(source, pickup.coords) <= config.maxExteriorDistance
    end
    return validInside(source, contract, pickup.coords)
end

lib.callback.register('noir_houserobbery:server:checkLoot', function(source, lootId)
    local contract = getContract(source)
    if activeCarry[source] or startedPickup[source] or startedLoot[source] then return false end
    local loot = contract and houseState[contract.houseId].loot[tonumber(lootId)]
    if not loot or not validInside(source, contract, loot.coords) or loot.status ~= 'available' then return false end
    loot.status, loot.busyBy = 'busy', source
    local duration = math.random(config.searchDuration.min, config.searchDuration.max)
    startedLoot[source] = {
        contractId = contract.id,
        lootId = tonumber(lootId),
        readyAt = GetGameTimer() + duration,
        startedAt = now(),
    }
    syncContract(contract)
    return { duration = duration }
end)

RegisterNetEvent('noir_houserobbery:server:finishLoot', function(lootId)
    local src = source
    local contract = getContract(src)
    local started = startedLoot[src]
    local loot = contract and houseState[contract.houseId].loot[tonumber(lootId)]
    if not started or started.contractId ~= contract?.id or started.lootId ~= tonumber(lootId) then return end
    if GetGameTimer() < started.readyAt then return end
    if not loot or loot.status ~= 'busy' or loot.busyBy ~= src or not validInside(src, contract, loot.coords) then return end

    local reward = config.rewards[loot.pool[math.random(#loot.pool)]]
    local rolls = math.random(reward.rolls.min, math.min(reward.rolls.max, #reward.items))
    local indexes = shuffledIndexes(#reward.items)
    for i = 1, rolls do
        exports.ox_inventory:AddItem(src, reward.items[indexes[i]], math.random(reward.amount.min, reward.amount.max))
    end
    loot.status, loot.busyBy = 'opened', nil
    startedLoot[src] = nil
    syncContract(contract)
end)

RegisterNetEvent('noir_houserobbery:server:cancelLoot', function(lootId)
    local src = source
    local contract = getContract(src)
    local loot = contract and houseState[contract.houseId].loot[tonumber(lootId)]
    if loot and loot.status == 'busy' and loot.busyBy == src then
        loot.status, loot.busyBy = 'available', nil
        startedLoot[src] = nil
        syncContract(contract)
    end
end)

lib.callback.register('noir_houserobbery:server:beginCarry', function(source, robberyId, lootId)
    local contract = getContract(source)
    if activeCarry[source] or startedPickup[source] or startedLoot[source] then return false end
    local pickup = getPickup(contract, robberyId, lootId)
    if not pickup or (pickup.state ~= 'available' and pickup.state ~= 'dropped')
        or not validPickupLocation(source, contract, pickup) then return false end

    -- This transition is atomic in the server event loop. A second request sees claiming.
    if not transitionLoot(pickup, 'claiming') then return false end
    pickup.carrier = source
    local duration = math.random(config.carryClaimDuration.min, config.carryClaimDuration.max)
    startedPickup[source] = {
        robberyId = contract.id,
        lootId = pickup.id,
        previousState = pickup.dropped and 'dropped' or 'available',
        readyAt = GetGameTimer() + duration,
        startedAt = now(),
    }
    updateLootRepresentation(contract, pickup)
    syncContract(contract)
    return { duration = duration }
end)

RegisterNetEvent('noir_houserobbery:server:finishCarry', function(robberyId, lootId)
    local src = source
    local contract = getContract(src)
    local started = startedPickup[src]
    local pickup = getPickup(contract, robberyId, lootId)
    if not started or started.robberyId ~= robberyId or started.lootId ~= lootId then return end
    if GetGameTimer() < started.readyAt then return end
    if not pickup or pickup.state ~= 'claiming' or pickup.carrier ~= src or not validPickupLocation(src, contract, pickup) then return end

    local participant = contract.players[src]
    local ped = GetPlayerPed(src)
    if not participant or ped <= 0 then return end
    if not transitionLoot(pickup, 'carried') then return end
    pickup.location = participant.inside and 'inside' or 'outside'
    pickup.dropped = false
    pickup.vehicle = nil
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local bucket = participant.inside and contract.routingBucket or 0
    pickup.lastCoords = vec3(coords.x, coords.y, coords.z)
    pickup.lastHeading = heading
    pickup.lastBucket = bucket
    activeCarry[src] = { robberyId = contract.id, lootId = pickup.id, createdAt = now() }
    startedPickup[src] = nil
    moveLootEntityToBucket(contract, pickup, bucket, coords, heading)
    debugLog(contract, pickup, 'claiming -> carried carrier=%s entity=%s netId=%s bucket=%s',
        src, pickup.entity or 0, pickup.netId or 0, bucket)
    syncContract(contract)
    TriggerClientEvent('noir_houserobbery:client:carryApproved', src, {
        robberyId = contract.id,
        lootId = pickup.id,
        netId = pickup.netId,
    })
end)

RegisterNetEvent('noir_houserobbery:server:cancelPickup', function(robberyId, lootId)
    local src = source
    local contract = getContract(src)
    local started = startedPickup[src]
    local pickup = getPickup(contract, robberyId, lootId)
    if started and started.robberyId == robberyId and started.lootId == lootId
        and pickup and pickup.state == 'claiming' and pickup.carrier == src then
        if not transitionLoot(pickup, started.previousState) then return end
        pickup.carrier = nil
        startedPickup[src] = nil
        updateLootRepresentation(contract, pickup)
        syncContract(contract)
    end
end)

local function dropCarriedLoot(src, contract, reason, notifyClient)
    local pickup = getCarriedPickup(src, contract)
    local participant = contract and contract.players[src]
    if not pickup or pickup.state ~= 'carried' or pickup.carrier ~= src or not participant then return false end

    local ped = GetPlayerPed(src)
    local coords = pickup.lastCoords or pickup.coords
    local heading = pickup.lastHeading or pickup.rotation or 0.0
    local bucket = pickup.lastBucket or pickup.currentBucket or (participant.inside and contract.routingBucket or 0)
    if GetPlayerName(src) and ped > 0 then
        coords = GetEntityCoords(ped)
        heading = GetEntityHeading(ped)
        bucket = GetPlayerRoutingBucket(src)
    elseif not coords and pickup.entity and DoesEntityExist(pickup.entity) then
        coords = GetEntityCoords(pickup.entity)
    end

    if not transitionLoot(pickup, 'dropped') then return false end
    pickup.carrier = nil
    pickup.vehicle = nil
    pickup.coords = vec3(coords.x, coords.y, coords.z)
    pickup.rotation = heading
    pickup.location = bucket == contract.routingBucket and 'inside' or 'outside'
    pickup.dropped = true
    pickup.lastCoords = pickup.coords
    pickup.lastHeading = heading
    pickup.lastBucket = bucket
    activeCarry[src] = nil
    moveLootEntityToBucket(contract, pickup, bucket, pickup.coords, heading)
    debugLog(contract, pickup, 'carried -> dropped reason=%s coords=%s bucket=%s',
        reason or 'unknown', json.encode(pickup.coords), bucket)
    if contract.status ~= 'closed' then syncContract(contract) end
    if notifyClient and GetPlayerName(src) then TriggerClientEvent('noir_houserobbery:client:carryCancelled', src) end
    return true
end

RegisterNetEvent('noir_houserobbery:server:dropCarry', function(robberyId, lootId)
    local src = source
    local carry = activeCarry[src]
    local contract = getContract(src)
    if not contract and carry?.robberyId == robberyId then contract = archivedRobberies[robberyId] end
    local pickup, carry = getCarriedPickup(src, contract)
    if not pickup or not carry or carry.robberyId ~= robberyId or carry.lootId ~= lootId then return end
    dropCarriedLoot(src, contract, 'manual', true)
end)

RegisterNetEvent('noir_houserobbery:server:storeCarryInVehicle', function(robberyId, lootId, vehicleNetId)
    local src = source
    local carryState = activeCarry[src]
    local contract = getContract(src)
    if not contract and carryState?.robberyId == robberyId then contract = archivedRobberies[robberyId] end
    local pickup, carry = getCarriedPickup(src, contract)
    if not contract or (contract.status ~= 'active' and contract.status ~= 'closed') or contract.players[src]?.inside
        or not pickup or not carry or carry.robberyId ~= robberyId or carry.lootId ~= lootId
        or pickup.state ~= 'carried' or pickup.carrier ~= src then return end
    if now() - carry.createdAt > config.carryTokenLifetime or GetPlayerRoutingBucket(src) ~= 0 then return end

    vehicleNetId = tonumber(vehicleNetId)
    local vehicle = vehicleNetId and NetworkGetEntityFromNetworkId(vehicleNetId) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    if GetEntityRoutingBucket(vehicle) ~= 0 then return end
    if distanceTo(src, GetEntityCoords(vehicle)) > config.maxVehicleDistance then return end
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    if lockStatus > 1 and lockStatus ~= 8 then
        notify(src, 'O veículo está trancado.', 'error')
        return
    end
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate or plate == '' then return end
    plate = plate:gsub('^%s*(.-)%s*$', '%1')
    local inventoryOk, inventory = pcall(function()
        return exports.ox_inventory:GetInventory({ id = 'trunk' .. plate, type = 'trunk', netid = vehicleNetId })
    end)
    if not inventoryOk or not inventory then
        notify(src, 'Esse veículo não possui um porta-malas utilizável.', 'error')
        return
    end
    if not transitionLoot(pickup, 'storing') then return end
    local carryOk, canCarry = pcall(function()
        return exports.ox_inventory:CanCarryItem(inventory.id, pickup.reward, 1)
    end)
    if not carryOk or not canCarry then
        transitionLoot(pickup, 'carried')
        notify(src, 'O porta-malas está cheio.', 'error')
        return
    end
    local addOk, success = pcall(function()
        return exports.ox_inventory:AddItem(inventory.id, pickup.reward, 1, {
            stolen = true,
            robberyId = contract.id,
            lootId = pickup.id,
        })
    end)
    if not addOk or not success then
        transitionLoot(pickup, 'carried')
        notify(src, 'Não foi possível guardar o objeto.', 'error')
        return
    end

    removeLootEntity(contract, pickup, 'stored_in_vehicle')
    if not transitionLoot(pickup, 'stored') then return end
    pickup.carrier = nil
    pickup.vehicle = plate
    pickup.location = 'vehicle'
    activeCarry[src] = nil
    if contract.status ~= 'closed' then syncContract(contract) end
    TriggerClientEvent('noir_houserobbery:client:carryStored', src)
    notify(src, 'Objeto guardado no porta-malas.', 'success')
    if contract.status == 'active' and allLootResolved(contract) then
        finalizeContract(src, 'O endereço foi limpo. Serviço encerrado.', true)
    end
end)

RegisterNetEvent('noir_houserobbery:server:residentCalledPolice', function(contractId)
    local src = source
    local contract = getContract(src)
    if not contract or contract.id ~= contractId or contract.status ~= 'active'
        or not contract.players[src]?.inside or not contract.resident then return end
    if contract.resident.calledPolice then return end
    contract.resident.calledPolice = true
    contract.resident.state = 'called_police'
    NoirHouseDispatch.alert(src, 'Morador reportou invasão residencial')
end)

RegisterNetEvent('noir_houserobbery:server:abortContract', function(reason)
    finalizeContract(source, 'Você abandonou o serviço.', false)
end)

RegisterNetEvent('noir_houserobbery:server:completeContract', function()
    local src = source
    local contract = getContract(src)
    if not contract or contract.status ~= 'active' or contract.players[src]?.inside or activeCarry[src] then return end
    local house = housesById[contract.houseId].config
    if distanceTo(src, house.coords) > 8.0 then return end
    finalizeContract(src, 'Você encerrou o serviço e saiu do endereço.', true)
end)

local function releasePlayerClaims(src, contract)
    local started = startedPickup[src]
    local pickup = started and getPickup(contract, started.robberyId, started.lootId)
    if pickup and pickup.state == 'claiming' and pickup.carrier == src then
        if transitionLoot(pickup, started.previousState) then pickup.carrier = nil end
        updateLootRepresentation(contract, pickup)
    end
    startedPickup[src] = nil

    local smallStarted = startedLoot[src]
    local loot = smallStarted and contract and houseState[contract.houseId].loot[smallStarted.lootId]
    if loot and loot.status == 'busy' and loot.busyBy == src then loot.status, loot.busyBy = 'available', nil end
    startedLoot[src] = nil
end

local function handleDisconnect(src)
    local robberyId = contractsBySource[src]
    local carry = activeCarry[src]
    robberyId = robberyId or carry?.robberyId
    local contract = robberyId and (robberiesById[robberyId] or archivedRobberies[robberyId])
    if not contract then return end

    -- Explicit lifecycle rule: carried loot becomes a dropped world entity.
    dropCarriedLoot(src, contract, 'disconnect', false)
    releasePlayerClaims(src, contract)
    contract.players[src] = nil
    contractsBySource[src] = nil
    if contract.ownerSource == src then contract.ownerSource = nil end
    if contract.status ~= 'closed' then
        if not next(contract.players) then
            -- Nobody is left in the session: treat it as cancelled right away
            -- instead of leaving the house's resident/loot alive in the world.
            finalizeRobbery(contract, 'O contrato foi cancelado.', false)
        else
            syncContract(contract)
        end
    end
end

AddEventHandler('playerDropped', function() handleDisconnect(source) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', handleDisconnect)

AddStateBagChangeHandler('isDead', nil, function(bagName, _, value)
    if not value then return end
    local playerSource = GetPlayerFromStateBagName(bagName)
    if playerSource and contractsBySource[playerSource] then
        local contract = getContract(playerSource)
        dropCarriedLoot(playerSource, contract, 'death', true)
        releasePlayerClaims(playerSource, contract)
        syncContract(contract)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, contract in pairs(robberiesById) do
        cleanupRobberyEntities(contract, false, 'resource_stop')
        for source, participant in pairs(contract.players) do
            if GetPlayerName(source) then
                if participant.inside then
                    local house = housesById[contract.houseId].config
                    local ped = GetPlayerPed(source)
                    if ped > 0 then SetEntityCoords(ped, house.coords.x, house.coords.y, house.coords.z, false, false, false, false) end
                end
                exports.qbx_core:SetPlayerBucket(source, 0)
            end
        end
    end
    for _, contract in pairs(archivedRobberies) do
        cleanupRobberyEntities(contract, false, 'resource_stop')
    end
end)

-- Server-side carry snapshots avoid depending on the player ped still existing
-- after playerDropped. One update per second is sufficient for a dropped prop.
CreateThread(function()
    while true do
        Wait(1000)
        for source, carry in pairs(activeCarry) do
            if GetPlayerName(source) then
                local contract = robberiesById[carry.robberyId] or archivedRobberies[carry.robberyId]
                local pickup = contract and contract.loot[carry.lootId]
                local ped = GetPlayerPed(source)
                if pickup and pickup.state == 'carried' and ped > 0 then
                    local coords = GetEntityCoords(ped)
                    pickup.lastCoords = vec3(coords.x, coords.y, coords.z)
                    pickup.lastHeading = GetEntityHeading(ped)
                    pickup.lastBucket = GetPlayerRoutingBucket(source)
                    pickup.location = pickup.lastBucket == contract.routingBucket and 'inside' or 'outside'
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        local timestamp = now()
        local expired = {}
        for _, contract in pairs(robberiesById) do
            if timestamp - contract.createdAt >= config.contractTimeout then
                expired[#expired + 1] = contract
            end
        end
        for _, contract in ipairs(expired) do finalizeRobbery(contract, 'O contato desistiu do endereço.', false) end
        for source, started in pairs(startedLoot) do
            if timestamp - started.startedAt >= 30 then
                local contract = getContract(source)
                local loot = contract and houseState[contract.houseId].loot[started.lootId]
                if loot and loot.busyBy == source then
                    loot.status, loot.busyBy = 'available', nil
                    syncContract(contract)
                end
                startedLoot[source] = nil
            end
        end
        for source, started in pairs(startedPickup) do
            if timestamp - started.startedAt >= 30 then
                local contract = robberiesById[started.robberyId]
                local pickup = getPickup(contract, started.robberyId, started.lootId)
                if pickup and pickup.state == 'claiming' and pickup.carrier == source then
                    if transitionLoot(pickup, started.previousState) then pickup.carrier = nil end
                    updateLootRepresentation(contract, pickup)
                    syncContract(contract)
                end
                startedPickup[source] = nil
            end
        end
        for source, carry in pairs(activeCarry) do
            if timestamp - carry.createdAt >= config.carryTokenLifetime then
                local contract = robberiesById[carry.robberyId] or archivedRobberies[carry.robberyId]
                if contract then dropCarriedLoot(source, contract, 'carry_timeout', true) else activeCarry[source] = nil end
            end
        end
        for _, contract in pairs(robberiesById) do
            if contract.resident and (not contract.resident.entity or not DoesEntityExist(contract.resident.entity))
                and contract.status == 'active' then spawnResidentEntity(contract) end
            for _, pickup in pairs(contract.loot) do
                ensureLootEntity(contract, pickup)
            end
        end
        for _, contract in pairs(archivedRobberies) do
            for _, pickup in pairs(contract.loot) do
                if pickup.location == 'outside' then ensureLootEntity(contract, pickup) end
            end
        end
    end
end)

RegisterCommand('noirhr', function(source, args)
    if not shared.debug or (source ~= 0 and not IsPlayerAceAllowed(source, shared.debugAce)) then return end
    local action = args[1]
    if action == 'assign' then requestContract(source)
    elseif action == 'clear' then
        for _, state in pairs(houseState) do state.status, state.cooldownUntil, state.contractId = 'available', 0, nil end
        notify(source, 'Cooldowns de casas limpos.', 'success')
    elseif action == 'state' then
        local contract = getContract(source)
        print(json.encode({ contract = contract, carry = activeCarry[source] }, { indent = true }))
    end
end, false)
