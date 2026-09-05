-- Bridge client-side para o Qbox.
-- Resources BGRZ usam estes exports/eventos em vez de falar com o qbx_core diretamente.
BGRZ = BGRZ or {}

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
exports('IsLoggedIn', BGRZ.IsLoggedIn)
exports('GetMetadata', BGRZ.GetMetadata)
exports('Notify', BGRZ.Notify)

-- Re-emite eventos do Qbox com nomes próprios, para os resources não dependerem do framework.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent('bgrz_core:client:playerLoaded')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerEvent('bgrz_core:client:playerUnloaded')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    TriggerEvent('bgrz_core:client:jobUpdated', currentJob() or {
        name = job and job.name,
        label = job and job.label,
        grade = job and job.grade and job.grade.level or 0,
        onDuty = job and job.onduty == true,
    })
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    TriggerEvent('bgrz_core:client:dutyUpdated', onDuty == true)
end)
