Canlogout = true

LogoutPlayer = function()
    DoScreenFadeOut(500)
    Wait(500)

    local option = GetPlayerCharactersArray()
    CreateCamScene(option[1])
    Wait(500)
    DoScreenFadeIn(500)
    Nuimessage('loadingscreen', false)
    
    Nuicontrol(true)
    Nuimessage('visible', true)
    SignOut()
end


Logout = function()
    if Canlogout then

        if Config.framework == 'qbx' then
            TriggerServerEvent('qbx:Logout')
        else
            TriggerServerEvent("IV:Relog")
        end
        Wait(1000)
        LogoutPlayer()
    end
end

RegisterCommand('Logout', Logout)
