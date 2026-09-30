Framework = nil
Fr = {}
ScriptFunctions = {}

local drugsCache = { data = nil, expiresAt = 0 }
local cacheTime = 10000

ScriptFunctions.GetInventoryDrugs = function()
    local playerData = Fr.GetPlayerData()
    local drugsList = {}

    local now = GetGameTimer() or 0
    if drugsCache.data and now < drugsCache.expiresAt then
        return drugsCache.data
    end
    
    if ESX then
        local items = playerData.inventory
        if not items then 
            return {} 
        end
        
        for k, v in pairs(items) do
            if v and Config.DrugSelling.availableDrugs[v.name] and v.count > 0 then
                local drugInfo = Config.DrugSelling.availableDrugs[v.name]
                table.insert(drugsList, {
                    icon = drugInfo.icon,
                    spawn_name = v.name,
                    label = drugInfo.label,
                    amount = v.count,
                    normalPrice = drugInfo.optimalPrice,
                    priceRangeMin = drugInfo.minimumPrice,
                    priceRangeMax = drugInfo.maximumPrice,
                })
            end
        end
    elseif QBCore or QBox then
        local items = playerData.items
        if not items then 
            return {} 
        end
        
        -- Uma entrada por droga, somando os slots. Os graus (noir_weed) vão em `grades`, na
        -- ordem de venda: o servidor vende primeiro o melhor, então a tela mostra todos.
        local byName = {}
        for k, v in pairs(items) do
            local count = v and (v.amount or v.count) or 0
            if v and Config.DrugSelling.availableDrugs[v.name] and count > 0 then
                local entry = byName[v.name]
                if not entry then
                    local drugInfo = Config.DrugSelling.availableDrugs[v.name]
                    entry = {
                        icon = drugInfo.icon,
                        spawn_name = v.name,
                        label = drugInfo.label,
                        amount = 0,
                        normalPrice = drugInfo.optimalPrice,
                        priceRangeMin = drugInfo.minimumPrice,
                        priceRangeMax = drugInfo.maximumPrice,
                        gradeCount = {},
                    }
                    byName[v.name] = entry
                    table.insert(drugsList, entry)
                end
                entry.amount = entry.amount + count
                local grade = type(v.metadata) == 'table' and v.metadata.grade
                if grade and Config.Grades.multiplier[grade] then
                    entry.gradeCount[grade] = (entry.gradeCount[grade] or 0) + count
                end
            end
        end
        for _, entry in ipairs(drugsList) do
            local grades = {}
            if next(entry.gradeCount) then
                -- Slot sem grau de uma droga que tem grau conta como o padrão.
                local graded = 0
                for _, n in pairs(entry.gradeCount) do graded = graded + n end
                if entry.amount > graded then
                    local d = Config.Grades.default
                    entry.gradeCount[d] = (entry.gradeCount[d] or 0) + entry.amount - graded
                end
                for _, grade in ipairs(Config.Grades.order) do
                    if entry.gradeCount[grade] then
                        grades[#grades + 1] = { grade = grade, amount = entry.gradeCount[grade], multiplier = Config.Grades.multiplier[grade] }
                    end
                end
            end
            entry.gradeCount = nil
            entry.grades = grades
        end
    end

    drugsCache.data = drugsList
    drugsCache.expiresAt = now + cacheTime
    
    debugPrint("drugsList", json.encode(drugsList))
    return drugsList
end