fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ak4y-taxi'
description 'Noir State · Taxi Job (dispatcher NPC, taxímetro server-authoritative, HUD compacto)'
version '2.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'locales/*.json',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/state.lua',
    'client/ui.lua',
    'client/dispatch.lua',
    'client/npc.lua',
    'client/climate.lua',
    'client/client.lua',
    'editable/cl_utils.lua',
}

server_scripts {
    'serverConfig.lua',
    'server/00_security.lua',
    'server/sessions.lua',
    'server/dispatch.lua',
    'server/meter.lua',
    'server/server.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'bgrz_core',
}

-- Sem Asset Escrow: todo o código é aberto.
escrow_ignore {
    '*.lua',
    'client/*.lua',
    'server/*.lua',
    'editable/*.lua',
    'html/*',
    'locales/*.json',
}
