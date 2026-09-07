-- Initial stop dataset adapted from Lachee/fivem-busdriver (MIT).
return {
    debug = false,
    Depot = {
        coords = vector4(449.37, -658.14, 28.45, 239.5),
        pedModel = 's_m_m_gentransport',
        radius = 30.0,
        spawn = vector4(471.04, -583.88, 28.5, 175.5)
    },
    stop = {
        radius = 9.0,
        maxDoorSpeedKmh = 3.0,
        maxDockSpeedKmh = 8.0,
        -- Maximum time the bus remains locked at a stop. It unlocks sooner
        -- when every passenger has completed the boarding animation.
        serviceTimeoutMs = 25000,
        pedExitTimeoutMs = 7000,
        pedEnterTimeoutMs = 10000
    },
    vehicleFailure = {
        engineHealth = 0.0
    },
    passenger = {
        spawnDistance = 150.0,
        spawnRadius = 2.0,
        minDemand = 0,
        maxDemand = 5,
        exitDespawnMs = 25000
    },
    vehicleProfiles = {
        bus = {
            class = 'urban',
            capacity = 11,
            doors = {0, 1}
        },
        coach = {
            class = 'coach',
            capacity = 9,
            doors = {0, 1}
        },
        tourbus = {
            class = 'tour',
            capacity = 9,
            doors = {0, 1}
        }
    },
    progression = {{
        level = 1,
        xp = 0,
        title = 'Motorista Aprendiz',
        unlocks = {'M01 Centro', 'I02 Industrial', 'Bus'}
    }, {
        level = 2,
        xp = 1500,
        title = 'Motorista Urbano',
        unlocks = {'M03 Metropolitana'}
    }, {
        level = 3,
        xp = 3000,
        title = 'Operador Municipal',
        unlocks = {'C04 Costa Oeste'}
    }, {
        level = 4,
        xp = 5000,
        title = 'Motorista Sênior',
        unlocks = {'Horário de Pico'}
    }, {
        level = 5,
        xp = 7500,
        title = 'Motorista Expresso',
        unlocks = {'X05 Sandy Shores', 'Coach'}
    }, {
        level = 6,
        xp = 10000,
        title = 'Motorista Regional',
        unlocks = {'Serviço Expresso'}
    }, {
        level = 7,
        xp = 15000,
        title = 'Motorista Intermunicipal',
        unlocks = {'R06 Route 68'}
    }, {
        level = 8,
        xp = 20000,
        title = 'Especialista de Frota',
        unlocks = {'Turismo / Tour'}
    }, {
        level = 9,
        xp = 25000,
        title = 'Supervisor de Linha',
        unlocks = {'Serviço Prioritário'}
    }, {
        level = 10,
        xp = 30000,
        title = 'Mestre de Operações',
        unlocks = {'Todo conteúdo operacional'}
    }},
    stops = {
        [3] = {
            name = 'Strawberry Ave',
            coords = vec4(302.49, -760.16, 29.31, 256.85)
        },
        [5] = {
            name = 'San Andreas Ave',
            coords = vec4(120.53, -780.38, 31.37, 154.51)
        },
        [6] = {
            name = 'Alta St',
            coords = vec4(-177.06, -811.17, 31.26, 256.12)
        },
        [8] = {
            name = 'Peaceful St / Vespucci',
            coords = vector4(-265.58, -826.85, 31.77, 74.22)
        },
        [10] = {
            name = 'San Andreas Ave East',
            coords = vec4(-508.17, -674.7, 33.13, 357.76)
        },
        [11] = {
            name = 'San Andreas Ave West',
            coords = vec4(-696.0, -673.09, 30.79, 350.33)
        },
        [12] = {
            name = 'Vespucci Blvd / Ginger St',
            coords = vec4(-713.22, -821.24, 23.6, 181.49)
        },
        [13] = {
            name = 'Ginger St',
            coords = vec4(-735.29, -754.58, 26.61, 92.54)
        },
        [14] = {
            name = 'Vespucci Blvd East',
            coords = vec4(-559.14, -852.15, 27.47, 2.24)
        },
        [16] = {
            name = 'Strawberry Ave / Macdonald St',
            coords = vec4(55.87, -1539.37, 29.29, 50.63)
        },
        [18] = {
            name = 'Carson Ave',
            coords = vec4(434.95, -2032.91, 23.39, 319.51)
        },
        [22] = {
            name = 'Popular St South',
            coords = vec4(819.23, -1636.33, 30.56, 271.02)
        },
        [24] = {
            name = 'Popular St / Olympic Fwy',
            coords = vec4(782.43, -1367.56, 26.57, 278.93)
        },
        [25] = {
            name = 'Popular St North',
            coords = vec4(764.71, -940.38, 25.68, 275.91)
        },
        [27] = {
            name = 'Hawick Ave / Boulevard Del Perro',
            coords = vec4(-501.22, 27.24, 44.79, 188.06)
        },
        [28] = {
            name = 'Boulevard Del Perro / Rockford Dr',
            coords = vec4(-697.08, -1.81, 38.22, 211.24)
        },
        [29] = {
            name = 'Boulevard Del Perro / Mad Wayne Thunder Dr',
            coords = vec4(-931.81, -119.98, 37.78, 195.34)
        },
        [30] = {
            name = 'Boulevard Del Perro West',
            coords = vec4(-1527.81, -460.28, 35.42, 211.53)
        },
        [31] = {
            name = 'Marathon Ave',
            coords = vec4(-1167.3, -394.93, 34.68, 185.94)
        },
        [32] = {
            name = 'Marathon Ave / Prosperity St',
            coords = vec4(-1412.64, -563.84, 29.35, 212.87)
        },
        [36] = {
            name = 'Bay City Ave / Invention Ct',
            coords = vec4(-1218.96, -1219.37, 6.69, 284.58)
        },
        [37] = {
            name = 'Magellan Ave / Aguja St',
            coords = vec4(-1174.37, -1474.17, 3.38, 313.82)
        },
        [38] = {
            name = 'Dashound Terminal',
            coords = vec4(453.81, -622.52, 27.52, 259.08)
        },
        [40] = {
            name = 'Sandy Shores',
            coords = vec4(1932.02, 3719.43, 31.87, 214.55)
        },
        [41] = {
            name = 'Grand Senora Desert',
            coords = vec4(1183.52, 2694.71, 36.94, 194.18)
        },
        [45] = {
            name = 'Route 68 West',
            coords = vec4(-2531.68, 2343.37, 33.8786, 32.8264)
        },
        [46] = {
            name = 'Route 68 / Harmony',
            coords = vec4(-1116.8, 2683.68, 17.62, 238.26)
        },
        [49] = {
            name = 'Palomino Ave / Lindsay Circus',
            coords = vec4(-617.35, -905.17, 23.29, 155.96)
        },
        [50] = {
            name = 'Hawick Ave / Alta Pl',
            coords = vec4(149.72, -212.14, 53.31, 334.1)
        }
    },
    routes = {
        small_metro = {
            code = 'M01',
            name = 'Linha M01 · Centro',
            minimumLevel = 1,
            vehicle = 'bus',
            stops = {3, 5, 6, 8, 38},
            reward = {
                basePay = 180,
                baseXp = 120
            }
        },
        industry = {
            code = 'I02',
            name = 'Linha I02 · Industrial',
            minimumLevel = 1,
            vehicle = 'bus',
            stops = {50, 25, 24, 22, 18, 16, 38},
            reward = {
                basePay = 220,
                baseXp = 150
            }
        },
        medium_metro = {
            code = 'M03',
            name = 'Linha M03 · Metropolitana',
            minimumLevel = 2,
            vehicle = 'bus',
            stops = {5, 31, 32, 36, 12, 13, 11, 10, 38},
            reward = {
                basePay = 280,
                baseXp = 180
            }
        },
        long_beach = {
            code = 'C04',
            name = 'Linha C04 · Costa Oeste',
            minimumLevel = 3,
            vehicle = 'bus',
            stops = {27, 28, 29, 30, 36, 37, 49, 14, 8, 38},
            reward = {
                basePay = 360,
                baseXp = 230
            }
        },
        sandy_express = {
            code = 'X05',
            name = 'Expresso X05 · Sandy Shores',
            minimumLevel = 5,
            vehicle = 'coach',
            stops = {38, 40, 38},
            reward = {
                basePay = 520,
                baseXp = 300
            }
        },
        long_rural = {
            code = 'R06',
            name = 'Regional R06 · Route 68',
            minimumLevel = 7,
            vehicle = 'coach',
            stops = {38, 40, 41, 46, 45, 38},
            reward = {
                basePay = 700,
                baseXp = 380
            }
        }
    }
}
