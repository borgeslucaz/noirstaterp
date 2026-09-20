-- Exercita server/crimes/parkingmeter/sessions.lua: a corrida entre dois
-- jogadores no mesmo poste, e a tentativa de pular as animações.
--
-- São os dois casos que só aparecem com má vontade: dois jogadores chegando
-- juntos, e um client adulterado chamando `reserve` e `claim` no mesmo frame.

local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local timer = T.gameTimer()
local Sessions = require 'server.crimes.parkingmeter.sessions'
local ServerConfig = require 'config.parkingmeter_server'
local Rules = require 'shared.parkingmeter_rules'

local KEY = '720:-3600:58'
local OTHER_KEY = '900:-3600:58'
local ANA, BRUNO = 1, 2
local ANA_CID, BRUNO_CID = 'ANA00001', 'BRU00002'

local MIN_ELAPSED = math.floor(Rules.totalDuration() * ServerConfig.minElapsedFactor)

-- Reserva ------------------------------------------------------------------------------

T.equal(Sessions.status(KEY), 'available', 'poste novo está livre')

T.truthy(Sessions.reserve(KEY, ANA, ANA_CID), 'Ana reserva')
T.equal(Sessions.status(KEY), 'reserved', 'o poste ficou reservado')
T.equal(Sessions.holder(KEY), ANA, 'e é da Ana')

-- Dois jogadores no mesmo poste: só um leva, e o outro sabe por quê.
local ok, code = Sessions.reserve(KEY, BRUNO, BRUNO_CID)
T.falsy(ok, 'Bruno não reserva o mesmo poste')
T.equal(code, 'reserved', 'e o código diz que já é de alguém')

-- Repetir a própria reserva é inofensivo: clique duplo, reconexão de UI.
T.truthy(Sessions.reserve(KEY, ANA, ANA_CID), 'Ana pode repetir a própria reserva')

-- Um jogador segura um poste por vez. Sem isto, um client adulterado reservaria
-- a rua inteira e travaria todo mundo.
ok, code = Sessions.reserve(OTHER_KEY, ANA, ANA_CID)
T.falsy(ok, 'Ana não reserva um segundo poste')
T.equal(code, 'busy', 'e o código diz que ela já está ocupada')

-- Mas o Bruno reserva o poste do lado normalmente.
T.truthy(Sessions.reserve(OTHER_KEY, BRUNO, BRUNO_CID), 'Bruno reserva outro poste')
T.equal(Sessions.counts(), 2, 'duas reservas vivas')

-- Entrega ------------------------------------------------------------------------------

-- Reservar e entregar no mesmo instante é o exploit que o minElapsed existe para
-- fechar: sem ele, quem chama os eventos à mão pula as duas barras.
ok, code = Sessions.claim(KEY, ANA, MIN_ELAPSED)
T.falsy(ok, 'entrega instantânea é recusada')
T.equal(code, 'too_soon', 'e o código diz que foi cedo demais')

timer.advance(MIN_ELAPSED - 1)
ok, code = Sessions.claim(KEY, ANA, MIN_ELAPSED)
T.falsy(ok, 'um milissegundo antes ainda é cedo')
T.equal(code, 'too_soon', 'mesmo código')

timer.advance(2)
local claimed, claimError, citizenId = Sessions.claim(KEY, ANA, MIN_ELAPSED)
T.truthy(claimed, 'passado o tempo, a entrega vale')
T.equal(claimError, nil, 'sem erro')
T.equal(citizenId, ANA_CID, 'devolve o citizenId DA RESERVA, não o de agora')

-- Uma entrega, uma vez. O segundo `claim` não encontra mais nada.
ok, code = Sessions.claim(KEY, ANA, MIN_ELAPSED)
T.falsy(ok, 'a mesma entrega não acontece duas vezes')
T.equal(code, 'expired', 'a sessão já saiu da tabela')
T.equal(Sessions.status(KEY), 'available', 'e o poste voltou a ficar livre na tabela de sessões')

-- Quem não reservou não entrega, mesmo chamando o evento à mão.
T.truthy(Sessions.reserve(KEY, ANA, ANA_CID), 'Ana reserva de novo')
timer.advance(MIN_ELAPSED + 1)
ok, code = Sessions.claim(KEY, BRUNO, MIN_ELAPSED)
T.falsy(ok, 'Bruno não entrega o poste da Ana')
T.equal(code, 'reserved', 'e o código diz de quem é')

-- Desistência --------------------------------------------------------------------------

T.truthy(Sessions.release(KEY, ANA), 'Ana devolve o poste')
T.equal(Sessions.status(KEY), 'available', 'e ele fica livre na hora')
T.falsy(Sessions.release(KEY, ANA), 'devolver duas vezes não faz nada')

T.truthy(Sessions.reserve(KEY, ANA, ANA_CID), 'Ana reserva mais uma vez')
T.falsy(Sessions.release(KEY, BRUNO), 'Bruno não devolve o poste da Ana')
T.equal(Sessions.holder(KEY), ANA, 'a reserva continua sendo dela')

-- Expiração ----------------------------------------------------------------------------
-- O jogador travou, desconectou ou o client morreu no meio da animação. O poste
-- não pode ficar trancado para sempre.

timer.advance(ServerConfig.reservationTimeout + 1)
T.equal(Sessions.status(KEY), 'available', 'a reserva expira sozinha')
T.equal(Sessions.holder(KEY), nil, 'e não sobra dono')

ok, code = Sessions.claim(KEY, ANA, MIN_ELAPSED)
T.falsy(ok, 'entregar uma reserva expirada não vale')
T.equal(code, 'expired', 'e o código explica')

-- Depois de expirar, o poste aceita outro jogador normalmente.
T.truthy(Sessions.reserve(KEY, BRUNO, BRUNO_CID), 'Bruno pega o poste abandonado')

-- Desconexão ---------------------------------------------------------------------------
-- É o caso que a expiração cobre, mas cobrir rápido é melhor: quem saiu não
-- segura o poste pelos 20 segundos inteiros.

T.truthy(Sessions.reserve(OTHER_KEY, ANA, ANA_CID), 'Ana reserva o outro poste')
Sessions.releaseAllFor(BRUNO)
T.equal(Sessions.status(KEY), 'available', 'a saída do Bruno soltou o poste dele')
T.equal(Sessions.holder(OTHER_KEY), ANA, 'e não encostou no da Ana')

-- Manutenção ---------------------------------------------------------------------------

timer.advance(ServerConfig.reservationTimeout + 1)
T.truthy(Sessions.prune() > 0, 'a limpeza descarta reserva vencida')
T.equal(Sessions.counts(), 0, 'nenhuma reserva pendurada')

print('parkingmeter_sessions_spec: ok')
