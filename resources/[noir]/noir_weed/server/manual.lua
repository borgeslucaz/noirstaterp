---Guia de Cultivo: o item abre um livro na NUI. Os números do livro saem daqui, do config
---do servidor, na hora de abrir; mexer no balanceamento não deixa o guia desatualizado.

local Shared = require 'config.shared'
local Config = require 'config.server'
local Integrations = require 'server.integrations'

---Minutos de 0 a 100% com as taxas dadas.
---@param growth { interval: number, gain: number }
---@param factor? number
---@return integer
local function minutesToGrow(growth, factor)
    local ticks = math.ceil(Shared.harvestAt / (growth.gain * (factor or 1)))
    return math.floor(ticks * growth.interval / 60000 + 0.5)
end

lib.callback.register('noir_weed:server:manual', function(source)
    if Integrations.count(source, Shared.items.manual) < 1 then return { ok = false, code = 'no_manual' } end
    local skill, perks = Config.skill, Config.skill.perks
    return {
        ok = true,
        manual = {
            maxPlants = Config.maxPlants,
            reward = Config.reward,
            minutes = minutesToGrow(Config.growth),
            minutesFast = minutesToGrow(Config.growth, perks.fastGrowth.factor),
            care = Config.care,
            initial = Config.initial,
            gradeByCare = Config.gradeByCare,
            xpPerHarvest = skill.xpPerHarvest,
            xpPerBud = skill.xpPerBud,
            yieldByLevel = skill.yieldByLevel,
            gradeCapByLevel = skill.gradeCapByLevel,
            perks = {
                thirst = { level = perks.thirst.level, percent = math.floor((1 - perks.thirst.factor) * 100 + 0.5) },
                fastGrowth = { level = perks.fastGrowth.level },
                seedBack = { level = perks.seedBack.level, amount = perks.seedBack.amount },
                extraPot = { level = perks.extraPot.level, amount = perks.extraPot.amount },
            },
            roll = Shared.roll,
            grinderUses = math.floor(100 / Shared.grinderCost),
        },
    }
end)
