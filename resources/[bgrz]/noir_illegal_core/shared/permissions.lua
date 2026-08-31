NoirIllegal.Permissions = {
    -- Mutation access is default-deny. Add a resource here and to the matching
    -- activity caller list before enabling an activity.
    publicRecorders = {
        noir_illegal_core = true,
    },
    privileged = {
        -- noir_admin = {
        --     grantUnlock = true,
        --     revokeUnlock = true,
        --     adjustReputation = true,
        --     adjustHeat = true,
        --     invalidateCache = true,
        -- },
    },
    ace = 'noir.illegal.admin',
}
