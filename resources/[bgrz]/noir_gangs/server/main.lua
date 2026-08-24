local invitations, cooldowns, locations = {}, {}, {}

local function notify(src, text, kind)
    TriggerClientEvent('ox_lib:notify', src, { description = text, type = kind or 'inform' })
end

local function player(src) return exports.qbx_core:GetPlayer(src) end
local function gangOf(p)
    local gang = p and p.PlayerData.gang
    return gang and gang.name ~= 'none' and gang or nil
end

local function topGrade(name)
    local gang, top = exports.qbx_core:GetGang(name), 0
    if gang then for grade in pairs(gang.grades) do top = math.max(top, tonumber(grade) or 0) end end
    return top
end

local function allowed(gang, permission)
    if not gang then return false end
    local level = tonumber(gang.grade.level) or 0
    local semanticLevel = level == topGrade(gang.name) and 4 or math.min(level, 3)
    for grade = semanticLevel, 0, -1 do
        local rule = Config.DefaultPermissions[grade]
        if rule and rule[permission] ~= nil then return rule[permission] end
    end
    return false
end

local function near(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if a == b or pedA <= 0 or pedB <= 0 then return false end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= Config.Invitation.maxDistance
end

local function charName(p)
    local c = p.PlayerData.charinfo
    return ('%s %s'):format(c.firstname or '', c.lastname or '')
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
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS noir_gang_locations (id INT UNSIGNED NOT NULL AUTO_INCREMENT, gang_name VARCHAR(64) NOT NULL, location_type VARCHAR(32) NOT NULL, x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL, heading FLOAT NOT NULL DEFAULT 0, size_x FLOAT NOT NULL DEFAULT 1.5, size_y FLOAT NOT NULL DEFAULT 1.5, size_z FLOAT NOT NULL DEFAULT 1.5, created_by VARCHAR(128) NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (id), INDEX idx_noir_gang_locations_gang (gang_name), INDEX idx_noir_gang_locations_type (location_type))]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS noir_gang_activity (id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, gang_name VARCHAR(64) NOT NULL, action VARCHAR(64) NOT NULL, actor_citizenid VARCHAR(64) NULL, target_citizenid VARCHAR(64) NULL, metadata JSON NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id), INDEX idx_noir_gang_activity_gang_created (gang_name, created_at))]])
    reloadLocations()
end)

lib.callback.register('noir_gangs:server:getState', function(source)
    local gang = gangOf(player(source))
    if not gang then return { inGang = false, permissions = {} } end
    local permissions = {}
    for name in pairs(Config.DefaultPermissions[4]) do permissions[name] = allowed(gang, name) end
    return { inGang = true, gang = gang, permissions = permissions }
end)

lib.callback.register('noir_gangs:server:getMembers', function(source)
    local actor, gang = player(source), gangOf(player(source))
    if not actor or not allowed(gang, 'view_members') then return end
    local entries, members = exports.qbx_core:GetGroupMembers(gang.name, 'gang'), {}
    local canSeeOffline = allowed(gang, 'view_offline_members')
    for i = 1, #entries do
        local member = exports.qbx_core:GetPlayerByCitizenId(entries[i].citizenid)
        local online = member ~= nil
        if not member and canSeeOffline then member = exports.qbx_core:GetOfflinePlayer(entries[i].citizenid) end
        if member then
            local grade = tonumber(entries[i].grade) or 0
            local gradeInfo = exports.qbx_core:GetGang(gang.name).grades[grade]
            members[#members + 1] = { citizenid = entries[i].citizenid, name = charName(member), online = online,
                grade = grade, gradeName = gradeInfo and gradeInfo.name or tostring(grade) }
        end
    end
    table.sort(members, function(a, b) return a.grade > b.grade or (a.grade == b.grade and a.name < b.name) end)
    return { gang = gang, members = members, actorCitizenId = actor.PlayerData.citizenid,
        permissions = { promote = allowed(gang, 'promote'), demote = allowed(gang, 'demote'), remove_member = allowed(gang, 'remove_member') } }
end)

lib.callback.register('noir_gangs:server:getActivity', function(source)
    local gang = gangOf(player(source))
    if not allowed(gang, 'view_members') then return {} end
    return MySQL.query.await('SELECT action, metadata, created_at FROM noir_gang_activity WHERE gang_name = ? ORDER BY id DESC LIMIT 50', { gang.name })
end)

RegisterNetEvent('noir_gangs:server:invite', function(target)
    local source = source
    target = tonumber(target)
    local actor, invited = player(source), target and player(target)
    local gang = gangOf(actor)
    if not actor or not invited or not allowed(gang, 'invite') or not near(source, target) then return notify(source, 'Não foi possível convidar esta pessoa.', 'error') end
    if gangOf(invited) then return notify(source, 'Essa pessoa já pertence a uma gang.', 'error') end
    local now = os.time()
    if (cooldowns[source] or 0) > now then return notify(source, 'Aguarde antes de enviar outro convite.', 'error') end
    for _, invite in pairs(invitations) do
        if invite.target == target and invite.expires > now then return notify(source, 'Essa pessoa já possui um convite pendente.', 'error') end
    end
    local id = ('%s:%s:%s'):format(source, target, now)
    invitations[id] = { actor = source, target = target, gang = gang.name, expires = now + Config.Invitation.duration }
    cooldowns[source] = now + Config.Invitation.cooldown
    log(gang.name, 'invitation_sent', actor.PlayerData.citizenid, invited.PlayerData.citizenid)
    TriggerClientEvent('noir_gangs:client:invitation', target, { id = id, gang = gang.label, actor = charName(actor) })
    notify(source, ('Convite enviado para %s.'):format(charName(invited)), 'success')
end)

RegisterNetEvent('noir_gangs:server:answerInvite', function(id, accepted)
    local source, invite = source, invitations[id]
    if not invite or invite.target ~= source then return end
    invitations[id] = nil
    local actor, target = player(invite.actor), player(source)
    local gang = gangOf(actor)
    if not accepted then
        if actor and target then log(invite.gang, 'invitation_declined', actor.PlayerData.citizenid, target.PlayerData.citizenid) end
        return
    end
    if not actor or not target or not gang or gang.name ~= invite.gang or invite.expires < os.time() or
        not allowed(gang, 'invite') or not near(invite.actor, source) or gangOf(target) then
        return notify(source, 'Este convite não é mais válido.', 'error')
    end
    local ok = exports.qbx_core:AddPlayerToGang(target.PlayerData.citizenid, gang.name, Config.DefaultGrade)
    if ok then ok = exports.qbx_core:SetPlayerPrimaryGang(target.PlayerData.citizenid, gang.name) end
    if not ok then return notify(source, 'Não foi possível entrar na gang.', 'error') end
    log(gang.name, 'member_joined', actor.PlayerData.citizenid, target.PlayerData.citizenid, { grade = Config.DefaultGrade })
    notify(source, ('Você entrou para %s.'):format(gang.label), 'success')
    notify(invite.actor, ('%s entrou para %s.'):format(charName(target), gang.label), 'success')
end)

local function memberAction(source, citizenid, action)
    local actor, gang = player(source), gangOf(player(source))
    local permission = action == 'promote' and 'promote' or action == 'demote' and 'demote' or 'remove_member'
    if not actor or not allowed(gang, permission) then return notify(source, 'Sem permissão.', 'error') end
    local target = exports.qbx_core:GetPlayerByCitizenId(citizenid) or exports.qbx_core:GetOfflinePlayer(citizenid)
    if not target or not target.PlayerData.gangs[gang.name] then return notify(source, 'Membro inválido.', 'error') end
    local actorGrade, oldGrade = tonumber(gang.grade.level), tonumber(target.PlayerData.gangs[gang.name])
    if actor.PlayerData.citizenid == citizenid or oldGrade >= actorGrade or oldGrade == topGrade(gang.name) then return notify(source, 'A hierarquia protege este membro.', 'error') end
    if action == 'remove' then
        if not exports.qbx_core:RemovePlayerFromGang(citizenid, gang.name) then return notify(source, 'Falha ao remover.', 'error') end
        log(gang.name, 'member_removed', actor.PlayerData.citizenid, citizenid, { oldGrade = oldGrade })
        if not target.Offline then notify(target.PlayerData.source, ('Você não pertence mais a %s.'):format(gang.label), 'error') end
        return notify(source, 'Membro removido.', 'success')
    end
    local newGrade = action == 'promote' and oldGrade + 1 or oldGrade - 1
    local gradeInfo = exports.qbx_core:GetGang(gang.name).grades[newGrade]
    if newGrade < 0 or newGrade >= actorGrade or not gradeInfo then return notify(source, 'Alteração de cargo inválida.', 'error') end
    if not exports.qbx_core:AddPlayerToGang(citizenid, gang.name, newGrade) then return notify(source, 'Falha ao alterar cargo.', 'error') end
    log(gang.name, action == 'promote' and 'member_promoted' or 'member_demoted', actor.PlayerData.citizenid, citizenid, { oldGrade = oldGrade, newGrade = newGrade })
    if not target.Offline then notify(target.PlayerData.source, ('Seu novo cargo é %s.'):format(gradeInfo.name), 'success') end
    notify(source, ('Cargo alterado para %s.'):format(gradeInfo.name), 'success')
end

RegisterNetEvent('noir_gangs:server:memberAction', function(citizenid, action)
    if action == 'promote' or action == 'demote' or action == 'remove' then memberAction(source, citizenid, action) end
end)

local function admin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.AdminAce)
end

RegisterCommand('gangsetup', function(source)
    if not admin(source) then return notify(source, 'Acesso negado.', 'error') end
    local gangs = {}
    for name, gang in pairs(exports.qbx_core:GetGangs()) do if name ~= 'none' then gangs[#gangs + 1] = { name = name, label = gang.label } end end
    table.sort(gangs, function(a, b) return a.label < b.label end)
    TriggerClientEvent('noir_gangs:client:openSetup', source, gangs, locations)
end)

lib.callback.register('noir_gangs:server:createLocation', function(source, gangName, data)
    if not admin(source) or gangName == 'none' or not exports.qbx_core:GetGang(gangName) then return false end
    local actor = player(source)
    local id = MySQL.insert.await('INSERT INTO noir_gang_locations (gang_name, location_type, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { gangName, 'management', data.x, data.y, data.z, data.heading or 0, actor.PlayerData.citizenid })
    log(gangName, 'management_point_created', actor.PlayerData.citizenid, nil, { id = id, coords = data })
    reloadLocations()
    return id
end)

lib.callback.register('noir_gangs:server:updateLocation', function(source, id, data)
    if not admin(source) then return false end
    local row = MySQL.single.await('SELECT gang_name FROM noir_gang_locations WHERE id = ?', { id })
    if not row then return false end
    MySQL.update.await('UPDATE noir_gang_locations SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?', { data.x, data.y, data.z, data.heading or 0, id })
    log(row.gang_name, 'management_point_moved', player(source).PlayerData.citizenid, nil, { id = id, coords = data })
    reloadLocations()
    return true
end)

lib.callback.register('noir_gangs:server:deleteLocation', function(source, id)
    if not admin(source) then return false end
    local row = MySQL.single.await('SELECT gang_name FROM noir_gang_locations WHERE id = ?', { id })
    if not row then return false end
    MySQL.query.await('DELETE FROM noir_gang_locations WHERE id = ?', { id })
    log(row.gang_name, 'management_point_deleted', player(source).PlayerData.citizenid, nil, { id = id })
    reloadLocations()
    return true
end)

RegisterNetEvent('noir_gangs:server:requestLocations', function() TriggerClientEvent('noir_gangs:client:setLocations', source, locations) end)
exports('GetGang', function(source) return gangOf(player(source)) end)
exports('HasGangPermission', function(source, permission) return allowed(gangOf(player(source)), permission) end)
exports('GetGangMembers', function(gang) return exports.qbx_core:GetGroupMembers(gang, 'gang') end)
exports('GetGangManagementLocations', function(name)
    local result = {}
    for i = 1, #locations do if locations[i].gangName == name then result[#result + 1] = locations[i] end end
    return result
end)
