-- Loads first in shared_scripts so every other file reads config at load time.

config = {}

-- Allow every connected player to open and save changes in the zone editor.
-- Set to false to restore the framework admin check below.
config.allowEveryone = true

-- Admin-gate framework. Only the selected adapter loads, so no unselected
-- framework runs and you take no framework dependency unless you opt in.
--   'standalone' - cfx ace: add_ace group.admin zonemanager.editor allow
--   'esx'        - xPlayer.getGroup() == 'admin'
--   'qbcore'     - Functions.HasPermission(src, 'admin'|'god')
--   'qbox'       - IsPlayerAceAllowed(src, 'group.admin')
--   'custom'     - wire your own in server/framework/custom.lua
config.framework = 'qbox'

-- Editor fetch/save callback transport. The server admin gate is enforced either way.
--   'internal'  - built-in shim over net events; works on any framework (default)
--   'framework' - the framework's native callbacks; esx/qbcore/qbox only,
--                 else falls back to 'internal' with a warning
config.callbacks = 'internal'
