fx_version 'cerulean'
game 'gta5'

name 'noir_weed'
author 'Noir State'
description 'Plantio de maconha em vaso (fork do uniq-weedsystem, GPL-3.0)'
version '1.0.0'

ox_lib 'locale'

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

-- `require` no client lê por LoadResourceFile: todo módulo do client precisa estar
-- aqui. `config/server.lua` e `server/` ficam de fora de propósito (§19.1).
files {
    'config/shared.lua',
    'client/integrations.lua',
    'client/placement.lua',
    'locales/*.json',
}

-- `qbx_core` e `ox_inventory` são providers do bgrz_core e não aparecem aqui (§6.2).
-- `ox_target` é chamado direto (§2.5) e por isso está declarado.
dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
    'bgrz_core',
    'ox_target',
}
