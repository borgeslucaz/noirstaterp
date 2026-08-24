fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'noir_gangs'
author 'Noir State'
description 'Immersive Qbox gang management'
version '1.0.0'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
dependencies { 'qbx_core', 'ox_lib', 'oxmysql', 'ox_target' }
