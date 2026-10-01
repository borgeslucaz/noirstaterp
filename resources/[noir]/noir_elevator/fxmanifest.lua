fx_version 'cerulean'
game 'gta5'

name 'noir_elevator'
author 'Noir State'
description 'Elevador com porta fechada, contador de andar e viagem sem teleporte à vista'
version '0.1.0'

ox_lib 'locale'

shared_script '@ox_lib/init.lua'

-- Só client: é deslocamento do próprio jogador dentro de um prédio, sem regra nem recompensa.
client_script 'client/main.lua'

files {
    'config/client.lua',
    'client/integrations.lua',
    'client/travel.lua',
    'locales/*.json',
}

-- `ox_target` é chamado direto (§2.5) e por isso está declarado.
dependencies {
    'ox_lib',
    'ox_target',
}
