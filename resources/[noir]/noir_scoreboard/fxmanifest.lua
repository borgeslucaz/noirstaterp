fx_version 'cerulean'
game 'gta5'

name 'noir_scoreboard'
author 'Noir State'
description 'Placar da cidade e tabela pública de policiamento mínimo por crime'
version '1.0.0'
-- Fork do qbx_scoreboard (GPL-3.0, https://github.com/Qbox-project/qbx_scoreboard).

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'web/index.html'

-- `config/server.lua` e `server/` ficam fora: a tabela de crimes só chega ao jogador
-- pela callback, e só para quem está numa gang (§19.1).
files {
    'config/client.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/fonts/*.woff2',
}

-- `noir_police` é quem conta a polícia em serviço; sem ele nenhum crime libera.
dependencies {
    'ox_lib',
    'bgrz_core',
    'noir_police',
}
