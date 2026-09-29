---Config só do servidor: nunca entra em `files{}` (§19.1).
return {
    ---ACE de quem abre o editor. Liberada em permissions.cfg para group.admin.
    adminAce = 'noir.busjob.editor',
    adminCommand = 'editoronibus',
    ---Mapa de debug das linhas (mesma ACE).
    mapCommand = 'onibusmap',
    ---Teste do traçado pela estrada via GPS do jogo (mesma ACE).
    traceCommand = 'onibusrota',

    ---Intervalo mínimo entre pedidos do mesmo jogador para a mesma ação (ms).
    rateLimitMs = {
        menu = 500,
        start = 1500,
        editor = 250,
        editorSave = 600,
    },

    ---Placa do ônibus da linha: prefixo + 4 dígitos.
    platePrefix = 'NOIR',
}
