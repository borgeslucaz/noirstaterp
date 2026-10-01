fx_version 'cerulean'
game 'gta5'

name 'noir_minigames'
author 'Noir State'
description 'Minigames do servidor num lugar só: os próprios, ponte para os outros e menu de teste'
version '0.1.0'

ox_lib 'locale'

ui_page 'html/index.html'

-- config/client.lua e shared/catalogue.lua vão para o jogador (require no cliente);
-- config/server.lua não.
files {
    'html/index.html',
    'html/css/*.css',
    'html/css/games/*.css',
    'html/js/*.js',
    'html/js/games/*.js',
    'html/fonts/*.woff2',
    'config/client.lua',
    'shared/catalogue.lua',
    'locales/*.json',
}

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/play.lua',
    'client/menu.lua',
}

server_scripts {
    'server/main.lua',
}

-- Os outros fornecedores (ps_lib, peuren_minigames, rep-enginewire, mhacking,
-- safecracker, ultra-voltlab) são opcionais: conferidos por GetResourceState na hora
-- de jogar e mostrados como parados no menu.
dependencies {
    'ox_lib',
}
