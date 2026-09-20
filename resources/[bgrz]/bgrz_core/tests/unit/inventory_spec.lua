local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { inventory = 'ox_inventory' }, Limits = { maxItemAmount = 100000 } }
local state = 'started'
local calls = {}
local provider = {}

function provider:AddItem(holder, item, amount, metadata)
    calls[#calls + 1] = { 'add', holder, item, amount, metadata }
    return true, { slot = 1 }
end

function provider:RemoveItem(holder, item, amount, metadata)
    calls[#calls + 1] = { 'remove', holder, item, amount, metadata }
    return amount ~= 9, amount == 9 and 'not_enough_items' or nil
end

function provider:GetItemCount(holder, item, metadata)
    calls[#calls + 1] = { 'count', holder, item, metadata }
    return 7
end

function provider:CanCarryItem(holder, item, amount, metadata)
    calls[#calls + 1] = { 'carry', holder, item, amount, metadata }
    return amount < 8
end

exports = T.exports({ ox_inventory = provider })
GetResourceState = function() return state end

dofile('shared/provider.lua')
dofile('server/inventory.lua')

local metadata = { batch = 'alpha' }
local ok, err = BGRZ.AddItem(12, 'weed_brick', 2, metadata)
T.equal(ok, true, 'AddItem success')
T.equal(err, nil, 'AddItem no error')
T.equal(calls[#calls][5], metadata, 'AddItem metadata forwarded')

ok, err = BGRZ.RemoveItem('outpost:docks', 'meth', 9)
T.equal(ok, false, 'RemoveItem provider refusal')
T.equal(err, 'not_enough_items', 'RemoveItem normalized provider reason')

local count, countErr = BGRZ.GetItemCount(12, 'cokebaggy', metadata)
T.equal(count, 7, 'GetItemCount value')
T.equal(countErr, nil, 'GetItemCount no error')

local canCarry, carryErr = BGRZ.CanCarryItem(12, 'weed_brick', 8)
T.equal(canCarry, false, 'CanCarryItem capacity refusal')
T.equal(carryErr, 'cannot_carry', 'CanCarryItem reason')

ok, err = BGRZ.AddItem(12, 'weed_brick', 1.5)
T.equal(ok, false, 'fractional amount rejected')
T.equal(err, 'invalid_amount', 'fractional amount code')

local before = #calls
ok, err = BGRZ.AddItem(12, '', 1)
T.equal(ok, false, 'blank item rejected')
T.equal(err, 'invalid_item', 'blank item code')
T.equal(#calls, before, 'invalid item not forwarded')

state = 'stopped'
ok, err = BGRZ.AddItem(12, 'weed_brick', 1)
T.equal(ok, false, 'stopped inventory rejected')
T.equal(err, 'provider_unavailable', 'stopped inventory code')

state = 'started'
provider.GetItemCount = function() error('provider exploded') end
count, countErr = BGRZ.GetItemCount(12, 'weed_brick')
T.equal(count, nil, 'provider exception count')
T.equal(countErr, 'provider_unavailable', 'provider exception normalized')

-- ---------------------------------------------------------------------------
-- GetItemLabel
-- ---------------------------------------------------------------------------
state = 'started'
provider.Items = function(_, item)
    if item == 'weed_brick' then return { label = 'Tijolo de Maconha' } end
    return nil
end

local label, labelErr = BGRZ.GetItemLabel('weed_brick')
T.equal(label, 'Tijolo de Maconha', 'GetItemLabel devolve o rótulo do provider')
T.equal(labelErr, nil, 'GetItemLabel sem erro no caminho feliz')

label, labelErr = BGRZ.GetItemLabel('item_que_nao_existe')
T.equal(label, 'item_que_nao_existe', 'item desconhecido cai para o próprio nome')
T.equal(labelErr, 'unknown_item', 'item desconhecido é sinalizado')

label, labelErr = BGRZ.GetItemLabel(42)
T.equal(label, nil, 'item não-string recusado')
T.equal(labelErr, 'invalid_item', 'código de erro estável')

state = 'stopped'
label, labelErr = BGRZ.GetItemLabel('weed_brick')
T.equal(label, 'weed_brick', 'provider parado ainda devolve algo legível')
T.equal(labelErr, 'provider_unavailable', 'provider parado é sinalizado')
state = 'started'

provider.Items = function() error('provider exploded') end
label, labelErr = BGRZ.GetItemLabel('weed_brick')
T.equal(label, 'weed_brick', 'exceção do provider não sobe')
T.equal(labelErr, 'unknown_item', 'exceção vira código tratado')

print('inventory_spec: ok')
