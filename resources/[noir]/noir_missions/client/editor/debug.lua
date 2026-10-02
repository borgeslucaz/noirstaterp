---Debug do editor: desenha no mundo zonas, pontos de NPC, veículos, carga, interações, rotas
---de reforço, pontos de perseguição e entregas da missão aberta, e mostra o estado da
---instância em execução (passo, variáveis, grupos, carga). Só para admin; o servidor confere
---a ACE antes de mandar qualquer coisa.
local Integrations = require 'client.integrations'

local Debug = {}

local drawables = {}
local mapBlips = {}
local instanceInfo = nil
local drawing = false
local instanceOverlay = false

local COLORS = {
    zone = { 110, 159, 189 }, step = { 242, 242, 242 }, ped = { 239, 41, 41 }, vehicle = { 215, 168, 75 },
    cargo = { 57, 223, 69 }, interaction = { 110, 159, 189 }, route = { 215, 168, 75 },
    chase = { 239, 41, 41 }, delivery = { 57, 223, 69 },
}

---Contorno do círculo: pontos em volta do centro. A altura do chão de cada ponto é lida
---quando o ponto chega perto (longe, o terreno ainda não carregou).
---@param center vector3
---@param radius number
---@return table[]
local function ring(center, radius)
    local count = math.max(24, math.min(120, math.floor(radius / 3)))
    local points = {}
    for index = 0, count - 1 do
        local angle = (index / count) * math.pi * 2
        points[#points + 1] = { x = center.x + math.cos(angle) * radius, y = center.y + math.sin(angle) * radius }
    end
    return points
end

local function add(kind, coords, label, radius, to)
    if not coords then return end
    local center = vector3(coords.x, coords.y, coords.z)
    drawables[#drawables + 1] = {
        kind = kind, coords = center, label = label, radius = radius,
        to = to and vector3(to.x, to.y, to.z) or nil,
        ring = radius and radius > 0 and ring(center, radius) or nil,
    }
end

---@param point table
---@param fallback number
---@return number
local function groundZ(point, fallback)
    if point.z then return point.z end
    -- Sonda logo acima do centro, não do céu: dentro de um galpão, vinda de cima ela acha o
    -- telhado e o contorno ficava lá em cima, invisível de dentro.
    local found, z = GetGroundZFor_3dCoord(point.x, point.y, fallback + 4.0, false)
    if found and math.abs(z - fallback) < 15.0 then point.z = z end
    return point.z or fallback
end

local WALL_HEIGHT = 3.0
local RING_DRAW_DISTANCE = 400.0

---Parede translúcida de 3 m no contorno inteiro, com borda forte em cima e embaixo: mostra
---até onde a área vai, de dentro e de fora, em qualquer tamanho.
local function drawRing(item, origin, color)
    local points = item.ring
    local count = #points
    local limit = RING_DRAW_DISTANCE * RING_DRAW_DISTANCE
    local r, g, b = color[1], color[2], color[3]
    for index = 1, count do
        local a, c = points[index], points[index % count + 1]
        local dx, dy = a.x - origin.x, a.y - origin.y
        if dx * dx + dy * dy < limit then
            local az, cz = groundZ(a, item.coords.z), groundZ(c, item.coords.z)
            local at, ct = az + WALL_HEIGHT, cz + WALL_HEIGHT
            -- Os dois sentidos: polígono só aparece de um lado.
            DrawPoly(a.x, a.y, az, c.x, c.y, cz, c.x, c.y, ct, r, g, b, 45)
            DrawPoly(a.x, a.y, az, c.x, c.y, ct, a.x, a.y, at, r, g, b, 45)
            DrawPoly(c.x, c.y, ct, c.x, c.y, cz, a.x, a.y, az, r, g, b, 45)
            DrawPoly(a.x, a.y, at, c.x, c.y, ct, a.x, a.y, az, r, g, b, 45)
            DrawLine(a.x, a.y, az + 0.05, c.x, c.y, cz + 0.05, r, g, b, 255)
            DrawLine(a.x, a.y, at, c.x, c.y, ct, r, g, b, 255)
        end
    end
end

local function clearMapBlips()
    for index = 1, #mapBlips do
        if DoesBlipExist(mapBlips[index]) then RemoveBlip(mapBlips[index]) end
    end
    mapBlips = {}
end

---Toda área com raio também no mapa, para ver o tamanho de longe.
local BLIP_COLORS = { zone = 3, step = 0, delivery = 2, route = 5 }
local function buildMapBlips()
    clearMapBlips()
    for index = 1, #drawables do
        local item = drawables[index]
        if item.radius and item.radius > 0 then
            local blip = AddBlipForRadius(item.coords.x, item.coords.y, item.coords.z, item.radius + 0.0)
            SetBlipColour(blip, BLIP_COLORS[item.kind] or 0)
            SetBlipAlpha(blip, 90)
            mapBlips[#mapBlips + 1] = blip
        end
    end
end

---@param def table
local function build(def)
    drawables = {}
    for _, zone in ipairs(def.zones or {}) do add('zone', zone.coords, 'Zona: ' .. (zone.label or zone.id), zone.radius) end
    for index, step in ipairs(def.steps or {}) do
        if step.coords then add('step', step.coords, ('%02d %s'):format(index, step.label or step.id), step.radius) end
    end
    for _, group in ipairs(def.pedGroups or {}) do
        for index, ped in ipairs(group.peds or {}) do
            add('ped', ped.coords, ('%s #%d'):format(group.label or group.id, index))
        end
    end
    for _, vehicle in ipairs(def.vehicles or {}) do add('vehicle', vehicle.coords, vehicle.label or vehicle.id) end
    for _, cargo in ipairs(def.cargo or {}) do
        for index, piece in ipairs(cargo.pieces or {}) do add('cargo', piece, ('%s #%d'):format(cargo.label or cargo.id, index)) end
    end
    for _, interaction in ipairs(def.interactions or {}) do add('interaction', interaction.coords, interaction.label) end
    for _, run in ipairs(def.reinforcements or {}) do
        local previous = run.spawn
        add('route', run.spawn, 'Reforço: ' .. (run.label or run.id))
        for _, point in ipairs(run.route or {}) do
            add('route', point, nil, nil, previous)
            previous = point
        end
        add('route', run.destination, 'Destino do reforço', run.arrivalDistance, previous)
    end
    for _, convoy in ipairs(def.convoys or {}) do
        local previous
        for index, point in ipairs(convoy.route or {}) do
            add('route', point, ('Comboio %s #%d'):format(convoy.label or convoy.id, index), nil, previous)
            previous = point
        end
    end
    for _, chase in ipairs(def.chases or {}) do
        for index, point in ipairs(chase.spawnPoints or {}) do add('chase', point, ('Perseguição %s #%d'):format(chase.label or chase.id, index)) end
    end
    for _, group in ipairs(def.deliveryGroups or {}) do
        for _, point in ipairs(group.points or {}) do add('delivery', point.coords, 'Entrega: ' .. point.label, point.radius) end
    end
end

local function text3d(coords, text)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.3, 0.3)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function overlay()
    if not instanceInfo then return end
    local lines = {
        ('Instância #%s  %s%s'):format(instanceInfo.instanceId, instanceInfo.missionId, instanceInfo.test and ' (teste)' or ''),
        ('Passo: %s  (%ss)'):format(tostring(instanceInfo.step), tostring(instanceInfo.elapsed)),
    }
    for name, value in pairs(instanceInfo.vars or {}) do lines[#lines + 1] = ('%s = %s'):format(name, tostring(value)) end
    for _, key in ipairs({ 'groups', 'cargo', 'vehicles', 'reinforcements', 'chases' }) do
        for _, line in ipairs(instanceInfo[key] or {}) do lines[#lines + 1] = line end
    end
    for index, line in ipairs(lines) do
        SetTextScale(0.28, 0.28)
        SetTextFont(4)
        SetTextOutline()
        SetTextColour(255, 255, 255, 220)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(line)
        EndTextCommandDisplayText(0.015, 0.30 + (index - 1) * 0.019)
    end
end

local function ensureLoop()
    if drawing then return end
    drawing = true
    CreateThread(function()
        while #drawables > 0 or instanceOverlay do
            local origin = GetEntityCoords(cache.ped)
            for index = 1, #drawables do
                local item = drawables[index]
                local distance = #(item.coords - origin)
                if item.ring and distance < item.radius + RING_DRAW_DISTANCE then
                    drawRing(item, origin, COLORS[item.kind])
                end
                if distance < 250.0 then
                    local color = COLORS[item.kind]
                    DrawMarker(28, item.coords.x, item.coords.y, item.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.25, 0.25, 0.25, color[1], color[2], color[3], 200, false, false, 2, false, nil, nil, false)
                    if item.to then
                        DrawLine(item.to.x, item.to.y, item.to.z, item.coords.x, item.coords.y, item.coords.z, color[1], color[2], color[3], 255)
                    end
                    if item.label and distance < 60.0 then text3d(item.coords + vector3(0.0, 0.0, 0.6), item.label) end
                end
            end
            if instanceOverlay then overlay() end
            Wait(0)
        end
        drawing = false
    end)
end

---@param enabled boolean
---@param missionId string?
local debugMission = nil

function Debug.setMission(enabled, missionId)
    debugMission = enabled and missionId or nil
    drawables = {}
    clearMapBlips()
    if not enabled or not missionId then return end
    local result = lib.callback.await('noir_missions:server:editorDraft', false, missionId)
    if not result or not result.ok then return end
    build(result.definition)
    buildMapBlips()
    ensureLoop()
end

---Depois de salvar, redesenha a missão que está sendo mostrada (zona movida aparece no
---lugar novo sem desligar e ligar a opção).
---@param missionId string
function Debug.refresh(missionId)
    if debugMission and debugMission == missionId then Debug.setMission(true, missionId) end
end

function Debug.toggleInstance()
    instanceOverlay = not instanceOverlay
    local result = lib.callback.await('noir_missions:server:debugSubscribe', false, instanceOverlay)
    if not result or not result.ok then
        instanceOverlay = false
        Integrations.notify('Sem permissão.', 'error')
        return
    end
    if not instanceOverlay then instanceInfo = nil end
    Integrations.notify(instanceOverlay and 'Debug de missão ligado.' or 'Debug de missão desligado.', 'inform')
    ensureLoop()
end

RegisterNetEvent('noir_missions:client:debug', function(info)
    if source ~= 65535 then return end
    instanceInfo = info or nil
end)

function Debug.clear()
    drawables = {}
    clearMapBlips()
    instanceOverlay = false
    instanceInfo = nil
end

return Debug
