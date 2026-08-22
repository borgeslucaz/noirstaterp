fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_multichar'
author 'Noir State'
description 'Noir State multicharacter selection resource'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/playerdata.lua',
    'shared.lua'
}


client_scripts {
    'util/util.lua',
    'Framework/qb/client.lua',
    'Framework/esx/client.lua',
    'Framework/qbx/client.lua',
    'modules/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'Framework/qbx/server.lua',
    'Framework/qb/server.lua',
    'Framework/esx/server.lua',
}

escrow_ignore {
    'Framework/qb/client.lua',
    'Framework/esx/client.lua',
    'Framework/qbx/client.lua',
    'util.lua',
    'shared.lua'
}

ui_page 'ui/dist/index.html'

files {
    'ui/dist/index.html',
    'ui/dist/assets/*.css',
    'ui/dist/assets/*.js',
    'ui/dist/assets/*.png',
    'ui/images/*.png',
    'ui/dist/assets/*.gif',
    'ui/dist/assets/*.ttf',
    'ui/dist/assets/*.otf',
    'ui/dist/*.svg',
}


provide 'esx_multicharacter'
