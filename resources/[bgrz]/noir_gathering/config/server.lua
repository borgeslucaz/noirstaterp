---Config só do servidor: nunca entra em `files{}`.
return {
    ---ACE de quem cria, edita e apaga rotas. Liberado em permissions.cfg.
    adminAce = 'noir.gathering.admin',
    adminCommand = 'rotascoleta',

    ---Distâncias conferidas com a posição que o SERVIDOR tem do ped.
    distance = {
        start = 5.0,
        point = 3.0,
        ---Folga no fim da coleta: o ped escorrega um pouco durante a animação.
        finishSlack = 1.5,
        ---Um veículo do model exigido pela rota precisa estar até aqui do jogador.
        vehicle = 60.0,
    },

    ---A coleta só é aceita depois desta fração do tempo configurado...
    minCollectFraction = 0.9,
    ---...e expira este tanto depois do tempo configurado.
    collectGraceMs = 15000,

    ---Turno parado há mais que isto é encerrado.
    sessionIdleMs = 30 * 60 * 1000,

    ---Intervalo mínimo entre pedidos do mesmo jogador para a mesma ação.
    rateLimitMs = 400,

    dispatch = {
        jobs = { 'police' },
        code = '10-31',
        duration = 150,
        priority = 3,
    },
}
