-- Toda conversa com o framework passa pelo bgrz_core. Este resource só conhece as
-- próprias tabelas (`noir_gang_*`); membros, cargos e personagens vêm do bridge.
local core = exports.bgrz_core

local invitations, cooldowns, locations, locationRequests = {}, {}, {}, {}

local function notify(src, text, kind)
    core:Notify(src, text, kind or 'inform')
end

---@param src number
---@return table|nil gang { name, label, grade, gradeName, isBoss }
local function gangOf(src)
    local gang = core:GetGang(src)
    if not gang or not gang.name or gang.name == 'none' then return nil end
    return gang
end

local function gangInfo(name)
    return name and core:GetGangInfo(name) or nil
end

---Permissão é do CARGO, não do nível. Não há mais herança: o que o arquétipo escreveu
---para aquele cargo é exatamente o que ele pode.
local function allowed(gang, permission)
    if not gang then return false end
    return NoirGangs.can(gang.name, tonumber(gang.grade) or 0, permission)
end

local function near(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if a == b or pedA <= 0 or pedB <= 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= Config.Invitation.maxDistance
end

---O servidor roda com uma gang por personagem (`qbx:max_gangs_per_player` nunca é setado,
---então vale o padrão 1). É justamente por isso que a checagem olha `gangs` e não só a
---gang primária: com o teto em 1, `AddPlayerToGang` recusa quem já tem qualquer gang, e
---quem estivesse em `gangs` com a primária em 'none' passaria pelo convite para falhar
---na entrada, com "não foi possível entrar" no lugar de "já pertence a uma gang".
---@param citizenId string
---@return boolean
local function inAnyGang(citizenId)
    return next(core:GetCharacterGangs(citizenId)) ~= nil
end

local function log(gang, action, actor, target, metadata)
    MySQL.insert('INSERT INTO noir_gang_activity (gang_name, action, actor_citizenid, target_citizenid, metadata) VALUES (?, ?, ?, ?, ?)',
        { gang, action, actor, target, metadata and json.encode(metadata) or nil })
    lib.print.info(('[noir_gangs] %s gang=%s actor=%s target=%s'):format(action, gang, actor or '-', target or '-'))
end

local function clientLocation(row)
    return { id = row.id, gangName = row.gang_name, type = row.location_type,
        coords = { x = row.x, y = row.y, z = row.z }, heading = row.heading,
        size = { x = row.size_x, y = row.size_y, z = row.size_z } }
end

local function reloadLocations()
    local rows = MySQL.query.await("SELECT * FROM noir_gang_locations WHERE location_type = 'management'")
    locations = {}
    for i = 1, #rows do locations[i] = clientLocation(rows[i]) end
    TriggerClientEvent('noir_gangs:client:setLocations', -1, locations)
end

MySQL.ready(function()
    if not NoirGangs.bootstrap() then return end
    reloadLocations()
end)

-- ---------------------------------------------------------------------------
-- Consulta
-- ---------------------------------------------------------------------------
lib.callback.register('noir_gangs:server:getState', function(source)
    local gang = gangOf(source)
    if not gang then return { inGang = false, permissions = {} } end

    local permissions = {}
    for i = 1, #Config.Permissions do permissions[Config.Permissions[i]] = allowed(gang, Config.Permissions[i]) end

    local rank = NoirGangs.rank(gang.name, tonumber(gang.grade) or 0)
    local state = { inGang = true, gang = gang, permissions = permissions,
        rankLabel = rank and rank.label or gang.gradeName }

    if permissions.view_reputation then state.reputation = NoirGangs.reputationOf(gang.name) end
    if permissions.view_products then
        state.products = {}
        for _, product in ipairs(NoirGangs.productsOf(gang.name)) do
            local definition = Config.ProductTypes[product]
            state.products[#state.products + 1] = { id = product, label = definition and definition.label or product }
        end
    end
    return state
end)

lib.callback.register('noir_gangs:server:getMembers', function(source)
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not allowed(gang, 'view_members') then return end

    local canSeeOffline = allowed(gang, 'view_offline_members')
    local visible = {}
    for _, entry in ipairs(core:GetGangMembers(gang.name)) do
        local memberSource = core:GetCharacterSource(entry.citizenId)
        if memberSource or canSeeOffline then
            visible[#visible + 1] = { citizenId = entry.citizenId, grade = entry.grade, online = memberSource ~= nil }
        end
    end

    -- Uma query resolve o nome de todo mundo. Antes era um carregamento completo de
    -- personagem por membro offline, toda vez que alguém abria o menu.
    local citizenIds = {}
    for i = 1, #visible do citizenIds[i] = visible[i].citizenId end
    local names = core:GetCharacterNames(citizenIds)

    local members = {}
    for i = 1, #visible do
        local entry = visible[i]
        local name = names[entry.citizenId]
        if name then
            local rank = NoirGangs.rank(gang.name, entry.grade)
            local nextLevel = NoirGangs.levelAbove(gang.name, entry.grade)
            local nextRank = nextLevel and NoirGangs.rank(gang.name, nextLevel)
            members[#members + 1] = { citizenid = entry.citizenId, name = name, online = entry.online,
                grade = entry.grade, gradeName = rank and rank.label or tostring(entry.grade),
                isBoss = rank ~= nil and rank.isBoss == true,
                -- Promover para chefe não existe, então a UI já esconde a ação em vez de
                -- oferecer um botão que o servidor vai recusar.
                canPromote = nextRank ~= nil and not nextRank.isBoss,
                canDemote = NoirGangs.levelBelow(gang.name, entry.grade) ~= nil }
        end
    end
    table.sort(members, function(a, b) return a.grade > b.grade or (a.grade == b.grade and a.name < b.name) end)

    return { gang = gang, members = members, actorCitizenId = actor.citizenId,
        permissions = { promote = allowed(gang, 'promote'), demote = allowed(gang, 'demote'),
            remove_member = allowed(gang, 'remove_member') } }
end)

lib.callback.register('noir_gangs:server:getActivity', function(source)
    local gang = gangOf(source)
    if not allowed(gang, 'view_members') then return {} end
    return MySQL.query.await(
        ('SELECT action, metadata, created_at FROM noir_gang_activity WHERE gang_name = ? ORDER BY id DESC LIMIT %d')
            :format(math.floor(Config.ActivityLimit)),
        { gang.name })
end)

-- ---------------------------------------------------------------------------
-- Convites
-- ---------------------------------------------------------------------------
local function pruneInvitations(now)
    for id, invite in pairs(invitations) do
        if invite.expires <= now then invitations[id] = nil end
    end
end

RegisterNetEvent('noir_gangs:server:invite', function(target)
    local source = source
    target = tonumber(target)
    local actor, invited = core:GetCharacter(source), target and core:GetCharacter(target)
    local gang = gangOf(source)
    if not actor or not invited or not allowed(gang, 'invite') or not near(source, target) then
        return notify(source, 'Não foi possível convidar esta pessoa.', 'error')
    end
    if inAnyGang(invited.citizenId) then return notify(source, 'Essa pessoa já pertence a uma gang.', 'error') end

    local now = os.time()
    pruneInvitations(now)
    if (cooldowns[source] or 0) > now then return notify(source, 'Aguarde antes de enviar outro convite.', 'error') end
    for _, invite in pairs(invitations) do
        if invite.target == target then return notify(source, 'Essa pessoa já possui um convite pendente.', 'error') end
    end

    local id = ('%s:%s:%s'):format(source, target, now)
    invitations[id] = { actor = source, target = target, gang = gang.name, expires = now + Config.Invitation.duration }
    cooldowns[source] = now + Config.Invitation.cooldown
    log(gang.name, 'invitation_sent', actor.citizenId, invited.citizenId)
    TriggerClientEvent('noir_gangs:client:invitation', target, { id = id, gang = gang.label, actor = actor.name.full })
    notify(source, ('Convite enviado para %s.'):format(invited.name.full), 'success')
end)

RegisterNetEvent('noir_gangs:server:answerInvite', function(id)
    local source, invite = source, invitations[id]
    if not invite or invite.target ~= source then return end
    invitations[id] = nil

    local actor, target = core:GetCharacter(invite.actor), core:GetCharacter(source)
    local gang = gangOf(invite.actor)
    if not actor or not target or not gang or gang.name ~= invite.gang or invite.expires < os.time() or
        not allowed(gang, 'invite') or not near(invite.actor, source) or inAnyGang(target.citizenId) then
        return notify(source, 'Este convite não é mais válido.', 'error')
    end

    if not core:SetGangGrade(target.citizenId, gang.name, Config.DefaultGrade) then
        return notify(source, 'Não foi possível entrar na gang.', 'error')
    end
    log(gang.name, 'member_joined', actor.citizenId, target.citizenId, { grade = Config.DefaultGrade })
    notify(source, ('Você entrou para %s.'):format(gang.label), 'success')
    notify(invite.actor, ('%s entrou para %s.'):format(target.name.full, gang.label), 'success')
end)

RegisterNetEvent('noir_gangs:server:declineInvite', function(id)
    local source, invite = source, invitations[id]
    if not invite or invite.target ~= source then return end
    invitations[id] = nil

    local actor, target = core:GetCharacter(invite.actor), core:GetCharacter(source)
    if actor and target then log(invite.gang, 'invitation_declined', actor.citizenId, target.citizenId) end
end)

-- Sem isso o cooldown sobrevivia à saída do jogador, e o FiveM reaproveita ids de
-- source: um jogador novo herdava o cooldown de quem tinha acabado de sair.
AddEventHandler('playerDropped', function()
    local src = source
    cooldowns[src] = nil
    locationRequests[src] = nil
    for id, invite in pairs(invitations) do
        if invite.actor == src or invite.target == src then invitations[id] = nil end
    end
end)

-- ---------------------------------------------------------------------------
-- Gestão de membros
-- ---------------------------------------------------------------------------
local ACTION_PERMISSION = { promote = 'promote', demote = 'demote', remove = 'remove_member' }

---Chefe é intocável por jogador: não é desligado, não muda de cargo, e ninguém é
---promovido até ele. Trocar quem lidera é operação de admin (`/setgang`) — de propósito,
---para não existir caminho de jogador que passe ou tome a liderança.
---@return boolean
local function isBossLevel(gangName, level)
    local rank = NoirGangs.rank(gangName, level)
    return rank ~= nil and rank.isBoss == true
end

local function memberAction(source, citizenid, action)
    local permission = ACTION_PERMISSION[action]
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not permission or not allowed(gang, permission) then return notify(source, 'Sem permissão.', 'error') end
    if actor.citizenId == citizenid then return notify(source, 'Você não pode fazer isso consigo mesmo.', 'error') end

    local oldGrade = core:GetCharacterGangs(citizenid)[gang.name]
    if not oldGrade then return notify(source, 'Membro inválido.', 'error') end

    -- Não há comparação entre o cargo de quem age e o de quem recebe: quem pode promover,
    -- promove; quem não deve poder, não recebe a permissão no arquétipo. A única barreira
    -- é o chefe.
    if isBossLevel(gang.name, oldGrade) then
        return notify(source, 'O chefe não pode ser desligado nem mudar de cargo.', 'error')
    end

    local targetSource = core:GetCharacterSource(citizenid)

    if action == 'remove' then
        if not core:RemoveFromGang(citizenid, gang.name) then return notify(source, 'Falha ao remover.', 'error') end
        log(gang.name, 'member_removed', actor.citizenId, citizenid, { oldGrade = oldGrade })
        if targetSource then notify(targetSource, ('Você não pertence mais a %s.'):format(gang.label), 'error') end
        return notify(source, 'Membro removido.', 'success')
    end

    local newGrade = action == 'promote' and NoirGangs.levelAbove(gang.name, oldGrade)
        or NoirGangs.levelBelow(gang.name, oldGrade)
    local newRank = newGrade and NoirGangs.rank(gang.name, newGrade)
    if not newRank then return notify(source, 'Alteração de cargo inválida.', 'error') end
    if newRank.isBoss then
        return notify(source, 'Ninguém é promovido a chefe pelo menu. Isso é com a administração.', 'error')
    end

    if not core:SetGangGrade(citizenid, gang.name, newGrade) then return notify(source, 'Falha ao alterar cargo.', 'error') end

    log(gang.name, action == 'promote' and 'member_promoted' or 'member_demoted', actor.citizenId, citizenid,
        { oldGrade = oldGrade, newGrade = newGrade })
    if targetSource then notify(targetSource, ('Seu novo cargo é %s.'):format(newRank.label), 'success') end
    notify(source, ('Cargo alterado para %s.'):format(newRank.label), 'success')
end

RegisterNetEvent('noir_gangs:server:memberAction', function(citizenid, action)
    if type(citizenid) == 'string' and ACTION_PERMISSION[action] then memberAction(source, citizenid, action) end
end)

RegisterNetEvent('noir_gangs:server:leaveGang', function()
    local source = source
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not gang then return end

    -- Sem trava para o chefe: como não há transferência de liderança por jogador, exigir
    -- que ele passasse o cargo antes o prenderia na gang para sempre. Chefe que sai deixa
    -- a gang sem topo, e quem recompõe é a administração, com /setgang.
    local actorGrade = tonumber(gang.grade) or 0
    if not core:RemoveFromGang(actor.citizenId, gang.name) then
        return notify(source, 'Não foi possível sair da gang.', 'error')
    end
    log(gang.name, 'member_left', actor.citizenId, actor.citizenId, { grade = actorGrade })
    notify(source, ('Você saiu de %s.'):format(gang.label), 'inform')
end)

-- ---------------------------------------------------------------------------
-- Setup admin
-- ---------------------------------------------------------------------------
local function admin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.AdminAce)
end

RegisterCommand('gangsetup', function(source)
    if source <= 0 then return lib.print.error('[noir_gangs] /gangsetup só funciona em jogo') end
    if not admin(source) then return notify(source, 'Acesso negado.', 'error') end
    TriggerClientEvent('noir_gangs:client:openSetup', source, core:GetGangList(), locations)
end, false)

lib.callback.register('noir_gangs:server:createLocation', function(source, gangName, data)
    if not admin(source) or not gangInfo(gangName) then return false end
    local actor = core:GetCharacter(source)
    local id = MySQL.insert.await('INSERT INTO noir_gang_locations (gang_name, location_type, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { gangName, 'management', data.x, data.y, data.z, data.heading or 0, actor.citizenId })
    log(gangName, 'management_point_created', actor.citizenId, nil, { id = id, coords = data })
    reloadLocations()
    return id
end)

lib.callback.register('noir_gangs:server:updateLocation', function(source, id, data)
    if not admin(source) then return false end
    local row = MySQL.single.await('SELECT gang_name FROM noir_gang_locations WHERE id = ?', { id })
    if not row then return false end
    MySQL.update.await('UPDATE noir_gang_locations SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?', { data.x, data.y, data.z, data.heading or 0, id })
    log(row.gang_name, 'management_point_moved', core:GetCharacter(source).citizenId, nil, { id = id, coords = data })
    reloadLocations()
    return true
end)

lib.callback.register('noir_gangs:server:deleteLocation', function(source, id)
    if not admin(source) then return false end
    local row = MySQL.single.await('SELECT gang_name FROM noir_gang_locations WHERE id = ?', { id })
    if not row then return false end
    MySQL.query.await('DELETE FROM noir_gang_locations WHERE id = ?', { id })
    log(row.gang_name, 'management_point_deleted', core:GetCharacter(source).citizenId, nil, { id = id })
    reloadLocations()
    return true
end)

-- Quem pede a lista é o client, ao entrar e a cada restart do resource: um empurrão do
-- servidor no start se perderia, porque os dois lados reiniciam juntos e o client ainda
-- não registrou o evento. Como o pedido vem de fora, ele tem teto por source — era um
-- callback aberto a spam. Edições do admin continuam saindo por broadcast do servidor.
lib.callback.register('noir_gangs:server:getLocations', function(source)
    local now = os.time()
    if (locationRequests[source] or 0) > now then return end
    locationRequests[source] = now + Config.LocationRequestCooldown
    return locations
end)

-- ---------------------------------------------------------------------------
-- Reputação
-- ---------------------------------------------------------------------------
---Ponto único de escrita da reputação: admin e outros resources passam por aqui, então
---todo ajuste fica no histórico da gang com quem pediu e por quê.
---@return integer|nil novoTotal
---@return string? errorCode
local function applyReputation(gangName, delta, reason, actorCitizenId)
    local updated, err = NoirGangs.addReputation(gangName, delta)
    if not updated or err == 'at_limit' then return updated, err or 'operation_failed' end
    log(gangName, 'reputation_changed', actorCitizenId, nil,
        { delta = delta, total = updated, reason = reason })
    return updated
end

RegisterCommand('gangrep', function(source, args)
    if source <= 0 then return lib.print.error('[noir_gangs] /gangrep só funciona em jogo') end
    if not admin(source) then return notify(source, 'Acesso negado.', 'error') end

    local gangName, delta = args[1], tonumber(args[2])
    if not gangName or not delta then
        return notify(source, 'Uso: /gangrep <gang> <pontos>. Use número negativo para tirar.', 'error')
    end

    local actor = core:GetCharacter(source)
    local updated, err = applyReputation(gangName, delta, table.concat(args, ' ', 3), actor and actor.citizenId)
    if not updated then return notify(source, ('Não foi possível alterar a reputação (%s).'):format(tostring(err)), 'error') end
    if err == 'at_limit' then return notify(source, ('%s já está no limite (%d).'):format(gangName, updated), 'error') end
    notify(source, ('Reputação de %s agora é %d.'):format(gangName, updated), 'success')
end, false)

exports('GetGang', function(source) return gangOf(source) end)

-- Atributos para os outros resources: craft, laboratório e tipo de missão perguntam aqui.
exports('GetGangReputation', function(gangName) return NoirGangs.reputationOf(gangName) end)
exports('AddGangReputation', function(gangName, delta, reason)
    return applyReputation(gangName, delta, reason or GetInvokingResource() or 'export')
end)
exports('GetGangProducts', function(gangName) return NoirGangs.productsOf(gangName) end)
exports('HasGangProduct', function(gangName, productType) return NoirGangs.hasProduct(gangName, productType) end)
exports('GetGangRanks', function(gangName) return NoirGangs.ranksOf(gangName) end)

---Produto pela ótica do jogador, que é como a maioria dos chamadores precisa.
exports('PlayerHasGangProduct', function(source, productType)
    local gang = gangOf(source)
    return gang ~= nil and NoirGangs.hasProduct(gang.name, productType)
end)

exports('HasGangPermission', function(source, permission) return allowed(gangOf(source), permission) end)
exports('GetGangMembers', function(gang) return core:GetGangMembers(gang) end)
exports('GetGangManagementLocations', function(name)
    local result = {}
    for i = 1, #locations do if locations[i].gangName == name then result[#result + 1] = locations[i] end end
    return result
end)
