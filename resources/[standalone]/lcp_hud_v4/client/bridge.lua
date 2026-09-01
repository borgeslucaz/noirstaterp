-- ---------------------------------------------------------------------------
--  Framework bridge (ESX / QBCore / standalone)
-- ---------------------------------------------------------------------------
--  Exposes Bridge.framework ('esx' | 'qb' | 'standalone') and helpers used
--  by the status, job and player-id modules. Detection is lazy so we do
--  not crash on servers that don't expose ESX / QBCore exports.
-- ---------------------------------------------------------------------------

Bridge = {
    framework = 'standalone',
    esx = nil,
    qb  = nil,
}

local function tryGetEsx()
    if GetResourceState('es_extended') ~= 'started' then return nil end
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then return obj end
    -- Older ESX
    local ok2, obj2 = pcall(function()
        local result
        TriggerEvent('esx:getSharedObject', function(o) result = o end)
        return result
    end)
    if ok2 and obj2 then return obj2 end
    return nil
end

local function tryGetQb()
    if GetResourceState('qb-core') ~= 'started' then return nil end
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and obj then return obj end
    return nil
end

local function hasQbox()
    return GetResourceState('qbx_core') == 'started'
end

local function getQboxPlayerData()
    if not hasQbox() then return nil end
    local ok, playerData = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    return ok and playerData or nil
end

local function detect()
    local forced = (Config and Config.Framework) or 'auto'

    if forced == 'esx' or forced == 'auto' then
        local esx = tryGetEsx()
        if esx then
            Bridge.esx = esx
            Bridge.framework = 'esx'
            return
        end
    end

    if forced == 'qb' or forced == 'auto' then
        local qb = tryGetQb()
        if qb then
            Bridge.qb = qb
            Bridge.framework = 'qb'
            return
        end
    end

    if forced == 'qbox' or forced == 'auto' then
        if hasQbox() then
            Bridge.framework = 'qbox'
            return
        end
    end

    Bridge.framework = 'standalone'
end

-- Run detection once the resource is up. We also retry a few times in
-- case the framework starts after us.
CreateThread(function()
    for i = 1, 10 do
        detect()
        if Bridge.framework ~= 'standalone' then return end
        Wait(500)
    end
end)

-- ---------------------------------------------------------------------------
--  Convenience getters
-- ---------------------------------------------------------------------------

function Bridge.getJob()
    if Bridge.framework == 'esx' and Bridge.esx then
        local pd = Bridge.esx.GetPlayerData and Bridge.esx.GetPlayerData() or nil
        if pd and pd.job then
            return {
                name  = pd.job.name or 'unemployed',
                label = pd.job.label or pd.job.name or 'Unemployed',
                grade = pd.job.grade_label or (pd.job.grade ~= nil and tostring(pd.job.grade)) or '',
            }
        end
    elseif Bridge.framework == 'qb' and Bridge.qb then
        local pd = Bridge.qb.Functions and Bridge.qb.Functions.GetPlayerData and Bridge.qb.Functions.GetPlayerData() or nil
        if pd and pd.job then
            return {
                name  = pd.job.name or 'unemployed',
                label = pd.job.label or pd.job.name or 'Unemployed',
                grade = (pd.job.grade and (pd.job.grade.name or pd.job.grade.level)) and
                        tostring(pd.job.grade.name or pd.job.grade.level) or '',
            }
        end
    elseif Bridge.framework == 'qbox' then
        local pd = getQboxPlayerData()
        if pd and pd.job then
            return {
                name  = pd.job.name or 'unemployed',
                label = pd.job.label or pd.job.name or 'Unemployed',
                grade = (pd.job.grade and (pd.job.grade.name or pd.job.grade.level)) and
                        tostring(pd.job.grade.name or pd.job.grade.level) or '',
            }
        end
    end
    return nil
end

-- Returns hunger / thirst from the framework (0-100) or nil if unsupported.
function Bridge.getFrameworkStatus()
    if Bridge.framework == 'qb' and Bridge.qb then
        local pd = Bridge.qb.Functions and Bridge.qb.Functions.GetPlayerData and Bridge.qb.Functions.GetPlayerData() or nil
        if pd and pd.metadata then
            return {
                hunger = tonumber(pd.metadata.hunger or pd.metadata.food) or nil,
                thirst = tonumber(pd.metadata.thirst or pd.metadata.water) or nil,
            }
        end
    elseif Bridge.framework == 'qbox' then
        local state = LocalPlayer.state
        local pd = getQboxPlayerData()
        local metadata = pd and pd.metadata or {}
        return {
            hunger = tonumber(state.hunger or metadata.hunger or metadata.food) or nil,
            thirst = tonumber(state.thirst or metadata.thirst or metadata.water) or nil,
        }
    end
    -- ESX status is pushed via the esx_status:onTick event handled in status.lua.
    return nil
end
