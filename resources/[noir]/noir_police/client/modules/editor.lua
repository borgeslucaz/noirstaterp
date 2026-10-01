---Editor de posições em jogo (/policiaeditor): delegacias (blip, serviço, armário,
---sala de evidências, leitor de digital, mesa de câmeras, garagens e vagas), radares,
---câmeras de segurança e sensores do shotspotter.
---
---Cada alteração é salva na hora: o servidor valida o tipo inteiro e publica. Se ele
---recusar, o rascunho volta para o que está salvo.

local Config = require 'config.shared'
local Integrations = require 'client.integrations'
local Util = require 'client.util'
local Placement = require 'client.placement'

local layout = nil
local showMarkers = false

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

local function save(kind)
    local result = lib.callback.await('noir_police:server:editorSave', false, kind, layout[kind])
    if result and result.ok then
        layout = result.snapshot
        Integrations.notify(locale('editor.saved'), 'success')
        return true
    end
    Integrations.notify(Util.errorText(result and result.code), 'error')
    return false
end

local function reset(kind)
    local alert = lib.alertDialog({ header = locale('editor.reset_title'), content = locale('editor.reset_confirm'),
        centered = true, cancel = true })
    if alert ~= 'confirm' then return end
    local result = lib.callback.await('noir_police:server:editorReset', false, kind)
    if result and result.ok then
        layout = result.snapshot
        Integrations.notify(locale('editor.saved'), 'success')
    else
        Integrations.notify(Util.errorText(result and result.code), 'error')
    end
end

---Roda uma alteração no rascunho e salva; se o servidor recusar, desfaz.
local function change(kind, fn)
    local backup = copy(layout[kind])
    if fn(layout[kind]) == false then return end
    if not save(kind) then layout[kind] = backup end
end

local function teleport(p)
    if p then SetEntityCoords(cache.ped, p.x, p.y, p.z, false, false, false, false) end
end

local function fmt(p)
    return p and ('%.1f, %.1f, %.1f'):format(p.x, p.y, p.z) or locale('editor.not_set')
end

local open

-- Listas de pontos (serviço, armário, sensores) ------------------------------------

local function pointList(kind, title, getList, mode, back)
    local list = getList()
    local options = {
        {
            title = locale('editor.add_point'),
            icon = 'fa-solid fa-plus',
            onSelect = function()
                local p = Placement.run(mode)
                if p then change(kind, function() table.insert(getList(), { x = p.x, y = p.y, z = p.z }) end) end
                pointList(kind, title, getList, mode, back)
            end,
        },
    }
    for index, p in ipairs(list) do
        options[#options + 1] = {
            title = ('#%d  %s'):format(index, fmt(p)),
            icon = 'fa-solid fa-location-dot',
            onSelect = function()
                lib.registerContext({
                    id = 'noir_police_editor_point',
                    title = ('%s #%d'):format(title, index),
                    menu = 'noir_police_editor_list',
                    options = {
                        { title = locale('editor.reposition'), icon = 'fa-solid fa-crosshairs', onSelect = function()
                            local moved = Placement.run(mode, p)
                            if moved then change(kind, function() getList()[index] = { x = moved.x, y = moved.y, z = moved.z } end) end
                            pointList(kind, title, getList, mode, back)
                        end },
                        { title = locale('editor.go_to'), icon = 'fa-solid fa-person-walking-arrow-right', onSelect = function() teleport(p) end },
                        { title = locale('editor.remove'), icon = 'fa-solid fa-trash', onSelect = function()
                            change(kind, function() table.remove(getList(), index) end)
                            pointList(kind, title, getList, mode, back)
                        end },
                    },
                })
                lib.showContext('noir_police_editor_point')
            end,
        }
    end
    lib.registerContext({ id = 'noir_police_editor_list', title = title, menu = back, options = options })
    lib.showContext('noir_police_editor_list')
end

-- Delegacias -----------------------------------------------------------------------

local openStation

local function areaMenu(stationIndex, key, title)
    local station = layout.stations[stationIndex]
    local area = station[key]
    lib.registerContext({
        id = 'noir_police_editor_area',
        title = title,
        menu = 'noir_police_editor_station',
        options = {
            { title = locale('editor.position'), description = fmt(area), icon = 'fa-solid fa-crosshairs', onSelect = function()
                local p = Placement.run('point', area)
                if p then
                    change('stations', function(list)
                        list[stationIndex][key] = { x = p.x, y = p.y, z = p.z, radius = area and area.radius or 1.5 }
                    end)
                end
                areaMenu(stationIndex, key, title)
            end },
            { title = locale('editor.radius'), description = area and tostring(area.radius) or '-', icon = 'fa-solid fa-circle',
                disabled = not area, onSelect = function()
                    local input = lib.inputDialog(title, {
                        { type = 'slider', label = locale('editor.radius'), min = 0.5, max = 10.0, step = 0.5, default = area.radius },
                    })
                    if input then change('stations', function(list) list[stationIndex][key].radius = input[1] end) end
                    areaMenu(stationIndex, key, title)
                end },
            { title = locale('editor.go_to'), icon = 'fa-solid fa-person-walking-arrow-right', disabled = not area,
                onSelect = function() teleport(area) end },
            { title = locale('editor.remove'), icon = 'fa-solid fa-trash', disabled = not area, onSelect = function()
                change('stations', function(list) list[stationIndex][key] = nil end)
                areaMenu(stationIndex, key, title)
            end },
        },
    })
    lib.showContext('noir_police_editor_area')
end

local function garageMenu(stationIndex, garageIndex)
    local garage = layout.stations[stationIndex].garages[garageIndex]
    local options = {
        { title = locale('editor.garage_point'), description = fmt(garage.point), icon = 'fa-solid fa-crosshairs', onSelect = function()
            local p = Placement.run('point', garage.point)
            if p then change('stations', function(list)
                list[stationIndex].garages[garageIndex].point = { x = p.x, y = p.y, z = p.z }
            end) end
            garageMenu(stationIndex, garageIndex)
        end },
        { title = locale('editor.add_spawn'), icon = 'fa-solid fa-plus', onSelect = function()
            local p = Placement.run('vehicle')
            if p then change('stations', function(list)
                table.insert(list[stationIndex].garages[garageIndex].spawns, p)
            end) end
            garageMenu(stationIndex, garageIndex)
        end },
    }
    for index, spawn in ipairs(garage.spawns) do
        options[#options + 1] = {
            title = ('%s #%d  %s'):format(locale('editor.spawn'), index, fmt(spawn)),
            icon = 'fa-solid fa-car',
            onSelect = function()
                local p = Placement.run('vehicle', spawn)
                if p then change('stations', function(list)
                    list[stationIndex].garages[garageIndex].spawns[index] = p
                end) end
                garageMenu(stationIndex, garageIndex)
            end,
        }
        options[#options + 1] = {
            title = ('   %s #%d'):format(locale('editor.remove_spawn'), index),
            icon = 'fa-solid fa-trash',
            disabled = #garage.spawns <= 1,
            onSelect = function()
                change('stations', function(list) table.remove(list[stationIndex].garages[garageIndex].spawns, index) end)
                garageMenu(stationIndex, garageIndex)
            end,
        }
    end
    options[#options + 1] = { title = locale('editor.go_to'), icon = 'fa-solid fa-person-walking-arrow-right',
        onSelect = function() teleport(garage.point) end }
    options[#options + 1] = { title = locale('editor.remove_garage'), icon = 'fa-solid fa-trash', onSelect = function()
        change('stations', function(list) table.remove(list[stationIndex].garages, garageIndex) end)
        openStation(stationIndex)
    end }
    lib.registerContext({
        id = 'noir_police_editor_garage',
        title = ('%s (%s)'):format(locale('editor.garage'), garage.type == 'air' and locale('editor.air') or locale('editor.car')),
        menu = 'noir_police_editor_station',
        options = options,
    })
    lib.showContext('noir_police_editor_garage')
end

local function addGarage(stationIndex)
    local input = lib.inputDialog(locale('editor.new_garage'), {
        { type = 'select', label = locale('editor.type'), required = true, default = 'car', options = {
            { value = 'car', label = locale('editor.car') }, { value = 'air', label = locale('editor.air') },
        } },
    })
    if not input then return openStation(stationIndex) end
    Integrations.notify(locale('editor.place_garage_point'), 'inform')
    local point = Placement.run('point')
    if not point then return openStation(stationIndex) end
    Integrations.notify(locale('editor.place_first_spawn'), 'inform')
    local spawn = Placement.run('vehicle')
    if not spawn then return openStation(stationIndex) end
    change('stations', function(list)
        list[stationIndex].garages = list[stationIndex].garages or {}
        table.insert(list[stationIndex].garages, { type = input[1], point = { x = point.x, y = point.y, z = point.z }, spawns = { spawn } })
    end)
    openStation(stationIndex)
end

local function editStationInfo(stationIndex)
    local station = layout.stations[stationIndex]
    local deptOptions = {}
    for name, department in pairs(Config.departments) do deptOptions[#deptOptions + 1] = { value = name, label = department.label } end
    local input = lib.inputDialog(locale('editor.station'), {
        { type = 'input', label = locale('editor.name'), required = true, default = station.label, max = 60 },
        { type = 'multi-select', label = locale('editor.departments'), options = deptOptions, required = true, default = station.departments },
        { type = 'number', label = locale('editor.blip_sprite'), default = station.blip and station.blip.sprite or 60, min = 1, max = 900 },
        { type = 'number', label = locale('editor.blip_color'), default = station.blip and station.blip.color or 29, min = 0, max = 85 },
    })
    if not input then return openStation(stationIndex) end
    change('stations', function(list)
        local target = list[stationIndex]
        target.label, target.departments = input[1], input[2]
        if target.blip then target.blip.sprite, target.blip.color = input[3], input[4] end
    end)
    openStation(stationIndex)
end

openStation = function(stationIndex)
    local station = layout.stations[stationIndex]
    if not station then return open() end
    local function stationList(key) return function() return layout.stations[stationIndex][key] end end
    local options = {
        { title = locale('editor.station_info'), description = table.concat(station.departments, ', '), icon = 'fa-solid fa-pen', onSelect = function() editStationInfo(stationIndex) end },
        { title = locale('editor.blip'), description = fmt(station.blip), icon = 'fa-solid fa-map-pin', onSelect = function()
            local p = Placement.run('point', station.blip)
            if p then change('stations', function(list)
                local old = list[stationIndex].blip or {}
                list[stationIndex].blip = { x = p.x, y = p.y, z = p.z, sprite = old.sprite or 60, color = old.color or 29, scale = old.scale or 0.8 }
            end) end
            openStation(stationIndex)
        end },
        { title = locale('editor.duty_points'), description = ('%d'):format(#station.duty), icon = 'fa-solid fa-clipboard-user',
            onSelect = function() pointList('stations', locale('editor.duty_points'), stationList('duty'), 'point', 'noir_police_editor_station') end },
        { title = locale('editor.lockers'), description = ('%d'):format(#station.lockers), icon = 'fa-solid fa-shirt',
            onSelect = function() pointList('stations', locale('editor.lockers'), stationList('lockers'), 'point', 'noir_police_editor_station') end },
        { title = locale('editor.evidence_room'), description = fmt(station.evidence), icon = 'fa-solid fa-box-archive',
            onSelect = function() areaMenu(stationIndex, 'evidence', locale('editor.evidence_room')) end },
        { title = locale('editor.fingerprint'), description = fmt(station.fingerprint), icon = 'fa-solid fa-fingerprint',
            onSelect = function() areaMenu(stationIndex, 'fingerprint', locale('editor.fingerprint')) end },
        { title = locale('editor.camera_desk'), description = fmt(station.cameras), icon = 'fa-solid fa-video',
            onSelect = function() areaMenu(stationIndex, 'cameras', locale('editor.camera_desk')) end },
        { title = locale('editor.dna_lab'), description = fmt(station.lab), icon = 'fa-solid fa-dna',
            onSelect = function() areaMenu(stationIndex, 'lab', locale('editor.dna_lab')) end },
        { title = locale('editor.reception'), description = fmt(station.reception), icon = 'fa-solid fa-box-open',
            onSelect = function() areaMenu(stationIndex, 'reception', locale('editor.reception')) end },
        { title = locale('editor.new_garage'), icon = 'fa-solid fa-plus', onSelect = function() addGarage(stationIndex) end },
    }
    for index, garage in ipairs(station.garages or {}) do
        options[#options + 1] = {
            title = ('%s #%d (%s)'):format(locale('editor.garage'), index, garage.type == 'air' and locale('editor.air') or locale('editor.car')),
            description = ('%s · %d %s'):format(fmt(garage.point), #garage.spawns, locale('editor.spawns')),
            icon = garage.type == 'air' and 'fa-solid fa-helicopter' or 'fa-solid fa-warehouse',
            onSelect = function() garageMenu(stationIndex, index) end,
        }
    end
    options[#options + 1] = { title = locale('editor.remove_station'), icon = 'fa-solid fa-trash', onSelect = function()
        local alert = lib.alertDialog({ header = station.label, content = locale('editor.remove_station_confirm'), centered = true, cancel = true })
        if alert ~= 'confirm' then return openStation(stationIndex) end
        change('stations', function(list) table.remove(list, stationIndex) end)
        open()
    end }
    lib.registerContext({ id = 'noir_police_editor_station', title = station.label, menu = 'noir_police_editor_stations', options = options })
    lib.showContext('noir_police_editor_station')
end

local function openStations()
    local options = {
        { title = locale('editor.new_station'), icon = 'fa-solid fa-plus', onSelect = function()
            local input = lib.inputDialog(locale('editor.new_station'), {
                { type = 'input', label = locale('editor.id'), description = locale('editor.id_help'), required = true, max = 32 },
                { type = 'input', label = locale('editor.name'), required = true, max = 60 },
            })
            if not input then return openStations() end
            local coords = GetEntityCoords(cache.ped)
            change('stations', function(list)
                table.insert(list, {
                    id = input[1]:lower():gsub('[^%w_]', '_'), label = input[2], departments = { 'police' },
                    blip = { x = coords.x, y = coords.y, z = coords.z, sprite = 60, color = 29, scale = 0.8 },
                    duty = {}, lockers = {}, garages = {},
                })
            end)
            openStation(#layout.stations)
        end },
    }
    for index, station in ipairs(layout.stations) do
        options[#options + 1] = { title = station.label, description = table.concat(station.departments, ', '),
            icon = 'fa-solid fa-building-shield', onSelect = function() openStation(index) end }
    end
    options[#options + 1] = { title = locale('editor.reset'), icon = 'fa-solid fa-rotate-left', onSelect = function() reset('stations') open() end }
    lib.registerContext({ id = 'noir_police_editor_stations', title = locale('editor.stations'), menu = 'noir_police_editor', options = options })
    lib.showContext('noir_police_editor_stations')
end

-- Radares --------------------------------------------------------------------------

local function openRadars()
    local options = {
        { title = locale('editor.add_radar'), icon = 'fa-solid fa-plus', onSelect = function()
            local p = Placement.run('heading')
            if p then
                local input = lib.inputDialog(locale('editor.radar'), {
                    { type = 'number', label = locale('editor.speed_limit'), required = true, default = 80, min = 10, max = 300 },
                })
                if input then change('radars', function(list) p.speedLimit = input[1] table.insert(list, p) end) end
            end
            openRadars()
        end },
    }
    for index, radar in ipairs(layout.radars) do
        options[#options + 1] = {
            title = ('#%d  %d %s'):format(index, radar.speedLimit, Config.radars.useMph and 'mph' or 'km/h'),
            description = fmt(radar), icon = 'fa-solid fa-gauge-high',
            onSelect = function()
                lib.registerContext({
                    id = 'noir_police_editor_radar', title = ('%s #%d'):format(locale('editor.radar'), index), menu = 'noir_police_editor_radars',
                    options = {
                        { title = locale('editor.reposition'), icon = 'fa-solid fa-crosshairs', onSelect = function()
                            local p = Placement.run('heading', radar)
                            if p then change('radars', function(list) p.speedLimit = radar.speedLimit list[index] = p end) end
                            openRadars()
                        end },
                        { title = locale('editor.speed_limit'), icon = 'fa-solid fa-gauge', onSelect = function()
                            local input = lib.inputDialog(locale('editor.radar'), {
                                { type = 'number', label = locale('editor.speed_limit'), required = true, default = radar.speedLimit, min = 10, max = 300 },
                            })
                            if input then change('radars', function(list) list[index].speedLimit = input[1] end) end
                            openRadars()
                        end },
                        { title = locale('editor.go_to'), icon = 'fa-solid fa-person-walking-arrow-right', onSelect = function() teleport(radar) end },
                        { title = locale('editor.remove'), icon = 'fa-solid fa-trash', onSelect = function()
                            change('radars', function(list) table.remove(list, index) end)
                            openRadars()
                        end },
                    },
                })
                lib.showContext('noir_police_editor_radar')
            end,
        }
    end
    options[#options + 1] = { title = locale('editor.reset'), icon = 'fa-solid fa-rotate-left', onSelect = function() reset('radars') open() end }
    lib.registerContext({ id = 'noir_police_editor_radars', title = locale('editor.radars'), menu = 'noir_police_editor', options = options })
    lib.showContext('noir_police_editor_radars')
end

-- Câmeras de segurança -------------------------------------------------------------

local previewCam = 0

local function stopPreview()
    if previewCam ~= 0 then
        DestroyCam(previewCam, false)
        RenderScriptCams(false, false, 0, true, true)
        ClearFocus()
        previewCam = 0
    end
end

local function preview(camera)
    stopPreview()
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, camera.x, camera.y, camera.z)
    SetCamRot(previewCam, camera.rx, camera.ry, camera.rz, 2)
    SetFocusArea(camera.x, camera.y, camera.z, 0.0, 0.0, 0.0)
    RenderScriptCams(true, false, 0, true, true)
    lib.showTextUI(locale('editor.preview_help'), { position = 'left-center' })
    while previewCam ~= 0 do
        if IsControlJustReleased(0, 177) or IsControlJustReleased(0, 191) then break end
        Wait(0)
    end
    lib.hideTextUI()
    stopPreview()
end

local function openCameras()
    local options = {
        { title = locale('editor.add_camera'), description = locale('editor.camera_capture_help'), icon = 'fa-solid fa-plus', onSelect = function()
            local input = lib.inputDialog(locale('editor.camera'), {
                { type = 'input', label = locale('editor.name'), required = true, max = 60 },
                { type = 'checkbox', label = locale('editor.can_rotate') },
            })
            if input then
                local shot = Placement.captureCamera()
                shot.label, shot.canRotate = input[1], input[2] == true
                change('cameras', function(list) table.insert(list, shot) end)
            end
            openCameras()
        end },
    }
    for index, camera in ipairs(layout.cameras) do
        options[#options + 1] = {
            title = ('#%d  %s'):format(index, camera.label), description = fmt(camera), icon = 'fa-solid fa-video',
            onSelect = function()
                lib.registerContext({
                    id = 'noir_police_editor_camera', title = camera.label, menu = 'noir_police_editor_cameras',
                    options = {
                        { title = locale('editor.preview'), icon = 'fa-solid fa-eye', onSelect = function() preview(camera) openCameras() end },
                        { title = locale('editor.recapture'), description = locale('editor.camera_capture_help'), icon = 'fa-solid fa-camera', onSelect = function()
                            local shot = Placement.captureCamera()
                            change('cameras', function(list)
                                shot.label, shot.canRotate = camera.label, camera.canRotate
                                list[index] = shot
                            end)
                            openCameras()
                        end },
                        { title = locale('editor.go_to'), icon = 'fa-solid fa-person-walking-arrow-right', onSelect = function() teleport(camera) end },
                        { title = locale('editor.remove'), icon = 'fa-solid fa-trash', onSelect = function()
                            change('cameras', function(list) table.remove(list, index) end)
                            openCameras()
                        end },
                    },
                })
                lib.showContext('noir_police_editor_camera')
            end,
        }
    end
    options[#options + 1] = { title = locale('editor.reset'), icon = 'fa-solid fa-rotate-left', onSelect = function() reset('cameras') open() end }
    lib.registerContext({ id = 'noir_police_editor_cameras', title = locale('editor.cameras'), menu = 'noir_police_editor', options = options })
    lib.showContext('noir_police_editor_cameras')
end

-- Marcadores -----------------------------------------------------------------------

local function drawLabel(p, text)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(p.x, p.y, p.z + 0.4)
    if not onScreen then return end
    SetTextScale(0.3, 0.3)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function mark(origin, p, text, color)
    if not p or #(origin - vec3(p.x, p.y, p.z)) > 120.0 then return end
    DrawMarker(1, p.x, p.y, p.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 0.7, 0.5, color[1], color[2], color[3], 150,
        false, false, 2, false, nil, nil, false)
    drawLabel(p, text)
end

local function markersLoop()
    CreateThread(function()
        while showMarkers and layout do
            local origin = GetEntityCoords(cache.ped)
            for _, station in ipairs(layout.stations) do
                if station.blip then mark(origin, station.blip, station.label, { 255, 255, 255 }) end
                for i, p in ipairs(station.duty) do mark(origin, p, locale('editor.mark_duty', i), { 60, 200, 90 }) end
                for i, p in ipairs(station.lockers) do mark(origin, p, locale('editor.mark_locker', i), { 60, 140, 255 }) end
                mark(origin, station.evidence, locale('editor.evidence_room'), { 230, 170, 40 })
                mark(origin, station.fingerprint, locale('editor.fingerprint'), { 200, 90, 220 })
                mark(origin, station.cameras, locale('editor.camera_desk'), { 90, 220, 220 })
                mark(origin, station.lab, locale('editor.dna_lab'), { 220, 220, 90 })
                mark(origin, station.reception, locale('editor.reception'), { 150, 230, 150 })
                for g, garage in ipairs(station.garages or {}) do
                    mark(origin, garage.point, locale('editor.mark_garage', g), { 240, 90, 60 })
                    for s, spawn in ipairs(garage.spawns) do mark(origin, spawn, locale('editor.mark_spawn', g, s), { 240, 140, 100 }) end
                end
            end
            for i, radar in ipairs(layout.radars) do mark(origin, radar, locale('editor.mark_radar', i, radar.speedLimit), { 255, 60, 60 }) end
            for i, camera in ipairs(layout.cameras) do mark(origin, camera, locale('editor.mark_camera', i), { 120, 120, 255 }) end
            for i, p in ipairs(layout.shotspotter) do mark(origin, p, locale('editor.mark_shotspotter', i), { 255, 120, 0 }) end
            Wait(0)
        end
    end)
end

-- Menu principal -------------------------------------------------------------------

open = function()
    lib.registerContext({
        id = 'noir_police_editor',
        title = locale('editor.title'),
        options = {
            { title = locale('editor.stations'), description = ('%d'):format(#layout.stations), icon = 'fa-solid fa-building-shield', onSelect = openStations },
            { title = locale('editor.radars'), description = ('%d'):format(#layout.radars), icon = 'fa-solid fa-gauge-high', onSelect = openRadars },
            { title = locale('editor.cameras'), description = ('%d'):format(#layout.cameras), icon = 'fa-solid fa-video', onSelect = openCameras },
            { title = locale('editor.shotspotter'), description = ('%d'):format(#layout.shotspotter), icon = 'fa-solid fa-tower-broadcast', onSelect = function()
                pointList('shotspotter', locale('editor.shotspotter'), function() return layout.shotspotter end, 'point', 'noir_police_editor')
            end },
            { title = showMarkers and locale('editor.hide_markers') or locale('editor.show_markers'), icon = 'fa-solid fa-eye', onSelect = function()
                showMarkers = not showMarkers
                if showMarkers then markersLoop() end
                open()
            end },
        },
    })
    lib.showContext('noir_police_editor')
end

RegisterNetEvent('noir_police:client:openEditor', function(snapshot)
    if source ~= 65535 or type(snapshot) ~= 'table' then return end
    layout = snapshot
    for _, key in ipairs({ 'stations', 'radars', 'cameras', 'shotspotter' }) do layout[key] = layout[key] or {} end
    for _, station in ipairs(layout.stations) do
        station.departments = station.departments or {}
        station.duty, station.lockers, station.garages = station.duty or {}, station.lockers or {}, station.garages or {}
        for _, garage in ipairs(station.garages) do garage.spawns = garage.spawns or {} end
    end
    open()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    showMarkers = false
    stopPreview()
end)
