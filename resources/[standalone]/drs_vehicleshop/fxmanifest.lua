fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DRS; based on QR Development qr-vehicleshop'
description 'DRS Vehicle Shop - secure multi-framework vehicle dealership system'
version '1.0.1-drs.9'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
    -- 'config-addons.lua': desligado aqui. Os modelos addon nao existem no servidor nem no
    -- qbx_core/shared/vehicles.lua, e o qbx_garages quebra ao listar carro fora dessa tabela.
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/carbrands/*.webp',
    'html/assets/plates/*.png',
    'html/assets/shops/*.webp',
    'html/assets/shops/*.svg',
    'html/assets/vehicles/*.png',
    'html/assets/vehicles/*.webp'
}

dependencies {
    'ox_lib',
    'oxmysql',
    '/onesync'
}
