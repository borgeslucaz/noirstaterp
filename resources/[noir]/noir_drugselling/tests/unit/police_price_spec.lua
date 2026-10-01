-- lua5.4 tests/unit/police_price_spec.lua (na raiz do resource)
local RES = (os.getenv('RES') or './')
dofile(RES .. 'config/ServerConfig.lua')

local started = { noir_police = true }
local cops = 0
function GetResourceState(name) return started[name] and 'started' or 'missing' end
exports = { noir_police = { GetCopCount = function() return cops end } }
setmetatable(exports.noir_police, { __index = function() return nil end })

dofile(RES .. 'integrations/server/police.lua')

local function equal(actual, expected, message)
    if actual ~= expected then error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2) end
end

equal(NoirDrugPolice.multiplierFor(0), 0.5, 'sem polícia paga metade')
equal(NoirDrugPolice.multiplierFor(1), 1.0, 'um policial: preço cheio')
equal(NoirDrugPolice.multiplierFor(2), 1.0, 'dois policiais: preço cheio')
equal(NoirDrugPolice.multiplierFor(3), 1.2, 'três policiais: bônus')
equal(NoirDrugPolice.multiplierFor(12), 1.2, 'muitos policiais: bônus')

cops = 0
equal(NoirDrugPolice.multiplier(), 0.5, 'contagem real: zero')
cops = 4
equal(NoirDrugPolice.multiplier(), 1.2, 'contagem real: quatro')

started.noir_police = nil
equal(NoirDrugPolice.multiplier(), 0.5, 'noir_police fora: conta como zero')
started.noir_police = true

exports.noir_police.GetCopCount = function() error('quebrou') end
equal(NoirDrugPolice.multiplier(), 0.5, 'export com erro: conta como zero')

print('police_price_spec: ok')
