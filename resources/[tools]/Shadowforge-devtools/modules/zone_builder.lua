-- modules/zone_builder.lua
-- Build & preview box/sphere/poly zones, then export to ox_target / ox_lib / qb-target / JSON.

SFD = SFD or {}
SFD.ZoneBuilder = {}

local function R(n) return SFD.Round(n, 2) end
local function dangerous() return SFD.HasPermission('dangerous') end

-- ───────────────────────────────────────────────
-- BOX ZONE
-- ───────────────────────────────────────────────
local box = {
    coords = nil, size = vec3(2.0, 2.0, 2.0), heading = 0.0, debug = true,
    drawing = false,
}

local function drawBoxLoop()
    if box.drawing then return end
    box.drawing = true
    CreateThread(function()
        local c = Config.Zones.debugColor
        while box.drawing and box.coords do
            DrawMarker(28, box.coords.x, box.coords.y, box.coords.z,
                0, 0, 0, 0, 0, box.heading,
                box.size.x, box.size.y, box.size.z,
                c.r, c.g, c.b, c.a,
                false, false, 2, false, nil, nil, false)
            Wait(0)
        end
        box.drawing = false
    end)
end

local function boxSnippetTarget()
    return ([[
exports.ox_target:addBoxZone({
    coords   = vec3(%s, %s, %s),
    size     = vec3(%s, %s, %s),
    rotation = %s,
    debug    = true,
    options  = {
        {
            label = 'Interact',
            icon  = 'fa-solid fa-hand',
            onSelect = function(data)
                print('Selected entity:', data.entity)
            end,
        },
    },
})]]):format(
        R(box.coords.x), R(box.coords.y), R(box.coords.z),
        R(box.size.x),   R(box.size.y),   R(box.size.z),
        R(box.heading))
end

local function boxSnippetLibZone()
    return ([[
local zone = lib.zones.box({
    coords   = vec3(%s, %s, %s),
    size     = vec3(%s, %s, %s),
    rotation = %s,
    debug    = true,
    onEnter = function(self) end,
    onExit  = function(self) end,
    inside  = function(self) end,
})]]):format(
        R(box.coords.x), R(box.coords.y), R(box.coords.z),
        R(box.size.x),   R(box.size.y),   R(box.size.z),
        R(box.heading))
end

local function boxSnippetQbTarget()
    return ([[
exports['qb-target']:AddBoxZone('zoneName', vector3(%s, %s, %s), %s, %s, {
    name    = 'zoneName',
    heading = %s,
    debugPoly = true,
    minZ = %s,
    maxZ = %s,
}, {
    options = {
        { label = 'Interact', icon = 'fa-solid fa-hand', action = function() end },
    },
    distance = 2.5,
})]]):format(
        R(box.coords.x), R(box.coords.y), R(box.coords.z),
        R(box.size.x),   R(box.size.y),   R(box.heading),
        R(box.coords.z - box.size.z / 2.0),
        R(box.coords.z + box.size.z / 2.0))
end

local function boxMenu()
    if not box.coords then box.coords = GetEntityCoords(PlayerPedId()) end
    drawBoxLoop()
    lib.registerContext({
        id = 'sfd_zone_box', title = 'Zone Builder — Box', menu = 'sfd_zone_main', canClose = true,
        options = {
            { title = 'Center', description = SFD.FormatVec3(box.coords), icon = 'crosshairs', readOnly = true },
            { title = 'Size',   description = ('%sx %sy %sz'):format(R(box.size.x), R(box.size.y), R(box.size.z)), icon = 'maximize',
              onSelect = function()
                  local input = lib.inputDialog('Box size', {
                      { type = 'number', label = 'X', default = box.size.x, min = 0.1, step = 0.1 },
                      { type = 'number', label = 'Y', default = box.size.y, min = 0.1, step = 0.1 },
                      { type = 'number', label = 'Z', default = box.size.z, min = 0.1, step = 0.1 },
                  })
                  if input then box.size = vec3(input[1] + 0.0, input[2] + 0.0, input[3] + 0.0) end
                  boxMenu()
              end },
            { title = 'Rotation', description = ('%s°'):format(R(box.heading)), icon = 'rotate',
              onSelect = function()
                  local input = lib.inputDialog('Rotation', {
                      { type = 'slider', label = 'Heading', min = 0, max = 359, default = math.floor(box.heading), step = 1 } })
                  if input then box.heading = (input[1] or 0) + 0.0 end
                  boxMenu()
              end },
            { title = 'Set center to player coords', icon = 'user',
              onSelect = function() box.coords = GetEntityCoords(PlayerPedId()); boxMenu() end },
            { title = 'Set center to aim/raycast hit', icon = 'crosshairs',
              onSelect = function()
                  local cam = GetGameplayCamCoord()
                  local rot = GetGameplayCamRot(2)
                  local rZ, rX = math.rad(rot.z), math.rad(rot.x)
                  local cosX = math.cos(rX); local d = 50.0
                  local dest = vec3(cam.x + (-math.sin(rZ) * cosX) * d, cam.y + (math.cos(rZ) * cosX) * d, cam.z + (math.sin(rX)) * d)
                  local h = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
                  local r, hit, endPos = 0
                  repeat r, hit, endPos = GetShapeTestResult(h); if r == 0 then Wait(0) end until r ~= 0
                  if hit == 1 then box.coords = endPos end
                  boxMenu()
              end },
            { title = 'Copy ox_target snippet', icon = 'crosshairs',
              onSelect = function() SFD.Copied('ox_target box zone', boxSnippetTarget()) end },
            { title = 'Copy ox_lib zone snippet', icon = 'puzzle-piece',
              onSelect = function() SFD.Copied('ox_lib box zone', boxSnippetLibZone()) end },
            { title = 'Copy qb-target snippet',  icon = 'crosshairs',
              onSelect = function() SFD.Copied('qb-target box zone', boxSnippetQbTarget()) end },
            { title = 'Copy as JSON', icon = 'file-code',
              onSelect = function()
                  SFD.Copied('zone JSON', json.encode({
                      type = 'box', coords = { box.coords.x, box.coords.y, box.coords.z },
                      size = { box.size.x, box.size.y, box.size.z }, rotation = box.heading,
                  }))
              end },
            { title = 'Stop preview', icon = 'eye-slash',
              onSelect = function() box.drawing = false; SFD.Notify.info('Box preview stopped.') end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() box.drawing = false; SFD.ZoneBuilder.openMenu() end },
        },
    })
    lib.showContext('sfd_zone_box')
end

-- ───────────────────────────────────────────────
-- SPHERE ZONE
-- ───────────────────────────────────────────────
local sphere = { coords = nil, radius = 1.5, drawing = false }

local function drawSphereLoop()
    if sphere.drawing then return end
    sphere.drawing = true
    CreateThread(function()
        local c = Config.Zones.debugColor
        while sphere.drawing and sphere.coords do
            DrawMarker(28, sphere.coords.x, sphere.coords.y, sphere.coords.z,
                0,0,0, 0,0,0, sphere.radius * 2, sphere.radius * 2, sphere.radius * 2,
                c.r, c.g, c.b, c.a, false, false, 2, false, nil, nil, false)
            Wait(0)
        end
        sphere.drawing = false
    end)
end

local function sphereSnippetTarget()
    return ([[
exports.ox_target:addSphereZone({
    coords = vec3(%s, %s, %s),
    radius = %s,
    debug  = true,
    options = {
        { label = 'Interact', icon = 'fa-solid fa-hand', onSelect = function(data) end },
    },
})]]):format(R(sphere.coords.x), R(sphere.coords.y), R(sphere.coords.z), R(sphere.radius))
end

local function sphereSnippetLib()
    return ([[
local zone = lib.zones.sphere({
    coords = vec3(%s, %s, %s),
    radius = %s,
    debug  = true,
    onEnter = function(self) end,
    onExit  = function(self) end,
})]]):format(R(sphere.coords.x), R(sphere.coords.y), R(sphere.coords.z), R(sphere.radius))
end

local function sphereMenu()
    if not sphere.coords then sphere.coords = GetEntityCoords(PlayerPedId()) end
    drawSphereLoop()
    lib.registerContext({
        id = 'sfd_zone_sphere', title = 'Zone Builder — Sphere', menu = 'sfd_zone_main', canClose = true,
        options = {
            { title = 'Center', description = SFD.FormatVec3(sphere.coords), icon = 'crosshairs', readOnly = true },
            { title = 'Radius', description = ('%sm'):format(R(sphere.radius)), icon = 'circle-dot',
              onSelect = function()
                  local input = lib.inputDialog('Radius', { { type = 'number', label = 'Radius (m)', default = sphere.radius, min = 0.1, step = 0.1 } })
                  if input then sphere.radius = (input[1] or 1.0) + 0.0 end
                  sphereMenu()
              end },
            { title = 'Set center to player coords', icon = 'user',
              onSelect = function() sphere.coords = GetEntityCoords(PlayerPedId()); sphereMenu() end },
            { title = 'Copy ox_target sphere',  icon = 'crosshairs',
              onSelect = function() SFD.Copied('ox_target sphere zone', sphereSnippetTarget()) end },
            { title = 'Copy ox_lib sphere zone',icon = 'puzzle-piece',
              onSelect = function() SFD.Copied('ox_lib sphere zone', sphereSnippetLib()) end },
            { title = 'Stop preview', icon = 'eye-slash',
              onSelect = function() sphere.drawing = false end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() sphere.drawing = false; SFD.ZoneBuilder.openMenu() end },
        },
    })
    lib.showContext('sfd_zone_sphere')
end

-- ───────────────────────────────────────────────
-- POLY ZONE
-- ───────────────────────────────────────────────
local poly = { points = {}, drawing = false }

local function drawPolyLoop()
    if poly.drawing then return end
    poly.drawing = true
    CreateThread(function()
        local c = Config.Zones.debugColor
        while poly.drawing do
            for i, p in ipairs(poly.points) do
                DrawMarker(1, p.x, p.y, p.z - 1.0, 0,0,0, 0,0,0, 0.4,0.4,1.0, c.r, c.g, c.b, 200, false, false, 2, false, nil, nil, false)
                local n = poly.points[i + 1] or poly.points[1]
                if n and #poly.points > 1 then
                    DrawLine(p.x, p.y, p.z, n.x, n.y, n.z, c.r, c.g, c.b, 255)
                end
            end
            Wait(0)
        end
    end)
end

local function polySnippetLib()
    local pts = {}
    for _, p in ipairs(poly.points) do
        pts[#pts + 1] = ('        vec3(%s, %s, %s),'):format(R(p.x), R(p.y), R(p.z))
    end
    return ([[
local zone = lib.zones.poly({
    points = {
%s
    },
    thickness = 4.0,
    debug = true,
    onEnter = function(self) end,
    onExit  = function(self) end,
})]]):format(table.concat(pts, '\n'))
end

local function polyMenu()
    drawPolyLoop()
    lib.registerContext({
        id = 'sfd_zone_poly', title = 'Zone Builder — Poly', menu = 'sfd_zone_main', canClose = true,
        options = {
            { title = ('Points: %d'):format(#poly.points), icon = 'draw-polygon', readOnly = true },
            { title = 'Add point at player coords', icon = 'plus',
              onSelect = function() poly.points[#poly.points + 1] = GetEntityCoords(PlayerPedId()); polyMenu() end },
            { title = 'Undo last point', icon = 'rotate-left',
              onSelect = function() table.remove(poly.points); polyMenu() end },
            { title = 'Clear points', icon = 'broom',
              onSelect = function() poly.points = {}; polyMenu() end },
            { title = 'Copy ox_lib poly zone', icon = 'puzzle-piece',
              onSelect = function()
                  if #poly.points < 3 then SFD.Notify.warning('Need at least 3 points.') return end
                  SFD.Copied('ox_lib poly zone', polySnippetLib())
              end },
            { title = 'Copy as JSON', icon = 'file-code',
              onSelect = function() SFD.Copied('poly JSON', json.encode(poly.points)) end },
            { title = 'Stop preview', icon = 'eye-slash',
              onSelect = function() poly.drawing = false end },
            { title = 'Back', icon = 'arrow-left',
              onSelect = function() poly.drawing = false; SFD.ZoneBuilder.openMenu() end },
        },
    })
    lib.showContext('sfd_zone_poly')
end

function SFD.ZoneBuilder.openMenu()
    lib.registerContext({
        id = 'sfd_zone_main', title = 'Zone Builder', menu = 'sfd_main_menu', canClose = true,
        options = {
            { title = 'Box zone',    description = 'Center · size · rotation · preview', icon = 'cube',         arrow = true, onSelect = function() boxMenu() end },
            { title = 'Sphere zone', description = 'Center · radius · preview',          icon = 'circle-dot',   arrow = true, onSelect = function() sphereMenu() end },
            { title = 'Poly zone',   description = 'Add points walking the perimeter',   icon = 'draw-polygon', arrow = true, onSelect = function() polyMenu() end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_zone_main')
end

SFD.RegisterModule({
    id = 'zone_builder', label = 'Zone Builder',
    description = 'Build box/sphere/poly zones for ox_target, ox_lib, qb-target',
    icon = 'draw-polygon',
    open = function() SFD.ZoneBuilder.openMenu() end,
})
