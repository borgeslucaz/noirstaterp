local T = dofile('tests/testlib.lua')
local N = T.loadShared()
local V = N.Validators

-- Identificadores e payload -------------------------------------------------------

T.equal(V.isIdentifier('docks'), true, 'plain identifier accepted')
T.equal(V.isIdentifier('la_mesa-1'), true, 'identifier with separators accepted')
T.equal(V.isIdentifier(''), false, 'empty identifier rejected')
T.equal(V.isIdentifier('drop table'), false, 'identifier with space rejected')
T.equal(V.isIdentifier(("a"):rep(41)), false, 'oversized identifier rejected')
T.equal(V.isIdentifier(12), false, 'non-string identifier rejected')

T.equal(V.isPositiveInteger(5, 10), true, 'integer within range accepted')
T.equal(V.isPositiveInteger(0), false, 'zero rejected')
T.equal(V.isPositiveInteger(-3), false, 'negative rejected')
T.equal(V.isPositiveInteger(2.5), false, 'fractional rejected')
T.equal(V.isPositiveInteger(11, 10), false, 'above maximum rejected')
T.equal(V.isPositiveInteger(0 / 0), false, 'NaN rejected')
T.equal(V.isPositiveInteger(math.huge), false, 'infinity rejected')
T.equal(V.isPositiveInteger('5'), false, 'numeric string rejected')

T.equal(V.isRequestId('r18f2a3b9c1'), true, 'request id accepted')
T.equal(V.isRequestId('short'), false, 'short request id rejected')
T.equal(V.isRequestId(("x"):rep(65)), false, 'oversized request id rejected')

-- Intervalo de vendas --------------------------------------------------------------

T.equal(V.saleInterval(75, 30, 70), 38, 'fast dealer interval')
T.equal(V.saleInterval(75, 30, 35), 64, 'slow dealer interval')
T.equal(V.saleInterval(75, 30, 100), 30, 'interval floors at the minimum')
T.equal(V.saleInterval(20, 30, 100), 30, 'minimum wins over a small base')

-- Lote e quantidade -----------------------------------------------------------------

T.equal(V.dealerLot(55, 20), 2, 'capacity 55 yields a lot of 2')
T.equal(V.dealerLot(10, 20), 1, 'lot never drops below one')
T.equal(V.dealerLot(80, 20), 4, 'capacity 80 yields a lot of 4')

local range = { min = 1, max = 3 }
T.equal(V.saleQuantity(range, 4, 10, 0.0), 1, 'lowest roll picks the minimum')
T.equal(V.saleQuantity(range, 4, 10, 0.99), 3, 'highest roll picks the maximum')
T.equal(V.saleQuantity(range, 2, 10, 0.99), 2, 'dealer lot caps the quantity')
T.equal(V.saleQuantity(range, 4, 2, 0.99), 2, 'stock caps the quantity')
T.equal(V.saleQuantity(range, 4, 0, 0.99), 0, 'no stock yields no sale')

-- Valores da venda -------------------------------------------------------------------

local amounts = V.saleAmounts(100, 2, 1.0, 0, 20)
T.equal(amounts.unitPrice, 100, 'unit price without modifiers')
T.equal(amounts.gross, 200, 'gross is price times quantity')
T.equal(amounts.commission, 40, 'commission is the split percentage')
T.equal(amounts.net, 160, 'net is gross minus commission')
T.equal(amounts.commission + amounts.net, amounts.gross, 'commission and net close the gross')

local negotiated = V.saleAmounts(100, 1, 1.0, 100, 0)
T.equal(negotiated.unitPrice, 110, 'negotiation raises the unit price')
T.equal(negotiated.net, 110, 'zero split keeps the full gross')

local jittered = V.saleAmounts(100, 1, 0.95, 0, 0)
T.equal(jittered.unitPrice, 95, 'jitter is applied to the unit price')

-- Loot do roubo -------------------------------------------------------------------------

local purseLoot, stockLoot = V.robberyLoot(1000, 100, 25, 10, 10)
T.equal(purseLoot, 250, 'purse loot follows the percentage')
T.equal(stockLoot, 10, 'stock loot is capped by the unit maximum')

purseLoot, stockLoot = V.robberyLoot(0, 0, 25, 10, 10)
T.equal(purseLoot, 0, 'empty purse yields no loot')
T.equal(stockLoot, 0, 'empty stock yields no loot')

purseLoot, stockLoot = V.robberyLoot(1000, 3, 10, 50, 10)
T.equal(stockLoot, 2, 'stock loot never exceeds the stock')

-- Transições ------------------------------------------------------------------------------

T.equal(V.canTransitionSession('READY', 'PROCESSING'), true, 'ready can process')
T.equal(V.canTransitionSession('PROCESSING', 'READY'), true, 'processing can return to ready')
T.equal(V.canTransitionSession('CLOSED', 'READY'), false, 'closed is terminal')
T.equal(V.canTransitionSession('OPENING', 'PROCESSING'), false, 'opening cannot process directly')

T.equal(V.canTransitionOutpost('available', 'claiming'), true, 'available can be claimed')
T.equal(V.canTransitionOutpost('claiming', 'controlled'), true, 'claiming can complete')
T.equal(V.canTransitionOutpost('available', 'controlled'), false, 'claim cannot be skipped')
T.equal(V.canTransitionOutpost('inactive', 'controlled'), false, 'inactive cannot be controlled')

-- Fechamento automático do painel ------------------------------------------------------------

-- Regressão: a pé o ox_lib entrega `cache.vehicle == false`, que não pode fechar o painel.
T.equal(V.shouldClosePanel({ dead = false, inVehicle = false, distance = 1.0 }, 4.0), false,
    'on foot and close by keeps the panel open')
T.equal(V.shouldClosePanel({ dead = false, inVehicle = true, distance = 1.0 }, 4.0), true,
    'entering a vehicle closes the panel')
T.equal(V.shouldClosePanel({ dead = true, inVehicle = false, distance = 1.0 }, 4.0), true,
    'dying closes the panel')
T.equal(V.shouldClosePanel({ dead = false, inVehicle = false, distance = 4.0 }, 4.0), false,
    'the limit itself keeps the panel open')
T.equal(V.shouldClosePanel({ dead = false, inVehicle = false, distance = 4.1 }, 4.0), true,
    'walking away closes the panel')
T.equal(V.shouldClosePanel({ dead = false, inVehicle = false, distance = nil }, 4.0), false,
    'an unknown distance never closes on its own')

-- Morte de corredor ----------------------------------------------------------------------------

-- Regressão: sem dono de rede o servidor lê vida 0 num ped vivo, e isso derrubava todos
-- os corredores que nenhum jogador estava por perto para transmitir.
T.equal(V.isDealerDown(false, false, 0), false, 'an unstreamed runner is not down')
T.equal(V.isDealerDown(false, true, 0), false, 'losing the owner does not kill a runner')
T.equal(V.isDealerDown(true, false, 0), false, 'health before ever seeing him alive is ignored')
T.equal(V.isDealerDown(true, true, 0), true, 'a streamed runner at zero health is down')
T.equal(V.isDealerDown(true, true, 200), false, 'a healthy runner stays up')
T.equal(V.isDealerDown(true, true, nil), false, 'unreadable health never downs a runner')

-- Permissões ---------------------------------------------------------------------------------

local permissions = { claim = 3, hire = 2, fire = 2, stock = 1, collect = 3, view = 0 }
T.equal(V.hasGrade(3, permissions, 'claim'), true, 'grade meets the claim requirement')
T.equal(V.hasGrade(2, permissions, 'claim'), false, 'grade below the claim requirement')
T.equal(V.hasGrade(nil, permissions, 'view'), false, 'missing grade denies everything')
T.equal(V.hasGrade(0, permissions, 'view'), true, 'grade zero can view')
T.equal(V.hasGrade(9, permissions, 'unknown'), false, 'unknown action denied')

local map = V.permissionMap(2, permissions, N.Constants.PermissionKeys)
T.equal(map.view, true, 'grade 2 can view')
T.equal(map.stock, true, 'grade 2 can stock')
T.equal(map.hire, true, 'grade 2 can hire')
T.equal(map.collect, false, 'grade 2 cannot collect')
T.equal(map.claim, false, 'grade 2 cannot claim')

print('validators_spec: ok')
