fx_version 'cerulean'
game 'gta5'

name 'noir_garage'
author 'Noir State'
description 'Garagens da Noir State: logica do qbx_garages com a interface do rhd_garage'
version '1.0.0'

ox_lib 'locale'

ui_page 'web/build/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/*.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/cam.lua',
    'client/preview.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/default-calculate-impound-fee.lua',
    'server/main.lua',
    'server/spawn-vehicle.lua',
    'server/services.lua',
}

files {
    'config/client.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/assets/*',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'qbx_vehicles',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
