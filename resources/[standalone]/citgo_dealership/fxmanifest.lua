fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'citgo_dealership'
author 'Citgo'
description 'Vehicle dealership with uz_AutoShot thumbnails and glassmorphic UI'
version '1.0.0'

ui_page 'html/build/index.html'

files {
    'html/build/index.html',
    'html/build/**/*',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
    -- noir: uz_AutoShot fica opcional; sem ele as fotos vem do docs.fivem.net (client/main.lua)
}
