fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_tireslash'
author 'Noir State'
description 'Target based tire slashing'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'ox_lib',
    'ox_target',
}
