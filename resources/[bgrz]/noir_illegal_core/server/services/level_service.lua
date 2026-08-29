NoirIllegal.Services = NoirIllegal.Services or {}
local Service = {}
NoirIllegal.Services.Level = Service

function Service.get(category, reputation)
    local thresholds = NoirIllegal.Levels[category]
    if not thresholds then return nil end
    local level = 0
    for i = 1, #thresholds do
        if reputation >= thresholds[i].minReputation then
            level = thresholds[i].level
        else
            break
        end
    end
    return level
end

function Service.all(reputations)
    local result = {}
    for category in pairs(NoirIllegal.Config.Categories) do
        result[category] = Service.get(category, reputations[category] or 0)
    end
    return result
end

function Service.validateConfiguration()
    for category in pairs(NoirIllegal.Config.Categories) do
        local thresholds = NoirIllegal.Levels[category]
        assert(type(thresholds) == 'table' and #thresholds > 0,
            ('Missing level thresholds for category %s'):format(category))
        local lastReputation, lastLevel = -1, -1
        for i = 1, #thresholds do
            local row = thresholds[i]
            assert(type(row.level) == 'number' and row.level > lastLevel,
                ('Invalid level ordering for category %s'):format(category))
            assert(type(row.minReputation) == 'number' and row.minReputation > lastReputation,
                ('Invalid reputation threshold ordering for category %s'):format(category))
            lastLevel, lastReputation = row.level, row.minReputation
        end
    end
end

function Service.diminishingMultiplier(count, rule)
    if not rule or count < rule.softCap then return 1.0 end
    return math.max(rule.floorMultiplier, 1 - ((count - rule.softCap + 1) / rule.softCap))
end
