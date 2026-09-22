-- Harness: o passo de esfriamento é aritmética pura, como o resto de shared/influence.lua.
-- O relógio e a persistência são do server/decay.lua e não entram aqui.
local RES = (os.getenv('RES') or './')

exports = setmetatable({}, { __call = function() end })
dofile(RES .. 'shared/config.lua')
dofile(RES .. 'shared/influence.lua')
dofile(RES .. 'shared/ownership.lua')

local fails = 0
local function check(ok, label)
    if not ok then fails = fails + 1 end
    print(('  [%s] %s'):format(ok and 'ok' or 'FALHOU', label))
end

---Aplica o passo como o servidor aplica: cada perda volta para o neutro.
local function decay(zone, keep)
    local losses = NoirInfluence.decayStep(zone, Config.Decay.Percent, keep)
    for gang, loss in pairs(losses) do NoirInfluence.grant(zone, gang, -loss) end
end

local function neutral(zone) return select(2, NoirInfluence.sumOf(zone)) end
local function closed(zone)
    local sum = NoirInfluence.sumOf(zone)
    return sum + neutral(zone) == Config.Influence.Total
end

print('o passo e proporcional:')
NoirInfluence.replaceAll({ davis = { ballas = 800, vagos = 200 } })
local losses = NoirInfluence.decayStep('davis', 5)
check(losses.ballas == 40 and losses.vagos == 10, '5% de cada fatia, nao um valor achatado')

print('nada se perde, tudo volta para o neutro:')
decay('davis')
check(NoirInfluence.get('davis', 'ballas') == 760, 'ballas desceu')
check(NoirInfluence.get('davis', 'vagos') == 190, 'vagos desceu')
check(neutral('davis') == 50, 'e os 50 pontos estao no neutro, nao apagados')
check(closed('davis'), 'o bairro continua somando 1000')

print('o desenho da disputa fica de pe:')
NoirInfluence.replaceAll({ davis = { ballas = 600, vagos = 300, triads = 100 } })
for _ = 1, 10 do decay('davis') end
local b, v, t = NoirInfluence.get('davis','ballas'), NoirInfluence.get('davis','vagos'), NoirInfluence.get('davis','triads')
check(b > v and v > t, 'quem liderava continua liderando enquanto o bairro esfria')
check(closed('davis'), 'e o pool continua fechado')

print('o esfriamento termina:')
NoirInfluence.replaceAll({ davis = { ballas = 19 } })
check(NoirInfluence.decayStep('davis', 5).ballas == 1,
    'abaixo de 20, 5% seria zero -- o minimo de 1 ponto existe para nao travar ali')
for _ = 1, 40 do decay('davis') end
check(NoirInfluence.get('davis', 'ballas') == 0, 'a gang chega a zero')
check(neutral('davis') == 1000, 'e o bairro volta a ser de ninguem')

print('ninguem perde mais do que tem:')
NoirInfluence.replaceAll({ davis = { ballas = 1 } })
check(NoirInfluence.decayStep('davis', 50).ballas == 1, 'o minimo nao vira divida')

print('bairro vazio nao esfria:')
NoirInfluence.replaceAll({})
check(next(NoirInfluence.decayStep('davis', 5)) == nil, 'nao ha o que devolver ao neutro')

print('percentual zero desliga:')
NoirInfluence.replaceAll({ davis = { ballas = 800 } })
check(next(NoirInfluence.decayStep('davis', 0)) == nil, 'sem passo, sem perda')

print('o dono tem piso no limiar:')
NoirInfluence.replaceAll({ davis = { ballas = 800, vagos = 200 } })
for _ = 1, 200 do decay('davis', 'ballas') end
check(NoirInfluence.get('davis', 'ballas') == 510,
    'o dono desce ate os 51% e para: a gordura derrete, a posse nao')
check(NoirInfluence.get('davis', 'vagos') == 0,
    'e o rival parado vai a zero: ele nao tem posse para proteger')
check(select(2, NoirInfluence.sumOf('davis')) == 490, 'o resto voltou para o neutro')
check(closed('davis'), 'o pool continua fechado')

NoirInfluence.replaceAll({ davis = { ballas = 400 } })
check(next(NoirInfluence.decayStep('davis', 5, 'ballas')) == nil,
    'dono ja abaixo do limiar nao esfria mais: nao ha gordura')

NoirInfluence.replaceAll({ davis = { ballas = 800 } })
for _ = 1, 200 do decay('davis') end
check(NoirInfluence.get('davis', 'ballas') == 0,
    'sem dono declarado, ninguem tem piso e o bairro volta inteiro ao neutro')

print('tempo travado nao conta como ocioso:')
local T0, HOUR = 1000000, 3600
NoirOwnership.now = function() return T0 end
NoirOwnership.replaceAll({ davis = { owner = 'ballas', takenAt = T0 } })

local fimDaTrava = T0 + Config.OwnershipLockSeconds
check(NoirOwnership.idleFrom('davis', T0) == fimDaTrava,
    'o ocio so comeca a contar quando a trava cai')
check(NoirOwnership.idleFrom('davis', fimDaTrava + 600) == fimDaTrava + 600,
    'atividade depois da trava manda no relogio')

NoirOwnership.replaceAll({})
check(NoirOwnership.idleFrom('davis', T0) == T0, 'bairro sem dono nao tem trava a descontar')

print('')
print(fails == 0 and 'decay_spec: ok' or ('decay_spec: ' .. fails .. ' falha(s)'))
os.exit(fails == 0 and 0 or 1)
