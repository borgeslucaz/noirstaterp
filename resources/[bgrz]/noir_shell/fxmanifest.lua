fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_shell'
author 'Noir State'
description 'Reusable shell/interior spawning library'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/utils.lua',
    'client/collision.lua',
    'client/instance.lua',
    'client/manager.lua',
    'client/dev.lua',
}
