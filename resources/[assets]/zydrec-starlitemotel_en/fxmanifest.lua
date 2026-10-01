fx_version 'cerulean'
games {'gta5'}
this_is_a_map 'yes'

author 'Zydrec' -- discord for support: https://discord.gg/zhjdFVVAWG
version '1.1.0'
description 'The Starlite motel located in East Vinewood'

files {
  'zydrec_starlitemotel_tc_list.xml',
}

data_file 'TIMECYCLEMOD_FILE' 'zydrec_starlitemotel_tc_list.xml'
server_script 'version_check.lua'

escrow_ignore {
  'stream/**/*',
  'version_check.lua'
}