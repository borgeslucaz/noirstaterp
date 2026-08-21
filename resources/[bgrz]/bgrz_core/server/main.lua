BGRZ = BGRZ or {}

CreateThread(function()
    local version = exports.qbx_core:GetCoreVersion(
        GetCurrentResourceName()
    )

    print('-----------------------------------------')
    print('[BGRZ] bgrz_core started')
    print(('[BGRZ] Qbox version: %s'):format(version or 'unknown'))
    print('-----------------------------------------')
end)

RegisterCommand('bgrztest', function(source)
    if not BGRZConfig.Debug then
        return
    end

    if source == 0 then
        print('[BGRZ] /bgrztest precisa ser executado por um jogador.')
        return
    end

    local character, err = BGRZ.GetCharacter(source)

    if not character then
        print(
            ('[BGRZ] Failed getting character: %s')
                :format(err or 'unknown')
        )

        exports.qbx_core:Notify(
            source,
            'Não foi possível carregar seu personagem.',
            'error'
        )

        return
    end

    print('[BGRZ] Character loaded:')
    print(json.encode(character))

    exports.qbx_core:Notify(
        source,
        ('BGRZ Core OK | %s | %s'):format(
            character.name.full,
            character.citizenId
        ),
        'success',
        10000
    )
end, false)
