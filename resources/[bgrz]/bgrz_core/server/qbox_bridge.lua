-- Bridge server-side para o Qbox.
BGRZ = BGRZ or {}

---@param source number
---@return table|nil job { name, label, grade, onDuty }
function BGRZ.GetJob(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    local job = player.PlayerData.job or {}
    return {
        name = job.name,
        label = job.label,
        grade = job.grade and job.grade.level or 0,
        onDuty = job.onduty == true,
    }
end

---@param source number
---@param jobName string
---@param requireDuty? boolean
---@return boolean
function BGRZ.HasJob(source, jobName, requireDuty)
    local job = BGRZ.GetJob(source)
    if not job or job.name ~= jobName then return false end
    if requireDuty and not job.onDuty then return false end
    return true
end

---@param source number
---@param account 'cash'|'bank'
---@param amount number
---@param reason? string
---@return boolean
function BGRZ.AddMoney(source, account, amount, reason)
    if type(amount) ~= 'number' or amount <= 0 then return false end
    return exports.qbx_core:AddMoney(source, account or 'cash', amount, reason or 'bgrz_core') == true
end

---@param source number
---@param account 'cash'|'bank'
---@param amount number
---@param reason? string
---@return boolean
function BGRZ.RemoveMoney(source, account, amount, reason)
    if type(amount) ~= 'number' or amount <= 0 then return false end
    return exports.qbx_core:RemoveMoney(source, account or 'cash', amount, reason or 'bgrz_core') == true
end

---@param source number
---@param key string
function BGRZ.GetMetadata(source, key)
    return exports.qbx_core:GetMetadata(source, key)
end

---@param source number
---@param key string
---@param value any
function BGRZ.SetMetadata(source, key, value)
    exports.qbx_core:SetMetadata(source, key, value)
end

---Reputação de emprego (PlayerData.metadata.jobrep[job]).
---@param source number
---@param jobName string
---@return number
function BGRZ.GetJobReputation(source, jobName)
    local rep = BGRZ.GetMetadata(source, 'jobrep')
    if type(rep) ~= 'table' then return 0 end
    return tonumber(rep[jobName]) or 0
end

---@param source number
---@param jobName string
---@param delta number
---@return number newValue
function BGRZ.AddJobReputation(source, jobName, delta)
    local rep = BGRZ.GetMetadata(source, 'jobrep')
    if type(rep) ~= 'table' then rep = {} end
    local newValue = math.max(0, (tonumber(rep[jobName]) or 0) + (tonumber(delta) or 0))
    rep[jobName] = newValue
    BGRZ.SetMetadata(source, 'jobrep', rep)
    return newValue
end

---Conta jogadores em serviço em um job, sem expor a estrutura de players do provider.
---@param jobName string
---@return integer? count
---@return string? errorCode
function BGRZ.CountOnDutyJob(jobName)
    if type(jobName) ~= 'string' or #jobName == 0 or #jobName > 32
        or not jobName:match('^[%w_-]+$') then
        return nil, 'invalid_job'
    end
    if not BGRZ.Provider.isStarted('qbx_core') then return nil, 'provider_unavailable' end
    local called, count = pcall(function()
        return exports.qbx_core:GetDutyCountJob(jobName)
    end)
    if not called then return nil, 'provider_unavailable' end
    if type(count) ~= 'number' or count ~= count or count < 0 then return nil, 'operation_failed' end
    return math.floor(count)
end

function BGRZ.Notify(source, message, ntype, duration)
    exports.qbx_core:Notify(source, message, ntype or 'inform', duration)
end

---Cria um veículo no servidor (OneSync) e entrega as chaves ao jogador.
---@param source number
---@param model string|number
---@param coords vector3|vector4
---@param warp? boolean coloca o jogador no banco do motorista
---@param plate? string
---@return number|nil netId
---@return number|nil vehicle
function BGRZ.SpawnVehicle(source, model, coords, warp, plate)
    if type(source) ~= 'number' or source <= 0 then return nil end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end

    local ok, netId, veh = pcall(qbx.spawnVehicle, {
        model = model,
        spawnSource = coords,
        warp = warp and ped or nil,
    })
    if not ok or not netId or netId == 0 or not veh or veh == 0 then
        print(('[bgrz_core] SpawnVehicle falhou: %s'):format(tostring(netId)))
        return nil
    end
    if not DoesEntityExist(veh) then
        print(('[bgrz_core] SpawnVehicle não resolveu a entidade: %s'):format(tostring(netId)))
        return nil
    end

    if plate then
        SetVehicleNumberPlateText(veh, plate)
    end
    BGRZ.GiveVehicleKeys(source, veh)
    return netId, veh
end

exports('GetJob', BGRZ.GetJob)
exports('HasJob', BGRZ.HasJob)
exports('AddMoney', BGRZ.AddMoney)
exports('RemoveMoney', BGRZ.RemoveMoney)
exports('GetMetadata', BGRZ.GetMetadata)
exports('SetMetadata', BGRZ.SetMetadata)
exports('GetJobReputation', BGRZ.GetJobReputation)
exports('AddJobReputation', BGRZ.AddJobReputation)
exports('Notify', BGRZ.Notify)
exports('CountOnDutyJob', BGRZ.CountOnDutyJob)
exports('SpawnVehicle', BGRZ.SpawnVehicle)

-- Re-emite eventos server-side do Qbox com nomes próprios.
AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    TriggerEvent('bgrz_core:server:jobUpdated', source, BGRZ.GetJob(source) or {
        name = job and job.name, onDuty = job and job.onduty == true,
    })
end)

---Gang atual normalizada a partir do personagem carregado.
---@param source number
---@return table|nil gang { name, label, grade, gradeName, isBoss }
function BGRZ.GetGang(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    local gang = player.PlayerData.gang or {}
    return {
        name = gang.name,
        label = gang.label,
        grade = gang.grade and gang.grade.level or 0,
        gradeName = gang.grade and gang.grade.name,
        isBoss = gang.isboss == true,
    }
end

exports('GetGang', BGRZ.GetGang)

local lastGang = {}

local function gangSignature(gang)
    if not gang then return nil end
    return ('%s:%s'):format(gang.name or '', gang.grade or 0)
end

local function emitGangUpdate(source)
    if type(source) ~= 'number' then return end
    local gang = BGRZ.GetGang(source)
    lastGang[source] = gangSignature(gang)
    TriggerEvent('bgrz_core:server:gangUpdated', source, gang or {})
end

AddEventHandler('QBCore:Server:OnGangUpdate', function(source)
    emitGangUpdate(source)
end)

-- `onGroupUpdate` cobre entrar e sair de job ou gang, casos em que o Qbox não dispara
-- OnGangUpdate. Só reemitimos quando a gang realmente mudou.
AddEventHandler('qbx_core:server:onGroupUpdate', function(source)
    if type(source) ~= 'number' then return end
    if gangSignature(BGRZ.GetGang(source)) ~= lastGang[source] then emitGangUpdate(source) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if type(src) == 'number' then lastGang[src] = nil end
end)

AddEventHandler('QBCore:Server:SetDuty', function(source, onDuty)
    TriggerEvent('bgrz_core:server:dutyUpdated', source, onDuty == true)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    if type(source) == 'number' then lastGang[source] = nil end
    TriggerEvent('bgrz_core:server:playerUnloaded', source)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    if type(src) == 'number' then lastGang[src] = gangSignature(BGRZ.GetGang(src)) end
    TriggerEvent('bgrz_core:server:playerLoaded', src)
end)

-- ---------------------------------------------------------------------------
-- Gestão de gang
-- ---------------------------------------------------------------------------
-- O provider guarda grades em config estática e membros em tabela própria. Estes
-- helpers normalizam as duas coisas para que os resources não precisem conhecer
-- nem `shared/gangs.lua` nem a tabela `player_groups`.

---Definição estática de uma gang.
---@param gangName string
---@return table|nil info { name, label, grades = table<integer, { name, isBoss }>, topGrade }
function BGRZ.GetGangInfo(gangName)
    if type(gangName) ~= 'string' or gangName == '' or gangName == 'none' then return nil end
    local gang = exports.qbx_core:GetGang(gangName)
    if not gang then return nil end

    local grades, topGrade = {}, 0
    for rawLevel, grade in pairs(gang.grades or {}) do
        local level = tonumber(rawLevel)
        if level then
            grades[level] = { name = grade.name, isBoss = grade.isboss == true }
            if level > topGrade then topGrade = level end
        end
    end

    return { name = gangName, label = gang.label or gangName, grades = grades, topGrade = topGrade }
end

---Todas as gangs configuradas, já ordenadas e sem a gang vazia.
---@return { name: string, label: string }[]
function BGRZ.GetGangList()
    local list = {}
    for name, gang in pairs(exports.qbx_core:GetGangs() or {}) do
        if name ~= 'none' then
            list[#list + 1] = { name = name, label = gang.label or name }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

---Membros persistidos de uma gang, incluindo quem está offline.
---@param gangName string
---@return { citizenId: string, grade: integer }[]
function BGRZ.GetGangMembers(gangName)
    if type(gangName) ~= 'string' or gangName == '' then return {} end
    local rows = exports.qbx_core:GetGroupMembers(gangName, 'gang') or {}
    local members = {}
    for i = 1, #rows do
        members[i] = { citizenId = rows[i].citizenid, grade = tonumber(rows[i].grade) or 0 }
    end
    return members
end

---Gangs em que o personagem está, mesmo offline.
---@param citizenId string
---@return table<string, integer> gangName -> grade
function BGRZ.GetCharacterGangs(citizenId)
    if type(citizenId) ~= 'string' or citizenId == '' then return {} end
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenId)
        or exports.qbx_core:GetOfflinePlayer(citizenId)
    if not player or not player.PlayerData then return {} end

    local gangs = {}
    for name, grade in pairs(player.PlayerData.gangs or {}) do
        gangs[name] = tonumber(grade) or 0
    end
    return gangs
end

---@param citizenId string
---@return number|nil source nil quando o personagem não está online
function BGRZ.GetCharacterSource(citizenId)
    if type(citizenId) ~= 'string' or citizenId == '' then return nil end
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenId)
    return player and player.PlayerData.source or nil
end

---Nomes de personagem em lote. Quem está online sai da memória; o resto sai de uma
---query só. Resolver um a um custava um carregamento completo de personagem por
---membro offline, o que ficava caro em listas grandes.
---@param citizenIds string[]
---@return table<string, string> citizenId -> nome completo
function BGRZ.GetCharacterNames(citizenIds)
    if type(citizenIds) ~= 'table' then return {} end

    local names, pending = {}, {}
    for i = 1, #citizenIds do
        local citizenId = citizenIds[i]
        if type(citizenId) == 'string' and citizenId ~= '' and not names[citizenId] then
            local player = exports.qbx_core:GetPlayerByCitizenId(citizenId)
            if player then
                local info = player.PlayerData.charinfo or {}
                names[citizenId] = ('%s %s'):format(info.firstname or '', info.lastname or '')
            else
                pending[#pending + 1] = citizenId
            end
        end
    end

    if #pending > 0 then
        local rows = MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)',
            { pending }) or {}
        for i = 1, #rows do
            local ok, info = pcall(json.decode, rows[i].charinfo)
            if ok and type(info) == 'table' then
                names[rows[i].citizenid] = ('%s %s'):format(info.firstname or '', info.lastname or '')
            end
        end
    end

    return names
end

---Define o cargo do personagem na gang (entrando nela se preciso) e a torna primária.
---@param citizenId string
---@param gangName string
---@param grade integer
---@return boolean ok
---@return string? errorCode
function BGRZ.SetGangGrade(citizenId, gangName, grade)
    if type(citizenId) ~= 'string' or citizenId == '' then return false, 'invalid_character' end
    if type(gangName) ~= 'string' or gangName == '' or gangName == 'none' then return false, 'invalid_gang' end

    grade = tonumber(grade)
    if not grade or grade < 0 then return false, 'invalid_grade' end

    local info = BGRZ.GetGangInfo(gangName)
    if not info then return false, 'gang_not_found' end
    if not info.grades[grade] then return false, 'invalid_grade' end

    if not exports.qbx_core:AddPlayerToGang(citizenId, gangName, grade) then
        return false, 'operation_failed'
    end
    if not exports.qbx_core:SetPlayerPrimaryGang(citizenId, gangName) then
        return false, 'operation_failed'
    end
    return true
end

---@param citizenId string
---@param gangName string
---@return boolean ok
---@return string? errorCode
function BGRZ.RemoveFromGang(citizenId, gangName)
    if type(citizenId) ~= 'string' or citizenId == '' then return false, 'invalid_character' end
    if type(gangName) ~= 'string' or gangName == '' or gangName == 'none' then return false, 'invalid_gang' end
    if not exports.qbx_core:RemovePlayerFromGang(citizenId, gangName) then
        return false, 'operation_failed'
    end
    return true
end

---Publica um cargo no provider. O rótulo precisa existir lá porque é de
---`PlayerData.gang.grade.name` que o resto do servidor lê o nome do cargo, e porque
---`AddPlayerToGang` recusa nível que a gang não tenha. Permissões não entram: o provider
---não tem conceito delas, elas ficam com quem chamou.
---@param gangName string
---@param level integer
---@param data table { label, isBoss?, bankAuth? }
---@return boolean ok
---@return string? errorCode
function BGRZ.UpsertGangGrade(gangName, level, data)
    if type(gangName) ~= 'string' or gangName == '' or gangName == 'none' then return false, 'invalid_gang' end
    level = tonumber(level)
    if not level or level < 0 or level % 1 ~= 0 then return false, 'invalid_grade' end
    if type(data) ~= 'table' or type(data.label) ~= 'string' or data.label == '' then return false, 'invalid_label' end
    if not exports.qbx_core:GetGang(gangName) then return false, 'gang_not_found' end

    -- `commitToFile` fica falso de propósito: gravar em shared/gangs.lua atropelaria
    -- edições feitas à mão lá. Quem chamou é dono dos cargos e republica a cada start.
    exports.qbx_core:UpsertGangGrade(gangName, level, {
        name = data.label,
        isboss = data.isBoss == true,
        bankAuth = data.bankAuth == true,
    }, false)
    return true
end

exports('GetGangInfo', BGRZ.GetGangInfo)
exports('UpsertGangGrade', BGRZ.UpsertGangGrade)
exports('GetGangList', BGRZ.GetGangList)
exports('GetGangMembers', BGRZ.GetGangMembers)
exports('GetCharacterGangs', BGRZ.GetCharacterGangs)
exports('GetCharacterSource', BGRZ.GetCharacterSource)
exports('GetCharacterNames', BGRZ.GetCharacterNames)
exports('SetGangGrade', BGRZ.SetGangGrade)
exports('RemoveFromGang', BGRZ.RemoveFromGang)
