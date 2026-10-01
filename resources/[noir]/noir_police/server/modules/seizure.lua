---Apreensão: pendências, seized_box, sala de evidências e destino do que foi guardado.
---
---Na rua o policial revista pela tela do ox_inventory e leva o que quiser para o
---próprio inventário. O hook de swapItems não bloqueia: registra cada item tirado de
---outro jogador como pendência. No depósito da seized_box, o que chega baixa as
---pendências; o que foi tirado e nunca chegou vira alerta de desvio depois do prazo.

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Departments = require 'shared.departments'
local Utils = require 'shared.utils'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Layout = require 'server.layout'
local Storage = require 'server.storage'
local State = require 'server.state'

local Seizure = {}

local cfg = ServerConfig.seizure
local BOX = Config.items.seizedBox

local function stashId(department) return ('noir_police_evidence_%s'):format(department) end

-- Grupo que ninguém tem: o ox_inventory não abre esses stashes pelo cliente, só pelo
-- `forceOpenInventory` do servidor, depois das checagens de posição, papel e serviço.
local LOCKED = { noir_police_server_only = 999 }

local function fail(code) return { ok = false, code = code } end

-- Boot -------------------------------------------------------------------------------

-- As contas dos departamentos só são criadas com o cache do banco carregado: antes
-- disso o Renewed-Banking não vê a conta que já existe e tenta criar de novo.
local function ensureAccounts()
    for _, department in pairs(Config.departments) do
        local ok, err = Integrations.ensureOrgAccount(department.account, department.label)
        if not ok then
            lib.print.warn(('[noir_police] conta %s não confirmada: %s'):format(department.account, tostring(err)))
        end
    end
end

AddEventHandler('bgrz_core:bankingReady', function()
    local invoker = GetInvokingResource and GetInvokingResource()
    if invoker and invoker ~= 'bgrz_core' then return end
    ensureAccounts()
end)

CreateThread(function()
    for name, department in pairs(Config.departments) do
        Integrations.registerStash(stashId(name), locale('stash.evidence', department.label), cfg.stashSlots,
            cfg.stashMaxWeight, LOCKED)
    end
    Integrations.setContainerProperties(BOX, { slots = cfg.boxSlots, maxWeight = cfg.boxMaxWeight,
        blacklist = { BOX } })
    -- Restart só do noir_police: o banco já estava pronto e o evento não vem de novo.
    if Integrations.bankingReady() then ensureAccounts() end
end)

-- Hooks do ox_inventory ----------------------------------------------------------------

Integrations.registerInventoryHook('createItem', function(payload)
    local metadata = payload.metadata or {}
    if not metadata.boxId then
        metadata.boxId = Utils.opaqueId('BOX')
        metadata.description = locale('seizure.box_description', metadata.boxId)
    end
    return metadata
end, { itemFilter = { [BOX] = true } })

local function recordSeizure(officer, target, job, slot, count)
    local officerCid = Integrations.getCitizenId(officer)
    local targetCid = Integrations.getCitizenId(target)
    if not officerCid or not targetCid then return end
    local coords = Security.coords(target)
    Storage.addSeizure({
        officer = officerCid,
        target = targetCid,
        department = job.name,
        item = slot.name,
        count = count,
        serial = slot.metadata and slot.metadata.serial or nil,
        coords = coords and ('%.1f,%.1f,%.1f'):format(coords.x, coords.y, coords.z) or nil,
    })
    Integrations.log(officer, 'seizure_take', ('%s tirou %dx %s de %s'):format(
        Integrations.getName(officer), count, slot.name, Integrations.getName(target)))
end

Integrations.registerInventoryHook('swapItems', function(payload)
    local src = payload.source
    if State.isCuffed(src) then return false end

    local from, to = payload.fromInventory, payload.toInventory
    -- Item saindo do inventário de outro jogador (e não só reorganizado dentro dele).
    local takesFrom = payload.fromType == 'player' and type(from) == 'number' and from ~= src and to ~= from
    -- Troca: o policial arrasta um item seu para um slot ocupado do alvo; o item do
    -- alvo vem para o policial.
    local swapsWith = payload.action == 'swap' and from == src and payload.toType == 'player'
        and type(to) == 'number' and to ~= src and type(payload.toSlot) == 'table'
    if not takesFrom and not swapsWith then return true end

    local job = Integrations.getJob(src)
    if not Departments.isPolice(job) then return true end
    -- Fora de serviço, policial não revista ninguém.
    if not job.onDuty then
        Integrations.notify(src, locale('error.off_duty'), 'error')
        return false
    end

    local target, slot, count
    if takesFrom then
        target, slot = from, payload.fromSlot
        count = tonumber(payload.count) or (type(slot) == 'table' and slot.count) or 1
    else
        target, slot = to, payload.toSlot
        count = slot.count or 1
    end
    if type(slot) == 'table' and slot.name then
        CreateThread(function() recordSeizure(src, target, job, slot, count) end)
    end
    return true
end)

Integrations.registerInventoryHook('usingItem', function(payload)
    if State.isCuffed(payload.source) then return false end
    return true
end)

Integrations.registerInventoryHook('openInventory', function(payload)
    if State.isCuffed(payload.source) then return false end
    return true
end)

-- Sala de evidências -------------------------------------------------------------------

---Estação de evidência do departamento onde o policial está.
local function atEvidenceRoom(src, job)
    for _, station in ipairs(Layout.stations()) do
        if station.evidence and Departments.stationServes(station, job.name)
            and Security.near(src, station.evidence.coords, station.evidence.radius + 2.0) then
            return station
        end
    end
end

local function boxes(src)
    local list = {}
    for _, slot in ipairs(Integrations.itemSlots(src, BOX)) do
        local container = Integrations.containerFromSlot(src, slot.slot)
        local count = 0
        for _, item in pairs(container and container.items or {}) do
            if type(item) == 'table' and item.name then count = count + 1 end
        end
        list[#list + 1] = { slot = slot.slot, boxId = slot.metadata.boxId or '?', tag = slot.metadata.tag, items = count }
    end
    return list
end

-- Etiqueta da caixa ------------------------------------------------------------------

lib.callback.register('noir_police:server:labelBox', function(src, slot, text)
    if not Security.rateLimit(src, 'default') then return fail('rate_limited') end
    slot = Utils.intInRange(slot, 1, 500)
    text = Utils.cleanText(text, 40, 1)
    if not slot or not text then return fail('invalid_input') end
    local box
    for _, entry in ipairs(Integrations.itemSlots(src, BOX)) do
        if entry.slot == slot then box = entry end
    end
    if not box then return fail('invalid_box') end
    local metadata = box.metadata
    metadata.tag = text
    metadata.label = locale('seizure.box_label', text)
    Integrations.setSlotMetadata(src, slot, metadata)
    return { ok = true }
end)

local function pendingTargets(officerCid)
    local rows = Storage.pendingByOfficer(officerCid)
    local cids, seen = {}, {}
    for _, row in ipairs(rows) do
        if not seen[row.target_cid] then
            seen[row.target_cid] = true
            cids[#cids + 1] = row.target_cid
        end
    end
    local names = Integrations.getNames(cids)
    local list = {}
    for _, cid in ipairs(cids) do list[#list + 1] = { citizenId = cid, name = names[cid] or cid } end
    return list, rows
end

lib.callback.register('noir_police:server:seizurePrepare', function(src)
    local job = Security.police(src, 'seize')
    if not job then return fail('not_police') end
    if not atEvidenceRoom(src, job) then return fail('too_far') end
    local cid = Integrations.getCitizenId(src)
    local targets, rows = pendingTargets(cid)
    local pending = {}
    for _, row in ipairs(rows) do
        pending[#pending + 1] = { item = Integrations.itemLabel(row.item), count = row.count }
    end
    return { ok = true, boxes = boxes(src), targets = targets, pending = pending }
end)

lib.callback.register('noir_police:server:seizureDeposit', function(src, slot, targetCid, reason)
    if not Security.rateLimit(src, 'deposit') then return fail('rate_limited') end
    local job = Security.police(src, 'seize')
    if not job then return fail('not_police') end
    if not atEvidenceRoom(src, job) then return fail('too_far') end

    slot = Utils.intInRange(slot, 1, 500)
    if not slot then return fail('invalid_box') end
    local box
    for _, entry in ipairs(Integrations.itemSlots(src, BOX)) do
        if entry.slot == slot then box = entry end
    end
    if not box or not box.metadata.boxId then return fail('invalid_box') end
    if Storage.boxDeposited(box.metadata.boxId) then
        Integrations.log(src, 'seizure_duplicate_box', ('caixa %s já depositada'):format(box.metadata.boxId))
        return fail('box_already_deposited')
    end

    local container = Integrations.containerFromSlot(src, slot)
    local items = container and container.items or {}
    local contents, counts, hasCleanMoney = {}, {}, false
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name and (item.count or 0) > 0 then
            contents[#contents + 1] = { name = item.name, count = item.count, metadata = item.metadata }
            counts[#counts + 1] = { name = item.name, count = item.count }
            if item.name == cfg.cleanMoneyItem then hasCleanMoney = true end
        end
    end
    if #contents == 0 then return fail('box_empty') end

    reason = Utils.cleanText(reason, 200) or nil
    if hasCleanMoney and not reason then return fail('reason_required') end
    targetCid = type(targetCid) == 'string' and #targetCid <= 64 and targetCid or nil

    local officerCid = Integrations.getCitizenId(src)
    local pendingRows = Storage.pendingByOfficer(officerCid)
    local pending = {}
    for _, row in ipairs(pendingRows) do
        if not targetCid or row.target_cid == targetCid then
            pending[#pending + 1] = { id = row.id, item = row.item, count = row.count }
        end
    end
    local matched, leftover = Utils.matchPending(counts, pending)

    local depositId, err = Storage.addDeposit({
        boxId = box.metadata.boxId,
        department = job.name,
        officer = officerCid,
        target = targetCid,
        reason = reason,
        contents = contents,
        unmatched = leftover,
    })
    if not depositId then return fail(err) end

    Storage.resolveSeizures(matched, depositId)
    if container and container.id then Integrations.clearInventory(container.id) end
    Integrations.removeItemFromSlot(src, BOX, 1, slot)

    local targetName = targetCid and (Integrations.getNames({ targetCid })[targetCid] or targetCid) or locale('seizure.unknown_target')
    local summary = {}
    for _, entry in ipairs(counts) do
        summary[#summary + 1] = ('%dx %s'):format(entry.count, Integrations.itemLabel(entry.name))
    end
    Integrations.addItem(stashId(job.name), Config.items.filledBag, 1, {
        label = locale('seizure.bag_label', depositId),
        description = locale('seizure.bag_description', depositId, targetName, Integrations.getName(src),
            os.date('%d/%m/%Y %H:%M'), reason or '-', table.concat(summary, ', ')),
        depositId = depositId,
    })

    Integrations.log(src, 'seizure_deposit', ('%s depositou a caixa %s (#%d): %s; pendências baixadas: %d'):format(
        Integrations.getName(src), box.metadata.boxId, depositId, table.concat(summary, ', '), #matched))
    return { ok = true, depositId = depositId, matched = #matched }
end)

-- Pertences liberados (recepção) ------------------------------------------------------

---Um stash por dono e departamento. Registrado de novo a cada uso: o ox_inventory
---carrega o conteúdo salvo pelo id.
local function registerReturnStash(department, citizenId)
    local id = ('noir_police_return_%s_%s'):format(department, citizenId)
    Integrations.registerStash(id, locale('stash.returns', Departments.get(department).label), 50, 1000000, LOCKED)
    return id
end

lib.callback.register('noir_police:server:openReturns', function(src)
    if not Security.rateLimit(src, 'default') then return fail('rate_limited') end
    local cid = Integrations.getCitizenId(src)
    if not cid then return fail('invalid_player') end
    for _, station in ipairs(Layout.stations()) do
        -- Recepção da delegacia; sem ela, o ponto de serviço.
        local atDesk = false
        if station.reception then
            atDesk = Security.near(src, station.reception.coords, station.reception.radius + 2.0)
        else
            for _, point in ipairs(station.duty or {}) do
                if Security.near(src, point, ServerConfig.distance.station) then atDesk = true break end
            end
        end
        if atDesk then
            for _, department in ipairs(station.departments) do
                local id = registerReturnStash(department, cid)
                if next(Integrations.inventoryItems(id)) then
                    Integrations.forceOpenInventory(src, 'stash', id)
                    return { ok = true }
                end
            end
            return fail('no_returns')
        end
    end
    return fail('too_far')
end)

-- Gaveta: abrir e dar destino ----------------------------------------------------------

lib.callback.register('noir_police:server:openEvidenceStash', function(src)
    local job = Security.police(src, 'evidenceStash')
    if not job then return fail('not_police') end
    if not atEvidenceRoom(src, job) then return fail('too_far') end
    Integrations.forceOpenInventory(src, 'stash', stashId(job.name))
    return { ok = true }
end)

lib.callback.register('noir_police:server:listDeposits', function(src)
    local job = Security.police(src, 'evidenceManage')
    if not job then return fail('not_police') end
    if not atEvidenceRoom(src, job) then return fail('too_far') end
    local rows = Storage.storedDeposits(job.name)
    local cids = {}
    for _, row in ipairs(rows) do
        cids[#cids + 1] = row.officer_cid
        if row.target_cid then cids[#cids + 1] = row.target_cid end
    end
    local names = Integrations.getNames(cids)
    local list = {}
    for _, row in ipairs(rows) do
        local contents = json.decode(row.contents or '[]') or {}
        local summary = {}
        for _, entry in ipairs(contents) do
            summary[#summary + 1] = ('%dx %s'):format(entry.count, Integrations.itemLabel(entry.name))
        end
        list[#list + 1] = {
            id = row.id,
            officer = names[row.officer_cid] or row.officer_cid,
            target = row.target_cid and (names[row.target_cid] or row.target_cid) or nil,
            reason = row.reason,
            summary = table.concat(summary, ', '),
            createdAt = tostring(row.created_at),
        }
    end
    return { ok = true, deposits = list }
end)

-- Bônus de apreensão -------------------------------------------------------------------

---Credita um bônus já registrado. Policial offline fica "a receber" até o próximo ponto.
---@return boolean paid
local function payBonus(officerSrc, depositId, amount)
    if not Storage.markBonusPaid(depositId) then return false end
    if not Integrations.addMoney(officerSrc, cfg.bonus.account, amount, 'noir_police:seizure_bonus') then
        Storage.unmarkBonusPaid(depositId)
        return false
    end
    return true
end

---Bônus do depósito destruído para quem depositou (não para quem destruiu).
---@param row table depósito
---@param contents { name: string, count: integer }[]
local function grantBonus(row, contents)
    local bonus = cfg.bonus
    local unmatched = json.decode(row.unmatched or '{}') or {}
    local amount, base = Utils.seizureBonus(contents, unmatched, bonus.values, bonus.rate,
        Storage.bonusLastHour(row.officer_cid), bonus.hourlyCap)
    if amount <= 0 then return end
    if not Storage.addBonus(row.id, row.officer_cid, amount, base) then return end

    local officerSrc = Integrations.getSourceByCitizenId(row.officer_cid)
    if officerSrc and payBonus(officerSrc, row.id, amount) then
        Integrations.notify(officerSrc, locale('info.seizure_bonus', row.id, amount), 'success')
    end
    Integrations.log(false, 'seizure_bonus', ('#%d: $%d para %s (valor de rua $%d)'):format(row.id, amount, row.officer_cid, base))
end

-- Quem estava offline na destruição recebe ao bater o ponto.
AddEventHandler('bgrz_core:server:dutyUpdated', function(src, onDuty)
    if not onDuty or not src then return end
    local cid = Integrations.getCitizenId(src)
    if not cid then return end
    local total = 0
    for _, owed in ipairs(Storage.owedBonuses(cid)) do
        if payBonus(src, owed.deposit_id, owed.amount) then total = total + owed.amount end
    end
    if total > 0 then Integrations.notify(src, locale('info.seizure_bonus_owed', total), 'success') end
end)

local function removeBag(department, depositId)
    Integrations.removeItemsWithMetadata(stashId(department), Config.items.filledBag, { depositId = depositId })
end

lib.callback.register('noir_police:server:resolveDeposit', function(src, depositId, action)
    if not Security.rateLimit(src, 'deposit') then return fail('rate_limited') end
    local job = Security.police(src, 'evidenceManage')
    if not job then return fail('not_police') end
    if not atEvidenceRoom(src, job) then return fail('too_far') end
    depositId = Utils.intInRange(depositId, 1, 2 ^ 31)
    if not depositId or (action ~= 'destroy' and action ~= 'return' and action ~= 'incorporate') then
        return fail('invalid_action')
    end

    local row = Storage.getDeposit(depositId)
    if not row or row.department ~= job.name or row.status ~= 'stored' then return fail('invalid_deposit') end
    local contents = json.decode(row.contents or '[]') or {}
    local officerCid = Integrations.getCitizenId(src)

    if action == 'return' then
        -- Devolver não põe nada no bolso: os itens vão para os pertences do dono na
        -- recepção, e ele retira pessoalmente (ponto de serviço da delegacia).
        if not row.target_cid then return fail('no_owner') end
        if not Storage.resolveDeposit(depositId, 'returned', officerCid) then return fail('invalid_deposit') end
        local returnStash = registerReturnStash(job.name, row.target_cid)
        local returned = 0
        for _, entry in ipairs(contents) do
            if not cfg.neverReturn[entry.name] then
                -- O bridge aceita até 100000 por chamada; dinheiro alto vai em partes.
                local left = entry.count
                while left > 0 do
                    local part = math.min(left, 100000)
                    if not Integrations.addItem(returnStash, entry.name, part, entry.metadata) then
                        Integrations.addItem(stashId(job.name), entry.name, left, entry.metadata)
                        Integrations.log(src, 'deposit_return_partial', ('#%d: %dx %s voltou para a gaveta'):format(depositId, left, entry.name))
                        break
                    end
                    left = left - part
                end
                returned = returned + 1
            end
        end
        removeBag(job.name, depositId)
        -- SMS pela linha da polícia no telefone: fica na conversa e chega mesmo offline. Sem
        -- chip registrado, cai na notificação do telefone (só se estiver online).
        local department = Departments.get(job.name)
        local text = locale('info.items_released', department.label)
        if not Integrations.phoneMessage(department.phoneCompany or 'police', row.target_cid, text) then
            local owner = Integrations.getSourceByCitizenId(row.target_cid)
            if owner then Integrations.phoneNotify(owner, department.label, text) end
        end
        Integrations.log(src, 'deposit_return', ('#%d liberado para %s na recepção por %s (%d itens)'):format(
            depositId, row.target_cid, Integrations.getName(src), returned))
        return { ok = true }
    end

    if action == 'incorporate' then
        local amount = 0
        for _, entry in ipairs(contents) do
            if entry.name == cfg.cleanMoneyItem then amount = amount + entry.count end
        end
        if amount <= 0 then return fail('no_clean_money') end
        if not Storage.resolveDeposit(depositId, 'incorporated', officerCid) then return fail('invalid_deposit') end
        local department = Departments.get(job.name)
        if not Integrations.addOrgMoney(department.account, amount) then
            Storage.reopenDeposit(depositId)
            return fail('bank_unavailable')
        end
        removeBag(job.name, depositId)
        Integrations.log(src, 'deposit_incorporate', ('#%d: $%d incorporado à conta %s por %s'):format(
            depositId, amount, department.account, Integrations.getName(src)))
        -- O resto da caixa é destruído junto com a sacola: conta para o bônus.
        grantBonus(row, contents)
        return { ok = true, amount = amount }
    end

    if not Storage.resolveDeposit(depositId, 'destroyed', officerCid) then return fail('invalid_deposit') end
    removeBag(job.name, depositId)
    Integrations.log(src, 'deposit_destroy', ('#%d destruído por %s'):format(depositId, Integrations.getName(src)))
    grantBonus(row, contents)
    return { ok = true }
end)

-- Pendências vencidas viram alerta de desvio ------------------------------------------

CreateThread(function()
    Wait(60000)
    while true do
        if Storage.isReady() then
            local ok, rows = pcall(Storage.flagOverdue, cfg.pendingDeadlineHours)
            if ok then
                for _, row in ipairs(rows) do
                    Integrations.log(false, 'seizure_missing', ('pendência #%d: %s tirou %dx %s de %s em %s e não depositou'):format(
                        row.id, row.officer_cid, row.count, row.item, row.target_cid, tostring(row.created_at)))
                end
            end
        end
        Wait(10 * 60000)
    end
end)

return Seizure
