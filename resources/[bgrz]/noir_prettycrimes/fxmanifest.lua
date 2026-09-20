fx_version 'cerulean'
game 'gta5'

name 'noir_prettycrimes'
author 'Noir State'
description 'Container modular de pequenos crimes de rua'
version '1.3.0'

-- `lua54 'yes'` não aparece aqui de propósito: a Cfx.re marcou a diretiva como
-- deprecated, porque Lua 5.4 já é o runtime padrão em artifacts modernos.

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
}

-- Só os pontos de entrada entram como script. Todo o resto é módulo carregado com
-- `require`, e é isso que permite um crime desligado nem ter o arquivo lido.
client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

-- `require` no client lê por LoadResourceFile, então todo módulo que o client
-- carrega precisa estar listado aqui.
--
-- Repare no que NÃO está:
--   * nada de `server/` — mandaria a lógica de validação para o cliente;
--   * nem `config/server.lua`, nem `config/smashgrab_server.lua` — é onde moram
--     loot tables, rate limit e regra anti-exploit, que o §19.1 do
--     SCRIPT_GOOD_PRACTICES manda manter fora do que é enviado ao jogador.
files {
    'config/shared.lua',
    'config/smashgrab.lua',
    'config/parkingmeter.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/smashgrab_rules.lua',
    'shared/parkingmeter_rules.lua',
    'client/integrations.lua',
    'client/crimes/*.lua',
    'client/crimes/smashgrab/*.lua',
    'client/crimes/parkingmeter/*.lua',
    'locales/*.json',
}

-- `qbx_core` e `ox_inventory` não são declarados aqui: toda interação com eles
-- passa pelo `bgrz_core`, e os providers são dependência DELE. É o que o §6.2 do
-- SCRIPT_GOOD_PRACTICES pede do consumidor.
--
-- `ox_target` é a exceção, e está declarado porque virou dependência de verdade:
-- o alvo por model do parquímetro chama `exports.ox_target:addModel` direto, por
-- decisão do dono do servidor. Dependência que se usa se declara — omiti-la aqui
-- para "parecer" conforme o §6.2 seria pior que a exceção, porque esconderia uma
-- ordem de start que o servidor precisa respeitar.
dependencies {
    '/onesync',
    'ox_lib',
    'bgrz_core',
    'ox_target',
}
