fx_version 'cerulean'
game 'gta5'

name 'noir_territories'
author 'Noir State'
description 'Áreas de gang: alertas por zona do Zone Manager e domínio por graffiti'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/claims.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/claims.lua',
    'client/zones.lua',
    'client/map.lua',
}

ui_page 'web/map.html'

files {
    'web/map.html',
    'web/leaflet.js',
    'web/leaflet.css',
    'web/tiles/**/*.png',
}

server_scripts {
    'server/main.lua',
    'server/claims.lua',
    'server/zones.lua',
}

dependencies {
    'qbx_core',
    'bgrz_core',
    'ox_lib',
    'zonemanager',
}
