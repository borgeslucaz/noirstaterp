Config = Config or {}

-- ============================================================
-- INTERNAL CONFIGURATION (ADVANCED)
-- This file contains technical defaults and system settings.
-- Only modify these if you know what you are doing.
-- For user-facing settings, see shared/config.lua
-- ============================================================

-- Version Checker
Config.EnableVersionChecker = false -- fork Noir State: não comparar com o upstream
Config.VersionURL = 'https://raw.githubusercontent.com/Peak-Studios/noir-truckjob/main/version.json'

-- Admin
Config.AdminGroups = { 'group.admin', 'admin', 'god', 'superadmin' }
Config.AdminAce    = 'admin'

-- XP thresholds — uma entrada por nível (60 níveis; o tamanho da tabela é o nível máximo).
-- Config.XP[i] é o XP para passar do nível i ao i+1. i × 110 fecha o 60 em ~4 semanas
-- com 2 tentativas de carga por dia disputando a rotação global.
Config.XP = {}

CreateThread(function()
    for i = 1, 60 do
        table.insert(Config.XP, i * 110)
    end
end)
