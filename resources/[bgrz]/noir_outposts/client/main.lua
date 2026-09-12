-- Estado local e snapshot público. O client apresenta; o servidor decide.
NoirOutposts = NoirOutposts or {}

local Client = {}
NoirOutposts.Client = Client

local shared = require 'config.shared'
local clientConfig = require 'config.client'
local C = NoirOutposts.Constants

Client.outposts = {}
Client.context = { organizationId = nil, permissions = {} }
Client.blips = {}
Client.loggedIn = false

function Client.notify(message, kind)
    exports.bgrz_core:Notify(message, kind or 'inform')
end

---@param code string
---@return string
function Client.message(code)
    return locale('error.' .. code)
end

---@param response table?
---@return boolean ok
function Client.handleFailure(response)
    if response and response.ok then return true end
    local code = response and response.code or 'internal_error'
    Client.notify(Client.message(code), 'error')
    return false
end

local function removeBlips()
    for id, blip in pairs(Client.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        Client.blips[id] = nil
    end
end

local function refreshBlips()
    if not clientConfig.blips.enabled then
        removeBlips()
        return
    end
    for index = 1, #Client.outposts do
        local outpost = Client.outposts[index]
        local definition = shared.outposts[outpost.id]
        local isActive = outpost.status ~= C.OutpostStatus.INACTIVE
        local shouldShow = definition ~= nil and (isActive or clientConfig.blips.showInactive)

        if shouldShow and not Client.blips[outpost.id] then
            local coords = definition.entrance
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, definition.blip.sprite)
            SetBlipColour(blip, definition.blip.color)
            SetBlipScale(blip, definition.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(definition.label)
            EndTextCommandSetBlipName(blip)
            Client.blips[outpost.id] = blip
        elseif not shouldShow and Client.blips[outpost.id] then
            RemoveBlip(Client.blips[outpost.id])
            Client.blips[outpost.id] = nil
        end
    end
end

---@param outpostId string
---@return table? outpost
function Client.outpost(outpostId)
    for index = 1, #Client.outposts do
        if Client.outposts[index].id == outpostId then return Client.outposts[index] end
    end
    return nil
end

---@param snapshot table[]
local function applySnapshot(snapshot)
    if type(snapshot) ~= 'table' then return end
    Client.outposts = snapshot
    refreshBlips()
    NoirOutposts.Interaction.refresh()
end

RegisterNetEvent(C.Events.SYNC, function(snapshot)
    if source ~= 65535 then return end
    applySnapshot(snapshot)
end)

function Client.requestContext()
    local response = lib.callback.await(C.Callbacks.GET_CONTEXT, false)
    if not response or not response.ok then return end
    Client.context.organizationId = response.data.organizationId
    Client.context.permissions = response.data.permissions or {}
    applySnapshot(response.data.outposts)
end

AddEventHandler('bgrz_core:client:playerLoaded', function()
    Client.loggedIn = true
    CreateThread(function()
        Wait(1500)
        Client.requestContext()
    end)
end)

AddEventHandler('bgrz_core:client:gangUpdated', function()
    if not Client.loggedIn then return end
    Client.requestContext()
end)

AddEventHandler('bgrz_core:client:playerUnloaded', function()
    Client.loggedIn = false
    Client.context.organizationId = nil
    Client.context.permissions = {}
    Client.outposts = {}
    removeBlips()
    NoirOutposts.Interaction.clear()
    NoirOutposts.Ui.forceClose()
end)

CreateThread(function()
    local attempts = 0
    while not exports.bgrz_core:IsLoggedIn() and attempts < 150 do
        attempts = attempts + 1
        Wait(200)
    end
    if not exports.bgrz_core:IsLoggedIn() then return end
    Client.loggedIn = true
    Client.requestContext()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeBlips()
end)
