fx_version 'cerulean'
game 'gta5'

name 'noir_missions'
author 'Noir State'
description 'Missões montadas no jogo: editor NUI, runtime genérico (passos, gatilhos, ações) e componentes'
version '0.1.0'

ui_page 'web/mission-editor/index.html'
nui_callback_strict_mode 'true'

shared_scripts {
    '@ox_lib/init.lua',
}

-- Só os pontos de entrada entram como script; o resto é módulo carregado com `require`.
client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

-- `require` no cliente lê por LoadResourceFile: todo módulo de cliente precisa estar aqui.
-- Fora de propósito: server/, config/server.lua (limites e regras), missions/ (definições
-- com recompensa) e dev/. O teste tests/unit/manifest_spec.lua trava isso.
files {
    'config/shared.lua',
    'config/client.lua',
    'shared/types/*.lua',
    'shared/utils/*.lua',
    'client/*.lua',
    'client/runtime/*.lua',
    'client/interactions/*.lua',
    'client/entities/*.lua',
    'client/cargo/*.lua',
    'client/vehicles/*.lua',
    'client/npc/*.lua',
    'client/chase/*.lua',
    'client/editor/*.lua',
    'web/mission-editor/index.html',
    'web/mission-editor/css/*.css',
    'web/mission-editor/js/*.js',
    'web/mission-editor/js/**/*.js',
    'web/mission-editor/fonts/*.woff2',
}

-- `ox_target` é a exceção do §2.5: chamado direto, só de client/integrations.lua.
-- `noir_lib` e `noir_minigames` são opcionais (conferidos por GetResourceState).
dependencies {
    '/onesync',
    'ox_lib',
    'bgrz_core',
    'ox_target',
}
