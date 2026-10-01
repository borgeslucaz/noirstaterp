local config = require 'config.client'

local isOpen = false
local requestPending = false
local keyHeld = false
local adminsOnDuty = {} ---@type table<integer, boolean>

---@param targetServerId integer
---@return boolean
local function shouldShowPlayerId(targetServerId)
    if config.idVisibility == 'all' then return true end
    if adminsOnDuty[cache.serverId] then return true end
    if config.idVisibility == 'admin_only' then return false end
    if config.idVisibility == 'admin_excluded' and adminsOnDuty[targetServerId] then return false end
    return true
end

---@param coords vector3
---@param text string
local function drawText3d(coords, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawPlayerNumbers()
    CreateThread(function()
        local players, refreshAt = {}, 0
        while isOpen do
            local now = GetGameTimer()
            if now >= refreshAt then
                refreshAt = now + 1000
                players = lib.getNearbyPlayers(GetEntityCoords(cache.ped), config.visibilityDistance, true)
                for index = #players, 1, -1 do
                    local player = players[index]
                    player.serverId = GetPlayerServerId(player.id)
                    if not shouldShowPlayerId(player.serverId) then table.remove(players, index) end
                end
            end

            if #players == 0 then
                Wait(250)
            else
                for index = 1, #players do
                    local player = players[index]
                    if DoesEntityExist(player.ped) then
                        local coords = GetEntityCoords(player.ped)
                        drawText3d(vec3(coords.x, coords.y, coords.z + 1.0), ('[%d]'):format(player.serverId))
                    end
                end
                Wait(0)
            end
        end
    end)
end

local function close()
    if not isOpen then return end
    isOpen = false
    SendNUIMessage({ action = 'close' })
end

local function open()
    if isOpen or requestPending then return end
    requestPending = true
    local data = lib.callback.await('noir_scoreboard:server:open', false)
    requestPending = false
    if type(data) ~= 'table' then return end
    -- Segurando a tecla: se ela foi solta enquanto a resposta vinha, não abre mais.
    if not config.toggle and not keyHeld then return end

    adminsOnDuty = data.admins or {}
    isOpen = true
    SendNUIMessage({
        action = 'open',
        players = data.players,
        maxPlayers = data.maxPlayers,
        crimes = data.crimes,
        policeUnavailable = data.policeUnavailable,
    })
    drawPlayerNumbers()
end

-- O nome `scoreboard` é o mesmo do qbx_scoreboard, para a tecla que o jogador já
-- tinha trocado nas configurações do FiveM continuar valendo.
lib.addKeybind({
    name = 'scoreboard',
    description = 'Abrir o placar da cidade',
    defaultKey = config.openKey,
    onPressed = function()
        keyHeld = true
        if not config.toggle then return open() end
        if isOpen then close() else open() end
    end,
    onReleased = function()
        keyHeld = false
        if not config.toggle then close() end
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then isOpen = false end
end)
