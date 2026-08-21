fx_version 'cerulean'
game 'gta5'

author 'BGRZ'
description 'BGRZ Core - abstraction layer over Qbox'
version '0.1.0'

shared_scripts {
    'shared/config.lua'
}

server_scripts {
    'server/character.lua',
    'server/main.lua'
}

dependency 'qbx_core'
