stolenDrugs = {}

while Framework == nil do Wait(5) end

-- Nível e XP do vendedor moram no noir_skills. Ele é dependency no fxmanifest, então os
-- exports existem sempre que este resource está de pé — não há caminho alternativo aqui de
-- propósito: um fallback silencioso faria o jogador vender sem progredir e ninguém notaria.
local SKILL = Config.Leveling.Skill

local function getDrugLevel(source)
    return exports.noir_skills:GetLevel(source, SKILL)
end

if Config.LevelCommand then
    RegisterCommand(Config.LevelCommand, function(source)
        local lvl = getDrugLevel(source)
        local boost = GetLevelBoost(lvl)

        TriggerClientEvent('op-drugselling:sendNotify', source, TranslateIt('level_command', lvl, boost .. "%"), "info", 5)
    end)
end

RegisterServerEvent('op-drugselling:getBackDrugs', function()
    local drugsCf = stolenDrugs[tostring(source)]
    if drugsCf then
        local xPlayer = Fr.getPlayerFromId(source)
        if not (drugsCf.grade and NoirDrugGrade.give(source, drugsCf.drugName, drugsCf.amount, drugsCf.grade)) then
            Fr.addItem(xPlayer, drugsCf.drugName, drugsCf.amount)
        end
        stolenDrugs[tostring(source)] = nil
    end
end)

-- Helper:
local function adjustSellChanceByPrice(baseChance, pricePerGram, cfgDrug)
    local minP = cfgDrug.minimumPrice or 0
    local optP = cfgDrug.optimalPrice or pricePerGram or 0
    local maxP = cfgDrug.maximumPrice or (optP > 0 and optP * 2 or 100)

    local influence = (cfgDrug.priceInfluence or 30) * 0.5  

    if optP <= minP then minP = math.max(0, optP - 1) end
    if maxP <= optP then maxP = optP + 1 end

    local factor = 0.0
    if pricePerGram and pricePerGram < optP then
        factor = math.min(1.0, (optP - pricePerGram) / (optP - minP))
    elseif pricePerGram and pricePerGram > optP then
        factor = -math.min(1.0, (pricePerGram - optP) / (maxP - optP))
    else
        factor = 0.0
    end

    local adjusted = baseChance + (factor * influence)
    return math.max(0, math.min(100, adjusted))
end

Fr.RegisterServerCallback('op-drugselling:getlvl', function(source, cb)
    return cb(getDrugLevel(source))
end)

-- Um negócio por ped, contado aqui. A lista do cliente (`soldPedsList`) só serve para esconder
-- a opção; quem decide é o servidor, senão um cliente adulterado vende o estoque inteiro parado,
-- sem ped nenhum, e leva XP, influência e reputação a cada chamada.
-- `entityRemoved` limpa quando o ped some; o prazo cobre o caso em que o evento não vem (entidade
-- culled) e o handle volta a ser usado por outro ped.
local DEALT_TTL = 30 * 60
local dealtPeds = {}

AddEventHandler('entityRemoved', function(entity)
    dealtPeds[entity] = nil
end)

CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        local now = os.time()
        for ped, at in pairs(dealtPeds) do
            if now - at > DEALT_TTL then dealtPeds[ped] = nil end
        end
    end
end)

---O ped da negociação, resolvido pelo servidor: existe, é ped, não é jogador, está na área
---do vendedor e ainda não negociou. Tipo do ped sai do modelo, não do que o cliente diz.
---Na recusa, o segundo retorno diz qual conferência falhou, para o log.
local function resolveCustomer(source, netId)
    if type(netId) ~= 'number' or netId <= 0 then return nil, 'sem netId' end
    local ped = NetworkGetEntityFromNetworkId(netId)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil, 'entidade não existe no servidor' end
    if GetEntityType(ped) ~= 1 then return nil, ('não é ped (tipo %s)'):format(GetEntityType(ped)) end
    if IsPedAPlayer(ped) then return nil, 'é jogador' end

    local at = dealtPeds[ped]
    if at and os.time() - at <= DEALT_TTL then return nil, 'já negociou' end

    -- O servidor não sabe onde o ped de rua está de verdade (ver ServerConfig): confere só
    -- que ele é da área. O alcance da negociação fica no cliente.
    local maxDistance = tonumber(ServerConfig.CustomerMaxDistance) or 200.0
    local distance = #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(ped))
    if distance > maxDistance then
        return nil, ('longe: %.1f m (máx. %.1f)'):format(distance, maxDistance)
    end

    return ped, Config.PedsList[GetEntityModel(ped)] or 'normal'
end

Fr.RegisterServerCallback('op-drugselling:sellDrug', function(source, cb, drugName, pricePerGram, customerNetId, cornerSelling)
    local xPlayer = Fr.getPlayerFromId(source)
    if not xPlayer then return cb(false) end

    local customer, pedType = resolveCustomer(source, customerNetId)
    if not customer then
        local reason = pedType
        -- Recusa em vez de erro: o cliente solta o ped e segue para o próximo, como numa
        -- recusa comum. O log fica para medir se ped legítimo cai aqui (ped fora da rede).
        print(('[op-drugselling] venda recusada, ped inválido: src=%s netId=%s motivo=%s'):format(source, tostring(customerNetId), tostring(reason)))
        return cb({ refused = true })
    end

    local hasItem = Fr.getItem(xPlayer, drugName)
    if not (hasItem and hasItem.amount and hasItem.amount > 0) then
        print('[op-drugselling] Player doenst have items inside inventory')
        print(json.encode(hasItem))
        print("drugName", drugName)
        return cb(false)
    end

    local cfgDrug = Config.DrugSelling.availableDrugs[drugName]
    if not cfgDrug then
        print('[op-drugselling] Missing drug config:', drugName)
        return cb(false)
    end

    local cfgPed = Config.PedTypes[pedType]
    if not cfgPed then
        print('[op-drugselling] Missing pedType config:', pedType)
        return cb(false)
    end

    -- O preço vem da NUI; fora da faixa do config só um cliente adulterado manda. Prende na
    -- faixa em vez de confiar, senão o preço vira dinheiro sujo sem teto.
    if type(pricePerGram) ~= 'number' or pricePerGram ~= pricePerGram then
        return cb(false)
    end
    local minPrice = cfgDrug.minimumPrice or 0
    local maxPrice = cfgDrug.maximumPrice or minPrice
    local clamped = math.floor(math.max(minPrice, math.min(maxPrice, pricePerGram)))
    if clamped ~= pricePerGram then
        print(('[op-drugselling] preço fora da faixa: src=%s droga=%s preço=%s faixa=%s-%s'):format(source, drugName, pricePerGram, minPrice, maxPrice))
    end
    pricePerGram = clamped

    -- A venda sai de um slot só, o de melhor grau (integrations/server/grade.lua); sem a
    -- ponte, de qualquer slot, como antes.
    local lot = NoirDrugGrade.pick(source, drugName)
    local available = lot and lot.count or hasItem.amount

    local maxPerPed = cfgDrug.maxAmountPedTransaction or 1
    local maxCanSell = math.max(1, math.min(available, maxPerPed))
    local amountSell = math.random(1, maxCanSell)

    local playerLevel = getDrugLevel(source)

    local multiplier = (1.0 + (GetLevelBoost(playerLevel) / 100.0)) * NoirDrugGrade.multiplier(lot)
    local finalPrice = math.floor((pricePerGram or 0) * amountSell * multiplier)

    local function takeDrug()
        if lot then return NoirDrugGrade.remove(source, drugName, amountSell, lot) end
        return Fr.removeItem(xPlayer, drugName, amountSell) ~= false
    end

    local sellChance, stealChance, refuseChance

    if cornerSelling then
        sellChance  = 80
        stealChance = 20
        refuseChance = 0
    else
        local baseSell = math.max(0, math.min(100, cfgPed.buyChance or 0))
        sellChance  = adjustSellChanceByPrice(baseSell, pricePerGram or cfgDrug.optimalPrice, cfgDrug)
        stealChance = math.max(0, math.min(100, cfgPed.stealDrugChance or 0))
        refuseChance = math.max(0, 100 - (sellChance + stealChance))
    end

    dealtPeds[customer] = os.time()

    local roll = math.random(1, 100)
    local stealBandEnd = stealChance
    local sellBandEnd  = stealBandEnd + sellChance

    if roll <= stealBandEnd then
        if not takeDrug() then return cb(false) end
        stolenDrugs[tostring(source)] = {
            amount = amountSell,
            drugName = drugName,
            grade = lot and lot.graded and lot.grade or nil,
        }
        return cb({ steal = true, amount = amountSell })
    elseif roll <= sellBandEnd then
        -- A droga sai antes de qualquer efeito (XP, território, dinheiro): se o slot mudou
        -- desde a leitura, a venda para aqui sem ter dado nada.
        if not takeDrug() then return cb(false) end
        local label = (cfgDrug.label or drugName)
        if lot and lot.graded then label = ('%s (%s)'):format(label, lot.grade) end

        local isRivalry = false
        local zoneOwner = false
        if Config.AdditionalScripts.op_Gangs then
            local turfId = exports['op-crime']:getPlayerTurfZone(source)
            if turfId then 
                isRivalry = exports['op-crime']:isTurfZoneInRivalry(turfId)
                zoneOwner = exports['op-crime']:isPlayerTurfOwner(source, turfId)
                TriggerEvent('op-crime:drugSold', source, turfId, finalPrice, amountSell)

                if isRivalry then 
                    finalPrice = finalPrice / 2
                end

                if zoneOwner then 
                    finalPrice = finalPrice * 1.1
                end
            end
        end
        exports.noir_skills:AddXp(source, SKILL, cfgPed.saleEXP)
        local newLevel = getDrugLevel(source)

        finalPrice = math.floor(finalPrice)

        Fr.ManageDirtyMoney(xPlayer, "add", finalPrice)

        NoirDrugTerritory.onSale(source)

        -- A venda fechada também é reputação da gang, mas quem decide quanto é o
        -- noir_illegal_core, que escuta este evento. Aqui só se diz o que aconteceu — a mesma
        -- fronteira da influência no noir_territories. Sem o core de pé, o evento cai no vazio.
        TriggerEvent('noir_drugselling:server:saleCompleted', {
            source = source,
            drug = drugName,
            amount = amountSell,
            price = finalPrice,
            grade = lot and lot.graded and lot.grade or nil,
            cornerSelling = cornerSelling == true,
        })

        local ident = Fr.GetIndentifier(source)
        local message = formatWebHook("**Drug Name:**", drugName or "None", "\n**Price per gram:**", pricePerGram, "\n**Player Identificator:**", ident, "\n**Price:**", finalPrice, "\n**Corner Selling:**", cornerSelling and "True" or "False")
        SendWebHook("DRUG SOLD", 706333, message)

        return cb({
            sold = true,
            label = label,
            amount = amountSell,
            price = finalPrice,
            newLevel = newLevel,
            isRivalry = isRivalry,
            zoneOwner = zoneOwner
        })
    else
        return cb({ refused = true })
    end
end)

