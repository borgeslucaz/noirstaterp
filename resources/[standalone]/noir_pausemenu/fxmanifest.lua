fx_version 'cerulean'
game 'gta5'

author 'Noir'
description 'Noir Pause Menu'

lua54 'on'

version '1.0.0'

ui_page 'ui/dist/index.html'

files {
    'ui/dist/assets/**/*.*',
    'ui/dist/*.*',
}

shared_scripts {
    'shared/config.lua',
    'shared/locales/*.lua',
    'shared/framework.lua',
    '@ox_lib/init.lua',
}

client_scripts {
    'client/camera.lua',
    'client/animations.lua',
    'client/photomode.lua',
    'client/main.lua',
    'client/nui.lua',
}

client_exports {
    'IsPhotomodeActive',
    'IsPauseMenuOpen',
}

server_scripts {
    'server/main.lua',
}

escrow_ignore {
    'shared/config.lua',
    'shared/locales/*.lua',
    'shared/framework.lua',
    'client/camera.lua',
    'client/animations.lua',
    'client/photomode.lua',
    'client/main.lua',
    'client/nui.lua',
    'server/main.lua',
}
dependency '/assetpacks'
