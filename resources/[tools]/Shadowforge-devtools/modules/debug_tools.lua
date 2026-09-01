-- modules/debug_tools.lua
-- Live debug overlay (coords/speed/heading/street/etc) + drawing helpers.

SFD = SFD or {}
SFD.DebugTools = {}

local overlay = false
local overlayConf = {
    coords     = true,
    speed      = true,
    heading    = true,
    street     = true,
    interior   = true,
    fps        = true,
    weapon     = true,
    bucket     = false,
    aimedEntity = true,
}
local fps = 0

local function fpsTracker()
    CreateThread(function()
        local last, frames = GetGameTimer(), 0
        while true do
            frames = frames + 1
            local now = GetGameTimer()
            if now - last >= 1000 then
                fps = math.floor(frames * 1000 / (now - last))
                frames, last = 0, now
            end
            Wait(0)
        end
    end)
end
fpsTracker()

-- Lightweight raycast for "aimed" line in the overlay
local function aimedEntityForOverlay()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rZ, rX = math.rad(rot.z), math.rad(rot.x)
    local cosX = math.cos(rX); local d = 25.0
    local dest = vec3(cam.x + (-math.sin(rZ) * cosX) * d, cam.y + (math.cos(rZ) * cosX) * d, cam.z + (math.sin(rX)) * d)
    local h = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local r, hit, _, _, ent = 0
    repeat r, hit, _, _, ent = GetShapeTestResult(h); if r == 0 then Wait(0) end until r ~= 0
    if hit == 1 and ent and ent ~= 0 then
        return ('handle %d · type %d · model %s'):format(ent, GetEntityType(ent), GetEntityModel(ent))
    end
    return 'none'
end

local function startOverlay()
    if overlay then return end
    overlay = true
    CreateThread(function()
        while overlay do
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local speed = GetEntitySpeed(ped) * 3.6 -- km/h
            local s1 = GetStreetNameAtCoord(p.x, p.y, p.z)
            local street = s1 ~= 0 and GetStreetNameFromHashKey(s1) or '—'
            local zone = GetLabelText(GetNameOfZone(p.x, p.y, p.z))
            local interior = GetInteriorAtCoords(p.x, p.y, p.z)
            local _, weapon = GetCurrentPedWeapon(ped, true)

            local lines = { '~p~ShadowForge DevTools' }
            if overlayConf.fps      then lines[#lines + 1] = ('~s~fps:    ~y~%d'):format(fps) end
            if overlayConf.coords   then lines[#lines + 1] = ('~s~coord:  ~y~%s'):format(SFD.FormatVec3(p)) end
            if overlayConf.heading  then lines[#lines + 1] = ('~s~head:   ~y~%.1f°'):format(heading) end
            if overlayConf.speed    then lines[#lines + 1] = ('~s~speed:  ~y~%.1f km/h'):format(speed) end
            if overlayConf.street   then lines[#lines + 1] = ('~s~street: ~y~%s, %s'):format(street, zone) end
            if overlayConf.interior then lines[#lines + 1] = ('~s~int id: ~y~%d'):format(interior) end
            if overlayConf.weapon   then lines[#lines + 1] = ('~s~weapon: ~y~%s'):format(tostring(weapon)) end
            if overlayConf.aimedEntity then lines[#lines + 1] = ('~s~aim:    ~y~%s'):format(aimedEntityForOverlay()) end

            -- Draw text
            SetTextFont(4); SetTextProportional(true); SetTextScale(0.0, 0.34)
            SetTextColour(255, 255, 255, 220); SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextEdge(1, 0, 0, 0, 200); SetTextDropShadow(); SetTextOutline()

            local x, y = 0.012, 0.32
            for _, line in ipairs(lines) do
                SetTextEntry('STRING'); AddTextComponentString(line); DrawText(x, y); y = y + 0.022
            end
            Wait(0)
        end
    end)
end

local function stopOverlay() overlay = false end

local function configMenu()
    local options = {}
    for k, v in pairs(overlayConf) do
        options[#options + 1] = {
            title = k, description = v and 'shown' or 'hidden',
            icon = v and 'eye' or 'eye-slash',
            onSelect = function() overlayConf[k] = not overlayConf[k]; configMenu() end,
        }
    end
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.DebugTools.openMenu() end }
    lib.registerContext({ id = 'sfd_dbg_cfg', title = 'Overlay fields', menu = 'sfd_dbg_main', canClose = true, options = options })
    lib.showContext('sfd_dbg_cfg')
end

function SFD.DebugTools.openMenu()
    lib.registerContext({
        id = 'sfd_dbg_main', title = 'Debug Tools', menu = 'sfd_main_menu', canClose = true,
        options = {
            { title = overlay and 'Stop debug overlay' or 'Start debug overlay',
              description = 'Live coords/speed/heading/street/etc',
              icon = overlay and 'stop' or 'play',
              onSelect = function() if overlay then stopOverlay() else startOverlay() end; SFD.DebugTools.openMenu() end },
            { title = 'Configure overlay fields', icon = 'sliders', arrow = true, onSelect = function() configMenu() end },
            { title = 'Print routing bucket to F8', icon = 'route',
              onSelect = function()
                  local b = lib.callback.await('sfd:getRoutingBucket', false)
                  print(('^5[SFD] routing bucket = %s^7'):format(tostring(b)))
                  SFD.Notify.info(('Routing bucket: %s'):format(tostring(b)))
              end },
            { title = 'Print own coords to F8', icon = 'terminal',
              onSelect = function()
                  local p = GetEntityCoords(PlayerPedId())
                  print(('^5[SFD] coords = %s^7'):format(SFD.FormatVec4(p, GetEntityHeading(PlayerPedId()))))
              end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_dbg_main')
end

SFD.RegisterModule({
    id = 'debug_tools', label = 'Debug Overlay',
    description = 'Live HUD with coords, speed, street, FPS, aim, etc',
    icon = 'bug',
    open = function() SFD.DebugTools.openMenu() end,
})
