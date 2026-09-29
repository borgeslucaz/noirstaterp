---Config lida pelo client e pelo servidor. Vai para o jogador (`files{}`): nada de
---recompensa, taxa de crescimento ou regra anti-exploit aqui (§19.1) — isso mora em
---`config/server.lua`.

return {
    items = {
        pot = 'weed_pot',
        shovel = 'garden_shovel',
        water = 'water',
        fertilizer = 'weed_nutrition',
        herbicide = 'herbicide',
    },

    ---Semente -> planta. `product` é o item entregue na colheita. `stages[i].from` é o
    ---crescimento (%) a partir do qual o estágio aparece; o primeiro começa em 0.
    ---Os props são do DLC do bunker, os mesmos que o qbx_weed já usava neste servidor.
    strains = {
        ['weed_og-kush_seed'] = { label = 'OG Kush', product = 'weed_og-kush' },
        ['weed_amnesia_seed'] = { label = 'Amnesia', product = 'weed_amnesia' },
        ['weed_skunk_seed'] = { label = 'Skunk', product = 'weed_skunk' },
        ['weed_ak47_seed'] = { label = 'AK47', product = 'weed_ak47' },
        ['weed_purple-haze_seed'] = { label = 'Purple Haze', product = 'weed_purple-haze' },
        ['weed_white-widow_seed'] = { label = 'White Widow', product = 'weed_white-widow' },
    },

    stages = {
        { prop = `bkr_prop_weed_01_small_01c`, from = 0 },
        { prop = `bkr_prop_weed_med_01b`, from = 40 },
        { prop = `bkr_prop_weed_lrg_01b`, from = 70 },
    },

    ---Crescimento a partir do qual a colheita abre.
    harvestAt = 100,

    ---Quem vê a opção de queimar planta alheia. Só decide o que MOSTRAR: quem autoriza
    ---é o servidor, que também exige estar em serviço.
    destroyJobs = { police = true },

    ---Distância em que o prop da planta existe no client.
    renderDistance = 60.0,
    ---Alcance do ox_target na planta.
    targetDistance = 2.0,
    ---Alcance do raycast ao posicionar o vaso, a partir da câmera.
    placeRange = 6.0,

    ---Duração (ms) de cada ação. O servidor confere que pelo menos isso passou entre o
    ---início e o fim (§17.4).
    durations = {
        plant = 5000,
        water = 5000,
        fertilizer = 5000,
        herbicide = 5000,
        harvest = 10000,
        destroy = 5000,
        move = 0,
    },

    animations = {
        plant = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        harvest = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        destroy = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        water = { dict = 'missfbi3_waterboard', clip = 'waterboard_loop_player', flag = 1 },
        fertilizer = { dict = 'missfbi3_waterboard', clip = 'waterboard_loop_player', flag = 1 },
        herbicide = { dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', clip = 'weed_spraybottle_stand_spraying_02_inspector', flag = 1 },
    },

    props = {
        plant = { model = `prop_cs_trowel`, bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        harvest = { model = `prop_cs_trowel`, bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        water = { model = `prop_wateringcan`, bone = 36029, pos = vec3(0.15, 0.0, 0.4), rot = vec3(0.0, -180.0, -140.0) },
        fertilizer = { model = `prop_oilcan_01a`, bone = 36029, pos = vec3(0.1, -0.02, 0.35), rot = vec3(0.0, 140.0, -140.0) },
        herbicide = { model = `bkr_prop_weed_spray_01a`, bone = 28422, pos = vec3(0.1, -0.05, -0.08), rot = vec3(-50.0, -10.0, 20.0) },
    },
}
