---Evidência (lado do cliente): relato de tiro, pontos visíveis para a polícia,
---coleta, GSR, status do corpo e exames em pessoa.

local Config = require 'config.shared'
local Departments = require 'shared.departments'
local Integrations = require 'client.integrations'
local Util = require 'client.util'
local Layout = require 'client.layout'

local zonesById = {}
local statuses = {}
local enteredWaterAt = nil
local lastReport = 0

local kindIcon = {
    casing = 'fa-solid fa-circle-dot',
    projectile = 'fa-solid fa-bullseye',
    blood = 'fa-solid fa-droplet',
    fingerprint = 'fa-solid fa-fingerprint',
}

-- Tiro -----------------------------------------------------------------------------

local function isSuppressed(ped, weapon)
    for _, component in ipairs(Config.suppressors) do
        if HasPedGotWeaponComponent(ped, weapon, component) then return true end
    end
    return false
end

local function shotPoints()
    local points = {}
    local hit, _, endCoords = lib.raycast.cam(511, 7, 60)
    if hit and endCoords then
        points[#points + 1] = { kind = 'projectile', coords = { endCoords.x, endCoords.y, endCoords.z } }
    end
    local pedCoords = GetEntityCoords(cache.ped)
    local angle = math.rad(math.random(360))
    local distance = math.random(50, 250) / 100
    local x, y = pedCoords.x + math.sin(angle) * distance, pedCoords.y + math.cos(angle) * distance
    local found, groundZ = GetGroundZFor_3dCoord(x, y, pedCoords.z + 1.0, false)
    if found then
        points[#points + 1] = { kind = 'casing', coords = { x, y, groundZ } }
    end
    return points
end

-- Geração: cada troca de arma invalida a thread anterior, mesmo que ela ainda não
-- tenha acordado.
local generation = 0

AddEventHandler('ox_inventory:currentWeapon', function(weapon)
    generation = generation + 1
    if not weapon or not weapon.ammo then return end
    local mine = generation
    CreateThread(function()
        while generation == mine do
            local ped = cache.ped
            if IsPedShooting(ped) then
                local now = GetGameTimer()
                if now - lastReport >= 300 then
                    lastReport = now
                    TriggerServerEvent('noir_police:server:shot', {
                        points = shotPoints(),
                        suppressed = isSuppressed(ped, GetSelectedPedWeapon(ped)),
                    })
                end
            end
            Wait(0)
        end
    end)
end)

-- GSR: lavar na água ---------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(5000)
        if IsEntityInWater(cache.ped) and IsPedSwimming(cache.ped) then
            enteredWaterAt = enteredWaterAt or GetGameTimer()
            if GetGameTimer() - enteredWaterAt >= Config.gsr.waterMinutes * 60000 then
                TriggerServerEvent('noir_police:server:gsrWashed')
                enteredWaterAt = nil
            end
        else
            enteredWaterAt = nil
        end
    end
end)

-- Status do corpo (vindo de consumíveis) -------------------------------------------

---qbx_consumables e outros disparam este evento local.
AddEventHandler('noir_police:client:setEvidenceStatus', function(status, seconds)
    if type(status) ~= 'string' or not Config.evidenceStatuses[status] then return end
    seconds = tonumber(seconds) or 0
    local previous = statuses[status]
    statuses[status] = seconds > 0 and GetGameTimer() + seconds * 1000 or nil
    if seconds > 0 and not previous then
        Integrations.notify(Config.evidenceStatuses[status], 'inform')
    end
    TriggerServerEvent('noir_police:server:setStatus', status, math.floor(seconds))
end)

-- Pontos no chão -------------------------------------------------------------------

local function removeZone(id)
    local zone = zonesById[id]
    if zone then
        Integrations.removeZone(zone)
        zonesById[id] = nil
    end
    zoneInfo[id] = nil
end

local function collect(id)
    local progressed = lib.progressBar({
        duration = 2500,
        label = locale('progress.collecting_evidence'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'pickup_object', clip = 'pickup_low' },
    })
    if not progressed then return end
    local result = lib.callback.await('noir_police:server:collectEvidence', false, id)
    if result and result.ok then
        Integrations.notify(locale('success.evidence_collected', result.count), 'success')
    else
        Integrations.notify(Util.errorText(result and result.code), 'error')
    end
end

-- Sangue e digital chegam na altura do corpo de quem deixou (posição do ped). No ar o
-- ox_target não acerta a zona: a mira só "encosta" nela quando bate em algo ali dentro,
-- e no começo era o próprio suspeito. Vai para o chão logo abaixo.
local onBody = { blood = true, fingerprint = true }

local function zoneCoords(node)
    local coords = vec3(node.x, node.y, node.z)
    if not onBody[node.kind] then return coords end
    local found, groundZ = GetGroundZFor_3dCoord(node.x, node.y, node.z + 0.5, false)
    if found and groundZ <= node.z + 0.5 and node.z - groundZ < 3.0 then
        return vec3(node.x, node.y, groundZ + 0.05)
    end
    return vec3(node.x, node.y, node.z - 0.95)
end

-- Diagnóstico (/evidenciadebug): o que cada zona virou de fato.
local zoneInfo = {}

local function addZone(node)
    if zonesById[node.id] then return end
    local coords = zoneCoords(node)
    zoneInfo[node.id] = { kind = node.kind, raw = vec3(node.x, node.y, node.z), coords = coords }
    zonesById[node.id] = Integrations.addSphereZone({
        coords = coords,
        radius = onBody[node.kind] and 0.5 or 0.35,
        drawSprite = true,
        options = {
            {
                name = ('noir_police:evidence:%d'):format(node.id),
                icon = kindIcon[node.kind] or 'fa-solid fa-magnifying-glass',
                label = locale('target.collect_' .. node.kind),
                distance = 2.0,
                onSelect = function() collect(node.id) end,
            },
        },
    })
end

RegisterNetEvent('noir_police:client:evidenceSnapshot', function(list)
    if source ~= 65535 then return end
    for id in pairs(zonesById) do removeZone(id) end
    for _, node in ipairs(type(list) == 'table' and list or {}) do addZone(node) end
end)

RegisterNetEvent('noir_police:client:evidenceDelta', function(added, removed)
    if source ~= 65535 then return end
    for _, id in ipairs(type(removed) == 'table' and removed or {}) do removeZone(id) end
    for _, node in ipairs(type(added) == 'table' and added or {}) do addZone(node) end
end)

-- Exames em pessoa -----------------------------------------------------------------

local function isOnDutyPolice(action)
    return Departments.can(Integrations.getJob(), action)
end

local function examine(callbackName, targetEntity, onResult)
    local target = Util.serverIdFromPed(targetEntity)
    if not target then return end
    local result = lib.callback.await(callbackName, false, target)
    if not result or not result.ok then
        return Integrations.notify(Util.errorText(result and result.code), 'error')
    end
    onResult(result)
end

Integrations.addGlobalPlayer({
    {
        name = 'noir_police:evidence:gsr',
        icon = 'fa-solid fa-gun',
        label = locale('target.gsr_test'),
        distance = 1.5,
        canInteract = function() return isOnDutyPolice() end,
        onSelect = function(data)
            examine('noir_police:server:gsrTest', data.entity, function(result)
                Integrations.notify(locale(result.positive and 'info.gsr_positive' or 'info.gsr_negative'),
                    result.positive and 'warning' or 'inform')
            end)
        end,
    },
    {
        name = 'noir_police:evidence:examine',
        icon = 'fa-solid fa-eye',
        label = locale('target.examine'),
        distance = 1.5,
        canInteract = function() return isOnDutyPolice() end,
        onSelect = function(data)
            examine('noir_police:server:examine', data.entity, function(result)
                local text = #result.statuses > 0 and table.concat(result.statuses, '\n') or locale('info.nothing_found')
                lib.alertDialog({ header = locale('target.examine'), content = text, centered = true })
            end)
        end,
    },
    {
        name = 'noir_police:evidence:dna',
        icon = 'fa-solid fa-dna',
        label = locale('target.take_dna'),
        distance = 1.5,
        items = Config.items.evidenceCase,
        canInteract = function() return isOnDutyPolice('takeDna') end,
        onSelect = function(data)
            examine('noir_police:server:takeDna', data.entity, function()
                Integrations.notify(locale('success.dna_taken'), 'success')
            end)
        end,
    },
    {
        name = 'noir_police:evidence:blood',
        icon = 'fa-solid fa-syringe',
        label = locale('target.take_blood'),
        distance = 1.5,
        items = Config.items.evidenceCase,
        canInteract = function(entity)
            if not isOnDutyPolice('takeDna') then return false end
            -- Contido, rendido ou caído; o servidor confere de novo.
            local id = Util.serverIdFromPed(entity)
            if not id then return false end
            return Util.isCuffed(id) or Util.playerState(id, 'handsUp') and true
                or IsPedDeadOrDying(entity, true) or IsPedFatallyInjured(entity)
        end,
        onSelect = function(data)
            examine('noir_police:server:takeBlood', data.entity, function()
                Integrations.notify(locale('success.blood_taken'), 'success')
            end)
        end,
    },
    {
        name = 'noir_police:evidence:fingerprint',
        icon = 'fa-solid fa-fingerprint',
        label = locale('target.scan_fingerprint'),
        distance = 2.0,
        canInteract = function(entity)
            if not isOnDutyPolice('fingerprint') then return false end
            local coords = GetEntityCoords(entity)
            for _, station in ipairs(Layout.stations()) do
                if station.fingerprint and #(coords - station.fingerprint.coords) <= station.fingerprint.radius + 1.0 then
                    return true
                end
            end
            return false
        end,
        onSelect = function(data)
            examine('noir_police:server:scanFingerprint', data.entity, function(result)
                lib.alertDialog({
                    header = locale('target.scan_fingerprint'),
                    content = locale('info.fingerprint_result', result.fingerprint),
                    centered = true,
                })
            end)
        end,
    },
})

---Limpa evidência na área (menu da polícia).
local function clearArea()
    local progressed = lib.progressBar({
        duration = 5000,
        label = locale('progress.clearing_evidence'),
        canCancel = true,
        disable = { car = true, combat = true },
    })
    if not progressed then return end
    local result = lib.callback.await('noir_police:server:clearEvidenceArea', false)
    if result and result.ok then
        Integrations.notify(locale('success.evidence_cleared', result.count), 'success')
    else
        Integrations.notify(Util.errorText(result and result.code), 'error')
    end
end

-- Diagnóstico temporário: mire no ponto de evidência e rode /evidenciadebug. Vai para o
-- log do servidor (para ler sem depender do F8) e para o F8.
RegisterCommand('evidenciadebug', function()
    local origin = GetEntityCoords(cache.ped)
    local hit, entity, endCoords = lib.raycast.fromCamera(511, 4, 20)
    local lines = {
        ('jogador %.2f %.2f %.2f | mira hit=%s ent=%s fim %.2f %.2f %.2f (%.2f m)'):format(origin.x, origin.y, origin.z,
            tostring(hit), tostring(entity), endCoords.x, endCoords.y, endCoords.z, #(origin - endCoords)),
        ('zonas locais: %d | job %s'):format((function() local n = 0 for _ in pairs(zonesById) do n = n + 1 end return n end)(),
            json.encode(Integrations.getJob() or {})),
    }
    for id, info in pairs(zoneInfo) do
        if #(origin - info.raw) < 15.0 then
            lines[#lines + 1] = ('#%d %s bruto z=%.2f zona %.2f %.2f %.2f | mira->zona %.2f | zoneId %s'):format(id, info.kind,
                info.raw.z, info.coords.x, info.coords.y, info.coords.z, #(endCoords - info.coords), tostring(zonesById[id]))
        end
    end
    for _, line in ipairs(lines) do print('[evidenciadebug] ' .. line) end
    TriggerServerEvent('noir_police:server:evidenceDebug', lines)
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for id in pairs(zonesById) do removeZone(id) end
end)

return { clearArea = clearArea }
