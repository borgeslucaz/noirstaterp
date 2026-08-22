if Config.framework == 'esx' then
    IsplayerLoaded = function()
        return ESX.IsPlayerLoaded()
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
                img = '',
                emptyslot = true,
                additionalInfo = {
                    cash = 0,
                    job = 'DESEMPREGADO',
                    lastSeen = 'DESCONHECIDO'
                }
            }
        end


        for _, data in pairs(characters) do
            if data.id <= maxslots then
                option[data.id] = {
                    id = data.id,
                    firstname = data.firstname,
                    lastname = data.lastname,
                    job = data.job,
                    skin = data.skin,
                    model = data.model,
                    sex = data.sex,
                    emptyslot = false,
                    img = GetResourceKvpString('slotimg' .. tostring(data.id)),
                    additionalInfo = {
                        cash = tonumber(data.money) or 0,
                        job = data.job or 'DESEMPREGADO',
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
            local number = string.find(data.identifier, ':')
            local identifier = data.identifier:sub(number + 1)

            option[#option + 1] = {
                id = data.id,
                identifier = identifier,
                firstname = data.firstname,
                lastname = data.lastname,
                sex = data.sex,
                job = data.job,
                cash = data.money,
                bank = data.bank,
                dob = data.dateofbirth
            }
        end



        return option
    end


    IsPlayerAdmin = function()
        return ESX.PlayerData.group == Config.AdminGroup
    end

    GetPlayerSkin = function(character)
        local model, skin

        if character.emptyslot then
            return Config.CreateMenu.model, false
        end

        model = character.sex == 'm' and 'mp_m_freemode_01' or 'mp_f_freemode_01'
        skin = character.skin

        return model, skin
    end

    LoadSkin = function(skin)
        if Config.illeniumappearance then
            TriggerEvent("skinchanger:loadSkin", skin)
        else
            TriggerEvent('qb-clothing:client:loadPlayerClothing', json.decode(skin), PlayerPedId())
        end
    end



    RegisterNetEvent("multicharacter:setPlayerData", function(data)
        SetTimeout(1, function()
            ESX.SetPlayerData("name", ("%s %s"):format(data.firstname, data.lastname))
            ESX.SetPlayerData("firstName", data.firstname)
            ESX.SetPlayerData("lastName", data.lastname)
            ESX.SetPlayerData("dateofbirth", data.dateofbirth)
            ESX.SetPlayerData("sex", data.sex)
            ESX.SetPlayerData("height", data.height)
        end)
    end)




    RegisterNetEvent("esx:playerLoaded")
    AddEventHandler("esx:playerLoaded", function(playerData, isNew, skin)
        local defaultlocation = vec4(-1039.0258, -2740.4907, 20.1693, 327.8384)
        local spawn = playerData.coords or defaultlocation
        ClearFocus()
        if isNew then
            local finished = false
            skin = Config.DefaultSkin[playerData.sex]
            skin.sex = playerData.sex == "m" and 0 or 1
            local model = skin.sex == 0 and 'mp_m_freemode_01' or 'mp_f_freemode_01'

            lib.requestModel(model)
            SetPlayerModel(PlayerId(), model)
            SetModelAsNoLongerNeeded(model)

            TriggerEvent("skinchanger:loadSkin", skin, function()
                local playerPed = PlayerPedId()
                SetPedAoBlobRendering(playerPed, true)
                ResetEntityAlpha(playerPed)
                DeleteCamScene()
                Wait(500)
                DoScreenFadeIn(500)

                TriggerEvent("esx_skin:openSaveableMenu", function()
                    finished = true
                end, function()
                    finished = true
                end)
            end)
            repeat
                Wait(200)
            until finished

            DoScreenFadeOut(750)
            Wait(750)
            local resp = NewCharacterAnimation()
            TriggerServerEvent("IV:GiveItems")
        else
            if Config.SpawnSelector then
                exports['Afterlife_ivspawn']:ShowMenu(false,false)
            else
                local playerPed = PlayerPedId()
                FreezeEntityPosition(playerPed, false)
                SetEntityCoordsNoOffset(playerPed, spawn.x, spawn.y, spawn.z, false, false, false, true)
                SetEntityHeading(playerPed, spawn.heading or defaultlocation.w)
                LastLocation()
                TriggerEvent("skinchanger:loadSkin", skin)
            end
        end




        EnableWeatherSync()
        TriggerServerEvent("esx:onPlayerSpawn")
        TriggerEvent("esx:onPlayerSpawn")
        TriggerEvent("playerSpawned")
        TriggerEvent("esx:restoreLoadout")
        TriggerServerEvent('Update:RoutingBucket', Config.Routingbucket)
        SignIn()
        Wait(1000)
        Canlogout = true
    end)
end
