-- Público: vai para o jogador. Nada de recompensa, limite anti-exploit ou regra aqui (§19.1).
return {
    locale = 'pt-br',

    commands = {
        editor = 'noirmissions',
        debug = 'noirmissionsdebug',
    },

    -- Jeitos de carregar. A carga escolhe um pelo nome; "custom" usa os campos da própria carga.
    -- Animações já usadas em outros resources deste servidor (Enhanced derruba o cliente com
    -- dicionário inexistente; ver DESIGN_v4 §11).
    carryPresets = {
        barrel = {
            dict = 'anim@heists@box_carry@', anim = 'idle', bone = 28422,
            offset = { 0.0, -0.05, -0.32 }, rotation = { 0.0, 0.0, 0.0 },
        },
        box = {
            dict = 'anim@heists@box_carry@', anim = 'idle', bone = 28422,
            offset = { 0.0, -0.03, -0.2 }, rotation = { 5.0, 0.0, 0.0 },
        },
        package = {
            dict = 'anim@heists@box_carry@', anim = 'idle', bone = 28422,
            offset = { 0.0, 0.0, -0.12 }, rotation = { 0.0, 0.0, 90.0 },
        },
    },

    -- Animação de cada tipo de interação durante a barra de progresso.
    interactionAnims = {
        hack = { dict = 'anim@gangops@facility@servers@', clip = 'hotwire', flag = 1 },
        search = { dict = 'amb@prop_human_bum_bin@idle_b', clip = 'idle_d', flag = 1 },
        generic = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
        load = { dict = 'anim@heists@load_box', clip = 'load_box_1', flag = 16 },
    },
}
