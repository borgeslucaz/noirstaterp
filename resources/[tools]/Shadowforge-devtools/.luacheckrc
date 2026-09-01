-- ShadowForge DevTools - luacheck config
-- See: https://luacheck.readthedocs.io/en/stable/config.html

std = "lua54"

-- FiveM globals. The lint action adds Cfx natives automatically, this covers the rest.
globals = {
    -- Resource lifecycle
    "GetCurrentResourceName",
    "GetResourceState",
    "GetResourcePath",
    "GetResourceMetadata",
    "GetNumResourceMetadata",
    "GetInvokingResource",

    -- Player / source
    "source",
    "PlayerData",
    "QBX",
    "QBCore",
    "ESX",

    -- ox_lib
    "lib",
    "cache",

    -- Common framework globals
    "exports",
    "GetGameTimer",

    -- ShadowForge global
    "SFD",
}

read_globals = {
    "vector2", "vector3", "vector4", "quat",
    "Citizen",
    "json",
    "promise",
    "msgpack",
}

-- Ignore some warnings that don't matter for FiveM scripts
ignore = {
    "212", -- Unused argument (common in event handlers)
    "213", -- Unused loop variable
    "611", -- Line contains only whitespace
    "612", -- Line contains trailing whitespace
    "614", -- Trailing whitespace in a comment
    "631", -- Line is too long
}

-- Per-file overrides
files["config.lua"] = {
    -- Config files define lots of globals intentionally
    ignore = { "111", "112", "113", "131" },
}

files["fxmanifest.lua"] = {
    -- fxmanifest has its own DSL (game, fx_version, etc.)
    ignore = { "111", "112", "113", "121", "122", "131" },
    globals = {
        "fx_version", "game", "games", "lua54",
        "name", "author", "description", "version", "repository",
        "client_script", "client_scripts",
        "server_script", "server_scripts",
        "shared_script", "shared_scripts",
        "dependency", "dependencies",
        "ui_page", "files", "data_file",
        "provide", "use_experimental_fxv2_oal",
        "rdr3_warning", "loadscreen", "loadscreen_manual_shutdown",
        "this_is_a_map", "server_only", "client_only",
        "convar_category",
    },
}

exclude_files = {
    ".github/",
    "docs/",
}

max_line_length = false
