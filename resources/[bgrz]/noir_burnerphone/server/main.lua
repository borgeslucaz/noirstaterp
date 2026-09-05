local serverConfig = require 'server.config'

local activityRequests = {}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function hasBurnerPhone(source)
    return exports.ox_inventory:GetItemCount(source, BurnerPhoneConfig.itemName) > 0
end

local function copyLimitedList(value, maximum)
    if type(value) ~= 'table' then return {} end
    local result = {}
    local first = math.max(1, #value - maximum + 1)
    for index = first, #value do
        local entry = value[index]
        if type(entry) == 'table' then result[#result + 1] = entry end
    end
    return result
end

local function normalizeState(value)
    value = type(value) == 'table' and value or {}
    return {
        version = 1,
        contacts = copyLimitedList(value.contacts, serverConfig.maxContacts),
        messages = copyLimitedList(value.messages, serverConfig.maxMessages),
    }
end

local function getPlayerState(player)
    local state = normalizeState(player.PlayerData.metadata[serverConfig.stateMetadata])
    if player.PlayerData.metadata[serverConfig.stateMetadata] == nil then
        exports.qbx_core:SetMetadata(player.PlayerData.source, serverConfig.stateMetadata, state)
    end
    return state
end

local function savePlayerState(player, value)
    local state = normalizeState(value)
    exports.qbx_core:SetMetadata(player.PlayerData.source, serverConfig.stateMetadata, state)
    return state
end

local function publicActivities()
    return {
        drugSales = serverConfig.activities.drugSales == true,
        deliveries = serverConfig.activities.deliveries == true,
        blackMarket = serverConfig.activities.blackMarket == true,
    }
end

-- Contracts ---------------------------------------------------------------
-- Ids handed to the NUI are '<providerIndex>|<providerId>' so they route
-- back to the right provider without exposing anything else.

local contractRequests = {}
local CONTRACT_ACTIONS = { accept = 'accept', resume = 'resume', abandon = 'abandon' }

local function contractsEnabled()
    local contracts = serverConfig.contracts
    return BurnerPhoneConfig.enabled and type(contracts) == 'table' and contracts.enabled == true
end

local function callProvider(provider, method, ...)
    local exportName = provider[method]
    if type(exportName) ~= 'string' or GetResourceState(provider.resource) ~= 'started' then
        return nil, 'provider_unavailable'
    end
    local ok, result, reason = pcall(function(...)
        local target = exports[provider.resource]
        return target[exportName](target, ...)
    end, ...)
    if not ok then
        print(('^1[noir_burnerphone] %s.%s falhou: %s^0'):format(provider.resource, exportName, tostring(result)))
        return nil, 'provider_error'
    end
    return result, reason
end

local function publicId(index, id)
    return ('%d|%s'):format(index, tostring(id))
end

local function resolveContractId(value)
    if type(value) ~= 'string' then return nil end
    local index, id = value:match('^(%d+)|(.+)$')
    index = tonumber(index)
    local provider = index and serverConfig.contracts.providers[index]
    if not provider or not id then return nil end
    return provider, id
end

local function collectContracts(source)
    local result = { active = {}, available = {} }
    if not contractsEnabled() then return result end

    for index, provider in ipairs(serverConfig.contracts.providers) do
        local data = callProvider(provider, 'list', source)
        if type(data) == 'table' then
            for _, entry in ipairs(type(data.active) == 'table' and data.active or {}) do
                if type(entry) == 'table' and entry.id ~= nil then
                    result.active[#result.active + 1] = {
                        id = publicId(index, entry.id),
                        label = tostring(entry.label or 'Contrato'),
                        status = tostring(entry.status or 'assigned'),
                        canResume = entry.canResume ~= false,
                        canAbandon = entry.canAbandon ~= false,
                    }
                end
            end
            for _, entry in ipairs(type(data.available) == 'table' and data.available or {}) do
                if type(entry) == 'table' and entry.id ~= nil then
                    result.available[#result.available + 1] = {
                        id = publicId(index, entry.id),
                        label = tostring(entry.label or 'Contrato'),
                        tier = tonumber(entry.tier),
                        difficulty = entry.difficulty ~= nil and tostring(entry.difficulty) or nil,
                    }
                end
            end
        end
    end
    return result
end

lib.callback.register('noir_burnerphone:server:getState', function(source)
    if not BurnerPhoneConfig.enabled then return nil, 'disabled' end
    local player = getPlayer(source)
    if not player then return nil, 'player_unavailable' end
    if not hasBurnerPhone(source) then return nil, 'missing_phone' end

    return {
        state = getPlayerState(player),
        activities = publicActivities(),
        contracts = collectContracts(source),
    }
end)

lib.callback.register('noir_burnerphone:server:getContracts', function(source)
    if not BurnerPhoneConfig.enabled or not getPlayer(source) or not hasBurnerPhone(source) then return nil end
    return collectContracts(source)
end)

-- Returns ok, payload. On success payload is the fresh snapshot; on failure it
-- is a short player-facing reason.
lib.callback.register('noir_burnerphone:server:contractAction', function(source, action, contractId)
    if not contractsEnabled() then return false, 'Contratos indisponíveis.' end
    if not getPlayer(source) or not hasBurnerPhone(source) then return false, 'Você precisa do burner phone.' end
    local method = CONTRACT_ACTIONS[action]
    if not method then return false, 'Ação inválida.' end

    local timestamp = GetGameTimer()
    if contractRequests[source] and contractRequests[source] > timestamp then return false, 'Aguarde um instante.' end
    contractRequests[source] = timestamp + (serverConfig.contracts.requestCooldownMs or 750)

    local provider, rawId = resolveContractId(contractId)
    if not provider then return false, 'Contrato inválido.' end

    local ok, reason = callProvider(provider, method, source, rawId)
    if ok ~= true then
        return false, type(reason) == 'string' and reason or 'Não foi possível concluir a ação.'
    end
    return true, collectContracts(source)
end)

-- Providers call this after any contract change so an open phone refreshes
-- its lists without closing. Cheap no-op for players without the NUI open.
exports('refreshContracts', function(source)
    source = tonumber(source)
    if not source or not contractsEnabled() or not getPlayer(source) then return false end
    TriggerClientEvent('noir_burnerphone:client:contractsChanged', source, collectContracts(source))
    return true
end)

lib.callback.register('noir_burnerphone:server:authorizeActivity', function(source, activityId)
    if not BurnerPhoneConfig.enabled or type(activityId) ~= 'string' then return false end
    if not getPlayer(source) or not hasBurnerPhone(source) then return false end
    if serverConfig.activities[activityId] ~= true then return false end

    local timestamp = os.time()
    if activityRequests[source] and activityRequests[source] > timestamp then return false end
    activityRequests[source] = timestamp + serverConfig.activityRequestCooldown
    return true
end)

-- Server resources can persist generic contacts/messages without coupling the
-- phone to a specific illegal activity. State belongs to the current citizen,
-- never to the transferable inventory item.
exports('getPlayerState', function(source)
    source = tonumber(source)
    if not source then return nil end
    local player = getPlayer(source)
    return player and getPlayerState(player) or nil
end)

exports('setPlayerState', function(source, value)
    source = tonumber(source)
    if not source then return false end
    local player = getPlayer(source)
    if not player then return false end
    local state = savePlayerState(player, value)
    TriggerClientEvent('noir_burnerphone:client:stateUpdated', source, {
        state = state,
        activities = publicActivities(),
    })
    return true
end)

AddEventHandler('playerDropped', function()
    activityRequests[source] = nil
    contractRequests[source] = nil
end)
