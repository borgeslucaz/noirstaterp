local utility = {}
local config = lib.require("config.shared")
local cachedMinimap
local cachedResolutionX
local cachedResolutionY
local cachedSafezone

---@param value number
---@return number
utility.convertRpmToPercentage = function(value)
    local percentage = math.ceil(value * 10000 - 2001) / 80
    local clampedPercentage = math.max(0, math.min(percentage, 100))
    return math.floor(clampedPercentage + 0.5)
end

-- True when both flat tables hold the same keys and values (nil previous = changed).
---@param previous table?
---@param current table
---@return boolean
utility.shallowEqual = function(previous, current)
    if not previous then return false end

    for key, value in pairs(current) do
        if previous[key] ~= value then return false end
    end

    for key in pairs(previous) do
        if current[key] == nil then return false end
    end

    return true
end

---@param num number
---@param numDecimalPlaces number?
---@return integer
utility.round = function(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num + 0.5 * mult)
end

utility.convertEngineHealthToPercentage = function(value)
    -- Engine health ranges from 1000 (perfect) to 0 (about to catch fire)
    -- Values below 0 are just shown as 0% since they're critically damaged
    local clampedValue = math.max(0, math.min(value, 1000))

    local percentage = (clampedValue / 1000) * 100

    percentage = math.floor(percentage + 0.5)

    return percentage
end

-- On screens wider than 16:9 the game keeps its HUD inside a centred 16:9 area.
-- This offset (in aligned units) pushes the map out to the real screen edge.
---@return number
utility.getUltrawideOffset = function()
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local defaultAspectRatio = 1920 / 1080
    local aspectRatio = resolutionX / resolutionY

    if aspectRatio > defaultAspectRatio then
        return ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end

    return 0
end

---@return {width: number, height: number, left: number, top: number}
utility.calculateMinimapSizeAndPosition = function(force)
    local resX, resY = GetActiveScreenResolution()
    -- The HUD size setting (safezone) moves the map too, so it is part of the key.
    local safezone = GetSafeZoneSize()
    if not force and cachedMinimap and cachedResolutionX == resX and cachedResolutionY == resY
        and cachedSafezone == safezone then
        return cachedMinimap
    end

    local minimap = {}
    local aspectRatio = GetAspectRatio(false)

    SetScriptGfxAlign(string.byte("L"), string.byte("B"))
    -- Same ultrawide offset positionMinimap applies, so the NUI follows the map to the edge.
    -- Component offsets are in 16:9-area widths, GetScriptGfxPosition in full-screen widths
    -- (measured at 3024x1296: the map moved 375px, the unconverted anchor 491px).
    local toScreenWidths = (1920 / 1080) / math.max(resX / resY, 1920 / 1080)
    local minimapRawX, minimapRawY = GetScriptGfxPosition(utility.getUltrawideOffset() * toScreenWidths, 0.002 + -0.229888)
    minimap.width = resX / (3.48 * aspectRatio)
    minimap.height = resY / 5.55
    ResetScriptGfxAlign()

    minimap.leftX = minimapRawX
    minimap.rightX = minimapRawX + minimap.width
    minimap.topY = minimapRawY
    minimap.bottomY = minimapRawY + minimap.height
    minimap.X = minimapRawX + (minimap.width / 2)
    minimap.Y = minimapRawY + (minimap.height / 2)

    minimap.webLeft = minimapRawX * resX
    minimap.webTop = minimapRawY * resY
    minimap.webWidth = (minimap.width / resX) * resX
    minimap.webHeight = (minimap.height / resY) * resY

    cachedMinimap = {
        top = minimap.webTop,
        left = minimap.webLeft,
        height = minimap.webHeight,
        width = minimap.webWidth,
        -- Values above are in game pixels; the NUI rescales them to its own viewport.
        screenWidth = resX,
        screenHeight = resY,
    }
    cachedResolutionX = resX
    cachedResolutionY = resY
    cachedSafezone = safezone

    return cachedMinimap
end

utility.invalidateMinimapCache = function()
    cachedMinimap = nil
end

--- Checks whether the specified framework is valid.
---@return boolean
utility.isFrameworkValid = function()
    local framework = config.framework and config.framework:lower() or nil

    if not framework then
        lib.print.info("(utility:isFrameworkValid) No framework specified, defaulting to 'none'.")
        return false
    end

    local validFrameworks = {
        esx = true,
        qb = true,
        ox = true,
        custom = true,
    }

    lib.print.verbose("(utility:isFrameworkValid) Checking if framework is valid: ", validFrameworks[framework] ~= nil)
    return validFrameworks[framework] ~= nil
end

-- Prevents the bigmap from staying active after the minimap is closed, since sometimes the bigmap is still active and stuck on the screen
utility.preventBigmapFromStayingActive = function()
    local timeout = 0
    while true do
        lib.print.debug("(utility:preventBigmapFromStayingActive) Running, timeout: ", timeout)

        SetBigmapActive(false, false)

        if timeout >= 10000 then
            return
        end

        timeout = timeout + 1000
        Wait(1000)
    end
end

-- Positions the minimap for the current resolution. Runs again whenever the
-- resolution changes, since the offset depends on the aspect ratio.
utility.positionMinimap = function()
    local minimapOffset = utility.getUltrawideOffset()
    -- Matches the approved 1920x1080 web preview: +28px right, -38.01px up (measured in game).
    -- Normalized offsets keep the same relative placement at other resolutions.
    local previewOffsetX = 28 / 1920
    local previewOffsetY = -38.01 / 1080

    SetMinimapComponentPosition("minimap", "L", "B", previewOffsetX + minimapOffset, -0.047 + previewOffsetY, 0.1638, 0.183)
    SetMinimapComponentPosition("minimap_mask", "L", "B", previewOffsetX + minimapOffset, previewOffsetY, 0.128, 0.20)
    SetMinimapComponentPosition("minimap_blur", "L", "B", -0.01 + previewOffsetX + minimapOffset, 0.025 + previewOffsetY, 0.262, 0.300)
    utility.invalidateMinimapCache()
end

utility.setupMinimap = function()
    lib.print.debug("(utility:setupMinimap) Setting up minimap.")

    RequestStreamedTextureDict("squaremap", false)

    while not HasStreamedTextureDictLoaded("squaremap") do
        Wait(100)
    end

    SetMinimapClipType(0)
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
    -- GTA V Enhanced no longer exposes radarmask1g in the graphics dictionary.
    -- Replacing it logs "Could not find original texture" on every resource start.

    utility.positionMinimap()

    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetBigmapActive(true, false)
    SetMinimapClipType(0)
    CreateThread(utility.preventBigmapFromStayingActive)

    if utility.watchingResolution then return end
    utility.watchingResolution = true

    local lastX, lastY = GetActiveScreenResolution()
    local lastSafezone = GetSafeZoneSize()
    while true do
        Wait(1000)
        local resX, resY = GetActiveScreenResolution()
        local safezone = GetSafeZoneSize()
        if resX ~= lastX or resY ~= lastY or safezone ~= lastSafezone then
            lastX, lastY, lastSafezone = resX, resY, safezone
            lib.print.debug(("(utility:setupMinimap) Screen changed to %dx%d, safezone %.3f; repositioning minimap."):format(resX, resY, safezone))
            utility.positionMinimap()
            -- Same bigmap toggle as the first setup, so the radar applies the new layout.
            SetBigmapActive(true, false)
            CreateThread(utility.preventBigmapFromStayingActive)
        end
    end
end

-- Removes the default health and armor bars from the HUD
utility.removeHealthArmorBars = function()
    local minimap = RequestScaleformMovie("minimap")
    while not HasScaleformMovieLoaded(minimap) do
        Wait(100)
    end

    SetRadarBigmapEnabled(false, false)
    while true do
        BeginScaleformMovieMethod(minimap, "SETUP_HEALTH_ARMOUR")
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
        Wait(1000)
    end
end

CreateThread(utility.removeHealthArmorBars)

---@param coords vector3
---@return boolean
---@return table
utility.get2DCoordFrom3DCoord = function(coords)
    if not coords then
        return false, {}
    end
    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    return onScreen, { left = tostring(x * 100) .. "%", top = tostring(y * 100) .. "%" }
end

return utility
