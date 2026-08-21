BGRZ = BGRZ or {}

local function normalizeCharacter(player)
    if not player or not player.PlayerData then
        return nil
    end

    local data = player.PlayerData
    local charinfo = data.charinfo or {}
    local job = data.job or {}
    local jobGrade = job.grade or {}
    local gang = data.gang or {}
    local gangGrade = gang.grade or {}
    local metadata = data.metadata or {}
    local money = data.money or {}

    return {
        source = data.source,
        citizenId = data.citizenid,
        name = {
            first = charinfo.firstname,
            last = charinfo.lastname,
            full = string.format(
                '%s %s',
                charinfo.firstname or '',
                charinfo.lastname or ''
            )
        },
        birthdate = charinfo.birthdate,
        nationality = charinfo.nationality,
        phone = charinfo.phone,
        job = {
            name = job.name,
            label = job.label,
            grade = jobGrade.level,
            gradeName = jobGrade.name,
            onDuty = job.onduty == true,
            isBoss = job.isboss == true
        },
        gang = {
            name = gang.name,
            label = gang.label,
            grade = gangGrade.level,
            gradeName = gangGrade.name,
            isBoss = gang.isboss == true
        },
        money = {
            cash = money.cash or 0,
            bank = money.bank or 0
        },
        status = {
            dead = metadata.isdead == true,
            handcuffed = metadata.ishandcuffed == true,
            jailTime = metadata.injail or 0
        },
        licenses = metadata.licences or {},
        fingerprint = metadata.fingerprint
    }
end

function BGRZ.GetCharacter(source)
    source = tonumber(source)

    if not source then
        return nil, 'invalid_source'
    end

    local player = exports.qbx_core:GetPlayer(source)

    if not player then
        return nil, 'player_not_found'
    end

    local character = normalizeCharacter(player)

    if not character then
        return nil, 'invalid_player_data'
    end

    return character
end

exports('GetCharacter', BGRZ.GetCharacter)
