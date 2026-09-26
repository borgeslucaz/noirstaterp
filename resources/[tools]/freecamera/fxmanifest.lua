fx_version 'cerulean'
game 'gta5'

author 'Lyla'
description 'Freecam'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'config.lua'
}

shared_script '@ox_lib/init.lua' -- NOIR: clipboard e notify do /capturarcena

client_scripts {
    'config.lua',
    'client.lua',
    'noir_capturarcena.lua', -- NOIR: ver PATCHES-NOIR.md
}