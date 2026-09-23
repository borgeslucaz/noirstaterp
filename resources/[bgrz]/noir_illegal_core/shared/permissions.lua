NoirIllegal.Permissions = {
    -- Mutation access is default-deny. Add a resource here and to the matching
    -- activity caller list before enabling an activity.
    publicRecorders = {
        -- Os resources de gameplay não registram atividade direto: eles anunciam o fato por
        -- evento e os adaptadores em `server/adapters/` registram em nome do próprio core.
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
