fx_version 'cerulean'
game 'gta5'

name 'noir_outposts'
author 'Noir State'
description 'Outposts e venda passiva por dealers NPC'
version '0.1.0'

ox_lib 'locale'

ui_page 'html/index.html'
nui_callback_strict_mode 'true'

files {
    'config/shared.lua',
    'config/client.lua',
    'locales/*.json',
    'html/index.html',
    'html/styles.css',
    'html/app.js',
    'html/fonts/*.woff2',
    'html/phone/index.html',
    'html/phone/phone.css',
    'html/phone/phone.js',
    'html/phone/icon.svg',
    'migrations/*.sql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/constants.lua',
    'shared/validators.lua',
}

client_scripts {
    'client/main.lua',
    'client/entities.lua',
    'client/interaction.lua',
    'client/ui.lua',
    'client/phone.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/log.lua',
    'server/integration.lua',
    'server/security.lua',
    'server/repositories/db.lua',
    'server/repositories/outpost_repository.lua',
    'server/repositories/dealer_repository.lua',
    'server/repositories/stock_repository.lua',
    'server/repositories/operation_repository.lua',
    'server/repositories/rotation_repository.lua',
    'server/state.lua',
    'server/sessions.lua',
    'server/entity_manager.lua',
    'server/services/notification_service.lua',
    'server/services/rotation_service.lua',
    'server/services/claim_service.lua',
    'server/services/dealer_service.lua',
    'server/services/stock_service.lua',
    'server/services/sale_service.lua',
    'server/services/robbery_service.lua',
    'server/scheduler.lua',
    'server/api.lua',
    'server/init.lua',
}

dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
    'bgrz_core',
}
