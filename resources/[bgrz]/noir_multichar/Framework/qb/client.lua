if Config.framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()

    IsplayerLoaded = function()
        return QBCore.PlayerData.charinfo and true or false
    end

    option = {}


    GetPlayerCharactersArray = function()

        local characters = lib.callback.await('IV:GetCharacters')
        local maxslots = GetPlayerMaxSlots('src') 
        option = {}


        for i = 1, maxslots do
            option[#option + 1] = {
                id = #option + 1,
                firstname = 'Nome',
                lastname = 'Sobrenome',
                citizenid = 'UNKNOWN',
                emptyslot = true,
                img = '',
                additionalInfo = {
                    cash = 0,
                    job = 'DESEMPREGADO',
                    lastSeen = 'DESCONHECIDO'
                }
            }
        end

        for _, data in pairs(characters) do
            if data.charinfo.cid <= maxslots then
                option[data.charinfo.cid] = {
                    id = data.charinfo.cid,
                    firstname = data.charinfo.firstname,
                    lastname = data.charinfo.lastname,
                    citizenid = data.citizenid,
                    job = data.job.name,
                    emptyslot = false,
                    img = GetResourceKvpString('slotimg' .. tostring(data.charinfo.cid)),
                    sex = data.charinfo.gender == 0 and true or false,
                    additionalInfo = {
                        cash = tonumber(data.money and data.money.cash) or 0,
                        job = data.job and data.job.label or 'DESEMPREGADO',
                        lastSeen = GetLastSeenLabel(data.position)
                    }
                }
            end
        end


        return option
    end



    GetAllCharacters = function()
        local characters = lib.callback.await('IV:GetAllCharacters')

        local option = {}

        for _, data in pairs(characters) do
            local number = string.find(data.license, ':')
            local identifier = data.license:sub(number + 1)

            option[#option + 1] = {
                id = data.cid,
                identifier = identifier,
                firstname = data.charinfo.firstname,
                lastname = data.charinfo.lastname,
                sex = data.charinfo.gender == 0 and true or false,
                job = data.job.label,
                cash = data.money.cash,
                bank = data.money.bank,
                dob = data.charinfo.birthdate

            }
        end

        return option
    end


    IsPlayerAdmin = function()
        return  lib.callback.await('IV:IsAdmin', false)
    end

   


    GetPlayerSkin = function(character)
        local model, skin


        model,skin = lib.callback.await('IV:GetSkin',false, character.citizenid)

        if model then
            return model, skin
        elseif character.emptyslot then
            return Config.CreateMenu.model, skin
        else
            return Config.CreateMenu.model, skin
        end

    end

    LoadSkin = function(skin)
        if Config.illeniumappearance then
            pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), json.decode(skin)) end)
        else
            TriggerEvent('qb-clothing:client:loadPlayerClothing', json.decode(skin), PlayerPedId())
        end
    end

    RegisterNetEvent('multicharactere:client:newplayer', function()
        FreezeEntityPosition(PlayerPedId(), false)
        SetEntityVisible(PlayerPedId(), true)
        ClearFocus()
        local resp = NewCharacterAnimation()

        Wait(1000)

        EnableWeatherSync()
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
        TriggerServerEvent('Update:RoutingBucket', Config.Routingbucket)
    end)

    RegisterNetEvent('multicharactere:client:newplayer', function()
        FreezeEntityPosition(PlayerPedId(), false)
        SetEntityVisible(PlayerPedId(), true)
        local resp = NewCharacterAnimation()
    end)

    RegisterNetEvent('multicharacter:client:spawnLastLocation', function(coords, cData)
        local ped = PlayerPedId()
        pcall(function()
            SetEntityCoords(ped, coords.x, coords.y, coords.z)
            SetEntityHeading(ped, coords.w)
        end)

        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true)
        local PlayerData = QBCore.Functions.GetPlayerData()
        local insideMeta = PlayerData.metadata["inside"]
        DoScreenFadeOut(500)

        if insideMeta.house then
            TriggerEvent('qb-houses:client:LastLocationHouse', insideMeta.house)
        elseif insideMeta.apartment.apartmentType and insideMeta.apartment.apartmentId then
            TriggerEvent('qb-apartments:client:LastLocationHouse', insideMeta.apartment.apartmentType,
                insideMeta.apartment.apartmentId)
        else
            pcall(function()
                SetEntityCoords(ped, coords.x, coords.y, coords.z)
                SetEntityHeading(ped, coords.w)
            end)
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true)
        end

        LastLocation()
        EnableWeatherSync()
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
        TriggerServerEvent('Update:RoutingBucket', Config.Routingbucket)
    end)

end
