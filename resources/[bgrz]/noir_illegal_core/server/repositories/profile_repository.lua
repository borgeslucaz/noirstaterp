local Repository = {}
NoirIllegal.Repositories.Profile = Repository

function Repository.ensure(query, citizenId)
    NoirIllegal.Database.execute(query,
        'INSERT IGNORE INTO noir_illegal_profiles (citizenid) VALUES (?)',
        { citizenId })
end

function Repository.lock(query, citizenId)
    return NoirIllegal.Database.single(query,
        'SELECT citizenid FROM noir_illegal_profiles WHERE citizenid = ? FOR UPDATE',
        { citizenId })
end

function Repository.exists(citizenId)
    return MySQL.scalar.await(
        'SELECT 1 FROM noir_illegal_profiles WHERE citizenid = ? LIMIT 1',
        { citizenId }) ~= nil
end
