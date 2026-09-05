fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'JericoFX'
description 'Complete mechanic job with realistic damage, inspection, and management'
version '1.1.1'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua'
}

client_scripts {
    'client/commands.lua',
    'client/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/init.lua'
}

files {
    'locales/*.json',
    'client/commands.lua',
    'client/modules/*.lua',
    'client/modules/fluid/*.lua'
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'ox_target'
}

server_script 'version_check.lua'
