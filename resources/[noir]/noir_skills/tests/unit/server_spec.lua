-- Carrega server/main.lua com o runtime do FiveM, o oxmysql e o bgrz_core stubados, e
-- exercita o que não dá para ver lendo: teto e piso de XP, o que chega no cliente, o que
-- é reemitido para os outros resources e a limpeza do cache.
local T = dofile('tests/testlib.lua')

dofile('shared/config.lua')
dofile('shared/xp.lua')

-- Mundo controlado pelo teste ----------------------------------------------------------
local world = {
    online = { [1] = 'AAA', [2] = 'BBB' },  -- source -> citizenid
    stored = { AAA = { { skill = 'arrombamento', xp = 400 }, { skill = 'fantasma', xp = 900 } } },
}

local core = {}
local notifications = {}

function core:GetCitizenId(source) return world.online[source] end
function core:Notify(source, text, kind)
    notifications[#notifications + 1] = { source = source, text = text, kind = kind }
end

-- Runtime stubado ------------------------------------------------------------------------
local registered
exports, registered = T.exports({ bgrz_core = core })

local eventHandlers, registerEvent = T.handlers()
AddEventHandler = registerEvent
local callbacks, registerCallback = T.handlers()
local commands = {}

lib = {
    print = { info = function() end, warn = function() end, error = function() end },
    callback = { register = registerCallback },
    addCommand = function(name, _, handler) commands[name] = handler end,
}

local writes = {}
MySQL = {
    ready = function(fn) fn() end,
    query = {
        await = function(sql, params)
            if sql:find('SELECT', 1, true) then
                return world.stored[params[1]] or {}
            end
            return {}
        end,
    },
    -- `MySQL.prepare` é chamado como função e tem `.await` no oxmysql, então o stub é uma
    -- tabela chamável, igual ao runtime real. O upsert acontece de verdade no mundo do
    -- teste: o personagem que sai e volta lê o que foi gravado, não o estado inicial.
    prepare = setmetatable({}, { __call = function(_, _, params)
            local citizenid, skill, xp = params[1], params[2], params[3]
            writes[#writes + 1] = { citizenid = citizenid, skill = skill, xp = xp }

            local rows = world.stored[citizenid] or {}
            world.stored[citizenid] = rows
            for i = 1, #rows do
                if rows[i].skill == skill then rows[i].xp = xp return end
            end
            rows[#rows + 1] = { skill = skill, xp = xp }
        end }),
}

local clientEvents, serverEvents = {}, {}
TriggerClientEvent = function(name, target, ...)
    clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } }
end
TriggerEvent = function(name, ...)
    serverEvents[#serverEvents + 1] = { name = name, args = { ... } }
end

GetInvokingResource = function() return 'teste' end
GetCurrentResourceName = function() return 'noir_skills' end
GetPlayers = function() return {} end
GetPlayerName = function(source) return 'Jogador' .. tostring(source) end
LoadResourceFile = function(_, path)
    local file = assert(io.open(path, 'r'), 'missing ' .. path)
    local content = file:read('*a')
    file:close()
    return content
end

dofile('server/store.lua')
dofile('server/main.lua')

local Xp = NoirSkills.xp

-- Helpers ----------------------------------------------------------------------------------
local function fire(event, ...)
    local handler = assert(eventHandlers[event], 'evento não registrado: ' .. event)
    return handler(...)
end

local function api(name, ...)
    return assert(registered[name], 'export não registrado: ' .. name)(...)
end

local function lastClientEvent(name)
    for i = #clientEvents, 1, -1 do
        if clientEvents[i].name == name then return clientEvents[i] end
    end
end

local function lastServerEvent(name)
    for i = #serverEvents, 1, -1 do
        if serverEvents[i].name == name then return serverEvents[i] end
    end
end

local function reset()
    writes, clientEvents, serverEvents, notifications = {}, {}, {}, {}
end

-- Carga do personagem ----------------------------------------------------------------------
fire('bgrz_core:server:playerLoaded', 1)

T.equal(api('GetXp', 1, 'arrombamento'), 400, 'o XP guardado volta do banco')
T.equal(api('GetLevel', 1, 'arrombamento'), Xp.levelFor('arrombamento', 400), 'o nível sai da curva, não do banco')
T.equal(api('GetXp', 1, 'mecanica'), 0, 'habilidade sem linha no banco começa zerada')
T.equal(#writes, 0, 'entrar no servidor não escreve no banco')

local sync = lastClientEvent('noir_skills:client:sync')
T.truthy(sync and sync.target == 1, 'o cliente recebe o estado ao carregar')
T.equal(sync.args[1].arrombamento, 400, 'o sync leva o XP bruto')
T.equal(sync.args[1].fantasma, nil, 'habilidade que saiu do config não vai para o cliente')
T.equal(sync.args[1].mecanica, 0, 'o sync leva todas as habilidades do config')

-- Habilidade fora do config continua no banco: tirar do config não apaga progresso.
T.equal(api('GetXp', 1, 'fantasma'), 0, 'habilidade desconhecida responde zero, não erro')

-- Ganho e perda ------------------------------------------------------------------------------
reset()
local previousLevel = api('GetLevel', 1, 'arrombamento')
T.truthy(api('AddXp', 1, 'arrombamento', 50), 'AddXp aceita ganho válido')
T.equal(api('GetXp', 1, 'arrombamento'), 450, 'o XP soma')
T.equal(#writes, 1, 'cada mudança grava uma vez')
T.equal(writes[1].citizenid, 'AAA', 'grava no personagem certo')
T.equal(writes[1].xp, 450, 'grava o XP absoluto, não o delta')

local update = lastClientEvent('noir_skills:client:update')
T.equal(update.args[1], 'arrombamento', 'o update nomeia a habilidade')
T.equal(update.args[2], 450, 'o update leva o XP novo')
T.truthy(lastServerEvent('noir_skills:server:xpChanged'), 'outros resources ouvem a mudança de XP')

reset()
T.falsy(api('AddXp', 1, 'arrombamento', 0), 'ganho de zero é recusado')
T.falsy(api('AddXp', 1, 'arrombamento', -10), 'AddXp não aceita número negativo')
T.falsy(api('AddXp', 1, 'arrombamento', 'muito'), 'AddXp não aceita texto')
T.falsy(api('AddXp', 1, 'inexistente', 10), 'habilidade desconhecida não grava')
T.falsy(api('AddXp', 99, 'arrombamento', 10), 'personagem não carregado não grava')
T.equal(#writes, 0, 'nenhuma chamada inválida chegou ao banco')

T.truthy(api('RemoveXp', 1, 'arrombamento', 100), 'RemoveXp aceita valor válido')
T.equal(api('GetXp', 1, 'arrombamento'), 350, 'o XP desce')
T.truthy(api('RemoveXp', 1, 'arrombamento', 99999), 'remover mais do que tem é aceito')
T.equal(api('GetXp', 1, 'arrombamento'), 0, 'o XP para em zero, nunca negativo')

-- Teto ------------------------------------------------------------------------------------
reset()
local teto = Xp.maxXp('arrombamento')
api('AddXp', 1, 'arrombamento', teto + 5000)
T.equal(api('GetXp', 1, 'arrombamento'), teto, 'o XP é grampeado no teto da habilidade')
T.equal(api('GetLevel', 1, 'arrombamento'), Xp.maxLevel('arrombamento'), 'quem chega no teto está no nível máximo')
T.equal(writes[#writes].xp, teto, 'o banco também guarda o valor grampeado')

reset()
T.falsy(api('AddXp', 1, 'arrombamento', 500), 'no teto, ganhar XP não muda nada')
T.equal(#writes, 0, 'nada mudou, então nada foi gravado')

-- Nível ---------------------------------------------------------------------------------------
reset()
T.truthy(api('SetLevel', 1, 'arrombamento', 5), 'SetLevel aceita nível dentro da faixa')
T.equal(api('GetLevel', 1, 'arrombamento'), 5, 'o nível é exatamente o pedido')
T.equal(api('GetXp', 1, 'arrombamento'), Xp.totalForLevel('arrombamento', 5), 'o XP vai para o piso do nível')

local changed = lastServerEvent('noir_skills:server:levelChanged')
T.equal(changed.args[3], 5, 'o evento de nível leva o nível novo')
T.truthy(changed.args[4] > 5, 'e o anterior, para quem precisar da direção da mudança')

T.falsy(api('SetLevel', 1, 'arrombamento', 0), 'nível abaixo de 1 é recusado')
T.falsy(api('SetLevel', 1, 'arrombamento', Xp.maxLevel('arrombamento') + 1), 'nível acima do máximo é recusado')
T.falsy(api('SetLevel', 1, 'arrombamento', 3.5), 'nível quebrado é recusado')
T.equal(api('GetLevel', 1, 'arrombamento'), 5, 'nenhuma recusa mexeu no nível')

T.truthy(api('HasLevel', 1, 'arrombamento', 5), 'HasLevel aceita nível igual')
T.truthy(api('HasLevel', 1, 'arrombamento', 4), 'HasLevel aceita nível abaixo')
T.falsy(api('HasLevel', 1, 'arrombamento', 6), 'HasLevel recusa nível acima')
T.falsy(api('HasLevel', 1, 'inexistente', 1), 'HasLevel de habilidade desconhecida é falso')

T.truthy(api('ResetSkill', 1, 'arrombamento'), 'ResetSkill zera')
T.equal(api('GetXp', 1, 'arrombamento'), 0, 'depois do reset o XP é zero')
T.equal(api('GetLevel', 1, 'arrombamento'), 1, 'e o nível volta para 1')

-- Estado completo -------------------------------------------------------------------------
api('AddXp', 1, 'mecanica', 200)
local all = api('GetAll', 1)
T.equal(all.mecanica.totalXp, 200, 'GetAll leva o XP bruto')
T.equal(all.mecanica.level, Xp.levelFor('mecanica', 200), 'GetAll leva o nível calculado')
T.truthy(all.arrombamento ~= nil, 'GetAll traz todas as habilidades, inclusive as zeradas')

-- Ciclo de vida -----------------------------------------------------------------------------
-- Sem limpeza o cache cresce a cada reconexão e nunca encolhe.
fire('bgrz_core:server:playerUnloaded', 1)
T.equal(next(api('GetAll', 1)), nil, 'trocar de personagem limpa o cache')
T.falsy(api('AddXp', 1, 'arrombamento', 10), 'e quem saiu não recebe mais XP')

fire('bgrz_core:server:playerLoaded', 2)
T.truthy(api('AddXp', 2, 'mecanica', 10), 'outro personagem carrega normalmente')
source = 2
fire('playerDropped')
T.equal(next(api('GetAll', 2)), nil, 'cair do servidor limpa o cache')

-- Callback de sync ----------------------------------------------------------------------------
fire('bgrz_core:server:playerLoaded', 1)
local pull = assert(callbacks['noir_skills:server:sync'], 'callback de sync não registrado')
T.equal(pull(1).arrombamento, 0, 'o cliente consegue pedir o próprio estado')
T.equal(pull(1).mecanica, 200, 'e o que foi gravado volta do banco na reconexão')
T.equal(next(pull(99)), nil, 'quem não está carregado recebe tabela vazia')

-- Comandos de admin -----------------------------------------------------------------------------
reset()
local addxp = assert(commands['addskillxp'], 'comando addskillxp não registrado')

addxp(1, { target = 1, skill = 'Tráfico', amount = 120 })
T.equal(api('GetXp', 1, 'trafico'), 120, 'o comando aceita o rótulo com acento, não só a chave')

addxp(1, { target = 1, skill = 'ARROMBAMENTO', amount = 30 })
T.equal(api('GetXp', 1, 'arrombamento'), 30, 'e aceita a chave em qualquer caixa')

addxp(1, { target = 1, skill = 'arrombamento', amount = -20 })
T.equal(api('GetXp', 1, 'arrombamento'), 10, 'valor negativo remove XP')

local before = api('GetXp', 1, 'arrombamento')
addxp(1, { target = 1, skill = 'voar', amount = 10 })
T.equal(api('GetXp', 1, 'arrombamento'), before, 'habilidade inexistente não mexe em nada')
T.equal(notifications[#notifications].kind, 'error', 'e o admin é avisado do erro')

addxp(1, { target = 77, skill = 'arrombamento', amount = 10 })
T.equal(notifications[#notifications].source, 1, 'o aviso vai para o admin, não para o alvo')
T.equal(notifications[#notifications].kind, 'error', 'alvo não carregado é erro')

local setlevel = assert(commands['setskilllevel'], 'comando setskilllevel não registrado')
setlevel(1, { target = 1, skill = 'arrombamento', level = 4 })
T.equal(api('GetLevel', 1, 'arrombamento'), 4, 'setskilllevel define o nível')
setlevel(1, { target = 1, skill = 'arrombamento', level = 999 })
T.equal(api('GetLevel', 1, 'arrombamento'), 4, 'nível fora da faixa não passa pelo comando')

local resetskill = assert(commands['resetskill'], 'comando resetskill não registrado')
resetskill(1, { target = 1, skill = 'arrombamento' })
T.equal(api('GetXp', 1, 'arrombamento'), 0, 'resetskill zera a habilidade')

print('server_spec: ok')
