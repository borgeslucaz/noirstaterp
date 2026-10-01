---Evidência no chão (cápsula, projétil, sangue, digital), GSR, status do corpo,
---shotspotter, coleta, limpeza, DNA e leitor de digital.
---
---Os pontos moram no servidor. Só policial em serviço recebe a lista, e só com o
---necessário para desenhar: quem é o dono da digital ou do sangue fica aqui até a
---coleta.

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Departments = require 'shared.departments'
local Utils = require 'shared.utils'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Storage = require 'server.storage'
local State = require 'server.state'
local Layout = require 'server.layout'

local Evidence = {}

---@type table<integer, table> id -> { id, kind, coords, createdAt, data }
local nodes = {}
local nodeCount = 0
local nextId = 0

local gsr = {}           -- source -> os.time() do último tiro
local statuses = {}      -- source -> { [status] = expiresAt }
local lastShotspotter = {}

local cfg = ServerConfig.evidence

-- Chave do código de DNA. Fica no KVP do servidor: gerada uma vez, nunca vai ao cliente.
local dnaSecret = GetResourceKvpString('noir_police:dnaSecret')
if not dnaSecret or #dnaSecret < 16 then
    local chars = {}
    for index = 1, 32 do chars[index] = string.char(math.random(33, 126)) end
    dnaSecret = table.concat(chars)
    SetResourceKvp('noir_police:dnaSecret', dnaSecret)
end

---@param citizenId string?
---@return string
local function dnaOf(citizenId)
    return citizenId and Utils.dnaCode(dnaSecret, citizenId) or '?'
end

-- Distribuição para policiais --------------------------------------------------------

local function publicNode(node)
    return { id = node.id, kind = node.kind, x = node.coords.x, y = node.coords.y, z = node.coords.z }
end

local function policeRecipients()
    local list = {}
    for _, src in ipairs(Integrations.onDutyByType(Config.policeJobType)) do
        if Departments.isOnDutyPolice(Integrations.getJob(src)) then list[#list + 1] = src end
    end
    return list
end

local pendingAdd, pendingRemove = {}, {}

local function flush()
    if not next(pendingAdd) and not next(pendingRemove) then return end
    local added, removed = {}, {}
    for _, node in pairs(pendingAdd) do added[#added + 1] = publicNode(node) end
    for id in pairs(pendingRemove) do removed[#removed + 1] = id end
    pendingAdd, pendingRemove = {}, {}
    for _, src in ipairs(policeRecipients()) do
        TriggerClientEvent('noir_police:client:evidenceDelta', src, added, removed)
    end
end

local function sendSnapshot(src)
    local list = {}
    for _, node in pairs(nodes) do list[#list + 1] = publicNode(node) end
    TriggerClientEvent('noir_police:client:evidenceSnapshot', src, list)
end

local function addNode(kind, coords, data)
    if nodeCount >= cfg.maxNodes then return nil end
    nextId = nextId + 1
    local node = { id = nextId, kind = kind, coords = coords, createdAt = os.time(), data = data or {} }
    nodes[node.id] = node
    nodeCount = nodeCount + 1
    pendingAdd[node.id] = node
    return node
end

local function removeNode(id)
    if not nodes[id] then return end
    nodes[id] = nil
    nodeCount = nodeCount - 1
    pendingAdd[id] = nil
    pendingRemove[id] = true
end

CreateThread(function()
    while true do
        Wait(1000)
        flush()
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        local limit = os.time() - cfg.ttlMinutes * 60
        for id, node in pairs(nodes) do
            if node.createdAt < limit then removeNode(id) end
        end
    end
end)

AddEventHandler('bgrz_core:server:dutyUpdated', function(src, onDuty)
    if not src then return end
    if onDuty then SetTimeout(500, function() sendSnapshot(src) end)
    else TriggerClientEvent('noir_police:client:evidenceSnapshot', src, {}) end
end)

AddEventHandler('bgrz_core:server:playerLoaded', function(src)
    SetTimeout(2000, function()
        if src and Departments.isOnDutyPolice(Integrations.getJob(src)) then sendSnapshot(src) end
    end)
end)

-- Tiro: cápsula, projétil, GSR e shotspotter ------------------------------------------

local function nearShotspotter(coords)
    for _, sensor in ipairs(Layout.shotspotter()) do
        if #(coords.xy - sensor.xy) <= ServerConfig.shotspotter.radius then return true end
    end
    return false
end

local ignoredWeapons = {}
for _, hash in ipairs(ServerConfig.shotspotter.ignoredWeapons) do ignoredWeapons[hash] = true end

local function triggerShotspotter(src, coords, suppressed)
    local config = ServerConfig.shotspotter
    if not config.enabled or suppressed then return end
    if Departments.isOnDutyPolice(Integrations.getJob(src)) then return end
    local weapon = GetSelectedPedWeapon(GetPlayerPed(src))
    if ignoredWeapons[weapon] then return end
    if (lastShotspotter[src] or 0) + config.cooldownSeconds > os.time() then return end
    if not nearShotspotter(coords) then return end
    lastShotspotter[src] = os.time()

    SetTimeout(config.delaySeconds * 1000, function()
        Integrations.dispatch({
            code = '10-71',
            title = locale('dispatch.shotspotter_title'),
            message = locale('dispatch.shotspotter_message'),
            coords = coords,
            jobs = Departments.jobNames(),
            priority = 2,
            radius = 80.0,
        })
    end)
end

---O cliente relata o tiro e onde caíram cápsula e projétil. O servidor confere
---posição, munição e quantidade; serial e munição saem da arma que o ox_inventory
---diz estar na mão.
RegisterNetEvent('noir_police:server:shot', function(report)
    local src = source
    if not Security.rateLimit(src, 'shot') then return end
    if type(report) ~= 'table' then return end

    local shooter = Security.coords(src)
    if not shooter then return end

    local weapon = Integrations.currentWeapon(src)
    local weaponItem = weapon and weapon.name
    -- A munição vem do cadastro da arma no inventário (ammoname), não do cliente.
    local ammoName = weaponItem and Integrations.weaponAmmo(weaponItem)
    local evidenceInfo = ammoName and Config.ammoEvidence[ammoName]
    local serial = weapon and weapon.metadata and weapon.metadata.serial or nil

    gsr[src] = os.time()
    triggerShotspotter(src, shooter, report.suppressed == true)

    if not weaponItem or not evidenceInfo then return end

    local points = type(report.points) == 'table' and report.points or {}
    local accepted = 0
    for index = 1, math.min(#points, cfg.maxNodesPerShot) do
        local point = points[index]
        local kind = type(point) == 'table' and point.kind
        local coords = type(point) == 'table' and Utils.toVec3(point.coords)
        if coords and ((kind == 'casing' and evidenceInfo.casing) or (kind == 'projectile' and evidenceInfo.projectile))
            and #(coords - shooter) <= (kind == 'casing' and 8.0 or ServerConfig.distance.shotEvidence) then
            addNode(kind, coords, { ammo = ammoName, serial = serial, weapon = weaponItem })
            accepted = accepted + 1
        end
    end
end)

---@param src integer
---@return boolean
function Evidence.hasGsr(src)
    local shotAt = gsr[src]
    return shotAt ~= nil and os.time() - shotAt <= Config.gsr.durationMinutes * 60
end

RegisterNetEvent('noir_police:server:gsrWashed', function()
    local src = source
    if not Security.rateLimit(src, 'status') then return end
    gsr[src] = nil
end)

-- Sangue e digital -----------------------------------------------------------------

---@param src integer
---@param coords vector3?
function Evidence.addBlood(src, coords)
    coords = coords or Security.coords(src)
    if not coords then return end
    local cid = Integrations.getCitizenId(src)
    if not cid then return end
    addNode('blood', coords, { citizenId = cid, bloodType = Integrations.getMetadata(src, 'bloodtype') or '?' })
end

---@param src integer
---@param coords vector3?
function Evidence.addFingerprint(src, coords)
    coords = coords or Security.coords(src)
    if not coords then return end
    local fingerprint = Integrations.getMetadata(src, 'fingerprint')
    if not fingerprint then return end
    addNode('fingerprint', coords, { fingerprint = fingerprint })
end

local function acceptDrop(src, coords)
    if not Security.rateLimit(src, 'evidenceDrop') then return nil end
    coords = Utils.toVec3(coords) or Security.coords(src)
    if not coords or not Security.near(src, coords, 6.0) then return nil end
    return coords
end

RegisterNetEvent('noir_police:server:bloodDrop', function(coords)
    local src = source
    coords = acceptDrop(src, coords)
    if coords then Evidence.addBlood(src, coords) end
end)

RegisterNetEvent('noir_police:server:fingerprintDrop', function(coords)
    local src = source
    coords = acceptDrop(src, coords)
    if coords then Evidence.addFingerprint(src, coords) end
end)

exports('AddBloodDrop', Evidence.addBlood)
exports('AddFingerprint', Evidence.addFingerprint)

-- Status do corpo (cheiro, pupilas...) ---------------------------------------------

RegisterNetEvent('noir_police:server:setStatus', function(status, seconds)
    local src = source
    if not Security.rateLimit(src, 'status') and seconds ~= 0 then return end
    if type(status) ~= 'string' or not Config.evidenceStatuses[status] then return end
    seconds = Utils.intInRange(seconds, 0, 1800)
    if not seconds then return end
    statuses[src] = statuses[src] or {}
    statuses[src][status] = seconds > 0 and os.time() + seconds or nil
end)

-- Coleta e limpeza -----------------------------------------------------------------

local function describe(node, collector)
    local data = node.data
    local street = ('%.0f, %.0f'):format(node.coords.x, node.coords.y)
    if node.kind == 'blood' then
        local dna = dnaOf(data.citizenId)
        return Config.items.filledBag, {
            label = locale('evidence.blood_label'),
            description = locale('evidence.blood_description', dna, data.bloodType or '?', collector, street),
            evidenceType = 'blood', dna = dna, bloodType = data.bloodType,
        }
    elseif node.kind == 'fingerprint' then
        return Config.items.filledBag, {
            label = locale('evidence.fingerprint_label'),
            description = locale('evidence.fingerprint_description', data.fingerprint or '?', collector, street),
            evidenceType = 'fingerprint', fingerprint = data.fingerprint,
        }
    end
    local ammo = Config.ammoEvidence[data.ammo]
    local item = node.kind == 'casing' and Config.items.casing or Config.items.projectile
    return item, {
        type = data.ammo,
        label = locale(node.kind == 'casing' and 'evidence.casing_label' or 'evidence.projectile_label',
            ammo and ammo.label or data.ammo),
        description = locale('evidence.ballistic_description', data.serial or locale('evidence.serial_unreadable'),
            collector, street),
        serial = data.serial,
    }
end

-- Bolsa de evidências ---------------------------------------------------------------
-- Container do ox_inventory (como a caixa de apreensão). A coleta entra direto nela; sem
-- bolsa não se coleta. Só aceita o que sai da coleta.

local CASE = Config.items.evidenceCase

CreateThread(function()
    Integrations.setContainerProperties(CASE, {
        slots = cfg.caseSlots, maxWeight = cfg.caseMaxWeight,
        whitelist = { Config.items.filledBag, Config.items.casing, Config.items.projectile },
    })
end)

---Containers das bolsas que o policial carrega.
local function cases(src)
    local list = {}
    for _, slot in ipairs(Integrations.itemSlots(src, CASE)) do
        local container = Integrations.containerFromSlot(src, slot.slot)
        if container and container.id then list[#list + 1] = container end
    end
    return list
end

---Guarda na primeira bolsa com espaço.
---@return boolean ok, string? code
local function storeInCase(src, item, metadata)
    local list = cases(src)
    if #list == 0 then return false, 'no_evidence_case' end
    for _, container in ipairs(list) do
        if Integrations.addItem(container.id, item, 1, metadata) then return true end
    end
    return false, 'evidence_case_full'
end
Evidence.storeInCase = storeInCase

lib.callback.register('noir_police:server:collectEvidence', function(src, nodeId)
    if not Security.rateLimit(src, 'evidenceCollect') then return { ok = false, code = 'rate_limited' } end
    if not Security.police(src) then return { ok = false, code = 'not_police' } end
    local node = nodes[tonumber(nodeId) or -1]
    if not node then return { ok = false, code = 'evidence_gone' } end
    if not Security.near(src, node.coords, ServerConfig.distance.evidenceNode) then return { ok = false, code = 'too_far' } end

    -- Coleta tudo o que estiver junto do ponto escolhido, com um saco só.
    local batch = {}
    for id, other in pairs(nodes) do
        if #(other.coords - node.coords) <= cfg.collectRadius then batch[#batch + 1] = id end
    end

    if #cases(src) == 0 then return { ok = false, code = 'no_evidence_case' } end

    local collector = Integrations.getName(src)
    local given, lastError = 0, nil
    for _, id in ipairs(batch) do
        local entry = nodes[id]
        if entry then
            local item, metadata = describe(entry, collector)
            local stored, code = storeInCase(src, item, metadata)
            if stored then
                removeNode(id)
                given = given + 1
            else
                lastError = code
                break
            end
        end
    end
    if given == 0 then return { ok = false, code = lastError or 'evidence_case_full' } end
    Integrations.log(src, 'evidence_collect', ('%s coletou %d evidência(s)'):format(collector, given))
    return { ok = true, count = given }
end)

lib.callback.register('noir_police:server:clearEvidenceArea', function(src)
    if not Security.rateLimit(src, 'evidenceCollect') then return { ok = false, code = 'rate_limited' } end
    if not Security.police(src) then return { ok = false, code = 'not_police' } end
    local coords = Security.coords(src)
    local removed = 0
    for id, node in pairs(nodes) do
        if #(node.coords - coords) <= cfg.clearRadius then
            removeNode(id)
            removed = removed + 1
        end
    end
    return { ok = true, count = removed }
end)

-- Exames em pessoa -----------------------------------------------------------------

local function examineTarget(src, targetId, action)
    if not Security.rateLimit(src, 'evidenceCollect') then return nil, 'rate_limited' end
    if not Security.police(src, action) then return nil, 'not_police' end
    local target = Security.player(targetId)
    if not target or target == src then return nil, 'invalid_target' end
    if not Security.playersNear(src, target, ServerConfig.distance.interact) then return nil, 'too_far' end
    return target
end

lib.callback.register('noir_police:server:gsrTest', function(src, targetId)
    local target, err = examineTarget(src, targetId)
    if not target then return { ok = false, code = err } end
    Integrations.log(src, 'gsr_test', ('%s testou GSR de %s'):format(Integrations.getName(src), Integrations.getName(target)))
    return { ok = true, positive = Evidence.hasGsr(target) }
end)

lib.callback.register('noir_police:server:examine', function(src, targetId)
    local target, err = examineTarget(src, targetId)
    if not target then return { ok = false, code = err } end
    local found, now = {}, os.time()
    for status, expiresAt in pairs(statuses[target] or {}) do
        if expiresAt > now then found[#found + 1] = Config.evidenceStatuses[status] end
    end
    return { ok = true, statuses = found }
end)

lib.callback.register('noir_police:server:takeDna', function(src, targetId)
    local target, err = examineTarget(src, targetId, 'takeDna')
    if not target then return { ok = false, code = err } end
    local cid = Integrations.getCitizenId(target)
    local dna = dnaOf(cid)
    local ok, code = storeInCase(src, Config.items.filledBag, {
        label = locale('evidence.dna_label'),
        description = locale('evidence.dna_description', dna, Integrations.getName(src)),
        evidenceType = 'dna', dna = dna,
    })
    if not ok then return { ok = false, code = code } end
    -- A coleta é o que põe a pessoa no banco de DNA da polícia.
    if cid then Storage.registerDna(dna, cid, Integrations.getCitizenId(src)) end
    Integrations.log(src, 'take_dna', ('%s coletou DNA de %s'):format(Integrations.getName(src), Integrations.getName(target)))
    return { ok = true }
end)

---Amostra de sangue colhida da pessoa (algemada, rendida ou caída): mesmo DNA do
---sangue achado no chão, mais o tipo sanguíneo. Também põe a pessoa no banco de DNA.
lib.callback.register('noir_police:server:takeBlood', function(src, targetId)
    local target, err = examineTarget(src, targetId, 'takeDna')
    if not target then return { ok = false, code = err } end
    -- Contido, caído ou rendido (o `handsUp` é o próprio alvo se entregando).
    if not State.isRestrained(target) and not Integrations.isDowned(target) and not Player(target).state.handsUp then
        return { ok = false, code = 'not_restrained' }
    end
    local cid = Integrations.getCitizenId(target)
    local dna = dnaOf(cid)
    local bloodType = Integrations.getMetadata(target, 'bloodtype') or '?'
    local ok, code = storeInCase(src, Config.items.filledBag, {
        label = locale('evidence.blood_sample_label'),
        description = locale('evidence.blood_sample_description', dna, bloodType, Integrations.getName(src)),
        evidenceType = 'blood', dna = dna, bloodType = bloodType,
    })
    if not ok then return { ok = false, code = code } end
    if cid then Storage.registerDna(dna, cid, Integrations.getCitizenId(src)) end
    Integrations.log(src, 'take_blood', ('%s colheu sangue de %s'):format(Integrations.getName(src), Integrations.getName(target)))
    return { ok = true }
end)

---Leitor de digital da delegacia: o suspeito precisa estar no leitor.
lib.callback.register('noir_police:server:scanFingerprint', function(src, targetId)
    local target, err = examineTarget(src, targetId, 'fingerprint')
    if not target then return { ok = false, code = err } end
    local job = Integrations.getJob(src)
    local atScanner = false
    for _, station in ipairs(Layout.stations()) do
        if station.fingerprint and Departments.stationServes(station, job.name)
            and Security.near(target, station.fingerprint.coords, station.fingerprint.radius + 1.5) then
            atScanner = true
        end
    end
    if not atScanner then return { ok = false, code = 'not_at_scanner' } end
    return { ok = true, fingerprint = Integrations.getMetadata(target, 'fingerprint') or '?' }
end)

-- Bancada de análise de DNA ----------------------------------------------------------

local function atLab(src, job)
    for _, station in ipairs(Layout.stations()) do
        if station.lab and Departments.stationServes(station, job.name)
            and Security.near(src, station.lab.coords, station.lab.radius + 2.0) then
            return true
        end
    end
    return false
end

---Sacos com DNA com o policial: no bolso e dentro das bolsas de evidência. A chave é
---"inventário:slot", opaca para o cliente e remontada aqui a cada pedido.
local function dnaSamples(src)
    local list = {}
    local holders = { src }
    for _, container in ipairs(cases(src)) do holders[#holders + 1] = container.id end
    for _, holder in ipairs(holders) do
        for _, slot in ipairs(Integrations.itemSlots(holder, Config.items.filledBag)) do
            local metadata = slot.metadata or {}
            if type(metadata.dna) == 'string' and metadata.dna ~= '?' then
                list[#list + 1] = { slot = ('%s:%d'):format(holder, slot.slot), dna = metadata.dna,
                    kind = metadata.evidenceType, label = metadata.label }
            end
        end
    end
    return list
end

lib.callback.register('noir_police:server:labSamples', function(src)
    local job = Security.police(src, 'dnaLab')
    if not job then return { ok = false, code = 'not_police' } end
    if not atLab(src, job) then return { ok = false, code = 'too_far' } end
    local samples = dnaSamples(src)
    local list = {}
    for _, sample in ipairs(samples) do
        list[#list + 1] = { slot = sample.slot, label = sample.label or '?', kind = sample.kind }
    end
    return { ok = true, samples = list }
end)

---Compara duas amostras, ou procura uma no banco de DNA.
lib.callback.register('noir_police:server:labAnalyze', function(src, slotA, slotB)
    if not Security.rateLimit(src, 'evidenceCollect') then return { ok = false, code = 'rate_limited' } end
    local job = Security.police(src, 'dnaLab')
    if not job then return { ok = false, code = 'not_police' } end
    if not atLab(src, job) then return { ok = false, code = 'too_far' } end

    local bySlot = {}
    for _, sample in ipairs(dnaSamples(src)) do bySlot[sample.slot] = sample end
    local a = bySlot[tostring(slotA)]
    if not a then return { ok = false, code = 'invalid_sample' } end

    if slotB ~= nil then
        local b = bySlot[tostring(slotB)]
        if not b or b.slot == a.slot then return { ok = false, code = 'invalid_sample' } end
        Integrations.log(src, 'dna_compare', ('%s comparou %s x %s'):format(Integrations.getName(src), a.dna, b.dna))
        return { ok = true, mode = 'compare', match = a.dna == b.dna }
    end

    local cid = Storage.findDna(a.dna)
    Integrations.log(src, 'dna_lookup', ('%s consultou %s: %s'):format(Integrations.getName(src), a.dna, cid or 'sem registro'))
    if not cid then return { ok = true, mode = 'lookup', found = false } end
    return { ok = true, mode = 'lookup', found = true, name = Integrations.getNames({ cid })[cid] or cid }
end)

-- Hook do ox_inventory: rótulo e imagem da cápsula/projétil criada ------------------

Integrations.registerInventoryHook('createItem', function(payload)
    local metadata = payload.metadata or {}
    local info = metadata.type and Config.ammoEvidence[metadata.type]
    if not info then return end
    metadata.image = payload.item.name
    return metadata
end, { itemFilter = { [Config.items.casing] = true, [Config.items.projectile] = true } })

-- Diagnóstico temporário (/evidenciadebug no cliente): imprime no log do servidor.
RegisterNetEvent('noir_police:server:evidenceDebug', function(lines)
    local src = source
    if not Security.rateLimit(src, 'default') or type(lines) ~= 'table' then return end
    local near = {}
    local coords = Security.coords(src)
    for id, node in pairs(nodes) do
        if coords and #(node.coords - coords) < 15.0 then
            near[#near + 1] = ('#%d %s servidor %.2f %.2f %.2f'):format(id, node.kind, node.coords.x, node.coords.y, node.coords.z)
        end
    end
    print(('[evidenciadebug] %s (%d)'):format(GetPlayerName(src) or '?', src))
    for index = 1, math.min(#lines, 40) do print('[evidenciadebug] cli ' .. tostring(lines[index]):sub(1, 300)) end
    for _, line in ipairs(near) do print('[evidenciadebug] srv ' .. line) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    gsr[src], statuses[src], lastShotspotter[src] = nil, nil, nil
end)

return Evidence
