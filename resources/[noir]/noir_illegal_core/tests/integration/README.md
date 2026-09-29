# Integration test matrix

Run these cases against an isolated MySQL database and a test FXServer with fake
Qbox/noir_gangs resources:

1. Accepted activity commits one ledger row and all expected dependent state.
2. Forced query failure rolls the entire activity back.
3. Two concurrent calls with one UUID produce one mutation and one replay.
4. Concurrent distinct UUIDs preserve exact reputation totals.
5. Cache is invalidated only after commit.
6. Heat decay persists and clamps at zero.
7. Unknown mutation callers receive FORBIDDEN_CALLER.
8. Privileged changes write audit rows and emit post-commit events.

The resource applies migration 001_initial automatically and then validates the
schema. The test database user therefore needs CREATE, ALTER, INDEX, INSERT,
SELECT, and DML permissions for the noir_illegal_* tables.
