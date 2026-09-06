-- ============================================================
-- DAILY MISSIONS — progresso calculado somente a partir de
-- conclusões validadas; recompensa concedida uma única vez.
-- ============================================================
DailyMissions = DailyMissions or {}

local DAY_SECONDS = 86400

--- Novo conjunto diário a partir de Config.DailyMissions.
function DailyMissions.NewSet()
    local data = {}
    for key, mission in pairs(Config.DailyMissions) do
        data[key] = {
            key = key,
            max = tonumber(mission.max) or 1,
            xp = tonumber(mission.xp) or 0,
            reputation = tonumber(mission.reputation) or 0,
            process = 0,
            claimed = false,
            companies = {}, -- usado por two_companies
        }
    end
    -- Reset alinhado ao relógio do servidor (meia-noite UTC seguinte)
    local now = os.time()
    local resetAt = (math.floor(now / DAY_SECONDS) + 1) * DAY_SECONDS
    return { data = data, resetAt = resetAt }
end

--- Projeção para a NUI (textos resolvidos por locale).
function DailyMissions.Project(set)
    if not set or type(set) ~= 'table' then return { data = {}, resetAt = os.time() } end
    local out = { data = {}, resetAt = set.resetAt }
    for key, entry in pairs(set.data or {}) do
        local cfg = Config.DailyMissions[key]
        if cfg then
            out.data[key] = {
                key = key,
                header = L(cfg.header),
                label = L(cfg.label),
                max = entry.max,
                xp = entry.xp,
                reputation = entry.reputation or 0,
                process = entry.process or 0,
                claimed = entry.claimed == true,
            }
        end
    end
    return out
end

local function Persist(src, profile)
    SyncPlayerDataByKey(src, 'dailymissions', DailyMissions.Project(profile.dailymissions))
    ExecuteSqlAsync(
        'UPDATE peak_trucking SET `dailymissions` = :missions WHERE `identifier` = :id',
        { missions = json.encode(profile.dailymissions), id = profile.identifier }
    )
end

--- Reseta o conjunto quando o relógio canônico do servidor passa de resetAt.
function DailyMissions.CheckReset(src, profile)
    local set = profile.dailymissions
    local needsReset = type(set) ~= 'table' or type(set.data) ~= 'table' or not set.resetAt or os.time() >= tonumber(set.resetAt)

    if not needsReset then
        -- Garante que chaves novas da config existam (config alterada sem reset)
        for key in pairs(Config.DailyMissions) do
            if not set.data[key] then needsReset = true break end
        end
        for key in pairs(set.data) do
            if not Config.DailyMissions[key] then needsReset = true break end
        end
    end

    if needsReset then
        profile.dailymissions = DailyMissions.NewSet()
        Persist(src, profile)
    end
end

local function Advance(src, profile, key, amount, companyIndex)
    local entry = profile.dailymissions and profile.dailymissions.data and profile.dailymissions.data[key]
    if not entry or entry.claimed then return false end

    entry.process = math.min(entry.max, (entry.process or 0) + (amount or 1))

    -- Transição atômica de recompensa: só concede uma vez.
    if entry.process >= entry.max and not entry.claimed then
        entry.claimed = true
        if entry.xp > 0 then AddXP(src, entry.xp) end
        if entry.reputation > 0 and companyIndex ~= nil then
            local k = tostring(companyIndex)
            profile.points = profile.points or {}
            profile.points[k] = (tonumber(profile.points[k]) or 0) + entry.reputation
            SyncPlayerDataByKey(src, 'points', profile.points)
            ExecuteSqlAsync('UPDATE peak_trucking SET `points` = :points WHERE `identifier` = :id',
                { points = json.encode(profile.points), id = profile.identifier })
        end
        return true
    end
    return false
end

--- Chamado apenas por Contracts.Finish com um resultado validado.
function DailyMissions.OnDelivery(src, profile, result)
    DailyMissions.CheckReset(src, profile)
    local data = profile.dailymissions.data
    local company = result.companyIndex

    if data.complete_global then
        Advance(src, profile, 'complete_global', 1, company)
    end

    if data.grade_a_or_s and (result.grade == 'A' or result.grade == 'S') then
        Advance(src, profile, 'grade_a_or_s', 1, company)
    end

    if data.two_companies and company ~= nil then
        local entry = data.two_companies
        entry.companies = entry.companies or {}
        local k = tostring(company)
        if not entry.companies[k] then
            entry.companies[k] = true
            Advance(src, profile, 'two_companies', 1, company)
        end
    end

    if data.medium_no_damage and result.tier == 'medium' and (tonumber(result.integrityPct) or 0) >= 90 then
        Advance(src, profile, 'medium_no_damage', 1, company)
    end

    if data.before_rotation_expiry and result.completedBeforeExpiry then
        Advance(src, profile, 'before_rotation_expiry', 1, company)
    end

    Persist(src, profile)
end
