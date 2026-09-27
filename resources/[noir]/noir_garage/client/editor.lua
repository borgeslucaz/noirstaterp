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

---Posiciona o atendente com o object_gizmo: cria um PED de teste onde ele estaria, abre o gizmo e
---devolve posicao e direcao ao apertar Enter. O modelo e conferido antes (no Enhanced, modelo
---inexistente derruba o cliente).
RegisterNUICallback('editor:gizmoPed', function(data, cb)
    if not editorOpen or type(data) ~= 'table' or type(data.model) ~= 'string' then return cb(false) end
    if GetResourceState('object_gizmo') ~= 'started' then
        lib.notify({ description = 'object_gizmo não está rodando.', type = 'error' })
        return cb(false)
    end

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

    SendNUIMessage({ action = 'editor', data = { hidden = true } })
    SetNuiFocus(false, false)

    local ped = CreatePed(4, model, start.x, start.y, start.z - 1.0, start.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(model)
    local result = false
    if ped ~= 0 then
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        local ok, gizmo = pcall(exports.object_gizmo.useGizmo, exports.object_gizmo, ped)
        if ok and gizmo and DoesEntityExist(ped) then
            local c = GetEntityCoords(ped)
            result = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
        end
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end

    if editorOpen then
        SendNUIMessage({ action = 'editor', data = { hidden = false } })
        SetNuiFocus(true, true)
    end
    cb(result)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not editorOpen then return end
    SetNuiFocus(false, false)
end)
