fx_version 'cerulean'
game 'gta5'

name 'noir_skills'
author 'Noir State'
description 'Habilidades de personagem: XP, níveis e painel'
version '1.0.0'

-- A curva de XP é shared de propósito: o cliente guarda o XP bruto e calcula nível e
-- progresso com a mesma matemática do servidor, então abrir o painel ou ler um export
-- não custa uma ida ao servidor.
shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/xp.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/store.lua',
    'server/main.lua',
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*',
}

-- Framework e notificação chegam pelo bgrz_core; declarar qbx_core aqui reabriria o
-- acoplamento que o bridge existe para fechar.
dependencies { 'ox_lib', 'oxmysql', 'bgrz_core' }
