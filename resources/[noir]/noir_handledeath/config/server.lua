return {
    -- Job dos paramedicos: conta quem esta em servico e recebe o chamado.
    emsJob = 'ambulance',
    -- O medico NPC so atende com esta quantidade de EMS em servico, ou menos.
    maxEmsOnDuty = 0,

    -- Intervalo minimo entre duas chamadas do medico NPC pelo mesmo jogador, em segundos.
    callCooldown = 15,
    -- Tempo minimo entre chamar e o medico chegar, em ms (a ambulancia nasce a ~80 m).
    minTravelTime = 5000,
    -- Chamada sem conclusao nesse tempo e descartada, em ms.
    sessionTtl = 180000,

    -- Chamado de EMS pela tela.
    alert = {
        code = '10-52',
        title = 'Pessoa ferida',
        message = 'Cidadão caído precisando de atendimento',
    },
}
