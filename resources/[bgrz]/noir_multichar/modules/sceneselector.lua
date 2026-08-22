GetCurrentScene = function()
    local id = GetResourceKvpString('IV:Multicharacter')

    for i = 1, #Config.CharacterSelection do
        if Config.CharacterSelection[i].id == id then
            return Config.CharacterSelection[i]
        end
    end
end


RegisterNUICallback('UpdateScene', function(payload, cb)
    local id = GetResourceKvpString('IV:Multicharacter')
    if not (payload == id) then
        PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
        SetResourceKvp('IV:Multicharacter', payload)

        CreateCamScene(option[Previewcharacter])
    end

    cb({})
end)


RegisterNUICallback('getcurrentscene', function(payload, cb)
    local id = GetResourceKvpString('IV:Multicharacter')
    cb(id)
end)



CreateThread(function()
    ::Repeat::

    local key = GetResourceKvpString('IV:Multicharacter')
    if key then
        ------
    else
        SetResourceKvp('IV:Multicharacter', Config.CharacterSelection[1].id)
        goto Repeat
    end
end)
