-- Harness: carrega o shared/influence.lua real, que é aritmética pura, e cobre o que o pool
-- promete — soma fechada, rateio proporcional entre o neutro e os rivais, e o bônus de azarão.
local RES = (os.getenv('RES') or './')

function vec3(x, y, z) return { x = x, y = y, z = z } end
exports = setmetatable({}, { __call = function() end })

dofile(RES .. 'shared/config.lua')
dofile(RES .. 'shared/influence.lua')

local fails = 0
local function check(ok, label)
    if not ok then fails = fails + 1 end
    print(('  [%s] %s'):format(ok and 'ok' or 'FALHOU', label))
end

-- Os casos de rateio medem a divisão, não o bônus: ele é ligado só no bloco dele.
Config.Influence.Underdog = 0

local function points(zone, gang) return NoirInfluence.get(zone, gang) end
local function neutral(zone)
    local _, n = NoirInfluence.sumOf(zone)
    return n
end

---A soma das fatias mais o neutro tem de dar o pool. É a invariante do modelo inteiro: se ela
---quebra, o mapa passa a mostrar um bairro maior do que ele é.
local function closed(zone)
    local sum = NoirInfluence.sumOf(zone)
    return sum + neutral(zone) == Config.Influence.Total and sum <= Config.Influence.Total
end

print('bairro virgem:')
NoirInfluence.replaceAll({})
check(neutral('davis') == 1000, 'comeca com 1000 de neutro')
check(points('davis', 'ballas') == 0, 'e ninguem com nada')
-- Quem e dono deixou de ser pergunta deste modulo: ela mora em tests/unit/ownership_spec.lua.

print('bairro sem gang nenhuma: so o neutro paga:')
NoirInfluence.grant('davis', 'ballas', 300)
check(points('davis', 'ballas') == 300, 'a gang sobe')
check(neutral('davis') == 700, 'e o neutro desce na mesma medida')
check(closed('davis'), 'o pool continua fechado')

-- O neutro é mais um pagador, não uma reserva gasta antes dos outros: num bairro quase virgem
-- ele é o maior de todos e banca quase tudo, mas quem já tem ponto ali paga junto.
print('cada um paga na proporcao do que tem:')
NoirInfluence.replaceAll({ davis = { ballas = 10, families = 75 } })
NoirInfluence.grant('davis', 'triads', 75)
check(points('davis', 'triads') == 75, 'o ganho inteiro entrou')
check(neutral('davis') == 846, 'o neutro tinha 91% do bairro e pagou 69 dos 75')
check(points('davis', 'families') == 69, 'families, com 7,5%, pagou 6')
check(points('davis', 'ballas') == 10, 'e ballas, com 1%, nao pagou nada')
check(closed('davis'), 'o pool continua fechado')

-- É a diferença que decide se uma gang nova consegue existir num bairro dominado: na divisão
-- em partes iguais ela pagaria 5 dos 22 que tem, 23% do seu patrimonio, contra 0,6% do gigante.
print('gang pequena nao paga a conta do gigante:')
NoirInfluence.replaceAll({ davis = { ballas = 800, triads = 22 } })
NoirInfluence.grant('davis', 'ballas', 10)
check(points('davis', 'triads') == 21, 'a gang nova perde 1 de 22, e nao 5')

print('limiar:')
check(NoirInfluence.required() == 510, '51% de 1000 sao 510 pontos')

print('sem neutro, a divisao e so entre as gangs:')
NoirInfluence.replaceAll({ davis = { ballas = 500, vagos = 500 } })
check(neutral('davis') == 0, 'bairro cheio comeca sem neutro')
NoirInfluence.grant('davis', 'triads', 100)
check(points('davis', 'triads') == 100, 'quem chega leva o que pediu')
check(points('davis', 'ballas') == 450 and points('davis', 'vagos') == 450,
    'iguais pagam igual')
check(closed('davis'), 'o pool continua fechado')

print('com o neutro esgotado, quem tem mais banca a maior parte:')
NoirInfluence.replaceAll({ davis = { ballas = 10, families = 75, triads = 915 } })
NoirInfluence.grant('davis', 'triads', 75)
check(points('davis', 'ballas') == 2, 'ballas, com 12% do que os dois somam, paga 8')
check(points('davis', 'families') == 8, 'e families paga os outros 67')
check(points('davis', 'triads') == 990, 'o ganho inteiro entrou')
check(closed('davis'), 'o pool continua fechado')

print('ganho maior do que o bairro inteiro:')
NoirInfluence.replaceAll({ davis = { ballas = 600, vagos = 400 } })
NoirInfluence.grant('davis', 'triads', 700)
check(points('davis', 'triads') == 700, 'o ganho inteiro entrou')
check(points('davis', 'ballas') == 180 and points('davis', 'vagos') == 120,
    'os dois pagaram na proporcao de 60/40')
check(closed('davis'), 'o pool continua fechado')

print('ninguem passa do teto:')
NoirInfluence.replaceAll({})
NoirInfluence.grant('davis', 'ballas', 5000)
check(points('davis', 'ballas') == 1000, 'o teto e o pool inteiro')
check(neutral('davis') == 0, 'e nao sobra neutro')
check(closed('davis'), 'o pool continua fechado')

print('perda volta para o neutro:')
NoirInfluence.replaceAll({ davis = { ballas = 600, vagos = 200 } })
NoirInfluence.grant('davis', 'ballas', -200)
check(points('davis', 'ballas') == 400, 'quem perdeu desceu')
check(points('davis', 'vagos') == 200, 'e o rival nao ganhou nada com isso')
check(neutral('davis') == 400, 'a rua ficou solta')

print('bonus de azarao:')
Config.Influence.Underdog = 1.5
NoirInfluence.replaceAll({ davis = { ballas = 800, triads = 100 } })
check(NoirInfluence.effective('davis', 'triads', 10) == 21,
    'quem esta 70% atras do lider ganha 21 por uma atividade de 10')
check(NoirInfluence.effective('davis', 'ballas', 10) == 10, 'e o lider nunca recebe bonus')

NoirInfluence.replaceAll({ davis = { ballas = 500, vagos = 500 } })
check(NoirInfluence.effective('davis', 'ballas', 10) == 10, 'empatados, ninguem recebe bonus')

NoirInfluence.replaceAll({})
check(NoirInfluence.effective('davis', 'ballas', 10) == 10,
    'bairro sem gang nenhuma tambem nao: nao se e azarao contra ninguem')

Config.Influence.Underdog = 0
NoirInfluence.replaceAll({ davis = { ballas = 800, triads = 100 } })
check(NoirInfluence.effective('davis', 'triads', 10) == 10, 'e com o bonus desligado, vale a base')

print('zero nao vira linha:')
NoirInfluence.replaceAll({ davis = { ballas = 100 } })
NoirInfluence.grant('davis', 'ballas', -100)
check(NoirInfluence.of('davis').ballas == nil, 'gang zerada some do registro')

print('')
print(fails == 0 and 'influence_spec: ok' or ('influence_spec: ' .. fails .. ' falha(s)'))
os.exit(fails == 0 and 0 or 1)
