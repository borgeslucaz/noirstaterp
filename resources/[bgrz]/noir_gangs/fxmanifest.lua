fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'noir_gangs'
author 'Noir State'
description 'Immersive Qbox gang management'
version '1.1.0'

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/state.lua', 'server/main.lua' }

-- Framework e target chegam pelo bgrz_core; declarar qbx_core ou ox_target aqui
-- reabriria o acoplamento que o bridge existe para fechar.
dependencies { 'ox_lib', 'oxmysql', 'bgrz_core' }
