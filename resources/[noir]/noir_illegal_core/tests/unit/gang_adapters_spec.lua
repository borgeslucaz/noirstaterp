-- Run from the resource root with Lua 5.4:
-- lua tests/unit/gang_adapters_spec.lua
-- Adaptadores da reputação de gang: peso da venda, bairro tomado/perdido/segurado.

NoirIllegal = {}
dofile('shared/config.lua')
dofile('server/validators.lua')

local function equal(actual, expected, label)
    assert(actual == expected, ('%s: expected %s, got %s'):format(label, tostring(expected), tostring(actual)))
end

local handlers, orgRecords, playerRecords, invoking = {}, {}, {}, nil
function AddEventHandler(name, fn) handlers[name] = fn end
function GetInvokingResource() return invoking end
function CreateThread() end
function Wait() end
NoirIllegal.Adapters = {}
dofile('server/adapters/adapters.lua')
NoirIllegal.Adapters.record = function(source, key, id, options)
    playerRecords[#playerRecords + 1] = { source = source, key = key, id = id, options = options }
end
NoirIllegal.Adapters.recordOrganization = function(org, key, id, options)
    orgRecords[#orgRecords + 1] = { org = org, key = key, id = id, options = options }
end
dofile('server/adapters/drugselling.lua')
dofile('server/adapters/territories.lua')

local Adapters = NoirIllegal.Adapters

-- Peso da venda: grau × droga.
equal(Adapters.saleWeight('weed_skunk_baggy', 'B'), 1.0, 'baggy grade B')
equal(Adapters.saleWeight('weed_skunk_baggy', 'S'), 1.5, 'baggy grade S')
equal(Adapters.saleWeight('weed_og-kush_brick', 'C'), 3.2, 'brick grade C')
equal(Adapters.saleWeight('cokebaggy', nil), 2.0, 'coke without grade counts as B')
equal(Adapters.saleWeight('meth', 'A'), 1.875, 'meth grade A')
equal(Adapters.saleWeight('unknown_thing', 'B'), 1.0, 'unknown drug weighs 1')

invoking = 'noir_drugselling'
handlers['noir_drugselling:server:saleCompleted']({ source = 4, drug = 'cokebaggy', grade = 'S', amount = 2 })
equal(playerRecords[1].key, 'drug_sale', 'sale recorded')
equal(playerRecords[1].options.weight, 3.0, 'sale carries the weight')

-- Bairro: tomada paga a gang nova, perda cobra a antiga, troca de admin não faz nada.
local function change(...)
    orgRecords = {}
    invoking = 'noir_territories'
    handlers['noir_territories:server:ownerChanged'](...)
    return orgRecords
end

local r = change('davis', 'ballas', 'vagos', 'influence')
equal(#r, 2, 'taken and lost')
equal(r[1].key, 'territory_taken', 'new owner takes')
equal(r[1].org, 'ballas', 'taken by ballas')
equal(r[2].key, 'territory_lost', 'old owner loses')
equal(r[2].org, 'vagos', 'lost by vagos')
local firstId = r[1].id
equal(change('davis', 'ballas', 'vagos', 'influence')[1].id, firstId, 'same neighborhood, same gang, same day: same id')

equal(#change('davis', 'ballas', 'vagos', 'admin'), 0, 'admin change pays nothing and costs nothing')
r = change('davis', nil, 'vagos', 'influence')
equal(#r, 1, 'decay to nobody only costs')
equal(r[1].key, 'territory_lost', 'loss')
equal(#change('davis', 'ballas', nil, 'influence'), 1, 'first owner only takes')

-- Bairro segurado: só paga com atividade da gang ali nas últimas 24h.
local activity = { ['davis:ballas'] = 1000 }
exports = { noir_territories = setmetatable({
    getOwnedTerritories = function() return { davis = 'ballas', grove = 'families' } end,
    getGangActivity = function(_, zone, gang) return activity[zone .. ':' .. gang] or 0 end,
}, { __index = function() return nil end }) }
function GetResourceState() return 'started' end

orgRecords = {}
equal(Adapters.payHeldTerritories(1000 + 3600), 1, 'only the active gang is paid')
equal(orgRecords[1].org, 'ballas', 'ballas worked davis')
orgRecords = {}
equal(Adapters.payHeldTerritories(1000 + 86400 + 1), 0, 'a day without activity pays nothing')

print('gang_adapters_spec: ok')
