fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_burnerphone'
author 'Noir'
description 'Burner phone minimo para atividades ilegais.'
version '0.3.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_script 'server/main.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependency 'ox_lib'
