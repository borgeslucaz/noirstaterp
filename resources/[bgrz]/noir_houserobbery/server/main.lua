local config = require 'config.server'
local shared = require 'config.shared'

local housesById = {}
local houseState = {}
local activeContracts = {}
local contractsBySource = {}
local playerCooldowns = {}
local activeCarry = {}
local startedLoot = {}
local startedPickup = {}
local sequence = 0

for index, house in ipairs(shared.houses) do
    housesById[house.id] = { index = index, config = house }
    houseState[house.id] = { status = 'available', cooldownUntil = 0, contractId = nil, loot = {}, pickups = {} }
end

local function now()
    return os.time()
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
    local citizenId = contractsBySource[source] or getCitizenId(source)
    return citizenId and activeContracts[citizenId], citizenId
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
    state.pickups = selectRuntimeEntries(interior.pickups, tier.pickups.min, tier.pickups.max)
    for _, pickup in ipairs(state.pickups) do pickup.location = 'inside' end
    contract.resident = nil

    if #interior.residents > 0 and math.random() <= (house.residentChance or tier.residentChance) then
        local definition = interior.residents[math.random(#interior.residents)]
        contract.resident = {
            coords = definition.coords,
            model = definition.models[math.random(#definition.models)],
            reaction = chooseReaction(),
            state = 'sleeping',
            calledPolice = false,
        }
    end
end

local function clientContract(contract)
    local house = housesById[contract.houseId].config
    local state = houseState[contract.houseId]
    return {
        id = contract.id,
        houseId = contract.houseId,
        tier = contract.tier,
        state = contract.state,
        coords = house.coords,
        interior = house.interior,
        routingBucket = contract.routingBucket,
        loot = state.loot,
        pickups = state.pickups,
        resident = contract.resident,
    }
end

local function syncContract(contract)
    if contract and GetPlayerName(contract.ownerSource) then
        TriggerClientEvent('noir_houserobbery:client:syncContract', contract.ownerSource, clientContract(contract))
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

local function finalizeContract(source, reason, completed)
    local contract, citizenId = getContract(source)
    if not contract then return false end

    if activeCarry[citizenId] then activeCarry[citizenId] = nil end
    startedLoot[source] = nil
    startedPickup[source] = nil
    playerCooldowns[citizenId] = now() + config.cooldowns.player
    cooldownHouse(contract.houseId)
    activeContracts[citizenId] = nil
    contractsBySource[source] = nil

    if GetPlayerName(source) then
        if contract.state == 'inside' then
            local house = housesById[contract.houseId].config
            local ped = GetPlayerPed(source)
            if ped > 0 then SetEntityCoords(ped, house.coords.x, house.coords.y, house.coords.z, false, false, false, false) end
        end
        exports.qbx_core:SetPlayerBucket(source, 0)
        TriggerClientEvent('noir_houserobbery:client:contractEnded', source, reason or 'Contrato encerrado.', completed == true)
    end
    return true
end

local function allLootResolved(state)
    for _, loot in ipairs(state.loot) do
        if loot.status ~= 'opened' then return false end
    end
    for _, pickup in ipairs(state.pickups) do
        if pickup.status ~= 'stored' then return false end
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
    local index = housesById[house.id].index
    local contract = {
        id = makeId(source), houseId = house.id, tier = house.tier, state = 'assigned',
        createdAt = now(), enteredAt = nil, ownerSource = source, citizenId = citizenId,
        routingBucket = shared.baseRoutingBucket + index,
    }
    activeContracts[citizenId] = contract
    contractsBySource[source] = citizenId
    houseState[house.id].status = 'reserved'
    houseState[house.id].contractId = contract.id
    setupHouse(contract)
    TriggerClientEvent('noir_houserobbery:client:contractAssigned', source, clientContract(contract))
    NoirBurnerIntegration.sendLocation(source, { coords = house.coords, id = contract.id })
end

exports('RequestHouseContract', requestContract)

lib.callback.register('noir_houserobbery:server:getContract', function(source)
    local contract = getContract(source)
    return contract and clientContract(contract) or nil
end)

local function startSkillcheck(source, houseId)
    local contract = getContract(source)
    local houseData = housesById[houseId]
    if not contract or not houseData or contract.houseId ~= houseId or contract.state ~= 'assigned' then return false end
    local state = houseState[houseId]
    if state.contractId ~= contract.id or state.status ~= 'reserved' then return false end
    if distanceTo(source, houseData.config.coords) > config.maxExteriorDistance then return false end

    local police = exports.qbx_core:GetDutyCountType('leo')
    if police < config.minimumPolice then
        notify(source, ('São necessários %d policiais em serviço.'):format(config.minimumPolice), 'error')
        return false
    end
    contract.state = 'breaching'
    return shared.interiors[houseData.config.interior].skillcheck
end

local function enterHouse(source, contract)
    local house = housesById[contract.houseId].config
    local interior = shared.interiors[house.interior]
    local ped = GetPlayerPed(source)
    SetEntityCoords(ped, interior.entry.x, interior.entry.y, interior.entry.z, false, false, false, false)
    SetEntityHeading(ped, interior.entry.w)
    exports.qbx_core:SetPlayerBucket(source, contract.routingBucket)
    contract.state = 'inside'
    contract.enteredAt = contract.enteredAt or now()
    houseState[contract.houseId].status = 'active'
    TriggerClientEvent('noir_houserobbery:client:enteredHouse', source, clientContract(contract))
end

local function processSkillcheckResult(src, houseId, success)
    local contract = getContract(src)
    if not contract or contract.houseId ~= houseId or contract.state ~= 'breaching' then return end
    if distanceTo(src, housesById[houseId].config.coords) > config.maxExteriorDistance then return end
    if success ~= true then
        contract.state = 'assigned'
        notify(src, 'A gazua escapou. Isso fez barulho.', 'error')
        TriggerClientEvent('noir_houserobbery:client:addNoise', src, shared.noise.actions.failedSkillcheck)
        return
    end
    notify(src, 'A fechadura cedeu.', 'success')
    enterHouse(src, contract)
end

local function attemptBreach(playerSource, isAdvanced)
    local contract = getContract(playerSource)
    if not contract or contract.state ~= 'assigned' then return end
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
    if not contract or contract.houseId ~= houseId or contract.state ~= 'escaped' then return end
    if distanceTo(src, housesById[houseId].config.coords) > config.maxExteriorDistance then return end
    enterHouse(src, contract)
end)

RegisterNetEvent('noir_houserobbery:server:leaveHouse', function()
    local src = source
    local contract = getContract(src)
    if not contract or contract.state ~= 'inside' then return end
    local house = housesById[contract.houseId].config
    local exit = shared.interiors[house.interior].exit.xyz
    if distanceTo(src, exit) > config.maxInteriorDistance then return end
    local ped = GetPlayerPed(src)
    exports.qbx_core:SetPlayerBucket(src, 0)
    SetEntityCoords(ped, house.coords.x, house.coords.y, house.coords.z, false, false, false, false)
    contract.state = 'escaped'
    TriggerClientEvent('noir_houserobbery:client:leftHouse', src, clientContract(contract))
end)

local function validInside(source, contract, coords)
    return contract and contract.state == 'inside'
        and GetPlayerRoutingBucket(source) == contract.routingBucket
        and distanceTo(source, coords) <= config.maxInteriorDistance
end

local function validPickupLocation(source, contract, pickup)
    if not contract or not pickup then return false end
    if pickup.location == 'outside' then
        return contract.state == 'escaped'
            and GetPlayerRoutingBucket(source) == 0
            and distanceTo(source, pickup.coords) <= config.maxExteriorDistance
    end
    return validInside(source, contract, pickup.coords)
end

lib.callback.register('noir_houserobbery:server:checkLoot', function(source, lootId)
    local contract = getContract(source)
    local loot = contract and houseState[contract.houseId].loot[tonumber(lootId)]
    if not loot or not validInside(source, contract, loot.coords) or loot.status ~= 'available' then return false end
    loot.status, loot.busyBy = 'busy', source
    startedLoot[source] = { contractId = contract.id, lootId = tonumber(lootId), startedAt = now() }
    syncContract(contract)
    return true
end)

RegisterNetEvent('noir_houserobbery:server:finishLoot', function(lootId)
    local src = source
    local contract = getContract(src)
    local started = startedLoot[src]
    local loot = contract and houseState[contract.houseId].loot[tonumber(lootId)]
    if not started or started.contractId ~= contract?.id or started.lootId ~= tonumber(lootId) then return end
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

lib.callback.register('noir_houserobbery:server:beginCarry', function(source, pickupId)
    local contract, citizenId = getContract(source)
    if activeCarry[citizenId] then return false end
    local pickup = contract and houseState[contract.houseId].pickups[tonumber(pickupId)]
    if not pickup or not validPickupLocation(source, contract, pickup) or pickup.status ~= 'available' then return false end
    pickup.status, pickup.busyBy = 'busy', source
    startedPickup[source] = { contractId = contract.id, pickupId = tonumber(pickupId), startedAt = now() }
    syncContract(contract)
    return true
end)

RegisterNetEvent('noir_houserobbery:server:finishCarry', function(pickupId)
    local src = source
    local contract, citizenId = getContract(src)
    local started = startedPickup[src]
    local pickup = contract and houseState[contract.houseId].pickups[tonumber(pickupId)]
    if not started or started.contractId ~= contract?.id or started.pickupId ~= tonumber(pickupId) then return end
    if not pickup or pickup.status ~= 'busy' or pickup.busyBy ~= src or not validPickupLocation(src, contract, pickup) then return end
    pickup.status, pickup.busyBy = 'carried', nil
    activeCarry[citizenId] = {
        contractId = contract.id, houseId = contract.houseId, pickupId = tonumber(pickupId),
        reward = pickup.reward, model = pickup.model, createdAt = now(),
    }
    startedPickup[src] = nil
    syncContract(contract)
    TriggerClientEvent('noir_houserobbery:client:carryApproved', src, { pickupId = tonumber(pickupId), model = pickup.model })
end)

RegisterNetEvent('noir_houserobbery:server:cancelPickup', function(pickupId)
    local src = source
    local contract = getContract(src)
    local pickup = contract and houseState[contract.houseId].pickups[tonumber(pickupId)]
    if pickup and pickup.status == 'busy' and pickup.busyBy == src then
        pickup.status, pickup.busyBy = 'available', nil
        startedPickup[src] = nil
        syncContract(contract)
    end
end)

local function deleteCarriedObject(source, carry, netId)
    netId = tonumber(netId)
    local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 3 then return end
    local expectedModel = type(carry.model) == 'number' and carry.model or joaat(carry.model)
    if GetEntityModel(entity) ~= expectedModel or distanceTo(source, GetEntityCoords(entity)) > 3.0 then return end
    DeleteEntity(entity)
end

RegisterNetEvent('noir_houserobbery:server:dropCarry', function(carryNetId)
    local src = source
    local contract, citizenId = getContract(src)
    local carry = citizenId and activeCarry[citizenId]
    if not contract or not carry or carry.contractId ~= contract.id then return end
    local pickup = houseState[contract.houseId].pickups[carry.pickupId]
    local ped = GetPlayerPed(src)
    if not pickup or pickup.status ~= 'carried' or ped <= 0 then return end
    local expectedBucket = contract.state == 'inside' and contract.routingBucket or 0
    if (contract.state ~= 'inside' and contract.state ~= 'escaped') or GetPlayerRoutingBucket(src) ~= expectedBucket then return end

    local coords = GetEntityCoords(ped)
    pickup.coords = vec3(coords.x, coords.y, coords.z)
    pickup.rotation = GetEntityHeading(ped)
    pickup.location = contract.state == 'inside' and 'inside' or 'outside'
    pickup.dropped = true
    pickup.status, pickup.busyBy = 'available', nil
    deleteCarriedObject(src, carry, carryNetId)
    activeCarry[citizenId] = nil
    syncContract(contract)
    TriggerClientEvent('noir_houserobbery:client:carryCancelled', src)
end)

RegisterNetEvent('noir_houserobbery:server:storeCarryInVehicle', function(netId, carryNetId)
    local src = source
    local contract, citizenId = getContract(src)
    local carry = citizenId and activeCarry[citizenId]
    if not contract or contract.state ~= 'escaped' or not carry or carry.contractId ~= contract.id then return end
    if now() - carry.createdAt > config.carryTokenLifetime then return end
    if GetPlayerRoutingBucket(src) ~= 0 then return end

    netId = tonumber(netId)
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId) or 0
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
        return exports.ox_inventory:GetInventory({ id = 'trunk' .. plate, type = 'trunk', netid = netId })
    end)
    if not inventoryOk or not inventory then
        notify(src, 'Esse veículo não possui um porta-malas utilizável.', 'error')
        return
    end
    local pickup = houseState[contract.houseId].pickups[carry.pickupId]
    if not pickup or pickup.status ~= 'carried' then return end
    if not exports.ox_inventory:CanCarryItem(inventory.id, carry.reward, 1) then
        notify(src, 'O porta-malas está cheio.', 'error')
        return
    end
    local success = exports.ox_inventory:AddItem(inventory.id, carry.reward, 1, { stolen = true, contract = contract.id })
    if not success then
        notify(src, 'Não foi possível guardar o objeto.', 'error')
        return
    end

    pickup.status = 'stored'
    deleteCarriedObject(src, carry, carryNetId)
    activeCarry[citizenId] = nil
    syncContract(contract)
    TriggerClientEvent('noir_houserobbery:client:carryStored', src)
    notify(src, 'Objeto guardado no porta-malas.', 'success')
    if allLootResolved(houseState[contract.houseId]) then finalizeContract(src, 'O endereço foi limpo. Serviço encerrado.', true) end
end)

RegisterNetEvent('noir_houserobbery:server:residentCalledPolice', function(contractId)
    local src = source
    local contract = getContract(src)
    if not contract or contract.id ~= contractId or contract.state ~= 'inside' or not contract.resident then return end
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
    local contract, citizenId = getContract(src)
    if not contract or contract.state ~= 'escaped' or activeCarry[citizenId] then return end
    local house = housesById[contract.houseId].config
    if distanceTo(src, house.coords) > 8.0 then return end
    finalizeContract(src, 'Você encerrou o serviço e saiu do endereço.', true)
end)

AddEventHandler('playerDropped', function()
    finalizeContract(source, 'disconnect', false)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    finalizeContract(source, 'unload', false)
end)

AddStateBagChangeHandler('isDead', nil, function(bagName, _, value)
    if not value then return end
    local playerSource = GetPlayerFromStateBagName(bagName)
    if playerSource and contractsBySource[playerSource] then
        finalizeContract(playerSource, 'Contrato encerrado: você ficou incapacitado.', false)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for source in pairs(contractsBySource) do
        if GetPlayerName(source) then
            local contract = getContract(source)
            if contract and contract.state == 'inside' then
                local house = housesById[contract.houseId].config
                local ped = GetPlayerPed(source)
                if ped > 0 then SetEntityCoords(ped, house.coords.x, house.coords.y, house.coords.z, false, false, false, false) end
            end
            exports.qbx_core:SetPlayerBucket(source, 0)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        local timestamp = now()
        local expired = {}
        for citizenId, contract in pairs(activeContracts) do
            if timestamp - contract.createdAt >= config.contractTimeout then expired[#expired + 1] = contract.ownerSource end
        end
        for _, source in ipairs(expired) do finalizeContract(source, 'O contato desistiu do endereço.', false) end
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
                local contract = getContract(source)
                local pickup = contract and houseState[contract.houseId].pickups[started.pickupId]
                if pickup and pickup.busyBy == source then
                    pickup.status, pickup.busyBy = 'available', nil
                    syncContract(contract)
                end
                startedPickup[source] = nil
            end
        end
        for citizenId, carry in pairs(activeCarry) do
            if timestamp - carry.createdAt >= config.carryTokenLifetime then
                local contract = activeContracts[citizenId]
                local pickup = contract and houseState[contract.houseId].pickups[carry.pickupId]
                if pickup and pickup.status == 'carried' then pickup.status = 'available' end
                activeCarry[citizenId] = nil
                if contract then
                    syncContract(contract)
                    TriggerClientEvent('noir_houserobbery:client:carryCancelled', contract.ownerSource)
                end
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
        local contract, citizenId = getContract(source)
        print(json.encode({ contract = contract, carry = citizenId and activeCarry[citizenId] }, { indent = true }))
    end
end, false)
