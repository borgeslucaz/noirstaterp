fx_version "cerulean"
game "gta5"
lua54 'yes'

ui_page 'html/index.html'
files {
	'html/index.html',
	'html/img/*.jpg',
	'html/img/icons/*.png',
    'html/img/*.png',
	'html/sound/*.ogg',
	'html/fonts/*.ttf',
	'html/fonts/*.otf',
	'html/*.js',
	'html/*.css',
}

shared_scripts {
    'config.lua',
    'locales/*.lua',
}

client_scripts { 
    "editable/cl_utils.lua",
    "client/client.lua"
}

server_scripts {
    "server/00_security.lua",
    "server/server.lua",
    "serverConfig.lua",
}

escrow_ignore {
    "client/client.lua",
    "server/server.lua",
    "server/00_security.lua",

    "editable/cl_utils.lua",
    "locales/*.lua",
    "config.lua",
    "serverConfig.lua",
}

depedency 'ak4y-core'
dependency '/assetpacks'