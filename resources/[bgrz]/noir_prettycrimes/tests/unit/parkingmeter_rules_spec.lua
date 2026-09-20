-- Exercita shared/parkingmeter_rules.lua: a identidade de um poste.
--
-- É o arquivo mais importante do crime para testar, porque um erro aqui não
-- aparece como erro. Se client e servidor calculassem chaves diferentes, tudo
-- continuaria "funcionando": o servidor esvaziaria um poste, o client continuaria
-- oferecendo o alvo, e ninguém veria uma linha vermelha no console.

local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local Rules = require 'shared.parkingmeter_rules'
local CrimeConfig = require 'config.parkingmeter'

-- Allowlist de model -------------------------------------------------------------------

T.truthy(Rules.isAllowedModel(joaat('prop_parknmeter_01')), 'model do config é aceito')
T.truthy(Rules.isAllowedModel(joaat('prop_parknmeter_02')), 'o segundo model também')
T.falsy(Rules.isAllowedModel(joaat('prop_atm_01')), 'um prop qualquer não passa')
T.falsy(Rules.isAllowedModel(nil), 'nil não passa')
T.falsy(Rules.isAllowedModel('prop_parknmeter_01'), 'nome não é hash')
T.falsy(Rules.isAllowedModel(0 / 0), 'NaN não passa')

-- O mesmo hash com sinal trocado aponta para o mesmo model: um payload que
-- atravessou a rede como inteiro com sinal não pode ser recusado pelo sinal.
local signed = joaat('prop_parknmeter_01') - 0x100000000
T.truthy(Rules.isAllowedModel(signed), 'hash com sinal ainda é o mesmo model')

-- Coordenadas --------------------------------------------------------------------------

T.falsy(Rules.readCoords(nil), 'nil não é coordenada')
T.falsy(Rules.readCoords({ x = 1 }), 'coordenada incompleta é recusada')
T.falsy(Rules.readCoords({ x = 0 / 0, y = 0, z = 0 }), 'NaN é recusado')
T.falsy(Rules.readCoords({ x = math.huge, y = 0, z = 0 }), 'infinito é recusado')
T.falsy(Rules.readCoords({ x = 99999, y = 0, z = 0 }), 'fora do mapa é recusado')
T.truthy(Rules.readCoords(vec3(-1200.5, 300.25, 12.0)), 'coordenada plausível passa')

-- Chave do poste -----------------------------------------------------------------------

local key = Rules.meterKey(vec3(360.12, -1800.44, 29.30))
T.truthy(key, 'coordenada vira chave')
T.equal(type(key), 'string', 'a chave é string')

-- A mesma leitura, duas vezes: a mesma chave. É o contrato básico.
T.equal(Rules.meterKey(vec3(360.12, -1800.44, 29.30)), key, 'determinística')

-- Ruído de float abaixo da célula não pode mudar a identidade.
T.equal(Rules.meterKey(vec3(360.12 + 0.001, -1800.44 - 0.002, 29.30)), key,
    'ruído de milímetro cai na mesma célula')

-- Dois postes vizinhos de verdade ficam a metros: nunca colidem.
T.truthy(Rules.meterKey(vec3(365.0, -1800.44, 29.30)) ~= key,
    'poste a 5m é outra chave')

-- O arredondamento precisa ser simétrico, e é aqui que se vê a diferença entre
-- arredondar e truncar. Dois pontos a 24 cm de cada lado do zero estão na mesma
-- célula de meio metro: com `math.floor(v / size + 0.5)` os dois dão 0, e com
-- `math.floor(v / size)` o negativo cairia em -1. Metade do mapa tem coordenada
-- negativa, então truncar deslocaria meia célula em metade da cidade.
T.equal(Rules.meterKey(vec3(0.24, 0.24, 0.24)), Rules.meterKey(vec3(-0.24, -0.24, -0.24)),
    'arredondamento simétrico em torno do zero')
T.equal(Rules.meterKey(vec3(-100.01, -50.01, 10.01)), Rules.meterKey(vec3(-100.02, -50.02, 10.02)),
    'e o ruído de centímetro também some longe do zero')

-- A borda de célula existe, e dois pontos que a atravessam caem em chaves
-- diferentes. Isso não é um defeito: parquímetro é prop de MAPA, a coordenada é
-- literalmente a mesma nos dois processos, e a grade está aqui só para absorver
-- ruído de float — não para reconciliar duas medições independentes.
T.truthy(Rules.meterKey(vec3(-0.24, 0.0, 0.0)) ~= Rules.meterKey(vec3(-0.26, 0.0, 0.0)),
    'a borda de célula separa, e está documentado que separa')

T.falsy(Rules.meterKey({ x = 'a', y = 0, z = 0 }), 'coordenada inválida não vira chave')

-- A chave é curta o bastante para atravessar evento sem virar payload gordo.
T.truthy(#Rules.meterKey(vec3(-9999.0, -9999.0, -1999.0)) <= 32,
    'a chave mais longa possível ainda é curta')

-- Distância horizontal -----------------------------------------------------------------
-- Horizontal de propósito: o alvo fica na cabeça do poste e o jogador está no
-- chão, então Z é ruído constante que só apertaria o limite sem proteger nada.

T.equal(Rules.flatDistance(vec3(0, 0, 0), vec3(3, 4, 0)), 5.0, 'pitágoras no plano')
T.equal(Rules.flatDistance(vec3(0, 0, 0), vec3(3, 4, 100)), 5.0, 'Z não conta')
T.falsy(Rules.flatDistance(nil, vec3(0, 0, 0)), 'coordenada inválida devolve nil')

-- Áreas --------------------------------------------------------------------------------

local areas = {
    { coords = vec3(100.0, 100.0, 20.0), radius = 50.0 },
    { coords = vec3(-500.0, 0.0, 30.0), radius = 10.0 },
}

T.truthy(Rules.inAnyArea(vec3(100.0, 100.0, 20.0), areas), 'o centro está dentro')
T.truthy(Rules.inAnyArea(vec3(140.0, 100.0, 20.0), areas), 'dentro do raio')
T.falsy(Rules.inAnyArea(vec3(200.0, 100.0, 20.0), areas), 'fora do raio')
T.truthy(Rules.inAnyArea(vec3(-495.0, 0.0, 30.0), areas), 'a segunda área também vale')
T.falsy(Rules.inAnyArea(vec3(-495.0, 0.0, 30.0), {}), 'sem áreas, nada passa')
T.falsy(Rules.inAnyArea(nil, areas), 'coordenada inválida não passa')
T.falsy(Rules.inAnyArea(vec3(0, 0, 0), nil), 'lista inválida não passa')

-- A esfera conta Z, e isso importa: um poste numa garagem 60m abaixo do centro
-- da área não é o mesmo lugar que a calçada em cima dela.
T.falsy(Rules.inAnyArea(vec3(100.0, 100.0, 200.0), areas), 'a esfera é 3D')

-- Área com raio inválido não pode virar "passa tudo".
T.falsy(Rules.inAnyArea(vec3(0, 0, 0), { { coords = vec3(0, 0, 0) } }),
    'área sem raio não aceita nada')
T.falsy(Rules.inAnyArea(vec3(0, 0, 0), { { radius = 10.0 } }),
    'área sem coordenada não aceita nada')

-- Áreas reais do config de servidor: uma coordenada do centro de Los Santos
-- precisa passar, e uma do deserto não.
local ServerConfig = require 'config.parkingmeter_server'
T.truthy(Rules.inAnyArea(vec3(215.0, -880.0, 30.0), ServerConfig.areas),
    'Legion Square está coberta')
T.falsy(Rules.inAnyArea(vec3(1700.0, 3700.0, 34.0), ServerConfig.areas),
    'Sandy Shores não tem parquímetro')

-- Duração ------------------------------------------------------------------------------

T.equal(Rules.totalDuration(), CrimeConfig.pryDuration + CrimeConfig.collectDuration,
    'a duração total é a soma das duas barras')
T.truthy(ServerConfig.reservationTimeout > Rules.totalDuration(),
    'a reserva sobrevive mais que as duas barras juntas')
T.truthy(math.floor(Rules.totalDuration() * ServerConfig.minElapsedFactor) < Rules.totalDuration(),
    'o mínimo exigido cabe dentro da duração real')

-- O client corta qualquer duração acima de `emptiedFallback`, e não recebe o
-- config de servidor para saber que está cortando. Com o teto abaixo do cooldown
-- real, o alvo voltaria a aparecer antes de o servidor liberar o poste e o
-- jogador levaria uma recusa sem explicação. É um desencontro entre dois arquivos
-- que nenhum dos dois lados percebe sozinho — por isso ele é conferido aqui.
T.truthy(CrimeConfig.emptiedFallback >= ServerConfig.meterCooldown * 1000,
    'o teto do client precisa cobrir o cooldown do servidor')

-- A reserva não pode durar mais que o cooldown do poste, senão uma reserva
-- pendurada sobreviveria ao próprio esvaziamento.
T.truthy(ServerConfig.reservationTimeout < ServerConfig.meterCooldown * 1000,
    'a reserva expira muito antes de o poste voltar')

print('parkingmeter_rules_spec: ok')
