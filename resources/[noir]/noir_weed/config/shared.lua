---Config lida pelo client e pelo servidor. Vai para o jogador (`files{}`): nada de
---recompensa, taxa de crescimento ou regra anti-exploit aqui (§19.1) — isso mora em
---`config/server.lua`. Receita pode ficar aqui: o jogador vê cada uma no menu.

local config = {
    items = {
        pot = 'weed_pot',
        shovel = 'garden_shovel',
        water = 'water',
        fertilizer = 'weed_nutrition',
        herbicide = 'herbicide',
        paper = 'rolling_paper',
        joint = 'joint',
        bag = 'empty_weed_bag',
    },

    ---Semente -> planta. `product` é o bud entregue na colheita; `baggy`, o saquinho que a
    ---mesa embala com ele. `look` escolhe o conjunto de modelos em `plantModels`.
    strains = {
        ['weed_og-kush_seed'] = { label = 'OG Kush', product = 'weed_og-kush', baggy = 'weed_og-kush_baggy', look = 'default' },
        ['weed_amnesia_seed'] = { label = 'Amnesia', product = 'weed_amnesia', baggy = 'weed_amnesia_baggy', look = 'yellow' },
        ['weed_skunk_seed'] = { label = 'Skunk', product = 'weed_skunk', baggy = 'weed_skunk_baggy', look = 'blue' },
        ['weed_ak47_seed'] = { label = 'AK47', product = 'weed_ak47', baggy = 'weed_ak47_baggy', look = 'default' },
        ['weed_purple-haze_seed'] = { label = 'Purple Haze', product = 'weed_purple-haze', baggy = 'weed_purple-haze_baggy', look = 'purple' },
        ['weed_white-widow_seed'] = { label = 'White Widow', product = 'weed_white-widow', baggy = 'weed_white-widow_baggy', look = 'white' },
    },

    ---Crescimento (%) a partir do qual cada estágio aparece. O primeiro é o vaso recém-
    ---plantado; os outros três são a planta pequena, média e grande.
    stageAt = { 0, 10, 40, 70 },

    ---Um modelo por estágio. Os coloridos e o vaso vêm de `stream_enhanced/`; o `default`
    ---usa os props do DLC do bunker.
    plantModels = {
        default = { `weed_empty_pot`, `bkr_prop_weed_01_small_01c`, `bkr_prop_weed_med_01b`, `bkr_prop_weed_lrg_01b` },
        purple = { `weed_empty_pot`, `an_weed_purple_01_small_01b`, `an_weed_purple_med_01b`, `an_weed_purple_lrg_01b` },
        white = { `weed_empty_pot`, `an_weed_white_01_small_01b`, `an_weed_white_med_01b`, `an_weed_white_lrg_01b` },
        yellow = { `weed_empty_pot`, `an_weed_yellow_01_small_01b`, `an_weed_yellow_med_01b`, `an_weed_yellow_lrg_01b` },
        blue = { `weed_empty_pot`, `an_weed_blue_01_small_01b`, `an_weed_blue_med_01b`, `an_weed_blue_lrg_01b` },
    },

    ---Crescimento a partir do qual a colheita abre.
    harvestAt = 100,

    ---Grau do bud, do pior para o melhor. Sai do cuidado com a planta (média de água,
    ---fertilizante e saúde ao longo do crescimento) e vai no metadata (`grade`) do bud e do
    ---saquinho; o noir_drugselling paga pelo grau. Grau é faixa e não número para os lotes
    ---empilharem: mesma variedade, mesmo grau e mesma validade ficam num slot só. Item sem
    ---grau (de antes do sistema) conta como `default`.
    grades = {
        order = { 'C', 'B', 'A', 'S' },
        default = 'B',
    },

    ---Dixavadores: todos iguais na função, muda a aparência. Cada baseado bolado gasta
    ---`grinderCost` pontos de qualidade (de 100); em 0 o dixavador fica gasto no
    ---inventário e para de funcionar.
    grinders = {
        grinder_crank = true,
        grinder_monster = true,
        grinder_slime = true,
        grinder_totem = true,
        grinder_ufo = true,
    },
    grinderCost = 10,
    ---Um bud (2 g) e duas sedas dão dois baseados.
    roll = { buds = 1, papers = 2, joints = 2 },

    ---Minigame da mesa (NUI). O tempo mínimo por unidade fica no config do servidor.
    packGame = {
        seal = 2.0,      -- segundos que o saquinho leva selando
        radius = 70,     -- folga, em px, para acertar o saquinho
        slots = 6,       -- saquinhos na mesa ao mesmo tempo
        maxBatch = 50,   -- teto de unidades por rodada
        wasteOnMiss = true, -- errar o saquinho perde o bud
        volume = 0.35,   -- volume inicial dos sons (0 a 1); o jogador ajusta na própria tela
    },

    ---Mesas de processamento. `recipes` é preenchido abaixo, uma receita por variedade.
    tables = {
        weed_processing_table = {
            label = 'Mesa de embalar',
            model = `freeze_it-scripts_weed_table`,
            recipes = {},
        },
    },

    ---Quem vê as opções de queimar planta e apreender mesa alheia. Só decide o que MOSTRAR:
    ---quem autoriza é o servidor, que também exige estar em serviço.
    destroyJobs = { police = true },

    ---Distância em que os props existem no client.
    renderDistance = 60.0,
    ---Alcance do ox_target na planta e na mesa.
    targetDistance = 2.0,
    ---Alcance do raycast ao posicionar, a partir do jogador.
    placeRange = 6.0,

    ---Duração (ms) de cada ação. O servidor confere que pelo menos isso passou entre o
    ---início e o fim (§17.4). A receita da mesa usa a própria `duration`.
    durations = {
        plant = 5000,
        water = 5000,
        fertilizer = 5000,
        herbicide = 5000,
        harvest = 10000,
        destroy = 5000,
        move = 0,
        roll = 6000,
        placeTable = 3000,
        pickupTable = 3000,
        seizeTable = 5000,
    },

    animations = {
        plant = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        harvest = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        destroy = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        water = { dict = 'missfbi3_waterboard', clip = 'waterboard_loop_player', flag = 1 },
        fertilizer = { dict = 'missfbi3_waterboard', clip = 'waterboard_loop_player', flag = 1 },
        herbicide = { dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', clip = 'weed_spraybottle_stand_spraying_02_inspector', flag = 1 },
        roll = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 },
        pack = { dict = 'anim@amb@drug_processors@coke@female_a@idles', clip = 'idle_a', flag = 1 },
        placeTable = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        pickupTable = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        seizeTable = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
    },

    props = {
        plant = { model = `prop_cs_trowel`, bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        harvest = { model = `prop_cs_trowel`, bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        water = { model = `prop_wateringcan`, bone = 36029, pos = vec3(0.15, 0.0, 0.4), rot = vec3(0.0, -180.0, -140.0) },
        fertilizer = { model = `prop_oilcan_01a`, bone = 36029, pos = vec3(0.1, -0.02, 0.35), rot = vec3(0.0, 140.0, -140.0) },
        herbicide = { model = `bkr_prop_weed_spray_01a`, bone = 28422, pos = vec3(0.1, -0.05, -0.08), rot = vec3(-50.0, -10.0, 20.0) },
    },
}

-- Mesa de embalar: um bud + um saquinho vazio viram um saquinho da variedade. No
-- minigame o jogador arrasta `drag` até `target`, que vira `result`.
for _, strain in pairs(config.strains) do
    config.tables.weed_processing_table.recipes['pack_' .. strain.product] = {
        label = strain.label,
        ingredients = { [strain.product] = 1, [config.items.bag] = 1 },
        outputs = { [strain.baggy] = 1 },
        minigame = { drag = strain.product, target = config.items.bag, result = strain.baggy },
    }
end

return config
