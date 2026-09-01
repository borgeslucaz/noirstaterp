-- ---------------------------------------------------------------------------
--  Voice range marker - ground circle drawn around the local player
-- ---------------------------------------------------------------------------
--  Per spec: shows on mode switch for ~2-3 seconds, optionally pulses
--  while NetworkIsPlayerTalking returns true. Two threads: a low-frequency
--  trigger (handled via the voiceModeChanged event) and a tight render
--  thread that only runs when the marker is actually visible.
-- ---------------------------------------------------------------------------

local visible = false
local visibleUntil = 0
local currentMode, currentDistance = 'normal', 7.5

local function showMarker(mode, distance)
    currentMode     = mode or 'normal'
    currentDistance = distance or 7.5
    visible         = true
    visibleUntil    = GetGameTimer() + math.floor((Config.Voice.marker.showSeconds or 2.5) * 1000)
end

AddEventHandler('lcp_hud_v4:voiceModeChanged', function(mode, distance)
    if not Config.Voice.marker.enabled then return end
    showMarker(mode, distance)
end)

-- Render thread. Idles cheaply when marker is hidden.
CreateThread(function()
    while true do
        if not Config.Voice.enabled or not Config.Voice.marker.enabled then
            Wait(500)
        else
            local now = GetGameTimer()
            local talking = Config.Voice.marker.pulseWhileTalking
                and NetworkIsPlayerTalking(PlayerId())
                or false

            if visible or talking then
                if not talking and now >= visibleUntil then
                    visible = false
                    Wait(250)
                else
                    local ped = PlayerPedId()
                    local coords = GetEntityCoords(ped)
                    local col = Config.Voice.colors[currentMode] or Config.Voice.colors.normal
                    local alpha = Config.Voice.marker.alpha or 110
                    if talking then
                        -- subtle pulse
                        alpha = math.floor(alpha + math.sin(now / 200.0) * 25)
                        if alpha < 30 then alpha = 30 end
                        if alpha > 200 then alpha = 200 end
                    end
                    local d = currentDistance * 2.0 -- marker takes diameter
                    DrawMarker(
                        1,                                  -- type: vertical cylinder / circle on ground
                        coords.x, coords.y, coords.z - 0.98,
                        0.0, 0.0, 0.0,                       -- dir
                        0.0, 0.0, 0.0,                       -- rot
                        d, d, (Config.Voice.marker.height or 0.5),
                        col[1] or 255, col[2] or 255, col[3] or 255,
                        alpha,
                        false, false, 2, false, nil, nil, false
                    )
                    Wait(0)
                end
            else
                Wait(200)
            end
        end
    end
end)
