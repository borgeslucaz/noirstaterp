fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_houserobbery'
author 'Noir; based on Qbox Project qbx_houserobbery'
description 'Noir Tier 1 residential burglary contracts.'
repository 'https://github.com/Qbox-project/qbx_houserobbery'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/integrations/burnerphone.lua',
    'server/integrations/dispatch.lua',
    'server/main.lua',
}

ui_page 'web/index.html'
nui_callback_strict_mode 'true'

files {
    'config/shared.lua',
    'config/client.lua',
    'config/server.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

dependencies {
    '/onesync',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'qbx_core',
    'noir_burnerphone',
    'peuren_minigames',
    'noir_shell',
}

-- OAL is intentionally not required by the NUI. Keep it disabled until the
-- resource's native calls have been audited independently.
-- use_experimental_fxv2_oal 'yes'
