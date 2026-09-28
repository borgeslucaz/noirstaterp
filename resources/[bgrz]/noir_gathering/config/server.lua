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
        ---Rota de carga: jogador até a pilha, até o veículo (avião e barco são compridos)
        ---e até o ponto de entrega; veículo até o ponto de entrega para descarregar.
        stack = 3.0,
        vehicleUse = 9.0,
        dropoff = 3.0,
        unloadVehicle = 40.0,
        ---Nada parado a menos disto da vaga impede entregar o veículo da rota.
        spawnClearance = 3.0,
    },

    haul = {
        ---Entre pegar a caixa e guardar (ou descarregar) ela passa pelo menos isto.
        minCarryMs = 1000,
        ---Rota de carga aberta há mais que isto é encerrada, e o veículo dela some.
        maxRunMs = 45 * 60 * 1000,
        ---O veículo da rota não é apagado com alguém dentro; tenta de novo por este tempo.
        vehicleCleanupMs = 5 * 60 * 1000,
    },

    ---A coleta só é aceita depois desta fração do tempo configurado...
    minCollectFraction = 0.9,
    ---...e expira este tanto depois do tempo configurado.
    collectGraceMs = 15000,

    ---Turno parado há mais que isto é encerrado.
    sessionIdleMs = 30 * 60 * 1000,

    ---Intervalo mínimo entre pedidos do mesmo jogador para a mesma ação.
    rateLimitMs = 400,

    ---Aviso do olheiro, no celular de quem é de outra gang com o mesmo produto.
    scout = { title = 'Olheiro' },

    dispatch = {
        jobs = { 'police' },
        code = '10-31',
        duration = 150,
        priority = 3,
    },
}
