---Delegacia: armário de roupa, frota e sala de evidências.

local Config = require 'config.shared'
local Outfits = require 'config.outfits'
local Departments = require 'shared.departments'
local Integrations = require 'client.integrations'
local Util = require 'client.util'
local Layout = require 'client.layout'

local zones = {}

local function job() return Integrations.getJob() end

local function servesMe(station)
    local current = job()
    return Departments.isPolice(current) and Departments.stationServes(station, current.name)
end

local function onDutyHere(station, action)
    local current = job()
    return Departments.can(current, action) and Departments.stationServes(station, current.name)
end

local function fail(result)
    Integrations.notify(Util.errorText(result and result.code), 'error')
end

-- Armário --------------------------------------------------------------------------

local function applyOutfit(outfit)
    local ped = cache.ped
    local model = GetEntityModel(ped)
    local variant = model == `mp_m_freemode_01` and outfit.male or model == `mp_f_freemode_01` and outfit.female
    if not variant then return Integrations.notify(Util.errorText('unsupported_model'), 'error') end
    for component, value in pairs(variant.components or {}) do
        SetPedComponentVariation(ped, component, value[1], value[2], 0)
    end
    for prop, value in pairs(variant.props or {}) do
        if value[1] < 0 then ClearPedProp(ped, prop) else SetPedPropIndex(ped, prop, value[1], value[2], true) end
    end
end

local function canWear(outfit)
    local current = job()
    if outfit.subunit then
        -- Uniforme é visual: a lista por citizenId vale só no servidor; aqui basta a grade.
        return Departments.inSubunit(current, nil, outfit.subunit)
    end
    return (tonumber(current and current.grade) or 0) >= (outfit.grade or 0)
end

local function openLocker()
    local current = job()
    local options = {
        {
            title = locale('locker.civilian'),
            icon = 'fa-solid fa-shirt',
            onSelect = Integrations.reloadSavedAppearance,
        },
    }
    for _, outfit in ipairs(Outfits[current.name] or {}) do
        options[#options + 1] = {
            title = outfit.label,
            icon = 'fa-solid fa-user-shield',
            disabled = not canWear(outfit),
            onSelect = function() applyOutfit(outfit) end,
        }
    end
    lib.registerContext({ id = 'noir_police_locker', title = locale('locker.title'), options = options })
    lib.showContext('noir_police_locker')
end

-- Frota ----------------------------------------------------------------------------

local function openGarage(station, garageIndex, garage)
    local current = job()
    local options = {}
    for _, entry in ipairs(Config.fleet[garage.type] or {}) do
        if Departments.fleetAllows(entry, current) then
            options[#options + 1] = {
                title = entry.label,
                icon = garage.type == 'air' and 'fa-solid fa-helicopter' or 'fa-solid fa-car-side',
                onSelect = function()
                    local result = lib.callback.await('noir_police:server:fleetSpawn', false, station.id, garageIndex, entry.model)
                    if not result or not result.ok then return fail(result) end
                end,
            }
        end
    end
    if #options == 0 then options[1] = { title = locale('garage.empty'), disabled = true } end
    lib.registerContext({ id = 'noir_police_garage', title = locale('garage.title'), options = options })
    lib.showContext('noir_police_garage')
end

local function storeVehicle()
    local vehicle = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 8.0, false)
    if not vehicle or not Entity(vehicle).state.noirPoliceFleet then
        return Integrations.notify(Util.errorText('not_fleet'), 'error')
    end
    if cache.vehicle then
        TaskLeaveVehicle(cache.ped, vehicle, 0)
        Wait(1500)
    end
    local result = lib.callback.await('noir_police:server:fleetStore', false, VehToNet(vehicle))
    if not result or not result.ok then return fail(result) end
    Integrations.notify(locale('success.vehicle_stored'), 'success')
end

-- Sala de evidências ----------------------------------------------------------------

local function deposit()
    local prepared = lib.callback.await('noir_police:server:seizurePrepare', false)
    if not prepared or not prepared.ok then return fail(prepared) end
    if #prepared.boxes == 0 then return Integrations.notify(Util.errorText('no_box'), 'error') end

    local boxOptions = {}
    for _, box in ipairs(prepared.boxes) do
        boxOptions[#boxOptions + 1] = {
            value = tostring(box.slot),
            label = locale('seizure.box_option', box.tag or locale('seizure.box_untagged'), box.items),
        }
    end
    local targetOptions = { { value = '', label = locale('seizure.unknown_target') } }
    for _, target in ipairs(prepared.targets) do
        targetOptions[#targetOptions + 1] = { value = target.citizenId, label = target.name }
    end

    local input = lib.inputDialog(locale('seizure.deposit_title'), {
        { type = 'select', label = locale('seizure.box'), options = boxOptions, required = true, default = boxOptions[1].value },
        { type = 'select', label = locale('seizure.target'), options = targetOptions, default = targetOptions[#targetOptions > 1 and 2 or 1].value },
        { type = 'textarea', label = locale('seizure.reason'), description = locale('seizure.reason_help'), max = 200 },
    })
    if not input then return end

    local target = input[2] ~= '' and input[2] or nil
    local result = lib.callback.await('noir_police:server:seizureDeposit', false, tonumber(input[1]), target, input[3])
    if not result or not result.ok then return fail(result) end
    Integrations.notify(locale('success.deposited', result.depositId, result.matched), 'success')
end

local function showPending()
    local prepared = lib.callback.await('noir_police:server:seizurePrepare', false)
    if not prepared or not prepared.ok then return fail(prepared) end
    local lines = {}
    for _, entry in ipairs(prepared.pending) do lines[#lines + 1] = ('%dx %s'):format(entry.count, entry.item) end
    lib.alertDialog({
        header = locale('seizure.pending_title'),
        content = #lines > 0 and table.concat(lines, '  \n') or locale('seizure.no_pending'),
        centered = true,
    })
end

local function manageDeposits()
    local result = lib.callback.await('noir_police:server:listDeposits', false)
    if not result or not result.ok then return fail(result) end
    local options = {}
    for _, entry in ipairs(result.deposits) do
        options[#options + 1] = {
            title = ('#%d · %s'):format(entry.id, entry.target or locale('seizure.unknown_target')),
            description = ('%s\n%s · %s'):format(entry.summary, entry.officer, entry.reason or '-'),
            icon = 'fa-solid fa-box-archive',
            onSelect = function()
                local choice = lib.inputDialog(('#%d'):format(entry.id), {
                    { type = 'select', label = locale('seizure.action'), required = true, options = {
                        { value = 'destroy', label = locale('seizure.action_destroy') },
                        { value = 'return', label = locale('seizure.action_return') },
                        { value = 'incorporate', label = locale('seizure.action_incorporate') },
                    } },
                })
                if not choice then return end
                local alert = lib.alertDialog({
                    header = locale('seizure.confirm_title'),
                    content = locale('seizure.confirm_' .. choice[1], entry.id),
                    centered = true,
                    cancel = true,
                })
                if alert ~= 'confirm' then return end
                local resolved = lib.callback.await('noir_police:server:resolveDeposit', false, entry.id, choice[1])
                if not resolved or not resolved.ok then return fail(resolved) end
                Integrations.notify(locale('success.deposit_resolved'), 'success')
            end,
        }
    end
    if #options == 0 then options[1] = { title = locale('seizure.no_deposits'), disabled = true } end
    lib.registerContext({ id = 'noir_police_deposits', title = locale('seizure.manage_title'), options = options })
    lib.showContext('noir_police_deposits')
end

local function openStash()
    local result = lib.callback.await('noir_police:server:openEvidenceStash', false)
    if not result or not result.ok then return fail(result) end
end

-- Pontos ---------------------------------------------------------------------------

local function clearZones()
    for _, zone in ipairs(zones) do Integrations.removeZone(zone) end
    zones = {}
end

local function buildZones()
    clearZones()
    for _, station in ipairs(Layout.stations()) do
        for index, point in ipairs(station.lockers or {}) do
            zones[#zones + 1] = Integrations.addSphereZone({
                coords = point,
                radius = 1.0,
                options = {
                    {
                        name = ('noir_police:locker:%s:%d'):format(station.id, index),
                        icon = 'fa-solid fa-shirt',
                        label = locale('target.locker'),
                        canInteract = function() return servesMe(station) end,
                        onSelect = openLocker,
                    },
                },
            })
        end

        for index, garage in ipairs(station.garages or {}) do
            zones[#zones + 1] = Integrations.addSphereZone({
                coords = garage.point,
                radius = 1.5,
                options = {
                    {
                        name = ('noir_police:garage:%s:%d'):format(station.id, index),
                        icon = garage.type == 'air' and 'fa-solid fa-helicopter' or 'fa-solid fa-warehouse',
                        label = locale(garage.type == 'air' and 'target.heli_garage' or 'target.garage'),
                        canInteract = function() return onDutyHere(station) end,
                        onSelect = function() openGarage(station, index, garage) end,
                    },
                    {
                        name = ('noir_police:garage_store:%s:%d'):format(station.id, index),
                        icon = 'fa-solid fa-square-parking',
                        label = locale('target.store_vehicle'),
                        canInteract = function() return onDutyHere(station) end,
                        onSelect = storeVehicle,
                    },
                },
            })
        end

        if station.lab then
            zones[#zones + 1] = Integrations.addSphereZone({
                coords = station.lab.coords,
                radius = station.lab.radius,
                options = {
                    {
                        name = ('noir_police:dna_lab:%s'):format(station.id),
                        icon = 'fa-solid fa-dna',
                        label = locale('target.dna_lab'),
                        canInteract = function() return onDutyHere(station, 'dnaLab') end,
                        onSelect = analyzeDna,
                    },
                },
            })
        end

        if station.evidence then
            zones[#zones + 1] = Integrations.addSphereZone({
                coords = station.evidence.coords,
                radius = station.evidence.radius,
                options = {
                    {
                        name = ('noir_police:evidence_deposit:%s'):format(station.id),
                        icon = 'fa-solid fa-box',
                        label = locale('target.deposit_box'),
                        items = Config.items.seizedBox,
                        canInteract = function() return onDutyHere(station, 'seize') end,
                        onSelect = deposit,
                    },
                    {
                        name = ('noir_police:evidence_pending:%s'):format(station.id),
                        icon = 'fa-solid fa-list-check',
                        label = locale('target.my_pending'),
                        canInteract = function() return onDutyHere(station, 'seize') end,
                        onSelect = showPending,
                    },
                    {
                        name = ('noir_police:evidence_stash:%s'):format(station.id),
                        icon = 'fa-solid fa-box-archive',
                        label = locale('target.evidence_stash'),
                        canInteract = function() return onDutyHere(station, 'evidenceStash') end,
                        onSelect = openStash,
                    },
                    {
                        name = ('noir_police:evidence_manage:%s'):format(station.id),
                        icon = 'fa-solid fa-scale-balanced',
                        label = locale('target.manage_evidence'),
                        canInteract = function() return onDutyHere(station, 'evidenceManage') end,
                        onSelect = manageDeposits,
                    },
                },
            })
        end
    end
end

buildZones()
AddEventHandler('noir_police:client:layoutChanged', function(kind)
    if kind == 'stations' then buildZones() end
end)

-- Bancada de DNA -------------------------------------------------------------------

local function analyzeDna()
    local prepared = lib.callback.await('noir_police:server:labSamples', false)
    if not prepared or not prepared.ok then return fail(prepared) end
    if #prepared.samples == 0 then return Integrations.notify(Util.errorText('no_dna_samples'), 'error') end

    local options = {}
    for _, sample in ipairs(prepared.samples) do
        options[#options + 1] = { value = tostring(sample.slot), label = sample.label }
    end
    local second = { { value = '', label = locale('lab.search_bank') } }
    for _, option in ipairs(options) do second[#second + 1] = option end

    local input = lib.inputDialog(locale('lab.title'), {
        { type = 'select', label = locale('lab.sample'), options = options, required = true, default = options[1].value },
        { type = 'select', label = locale('lab.compare_with'), description = locale('lab.compare_help'), options = second, default = '' },
    })
    if not input then return end

    local done = lib.progressBar({
        duration = 6000,
        label = locale('progress.analyzing_dna'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@amb@business@coc@coc_unpack_cut@', clip = 'fullcut_cycle_v6_cokecutter' },
    })
    if not done then return end

    -- A chave da amostra é opaca ("inventário:slot"); o servidor remonta a lista.
    local result = lib.callback.await('noir_police:server:labAnalyze', false, input[1],
        input[2] ~= '' and input[2] or nil)
    if not result or not result.ok then return fail(result) end

    local content
    if result.mode == 'compare' then
        content = locale(result.match and 'lab.match' or 'lab.no_match')
    else
        content = result.found and locale('lab.found', result.name) or locale('lab.not_found')
    end
    lib.alertDialog({ header = locale('lab.title'), content = content, centered = true })
end

-- Etiqueta da caixa (botão do item no ox_inventory) --------------------------------

exports('labelSeizedBox', function(slot)
    local input = lib.inputDialog(locale('seizure.label_title'), {
        { type = 'input', label = locale('seizure.label_field'), required = true, max = 40 },
    })
    if not input then return end
    local result = lib.callback.await('noir_police:server:labelBox', false, slot, input[1])
    if not result or not result.ok then return fail(result) end
end)

-- Captura de uniforme (admin) -------------------------------------------------------

RegisterCommand('noir_police_outfit', function()
    local ped = cache.ped
    local lines = { '{', '    components = {' }
    for _, component in ipairs({ 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do
        lines[#lines + 1] = ('        [%d] = { %d, %d },'):format(component,
            GetPedDrawableVariation(ped, component), GetPedTextureVariation(ped, component))
    end
    lines[#lines + 1] = '    },'
    lines[#lines + 1] = '    props = {'
    for _, prop in ipairs({ 0, 1 }) do
        lines[#lines + 1] = ('        [%d] = { %d, %d },'):format(prop, GetPedPropIndex(ped, prop), GetPedPropTextureIndex(ped, prop))
    end
    lines[#lines + 1] = '    },'
    lines[#lines + 1] = '}'
    lib.setClipboard(table.concat(lines, '\n'))
    Integrations.notify(locale('success.outfit_copied'), 'success')
end, true)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    clearZones()
end)
