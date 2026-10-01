---Configuração do cliente do noir_minigames. Nada aqui é segredo: o arquivo vai para
---o jogador.

return {
    -- Limite de uma partida. Passou disso sem resposta, conta como falha e o foco da
    -- NUI é liberado (§13: toda espera tem limite).
    timeoutSeconds = 180,

    -- Teclas do lib.skillCheck do ox_lib.
    skillCheckKeys = { 'w', 'a', 's', 'd' },

    -- Itens de mostra do Saque (peuren). Só desenho: nada entra no inventário.
    lootingSample = {
        ['1'] = { item = 'lockpick', amount = 1 },
        ['5'] = { item = 'water', amount = 2 },
        ['7'] = { item = 'money', amount = 150 },
    },
}
