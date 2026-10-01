-- Noir: posicionar por mira, no mesmo molde do editor do noir_garage. A câmera livre
-- original movia o foco de streaming (SetFocusPosAndVel) e o mundo em volta sumia:
-- peds, props e a mobília do interior. Aqui o admin anda com o próprio personagem, o
-- ponto segue o chão para onde a câmera do jogo aponta, a roda do mouse gira (Shift =
-- mais rápido), Enter confirma e Backspace cancela.
--
-- O fantasma é o que a etapa cria de verdade em jogo, do mesmo jeito que client/run.lua
-- e client/hazards.lua criam: o prop (com propZ e PlaceObjectOnGroundProperly), o ped
-- (o spawn usa z - 1, então o ponto fica 1 m acima do chão) ou, sem nenhum dos dois, a
-- esfera do ox_target com o raio de alcance da etapa.
Placement = { active = false }

local resolve
local ghost = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }
local mode = 'point'
local label = 'Ponto'
local colour = { 25, 229, 140 }
local radius = 10.0

local PED_LIFT = 1.0
local PED_STAGES = { hostage = true, guard = true }

local function loadModel(name, wantPed)
    if type(name) ~= 'string' or name == '' then return nil end
    local model = joaat(name)
    -- No Enhanced, modelo que não existe no build derruba o cliente: confere antes de pedir.
    -- Teste por verdade, como no noir_garage: o retorno desses natives não é sempre booleano.
    local inImage = IsModelInCdimage(model)
    local isPed = IsModelAPed(model)
    local kindOk = wantPed and isPed or (not wantPed and not isPed)
    if not inImage or not kindOk then
        lib.notify({ description = ('Modelo inexistente: %s'):format(name), type = 'error' })
        print(('[XS-Robberies:posicionar] %s recusado: cdimage=%s ped=%s (esperado ped=%s)')
            :format(name, tostring(inImage), tostring(isPed), tostring(wantPed)))
        return nil
    end
    if not pcall(lib.requestModel, model, 5000) then return nil end
    return model
end

---Monta o fantasma da etapa: { kind = 'ped'|'prop'|'sphere', entity?, lift, propZ, reach }.
local function buildPreview(opts)
    local stageType = opts.stageType
    local stageOpts = {}
    if stageType and Stages.types[stageType] then
        for k, v in pairs(Stages.Defaults(stageType)) do stageOpts[k] = v end
    end
    for k, v in pairs(opts.stageOpts or {}) do stageOpts[k] = v end

    local preview = { kind = 'sphere', lift = 0.0, propZ = 0.0, reach = tonumber(stageOpts.reach) or 1.5,
        worldModel = stageOpts.worldModel ~= '' and stageOpts.worldModel or nil }

    if PED_STAGES[stageType] then
        local fallback = stageType == 'guard' and 's_m_m_security_01' or 'mp_m_shopkeep_01'
        local name = (stageOpts.ped and stageOpts.ped ~= '') and stageOpts.ped or fallback
        local model = loadModel(name, true)
        if model then
            local ped = CreatePed(4, model, ghost.x, ghost.y, ghost.z - PED_LIFT, ghost.h, false, false)
            SetModelAsNoLongerNeeded(model)
            if ped ~= 0 then
                SetEntityInvincible(ped, true)
                SetEntityCollision(ped, false, false)
                FreezeEntityPosition(ped, true)
                SetEntityAlpha(ped, 200, false)
                SetBlockingOfNonTemporaryEvents(ped, true)
                preview.kind, preview.entity, preview.lift = 'ped', ped, PED_LIFT
            end
        end
    elseif stageOpts.prop and stageOpts.prop ~= '' then
        local model = loadModel(stageOpts.prop, false)
        if model then
            local propZ = tonumber(stageOpts.propZ) or 0.0
            local object = CreateObject(model, ghost.x, ghost.y, ghost.z + propZ, false, false, false)
            SetModelAsNoLongerNeeded(model)
            if object ~= 0 then
                SetEntityCollision(object, false, false)
                FreezeEntityPosition(object, true)
                SetEntityAlpha(object, 200, false)
                preview.kind, preview.entity, preview.propZ = 'prop', object, propZ
            end
        end
    end

    return preview
end

local function deletePreview(preview)
    local entity = preview and preview.entity
    if not entity or not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    if preview.kind == 'ped' then DeletePed(entity) else DeleteObject(entity) end
end

local function drawPreview(preview)
    local r, g, b = colour[1], colour[2], colour[3]

    if mode == 'zone' then
        DrawMarker(1, ghost.x, ghost.y, ghost.z - 1.0, 0, 0, 0, 0, 0, 0,
            radius * 2, radius * 2, 2.0, r, g, b, 70, false, false, 2, false, nil, nil, false)
        DrawMarker(28, ghost.x, ghost.y, ghost.z + 0.15, 0, 0, 0, 0, 0, 0,
            0.18, 0.18, 0.18, r, g, b, 210, false, false, 2, false, nil, nil, false)
        return
    end

    if preview.kind == 'ped' then
        SetEntityCoordsNoOffset(preview.entity, ghost.x, ghost.y, ghost.z - preview.lift, false, false, false)
        SetEntityHeading(preview.entity, ghost.h)
    elseif preview.kind == 'prop' then
        SetEntityCoordsNoOffset(preview.entity, ghost.x, ghost.y, ghost.z + preview.propZ, false, false, false)
        SetEntityHeading(preview.entity, ghost.h)
        PlaceObjectOnGroundProperly(preview.entity)
    elseif preview.worldModel and WorldObjects.Find(ghost, preview.worldModel) then
        -- Objeto do mapa achado: a seta em cima dele é o alvo que vai valer em jogo.
        local object = WorldObjects.Find(ghost, preview.worldModel)
        local at = GetEntityCoords(object)
        local _, top = GetModelDimensions(GetEntityModel(object))
        DrawMarker(2, at.x, at.y, at.z + top.z + 0.35, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.25, 0.25, 0.25,
            60, 220, 120, 230, true, false, 2, false, nil, nil, false)
        DrawMarker(28, ghost.x, ghost.y, ghost.z, 0, 0, 0, 0, 0, 0,
            0.05, 0.05, 0.05, r, g, b, 230, false, false, 2, false, nil, nil, false)
    else
        -- A zona do ox_target: esfera com o alcance da etapa, centrada no ponto.
        DrawMarker(28, ghost.x, ghost.y, ghost.z, 0, 0, 0, 0, 0, 0,
            preview.reach, preview.reach, preview.reach, r, g, b, 90, false, false, 2, false, nil, nil, false)
        DrawMarker(28, ghost.x, ghost.y, ghost.z, 0, 0, 0, 0, 0, 0,
            0.05, 0.05, 0.05, r, g, b, 230, false, false, 2, false, nil, nil, false)
    end

    -- Para onde a etapa olha.
    local hx = ghost.x + math.sin(math.rad(-ghost.h)) * 0.8
    local hy = ghost.y + math.cos(math.rad(-ghost.h)) * 0.8
    DrawLine(ghost.x, ghost.y, ghost.z, hx, hy, ghost.z, r, g, b, 255)
end

-- Chão logo abaixo do ponto, inclusive dentro de interior (GetGroundZFor_3dCoord não vê
-- piso de interior). Procura de 1 m acima até 5 m abaixo da base.
local function floorUnder(x, y, z)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(x, y, z + 1.0, x, y, z - 5.0, 1 | 16, PlayerPedId(), 4)
    local _, hit, coords = GetShapeTestResult(ray)
    if hit == 1 then return coords.z end
    return nil
end

local function finish(result)
    if not Placement.active then return end
    Placement.active = false

    local done = resolve
    resolve = nil
    if done then done(result) end
end

function Placement.Abort()
    if Placement.active then finish(nil) end
end

---@param opts { label?: string, colour?: number[], mode?: 'point'|'zone', radius?: number, origin?: table, stageType?: string, stageOpts?: table }
function Placement.Start(opts)
    if Placement.active then return nil end

    opts = opts or {}
    mode = opts.mode or 'point'
    label = opts.label or 'Ponto'
    colour = opts.colour or { 25, 229, 140 }
    radius = opts.radius or 10.0

    local ped = PlayerPedId()
    local start = opts.origin or GetEntityCoords(ped) + GetEntityForwardVector(ped) * 1.5
    ghost = { x = start.x, y = start.y, z = start.z, h = (opts.origin and opts.origin.h) or GetEntityHeading(ped) }

    local preview = mode == 'zone' and { kind = 'zone', lift = 0.0 } or buildPreview(opts)

    -- Fixado, o ponto para de seguir a mira e só as setas/PgUp/PgDn o movem. Ajustando um
    -- ponto que já existe, começa fixado nele; E alterna entre fixado e mira.
    local pinned = opts.origin ~= nil
    local aimed = nil       -- entidade sob a mira, para o G
    local captured = false  -- G pegou um objeto do mapa nesta sessão

    Placement.active = true

    local p = promise.new()
    resolve = function(value) p:resolve(value) end

    -- Mira em thread própria: o raycast do ox_lib espera um frame, e o laço abaixo lê as
    -- teclas em todo frame para não perder o Enter nem a roda.
    CreateThread(function()
        while Placement.active do
            local hit, entity, coords = lib.raycast.fromCamera(1 | 16, 4, Config.Builder.PlacementRange)
            aimed = hit and entity or nil
            if hit and Placement.active and not pinned then
                ghost.x, ghost.y, ghost.z = coords.x, coords.y, coords.z + preview.lift
            end
        end
    end)

    local function showHelp()
        lib.showTextUI(('%s  \n[Mira] mover%s  \n[Setas] frente/trás/lados  \n[PgUp/PgDn] subir/descer (Ctrl: fino)  \n[Espaço] grudar no chão%s  \n[E] %s  \n[Roda do mouse] %s (Shift: rápido)  \n[Enter] confirmar  \n[Backspace] cancelar')
            :format(label, pinned and ' (fixado)' or '',
                preview.kind == 'sphere' and ('  \n[G] usar o objeto mirado%s'):format(preview.worldModel and ' (objeto definido)' or '') or '',
                pinned and 'voltar a seguir a mira' or 'fixar',
                mode == 'zone' and 'raio' or 'girar'), { position = 'left-center' })
    end
    showHelp()

    CreateThread(function()
        while Placement.active do
            DisableControlAction(0, 14, true)  -- roda: arma seguinte
            DisableControlAction(0, 15, true)  -- roda: arma anterior
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 24, true)  -- ataque
            DisableControlAction(0, 25, true)  -- mirar
            DisableControlAction(0, 177, true) -- Backspace não abre o menu de pausa
            DisableControlAction(0, 10, true)  -- PgUp
            DisableControlAction(0, 11, true)  -- PgDn
            DisableControlAction(0, 36, true)  -- Ctrl: agachar
            DisableControlAction(0, 38, true)  -- E
            DisableControlAction(0, 22, true)  -- Espaço: pular
            DisableControlAction(0, 47, true)  -- G
            DisableControlAction(0, 172, true) -- setas: celular e menus
            DisableControlAction(0, 173, true)
            DisableControlAction(0, 174, true)
            DisableControlAction(0, 175, true)
            DisablePlayerFiring(PlayerId(), true)

            if IsDisabledControlJustPressed(0, 38) then
                pinned = not pinned
                showHelp()
            end

            -- G: o objeto do mapa sob a mira vira o alvo da etapa, e o ponto vai para ele.
            if preview.kind == 'sphere' and IsDisabledControlJustPressed(0, 47) then
                local object = aimed
                if object and object ~= 0 and DoesEntityExist(object) and GetEntityType(object) == 3 then
                    local at = GetEntityCoords(object)
                    preview.worldModel = tostring(GetEntityModel(object))
                    captured = true
                    ghost.x, ghost.y, ghost.z = at.x, at.y, at.z
                    pinned = true
                    showHelp()
                else
                    lib.notify({ description = 'Mire num objeto do mapa.', type = 'error' })
                end
            end

            -- Espaço: assenta no chão logo abaixo. Ped fica com o pé no piso (ponto 1 m
            -- acima, porque o spawn usa z - 1); prop e esfera ficam no piso.
            if IsDisabledControlJustPressed(0, 22) then
                local floor = floorUnder(ghost.x, ghost.y, ghost.z - preview.lift)
                if floor then
                    ghost.z = floor + preview.lift
                    if not pinned then pinned = true showHelp() end
                end
            end

            -- Setas andam no chão em relação a para onde a câmera olha; PgUp/PgDn na altura.
            -- Metros por segundo, então segurar a tecla desliza de leve.
            local speed = (IsDisabledControlPressed(0, 36) and 0.1 or 0.5) * GetFrameTime()
            local yaw = math.rad(GetFinalRenderedCamRot(2).z)
            local fx, fy = -math.sin(yaw), math.cos(yaw)
            local dx, dy, dz = 0.0, 0.0, 0.0
            if IsDisabledControlPressed(0, 172) then dx, dy = dx + fx, dy + fy end
            if IsDisabledControlPressed(0, 173) then dx, dy = dx - fx, dy - fy end
            if IsDisabledControlPressed(0, 175) then dx, dy = dx + fy, dy - fx end
            if IsDisabledControlPressed(0, 174) then dx, dy = dx - fy, dy + fx end
            if IsDisabledControlPressed(0, 10) then dz = dz + 1.0 end
            if IsDisabledControlPressed(0, 11) then dz = dz - 1.0 end
            if dx ~= 0.0 or dy ~= 0.0 or dz ~= 0.0 then
                if not pinned then pinned = true showHelp() end
                ghost.x = ghost.x + dx * speed
                ghost.y = ghost.y + dy * speed
                ghost.z = ghost.z + dz * speed
            end

            local fast = IsControlPressed(0, 21) -- Shift
            local up = IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17)
            local down = IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16)
            if mode == 'zone' then
                local step = fast and 5.0 or 1.0
                if up then radius = math.min(300.0, radius + step) end
                if down then radius = math.max(1.0, radius - step) end
            else
                local step = fast and 15.0 or 5.0
                if up then ghost.h = (ghost.h + step) % 360 end
                if down then ghost.h = (ghost.h - step) % 360 end
            end

            drawPreview(preview)
            Markers.DrawEditorPoints(ghost)

            if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then -- Enter
                finish({
                    x = math.floor(ghost.x * 1000 + 0.5) / 1000,
                    y = math.floor(ghost.y * 1000 + 0.5) / 1000,
                    z = math.floor(ghost.z * 1000 + 0.5) / 1000,
                    h = math.floor(ghost.h * 10 + 0.5) / 10,
                    radius = mode == 'zone' and (math.floor(radius * 10 + 0.5) / 10) or nil,
                    worldModel = captured and preview.worldModel or nil,
                })
            elseif IsDisabledControlJustReleased(0, 177) then -- Backspace
                finish(nil)
            end

            Wait(0)
        end

        lib.hideTextUI()
        deletePreview(preview)
    end)

    return Citizen.Await(p)
end
