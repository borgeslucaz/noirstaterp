---Config lida pelos dois lados. Nada aqui é segredo: recompensa, chance de alerta e
---distâncias de validação ficam em `config/server.lua`.
return {
    debug = false,

    ---Raio do alvo do ox_target no ponto de início e nos pontos de coleta.
    targetRadius = 1.0,

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
    },
}
