---Pontos de serviço, blips das delegacias e blips de colegas em serviço.

local Config = require 'config.shared'
local Departments = require 'shared.departments'
local Integrations = require 'client.integrations'
local Util = require 'client.util'
local Layout = require 'client.layout'

local stationBlips = {}
local unitBlips = {}
local zones = {}

local function toggleDuty()
    local result = lib.callback.await('noir_police:server:toggleDuty', false)
    if not result or not result.ok then
        return Integrations.notify(Util.errorText(result and result.code), 'error')
    end
    Integrations.notify(locale(result.onDuty and 'success.on_duty' or 'success.off_duty'), 'success')
end

local function clearStations()
    for _, blip in ipairs(stationBlips) do RemoveBlip(blip) end
    for _, zone in ipairs(zones) do Integrations.removeZone(zone) end
    stationBlips, zones = {}, {}
end

---Retirar pertences liberados (qualquer pessoa; o servidor confere se há algo).
local function returnsOption(key)
    return {
        name = ('noir_police:returns:%s'):format(key),
        icon = 'fa-solid fa-box-open',
        label = locale('target.pickup_returns'),
        onSelect = function()
            local result = lib.callback.await('noir_police:server:openReturns', false)
            if not result or not result.ok then
                Integrations.notify(Util.errorText(result and result.code), 'error')
            end
        end,
    }
end

local function buildStations()
    clearStations()
    for _, station in ipairs(Layout.stations()) do
        if station.blip then
            local blip = AddBlipForCoord(station.blip.coords.x, station.blip.coords.y, station.blip.coords.z)
            SetBlipSprite(blip, station.blip.sprite or 60)
            SetBlipColour(blip, station.blip.color or 29)
            SetBlipScale(blip, station.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(station.label)
            EndTextCommandSetBlipName(blip)
            stationBlips[#stationBlips + 1] = blip
        end

        for index, point in ipairs(station.duty or {}) do
            zones[#zones + 1] = Integrations.addSphereZone({
                coords = point,
                radius = 1.0,
                options = {
                    {
                        name = ('noir_police:duty:%s:%d'):format(station.id, index),
                        icon = 'fa-solid fa-clipboard-user',
                        label = locale('target.toggle_duty'),
                        canInteract = function()
                            local job = Integrations.getJob()
                            return Departments.isPolice(job) and Departments.stationServes(station, job.name)
                        end,
                        onSelect = toggleDuty,
                    },
                    -- Sem recepção configurada, a retirada fica no ponto de serviço.
                    not station.reception and returnsOption(('%s:%d'):format(station.id, index)) or nil,
                },
            })
        end

        if station.reception then
            zones[#zones + 1] = Integrations.addSphereZone({
                coords = station.reception.coords,
                radius = station.reception.radius,
                options = { returnsOption(station.id) },
            })
        end
    end
end

buildStations()
AddEventHandler('noir_police:client:layoutChanged', function(kind)
    if kind == 'stations' then buildStations() end
end)

-- Blips de colegas -----------------------------------------------------------------

local function clearUnitBlips(keep)
    for id, blip in pairs(unitBlips) do
        if not keep or not keep[id] then
            RemoveBlip(blip)
            unitBlips[id] = nil
        end
    end
end

RegisterNetEvent('noir_police:client:units', function(units)
    if source ~= 65535 then return end
    if type(units) ~= 'table' then return end
    local seen = {}
    for _, unit in ipairs(units) do
        if unit.id ~= cache.serverId then
            seen[unit.id] = true
            local blip = unitBlips[unit.id]
            if not blip or not DoesBlipExist(blip) then
                blip = AddBlipForCoord(unit.x, unit.y, unit.z)
                SetBlipSprite(blip, 1)
                SetBlipScale(blip, 0.8)
                SetBlipCategory(blip, 7)
                ShowHeadingIndicatorOnBlip(blip, true)
                unitBlips[unit.id] = blip
            else
                SetBlipCoords(blip, unit.x, unit.y, unit.z)
            end
            SetBlipSprite(blip, unit.inVehicle and 56 or 1)
            SetBlipColour(blip, unit.color or 1)
            SetBlipRotation(blip, math.floor(unit.heading or 0.0))
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(unit.label or '')
            EndTextCommandSetBlipName(blip)
        end
    end
    clearUnitBlips(seen)
end)

AddEventHandler('bgrz_core:client:playerUnloaded', function() clearUnitBlips() end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    clearUnitBlips()
    clearStations()
end)

-- Alerta do fallback de dispatch do bgrz_core (quando não há MDT com chamado) e de
-- resources que avisam os policiais direto por este evento.
RegisterNetEvent('police:client:policeAlert', function(coords, text)
    if source ~= 65535 then return end
    if not Departments.isOnDutyPolice(Integrations.getJob()) or type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
    Integrations.notify(tostring(text or locale('dispatch.generic_message')), 'warning')
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('dispatch.generic_title'))
    EndTextCommandSetBlipName(blip)
    SetTimeout(120000, function() RemoveBlip(blip) end)
end)

-- Contagem de policiais para quem ainda lê pelo cliente.
local copCount = 0
RegisterNetEvent('police:SetCopCount', function(amount)
    if source ~= 65535 then return end
    copCount = tonumber(amount) or 0
end)

exports('GetCopCount', function() return copCount end)
