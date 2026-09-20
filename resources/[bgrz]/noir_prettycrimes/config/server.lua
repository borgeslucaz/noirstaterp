---Configuração que o cliente NÃO recebe.
---
---Não está em `files{}`. É onde ficam as regras anti-exploit, os limites de rate
---limit e as integrações sensíveis, como manda o §19.1 do SCRIPT_GOOD_PRACTICES.

return {
    -- Permissão exigida pelos comandos de debug do servidor. Eles só são
    -- registrados com `debug = true`, e mesmo assim ficam atrás disto.
    debugAce = 'group.admin',

    -- Anti-spam de evento, aplicado antes de qualquer validação cara.
    -- É por jogador e por chave de ação, em milissegundos.
    rateLimit = {
        -- Piso para qualquer pedido deste resource. Um crime pode pedir mais que
        -- isso no config dele, nunca menos.
        default = 750,
    },

    limits = {
        -- Distância máxima entre o jogador e a entidade alvo aceita pelo servidor.
        -- Vale para todo crime e é a última palavra: o client pode mandar o que
        -- quiser, isto aqui é medido com as coordenadas do servidor.
        --
        -- Não aperte demais. A coordenada de um veículo é o centro dele, não a
        -- janela, e um caminhão tem vários metros entre uma coisa e outra.
        maxInteractDistance = 8.0,
    },

    dispatch = {
        -- Alerta policial. Vai pelo bgrz_core, que escolhe o provider.
        enabled = true,
        jobs = { 'police' },
        -- Segundos que a ocorrência fica viva no MDT.
        duration = 300,
        -- 1 = mais urgente, 4 = menos.
        priority = 3,
    },

    -- Progressão criminal opcional (noir_illegal_core).
    --
    -- Desligado de propósito: ligar exige registrar `noir_prettycrimes` em
    -- `noir_illegal_core/shared/permissions.lua` (publicRecorders) e declarar as
    -- activities lá. Sem isso o core recusa a chamada, e a recusa é silenciosa
    -- do ponto de vista do jogador. Veja o README antes de ligar.
    progression = {
        enabled = false,
        resource = 'noir_illegal_core',
    },
}
