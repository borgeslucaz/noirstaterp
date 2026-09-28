if not IsDuplicityVersion() then
    local config = lib.require("config.shared")
    local playerStatusClass = lib.require("modules.threads.client.player_status")
    local vehicleStatusClass = lib.require("modules.threads.client.vehicle_status")
    local seatbeltLogicClass = lib.require("modules.seatbelt.client")
    local utility = lib.require("modules.utility.shared.main")
    local interface = lib.require("modules.interface.client")

    local seatbeltLogic = seatbeltLogicClass.new()
    local playerStatusThread = playerStatusClass.new()
    local vehicleStatusThread = vehicleStatusClass.new(playerStatusThread, seatbeltLogic)
    local framework = utility.isFrameworkValid() and lib.require("modules.frameworks." .. config.framework:lower()).new() or false

    -- Map zoom values previously supplied by neen-atlasmap-en2.
    CreateThread(function()
        SetMapZoomDataLevel(0, 2.75, 0.9, 0.08, 0.0, 0.0)
        SetMapZoomDataLevel(1, 2.8, 0.9, 0.08, 0.0, 0.0)
        SetMapZoomDataLevel(2, 8.0, 0.9, 0.08, 0.0, 0.0)
        SetMapZoomDataLevel(3, 20.0, 0.9, 0.08, 0.0, 0.0)
        SetMapZoomDataLevel(4, 35.0, 0.9, 0.08, 0.0, 0.0)
        SetMapZoomDataLevel(5, 55.0, 0.0, 0.1, 2.0, 1.0)
        SetMapZoomDataLevel(6, 450.0, 0.0, 0.1, 1.0, 1.0)
        SetMapZoomDataLevel(7, 4.5, 0.0, 0.0, 0.0, 0.0)
        SetMapZoomDataLevel(8, 11.0, 0.0, 0.0, 2.0, 3.0)
        SetRadarZoom(1200)

        while true do
            Wait(10000)
            SetRadarZoom(1100)
        end
    end)

    playerStatusThread:start(vehicleStatusThread, seatbeltLogic, framework)

    _G.minimapVisible = config.minimapAlways
    local pauseVisibilityManagedExternally = false

    exports("toggleHud", function(state)
        interface:toggle(state)
        if type(state) == "boolean" then
            playerStatusThread:setRadarVisible(state)
        end
        lib.print.debug("(exports:toggleHud) Toggled HUD to state: ", state)
    end)

    exports("setHudVisible", function(state)
        assert(type(state) == "boolean", "state must be a boolean")
        interface:toggle(state)
    end)

    exports("isHudVisible", function()
        return interface.store.visibility.app
    end)

    exports("setPauseVisibilityManaged", function(state)
        pauseVisibilityManagedExternally = state == true
    end)

    local function toggleMap(state)
        _G.minimapVisible = state
        playerStatusThread:setRadarVisible(state)
        lib.print.debug("(toggleMap) Toggled map to state: ", state)
    end

    exports("toggleMap", toggleMap)

    RegisterCommand("togglehud", function()
        interface:toggle()
    end, false)

    local isPauseMenuOpen = false
    CreateThread(function()
        while true do
            local currentPauseMenuState = IsPauseMenuActive()

            if pauseVisibilityManagedExternally then
                -- Keep the edge detector synchronized while another resource owns
                -- pause-menu visibility, avoiding a late restore race on unlock.
                isPauseMenuOpen = currentPauseMenuState
            elseif currentPauseMenuState ~= isPauseMenuOpen then
                isPauseMenuOpen = currentPauseMenuState

                if isPauseMenuOpen then
                    interface:toggle(false)
                else
                    interface:toggle(true)
                end
            end
            Wait(isPauseMenuOpen and 250 or 500)
        end
    end)

    -- /hudmapa: alignment diagnostic. Red = rect Lua reports (drawn by the game),
    -- cyan = rect the NUI places the bars against, plus the numbers on screen and in F8.
    local debugMinimap = false
    RegisterCommand("hudmapa", function()
        debugMinimap = not debugMinimap
        local map = utility.calculateMinimapSizeAndPosition(true)
        print(("[noir_hud] res=%dx%d aspect=%.4f safezone=%.4f | map left=%.1f top=%.1f w=%.1f h=%.1f"):format(
            map.screenWidth, map.screenHeight, GetAspectRatio(false), GetSafeZoneSize(), map.left, map.top, map.width, map.height))
        interface:message("debug::minimap", {
            enabled = debugMinimap,
            aspect = GetAspectRatio(false),
            safezone = GetSafeZoneSize(),
        })
        if not debugMinimap then return end

        CreateThread(function()
            while debugMinimap do
                local m = utility.calculateMinimapSizeAndPosition()
                local x, y = m.left / m.screenWidth, m.top / m.screenHeight
                local w, h = m.width / m.screenWidth, m.height / m.screenHeight
                local tx, ty = 2 / m.screenWidth, 2 / m.screenHeight
                DrawRect(x + w / 2, y, w, ty, 255, 40, 40, 230)
                DrawRect(x + w / 2, y + h, w, ty, 255, 40, 40, 230)
                DrawRect(x, y + h / 2, tx, h, 255, 40, 40, 230)
                DrawRect(x + w, y + h / 2, tx, h, 255, 40, 40, 230)
                Wait(0)
            end
        end)
    end, false)

    interface:on("debug::viewport", function(data, cb)
        print(("[noir_hud] NUI viewport=%sx%s dpr=%s"):format(data.width, data.height, data.dpr))
        cb(true)
    end)

    interface:on("APP_LOADED", function(_, cb)
        local data = {
            config = config,
            minimap = utility.calculateMinimapSizeAndPosition(),
        }

        cb(data)

        CreateThread(utility.setupMinimap)
        toggleMap(config.minimapAlways)

        -- The interface hides itself on load and only reappears on the login event,
        -- which does not fire again after a resource restart mid-session.
        local ok, loggedIn = pcall(function() return exports.bgrz_core:IsLoggedIn() end)
        if ok and loggedIn and not IsPauseMenuActive() then
            interface:toggle(true)
        end
    end)

    return
end

local sv_utils = lib.require("modules.utility.server.main")

CreateThread(function()
    if not sv_utils.isInterfaceCompiled() then
        print("^1UI not compiled: run ^0npm install && npm run build^1 inside noir_hud/web^0")
    end

    assert(GetResourceState('ox_lib') == 'started', 'ox_lib is not started. Please ensure ox_lib is installed and started before noir_hud.')
    assert(lib.checkDependency('ox_lib', '3.27.0', true), 'Upgrade ox_lib to 3.27.0 or higher')
end)
