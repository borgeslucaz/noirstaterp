fx_version 'cerulean'
game 'gta5'

author 'Noir State'
description 'Noir State public transport career'
version '1.0.0'

ox_lib 'locale'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/fonts/*.woff2',
    'locales/*.json',
    'migrations/001_initial.sql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql',
    'bgrz_core',
}
