---@description STATIC VARIABLES (Don't touch unless you know what are you doing)
local SCALE_PERCENT = 100                               ---@note x and y (because 1:1 and equal proportions)
local WORLD_WIDTH = 9216.0                              ---@note WORLD_HEIGHT = 15360.002 (probably 15360.0) (for reference)
local SCALEFORM_WIDTH = 1728.0                          ---@note SCALEFORM_HEIGHT = 2880.0 (for reference)
local ORIGIN = { x = 864.0, y = 1440.0 }
local OFFSET = { x = 360, y = 600 }
local BITMAP_SIZE = { x = 4500.0, y = 4500.0 }
local BITMAP_START = { x = -4140.0, y = 8400.0 }
local VANILLA_MAP_MIN = { row = 0, col = 0 }            ---@note Minimum tiles extension of vanilla Map (Don't touch)
local VANILLA_MAP_MAX = { row = 2, col = 1 }            ---@note Maximum tiles extension of vanilla Map (Don't touch)

local defaultMap = GetConvar('mnr_minimap:default_map', 'atlas')

-- Creates an invisible blip at the specified coordinates.
---@param x number The x coordinate of the blip.
---@param y number The y coordinate of the blip.
local function createFakeBlip(x, y)
    local blipId = AddBlipForCoord(x, y, 1.0)
    SetBlipDisplay(blipId, 4)
    SetBlipAlpha(blipId, 0)
end

-- Extends the pause menu map bounds by creating invisible blips at the corners.
---@param min table Table with minimum tile offsets (row, col).
---@param max table Table with maximum tile offsets (row, col).
local function extendMapBounds(min, max)
    local xMin = BITMAP_START.x + min.col * BITMAP_SIZE.x
    local xMax = BITMAP_START.x + (max.col + 1) * BITMAP_SIZE.x
    local yMin = BITMAP_START.y - min.row * BITMAP_SIZE.y
    local yMax = BITMAP_START.y - (max.row + 1) * BITMAP_SIZE.y

    createFakeBlip(xMin, yMin)
    createFakeBlip(xMax, yMax)

    ExtendWorldBoundaryForPlayer(xMin, yMin, -300.0)
    ExtendWorldBoundaryForPlayer(xMax, yMax, 2000.0)
end

-- Requests and loads a scaleform file.
---@param name string The name of the scaleform file to load.
---@return number The handle of the loaded scaleform.
local function loadScaleform(name)
    local scaleformId = RequestScaleformMovie(name)

    while not HasScaleformMovieLoaded(scaleformId) do
        Wait(0)
    end

    return scaleformId
end

-- Refreshes the minimap by toggling the bigmap view.
local function refreshMinimap()
    local minimapId = loadScaleform('minimap')

    SetBigmapActive(true, false)
    Wait(0)
    SetBigmapActive(false, false)

    SetScaleformMovieAsNoLongerNeeded(minimapId)
end

-- Adds a tile to the scaleform with the provided configuration.
---@param mainMapId number The handle of the scaleform to draw the tile on.
---@param tile table The tile configuration (dict, name, alpha).
---@param data table Tile positioning data (name, x, y, size).
local function addTile(mainMapId, tile, data)
    ---@diagnostic disable-next-line: missing-parameter
    RequestStreamedTextureDict(tile.dict)

    while not HasStreamedTextureDictLoaded(tile.dict) do
        Wait(0)
    end

    BeginScaleformMovieMethod(mainMapId, 'DRAW_TEXTURE')
    PushScaleformMovieFunctionParameterString(data.name)
    PushScaleformMovieFunctionParameterString(tile.dict)
    PushScaleformMovieFunctionParameterString(tile.name)
    PushScaleformMovieFunctionParameterFloat(data.x)
    PushScaleformMovieFunctionParameterFloat(data.y)
    PushScaleformMovieFunctionParameterInt(SCALE_PERCENT)
    PushScaleformMovieFunctionParameterInt(SCALE_PERCENT)
    PushScaleformMovieFunctionParameterFloat(data.size)
    PushScaleformMovieFunctionParameterFloat(data.size)
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(mainMapId, 'SET_TILE_ALPHA')
    PushScaleformMovieFunctionParameterString(data.name)
    PushScaleformMovieFunctionParameterInt(tile.alpha)
    EndScaleformMovieMethod()

    if HasStreamedTextureDictLoaded(tile.dict) then
        SetStreamedTextureDictAsNoLongerNeeded(tile.dict)
    end
end

-- Calculates the scaleform position for a tile.
---@param tile table The tile configuration (row, col).
---@param tileSize number The size of each tile in scaleform units.
---@param xOrigin number The x-axis origin point.
---@param yOrigin number The y-axis origin point.
---@return number x, number y The calculated tile position.
local function calculateTilePosition(tile, tileSize, xOrigin, yOrigin)
    local x = xOrigin + tile.col * tileSize - (config.offset * tile.col)
    local y = yOrigin + tile.row * tileSize - (config.offset * tile.row)

    return x, y
end

-- Checks if all resources in a list are currently running.
---@param resources table List of resource names to check.
---@return boolean valid True if all resources are running, false otherwise.
local function areAllResourcesRunning(resources)
    for _, resourceName in ipairs(resources) do
        if GetResourceState(resourceName) ~= 'started' then
            return false
        end
    end
    return true
end

-- Checks if the default map is compatible with a mod.
---@param compatible table List of compatible map names.
---@return boolean isCompatible True if the default map is compatible, false otherwise.
local function isMapCompatible(compatible)
    for _, mapName in ipairs(compatible) do
        if mapName == defaultMap then
            return true
        end
    end
    return false
end

-- Processes tiles and applies mod replacements if applicable.
---@param baseTiles table The base configuration tiles.
---@return table The processed tiles with mod replacements applied.
local function processTiles(baseTiles)
    local tileMap = {}
    for _, tile in ipairs(baseTiles) do
        tileMap[tile.id] = {
            id = tile.id,
            row = tile.row,
            col = tile.col,
            alpha = tile.alpha,
            mod = nil
        }
    end

    for _, modConfig in ipairs(config.mods) do
        if areAllResourcesRunning(modConfig.resources) and isMapCompatible(modConfig.compatible) then
            for _, modTile in ipairs(modConfig.mods) do
                if tileMap[modTile.id] then
                    tileMap[modTile.id].mod = modTile.mod
                else
                    tileMap[modTile.id] = modTile
                end
            end
        end
    end

    local processedTiles = {}
    for id, tile in pairs(tileMap) do
        local dict, name
        if tile.mod then
            dict = ('%s_%s_%s'):format(defaultMap, tile.id, tile.mod)
            name = dict
        else
            dict = ('%s_%s'):format(defaultMap, tile.id)
            name = dict
        end

        table.insert(processedTiles, {
            dict = dict,
            name = name,
            row = tile.row,
            col = tile.col,
            alpha = tile.alpha
        })
    end

    return processedTiles
end

CreateThread(function()
    local tiles = processTiles(config.tiles)

    local mainMapId = loadScaleform('minimap_main_map')

    BeginScaleformMovieMethod(mainMapId, 'CLEAR_TEXTURES')
    EndScaleformMovieMethod()

    local conversionScale = WORLD_WIDTH / SCALEFORM_WIDTH

    local tileSize = BITMAP_SIZE.x / conversionScale
    local xOrigin = ORIGIN.x + (OFFSET.x / conversionScale) - tileSize
    local yOrigin = ORIGIN.y + (OFFSET.y / conversionScale) - (2 * tileSize)

    local min = { row = VANILLA_MAP_MIN.row, col = VANILLA_MAP_MIN.col }
    local max = { row = VANILLA_MAP_MAX.row, col = VANILLA_MAP_MAX.col }

    for i, tile in ipairs(tiles) do
        local x, y = calculateTilePosition(tile, tileSize, xOrigin, yOrigin)

        min.row = math.min(min.row, tile.row)
        min.col = math.min(min.col, tile.col)
        max.row = math.max(max.row, tile.row)
        max.col = math.max(max.col, tile.col)

        addTile(mainMapId, tile, {
            name = tostring(i),
            x = x,
            y = y,
            size = tileSize
        })
    end

    refreshMinimap()
    extendMapBounds(min, max)
end)