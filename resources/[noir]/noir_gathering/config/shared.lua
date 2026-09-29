---Config lida pelos dois lados. Nada aqui é segredo: recompensa, chance de alerta e
---distâncias de validação ficam em `config/server.lua`.
return {
    debug = false,

    ---Raio do alvo no ponto de início e nos pontos de coleta.
    ---O ponto é gravado na altura do corpo do admin (~1 m do chão) e o ox_target só
    ---mostra a opção quando a MIRA acerta algo dentro da esfera: abaixo de ~1.5 o chão
    ---fica fora e aparece só a bolinha, sem opção. 2.0 é o padrão do ox_target.
    targetRadius = 2.0,

    ---Marcador sobre o ponto atual do turno.
    marker = { enabled = true, distance = 30.0 },

    ---Blip com rota no GPS até o ponto atual do turno.
    blip = { sprite = 465, color = 5, scale = 0.9 },

    ---Tecla (editável em Configurações > Teclas) que encerra o turno ou o modo AFK.
    stopKey = 'F7',

    ---Imagem do item no menu da rota. `%s` é o nome do item.
    itemImage = 'nui://ox_inventory/web/images/%s.png',

    ---Animação quando o item não tem uma própria. Dicionário ausente no build derruba o
    ---cliente no Enhanced, por isso o client confere com DoesAnimDictExist antes de usar.
    defaultAnim = { dict = 'amb@prop_human_bum_bin@idle_a', clip = 'idle_a', flag = 1 },

    ---Rota de carga. Prop que não existe no build derruba o cliente no Enhanced: o admin
    ---só escolhe desta lista, e o client ainda confere com IsModelInCdimage antes de criar.
    haul = {
        stackProps = {
            { model = 'prop_boxpile_07d', label = 'Pilha de caixas' },
            { model = 'prop_boxpile_06b', label = 'Pilha de caixas baixa' },
            { model = 'prop_boxpile_02b', label = 'Caixas empilhadas' },
            { model = 'prop_mb_crate_01a', label = 'Caixote de madeira' },
        },
        ---Caixa na mão (a mesma do emote "box" do rpemotes).
        carry = {
            prop = 'hei_prop_heist_box',
            bone = 60309,
            offset = { 0.025, 0.08, 0.255 },
            rotation = { -145.0, 290.0, 0.0 },
            dict = 'anim@heists@box_carry@',
            clip = 'idle',
            ---Levantar a caixa antes de passar a carregar (da pilha e do veículo).
            lift = { dict = 'anim@heists@load_box', clip = 'lift_box', ms = 1800 },
            ---Guardar a caixa no veículo, durante a barra.
            load = { dict = 'anim@heists@load_box', clip = 'load_box_1' },
        },
        ---Tempo da barra ao guardar e ao tirar uma caixa do veículo.
        loadMs = 2000,
        ---Por quanto tempo o olheiro deixa a área marcada no mapa de quem recebeu.
        scoutBlipSeconds = 120,
        npcScenario = 'WORLD_HUMAN_CLIPBOARD',
        ---Motorista que leva embora o veículo da rota na entrega (se a rota tiver o ponto dele).
        driverModel = 's_m_m_trucker_01',
    },

    ---Limites de uma rota. O servidor recusa o que passar disso ao salvar.
    limits = {
        nameLength = 60,
        itemsPerRoute = 16,
        pointsPerItem = 64,
        extrasPerItem = 8,
        groupsPerRoute = 16,
        amount = 100,
        collectTime = { min = 1000, max = 120000, default = 7000 },
        stress = 100,
        ---Raio (m) da área do alerta policial e do olheiro.
        alertRadius = { min = 20, max = 1000, default = 150 },
        haul = {
            defaultProp = 'prop_boxpile_07d',
            boxes = 30,
            rewardItems = 8,
            ---Teto da reputação por entrega quando o noir_illegal_core não responde. Com ele no
            ---ar, o teto é o da atividade `gathering_delivery` de lá.
            reputation = 100,
            cooldownMinutes = 240,
        },
    },
}
