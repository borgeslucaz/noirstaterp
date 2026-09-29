fx_version 'cerulean'
game 'gta5'

author 'Noir'
description 'Lojas de NPC: carrinho, pagamento em dinheiro ou cartão'
version '1.0.0'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
    'ox_target',
}

shared_scripts {
    '@ox_lib/init.lua',
    'locales/*.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

client_exports {
    'OpenShop',
    'CloseShop'
}

ui_page 'html/ui.html'

files {
    'html/ui.html',
    'html/css/base.css',
    'html/css/shop.css',
    'html/css/admin.css',
    'html/fonts/*.woff2',
    'html/js/script.js',
    'html/js/ped_models.js',
    'html/images/*.png'
}
