-- Run from the resource root with Lua 5.4:
-- lua tests/unit/heat_spec.lua
-- Heat por hora jogada: offline não decai, login zera o relógio, logout grava o decaimento.

NoirIllegal = { Services = {}, Repositories = {} }
dofile('shared/config.lua')
dofile('server/validators.lua')
dofile('server/services/heat_service.lua')

local function equal(actual, expected, label)
    assert(actual == expected, ('%s: expected %s, got %s'):format(label, tostring(expected), tostring(actual)))
end

local Heat = NoirIllegal.Services.Heat
NoirIllegal.Config.Heat.decayPerSecond = 0.5

equal(Heat.calculate(10, 100, 110, true), 5, 'online decays')
equal(Heat.calculate(10, 100, 110, false), 10, 'offline does not decay')
equal(Heat.calculate(10, 100, 10000, false), 10, 'offline for hours does not decay')

-- Banco falso: uma linha por personagem.
local rows, now = {}, 1000
os.time = function() return now end
NoirIllegal.Logger = { error = function() end }
NoirIllegal.Validators.randomUuid = function() return 'uuid' end
TriggerEvent = function() end
MySQL = { startTransaction = function(fn) return fn('q') end }
NoirIllegal.Repositories.Heat = {
    ensure = function(cid) rows[cid] = rows[cid] or { value = 0, last_decay_epoch = now } end,
    get = function(cid) return rows[cid] end,
    touch = function(cid, at) rows[cid].last_decay_epoch = at end,
    set = function(cid, value, at) rows[cid] = { value = value, last_decay_epoch = at } end,
}

rows.CID1 = { value = 40, last_decay_epoch = 0 }
equal(Heat.isOnline('CID1'), false, 'starts offline')
equal(Heat.read('CID1'), 40, 'offline read keeps the value')

-- Login depois de muito tempo fora: o tempo offline não conta.
now = 5000
Heat.startSession(7, 'CID1')
equal(Heat.isOnline('CID1'), true, 'online after login')
equal(rows.CID1.last_decay_epoch, 5000, 'login resets the decay clock')
equal(rows.CID1.value, 40, 'login does not decay')

-- 20 s jogados a 0.5/s = 10.
now = 5020
equal(Heat.read('CID1', 7), 30, 'played time decays')

-- Logout grava o que decaiu até ali e para o relógio.
now = 5030
Heat.endSession(7)
equal(rows.CID1.value, 25, 'logout persists decay')
equal(Heat.isOnline('CID1'), false, 'offline after logout')
now = 90000
equal(Heat.read('CID1'), 25, 'nothing decays while offline')

-- Login repetido no meio da sessão não joga fora o tempo jogado.
now = 100000
Heat.startSession(7, 'CID1')
now = 100010
Heat.startSession(7, 'CID1')
equal(rows.CID1.value, 20, 'repeated login keeps played decay')

print('heat_spec: ok')
