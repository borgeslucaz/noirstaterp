---Só o servidor lê. Fora de `files{}` de propósito (§19.1).

return {
    ---Vasos por personagem, contando os que estão no mundo.
    maxPlants = 5,
    ---Mesas de processamento por personagem.
    maxTables = 1,

    ---Colheita pela saúde da planta: saúde 0 dá `min`, saúde 100 dá `max`.
    reward = { min = 2, max = 10 },

    ---Grau pelo cuidado: média de água, fertilizante e saúde a cada ciclo do crescimento
    ---(0 a 100). Vale a última faixa alcançada. O teto do grau vem do nível de `cultivo`.
    gradeByCare = {
        { care = 0, grade = 'C' },
        { care = 50, grade = 'B' },
        { care = 70, grade = 'A' },
        { care = 85, grade = 'S' },
    },

    ---Skill `cultivo` do noir_skills. Cada faixa vale a partir do nível indicado, e a cada
    ---dois níveis, mais ou menos, entra algo que muda o jogo (docs/Recompensa e progressão
    ---no roleplay):
    ---  - `yieldByLevel`: ajuste da colheita;
    ---  - `gradeCapByLevel`: melhor grau que o jogador consegue colher;
    ---  - `perks`: planta bebe menos, cresce mais rápido, devolve semente, vaso extra.
    ---Bebe menos e cresce mais rápido valem pelo nível do dono na hora de plantar (a planta
    ---cresce com ele offline); colheita, grau e semente, pelo nível na hora de colher.
    ---A colheita dá `xpPerHarvest + xpPerBud × buds` (antes do ajuste do nível): cuidar bem
    ---sobe mais rápido, e planta mal cuidada ainda rende algum XP. Sem o noir_skills no ar,
    ---o jogador conta como nível 1 e não ganha XP.
    skill = {
        name = 'cultivo',
        xpPerHarvest = 10,
        xpPerBud = 2,
        yieldByLevel = {
            { level = 1, percent = 0 },
            { level = 3, percent = 5 },
            { level = 5, percent = 10 },
            { level = 9, percent = 15 },
            { level = 11, percent = 20 },
            { level = 15, percent = 25 },
        },
        gradeCapByLevel = {
            { level = 1, grade = 'B' },
            { level = 5, grade = 'A' },
            { level = 11, grade = 'S' },
        },
        perks = {
            ---Perdas de água e fertilizante multiplicadas por `factor`.
            thirst = { level = 3, factor = 0.8 },
            ---Ganho de crescimento multiplicado por `factor` (25 min viram 20).
            fastGrowth = { level = 7, factor = 1.25 },
            ---Sementes da mesma variedade devolvidas na colheita.
            seedBack = { level = 9, amount = 1 },
            ---Vasos a mais sobre `maxPlants`.
            extraPot = { level = 13, amount = 1 },
        },
    },

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
        herbicide = 25.0,
    },

    ---Status de uma planta recém-plantada.
    initial = { health = 30.0, water = 30.0, fertilizer = 30.0 },

    ---Queimar planta e apreender mesa alheia exigem estar em serviço num dos `destroyJobs`
    ---do config shared.
    destroyRequiresDuty = true,

    distance = {
        ---Jogador até a planta para qualquer ação.
        interact = 3.0,
        ---Jogador até o ponto onde o vaso vai.
        place = 6.0,
        ---Espaço mínimo entre dois vasos.
        spacing = 1.0,
        ---Espaço mínimo entre duas mesas.
        tableSpacing = 2.0,
    },

    ---Onde não se planta nem se monta mesa.
    blacklistZones = {
        { coords = vec3(430.077, -1012.518, 30.705), radius = 50.0 }, -- Mission Row PD
    },

    ---Mesa: ritmo esperado por unidade embalada. Não corta a entrega; quem embala mais
    ---rápido que isso vira um registro `pack_fast` (server/logs.lua).
    packSecondsPerUnit = 3.5,

    ---Folga (ms) na conferência do tempo da ação: latência não pode recusar quem esperou.
    durationSlackMs = 750,
    ---Intervalo mínimo entre pedidos do mesmo jogador.
    rateLimitMs = 800,
    ---A cada quantos ciclos o status vai para o banco. Criar, mover e remover gravam na hora.
    saveEveryTicks = 10,
}
