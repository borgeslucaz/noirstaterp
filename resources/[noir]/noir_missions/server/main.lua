---Entrada do servidor. Carrega os módulos (cada componente se registra ao ser carregado),
---lê as missões salvas, liga o monitor e cuida do ciclo de vida: jogador saindo, personagem
---deslogando e resource parando.
local Config = require 'config.server'
local Repository = require 'server.missions.repository'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Monitor = require 'server.instances.monitor'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local MissionComponents = require 'server.components.registry'
local Schema = require 'shared.types.schema'

-- Componentes. A ordem não importa para o runtime; cada um se registra no require.
require 'server.components.flow'
require 'server.components.goto'
require 'server.components.npc'
require 'server.components.vehicles'
require 'server.components.interaction'
require 'server.components.cargo'
require 'server.components.delivery'
require 'server.components.reinforcement'
require 'server.components.chase'

local Rewards = require 'server.rewards.rewards'
local Offers = require 'server.offers'
local Editor = require 'server.editor'
require 'server.api'

-- Todo passo e toda ação do esquema precisa de handler; faltar um é erro de desenvolvimento,
-- e aparece no boot em vez de no meio de uma missão.
for index = 1, #Schema.steps do
    if not MissionComponents.step(Schema.steps[index].type) then
        lib.print.error(('[noir_missions] passo sem handler: %s'):format(Schema.steps[index].type))
    end
end
for index = 1, #Schema.actions do
    local actionType = Schema.actions[index].type
    if actionType ~= 'wait' and not MissionComponents.action(actionType) then
        lib.print.error(('[noir_missions] ação sem handler: %s'):format(actionType))
    end
end

Runtime.io.onFinish = function(inst)
    if inst.status ~= 'COMPLETED' then return end
    if inst.test then
        for source in pairs(inst.participants) do
            Integrations.notify(source, 'Teste concluído. Recompensa não entregue em teste.', 'inform')
        end
        return
    end
    Rewards.grant(inst)
end

Repository.loadAll()
Monitor.run()

-- Ciclo de vida -------------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local src = source
    local inst = Runtime.forPlayer(src)
    if inst then Runtime.removeParticipant(inst, src, 'disconnected') end
    Security.forget(src)
    Offers.forget(src)
    Monitor.forget(src)
end)

-- Trocar de personagem tira da missão: o participante é o personagem, não a conexão.
AddEventHandler('bgrz_core:server:playerUnloaded', function(src)
    src = tonumber(src) or source
    local inst = Runtime.forPlayer(src)
    if inst then Runtime.removeParticipant(inst, src, 'logout') end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local list = {}
    for _, inst in pairs(Runtime.instances) do list[#list + 1] = inst end
    for index = 1, #list do Runtime.finish(list[index], 'CANCELLED', 'resource_stop') end
    World.cleanupAll()
end)

-- Comandos de admin ---------------------------------------------------------------------------

local function adminCommand(name, handler)
    RegisterCommand(name, function(source, args)
        if source ~= 0 and not Editor.isAdmin(source) then return end
        handler(source, args)
    end, false)
end

local function reply(source, message)
    if source == 0 then
        lib.print.info(('[noir_missions] %s'):format(message))
    else
        Integrations.notify(source, message, 'inform')
    end
end

-- /nmoffer <missão> [id do jogador] — liga oferecendo a missão.
adminCommand('nmoffer', function(source, args)
    local target = tonumber(args[2]) or source
    local ok, code = Offers.offer(args[1] or '', target)
    reply(source, ok and 'Oferta enviada.' or ('Oferta recusada: %s'):format(code))
end)

-- /nmstart <missão> [ids...] — começa uma missão publicada direto, sem oferta.
adminCommand('nmstart', function(source, args)
    local list = {}
    for index = 2, #args do list[#list + 1] = tonumber(args[index]) end
    if #list == 0 and source ~= 0 then list[1] = source end
    local id, code = exports[GetCurrentResourceName()]:startMission(args[1] or '', list)
    reply(source, id and ('Instância #%d iniciada.'):format(id) or ('Não iniciou: %s'):format(code))
end)

-- /nmstop <instância>
adminCommand('nmstop', function(source, args)
    local inst = Runtime.get(tonumber(args[1] or '') or 0)
    if not inst then return reply(source, 'Instância não encontrada.') end
    Runtime.finish(inst, 'CANCELLED', 'admin')
    reply(source, 'Instância encerrada.')
end)

-- /nmcooldown <missão> — zera o cooldown.
adminCommand('nmcooldown', function(source, args)
    Repository.clearCooldown(args[1] or '')
    reply(source, 'Cooldown zerado.')
end)

lib.print.info(('[noir_missions] pronto (ACE de admin: %s)'):format(Config.adminAce))
