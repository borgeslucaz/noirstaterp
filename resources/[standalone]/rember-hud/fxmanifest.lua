fx_version 'cerulean'
games { 'gta5', 'rdr3' }   -- runs on BOTH FiveM and RedM. Set Config.Game to
                           -- 'rdr3' for RedM so the correct native stats are read
                           -- (RDR2 uses attribute cores + mounts; no armor).

author 'Rember'
description 'Rember HUD — a component-based, data-driven standalone HUD'
version '0.1.0'

ui_page 'html/index.html'

client_scripts {
  'config.lua',
  'client.lua',
}

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
}
