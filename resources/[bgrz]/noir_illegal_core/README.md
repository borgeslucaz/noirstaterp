# noir_illegal_core

Server-only criminal progression domain service for Qbox.

## Installation

1. Add ensure noir_illegal_core after oxmysql, qbx_core, and noir_gangs.
2. Configure categories, activities, unlocks, levels, and caller permissions.
3. Keep every activity disabled until its owner performs complete server-side gameplay validation.

The resource intentionally has no client scripts, gameplay events, NUI, territory,
inventory, dispatch, or concrete crime implementation.

## Server export convention

Every export returns two values: ok, dataOrError.

Example:

~~~lua
local ok, result = exports.noir_illegal_core:RecordActivity(
    source,
    'drug_sale',
    '575c1c60-03ad-4a64-9849-0b7fe8d43d4f',
    { metadata = { zoneId = 'davis' } }
)
~~~

The caller must be present in shared/permissions.lua and in the activity callers
list. The transaction UUID must remain stable across retries.

## Database

At startup, the resource executes migrations/001_initial.sql statement by
statement. The migrator accepts only CREATE TABLE IF NOT EXISTS and INSERT
IGNORE statements. Existing tables and migration records are therefore left
untouched. After migration, startup validates every required table and fails
closed if the schema is unavailable.
