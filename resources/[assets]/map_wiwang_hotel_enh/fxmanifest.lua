
fx_version "cerulean"
games { 'gta5' }

author 'Floky'

this_is_a_map 'yes'

dependencies {
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
}

client_scripts {
  'ipl.lua',
  'elevators.lua',
}

lua54 'yes'



data_file 'AUDIO_GAMEDATA' 'audio/floky_wiwang_doors_game.dat'
data_file 'AUDIO_GAMEDATA' 'audio/8F55E056_game.dat'

files {
  'audio/floky_wiwang_doors_game.dat151.rel',
  'audio/8F55E056_game.dat151.rel',
}
