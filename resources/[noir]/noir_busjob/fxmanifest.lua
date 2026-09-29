fx_version 'cerulean'
game 'gta5'

author 'Noir State'
description 'Noir State public transport career'
version '2.0.0'

ox_lib 'locale'

ui_page 'html/index.html'

-- `require` no client lê por LoadResourceFile: todo módulo do client precisa estar aqui.
-- `config/server.lua`, `data/seed.lua` e `server/` ficam de fora de propósito (§19.1).
files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/editor.js',
    'html/editor.css',
    'html/map.js',
    'html/map.css',
    'html/vendor/leaflet.js',
    'html/vendor/leaflet.css',
    'html/fonts/*.woff2',
    'locales/*.json',
    'config/shared.lua',
    'shared/rules.lua',
    'client/integrations.lua',
    'client/placement.lua',
    'client/editor.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- `ox_target` é chamado direto (§2.5) e por isso está declarado; `noir_lib` mostra as
-- teclas dos modos do editor. `noir_territories` é opcional: só o mapa de debug usa os tiles
-- dele, e sem ele o mapa avisa em vez de abrir.
dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
    'bgrz_core',
    'ox_target',
    'noir_lib',
}
