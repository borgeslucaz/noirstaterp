-- Única fronteira com providers: tudo passa pelo bgrz_core (framework, inventário,
-- phone, dispatch). Nenhum outro arquivo do resource chama exports externos.
NoirOutposts = NoirOutposts or {}

local Integration = {}
NoirOutposts.Integration = Integration

local config = require 'config.server'
local Log = NoirOutposts.Log

local orgBySource = {}
local membersByOrganization = {}

local function callBridge(name, ...)
    local called, first, second = pcall(function(...)
        return exports.bgrz_core[name](exports.bgrz_core, ...)
    end, ...)
    if not called then
        Log.error('bridge_call_failed', { export = name, error = tostring(first) })
        return nil, 'provider_unavailable'
    end
    return first, second
end

-- Identidade -------------------------------------------------------------------

---@param source number
---@return table? character
function Integration.getCharacter(source)
    local character = callBridge('GetCharacter', source)
    if type(character) ~= 'table' or not character.citizenId then return nil end
    return character
end

---A organização é a gang do personagem normalizado pelo bridge. `none` não conta.
---@param character table? retorno de GetCharacter
---@return table? organization { id, label, grade, gradeName }
function Integration.organizationFrom(character)
    local gang = type(character) == 'table' and character.gang or nil
    if type(gang) ~= 'table' then return nil end
    local name = gang.name
    if type(name) ~= 'string' or name == '' or name == 'none' then return nil end
    return {
        id = name,
        label = gang.label or name,
        grade = tonumber(gang.grade) or 0,
        gradeName = gang.gradeName or tostring(gang.grade or 0),
    }
end

---@param source number
---@return table? organization { id, label, grade, gradeName }
function Integration.getOrganization(source)
    return Integration.organizationFrom(Integration.getCharacter(source))
end

-- Inventário e dinheiro ------------------------------------------------------------

function Integration.addItem(source, item, amount, metadata)
    return callBridge('AddItem', source, item, amount, metadata)
end

function Integration.removeItem(source, item, amount, metadata)
    return callBridge('RemoveItem', source, item, amount, metadata)
end

function Integration.getItemCount(source, item)
    local count, err = callBridge('GetItemCount', source, item)
    if type(count) ~= 'number' then return 0, err end
    return count
end

function Integration.canCarryItem(source, item, amount)
    return callBridge('CanCarryItem', source, item, amount)
end

function Integration.addMoney(source, account, amount, reason)
    local ok = callBridge('AddMoney', source, account, amount, reason)
    return ok == true
end

function Integration.removeMoney(source, account, amount, reason)
    local ok = callBridge('RemoveMoney', source, account, amount, reason)
    return ok == true
end

-- Feedback ----------------------------------------------------------------------

function Integration.notify(source, message, kind)
    callBridge('Notify', source, message, kind or 'inform')
end

---@param source number
---@param payload table { title, body }
function Integration.sendPhoneNotification(source, payload)
    local shared = require 'config.shared'
    payload.app = payload.app or shared.phone.name
    payload.appId = payload.appId or shared.phone.identifier
    local ok, err = callBridge('SendPhoneNotification', source, payload)
    if not ok and err ~= 'provider_unavailable' then
        Log.debug('phone_notification_failed', { source = source, code = err })
    end
    return ok == true
end

---@param request table
---@return boolean ok
function Integration.sendDispatch(request)
    local ok, result = callBridge('SendDispatch', request)
    if not ok then
        Log.debug('dispatch_failed', { code = tostring(result) })
    end
    return ok == true
end

-- Servidor ----------------------------------------------------------------------

---@return integer
function Integration.onlinePlayerCount()
    return #GetPlayers()
end

---@return integer
function Integration.onDutyPoliceCount()
    local total = 0
    for index = 1, #config.police.jobs do
        local count = callBridge('CountOnDutyJob', config.police.jobs[index])
        if type(count) == 'number' then total = total + count end
    end
    return total
end

-- Cache de organização por jogador online ----------------------------------------

local function detach(source)
    local previous = orgBySource[source]
    if not previous then return nil end
    orgBySource[source] = nil
    local members = membersByOrganization[previous.id]
    if members then
        members[source] = nil
        if next(members) == nil then membersByOrganization[previous.id] = nil end
    end
    return previous
end

---@param source number
---@return table? organization
function Integration.refreshPlayer(source)
    local previous = detach(source)
    local organization = Integration.getOrganization(source)
    if organization then
        orgBySource[source] = { id = organization.id, grade = organization.grade }
        membersByOrganization[organization.id] = membersByOrganization[organization.id] or {}
        membersByOrganization[organization.id][source] = organization.grade
    end
    local previousId = previous and previous.id or nil
    local currentId = organization and organization.id or nil
    if previousId ~= currentId or (previous and organization and previous.grade ~= organization.grade) then
        TriggerEvent('noir_outposts:server:organizationChanged', source, previousId, organization)
    end
    return organization
end

---@param source number
function Integration.removePlayer(source)
    local previous = detach(source)
    if previous then
        TriggerEvent('noir_outposts:server:organizationChanged', source, previous.id, nil)
    end
end

function Integration.rebuildMembers()
    orgBySource = {}
    membersByOrganization = {}
    local players = GetPlayers()
    for index = 1, #players do
        local source = tonumber(players[index])
        if source then Integration.refreshPlayer(source) end
    end
end

---@param organizationId string
---@return number[] sources
function Integration.onlineMembers(organizationId)
    local result = {}
    local members = membersByOrganization[organizationId]
    if not members then return result end
    for source in pairs(members) do result[#result + 1] = source end
    table.sort(result)
    return result
end

---@param organizationId string
---@param minimumGrade? number
---@return number[] sources
function Integration.onlineMembersWithGrade(organizationId, minimumGrade)
    local result = {}
    local members = membersByOrganization[organizationId]
    if not members then return result end
    for source, grade in pairs(members) do
        if (tonumber(grade) or 0) >= (minimumGrade or 0) then result[#result + 1] = source end
    end
    table.sort(result)
    return result
end

---@param organizationId string
---@return boolean
function Integration.hasOnlineMember(organizationId)
    local members = membersByOrganization[organizationId]
    return members ~= nil and next(members) ~= nil
end

AddEventHandler('bgrz_core:server:playerLoaded', function(source)
    if type(source) == 'number' then Integration.refreshPlayer(source) end
end)

AddEventHandler('bgrz_core:server:gangUpdated', function(source)
    if type(source) == 'number' then Integration.refreshPlayer(source) end
end)

AddEventHandler('bgrz_core:server:playerUnloaded', function(source)
    if type(source) == 'number' then Integration.removePlayer(source) end
end)

AddEventHandler('playerDropped', function()
    local source = source
    Integration.removePlayer(source)
end)
