-- Harness: o passo de esfriamento é aritmética pura, como o resto de shared/influence.lua.
-- O relógio e a persistência são do server/decay.lua e não entram aqui.
local RES = (os.getenv('RES') or './')

exports = setmetatable({}, { __call = function() end })
dofile(RES .. 'shared/config.lua')
dofile(RES .. 'shared/influence.lua')

local fails = 0
local function check(ok, label)
    if not ok then fails = fails + 1 end
    print(('  [%s] %s'):format(ok and 'ok' or 'FALHOU', label))
end

---Aplica o passo como o servidor aplica: cada perda volta para o neutro.
local function decay(zone)
    local losses = NoirInfluence.decayStep(zone, Config.Decay.Percent)
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

print('')
print(fails == 0 and 'decay_spec: ok' or ('decay_spec: ' .. fails .. ' falha(s)'))
os.exit(fails == 0 and 0 or 1)
