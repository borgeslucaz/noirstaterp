fx_version 'cerulean'
game 'gta5'

name 'noir_chat'
author 'Noir State RP, adapted from Cfx.re chat'
description 'Drop-in CFX chat replacement without a default visibility keybind.'
version '1.0.0'

provide 'chat'

ui_page 'dist/ui.html'

shared_script 'config.lua'
client_script 'cl_chat.lua'
server_script 'sv_chat.lua'

files {
    'dist/ui.html',
    'dist/index.css',
    'dist/chat.js',
    'html/vendor/*.css',
    'html/vendor/fonts/*.woff2',
}

nui_callback_strict_mode 'true'
