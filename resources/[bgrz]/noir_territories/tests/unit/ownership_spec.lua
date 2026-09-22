-- Harness: carrega shared/ownership.lua real sobre a influência real, e cobre a placa — o
-- domínio grudento, a trava de quatro horas e o dono que é varrido do bairro.
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

local HOUR = 3600
local T0 = 1000000    -- "agora" de referência dos casos

---Aplica a decisão como o servidor aplicaria: calcula, e se mudou, carimba a hora.
local function refresh(zone, now)
    local current = NoirOwnership.get(zone)
    local desired = NoirOwnership.desiredOwner(zone, now)
    if desired ~= current then NoirOwnership.set(zone, desired, now) end
    return desired
end

local function seed(influence, owner, takenAt)
    NoirInfluence.replaceAll({ davis = influence })
    NoirOwnership.replaceAll(owner and { davis = { owner = owner, takenAt = takenAt } } or {})
end

print('primeira tomada:')
seed({ ballas = 400 })
check(refresh('davis', T0) == nil, '400 nao basta: bairro segue sem dono')
seed({ ballas = 510 })
check(refresh('davis', T0) == 'ballas', '510 leva o bairro, e nao ha trava a esperar')

print('dono grudento:')
seed({ ballas = 480, vagos = 450, families = 70 }, 'ballas', T0)
check(refresh('davis', T0 + 10 * HOUR) == 'ballas',
    'cair abaixo do limiar nao devolve o bairro para ninguem')
check(NoirOwnership.challengerOf('davis') == nil, 'e nao ha desafiante: ninguem alcancou')

print('trava de 4h:')
seed({ ballas = 460, vagos = 510 }, 'ballas', T0)
check(refresh('davis', T0 + 1 * HOUR) == 'ballas', 'uma hora depois, a placa nao muda')
check(refresh('davis', T0 + 3 * HOUR + 3599) == 'ballas', 'nem um segundo antes de fechar 4h')
check(NoirOwnership.challengerOf('davis') == 'vagos', 'mas o desafiante esta anunciado o tempo todo')
check(NoirOwnership.isLocked('davis', T0 + 2 * HOUR) == true, 'a trava se declara travada')

check(refresh('davis', T0 + 4 * HOUR) == 'vagos', 'as 4h em ponto o bairro troca de dono')
check(NoirOwnership.isLocked('davis', T0 + 4 * HOUR + 1) == true,
    'e a tomada nova comeca uma trava nova')

print('trava nao segura quem nao alcancou:')
seed({ ballas = 300, vagos = 400 }, 'ballas', T0)
check(refresh('davis', T0 + 9 * HOUR) == 'ballas',
    'trava caida sem ninguem nos 51% deixa tudo como esta')

print('dono varrido do bairro:')
seed({ vagos = 600 }, 'ballas', T0)
check(refresh('davis', T0 + 10) == 'vagos',
    'dono com zero ponto perde a placa na hora, e a trava nao o protege')

seed({ vagos = 300 }, 'ballas', T0)
check(refresh('davis', T0 + 10) == nil,
    'zerado sem ninguem no limiar, o bairro volta a nao ter dono')

print('a propria gang dona alcancando de novo:')
seed({ ballas = 600 }, 'ballas', T0)
local before = select(2, NoirOwnership.get('davis'))
check(refresh('davis', T0 + HOUR) == 'ballas', 'segue dona')
check(select(2, NoirOwnership.get('davis')) == before,
    'e a trava nao e reiniciada por ela continuar trabalhando o proprio bairro')

print('trava para os dois lados:')
seed({ ballas = 600, vagos = 200 }, 'ballas', T0)
local DENTRO, FORA = T0 + HOUR, T0 + 5 * HOUR

check(NoirOwnership.protects('davis', 'ballas',  75, DENTRO) == true, 'o dono nao ganha')
check(NoirOwnership.protects('davis', 'ballas', -75, DENTRO) == true, 'e nao perde')
check(NoirOwnership.protects('davis', 'vagos',   75, DENTRO) == true, 'de fora ninguem ganha')
check(NoirOwnership.protects('davis', 'vagos',  -75, DENTRO) == false,
    'mas quem nao e dono ainda perde: isso nao toca no dono')

check(NoirOwnership.protects('davis', 'ballas',  75, FORA) == false, 'caida a trava, tudo volta')
check(NoirOwnership.protects('davis', 'vagos',   75, FORA) == false, 'para os dois lados')

seed({ ballas = 600 }, nil, nil)
check(NoirOwnership.protects('davis', 'ballas', 75, DENTRO) == false,
    'bairro sem dono nao tem o que proteger')

print('')
print(fails == 0 and 'ownership_spec: ok' or ('ownership_spec: ' .. fails .. ' falha(s)'))
os.exit(fails == 0 and 0 or 1)
