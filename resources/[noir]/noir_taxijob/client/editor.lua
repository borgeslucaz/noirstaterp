---Editor in-game (/editortaxi). A NUI monta o rascunho; aqui ficam os modos que mexem no mundo
---(marcar um ponto de coleta/destino onde o admin está, posicionar o atendente e as vagas da
---Central, ir até um ponto, copiar o visual do carro atual) e o desenho dos pontos por perto.
---O servidor valida tudo o que for salvo.
---
---Sem gizmo: no Enhanced o object_gizmo desenha as alças mas não pega o clique (DESIGN v4 §ML.7).

local editor = { open = false, busy = false, catalog = nil, draft = nil, showWorld = true, showAlways = false }
local DRAW_DISTANCE = 250.0

local SERVER_METHODS = {
    data = true, savePoint = true, deletePoint = true, saveVehicle = true, deleteVehicle = true,
    moveVehicle = true, saveLevels = true, saveDepot = true, saveSettings = true,
}

-- Cor de cada região no mundo e no mapa (mesma ordem de Catalog.REGIONS).
local REGION_COLOR = {
    ['downtown'] = { 242, 196, 43 },
    ['sandy shores'] = { 215, 140, 60 },
    ['paleto bay'] = { 110, 159, 189 },
}

local function send(data)
    UI.send('editor', data)
end

local function close()
    if not editor.open then return end
    editor.open, editor.busy, editor.draft = false, false, nil
    Integrations.hideKeys()
    send({ visible = false })
    SetNuiFocus(false, false)
end

---A tela some enquanto o admin anda ou mira; volta com o resultado.
local function hideForMode()
    editor.busy = true
    send({ hidden = true })
    SetNuiFocus(false, false)
end

local function showAfterMode(result)
    Integrations.hideKeys()
    editor.busy = false
    if not editor.open then return end
    send({ hidden = false, result = result })
    SetNuiFocus(true, true)
end

-- Desenho no mundo ------------------------------------------------------------------------

---Ponto de coleta/destino: cilindro no chão e seta no sentido em que o passageiro espera.
local function drawPoint(p, r, g, b, alpha)
    DrawMarker(1, p.x, p.y, p.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.4, 1.4, 0.5, r, g, b, alpha or 120, false, false, 2, false, nil, nil, false)
    local angle = math.rad(p.w or 0.0)
    local ax, ay = p.x - math.sin(angle) * 2.0, p.y + math.cos(angle) * 2.0
    DrawLine(p.x, p.y, p.z - 0.5, ax, ay, p.z - 0.5, r, g, b, 255)
end

local function drawNearby()
    local coords = GetEntityCoords(cache.ped)
    local catalog = editor.catalog
    local draft = editor.open and editor.draft or nil
    if editor.showWorld and catalog then
        for _, p in ipairs(catalog.points or {}) do
            if not (draft and draft.kind == 'point' and draft.id == p.id) and #(coords - vec3(p.x, p.y, p.z)) <= DRAW_DISTANCE then
                local c = p.enabled and (REGION_COLOR[p.region] or { 200, 200, 200 }) or { 120, 120, 120 }
                drawPoint(p, c[1], c[2], c[3], p.enabled and 140 or 60)
            end
        end
        local depot = catalog.depot
        if depot and #(coords - vec3(depot.ped.x, depot.ped.y, depot.ped.z)) <= DRAW_DISTANCE then
            drawPoint(depot.ped, 57, 223, 69)
            for _, s in ipairs(depot.spawnPoints or {}) do drawPoint(s, 110, 159, 189) end
        end
    end
    if draft and draft.value then drawPoint(draft.value, 57, 223, 69, 200) end
end

CreateThread(function()
    while true do
        if (editor.open and not editor.busy) or (not editor.open and editor.showAlways and editor.showWorld and editor.catalog) then
            drawNearby()
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Modos -----------------------------------------------------------------------------------

---Ponto de coleta/destino: o admin fica onde o passageiro vai esperar (a pé, virado para a
---rua, ou com o carro parado na guia) e aperta E.
local function capturePoint()
    hideForMode()
    Integrations.showKeys({
        { key = 'E', label = 'Marcar aqui' },
        { key = 'Backspace', label = 'Cancelar' },
    })
    local result = nil
    while editor.open do
        drawNearby()
        DisableControlAction(0, 177, true)
        if IsControlJustReleased(0, 38) then
            local entity = cache.vehicle or cache.ped
            local c = GetEntityCoords(entity)
            result = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(entity) }
            break
        end
        if IsDisabledControlJustReleased(0, 177) then break end
        Wait(0)
    end
    showAfterMode(result and { kind = 'point', value = result } or { kind = 'cancel' })
end

local function placeEntity(kind, model, current, resultKind)
    hideForMode()
    local point = Placement.run(kind, model, current)
    showAfterMode(point and { kind = resultKind, value = point } or { kind = 'cancel' })
end

-- NUI -------------------------------------------------------------------------------------

local function open()
    if editor.open then return end
    if not Taxi.is(TAXI_STATE.HIDDEN) then
        Integrations.notify('Desligue o taxímetro antes de abrir o editor.', 'error')
        return
    end
    local response = lib.callback.await('noir_taxijob:server:editor:data', false)
    if not response or not response.ok then
        Integrations.notify('Não foi possível abrir o editor do táxi.', 'error')
        return
    end
    editor.open, editor.catalog = true, response.catalog
    send({ visible = true, catalog = response.catalog, show = { world = editor.showWorld, always = editor.showAlways } })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end

RegisterNetEvent('noir_taxijob:client:openEditor', function()
    if source ~= 65535 then return end
    open()
end)

RegisterNUICallback('editor:close', function(_, cb)
    cb({ ok = true })
    close()
end)

---Chamada ao servidor por nome, com lista fechada de métodos.
RegisterNUICallback('editor:request', function(data, cb)
    if not editor.open or type(data) ~= 'table' or not SERVER_METHODS[data.method] then
        return cb({ ok = false, code = 'invalid_payload' })
    end
    local args = type(data.args) == 'table' and data.args or {}
    local response = lib.callback.await('noir_taxijob:server:editor:' .. data.method, false, table.unpack(args, 1, 3))
    if response and response.ok and response.catalog then editor.catalog = response.catalog end
    cb(response or { ok = false, code = 'internal_error' })
end)

---Rascunho aberto na tela (o ponto em edição), para desenhar no mundo.
RegisterNUICallback('editor:draft', function(data, cb)
    cb({ ok = true })
    editor.draft = type(data) == 'table' and data.value and data or nil
end)

RegisterNUICallback('editor:mode', function(data, cb)
    if not editor.open or editor.busy or type(data) ~= 'table' then return cb({ ok = false, code = 'busy' }) end
    cb({ ok = true })
    if data.mode == 'point' then
        CreateThread(capturePoint)
    elseif data.mode == 'depotPed' and type(data.model) == 'string' then
        CreateThread(function() placeEntity('ped', data.model, data.current, 'depotPed') end)
    elseif data.mode == 'depotSpawn' and type(data.model) == 'string' then
        CreateThread(function() placeEntity('vehicle', data.model, data.current, 'depotSpawn') end)
    else
        showAfterMode({ kind = 'cancel' })
    end
end)

RegisterNUICallback('editor:position', function(_, cb)
    local entity = cache.vehicle or cache.ped
    local c = GetEntityCoords(entity)
    cb({ x = c.x, y = c.y, z = c.z, w = GetEntityHeading(entity) })
end)

RegisterNUICallback('editor:teleport', function(data, cb)
    if not editor.open or type(data) ~= 'table' then return cb({ ok = false }) end
    local response = lib.callback.await('noir_taxijob:server:editor:teleport', false, data.kind, data.id, data.point)
    if not response or not response.ok then return cb(response or { ok = false }) end
    local point = response.point
    local entity = cache.vehicle or cache.ped
    SetEntityCoords(entity, point.x, point.y, point.z, false, false, false, false)
    SetEntityHeading(entity, point.w or 0.0)
    cb({ ok = true })
end)

RegisterNUICallback('editor:show', function(data, cb)
    if type(data) == 'table' then
        if data.world ~= nil then editor.showWorld = data.world == true end
        if data.always ~= nil then editor.showAlways = data.always == true end
    end
    cb({ ok = true, world = editor.showWorld, always = editor.showAlways })
end)

---Modelo existe no build? (Modelo ausente derruba o cliente no Enhanced.)
RegisterNUICallback('editor:checkModel', function(data, cb)
    if type(data) ~= 'table' or type(data.model) ~= 'string' or #data.model > 32 then return cb({ ok = false }) end
    local hash = joaat(data.model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return cb({ ok = false, code = 'invalid_model' }) end
    cb({ ok = true, seats = math.max(0, GetVehicleModelNumberOfSeats(hash) - 1) })
end)

-- Fora do visual copiado: placa, estado e desempenho (o carro do emprego não fica mais forte
-- por ter passado na oficina).
local NOT_VISUAL = { 'model', 'plate', 'plateIndex', 'lockState', 'bodyHealth', 'engineHealth', 'tankHealth',
    'fuelLevel', 'oilLevel', 'dirtLevel', 'windows', 'doors', 'tyres', 'bulletProofTyres', 'driftTyres',
    'modEngine', 'modBrakes', 'modTransmission', 'modSuspension', 'modArmor', 'modNitrous', 'modTurbo' }

---Visual do carro em que o admin está (montado no qbx_customs), para o `appearance.props` do
---carro do catálogo. Só serve se for o mesmo modelo.
RegisterNUICallback('editor:copyVisual', function(data, cb)
    local veh = cache.vehicle
    if not editor.open or not veh then return cb({ ok = false, code = 'not_in_vehicle' }) end
    if type(data) == 'table' and type(data.model) == 'string' and GetEntityModel(veh) ~= joaat(data.model) then
        return cb({ ok = false, code = 'other_model' })
    end
    local ok, props = pcall(lib.getVehicleProperties, veh)
    if not ok or type(props) ~= 'table' then return cb({ ok = false, code = 'read_failed' }) end
    for _, key in ipairs(NOT_VISUAL) do props[key] = nil end
    -- Mod em -1 é "de fábrica": não precisa ir para o catálogo.
    for key, value in pairs(props) do
        if type(key) == 'string' and key:sub(1, 3) == 'mod' and value == -1 then props[key] = nil end
    end
    cb({ ok = true, props = props })
end)

-- Mapa de debug ---------------------------------------------------------------------------

local mapOpen = false

RegisterNUICallback('editor:openMap', function(_, cb)
    if not editor.open or mapOpen then return cb({ ok = false }) end
    local map = Integrations.territoryMap()
    if not map then return cb({ ok = false, code = 'map_unavailable' }) end
    local coords = GetEntityCoords(cache.ped)
    mapOpen = true
    UI.send('taxiMap', { visible = true, catalog = editor.catalog, map = map, player = { x = coords.x, y = coords.y } })
    cb({ ok = true })
end)

RegisterNUICallback('map:close', function(_, cb)
    cb({ ok = true })
    if not mapOpen then return end
    mapOpen = false
    UI.send('taxiMap', { visible = false })
end)

AddEventHandler('bgrz_core:client:playerUnloaded', close)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then close() end
end)
