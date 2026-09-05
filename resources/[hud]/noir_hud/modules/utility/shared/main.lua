local utility = {}
local config = lib.require("config.shared")
local cachedMinimap
local cachedResolutionX
local cachedResolutionY

---@param value number
---@return number
utility.convertRpmToPercentage = function(value)
    local percentage = math.ceil(value * 10000 - 2001) / 80
    local clampedPercentage = math.max(0, math.min(percentage, 100))
    return math.floor(clampedPercentage + 0.5)
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

---@return {width: number, height: number, left: number, top: number}
utility.calculateMinimapSizeAndPosition = function(force)
    local resX, resY = GetActiveScreenResolution()
    if not force and cachedMinimap and cachedResolutionX == resX and cachedResolutionY == resY then
        return cachedMinimap
    end

    local minimap = {}
    local aspectRatio = GetAspectRatio(false)

    SetScriptGfxAlign(string.byte("L"), string.byte("B"))
    local minimapRawX, minimapRawY = GetScriptGfxPosition(0.000, 0.002 + -0.229888)
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
    }
    cachedResolutionX = resX
    cachedResolutionY = resY

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

utility.setupMinimap = function()
    lib.print.debug("(utility:setupMinimap) Setting up minimap.")
    local defaultAspectRatio = 1920 / 1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local minimapOffset = 0
    -- Matches the approved 1920x1080 web preview: +28px right, -14.01px up.
    -- Normalized offsets keep the same relative placement at other resolutions.
    local previewOffsetX = 28 / 1920
    local previewOffsetY = -38.01 / 1080

    if aspectRatio > defaultAspectRatio then
        minimapOffset = ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end

    RequestStreamedTextureDict("squaremap", false)

    while not HasStreamedTextureDictLoaded("squaremap") do
        Wait(100)
    end

    SetMinimapClipType(0)
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
    -- GTA V Enhanced no longer exposes radarmask1g in the graphics dictionary.
    -- Replacing it logs "Could not find original texture" on every resource start.

    SetMinimapComponentPosition("minimap", "L", "B", previewOffsetX + minimapOffset, -0.047 + previewOffsetY, 0.1638, 0.183)
    SetMinimapComponentPosition("minimap_mask", "L", "B", previewOffsetX + minimapOffset, previewOffsetY, 0.128, 0.20)
    SetMinimapComponentPosition("minimap_blur", "L", "B", -0.01 + previewOffsetX + minimapOffset, 0.025 + previewOffsetY, 0.262, 0.300)
    utility.invalidateMinimapCache()

    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetBigmapActive(true, false)
    SetMinimapClipType(0)
    CreateThread(utility.preventBigmapFromStayingActive)

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
