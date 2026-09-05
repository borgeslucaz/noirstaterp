fx_version 'cerulean'
game 'gta5'

author 'Grot RP'
description 'Fast Mechanic System'
version '1.0.0'

shared_scripts {
    'locales/init.lua',
    'locales/en.lua',
    'locales/pl.lua',
    'locales/pt-br.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
