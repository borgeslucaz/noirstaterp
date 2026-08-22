Framework = {}
Framework.name = 'standalone'
Framework.object = nil

local function mapQbPlayerData(data)
    if not data or not data.charinfo then
        return nil
    end

    local charinfo = data.charinfo or {}
    local money = data.money or {}
    local job = data.job or {}

    return {
        firstName = charinfo.firstname or 'Unknown',
        lastName = charinfo.lastname or '',
        serverId = GetPlayerServerId(PlayerId()),
        cash = money.cash or 0,
        bank = money.bank or 0,
        jobLabel = job.label or 'Unemployed',
    }
end

local function detectFramework()
    if GetResourceState('qbx_core') == 'started' then
        Framework.name = 'qbx'
        Framework.object = nil
        return
    end

    if GetResourceState('es_extended') == 'started' then
        Framework.name = 'esx'
        Framework.object = exports['es_extended']:getSharedObject()
        return
    end

    if GetResourceState('qb-core') == 'started' then
        Framework.name = 'qbcore'
        Framework.object = exports['qb-core']:GetCoreObject()
        return
    end

    Framework.name = 'standalone'
    Framework.object = nil
end

detectFramework()

CreateThread(function()
    while Framework.name == 'standalone' do
        Wait(500)
        detectFramework()
    end
end)

function Framework.GetPlayerData()
    detectFramework()

    if Framework.name == 'qbx' then
        local data = exports.qbx_core:GetPlayerData()
        return mapQbPlayerData(data) or Framework.GetStandaloneData()
    end

    if Framework.name == 'esx' and Framework.object then
        local data = Framework.object.GetPlayerData()
        if not data then return Framework.GetStandaloneData() end

        local cash, bank = 0, 0
        if data.accounts then
            for _, account in ipairs(data.accounts) do
                if account.name == 'money' or account.name == 'cash' then
                    cash = account.money or 0
                elseif account.name == 'bank' then
                    bank = account.money or 0
                end
            end
        end

        return {
            firstName = data.firstName or 'Unknown',
            lastName = data.lastName or '',
            serverId = GetPlayerServerId(PlayerId()),
            cash = cash,
            bank = bank,
            jobLabel = (data.job and data.job.label) or 'Unemployed',
        }
    end

    if Framework.name == 'qbcore' and Framework.object then
        local data = Framework.object.Functions.GetPlayerData()
        return mapQbPlayerData(data) or Framework.GetStandaloneData()
    end

    return Framework.GetStandaloneData()
end

function Framework.GetStandaloneData()
    return {
        firstName = GetPlayerName(PlayerId()) or 'Player',
        lastName = '',
        serverId = GetPlayerServerId(PlayerId()),
        cash = 0,
        bank = 0,
        jobLabel = 'N/A',
    }
end
