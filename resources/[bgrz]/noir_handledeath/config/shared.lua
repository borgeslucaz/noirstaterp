return {
    -- Preco do medico NPC, cobrado so depois da reanimacao: dinheiro vivo primeiro, depois banco.
    -- Referencia: o check-in do hospital (qbx_ambulancejob) custa 2000.
    price = 5000,

    -- Tempo minimo caido antes de poder chamar o medico particular, em segundos.
    doctorCallDelay = 180,

    -- Tempo da massagem cardiaca, em ms. O servidor exige esse tempo entre a chegada e a reanimacao.
    reviveTime = 20000,

    vehicleModel = 'ambulance',
    pedModel = 's_m_m_doctor_01',
    plate = 'NOIRMED',
    useSiren = true,

    -- Distancia em que a ambulancia nasce, em metros.
    spawnDistance = 80.0,
    driveSpeed = 25.0,

    -- Sem chegar nesse tempo (preso no transito, rua sem acesso), a ambulancia e colocada
    -- na rua mais proxima do jogador.
    arriveTimeout = 60000,
    -- Mesmo limite para o medico andar da ambulancia ate o jogador.
    walkTimeout = 20000,

    -- Intervalo entre dois chamados de EMS pela tela, em segundos (o servidor tambem confere).
    alertCooldown = 60,
}
