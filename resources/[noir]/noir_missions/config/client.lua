return {
    keys = {
        drop = 'G',
    },

    hud = {
        -- Some a janela de informação revelada (manifesto) depois deste tempo.
        infoSeconds = 20,
    },

    placement = {
        maxDistance = 80.0,
        rotateStep = 5.0,
        heightStep = 0.05,
    },

    -- Distância em que o NPC de início de missão nasce para o jogador (local, por cliente).
    starterSpawnDistance = 60.0,

    -- Laço que conduz a IA das entidades de missão que este cliente é dono de rede.
    entityLoopMs = 500,

    -- Detecção de tiro do próprio jogador dentro da área da missão.
    shotCheckMs = 250,

    -- Sugestões do campo de arma no editor. Qualquer WEAPON_* vale; isto só ajuda a digitar.
    weapons = {
        'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_PISTOL50', 'WEAPON_HEAVYPISTOL',
        'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_MINISMG', 'WEAPON_MACHINEPISTOL', 'WEAPON_ASSAULTSMG',
        'WEAPON_ASSAULTRIFLE', 'WEAPON_CARBINERIFLE', 'WEAPON_COMPACTRIFLE', 'WEAPON_SPECIALCARBINE',
        'WEAPON_PUMPSHOTGUN', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_BULLPUPSHOTGUN', 'WEAPON_MG',
        'WEAPON_KNIFE', 'WEAPON_BAT', 'WEAPON_MACHETE',
    },
}
