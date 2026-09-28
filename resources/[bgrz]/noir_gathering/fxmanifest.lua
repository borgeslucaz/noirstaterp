fx_version 'cerulean'
game 'gta5'

name 'noir_gathering'
author 'Noir State'
description 'Rotas de coleta criadas em jogo (fork do mri_Qfarm)'
version '1.1.0'

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
    'shared/rules.lua',
    'client/integrations.lua',
    'client/collect.lua',
    'client/carry.lua',
    'client/haul.lua',
    'client/npc.lua',
    'client/placement.lua',
    'client/creator.lua',
    'locales/*.json',
}

-- `qbx_core`, `ox_inventory` e `ox_target` são providers do bgrz_core e não aparecem
-- aqui (§6.2). `noir_illegal_core` e `noir_gangs` são opcionais: consultados na hora, e
-- sem eles a rota com requisito não abre e o olheiro não avisa ninguém.
dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
    'bgrz_core',
    'noir_lib',
}
