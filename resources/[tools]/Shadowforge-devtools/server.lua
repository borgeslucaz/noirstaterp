-- ShadowForge DevTools — Server
-- Permissions, framework data callbacks, optional Discord logging,
-- safe resource control commands.

SFD = SFD or { Framework = 'standalone' }

-- ───────────────────────────────────────────────
-- Framework detection
-- ───────────────────────────────────────────────
CreateThread(function()
    Wait(500)
    if GetResourceState('qbx_core') == 'started' then
        SFD.Framework = 'qbox'
    elseif GetResourceState('qb-core') == 'started' then
        SFD.Framework = 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        SFD.Framework = 'esx'
    end
end)

-- ───────────────────────────────────────────────
-- Permissions
-- ───────────────────────────────────────────────
local function hasPermission(source, level)
    if not Config.Permissions.require then return true end
    local perm = (level == 'dangerous')
        and Config.Permissions.dangerous
        or  Config.Permissions.ace
    return IsPlayerAceAllowed(source, perm) == true
end

lib.callback.register('sfd:permission', function(source, level)
    return hasPermission(source, level or 'base')
end)

-- ───────────────────────────────────────────────
-- Player identifiers (gated)
-- ───────────────────────────────────────────────
lib.callback.register('sfd:getIdentifiers', function(source)
    if not hasPermission(source) then return nil end
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(source, i)
    end
    return {
        source      = source,
        name        = GetPlayerName(source),
        identifiers = ids,
        ping        = GetPlayerPing(source),
    }
end)

-- ───────────────────────────────────────────────
-- Framework data
-- ───────────────────────────────────────────────
lib.callback.register('sfd:getFrameworkData', function(source)
    if not hasPermission(source) then return nil end
    local data = { framework = SFD.Framework }

    local ok, err = pcall(function()
        if SFD.Framework == 'qbox' then
            local Player = exports.qbx_core:GetPlayer(source)
            if Player and Player.PlayerData then
                local pd = Player.PlayerData
                data.job       = pd.job
                data.money     = pd.money
                data.citizenid = pd.citizenid
                data.duty      = pd.job and pd.job.onduty
                data.gang      = pd.gang
            end
        elseif SFD.Framework == 'qbcore' then
            local QBCore = exports['qb-core']:GetCoreObject()
            local Player = QBCore.Functions.GetPlayer(source)
            if Player and Player.PlayerData then
                local pd = Player.PlayerData
                data.job       = pd.job
                data.money     = pd.money
                data.citizenid = pd.citizenid
                data.duty      = pd.job and pd.job.onduty
                data.gang      = pd.gang
            end
        elseif SFD.Framework == 'esx' then
            local ESX = exports.es_extended:getSharedObject()
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                data.job        = xPlayer.getJob and xPlayer.getJob() or nil
                data.identifier = xPlayer.identifier
                data.money      = {
                    cash = xPlayer.getMoney and xPlayer.getMoney() or 0,
                    bank = xPlayer.getAccount and xPlayer.getAccount('bank') and xPlayer.getAccount('bank').money or 0,
                }
            end
        end
    end)
    if not ok then data._error = tostring(err) end
    return data
end)

-- ───────────────────────────────────────────────
-- Routing bucket lookup (debug overlay)
-- ───────────────────────────────────────────────
lib.callback.register('sfd:getRoutingBucket', function(source)
    if not hasPermission(source) then return nil end
    return GetPlayerRoutingBucket(source)
end)

-- ───────────────────────────────────────────────
-- Safe resource commands
-- ───────────────────────────────────────────────
local function isSafeResource(name)
    for _, r in ipairs(Config.SafeResources) do
        if r == name then return true end
    end
    return false
end

lib.callback.register('sfd:listSafeResources', function(source)
    if not hasPermission(source, 'dangerous') then return {} end
    local list = {}
    for _, r in ipairs(Config.SafeResources) do
        list[#list + 1] = { name = r, state = GetResourceState(r) }
    end
    return list
end)

RegisterNetEvent('sfd:resource', function(action, name)
    local src = source
    if not hasPermission(src, 'dangerous') then return end
    if not isSafeResource(name) then return end
    if action == 'restart' then
        ExecuteCommand(('ensure %s'):format(name))
    elseif action == 'start' then
        StartResource(name)
    elseif action == 'stop' then
        StopResource(name)
    else
        return
    end
    TriggerEvent('sfd:log', ('resource:%s'):format(action), { resource = name, by = src })
end)

-- ───────────────────────────────────────────────
-- Optional world sync (admin-style time/weather broadcast)
-- ───────────────────────────────────────────────
RegisterNetEvent('sfd:worldSync', function(payload)
    local src = source
    if not Config.World.syncToServer then return end
    if not hasPermission(src, 'dangerous') then return end
    TriggerClientEvent('sfd:applyWorldSync', -1, payload)
    TriggerEvent('sfd:log', 'world:sync', { by = src, payload = payload })
end)

-- ───────────────────────────────────────────────
-- Discord logging
-- ───────────────────────────────────────────────
local function postWebhook(payload)
    if not Config.Discord.enabled then return end
    if not Config.Discord.webhook or Config.Discord.webhook == '' then return end
    PerformHttpRequest(Config.Discord.webhook, function() end,
        'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function trimLogKey(action)
    -- 'resource:restart' -> 'resource'
    return action:match('^([^:]+)') or action
end

RegisterNetEvent('sfd:log', function(action, data)
    if not Config.Discord.enabled then return end
    local key = trimLogKey(action)
    if Config.Discord.log[key] == false then return end

    local src = source
    local name = (src and src > 0 and GetPlayerName(src)) or 'CONSOLE'
    local body
    local ok, encoded = pcall(json.encode, data or {})
    if ok then
        body = encoded
    else
        body = tostring(data)
    end
    if #body > 900 then body = body:sub(1, 900) .. '…' end

    postWebhook({
        username   = Config.Discord.botName,
        avatar_url = Config.Discord.botAvatar ~= '' and Config.Discord.botAvatar or nil,
        embeds = {{
            title  = ('ShadowForge DevTools — %s'):format(action),
            color  = Config.Discord.color,
            fields = {
                { name = 'Player', value = ('`%s` (%s)'):format(name, tostring(src or 'n/a')), inline = true },
                { name = 'Action', value = action, inline = true },
                { name = 'Data',   value = ('```json\n%s\n```'):format(body), inline = false },
            },
            timestamp = os.date('!%Y-%m-%dT%TZ'),
            footer    = { text = 'ShadowForge DevTools' },
        }},
    })
end)
