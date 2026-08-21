local function setupMapZooms()
    for _, lvl in ipairs(config.zoomLevels) do
        SetMapZoomDataLevel(lvl.index, lvl.zoomScale, lvl.zoomSpeed, lvl.scrollSpeed, lvl.tilesX, lvl.tilesY)
    end
end

local function setupMinimapLayout()
    local defaultAspectRatio = 1920 / 1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local minimapOffset = 0

    if aspectRatio > defaultAspectRatio then
        minimapOffset = ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end

    SetMinimapClipType(0)
    SetMinimapComponentPosition('minimap', 'L', 'B', minimapOffset, -0.047, 0.1638, 0.183)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', minimapOffset, 0.0, 0.128, 0.20)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01 + minimapOffset, 0.025, 0.262, 0.300)
    SetBlipAlpha(GetNorthRadarBlip(), 0)
end

local function radarLoop()
    SetRadarZoom(config.radarZoom)
    DontTiltMinimapThisFrame()
end

CreateThread(function()
    setupMapZooms()
    setupMinimapLayout()
    while true do
        radarLoop()
        Wait(0)
    end
end)

if not config.removeBlur then return end

---@diagnostic disable-next-line: missing-parameter
RequestStreamedTextureDict('radar_masks')

while not HasStreamedTextureDictLoaded('radar_masks') do
    Wait(0)
end

AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'radar_masks', 'radarmasksm')
AddReplaceTexture('platform:/textures/graphics', 'radarmasklg', 'radar_masks', 'radarmasklg')
Wait(500)

SetBigmapActive(true, false)
Wait(0)
SetBigmapActive(false, false)

if HasStreamedTextureDictLoaded('radar_masks') then
    SetStreamedTextureDictAsNoLongerNeeded('radar_masks')
end