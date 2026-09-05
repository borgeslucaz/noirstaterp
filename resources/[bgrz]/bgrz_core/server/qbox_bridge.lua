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
    if not ok or not veh or veh == 0 then
        print(('[bgrz_core] SpawnVehicle falhou: %s'):format(tostring(netId)))
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
exports('SpawnVehicle', BGRZ.SpawnVehicle)

-- Re-emite eventos server-side do Qbox com nomes próprios.
AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    TriggerEvent('bgrz_core:server:jobUpdated', source, BGRZ.GetJob(source) or {
        name = job and job.name, onDuty = job and job.onduty == true,
    })
end)

AddEventHandler('QBCore:Server:SetDuty', function(source, onDuty)
    TriggerEvent('bgrz_core:server:dutyUpdated', source, onDuty == true)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    TriggerEvent('bgrz_core:server:playerUnloaded', source)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    TriggerEvent('bgrz_core:server:playerLoaded', source)
end)
