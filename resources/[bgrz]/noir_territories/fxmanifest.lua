fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_territories'
author 'Noir State'
description 'Gang territory entry alerts backed by Zone Manager'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_script 'server/main.lua'

dependencies {
    'qbx_core',
    'ox_lib',
    'zonemanager',
}
