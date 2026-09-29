fx_version 'cerulean'
game 'gta5'
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
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/state.lua', 'server/members.lua', 'server/main.lua' }

-- Framework e target chegam pelo bgrz_core; declarar qbx_core ou ox_target aqui
-- reabriria o acoplamento que o bridge existe para fechar.
--
-- `noir_territories` não está aqui de propósito: o mapa é informação de apoio e a aba sabe
-- explicar a ausência. Declarar a dependência faria a gestão de gang inteira deixar de
-- subir por causa de uma tela de território.
--
-- `/onesync` está aqui porque o resource depende dele de verdade: a validação de distância
-- do convite roda no servidor (`GetPlayerPed` + `GetEntityCoords`) e a gang do jogador é
-- publicada no state bag de `Player(source)`. Sem OneSync os dois falham em runtime, e
-- falhar no start é melhor do que descobrir no primeiro convite.
dependencies { '/onesync', 'ox_lib', 'oxmysql', 'bgrz_core' }
