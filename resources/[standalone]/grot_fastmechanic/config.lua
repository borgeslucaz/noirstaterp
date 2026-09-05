Config = {}

Config.Locale = 'pt-br'
-- ============================================
-- GENERAL SETTINGS
-- ============================================

-- Command to open the menu while inside a vehicle
Config.OpenCommand = 'tunetest'

-- Enable mechanic access at specific stationary locations (true/false)
Config.EnableMechanicLocations = true

-- Interaction distance with the mechanic marker (meters)
Config.InteractionDistance = 3.0

-- Key to open the menu at the mechanic location (E = 38)
Config.MechanicKey = 38

-- ============================================
-- MECHANIC LOCATIONS
-- ============================================
Config.MechanicLocations = {
    {
        enabled = true,
        coords = vector3(-334.39, -134.43, 39.01),
        heading = 70.0,
        blipEnabled = true,
        blipSprite = 72,
        blipColor = 3,
        blipScale = 0.8,
        blipName = "Los Santos Customs - Vinewood",
        markerType = 27,
        markerColor = {r = 0, g = 255, b = 0, a = 100},
        markerSize = {x = 2.0, y = 2.0, z = 1.0}
    },
    {
        enabled = true,
        coords = vector3(-1152.76, -2007.23, 13.18),
        heading = 315.0,
        blipEnabled = true,
        blipSprite = 72,
        blipColor = 3,
        blipScale = 0.8,
        blipName = "Los Santos Customs - Aeroporto",
        markerType = 27,
        markerColor = {r = 0, g = 255, b = 0, a = 100},
        markerSize = {x = 2.0, y = 2.0, z = 1.0}
    },
    {
        enabled = true,
        coords = vector3(731.29, -1088.83, 22.17),
        heading = 270.0,
        blipEnabled = true,
        blipSprite = 72,
        blipColor = 3,
        blipScale = 0.8,
        blipName = "Los Santos Customs - Leste",
        markerType = 27,
        markerColor = {r = 0, g = 255, b = 0, a = 100},
        markerSize = {x = 2.0, y = 2.0, z = 1.0}
    },
    {
        enabled = true,
        coords = vector3(1181.46, 2640.85, 37.81),
        heading = 0.0,
        blipEnabled = true,
        blipSprite = 72,
        blipColor = 3,
        blipScale = 0.8,
        blipName = "Los Santos Customs - Sandy Shores",
        markerType = 27,
        markerColor = {r = 0, g = 255, b = 0, a = 100},
        markerSize = {x = 2.0, y = 2.0, z = 1.0}
    },
    {
        enabled = true,
        coords = vector3(110.81, 6626.51, 31.79),
        heading = 45.0,
        blipEnabled = true,
        blipSprite = 72,
        blipColor = 3,
        blipScale = 0.8,
        blipName = "Los Santos Customs - Paleto",
        markerType = 27,
        markerColor = {r = 0, g = 255, b = 0, a = 100},
        markerSize = {x = 2.0, y = 2.0, z = 1.0}
    },
    {
        enabled = true,
        coords = vector3(-211.55, -1324.55, 30.89),
        heading = 0.0,
        blipEnabled = true,
        blipSprite = 72,
        blipColor = 5,
        blipScale = 0.8,
        blipName = "Benny's Motorworks",
        markerType = 27,
        markerColor = {r = 0, g = 255, b = 0, a = 100},
        markerSize = {x = 2.0, y = 2.0, z = 1.0}
    },
}

-- Mechanical tuning configuration
Config.Performance = {
    {id = 'engine', label = 'Motor', modType = 11, levels = 4},
    {id = 'brakes', label = 'Freios', modType = 12, levels = 3},
    {id = 'transmission', label = 'Transmissão', modType = 13, levels = 3},
    {id = 'suspension', label = 'Suspensão', modType = 15, levels = 4},
    {id = 'armor', label = 'Blindagem', modType = 16, levels = 5},
    {id = 'turbo', label = 'Turbo', modType = 18, levels = 1},
}

-- Visual tuning configuration
Config.Visual = {
    {id = 'spoiler', label = 'Aerofólio', modType = 0},
    {id = 'fbumper', label = 'Para-choque dianteiro', modType = 1},
    {id = 'rbumper', label = 'Para-choque traseiro', modType = 2},
    {id = 'skirt', label = 'Saias laterais', modType = 3},
    {id = 'exhaust', label = 'Escapamento', modType = 4},
    {id = 'frame', label = 'Chassi', modType = 5},
    {id = 'grille', label = 'Grade', modType = 6},
    {id = 'hood', label = 'Capô', modType = 7},
    {id = 'fender', label = 'Para-lama esquerdo / Extras 1', modType = 8},
    {id = 'rfender', label = 'Para-lama direito / Extras 2', modType = 9},
    {id = 'roof', label = 'Teto / Barra de luz', modType = 10},
    {id = 'vanity', label = 'Moldura da placa', modType = 25},
    {id = 'trim1', label = 'Acabamento interno', modType = 27},
    {id = 'ornaments', label = 'Ornamentos', modType = 28},
    {id = 'dashboard', label = 'Painel', modType = 29},
    {id = 'dials', label = 'Mostradores', modType = 30},
    {id = 'doors', label = 'Alto-falantes das portas', modType = 31},
    {id = 'seats', label = 'Bancos', modType = 32},
    {id = 'steering_wheel', label = 'Volante', modType = 33},
    {id = 'gear_lever', label = 'Alavanca de câmbio', modType = 34},
    {id = 'plaques', label = 'Placas internas', modType = 35},
    {id = 'speakers', label = 'Sistema de áudio', modType = 36},
    {id = 'trunk', label = 'Som no porta-malas', modType = 37},
    {id = 'hydraulics', label = 'Hidráulica', modType = 38},
    {id = 'engine_block', label = 'Bloco do motor', modType = 39},
    {id = 'air_filter', label = 'Filtro de ar', modType = 40},
    {id = 'strut', label = 'Barra estrutural', modType = 41},
    {id = 'arch_cover', label = 'Cobertura dos arcos', modType = 42},
    {id = 'aerials', label = 'Antenas / Teto 2', modType = 43},
    {id = 'trim2', label = 'Acabamento externo', modType = 44},
    {id = 'tank', label = 'Tanque', modType = 45},
    {id = 'windows', label = 'Janelas', modType = 46},
    {id = 'livery', label = 'Estampa', modType = 48},
}

-- Colors configuration
Config.Colors = {
    {id = 0, label = 'Preto'},
    {id = 1, label = 'Preto grafite'},
    {id = 2, label = 'Preto aço'},
    {id = 3, label = 'Prata escuro'},
    {id = 4, label = 'Prata'},
    {id = 5, label = 'Prata azulado'},
    {id = 6, label = 'Cinza aço'},
    {id = 7, label = 'Cinza escuro'},
    {id = 8, label = 'Cinza'},
    {id = 9, label = 'Cinza claro'},
    {id = 10, label = 'Branco'},
    {id = 27, label = 'Vermelho'},
    {id = 28, label = 'Vermelho Torino'},
    {id = 29, label = 'Vermelho Fórmula'},
    {id = 30, label = 'Vermelho lava'},
    {id = 31, label = 'Vermelho Blaze'},
    {id = 32, label = 'Vermelho Grace'},
    {id = 33, label = 'Vinho'},
    {id = 34, label = 'Bordô'},
    {id = 35, label = 'Vermelho violeta'},
    {id = 36, label = 'Vermelho vivo'},
    {id = 37, label = 'Vermelho escuro'},
    {id = 38, label = 'Vermelho vulcânico'},
    {id = 54, label = 'Laranja'},
    {id = 55, label = 'Laranja claro'},
    {id = 56, label = 'Laranja ferrugem'},
    {id = 57, label = 'Laranja amarronzado'},
    {id = 88, label = 'Amarelo'},
    {id = 89, label = 'Amarelo corrida'},
    {id = 90, label = 'Amarelo bronze'},
    {id = 91, label = 'Amarelo escuro'},
    {id = 49, label = 'Verde escuro'},
    {id = 50, label = 'Verde corrida'},
    {id = 51, label = 'Verde mar'},
    {id = 52, label = 'Verde oliva'},
    {id = 53, label = 'Verde claro'},
    {id = 61, label = 'Azul'},
    {id = 62, label = 'Azul escuro'},
    {id = 63, label = 'Azul saxão'},
    {id = 64, label = 'Azul marina'},
    {id = 65, label = 'Azul porto'},
    {id = 66, label = 'Azul diamante'},
    {id = 67, label = 'Azul surf'},
    {id = 68, label = 'Azul náutico'},
    {id = 69, label = 'Azul corrida'},
    {id = 70, label = 'Azul claro'},
    {id = 71, label = 'Azul púrpura'},
    {id = 72, label = 'Azul púrpura escuro'},
    {id = 73, label = 'Azul violeta'},
    {id = 143, label = 'Roxo'},
    {id = 144, label = 'Roxo escuro'},
    {id = 145, label = 'Roxo brilhante'},
    {id = 92, label = 'Marrom'},
    {id = 94, label = 'Marrom terra'},
    {id = 95, label = 'Marrom chocolate'},
    {id = 96, label = 'Marrom bege'},
    {id = 97, label = 'Marrom areia'},
    {id = 98, label = 'Marrom claro'},
}

-- Wheels categories configuration
Config.Wheels = {
    {id = 0, label = 'Sport'},
    {id = 1, label = 'Muscle'},
    {id = 2, label = 'Lowrider'},
    {id = 3, label = 'SUV'},
    {id = 4, label = 'Offroad'},
    {id = 5, label = 'Tuner'},
    {id = 6, label = 'High End'},
}

-- Vehicle Handling real-time configuration limits
Config.Handling = {
    {id = 'speed', label = 'Velocidade máxima', min = 0.5, max = 3.0, default = 1.0, step = 0.1},
    {id = 'acceleration', label = 'Aceleração', min = 0.5, max = 3.0, default = 1.0, step = 0.1},
    {id = 'braking', label = 'Força de frenagem', min = 0.5, max = 3.0, default = 1.0, step = 0.1},
    {id = 'traction', label = 'Tração', min = 0.5, max = 3.0, default = 1.0, step = 0.1},
    {id = 'suspension', label = 'Altura da suspensão', min = -0.2, max = 0.2, default = 0.0, step = 0.01},
    {id = 'downforce', label = 'Força aerodinâmica', min = 0.0, max = 5.0, default = 1.0, step = 0.1},
    -- Stance options (utilizes dynamic FiveM natives that natively manipulate specific wheel offsets and camber angles)
    {id = 'camber', label = 'Cambagem', min = -0.25, max = 0.1, default = 0.0, step = 0.01},
    {id = 'trackWidth', label = 'Largura das rodas', min = 0.0, max = 0.2, default = 0.0, step = 0.005},
}

-- Window tint configuration
Config.WindowTints = {
    {id = 0, label = 'Nenhuma / Original'},
    {id = 1, label = 'Preto puro'},
    {id = 2, label = 'Fumê escuro'},
    {id = 3, label = 'Fumê claro'},
    {id = 4, label = 'Original'},
    {id = 5, label = 'Limusine'},
    {id = 6, label = 'Verde'},
}

-- Xenon headlights color configurations
Config.XenonColors = {
    {id = 255, label = 'Padrão (branco)'},
    {id = 0, label = 'Branco'},
    {id = 1, label = 'Azul'},
    {id = 2, label = 'Azul elétrico'},
    {id = 3, label = 'Verde menta'},
    {id = 4, label = 'Verde limão'},
    {id = 5, label = 'Amarelo'},
    {id = 6, label = 'Dourado'},
    {id = 7, label = 'Laranja'},
    {id = 8, label = 'Vermelho'},
    {id = 9, label = 'Rosa'},
    {id = 10, label = 'Rosa claro'},
    {id = 11, label = 'Roxo'},
    {id = 12, label = 'Ultravioleta'},
}
