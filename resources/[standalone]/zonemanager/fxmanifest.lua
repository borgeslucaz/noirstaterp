fx_version 'cerulean'
game 'gta5'
name 'zonemanager'
version '1.0.0'
description 'Polyzone editor and runtime zone engine.'
author 'Scrubz - github:itsxScrubz | discord:scrubz'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
nui_callback_strict_mode 'true'

-- config first so other files read config.framework at load. _-prefixed files
-- (_module.lua) sort ahead of lowercase siblings, so the module table is declared
-- before impl files attach. All other cross-file refs are call-time, so glob order
-- is otherwise safe.
shared_scripts {
    'config.lua',
    'shared/*.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}

ui_page 'ui/dist/index.html'

-- Framework adapters load at runtime per config.framework, so they are files{}
-- (readable by the loader), not auto-run scripts. The non-recursive client/server
-- globs already skip the subdir.
files {
    'client/framework/*.lua',
    'server/framework/*.lua',
    'data/zones.json',
    'ui/dist/index.html',
    'ui/dist/assets/*',
}
