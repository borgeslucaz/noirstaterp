fx_version 'cerulean'
game 'gta5'
lua54 'yes'
server_only 'yes'

name 'noir_illegal_core'
author 'Noir State'
description 'Server-authoritative criminal progression domain service'
version '0.1.0'

files {
    'migrations/*.sql',
}

shared_scripts {
    'shared/constants.lua',
    'shared/config.lua',
    'shared/levels.lua',
    'shared/unlocks.lua',
    'shared/activities.lua',
    'shared/permissions.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/logger.lua',
    'server/migrations.lua',
    'server/validators.lua',
    'server/cache.lua',
    'server/bridges/qbox.lua',
    'server/bridges/gangs.lua',
    'server/repositories/db.lua',
    'server/repositories/profile_repository.lua',
    'server/repositories/reputation_repository.lua',
    'server/repositories/heat_repository.lua',
    'server/repositories/unlock_repository.lua',
    'server/repositories/activity_repository.lua',
    'server/repositories/cooldown_repository.lua',
    'server/repositories/audit_repository.lua',
    'server/services/level_service.lua',
    'server/services/heat_service.lua',
    'server/services/idempotency_service.lua',
    'server/services/cooldown_service.lua',
    'server/services/eligibility_service.lua',
    'server/services/unlock_service.lua',
    'server/services/profile_service.lua',
    'server/services/activity_service.lua',
    'server/services/admin_service.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/init.lua',
}

dependencies {
    'qbx_core',
    'oxmysql',
    'noir_gangs',
}
