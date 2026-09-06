-- ============================================================
-- XP — nível e experiência (determinístico; o valor vem sempre de
-- Config.RouteMeta × nota, nunca de sorteio nem do client).
-- ============================================================

local function Persist(identifier, myData)
    ExecuteSqlAsync(
        'UPDATE peak_trucking SET `level` = :level, `xp` = :xp WHERE `identifier` = :id',
        { level = myData.level, xp = myData.xp, id = identifier }
    )
end

--- Adds XP to a player, applying as many level-ups as the amount allows.
--- Mission availability is derived from level/reputation at read time, so
--- nothing else needs to be unlocked here.
--- @param source number
--- @param xp number
--- @return number newLevel, boolean leveledUp
function AddXP(source, xp)
    local myData = GetPlayerJobData(source)
    xp = math.floor(tonumber(xp) or 0)
    if not myData or xp <= 0 then return myData and myData.level or 1, false end

    local maxLevel = #Config.XP
    local level = tonumber(myData.level) or 1
    local current = tonumber(myData.xp) or 0
    local leveled = false

    if level >= maxLevel then
        myData.level = maxLevel
        myData.xp = 0
        return maxLevel, false
    end

    current = current + xp
    while level < maxLevel and Config.XP[level] and current >= Config.XP[level] do
        current = current - Config.XP[level]
        level = level + 1
        leveled = true
    end
    if level >= maxLevel then
        level = maxLevel
        current = 0
    end

    myData.level = level
    myData.xp = current

    SyncPlayerDataByKey(source, 'xp', myData.xp)
    SyncPlayerDataByKey(source, 'level', myData.level)
    Persist(myData.identifier, myData)

    return level, leveled
end
