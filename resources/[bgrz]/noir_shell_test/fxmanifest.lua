fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_shell_test'
author 'Noir State'
description 'Throwaway test script: ox_target to spawn/enter/exit the lev-apartments shell'
version '0.0.1'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'lev-apartments',
    'noir_shell',
}
