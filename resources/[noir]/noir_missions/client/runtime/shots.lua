---Percebe tiro do próprio jogador dentro da área de um grupo da missão, pela munição que
---caiu. `gameEventTriggered` não é confiável no Enhanced (memória do servidor), então é por
---leitura de estado, e só enquanto há missão e o jogador está perto de um grupo.
local ClientConfig = require 'config.client'
local State = require 'client.runtime.state'

local Shots = {}

local running = false

---@param coords vector3
---@param areas table[]
---@return boolean
local function inside(coords, areas)
    for index = 1, #areas do
        local area = areas[index]
        if #(coords - vector3(area.x, area.y, area.z)) <= area.r then return true end
    end
    return false
end

function Shots.start()
    if running then return end
    running = true
    CreateThread(function()
        local lastWeapon, lastAmmo
        while State.view do
            local areas = State.view.areas or {}
            local sleep = 1000
            if #areas > 0 and inside(GetEntityCoords(cache.ped), areas) then
                sleep = ClientConfig.shotCheckMs
                local weapon = GetSelectedPedWeapon(cache.ped)
                if IsPedArmed(cache.ped, 4) then
                    local ammo = GetAmmoInPedWeapon(cache.ped, weapon)
                    if (lastWeapon == weapon and lastAmmo and ammo < lastAmmo) or IsPedShooting(cache.ped) then
                        TriggerServerEvent('noir_missions:server:shot')
                    end
                    lastWeapon, lastAmmo = weapon, ammo
                else
                    lastWeapon, lastAmmo = nil, nil
                end
            else
                lastWeapon, lastAmmo = nil, nil
            end
            Wait(sleep)
        end
        running = false
    end)
end

return Shots
