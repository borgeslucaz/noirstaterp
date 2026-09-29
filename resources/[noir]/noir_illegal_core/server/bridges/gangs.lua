NoirIllegal.Bridges.Gangs = {}

function NoirIllegal.Bridges.Gangs.getOrganization(source)
    if GetResourceState('noir_gangs') ~= 'started' then return nil end
    local ok, gang = pcall(function()
        return exports.noir_gangs:GetGang(source)
    end)
    if not ok or type(gang) ~= 'table' or gang.name == 'none' then return nil end
    if not NoirIllegal.Validators.string(gang.name, 1, 64) then return nil end

    -- O noir_gangs devolve a gang já normalizada pelo bgrz_core: `grade` é o nível, e o
    -- nome do cargo vem em `gradeName`. Ler `grade.level` aqui não estourava, caía no
    -- `or 0` — todo mundo virava cargo 0 em silêncio, que é pior que quebrar.
    local grade = tonumber(gang.grade) or 0
    return {
        id = gang.name,
        label = gang.label or gang.name,
        grade = grade,
        gradeName = gang.gradeName or tostring(grade),
    }
end
