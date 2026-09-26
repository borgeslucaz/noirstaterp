lib.callback.register('IV:GetAllCharacters', function(source)
	if not IsPlayerAceAllowed(source, 'command') then return {} end

    local plyChars = {}
    local result = MySQL.query.await('SELECT * FROM players')

    for i = 1, (#result), 1 do
        result[i].charinfo = json.decode(result[i].charinfo)
        result[i].money = json.decode(result[i].money)
        result[i].job = json.decode(result[i].job)
        plyChars[#plyChars + 1] = result[i]
    end

    return plyChars
end)


lib.callback.register("IV:GetSkin", function(source, cid)
    local result = MySQL.query.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = ?', { cid, 1 })

    if result[1] then
        return result[1].model, result[1].skin
    end
end)

-- Gang mora no noir_gangs, não no JSON `players.gang` do Qbox (que ficou velho); por isso
-- a pergunta vai ao bgrz_core. Só responde por personagens da própria licença.
lib.callback.register('noir_multichar:server:getCharacterGangs', function(source, citizenIds)
    if type(citizenIds) ~= 'table' or #citizenIds == 0 then return {} end

    local license2, license = GetPlayerIdentifierByType(source, 'license2'), GetPlayerIdentifierByType(source, 'license')
    local owned = {}
    for _, row in ipairs(MySQL.query.await('SELECT citizenid FROM players WHERE license = ? OR license = ?', { license, license2 }) or {}) do
        owned[row.citizenid] = true
    end

    local gangs = {}
    for _, citizenId in ipairs(citizenIds) do
        if owned[citizenId] then
            local ok, info, level = pcall(function()
                local name, grade = next(exports.bgrz_core:GetCharacterGangs(citizenId))
                return name and exports.bgrz_core:GetGangInfo(name), grade
            end)
            if ok and info then
                local grade = info.grades and info.grades[level]
                gangs[citizenId] = { label = info.label, grade = grade and grade.name or nil }
            end
        end
    end

    return gangs
end)

lib.callback.register('IV:IsAdmin', function(source)
    return IsPlayerAceAllowed(source, 'command')
end)
