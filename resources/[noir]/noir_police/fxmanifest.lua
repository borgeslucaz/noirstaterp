fx_version 'cerulean'
game 'gta5'

name 'noir_police'
author 'Noir State'
description 'Polícia: algema, escolta, evidência, apreensão, frota e vigilância. Base: ND_Police (GPL-3.0).'
version '0.1.0'
license 'GPL-3.0'

-- `lua54 'yes'` não aparece de propósito: Lua 5.4 já é o padrão nos artifacts atuais.

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- `require` no cliente lê por LoadResourceFile: todo módulo do cliente precisa estar
-- aqui. `config/server.lua` e `server/` ficam de fora: é onde moram tetos, limites e
-- regras anti-exploit (§19.1 do SCRIPT_GOOD_PRACTICES).
files {
    'config/shared.lua',
    'config/outfits.lua',
    'shared/*.lua',
    'client/integrations.lua',
    'client/util.lua',
    'client/layout.lua',
    'client/placement.lua',
    'client/modules/*.lua',
    'locales/*.json',
}

-- A mira de uma mão do escudo (Gang1H) vem do ND_GunAnims ([standalone]), como no ND.

-- Props do ND convertidos para o Enhanced (RSC7 v159). O áudio segue em
-- `assets/pending_audio` até ser testado (ver README); quando for, descomentar:
data_file 'DLC_ITYP_REQUEST' 'stream_enhanced/cuffs_main.ytyp'
-- data_file 'AUDIO_WAVEPACK' 'audiodirectory'
-- data_file 'AUDIO_SOUNDDATA' 'audiodata/nd_police.dat'

-- `qbx_core` e `ox_inventory` para jogador, dinheiro e itens passam pelo `bgrz_core`.
-- `ox_target` é a exceção do §2.5. `ox_inventory` também é declarado porque os hooks,
-- stash e container são chamados direto (ver server/integrations.lua).
dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
    'bgrz_core',
    'ox_target',
    'ox_inventory',
}
