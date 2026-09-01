-- ShadowForge DevTools — Configuration
-- Edit this file to fit your server. All keys have safe defaults.

SFD = SFD or {
    Modules    = {},
    Framework  = 'standalone',
    Detected   = {},
    State      = {},
    ResourceName = GetCurrentResourceName(),
}

function SFD.RegisterModule(mod)
    if type(mod) ~= 'table' then return end
    if not mod.id or not mod.label or not mod.open then return end
    SFD.Modules[#SFD.Modules + 1] = mod
end

Config = {}

-- ───────────────────────────────────────────────
-- Commands & Keybind
-- ───────────────────────────────────────────────
Config.Commands = { 'sfdev', 'sfdevtools' }

Config.Keybind = {
    enabled     = true,
    name        = 'sfdev_open',
    description = 'Open ShadowForge DevTools',
    defaultKey  = 'F6',
}

-- ───────────────────────────────────────────────
-- Permissions
-- ───────────────────────────────────────────────
Config.Permissions = {
    require   = false,                        -- false to allow everyone
    ace       = 'shadowforge.devtools',      -- base permission
    dangerous = 'shadowforge.devtools.dangerous', -- spawn/delete/modify world
}

-- ───────────────────────────────────────────────
-- Module toggles
-- ───────────────────────────────────────────────
Config.Modules = {
    entity_inspector = true,
    coords           = true,
    zone_builder     = true,
    object_placer    = true,
    vehicle_tools    = true,
    ped_tools        = true,
    player_tools     = true,
    world_tools      = true,
    resource_tools   = true,
    debug_tools      = true,
    snippets         = true,
    settings         = true,
}

-- ───────────────────────────────────────────────
-- Inspector
-- ───────────────────────────────────────────────
Config.Inspector = {
    maxDistance  = 30.0,
    refreshMs    = 100,
    drawLine     = true,
    drawHitMarker = true,
    markerColor  = { r = 192, g = 160, b = 255, a = 200 },
}

-- ───────────────────────────────────────────────
-- Coords
-- ───────────────────────────────────────────────
Config.Coords = {
    maxSavedLocations = 100,
    decimals          = 2,
}

-- ───────────────────────────────────────────────
-- Zone builder
-- ───────────────────────────────────────────────
Config.Zones = {
    defaultBoxSize    = vec3(2.0, 2.0, 2.0),
    defaultSphereRad  = 1.5,
    debugColor        = { r = 192, g = 160, b = 255, a = 80 },
}

-- ───────────────────────────────────────────────
-- Object placer
-- ───────────────────────────────────────────────
Config.ObjectPlacer = {
    maxDevProps = 50,
    moveSpeed   = 0.05,
    rotateSpeed = 2.0,
    fastMul     = 4.0,
    slowMul     = 0.25,
    snapToGround = true,
}

-- ───────────────────────────────────────────────
-- Player tools (everything off by default for safety on public servers)
-- ───────────────────────────────────────────────
Config.PlayerTools = {
    allowSelfHeal     = true,
    allowSelfArmor    = true,
    allowNoclip       = true,
    allowGodmode      = true,
    allowInvisible    = true,
    allowDevBlips     = true,
    noclipSpeed       = 1.0,
    noclipFastMul     = 4.0,
    noclipSlowMul     = 0.25,
}

-- ───────────────────────────────────────────────
-- Resource tools
-- Only resources listed here can be restarted via the panel.
-- ───────────────────────────────────────────────
Config.SafeResources = {
    -- 'my_test_resource',
    -- 'qbx_garages',
}

-- ───────────────────────────────────────────────
-- World
-- ───────────────────────────────────────────────
Config.World = {
    weatherTypes = {
        'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'SMOG', 'FOGGY',
        'OVERCAST', 'RAIN', 'THUNDER', 'CLEARING', 'NEUTRAL',
        'SNOW', 'BLIZZARD', 'SNOWLIGHT', 'XMAS', 'HALLOWEEN',
    },
    syncToServer = false, -- set true to broadcast time/weather to all (admin-style)
}

-- ───────────────────────────────────────────────
-- Ped scenarios
-- ───────────────────────────────────────────────
Config.Scenarios = {
    'WORLD_HUMAN_CLIPBOARD',
    'WORLD_HUMAN_COP_IDLES',
    'WORLD_HUMAN_GUARD_STAND',
    'WORLD_HUMAN_STAND_IMPATIENT',
    'WORLD_HUMAN_SMOKING',
    'WORLD_HUMAN_HANG_OUT_STREET',
    'WORLD_HUMAN_AA_COFFEE',
    'WORLD_HUMAN_LEANING',
    'WORLD_HUMAN_MUSICIAN',
    'WORLD_HUMAN_DRINKING',
    'WORLD_HUMAN_PARTYING',
    'WORLD_HUMAN_TOURIST_MOBILE',
    'WORLD_HUMAN_AA_SMOKE',
    'WORLD_HUMAN_PAPARAZZI',
}

-- ───────────────────────────────────────────────
-- UI
-- ───────────────────────────────────────────────
Config.UI = {
    panelIcon       = 'screwdriver-wrench',
    panelTitle      = 'ShadowForge DevTools',
    panelSubtitle   = 'Developer panel',
    sound           = true,
    framework_detect = true,
    debug_markers   = true,
    accent          = '#C0A0FF',
}

-- ───────────────────────────────────────────────
-- Discord logging
-- ───────────────────────────────────────────────
Config.Discord = {
    enabled   = false,
    webhook   = '',
    botName   = 'ShadowForge DevTools',
    botAvatar = '',
    color     = 12624639,
    log = {
        open     = true,
        delete   = true,
        spawn    = true,
        teleport = true,
        noclip   = true,
        godmode  = true,
        snippet  = false,
        resource = true,
        world    = true,
    },
}
