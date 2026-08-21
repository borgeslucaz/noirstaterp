fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'cx-hud'
author      'Cxsper'
description 'this is a hud i guess'
version     '1.2.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/vehicle.css',
    'html/menu.css',
    'html/app.js',
    'html/vehicle.js',
    'html/hud-menu.js',
    'html/editor.css',
    'html/editor.js',
    'stream/minimap.gfx',
    'stream/minimap.ytd',
    'stream/squaremap.ytd',

    -- Module files. Loaded by client/main.lua via LoadResourceFile +
    -- load(), preserving cx-hud's original `return function(deps) end`
    -- factory pattern (previously fetched through ox_lib's lib.load).
    'client/utils.lua',
    'client/minimap.lua',
    'client/vehicle.lua',
    'client/weapon_data.lua',
    'client/weapon.lua',
    'client/seatbelt.lua',
    'client/lights.lua',
    'client/status.lua',
    'client/nui.lua',
    'client/events.lua',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    -- Only main.lua is auto-loaded; it pulls in every other module
    -- explicitly via the loadModule helper at the top of the file.
    'client/main.lua',
}

server_scripts {
    'server/version.lua',
}

optional_dependencies {
    'jg-stress-addon',
}