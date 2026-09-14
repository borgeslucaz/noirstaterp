Config = {}

-- Debug Settings
Config.Debug = false -- Set to true to enable debug prints

-- Basic Settings
Config.BenchModel = 'gr_prop_gr_bench_02b'
Config.BenchItem = 'crafting_bench'

-- Discord Webhook (optional)
Config.Discord = {
    enabled = false,
    webhook = '',
    logCrafting = true,
    logBenchPlacement = true,
    botName = 'Noir Guncraft',
    color = 3066993 -- Default green color
}

-- Target System Detection
Config.Target = 'auto' -- 'qb-target', 'ox_target', 'interact', or 'auto'

-- Segurança. O upstream confiava no benchId que o cliente mandava, sem conferir
-- dono nem distância, então qualquer jogador abria a bancada de qualquer um
-- chutando ids sequenciais. Tudo aqui é aplicado no servidor.
Config.Security = {
    -- Distância máxima (m) entre o jogador e a bancada para qualquer ação.
    maxDistance = 3.0,
    -- true = só o dono abre as stashes e crafta. false = quem chegar perto usa,
    -- que é como o target sempre funcionou (a bancada é um objeto no mundo).
    requireOwnerForStash = false,
    -- Teto de itens por craft.
    maxCraftQuantity = 10,
    -- Intervalo mínimo (s) entre pedidos de sincronia de bancadas por jogador.
    benchSyncCooldown = 5,
}

-- Capacidade das stashes de cada bancada. O upstream vinha com 5.000.000g
-- (5 toneladas) em materials e storage, o que na prática é armazenamento
-- infinito e transforma a bancada no melhor cofre do servidor.
Config.Stashes = {
    materials  = { slots = 50, weight = 250000 },
    blueprints = { slots = 10, weight = 50000 },
    storage    = { slots = 50, weight = 250000 },
}

-- Distância (m) em que as bancadas viram objeto no mundo do cliente.
-- O upstream criava um CreateObject para toda bancada do servidor, em todo
-- cliente, para sempre.
Config.StreamDistance = 100.0

-- Craft pronto e não coletado é movido para a storage da bancada depois deste
-- tempo (s). O upstream simplesmente apagava a linha e o item sumia.
Config.AutoCollectAfter = 7200

-- Theme Configuration
Config.ThemeFile = 'theme.json'

-- Workbench Camera Settings (o resto vive em shared/weapons.lua)
Config.WorkbenchCamera = {
    offset = vector3(0.0, -1.2, 1.4),
    target = vector3(0.0, 0.0, 1.2),
    fov = 40.0,
    transitionTime = 1500,
}

-- Recipe Configuration Files
local function loadConfig(file)
    local content = LoadResourceFile(GetCurrentResourceName(), file)
    if not content then return {} end
    local chunk = load(content)
    return chunk and chunk() or {}
end

Config.Recipes = loadConfig('config/recipes.lua')
Config.Blueprints = loadConfig('config/blueprints.lua')
