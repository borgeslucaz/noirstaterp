-- Autoridade do XP. O cliente nunca manda ganho de XP: quem concede é outro resource do
-- servidor, pelos exports daqui. O cliente só recebe o estado para desenhar e responder
-- export local sem ida ao servidor.
local Xp = NoirSkills.xp
local Store = NoirSkills.store
local core = exports.bgrz_core

-- [source] = { citizenid = string, xp = { [habilidade] = xp bruto } }
local players = {}

-- Só depois de config validado e schema no lugar. Sem isto, um config quebrado deixaria o
-- resource meio de pé: carregando personagem, respondendo export e gravando XP com curva
-- inválida — o pior dos dois mundos, porque ninguém vê o erro até o dano estar no banco.
local booted = false

-- ---------------------------------------------------------------------------
-- Validação
-- ---------------------------------------------------------------------------
-- O aviso nomeia o resource que chamou: export com habilidade errada não estoura, ele só
-- devolve zero para sempre, e sem o nome de quem chamou ninguém acha o culpado.
local function warnCaller(fn, message)
    lib.print.warn(('[noir_skills] %s (chamado por %s): %s')
        :format(fn, GetInvokingResource() or 'noir_skills', message))
end

---@return table|nil player
local function getPlayer(fn, source)
    local player = players[source]
    if not player then
        warnCaller(fn, ('personagem %s não está carregado'):format(tostring(source)))
    end
    return player
end

local function checkSkill(fn, skill)
    if not Xp.exists(skill) then
        warnCaller(fn, ('habilidade desconhecida: %s'):format(tostring(skill)))
        return false
    end
    return true
end

local function checkAmount(fn, amount)
    if type(amount) ~= 'number' or amount ~= amount or amount <= 0 then
        warnCaller(fn, ('quantidade de XP inválida: %s'):format(tostring(amount)))
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Estado
-- ---------------------------------------------------------------------------
local function snapshot(player)
    local xp = {}
    for _, skill in ipairs(Xp.list()) do
        xp[skill] = player.xp[skill] or 0
    end
    return xp
end

local function loadPlayer(source)
    if not booted then return end

    local citizenid = core:GetCitizenId(source)
    if not citizenid then return end

    players[source] = { citizenid = citizenid, xp = Store.load(citizenid) }
    TriggerClientEvent('noir_skills:client:sync', source, snapshot(players[source]))
end

---Escrita central: grava, atualiza o cache, avisa o cliente e reemite o que mudou.
---@return boolean changed
local function writeXp(source, skill, value)
    local player = players[source]
    if not player then return false end

    value = math.floor(math.max(0, math.min(value, Xp.maxXp(skill))))

    local previousXp = player.xp[skill] or 0
    if value == previousXp then return false end

    local previousLevel = Xp.levelFor(skill, previousXp)
    local level = Xp.levelFor(skill, value)

    player.xp[skill] = value
    Store.save(player.citizenid, skill, value)

    TriggerClientEvent('noir_skills:client:update', source, skill, value, level > previousLevel)
    TriggerEvent('noir_skills:server:xpChanged', source, skill, value, previousXp)

    if level ~= previousLevel then
        TriggerEvent('noir_skills:server:levelChanged', source, skill, level, previousLevel)
    end

    return true
end

-- ---------------------------------------------------------------------------
-- API pública
-- ---------------------------------------------------------------------------

---XP bruto acumulado na habilidade.
---@param source number
---@param skill string
---@return number
local function GetXp(source, skill)
    if not checkSkill('GetXp', skill) then return 0 end
    local player = players[source]
    return player and player.xp[skill] or 0
end

---@param source number
---@param skill string
---@return number
local function GetLevel(source, skill)
    if not checkSkill('GetLevel', skill) then return 0 end
    return Xp.levelFor(skill, GetXp(source, skill))
end

---Atalho para portão de conteúdo: `if not exports.noir_skills:HasLevel(src, 'tiro', 5) then ...`
---@param source number
---@param skill string
---@param level number
---@return boolean
local function HasLevel(source, skill, level)
    if not checkSkill('HasLevel', skill) then return false end
    if type(level) ~= 'number' then
        warnCaller('HasLevel', ('nível inválido: %s'):format(tostring(level)))
        return false
    end
    return GetLevel(source, skill) >= level
end

---Estado completo, já com nível e progresso calculados.
---@param source number
---@return table<string, { level: number, maxLevel: number, xp: number, need: number|nil, totalXp: number, ratio: number }>
local function GetAll(source)
    local player = players[source]
    local all = {}
    if not player then return all end

    for _, skill in ipairs(Xp.list()) do
        all[skill] = Xp.progress(skill, player.xp[skill] or 0)
    end
    return all
end

---@param source number
---@param skill string
---@param amount number
---@return boolean
local function AddXp(source, skill, amount)
    if not checkSkill('AddXp', skill) then return false end
    if not checkAmount('AddXp', amount) then return false end
    local player = getPlayer('AddXp', source)
    if not player then return false end

    return writeXp(source, skill, (player.xp[skill] or 0) + amount)
end

---@param source number
---@param skill string
---@param amount number
---@return boolean
local function RemoveXp(source, skill, amount)
    if not checkSkill('RemoveXp', skill) then return false end
    if not checkAmount('RemoveXp', amount) then return false end
    local player = getPlayer('RemoveXp', source)
    if not player then return false end

    return writeXp(source, skill, (player.xp[skill] or 0) - amount)
end

---Coloca a habilidade no piso de XP do nível pedido — o progresso dentro do nível zera.
---@param source number
---@param skill string
---@param level number
---@return boolean
local function SetLevel(source, skill, level)
    if not checkSkill('SetLevel', skill) then return false end
    if type(level) ~= 'number' or level < 1 or level > Xp.maxLevel(skill) or level % 1 ~= 0 then
        warnCaller('SetLevel', ('nível fora da faixa de %s: %s'):format(skill, tostring(level)))
        return false
    end
    if not getPlayer('SetLevel', source) then return false end

    return writeXp(source, skill, Xp.totalForLevel(skill, level))
end

---@param source number
---@param skill string
---@return boolean
local function ResetSkill(source, skill)
    if not checkSkill('ResetSkill', skill) then return false end
    if not getPlayer('ResetSkill', source) then return false end

    return writeXp(source, skill, 0)
end

exports('GetXp', GetXp)
exports('GetLevel', GetLevel)
exports('HasLevel', HasLevel)
exports('GetAll', GetAll)
exports('AddXp', AddXp)
exports('RemoveXp', RemoveXp)
exports('SetLevel', SetLevel)
exports('ResetSkill', ResetSkill)

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------
AddEventHandler('bgrz_core:server:playerLoaded', function(source)
    if type(source) == 'number' then loadPlayer(source) end
end)

-- Sem isto o cache cresce a cada reconexão e nunca encolhe.
AddEventHandler('bgrz_core:server:playerUnloaded', function(source)
    if type(source) == 'number' then players[source] = nil end
end)

AddEventHandler('playerDropped', function()
    players[source] = nil
end)

-- Só o cliente pede, e só o estado dele: cobre restart do resource com gente logada e o
-- caso do cliente que carrega antes do servidor terminar o boot.
lib.callback.register('noir_skills:server:sync', function(source)
    local player = players[source]
    if not player then return {} end
    return snapshot(player)
end)

MySQL.ready(function()
    if #Xp.configErrors > 0 then
        for i = 1, #Xp.configErrors do
            lib.print.error(('[noir_skills] config: %s'):format(Xp.configErrors[i]))
        end
        error('config de habilidade inválido; o noir_skills não vai carregar ninguém')
    end

    if not Store.runSchema() then
        error('schema do noir_skills não subiu; o resource não vai carregar ninguém')
    end

    booted = true

    -- Restart com o servidor de pé: quem já está logado não dispara playerLoaded de novo.
    local online = GetPlayers()
    for i = 1, #online do
        loadPlayer(tonumber(online[i]) --[[@as number]])
    end
end)

-- ---------------------------------------------------------------------------
-- Comandos de admin
-- ---------------------------------------------------------------------------
local function notifyAdmin(source, message, kind)
    core:Notify(source, message, kind or 'inform')
end

---Nome de habilidade digitado por humano: aceita com e sem acento, em qualquer caixa.
---@param input string
---@return string|nil
local function resolveSkill(input)
    if type(input) ~= 'string' then return nil end
    if Xp.exists(input) then return input end

    local wanted = input:lower()
    for _, skill in ipairs(Xp.list()) do
        if skill:lower() == wanted or Config.Skills[skill].label:lower() == wanted then
            return skill
        end
    end
    return nil
end

local skillList = function() return table.concat(Xp.list(), ', ') end

lib.addCommand('addskillxp', {
    help = 'Dá (ou tira, com valor negativo) XP de uma habilidade',
    restricted = Config.AdminAce,
    params = {
        { name = 'target', type = 'playerId', help = 'ID do jogador' },
        { name = 'skill', type = 'string', help = 'Habilidade' },
        { name = 'amount', type = 'number', help = 'XP (negativo remove)' },
    },
}, function(source, args)
    local skill = resolveSkill(args.skill)
    if not skill then
        return notifyAdmin(source, ('Habilidade inválida. Disponíveis: %s'):format(skillList()), 'error')
    end
    if not players[args.target] then
        return notifyAdmin(source, ('O jogador %d não está carregado.'):format(args.target), 'error')
    end
    if args.amount == 0 then
        return notifyAdmin(source, 'A quantidade de XP não pode ser zero.', 'error')
    end

    local ok = args.amount > 0 and AddXp(args.target, skill, args.amount)
        or RemoveXp(args.target, skill, -args.amount)

    notifyAdmin(source, ok
        and ('%s: %+d XP em %s (nível %d).'):format(GetPlayerName(args.target), args.amount,
            Config.Skills[skill].label, GetLevel(args.target, skill))
        or ('Nada mudou: %s já está no limite dessa habilidade.'):format(GetPlayerName(args.target)),
        ok and 'success' or 'inform')
end)

lib.addCommand('setskilllevel', {
    help = 'Define o nível de uma habilidade (o progresso dentro do nível zera)',
    restricted = Config.AdminAce,
    params = {
        { name = 'target', type = 'playerId', help = 'ID do jogador' },
        { name = 'skill', type = 'string', help = 'Habilidade' },
        { name = 'level', type = 'number', help = 'Nível' },
    },
}, function(source, args)
    local skill = resolveSkill(args.skill)
    if not skill then
        return notifyAdmin(source, ('Habilidade inválida. Disponíveis: %s'):format(skillList()), 'error')
    end
    if not players[args.target] then
        return notifyAdmin(source, ('O jogador %d não está carregado.'):format(args.target), 'error')
    end
    if args.level < 1 or args.level > Xp.maxLevel(skill) or args.level % 1 ~= 0 then
        return notifyAdmin(source, ('Nível precisa ser inteiro entre 1 e %d.'):format(Xp.maxLevel(skill)), 'error')
    end

    SetLevel(args.target, skill, args.level)
    notifyAdmin(source, ('%s: %s no nível %d.'):format(GetPlayerName(args.target),
        Config.Skills[skill].label, args.level), 'success')
end)

lib.addCommand('resetskill', {
    help = 'Zera uma habilidade do jogador',
    restricted = Config.AdminAce,
    params = {
        { name = 'target', type = 'playerId', help = 'ID do jogador' },
        { name = 'skill', type = 'string', help = 'Habilidade' },
    },
}, function(source, args)
    local skill = resolveSkill(args.skill)
    if not skill then
        return notifyAdmin(source, ('Habilidade inválida. Disponíveis: %s'):format(skillList()), 'error')
    end
    if not players[args.target] then
        return notifyAdmin(source, ('O jogador %d não está carregado.'):format(args.target), 'error')
    end

    ResetSkill(args.target, skill)
    notifyAdmin(source, ('%s: %s zerada.'):format(GetPlayerName(args.target),
        Config.Skills[skill].label), 'success')
end)

-- Conferir a curva antes de publicar: imprime o custo de cada nível e o total no console
-- do servidor. Curva ruim só aparece meses depois, quando ninguém passa do nível 12.
lib.addCommand('skillcurve', {
    help = 'Imprime a curva de XP de uma habilidade no console do servidor',
    restricted = Config.AdminAce,
    params = {
        { name = 'skill', type = 'string', help = 'Habilidade' },
    },
}, function(source, args)
    local skill = resolveSkill(args.skill)
    if not skill then
        return notifyAdmin(source, ('Habilidade inválida. Disponíveis: %s'):format(skillList()), 'error')
    end

    local lines = { ('[noir_skills] curva de %s'):format(Config.Skills[skill].label) }
    for level = 2, Xp.maxLevel(skill) do
        lines[#lines + 1] = ('  nível %2d: +%d XP (total %d)'):format(level,
            Xp.totalForLevel(skill, level) - Xp.totalForLevel(skill, level - 1),
            Xp.totalForLevel(skill, level))
    end
    print(table.concat(lines, '\n'))
    notifyAdmin(source, ('Curva de %s impressa no console (total %d XP).')
        :format(Config.Skills[skill].label, Xp.maxXp(skill)), 'success')
end)
