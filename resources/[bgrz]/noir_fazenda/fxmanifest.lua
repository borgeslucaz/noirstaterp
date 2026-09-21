fx_version 'cerulean'
game 'gta5'
lua54 'yes'
server_only 'yes'

name 'noir_fazenda'
author 'Noir State'
description 'Receita: ledger de movimentação e apuração de imposto de renda'
version '0.1.0'

-- `server_only` é literal: não existe client nem NUI. A Receita é um serviço de
-- domínio, e alíquota, base de cálculo e dívida nunca devem chegar ao cliente
-- (§19.1).

files {
    'migrations/*.sql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/constants.lua',
    'shared/config.lua',
    'shared/rules.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/logger.lua',
    'server/migrations.lua',
    'server/storage.lua',
    'server/bridges/banking.lua',
    'server/services/ledger_service.lua',
    'server/services/treasury_service.lua',
    'server/services/assessment_service.lua',
    'server/services/payment_service.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/init.lua',
}

-- O banco NÃO é declarado aqui de propósito. Este resource não conhece o provider
-- de banking: ele escuta `bgrz_core:bankMovement` e chama exports do bridge. Quem
-- depende do banco é o `bgrz_core` (§6.2).
dependencies {
    'ox_lib',
    'oxmysql',
    'bgrz_core',
}
