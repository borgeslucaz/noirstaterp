NoirIllegal.Bridges.Gangs = {}

function NoirIllegal.Bridges.Gangs.getOrganization(source)
    if GetResourceState('noir_gangs') ~= 'started' then return nil end
    local ok, gang = pcall(function()
        return exports.noir_gangs:GetGang(source)
    end)
    if not ok or type(gang) ~= 'table' or gang.name == 'none' then return nil end
    if not NoirIllegal.Validators.string(gang.name, 1, 64) then return nil end

    local grade = type(gang.grade) == 'table' and gang.grade or {}
    return {
        id = gang.name,
        label = gang.label or gang.name,
        grade = tonumber(grade.level) or 0,
        gradeName = grade.name or tostring(grade.level or 0),
    }
end
