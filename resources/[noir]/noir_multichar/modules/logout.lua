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

        TriggerServerEvent('qbx:Logout')
        Wait(1000)
        LogoutPlayer()
    end
end

RegisterCommand('Logout', Logout)
