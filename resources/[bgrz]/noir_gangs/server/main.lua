-- Toda conversa com o framework passa pelo bgrz_core. Este resource só conhece as
-- próprias tabelas (`noir_gang_*`); membros, cargos e personagens vêm do bridge.
local core = exports.bgrz_core

local invitations, cooldowns, locations, locationRequests = {}, {}, {}, {}
-- Matéria-prima do snapshot por gang e a guarda de montagem por source. Ver `gangMaterial`
-- e o callback `getSnapshot`.
local snapshotCache, snapshotBuilding = {}, {}

-- O bootstrap pode falhar: erro de digitação no config, schema recusado, banco fora. O que
-- ele deixa para trás não é "servidor sem gangs" — é gang nenhuma publicada no provider, e
-- o Qbox descarta a gang de quem loga nesse estado, com um aviso e nada mais. Então o
-- resource passa a recusar em vez de servir o vazio, e repete o erro no console de tempos
-- em tempos, porque a linha do start some em minutos num servidor movimentado.
local ready = false

-- Uma ação por gang de cada vez. A tela tranca o clique repetido em `BUSY`, mas essa
-- tranca é do cliente, e não é só clique repetido: duas pessoas com `manage_ranks` agindo
-- juntas passam as duas pelo teto de cargos, porque `createRank` lê a memória e só a
-- atualiza depois da escrita, que cede o controle.
local gangLocks = {}

---Roda `fn` com a gang trancada. Devolve `false, 'busy'` para quem chegou no meio.
local function locked(gangName, fn, ...)
    if not gangName then return false, 'no_gang' end
    if gangLocks[gangName] then return false, 'busy' end
    gangLocks[gangName] = true

    -- `pcall` para que um erro lá dentro não deixe a gang trancada para sempre.
    local result = table.pack(pcall(fn, ...))
    gangLocks[gangName] = nil
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

local function notify(src, text, kind)
    core:Notify(src, text, kind or 'inform')
end

---@param src number
---@return table|nil gang { name, label, grade, gradeName, isBoss }
local function gangOf(src)
    local gang = NoirGangs.gangOfSource(src)
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

---`setGrade` não tem uma permissão só: subir na escada exige `promote`, descer exige
---`demote`. Quem tem só uma das duas abre o modal, e a recusa vem na direção errada --
---esta função é só o portão de entrada.
---
---Fica aqui, e não junto de `memberAction`, porque `buildMembers` também a usa: declarada
---lá embaixo, o nome vira lookup global e a chamada estoura em nil.
local function canChangeGrade(gang)
    return allowed(gang, 'promote') or allowed(gang, 'demote')
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
    return NoirGangs.hasAnyGang(citizenId)
end

---Ponto único de escrita do histórico — e, por isso, o lugar certo para invalidar o
---cache: toda mutação de gang passa por aqui, então o refresh que vem logo depois de
---promover, desligar ou editar cargo lê o banco de novo em vez de repetir a tela antiga.
local function log(gang, action, actor, target, metadata)
    snapshotCache[gang] = nil
    MySQL.insert('INSERT INTO noir_gang_activity (gang_name, action, actor_citizenid, target_citizenid, metadata) VALUES (?, ?, ?, ?, ?)',
        { gang, action, actor, target, metadata and json.encode(metadata) or nil })
    lib.print.info(('[noir_gangs] %s gang=%s actor=%s target=%s'):format(action, gang, actor or '-', target or '-'))
end

---A tabela de histórico só cresce, e a leitura fica mais cara junto com ela. A poda é por
---contagem e por gang: corta pelo `id` da linha que está na posição `ActivityRetention`
---mais nova, o que usa exatamente o índice da leitura em vez de varrer por data.
---@param gangName string
---@return integer removidas
local function pruneActivity(gangName)
    local keep = math.floor(Config.ActivityRetention or 0)
    if keep <= 0 then return 0 end

    -- O corte entra formatado, e não como parâmetro, porque `OFFSET ?` depende de o driver
    -- mandar inteiro — é a mesma razão do `LIMIT` em `fetchActivity`.
    local cutoff = MySQL.scalar.await(
        ('SELECT id FROM noir_gang_activity WHERE gang_name = ? ORDER BY id DESC LIMIT 1 OFFSET %d')
            :format(keep),
        { gangName })
    if not cutoff then return 0 end

    local removed = tonumber(MySQL.update.await('DELETE FROM noir_gang_activity WHERE gang_name = ? AND id <= ?',
        { gangName, cutoff })) or 0
    if removed > 0 then
        lib.print.info(('[noir_gangs] histórico de %s podado: %d linhas'):format(gangName, removed))
    end
    return removed
end

local function pruneAllActivity()
    local list = NoirGangs.gangList()
    for i = 1, #list do pruneActivity(list[i].name) end
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
    if not NoirGangs.bootstrap() then
        -- Sem `ready`, todo callback recusa. O alarme repete porque um servidor que sobe
        -- com gangs faltando parece normal até alguém reclamar que perdeu a gang.
        CreateThread(function()
            while not ready do
                lib.print.error('[noir_gangs] BOOTSTRAP FALHOU: nenhuma gang foi publicada e o menu está ' ..
                    'recusando. Corrija os erros acima e reinicie o resource — quem logar até lá entra sem gang.')
                Wait(math.floor(Config.BootstrapAlertInterval * 1000))
            end
        end)
        return
    end
    ready = true

    reloadLocations()
    broadcastGangs()
    pruneAllActivity()

    -- Servidor que fica dias de pé não pode depender só da poda do start.
    local interval = math.floor((Config.ActivityPruneInterval or 0) * 3600000)
    if interval <= 0 then return end
    CreateThread(function()
        while true do
            Wait(interval)
            pruneAllActivity()
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Consulta
-- ---------------------------------------------------------------------------
-- A tela recebe um snapshot inteiro e não calcula nada: o que ela pode fazer, quem ela vê e
-- o que cada ação vai encontrar do outro lado já vem decidido aqui. Os três construtores
-- abaixo existem para que o snapshot e o estado do radial leiam a mesma coisa — duas
-- montagens divergiriam no dia em que uma permissão nova entrasse só numa delas.

local function buildState(source)
    -- Bootstrap falhado não é "esta pessoa não tem gang": é o resource sem registro. A
    -- tela precisa saber a diferença para dizer a coisa certa em vez de "acesso negado".
    if not ready then return { inGang = false, permissions = {}, notReady = true } end

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

---Quem enxerga quem é decidido aqui, a cada pedido, e não no cache: `view_offline_members`
---e o cargo de quem pediu mudam a lista, então a matéria-prima é compartilhada mas a
---montagem é sempre pessoal.
---@param material table ver `gangMaterial`
---@return table|nil { gang, members, roster, actorCitizenId, permissions, total, online }
local function buildMembers(source, material)
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not allowed(gang, 'view_members') then return end

    local canSeeOffline = allowed(gang, 'view_offline_members')
    local roster = material.roster
    local visible, onlineCount = {}, 0
    for _, entry in ipairs(roster) do
        local memberSource = core:GetCharacterSource(entry.citizenId)
        if memberSource then onlineCount = onlineCount + 1 end
        if memberSource or canSeeOffline then
            visible[#visible + 1] = { citizenId = entry.citizenId, grade = entry.grade, online = memberSource ~= nil }
        end
    end

    local names = material.names
    local members = {}
    for i = 1, #visible do
        local entry = visible[i]
        local name = names[entry.citizenId]
        if name then
            local rank = NoirGangs.rank(gang.name, entry.grade)
            members[#members + 1] = { citizenid = entry.citizenId, name = name, online = entry.online,
                grade = entry.grade, gradeName = rank and rank.label or tostring(entry.grade),
                isBoss = rank ~= nil and rank.isBoss == true,
                -- Chefe não muda de cargo por jogador, e ninguém é movido PARA chefe. Fora
                -- isso, qualquer cargo da escada é destino válido -- a escolha é da tela, e
                -- a direção decide qual permissão o servidor vai exigir.
                canChangeGrade = rank == nil or rank.isBoss ~= true }
        end
    end
    -- Ordena pela POSIÇÃO do cargo na escada, não pelo número dele: depois que `level`
    -- virou identidade, um cargo criado depois tem número maior sem estar mais alto.
    local position = {}
    local ladder = NoirGangs.ladder(gang.name)
    for i = 1, #ladder do position[ladder[i].level] = i end
    table.sort(members, function(a, b)
        local pa, pb = position[a.grade] or -1, position[b.grade] or -1
        if pa == pb then return a.name < b.name end
        return pa > pb
    end)

    -- `total` é quanta gente a gang tem, e não quanta gente esta pessoa enxerga:
    -- `view_offline_members` esconde QUEM está fora, não que a gang seja maior.
    return { gang = gang, members = members, roster = roster, actorCitizenId = actor.citizenId,
        total = #roster, online = onlineCount,
        permissions = { promote = allowed(gang, 'promote'), demote = allowed(gang, 'demote'),
            changeGrade = canChangeGrade(gang),
            remove_member = allowed(gang, 'remove_member') } }
end

---O histórico sai daqui já legível: nome em vez de identificador, data em segundos e só os
---campos de `metadata` que a tela mostra. A página não deve precisar entender o formato
---interno de um registro para escrever uma linha de histórico.
local ACTIVITY_META = { 'grade', 'oldGrade', 'newGrade', 'delta', 'total', 'reason' }

local function fetchActivity(gangName)
    local rows = MySQL.query.await(
        ('SELECT action, actor_citizenid, target_citizenid, metadata, UNIX_TIMESTAMP(created_at) AS created_at'
            .. ' FROM noir_gang_activity WHERE gang_name = ? ORDER BY id DESC LIMIT %d')
            :format(math.floor(Config.ActivityLimit)),
        { gangName })

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

---O que o snapshot busca no banco é igual para a gang inteira — o roster, os nomes e o
---histórico — e é o que custa: quatro consultas por abertura de tela. O cache guarda essa
---matéria-prima, nunca o snapshot pronto: o pronto carrega o cargo e o `actorCitizenId` de
---quem pediu, e reaproveitá-lo entregaria membro offline a quem não tem permissão de ver.
---
---A validade é curta e existe contra repetição, não contra desatualização: quem invalida
---de verdade é o `log()`, que roda em toda mutação. O teto também é o que limita o pedido
---repetido — a tela tranca o clique em `BUSY`, mas essa tranca é do cliente e um client
---modificado não a tem.
---@return table { roster, names, activity }
local function gangMaterial(gangName)
    local cached = snapshotCache[gangName]
    if cached and cached.expires > os.time() then return cached end

    -- Nomes do roster inteiro, e não só de quem o pedinte enxerga: a lista é a mesma para
    -- a gang toda, então uma consulta serve todo mundo em vez de uma por recorte.
    local roster = NoirGangs.membersOf(gangName)
    local citizenIds = {}
    for i = 1, #roster do citizenIds[i] = roster[i].citizenId end

    local material = {
        roster = roster,
        names = #citizenIds > 0 and core:GetCharacterNames(citizenIds) or {},
        activity = fetchActivity(gangName),
        expires = os.time() + Config.SnapshotCacheTTL,
    }
    snapshotCache[gangName] = material
    return material
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
    -- `ladder` entrega os cargos por POSIÇÃO, de baixo para cima. Ordenar por `level`
    -- aqui mostraria um cargo novo no lugar errado, porque level virou só identidade.
    for _, rank in ipairs(NoirGangs.ladder(gangName)) do
        local level = rank.level
        -- O conjunto vira lista na ordem do catálogo: a tela desenha as permissões sempre
        -- na mesma sequência, e `pairs` não garante ordem nenhuma.
        local permissions = {}
        for i = 1, #Config.Permissions do
            if rank.permissions[Config.Permissions[i]] then permissions[#permissions + 1] = Config.Permissions[i] end
        end

        list[#list + 1] = { level = level, label = rank.label, isBoss = rank.isBoss == true,
            bankAuth = rank.bankAuth == true, permissions = permissions, count = counts[level] or 0 }
    end

    -- A tela desenha do topo para a base, então inverte o que veio de baixo para cima.
    for i = 1, #list // 2 do
        list[i], list[#list - i + 1] = list[#list - i + 1], list[i]
    end
    return list
end

lib.callback.register('noir_gangs:server:getState', buildState)

---Snapshot completo da tela: estado, membros, cargos e histórico numa mensagem só. A NUI
---precisa conseguir se redesenhar inteira a partir daqui — é isso que torna um reload do
---CEF, ou um restart do resource, recuperável sem caminho especial.
local function buildSnapshot(source)
    local state = buildState(source)
    if not state.inGang then return state end

    -- Uma materialização serve as três partes que liam o banco por conta própria. Sem
    -- `view_members` não se busca nada: a tela nem abre nesse caso.
    local material = state.permissions.view_members and gangMaterial(state.gang.name) or nil
    local roster = material and buildMembers(source, material)
    state.members = roster and roster.members or {}
    state.actorCitizenId = roster and roster.actorCitizenId
    state.memberCount = roster and roster.total or #state.members
    state.onlineCount = roster and roster.online or 0
    state.ranks = buildRanks(state.gang.name, roster and roster.roster)
    state.activity = material and material.activity or {}

    -- O editor de cargos precisa saber o que existe para oferecer, e até onde vai. Vem do
    -- servidor para a tela não guardar uma segunda cópia do catálogo que envelhece sozinha.
    if state.permissions.manage_ranks then
        state.permissionCatalog = Config.Permissions
        state.rankLimits = { max = Config.Ranks.max, labelMaxLength = Config.Ranks.labelMaxLength }
    end
    return state
end

---A montagem cede no meio — as consultas são `await` —, então um mesmo source consegue
---abrir várias montagens antes de a primeira responder, e o cache não ajuda porque
---nenhuma delas terminou para preenchê-lo. A guarda fecha essa janela. O `pcall` está
---aqui para que um erro lá dentro não deixe a porta trancada para sempre.
lib.callback.register('noir_gangs:server:getSnapshot', function(source)
    if snapshotBuilding[source] then return end
    snapshotBuilding[source] = true

    local ok, result = pcall(buildSnapshot, source)
    snapshotBuilding[source] = nil
    if not ok then error(result, 0) end
    return result
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
    if not ready then return false, 'not_ready' end
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
    if not NoirGangs.setMember(target.citizenId, gang.name, entryGrade) then
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
    snapshotBuilding[src] = nil
    for id, invite in pairs(invitations) do
        if invite.actor == src or invite.target == src then invitations[id] = nil end
    end
end)

-- ---------------------------------------------------------------------------
-- Gestão de membros
-- ---------------------------------------------------------------------------
local ACTION_PERMISSION = { remove = 'remove_member' }


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
local function memberAction(source, citizenid, action, level)
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not gang then return false, 'no_gang' end

    if action == 'setGrade' then
        if not canChangeGrade(gang) then return false, 'no_permission' end
    else
        local permission = ACTION_PERMISSION[action]
        if not permission or not allowed(gang, permission) then return false, 'no_permission' end
    end
    if actor.citizenId == citizenid then return false, 'self_action' end

    local oldGrade = NoirGangs.gangOfCitizen(citizenid)
    oldGrade = oldGrade and oldGrade.name == gang.name and oldGrade.grade or nil
    if not oldGrade then return false, 'invalid_member' end

    -- Não há comparação entre o cargo de quem age e o de quem recebe: quem pode promover,
    -- promove; quem não deve poder, não recebe a permissão no arquétipo. A única barreira
    -- é o chefe.
    if isBossLevel(gang.name, oldGrade) then return false, 'boss_protected' end

    local targetSource = core:GetCharacterSource(citizenid)

    if action == 'remove' then
        if not NoirGangs.removeMember(citizenid) then return false, 'failed' end
        log(gang.name, 'member_removed', actor.citizenId, citizenid, { oldGrade = oldGrade })
        if targetSource then notify(targetSource, ('Você não pertence mais a %s.'):format(gang.label), 'error') end
        return true
    end

    local newGrade = tonumber(level)
    local newRank = newGrade and NoirGangs.rank(gang.name, newGrade)
    if not newRank then return false, 'no_rank_available' end
    if newRank.isBoss then return false, 'boss_not_promotable' end
    if newGrade == oldGrade then return false, 'same_rank' end

    -- A direção sai da POSIÇÃO na escada, nunca do número do cargo. Desde que `level`
    -- virou identidade, um cargo criado depois tem número maior sem estar mais alto --
    -- comparar `newGrade > oldGrade` chamaria de promoção o que é rebaixamento.
    local ladder = NoirGangs.ladder(gang.name)
    local oldPosition, newPosition
    for i = 1, #ladder do
        if ladder[i].level == oldGrade then oldPosition = i end
        if ladder[i].level == newGrade then newPosition = i end
    end
    if not oldPosition or not newPosition then return false, 'no_rank_available' end

    local rising = newPosition > oldPosition
    if not allowed(gang, rising and 'promote' or 'demote') then return false, 'no_permission' end

    if not NoirGangs.setMember(citizenid, gang.name, newGrade) then return false, 'failed' end

    log(gang.name, rising and 'member_promoted' or 'member_demoted', actor.citizenId, citizenid,
        { oldGrade = oldGrade, newGrade = newGrade })
    if targetSource then notify(targetSource, ('Seu novo cargo é %s.'):format(newRank.label), 'success') end
    return true, nil, newRank.label
end

lib.callback.register('noir_gangs:server:memberAction', function(source, citizenid, action, level)
    if not ready then return false, 'not_ready' end
    if type(citizenid) ~= 'string' then return false, 'invalid_action' end
    if action ~= 'setGrade' and not ACTION_PERMISSION[action] then return false, 'invalid_action' end
    if action == 'setGrade' and type(level) ~= 'number' then return false, 'invalid_action' end

    local gang = gangOf(source)
    if not gang then return false, 'no_gang' end
    return locked(gang.name, memberAction, source, citizenid, action, level)
end)

lib.callback.register('noir_gangs:server:leaveGang', function(source)
    if not ready then return false, 'not_ready' end
    local actor, gang = core:GetCharacter(source), gangOf(source)
    if not actor or not gang then return false, 'no_gang' end
    return locked(gang.name, function()
        -- Sem trava para o chefe: como não há transferência de liderança por jogador,
        -- exigir que ele passasse o cargo antes o prenderia na gang para sempre. Chefe que
        -- sai deixa a gang sem topo, e quem recompõe é a administração, com /setgang.
        local actorGrade = tonumber(gang.grade) or 0
        if not NoirGangs.removeMember(actor.citizenId) then return false, 'failed' end

        log(gang.name, 'member_left', actor.citizenId, actor.citizenId, { grade = actorGrade })
        return true, nil, gang.label
    end)
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

---O editor inteiro entra por aqui: prontidão, permissão e uma edição por gang de cada vez.
---A tranca é da gang, e não de quem pediu, porque o teto de cargos é da gang: dois chefes
---clicando junto passariam os dois pela contagem, que é lida da memória antes da escrita.
local function rankAction(source, fn)
    if not ready then return false, 'not_ready' end
    local actor, gang, denied = rankManager(source)
    if not actor then return false, denied end
    return locked(gang.name, fn, actor, gang)
end

lib.callback.register('noir_gangs:server:createRank', function(source, label)
    return rankAction(source, function(actor, gang)
        local level, err = NoirGangs.createRank(gang.name, label)
        if not level then return false, err end

        log(gang.name, 'rank_created', actor.citizenId, nil, { level = level, label = label })
        return true, nil, level
    end)
end)

lib.callback.register('noir_gangs:server:updateRank', function(source, level, data)
    return rankAction(source, function(actor, gang)
        level = tonumber(level)
        if not level then return false, 'rank_not_found' end
        if isOwnRank(gang, level) then return false, 'own_rank' end

        local ok, err = NoirGangs.updateRank(gang.name, level, data)
        if not ok then return false, err end

        log(gang.name, 'rank_updated', actor.citizenId, nil,
            { level = level, label = data and data.label })
        return true
    end)
end)

lib.callback.register('noir_gangs:server:deleteRank', function(source, level)
    return rankAction(source, function(actor, gang)
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
end)

-- ---------------------------------------------------------------------------
-- Setup admin
-- ---------------------------------------------------------------------------
local function admin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.AdminAce)
end

---Admin com o resource de pé. Separado do `admin` porque a recusa aqui não é de permissão:
---o registro está vazio, e escrever gang sobre registro vazio é criar a segunda cópia de
---uma gang que existe no banco e não foi lida.
local function adminReady(source)
    return ready and admin(source)
end

---Quem pode receber o primeiro chefe: gente online e fora de qualquer gang. Fora de gang
---porque o servidor roda com uma gang por personagem — pôr alguém que já tem gang aqui
---seria a mesma recusa do convite, só que descoberta depois do clique.
---@return table[] { source, name }
local function bossCandidates()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local candidate = tonumber(id)
        local character = candidate and core:GetCharacter(candidate)
        if character and not inAnyGang(character.citizenId) then
            list[#list + 1] = { source = candidate, name = character.name.full }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

---Produtos que vieram da tela. Devolve a lista limpa, ou `nil` quando algum item não está
---no catálogo — recusar a edição inteira é melhor que gravar metade dela.
---@return string[]|nil
local function readProducts(list)
    if list == nil then return {} end
    if type(list) ~= 'table' then return nil end

    local clean, seen = {}, {}
    for i = 1, #list do
        local product = list[i]
        if type(product) ~= 'string' or not Config.ProductTypes[product] then return nil end
        if not seen[product] then
            seen[product] = true
            clean[#clean + 1] = product
        end
    end
    return clean
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

    -- O roster de cada gang é lido uma vez e reaproveitado: a contagem de membros e o nome
    -- de quem lidera saem do mesmo lugar. E os nomes saem numa consulta só, do mesmo jeito
    -- que a lista de membros — uma por gang seria uma por linha da tela.
    local rosters, bossIds = {}, {}
    for _, gang in ipairs(NoirGangs.gangList()) do
        local roster = NoirGangs.membersOf(gang.name)
        rosters[gang.name] = roster

        local boss = NoirGangs.bossRank(gang.name)
        if boss then
            for _, entry in ipairs(roster) do
                if entry.grade == boss.level then bossIds[#bossIds + 1] = entry.citizenId end
            end
        end
    end
    local bossNames = #bossIds > 0 and core:GetCharacterNames(bossIds) or {}

    local gangs = {}
    for _, gang in ipairs(NoirGangs.gangList()) do
        local archetype = Config.RankArchetypes[gang.archetype]
        local _, plainRanks = NoirGangs.rankCount(gang.name)
        -- Quem já lidera. A tela usa isto para oferecer o primeiro chefe só onde falta um:
        -- trocar liderança continua sendo `/setgang`, de propósito.
        local boss = NoirGangs.bossRank(gang.name)
        local roster = rosters[gang.name]
        local bossCitizenId
        for _, entry in ipairs(roster) do
            if boss and entry.grade == boss.level then bossCitizenId = entry.citizenId end
        end

        gangs[#gangs + 1] = {
            name = gang.name,
            label = gang.label,
            color = gang.color,
            colorHex = NoirGangs.gangColor(gang.name),
            archetype = gang.archetype,
            archetypeLabel = archetype and archetype.label or gang.archetype,
            members = #roster,
            ranks = plainRanks + 1,
            locations = byGang[gang.name] or {},
            products = NoirGangs.productsOf(gang.name),
            hasBossRank = boss ~= nil,
            bossName = bossCitizenId and bossNames[bossCitizenId] or nil,
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

    local productTypes = {}
    for id, product in pairs(Config.ProductTypes) do
        productTypes[#productTypes + 1] = { id = id, label = product.label or id }
    end
    table.sort(productTypes, function(a, b) return a.label < b.label end)

    return { gangs = gangs, archetypes = archetypes, colors = colors,
        products = productTypes, candidates = bossCandidates(),
        limits = { max = Config.Gang.max, nameMaxLength = Config.Gang.nameMaxLength,
            labelMaxLength = Config.Gang.labelMaxLength,
            -- A régua da cor livre vai junto para a tela avisar na hora, em vez de deixar
            -- escolher e só descobrir na recusa. Quem decide continua sendo o servidor.
            color = { minContrast = Config.CustomColor.minContrast, against = Config.CustomColor.against } } }
end

---Console e jogador recebem a mesma resposta por caminhos diferentes.
local function respondSetGang(source, message)
    if source <= 0 then return lib.print.info('[noir_gangs] ' .. message) end
    notify(source, message, 'inform')
end

RegisterCommand('gangsetup', function(source)
    if source <= 0 then return lib.print.error('[noir_gangs] /gangsetup só funciona em jogo') end
    if not admin(source) then return notify(source, 'Acesso negado.', 'error') end
    TriggerClientEvent('noir_gangs:client:openSetup', source)
end, false)

---Define ou remove a gang de um personagem, por fora da tela.
---
---Substitui o `/setgang` do `qbx_core`, que continua existindo mas escreve num lugar que
---ninguém mais lê: a membresia é deste resource desde que o Qbox deixou de ser dono dela.
---
---Aceita o ID de servidor de quem está online. Sem cargo, entra pelo cargo de entrada da
---gang -- o mais baixo que ela TEM, não um número fixo.
RegisterCommand('gangmembro', function(source, args)
    if not admin(source) then
        if source > 0 then notify(source, 'Acesso negado.', 'error') end
        return
    end
    if not ready then return respondSetGang(source, 'O noir_gangs ainda não subiu.') end

    local targetSource = tonumber(args[1])
    local gangName = args[2] and tostring(args[2]):lower() or nil
    if not targetSource then
        return respondSetGang(source, 'uso: /gangmembro <id> <gang|none> [cargo]')
    end

    local character = core:GetCharacter(targetSource)
    if not character then return respondSetGang(source, 'Jogador não encontrado em jogo.') end

    if not gangName or gangName == 'none' then
        NoirGangs.removeMember(character.citizenId)
        return respondSetGang(source, ('%s saiu de qualquer gang.'):format(character.name.full))
    end

    local info = gangInfo(gangName)
    if not info then return respondSetGang(source, ('Gang %s não existe.'):format(gangName)) end

    local level = tonumber(args[3])
    if not level then level = NoirGangs.bottomLevel(gangName) or Config.DefaultGrade end

    local ok, err = NoirGangs.setMember(character.citizenId, gangName, level)
    if not ok then return respondSetGang(source, ('Não deu: %s'):format(tostring(err))) end

    local rank = NoirGangs.rank(gangName, level)
    respondSetGang(source, ('%s agora é %s em %s.'):format(
        character.name.full, rank and rank.label or level, info.label))
end, false)

lib.callback.register('noir_gangs:server:getSetup', buildSetup)

lib.callback.register('noir_gangs:server:createGang', function(source, data)
    if not adminReady(source) then return false, ready and 'no_permission' or 'not_ready' end
    if type(data) ~= 'table' then return false, 'invalid_name' end

    -- Produtos antes de criar: recusar depois deixaria a gang em pé com a lista pela
    -- metade, e o admin sem saber qual metade.
    local products = readProducts(data.products)
    if not products then return false, 'invalid_product' end

    local name, err = NoirGangs.createGang(data.name, data.label, data.archetype, data.color)
    if not name then return false, err end

    -- Só grava quando o admin escolheu algo: lista vazia aqui é "não escolhi", e marcar a
    -- gang como semeada impediria o config de semeá-la se ela entrar lá depois.
    if #products > 0 then NoirGangs.setProducts(name, products) end

    broadcastGangs()
    local actor = core:GetCharacter(source)
    log(name, 'gang_created', actor and actor.citizenId, nil,
        { label = data.label, archetype = data.archetype, color = data.color, products = products })
    lib.print.info(('[noir_gangs] gang %s criada por %s'):format(name, GetPlayerName(source) or source))
    return true, nil, name
end)

lib.callback.register('noir_gangs:server:updateGang', function(source, data)
    if not adminReady(source) then return false, ready and 'no_permission' or 'not_ready' end
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return false, 'gang_not_found' end

    -- `nil` é tela antiga, que não manda produto nenhum: nesse caso a lista fica como
    -- está. Lista vazia é escolha, e apaga.
    local products = data.products ~= nil and readProducts(data.products) or nil
    if data.products ~= nil and not products then return false, 'invalid_product' end

    return locked(data.name, function()
        local ok, err, members = NoirGangs.updateGang(data.name, data)
        if not ok then return false, err, members end

        if products then
            local productsOk, productsErr = NoirGangs.setProducts(data.name, products)
            if not productsOk then return false, productsErr end
        end

        broadcastGangs()
        local actor = core:GetCharacter(source)
        log(data.name, 'gang_updated', actor and actor.citizenId, nil,
            { label = data.label, archetype = data.archetype, color = data.color, products = products })
        return true
    end)
end)

---O primeiro chefe, e só ele. A gang criada pela tela nasce com a escada montada e ninguém
---dentro: sem isto, o admin sai do setup, roda `/setgang` e volta. Com um chefe em pé a
---tela para de oferecer — trocar quem lidera continua sendo operação de fora, como o resto
---do resource assume em todo lugar.
lib.callback.register('noir_gangs:server:assignBoss', function(source, gangName, target)
    if not adminReady(source) then return false, ready and 'no_permission' or 'not_ready' end

    local info = gangInfo(gangName)
    if not info then return false, 'gang_not_found' end

    local targetSource = tonumber(target)
    if not targetSource or targetSource < 1 then return false, 'invalid_member' end

    return locked(gangName, function()
        local boss = NoirGangs.bossRank(gangName)
        if not boss then return false, 'no_boss' end

        for _, entry in ipairs(NoirGangs.membersOf(gangName)) do
            if entry.grade == boss.level then return false, 'boss_exists' end
        end

        local character = core:GetCharacter(targetSource)
        if not character then return false, 'invalid_member' end
        if inAnyGang(character.citizenId) then return false, 'already_in_gang' end

        if not NoirGangs.setMember(character.citizenId, gangName, boss.level) then return false, 'failed' end

        local actor = core:GetCharacter(source)
        log(gangName, 'boss_assigned', actor and actor.citizenId, character.citizenId, { grade = boss.level })
        notify(targetSource, ('Você agora lidera %s.'):format(info.label), 'success')
        return true, nil, character.name.full
    end)
end)

-- Não há mais handler de `onResourceStart` para o qbx_core aqui.
--
-- Ele existia para republicar gangs e cargos quando o provider reiniciava sozinho e
-- esquecia tudo. Como nada mais é publicado lá, não há o que republicar: um restart do
-- qbx_core não afeta gang nenhuma. Era justamente essa republicação que rebaixava os
-- membros online, então some o gatilho junto com a dependência.

-- O ponto vem da tela de setup, e a tela é do cliente: o payload pode chegar incompleto,
-- forjado, ou depois de quem pediu já ter saído. As colunas de coordenada são
-- `DOUBLE NOT NULL`, então campo faltando não vira recusa — vira erro de SQL no meio da
-- escrita, com o ponto pela metade e o log já gravado.

local COORD_LIMIT = 10000.0

---Número que dá para gravar: `nil`, texto, NaN e infinito não dão.
local function finiteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@return table|nil { x, y, z, heading } já normalizado
local function readPoint(data)
    if type(data) ~= 'table' then return nil end

    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        local value = data[axis]
        if not finiteNumber(value) or value < -COORD_LIMIT or value > COORD_LIMIT then return nil end
    end

    -- Heading ausente continua virando 0, como antes. Heading torto é recusa: virar 0 em
    -- silêncio esconderia a tela quebrada em vez de mostrá-la.
    local heading = data.heading == nil and 0 or data.heading
    if not finiteNumber(heading) then return nil end

    return { x = data.x, y = data.y, z = data.z, heading = heading % 360 }
end

---@return integer|nil
local function readPointId(value)
    local id = tonumber(value)
    if not id or id % 1 ~= 0 or id < 1 or id > 4294967295 then return nil end
    return id
end

local function refusePoint(source, callbackName)
    lib.print.warn(('[noir_gangs] %s recebeu payload inválido de %s'):format(callbackName, source))
    return false
end

---Quem pediu ainda está no servidor? Entre o pedido e a escrita há consultas, e cada uma
---cede o controle: dá tempo de o admin cair no meio. Sem esta checagem, `actor.citizenId`
---é índice de nil, e o erro estoura depois de a linha já ter sido gravada.
local function pointActor(source, callbackName)
    local actor = core:GetCharacter(source)
    if not actor then
        lib.print.warn(('[noir_gangs] %s abandonado: source %s saiu no meio'):format(callbackName, source))
    end
    return actor
end

lib.callback.register('noir_gangs:server:createLocation', function(source, gangName, data)
    if not adminReady(source) or not gangInfo(gangName) then return false end

    local point = readPoint(data)
    if not point then return refusePoint(source, 'createLocation') end

    local actor = pointActor(source, 'createLocation')
    if not actor then return false end

    local id = MySQL.insert.await('INSERT INTO noir_gang_locations (gang_name, location_type, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { gangName, 'management', point.x, point.y, point.z, point.heading, actor.citizenId })
    if not id then return false end

    log(gangName, 'management_point_created', actor.citizenId, nil, { id = id, coords = point })
    reloadLocations()
    return id
end)

lib.callback.register('noir_gangs:server:updateLocation', function(source, id, data)
    if not adminReady(source) then return false end

    local pointId, point = readPointId(id), readPoint(data)
    if not pointId or not point then return refusePoint(source, 'updateLocation') end

    local row = MySQL.single.await('SELECT gang_name FROM noir_gang_locations WHERE id = ?', { pointId })
    if not row then return false end

    -- Depois da consulta, e não antes: é ela que cede, e é aí que a saída acontece.
    local actor = pointActor(source, 'updateLocation')
    if not actor then return false end

    MySQL.update.await('UPDATE noir_gang_locations SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?',
        { point.x, point.y, point.z, point.heading, pointId })
    log(row.gang_name, 'management_point_moved', actor.citizenId, nil, { id = pointId, coords = point })
    reloadLocations()
    return true
end)

lib.callback.register('noir_gangs:server:deleteLocation', function(source, id)
    if not adminReady(source) then return false end

    local pointId = readPointId(id)
    if not pointId then return refusePoint(source, 'deleteLocation') end

    local row = MySQL.single.await('SELECT gang_name FROM noir_gang_locations WHERE id = ?', { pointId })
    if not row then return false end

    local actor = pointActor(source, 'deleteLocation')
    if not actor then return false end

    MySQL.query.await('DELETE FROM noir_gang_locations WHERE id = ?', { pointId })
    log(row.gang_name, 'management_point_deleted', actor.citizenId, nil, { id = pointId })
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

---Estado do bootstrap em jogo. O erro do start some do console, e "o menu não abre" é o
---mesmo sintoma de bug, de permissão e de bootstrap falhado — este comando separa os três
---sem precisar de acesso ao servidor.
RegisterCommand('gangstatus', function(source)
    local list = NoirGangs.gangList()
    local report = ready
        and ('[noir_gangs] no ar: %d gangs, %d pontos de gestão'):format(#list, #locations)
        or '[noir_gangs] BOOTSTRAP FALHOU: o registro está vazio e todo callback recusa. Veja o console do start.'

    if source > 0 then
        if not admin(source) then return notify(source, 'Acesso negado.', 'error') end
        return notify(source, report, ready and 'success' or 'error')
    end
    lib.print.info(report)
end, false)

---Outros resources perguntam antes de confiar no que vem daqui: com o bootstrap falhado,
---`GetGangProducts` e companhia devolvem vazio, que é indistinguível de "não tem".
exports('IsReady', function() return ready end)

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
exports('GetGangMembers', function(gang) return NoirGangs.membersOf(gang) end)

---Gang de um personagem por citizenid, inclusive offline. É o que o bridge consome para
---responder `GetCharacterGangs` sem voltar ao Qbox.
exports('GetCitizenGang', function(citizenId) return NoirGangs.gangOfCitizen(citizenId) end)

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
