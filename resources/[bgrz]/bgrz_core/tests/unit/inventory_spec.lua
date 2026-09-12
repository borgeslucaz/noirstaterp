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

print('inventory_spec: ok')
