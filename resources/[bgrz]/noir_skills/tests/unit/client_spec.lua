-- Carrega client/main.lua com o runtime do FiveM stubado e exercita o que o jogador vê:
-- o que entra no painel, o que fica de fora e o aviso de nível.
local T = dofile('tests/testlib.lua')

dofile('shared/config.lua')
dofile('shared/xp.lua')

local notifications = {}
local core = {}

function core:Notify(text, kind)
    notifications[#notifications + 1] = { text = text, kind = kind }
end

-- Runtime stubado ------------------------------------------------------------------------
local registered
exports, registered = T.exports({ bgrz_core = core })

local netEvents, registerNet = T.handlers()
RegisterNetEvent = registerNet
local eventHandlers, registerEvent = T.handlers()
AddEventHandler = registerEvent
local nuiCallbacks, registerNui = T.handlers()
RegisterNUICallback = registerNui

local commands = {}
RegisterCommand = function(name, handler) commands[name] = handler end
local keyMappings = {}
RegisterKeyMapping = function(command, description, _, key)
    keyMappings[command] = { description = description, key = key }
end

local messages = {}
SendNUIMessage = function(payload) messages[#messages + 1] = payload end
local focus = {}
SetNuiFocus = function(a, b) focus = { a, b } end

IsPauseMenuActive = function() return false end
IsNuiFocused = function() return false end
GetCurrentResourceName = function() return 'noir_skills' end

local clientEvents = {}
TriggerEvent = function(name, ...) clientEvents[#clientEvents + 1] = { name = name, args = { ... } } end

-- O thread de boot pede o estado ao servidor; num cliente que acabou de entrar vem vazio.
CreateThread = function(fn) fn() end
lib = { callback = { await = function() return {} end } }

dofile('client/main.lua')

-- Helpers ----------------------------------------------------------------------------------
local function fireNet(event, ...)
    return assert(netEvents[event], 'evento não registrado: ' .. event)(...)
end

local function api(name, ...)
    return assert(registered[name], 'export não registrado: ' .. name)(...)
end

local function open()
    assert(commands[Config.Command], 'comando do painel não registrado')()
    return messages[#messages].data
end

local function byName(list)
    local names = {}
    for i = 1, #list do names[#names + 1] = list[i].name end
    table.sort(names)
    return table.concat(names, ',')
end

local Xp = NoirSkills.xp
local first = Xp.list()[1]
local second = Xp.list()[2]

-- Painel: só o que o personagem treinou -----------------------------------------------------
-- Habilidade zerada não entra na lista: o painel mostra progresso, não o catálogo do config.
fireNet('noir_skills:client:sync', { [first] = 150 })

local data = open()
T.truthy(data.visible, 'abrir o comando mostra o painel')
T.equal(focus[1], true, 'e entrega o foco para a NUI')
T.equal(byName(data.skills), first, 'só a habilidade com XP aparece')
T.equal(data.skills[1].level, Xp.levelFor(first, 150), 'com o nível calculado no cliente')
T.equal(data.skills[1].label, Config.Skills[first].label, 'e o rótulo do config')

local closed = open()
T.falsy(closed.visible, 'o mesmo comando fecha')
T.equal(focus[1], false, 'e devolve o foco ao jogo')

-- Personagem novo: nada treinado, lista vazia (a NUI mostra o estado vazio).
fireNet('noir_skills:client:sync', {})
T.equal(#open().skills, 0, 'sem XP nenhum, a lista vai vazia')
open()

-- Primeiro XP faz a habilidade aparecer sozinha.
fireNet('noir_skills:client:update', second, 40, false)
T.equal(byName(open().skills), second, 'a habilidade entra na lista no primeiro XP')
open()

-- Aviso de nível ------------------------------------------------------------------------------
notifications = {}
fireNet('noir_skills:client:update', second, Xp.totalForLevel(second, 2), true)
T.equal(#notifications, 1, 'subir de nível avisa o jogador')
T.equal(notifications[#notifications].kind, 'success', 'o aviso é de sucesso')
T.truthy(notifications[#notifications].text:find(Config.Skills[second].label, 1, true),
    'e diz qual habilidade subiu')

local levelUp = clientEvents[#clientEvents]
T.equal(levelUp.name, 'noir_skills:client:levelUp', 'outros resources ouvem o nível novo')
T.equal(levelUp.args[2], 2, 'com o nível alcançado')

notifications = {}
fireNet('noir_skills:client:update', second, Xp.totalForLevel(second, 2) + 5, false)
T.equal(#notifications, 0, 'ganho de XP sem subir de nível não avisa nada')

-- Exports locais -------------------------------------------------------------------------------
-- Respondem do cache: são feitos para caber em loop, sem callback para o servidor.
T.equal(api('GetXp', second), Xp.totalForLevel(second, 2) + 5, 'GetXp responde do cache')
T.equal(api('GetLevel', second), 2, 'GetLevel calcula com a curva local')
T.truthy(api('HasLevel', second, 2), 'HasLevel aceita nível alcançado')
T.falsy(api('HasLevel', second, 3), 'HasLevel recusa nível acima')
T.equal(api('GetXp', 'inexistente'), 0, 'habilidade desconhecida responde zero')
T.falsy(api('HasLevel', second, 'dois'), 'nível que não é número é falso')
T.truthy(api('GetAll')[second] ~= nil, 'GetAll traz o estado calculado')

-- Teclado e fechamento pela NUI -----------------------------------------------------------------
T.truthy(keyMappings[Config.Command], 'o painel tem tecla padrão')
T.equal(keyMappings[Config.Command].key, Config.Hotkey, 'a tecla é a do config')

open()
local cb = assert(nuiCallbacks['close'], 'callback de fechar não registrado')
cb({}, function() end)
T.equal(focus[1], false, 'fechar pela NUI devolve o foco')

-- E se o resource parar com o painel aberto, o foco não pode ficar preso.
open()
assert(eventHandlers['onResourceStop'], 'onResourceStop não registrado')('noir_skills')
T.equal(focus[1], false, 'parar o resource com o painel aberto libera o foco')

print('client_spec: ok')
