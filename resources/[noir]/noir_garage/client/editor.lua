---Editor de garagens no jogo (/garagem). A tela monta o rascunho; salvar e apagar sao validados no
---servidor (server/editor.lua), que confere a ACE de novo em cada chamada.

local editorOpen = false

local function closeEditor()
    if not editorOpen then return end
    editorOpen = false
    SendNUIMessage({ action = 'editor', data = { visible = false } })
    SetNuiFocus(false, false)
end

RegisterNetEvent('noir_garage:client:openEditor', function(list, groups)
    if type(list) ~= 'table' then return end
    editorOpen = true
    SendNUIMessage({ action = 'editor', data = { visible = true, garages = list, groups = groups } })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('editor:close', function(_, cb)
    closeEditor()
    cb(1)
end)

RegisterNUICallback('editor:save', function(data, cb)
    if not editorOpen or type(data) ~= 'table' then return cb({ ok = false, error = 'Editor fechado.' }) end
    cb(lib.callback.await('noir_garage:admin:save', false, data.name, data.garage) or { ok = false, error = 'Sem resposta do servidor.' })
end)

RegisterNUICallback('editor:delete', function(data, cb)
    if not editorOpen or type(data) ~= 'table' then return cb({ ok = false, error = 'Editor fechado.' }) end
    cb(lib.callback.await('noir_garage:admin:delete', false, data.name) or { ok = false, error = 'Sem resposta do servidor.' })
end)

RegisterNUICallback('editor:teleport', function(data, cb)
    cb(1)
    local c = type(data) == 'table' and data.coords
    if not editorOpen or type(c) ~= 'table' or type(c.x) ~= 'number' then return end
    local entity = cache.vehicle or cache.ped
    SetEntityCoords(entity, c.x, c.y, c.z, false, false, false, false)
    if type(c.w) == 'number' then SetEntityHeading(entity, c.w) end
end)

---@param points table[] pontos do rascunho, desenhados enquanto se escolhe o lugar
local function drawDraftPoints(points)
    for i = 1, #points do
        local p = points[i]
        if p.coords then
            DrawMarker(1, p.coords.x, p.coords.y, p.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.6, 255, 255, 255, 120, false, false, 2, false, nil, nil, false)
        end
        for _, spot in ipairs(p.spawns or {}) do
            DrawMarker(36, spot.x, spot.y, spot.z + 0.5, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 1.2, 111, 143, 174, 180, false, true, 2, false, nil, nil, false)
        end
        if p.dropPoint then
            DrawMarker(1, p.dropPoint.x, p.dropPoint.y, p.dropPoint.z - 1.0, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 0.5, 242, 0, 48, 90, false, false, 2, false, nil, nil, false)
        end
    end
end

local labels = {
    coords = 'balcão',
    dropPoint = 'ponto de guardar',
}

---Esconde o editor, deixa andar ate o lugar e devolve a posicao (com direcao) ao apertar E.
RegisterNUICallback('editor:capture', function(data, cb)
    if not editorOpen or type(data) ~= 'table' or not labels[data.kind] then return cb(false) end
    local points = type(data.points) == 'table' and data.points or {}

    SendNUIMessage({ action = 'editor', data = { hidden = true } })
    SetNuiFocus(false, false)
    lib.showTextUI(('[E] marcar %s  \n[Backspace] cancelar'):format(labels[data.kind]))

    local result = false
    while editorOpen do
        drawDraftPoints(points)
        DisableControlAction(0, 177, true) -- Backspace nao abre o menu de pausa/voltar
        if IsControlJustReleased(0, 38) then
            local entity = cache.vehicle or cache.ped
            local c = GetEntityCoords(entity)
            result = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(entity) }
            break
        end
        if IsDisabledControlJustReleased(0, 177) then break end
        Wait(0)
    end

    lib.hideTextUI()
    if editorOpen then
        SendNUIMessage({ action = 'editor', data = { hidden = false } })
        SetNuiFocus(true, true)
    end
    cb(result)
end)

---Modo de posicionar (atendente ou vaga de carro), sem gizmo: no Enhanced o object_gizmo desenha as
---alcas mas nao pega o clique. A entidade de teste segue o chao para onde a camera mira, a roda do
---mouse gira (Shift = mais rapido), Enter confirma e Backspace cancela. O resultado volta para a tela
---pela mensagem 'editor' (placement), fora do callback da NUI, como no noir_guncraft.
local function placeLog(fmt, ...)
    print(('[noir_garage:posicionar] ' .. fmt):format(...))
end

---@param request { kind: 'ped'|'vehicle', index: integer, slot?: integer, model: integer, start: table }
local function runPlacement(request)
    SendNUIMessage({ action = 'editor', data = { hidden = true } })
    SetNuiFocus(false, false)
    Wait(250)

    local isPed = request.kind == 'ped'
    local start = request.start
    local model = request.model
    local entity
    -- Altura da origem acima do chao: PED ~1 m (o spawn usa z - 1); carro pelo tamanho do modelo.
    local lift = 1.0
    if isPed then
        entity = CreatePed(4, model, start.x, start.y, start.z - 1.0, start.w or 0.0, false, false)
    else
        local min = GetModelDimensions(model)
        lift = -min.z
        entity = CreateVehicle(model, start.x, start.y, start.z, start.w or 0.0, false, false)
    end
    SetModelAsNoLongerNeeded(model)

    local result = false
    if entity == 0 then
        placeLog('criar a entidade falhou (%s)', request.kind)
    else
        SetEntityInvincible(entity, true)
        SetEntityCollision(entity, false, false)
        FreezeEntityPosition(entity, true)
        SetEntityAlpha(entity, 200, false)
        if isPed then
            SetBlockingOfNonTemporaryEvents(entity, true)
        else
            SetVehicleDoorsLocked(entity, 2)
            SetVehicleEngineOn(entity, false, true, true)
        end

        local position = vec3(start.x, start.y, start.z)
        local heading = start.w or 0.0
        local placing = true

        -- Mira em thread propria: o raycast do ox_lib espera um frame, e o laco abaixo precisa ler as
        -- teclas em todo frame para nao perder o Enter nem a roda do mouse.
        CreateThread(function()
            while placing do
                local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, isPed and 25.0 or 40.0)
                if hit and placing then position = vec3(coords.x, coords.y, coords.z + lift) end
            end
        end)

        lib.showTextUI('[Mira] mover  \n[Roda do mouse] girar (Shift: rápido)  \n[Enter] confirmar  \n[Backspace] cancelar')
        while placing do
            DisableControlAction(0, 14, true)  -- roda: arma seguinte
            DisableControlAction(0, 15, true)  -- roda: arma anterior
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 24, true)  -- ataque
            DisableControlAction(0, 25, true)  -- mirar
            DisableControlAction(0, 177, true) -- Backspace nao abre o menu de pausa
            DisablePlayerFiring(cache.playerId, true)

            local step = IsControlPressed(0, 21) and 15.0 or 5.0 -- Shift
            if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then
                heading = (heading - step) % 360
            elseif IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then
                heading = (heading + step) % 360
            end

            SetEntityCoordsNoOffset(entity, position.x, position.y, position.z, false, false, false)
            SetEntityHeading(entity, heading)

            if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then -- Enter
                local c = GetEntityCoords(entity)
                result = { x = c.x, y = c.y, z = c.z, w = heading }
                placing = false
            elseif IsDisabledControlJustReleased(0, 177) then -- Backspace
                placing = false
            end
            Wait(0)
        end
        lib.hideTextUI()
        placeLog('%s: %s', request.kind, result and ('%.2f, %.2f, %.2f / %.0f°'):format(result.x, result.y, result.z, result.w) or 'cancelado')

        if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
    end

    if editorOpen then
        SendNUIMessage({ action = 'editor', data = {
            hidden = false,
            placement = { kind = request.kind, index = request.index, slot = request.slot, result = result },
        } })
        SetNuiFocus(true, true)
    end
end

---Ponto de partida: o salvo, ou a frente do jogador (virado para ele, no caso do PED).
local function placementStart(data, distance, faceBack)
    if type(data.position) == 'table' and type(data.position.x) == 'number' then return data.position end
    local c = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * distance
    local heading = GetEntityHeading(cache.ped)
    return { x = c.x, y = c.y, z = c.z, w = faceBack and (heading + 180.0) % 360 or heading }
end

---@param name string
---@param isPed boolean
---@return integer? model
local function loadModel(name, isPed)
    local model = type(name) == 'number' and name or joaat(name)
    local exists = IsModelInCdimage(model) and (isPed and IsModelAPed(model) or (not isPed and IsModelAVehicle(model)))
    if not exists then
        lib.notify({ description = ('Modelo inexistente: %s'):format(tostring(name)), type = 'error' })
        return
    end
    if not pcall(lib.requestModel, model, 5000) then return end
    return model
end

RegisterNUICallback('editor:placePed', function(data, cb)
    if not editorOpen or type(data) ~= 'table' or type(data.model) ~= 'string' then return cb(false) end
    local model = loadModel(data.model, true)
    if not model then return cb(false) end
    cb(true)
    local start = placementStart(data, 1.5, true)
    CreateThread(function() runPlacement({ kind = 'ped', index = data.index, model = model, start = start }) end)
end)

---Vaga de saida: o carro de teste e o modelo do carro em que o admin esta, ou um Sultan a pe.
RegisterNUICallback('editor:placeVehicle', function(data, cb)
    if not editorOpen or type(data) ~= 'table' then return cb(false) end
    local model = loadModel(cache.vehicle and GetEntityModel(cache.vehicle) or 'sultan', false)
    if not model then return cb(false) end
    cb(true)
    local start = placementStart(data, 6.0, false)
    CreateThread(function()
        runPlacement({ kind = 'vehicle', index = data.index, slot = data.slot, model = model, start = start })
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not editorOpen then return end
    SetNuiFocus(false, false)
end)
