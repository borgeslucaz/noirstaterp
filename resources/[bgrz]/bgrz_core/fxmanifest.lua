fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'BGRZ'
description 'BGRZ Core - abstraction layer over Qbox'
version '0.2.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/config.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/qbox_bridge.lua'
}

server_scripts {
    'server/character.lua',
    'server/vehicle_keys.lua',
    'server/qbox_bridge.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'qbx_core',
    'qbx_vehiclekeys'
}
