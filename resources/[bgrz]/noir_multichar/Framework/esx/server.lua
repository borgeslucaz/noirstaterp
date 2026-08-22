if Config.framework == 'esx' then
    ESX = exports["es_extended"]:getSharedObject()
    
    local DB_TABLES = { users = "identifier" }
    local PREFIX = Config.Prefix or "char"

    MySQL.ready(function()
        local length = 42 + #PREFIX
        local DB_COLUMNS = MySQL.query.await(
        ('SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = "%s" AND DATA_TYPE = "varchar" AND COLUMN_NAME IN (?)')
        :format(DATABASE, length), {
            { "identifier", "owner" },
        })

        if DB_COLUMNS then
            local columns = {}
            local count = 0

            for i = 1, #DB_COLUMNS do
                local column = DB_COLUMNS[i]
                DB_TABLES[column.TABLE_NAME] = column.COLUMN_NAME

                if column?.CHARACTER_MAXIMUM_LENGTH ~= length then
                    count = count + 1
                    columns[column.TABLE_NAME] = column.COLUMN_NAME
                end
            end

            if next(columns) then
                local query = "ALTER TABLE `%s` MODIFY COLUMN `%s` VARCHAR(%s)"
                local queries = table.create(count, 0)

                for k, v in pairs(columns) do
                    queries[#queries + 1] = { query = query:format(k, v, length) }
                end


            end

            while not next(ESX.Jobs) do
                Wait(500)
                ESX.Jobs = ESX.GetJobs()
            end
        end
    end)



    local function saveIdentityToDatabase(identifier, identity)
        MySQL.update.await("UPDATE users SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ? WHERE identifier = ?",{ identity.firstName, identity.lastName, identity.dateOfBirth, identity.sex, identity.height, identifier })
    end


    lib.callback.register('IV:DeleteCharacters', function(source, char)
        local identifier = ("%s%s:%s"):format(PREFIX, char.id, GetIdentifier(source))
        local query = "DELETE FROM %s WHERE %s = ?"
        local queries = {}
        local count = 0
        local response = true

        for table, column in pairs(DB_TABLES) do
            count = count + 1
            queries[count] = { query = query:format(table, column), values = { identifier } }
        end

        MySQL.transaction(queries, function(result)
            if result then
                Wait(50)
            else
                response = false
            end
        end)
        return response
    end)



    RegisterNetEvent('IV:CreateCharacters', function(data)
        local xPlayer = ESX.GetPlayerFromId(source)
        local playerIdentity = {}

        if xPlayer then
            playerIdentity[xPlayer.identifier] = {
                firstName = data.firstName,
                lastName = data.lastName,
                dateOfBirth = data.DOB,
                sex = data.gender == 'Male' and 'm' or 'f',
                height = data.height,
            }

            local currentIdentity = playerIdentity[xPlayer.identifier]

            xPlayer.setName(("%s %s"):format(currentIdentity.firstName, currentIdentity.lastName))
            xPlayer.set("firstName", currentIdentity.firstName)
            xPlayer.set("lastName", currentIdentity.lastName)
            xPlayer.set("dateofbirth", currentIdentity.dateOfBirth)
            xPlayer.set("sex", currentIdentity.sex)
            xPlayer.set("height", currentIdentity.height)

            TriggerClientEvent("multicharacter:setPlayerData", xPlayer.source, currentIdentity)
            saveIdentityToDatabase(xPlayer.identifier, currentIdentity)
            TriggerEvent("esx:onPlayerJoined", source, PREFIX .. data.slot, data)
            ESX.Players[GetIdentifier(source)] = true

        end

        local Identity = {
            firstname = data.firstName,
            lastname = data.lastName,
            dateofbirth = data.DOB,
            sex = data.gender == 'Male' and 'm' or 'f',
            height = data.height,
        }

        TriggerEvent("esx:onPlayerJoined", source, PREFIX .. data.slot, Identity)
        ESX.Players[GetIdentifier(source)] = true
        TriggerClientEvent("multicharacter:setPlayerData", source, Identity)

    end)





    lib.callback.register('IV:GetCharacters', function(source)
        local identifier = GetIdentifier(source)
        
        ESX.Players[identifier] = true

        local resultall = MySQL.query.await("SELECT identifier, accounts, job, job_grade, firstname, lastname, dateofbirth, sex, skin, disabled, position FROM users ")

        local result = {}
        for i = 1,#resultall do
            if string.find(resultall[i].identifier, identifier) then
                result[#result + 1] =  resultall[i]
            end
            
        end
        local characters

        if result then
            local characterCount = #result

            characters = table.create(0, characterCount)

            for i = 1, characterCount, 1 do
                local v = result[i]
                local job, grade = v.job or "unemployed", tostring(v.job_grade)

                if ESX.Jobs[job] and ESX.Jobs[job].grades[grade] then
                    if job ~= "unemployed" then
                        grade = ESX.Jobs[job].grades[grade].label
                    else
                        grade = ""
                    end
                    job = ESX.Jobs[job].label
                end

                local accounts = json.decode(v.accounts)
                local id = tonumber(string.sub(v.identifier, #PREFIX + 1, string.find(v.identifier, ":") - 1))

                characters[id] = {
                    id = id,
                    bank = accounts.bank,
                    money = accounts.money,
                    job = job,
                    job_grade = grade,
                    firstname = v.firstname,
                    lastname = v.lastname,
                    dateofbirth = v.dateofbirth,
                    skin = v.skin and json.decode(v.skin) or {},
                    disabled = v.disabled,
                    sex = v.sex  == 'm' and true or false,
                    position = v.position,
                }
            end
        end

        return characters
    end)




    lib.callback.register('IV:GetAllCharacters', function(source)
        local identifier = GetIdentifier(source)
        ESX.Players[identifier] = true

        local result = MySQL.query.await("SELECT identifier, accounts, job, job_grade, firstname, lastname, dateofbirth, sex, skin, disabled, position FROM users ")
        local characters

        if result then
            local characterCount = #result

            characters = table.create(0, characterCount)

            for i = 1, characterCount, 1 do
         
                local v = result[i]
                local job, grade = v.job or "unemployed", tostring(v.job_grade)

                if ESX.Jobs[job] and ESX.Jobs[job].grades[grade] then
                    if job ~= "unemployed" then
                        grade = ESX.Jobs[job].grades[grade].label
                    else
                        grade = ""
                    end
                    job = ESX.Jobs[job].label
                end

                local accounts = json.decode(v.accounts)
                local id = tonumber(string.sub(v.identifier, #PREFIX + 1, string.find(v.identifier, ":") - 1))

                characters[i] = {
                    id = id,
                    identifier = v.identifier,
                    bank = accounts.bank,
                    money = accounts.money,
                    job = job,
                    job_grade = grade,
                    firstname = v.firstname,
                    lastname = v.lastname,
                    dateofbirth = v.dateofbirth,
                    skin = v.skin and json.decode(v.skin) or {},
                    disabled = v.disabled,
                    sex = v.sex  == 'm' and true or false,
                }
            end
        end

        return characters
    end)




    RegisterNetEvent("IV:CharacterChosen", function(char)
        local charid = char.id
        if type(charid) == "number" and string.len(charid) <= 2 then
            if not ESX.GetConfig().EnableDebug then
                local identifier = PREFIX .. charid .. ":" .. GetIdentifier(source)
                if ESX.GetPlayerFromIdentifier(identifier) then
                    DropPlayer(source, "Your identifier " .. identifier .. " is already on the server!")
                    return
                end
            end

            TriggerEvent("esx:onPlayerJoined", source, PREFIX .. charid)
            ESX.Players[GetIdentifier(source)] = true
        end
    end)



    RegisterNetEvent("IV:Relog", function()
        local source = source
        TriggerEvent("esx:playerLogout", source)
    end)


    RegisterNetEvent("IV:GiveItems", function ()
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        for i = 1, #Config.StarterItems do
            xPlayer.addInventoryItem(Config.StarterItems[i].name, Config.StarterItems[i].amount)
        end
    end)


end
