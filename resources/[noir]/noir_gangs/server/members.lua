-- Membresia de gang.
--
-- A partir daqui o dono do dado é este resource, e não o Qbox.
--
-- Por que saiu de lá: o Qbox guardava a mesma informação em dois lugares --
-- `player_groups.grade` e o JSON `players.gang` -- e conseguia atualizar um sem o outro.
-- Toda vez que uma gang era republicada (`CreateGangs`), ele avisava os jogadores online,
-- cada um procurava o próprio nível na escada nova e, se a escada chegasse vazia por um
-- instante, era rebaixado para 0 com `isboss` e `bankAuth` desligados. Os cargos voltavam
-- logo depois; o nível do jogador, não. E o login relê justamente a coluna corrompida,
-- então não havia conserto por relog.
--
-- Aqui existe uma linha por personagem e ninguém mais escreve nela.
--
-- O que CONTINUA vindo do Qbox pelo bridge é identidade -- citizenid, nome, source. Isso
-- não é gang, é "quem é esta pessoa", e não faz sentido duplicar.

NoirGangs = NoirGangs or {}

local core = exports.bgrz_core

---@type table<string, { citizenId: string, gang: string, level: integer }>
local members = {}
---@type table<string, table<string, integer>> gangName -> citizenId -> level
local byGang = {}

--------------------------------------------------------------------------------
-- Cache
--------------------------------------------------------------------------------

local function index(citizenId, gangName, level)
    members[citizenId] = { citizenId = citizenId, gang = gangName, level = level }
    byGang[gangName] = byGang[gangName] or {}
    byGang[gangName][citizenId] = level
end

local function unindex(citizenId)
    local entry = members[citizenId]
    if not entry then return end
    if byGang[entry.gang] then byGang[entry.gang][citizenId] = nil end
    members[citizenId] = nil
end

function NoirGangs.loadMembers()
    members, byGang = {}, {}
    for _, row in ipairs(MySQL.query.await('SELECT citizenid, gang_name, level FROM noir_gang_members') or {}) do
        index(row.citizenid, row.gang_name, tonumber(row.level) or 0)
    end
end

--------------------------------------------------------------------------------
-- Leitura
--------------------------------------------------------------------------------

---Gang de um personagem, já normalizada com o que vem do cargo.
---
---É o substituto de `PlayerData.gang`. Devolve o mesmo formato que o bridge devolvia, para
---que quem consome não precise saber que a fonte mudou.
---@param citizenId string
---@return table|nil gang { name, label, grade, gradeName, isBoss, bankAuth }
function NoirGangs.gangOfCitizen(citizenId)
    local entry = citizenId and members[citizenId]
    if not entry then return nil end

    local info = NoirGangs.gangInfo(entry.gang)
    if not info then return nil end

    -- Cargo ausente não vira nível 0 em silêncio -- foi exatamente assim que o Qbox
    -- rebaixava gente. Aqui o nível é preservado e só o rótulo degrada, para o problema
    -- ficar visível em vez de virar perda de cargo.
    local rank = NoirGangs.rank(entry.gang, entry.level)
    return {
        name = entry.gang,
        label = info.label,
        grade = entry.level,
        gradeName = rank and rank.label or ('cargo %d'):format(entry.level),
        isBoss = rank ~= nil and rank.isBoss == true,
        bankAuth = rank ~= nil and rank.bankAuth == true,
    }
end

---@param source number
---@return table|nil gang
function NoirGangs.gangOfSource(source)
    -- `GetCitizenId` e não `GetCharacter` de propósito: o bridge preenche a gang do
    -- personagem perguntando A ESTE resource, e `GetCharacter` aqui fecharia o ciclo --
    -- gang -> personagem -> gang. `GetCitizenId` é leitura crua do Qbox e não volta.
    local citizenId = source and core:GetCitizenId(source)
    return citizenId and NoirGangs.gangOfCitizen(citizenId) or nil
end

---@param citizenId string
---@return boolean
function NoirGangs.hasAnyGang(citizenId)
    return members[citizenId] ~= nil
end

---Membros de uma gang, no formato que o resto do resource já esperava do bridge.
---@param gangName string
---@return { citizenId: string, grade: integer }[]
function NoirGangs.membersOf(gangName)
    local list = {}
    for citizenId, level in pairs(byGang[gangName] or {}) do
        list[#list + 1] = { citizenId = citizenId, grade = level }
    end
    table.sort(list, function(a, b) return a.citizenId < b.citizenId end)
    return list
end

---@param gangName string
---@param level integer
---@return integer
function NoirGangs.countAtLevel(gangName, level)
    local total = 0
    for _, memberLevel in pairs(byGang[gangName] or {}) do
        if memberLevel == level then total = total + 1 end
    end
    return total
end

--------------------------------------------------------------------------------
-- Publicação para o client
--------------------------------------------------------------------------------

---A gang vai para o state bag do jogador.
---
---É o que substitui `QBX.PlayerData.gang` no client. State bag em vez de callback porque
---a tela e o target consultam isso o tempo todo, e replicado porque quem lê é o próprio
---dono -- a autoridade continua sendo o servidor, que é quem escreve.
---@param source number|nil
---@param citizenId string
local function publish(source, citizenId)
    if not source then return end
    local player = Player(source)
    if not player or not player.state then return end

    local gang = NoirGangs.gangOfCitizen(citizenId)
    player.state:set('noirGang', gang or false, true)
    TriggerClientEvent('noir_gangs:client:gangChanged', source, gang or false)
end

---@param citizenId string
function NoirGangs.publishFor(citizenId)
    publish(core:GetCharacterSource(citizenId), citizenId)
end

---@param source number
function NoirGangs.publishSource(source)
    local character = source and core:GetCharacter(source)
    if character then publish(source, character.citizenId) end
end

--------------------------------------------------------------------------------
-- Escrita
--------------------------------------------------------------------------------

---Entra na gang, ou muda de cargo dentro dela.
---
---Uma gang por personagem: a chave primária garante, e trocar de gang é sair e entrar.
---@param citizenId string
---@param gangName string
---@param level integer
---@return boolean ok
---@return string? errorCode
function NoirGangs.setMember(citizenId, gangName, level)
    if type(citizenId) ~= 'string' or citizenId == '' then return false, 'invalid_character' end
    if type(gangName) ~= 'string' or gangName == '' then return false, 'invalid_gang' end
    if not NoirGangs.gangInfo(gangName) then return false, 'gang_not_found' end

    level = tonumber(level)
    if not level or level < 0 or level % 1 ~= 0 then return false, 'invalid_grade' end
    if not NoirGangs.rank(gangName, level) then return false, 'invalid_grade' end

    local ok, err = pcall(MySQL.query.await,
        'INSERT INTO noir_gang_members (citizenid, gang_name, level) VALUES (?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE gang_name = VALUES(gang_name), level = VALUES(level)',
        { citizenId, gangName, level })
    if not ok then
        lib.print.error(('[noir_gangs] membresia não gravada para %s: %s'):format(citizenId, tostring(err)))
        return false, 'storage_failed'
    end

    unindex(citizenId)
    index(citizenId, gangName, level)
    NoirGangs.publishFor(citizenId)
    return true
end

---@param citizenId string
---@return boolean ok
---@return string? errorCode
function NoirGangs.removeMember(citizenId)
    if type(citizenId) ~= 'string' or citizenId == '' then return false, 'invalid_character' end
    if not members[citizenId] then return true end

    local ok, err = pcall(MySQL.query.await,
        'DELETE FROM noir_gang_members WHERE citizenid = ?', { citizenId })
    if not ok then
        lib.print.error(('[noir_gangs] membresia não removida para %s: %s'):format(citizenId, tostring(err)))
        return false, 'storage_failed'
    end

    unindex(citizenId)
    NoirGangs.publishFor(citizenId)
    return true
end

---Apaga a membresia de uma gang inteira. Usado quando a gang deixa de existir.
---@param gangName string
function NoirGangs.clearGangMembers(gangName)
    local affected = {}
    for citizenId in pairs(byGang[gangName] or {}) do affected[#affected + 1] = citizenId end
    if #affected == 0 then return end

    MySQL.query.await('DELETE FROM noir_gang_members WHERE gang_name = ?', { gangName })
    for i = 1, #affected do
        unindex(affected[i])
        NoirGangs.publishFor(affected[i])
    end
end

---Republica a gang de quem acabou de entrar. O state bag nasce vazio a cada conexão.
AddEventHandler('bgrz_core:server:playerLoaded', function(source)
    NoirGangs.publishSource(source)
end)
