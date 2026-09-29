-- Os arquivos de `shared/` rodam nos dois lados, e o cliente do FiveM não tem a biblioteca
-- `os` — nem `os.time`, nem a tabela. Um `os.time()` esquecido ali não quebra teste nenhum,
-- não quebra o servidor, e só aparece como crash na primeira vez que alguém abre a tela.
-- Aconteceu: `client/map.lua` chamava `os.time()` e derrubava o menu do noir_gangs.
--
-- Este spec carrega os shared num ambiente sem `os` e exercita o que o cliente exercita.
local RES = (os.getenv('RES') or './')
local exit = os.exit

function vec3(x, y, z) return { x = x, y = y, z = z } end
exports = setmetatable({}, { __call = function() end })

local fails = 0
local function check(ok, label)
    if not ok then fails = fails + 1 end
    print(('  [%s] %s'):format(ok and 'ok' or 'FALHOU', label))
end

local chunks = {}
for _, name in ipairs({ 'shared/config.lua', 'shared/influence.lua', 'shared/ownership.lua',
    'shared/claims.lua' }) do
    chunks[#chunks + 1] = assert(loadfile(RES .. name))
end

-- A partir daqui o ambiente é o do cliente.
os = nil

print('carga dos shared sem a biblioteca os:')
for i = 1, #chunks do
    local ok, err = pcall(chunks[i])
    check(ok, ok and ('arquivo %d carrega'):format(i) or tostring(err))
end

print('o que a tela do mapa chama:')
NoirInfluence.replaceAll({ davis = { ballas = 600, vagos = 520 } })
NoirOwnership.replaceAll({ davis = { owner = 'ballas', takenAt = 1000 } })

local ok, status = pcall(NoirClaims.getZoneStatus, 'davis')
check(ok, ok and 'getZoneStatus responde' or tostring(status))
check(ok and status.gang == 'ballas' and status.challenger == 'vagos',
    'com dono e desafiante')
check(ok and status.lockedUntil == 1000 + Config.OwnershipLockSeconds, 'e a hora da trava')

check(pcall(NoirOwnership.isLocked, 'davis'), 'isLocked sem hora nao estoura')
check(NoirOwnership.now() == 0, 'e o relogio do cliente responde 0 ate o servidor mandar a hora')

check(pcall(NoirInfluence.effective, 'davis', 'vagos', 10), 'effective nao estoura')
check(pcall(NoirClaims.getTerritoryAt, vec3(0.0, 0.0, 0.0)), 'getTerritoryAt nao estoura')

print('')
print(fails == 0 and 'client_env_spec: ok' or ('client_env_spec: ' .. fails .. ' falha(s)'))
exit(fails == 0 and 0 or 1)
