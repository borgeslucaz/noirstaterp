if Config.framework == 'qb' then
    local QBCore = exports['qb-core']:GetCoreObject()
    local hasDonePreloading = {}

    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        Wait(1000) -- 1 second should be enough to do the preloading in other resources

        SetPlayerRoutingBucket(Player.PlayerData.source,Config.Routingbucket)
        hasDonePreloading[Player.PlayerData.source] = true
    end)

    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
        hasDonePreloading[src] = false
    end)

    local function GiveStarterItems(source)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        for i = 1, #Config.StarterItems do
            local info = {}
            if Config.StarterItems[i].name == "id_card" then
                info.citizenid = Player.PlayerData.citizenid
                info.firstname = Player.PlayerData.charinfo.firstname
                info.lastname = Player.PlayerData.charinfo.lastname
                info.birthdate = Player.PlayerData.charinfo.birthdate
                info.gender = Player.PlayerData.charinfo.gender
                info.nationality = Player.PlayerData.charinfo.nationality
            elseif Config.StarterItems[i].name == "driver_license" then
                info.firstname = Player.PlayerData.charinfo.firstname
                info.lastname = Player.PlayerData.charinfo.lastname
                info.birthdate = Player.PlayerData.charinfo.birthdate
                info.type = "Class C Driver License"
            end

            if Config.oxinventory then
                exports.ox_inventory:AddItem(src, Config.StarterItems[i].name, Config.StarterItems[i].amount,info,false,false)
            else
                exports['qb-inventory']:AddItem(src, Config.StarterItems[i].name, Config.StarterItems[i].amount, false, info, 'qb-multicharacter:GiveStarterItems')
            end

        end
    end


    local function loadHouseData(src)
        local HouseGarages = {}
        local Houses = {}
        local result = MySQL.query.await('SELECT * FROM houselocations', {})
        if result[1] ~= nil then
            for _, v in pairs(result) do
                local owned = false
                if tonumber(v.owned) == 1 then
                    owned = true
                end
                local garage = v.garage ~= nil and json.decode(v.garage) or {}
                Houses[v.name] = {
                    coords = json.decode(v.coords),
                    owned = owned,
                    price = v.price,
                    locked = true,
                    adress = v.label,
                    tier = v.tier,
                    garage = garage,
                    decorations = {},
                }
                HouseGarages[v.name] = {
                    label = v.label,
                    takeVehicle = garage,
                }
            end
        end
        TriggerClientEvent("qb-garages:client:houseGarageConfig", src, HouseGarages)
        TriggerClientEvent("qb-houses:client:setHouseConfig", src, Houses)
    end





    RegisterNetEvent("IV:Relog", function()
        QBCore.Player.Logout(source)
    end)

    lib.callback.register('IV:DeleteCharacters', function(source, char)
        local src = source
        QBCore.Player.DeleteCharacter(src, char.citizenid)
        return true
    end)


    RegisterNetEvent('IV:CreateCharacters', function(message)
        local src = source
        local data = {
            firstname = message.firstName,
            lastname = message.lastName,
            nationality = message.nationality,
            birthdate = message.DOB,
            gender = message.gender == 'Male' and 0 or 1,
            cid = message.slot,
        }
        local newData = {}
        newData.cid = data.cid
        newData.charinfo = data
        if QBCore.Player.Login(src, false, newData) then
            repeat
                Wait(10)
            until hasDonePreloading[src]
            if Config.SpawnSelector and Config.appartmentstart then
                local randbucket = (GetPlayerPed(src) .. math.random(1, 999))
                SetPlayerRoutingBucket(src, randbucket)
                QBCore.Commands.Refresh(src)
                loadHouseData(src)
                TriggerClientEvent("qb-multicharacter:client:closeNUI", src)
                TriggerClientEvent(Config.appartmentevent, src, newData)
            else
                QBCore.Commands.Refresh(src)
                loadHouseData(src)
                TriggerEvent('apartments:client:SetHomeBlip', nil)
                TriggerClientEvent('multicharactere:client:newplayer', src)
            end
            GiveStarterItems(src)
        end

    end)




    lib.callback.register('IV:GetCharacters', function(source)
        local license = QBCore.Functions.GetIdentifier(source, 'license')
        local plyChars = {}
        local result = MySQL.query.await('SELECT * FROM players WHERE license = ?', { license })

        for i = 1, (#result), 1 do
            result[i].charinfo = json.decode(result[i].charinfo)
            result[i].money = json.decode(result[i].money)
            result[i].job = json.decode(result[i].job)
            plyChars[#plyChars + 1] = result[i]
        end

        return plyChars
    end)


    lib.callback.register('IV:GetAllCharacters', function(source)
        local plyChars = {}
        local result = MySQL.query.await('SELECT * FROM players')

        for i = 1, (#result), 1 do
            result[i].charinfo = json.decode(result[i].charinfo)
            result[i].money = json.decode(result[i].money)
            result[i].job = json.decode(result[i].job)
            plyChars[#plyChars + 1] = result[i]
        end

        return plyChars
    end)


    lib.callback.register("IV:GetSkin", function(source, cid)
        local result = MySQL.query.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = ?', { cid, 1 })

        if result[1] then
            return result[1].model, result[1].skin
        end
    end)

    lib.callback.register('IV:IsAdmin', function(source)
        return QBCore.Functions.HasPermission(source, 'admin') or IsPlayerAceAllowed(source, 'command')
    end)


    RegisterNetEvent('IV:CharacterChosen', function(cData)
        local src = source

        local cData = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', { cData.citizenid })[1]
        if QBCore.Player.Login(src, cData.citizenid) then
            repeat
                Wait(10)
            until hasDonePreloading[src]
            QBCore.Commands.Refresh(src)
            loadHouseData(src)
            if Config.SpawnSelector then
                TriggerClientEvent('qb-spawn:client:setupSpawns', src, cData, false, nil)
                TriggerClientEvent('qb-spawn:client:openUI', src, true)
            else
                local coords = json.decode(cData.position)
                TriggerClientEvent('multicharacter:client:spawnLastLocation', src, coords, cData)
            end
        end
    end)
end
