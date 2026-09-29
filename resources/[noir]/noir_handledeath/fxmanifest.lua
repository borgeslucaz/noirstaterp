fx_version 'cerulean'
game 'gta5'

name 'noir_handledeath'
author 'Noir State'
description 'Noir tela de morte e medico NPC'
version '1.0.0'

ox_lib 'locale'

ui_page 'web/build/index.html'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/screen.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'config/shared.lua',
    'client/doctor.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/**/*',
}

dependencies {
    'ox_lib',
    'bgrz_core',
}

lua54 'yes'
