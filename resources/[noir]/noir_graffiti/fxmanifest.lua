fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_graffiti'
author 'Noir State'
description 'Graffiti de texto em paredes'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/graffiti.lua',
    'client/spray.lua',
    'client/placement.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/validation.lua',
    'server/store.lua',
    'server/territories.lua',
    'server/main.lua',
}

ui_page 'web/ui.html'

files {
    'web/ui.html',
    'web/scene.html',
    'web/measure.js',
    'web/scene-assets/fonts/*',
}

dependencies {
    'bgrz_core',
    'ox_lib',
    'ox_inventory',
    'oxmysql',
}
