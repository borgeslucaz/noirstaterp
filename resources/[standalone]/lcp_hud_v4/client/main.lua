-- ---------------------------------------------------------------------------
--  lcp_hud_v4 - main client controller
-- ---------------------------------------------------------------------------
--  Holds the central HUD state, dispatches updates to the NUI layer, and
--  manages saving / loading the player's editor layout to KVP.
-- ---------------------------------------------------------------------------

local KVP_KEY = 'lcp_hud_v4:layout:v1'

HUD = {
    layout  = nil,
    visible = true,
    state   = {
        health  = 100,
        armor   = 0,
        hunger  = 100.0,
        thirst  = 100.0,
        voice   = { mode = 'normal', distance = 7.5 },
        ammo    = { current = 0, max = 0, weapon = '' },
        weapon  = false,
        job     = nil,
        id      = -1,
    },
}

-- ---------------------------------------------------------------------------
--  Layout persistence
-- ---------------------------------------------------------------------------

local function defaultLayout()
    local layout = {}
    for k, v in pairs(Config.Defaults) do
        layout[k] = { x = v.x, y = v.y, scale = v.scale, visible = v.visible }
    end
    return layout
end

function HUD.loadLayout()
    local raw = GetResourceKvpString(KVP_KEY)
    if raw then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then
            local layout = defaultLayout()
            for k, v in pairs(data) do
                if layout[k] and type(v) == 'table' then
                    layout[k].x       = tonumber(v.x)       or layout[k].x
                    layout[k].y       = tonumber(v.y)       or layout[k].y
                    layout[k].scale   = tonumber(v.scale)   or layout[k].scale
                    if v.visible ~= nil then layout[k].visible = v.visible and true or false end
                end
            end
            HUD.layout = layout
            return
        end
    end
    HUD.layout = defaultLayout()
end

function HUD.saveLayout()
    if not HUD.layout then return end
    SetResourceKvp(KVP_KEY, json.encode(HUD.layout))
end

function HUD.resetLayout()
    HUD.layout = defaultLayout()
    HUD.saveLayout()
    SendNUIMessage({ type = 'layout', layout = HUD.layout })
end

-- ---------------------------------------------------------------------------
--  NUI dispatch helpers
-- ---------------------------------------------------------------------------

function HUD.pushState()
    SendNUIMessage({
        type    = 'state',
        state   = HUD.state,
        visible = HUD.visible,
    })
end

function HUD.pushVoice(mode, distance)
    SendNUIMessage({
        type     = 'voice',
        mode     = mode,
        distance = distance,
    })
end

function HUD.pushAmmo(weapon, current, max)
    SendNUIMessage({
        type    = 'ammo',
        weapon  = weapon,
        current = current,
        max     = max,
    })
end

function HUD.pushJob(job)
    SendNUIMessage({ type = 'job', job = job })
end

function HUD.pushPlayerId(id, visible)
    SendNUIMessage({ type = 'playerid', id = id, visible = visible })
end

function HUD.pushVisibility(visible)
    HUD.visible = visible and true or false
    SendNUIMessage({ type = 'visibility', visible = HUD.visible })
end

-- ---------------------------------------------------------------------------
--  Boot
-- ---------------------------------------------------------------------------

CreateThread(function()
    -- Wait until the NUI page has loaded once.
    Wait(0)
    HUD.loadLayout()
    SendNUIMessage({
        type    = 'init',
        config  = {
            layout      = Config.Layout,
            colors      = Config.Voice.colors,
            playerId    = Config.PlayerId,
            ammo        = Config.Ammo,
            jobEnabled  = Config.Job.enabled,
            voiceEnabled = Config.Voice.enabled,
            editor      = Config.Editor,
        },
        layout = HUD.layout,
    })
    HUD.pushState()
end)

-- Toggle the whole HUD with /hud (handy for screenshots).
RegisterCommand('hud', function()
    HUD.pushVisibility(not HUD.visible)
end, false)

-- Pause menu hide.
CreateThread(function()
    local wasPaused = false
    while true do
        Wait(250)
        local paused = IsPauseMenuActive()
        if paused ~= wasPaused then
            wasPaused = paused
            SendNUIMessage({ type = 'pause', paused = paused })
        end
    end
end)
