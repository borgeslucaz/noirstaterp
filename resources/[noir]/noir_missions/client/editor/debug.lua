---Debug do editor: desenha no mundo zonas, pontos de NPC, veículos, carga, interações, rotas
---de reforço, pontos de perseguição e entregas da missão aberta, e mostra o estado da
---instância em execução (passo, variáveis, grupos, carga). Só para admin; o servidor confere
---a ACE antes de mandar qualquer coisa.
local Integrations = require 'client.integrations'

local Debug = {}

local drawables = {}
local instanceInfo = nil
local drawing = false
local instanceOverlay = false

local COLORS = {
    zone = { 110, 159, 189 }, step = { 242, 242, 242 }, ped = { 239, 41, 41 }, vehicle = { 215, 168, 75 },
    cargo = { 57, 223, 69 }, interaction = { 110, 159, 189 }, route = { 215, 168, 75 },
    chase = { 239, 41, 41 }, delivery = { 57, 223, 69 },
}

local function add(kind, coords, label, radius, to)
    if not coords then return end
    drawables[#drawables + 1] = {
        kind = kind, coords = vector3(coords.x, coords.y, coords.z), label = label, radius = radius,
        to = to and vector3(to.x, to.y, to.z) or nil,
    }
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
                if distance < 250.0 then
                    local color = COLORS[item.kind]
                    if item.radius and item.radius <= 120 then
                        DrawMarker(1, item.coords.x, item.coords.y, item.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            item.radius * 2.0, item.radius * 2.0, 1.5, color[1], color[2], color[3], 50, false, false, 2, false, nil, nil, false)
                    end
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
function Debug.setMission(enabled, missionId)
    drawables = {}
    if not enabled or not missionId then return end
    local result = lib.callback.await('noir_missions:server:editorDraft', false, missionId)
    if not result or not result.ok then return end
    build(result.definition)
    ensureLoop()
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
    instanceOverlay = false
    instanceInfo = nil
end

return Debug
