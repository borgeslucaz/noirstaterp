---Regras puras de departamento e permissão. Sem natives e sem exports: roda igual no
---cliente, no servidor e nos testes.
---
---`job` é sempre o formato normalizado do bgrz_core: { name, label, type, grade, onDuty }.

local Config = require 'config.shared'

local Departments = {}

---@param jobName string?
---@return table? department
function Departments.get(jobName)
    if type(jobName) ~= 'string' then return nil end
    return Config.departments[jobName]
end

---É policial (qualquer job `leo` que esteja em `departments`), em serviço ou não.
---@param job table?
---@return boolean
function Departments.isPolice(job)
    return type(job) == 'table'
        and job.type == Config.policeJobType
        and Config.departments[job.name] ~= nil
end

---@param job table?
---@return boolean
function Departments.isOnDutyPolice(job)
    return Departments.isPolice(job) and job.onDuty == true
end

---@param job table?
---@return boolean
function Departments.isOnDutyEms(job)
    return type(job) == 'table' and job.type == Config.emsJobType and job.onDuty == true
end

---Grade mínima de uma ação para o departamento do job.
---@param jobName string
---@param action string
---@return integer
function Departments.requiredGrade(jobName, action)
    local department = Config.departments[jobName]
    local override = department and department.grades and department.grades[action]
    if type(override) == 'number' then return override end
    return Config.grades[action] or 0
end

---Policial em serviço com grade suficiente para a ação.
---@param job table?
---@param action? string
---@return boolean
function Departments.can(job, action)
    if not Departments.isOnDutyPolice(job) then return false end
    if not action then return true end
    return (tonumber(job.grade) or 0) >= Departments.requiredGrade(job.name, action)
end

---Subunidade (K9, SWAT...). Liberada por citizenId na lista ou por grade mínima.
---@param job table?
---@param citizenId string?
---@param subunit string
---@return boolean
function Departments.inSubunit(job, citizenId, subunit)
    local entry = Config.subunits[subunit]
    if not entry or not Departments.isPolice(job) then return false end
    if citizenId then
        for index = 1, #(entry.citizenIds or {}) do
            if entry.citizenIds[index] == citizenId then return true end
        end
    end
    return entry.minGrade ~= nil and (tonumber(job.grade) or 0) >= entry.minGrade
end

---Lista dos jobs que são polícia, em ordem estável.
---@return string[]
function Departments.jobNames()
    local names = {}
    for name in pairs(Config.departments) do names[#names + 1] = name end
    table.sort(names)
    return names
end

---A estação atende o departamento?
---@param station table
---@param jobName string
---@return boolean
function Departments.stationServes(station, jobName)
    for index = 1, #(station.departments or {}) do
        if station.departments[index] == jobName then return true end
    end
    return false
end

---A entrada da frota vale para o departamento e a grade?
---@param entry table
---@param job table
---@return boolean
function Departments.fleetAllows(entry, job)
    if (tonumber(job.grade) or 0) < (entry.grade or 0) then return false end
    if not entry.departments or #entry.departments == 0 then return true end
    for index = 1, #entry.departments do
        if entry.departments[index] == job.name then return true end
    end
    return false
end

return Departments
