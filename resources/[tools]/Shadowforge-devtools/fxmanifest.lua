fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'shadowforge-devtools'
author      'ShadowForge'
description 'Free, open-source in-game developer panel for FiveM (Standalone / Qbox / QBCore / ESX).'
version     '1.0.0'
repository  'https://github.com/shadowforge/shadowforge-devtools'

dependency 'ox_lib'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'modules/clipboard.lua',
    'modules/ui.lua',
    'modules/entity_inspector.lua',
    'modules/coords.lua',
    'modules/zone_builder.lua',
    'modules/object_placer.lua',
    'modules/vehicle_tools.lua',
    'modules/ped_tools.lua',
    'modules/player_tools.lua',
    'modules/world_tools.lua',
    'modules/resource_tools.lua',
    'modules/debug_tools.lua',
    'modules/exports_generator.lua',
    'client.lua',
}

server_scripts {
    'server.lua',
}

files {
    'README.md',
    'CHANGELOG.md',
    'LICENSE',
    'docs/permissions.md',
    'docs/config.md',
    'docs/examples.md',
}

provide 'shadowforge-devtools'
