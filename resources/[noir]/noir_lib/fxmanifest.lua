fx_version 'cerulean'
game 'gta5'

name 'noir_lib'
author 'Noir State'
description 'Componentes compartilhados da Noir State (teclas visíveis e fala de ped do DESIGN_v4)'
version '1.0.0'

ui_page 'web/index.html'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/keyhints.lua',
    'client/pedspeech.lua',
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/fonts/*.woff2',
}

dependencies {
    'ox_lib',
}

use_experimental_fxv2_oal 'yes'
