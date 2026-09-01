-- modules/coords.lua
-- Coordinate helpers: copy in many formats, save & teleport to named locations.

SFD = SFD or {}
SFD.Coords = {}

local KVP_KEY = 'sfd:savedLocations'

-- ───────────────────────────────────────────────
-- Format helpers
-- ───────────────────────────────────────────────
local function R(n) return SFD.Round(n, Config.Coords.decimals or 2) end

local function fmtVec2(v)   return ('vector2(%s, %s)'):format(R(v.x), R(v.y)) end
local function fmtVec3(v)   return ('vector3(%s, %s, %s)'):format(R(v.x), R(v.y), R(v.z)) end
local function fmtVec4(v,h) return ('vector4(%s, %s, %s, %s)'):format(R(v.x), R(v.y), R(v.z), R(h)) end
local function fmtVec3s(v)  return ('vec3(%s, %s, %s)'):format(R(v.x), R(v.y), R(v.z)) end
local function fmtVec4s(v,h)return ('vec4(%s, %s, %s, %s)'):format(R(v.x), R(v.y), R(v.z), R(h)) end
local function fmtTable(v, h)
    return ('{ x = %s, y = %s, z = %s, w = %s }'):format(R(v.x), R(v.y), R(v.z), R(h))
end
local function fmtJson(v, h)
    return ('{ "x": %s, "y": %s, "z": %s, "h": %s }'):format(R(v.x), R(v.y), R(v.z), R(h))
end
local function fmtTeleport(v, h)
    return ('/tp %s %s %s %s'):format(R(v.x), R(v.y), R(v.z), R(h))
end

-- ───────────────────────────────────────────────
-- Cam raycast hit (reuses inspector technique)
-- ───────────────────────────────────────────────
local function camHit()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rZ, rX = math.rad(rot.z), math.rad(rot.x)
    local cosX = math.cos(rX)
    local distance = 100.0
    local dest = vec3(
        cam.x + (-math.sin(rZ) * cosX) * distance,
        cam.y + ( math.cos(rZ) * cosX) * distance,
        cam.z + ( math.sin(rX))        * distance
    )
    local h = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local result, hit, endPos = 0
    repeat
        result, hit, endPos = GetShapeTestResult(h)
        if result == 0 then Wait(0) end
    until result ~= 0
    return hit == 1, endPos
end

-- ───────────────────────────────────────────────
-- Saved locations (KVP local storage)
-- ───────────────────────────────────────────────
local function loadSaved()
    local raw = GetResourceKvpString(KVP_KEY)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    return ok and data or {}
end

local function saveAll(t)
    SetResourceKvp(KVP_KEY, json.encode(t or {}))
end

local function saveLocation(name, v, h)
    local saved = loadSaved()
    if #saved >= (Config.Coords.maxSavedLocations or 100) then
        SFD.Notify.error('Saved-location limit reached.')
        return
    end
    saved[#saved + 1] = { name = name, x = v.x, y = v.y, z = v.z, h = h, t = os.time() }
    saveAll(saved)
    SFD.Notify.success(('Location saved: %s'):format(name))
end

local function deleteLocation(idx)
    local saved = loadSaved()
    table.remove(saved, idx)
    saveAll(saved)
end

-- ───────────────────────────────────────────────
-- Menus
-- ───────────────────────────────────────────────
local function copyMenu(label, v, h)
    local id = 'sfd_coords_copy'
    lib.registerContext({
        id = id,
        title = ('Copy — %s'):format(label),
        menu = 'sfd_coords_main',
        canClose = true,
        options = {
            { title = 'vector3',          description = fmtVec3(v),           icon = 'arrows-up-down-left-right',
              onSelect = function() SFD.Copied('vector3', fmtVec3(v)) end },
            { title = 'vector4',          description = fmtVec4(v, h or 0),   icon = 'compass',
              onSelect = function() SFD.Copied('vector4', fmtVec4(v, h or 0)) end },
            { title = 'vector2',          description = fmtVec2(v),           icon = 'arrows-left-right',
              onSelect = function() SFD.Copied('vector2', fmtVec2(v)) end },
            { title = 'vec3 (short)',     description = fmtVec3s(v),          icon = 'code',
              onSelect = function() SFD.Copied('vec3', fmtVec3s(v)) end },
            { title = 'vec4 (short)',     description = fmtVec4s(v, h or 0),  icon = 'code',
              onSelect = function() SFD.Copied('vec4', fmtVec4s(v, h or 0)) end },
            { title = 'Lua table',        description = fmtTable(v, h or 0),  icon = 'table',
              onSelect = function() SFD.Copied('Lua table', fmtTable(v, h or 0)) end },
            { title = 'JSON',             description = fmtJson(v, h or 0),   icon = 'file-code',
              onSelect = function() SFD.Copied('JSON', fmtJson(v, h or 0)) end },
            { title = 'Heading only',     description = tostring(R(h or 0)),  icon = 'arrow-up',
              onSelect = function() SFD.Copied('heading', tostring(R(h or 0))) end },
            { title = '/tp command',      description = fmtTeleport(v, h or 0), icon = 'terminal',
              onSelect = function() SFD.Copied('teleport command', fmtTeleport(v, h or 0)) end },
            {
                title = 'Save as named location',
                icon = 'bookmark',
                onSelect = function()
                    local input = lib.inputDialog('Save Location', {
                        { type = 'input', label = 'Name', required = true, max = 32 },
                    })
                    if input and input[1] then
                        saveLocation(input[1], v, h or 0)
                    end
                end,
            },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.Coords.openMenu() end },
        },
    })
    lib.showContext(id)
end

local function savedLocationsMenu()
    local saved = loadSaved()
    local options = {}
    if #saved == 0 then
        options[#options + 1] = { title = 'No saved locations', description = 'Save coords first', icon = 'circle-info', readOnly = true }
    end
    for i, s in ipairs(saved) do
        options[#options + 1] = {
            title = s.name,
            description = ('vec4(%s, %s, %s, %s)'):format(R(s.x), R(s.y), R(s.z), R(s.h or 0)),
            icon = 'location-pin',
            onSelect = function()
                lib.registerContext({
                    id = 'sfd_coords_loc_' .. i,
                    title = s.name,
                    menu = 'sfd_coords_saved',
                    canClose = true,
                    options = {
                        { title = 'Teleport', icon = 'plane',
                          onSelect = function()
                              if not SFD.HasPermission('dangerous') then SFD.Notify.error('Permission required.') return end
                              local ped = PlayerPedId()
                              SetPedCoordsKeepVehicle(ped, s.x, s.y, s.z)
                              SetEntityHeading(ped, s.h or 0)
                              SFD.Notify.success(('Teleported to %s'):format(s.name))
                              SFD.LogServer('teleport', { name = s.name, coords = { s.x, s.y, s.z, s.h } })
                          end },
                        { title = 'Copy vector4', icon = 'copy',
                          onSelect = function()
                              SFD.Copied('vector4', fmtVec4(vec3(s.x, s.y, s.z), s.h or 0))
                          end },
                        { title = 'Delete', icon = 'trash', iconColor = '#ff6b35',
                          onSelect = function()
                              deleteLocation(i)
                              SFD.Notify.success('Deleted.')
                              savedLocationsMenu()
                          end },
                        { title = 'Back', icon = 'arrow-left', onSelect = function() savedLocationsMenu() end },
                    },
                })
                lib.showContext('sfd_coords_loc_' .. i)
            end,
        }
    end
    options[#options + 1] = {
        title = 'Export all as Lua',
        icon = 'file-export',
        onSelect = function()
            local lines = { 'local locations = {' }
            for _, s in ipairs(saved) do
                lines[#lines + 1] = ('    { name = %q, coords = vector4(%s, %s, %s, %s) },'):format(
                    s.name, R(s.x), R(s.y), R(s.z), R(s.h or 0))
            end
            lines[#lines + 1] = '}'
            SFD.Copied('locations as Lua', table.concat(lines, '\n'))
        end,
    }
    options[#options + 1] = {
        title = 'Export all as JSON',
        icon = 'file-code',
        onSelect = function() SFD.Copied('locations as JSON', json.encode(saved)) end,
    }
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.Coords.openMenu() end }

    lib.registerContext({
        id = 'sfd_coords_saved',
        title = 'Saved locations',
        menu = 'sfd_coords_main',
        canClose = true,
        options = options,
    })
    lib.showContext('sfd_coords_saved')
end

function SFD.Coords.openMenu()
    local ped = PlayerPedId()
    local v = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)

    lib.registerContext({
        id = 'sfd_coords_main',
        title = 'Coordinate Tools',
        menu = 'sfd_main_menu',
        canClose = true,
        options = {
            { title = 'Player coords', description = fmtVec4(v, h), icon = 'user',
              onSelect = function() copyMenu('Player', v, h) end },
            { title = 'Camera coords', description = fmtVec3(GetGameplayCamCoord()), icon = 'camera',
              onSelect = function() copyMenu('Camera', GetGameplayCamCoord(), GetGameplayCamRot(2).z) end },
            { title = 'Aim/raycast hit',  description = 'Open menu to copy hit point', icon = 'crosshairs',
              onSelect = function()
                  local hit, pos = camHit()
                  if not hit then SFD.Notify.warning('No surface hit.') return end
                  copyMenu('Hit point', pos, 0.0)
              end },
            { title = 'Ground Z (here)', description = 'Resolve ground height under your feet', icon = 'mountain',
              onSelect = function()
                  local _, gz = GetGroundZFor_3dCoord(v.x, v.y, v.z + 1.0, false)
                  SFD.Copied('ground Z', tostring(R(gz)))
              end },
            { title = 'Saved locations', description = ('%d saved'):format(#loadSaved()), icon = 'bookmark', arrow = true,
              onSelect = function() savedLocationsMenu() end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_coords_main')
end

SFD.RegisterModule({
    id = 'coords',
    label = 'Coordinate Tools',
    description = 'Copy coords in any format · save named locations',
    icon = 'location-dot',
    open = function() SFD.Coords.openMenu() end,
})
