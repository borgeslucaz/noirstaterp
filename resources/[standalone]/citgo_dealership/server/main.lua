local isQbx  = GetResourceState('qbx_core') ~= 'missing'
local QBCore = exports['qb-core']:GetCoreObject()

-- ── Sessoes (noir) ──────────────────────────────────────────────────────────
-- O original deixava qualquer cliente trocar de routing bucket e comprar de qualquer lugar.
-- Agora a sessao so abre com o jogador junto de uma concessionaria (no getVehicles), o
-- bucket so muda dentro de uma sessao aberta, e a compra exige sessao valida + estar na loja
-- ou no ponto de preview.

local SHOP_DISTANCE    = 10.0          -- a zona do ox_target tem 5 m
local PREVIEW_DISTANCE = 25.0          -- o cliente fica em PreviewPoint.z - 5
local SESSION_TTL      = 30 * 60       -- segundos
local BUCKET_OFFSET    = 20000         -- illenium-appearance ja usa bucket = source

local sessions = {}

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

local function nearShop(src, shop)
    local coords = playerCoords(src)
    if not coords then return false end
    local loc = shop.location
    return #(coords - vector3(loc.x, loc.y, loc.z)) <= SHOP_DISTANCE
end

local function findShopByKey(shopKey)
    for shopId, shop in pairs(Config.Dealerships) do
        if shop.shopKey == shopKey then return shopId, shop end
    end
end

local function activeSession(src)
    local session = sessions[src]
    if not session then return nil end
    if os.time() > session.expiresAt then
        sessions[src] = nil
        return nil
    end
    return session
end

local function nearPreview(src)
    local coords = playerCoords(src)
    local pp = Config.PreviewPoint
    return coords ~= nil and #(coords - vector3(pp.x, pp.y, pp.z)) <= PREVIEW_DISTANCE
end

local function canPurchase(src)
    local session = activeSession(src)
    if not session then return false end
    local shop = Config.Dealerships[session.shopId]
    if session.bucket then
        return GetPlayerRoutingBucket(src) == session.bucket and nearPreview(src)
    end
    return nearShop(src, shop)
end

local function leaveBucket(src, session)
    if not session or not session.bucket then return end
    if GetPlayerRoutingBucket(src) == session.bucket then
        SetPlayerRoutingBucket(src, session.previousBucket or 0)
    end
    session.bucket = nil
end

RegisterNetEvent('citgo_dealership:enterBucket', function()
    local src = source
    local session = activeSession(src)
    if not session or session.bucket then return end
    -- O cliente teleporta logo depois de disparar o evento; a posicao pode ja ser a do preview.
    if not nearShop(src, Config.Dealerships[session.shopId]) and not nearPreview(src) then return end
    session.previousBucket = GetPlayerRoutingBucket(src)
    session.bucket = BUCKET_OFFSET + src
    SetPlayerRoutingBucket(src, session.bucket)
end)

RegisterNetEvent('citgo_dealership:exitBucket', function()
    local src = source
    -- So devolve quem a loja colocou no bucket; nao serve para sair de outra instancia.
    leaveBucket(src, sessions[src])
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, session in pairs(sessions) do leaveBucket(src, session) end
end)

-- ── Helpers ─────────────────────────────────────────────────────────────────

local function generatePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate
    repeat
        plate = ''
        for _ = 1, 8 do
            local idx = math.random(1, #chars)
            plate = plate .. chars:sub(idx, idx)
        end
        local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
    until not result
    return plate
end

local function getAllVehicles()
    if isQbx then
        return exports.qbx_core:GetVehiclesByName()
    end
    return QBCore.Shared.Vehicles
end

-- noir: so vende o que alguma concessionaria configurada vende. O original aceitava qualquer
-- modelo do qbx_core vindo do cliente (viatura, aviao, trem...).
local sellableCategories = {}
for _, shop in pairs(Config.Dealerships) do
    for _, cat in ipairs(shop.categories or {}) do sellableCategories[cat] = true end
end

local function getVehicleData(model)
    if type(model) ~= 'string' then return nil end
    local vehicles = getAllVehicles()
    local veh
    if isQbx then
        veh = vehicles[model]
    else
        for _, v in pairs(vehicles) do
            if v.model == model then veh = v break end
        end
    end
    if not veh or not sellableCategories[veh.category] then return nil end
    return veh
end

-- noir: placa pedida pelo cliente so com letras, numeros e espaco (1 a 8).
local function cleanPlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:upper():gsub('[^A-Z0-9 ]', ''):sub(1, 8)
    plate = plate:match('^%s*(.-)%s*$')
    if plate == '' then return nil end
    return plate
end

-- noir: o mri_Qcarkeys so entrega a chave definitiva (item) pelo GivePermanentKey; o evento
-- vehiclekeys:client:SetOwner que o cliente dispara nao da chave para carro com dono.
local function givePermanentKey(src, plate)
    if GetResourceState('mri_Qcarkeys') ~= 'started' then return end
    local ok, given = pcall(function() return exports.mri_Qcarkeys:GivePermanentKey(src, plate) end)
    if not ok or given ~= true then
        exports.qbx_core:Notify(src, 'Não coube a chave do veículo no inventário. Peça uma cópia na garagem.', 'error')
    end
end

local function buildMods(plate, primaryColor, secondaryColor)
    local pc = primaryColor or { r = 0, g = 0, b = 0 }
    local sc = secondaryColor or pc
    return json.encode({
        plate  = plate,
        color1 = { pc.r or 0, pc.g or 0, pc.b or 0 },
        color2 = { sc.r or 0, sc.g or 0, sc.b or 0 },
        fuelLevel    = 100.0,
        engineHealth = 1000.0,
        bodyHealth   = 1000.0,
    })
end

local function insertVehicle(citizenid, model, plate, mods)
    local hash = tostring(joaat(model))
    if isQbx then
        MySQL.insert.await(
            'INSERT INTO player_vehicles (citizenid, vehicle, hash, mods, plate, fuel, engine, body, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { citizenid, model, hash, mods, plate, 100, 1000.0, 1000.0, 0 }
        )
    else
        MySQL.insert.await(
            'INSERT INTO player_vehicles (citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { citizenid, model, hash, mods, plate, Config.DefaultGarage, 100, 1000.0, 1000.0, 0 }
        )
    end
end

local function resolvePlate(requested)
    if requested then
        local taken = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { requested })
        if taken then return generatePlate() end
        return requested
    end
    return generatePlate()
end

-- ── Finance Helpers ─────────────────────────────────────────────────────────

local function getFinanceTier(score)
    for _, tier in ipairs(Config.Finance.tiers) do
        if score >= tier.minScore then return tier end
    end
    return nil
end

local function getFinanceDetails(citizenid, vehiclePrice)
    if not Config.Finance.enabled then
        return nil, 'Financing is not available'
    end

    local ok, score = pcall(exports['tgg-banking'].GetCreditScore, exports['tgg-banking'], citizenid)
    if not ok or not score then
        score = MySQL.scalar.await('SELECT score FROM tgg_banking_credit_scores WHERE playerId = ?', { citizenid })
    end
    if not score then
        return nil, 'Unable to retrieve credit score'
    end

    local tier = getFinanceTier(score)
    if not tier then
        return nil, 'No eligible financing tier'
    end

    if vehiclePrice > tier.maxPrice then
        return nil, ('Credit score too low for vehicles over $%s'):format(
            tostring(math.floor(tier.maxPrice))
        )
    end

    local totalInterest  = vehiclePrice * (tier.rate / 100)
    local totalOwed      = vehiclePrice + totalInterest
    local dailyPayment   = math.ceil(totalOwed / Config.Finance.loanDuration)

    return {
        score         = score,
        tier          = tier.label,
        rate          = tier.rate,
        totalOwed     = totalOwed,
        totalInterest = totalInterest,
        duration      = Config.Finance.loanDuration,
        dailyPayment  = dailyPayment,
        maxPrice      = tier.maxPrice,
    }
end

-- ── Callbacks ───────────────────────────────────────────────────────────────

QBCore.Functions.CreateCallback('citgo_dealership:getVehicles', function(source, cb, shopKey, shopCategories)
    local vehicles = {}

    -- noir: abre a sessao so junto da loja e usa as categorias do config, nao as do cliente.
    local shopId, shop = findShopByKey(shopKey)
    if not shop or not nearShop(source, shop) then
        cb(vehicles)
        return
    end
    local previous = sessions[source]
    if previous and previous.bucket then leaveBucket(source, previous) end
    sessions[source] = { shopId = shopId, expiresAt = os.time() + SESSION_TTL }
    shopCategories = shop.categories
    local allVehicles = getAllVehicles()

    if isQbx then
        -- QBox: no shop field on vehicles, filter by category list from config
        local catSet = {}
        if shopCategories then
            for _, cat in ipairs(shopCategories) do catSet[cat] = true end
        end
        for _, veh in pairs(allVehicles) do
            if catSet[veh.category] then
                vehicles[#vehicles + 1] = {
                    model    = veh.model,
                    name     = veh.name,
                    brand    = veh.brand,
                    price    = veh.price,
                    category = veh.category,
                    type     = veh.type,
                }
            end
        end
    else
        -- QBCore: filter by shop field
        for _, veh in pairs(allVehicles) do
            local shop = veh.shop
            if type(shop) == 'table' then
                for _, s in ipairs(shop) do
                    if s == shopKey then
                        vehicles[#vehicles + 1] = {
                            model    = veh.model,
                            name     = veh.name,
                            brand    = veh.brand,
                            price    = veh.price,
                            category = veh.category,
                            type     = veh.type,
                        }
                        break
                    end
                end
            elseif shop == shopKey then
                vehicles[#vehicles + 1] = {
                    model    = veh.model,
                    name     = veh.name,
                    brand    = veh.brand,
                    price    = veh.price,
                    category = veh.category,
                    type     = veh.type,
                }
            end
        end
    end

    cb(vehicles)
end)

QBCore.Functions.CreateCallback('citgo_dealership:checkPlate', function(source, cb, plate)
    plate = cleanPlate(plate)
    if not plate then
        cb(false)
        return
    end
    local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
    cb(not result)
end)

QBCore.Functions.CreateCallback('citgo_dealership:getFinanceInfo', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({ available = false, reason = 'Player not found' }) return end

    local vehicleData = getVehicleData(data.model)
    if not vehicleData then cb({ available = false, reason = 'Vehicle not found' }) return end

    local totalPrice = vehicleData.price + (data.surcharge or 0)
    local details, err = getFinanceDetails(Player.PlayerData.citizenid, totalPrice)

    if not details then
        cb({ available = false, reason = err })
        return
    end

    cb({
        available    = true,
        score        = details.score,
        tier         = details.tier,
        rate         = details.rate,
        totalOwed    = details.totalOwed,
        interest     = details.totalInterest,
        duration     = details.duration,
        dailyPayment = details.dailyPayment,
        maxPrice     = details.maxPrice,
    })
end)

QBCore.Functions.CreateCallback('citgo_dealership:purchaseVehicle', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb({ success = false, message = 'Player not found' }) return end
    if type(data) ~= 'table' or not canPurchase(src) then
        cb({ success = false, message = 'Você precisa estar na concessionária.' })
        return
    end

    local model = data.model
    local plate = cleanPlate(data.plate)
    local vehicleData = getVehicleData(model)

    if not vehicleData then
        cb({ success = false, message = 'Vehicle not found' })
        return
    end

    local hasSecondary = data.secondaryColor ~= nil
    local surcharge    = hasSecondary and Config.SecondaryColorPrice or 0
    local price        = vehicleData.price + surcharge
    local cash         = Player.PlayerData.money['cash']
    local bank         = Player.PlayerData.money['bank']

    if bank >= price then
        Player.Functions.RemoveMoney('bank', price, 'vehicle-purchase')
    elseif cash >= price then
        Player.Functions.RemoveMoney('cash', price, 'vehicle-purchase')
    else
        cb({ success = false, message = 'Not enough money' })
        return
    end

    plate = resolvePlate(plate)
    local mods = buildMods(plate, data.color, data.secondaryColor)
    insertVehicle(Player.PlayerData.citizenid, model, plate, mods)
    givePermanentKey(src, plate)

    cb({ success = true, plate = plate, price = price })
end)

QBCore.Functions.CreateCallback('citgo_dealership:financeVehicle', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb({ success = false, message = 'Player not found' }) return end
    if type(data) ~= 'table' or not canPurchase(src) then
        cb({ success = false, message = 'Você precisa estar na concessionária.' })
        return
    end

    local model = data.model
    local plate = cleanPlate(data.plate)
    local vehicleData = getVehicleData(model)

    if not vehicleData then
        cb({ success = false, message = 'Vehicle not found' })
        return
    end

    local hasSecondary = data.secondaryColor ~= nil
    local surcharge    = hasSecondary and Config.SecondaryColorPrice or 0
    local totalPrice   = vehicleData.price + surcharge
    local citizenid    = Player.PlayerData.citizenid

    local details, err = getFinanceDetails(citizenid, totalPrice)
    if not details then
        cb({ success = false, message = err })
        return
    end

    local loanResult = exports['tgg-banking']:CreateAndApproveLoan(citizenid, {
        amount           = totalPrice,
        duration         = Config.Finance.loanDuration,
        paymentFrequency = Config.Finance.paymentFrequency,
        autoPayment      = Config.Finance.autoPayment,
    })

    if not loanResult or not loanResult.success then
        cb({ success = false, message = loanResult and loanResult.message or 'Loan denied by bank' })
        return
    end

    plate = resolvePlate(plate)
    local mods = buildMods(plate, data.color, data.secondaryColor)
    insertVehicle(citizenid, model, plate, mods)
    givePermanentKey(src, plate)

    -- Track the loan-to-vehicle mapping for repo system
    MySQL.insert.await(
        'INSERT INTO dealership_loans (citizenid, loan_id, vehicle, plate, financed_at) VALUES (?, ?, ?, ?, NOW())',
        { citizenid, loanResult.loanId, model, plate }
    )

    cb({
        success      = true,
        plate        = plate,
        loanId       = loanResult.loanId,
        totalOwed    = details.totalOwed,
        dailyPayment = details.dailyPayment,
        rate         = details.rate,
    })
end)

-- ── Repo System — check for missed payments ─────────────────────────────────

CreateThread(function()
    if not Config.Finance.enabled then return end

    while true do
        Wait(Config.Finance.repoCheckInterval * 1000)

        local loans = MySQL.query.await([[
            SELECT dl.*, tbl.missedPayments, tbl.status AS loanStatus
            FROM dealership_loans dl
            JOIN tgg_banking_loans tbl ON tbl.loanId = dl.loan_id
            WHERE dl.repossessed = 0
        ]])
        if loans then
            for _, record in ipairs(loans) do
                if record.missedPayments and record.missedPayments >= Config.Finance.maxMissedPayments then
                    MySQL.update.await('DELETE FROM player_vehicles WHERE citizenid = ? AND plate = ?', {
                        record.citizenid, record.plate
                    })
                    MySQL.update.await('UPDATE dealership_loans SET repossessed = 1 WHERE id = ?', { record.id })

                    local Player = QBCore.Functions.GetPlayerByCitizenId(record.citizenid)
                    if Player then
                        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source,
                            'Your ' .. record.vehicle .. ' has been repossessed due to missed payments',
                            'error', 10000
                        )
                    end

                    print(('[citgo_dealership] Repossessed %s (plate: %s) from %s — %d missed payments'):format(
                        record.vehicle, record.plate, record.citizenid, record.missedPayments
                    ))
                end
            end
        end
    end
end)
