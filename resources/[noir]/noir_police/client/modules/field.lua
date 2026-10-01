---Menu da polícia e ações de campo: multa, licença, tornozeleira, officer down, área
---interditada, status de unidade e reunião.

local Config = require 'config.shared'
local Departments = require 'shared.departments'
local Integrations = require 'client.integrations'
local Util = require 'client.util'
local Evidence = require 'client.modules.evidence'

local interdictBlips = {}

local function job() return Integrations.getJob() end
local function can(action) return Departments.can(job(), action) end
local function fail(result) Integrations.notify(Util.errorText(result and result.code), 'error') end

-- Ações sobre outro jogador ----------------------------------------------------------

local function fine(target)
    local input = lib.inputDialog(locale('fine.title'), {
        { type = 'number', label = locale('fine.amount'), required = true, min = 1 },
        { type = 'input', label = locale('fine.reason'), required = true, min = 3, max = 120 },
    })
    if not input then return end
    local result = lib.callback.await('noir_police:server:fine', false, target, math.floor(input[1] or 0), input[2])
    if not result or not result.ok then return fail(result) end
    Integrations.notify(locale('success.fined'), 'success')
end

local function license(target)
    local options = {}
    for key, label in pairs(Config.licenses) do options[#options + 1] = { value = key, label = label } end
    local input = lib.inputDialog(locale('license.title'), {
        { type = 'select', label = locale('license.type'), options = options, required = true },
        { type = 'select', label = locale('license.action'), required = true, default = 'grant', options = {
            { value = 'grant', label = locale('license.grant') },
            { value = 'revoke', label = locale('license.revoke') },
        } },
    })
    if not input then return end
    local result = lib.callback.await('noir_police:server:license', false, target, input[1], input[2] == 'grant')
    if not result or not result.ok then return fail(result) end
    Integrations.notify(locale('success.license_updated'), 'success')
end

local function anklet(target)
    local result = lib.callback.await('noir_police:server:anklet', false, target)
    if not result or not result.ok then return fail(result) end
    Integrations.notify(locale(result.enabled and 'success.anklet_on' or 'success.anklet_off', result.citizenId or '?'), 'success')
end

Integrations.addGlobalPlayer({
    {
        name = 'noir_police:field:fine',
        icon = 'fa-solid fa-file-invoice-dollar',
        label = locale('target.fine'),
        distance = 2.0,
        canInteract = function() return can('fine') end,
        onSelect = function(data) fine(Util.serverIdFromPed(data.entity)) end,
    },
    {
        name = 'noir_police:field:license',
        icon = 'fa-solid fa-id-card',
        label = locale('target.license'),
        distance = 2.0,
        canInteract = function() return can('license') end,
        onSelect = function(data) license(Util.serverIdFromPed(data.entity)) end,
    },
    {
        name = 'noir_police:field:jail',
        icon = 'fa-solid fa-building-lock',
        label = locale('target.jail'),
        distance = 2.0,
        canInteract = function(entity)
            local id = Util.serverIdFromPed(entity)
            return id and Util.isCuffed(id) and can()
        end,
        onSelect = function() TriggerEvent('noir_police:client:radial', 'jail') end,
    },
    {
        name = 'noir_police:field:anklet',
        icon = 'fa-solid fa-satellite-dish',
        label = locale('target.anklet'),
        distance = 1.5,
        canInteract = function(entity)
            local id = Util.serverIdFromPed(entity)
            return id and Util.isCuffed(id) and can('anklet')
        end,
        onSelect = function(data) anklet(Util.serverIdFromPed(data.entity)) end,
    },
})

-- Menu da polícia ------------------------------------------------------------------

local function interdict()
    local input = lib.inputDialog(locale('interdict.title'), {
        { type = 'input', label = locale('interdict.label'), required = true, min = 3, max = 40 },
        { type = 'slider', label = locale('interdict.radius'), min = 10, max = math.floor(Config.interdict.maxRadius), default = 50, step = 10 },
        { type = 'number', label = locale('interdict.minutes'), min = 1, max = Config.interdict.maxMinutes, default = 15, required = true },
    })
    if not input then return end
    local result = lib.callback.await('noir_police:server:interdict', false, input[2], input[3], input[1])
    if not result or not result.ok then return fail(result) end
end

local function removeInterdict()
    local result = lib.callback.await('noir_police:server:removeInterdict', false)
    if not result or not result.ok then return fail(result) end
    Integrations.notify(locale('success.interdict_removed', result.count), 'success')
end

local function unitStatus()
    local options = {}
    for _, entry in ipairs(Config.unitStatuses) do options[#options + 1] = { value = entry.value, label = entry.label } end
    local input = lib.inputDialog(locale('status.title'), {
        { type = 'select', label = locale('status.status'), options = options, required = true },
    })
    if not input then return end
    local result = lib.callback.await('noir_police:server:unitStatus', false, input[1])
    if not result or not result.ok then return fail(result) end
end

local function meeting()
    local input = lib.inputDialog(locale('meeting.title'), {
        { type = 'input', label = locale('meeting.reason'), required = true, min = 3, max = 120 },
        { type = 'input', label = locale('meeting.radio'), max = 12 },
    })
    if not input then return end
    local result = lib.callback.await('noir_police:server:meeting', false, input[1], input[2])
    if not result or not result.ok then return fail(result) end
end

local function officerDown()
    TriggerServerEvent('noir_police:server:officerDown')
    Integrations.notify(locale('success.officer_down_sent'), 'success')
end

local function openMenu()
    if not Departments.isOnDutyPolice(job()) then return end
    lib.registerContext({
        id = 'noir_police_menu',
        title = locale('menu.title'),
        options = {
            { title = locale('menu.unit_status'), icon = 'fa-solid fa-signal', onSelect = unitStatus, disabled = not can('unitStatus') },
            { title = locale('menu.interdict'), icon = 'fa-solid fa-ban', onSelect = interdict, disabled = not can('interdict') },
            { title = locale('menu.remove_interdict'), icon = 'fa-solid fa-circle-xmark', onSelect = removeInterdict },
            { title = locale('menu.meeting'), icon = 'fa-solid fa-people-group', onSelect = meeting, disabled = not can('meeting') },
            { title = locale('menu.clear_evidence'), icon = 'fa-solid fa-broom', onSelect = Evidence.clearArea },
            { title = locale('menu.officer_down'), icon = 'fa-solid fa-triangle-exclamation', onSelect = officerDown },
        },
    })
    lib.showContext('noir_police_menu')
end

lib.addKeybind({
    name = 'noir_police_menu',
    description = locale('keybind.police_menu'),
    defaultKey = 'F6',
    onPressed = openMenu,
})

AddEventHandler('noir_police:client:openMenu', openMenu)
AddEventHandler('noir_police:client:officerDown', function()
    if Departments.isOnDutyPolice(job()) or Departments.isOnDutyEms(job()) then officerDown() end
end)

-- Recebidos ------------------------------------------------------------------------

RegisterNetEvent('noir_police:client:interdict', function(area)
    if source ~= 65535 or type(area) ~= 'table' then return end
    if interdictBlips[area.id] then return end
    local radius = AddBlipForRadius(area.x, area.y, area.z, area.radius)
    SetBlipColour(radius, Config.interdict.color)
    SetBlipAlpha(radius, 90)
    local center = AddBlipForCoord(area.x, area.y, area.z)
    SetBlipSprite(center, 526)
    SetBlipColour(center, Config.interdict.color)
    SetBlipScale(center, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('interdict.blip', area.label))
    EndTextCommandSetBlipName(center)
    interdictBlips[area.id] = { radius, center }
    Integrations.notify(locale('interdict.notice', area.label), 'warning')
end)

RegisterNetEvent('noir_police:client:interdictRemoved', function(id)
    if source ~= 65535 then return end
    local blips = interdictBlips[id]
    if not blips then return end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    interdictBlips[id] = nil
end)

RegisterNetEvent('noir_police:client:unitStatus', function(payload)
    if source ~= 65535 or type(payload) ~= 'table' then return end
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(payload.x, payload.y, payload.z))
    Integrations.notify(locale('status.notice', payload.unit, payload.status, street), 'inform')
end)

RegisterNetEvent('noir_police:client:meeting', function(payload)
    if source ~= 65535 or type(payload) ~= 'table' then return end
    Integrations.notify(locale('meeting.notice', payload.from, payload.reason, payload.radio), 'warning')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for _, blips in pairs(interdictBlips) do
        for _, blip in ipairs(blips) do RemoveBlip(blip) end
    end
end)
