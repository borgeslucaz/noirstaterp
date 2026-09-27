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
        if p.spawn then
            DrawMarker(36, p.spawn.x, p.spawn.y, p.spawn.z + 0.5, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 1.2, 111, 143, 174, 180, false, true, 2, false, nil, nil, false)
        end
        if p.dropPoint then
            DrawMarker(1, p.dropPoint.x, p.dropPoint.y, p.dropPoint.z - 1.0, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 0.5, 242, 0, 48, 90, false, false, 2, false, nil, nil, false)
        end
    end
end

local labels = {
    coords = 'balcão',
    spawn = 'saída do veículo',
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

---Posiciona o atendente sem gizmo: no Enhanced o object_gizmo desenha as alcas mas nao pega o clique
---(os comandos +gizmoSelect/+gizmoRotation nao surtem efeito). O PED de teste segue o chao para onde a
---camera mira, a roda do mouse gira (Shift = mais rapido), Enter confirma e Backspace cancela.
local function placeLog(fmt, ...)
    print(('[noir_garage:posicionar] ' .. fmt):format(...))
end

---@param index integer ponto do rascunho (so ecoado de volta para a tela)
---@param model integer
---@param start table
local function runPedPlacement(index, model, start)
    SendNUIMessage({ action = 'editor', data = { hidden = true } })
    SetNuiFocus(false, false)
    Wait(250)

    local ped = CreatePed(4, model, start.x, start.y, start.z - 1.0, start.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(model)
    local result = false

    if ped == 0 then
        placeLog('CreatePed falhou')
    else
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityAlpha(ped, 200, false)

        local position = vec3(start.x, start.y, start.z)
        local heading = start.w or 0.0
        local placing = true

        -- Mira em thread propria: o raycast do ox_lib espera um frame, e o laco abaixo precisa ler
        -- as teclas em todo frame para nao perder o Enter nem a roda do mouse.
        CreateThread(function()
            while placing do
                local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, 25.0)
                if hit and placing then position = vec3(coords.x, coords.y, coords.z + 1.0) end
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

            SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false)
            SetEntityHeading(ped, heading)

            if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then -- Enter
                result = { x = position.x, y = position.y, z = position.z, w = heading }
                placing = false
            elseif IsDisabledControlJustReleased(0, 177) then -- Backspace
                placing = false
            end
            Wait(0)
        end
        lib.hideTextUI()
        placeLog('fim: %s', result and ('%.2f, %.2f, %.2f / %.0f°'):format(result.x, result.y, result.z, result.w) or 'cancelado')

        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end

    if editorOpen then
        SendNUIMessage({ action = 'editor', data = { hidden = false, gizmo = { index = index, result = result } } })
        SetNuiFocus(true, true)
    end
end

RegisterNUICallback('editor:placePed', function(data, cb)
    if not editorOpen or type(data) ~= 'table' or type(data.model) ~= 'string' then return cb(false) end
    local model = joaat(data.model)
    if not IsModelInCdimage(model) or not IsModelAPed(model) then
        lib.notify({ description = ('Modelo inexistente: %s'):format(data.model), type = 'error' })
        return cb(false)
    end
    if not pcall(lib.requestModel, model, 5000) then return cb(false) end

    local start = type(data.position) == 'table' and data.position or nil
    if not start then
        local c = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 1.5
        start = { x = c.x, y = c.y, z = c.z, w = (GetEntityHeading(cache.ped) + 180.0) % 360 }
    end

    cb(true)
    CreateThread(function() runPedPlacement(data.index, model, start) end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not editorOpen then return end
    SetNuiFocus(false, false)
end)
