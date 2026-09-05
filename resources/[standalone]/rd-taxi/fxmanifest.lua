fx_version 'cerulean'
game 'gta5'

author 'RoxDev'
description 'RD-Taxi Service'
version '1.0.0'

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'client/zones.lua',
    'client/main.lua',
    'server/main.lua',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

shared_scripts {
    'config.lua',
    'locales/en.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/zones.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*',
    'html/sounds/*.mp3',
    'locales/*.lua'
}

dependency '/assetpacks'