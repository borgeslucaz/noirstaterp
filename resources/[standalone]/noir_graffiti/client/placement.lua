NoirGraffiti = NoirGraffiti or {}

local placing = false

local function wallRaycast()
    local hit, _, coords, normal = lib.raycast.fromCamera(511, 4, Config.Placement.maxDistance + 1.0)
    if not hit or not coords or not normal then return end
    if math.abs(normal.z) > Config.Placement.maxWallNormalZ then return end
    if #(GetEntityCoords(PlayerPedId()) - coords) > Config.Placement.maxDistance + 0.5 then return end
    return coords, normal
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function cleanupPreview(keepFrozen)
    placing = false
    NoirGraffiti.DestroyRenderer('preview')
    lib.hideTextUI()
    if not keepFrozen then FreezeEntityPosition(PlayerPedId(), false) end
end

function NoirGraffiti.StartPlacement(text, font, slot, color)
    if placing then return lib.notify({ description = 'Você já está posicionando um graffiti.', type = 'error' }) end
    placing = true
    FreezeEntityPosition(PlayerPedId(), true)

    local previewData = { text = text, font = font, color = color or Config.DefaultColor }
    local renderer = NoirGraffiti.CreateRenderer('preview', previewData)
    if not renderer then
        placing = false
        FreezeEntityPosition(PlayerPedId(), false)
        return lib.notify({ description = 'Não foi possível carregar a prévia.', type = 'error' })
    end

    local scale, angle = Config.Placement.defaultScale, 0.0
    local horizontalOffset, verticalOffset = 0.0, 0.0
    local finalCoords, finalNormal, surfaceState
    local lockedCoords, lockedNormal
    local fontIndex = 1
    for index, entry in ipairs(Config.Fonts) do if entry.id == font then fontIndex = index break end end

    local function showHelp(hasSurface)
        lib.showTextUI(hasSurface
            and ('[PAREDE FIXADA] Fonte: %s  [Z/X] Fonte  [RODA] Tamanho  [Q/E] Girar  [SETAS] Ajustar  [R] Reposicionar  [ENTER/CLIQUE] Confirmar'):format(font)
            or '[SEM PAREDE] Aponte para uma parede a menos de 4 metros  [BACKSPACE/ESC] Cancelar',
            { position = 'bottom-center' })
    end

    while placing do
        Wait(0)
        DisablePlayerFiring(PlayerPedId(), true)
        for _, control in ipairs({ 20, 21, 22, 23, 24, 30, 31, 32, 33, 34, 35, 37, 44, 38, 45, 73, 75, 172, 173, 174, 175, 177, 191, 200, 241, 242 }) do
            DisableControlAction(0, control, true)
        end

        if not lockedCoords then
            local hitCoords, hitNormal = wallRaycast()
            if hitCoords and hitNormal then
                lockedCoords, lockedNormal = hitCoords, hitNormal
            end
        end

        local hasSurface = lockedCoords ~= nil
        if hasSurface ~= surfaceState then
            surfaceState = hasSurface
            showHelp(hasSurface)
        end
        if lockedCoords and lockedNormal then
            local right, up = NoirGraffiti.Geometry.basis(lockedNormal, angle)
            finalCoords = lockedCoords + lockedNormal * Config.Placement.wallOffset + right * horizontalOffset + up * verticalOffset
            finalNormal = lockedNormal
            local corners = NoirGraffiti.Geometry.corners(finalCoords, lockedNormal, scale, angle)
            NoirGraffiti.Geometry.draw(corners, renderer.txd, renderer.txn, 230)
            DrawLine(corners.topLeft.x, corners.topLeft.y, corners.topLeft.z, corners.topRight.x, corners.topRight.y, corners.topRight.z, 116, 68, 154, 210)
            DrawLine(corners.topRight.x, corners.topRight.y, corners.topRight.z, corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z, 116, 68, 154, 210)
            DrawLine(corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z, corners.bottomLeft.x, corners.bottomLeft.y, corners.bottomLeft.z, 116, 68, 154, 210)
            DrawLine(corners.bottomLeft.x, corners.bottomLeft.y, corners.bottomLeft.z, corners.topLeft.x, corners.topLeft.y, corners.topLeft.z, 116, 68, 154, 210)
        else
            finalCoords, finalNormal = nil, nil
        end

        if IsDisabledControlJustReleased(0, 241) then scale = clamp(scale + Config.Placement.scaleStep, Config.Placement.minScale, Config.Placement.maxScale) end
        if IsDisabledControlJustReleased(0, 242) then scale = clamp(scale - Config.Placement.scaleStep, Config.Placement.minScale, Config.Placement.maxScale) end
        if IsDisabledControlPressed(0, 44) then angle = angle - Config.Placement.rotationStep * GetFrameTime() * 10.0 end
        if IsDisabledControlPressed(0, 38) then angle = angle + Config.Placement.rotationStep * GetFrameTime() * 10.0 end
        if IsDisabledControlPressed(0, 174) then horizontalOffset = horizontalOffset - Config.Placement.positionStep end
        if IsDisabledControlPressed(0, 175) then horizontalOffset = horizontalOffset + Config.Placement.positionStep end
        if IsDisabledControlPressed(0, 172) then verticalOffset = verticalOffset + Config.Placement.positionStep end
        if IsDisabledControlPressed(0, 173) then verticalOffset = verticalOffset - Config.Placement.positionStep end
        if IsDisabledControlJustReleased(0, 20) or IsDisabledControlJustReleased(0, 73) then
            local direction = IsDisabledControlJustReleased(0, 20) and -1 or 1
            fontIndex = ((fontIndex - 1 + direction) % #Config.Fonts) + 1
            font = Config.Fonts[fontIndex].id
            previewData.font = font
            NoirGraffiti.UpdateRenderer('preview', previewData)
            showHelp(hasSurface)
        end
        if IsDisabledControlJustReleased(0, 45) then
            lockedCoords, lockedNormal = nil, nil
            finalCoords, finalNormal = nil, nil
            horizontalOffset, verticalOffset = 0.0, 0.0
            surfaceState = nil
        end

        if IsDisabledControlJustReleased(0, 177) or IsDisabledControlJustReleased(0, 200) then
            cleanupPreview()
            lib.notify({ description = 'Posicionamento cancelado.', type = 'inform' })
            return
        end

        if IsDisabledControlJustReleased(0, 191) or IsDisabledControlJustReleased(0, 24) then
            if not finalCoords then
                lib.notify({ description = 'Aponte para uma parede próxima.', type = 'error' })
            else
                local coords, surfaceNormal = finalCoords, finalNormal
                cleanupPreview(true)
                local completed = lib.progressCircle({
                    duration = 5000,
                    label = 'Aplicando graffiti',
                    position = 'bottom',
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                    anim = { dict = 'anim@scripted@freemode@postertag@graffiti_spray@male@', clip = 'spray_can_idle_male' },
                    prop = { model = 'prop_cs_spray_can', bone = 57005, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
                })
                FreezeEntityPosition(PlayerPedId(), false)
                if not completed then return end

                local result = lib.callback.await('noir_graffiti:server:place', false, {
                    type = 'text', text = text, font = font, slot = slot,
                    x = coords.x, y = coords.y, z = coords.z,
                    nx = surfaceNormal.x, ny = surfaceNormal.y, nz = surfaceNormal.z,
                    scale = scale, rotation = angle,
                })
                lib.notify({
                    description = result and result.success and 'Graffiti aplicado.' or ((result and result.error) or 'Não foi possível aplicar o graffiti.'),
                    type = result and result.success and 'success' or 'error',
                })
                return
            end
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and placing then cleanupPreview() end
end)
