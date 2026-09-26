-- NOIR: /capturarcena <id> monta o bloco de uma cena nova para Config.CharacterSelection do
-- noir_multichar. Fica aqui, junto do freecam, porque é com ele que a cena é enquadrada e
-- porque reiniciar este resource é mais leve que reiniciar a seleção de personagem.
--
-- Como usar: estacione o carro (se a cena tiver um) e desça; fique em pé onde o personagem
-- deve aparecer, virado para onde ele deve olhar; enquadre com o /freecam e rode o comando
-- com ele ligado. A câmera capturada é a que está na tela.
-- O bloco sai no F8 e vai para a área de transferência.

local WEATHERS = {
    'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'SMOG', 'FOGGY', 'OVERCAST', 'RAIN', 'THUNDER',
    'CLEARING', 'NEUTRAL', 'SNOW', 'BLIZZARD', 'SNOWLIGHT', 'XMAS', 'HALLOWEEN',
}

local function currentWeather()
    local hash = GetPrevWeatherTypeHashName()
    for _, name in ipairs(WEATHERS) do
        if joaat(name) == hash then return name end
    end
    return 'EXTRASUNNY'
end

local function fmt(n) return ('%.4f'):format(n) end

RegisterCommand('capturarcena', function(_, args)

    local id = args[1] or ('cena_%d'):format(GetCloudTimeAsInt())
    local ped = PlayerPedId()
    local pos, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local camPos, camRot, fov = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2), GetFinalRenderedCamFov()

    -- Carro de enfeite: o último em que o ped esteve, se ficou perto.
    local vehicleLine, vehicleLocationLine = '        vehicle = false,', nil
    local vehicle = GetVehiclePedIsIn(ped, true)
    if vehicle ~= 0 and DoesEntityExist(vehicle) and #(GetEntityCoords(vehicle) - pos) < 20.0 then
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
        local vpos, vheading = GetEntityCoords(vehicle), GetEntityHeading(vehicle)
        vehicleLine = ("        vehicle = '%s', -- confira se é o nome de spawn"):format(model)
        vehicleLocationLine = ('        vehiclelocation = vec4(%s, %s, %s, %s),'):format(fmt(vpos.x), fmt(vpos.y), fmt(vpos.z), fmt(vheading))
    end

    local lines = {
        '    {',
        ("        id = '%s',"):format(id),
        ("        weather = '%s',"):format(currentWeather()),
        ('        time = { hours = %d, minutes = %d, seconds = 0 },'):format(GetClockHours(), GetClockMinutes()),
        -- Sem dict/anim: a pose é sorteada. Para cena sentada, acrescente dict/anim à mão.
        vehicleLine,
        ('        location = vec4(%s, %s, %s, %s),'):format(fmt(pos.x), fmt(pos.y), fmt(pos.z), fmt(heading)),
    }
    if vehicleLocationLine then lines[#lines + 1] = vehicleLocationLine end
    lines[#lines + 1] = ('        camlocation = vec3(%s, %s, %s),'):format(fmt(camPos.x), fmt(camPos.y), fmt(camPos.z))
    lines[#lines + 1] = ('        camrotation = vec3(%s, %s, %s),'):format(fmt(camRot.x), fmt(camRot.y), fmt(camRot.z))
    lines[#lines + 1] = ('        fov = %.1f,'):format(fov)
    lines[#lines + 1] = '    },'

    local block = table.concat(lines, '\n')
    print(('^2[noir_multichar] cena capturada:^7\n%s'):format(block))
    lib.setClipboard(block)
    lib.notify({ title = 'Cena capturada', description = ('%s copiada para a área de transferência (e no F8)'):format(id), type = 'success' })
end, false)
