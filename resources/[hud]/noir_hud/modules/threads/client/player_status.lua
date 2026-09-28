---@diagnostic disable: cast-local-type
local interface = lib.require("modules.interface.client")
local config = lib.require("config.shared")
local utility = lib.require("modules.utility.shared.main")
local sharedFunctions = lib.require("config.functions")

local PlayerStatusThread = {}
PlayerStatusThread.__index = PlayerStatusThread

local headingRanges = {
    { min = 315, max = 360, dir = "N" },
    { min = 0, max = 45, dir = "N" },
    { min = 45, max = 135, dir = "E" },
    { min = 135, max = 225, dir = "S" },
    { min = 225, max = 315, dir = "W" },
}

local compassEnabled = config.compassLocation ~= "hidden"

local voiceModes = {
    Whisper = 15,
    Normal = 50,
    Shouting = 100,
}

---@return table
function PlayerStatusThread.new()
    local self = setmetatable({
        isVehicleThreadRunning = false,
        lastPlayerData = nil,
        lastMinimap = nil,
        radarVisible = nil,
        uiWasVisible = false,
    }, PlayerStatusThread)

    return self
end

function PlayerStatusThread:getIsVehicleThreadRunning()
    return self.isVehicleThreadRunning
end

---@param value boolean
function PlayerStatusThread:setIsVehicleThreadRunning(value)
    lib.print.verbose("(PlayerStatusThread:setIsVehicleThreadRunning) Setting: ", value)
    self.isVehicleThreadRunning = value
end

-- Skips the native unless the radar is actually in another state (the game or
-- the pause menu can hide it behind our back, so the cache alone is not enough).
function PlayerStatusThread:setRadarVisible(state, force)
    if not force and self.radarVisible == state and IsRadarHidden() ~= state then return end
    self.radarVisible = state
    DisplayRadar(state)
end

function PlayerStatusThread:start(vehicleStatusThread, seatbeltLogic, framework)
    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            local isInVehicle = IsPedInAnyVehicle(ped, false)

            if isInVehicle then
                if not self:getIsVehicleThreadRunning() and vehicleStatusThread then
                    vehicleStatusThread:start()
                    lib.print.verbose("(playerStatus) (vehicleStatusThread) Vehicle status thread started.")
                end
                self:setRadarVisible(true)
            else
                self:setRadarVisible(_G.minimapVisible)
            end

            local uiVisible = interface.store.visibility.app
            if uiVisible and not self.uiWasVisible then
                self.lastPlayerData = nil
                self.lastMinimap = nil
            end
            self.uiWasVisible = uiVisible

            -- Hidden HUD (pause menu, logged out): keep the radar in sync, skip the rest.
            if uiVisible then
                local playerId = PlayerId()
                local voice, voiceMode = 0, nil

                -- Street, zone and heading only feed the compass; the heading follows the
                -- camera, so computing it while hidden would resend the state on every look.
                local currentStreet, zone, compass = "", "", ""
                if compassEnabled and (config.compassAlways or isInVehicle) then
                    local coords = GetEntityCoords(ped)
                    currentStreet = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
                    zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

                    local camRot = GetGameplayCamRot(0)
                    local heading = utility.round(360.0 - ((camRot.z + 360.0) % 360.0))
                    compass = " "
                    for _, range in ipairs(headingRanges) do
                        if heading >= range.min and heading < range.max then
                            compass = range.dir
                            break
                        end
                    end
                end

                local proximity = LocalPlayer.state["proximity"]
                if proximity then
                    voiceMode = proximity.mode
                    voice = voiceModes[voiceMode] or 0
                end

                local pedMaxHealth = GetEntityMaxHealth(ped)
                local pedHealthPercentage = math.floor(((GetEntityHealth(ped) - 100) / (pedMaxHealth - 100)) * 100)
                pedHealthPercentage = math.max(0, math.min(100, pedHealthPercentage))

                local player_data = {
                    health = pedHealthPercentage,
                    armor = GetPedArmour(ped),
                    hunger = framework and framework:getPlayerHunger() or nil,
                    thirst = framework and framework:getPlayerThirst() or nil,
                    stress = framework and framework:getPlayerStress() or nil,
                    oxygen = math.floor(GetPlayerUnderwaterTimeRemaining(playerId) * 10),
                    stamina = math.floor(100 - GetPlayerSprintStaminaRemaining(playerId)),
                    streetLabel = currentStreet,
                    areaLabel = zone,
                    heading = compass,
                    voice = voice,
                    voiceMode = voiceMode,
                    mic = NetworkIsPlayerTalking(playerId),
                    isSeatbeltOn = config.useBuiltInSeatbeltLogic and seatbeltLogic.seatbeltState or sharedFunctions.isSeatbeltOn(),
                    isInVehicle = isInVehicle,
                }

                local minimap = utility.calculateMinimapSizeAndPosition()
                local playerChanged = not utility.shallowEqual(self.lastPlayerData, player_data)
                local minimapChanged = self.lastMinimap ~= minimap

                if playerChanged or minimapChanged then
                    interface:message("state::global::set", {
                        minimap = minimap,
                        player = player_data,
                    })
                    self.lastPlayerData = player_data
                    self.lastMinimap = minimap
                end
            end

            Wait(config.playerUpdateInterval or 500)
        end
    end)
end

return PlayerStatusThread
