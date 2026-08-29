fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_graffiti'
author 'Noir State / Peak Studios renderer'
description 'Focused text graffiti for Qbox'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/renderer.lua',
    'client/placement.lua',
    'client/target.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/validation.lua',
    'server/persistence.lua',
    'server/admin.lua',
    'server/main.lua',
}

ui_page 'web/scene.html'

files {
    'web/scene.html',
    'web/assets/*.js',
    'web/assets/*.css',
    'web/scene-assets/fonts/*',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql',
}
