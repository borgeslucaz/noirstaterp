# noir_illegal_core — Implementation Specification

**Resource:** noir_illegal_core  
**Target:** FiveM / Qbox / Lua 5.4 / oxmysql  
**Initial release:** v0.1.0  
**Scope:** Server-authoritative criminal state and progression only.

## 1. Purpose and boundaries

noir_illegal_core is a reusable domain resource for criminal progression. Illegal-gameplay resources validate their own gameplay server-side, then call this core to record an activity and query progression. The core owns personal and organization reputation, heat, an immutable activity ledger, derived levels, unlocks, cooldowns, diminishing returns, idempotency, cache, audit records, and server-side integrations.

It must not implement:

- territories/turf, drugs, robberies, boosting, crafting, laundering, black markets, dispatch, inventories, gameplay NUI, or any concrete crime loop;
- gang recruitment, removal, promotion, demotion, ranks, permissions, ownership, member lists, or gang creation;
- a player-facing event/callback that awards reputation or otherwise mutates progression.

A feature resource owns gameplay validation. noir_illegal_core owns the resulting state mutation. Client code must never be able to award reputation, change heat, grant an unlock, or supply a player/organization identity for a mutation.

### Integration boundary: noir_gangs

noir_gangs is the source of truth for gangs. It already owns membership, ranks, permissions, recruitment, promotions, and dismissals. The installed resource currently exposes:

~~~lua
exports.noir_gangs:GetGang(source)
-- Qbox gang object or nil:
-- { name = 'families', label = 'The Families',
--   grade = { level = 2, name = 'Enforcer' }, ... }
~~~

Only server/bridges/gangs.lua may call that export. It normalizes it:

~~~lua
{ id = 'families', label = 'The Families', grade = 2, gradeName = 'Enforcer' }
~~~

The core never creates a gang membership table and never caches membership as authoritative state. Its organization-reputation rows are keyed by organization_id. Every player request that needs current membership resolves it from noir_gangs. If noir_gangs changes its export to GetPlayerGang later, adapt only the bridge.

## 2. Architecture

~~~text
feature resource server logic
  -> noir_illegal_core server export / caller authorization
  -> ActivityService -> PolicyService / HeatService / UnlockService
  -> repositories -> one oxmysql transaction -> MySQL
  -> post-commit cache update + internal server events + audit/logging

QboxBridge: source -> Qbox player/citizenid
GangBridge: source -> noir_gangs current organization
~~~

Rules:

1. Normal mutations enter through RecordActivity only.
2. Direct adjustment APIs are privileged, explicitly allow-listed, and audited.
3. Ledger, reputation, heat, cooldown, unlock, and audit writes for one activity commit atomically.
4. MySQL is authoritative. Cache is an optimization only.
5. Internal events notify consumers after a commit; they are never a mutation command channel.

## 3. Directory layout

~~~text
noir_illegal_core/
├── fxmanifest.lua
├── README.md
├── shared/
│   ├── constants.lua             # error codes and enums
│   ├── config.lua                # cache, heat, logging, command defaults
│   ├── activities.lua            # activity registry
│   ├── levels.lua                # deterministic thresholds
│   ├── unlocks.lua               # unlock definitions
│   └── permissions.lua           # caller/privileged allow lists
├── server/
│   ├── init.lua
│   ├── api.lua                   # exports only; no business logic/SQL
│   ├── commands.lua
│   ├── cache.lua
│   ├── logger.lua
│   ├── validators.lua
│   ├── bridges/qbox.lua
│   ├── bridges/gangs.lua
│   ├── repositories/
│   │   ├── profile_repository.lua
│   │   ├── reputation_repository.lua
│   │   ├── heat_repository.lua
│   │   ├── unlock_repository.lua
│   │   ├── activity_repository.lua
│   │   └── audit_repository.lua
│   └── services/
│       ├── activity_service.lua
│       ├── profile_service.lua
│       ├── reputation_service.lua
│       ├── level_service.lua
│       ├── heat_service.lua
│       ├── unlock_service.lua
│       ├── eligibility_service.lua
│       ├── cooldown_service.lua
│       ├── idempotency_service.lua
│       └── audit_service.lua
├── migrations/001_initial.sql
└── tests/{unit,integration,fixtures}/
~~~

fxmanifest.lua must use server_only 'yes', Lua 5.4, @oxmysql/lib/MySQL.lua, and server scripts only. Dependencies: qbx_core, oxmysql, noir_gangs. ox_lib is optional, and only for server helpers if actually used.

## 4. Domain model

- **Player subject:** Qbox citizenid, never a transient source.
- **Organization subject:** normalized noir_gangs id (currently Qbox gang name).
- **Category:** config-defined generic key, for example street, drug, weapons, boosting. Categories do not implement their underlying gameplay.
- **Reputation:** non-negative decimal per subject/category.
- **Level:** derived at read/write time from reputation and levels.lua; never mutable authoritative data.
- **Heat:** decimal in [0, Config.Heat.max], reduced lazily from last_decay_at.
- **Unlock:** named player or organization entitlement, automatic or manually granted/revoked.
- **Activity:** immutable accepted/rejected request stored in the ledger. transactionId is its idempotency key.

Callers cannot supply arbitrary reputation/heat deltas to RecordActivity. The activity registry supplies the deltas. Privileged adjustments require an explicit permission and complete audit record.

## 5. Configuration

### Activity registry (shared/activities.lua)

~~~lua
return {
    drug_sale = {
        enabled = true,
        callers = { 'noir_drugs' },
        cooldownSeconds = 45,
        idempotencyTtlSeconds = 2592000,
        personal = { drug = 2, street = 1 },
        organization = { drug = 1 },
        heat = 0.35,
        diminishingReturns = {
            windowSeconds = 3600,
            softCap = 20,
            floorMultiplier = 0.20,
            curve = 'linear',
            key = 'player:activity',
        },
        requirements = { minLevel = { drug = 1 } },
        metadata = { allow = { 'zoneId', 'saleType', 'targetId' } },
    },
}
~~~

Examples document the integration shape only. No activity is active unless its owner is installed and allow-listed. Validate registry startup: reject duplicate keys, unknown category/unlock keys, unsafe metadata, unknown caller resources, negative cooldowns, or deltas outside configured bounds.

### Levels (shared/levels.lua)

~~~lua
return {
  drug = {
    { level = 0, minReputation = 0 },
    { level = 1, minReputation = 100 },
    { level = 2, minReputation = 300 },
    { level = 3, minReputation = 700 },
  },
}
~~~

Thresholds are strictly increasing. GetLevel returns the highest threshold at or below current reputation. A curve change must be versioned and tested against persisted values.

### Caller permissions (shared/permissions.lua)

~~~lua
return {
  publicRecorders = { noir_drugs = true, noir_boosting = true },
  privileged = {
    noir_admin = {
      grantUnlock = true, revokeUnlock = true,
      adjustReputation = true, adjustHeat = true,
    },
  },
  ace = 'noir.illegal.admin',
}
~~~

Use GetInvokingResource(), not a caller name parameter. Nil, unknown, or unauthorized callers receive FORBIDDEN_CALLER. Console/admin commands require the ACE permission. Default deny.

## 6. Initial SQL schema

Save as migrations/001_initial.sql. Use InnoDB, utf8mb4, UTC database timestamps, and DECIMAL(12,4) for fractional state. A migration runner records successful versions. Normal runtime paths must not perform DDL.

~~~sql
CREATE TABLE IF NOT EXISTS noir_illegal_schema_migrations (
  version VARCHAR(64) NOT NULL,
  applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_profiles (
  citizenid VARCHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_player_reputation (
  citizenid VARCHAR(64) NOT NULL,
  category VARCHAR(64) NOT NULL,
  value DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (citizenid, category),
  CONSTRAINT chk_noir_illegal_player_rep_nonnegative CHECK (value >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_organization_reputation (
  organization_id VARCHAR(64) NOT NULL,
  category VARCHAR(64) NOT NULL,
  value DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (organization_id, category),
  CONSTRAINT chk_noir_illegal_org_rep_nonnegative CHECK (value >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_player_heat (
  citizenid VARCHAR(64) NOT NULL,
  value DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  last_decay_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (citizenid),
  CONSTRAINT chk_noir_illegal_player_heat_nonnegative CHECK (value >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_unlocks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  subject_type ENUM('player', 'organization') NOT NULL,
  subject_id VARCHAR(64) NOT NULL,
  unlock_key VARCHAR(96) NOT NULL,
  state ENUM('granted', 'revoked') NOT NULL DEFAULT 'granted',
  source VARCHAR(96) NOT NULL,
  granted_by VARCHAR(128) NULL,
  reason VARCHAR(255) NULL,
  metadata JSON NULL,
  granted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at DATETIME NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_noir_illegal_unlock_subject_key (subject_type, subject_id, unlock_key),
  KEY idx_noir_illegal_unlock_lookup (subject_type, subject_id, state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_cooldowns (
  subject_type ENUM('player', 'organization') NOT NULL,
  subject_id VARCHAR(64) NOT NULL,
  cooldown_key VARCHAR(128) NOT NULL,
  expires_at DATETIME NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (subject_type, subject_id, cooldown_key),
  KEY idx_noir_illegal_cooldown_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_activity_ledger (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  transaction_id CHAR(36) NOT NULL,
  activity_key VARCHAR(96) NOT NULL,
  caller_resource VARCHAR(128) NOT NULL,
  citizenid VARCHAR(64) NOT NULL,
  organization_id VARCHAR(64) NULL,
  status ENUM('accepted', 'rejected') NOT NULL,
  rejection_code VARCHAR(64) NULL,
  base_personal JSON NOT NULL,
  applied_personal JSON NOT NULL,
  base_organization JSON NOT NULL,
  applied_organization JSON NOT NULL,
  base_heat DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  applied_heat DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  diminishing_multiplier DECIMAL(8,4) NOT NULL DEFAULT 1.0000,
  metadata JSON NULL,
  occurred_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_noir_illegal_ledger_transaction (transaction_id),
  KEY idx_noir_illegal_ledger_citizen_activity_time (citizenid, activity_key, occurred_at),
  KEY idx_noir_illegal_ledger_org_activity_time (organization_id, activity_key, occurred_at),
  KEY idx_noir_illegal_ledger_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  action VARCHAR(96) NOT NULL,
  actor_type ENUM('resource', 'player', 'console', 'system') NOT NULL,
  actor_id VARCHAR(128) NOT NULL,
  target_type VARCHAR(32) NULL,
  target_id VARCHAR(128) NULL,
  transaction_id CHAR(36) NULL,
  before_state JSON NULL,
  after_state JSON NULL,
  metadata JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_noir_illegal_audit_target (target_type, target_id, created_at),
  KEY idx_noir_illegal_audit_transaction (transaction_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
~~~

Use parameterized SQL. Upserts and clamps occur only inside a transaction. Sanitized plain tables only may enter JSON columns. Rejected-ledger writes must preserve the exact same transactionId uniqueness behavior.

## 7. RecordActivity

### Export contract

~~~lua
---@param source number
---@param activityKey string
---@param transactionId string   -- canonical UUID, stable across caller retry
---@param options? table
---@return boolean ok
---@return table resultOrError
exports('RecordActivity', function(source, activityKey, transactionId, options) end)
~~~

The only accepted option keys are:

~~~lua
{
  occurredAt = os.time(),      -- optional; server clamps skew/age
  organizationId = nil,        -- ignored unless equal to bridge result
  metadata = { zoneId = 'davis' }, -- registry allow-list filters this
}
~~~

Success:

~~~lua
{
  ok = true, transactionId = 'uuid', replayed = false, activity = 'drug_sale',
  profile = { citizenId = '...', organization = { id = 'families', label = 'Families' } },
  applied = { personal = { drug = 1.6 }, organization = { drug = 0.8 }, heat = 0.28 },
  levels = { before = { drug = 1 }, after = { drug = 1 } },
  unlocksGranted = { 'dealer_contact' },
}
~~~

Failure:

~~~lua
{ ok = false, code = 'COOLDOWN_ACTIVE',
  message = 'Activity cooldown is active.', retryAt = 1735689600 }
~~~

### Algorithm

1. Verify GetInvokingResource against both the global recorder permission and the activity caller allow-list.
2. Resolve source through Qbox and obtain citizenid. Reject disconnected/invalid sources.
3. Validate activity key, canonical UUID, timestamp bounds, and options shape. Never silently generate a transactionId.
4. Resolve the current organization via GangBridge. Reject a supplied organizationId that differs.
5. In one oxmysql transaction, look up transactionId using a uniqueness-safe strategy. For an identical prior request return its persisted result with replayed = true. For a different request identity return DUPLICATE_TRANSACTION.
6. Create minimum profile/heat rows if missing and apply heat decay inside the transaction.
7. Evaluate activity enabled state, eligibility, cooldown, and rolling-window diminishing-return count. Optionally ledger rejected requests when Config.AuditRejectedActivities is true; rejected requests never mutate progression.
8. Compute resolved deltas. Apply personal and organization reputation, heat, and cooldown writes; derive before/after levels; grant any automatic unlocks.
9. Insert accepted ledger and audit entries, then commit. A duplicate-key race must select and return the original outcome.
10. Only after commit, write-through/invalidate affected cache keys and emit internal events.

One activity must be all-or-nothing across ledger, rep, heat, cooldown, unlock, and audit state.

### Diminishing returns

For n accepted matching ledger entries before the new activity:

~~~text
multiplier = 1                                               if n < softCap
multiplier = max(floorMultiplier, 1 - (n - softCap + 1)/softCap) otherwise
appliedDelta = round(baseDelta * multiplier, 4)
~~~

Count only accepted ledger rows. Registry key determines player+activity, player+category, or organization+activity. v0.1.0 rejects negative configured deltas. Store base values, multiplier, and applied values in the ledger.

## 8. Read export contracts

All reads are server-only and return immutable copies, never a cached table reference.

~~~lua
exports('GetProfile', function(source) end)
-- profile: { citizenId, reputations, levels, heat, organization|nil, unlocks }

exports('GetReputation', function(source, category) end)
exports('GetLevel', function(source, category) end)
exports('GetHeat', function(source) end)
exports('HasUnlock', function(source, unlockKey) end)
exports('IsEligible', function(source, activityKey, options) end)
exports('GetOrganization', function(source) end)
exports('GetOrganizationReputation', function(source, category) end)
~~~

Each returns ok, dataOrError. GetOrganization returns ok=true, data=nil when the player has no gang. GetHeat applies lazy decay, persists it when required, refreshes cache, and emits heatChanged with reason = decay only if effective heat changed.

## 9. Unlocks, eligibility, and privileged exports

Unlock configuration:

~~~lua
dealer_contact = {
  scope = 'player',
  automatic = true,
  requirements = { reputation = { drug = 200 }, maxHeat = 25 },
  manualGrantOverridesRequirements = true,
}
~~~

IsEligible evaluates configured activity status, requirements, unlocks, max heat, current organization conditions, and current cooldown. It does not reserve a cooldown or start gameplay.

Manual unlock APIs are privileged:

~~~lua
exports('GrantUnlock', function(subject, unlockKey, reason, metadata) end)
exports('RevokeUnlock', function(subject, unlockKey, reason, metadata) end)
-- subject = { type = 'player', citizenId = '...' }
--        or { type = 'organization', id = 'families' }
~~~

They obtain actor identity from GetInvokingResource, upsert state rather than deleting history, write before/after audit data, invalidate cache, and emit only when effective state changes.

Direct state adjustments are privileged and disabled unless permissions.lua enables them:

~~~lua
exports('AdjustReputation', function(subject, category, delta, reason, transactionId) end)
exports('SetHeat', function(citizenId, value, reason, transactionId) end)
exports('AdjustHeat', function(citizenId, delta, reason, transactionId) end)
exports('InvalidateCache', function(citizenId) end)
~~~

They must require a UUID except cache invalidation, bound adjustment magnitude, use transactional writes, audit all changes, and return FORBIDDEN_CALLER before exposing target details.

## 10. Internal events

Emit after commit only. Register consumers with AddEventHandler; do not use RegisterNetEvent for these notifications.

~~~lua
TriggerEvent('noir_illegal_core:server:activityRecorded', payload)
TriggerEvent('noir_illegal_core:server:reputationChanged', payload)
TriggerEvent('noir_illegal_core:server:levelChanged', payload)
TriggerEvent('noir_illegal_core:server:heatChanged', payload)
TriggerEvent('noir_illegal_core:server:unlockGranted', payload)
~~~

Every payload includes transactionId, citizenId, online source when available, callerResource, occurredAt, and sanitized metadata. State payloads add scope (player/organization), subjectId, category where relevant, before, after, delta, and reason. activityRecorded adds activityKey, resolved deltas, multiplier, and replayed=false.

Order: activityRecorded; each reputationChanged; each levelChanged; heatChanged; each unlockGranted. Never emit for replay, rejected work, failed transactions, or no-op changes.

## 11. Heat decay and cache

### Lazy heat decay

~~~text
elapsed = max(0, now - last_decay_at)
decay = elapsed * Config.Heat.decayPerSecond
newHeat = clamp(oldHeat - decay, 0, Config.Heat.max)
~~~

Run it before every heat read/check/write. Persist it within a transaction when the change exceeds Config.Heat.persistEpsilon or a mutation already commits. Do not run a global periodic sweep over all player rows.

### Cache

- Cache profile by citizenid and organization reputation by organizationId.
- Configurable TTL defaults to 60 seconds.
- Cache current source-to-citizen mapping briefly; never cache authorization or gang membership as truth.
- Store loadedAt, expiresAt, and updatedAt/version marker.
- Commit first, then invalidate/write through every affected cache entry.
- A missing profile can lazily create profile/zero-heat records. No-gang may be short negative-cached.
- Disconnect clears source mapping only, not durable state.

## 12. Repository and service separation

Repositories contain parameterized SQL and map rows only. Services own validation, calculation, transaction orchestration, audit, cache updates, and events. Bridges isolate qbx_core/noir_gangs shape changes. api.lua validates export arguments, identifies the caller, and delegates; it contains no SQL or domain calculation.

Use one MySQL.transaction.await per write. Do not nest transactions; pass the transaction executor to collaborating services. Convert database exceptions to DATABASE_ERROR, log original details server-side, and never return SQL text to callers.

## 13. Standard errors and logging

All expected failures return:

~~~lua
{ ok = false, code = 'INVALID_ACTIVITY', message = 'Unknown activity key.', details = nil }
~~~

Stable v0.1.0 error codes:

| Code | Meaning |
|---|---|
| INVALID_SOURCE | Invalid/offline source or no Qbox player. |
| INVALID_ARGUMENT | Invalid type, UUID, timestamp, category, unlock, or metadata. |
| FORBIDDEN_CALLER | Caller resource/ACE lacks permission. |
| ACTIVITY_DISABLED | Registered activity is disabled. |
| INVALID_ACTIVITY | Activity is not registered. |
| ORGANIZATION_MISMATCH | Supplied organization differs from GangBridge. |
| NOT_ELIGIBLE | Configured requirement is unmet. |
| COOLDOWN_ACTIVE | Cooldown active; include retryAt. |
| DUPLICATE_TRANSACTION | Same UUID reused with a different immutable request identity. |
| NOT_FOUND | Missing durable entity where absence is an error. |
| DATABASE_ERROR | Query/transaction failed; consult server log. |
| INTERNAL_ERROR | Unexpected controlled failure. |

Structured logs include event, transactionId, caller resource, citizenid, organizationId, activity key, code, and duration. Redact configured sensitive metadata. Accepted mutation: info; routine denial/cooldown: debug or sampled warn; idempotency conflict: warn; persistence failure: error.

The durable audit log is mandatory for accepted activities and privileged changes. Preserve actor, reason/source, sanitized before/after values, and transactionId. Do not automatically delete audit history in v0.1.0; document a separate indexed archival process.

## 14. Admin and debug commands

Commands are server-side, ACE-gated, available only with Config.Commands.enabled, and return output only to console/invoking admin.

~~~text
/noirillegal profile <serverId>
/noirillegal activity <serverId> <activityKey> <uuid>
/noirillegal grant <player|organization> <id> <unlockKey> <reason...>
/noirillegal revoke <player|organization> <id> <unlockKey> <reason...>
/noirillegal rep <player|organization> <id> <category> <delta> <uuid> <reason...>
/noirillegal heat <serverId> <set|add> <value> <uuid> <reason...>
/noirillegal cache <serverId|all> clear
~~~

Commands use the same services, authorization, idempotency, audit, and event paths as exports. The activity command is development-only and disabled in production. Debug mode must increase diagnostics only; it must never bypass policy.

## 15. Security requirements

- No RegisterNetEvent in this resource may mutate reputation, heat, unlocks, cooldowns, or activities from a client.
- Do not provide generic AddRep, SetRep, arbitrary SQL, or arbitrary-action exports.
- Validate source, timestamp, metadata, UUID, registered keys, numeric range, and organization server-side.
- Resolve citizenid and current organization server-side.
- Use GetInvokingResource plus allow lists, never a claimed caller parameter.
- Keep server_only 'yes' and expose no state through state bags.
- Internal notification handlers use AddEventHandler, not network registration.

## 16. v0.1.0 milestones

1. **Foundation:** manifest, config validation, Qbox/Gang bridges, logging, migrations, startup health checks.
2. **Read model:** repositories, cache, lazy heat decay, all read exports.
3. **Activity path:** caller authorization, idempotency, ledger, atomic rep/heat/cooldown updates, diminishing returns, events.
4. **Progression:** derived levels, automatic/manual unlocks, eligibility, complete audit.
5. **Operations:** ACE commands, metrics/log docs, test fixture resource, migration/rollback documentation.

## 17. Tests

Unit tests must cover:

- threshold boundaries; every diminishing-return branch;
- zero/partial/capped heat decay, clock skew, and persist epsilon;
- cooldowns, eligibility, unlock requirements, metadata filtering, and caller permissions;
- noir_gangs bridge normalization for no gang, valid gang, unexpected shape;
- identical UUID replay and conflicting UUID rejection.

Integration tests against test MySQL must prove:

- RecordActivity produces exactly one ledger row and expected rep, heat, cooldown, unlock, audit state;
- a transaction failure rolls back every dependent write;
- concurrent identical UUID calls produce one mutation and one replay;
- concurrent distinct UUID calls preserve totals;
- cache invalidates after commit and does not return stale changed state;
- lazy decay persists correctly;
- privileged operations deny unauthorized resources and audit authorized ones;
- static event/manifest validation confirms no client mutation path.

Use fake Qbox/Gang bridges for deterministic service tests; use real oxmysql query shapes in integration tests where supported.

## 18. Acceptance criteria

v0.1.0 is accepted only if:

- noir_gangs remains the exclusive owner of gang membership, ranks, and permissions; the core has no membership table or management API.
- An allow-listed server resource records a configured activity with UUID and gets a resolved result exactly once across retries.
- Unknown callers, client events, arbitrary deltas, invalid sources, and organization mismatch cannot mutate state.
- Ledger, personal/org reputation, heat, cooldown, unlock, and audit changes are atomic.
- Heat decays lazily and remains within zero and configured maximum.
- Levels are completely derived from current configuration/reputation; threshold events occur only after commit.
- Diminishing returns, cooldowns, and unlock decisions are config-driven and explainable from ledger/audit records.
- Every normal/privileged mutation is traceable by transactionId, actor, reason/source, before/after state, and timestamp.
- Exports, error codes, commands, migration, and tests documented above are implemented and passing.

## 19. Implementation sequence

Implement migrations and typed service contracts first. Then implement one development fixture activity to validate the complete path before onboarding a real gameplay resource. Keep feature resource names only in configuration. Do not add gameplay UI, territory, inventory, dispatch, or concrete crime mechanics while implementing this core.

