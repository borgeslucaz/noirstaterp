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

---Gang conhecida por nós. O registro é nosso, então a pergunta não precisa ir ao provider.
local function gangInfo(name)
    return name and NoirGangs.gangInfo(name) or nil
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

---A gang, o rótulo e a cor viajam para os clientes. Não é dado sensível — é o que já
---aparece em cima da cabeça de todo mundo — e é o que o mapa de território precisa para
---pintar cada bairro sem manter a própria lista de cores.
local function gangDirectory()
    local list = NoirGangs.gangList()
    for i = 1, #list do list[i].colorHex = NoirGangs.gangColor(list[i].name) end
    return list
end

local function broadcastGangs()
    TriggerClientEvent('noir_gangs:client:setGangs', -1, gangDirectory())
end

lib.callback.register('noir_gangs:server:getGangs', function() return gangDirectory() end)

local function reloadLocations()
    local rows = MySQL.query.await("SELECT * FROM noir_gang_locations WHERE location_type = 'management'")
    locations = {}
    for i = 1, #rows do locations[i] = clientLocation(rows[i]) end
    TriggerClientEvent('noir_gangs:client:setLocations', -1, locations)
end

MySQL.ready(function()
    if not NoirGangs.bootstrap() then return end
    reloadLocations()
    broadcastGangs()
end)

-- ---------------------------------------------------------------------------
-- Consulta
-- ---------------------------------------------------------------------------
-- A tela recebe um snapshot inteiro e não calcula nada: o que ela pode fazer, quem ela vê e
-- o que cada ação vai encontrar do outro lado já vem decidido aqui. Os três construtores
-- abaixo existem para que o snapshot e o estado do radial leiam a mesma coisa — duas
-- montagens divergiriam no dia em que uma permissão nova entrasse só numa delas.

local function buildState(source)
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
end

---@return table|nil { gang, members, roster, actorCitizenId, permissions, total, online }
local function buildMembers(source)
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not allowed(gang, 'view_members') then return end

    local canSeeOffline = allowed(gang, 'view_offline_members')
    local roster = core:GetGangMembers(gang.name)
    local visible, onlineCount = {}, 0
    for _, entry in ipairs(roster) do
        local memberSource = core:GetCharacterSource(entry.citizenId)
        if memberSource then onlineCount = onlineCount + 1 end
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

    -- `total` é quanta gente a gang tem, e não quanta gente esta pessoa enxerga:
    -- `view_offline_members` esconde QUEM está fora, não que a gang seja maior.
    return { gang = gang, members = members, roster = roster, actorCitizenId = actor.citizenId,
        total = #roster, online = onlineCount,
        permissions = { promote = allowed(gang, 'promote'), demote = allowed(gang, 'demote'),
            remove_member = allowed(gang, 'remove_member') } }
end

---O histórico sai daqui já legível: nome em vez de identificador, data em segundos e só os
---campos de `metadata` que a tela mostra. A página não deve precisar entender o formato
---interno de um registro para escrever uma linha de histórico.
local ACTIVITY_META = { 'grade', 'oldGrade', 'newGrade', 'delta', 'total', 'reason' }

local function buildActivity(source)
    local gang = gangOf(source)
    if not allowed(gang, 'view_members') then return {} end

    local rows = MySQL.query.await(
        ('SELECT action, actor_citizenid, target_citizenid, metadata, UNIX_TIMESTAMP(created_at) AS created_at'
            .. ' FROM noir_gang_activity WHERE gang_name = ? ORDER BY id DESC LIMIT %d')
            :format(math.floor(Config.ActivityLimit)),
        { gang.name })

    -- Uma query para todos os nomes do histórico, do mesmo jeito que a lista de membros: o
    -- histórico cita quem já saiu da gang, e esses nomes não estão no roster.
    local wanted, seen = {}, {}
    for i = 1, #rows do
        for _, id in ipairs({ rows[i].actor_citizenid, rows[i].target_citizenid }) do
            if type(id) == 'string' and not seen[id] then
                seen[id] = true
                wanted[#wanted + 1] = id
            end
        end
    end
    local names = #wanted > 0 and core:GetCharacterNames(wanted) or {}

    local entries = {}
    for i = 1, #rows do
        local row = rows[i]
        local metadata = row.metadata
        if type(metadata) == 'string' then
            local ok, decoded = pcall(json.decode, metadata)
            metadata = ok and type(decoded) == 'table' and decoded or nil
        end

        local meta = {}
        for _, key in ipairs(ACTIVITY_META) do
            if metadata and metadata[key] ~= nil then meta[key] = metadata[key] end
        end

        entries[i] = {
            action = row.action,
            actorName = row.actor_citizenid and names[row.actor_citizenid] or nil,
            targetName = row.target_citizenid and names[row.target_citizenid] or nil,
            createdAt = tonumber(row.created_at),
            meta = meta,
        }
    end
    return entries
end

---Os cargos da gang, do topo para a base, com quanta gente ocupa cada um. É leitura:
---editar cargo continua não existindo em jogo (ver `Config.RanksFromConfig`).
---
---Conta a gang inteira, e não só quem esta pessoa enxerga, pelo mesmo motivo de
---`memberCount`: `view_offline_members` esconde QUEM está fora, não quantos são. Contar só
---o visível faria a soma dos cargos brigar com o total logo acima, na mesma tela.
local function buildRanks(gangName, roster)
    local counts = {}
    for i = 1, #(roster or {}) do
        counts[roster[i].grade] = (counts[roster[i].grade] or 0) + 1
    end

    local list = {}
    for level, rank in pairs(NoirGangs.ranksOf(gangName)) do
        -- O conjunto vira lista na ordem do catálogo: a tela desenha as permissões sempre
        -- na mesma sequência, e `pairs` não garante ordem nenhuma.
        local permissions = {}
        for i = 1, #Config.Permissions do
            if rank.permissions[Config.Permissions[i]] then permissions[#permissions + 1] = Config.Permissions[i] end
        end

        list[#list + 1] = { level = level, label = rank.label, isBoss = rank.isBoss == true,
            bankAuth = rank.bankAuth == true, permissions = permissions, count = counts[level] or 0 }
    end
    table.sort(list, function(a, b) return a.level > b.level end)
    return list
end

lib.callback.register('noir_gangs:server:getState', buildState)

---Snapshot completo da tela: estado, membros, cargos e histórico numa mensagem só. A NUI
---precisa conseguir se redesenhar inteira a partir daqui — é isso que torna um reload do
---CEF, ou um restart do resource, recuperável sem caminho especial.
lib.callback.register('noir_gangs:server:getSnapshot', function(source)
    local state = buildState(source)
    if not state.inGang then return state end

    local roster = buildMembers(source)
    state.members = roster and roster.members or {}
    state.actorCitizenId = roster and roster.actorCitizenId
    state.memberCount = roster and roster.total or #state.members
    state.onlineCount = roster and roster.online or 0
    state.ranks = buildRanks(state.gang.name, roster and roster.roster)
    state.activity = buildActivity(source)

    -- O editor de cargos precisa saber o que existe para oferecer, e até onde vai. Vem do
    -- servidor para a tela não guardar uma segunda cópia do catálogo que envelhece sozinha.
    if state.permissions.manage_ranks then
        state.permissionCatalog = Config.Permissions
        state.rankLimits = { max = Config.Ranks.max, labelMaxLength = Config.Ranks.labelMaxLength }
    end
    return state
end)

-- ---------------------------------------------------------------------------
-- Convites
-- ---------------------------------------------------------------------------
local function pruneInvitations(now)
    for id, invite in pairs(invitations) do
        if invite.expires <= now then invitations[id] = nil end
    end
end

---O convite responde com um código, e não com uma frase: quem chamou decide como mostrar.
---O mesmo convite sai da tela de gestão e do radial, e cada um apresenta do seu jeito.
lib.callback.register('noir_gangs:server:invite', function(source, target)
    target = tonumber(target)
    local actor, invited = core:GetCharacter(source), target and core:GetCharacter(target)
    local gang = gangOf(source)
    if not actor or not gang then return false, 'no_gang' end
    if not allowed(gang, 'invite') then return false, 'no_permission' end
    if not invited or not near(source, target) then return false, 'invalid_target' end
    if inAnyGang(invited.citizenId) then return false, 'already_in_gang' end

    local now = os.time()
    pruneInvitations(now)
    if (cooldowns[source] or 0) > now then return false, 'cooldown' end
    for _, invite in pairs(invitations) do
        if invite.target == target then return false, 'pending_invite' end
    end

    local id = ('%s:%s:%s'):format(source, target, now)
    invitations[id] = { actor = source, target = target, gang = gang.name, expires = now + Config.Invitation.duration }
    cooldowns[source] = now + Config.Invitation.cooldown
    log(gang.name, 'invitation_sent', actor.citizenId, invited.citizenId)
    TriggerClientEvent('noir_gangs:client:invitation', target, { id = id, gang = gang.label, actor = actor.name.full })
    return true, nil, invited.name.full
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

    -- A porta de entrada é o menor cargo que a gang TEM, e não uma constante: com o editor
    -- em jogo, o cargo mais baixo pode ter sido apagado, e entrar num nível sem cargo é
    -- entrar sem permissão nenhuma e sem rótulo.
    local entryGrade = NoirGangs.bottomLevel(gang.name) or Config.DefaultGrade
    if not core:SetGangGrade(target.citizenId, gang.name, entryGrade) then
        return notify(source, 'Não foi possível entrar na gang.', 'error')
    end
    log(gang.name, 'member_joined', actor.citizenId, target.citizenId, { grade = entryGrade })
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

---Quem age recebe um código e a tela traduz; quem sofre a ação recebe notificação, porque
---não está com o menu aberto.
---@return boolean ok
---@return string? errorCode
---@return string? rankLabel novo cargo, quando houve mudança de cargo
local function memberAction(source, citizenid, action)
    local permission = ACTION_PERMISSION[action]
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not gang then return false, 'no_gang' end
    if not permission or not allowed(gang, permission) then return false, 'no_permission' end
    if actor.citizenId == citizenid then return false, 'self_action' end

    local oldGrade = core:GetCharacterGangs(citizenid)[gang.name]
    if not oldGrade then return false, 'invalid_member' end

    -- Não há comparação entre o cargo de quem age e o de quem recebe: quem pode promover,
    -- promove; quem não deve poder, não recebe a permissão no arquétipo. A única barreira
    -- é o chefe.
    if isBossLevel(gang.name, oldGrade) then return false, 'boss_protected' end

    local targetSource = core:GetCharacterSource(citizenid)

    if action == 'remove' then
        if not core:RemoveFromGang(citizenid, gang.name) then return false, 'failed' end
        log(gang.name, 'member_removed', actor.citizenId, citizenid, { oldGrade = oldGrade })
        if targetSource then notify(targetSource, ('Você não pertence mais a %s.'):format(gang.label), 'error') end
        return true
    end

    local newGrade = action == 'promote' and NoirGangs.levelAbove(gang.name, oldGrade)
        or NoirGangs.levelBelow(gang.name, oldGrade)
    local newRank = newGrade and NoirGangs.rank(gang.name, newGrade)
    if not newRank then return false, 'no_rank_available' end
    if newRank.isBoss then return false, 'boss_not_promotable' end

    if not core:SetGangGrade(citizenid, gang.name, newGrade) then return false, 'failed' end

    log(gang.name, action == 'promote' and 'member_promoted' or 'member_demoted', actor.citizenId, citizenid,
        { oldGrade = oldGrade, newGrade = newGrade })
    if targetSource then notify(targetSource, ('Seu novo cargo é %s.'):format(newRank.label), 'success') end
    return true, nil, newRank.label
end

lib.callback.register('noir_gangs:server:memberAction', function(source, citizenid, action)
    if type(citizenid) ~= 'string' or not ACTION_PERMISSION[action] then return false, 'invalid_action' end
    return memberAction(source, citizenid, action)
end)

lib.callback.register('noir_gangs:server:leaveGang', function(source)
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not gang then return false, 'no_gang' end

    -- Sem trava para o chefe: como não há transferência de liderança por jogador, exigir
    -- que ele passasse o cargo antes o prenderia na gang para sempre. Chefe que sai deixa
    -- a gang sem topo, e quem recompõe é a administração, com /setgang.
    local actorGrade = tonumber(gang.grade) or 0
    if not core:RemoveFromGang(actor.citizenId, gang.name) then return false, 'failed' end

    log(gang.name, 'member_left', actor.citizenId, actor.citizenId, { grade = actorGrade })
    return true, nil, gang.label
end)

-- ---------------------------------------------------------------------------
-- Cargos
-- ---------------------------------------------------------------------------
-- Editar cargo é mexer no que os outros podem fazer, então vale a mesma regra que vale para
-- membro: o chefe é intocável, e ninguém mexe no próprio cargo. A segunda existe porque sem
-- ela `manage_ranks` seria auto-promoção — bastaria marcar todas as permissões no cargo em
-- que a própria pessoa está.

---@return table|nil actor
---@return table|nil gang
---@return string? errorCode
local function rankManager(source)
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not gang then return nil, nil, 'no_gang' end
    if not allowed(gang, 'manage_ranks') then return nil, nil, 'no_permission' end
    return actor, gang
end

local function isOwnRank(gang, level)
    return (tonumber(gang.grade) or 0) == level
end

lib.callback.register('noir_gangs:server:createRank', function(source, label)
    local actor, gang, denied = rankManager(source)
    if not actor then return false, denied end

    local level, err = NoirGangs.createRank(gang.name, label)
    if not level then return false, err end

    log(gang.name, 'rank_created', actor.citizenId, nil, { level = level, label = label })
    return true, nil, level
end)

lib.callback.register('noir_gangs:server:updateRank', function(source, level, data)
    local actor, gang, denied = rankManager(source)
    if not actor then return false, denied end

    level = tonumber(level)
    if not level then return false, 'rank_not_found' end
    if isOwnRank(gang, level) then return false, 'own_rank' end

    local ok, err = NoirGangs.updateRank(gang.name, level, data)
    if not ok then return false, err end

    log(gang.name, 'rank_updated', actor.citizenId, nil,
        { level = level, label = data and data.label })
    return true
end)

lib.callback.register('noir_gangs:server:deleteRank', function(source, level)
    local actor, gang, denied = rankManager(source)
    if not actor then return false, denied end

    level = tonumber(level)
    if not level then return false, 'rank_not_found' end
    if isOwnRank(gang, level) then return false, 'own_rank' end

    local rank = NoirGangs.rank(gang.name, level)
    local ok, err, occupied = NoirGangs.deleteRank(gang.name, level)
    if not ok then return false, err, occupied end

    log(gang.name, 'rank_deleted', actor.citizenId, nil,
        { level = level, label = rank and rank.label })
    return true
end)

-- ---------------------------------------------------------------------------
-- Setup admin
-- ---------------------------------------------------------------------------
local function admin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.AdminAce)
end

---Tudo que a tela de setup desenha. Como ela é de admin, o snapshot inteiro é montado
---atrás do mesmo portão — e cada ação o atravessa de novo, porque a tela não é prova de
---nada: ela só diz o que pedir.
---@return table|nil
local function buildSetup(source)
    if not admin(source) then return end

    local byGang = {}
    for i = 1, #locations do
        local location = locations[i]
        byGang[location.gangName] = byGang[location.gangName] or {}
        table.insert(byGang[location.gangName], { id = location.id, coords = location.coords })
    end

    local gangs = {}
    for _, gang in ipairs(NoirGangs.gangList()) do
        local archetype = Config.RankArchetypes[gang.archetype]
        local _, plainRanks = NoirGangs.rankCount(gang.name)
        gangs[#gangs + 1] = {
            name = gang.name,
            label = gang.label,
            color = gang.color,
            colorHex = NoirGangs.gangColor(gang.name),
            archetype = gang.archetype,
            archetypeLabel = archetype and archetype.label or gang.archetype,
            members = #core:GetGangMembers(gang.name),
            ranks = plainRanks + 1,
            locations = byGang[gang.name] or {},
        }
    end

    local archetypes = {}
    for id, archetype in pairs(Config.RankArchetypes) do
        archetypes[#archetypes + 1] = { id = id, label = archetype.label or id, ranks = #archetype.ranks }
    end
    table.sort(archetypes, function(a, b) return a.label < b.label end)

    local colors = {}
    for id, color in pairs(Config.Colors) do
        colors[#colors + 1] = { id = id, label = color.label or id,
            hex = ('#%02X%02X%02X'):format(color.r, color.g, color.b) }
    end
    table.sort(colors, function(a, b) return a.label < b.label end)

    return { gangs = gangs, archetypes = archetypes, colors = colors,
        limits = { max = Config.Gang.max, nameMaxLength = Config.Gang.nameMaxLength,
            labelMaxLength = Config.Gang.labelMaxLength,
            -- A régua da cor livre vai junto para a tela avisar na hora, em vez de deixar
            -- escolher e só descobrir na recusa. Quem decide continua sendo o servidor.
            color = { minContrast = Config.CustomColor.minContrast, against = Config.CustomColor.against } } }
end

RegisterCommand('gangsetup', function(source)
    if source <= 0 then return lib.print.error('[noir_gangs] /gangsetup só funciona em jogo') end
    if not admin(source) then return notify(source, 'Acesso negado.', 'error') end
    TriggerClientEvent('noir_gangs:client:openSetup', source)
end, false)

lib.callback.register('noir_gangs:server:getSetup', buildSetup)

lib.callback.register('noir_gangs:server:createGang', function(source, data)
    if not admin(source) then return false, 'no_permission' end
    if type(data) ~= 'table' then return false, 'invalid_name' end

    local name, err = NoirGangs.createGang(data.name, data.label, data.archetype, data.color)
    if not name then return false, err end

    broadcastGangs()
    local actor = core:GetCharacter(source)
    log(name, 'gang_created', actor and actor.citizenId, nil,
        { label = data.label, archetype = data.archetype, color = data.color })
    lib.print.info(('[noir_gangs] gang %s criada por %s'):format(name, GetPlayerName(source) or source))
    return true, nil, name
end)

lib.callback.register('noir_gangs:server:updateGang', function(source, data)
    if not admin(source) then return false, 'no_permission' end
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return false, 'gang_not_found' end

    local ok, err, members = NoirGangs.updateGang(data.name, data)
    if not ok then return false, err, members end

    broadcastGangs()
    local actor = core:GetCharacter(source)
    log(data.name, 'gang_updated', actor and actor.citizenId, nil,
        { label = data.label, archetype = data.archetype, color = data.color })
    return true
end)

---O provider guarda gangs e cargos só em memória. Quando ele reinicia sozinho, relê o
---`shared/gangs.lua` — que não tem mais gang nenhuma — e tudo que registramos some. Quem
---relogasse nesse intervalo entraria sem gang, em silêncio. O `Wait` dá tempo de ele
---terminar de subir antes de receber a lista de volta.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'qbx_core' then return end
    CreateThread(function()
        Wait(2000)
        NoirGangs.republishToProvider()
        lib.print.info('[noir_gangs] provider reiniciou: gangs e cargos republicados')
    end)
end)

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

---A cor é identidade da gang, escolhida no `/gangsetup`. Quem desenha mapa, blip ou lista
---pergunta aqui em vez de manter a própria lista — foi assim que o `noir_territories`
---acabou com uma tabela de cores que envelhecia sozinha.
---@return string hexadecimal, sempre; gang desconhecida devolve a cor padrão
exports('GetGangColor', function(gangName) return NoirGangs.gangColor(gangName) end)
exports('GetGangList', function() return NoirGangs.gangList() end)
exports('GetGangManagementLocations', function(name)
    local result = {}
    for i = 1, #locations do if locations[i].gangName == name then result[#result + 1] = locations[i] end end
    return result
end)
