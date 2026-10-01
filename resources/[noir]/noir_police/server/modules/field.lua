---Ações de campo: multa, licença, callsign, officer down, área interditada, status de
---unidade e reunião.

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Departments = require 'shared.departments'
local Utils = require 'shared.utils'
local Security = require 'server.security'
local Integrations = require 'server.integrations'

local Field = {}

local interdicts = {}
local nextInterdict = 0

local function fail(code) return { ok = false, code = code } end

local function departmentRecipients(department)
    local list = {}
    for _, src in ipairs(Integrations.onDutyByType(Config.policeJobType)) do
        local job = Integrations.getJob(src)
        if Departments.isOnDutyPolice(job) and (not department or job.name == department) then list[#list + 1] = src end
    end
    return list
end

local function officerLabel(src)
    local callsign = Integrations.getMetadata(src, 'callsign')
    local name = Integrations.getName(src)
    return callsign and callsign ~= '' and ('%s %s'):format(callsign, name) or name
end

-- Multa ----------------------------------------------------------------------------

lib.callback.register('noir_police:server:fine', function(src, targetId, amount, reason)
    if not Security.rateLimit(src, 'fine') then return fail('rate_limited') end
    local job = Security.police(src, 'fine')
    if not job then return fail('not_police') end
    local target = Security.player(targetId)
    if not target or target == src then return fail('invalid_target') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact + 2.0) then return fail('too_far') end

    local maximum = ServerConfig.fines.max[job.name] or 0
    amount = Utils.intInRange(amount, ServerConfig.fines.min, maximum)
    if not amount then return fail('invalid_amount') end
    reason = Utils.cleanText(reason, 120, 3)
    if not reason then return fail('invalid_reason') end

    -- A multa vira pendência no banco: trava saque e transferência até ser paga, e o
    -- pagamento cai na conta do departamento.
    local department = Departments.get(job.name)
    local invoiceId, err = Integrations.createInvoice({
        recipientSource = target,
        issuerSource = src,
        issuerAccount = department.account,
        issuerLabel = department.label,
        kind = 'fine',
        title = locale('fine.invoice_title'),
        description = ('%s (%s)'):format(reason, officerLabel(src)),
        amount = amount,
        dueDays = ServerConfig.fines.dueDays,
        silent = true,
    })
    if not invoiceId then
        lib.print.warn(('[noir_police] multa de $%d não foi registrada no banco: %s'):format(amount, tostring(err)))
        return fail(err == 'provider_not_ready' and 'bank_not_ready' or 'fine_failed')
    end
    Integrations.notify(target, locale('info.fined', amount, reason), 'warning')
    Integrations.log(src, 'fine', ('%s multou %s em $%d: %s'):format(Integrations.getName(src),
        Integrations.getName(target), amount, reason))
    return { ok = true }
end)

-- Licenças -------------------------------------------------------------------------

lib.callback.register('noir_police:server:license', function(src, targetId, license, grant)
    if not Security.rateLimit(src, 'default') then return fail('rate_limited') end
    if not Security.police(src, 'license') then return fail('not_police') end
    local target = Security.player(targetId)
    if not target or target == src then return fail('invalid_target') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact + 2.0) then return fail('too_far') end
    if type(license) ~= 'string' or not Config.licenses[license] then return fail('invalid_license') end

    local current = Integrations.getMetadata(target, 'licences')
    local licences = {}
    for key, value in pairs(type(current) == 'table' and current or {}) do licences[key] = value end
    licences[license] = grant == true
    Integrations.setMetadata(target, 'licences', licences)

    Integrations.notify(target, locale(grant and 'info.license_granted' or 'info.license_revoked', Config.licenses[license]), 'inform')
    Integrations.log(src, 'license', ('%s %s %s de %s'):format(Integrations.getName(src),
        grant and 'concedeu' or 'revogou', license, Integrations.getName(target)))
    return { ok = true }
end)

-- Callsign -------------------------------------------------------------------------

lib.addCommand('callsign', {
    help = locale('command.callsign'),
    params = { { name = 'callsign', type = 'string', help = locale('command.callsign_param') } },
}, function(src, args)
    if not Security.police(src) then
        return Integrations.notify(src, locale('error.not_police'), 'error')
    end
    local value = type(args.callsign) == 'string' and args.callsign:upper() or ''
    if not value:match('^[%w%-]+$') or #value > 8 then
        return Integrations.notify(src, locale('error.invalid_callsign'), 'error')
    end
    Integrations.setMetadata(src, 'callsign', value)
    Integrations.notify(src, locale('success.callsign_set', value), 'success')
end)

-- Officer down ---------------------------------------------------------------------

RegisterNetEvent('noir_police:server:officerDown', function()
    local src = source
    if not Security.rateLimit(src, 'officerDown') then return end
    if not Security.emergency(src) then return end
    local coords = Security.coords(src)
    if not coords then return end
    local jobs = Departments.jobNames()
    for _, extra in ipairs(ServerConfig.officerDownExtraJobs) do jobs[#jobs + 1] = extra end
    Integrations.dispatch({
        code = '10-99',
        title = locale('dispatch.officer_down_title'),
        message = locale('dispatch.officer_down_message', officerLabel(src)),
        coords = coords,
        jobs = jobs,
        priority = 1,
        duration = 300,
    })
    Integrations.log(src, 'officer_down', officerLabel(src))
end)

-- Alerta de crime para a polícia --------------------------------------------------
-- Substitui o `police:server:policeAlert` do qbx_police. A posição é sempre a do
-- jogador que disparou, lida no servidor.

---@param source integer jogador que disparou (posição do alerta)
---@param message string
---@param coords? vector3
function Field.alert(source, message, coords)
    coords = coords or Security.coords(source)
    message = Utils.cleanText(message, 200, 3) or locale('dispatch.generic_message')
    if not coords then return end
    Integrations.dispatch({
        code = '10-31',
        title = locale('dispatch.generic_title'),
        message = message,
        coords = coords,
        jobs = Departments.jobNames(),
        priority = 2,
    })
end

RegisterNetEvent('noir_police:server:alert', function(message)
    local src = source
    if not Security.rateLimit(src, 'alert') then return end
    Field.alert(src, type(message) == 'string' and message or nil)
end)

exports('Alert', Field.alert)

-- Área interditada -----------------------------------------------------------------

local function activeInterdicts(owner)
    local count = 0
    for _, area in pairs(interdicts) do
        if area.owner == owner then count = count + 1 end
    end
    return count
end

local function removeInterdict(id)
    if not interdicts[id] then return end
    interdicts[id] = nil
    TriggerClientEvent('noir_police:client:interdictRemoved', -1, id)
end

lib.callback.register('noir_police:server:interdict', function(src, radius, minutes, label)
    if not Security.rateLimit(src, 'interdict') then return fail('rate_limited') end
    if not Security.police(src, 'interdict') then return fail('not_police') end
    radius = Utils.intInRange(radius, 10, math.floor(Config.interdict.maxRadius))
    minutes = Utils.intInRange(minutes, 1, Config.interdict.maxMinutes)
    label = Utils.cleanText(label, 40, 3)
    if not radius or not minutes or not label then return fail('invalid_input') end
    if activeInterdicts(src) >= ServerConfig.interdict.maxActivePerOfficer then return fail('interdict_limit') end

    local coords = Security.coords(src)
    nextInterdict = nextInterdict + 1
    local id = nextInterdict
    local area = { id = id, owner = src, x = coords.x, y = coords.y, z = coords.z, radius = radius + 0.0, label = label,
        expiresAt = os.time() + minutes * 60 }
    interdicts[id] = area
    TriggerClientEvent('noir_police:client:interdict', -1, area)
    SetTimeout(minutes * 60000, function() removeInterdict(id) end)
    Integrations.log(src, 'interdict', ('%s interditou "%s" (%dm, %dmin)'):format(Integrations.getName(src), label, radius, minutes))
    return { ok = true, id = id }
end)

lib.callback.register('noir_police:server:removeInterdict', function(src)
    if not Security.police(src) then return fail('not_police') end
    local coords = Security.coords(src)
    local removed = 0
    for id, area in pairs(interdicts) do
        if area.owner == src or #(vector3(area.x, area.y, area.z) - coords) <= area.radius then
            removeInterdict(id)
            removed = removed + 1
        end
    end
    return { ok = true, count = removed }
end)

AddEventHandler('bgrz_core:server:playerLoaded', function(src)
    SetTimeout(2000, function()
        for _, area in pairs(interdicts) do TriggerClientEvent('noir_police:client:interdict', src, area) end
    end)
end)

-- Status de unidade e reunião -------------------------------------------------------

lib.callback.register('noir_police:server:unitStatus', function(src, status)
    if not Security.rateLimit(src, 'status') then return fail('rate_limited') end
    local job = Security.police(src, 'unitStatus')
    if not job then return fail('not_police') end
    local label
    for _, entry in ipairs(Config.unitStatuses) do
        if entry.value == status then label = entry.label end
    end
    if not label then return fail('invalid_input') end
    local coords = Security.coords(src)
    local payload = { unit = officerLabel(src), status = label, x = coords.x, y = coords.y, z = coords.z }
    for _, target in ipairs(departmentRecipients(job.name)) do
        TriggerClientEvent('noir_police:client:unitStatus', target, payload)
    end
    return { ok = true }
end)

lib.callback.register('noir_police:server:meeting', function(src, reason, radio)
    if not Security.rateLimit(src, 'meeting') then return fail('rate_limited') end
    local job = Security.police(src, 'meeting')
    if not job then return fail('not_police') end
    reason = Utils.cleanText(reason, 120, 3)
    radio = Utils.cleanText(tostring(radio or ''), 12) or '-'
    if not reason then return fail('invalid_input') end
    local payload = { from = officerLabel(src), reason = reason, radio = radio }
    for _, target in ipairs(departmentRecipients(job.name)) do
        TriggerClientEvent('noir_police:client:meeting', target, payload)
    end
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, area in pairs(interdicts) do
        if area.owner == src then area.owner = 0 end
    end
end)

return Field
