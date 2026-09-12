local T = dofile('tests/testlib.lua')

-- Stubs dos construtores de vetor usados por config/shared.lua.
function vector3(x, y, z) return { x = x, y = y, z = z } end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end

local shared = T.loadConfig('config/shared.lua')
local server = T.loadConfig('config/server.lua')
local client = T.loadConfig('config/client.lua')

local function read(path)
    local file = assert(io.open(path, 'r'))
    local content = file:read('*a')
    file:close()
    return content
end

-- Sigilo: nada econômico no config público -------------------------------------------

local sharedSource = read('config/shared.lua')
for _, forbidden in ipairs({ 'unitPrice', 'hirePrice', 'dispatchChance', 'pursePercent', 'adminAce' }) do
    assert(not sharedSource:find(forbidden, 1, true),
        ('config/shared.lua must not contain %s'):format(forbidden))
end

local manifest = read('fxmanifest.lua')
assert(manifest:find("'config/shared.lua'", 1, true), 'shared config must be downloadable')
assert(manifest:find("'config/client.lua'", 1, true), 'client config must be downloadable')
assert(not manifest:find("'config/server.lua'", 1, true), 'server config must not be in files')
assert(not manifest:find('ox_target', 1, true), 'providers are bgrz_core dependencies, not ours')
assert(not manifest:find('sd-phone', 1, true), 'phone provider is a bgrz_core dependency')
assert(manifest:find("'bgrz_core'", 1, true), 'bridge dependency declared')
assert(not manifest:find('noir_illegal_core', 1, true), 'progression bridge must not be a dependency')
assert(not manifest:find('noir_gangs', 1, true), 'gang provider is reached through bgrz_core')

-- Locais ------------------------------------------------------------------------------

local outpostCount = 0
for id, definition in pairs(shared.outposts) do
    outpostCount = outpostCount + 1
    assert(type(definition.label) == 'string' and #definition.label > 0, id .. ' needs a label')
    assert(definition.computer and definition.entrance, id .. ' needs computer and entrance coords')
    assert(#definition.dealerCorners >= 6, id .. ' needs at least six corners')
    assert(#definition.dealerCorners >= server.limits.maxDealersPerOutpost,
        id .. ' needs more corners than dealers')
    assert(#definition.typePool > 0, id .. ' needs a type pool')

    local seen = {}
    for index = 1, #definition.dealerCorners do
        local corner = definition.dealerCorners[index]
        local key = ('%s:%s'):format(corner.x, corner.y)
        assert(not seen[key], id .. ' has duplicate corners')
        seen[key] = true
    end
end
assert(outpostCount >= 3, 'at least three outposts must be registered')

local drugCapable = 0
for _, definition in pairs(shared.outposts) do
    for index = 1, #definition.typePool do
        if definition.typePool[index] == 'drug' then drugCapable = drugCapable + 1 break end
    end
end
assert(drugCapable >= server.rotation.activeDrugOutposts, 'not enough drug-capable outposts')

-- Perfis e economia ----------------------------------------------------------------------

assert(#shared.dealerProfiles >= 6, 'at least six dealer profiles for the MVP')
local profileKeys = {}
for index = 1, #shared.dealerProfiles do
    local profile = shared.dealerProfiles[index]
    assert(not profileKeys[profile.key], 'duplicate profile key ' .. profile.key)
    profileKeys[profile.key] = true
    assert(type(server.dealerHirePrice[profile.key]) == 'number', profile.key .. ' needs a hire price')
    for _, stat in ipairs({ 'speed', 'capacity', 'negotiation', 'split' }) do
        local value = profile.stats[stat]
        assert(type(value) == 'number' and value >= 0 and value <= 100,
            ('%s.%s must be between 0 and 100'):format(profile.key, stat))
    end
end

for index = 1, #shared.products do
    local product = shared.products[index]
    local rule = server.products[product.id]
    assert(rule, product.id .. ' needs a server-side rule')
    assert(rule.unitPrice > 0, product.id .. ' needs a positive price')
    assert(rule.quantity.min >= 1 and rule.quantity.max >= rule.quantity.min,
        product.id .. ' has an invalid quantity range')
end

-- Venda passiva deve render menos que a venda ativa do op-drugselling ------------------------
-- Referência do op-drugselling: weed_brick 50-100, meth 150-250, cokebaggy 450-700.
local activeFloor = { weed_brick = 50, meth = 150, cokebaggy = 450 }
for id, floorPrice in pairs(activeFloor) do
    local rule = server.products[id]
    if rule then
        assert(rule.unitPrice >= floorPrice, id .. ' passive price fell below the active floor')
        assert(rule.unitPrice <= floorPrice * 1.2,
            id .. ' passive price should stay close to the active floor')
    end
end

-- Limites coerentes ---------------------------------------------------------------------------

assert(server.limits.maxStockPerDeposit <= server.limits.maxStockTotal, 'deposit cap above total cap')
assert(server.limits.maxDealersPerOutpost == shared.limits.maxDealersPerOutpost,
    'dealer limit must match between shared and server config')
assert(server.limits.maxStockTotal == shared.limits.maxStockTotal, 'stock limit mismatch')
assert(server.limits.maxStockPerDeposit == shared.limits.maxStockPerDeposit, 'deposit limit mismatch')
assert(server.sales.minimumIntervalSeconds >= 30, 'minimum sale interval must be at least 30s')
assert(server.sales.baseIntervalSeconds >= server.sales.minimumIntervalSeconds, 'base below minimum')
assert(server.sales.maxStartupCatchupSalesPerDealer <= 1, 'startup catch-up must stay bounded')
assert(server.sales.dispatchChance >= 0 and server.sales.dispatchChance <= 100, 'invalid dispatch chance')
assert(server.sales.dispatchCooldownSeconds > 0, 'dispatch needs a cooldown')
assert(server.robbery.cooldownSeconds > 0, 'robbery needs a cooldown')
assert(server.robbery.pursePercent.max <= 100 and server.robbery.stockPercent.max <= 100,
    'robbery percentages must stay within 0-100')
assert(server.robbery.pursePercent.min <= server.robbery.pursePercent.max, 'invalid purse percent range')
assert(server.claim.durationMs >= 10000, 'claim must take a meaningful amount of time')
assert(server.claim.ownerDurationHours > 0, 'control duration must be positive')

for _, action in ipairs({ 'view', 'stock', 'hire', 'fire', 'collect', 'claim' }) do
    assert(type(server.permissions[action]) == 'number', 'missing permission for ' .. action)
end
assert(server.permissions.claim >= server.permissions.stock, 'claim must not be easier than stocking')
assert(server.permissions.collect >= server.permissions.stock, 'collect must not be easier than stocking')

-- Atendente do terminal (auxiliar de teste, mas precisa ser desligável e allowlisted)
local npc = shared.terminalNpc
assert(type(npc) == 'table', 'terminalNpc block missing')
assert(type(npc.enabled) == 'boolean', 'terminalNpc.enabled must be a boolean')
assert(type(npc.model) == 'string' and npc.model:match('^[%w_]+$'), 'terminalNpc.model must be a plain model name')
assert(npc.scenario == nil or type(npc.scenario) == 'string', 'terminalNpc.scenario must be a string when set')
for id, definition in pairs(shared.outposts) do
    assert(definition.terminalNpc == nil or definition.terminalNpc == false,
        id .. ' may only disable terminalNpc, never redefine it')
end

assert(type(shared.phone.identifier) == 'string' and shared.phone.identifier:match('^[%w_-]+$'),
    'phone identifier must be a plain slug')
assert(type(shared.phone.defaultApp) == 'boolean', 'phone.defaultApp must be a boolean')

assert(type(client.animations.claim.dict) == 'string', 'claim animation dictionary missing')
assert(client.progress.depositDurationMs > 0, 'deposit progress duration missing')
assert(shared.payoutItem == server.payout.item, 'payout item mismatch between configs')

-- Locales ---------------------------------------------------------------------------------------

local ptbr = read('locales/pt-br.json')
local en = read('locales/en.json')
for _, key in ipairs({
    'target', 'progress', 'dealer', 'claim', 'robbery', 'phone', 'dispatch', 'error',
}) do
    assert(ptbr:find('"' .. key .. '"', 1, true), 'pt-br locale missing section ' .. key)
    assert(en:find('"' .. key .. '"', 1, true), 'en locale missing section ' .. key)
end

print('config_spec: ok')
