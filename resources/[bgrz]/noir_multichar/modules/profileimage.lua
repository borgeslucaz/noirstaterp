RegisterNUICallback('saveprofilepicture', function(data, cb)
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
    SetResourceKvp('slotimg' .. tostring(data.slot), data.img)


    cb(GetPlayerCharactersArray())
end)

local openprofiles = function()
    local profiles = GetPlayerCharactersArray()
    Nuimessage('profilepicture', profiles)
    Nuicontrol(true)
end


RegisterCommand(Config.ProfilEditorCommand, function()
    openprofiles()
end)


