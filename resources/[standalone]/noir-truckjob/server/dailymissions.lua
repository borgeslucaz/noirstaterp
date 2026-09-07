DailyMissions = DailyMissions or {}

function DailyMissions.NewSet()
    local data = {}
    for key, entry in pairs(Config.DailyMissions or {}) do data[key] = { progress = 0, claimed = false, max = entry.max, xp = entry.xp } end
    return { day = os.date('!%Y-%m-%d'), data = data }
end

function DailyMissions.Project(set) return set or DailyMissions.NewSet() end

function DailyMissions.CheckReset(src, profile)
    local today = os.date('!%Y-%m-%d')
    if not profile.dailymissions or profile.dailymissions.day ~= today then
        profile.dailymissions = DailyMissions.NewSet()
        ExecuteSqlAsync('UPDATE noir_truckjob_players SET dailymissions = ? WHERE identifier = ?', { json.encode(profile.dailymissions), profile.identifier })
        SyncPlayerDataByKey(src, 'dailymissions', DailyMissions.Project(profile.dailymissions))
    end
end

local function Advance(src, profile, key)
    local entry = profile.dailymissions.data[key]
    if not entry or entry.claimed then return end
    entry.progress = math.min(entry.max, entry.progress + 1)
    if entry.progress >= entry.max then entry.claimed = true; AddXP(src, entry.xp) end
    ExecuteSqlAsync('UPDATE noir_truckjob_players SET dailymissions = ? WHERE identifier = ?', { json.encode(profile.dailymissions), profile.identifier })
    SyncPlayerDataByKey(src, 'dailymissions', DailyMissions.Project(profile.dailymissions))
end

function DailyMissions.OnDelivery(src, profile, result)
    DailyMissions.CheckReset(src, profile)
    Advance(src, profile, 'complete_global')
    if result.grade == 'S' or result.grade == 'A' then Advance(src, profile, 'grade_a_or_s') end
    if result.tier == 'medium' and (result.integrityPct or 0) >= 99 then Advance(src, profile, 'medium_no_damage') end
    if result.completedBeforeExpiry then Advance(src, profile, 'before_rotation_expiry') end
end
