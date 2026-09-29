fx_version 'cerulean'
game 'gta5'

authors { "L'kid" }
description "Imperial by Tidemo, FiveM ressource made by L'kid"
version '1.1'

lua54 'yes'

files {
    'data/**/*.meta',
}

data_file 'HANDLING_FILE' 'data/**/handling*.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/**/vehicles*.meta'
data_file 'CARCOLS_FILE' 'data/**/carcols*.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations*.meta'

client_scripts {
    'vehicle_names.lua',
}