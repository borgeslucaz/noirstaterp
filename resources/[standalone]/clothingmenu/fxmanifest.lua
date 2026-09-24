fx_version 'cerulean'
game 'gta5'
author 'SP-Scripts'
description 'Menu de roupas'
version '1.1.0'

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js'
}

client_scripts {
    'config.lua',
    'bridge/init.lua',
    'client/main.lua'
}

server_scripts {
    'config.lua',
    'bridge/init.lua',
    'server/main.lua'
}

shared_script {
    '@ox_lib/init.lua'
}

dependencies {
    'ox_lib',
    'ox_target'
}
