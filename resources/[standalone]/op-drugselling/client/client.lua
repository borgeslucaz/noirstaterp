isDrugDealing = false
dealingPed = nil
isPedAtPoint = false
cam = nil
pedCamCoords = nil
isInCam = nil
isUiLanguageLoaded = false
pedType = "normal"
stolenTarget = nil

local playerLVL = nil

local isOnCooldown = false
local movementDisabled = false
local soldPedsList = {}
local dealSessionId = 0
local dealMenuOpen = false
local cornerTargetData = nil

local function clearCornerTarget()
    if not cornerTargetData then return end
    removeTargetEntity(cornerTargetData)
    cornerTargetData = nil
end

local function scheduleNextCustomer(delaySeconds)
    if not isDrugDealing then return end
    local delay = tonumber(delaySeconds) or Config.CornerDealing.SellTimeout
    Citizen.CreateThread(function()
        Wait(delay * 1000)
        if isDrugDealing then getNextDealing() end
    end)
end

function cancelActiveDrugDeal(reasonKey)
    dealSessionId = dealSessionId + 1
    dealMenuOpen = false
    if isDrugDealing and dealingPed then
        soldPedsList[dealingPed] = true
    end
    clearCornerTarget()
    endCam()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setDrugSellingVisible", data = false })
    stopDealFunc()

    if reasonKey then
        sendNotify(TranslateIt(reasonKey), "error", 5)
    end

    scheduleNextCustomer()
end

local function watchActiveDrugDeal(entity)
    dealSessionId = dealSessionId + 1
    local sessionId = dealSessionId
    local startedAt = GetGameTimer()
    local maxDistance = tonumber(Config.DealLimits and Config.DealLimits.MaxDistance) or 3.0
    local maxDuration = (tonumber(Config.DealLimits and Config.DealLimits.MaxDurationSeconds) or 30) * 1000

    Citizen.CreateThread(function()
        while sessionId == dealSessionId do
            if not DoesEntityExist(entity) or IsEntityDead(entity) then
                cancelActiveDrugDeal('deal_cancelled_invalid_ped')
                return
            end

            local playerCoords = GetEntityCoords(PlayerPedId())
            local customerCoords = GetEntityCoords(entity)
            if #(playerCoords - customerCoords) > maxDistance then
                cancelActiveDrugDeal('deal_cancelled_distance')
                return
            end

            if GetGameTimer() - startedAt >= maxDuration then
                cancelActiveDrugDeal('deal_cancelled_timeout')
                return
            end

            Wait(250)
        end
    end)
end

local function watchWaitingCustomer(entity)
    Citizen.CreateThread(function()
        while isDrugDealing and dealingPed == entity and DoesEntityExist(entity) do
            if isPedAtPoint then break end
            Wait(250)
        end

        if not isDrugDealing or dealingPed ~= entity then return end
        if not DoesEntityExist(entity) or IsEntityDead(entity) then
            clearCornerTarget()
            dealingPed = nil
            isPedAtPoint = false
            sendNotify(TranslateIt('deal_cancelled_invalid_ped'), "error", 5)
            scheduleNextCustomer()
            return
        end

        local maxDuration = (tonumber(Config.DealLimits and Config.DealLimits.MaxDurationSeconds) or 30) * 1000
        local expiresAt = GetGameTimer() + maxDuration

        while isDrugDealing and dealingPed == entity and not dealMenuOpen do
            if not DoesEntityExist(entity) or IsEntityDead(entity) then
                clearCornerTarget()
                dealingPed = nil
                isPedAtPoint = false
                sendNotify(TranslateIt('deal_cancelled_invalid_ped'), "error", 5)
                scheduleNextCustomer()
                return
            end
            if GetGameTimer() >= expiresAt then
                clearCornerTarget()
                soldPedsList[entity] = true
                stopDealFunc()
                releaseCornerCustomer(entity)
                if dealingPed == entity then dealingPed = nil end
                isPedAtPoint = false
                sendNotify(TranslateIt('deal_cancelled_timeout'), "error", 5)
                scheduleNextCustomer()
                return
            end
            Wait(250)
        end
    end)
end
local maleNames = {
    "Michael", "James", "John", "Robert", "David",
    "William", "Joseph", "Thomas", "Charles", "Daniel",
    "Matthew", "Anthony", "Mark", "Paul", "Steven"
}
local femaleNames = {
    "Mary", "Patricia", "Jennifer", "Linda", "Elizabeth",
    "Barbara", "Susan", "Jessica", "Sarah", "Karen",
    "Nancy", "Lisa", "Margaret", "Sandra", "Ashley"
}

Citizen.CreateThread(function()
    while not isUiLanguageLoaded do
        Wait(0)
        local loc = string.lower(Config.Locale)
        SendNUIMessage({
            action = "setLanguage",
            data = {locale = Locales[loc]}
        })
        SendNUIMessage({
            action = "setCurrency",
            data = {
                currency = Config.CurrencySettings.currency,
                style = Config.CurrencySettings.style,
                format = Config.CurrencySettings.format,
            }
        })
    end
end)

while Framework == nil do Wait(5) end

local scriptName = GetCurrentResourceName()
if scriptName ~= "op-drugselling" then return print('[OTHERPLANET.DEV] Required resource name: op-drugselling (needed for proper functionality)') end

if Config.LevelCommand then
    TriggerEvent('chat:addSuggestion', ('/%s'):format(Config.LevelCommand), TranslateIt('level_command_helper'), {})
end

----
-- ADDING GLOBAL TARGETS:
----

addGlobalPeds("global_peds_drugselling", 1.7, TranslateIt('target_selldrug_icon'), TranslateIt('target_selldrug'), function(entity)
    dealingPed = entity
    sellDrugMenu(entity)
end, function(entity) 
    if dealMenuOpen then return false end
    if isDrugDealing then return false end
    local pedModel = GetEntityModel(entity)
    if Config.BlackListPeds[pedModel] then return end
    local inventoryItems = ScriptFunctions.GetInventoryDrugs()
    if #inventoryItems < 1 then return false end
    if soldPedsList[entity] then return false end
    return IsEntityAPed(entity) and not IsPedAPlayer(entity) and not IsPedInAnyVehicle(entity, false) and not IsPedDeadOrDying(entity, true) and not IsPedInCombat(entity, PlayerPedId())
end)

----
-- SELL DRUGS MENU:
----

function getLVL(cb)
    if not playerLVL then 
        Fr.TriggerServerCallback('op-drugselling:getlvl', function(reslvl)
            playerLVL = resExp
            cb(reslvl)
        end)
    else 
        cb(playerLVL) 
    end
end

function sellDrugMenu(entity)
    if dealMenuOpen then return end
    dealMenuOpen = true
    local playerPed = PlayerPedId()
    local pedModel = GetEntityModel(entity)
    pedType = "normal"

    if Config.PedsList[pedModel] then
        pedType = Config.PedsList[pedModel]
    end
    local pedCfg = Config.PedTypes[pedType]

    if math.random(100) <= pedCfg.refuseChance then
        dealMenuOpen = false
        soldPedsList[entity] = true
        if Config.dispatchScript ~= "none" and pedCfg.dispatchCall then
            sendDispatchAlert(TranslateIt('drugdeal_dispatch_title'), TranslateIt('drugdeal_dispatch_message'), Config.DrugSelling.blipData)
        end

        stopDealFunc()
        if isDrugDealing then
            Citizen.CreateThread(function()
                Wait(Config.CornerDealing.SellTimeout * 1000)
                getNextDealing()
            end)
        end

        return sendNotify(TranslateIt('notify_refuse_2'), "error", 5)
    end

    getLVL(function(lvl)
        local inventoryItems = ScriptFunctions.GetInventoryDrugs()
        
        if not pedCfg then return print('Config for Ped Type not found!', pedType) end

        local pedGenderObj = IsPedMale(entity) and maleNames or femaleNames
        local pedName = pedGenderObj[math.random(1, #pedGenderObj)]
        local nuiData = {
            pedType = pedCfg.label,
            pedBorder = pedCfg.colors.border,
            pedBg = pedCfg.colors.background,
            playerLevel = lvl,
            playerBoost = GetLevelBoost(lvl),
            playerDrugs = inventoryItems,
            pedName = pedName
        }

        local dict = "missfbi3_party_b"
        if not LoadAnimDict(dict) then
            return debugPrint("Unable to load anim dict:", dict)
        end

        ClearPedTasks(entity)
        SetBlockingOfNonTemporaryEvents(entity, true)
        hardStopPed(entity) 
        faceEachOtherHard(playerPed, entity)

        TaskStandStill(entity, -1)
        TaskPlayAnim(entity, dict, "talk_inside_loop_male1", 8.0, -8.0, -1, 49, 0.0, false, false, false)
        TaskPlayAnim(playerPed, dict, "talk_inside_loop_male1", 8.0, -8.0, -1, 49, 0.0, false, false, false)

        startcam(entity)
        SetNuiFocus(true, true)
        SendNUIMessage({ action = "setDrugDealingData", data = nuiData })
        SendNUIMessage({ action = "setDrugSellingVisible", data = true })
        watchActiveDrugDeal(entity)
    end)
end

----
-- Function Triggered by NUI:
----

function sellDrugForPedFinalize(drug_name, price)
    dealSessionId = dealSessionId + 1
    dealMenuOpen = false
    local isdead = Fr.isDead()
    if isdead then 
        isDrugDealing = false
        return stopDealFunc()
    end

    endCam()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setDrugSellingVisible",
        data = false
    })
    local drugCfg = Config.DrugSelling.availableDrugs[drug_name]
    if not drugCfg then return print('[op-drugselling] Missing drug config:', drug_name) end

    Fr.TriggerServerCallback('op-drugselling:sellDrug', function(sold)
        if not sold then 
            return print('An server-side error occured. Check txAdmin Console.')
        end

        local pedCfg = Config.PedTypes[pedType]
        local nextCustomerDelay = Config.CornerDealing.SellTimeout
        if math.random(100) <= Config.DrugSelling.dispatchCallChance then
            if Config.dispatchScript ~= "none" and pedCfg.dispatchCall then
                sendDispatchAlert(TranslateIt('drugdeal_dispatch_title'), TranslateIt('drugdeal_dispatch_message'), Config.DrugSelling.blipData)
            end
        end

        if sold.sold then
            local saleDelay = Config.DealLimits and Config.DealLimits.SuccessfulSaleNextCustomerDelay or {}
            local minDelay = math.max(10, tonumber(saleDelay.MinSeconds) or 10)
            local maxDelay = math.max(minDelay, tonumber(saleDelay.MaxSeconds) or 30)
            nextCustomerDelay = math.random(math.floor(minDelay), math.floor(maxDelay))
            soldPedsList[dealingPed] = true
            movementDisabled = true
            CreateThread(function()
                while movementDisabled do
                    DisableControlAction(0, 30, true) 
                    DisableControlAction(0, 31, true) 
                    DisableControlAction(0, 32, true) 
                    DisableControlAction(0, 33, true) 
                    DisableControlAction(0, 34, true)
                    DisableControlAction(0, 35, true) 
                    DisableControlAction(0, 21, true) 
                    DisableControlAction(0, 22, true) 
                    DisableControlAction(0, 36, true) 
                    Wait(0)
                end
            end)

            playerLVL = sold.newLevel
            FaceEachOtherAndPlayGive(dealingPed, drugCfg.handPropName)
            if not sold.isRivalry then 
                --sendNotify(TranslateIt('notify_success', sold.amount, sold.label, sold.price), "success", 5)
            else
                --sendNotify(TranslateIt('notify_success_2', sold.amount, sold.label, sold.price), "success", 5)
            end

            if sold.zoneOwner then 
                --sendNotify(TranslateIt('notify_zoneowner'), "info", 5)
            end
            
            movementDisabled = false

            local dumpPed = dealingPed
            Citizen.CreateThread(function()
                Wait(25 * 1000)
                releaseCornerCustomer(dumpPed)
            end)
        elseif sold.steal then
            nextCustomerDelay = math.max(
                10,
                tonumber(Config.DealLimits and Config.DealLimits.RobberyNextCustomerDelaySeconds) or 10
            )
            soldPedsList[dealingPed] = true
            ClearPedTasks(PlayerPedId())

            addTargetTypedEntity("ped_drug_stolen", 2.0, TranslateIt('target_getdrugs_icon'), TranslateIt('target_getdrugs'), function(deleteData)
                TriggerServerEvent('op-drugselling:getBackDrugs')
                removeTargetEntity(deleteData)
            end, dealingPed)

            MakePedRunAway()
            sendNotify(TranslateIt('notify_steal'), "error", 5)
        elseif sold.refused then
            soldPedsList[dealingPed] = true
            local dumpPed = dealingPed
            stopDealFunc()
            sendNotify(TranslateIt('notify_refuse'), "error", 5)
            Citizen.CreateThread(function()
                Wait(25 * 1000)
                releaseCornerCustomer(dumpPed)
            end)
        end

        scheduleNextCustomer(nextCustomerDelay)
    end, drug_name, price, pedType, isDrugDealing)
end

----
-- Corner Selling Command:
----

if Config.CornerDealing.Enable then
    debugPrint("Registering drug selling command:", Config.CornerDealing.Command)

    RegisterNetEvent('op-drugselling:startDealingCorner', function()
        if isOnCooldown then
            return sendNotify(TranslateIt('drugDealing_wait'), "error", 5)
        end

        if not isDrugDealing then
            isDrugDealing = true
            sendNotify(TranslateIt('drugdeal_started_notify'), "info", 5)
            getNextDealing()
        else
            isDrugDealing = false
            dealSessionId = dealSessionId + 1
            dealMenuOpen = false
            clearCornerTarget()
            
            stopDealFunc()
            releaseCornerCustomer(dealingPed)

            dealingPed = nil
            sendNotify(TranslateIt('ended_drugdealing'), "info", 5)
            isOnCooldown = true
            
            local timeouttime = Config.CornerDealing.SellTimeout * 1000
            SetTimeout(timeouttime + 2000, function()
                isOnCooldown = false
            end)
        end
    end)

    TriggerEvent('chat:addSuggestion', ('/%s'):format(Config.CornerDealing.Command), TranslateIt('drugsell_command_help'), {})

    RegisterCommand(Config.CornerDealing.Command, function()
        TriggerEvent('op-drugselling:startDealingCorner')
    end)

    function getNextDealing()
        if not isDrugDealing then return end
        clearCornerTarget()
        isPedAtPoint = false
        dealingPed = findNearbyCornerCustomer()
        if not dealingPed then
            sendNotify(TranslateIt('no_customer_nearby'), "info", 5)
            scheduleNextCustomer()
            return
        end

        local customer = dealingPed
        TaskFollowToOffsetOfEntity(customer, PlayerPedId(), 0.0, 0.0, 0.0, 1.0, -1, 1.45, true)
        watchCornerCustomerApproach(customer, 1.45)
        cornerTargetData = addTargetTypedEntity(
            'corner_ped_drugselling',
            2.0,
            TranslateIt('target_selldrug_icon'),
            TranslateIt('target_selldrug'),
            function(targetData)
                if customer ~= dealingPed or dealMenuOpen then return end
                removeTargetEntity(targetData)
                cornerTargetData = nil
                sellDrugMenu(customer)
            end,
            customer
        )
        watchWaitingCustomer(customer)
        sendNotify(TranslateIt('ped_heading_notify'), "success", 5)
    end
end

----
-- Run with Drugs Function:
----

function MakePedRunAway()
    local playerPed = PlayerPedId()
    local ped = dealingPed
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    SetEntityAsMissionEntity(ped, true, false)       
    ClearPedTasksImmediately(ped)
    ClearPedSecondaryTask(ped)
    TaskSetBlockingOfNonTemporaryEvents(ped, false) 
    SetBlockingOfNonTemporaryEvents(ped, false)

    SetPedCombatAttributes(ped, 46, false)           
    SetPedFleeAttributes(ped, 0, false)             
    SetPedSeeingRange(ped, 80.0)
    SetPedHearingRange(ped, 80.0)
    SetPedAlertness(ped, 3)

    SetPedKeepTask(ped, true)
    SetPedMaxMoveBlendRatio(ped, 3.0)                
    SetPedDesiredMoveBlendRatio(ped, 3.0)

    local ply = GetPlayerPed(-1)
    local plyCoords = GetEntityCoords(playerPed)
    TaskReactAndFleePed(ped, playerPed)
    SetTimeout(500, function()
        if DoesEntityExist(ped) then
            TaskSmartFleePed(ped, playerPed, 120.0, -1, true, false)
        end
    end)
end

----
-- Stop Dealing Function:
----

function stopDealFunc()
    if dealingPed then 
        FreezeEntityPosition(dealingPed, false)
        TaskClearLookAt(dealingPed)
        ClearPedTasksImmediately(dealingPed)
        SetBlockingOfNonTemporaryEvents(dealingPed, false)
        TaskWanderStandard(dealingPed, 10.0, 10)
    end
    ClearPedTasks(PlayerPedId())
end

----
-- Give Drugs Animation:
----

function FaceEachOtherAndPlayGive(targetPed, propName)
    if not DoesEntityExist(targetPed) then
        return debugPrint("FaceEachOtherAndPlayGive: targetPed does not exist")
    end

    local playerDuration = 2000
    local npcDuration = 2000
    local playerPed = PlayerPedId()
    local dict = "mp_common"

    if not LoadAnimDict(dict) then
        return debugPrint("Unable to load anim dict:", dict)
    end
    TaskPlayAnim(targetPed, dict, "givetake2_a", 8.0, -8.0, npcDuration, 49, 0.0, false, false, false)
    TaskPlayAnim(playerPed, dict, "givetake1_b", 8.0, -8.0, playerDuration, 49, 0.0, false, false, false)

    local ok, propHash = LoadModel(propName)
    if not ok then
        return debugPrint("Couldn't load prop:", propName)
    end

    local prop = CreateObject(propHash, 0.0, 0.0, 0.0, true, true, false)
    SetEntityCollision(prop, false, true)
    attachPropToRightHand(playerPed, prop)

    local half = math.floor(math.min(playerDuration, npcDuration) / 2)
    CreateThread(function()
        Wait(half)
        if DoesEntityExist(prop) and DoesEntityExist(targetPed) then
            attachPropToRightHand(targetPed, prop)
        end
    end)
    SetModelAsNoLongerNeeded(propHash)
    
    Wait(2300)
    DeleteEntity(prop)
    PlayPedAmbientSpeechNative(targetPed, "GENERIC_THANKS", "SPEECH_PARAMS_FORCE")
    TaskClearLookAt(targetPed)
    ClearPedTasks(targetPed)
    SetBlockingOfNonTemporaryEvents(targetPed, false)
    TaskWanderStandard(targetPed, 10.0, 10)
end

----
-- Corner customers use pedestrians already streamed into the world.
----

function releaseCornerCustomer(ped)
    if not ped or not DoesEntityExist(ped) then return end

    ensureControl(ped, 10, 30)
    FreezeEntityPosition(ped, false)
    TaskClearLookAt(ped)
    ClearPedTasks(ped)
    SetPedKeepTask(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    TaskWanderStandard(ped, 10.0, 10)
    SetEntityAsNoLongerNeeded(ped)
end

local function isEligibleCornerCustomer(ped, playerPed, playerCoords, minDistance, maxDistance)
    if ped == playerPed or not DoesEntityExist(ped) or not IsPedHuman(ped) then return false end
    if IsPedAPlayer(ped) or IsPedInAnyVehicle(ped, false) or IsPedDeadOrDying(ped, true) then return false end
    if IsPedInCombat(ped, playerPed) or IsPedFleeing(ped) or IsPedRagdoll(ped) then return false end
    if IsEntityAMissionEntity(ped) or Config.BlackListPeds[GetEntityModel(ped)] or soldPedsList[ped] then return false end

    local distance = #(playerCoords - GetEntityCoords(ped))
    return distance >= minDistance and distance <= maxDistance
end

function findNearbyCornerCustomer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local minDistance = tonumber(Config.CornerDealing.CustomerMinDistance) or 4.0
    local maxDistance = tonumber(Config.CornerDealing.CustomerSearchRadius) or 30.0
    local candidates = {}

    for _, ped in ipairs(GetGamePool('CPed')) do
        if isEligibleCornerCustomer(ped, playerPed, playerCoords, minDistance, maxDistance) then
            candidates[#candidates + 1] = {
                ped = ped,
                distance = #(playerCoords - GetEntityCoords(ped)),
            }
        end
    end

    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    for _, candidate in ipairs(candidates) do
        if ensureControl(candidate.ped, 10, 30) then
            return candidate.ped
        end
    end
end

function watchCornerCustomerApproach(ped, stopRange)
    CreateThread(function()
        local lastReissue = 0
        while isDrugDealing and dealingPed == ped and DoesEntityExist(ped) do
            local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped))
            if distance <= stopRange + 0.5 then
                isPedAtPoint = true
                ClearPedTasks(ped)
                TaskStandStill(ped, -1)
                TaskTurnPedToFaceEntity(ped, PlayerPedId(), 800)
                TaskLookAtEntity(ped, PlayerPedId(), -1, 2048, 3)
                return
            end

            if GetGameTimer() - lastReissue > 2000 then
                TaskFollowToOffsetOfEntity(ped, PlayerPedId(), 0.0, 0.0, 0.0, 1.0, -1, stopRange, true)
                lastReissue = GetGameTimer()
            end
            Wait(300)
        end
    end)
end
