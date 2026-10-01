fx_version 'cerulean'
game 'gta5'

name 'noir_colprobe'
description 'Diagnóstico de colisão (só admin): /colprobe mede o que bate na frente do personagem; /colview desenha a colisão do mrp_house em volta.'
version '0.2.0'

shared_script '@ox_lib/init.lua'
client_scripts {
    'data_mrp_house.lua',
    'client.lua',
    'colview.lua',
}
server_script 'server.lua'

dependencies { 'ox_lib' }
