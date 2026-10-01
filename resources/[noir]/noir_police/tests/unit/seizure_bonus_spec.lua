-- Bônus de apreensão: só o que veio de outro jogador conta, fração do valor de rua, teto por hora.

local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local Utils = require 'shared.utils'
local ServerConfig = require 'config.server'

local values = { black_money = 1, weed_skunk_brick = 780, cokebaggy = 580 }

local amount, base = Utils.seizureBonus({ { name = 'black_money', count = 2000 } }, {}, values, 0.15, 0, 1000)
T.equal(base, 2000, 'dinheiro sujo vale o próprio valor')
T.equal(amount, 300, '15% de 2000')

amount, base = Utils.seizureBonus({ { name = 'weed_skunk_brick', count = 2 }, { name = 'money', count = 5000 } }, {}, values, 0.15, 0, 1000)
T.equal(base, 1560, 'dinheiro limpo não entra no valor')
T.equal(amount, 234, '15% de 1560')

-- O que o policial pôs sem pendência não rende.
amount, base = Utils.seizureBonus({ { name = 'cokebaggy', count = 5 } }, { cokebaggy = 3 }, values, 0.15, 0, 1000)
T.equal(base, 1160, 'só as 2 que bateram com pendência')
amount = Utils.seizureBonus({ { name = 'cokebaggy', count = 5 } }, { cokebaggy = 5 }, values, 0.15, 0, 1000)
T.equal(amount, 0, 'tudo sem pendência: nada')

-- Teto por hora
amount = Utils.seizureBonus({ { name = 'black_money', count = 100000 } }, {}, values, 0.15, 0, 1000)
T.equal(amount, 1000, 'teto da hora')
amount = Utils.seizureBonus({ { name = 'black_money', count = 100000 } }, {}, values, 0.15, 800, 1000)
T.equal(amount, 200, 'só o que sobra do teto')
amount = Utils.seizureBonus({ { name = 'black_money', count = 100000 } }, {}, values, 0.15, 1000, 1000)
T.equal(amount, 0, 'teto batido')

-- Item sem valor de rua
amount, base = Utils.seizureBonus({ { name = 'weapon_pistol', count = 1 } }, {}, values, 0.15, 0, 1000)
T.equal(amount, 0, 'arma não tem valor de rua')
T.equal(base, 0, 'base zero')

-- O bônus é sempre menor que o destruído, e a config tem valor para o dinheiro sujo.
local bonus = ServerConfig.seizure.bonus
T.truthy(bonus.rate > 0 and bonus.rate < 1, 'rate entre 0 e 1')
T.equal(bonus.values.black_money, 1, 'black_money vale 1')

print('seizure_bonus_spec: ok')
