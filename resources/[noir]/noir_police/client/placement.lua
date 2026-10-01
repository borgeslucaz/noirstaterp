---Posicionar por mira, no mesmo modo do noir_garage e do noir_gathering: o ponto segue
---o chão para onde a câmera aponta, a roda do mouse gira (Shift = mais rápido), Enter
---confirma e Backspace cancela. Sem gizmo: no Enhanced o object_gizmo desenha as alças
---mas não pega o clique.

local Placement = {}

local GHOST_VEHICLE = `police`

local function drawArrow(position, heading, color)
    DrawMarker(2, position.x, position.y, position.z + 1.2, 0.0, 0.0, 0.0, 0.0, 180.0, heading, 0.4, 0.4, 0.4,
        color[1], color[2], color[3], 220, false, false, 2, false, nil, nil, false)
end

local function ghostVehicle(start)
    if not IsModelInCdimage(GHOST_VEHICLE) or not pcall(lib.requestModel, GHOST_VEHICLE, 5000) then return nil, 0.0 end
    local vehicle = CreateVehicle(GHOST_VEHICLE, start.x, start.y, start.z, start.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(GHOST_VEHICLE)
    if vehicle == 0 then return nil, 0.0 end
    local min = GetModelDimensions(GHOST_VEHICLE)
    SetEntityCollision(vehicle, false, false)
    FreezeEntityPosition(vehicle, true)
    SetEntityAlpha(vehicle, 170, false)
    SetVehicleDoorsLocked(vehicle, 2)
    return vehicle, -min.z
end

local function deleteGhost(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteEntity(vehicle)
    end
end

---Abre o modo de posicionar e devolve onde o admin confirmou, ou nil se cancelou.
---@param mode 'point'|'heading'|'vehicle'
---@param current? { x: number, y: number, z: number, w?: number } posição salva, para partir dela
---@return { x: number, y: number, z: number, w: number }?
function Placement.run(mode, current)
    local ahead = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * (mode == 'vehicle' and 6.0 or 2.0)
    local start = current or { x = ahead.x, y = ahead.y, z = ahead.z, w = GetEntityHeading(cache.ped) }
    local position = vec3(start.x, start.y, start.z)
    local heading = start.w or GetEntityHeading(cache.ped)
    local ghost, lift = nil, 0.0
    if mode == 'vehicle' then ghost, lift = ghostVehicle(start) end

    local placing, result = true, nil
    local reach = mode == 'vehicle' and 40.0 or 30.0

    -- Mira em thread própria: o raycast espera um frame, e o laço abaixo lê as teclas
    -- em todo frame para não perder o Enter nem a roda.
    CreateThread(function()
        while placing do
            local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, reach)
            if hit and placing then position = vec3(coords.x, coords.y, coords.z) end
        end
    end)

    lib.showTextUI(locale(mode == 'point' and 'editor.place_help_point' or 'editor.place_help_heading'), { position = 'left-center' })

    while placing do
        for _, control in ipairs({ 14, 15, 16, 17, 24, 25, 177 }) do DisableControlAction(0, control, true) end
        DisablePlayerFiring(cache.playerId, true)

        if mode ~= 'point' then
            local step = IsControlPressed(0, 21) and 15.0 or 5.0
            if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then
                heading = (heading - step) % 360
            elseif IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then
                heading = (heading + step) % 360
            end
        end

        if ghost then
            SetEntityCoordsNoOffset(ghost, position.x, position.y, position.z + lift, false, false, false)
            SetEntityHeading(ghost, heading)
        else
            DrawMarker(1, position.x, position.y, position.z - 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.6,
                60, 140, 255, 160, false, false, 2, false, nil, nil, false)
            if mode == 'heading' then drawArrow(position, heading, { 255, 200, 60 }) end
        end

        if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then
            local z = ghost and GetEntityCoords(ghost).z or position.z + 1.0
            result = { x = position.x, y = position.y, z = z, w = heading }
            placing = false
        elseif IsDisabledControlJustReleased(0, 177) then
            placing = false
        end
        Wait(0)
    end

    lib.hideTextUI()
    deleteGhost(ghost)
    return result
end

---Posição e rotação da câmera que o jogo está mostrando agora (para câmera de segurança).
---@return { x: number, y: number, z: number, rx: number, ry: number, rz: number }
function Placement.captureCamera()
    local coords = GetFinalRenderedCamCoord()
    local rot = GetFinalRenderedCamRot(2)
    return { x = coords.x, y = coords.y, z = coords.z, rx = rot.x, ry = rot.y, rz = rot.z }
end

---Objeto fantasma na mira, igual ao vaso do noir_weed: segue o chão para onde a câmera
---aponta, a roda gira (Shift = 15°), Enter confirma, Backspace cancela.
---@param model integer
---@param range number distância máxima do jogador (o servidor confere de novo)
---@return { x: number, y: number, z: number, w: number }?
function Placement.object(model, range)
    if not IsModelInCdimage(model) or not pcall(lib.requestModel, model, 5000) then return nil end
    local start = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 1.5
    local ghost = CreateObject(model, start.x, start.y, start.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if ghost == 0 then return nil end
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityAlpha(ghost, 180, false)

    local position, valid, placing, result = start, false, true, nil
    local heading = GetEntityHeading(cache.ped)

    -- Mira em thread própria: o raycast do ox_lib espera um frame, e o laço lê teclas
    -- em todo frame.
    CreateThread(function()
        while placing do
            local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, range + 4.0)
            if placing then
                valid = hit and #(coords - GetEntityCoords(cache.ped)) <= range
                if valid then position = coords end
            end
        end
    end)

    lib.showTextUI(locale('placement.object_help'))
    while placing do
        DisableControlAction(0, 14, true)
        DisableControlAction(0, 15, true)
        DisableControlAction(0, 16, true)
        DisableControlAction(0, 17, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 177, true)
        DisablePlayerFiring(cache.playerId, true)

        local step = IsControlPressed(0, 21) and 15.0 or 5.0
        if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then
            heading = (heading - step) % 360
        elseif IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then
            heading = (heading + step) % 360
        end

        SetEntityCoordsNoOffset(ghost, position.x, position.y, position.z, false, false, false)
        SetEntityHeading(ghost, heading)
        SetEntityAlpha(ghost, valid and 180 or 70, false)

        if valid and (IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201)) then
            result = { x = position.x, y = position.y, z = position.z, w = heading }
            placing = false
        elseif IsDisabledControlJustReleased(0, 177) then
            placing = false
        end
        Wait(0)
    end
    lib.hideTextUI()
    if DoesEntityExist(ghost) then DeleteObject(ghost) end
    return result
end

return Placement
