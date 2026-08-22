

local OpenAdminPanel = function ()
    local characters = GetAllCharacters()

    Nuimessage('adminpanel', characters)
    Nuicontrol(true)
end


RegisterCommand(Config.AdminCommand, function ()
    if IsPlayerAdmin() then
    OpenAdminPanel()
    end
end)




RegisterNUICallback('updateslot', function(payload, cb)
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
    local resp = lib.callback.await('IV:UpdateSlot', false, payload)
    cb { {} }
end)

RegisterNUICallback('GetSlots', function(payload, cb)
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)

    local slots = lib.callback.await('IV:GetExtraSlots', false,payload)

    cb(slots)
end)



