local isQbx  = GetResourceState('qbx_core') ~= 'missing'
local QBCore = exports['qb-core']:GetCoreObject()

local isOpen       = false
local previewVeh   = nil
local currentShop  = nil
local spawnedNpcs  = {}
local activeMenu   = nil

local previewCam   = nil
local isPreviewing = false
local camAngle     = 0.0
local camHeight    = 0.5
local camRadius    = 6.0
local savedCoords  = nil

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    return hash
end

local function deletePreview()
    if previewVeh and DoesEntityExist(previewVeh) then
        QBCore.Functions.DeleteVehicle(previewVeh)
    end
    previewVeh = nil
end

local function destroyPreviewCam()
    if previewCam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    isPreviewing = false
end

local function teleportToPreview()
    local ped = PlayerPedId()
    -- noir: um segundo preview sem sair do primeiro gravava o ponto subterraneo como volta.
    savedCoords = savedCoords or GetEntityCoords(ped)

    TriggerServerEvent('citgo_dealership:enterBucket')

    local pp = Config.PreviewPoint
    SetEntityCoords(ped, pp.x, pp.y, pp.z - 5.0, false, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
end

local function teleportBack()
    local ped = PlayerPedId()
    if savedCoords then
        SetEntityCoords(ped, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false, false)
    end
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, true)
    SetEntityCollision(ped, true, true)
    savedCoords = nil

    TriggerServerEvent('citgo_dealership:exitBucket')
end

local function spawnPreviewVehicle(model)
    deletePreview()
    local pp   = Config.PreviewPoint
    local hash = loadModel(model)
    if not HasModelLoaded(hash) then return end

    previewVeh = CreateVehicle(hash, pp.x, pp.y, pp.z, pp.w, false, false)
    SetEntityAsMissionEntity(previewVeh, true, true)
    SetVehicleOnGroundProperly(previewVeh)
    FreezeEntityPosition(previewVeh, true)
    SetEntityInvincible(previewVeh, true)
    SetVehicleDoorsLocked(previewVeh, 2)
    SetModelAsNoLongerNeeded(hash)
end

local function updateCamPosition()
    if not previewCam then return end
    local pp = Config.PreviewPoint
    local cx = pp.x + camRadius * math.cos(math.rad(camAngle))
    local cy = pp.y + camRadius * math.sin(math.rad(camAngle))
    local cz = pp.z + camHeight

    SetCamCoord(previewCam, cx, cy, cz)
    PointCamAtCoord(previewCam, pp.x, pp.y, pp.z + 0.5)
end

local function createPreviewCam()
    local pp = Config.PreviewPoint
    camAngle  = pp.w + 180.0
    camHeight = 0.5
    camRadius = 6.0

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCamPosition()
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 500, true, false)
    isPreviewing = true
end

local function applyPrimaryColor(color)
    if not previewVeh or not DoesEntityExist(previewVeh) then return end
    SetVehicleCustomPrimaryColour(previewVeh, color.r or 0, color.g or 0, color.b or 0)
end

local function applySecondaryColor(color)
    if not previewVeh or not DoesEntityExist(previewVeh) then return end
    SetVehicleCustomSecondaryColour(previewVeh, color.r or 0, color.g or 0, color.b or 0)
end

local function applyPlate(plate)
    if not previewVeh or not DoesEntityExist(previewVeh) then return end
    SetVehicleNumberPlateText(previewVeh, plate:upper():sub(1, 8))
end

-- noir: o original chamava exports['ZSX_UIV2'], que nao existe aqui e quebrava a abertura da loja.
local function hideHUD(hide)
    if GetResourceState('noir_hud') ~= 'started' then return end
    pcall(function() exports.noir_hud:setHudVisible(not hide) end)
end

-- noir: uz_AutoShot e opcional. Sem ele, usa o render oficial do veiculo no docs.fivem.net.
local function getVehiclePhoto(model)
    if GetResourceState('uz_AutoShot') == 'started' then
        local ok, url = pcall(function() return exports['uz_AutoShot']:getVehiclePhotoURL(model) end)
        if ok and url then return url end
    end
    return ('https://docs.fivem.net/vehicles/%s.webp'):format(model)
end

-- ── Open / Close ─────────────────────────────────────────────────────────────

local function openDealership(shopId)
    if isOpen then return end
    local shop = Config.Dealerships[shopId]
    if not shop then return end
    currentShop = shopId
    isOpen = true

    hideHUD(true)

    QBCore.Functions.TriggerCallback('citgo_dealership:getVehicles', function(vehicles)
        local categoriesSet = {}
        local categoriesList = {}
        for _, cat in ipairs(shop.categories) do
            categoriesSet[cat] = true
        end

        local filtered = {}
        for _, veh in ipairs(vehicles) do
            if categoriesSet[veh.category] then
                veh.photo = getVehiclePhoto(veh.model)
                filtered[#filtered + 1] = veh
                if not categoriesList[veh.category] then
                    categoriesList[veh.category] = true
                end
            end
        end

        local cats = {}
        for _, cat in ipairs(shop.categories) do
            if categoriesList[cat] then
                cats[#cats + 1] = cat
            end
        end

        SendNUIMessage({
            type                = 'open',
            vehicles            = filtered,
            categories          = cats,
            shopLabel           = shop.label,
            shopId              = shopId,
            secondaryColorPrice = Config.SecondaryColorPrice,
            financeEnabled      = Config.Finance.enabled,
        })
        SetNuiFocus(true, true)
    end, shop.shopKey, shop.categories)
end

local function closeDealership()
    if not isOpen then return end
    isOpen = false
    currentShop = nil

    if isPreviewing then
        destroyPreviewCam()
        deletePreview()
        teleportBack()
    end

    deletePreview()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
    hideHUD(false)
end

-- ── NUI Callbacks ────────────────────────────────────────────────────────────

RegisterNUICallback('previewVehicle', function(data, cb)
    if data.model then
        teleportToPreview()
        spawnPreviewVehicle(data.model)
        if data.color then applyPrimaryColor(data.color) end
        if data.secondaryColor then applySecondaryColor(data.secondaryColor) end
        if data.plate and #data.plate > 0 then applyPlate(data.plate) end
        createPreviewCam()
    else
        destroyPreviewCam()
        deletePreview()
        teleportBack()
    end
    cb('ok')
end)

RegisterNUICallback('exitPreview', function(_, cb)
    destroyPreviewCam()
    deletePreview()
    teleportBack()
    cb('ok')
end)

RegisterNUICallback('changePrimaryColor', function(data, cb)
    if data.color then applyPrimaryColor(data.color) end
    cb('ok')
end)

RegisterNUICallback('changeSecondaryColor', function(data, cb)
    if data.color then applySecondaryColor(data.color) end
    cb('ok')
end)

RegisterNUICallback('changePlate', function(data, cb)
    if data.plate then applyPlate(data.plate) end
    cb('ok')
end)

RegisterNUICallback('checkPlate', function(data, cb)
    if not data.plate or #data.plate < 1 then
        cb({ available = false })
        return
    end
    QBCore.Functions.TriggerCallback('citgo_dealership:checkPlate', function(available)
        cb({ available = available })
    end, data.plate)
end)

-- Camera orbit controlled from NUI
RegisterNUICallback('camRotate', function(data, cb)
    if not isPreviewing then cb('ok') return end
    camAngle = camAngle - (data.dx or 0)
    updateCamPosition()
    cb('ok')
end)

RegisterNUICallback('camZoom', function(data, cb)
    if not isPreviewing then cb('ok') return end
    local dir = data.direction or 0
    if dir > 0 then
        camRadius = math.max(3.0, camRadius - 0.5)
    elseif dir < 0 then
        camRadius = math.min(12.0, camRadius + 0.5)
    end
    updateCamPosition()
    cb('ok')
end)

RegisterNUICallback('camHeight', function(data, cb)
    if not isPreviewing then cb('ok') return end
    camHeight = math.max(-1.0, math.min(3.0, camHeight + (data.delta or 0)))
    updateCamPosition()
    cb('ok')
end)

RegisterNUICallback('purchaseVehicle', function(data, cb)
    QBCore.Functions.TriggerCallback('citgo_dealership:purchaseVehicle', function(result)
        if result.success then
            destroyPreviewCam()
            deletePreview()
            teleportBack()

            QBCore.Functions.Notify('Vehicle purchased! Plate: ' .. result.plate, 'success', 5000)

            local shop  = Config.Dealerships[currentShop]
            local spawn = shop.spawnPoint
            QBCore.Functions.SpawnVehicle(data.model, function(veh)
                local primaryColor   = data.color or { r = 0, g = 0, b = 0 }
                local secondaryColor = data.secondaryColor or primaryColor

                local props = {
                    plate  = result.plate,
                    color1 = { primaryColor.r, primaryColor.g, primaryColor.b },
                    color2 = { secondaryColor.r, secondaryColor.g, secondaryColor.b },
                }
                QBCore.Functions.SetVehicleProperties(veh, props)
                SetVehicleOnGroundProperly(veh)
                FreezeEntityPosition(veh, false)
                SetEntityInvincible(veh, false)
                TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
                SetVehicleEngineOn(veh, true, true)
            end, spawn, true, false)
        else
            QBCore.Functions.Notify(result.message or 'Purchase failed', 'error', 3000)
        end

        closeDealership()
        cb('ok')
    end, {
        model          = data.model,
        color          = data.color or { r = 0, g = 0, b = 0 },
        secondaryColor = data.secondaryColor,
        plate          = data.plate or nil,
    })
end)

RegisterNUICallback('getFinanceInfo', function(data, cb)
    QBCore.Functions.TriggerCallback('citgo_dealership:getFinanceInfo', function(result)
        cb(result)
    end, data)
end)

RegisterNUICallback('financeVehicle', function(data, cb)
    QBCore.Functions.TriggerCallback('citgo_dealership:financeVehicle', function(result)
        if result.success then
            destroyPreviewCam()
            deletePreview()
            teleportBack()

            QBCore.Functions.Notify(
                ('Vehicle financed! Plate: %s | $%s/day for %d days'):format(
                    result.plate,
                    tostring(math.floor(result.dailyPayment)),
                    Config.Finance.loanDuration
                ),
                'success', 8000
            )

            local shop  = Config.Dealerships[currentShop]
            local spawn = shop.spawnPoint
            QBCore.Functions.SpawnVehicle(data.model, function(veh)
                local primaryColor   = data.color or { r = 0, g = 0, b = 0 }
                local secondaryColor = data.secondaryColor or primaryColor
                local props = {
                    plate  = result.plate,
                    color1 = { primaryColor.r, primaryColor.g, primaryColor.b },
                    color2 = { secondaryColor.r, secondaryColor.g, secondaryColor.b },
                }
                QBCore.Functions.SetVehicleProperties(veh, props)
                SetVehicleOnGroundProperly(veh)
                FreezeEntityPosition(veh, false)
                SetEntityInvincible(veh, false)
                TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                TriggerEvent('vehiclekeys:client:SetOwner', result.plate)
                SetVehicleEngineOn(veh, true, true)
            end, spawn, true, false)
        else
            QBCore.Functions.Notify(result.message or 'Financing denied', 'error', 3000)
        end

        closeDealership()
        cb('ok')
    end, {
        model          = data.model,
        color          = data.color or { r = 0, g = 0, b = 0 },
        secondaryColor = data.secondaryColor,
        plate          = data.plate or nil,
    })
end)

RegisterNUICallback('closeUI', function(_, cb)
    closeDealership()
    cb('ok')
end)

-- ── Blips & NPCs ─────────────────────────────────────────────────────────────

CreateThread(function()
    for _, shop in pairs(Config.Dealerships) do
        if shop.blip and shop.blip.sprite then
            local loc  = shop.location
            local blip = AddBlipForCoord(loc.x, loc.y, loc.z)
            SetBlipSprite(blip, shop.blip.sprite)
            SetBlipColour(blip, shop.blip.color or 0)
            SetBlipScale(blip, shop.blip.scale or 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(shop.blip.label or shop.label)
            EndTextCommandSetBlipName(blip)
        end

        if shop.npc then
            local loc  = shop.location
            local hash = loadModel(shop.npc.model)
            if HasModelLoaded(hash) then
                local ped = CreatePed(0, hash, loc.x, loc.y, loc.z - 1.0, shop.npc.heading or loc.w, false, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                FreezeEntityPosition(ped, true)
                SetModelAsNoLongerNeeded(hash)
                spawnedNpcs[#spawnedNpcs + 1] = ped
            end
        end
    end
end)

-- ── core_focus context menus ─────────────────────────────────────────────────

local useOxInteraction = Config.UseOxTarget or Config.UseOxRadial
local SHOP_RADIUS = 5.0

local function getNearestDealership()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, bestDist = nil, SHOP_RADIUS
    for shopId, shop in pairs(Config.Dealerships) do
        local loc  = shop.location
        local dist = #(coords - vector3(loc.x, loc.y, loc.z))
        if dist < bestDist then
            bestDist = dist
            best     = shopId
        end
    end
    return best
end

if not useOxInteraction then
    CreateThread(function()
        while true do
            local nearest = getNearestDealership()

            if nearest ~= activeMenu then
                if activeMenu then
                    exports['core_focus']:RemoveContextMenu('citgo_dealer')
                    activeMenu = nil
                end

                if nearest and not isOpen then
                    local shop = Config.Dealerships[nearest]
                    exports['core_focus']:AddContextMenu('citgo_dealer', {
                        enabled = true,
                        label   = shop.label,
                        icon    = 'fas fa-car',
                        options = {
                            {
                                label  = 'Browse Vehicles',
                                icon   = 'fas fa-car',
                                action = function()
                                    openDealership(nearest)
                                end,
                            },
                        },
                    })
                    activeMenu = nearest
                end
            end

            Wait(nearest and 500 or 1500)
        end
    end)
end

-- ── Optional: ox_target zones ────────────────────────────────────────────────

if Config.UseOxTarget and GetResourceState('ox_target') == 'started' then
    for shopId, shop in pairs(Config.Dealerships) do
        local loc = shop.location
        exports.ox_target:addSphereZone({
            coords = vec3(loc.x, loc.y, loc.z),
            radius = SHOP_RADIUS,
            debug  = false,
            options = {
                {
                    name     = 'dealer_' .. shopId,
                    label    = 'Browse ' .. shop.label,
                    icon     = 'fas fa-car',
                    onSelect = function()
                        openDealership(shopId)
                    end,
                },
            },
        })
    end
end

-- ── Optional: ox_lib radial menu ─────────────────────────────────────────────

if Config.UseOxRadial and GetResourceState('ox_lib') == 'started' then
    CreateThread(function()
        while true do
            local nearest = getNearestDealership()
            if nearest and not isOpen then
                local shop = Config.Dealerships[nearest]
                lib.addRadialItem({
                    id    = 'citgo_dealer_radial',
                    label = shop.label,
                    icon  = 'car',
                    onSelect = function()
                        openDealership(nearest)
                    end,
                })
            else
                lib.removeRadialItem('citgo_dealer_radial')
            end
            Wait(nearest and 500 or 1500)
        end
    end)
end

-- noir: removido o comando /dealership de teste; abria a loja em qualquer lugar do mapa, sem permissao.

-- ── Cleanup ──────────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    destroyPreviewCam()
    deletePreview()
    if savedCoords then teleportBack() end
    hideHUD(false)
    for _, ped in ipairs(spawnedNpcs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
