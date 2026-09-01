local config = require 'config.client'
local shared = require 'config.shared'

local contract
local inside = false
local interiorTargets = {}
local residentPed
local residentNetId
local residentAwake = false
local targetBlip
local currentNoise = 0.0
local lastNoiseUi = -1
local noiseUiValue
local lastMovementAt = 0
local lastWakeCheck = 0
local wasJumping = false
local carryProp
local carriedPickupId
local carriedNetId
local carryTextUiShown = false
local exteriorTargets = {}
local refreshExteriorTarget
local resolveNetworkEntity

local function finishTransition()
    DoScreenFadeIn(500)
end

local function notify(message, kind)
    lib.notify({ description = message, type = kind or 'inform' })
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function loadAnim(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    return HasAnimDictLoaded(dict)
end

local function removeBlip()
    if targetBlip then RemoveBlip(targetBlip) targetBlip = nil end
end

local function setContractBlip(coords)
    removeBlip()
    targetBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(targetBlip, 40)
    SetBlipColour(targetBlip, 1)
    SetBlipScale(targetBlip, 0.85)
    SetBlipRoute(targetBlip, true)
    SetBlipRouteColour(targetBlip, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Endereço do contato')
    EndTextCommandSetBlipName(targetBlip)
end

local function addNoise(amount)
    if not inside then return end
    currentNoise = math.min(100.0, currentNoise + (tonumber(amount) or 0))
    lastMovementAt = GetGameTimer()
end

RegisterNetEvent('noir_houserobbery:client:addNoise', addNoise)

local function stopNoise()
    currentNoise, lastNoiseUi = 0.0, -1
    noiseUiValue = nil
end

local function cleanupResident()
    residentPed, residentNetId = nil, nil
end

local function cleanupInterior()
    for _, zoneId in ipairs(interiorTargets) do exports.ox_target:removeZone(zoneId, true) end
    interiorTargets = {}
    cleanupResident()
    stopNoise()
end

local function clearCarry()
    local wasCarrying = carriedPickupId ~= nil
    carryProp, carriedPickupId, carriedNetId = nil, nil, nil
    StopAnimTask(cache.ped, config.carryAnimation.dict, config.carryAnimation.clip, 2.0)
    ClearPedSecondaryTask(cache.ped)
    SetPedCanSwitchWeapon(cache.ped, true)
    if wasCarrying then SetPedMaxMoveBlendRatio(cache.ped, 3.0) end
    if carryTextUiShown then
        lib.hideTextUI()
        carryTextUiShown = false
    end
end

local function cleanEverything()
    inside = false
    cleanupInterior()
    clearCarry()
    removeBlip()
    contract = nil
    if refreshExteriorTarget then refreshExteriorTarget() end
    finishTransition()
end

local function wakeResident()
    if residentAwake or not residentPed or not DoesEntityExist(residentPed) then return end
    residentAwake = true
    ClearPedTasks(residentPed)
    SetFacialIdleAnimOverride(residentPed, 'mood_stressed_1', 0)
    SetPedAlertness(residentPed, 3)
    SetPedSeeingRange(residentPed, 30.0)
    SetPedHearingRange(residentPed, 30.0)
    local reaction = contract.resident.reaction

    if reaction == 'armed' then
        GiveWeaponToPed(residentPed, joaat(shared.residents.weapon), 60, false, true)
        SetPedAccuracy(residentPed, 18)
        TaskCombatPed(residentPed, cache.ped, 0, 16)
    elseif reaction == 'confront' then
        TaskGoToEntity(residentPed, cache.ped, -1, 2.5, 1.0, 0.0, 0)
    elseif reaction == 'hide' then
        TaskCower(residentPed, -1)
    else
        TaskSmartFleePed(residentPed, cache.ped, 80.0, -1, false, false)
    end

    if reaction == 'flee' or reaction == 'hide' then
        local delay = math.random(shared.residents.dispatchDelay.min, shared.residents.dispatchDelay.max)
        SetTimeout(delay, function()
            if contract and residentAwake then
                TriggerServerEvent('noir_houserobbery:server:residentCalledPolice', contract.id)
            end
        end)
    end
    notify('O morador acordou!', 'error')
end

local function spawnResident()
    if not contract?.resident?.netId then return end
    local data = contract.resident
    local robberyId, netId = contract.id, data.netId
    if residentNetId == netId and residentPed and DoesEntityExist(residentPed) then return end
    cleanupResident()
    residentAwake = data.state ~= 'sleeping'
    residentNetId = netId
    CreateThread(function()
        local ped = resolveNetworkEntity(netId)
        if not ped or contract?.id ~= robberyId or contract.resident?.netId ~= netId then return end
        residentPed = ped
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedHearingRange(ped, 3.0)
        SetPedSeeingRange(ped, 0.0)
        SetPedAlertness(ped, 0)
        SetEntityInvincible(ped, false)
        if data.state == 'sleeping' and loadAnim('amb@lo_res_idles@') then
            TaskPlayAnimAdvanced(ped, 'amb@lo_res_idles@', 'lying_face_up_lo_res_base', data.coords.x, data.coords.y, data.coords.z, 0.0, 0.0, data.coords.w, 8.0, 1.0, -1, 1, 1.0, true, true)
            SetFacialIdleAnimOverride(ped, 'mood_sleeping_1', 0)
        end
    end)
end

local function dropFingerprint()
    if qbx.isWearingGloves() then return end
    if math.random(100) <= config.fingerprintChance then
        TriggerServerEvent('evidence:server:CreateFingerDrop', GetEntityCoords(cache.ped))
    end
end

resolveNetworkEntity = function(netId, timeoutMs)
    local timeout = GetGameTimer() + (timeoutMs or 5000)
    repeat
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity ~= 0 and DoesEntityExist(entity) then return entity end
        Wait(0)
    until GetGameTimer() >= timeout
end

-- Physics-affecting natives (freeze/collision/placement) only take real effect
-- on the machine that currently has network control of the entity. Without
-- this, unfreeze/collision changes can lag behind until ownership migrates
-- naturally, leaving the prop floating or drifting away from its logged coords.
local function requestNetworkControl(entity, timeoutMs)
    if entity == 0 or not DoesEntityExist(entity) then return false end
    if not NetworkGetEntityIsNetworked(entity) or NetworkHasControlOfEntity(entity) then return true end
    local timeout = GetGameTimer() + (timeoutMs or 500)
    repeat
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    until NetworkHasControlOfEntity(entity) or GetGameTimer() >= timeout
    return NetworkHasControlOfEntity(entity)
end

local function attachLootEntity(entity, carrierSource)
    local player = GetPlayerFromServerId(tonumber(carrierSource) or -1)
    if player == -1 then return false end
    local ped = GetPlayerPed(player)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    requestNetworkControl(entity)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, false)
    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, 28422), 0.0, -0.03, -0.18, 5.0, 0.0, 0.0, false, false, false, false, 2, true)
    return true
end

local function detachLootEntity(entity, state)
    requestNetworkControl(entity)
    DetachEntity(entity, true, true)
    SetEntityCollision(entity, true, true)
    SetEntityHeading(entity, state['loot:rotation'] or 0.0)
    if state['loot:dropped'] then
        PlaceObjectOnGroundProperly(entity)
        FreezeEntityPosition(entity, false)
    else
        FreezeEntityPosition(entity, true)
    end
end

local function applyLootRepresentation(bagName)
    CreateThread(function()
        local timeout = GetGameTimer() + 5000
        repeat
            local entity = GetEntityFromStateBagName(bagName)
            if entity ~= 0 and DoesEntityExist(entity) then
                local state = Entity(entity).state
                if state['loot:state'] == 'carried' then
                    if attachLootEntity(entity, state['loot:carrier']) then return end
                else
                    detachLootEntity(entity, state)
                    return
                end
            end
            Wait(50)
        until GetGameTimer() >= timeout
    end)
end

AddStateBagChangeHandler('loot:state', nil, function(bagName) applyLootRepresentation(bagName) end)
AddStateBagChangeHandler('loot:carrier', nil, function(bagName) applyLootRepresentation(bagName) end)

local function updateLocalCarryEntity(data)
    if not contract or contract.id ~= data.robberyId or carriedPickupId ~= data.lootId then return end
    if not data.netId then return end
    carriedNetId = data.netId
    CreateThread(function()
        local entity = resolveNetworkEntity(data.netId)
        if entity and carriedPickupId == data.lootId and carriedNetId == data.netId then
            carryProp = entity
            attachLootEntity(entity, GetPlayerServerId(PlayerId()))
        end
    end)
end

local function startCarry(data)
    clearCarry()
    if not contract or contract.id ~= data.robberyId then return end
    carriedPickupId = data.lootId
    SetCurrentPedWeapon(cache.ped, joaat('WEAPON_UNARMED'), true)
    SetPedCanSwitchWeapon(cache.ped, false)
    if loadAnim(config.carryAnimation.dict) then
        TaskPlayAnim(cache.ped, config.carryAnimation.dict, config.carryAnimation.clip, 2.0, 2.0, -1, 49, 0.0, false, false, false)
    end
    lib.showTextUI('Pressione G para soltar o item', {
        position = 'left-center',
        icon = 'hand',
    })
    carryTextUiShown = true
    updateLocalCarryEntity(data)
    addNoise(shared.noise.actions.pickupLarge)
end

RegisterNetEvent('noir_houserobbery:client:carryApproved', startCarry)
RegisterNetEvent('noir_houserobbery:client:carryEntity', updateLocalCarryEntity)
RegisterNetEvent('noir_houserobbery:client:carryCancelled', clearCarry)
RegisterNetEvent('noir_houserobbery:client:carryStored', clearCarry)

local function reconcileLocalCarry()
    if not contract then return end
    local serverId = GetPlayerServerId(PlayerId())
    for lootId, pickup in pairs(contract.pickups or {}) do
        if pickup.state == 'carried' and pickup.carrier == serverId then
            local data = { robberyId = contract.id, lootId = lootId, netId = pickup.netId }
            if carriedPickupId ~= lootId then startCarry(data) else updateLocalCarryEntity(data) end
            return
        end
    end
    if carriedPickupId then clearCarry() end
end

local function reconcileSharedCarryEntities()
    if not contract then return end
    local localBucket = inside and contract.routingBucket or 0
    for lootId, pickup in pairs(contract.pickups or {}) do
        if pickup.state == 'carried' and pickup.netId and pickup.carrier
            and pickup.currentBucket == localBucket then
            local robberyId, currentLootId, netId, carrier = contract.id, lootId, pickup.netId, pickup.carrier
            CreateThread(function()
                local entity = resolveNetworkEntity(netId)
                local current = contract?.id == robberyId and contract.pickups?[currentLootId]
                if entity and current and current.state == 'carried' and current.netId == netId then
                    attachLootEntity(entity, carrier)
                end
            end)
        end
    end
end

-- State bag handlers cover normal scope changes; this lightweight reconciliation
-- recovers attachments after ownership migration or an entity recreation.
CreateThread(function()
    while true do
        Wait(3000)
        if contract then
            reconcileSharedCarryEntities()
            reconcileLocalCarry()
        end
    end
end)

local function pickupIsHere(pickup)
    return (inside and pickup.location ~= 'outside') or (not inside and pickup.location == 'outside')
end

local function searchLoot(lootId)
    local current = contract?.loot?[lootId]
    if not inside or not current or current.status ~= 'available' or carriedPickupId then return end
    dropFingerprint()
    local claim = lib.callback.await('noir_houserobbery:server:checkLoot', false, lootId)
    if not claim then return end
    addNoise(shared.noise.actions[current.noise] or shared.noise.actions.searchDrawer)
    local finished = lib.progressCircle({
        duration = claim.duration, position = 'bottom', canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'missexile3', clip = 'ex03_dingy_search_case_base_michael', flag = 1 },
    })
    TriggerServerEvent(finished and 'noir_houserobbery:server:finishLoot' or 'noir_houserobbery:server:cancelLoot', lootId)
    if finished then addNoise(shared.noise.actions.takeSmall) end
end

local function takePickup(pickupId)
    local current = contract?.pickups?[pickupId]
    if carriedPickupId or not current or not pickupIsHere(current)
        or (current.state ~= 'available' and current.state ~= 'dropped') then return end
    dropFingerprint()
    local robberyId = contract.id
    local claim = lib.callback.await('noir_houserobbery:server:beginCarry', false, robberyId, pickupId)
    if not claim then return end
    local finished = lib.progressCircle({
        duration = claim.duration, position = 'bottom', canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'missexile3', clip = 'ex03_dingy_search_case_base_michael', flag = 1 },
    })
    TriggerServerEvent(finished and 'noir_houserobbery:server:finishCarry' or 'noir_houserobbery:server:cancelPickup', robberyId, pickupId)
end

local function setupInteriorTargets()
    for _, zoneId in ipairs(interiorTargets) do exports.ox_target:removeZone(zoneId, true) end
    interiorTargets = {}

    for id, loot in ipairs(contract.loot or {}) do
        local lootId = id
        interiorTargets[#interiorTargets + 1] = exports.ox_target:addSphereZone({
            coords = loot.coords,
            radius = 0.8,
            debug = shared.debug,
            options = {{
                name = ('noir_houserobbery_loot_%s_%d'):format(contract.id, lootId),
                icon = 'fa-solid fa-magnifying-glass',
                label = 'Vasculhar',
                distance = 1.5,
                canInteract = function()
                    local current = contract?.loot?[lootId]
                    return inside and not carriedPickupId and current and current.status == 'available'
                end,
                onSelect = function() searchLoot(lootId) end,
            }},
        })
    end

    for id, pickup in pairs(contract.pickups or {}) do
        local pickupId = id
        if pickup.location == 'inside' and pickup.state ~= 'stored'
            and pickup.state ~= 'sold' and pickup.state ~= 'removed' then
            interiorTargets[#interiorTargets + 1] = exports.ox_target:addSphereZone({
                coords = pickup.coords,
                radius = 0.9,
                debug = shared.debug,
                options = {{
                    name = ('noir_houserobbery_pickup_%s_%s'):format(contract.id, pickupId),
                    icon = 'fa-solid fa-box',
                    label = 'Carregar objeto',
                    distance = 1.7,
                    canInteract = function()
                        local current = contract?.pickups?[pickupId]
                        return inside and not carriedPickupId and current
                            and (current.state == 'available' or current.state == 'dropped')
                    end,
                    onSelect = function() takePickup(pickupId) end,
                }},
            })
        end
    end

    local interior = shared.interiors[contract.interior]
    interiorTargets[#interiorTargets + 1] = exports.ox_target:addSphereZone({
        coords = interior.exit.xyz,
        radius = 1.0,
        debug = shared.debug,
        options = {{
            name = 'noir_houserobbery_exit_' .. contract.id,
            icon = 'fa-solid fa-door-open',
            label = 'Sair da casa',
            distance = 1.8,
            canInteract = function() return inside end,
            onSelect = function() TriggerServerEvent('noir_houserobbery:server:leaveHouse') end,
        }},
    })
end

local function enterClient(data)
    contract = data
    inside = true
    if refreshExteriorTarget then refreshExteriorTarget() end
    removeBlip()
    currentNoise, lastMovementAt, lastWakeCheck = 0.0, GetGameTimer(), GetGameTimer()
    setupInteriorTargets()
    spawnResident()
    reconcileSharedCarryEntities()
    reconcileLocalCarry()
    noiseUiValue = 0
    finishTransition()
end

RegisterNetEvent('noir_houserobbery:client:enteredHouse', enterClient)

RegisterNetEvent('noir_houserobbery:client:leftHouse', function(data)
    contract = data
    inside = false
    cleanupInterior()
    if refreshExteriorTarget then refreshExteriorTarget() end
    reconcileSharedCarryEntities()
    reconcileLocalCarry()
    if carriedPickupId and loadAnim(config.carryAnimation.dict) then
        TaskPlayAnim(cache.ped, config.carryAnimation.dict, config.carryAnimation.clip, 2.0, 2.0, -1, 49, 0.0, false, false, false)
    end
    finishTransition()
end)

RegisterNetEvent('noir_houserobbery:client:syncContract', function(data)
    if not contract or contract.id ~= data.id then return end
    contract = data
    inside = data.inside == true
    if refreshExteriorTarget then refreshExteriorTarget() end
    if inside then
        setupInteriorTargets()
        spawnResident()
    end
    reconcileSharedCarryEntities()
    reconcileLocalCarry()
end)

RegisterNetEvent('noir_houserobbery:client:contractAssigned', function(data)
    if contract then return end
    contract = data
    if refreshExteriorTarget then refreshExteriorTarget() end
    setContractBlip(data.coords)
    SetNewWaypoint(data.coords.x, data.coords.y)
    notify('O contato enviou um endereço ao GPS.', 'success')
end)

RegisterNetEvent('noir_houserobbery:client:contractEnded', function(reason, completed, preserveCarry, closedContract)
    if preserveCarry and carriedPickupId and closedContract then
        inside = false
        cleanupInterior()
        removeBlip()
        contract = closedContract
        if refreshExteriorTarget then refreshExteriorTarget() end
        reconcileLocalCarry()
    else
        cleanEverything()
    end
    notify(reason or 'Contrato encerrado.', completed and 'success' or 'error')
end)

local breachMinigameActive = false
local LOCKPICK_EVENT_STEP = { easy = 3, medium = 5, hard = 7 }

local function getLockpickSettings(difficulty)
    if type(difficulty) ~= 'table' then
        return 1, LOCKPICK_EVENT_STEP[difficulty] or LOCKPICK_EVENT_STEP.medium
    end

    local eventStep = LOCKPICK_EVENT_STEP.easy
    for i = 1, #difficulty do
        local step = LOCKPICK_EVENT_STEP[difficulty[i]] or LOCKPICK_EVENT_STEP.medium
        if step > eventStep then eventStep = step end
    end

    return math.max(#difficulty, 1), eventStep
end

RegisterNetEvent('noir_houserobbery:client:startSkillcheck', function(difficulty)
    if inside or not contract then
        TriggerServerEvent('noir_houserobbery:server:skillcheckResult', false)
        return
    end
    if breachMinigameActive then return end

    breachMinigameActive = true
    local pickCount, eventStep = getLockpickSettings(difficulty)
    lib.playAnim(cache.ped, 'veh@break_in@0h@p_m_one@', 'std_force_entry_rds', 3.0, 3.0, -1, 17, 0, false, false, false)
    local success = exports.peuren_minigames:StartLockpick(pickCount, eventStep, 100)
    breachMinigameActive = false
    ClearPedTasks(cache.ped)
    TriggerServerEvent('noir_houserobbery:server:skillcheckResult', success == true)
end)

refreshExteriorTarget = function()
    for _, zoneId in ipairs(exteriorTargets) do exports.ox_target:removeZone(zoneId, true) end
    exteriorTargets = {}
    if not contract or inside then return end

    local house
    for _, candidate in ipairs(shared.houses) do
        if candidate.id == contract.houseId then
            house = candidate
            break
        end
    end
    if not house then return end

    local houseId = house.id
    exteriorTargets[1] = exports.ox_target:addBoxZone({
        coords = vec3(house.coords.x, house.coords.y, house.coords.z + 1.0),
        size = vec3(2.4, 2.4, 2.8),
        rotation = house.targetRotation or 0.0,
        debug = shared.debug,
        options = {
            {
                name = 'noir_houserobbery_breach_' .. houseId,
                icon = 'fa-solid fa-lock-open',
                label = 'Arrombar porta',
                distance = 2.5,
                canInteract = function()
                    return contract and not inside and contract.houseId == houseId and contract.status == 'assigned'
                end,
                onSelect = function()
                    TriggerServerEvent('noir_houserobbery:server:attemptEntry')
                end,
            },
            {
                name = 'noir_houserobbery_enter_' .. houseId,
                icon = 'fa-solid fa-house',
                label = 'Entrar na casa',
                distance = 2.5,
                canInteract = function()
                    return contract and not inside and contract.houseId == houseId and contract.status == 'active'
                end,
                onSelect = function()
                    TriggerServerEvent('noir_houserobbery:server:enterHouse', houseId)
                end,
            },
            {
                name = 'noir_houserobbery_finish_' .. houseId,
                icon = 'fa-solid fa-flag-checkered',
                label = 'Encerrar serviço',
                distance = 2.5,
                canInteract = function()
                    return contract and not inside and not carriedPickupId and contract.houseId == houseId and contract.status == 'active'
                end,
                onSelect = function()
                    TriggerServerEvent('noir_houserobbery:server:completeContract')
                end,
            },
        },
    })

    for id, pickup in pairs(contract.pickups or {}) do
        if pickup.location == 'outside' and pickup.state == 'dropped' then
            local pickupId = id
            exteriorTargets[#exteriorTargets + 1] = exports.ox_target:addSphereZone({
                coords = pickup.coords,
                radius = 0.9,
                debug = shared.debug,
                options = {{
                    name = ('noir_houserobbery_dropped_%s_%s'):format(contract.id, pickupId),
                    icon = 'fa-solid fa-box',
                    label = 'Carregar objeto',
                    distance = 1.7,
                    canInteract = function()
                        local current = contract?.pickups?[pickupId]
                        return not inside and not carriedPickupId and current
                            and current.location == 'outside' and current.state == 'dropped'
                    end,
                    onSelect = function() takePickup(pickupId) end,
                }},
            })
        end
    end
end

local function getVehicleRear(vehicle)
    local pedCoords = GetEntityCoords(cache.ped)
    local bone = GetEntityBoneIndexByName(vehicle, 'boot')
    local rear = bone ~= -1 and GetWorldPositionOfEntityBone(vehicle, bone) or GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.0)
    return rear, #(pedCoords - rear)
end

local function setupCarryTargets()
    exports.ox_target:addGlobalVehicle({
        name = 'noir_houserobbery_store_carry',
        icon = 'fa-solid fa-car-rear',
        label = 'Guardar objeto roubado',
        distance = config.vehicleSearchRadius,
        canInteract = function(vehicle)
            if inside or not carriedPickupId or not DoesEntityExist(vehicle) or IsEntityDead(vehicle) then return false end
            local vehicleClass = GetVehicleClass(vehicle)
            if vehicleClass == 13 or (vehicleClass >= 14 and vehicleClass <= 16) then return false end
            local _, rearDistance = getVehicleRear(vehicle)
            local vehicleDistance = #(GetEntityCoords(cache.ped) - GetEntityCoords(vehicle))
            return rearDistance <= math.max(config.trunkDistance, 3.0)
                or vehicleDistance <= config.vehicleSearchRadius
        end,
        onSelect = function(data)
            local vehicleNetId = NetworkGetNetworkIdFromEntity(data.entity)
            if vehicleNetId == 0 then
                notify('Aguarde o veículo sincronizar e tente novamente.', 'error')
                return
            end
            TriggerServerEvent('noir_houserobbery:server:storeCarryInVehicle',
                contract.id, carriedPickupId, vehicleNetId)
        end,
    })
end

CreateThread(function()
    while true do
        if carriedPickupId then
            Wait(0)
            -- The carry can be cleared by a server event while this thread is yielding.
            -- Recheck it before restoring the looping animation.
            if carriedPickupId then
                if IsControlJustPressed(0, 47) then -- G
                    if inside then addNoise(shared.noise.actions.dropLarge) end
                    TriggerServerEvent('noir_houserobbery:server:dropCarry', contract.id, carriedPickupId)
                end
                DisableControlAction(0, 21, true) -- Sprint
                DisableControlAction(0, 22, true) -- Jump
                DisableControlAction(0, 23, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 37, true)
                DisableControlAction(0, 44, true)
                DisablePlayerFiring(cache.playerId, true)
                SetCurrentPedWeapon(cache.ped, joaat('WEAPON_UNARMED'), true)
                SetPedMaxMoveBlendRatio(cache.ped, 1.0)
                if not IsEntityPlayingAnim(cache.ped, config.carryAnimation.dict, config.carryAnimation.clip, 3) then
                    TaskPlayAnim(cache.ped, config.carryAnimation.dict, config.carryAnimation.clip, 2.0, 2.0, -1, 49, 0.0, false, false, false)
                end
            end
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if not inside then
            Wait(500)
        else
            local tick = shared.noise.tick
            Wait(tick)
            local ped = cache.ped
            local moving = GetEntitySpeed(ped) > 0.08
            local rate = 0.0
            if IsPedSprinting(ped) then rate = shared.noise.movement.sprint
            elseif IsPedRunning(ped) then rate = shared.noise.movement.run
            elseif moving and GetPedStealthMovement(ped) then rate = shared.noise.movement.sneak
            elseif moving then rate = shared.noise.movement.walk end

            local jumping = IsPedJumping(ped)
            if jumping and not wasJumping then addNoise(shared.noise.actions.jump) end
            wasJumping = jumping
            local seconds = tick / 1000
            if moving then
                currentNoise = math.min(100.0, currentNoise + rate * seconds * 4.0)
                lastMovementAt = GetGameTimer()
            elseif GetGameTimer() - lastMovementAt >= shared.noise.quietGrace then
                currentNoise = math.max(0.0, currentNoise - shared.noise.decayPerSecond * seconds)
            end
            local nativeNoise = GetPlayerCurrentStealthNoise(cache.playerId) * shared.noise.nativeWeight
            currentNoise = math.max(currentNoise, nativeNoise)

            local rounded = math.floor(currentNoise + 0.5)
            if math.abs(rounded - lastNoiseUi) >= shared.noise.syncDelta then
                lastNoiseUi = rounded
                noiseUiValue = rounded
            end

            if contract?.resident and not residentAwake then
                local wake = shared.noise.wake
                local shouldWake = currentNoise >= wake.immediate
                if not shouldWake and currentNoise >= wake.risk and GetGameTimer() - lastWakeCheck >= wake.interval then
                    lastWakeCheck = GetGameTimer()
                    local chance = currentNoise >= wake.critical and wake.chances.critical or (currentNoise >= wake.danger and wake.chances.danger or wake.chances.risk)
                    shouldWake = math.random() <= chance
                end
                if shouldWake then wakeResident() end
            end
        end
    end
end)

local function drawNoiseMeter(value)
    local x, y = 0.925, 0.885
    local width, height = 0.115, 0.007
    local progress = math.max(0.0, math.min(1.0, value / 100.0))
    local red, green, blue = 216, 210, 193
    if value >= 90 then red, green, blue = 240, 40, 40
    elseif value >= 70 then red, green, blue = 198, 83, 63
    elseif value >= 50 then red, green, blue = 213, 146, 79
    elseif value >= 30 then red, green, blue = 208, 181, 106 end

    SetTextFont(4)
    SetTextScale(0.0, 0.30)
    SetTextColour(235, 232, 224, 235)
    SetTextRightJustify(true)
    SetTextWrap(0.0, x + width * 0.5)
    SetTextEntry('STRING')
    AddTextComponentString(('NOISE  %d'):format(value))
    DrawText(x - width * 0.5, y - 0.025)

    DrawRect(x, y, width, height, 12, 13, 14, 190)
    if progress > 0 then
        DrawRect(x - width * 0.5 + (width * progress) * 0.5, y, width * progress, height, red, green, blue, 235)
    end
end

CreateThread(function()
    while true do
        if inside and noiseUiValue ~= nil then
            Wait(0)
            drawNoiseMeter(noiseUiValue)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    finishTransition()
    SetTimeout(750, finishTransition)
    setupCarryTargets()
    CreateThread(function()
        Wait(1000)
        local active = lib.callback.await('noir_houserobbery:server:getContract', false)
        if active then
            contract = active
            inside = active.inside == true
            if active.inside then
                enterClient(active)
            else
                setContractBlip(active.coords)
                refreshExteriorTarget()
                reconcileSharedCarryEntities()
                reconcileLocalCarry()
            end
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local active = lib.callback.await('noir_houserobbery:server:getContract', false)
    if active and not contract then
        contract = active
        inside = active.inside == true
        if active.inside then
            enterClient(active)
        else
            setContractBlip(active.coords)
            refreshExteriorTarget()
            reconcileSharedCarryEntities()
            reconcileLocalCarry()
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', cleanEverything)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    exports.ox_target:removeGlobalVehicle('noir_houserobbery_store_carry')
    cleanEverything()
end)
