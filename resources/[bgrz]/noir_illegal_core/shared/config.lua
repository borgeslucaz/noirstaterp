NoirIllegal.Config = {
    Version = '0.1.0',
    Categories = {
        street = true,
        drug = true,
        weapons = true,
        boosting = true,
    },
    Heat = {
        max = 100.0,
        decayPerSecond = 0.0025,
        persistEpsilon = 0.01,
    },
    Cache = {
        ttlSeconds = 60,
        sourceTtlSeconds = 15,
        organizationTtlSeconds = 60,
    },
    Limits = {
        maxActivityDelta = 1000.0,
        maxAdminDelta = 100000.0,
        maxMetadataKeys = 16,
        maxMetadataStringLength = 256,
        maxOccurredAtPastSeconds = 86400,
        maxOccurredAtFutureSeconds = 60,
    },
    AuditRejectedActivities = true,
    Commands = {
        enabled = true,
        developmentActivityCommand = false,
    },
    Debug = false,
}
