return {
    -- Density of various things in the world
    -- Minimum value is 0.0, maximum value is 1.0
    -- Value of 1.0 represents GTA Online populate rates
    -- Value of 0.0 removes all of that type
    parked = 0.8, -- Density of parked vehicles
    vehicle = 0.8, -- Density of vehicles
    randomvehicles = 0.8, -- Density of random vehicles
    peds = 0.8, -- Density of random peds (civilians, etc.)
    scenario = 0.8, -- Density of scenario peds (bikers, gangsters, etc.)

    -- Ambient peds with these models will not be created. This does not affect
    -- peds spawned by jobs, missions, shops, or other resources.
    blockedPedModels = {
        'g_f_y_ballas_01',
        'g_f_y_families_01',
        'g_f_y_lost_01',
        'g_f_y_vagos_01',
        'g_m_m_armboss_01',
        'g_m_m_armgoon_01',
        'g_m_m_armgoon_02',
        'g_m_m_armlieut_01',
        'g_m_m_chiboss_01',
        'g_m_m_chicold_01',
        'g_m_m_chigoon_01',
        'g_m_m_chigoon_02',
        'g_m_m_korboss_01',
        'g_m_m_mexboss_01',
        'g_m_m_mexboss_02',
        'g_m_y_azteca_01',
        'g_m_y_ballaeast_01',
        'g_m_y_ballaorig_01',
        'g_m_y_ballasout_01',
        'g_m_y_famca_01',
        'g_m_y_famdnf_01',
        'g_m_y_famfor_01',
        'g_m_y_korean_01',
        'g_m_y_korean_02',
        'g_m_y_korlieut_01',
        'g_m_y_lost_01',
        'g_m_y_lost_02',
        'g_m_y_lost_03',
        'g_m_y_mexgang_01',
        'g_m_y_mexgoon_01',
        'g_m_y_mexgoon_02',
        'g_m_y_mexgoon_03',
        'g_m_y_pologoon_01',
        'g_m_y_pologoon_02',
        'g_m_y_salvaboss_01',
        'g_m_y_salvagoon_01',
        'g_m_y_salvagoon_02',
        'g_m_y_salvagoon_03',
    },

    -- The first matching zone overrides only the values it defines.
    -- Example:
    -- {
    --     name = 'legion_square',
    --     coords = vec3(215.0, -810.0, 30.0),
    --     radius = 150.0,
    --     density = { parked = 0.2, vehicle = 0.25, peds = 0.6 },
    -- },
    zones = {},
}
