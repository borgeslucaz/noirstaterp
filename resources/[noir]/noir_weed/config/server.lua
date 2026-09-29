---Só o servidor lê. Fora de `files{}` de propósito (§19.1).

return {
    ---Vasos por personagem, contando os que estão no mundo.
    maxPlants = 5,

    ---Colheita pela saúde da planta: saúde 0 dá `min`, saúde 100 dá `max`.
    reward = { min = 2, max = 10 },

    ---O ciclo roda a cada `interval` ms e aplica as perdas e o ganho abaixo.
    ---Com os padrões, uma planta bem cuidada vai de 0 a 100% em 25 min.
    growth = {
        interval = 30000,
        loseWater = 1.5,
        loseFertilizer = 1.5,
        loseHealth = 1.0,
        gain = 2.0,
    },

    ---Quanto cada item devolve ao status correspondente, em pontos de 0 a 100.
    care = {
        water = 10.0,
        fertilizer = 10.0,
        herbicide = 10.0,
    },

    ---Status de uma planta recém-plantada.
    initial = { health = 30.0, water = 30.0, fertilizer = 30.0 },

    ---Queimar planta alheia exige estar em serviço num dos `destroyJobs` do config shared.
    destroyRequiresDuty = true,

    distance = {
        ---Jogador até a planta para qualquer ação.
        interact = 3.0,
        ---Jogador até o ponto onde o vaso vai.
        place = 6.0,
        ---Espaço mínimo entre dois vasos.
        spacing = 1.0,
    },

    ---Onde não se planta.
    blacklistZones = {
        { coords = vec3(430.077, -1012.518, 30.705), radius = 50.0 }, -- Mission Row PD
    },

    ---Folga (ms) na conferência do tempo da ação: latência não pode recusar quem esperou.
    durationSlackMs = 750,
    ---Intervalo mínimo entre pedidos do mesmo jogador.
    rateLimitMs = 800,
    ---A cada quantos ciclos o status vai para o banco. Criar, mover e remover gravam na hora.
    saveEveryTicks = 10,
}
