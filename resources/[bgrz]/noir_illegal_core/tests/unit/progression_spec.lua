-- Run from the resource root with Lua 5.4:
-- lua tests/unit/progression_spec.lua
--
-- Progressão da gang: unlocks de organização, atividade sem autor e a validação de config que
-- impede as combinações que não fazem sentido para uma gang.

NoirIllegal = {}
json = { encode = function() return '{}' end, decode = function() return {} end }
GetGameTimer = function() return 0 end

local events = {}
TriggerEvent = function(name, payload) events[#events + 1] = { name = name, payload = payload } end

dofile('shared/constants.lua')
dofile('shared/config.lua')
dofile('shared/levels.lua')
dofile('shared/unlocks.lua')
dofile('shared/activities.lua')
dofile('shared/permissions.lua')
dofile('server/validators.lua')
dofile('server/services/level_service.lua')
dofile('server/services/eligibility_service.lua')
dofile('server/services/unlock_service.lua')
dofile('server/services/idempotency_service.lua')
dofile('server/services/activity_service.lua')

local function equal(actual, expected, label)
    assert(actual == expected, ('%s: expected %s, got %s'):format(
        label, tostring(expected), tostring(actual)))
end

local function fails(callback, label)
    assert(not pcall(callback), label .. ': expected an error')
end

local V = NoirIllegal.Validators

-- Banco em memória ---------------------------------------------------------------------

local db

local function reset()
    db = { reputation = {}, unlocks = {}, ledger = {} }
    events = {}
end

local function repKey(scope, id) return scope .. ':' .. id end

NoirIllegal.Repositories = {
    Reputation = {
        list = function(scope, id)
            return V.copy(db.reputation[repKey(scope, id)] or {})
        end,
        ensureCategory = function(scope, id, category)
            local key = repKey(scope, id)
            db.reputation[key] = db.reputation[key] or {}
            db.reputation[key][category] = db.reputation[key][category] or 0
        end,
        set = function(scope, id, category, value)
            local key = repKey(scope, id)
            db.reputation[key] = db.reputation[key] or {}
            db.reputation[key][category] = math.max(0, value)
        end,
    },
    Unlock = {
        list = function(scope, id)
            local rows = {}
            for unlockKey, state in pairs(db.unlocks[repKey(scope, id)] or {}) do
                rows[#rows + 1] = { unlock_key = unlockKey, state = state }
            end
            return rows
        end,
        upsert = function(scope, id, unlockKey, state)
            local key = repKey(scope, id)
            db.unlocks[key] = db.unlocks[key] or {}
            db.unlocks[key][unlockKey] = state
        end,
    },
    Activity = {
        findByTransaction = function(transactionId)
            return db.ledger[transactionId]
        end,
        countAccepted = function() return 0 end,
        insert = function(data)
            db.ledger[data.transactionId] = {
                transaction_id = data.transactionId,
                activity_key = data.activityKey,
                caller_resource = data.callerResource,
                citizenid = data.citizenId,
                status = data.status,
                result_payload = data.resultPayload,
            }
        end,
    },
    Audit = { insert = function() end },
}
NoirIllegal.Cache = { invalidateOrganization = function() end, invalidatePlayer = function() end }
NoirIllegal.Logger = { info = function() end, error = function(event, ctx)
    error(event .. ': ' .. tostring(ctx and ctx.error))
end }
MySQL = { startTransaction = function(callback) return callback({}) end }

local Activity = NoirIllegal.Services.Activity
local CORE = 'noir_illegal_core'

-- A config entregue passa na validação --------------------------------------------------

Activity.validateConfiguration()

-- UUID estável --------------------------------------------------------------------------

local stable = V.stableUuid('territory_held:davis:ballas:20354')
assert(V.uuid(stable), 'stable uuid must be a valid uuid')
equal(V.stableUuid('territory_held:davis:ballas:20354'), stable, 'same key, same uuid')
assert(V.stableUuid('territory_held:davis:ballas:20355') ~= stable, 'next period, new uuid')

-- Atividade da gang --------------------------------------------------------------------

reset()
local ok, outcome = Activity.recordOrganization(
    'ballas', 'territory_held', V.stableUuid('a'), { metadata = { zone = 'davis', period = 1 } }, CORE)
equal(ok, true, 'territory_held accepted')
equal(db.reputation['organization:ballas'].drug, 5, 'territory_held pays the gang')
equal(outcome.applied.organization.drug, 5, 'applied delta reported')

ok = Activity.recordOrganization('ballas', 'territory_held', V.stableUuid('a'), {}, CORE)
equal(ok, true, 'replay answers ok')
equal(db.reputation['organization:ballas'].drug, 5, 'replay does not pay twice')

ok, outcome = Activity.recordOrganization('ballas', 'territory_lost', V.stableUuid('b'), {}, CORE)
equal(ok, true, 'territory_lost accepted')
equal(db.reputation['organization:ballas'].drug, 0, 'loss is floored at zero')
equal(outcome.applied.organization.drug, -5, 'applied delta is what was actually lost')

ok, outcome = Activity.recordOrganization('ballas', 'drug_sale', V.stableUuid('c'), {}, CORE)
equal(ok, false, 'player activity refused on organization path')
equal(outcome.code, 'INVALID_ACTIVITY', 'player activity refusal code')

ok, outcome = Activity.recordOrganization('ballas', 'territory_held', V.stableUuid('d'), {}, 'noir_outposts')
equal(ok, false, 'unknown caller refused')
equal(outcome.code, 'FORBIDDEN_CALLER', 'caller refusal code')

ok, outcome = Activity.recordOrganization('none', 'territory_held', V.stableUuid('e'), {}, CORE)
equal(ok, false, 'gang none refused')

-- Unlock de gang: chega no nível e o contato abre --------------------------------------

reset()
db.reputation['organization:ballas'] = { drug = 299 }
Activity.recordOrganization('ballas', 'territory_held', V.stableUuid('f'), {}, CORE)
equal(db.unlocks['organization:ballas'].contact_meth, 'granted', 'level 2 grants contact_meth')
equal(db.unlocks['organization:ballas'].contact_coke, nil, 'level 2 does not grant contact_coke')
local unlockEvent
for _, event in ipairs(events) do
    if event.name == 'noir_illegal_core:server:unlockGranted' then unlockEvent = event.payload end
end
assert(unlockEvent, 'unlockGranted emitted')
equal(unlockEvent.scope, 'organization', 'unlock event scope')
equal(unlockEvent.subjectId, 'ballas', 'unlock event subject')

-- Os dois limiares de uma vez: a dependência entre contatos resolve na mesma atividade,
-- qualquer que seja a ordem do pairs.
-- O `pairs` do Lua 5.4 muda de ordem a cada execução; o teste força a ordem ruim, coca antes da
-- meth, para não passar por sorte.
local function cokeFirst(unlocks)
    local order = { 'contact_coke', 'contact_meth' }
    for key in next, unlocks do
        if key ~= 'contact_coke' and key ~= 'contact_meth' then order[#order + 1] = key end
    end
    local index = 0
    return function()
        index = index + 1
        local key = order[index]
        if key then return key, rawget(unlocks, key) end
    end
end
setmetatable(NoirIllegal.Unlocks, { __pairs = function(t) return cokeFirst(t) end })

reset()
db.reputation['organization:vagos'] = { drug = 1499 }
Activity.recordOrganization('vagos', 'territory_held', V.stableUuid('g'), {}, CORE)
equal(db.unlocks['organization:vagos'].contact_meth, 'granted', 'chained: meth')
equal(db.unlocks['organization:vagos'].contact_coke, 'granted', 'chained: coke in the same pass')

-- Revogado por admin não volta sozinho, e sem meth não há coca.
reset()
db.reputation['organization:families'] = { drug = 1499 }
db.unlocks['organization:families'] = { contact_meth = 'revoked' }
Activity.recordOrganization('families', 'territory_held', V.stableUuid('h'), {}, CORE)
equal(db.unlocks['organization:families'].contact_meth, 'revoked', 'revoked stays revoked')
equal(db.unlocks['organization:families'].contact_coke, nil, 'coke needs the gang meth contact')

-- O candidato da gang lê os unlocks da GANG. O jogador ter o contato não vale por ela.
local granted = NoirIllegal.Services.Unlock.evaluateAutomatic({
    player = {
        id = 'CID1', reputations = { drug = 5000 }, heat = 0,
        unlockRows = { { unlock_key = 'contact_meth', state = 'granted' } },
    },
    organization = { id = 'lostmc', reputations = { drug = 1500 }, unlockRows = {} },
}, {}, { actorId = CORE })
local grantedKeys = {}
for _, entry in ipairs(granted) do grantedKeys[entry.scope .. ':' .. entry.key] = true end
assert(grantedKeys['organization:contact_meth'], 'gang gets its own meth contact')
assert(grantedKeys['organization:contact_coke'], 'then coke, from the gang unlocks')
assert(grantedKeys['player:dealer_contact'], 'player unlock still evaluated')

-- Validação de config ------------------------------------------------------------------

local function withUnlock(key, definition, callback)
    NoirIllegal.Unlocks[key] = definition
    local okCall, err = pcall(callback)
    NoirIllegal.Unlocks[key] = nil
    assert(not okCall, key .. ': expected validation error')
    return err
end

withUnlock('bad_heat', { scope = 'organization', automatic = true, requirements = { maxHeat = 10 } },
    NoirIllegal.Services.Unlock.validateConfiguration)
withUnlock('bad_dep', { scope = 'organization', automatic = true, requirements = { unlocks = { 'dealer_contact' } } },
    NoirIllegal.Services.Unlock.validateConfiguration)
withUnlock('bad_scope', { scope = 'crew', automatic = true },
    NoirIllegal.Services.Unlock.validateConfiguration)

local function withActivity(key, definition, label)
    NoirIllegal.Activities[key] = definition
    fails(Activity.validateConfiguration, label)
    NoirIllegal.Activities[key] = nil
end

withActivity('bad_negative', {
    enabled = true, callers = { CORE }, organization = { drug = -1 },
}, 'player activity cannot take reputation away')
withActivity('bad_personal', {
    enabled = true, subject = 'organization', callers = { CORE },
    personal = { drug = 1 }, organization = { drug = 1 },
}, 'organization activity cannot move personal reputation')
withActivity('bad_heat', {
    enabled = true, subject = 'organization', callers = { CORE }, heat = 1, organization = { drug = 1 },
}, 'organization activity cannot assign heat')
withActivity('bad_diminishing', {
    enabled = true, subject = 'organization', callers = { CORE }, organization = { drug = 1 },
    diminishingReturns = { windowSeconds = 60, softCap = 1, floorMultiplier = 0.5,
        curve = 'linear', key = 'player:activity' },
}, 'organization activity diminishes per organization')

Activity.validateConfiguration()

print('progression_spec: ok')
