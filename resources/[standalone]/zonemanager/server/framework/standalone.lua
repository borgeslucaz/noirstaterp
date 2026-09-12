-- Standalone framework adapter. No framework; admin gates on cfx ace.
-- Grant with: add_ace group.admin zonemanager.editor allow

return {
    isAdmin = function(src)
        return IsPlayerAceAllowed(src, 'zonemanager.editor')
    end,
}
