-- Estado de gang e notificações vêm do bgrz_core; este resource não fala com o
-- framework diretamente.
--
-- Cada tela tem o seu arquivo: a gestão em `client/ui.lua`, a administração em
-- `client/setup.lua`. O que sobra aqui é o que não é tela — o radial, as zonas de gestão no
-- mundo e o convite, que é uma pergunta de dois botões para quem está no meio da rua.
local core = exports.bgrz_core

local zones, radialAdded = {}, false
local directory = {} -- gangName -> { name, label, color, colorHex }

local function notify(text, kind) core:Notify(text, kind or 'inform') end
-- A gang vem do state bag do próprio jogador, escrito pelo servidor deste resource.
--
-- Antes vinha de `PlayerData.gang` pelo bridge -- ou seja, do Qbox. O dado não mora mais
-- lá: quem é dono da membresia é o servidor daqui, e o state bag é como ele publica.
--
-- `false` é ausência explícita de gang; o servidor grava assim de propósito, porque state
-- bag apagado e state bag nunca escrito são indistinguíveis.
local function gang()
    local value = LocalPlayer.state.noirGang
    if type(value) ~= 'table' then return nil end
    return value
end

local INVITE_ERRORS = {
    no_gang = 'Você não está em uma gang.',
    no_permission = 'Seu cargo não convida.',
    invalid_target = 'Ninguém por perto para convidar.',
    already_in_gang = 'Essa pessoa já pertence a uma gang.',
    cooldown = 'Aguarde antes de enviar outro convite.',
    pending_invite = 'Essa pessoa já possui um convite pendente.',
}

---Convite pelo radial: mesma checagem do servidor, apresentação de rua. A tela de gestão
---chama o mesmo callback e mostra o resultado nela mesma.
local function inviteNearby()
    local closest = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.Invitation.maxDistance, false)
    if not closest then return notify('Nenhuma pessoa próxima.', 'error') end

    local ok, code, name = lib.callback.await('noir_gangs:server:invite', false, GetPlayerServerId(closest))
    if not ok then return notify(INVITE_ERRORS[code] or 'Não foi possível convidar esta pessoa.', 'error') end
    notify(('Convite enviado para %s.'):format(name or 'a pessoa'), 'success')
end

local function refreshRadial()
    if radialAdded then lib.removeRadialItem('noir_gang_actions'); radialAdded = false end
    local state = lib.callback.await('noir_gangs:server:getState', false)
    if not state or not state.inGang then return end
    local items = {{ label = 'Minha Gang', icon = 'users', onSelect = Menu.open }}
    if state.permissions.invite then items[#items + 1] = { label = 'Convidar pessoa próxima', icon = 'user-plus', onSelect = inviteNearby } end
    lib.registerRadial({ id = 'noir_gang_submenu', items = items })
    lib.addRadialItem({ id = 'noir_gang_actions', label = 'Gang', icon = 'skull-crossbones', menu = 'noir_gang_submenu' })
    radialAdded = true
end

RegisterNetEvent('noir_gangs:client:invitation', function(invite)
    if type(invite) ~= 'table' or not invite.id then return end
    local gangLabel, actorName = tostring(invite.gang or 'Gang'), tostring(invite.actor or 'Alguém')
    lib.registerContext({
        id = 'noir_gangs_invitation',
        title = ('Convite — %s'):format(gangLabel:upper()),
        canClose = false,
        options = {
            { title = 'Aceitar convite', description = ('Entrar para a gang de %s.'):format(actorName), icon = 'check', iconColor = '#69c586',
                onSelect = function() TriggerServerEvent('noir_gangs:server:answerInvite', invite.id) end },
            { title = 'Recusar convite', description = ('Recusar o convite de %s.'):format(actorName), icon = 'xmark', iconColor = '#c44747',
                onSelect = function() TriggerServerEvent('noir_gangs:server:declineInvite', invite.id) end },
        }
    })
    lib.showContext('noir_gangs_invitation')
end)

---Recria as zonas de gestão. Serve tanto para o broadcast do servidor (edição do admin)
---quanto para a busca do próprio client, para não haver dois caminhos que divergem.
local function applyLocations(incoming)
    for i = 1, #zones do core:RemoveZoneTarget(zones[i]) end
    zones = {}
    if type(incoming) ~= 'table' then return end

    for i = 1, #incoming do
        local location = incoming[i]
        local name = ('management:%s'):format(location.id)
        local ok, err = core:AddBoxZoneTarget({
            name = name,
            coords = vec3(location.coords.x, location.coords.y, location.coords.z),
            size = vec3(location.size.x, location.size.y, location.size.z),
            rotation = location.heading,
            options = {{ name = 'manage', icon = 'users-gear', label = 'Gerenciar Gang',
                distance = Config.ManagementDistance,
                canInteract = function()
                    local current = gang()
                    return current ~= nil and current.name == location.gangName and current.name ~= 'none'
                end,
                onSelect = Menu.open }}
        })
        if ok then
            zones[#zones + 1] = name
        else
            lib.print.error(('[noir_gangs] zona %s falhou: %s'):format(name, tostring(err)))
        end
    end
end

RegisterNetEvent('noir_gangs:client:setLocations', applyLocations)

---Diretório de gangs do lado do cliente: nome, rótulo e cor. Serve para quem desenha e não
---pode perguntar ao servidor a cada quadro — o mapa de território pinta bairro com isto.
RegisterNetEvent('noir_gangs:client:setGangs', function(list)
    directory = {}
    for i = 1, #(list or {}) do directory[list[i].name] = list[i] end
end)

local function requestGangs()
    local list = lib.callback.await('noir_gangs:server:getGangs', false)
    if type(list) ~= 'table' then return end
    directory = {}
    for i = 1, #list do directory[list[i].name] = list[i] end
end

---@return string hexadecimal; gang desconhecida devolve a cor padrão do config
exports('GetGangColor', function(gangName)
    local entry = directory[gangName]
    if entry and type(entry.colorHex) == 'string' then return entry.colorHex end
    local fallback = Config.Colors[Config.FallbackColor]
    return ('#%02X%02X%02X'):format(fallback.r, fallback.g, fallback.b)
end)

exports('GetGangDirectory', function() return directory end)

local function requestLocations()
    local incoming = lib.callback.await('noir_gangs:server:getLocations', false)
    -- nil é o servidor segurando o pedido pelo cooldown; as zonas atuais seguem valendo.
    if incoming then applyLocations(incoming) end
end

-- O bgrz_core já normaliza entrar/sair de gang e troca de cargo num evento só.
AddEventHandler('bgrz_core:client:playerLoaded', function()
    refreshRadial()
    requestGangs()
    requestLocations()
end)

---Cargo ou gang mudaram com a tela aberta: o que está desenhado é de antes. Fechar é mais
---honesto do que redesenhar por baixo de uma pessoa no meio de uma ação.
RegisterNetEvent('noir_gangs:client:gangChanged', function()
    Menu.forceClose()
    refreshRadial()
end)

AddEventHandler('bgrz_core:client:playerUnloaded', function()
    Menu.forceClose()
    Setup.forceClose()
    if radialAdded then lib.removeRadialItem('noir_gang_actions'); radialAdded = false end
end)

-- Restart do resource com o jogador já em jogo: `playerLoaded` não vai disparar de novo.
CreateThread(function()
    Wait(1500)
    if not core:IsLoggedIn() then return end
    refreshRadial()
    requestGangs()
    requestLocations()
end)

-- Restart só do `bgrz_core`, que é o que acontece quando o bridge é atualizado sozinho: ao
-- parar ele apaga as zonas de todo caller, e volta com o registro vazio. Os pontos de gestão
-- somem do mundo e ninguém os recria -- `playerLoaded` não dispara de novo, porque quem
-- reiniciou foi o bridge e não o jogador, e o broadcast de `setLocations` só sai quando um
-- admin edita um ponto. Sem isto a gestão fica morta até o relog.
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'bgrz_core' then return end
    if not core:IsLoggedIn() then return end
    refreshRadial()
    requestGangs()
    requestLocations()
end)

---Sem isto, um restart com a tela aberta deixaria o jogador com o foco preso e sem teclado.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    Menu.state, Setup.state = 'CLOSED', 'CLOSED'
    SetNuiFocus(false, false)
end)

exports('OpenManagement', function() Menu.open() end)
