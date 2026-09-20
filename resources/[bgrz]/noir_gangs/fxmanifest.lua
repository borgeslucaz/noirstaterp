fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'noir_gangs'
author 'Noir State'
description 'Immersive Qbox gang management'
version '1.2.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/fonts/*.woff2',
    'html/vendor/leaflet.js',
    'html/vendor/leaflet.css',
}

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts { 'client/ui.lua', 'client/setup.lua', 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/state.lua', 'server/main.lua' }

-- Framework e target chegam pelo bgrz_core; declarar qbx_core ou ox_target aqui
-- reabriria o acoplamento que o bridge existe para fechar.
--
-- `noir_territories` não está aqui de propósito: o mapa é informação de apoio e a aba sabe
-- explicar a ausência. Declarar a dependência faria a gestão de gang inteira deixar de
-- subir por causa de uma tela de território.
dependencies { 'ox_lib', 'oxmysql', 'bgrz_core' }
