fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'noir_guncraft'
author 'Nmil4 (upstream) / Noir State'
description 'Bancadas de crafting com customizacao de armas. Fork de Nmil4/n4-crafting.'
version '1.1.0'

dependencies {
    'object_gizmo'
}

optional_dependencies {
    'qb-core',
    'qbx_core',
    'ox_inventory',
    'qb-target',
    'ox_target',
    'interact'
}

ui_page 'web/index.html'

shared_scripts {
    'shared/systems.lua',
    'shared/config.lua',
    'shared/weapons.lua'
}

client_scripts {
    'client/camera.lua',
    'client/client_events.lua',
    'client/ui_handlers.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/discord.lua',
    'server/access.lua',
    'server/server_events.lua',
    'server/crafting_logic.lua',
    'server/weapon_attachments.lua'
}

files {
	'web/index.html',
	'web/assets/*',
	'config/recipes.lua',
	'config/blueprints.lua',
	'theme.json'
}