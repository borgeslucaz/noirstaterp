-- Exercita server/crimes/parkingmeter/registry.lua: cooldown de poste, cooldown
-- de jogador e teto por hora.
--
-- Estas três travas são a defesa econômica do crime, e todas as três dependem de
-- relógio. Testá-las esperando de verdade custaria meia hora por asserção, então
-- `T.clock()` toma o lugar de `os.time` e o tempo anda quando este arquivo manda.

local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local clock = T.clock()
local Registry = require 'server.crimes.parkingmeter.registry'
local ServerConfig = require 'config.parkingmeter_server'

-- Poste esvaziado ----------------------------------------------------------------------

local KEY = '720:-3600:58'

T.falsy(Registry.isEmptied(KEY), 'poste desconhecido tem moedas')
T.equal(Registry.remaining(KEY), 0, 'e não tem tempo restante')

local duration = Registry.markEmptied(KEY)
T.equal(duration, ServerConfig.meterCooldown, 'a duração é a do config')
T.truthy(Registry.isEmptied(KEY), 'depois de marcado, está vazio')

clock.advance(ServerConfig.meterCooldown - 1)
T.truthy(Registry.isEmptied(KEY), 'um segundo antes do fim, ainda está vazio')

clock.advance(2)
T.falsy(Registry.isEmptied(KEY), 'passado o cooldown, volta a ter moedas')

-- Expiração preguiçosa: a leitura acima já apagou a chave, sem timer nenhum.
T.equal(select(1, Registry.counts()), 0, 'a leitura descartou a chave morta')

-- Snapshot -----------------------------------------------------------------------------

Registry.markEmptied('1:1:1')
Registry.markEmptied('2:2:2')
clock.advance(10)

local snapshot = Registry.snapshot()
T.equal(snapshot['1:1:1'], (ServerConfig.meterCooldown - 10) * 1000,
    'o snapshot vem em milissegundos, já descontado o tempo passado')
T.truthy(snapshot['2:2:2'], 'os dois postes estão no snapshot')

-- O snapshot também limpa o que venceu.
clock.advance(ServerConfig.meterCooldown)
T.equal(next(Registry.snapshot()), nil, 'snapshot vazio depois do cooldown')
T.equal(select(1, Registry.counts()), 0, 'e a tabela ficou vazia')

-- Teto por hora ------------------------------------------------------------------------

local CITIZEN = 'ABC12345'

T.equal(Registry.heatCount(CITIZEN), 0, 'jogador novo não tem histórico')
T.truthy(Registry.underCap(CITIZEN), 'e está abaixo do teto')

for index = 1, ServerConfig.maxPerHour do
    Registry.addHeat(CITIZEN)
    clock.advance(60)
    local allowed, count = Registry.underCap(CITIZEN)
    T.equal(count, index, ('contagem depois de %d arrombamentos'):format(index))
    if index < ServerConfig.maxPerHour then
        T.truthy(allowed, ('ainda cabe no teto em %d'):format(index))
    else
        T.falsy(allowed, 'no teto, não cabe mais')
    end
end

-- A janela é DESLIZANTE: passada a hora, os antigos saem e o jogador volta.
clock.advance(ServerConfig.heatWindow)
T.equal(Registry.heatCount(CITIZEN), 0, 'a janela deslizou e esvaziou o histórico')
T.truthy(Registry.underCap(CITIZEN), 'e o jogador volta a caber')

-- Um jogador no teto não pode travar o outro.
Registry.addHeat('OUTRO111')
T.equal(Registry.heatCount(CITIZEN), 0, 'o histórico é por citizenId')
T.equal(Registry.heatCount('OUTRO111'), 1, 'cada um com o seu')

-- Cooldown entre arrombamentos ---------------------------------------------------------
-- Sai da MESMA lista do teto: o último timestamp dela é o último arrombamento.

local FRESH = 'DEF67890'
T.equal(Registry.claimCooldownLeft(FRESH), 0, 'quem nunca arrombou não espera')

Registry.addHeat(FRESH)
T.equal(Registry.claimCooldownLeft(FRESH), ServerConfig.playerCooldown,
    'logo depois, espera o cooldown inteiro')

clock.advance(ServerConfig.playerCooldown - 5)
T.equal(Registry.claimCooldownLeft(FRESH), 5, 'a espera diminui com o tempo')

clock.advance(5)
T.equal(Registry.claimCooldownLeft(FRESH), 0, 'e zera no fim')

-- Depois de um segundo arrombamento, o cooldown conta do MAIS RECENTE.
Registry.addHeat(FRESH)
clock.advance(1)
T.equal(Registry.claimCooldownLeft(FRESH), ServerConfig.playerCooldown - 1,
    'conta do último, não do primeiro')

-- Um jogador cujo histórico inteiro saiu da janela não pode ficar preso num
-- cooldown fantasma.
clock.advance(ServerConfig.heatWindow)
T.equal(Registry.claimCooldownLeft(FRESH), 0, 'janela vazia, sem cooldown pendurado')

-- Manutenção ---------------------------------------------------------------------------

Registry.markEmptied('9:9:9')
Registry.addHeat('GHI00000')
clock.advance(math.max(ServerConfig.meterCooldown, ServerConfig.heatWindow) + 1)

T.truthy(Registry.prune() > 0, 'a limpeza descarta o que venceu')
local emptiedCount, players = Registry.counts()
T.equal(emptiedCount, 0, 'nenhum poste pendurado')
T.equal(players, 0, 'nenhum jogador pendurado')

-- `forget` é o caminho do /meterreset: devolve as moedas na hora.
Registry.markEmptied('5:5:5')
T.truthy(Registry.isEmptied('5:5:5'), 'marcado')
Registry.forget('5:5:5')
T.falsy(Registry.isEmptied('5:5:5'), 'esquecido')

clock.restore()
print('parkingmeter_registry_spec: ok')
