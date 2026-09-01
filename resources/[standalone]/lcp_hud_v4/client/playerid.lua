-- ---------------------------------------------------------------------------
--  Player ID module
-- ---------------------------------------------------------------------------
--  Displays the player's server ID. Two modes:
--    * 'always'   - always visible (default)
--    * 'keyhold'  - only visible while the configured keybind is held
-- ---------------------------------------------------------------------------

local visible = false

local function pushIdState()
    HUD.pushPlayerId(GetPlayerServerId(PlayerId()), visible)
end

CreateThread(function()
    if not Config.PlayerId.enabled then
        HUD.pushPlayerId(-1, false)
        return
    end

    -- Wait briefly so the server id is available.
    Wait(500)

    if (Config.PlayerId.visibility or 'always') == 'always' then
        visible = true
        HUD.state.id = GetPlayerServerId(PlayerId())
        pushIdState()
        -- Refresh occasionally in case the player reconnects mid-resource.
        while true do
            Wait(5000)
            HUD.state.id = GetPlayerServerId(PlayerId())
            pushIdState()
        end
    else
        -- keyhold mode
        RegisterKeyMapping('+lcp_hud_v4_showid', Config.PlayerId.keybindLabel or 'Show Player ID', 'keyboard', Config.PlayerId.keybindKey or 'U')
        RegisterCommand('+lcp_hud_v4_showid', function()
            visible = true
            HUD.state.id = GetPlayerServerId(PlayerId())
            pushIdState()
        end, false)
        RegisterCommand('-lcp_hud_v4_showid', function()
            visible = false
            pushIdState()
        end, false)
        -- Initial state
        HUD.state.id = GetPlayerServerId(PlayerId())
        pushIdState()
    end
end)
