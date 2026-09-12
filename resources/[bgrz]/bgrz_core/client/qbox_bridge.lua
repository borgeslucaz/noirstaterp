-- Bridge client-side para o Qbox.
-- Resources BGRZ usam estes exports/eventos em vez de falar com o qbx_core diretamente.
BGRZ = BGRZ or {}

---Gang atual normalizada. `name` pode vir como 'none'; quem consome decide o que fazer.
---@return table|nil gang { name, label, grade, gradeName, isBoss }
local function currentGang()
    local gang = QBX and QBX.PlayerData and QBX.PlayerData.gang or nil
    if not gang then return nil end
    return {
        name = gang.name,
        label = gang.label,
        grade = gang.grade and gang.grade.level or 0,
        gradeName = gang.grade and gang.grade.name,
        isBoss = gang.isboss == true,
    }
end

local function currentJob()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job or nil
    if not job then return nil end
    return {
        name = job.name,
        label = job.label,
        grade = job.grade and job.grade.level or 0,
        onDuty = job.onduty == true,
    }
end

---@return table|nil job { name, label, grade, onDuty }
function BGRZ.GetJob()
    return currentJob()
end

---@return table|nil gang { name, label, grade, gradeName, isBoss }
function BGRZ.GetGang()
    return currentGang()
end

---@return boolean
function BGRZ.IsLoggedIn()
    return LocalPlayer.state.isLoggedIn == true
end

---@return table|nil metadata
function BGRZ.GetMetadata(key)
    local meta = QBX and QBX.PlayerData and QBX.PlayerData.metadata or nil
    if not meta then return nil end
    return key and meta[key] or meta
end

function BGRZ.Notify(message, ntype, duration)
    exports.qbx_core:Notify(message, ntype or 'inform', duration)
end

exports('GetJob', BGRZ.GetJob)
exports('GetGang', BGRZ.GetGang)
exports('IsLoggedIn', BGRZ.IsLoggedIn)
exports('GetMetadata', BGRZ.GetMetadata)
exports('Notify', BGRZ.Notify)

-- Re-emite eventos do Qbox com nomes próprios, para os resources não dependerem do framework.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local gang, job = currentGang(), currentJob()
    lastGangName, lastGangGrade = gang and gang.name or nil, gang and gang.grade or nil
    lastJobName, lastJobGrade = job and job.name or nil, job and job.grade or nil
    TriggerEvent('bgrz_core:client:playerLoaded')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    lastGangName, lastGangGrade, lastJobName, lastJobGrade = nil, nil, nil, nil
    TriggerEvent('bgrz_core:client:playerUnloaded')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    emitJobUpdate()
end)

local lastGangName, lastGangGrade, lastJobName, lastJobGrade

local function emitGangUpdate()
    local gang = currentGang()
    lastGangName = gang and gang.name or nil
    lastGangGrade = gang and gang.grade or nil
    TriggerEvent('bgrz_core:client:gangUpdated', gang or {})
end

local function emitJobUpdate()
    local job = currentJob()
    lastJobName = job and job.name or nil
    lastJobGrade = job and job.grade or nil
    TriggerEvent('bgrz_core:client:jobUpdated', job or {})
end

RegisterNetEvent('QBCore:Client:OnGangUpdate', function()
    emitGangUpdate()
end)

-- Entrar ou sair de um grupo não dispara OnGangUpdate/OnJobUpdate: o Qbox emite apenas
-- `onGroupUpdate`, sem dizer se mudou job ou gang. Comparamos com o último valor conhecido
-- para reemitir só o que realmente mudou.
RegisterNetEvent('qbx_core:client:onGroupUpdate', function()
    local gang = currentGang()
    if (gang and gang.name or nil) ~= lastGangName
        or (gang and gang.grade or nil) ~= lastGangGrade then
        emitGangUpdate()
    end

    local job = currentJob()
    if (job and job.name or nil) ~= lastJobName
        or (job and job.grade or nil) ~= lastJobGrade then
        emitJobUpdate()
    end
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    TriggerEvent('bgrz_core:client:dutyUpdated', onDuty == true)
end)
