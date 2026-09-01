fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lcp_hud_v4'
description 'Modern, modular FiveM HUD with dual-circle status, voice range, ammo, job, player ID, and a full in-game HUD editor.'
author 'lcp / Contentlos'
version '4.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*.svg',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/bridge.lua',
    'client/main.lua',
    'client/status.lua',
    'client/voice.lua',
    'client/voice_marker.lua',
    'client/ammo.lua',
    'client/job.lua',
    'client/playerid.lua',
    'client/editor.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    -- pma-voice is optional. Listed here so users get a hint if they forget it.
    -- Remove or replace with your own voice resource if needed.
    -- '/pma-voice',
}
