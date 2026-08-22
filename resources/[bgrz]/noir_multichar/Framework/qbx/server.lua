if Config.framework == 'qbx' then
    
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

    lib.callback.register('IV:IsAdmin', function(source)
        return IsPlayerAceAllowed(source, 'command')
    end)

end
