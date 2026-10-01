fx_version 'cerulean'
game 'gta5'

name 'noir_gunanims_test'
description 'Menu de teste das animações do ND_GunAnims (/testanims, só admin).'
version '0.1.0'

shared_script '@ox_lib/init.lua'
client_script 'client.lua'
server_script 'server.lua'

dependencies { 'ox_lib', 'ND_GunAnims' }
