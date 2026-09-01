local config = require 'config.client'
local shared = require 'config.shared'

local contract
local inside = false
local interiorTargets = {}
local pickupProps = {}
local residentPed
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
local carriedModel
local carryTextUiShown = false
local exteriorTargets = {}
local refreshExteriorTarget

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

local function deleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        if NetworkGetEntityIsNetworked(entity) and not NetworkHasControlOfEntity(entity) then
            NetworkRequestControlOfEntity(entity)
            local timeout = GetGameTimer() + 1000
            while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
                NetworkRequestControlOfEntity(entity)
                Wait(0)
            end
        end
        DetachEntity(entity, true, true)
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
end

local function allowNetworkMigration(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId ~= 0 then SetNetworkIdCanMigrate(netId, true) end
end

local function createCarryObject(hash)
    local pedCoords = GetEntityCoords(cache.ped)
    local object = CreateObject(hash, pedCoords.x, pedCoords.y, pedCoords.z, true, true, false)
    allowNetworkMigration(object)
    SetEntityCollision(object, false, false)
    AttachEntityToEntity(object, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0.0, -0.03, -0.18, 5.0, 0.0, 0.0, false, false, false, false, 2, true)
    return object
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
    deleteEntity(residentPed)
    residentPed = nil
end

local function cleanupInterior(keepCarry)
    for _, zoneId in ipairs(interiorTargets) do exports.ox_target:removeZone(zoneId, true) end
    interiorTargets = {}
    for id, prop in pairs(pickupProps) do
        if not keepCarry or id ~= carriedPickupId then deleteEntity(prop) end
    end
    pickupProps = {}
    cleanupResident()
    stopNoise()
end

local function clearCarry()
    local wasCarrying = carryProp ~= nil or carriedPickupId ~= nil
    local prop = carryProp
    carryProp, carriedPickupId, carriedModel = nil, nil, nil
    StopAnimTask(cache.ped, config.carryAnimation.dict, config.carryAnimation.clip, 2.0)
    ClearPedSecondaryTask(cache.ped)
    SetPedCanSwitchWeapon(cache.ped, true)
    if wasCarrying then SetPedMaxMoveBlendRatio(cache.ped, 3.0) end
    deleteEntity(prop)
    if carryTextUiShown then
        lib.hideTextUI()
        carryTextUiShown = false
    end
end

local function cleanEverything()
    inside = false
    cleanupInterior(false)
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
    cleanupResident()
    residentAwake = false
    if not contract?.resident then return end
    local data = contract.resident
    local hash = loadModel(data.model)
    if not hash then return end
    residentPed = CreatePed(4, hash, data.coords.x, data.coords.y, data.coords.z, data.coords.w, false, false)
    SetEntityAsMissionEntity(residentPed, true, true)
    SetBlockingOfNonTemporaryEvents(residentPed, true)
    SetPedHearingRange(residentPed, 3.0)
    SetPedSeeingRange(residentPed, 0.0)
    SetPedAlertness(residentPed, 0)
    SetEntityInvincible(residentPed, false)
    if loadAnim('amb@lo_res_idles@') then
        TaskPlayAnimAdvanced(residentPed, 'amb@lo_res_idles@', 'lying_face_up_lo_res_base', data.coords.x, data.coords.y, data.coords.z, 0.0, 0.0, data.coords.w, 8.0, 1.0, -1, 1, 1.0, true, true)
        SetFacialIdleAnimOverride(residentPed, 'mood_sleeping_1', 0)
    end
    SetModelAsNoLongerNeeded(hash)
end

local function dropFingerprint()
    if qbx.isWearingGloves() then return end
    if math.random(100) <= config.fingerprintChance then
        TriggerServerEvent('evidence:server:CreateFingerDrop', GetEntityCoords(cache.ped))
    end
end

local function startCarry(data)
    clearCarry()
    local hash = loadModel(data.model)
    if not hash then
        TriggerServerEvent('noir_houserobbery:server:dropCarry')
        return
    end
    carryProp = createCarryObject(hash)
    carriedPickupId = data.pickupId
    carriedModel = data.model
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
    SetModelAsNoLongerNeeded(hash)
    addNoise(shared.noise.actions.pickupLarge)
end

RegisterNetEvent('noir_houserobbery:client:carryApproved', startCarry)
RegisterNetEvent('noir_houserobbery:client:carryCancelled', clearCarry)
RegisterNetEvent('noir_houserobbery:client:carryStored', clearCarry)

local function pickupIsHere(pickup)
    return (inside and pickup.location ~= 'outside') or (not inside and pickup.location == 'outside')
end

local function spawnPickupProps()
    for _, prop in pairs(pickupProps) do deleteEntity(prop) end
    pickupProps = {}
    for id, pickup in ipairs(contract.pickups or {}) do
        if pickupIsHere(pickup) and (pickup.status == 'available' or pickup.status == 'busy') then
            local hash = loadModel(pickup.model)
            if hash then
                local object = CreateObject(hash, pickup.coords.x, pickup.coords.y, pickup.coords.z, true, true, false)
                allowNetworkMigration(object)
                SetEntityHeading(object, pickup.rotation or 0.0)
                if pickup.dropped then PlaceObjectOnGroundProperly(object) end
                FreezeEntityPosition(object, true)
                pickupProps[id] = object
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
end

local function searchLoot(lootId)
    local current = contract?.loot?[lootId]
    if not inside or not current or current.status ~= 'available' or carryProp then return end
    dropFingerprint()
    if not lib.callback.await('noir_houserobbery:server:checkLoot', false, lootId) then return end
    addNoise(shared.noise.actions[current.noise] or shared.noise.actions.searchDrawer)
    local finished = lib.progressCircle({
        duration = math.random(4000, 7000), position = 'bottom', canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'missexile3', clip = 'ex03_dingy_search_case_base_michael', flag = 1 },
    })
    TriggerServerEvent(finished and 'noir_houserobbery:server:finishLoot' or 'noir_houserobbery:server:cancelLoot', lootId)
    if finished then addNoise(shared.noise.actions.takeSmall) end
end

local function takePickup(pickupId)
    local current = contract?.pickups?[pickupId]
    if carryProp or not current or not pickupIsHere(current) or current.status ~= 'available' then return end
    dropFingerprint()
    if not lib.callback.await('noir_houserobbery:server:beginCarry', false, pickupId) then return end
    local finished = lib.progressCircle({
        duration = math.random(3000, 5000), position = 'bottom', canCancel = true,
        disable = { move = true, combat = true },
        anim = { dict = 'missexile3', clip = 'ex03_dingy_search_case_base_michael', flag = 1 },
    })
    TriggerServerEvent(finished and 'noir_houserobbery:server:finishCarry' or 'noir_houserobbery:server:cancelPickup', pickupId)
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
                    return inside and not carryProp and current and current.status == 'available'
                end,
                onSelect = function() searchLoot(lootId) end,
            }},
        })
    end

    for id, pickup in ipairs(contract.pickups or {}) do
        local pickupId = id
        if pickup.location ~= 'outside' then
            interiorTargets[#interiorTargets + 1] = exports.ox_target:addSphereZone({
                coords = pickup.coords,
                radius = 0.9,
                debug = shared.debug,
                options = {{
                    name = ('noir_houserobbery_pickup_%s_%d'):format(contract.id, pickupId),
                    icon = 'fa-solid fa-box',
                    label = 'Carregar objeto',
                    distance = 1.7,
                    canInteract = function()
                        local current = contract?.pickups?[pickupId]
                        return inside and not carryProp and current and current.status == 'available'
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
    spawnPickupProps()
    spawnResident()
    noiseUiValue = 0
    finishTransition()
end

RegisterNetEvent('noir_houserobbery:client:enteredHouse', enterClient)

RegisterNetEvent('noir_houserobbery:client:leftHouse', function(data)
    contract = data
    inside = false
    cleanupInterior(true)
    if refreshExteriorTarget then refreshExteriorTarget() end
    spawnPickupProps()
    if carryProp and carriedModel then
        local hash = loadModel(carriedModel)
        if hash then
            deleteEntity(carryProp)
            carryProp = createCarryObject(hash)
            SetModelAsNoLongerNeeded(hash)
        end
    end
    if carryProp and loadAnim(config.carryAnimation.dict) then
        TaskPlayAnim(cache.ped, config.carryAnimation.dict, config.carryAnimation.clip, 2.0, 2.0, -1, 49, 0.0, false, false, false)
    end
    finishTransition()
end)

RegisterNetEvent('noir_houserobbery:client:syncContract', function(data)
    if not contract or contract.id ~= data.id then return end
    contract = data
    if refreshExteriorTarget then refreshExteriorTarget() end
    if inside then
        setupInteriorTargets()
    end
    spawnPickupProps()
end)

RegisterNetEvent('noir_houserobbery:client:contractAssigned', function(data)
    if contract then return end
    contract = data
    if refreshExteriorTarget then refreshExteriorTarget() end
    setContractBlip(data.coords)
    SetNewWaypoint(data.coords.x, data.coords.y)
    notify('O contato enviou um endereço ao GPS.', 'success')
end)

RegisterNetEvent('noir_houserobbery:client:contractEnded', function(reason, completed)
    cleanEverything()
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
                    return contract and not inside and contract.houseId == houseId and contract.state == 'assigned'
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
                    return contract and not inside and contract.houseId == houseId and contract.state == 'escaped'
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
                    return contract and not inside and not carryProp and contract.houseId == houseId and contract.state == 'escaped'
                end,
                onSelect = function()
                    TriggerServerEvent('noir_houserobbery:server:completeContract')
                end,
            },
        },
    })

    for id, pickup in ipairs(contract.pickups or {}) do
        if pickup.location == 'outside' then
            local pickupId = id
            exteriorTargets[#exteriorTargets + 1] = exports.ox_target:addSphereZone({
                coords = pickup.coords,
                radius = 0.9,
                debug = shared.debug,
                options = {{
                    name = ('noir_houserobbery_dropped_%s_%d'):format(contract.id, pickupId),
                    icon = 'fa-solid fa-box',
                    label = 'Carregar objeto',
                    distance = 1.7,
                    canInteract = function()
                        local current = contract?.pickups?[pickupId]
                        return not inside and not carryProp and current
                            and current.location == 'outside' and current.status == 'available'
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
            if inside or not carryProp or not DoesEntityExist(vehicle) or IsEntityDead(vehicle) then return false end
            local vehicleClass = GetVehicleClass(vehicle)
            if vehicleClass == 13 or (vehicleClass >= 14 and vehicleClass <= 16) then return false end
            if not NetworkGetEntityIsNetworked(vehicle) then return false end
            local _, rearDistance = getVehicleRear(vehicle)
            return rearDistance <= config.trunkDistance
        end,
        onSelect = function(data)
            TriggerServerEvent(
                'noir_houserobbery:server:storeCarryInVehicle',
                NetworkGetNetworkIdFromEntity(data.entity),
                NetworkGetNetworkIdFromEntity(carryProp)
            )
        end,
    })

    exports.ox_target:addGlobalOption({
        name = 'noir_houserobbery_drop_carry',
        icon = 'fa-solid fa-box-open',
        label = 'Soltar objeto roubado',
        canInteract = function() return carryProp ~= nil end,
        onSelect = function()
            if inside then addNoise(shared.noise.actions.dropLarge) end
            TriggerServerEvent('noir_houserobbery:server:dropCarry', NetworkGetNetworkIdFromEntity(carryProp))
        end,
    })
end

CreateThread(function()
    while true do
        if carryProp then
            Wait(0)
            -- The carry can be cleared by a server event while this thread is yielding.
            -- Recheck it before restoring the looping animation.
            if carryProp then
                if IsControlJustPressed(0, 47) then -- G
                    if inside then addNoise(shared.noise.actions.dropLarge) end
                    TriggerServerEvent('noir_houserobbery:server:dropCarry', NetworkGetNetworkIdFromEntity(carryProp))
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

CreateThread(function()
    while true do
        Wait(500)
        if contract and LocalPlayer.state.isDead then
            TriggerServerEvent('noir_houserobbery:server:abortContract', 'Contrato encerrado: você ficou incapacitado.')
            Wait(5000)
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
            if active.state == 'inside' then
                enterClient(active)
            else
                setContractBlip(active.coords)
                refreshExteriorTarget()
                spawnPickupProps()
            end
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local active = lib.callback.await('noir_houserobbery:server:getContract', false)
    if active and not contract then
        contract = active
        if active.state == 'inside' then
            enterClient(active)
        else
            setContractBlip(active.coords)
            refreshExteriorTarget()
            spawnPickupProps()
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', cleanEverything)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    exports.ox_target:removeGlobalVehicle('noir_houserobbery_store_carry')
    exports.ox_target:removeGlobalOption('noir_houserobbery_drop_carry')
    cleanEverything()
end)
