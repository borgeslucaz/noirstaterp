local zones, radialAdded = {}, false
local function notify(text, kind) lib.notify({ description = text, type = kind or 'inform' }) end
local function gang() return QBX.PlayerData.gang end

local function closestPlayer()
    local id = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.Invitation.maxDistance, false)
    if not id then return end
    return GetPlayerServerId(id)
end

local function openMember(member, data)
    local options = {{ title = member.gradeName, description = member.online and 'Online' or 'Offline', icon = 'user', disabled = true }}
    local function action(label, event, icon, danger)
        options[#options + 1] = { title = label, icon = icon, iconColor = danger and '#c44747' or nil, onSelect = function()
            if lib.alertDialog({ header = label, content = ('Confirmar ação sobre **%s**?'):format(member.name), centered = true, cancel = true }) == 'confirm' then
                TriggerServerEvent('noir_gangs:server:memberAction', member.citizenid, event)
            end
        end }
    end
    if member.citizenid ~= data.actorCitizenId then
        if data.permissions.promote then action('Promover', 'promote', 'arrow-up') end
        if data.permissions.demote then action('Rebaixar', 'demote', 'arrow-down') end
        if data.permissions.remove_member then action('Remover da gang', 'remove', 'user-minus', true) end
    end
    lib.registerContext({ id = 'noir_gangs_member', title = member.name, menu = 'noir_gangs_members', options = options })
    lib.showContext('noir_gangs_member')
end

local function openMembers()
    local data = lib.callback.await('noir_gangs:server:getMembers', false)
    if not data then return notify('Sem permissão para ver os membros.', 'error') end
    local options = {}
    for i = 1, #data.members do
        local member = data.members[i]
        options[#options + 1] = { title = member.name,
            description = ('%s • %s'):format(member.gradeName, member.online and 'ONLINE' or 'OFFLINE'),
            icon = 'user', iconColor = member.online and '#69c586' or '#777777',
            onSelect = function() openMember(member, data) end }
    end
    if #options == 0 then options[1] = { title = 'Nenhum membro visível', disabled = true } end
    lib.registerContext({ id = 'noir_gangs_members', title = ('%s — MEMBROS'):format(data.gang.label:upper()), menu = 'noir_gangs_main', options = options })
    lib.showContext('noir_gangs_members')
end

local function openActivity()
    local rows = lib.callback.await('noir_gangs:server:getActivity', false) or {}
    local options = {}
    for i = 1, #rows do
        local metadata = rows[i].metadata
        if type(metadata) == 'string' then metadata = json.decode(metadata) end
        if type(metadata) == 'table' then
            local displayMetadata = {}
            for key, value in pairs(metadata) do
                if type(value) == 'table' then
                    if value.x and value.y and value.z then
                        value = ('X: %.2f, Y: %.2f, Z: %.2f%s'):format(
                            tonumber(value.x) or 0,
                            tonumber(value.y) or 0,
                            tonumber(value.z) or 0,
                            value.heading and (', H: %.2f'):format(tonumber(value.heading) or 0) or ''
                        )
                    else
                        value = json.encode(value)
                    end
                elseif value ~= nil then
                    value = tostring(value)
                end
                displayMetadata[tostring(key)] = value
            end
            metadata = displayMetadata
        end
        options[#options + 1] = { title = rows[i].action:gsub('_', ' '), description = tostring(rows[i].created_at), metadata = metadata, icon = 'clock-rotate-left' }
    end
    if #options == 0 then options[1] = { title = 'Nenhuma atividade registrada', disabled = true } end
    lib.registerContext({ id = 'noir_gangs_activity', title = 'ATIVIDADE', menu = 'noir_gangs_main', options = options })
    lib.showContext('noir_gangs_activity')
end

local function openManagement()
    local state = lib.callback.await('noir_gangs:server:getState', false)
    if not state or not state.inGang or not state.permissions.view_members then return notify('Sem acesso à gestão.', 'error') end
    lib.registerContext({ id = 'noir_gangs_main', title = state.gang.label:upper(), options = {
        { title = 'Membros', description = 'Lista, cargos e status', icon = 'users', onSelect = openMembers },
        { title = 'Atividade', description = 'Histórico de gestão', icon = 'clock-rotate-left', onSelect = openActivity },
        { title = 'Meu cargo', description = state.gang.grade.name, icon = 'ranking-star', disabled = true },
    } })
    lib.showContext('noir_gangs_main')
end

local function inviteNearby()
    local target = closestPlayer()
    if not target then return notify('Nenhuma pessoa próxima.', 'error') end
    TriggerServerEvent('noir_gangs:server:invite', target)
end

local function refreshRadial()
    if radialAdded then lib.removeRadialItem('noir_gang_actions'); radialAdded = false end
    local state = lib.callback.await('noir_gangs:server:getState', false)
    if not state or not state.inGang then return end
    local items = {{ label = 'Minha Gang', icon = 'users', onSelect = openManagement }}
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
                onSelect = function() TriggerServerEvent('noir_gangs:server:answerInvite', invite.id, true) end },
            { title = 'Recusar convite', description = ('Recusar o convite de %s.'):format(actorName), icon = 'xmark', iconColor = '#c44747',
                onSelect = function() TriggerServerEvent('noir_gangs:server:answerInvite', invite.id, false) end },
        }
    })
    lib.showContext('noir_gangs_invitation')
end)

RegisterNetEvent('noir_gangs:client:setLocations', function(locations)
    for i = 1, #zones do exports.ox_target:removeZone(zones[i]) end
    zones = {}
    for i = 1, #locations do
        local location = locations[i]
        zones[#zones + 1] = exports.ox_target:addBoxZone({
            coords = vec3(location.coords.x, location.coords.y, location.coords.z),
            size = vec3(location.size.x, location.size.y, location.size.z), rotation = location.heading,
            options = {{ name = ('noir_gang_management_%s'):format(location.id), icon = 'users-gear', label = 'Gerenciar Gang',
                distance = Config.ManagementDistance,
                canInteract = function()
                    local current = gang()
                    return current and current.name == location.gangName and current.name ~= 'none'
                end,
                onSelect = openManagement }}
        })
    end
end)

local function place(gangName, locationId)
    notify('Posicione-se no local. E confirma; BACKSPACE cancela.')
    CreateThread(function()
        while true do
            Wait(0)
            local coords = GetEntityCoords(cache.ped)
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.5, 120, 25, 35, 100, false, false, 2, false)
            if IsControlJustReleased(0, 38) then
                local data = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(cache.ped) }
                local ok = locationId and lib.callback.await('noir_gangs:server:updateLocation', false, locationId, data)
                    or lib.callback.await('noir_gangs:server:createLocation', false, gangName, data)
                return notify(ok and 'Ponto de gestão salvo.' or 'Não foi possível salvar.', ok and 'success' or 'error')
            elseif IsControlJustReleased(0, 177) then return notify('Posicionamento cancelado.') end
        end
    end)
end

local function locationActions(gangData, location)
    lib.registerContext({ id = 'noir_gangs_setup_location', title = ('Ponto #%s'):format(location.id), menu = 'noir_gangs_setup_gang', options = {
        { title = 'Teleportar', icon = 'location-arrow', onSelect = function() SetEntityCoords(cache.ped, location.coords.x, location.coords.y, location.coords.z, false, false, false, false) end },
        { title = 'Mover para minha posição', icon = 'arrows-up-down-left-right', onSelect = function() place(gangData.name, location.id) end },
        { title = 'Excluir', icon = 'trash', iconColor = '#c44747', onSelect = function()
            if lib.alertDialog({ header = 'Excluir ponto', content = 'Esta ação é permanente.', centered = true, cancel = true }) == 'confirm' then
                local ok = lib.callback.await('noir_gangs:server:deleteLocation', false, location.id)
                notify(ok and 'Ponto removido.' or 'Não foi possível remover.', ok and 'success' or 'error')
            end
        end },
    } })
    lib.showContext('noir_gangs_setup_location')
end

local function gangSetup(gangData, locations)
    local options = {{ title = 'Adicionar ponto de gestão', icon = 'plus', onSelect = function() place(gangData.name) end }}
    for i = 1, #locations do
        local location = locations[i]
        if location.gangName == gangData.name then
            options[#options + 1] = { title = ('Ponto #%s'):format(location.id),
                description = ('%.2f, %.2f, %.2f'):format(location.coords.x, location.coords.y, location.coords.z), icon = 'location-dot',
                onSelect = function() locationActions(gangData, location) end }
        end
    end
    lib.registerContext({ id = 'noir_gangs_setup_gang', title = gangData.label, menu = 'noir_gangs_setup', options = options })
    lib.showContext('noir_gangs_setup_gang')
end

RegisterNetEvent('noir_gangs:client:openSetup', function(gangs, locations)
    local options = {}
    for i = 1, #gangs do
        local entry = gangs[i]
        options[#options + 1] = { title = entry.label, description = entry.name, icon = 'users', onSelect = function() gangSetup(entry, locations) end }
    end
    lib.registerContext({ id = 'noir_gangs_setup', title = 'GANG SETUP', options = options })
    lib.showContext('noir_gangs_setup')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() Wait(1000); refreshRadial(); TriggerServerEvent('noir_gangs:server:requestLocations') end)
RegisterNetEvent('QBCore:Client:OnGangUpdate', function() Wait(100); refreshRadial() end)
RegisterNetEvent('qbx_core:client:playerLoggedOut', function() if radialAdded then lib.removeRadialItem('noir_gang_actions'); radialAdded = false end end)
CreateThread(function() Wait(1500); refreshRadial(); TriggerServerEvent('noir_gangs:server:requestLocations') end)
exports('OpenManagement', openManagement)
