fx_version 'cerulean'
game 'gta5'

author 'BGRZ'
description 'NPC interaction showcase for envi-interact'
version '0.1.0'


shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}
client_script 'client/main.lua'

dependencies {
    'ox_lib',
    'envi-interact',
    'bgrz_core'
}
