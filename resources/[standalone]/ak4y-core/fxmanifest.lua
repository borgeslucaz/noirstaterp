fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ak4y-core'
author 'Noir'
version '0.0.1'
description 'QBX compatibility shim exposing the ak4y-core export surface (player, money, sql, callbacks, spawn) on top of qbx_core and oxmysql.'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
