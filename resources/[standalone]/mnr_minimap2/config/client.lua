---@diagnostic disable-next-line: lowercase-global
config = {}

config.offset = 0.05
config.removeBlur = true

config.tiles = {
    { id = '0_0', row = 0, col = 0, alpha = 100 },
    { id = '0_1', row = 0, col = 1, alpha = 100 },
    { id = '1_0', row = 1, col = 0, alpha = 100 },
    { id = '1_1', row = 1, col = 1, alpha = 100 },
    { id = '2_0', row = 2, col = 0, alpha = 100 },
    { id = '2_1', row = 2, col = 1, alpha = 100 },
}

config.mods = {
    {
        resources = { 'tstudio_alamo_island' },
        compatible = { 'atlas' },
        mods = {
            { id = '0_0', mod = 'tstudio1', row = 0, col = 0, alpha = 100 },
            { id = '0_1', mod = 'tstudio1', row = 0, col = 1, alpha = 100 },
            { id = '1_0', mod = 'tstudio1', row = 1, col = 0, alpha = 100 },
            { id = '1_1', mod = 'tstudio1', row = 1, col = 1, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_canyon_bridge' },
        compatible = { 'atlas' },
        mods = {
            { id = '0_0', mod = 'tstudio2', row = 0, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_alamo_island', 'tstudio_canyon_bridge' },
        compatible = { 'atlas' },
        mods = {
            { id = '0_0', mod = 'tstudio3', row = 0, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_legionsquare' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_0', mod = 'tstudio1', row = 2, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_missionrow_park' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_0', mod = 'tstudio2', row = 2, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_pearls_resort' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_0', mod = 'tstudio3', row = 2, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_legionsquare', 'tstudio_missionrow_park' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_0', mod = 'tstudio4', row = 2, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_legionsquare', 'tstudio_pearls_resort' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_0', mod = 'tstudio5', row = 2, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_missionrow_park', 'tstudio_pearls_resort' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_0', mod = 'tstudio6', row = 2, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_legionsquare', 'tstudio_missionrow_park', 'tstudio_pearls_resort' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_0', mod = 'tstudio7', row = 2, col = 0, alpha = 100 },
        },
    },
    {
        resources = { 'mnr_cayo' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_1', mod = 'mnr1', row = 2, col = 1, alpha = 100 },
            { id = '2_2', mod = 'mnr1', row = 2, col = 2, alpha = 100 },
            { id = '3_1', mod = 'mnr1', row = 3, col = 1, alpha = 100 },
            { id = '3_2', mod = 'mnr1', row = 3, col = 2, alpha = 100 },
        },
    },
    {
        resources = { 'mnr_cayo', 'tstudio_cayo_bridge' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_1', mod = 'tstudio1', row = 2, col = 1, alpha = 100 },
        },
    },
    {
        resources = { 'tstudio_missionrow_park' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_1', mod = 'tstudio2', row = 2, col = 1, alpha = 100 },
        },
    },
    {
        resources = { 'mnr_cayo', 'tstudio_missionrow_park' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_1', mod = 'tstudio3', row = 2, col = 1, alpha = 100 },
        },
    },
    {
        resources = { 'mnr_cayo', 'tstudio_cayo_bridge', 'tstudio_missionrow_park' },
        compatible = { 'atlas' },
        mods = {
            { id = '2_1', mod = 'tstudio4', row = 2, col = 1, alpha = 100 },
        },
    },
}

config.radarZoom = 1000

config.zoomLevels = {
    { index = 0, zoomScale = 3.0, zoomSpeed = 0.9, scrollSpeed = 0.08, tilesX = 0.0, tilesY = 0.0 },
    { index = 1, zoomScale = 3.5, zoomSpeed = 0.9, scrollSpeed = 0.08, tilesX = 0.0, tilesY = 0.0 },
    { index = 2, zoomScale = 8.0, zoomSpeed = 0.9, scrollSpeed = 0.08, tilesX = 9.0, tilesY = 4.0 },
    { index = 3, zoomScale = 20.0, zoomSpeed = 0.9, scrollSpeed = 0.08, tilesX = 3.0, tilesY = 2.0 },
    { index = 4, zoomScale = 27.5, zoomSpeed = 0.9, scrollSpeed = 0.08, tilesX = 2.0, tilesY = 1.0 },
}