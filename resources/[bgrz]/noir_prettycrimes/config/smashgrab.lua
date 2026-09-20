---Smash & Grab — objetos visíveis dentro de veículos estacionados.
---
---A ideia não é "vasculhar um carro": é o jogador ENXERGAR uma mochila no banco de
---trás, quebrar o vidro daquela porta e pegar. O prop é a feature; o loot é a
---consequência.
---
---Convenção de números: **toda chance neste arquivo é uma fração de 0 a 1.**
---0.12 é doze por cento. Não misture com porcentagem inteira — os pesos (`weight`)
---é que são relativos e podem ter qualquer escala.
---
---**Este arquivo É enviado ao cliente** (está em `files{}`), porque o client
---precisa de prop, assento, janela e distância para desenhar o objeto. Nada que
---decida recompensa mora aqui: isso está em `config/smashgrab_server.lua`, que não
---é enviado. Ao acrescentar campo, pergunte de que lado ele precisa existir.

return {
    -- Quem decide é o SERVIDOR, e só ele. O client pergunta sobre os veículos
    -- que tem por perto e o servidor só responde sobre os que estão mesmo
    -- perto dele — é isso que impede um client adulterado de varrer o mapa
    -- inteiro atrás das maletas. A decisão de cada carro é tomada uma vez e
    -- memorizada, então dois jogadores veem o mesmo objeto no mesmo banco.

    -- =======================================================================
    -- Varredura e distâncias (metros / ms)
    -- =======================================================================

    -- Intervalo entre varreduras de veículos próximos. Não existe varredura por
    -- frame neste resource; é este número que define todo o custo do sistema.
    scanInterval = 1500,

    -- Teto de espera por resposta do servidor (ms), para TODO callback.
    --
    -- `lib.callback.await` com delay `false` espera para SEMPRE — e uma consulta
    -- sem resposta dentro da varredura trava a thread inteira: a varredura roda
    -- uma vez e nunca mais. O §13.3 do SCRIPT_GOOD_PRACTICES é explícito: toda
    -- espera tem limite. Estourado o prazo, a resposta vem nil e o caminho de
    -- recusa que já existe cuida do resto.
    callbackTimeout = 5000,

    -- Máximo de veículos por consulta ao servidor. O client corta o lote nisto e
    -- o resto vai na varredura seguinte; o servidor recusa lote maior. Dirigindo
    -- rápido entram muitos carros de uma vez, e é este número que impede uma
    -- consulta gigante de virar trabalho de servidor num pico só.
    surveyBatchMax = 40,

    -- Intervalo quando não há nada a fazer: dirigindo, morto, deslogado ou sem
    -- nenhum objeto por perto. É o sleep adaptativo que o §14.3 pede.
    scanIdleInterval = 5000,

    -- Raio em que os veículos passam a ser avaliados.
    activationDistance = 80.0,
    -- Raio em que o prop é realmente criado.
    renderDistance = 60.0,
    -- Raio em que o prop é destruído.
    cleanupDistance = 120.0,

    -- Distância máxima entre jogador e veículo durante o roubo. Vale no client
    -- (cancela a progress) e no servidor (recusa a reserva e a entrega).
    maxDistance = 4.0,

    -- =======================================================================
    -- Elegibilidade do veículo
    -- =======================================================================

    eligibility = {
        -- Tipos aceitos, conferidos no servidor com GetVehicleType.
        allowedTypes = { automobile = true },

        -- Classes do GTA recusadas. 8 = motos, 13 = bicicletas, 14 = barcos,
        -- 15 = helicópteros, 16 = aviões, 18 = emergência, 19 = militar,
        -- 21 = trens. Motos e bicicletas não têm vidro; o resto é por regra.
        vehicleClassBlacklist = {
            [8] = true, [13] = true, [14] = true, [15] = true,
            [16] = true, [18] = true, [19] = true, [21] = true,
        },

        -- Modelos recusados, por nome. Viaturas, resgate e veículos de trabalho.
        vehicleModelBlacklist = {
            'police', 'police2', 'police3', 'police4', 'policeb', 'policeold1',
            'policeold2', 'policet', 'sheriff', 'sheriff2', 'fbi', 'fbi2',
            'riot', 'riot2', 'pranger', 'predator',
            'ambulance', 'firetruk', 'lguard',
            'taxi', 'trash', 'trash2', 'bus', 'coach', 'airbus', 'rentalbus',
            'stockade', 'brickade',
        },

        -- Carro ocupado (jogador ou NPC) não recebe objeto: isso aqui é petty
        -- crime de carro parado, não assalto a quem está dentro.
        blockOccupied = true,

        -- Carro em movimento não recebe objeto.
        blockMoving = true,
        maxSpeed = 0.5,

        -- Carro destruído/queimado não recebe objeto.
        blockDestroyed = true,
        minBodyHealth = 200.0,

        -- Veículo de jogador. O Qbox marca os persistidos com a state bag
        -- `persisted` (replicada) e guarda `vehicleid` no servidor. As duas são
        -- conferidas; é por aqui que entra qualquer outro sistema de propriedade.
        blockPlayerOwned = true,
        ownedStateBags = { 'persisted', 'vehicleid' },

        -- Veículo sem placa sincronizada é pulado: a placa entra na semente, e
        -- avaliar antes de ela chegar faria o prop trocar na frente do jogador.
        requirePlate = true,
    },

    -- =======================================================================
    -- Props
    -- =======================================================================
    --
    -- Todos os modelos abaixo foram conferidos contra a lista de objetos do
    -- `ps_lib` (`modules/streamed_assets/shared/objectList.lua`). Ao acrescentar
    -- um prop, confira lá antes — modelo inexistente no build do Enhanced derruba
    -- o cliente na thread de render, e não dá erro de script. O módulo ainda
    -- valida com IsModelValid/IsModelInCdimage no start e recusa o que faltar.
    --
    -- `weight` é peso relativo do sorteio; `label` é a chave de locale.
    -- A raridade é a ponte com a loot table: quanto mais raro o prop, melhor a
    -- mesa. Continua sendo petty crime — nada aqui paga um carro.

    props = {
        shoppingbag = {
            model = 'prop_cs_shopping_bag',
            label = 'sg_prop_shoppingbag',
            weight = 26,
            lootTable = 'cheap',
            offset = vec3(0.0, 0.0, 0.0),
            rotation = vec3(0.0, 0.0, 0.0),
        },
        backpack = {
            model = 'prop_michael_backpack',
            label = 'sg_prop_backpack',
            weight = 24,
            lootTable = 'common',
            offset = vec3(0.0, 0.0, 0.02),
            rotation = vec3(0.0, 0.0, 90.0),
        },
        handbag = {
            model = 'prop_amb_handbag_01',
            label = 'sg_prop_handbag',
            weight = 18,
            lootTable = 'common',
            offset = vec3(0.0, 0.0, 0.0),
            rotation = vec3(0.0, 0.0, 0.0),
        },
        package = {
            model = 'prop_cs_cardbox_01',
            label = 'sg_prop_package',
            weight = 16,
            lootTable = 'variable',
            offset = vec3(0.0, 0.0, 0.03),
            rotation = vec3(0.0, 0.0, 0.0),
        },
        laptop = {
            model = 'prop_laptop_01a',
            label = 'sg_prop_laptop',
            weight = 10,
            lootTable = 'electronics',
            offset = vec3(0.0, 0.0, 0.02),
            rotation = vec3(0.0, 0.0, 0.0),
        },
        briefcase = {
            model = 'prop_ld_case_01',
            label = 'sg_prop_briefcase',
            weight = 6,
            lootTable = 'valuable',
            offset = vec3(0.0, 0.0, 0.02),
            rotation = vec3(0.0, 0.0, 90.0),
        },
    },

    -- =======================================================================
    -- Posições dentro do carro
    -- =======================================================================
    --
    -- Cada posição amarra TRÊS coisas: o osso onde o prop gruda, a janela que
    -- precisa estar quebrada para alcançá-lo, e o peso do sorteio.
    --
    -- Os ossos são os padrão do GTA (o próprio ox_target usa esses nomes nas
    -- opções de assento). `dside` = lado do motorista (esquerda),
    -- `pside` = lado do passageiro (direita).
    --
    -- Índices de janela: 0 dianteira esquerda, 1 dianteira direita,
    -- 2 traseira esquerda, 3 traseira direita.
    --
    -- `bone` é onde o PROP gruda. `targetBones` é onde o ALVO aparece — e são
    -- coisas diferentes: o raycast do ox_target acerta a carroceria antes de
    -- alcançar qualquer coisa dentro do carro, então o alvo tem que morar no
    -- veículo, com filtro de osso, e não no prop. É assim que o próprio ox_target
    -- faz as opções de porta e assento.
    --
    -- A lista tem três ossos porque nem todo modelo traz `window_*`; quando ele
    -- falta, o osso da porta pega no mesmo lugar. O ox_target escolhe o mais
    -- próximo do ponto mirado entre os que existirem.
    --
    -- O banco do motorista fica de fora: é por onde o dono entra, e objeto
    -- largado ali não passa a mesma leitura de "esqueceram no carro".

    seats = {
        passengerFront = {
            bone = 'seat_pside_f',
            targetBones = { 'window_rf', 'door_pside_f', 'seat_pside_f' },
            window = 1,
            weight = 35,
            offset = vec3(0.0, 0.0, 0.18),
            rotation = vec3(0.0, 0.0, 0.0),
        },
        passengerFloor = {
            bone = 'seat_pside_f',
            targetBones = { 'window_rf', 'door_pside_f', 'seat_pside_f' },
            window = 1,
            weight = 15,
            offset = vec3(0.0, 0.22, -0.18),
            rotation = vec3(0.0, 0.0, 0.0),
        },
        rearLeft = {
            bone = 'seat_dside_r',
            targetBones = { 'window_lr', 'door_dside_r', 'seat_dside_r' },
            window = 2,
            weight = 25,
            offset = vec3(0.0, 0.0, 0.18),
            rotation = vec3(0.0, 0.0, 0.0),
        },
        rearRight = {
            bone = 'seat_pside_r',
            targetBones = { 'window_rr', 'door_pside_r', 'seat_pside_r' },
            window = 3,
            weight = 25,
            offset = vec3(0.0, 0.0, 0.18),
            rotation = vec3(0.0, 0.0, 0.0),
        },
    },

    -- Override por modelo, para quando o offset padrão não cair bem.
    -- Substitui o offset/rotação DA POSIÇÃO; o ajuste do prop continua somando.
    -- Sem override, o padrão acima é usado — e ele foi pensado para funcionar
    -- razoavelmente em carro comum de 4 portas.
    vehicleOffsets = {
        -- ['granger'] = {
        --     rearLeft = { offset = vec3(0.0, 0.0, 0.26), rotation = vec3(0.0, 0.0, 0.0) },
        -- },
    },

    -- =======================================================================
    -- Roubo
    -- =======================================================================

    -- Duração da animação de quebrar o vidro (ms).
    breakDuration = 1000,

    -- Animação da quebra: arrombamento de veículo do jogo base.
    --
    -- ATENÇÃO, duas coisas diferentes podem dar errado aqui, e elas falham de
    -- formas diferentes:
    --
    --   * dicionário ausente -> o módulo confere com DoesAnimDictExist e roda a
    --     progress SEM animação, deixando um aviso no console. Não derruba o
    --     cliente (que é o que aconteceria se passasse direto ao jogo).
    --   * clip errado dentro de um dicionário que existe -> silêncio total: a
    --     barra roda, o personagem não faz nada, e nada é logado.
    --
    -- Este servidor usa `veh@break_in@0h@p_m_one@` (com "one") em quatro
    -- resources — qbx_storerobbery, qbx_houserobbery, noir_houserobbery e
    -- qbx_vehiclekeys — com os clips `low_force_entry_ds` e `std_force_entry_rds`.
    -- A variante `p_m_zero@` abaixo é da mesma família.
    breakAnim = {
        dict = 'veh@break_in@0h@p_m_zero@',
        clip = 'low_force_entry_ds',
        flag = 49,
    },

    -- Duração da animação de alcançar o interior e pegar o objeto (ms).
    duration = 3000,

    -- `mp_car_bomb` / `car_bomb_mechanic` é o "debruçar para dentro do carro"
    -- do jogo base, já em produção no qbx_vineyard e no qbx_recyclejob deste
    -- servidor. Dicionário ausente no Enhanced derruba o cliente, então o módulo
    -- confere com DoesAnimDictExist e roda sem animação se faltar.
    anim = {
        dict = 'mp_car_bomb',
        clip = 'car_bomb_mechanic',
        flag = 49,
    },

}
