return {
    debug = false,
    debugAce = 'noir.houserobbery.debug',
    baseRoutingBucket = 7600,
    burnerContact = {
        enabled = true,
        number = '404-0199',
        name = 'Ninguém',
        requestText = 'Preciso de trabalho.',
    },
    tiers = {
        [1] = {
            enabled = true,
            residentChance = 1.0,
            loot = { min = 3, max = 3 },
            pickups = { min = 2, max = 2 },
        },
        [2] = { enabled = false },
        [3] = { enabled = false },
    },
    noise = {
        tick = 250,
        syncDelta = 0.5,
        nativeWeight = 0.12,
        movement = { sneak = 0.05, walk = 2, run = 5, sprint = 10 },
        decayPerSecond = 0.01,
        quietGrace = 1000,
        actions = { jump = 35, searchDrawer = 10, searchCabinet = 10, takeSmall = 5, pickupLarge = 15, dropLarge = 25, failedSkillcheck = 25 },
        wake = { risk = 50, danger = 70, critical = 90, immediate = 100, interval = 2500, chances = { risk = 0.08, danger = 0.25, critical = 0.60 } },
    },
    residents = {
        dispatchDelay = { min = 7000, max = 14000 },
        reactions = {
            { name = 'flee', chance = 10 },
            { name = 'hide', chance = 20 },
            { name = 'confront', chance = 30 },
            { name = 'armed', chance = 35 },
        },
        weapon = 'WEAPON_PISTOL',
    },
    interiors = {
        -- tier1_small_01 = {
        --     tier = 1,
        --     entry = vec4(266.3588, -1007.2146, -101.0085, 357.9339),
        --     exit = vec4(266.3588, -1007.2146, -101.0085, 357.9339),
        --     skillcheck = {'easy', 'medium', 'easy'},
        --     loot = {
        --         { coords = vec3(265.94, -999.49, -99.01), pool = {1, 3}, noise = 'searchDrawer' },
        --         { coords = vec3(259.62, -1003.96, -99.01), pool = {1, 2}, noise = 'searchDrawer' },
        --         { coords = vec3(257.01, -995.84, -99.01), pool = {1, 2, 3}, noise = 'searchDrawer' },
        --     },
        --     pickups = {
        --         { coords = vec3(261.95886230469, -1000.3989257812, -99.29857635498), model = 'prop_toaster_02', reward = 'houselaptop', rotation = 20.0 },
        --         { coords = vec3(266.439, -997.042, -98.805), model = 'prop_coffee_mac_02', reward = 'boombox', rotation = 150.0 },
        --         { coords = vec3(262.77, -1002.53, -99.01), model = 'prop_tv_flat_03', reward = 'small_tv', rotation = 0.0 },
        --     },
        --     residents = {
        --         { coords = vec4(262.34, -1004.14, -99.27, 270.0), models = {'CS_Patricia', 'A_F_M_FatCult_01', 'G_M_M_MexBoss_01'} },
        --     },
        -- },
        -- tier1_small_02 = {
        --     tier = 1,
        --     entry = vec4(346.798, -1009.72, -100.09, 350.0),
        --     exit = vec4(346.420, -1012.641, -99.196, 5.8),
        --     skillcheck = {'easy', 'medium', 'medium'},
        --     loot = {
        --         { coords = vec3(346.15, -1001.71, -99.2), pool = {1, 3}, noise = 'searchDrawer' },
        --         { coords = vec3(345.01, -995.49, -99.2), pool = {1, 2, 3}, noise = 'searchCabinet' },
        --         { coords = vec3(341.97, -997.45, -99.2), pool = {1, 2}, noise = 'searchDrawer' },
        --         { coords = vec3(338.35, -995.22, -99.2), pool = {1, 2, 3}, noise = 'searchCabinet' },
        --         { coords = vec3(338.31, -997.88, -99.2), pool = {1, 3}, noise = 'searchDrawer' },
        --         { coords = vec3(339.71, -1000.35, -99.2), pool = {1, 2}, noise = 'searchCabinet' },
        --         { coords = vec3(351.13, -999.23, -99.2), pool = {1, 2, 3}, noise = 'searchDrawer' },
        --     },
        --     pickups = {
        --         { coords = vec3(338.33, -995.99, -100.20), model = 'p_amb_lap_top_02', reward = 'houselaptop', rotation = 45.0 },
        --         { coords = vec3(344.68, -995.71, -100.20), model = 'prop_speaker_03', reward = 'mdspeakers', rotation = 6.0 },
        --         { coords = vec3(341.85, -1002.14, -99.28), model = 'prop_toaster_01', reward = 'toaster', rotation = 90.0 },
        --     },
        --     residents = {
        --         { coords = vec4(349.8, -996.141, -98.74, 90.0), models = {'a_f_y_hipster_01', 'a_f_y_hiker_01'} },
        --     },
        -- },
        -- tier1_small_03 = {
        --     tier = 1,
        --     entry = vec4(151.85, -1005.84, -99.99, 331.0),
        --     exit = vec4(151.29, -1007.59, -99.0, 331.0),
        --     skillcheck = {'easy', 'medium', 'easy'},
        --     loot = {
        --         { coords = vec3(153.26, -1001.25, -99.0), pool = {1, 3}, noise = 'searchDrawer' },
        --         { coords = vec3(154.70, -1003.65, -99.0), pool = {1, 2}, noise = 'searchCabinet' },
        --         { coords = vec3(153.42, -1006.24, -99.0), pool = {1, 3}, noise = 'searchDrawer' },
        --         { coords = vec3(155.02, -1007.04, -99.0), pool = {1, 2, 3}, noise = 'searchCabinet' },
        --     },
        --     pickups = {
        --         { coords = vec3(154.43, -1007.22, -99.32), model = 'p_idol_case_s', reward = 'gold', rotation = 180.0 },
        --         { coords = vec3(154.05, -1004.08, -99.35), model = 'prop_laptop_lester', reward = 'houselaptop', rotation = 160.0 },
        --         { coords = vec3(153.77, -1002.30, -99.99), model = 'prop_big_bag_01', reward = 'boombox', rotation = 130.0 },
        --     },
        --     residents = {
        --         { coords = vec4(154.16, -1004.89, -99.41, 270.0), models = {'A_M_O_GenStreet_01', 'a_m_y_beach_02'} },
        --     },
        -- },
        lev_apartment_shell = {
            tier = 1,
            -- dynamically spawned via noir_shell instead of a pre-placed
            -- interior; entry/exit share the same door coordinate, same as
            -- the noir_shell_test proof of concept
            shell = {
                model = `lev_apartment_shell`,
                origin = vec4(120.83, -1128.245, -101.233, 335.0),
            },
            entry = vec4(119.4, -1130.32, -99.84, 270.76),
            exit = vec4(119.4, -1130.32, -99.84, 270.76),
            skillcheck = {'easy', 'easy', 'medium'},
            -- TODO: the old loot/pickup coordinates were tied to the
            -- previous real-house location and no longer line up with the
            -- shell above; re-measure them in-game the same way EXIT_POS
            -- was captured for noir_shell_test before re-enabling these.  
            loot = {
                 { coords = vec3(120.92, -1131.33, -99.87), pool = {1, 3}, noise = 'searchDrawer' },
                 { coords = vec3(128.76, -1128.55, -99.87), pool = {1, 3}, noise = 'searchDrawer' },
                 { coords = vec3(125.47, -1127.65, -99.87), pool = {1, 3}, noise = 'searchDrawer' },

            },
            pickups = {
                 { coords = vec3(124.564, -1128.328, -99.991), model = 'prop_cash_pile_02', name = 'Dinheiro', reward = 'money', rotation = 0, carry = false, amount = { min = 100, max = 800 } },
                 { coords = vec3(120.276, -1127.305, -100.04), model = 'prop_laptop_01a', name = 'Notebook', reward = 'laptop', rotation = 0, carry = false },
                 { coords = vec3(125.519, -1131.701, -99.299), model = 'p_watch_03_s', name = 'Rolex', reward = 'rolex', rotation = 0, carry = false },
                 { coords = vec3(122.908, -1131.708, -100.084), model = 'prop_boombox_01', name = 'Rádio', reward = 'boombox', rotation = vec3(0, 0, -137.583) },
            },
            residents = {
                 { coords = vec4(127.25, -1128.33, -99.17, 247.23), models = {'A_M_O_GenStreet_01', 'U_M_Y_ProlDriver_01'} },
                 { coords = vec4(126.27, -1128.44, -99.17, 255.13), models = {'U_F_O_Eileen', 'S_F_Y_SweatShop_01'} },

            },
        },
    },
    houses = {
        -- { id = 'tier1_01', tier = 1, interior = 'tier1_small_01', coords = vec3(-46.34, -1446.24, 32.43) },
        -- { id = 'tier1_02', tier = 1, interior = 'tier1_small_02', coords = vec3(-139.48, -1588.042, 34.24) },
        -- { id = 'tier1_03', tier = 1, interior = 'tier1_small_02', coords = vec3(257.11, -1723.26, 29.65) },
        -- { id = 'tier1_04', tier = 1, interior = 'tier1_small_03', coords = vec3(455.21, -1579.75, 32.79) },
        -- { id = 'tier1_05', tier = 1, interior = 'tier1_small_01', coords = vec3(256.57, -2023.59, 19.27) },
        { id = 'tier1_01', tier = 1, interior = 'lev_apartment_shell', coords = vector3(-102.43, -31.9, 66.44) },
    },
}


