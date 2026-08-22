
Previewcharacter = 1

RegisterNUICallback('playcharacter', function(payload, cb)
    
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)

    local character = {}
        for i = 1,#option do
            if option[i].id == payload then
                character = option[i]
                break
            end
        end


        if character.emptyslot then
            CreateMenu(character.id)

        else

            Nuicontrol(false)
            DoScreenFadeOut(500)
            Wait(500)
            Nuimessage('visible', false)
            DeleteCamScene()

            if Config.framework == 'qbx' then
                SelectCharacter(character.citizenid)
            else
                TriggerServerEvent('IV:CharacterChosen', character)
            end

            
            SignIn()

        end

    cb { {} }
end)

RegisterNUICallback('PreviewCharacter', function(payload, cb)
    Previewcharacter = payload.counter + 1

    local char = option[payload.counter + 1]
    local data = GetCurrentScene()

    CreateLocalPed(char, data)

    cb { {} }
end)

RegisterNUICallback('CreateCharacter', function(payload, cb)
    if (payload.firstName == '') then
        PlaySoundFromEntity(-1, "5_Second_Timer", PlayerPedId(), "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0, 0)
        cb {false}
        return
    elseif (payload.lastName == '') then
        PlaySoundFromEntity(-1, "5_Second_Timer", PlayerPedId(), "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0, 0)
        cb {false}
        return
    elseif (payload.DOB == '') then
        PlaySoundFromEntity(-1, "5_Second_Timer", PlayerPedId(), "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0, 0)
        cb {false}
        return
    elseif (payload.nationality == '') then
        PlaySoundFromEntity(-1, "5_Second_Timer", PlayerPedId(), "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0, 0)
        cb {false}
        return
    end

    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
    Nuimessage('visible', false)
    Nuicontrol(false)
    DoScreenFadeOut(500)
    Wait(500)
    if Config.framework == 'qbx' then
        Createcharacter(payload)
    else
        TriggerServerEvent('IV:CreateCharacters', payload)
    end
   
    cb(true)
end)


RegisterNUICallback('DeleteCharacter', function(payload, cb)

    local key = 0
    for i = 1,#option do
        if option[i].id == payload  then
            key = i
            break
        end
    end
    if Config.framework == 'qbx' then
        lib.callback.await('qbx_core:server:deleteCharacter', false, option[key].citizenid)
    else
        print('a')
    local response = lib.callback.await('IV:DeleteCharacters',false, option[key])
    end


        PlaySoundFrontend(-1, "FocusOut",  "HintCamSounds",  0)
        
        DoScreenFadeOut(500)
        Wait(2500)

        local option = GetPlayerCharactersArray()
        CreateCamScene(option[1])

        Wait(500)
        DoScreenFadeIn(500)
       
        Nuimessage('characterselection', option)
end)

-- RegisterNUICallback('exitconfirm', function(payload, cb)
--     SetEntityVisible(PlayerPedId(), true, 0)
--     PlaySoundFrontend(-1, "FocusOut",  "HintCamSounds",  0)
--     Nuimessage('visible-chararacters')
--     cb { {} }
-- end)



-- RegisterNUICallback('OPTIONS', function(payload, cb)

-- end)

-- RegisterNUICallback('CREDIT', function(payload, cb)
--     SetEntityVisible(PlayerPedId(), false, 0)
--     PlaySoundFrontend(-1, "FocusIn",  "HintCamSounds",  0)
--     Nuimessage('visible-credits')
--     cb { {} }
-- end)

-- RegisterNUICallback('exitcredits', function(payload, cb)
--     SetEntityVisible(PlayerPedId(), true, 0)
--     PlaySoundFrontend(-1, "FocusOut",  "HintCamSounds",  0)
--     Nuimessage('visible-chararacters')
--     cb { {} }
-- end)

RegisterNUICallback('exit', function(payload, cb)
    Nuicontrol(false)
    cb { {} }
end)

-- RegisterNUICallback('EXITGAME', function(payload, cb)
--     TriggerServerEvent('Exit:Game')
--     cb { {} }
-- end)



-- RegisterNUICallback('exitdelete', function(payload, cb)
--     SetEntityVisible(PlayerPedId(), true, 0)
--     PlaySoundFrontend(-1, "FocusOut",  "HintCamSounds",  0)
--     Nuimessage('visible-chararacters')
--     cb { {} }
-- end)

-- RegisterNUICallback('DELETE', function(payload, cb)
--     print(payload.id)
--     deleteid = payload.id
--     SetEntityVisible(PlayerPedId(), false, 0)
--     PlaySoundFrontend(-1, "FocusIn",  "HintCamSounds",  0)
--     Nuimessage('deleteconfirm')
--     cb { {} }
-- end)

RegisterNUICallback('hover', function(data, cb)
    PlaySoundFrontend(-1, "Cycle_Item", 'DLC_Dmod_Prop_Editor_Sounds', 0)
    cb { {} }
end)

RegisterNUICallback('click', function(data, cb)
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
    cb { {} }
end)


RegisterNUICallback('SOUND2', function(payload, cb)
    if (payload) then
        PlaySoundFrontend(-1, "FocusIn",  "HintCamSounds",  0)
    else
        PlaySoundFrontend(-1, "FocusOut",  "HintCamSounds",  0)
    end
    cb { {} }
end)

RegisterNUICallback('GetCharacters', function(payload, cb)
    cb(GetPlayerCharactersArray())
end)

RegisterNUICallback('GetAllCharacters', function(payload, cb)
    cb(GetAllCharacters())
end)


RegisterNUICallback('getConfig', function(payload, cb)

    local data = {
        Scenes = Config.CharacterSelection,
        Lang = Config.Lang,
        credits = Config.credits,
        maxdob = Config.maxdob,
        mindob = Config.mindob,
    }
    
    cb(data)
end)
