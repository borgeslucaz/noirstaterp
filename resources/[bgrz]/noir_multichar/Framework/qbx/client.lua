if Config.framework == 'qbx' then
    IsplayerLoaded = function()
        return QBX.PlayerData.charinfo and true or false
    end

    option = {}


    GetPlayerCharactersArray = function()
        local characters, amount = lib.callback.await('qbx_core:server:getCharacters')
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
        return lib.callback.await('IV:IsAdmin', false)
    end



    GetPlayerSkin = function(character)
        local model, skin

        model, skin = lib.callback.await('IV:GetSkin', false, character.citizenid)

        if model then
            return model, skin
        elseif character.emptyslot then
            return Config.CreateMenu.model, skin
        else
            return Config.CreateMenu.model, skin
        end
    end

    LoadSkin = function(skin)
        pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), json.decode(skin)) end)
    end


    RegisterNetEvent('multicharactere:client:newplayer', function()
        FreezeEntityPosition(PlayerPedId(), false)
        SetEntityVisible(PlayerPedId(), true)
        local resp = NewCharacterAnimation()

        Wait(1000)

        EnableWeatherSync()
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end)




    SelectCharacter = function(id)
        lib.callback.await('qbx_core:server:loadCharacter', false, id)

        TriggerServerEvent('Update:RoutingBucket', Config.Routingbucket)
        
        if Config.SpawnSelector then
            TriggerEvent('qb-spawn:client:setupSpawns', id)
            TriggerEvent('qb-spawn:client:openUI', true)
        else
            exports.spawnmanager:spawnPlayer({
                x = QBX.PlayerData.position.x,
                y = QBX.PlayerData.position.y,
                z = QBX.PlayerData.position.z,
                heading = QBX.PlayerData.position.w
            })
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
            TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
            Wait(500)
            DoScreenFadeIn(500)
            LastLocation()
            EnableWeatherSync()
        end
    end


    Createcharacter = function(payload)
        DoScreenFadeOut(500)
        Wait(500)

        ClearFocus()
        DeleteCreateCamScene()

        local newData = lib.callback.await('qbx_core:server:createCharacter', false, {
            firstname = payload.firstName,
            lastname = payload.lastName,
            nationality = payload.nationality,
            birthdate = payload.DOB,
            gender = payload.gender == 'Male' and 0 or 1,
            cid = payload.slot,
        })

        if not newData then
            DoScreenFadeIn(500)
            return
        end

        local spawn = Config.NewCharacterLocation

        exports.spawnmanager:spawnPlayer({
            x = spawn.x,
            y = spawn.y,
            z = spawn.z,
            heading = spawn.w,
            model = Config.CreateMenu.model,
            skipFade = true,
        }, function()
            FreezeEntityPosition(PlayerPedId(), false)
            SetEntityVisible(PlayerPedId(), true)
            SetEntityHeading(PlayerPedId(), spawn.w)

            local playerDataTimeout = GetGameTimer() + 10000
            while not QBX.PlayerData.charinfo and GetGameTimer() < playerDataTimeout do
                Wait(50)
            end

            EnableWeatherSync()
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
            Wait(250)
            TriggerEvent('qb-clothes:client:CreateFirstCharacter')
            Wait(250)
            DoScreenFadeIn(500)
        end)
    end
end
