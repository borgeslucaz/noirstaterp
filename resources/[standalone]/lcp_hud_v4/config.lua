Config = {}

-- =========================================================================
--  General
-- =========================================================================

-- "circles" = dual-circle status block (hunger/thirst + health/armor)
-- "row"     = horizontal row of individual elements
Config.Layout = 'circles'

-- Update intervals in ms. Keep these conservative for low CPU usage.
Config.Tick = {
    status = 250, -- health / armor / hunger / thirst poll
    ammo   = 150, -- weapon + ammo poll
    voice  = 200, -- pma-voice mode poll
    job    = 2000,
}

-- =========================================================================
--  Framework detection (ESX / QBCore / standalone)
--
--  Set to 'auto' to detect automatically. Force a value if you want to
--  bypass detection (e.g. you run multiple cores).
-- =========================================================================
Config.Framework = 'qbox' -- 'auto' | 'esx' | 'qb' | 'qbox' | 'standalone'

-- =========================================================================
--  Status (hunger / thirst)
--
--  Source 'framework' tries to read from ESX (esx_status events) or
--  QBCore (PlayerData.metadata.hunger / thirst). 'internal' uses the
--  built-in decay loop below.
-- =========================================================================
Config.Status = {
    source = 'auto', -- 'auto' | 'framework' | 'internal'

    -- Internal decay (used when source == 'internal' or no framework found).
    -- Time in MINUTES it takes for hunger/thirst to drop from 100 -> 0.
    decayMinutesHunger = 50,
    decayMinutesThirst = 45,

    -- Reset values applied on respawn / revive (per spec).
    respawnHunger = 100.0,
    respawnThirst = 100.0,
}

-- =========================================================================
--  Voice (pma-voice)
--
--  STRICT, FIXED mapping per spec. Do not change unless you know what
--  you are doing.
-- =========================================================================
Config.Voice = {
    enabled  = true,

    -- Whether to draw a ground marker around the player on mode change.
    marker = {
        enabled       = true,
        showSeconds   = 2.5,   -- visible time after mode switch
        height        = 1.0,
        alpha         = 110,   -- 0-255
        pulseWhileTalking = true,
    },

    -- Fixed distances. DO NOT modify.
    distances = {
        whisper  = 1.5,
        normal   = 7.5,
        shouting = 15.0,
    },

    -- Colors are mirrored in CSS, but the marker also uses these.
    colors = {
        whisper  = { 200, 200, 200 }, -- gray
        normal   = {  70, 200, 110 }, -- green
        shouting = { 230,  70,  70 }, -- red
    },
}

-- =========================================================================
--  Ammo
-- =========================================================================
Config.Ammo = {
    enabled       = true,
    hideWhenEmpty = true, -- hide entirely when no weapon (per spec)
}

-- =========================================================================
--  Player ID
-- =========================================================================
Config.PlayerId = {
    enabled       = true,
    -- 'always' = always visible
    -- 'keyhold' = only while keybind is held
    visibility    = 'always',
    -- Default keybind name for "keyhold". Players can rebind via FiveM
    -- settings > Key Bindings > FiveM > lcp_hud_v4.
    keybindKey    = 'U',
    keybindLabel  = 'Show Player ID',
}

-- =========================================================================
--  Job
-- =========================================================================
Config.Job = {
    enabled    = true,
    showGrade  = true,
    -- Optional icon mapping by job name. Falls back to a generic icon.
    icons = {
        police   = 'shield',
        ambulance = 'plus',
        mechanic = 'wrench',
        taxi     = 'car',
        unemployed = 'user',
    },
}

-- =========================================================================
--  HUD Editor
-- =========================================================================
Config.Editor = {
    command       = 'hudeditor',
    resetCommand  = 'hudreset',
    snapToGrid    = true,
    gridSize      = 8, -- px
}

-- =========================================================================
--  Default element positions / scale (in CSS percent units).
--
--  These are used the first time the HUD runs. After that, the player's
--  saved layout from KVP is used.
-- =========================================================================
Config.Defaults = {
    status   = { x = 1.5,  y = 84.0, scale = 1.0, visible = true },
    voice    = { x = 50.0, y = 92.0, scale = 1.0, visible = true },
    ammo     = { x = 88.0, y = 88.0, scale = 1.0, visible = true },
    playerid = { x = 1.5,  y = 1.5,  scale = 1.0, visible = true },
    job      = { x = 12.0, y = 92.0, scale = 1.0, visible = true },
}
