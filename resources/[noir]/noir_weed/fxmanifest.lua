fx_version 'cerulean'
game 'gta5'

name 'noir_weed'
author 'Noir State'
description 'Plantio, baseado e mesa de embalar (fork do uniq-weedsystem e do it-drugs, GPL-3.0)'
version '1.2.0'

ox_lib 'locale'

ui_page 'web/index.html'

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
    'client/actions.lua',
    'client/objects.lua',
    'client/placement.lua',
    'client/plants.lua',
    'client/tables.lua',
    'client/grinder.lua',
    'client/packing.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/fonts/*.woff2',
    'web/sounds/*.ogg',
}

-- Modelos em `stream_enhanced/` (formato Enhanced: ydr v159, ytd v5). Os archetypes
-- vêm dos ytyp; ydr e ytd não precisam de data_file.
data_file 'DLC_ITYP_REQUEST' 'stream_enhanced/weed_empty_pot.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream_enhanced/an_weed.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream_enhanced/freeze_it-drugs_table.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream_enhanced/mushroom_base.ytyp'

-- `qbx_core` e `ox_inventory` são providers do bgrz_core e não aparecem aqui (§6.2).
-- `ox_target` é chamado direto (§2.5) e por isso está declarado.
dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
    'bgrz_core',
    'ox_target',
}
