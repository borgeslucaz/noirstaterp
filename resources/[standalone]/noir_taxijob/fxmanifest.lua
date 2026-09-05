fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_taxijob'
description 'Noir State · Taxi V2 (central com perfil, Confiança, ranking e catálogo; dispatcher NPC e taxímetro server-authoritative)'
version '2.1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/fonts/*.woff2',
    'html/img/vehicles/*.png',
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
    'client/rental.lua',
    'client/central.lua',
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'serverConfig.lua',
    'server/00_security.lua',
    'server/sessions.lua',
    'server/progression.lua',
    'server/ranking.lua',
    'server/central.lua',
    'server/rental.lua',
    'server/dispatch.lua',
    'server/meter.lua',
    'server/server.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql',
    'qbx_core',
    'bgrz_core',
}

-- Sem Asset Escrow: todo o código é aberto.
escrow_ignore {
    '*.lua',
    'client/*.lua',
    'server/*.lua',
    'html/*',
    'locales/*.json',
    'migrations/*.sql',
}
