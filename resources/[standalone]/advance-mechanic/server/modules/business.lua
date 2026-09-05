local Business = {}
local Framework = require 'shared.framework'

local function decodeJson(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or fallback
end

local function getShop(shopId)
    return MySQL.single.await('SELECT id, name, owner, storage FROM mechanic_shops WHERE id = ?', { shopId })
end

function Business.createBusiness(shopId)
    return getShop(shopId) ~= nil, shopId
end

function Business.getBusinessByShop(shopId)
    local shop = getShop(shopId)
    if not shop then return nil end
    shop.metadata = { shop_id = shop.id, type = 'mechanic_shop' }
    return shop
end

function Business.isBusinessBoss(citizenId, shopId)
    local shop = getShop(shopId)
    return shop ~= nil and shop.owner == citizenId
end

function Business.getEmployeeRank(citizenId, shopId)
    local shop = getShop(shopId)
    if shop and shop.owner == citizenId then return Config.BossGrade end

    local grade = MySQL.scalar.await(
        'SELECT grade FROM mechanic_employees WHERE shop_id = ? AND citizenid = ? LIMIT 1',
        { shopId, citizenId }
    )
    return tonumber(grade) or 0
end

function Business.isEmployee(citizenId, shopId)
    return MySQL.scalar.await(
        'SELECT 1 FROM mechanic_employees WHERE shop_id = ? AND citizenid = ? LIMIT 1',
        { shopId, citizenId }
    ) ~= nil
end

function Business.hasBusinessPermission(citizenId, shopId, permission)
    if Business.isBusinessBoss(citizenId, shopId) then return true end
    local permissions = Config.Employees.permissions[Business.getEmployeeRank(citizenId, shopId)]
    return permissions ~= nil and permission ~= nil and permissions[permission] == true
end

function Business.getBusinessFunds(shopId)
    local shop = getShop(shopId)
    if not shop then return 0 end
    local storage = decodeJson(shop.storage, {})
    return tonumber(storage.funds) or 0
end

function Business.updateBusinessFunds(shopId, amount, isWithdrawal)
    amount = tonumber(amount)
    if not amount or amount < 0 then return false end

    local shop = getShop(shopId)
    if not shop then return false end
    local storage = decodeJson(shop.storage, {})
    local funds = tonumber(storage.funds) or 0
    local updated = isWithdrawal and (funds - amount) or (funds + amount)
    if updated < 0 then return false end
    storage.funds = updated

    return MySQL.update.await('UPDATE mechanic_shops SET storage = ? WHERE id = ?', {
        json.encode(storage), shopId
    }) > 0
end

function Business.getBusinessEmployees(shopId)
    local result = MySQL.query.await([[
        SELECT me.*, p.charinfo
        FROM mechanic_employees me
        LEFT JOIN players p ON p.citizenid = me.citizenid
        WHERE me.shop_id = ?
        ORDER BY me.grade DESC, me.name ASC
    ]], { shopId }) or {}

    for _, employee in ipairs(result) do
        local charinfo = decodeJson(employee.charinfo, {})
        local fallbackName = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):match('^%s*(.-)%s*$')
        employee.name = employee.name or fallbackName
        employee.on_duty = employee.on_duty == 1 or employee.on_duty == true
    end
    return result
end

function Business.hireEmployee(shopId, targetId, grade, wage)
    local Target = Framework.GetPlayer(targetId)
    if not Target then return false, 'player_not_found' end

    local citizenid = Target.PlayerData.citizenid
    local existingShop = MySQL.scalar.await([[
        SELECT shop_id FROM mechanic_employees WHERE citizenid = ? LIMIT 1
    ]], { citizenid })
    local ownedShop = MySQL.scalar.await('SELECT id FROM mechanic_shops WHERE owner = ? LIMIT 1', { citizenid })
    if existingShop or ownedShop then return false, locale('employee_already_assigned') end

    local charinfo = Target.PlayerData.charinfo or {}
    local name = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):match('^%s*(.-)%s*$')
    wage = tonumber(wage) or Config.Employees.defaultWage

    local result = MySQL.query.await([[
        INSERT INTO mechanic_employees (shop_id, citizenid, name, grade, wage)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), grade = VALUES(grade), wage = VALUES(wage)
    ]], { shopId, citizenid, name, grade, wage })

    if not result then return false, 'hire_failed' end
    Target.Functions.SetJob(Config.JobName, grade)
    return true
end

function Business.fireEmployee(shopId, targetCitizenId)
    local changed = MySQL.update.await(
        'DELETE FROM mechanic_employees WHERE shop_id = ? AND citizenid = ?',
        { shopId, targetCitizenId }
    )
    if changed < 1 then return false, 'employee_not_found' end

    local Target = Framework.GetPlayerByCitizenId(targetCitizenId)
    if Target then
        local stillAssigned = MySQL.scalar.await(
            'SELECT 1 FROM mechanic_employees WHERE citizenid = ? LIMIT 1', { targetCitizenId }
        ) or MySQL.scalar.await('SELECT 1 FROM mechanic_shops WHERE owner = ? LIMIT 1', { targetCitizenId })
        if not stillAssigned then Target.Functions.SetJob('unemployed', 0) end
    end
    return true
end

function Business.updateEmployeeGrade(shopId, targetCitizenId, newGrade)
    local changed = MySQL.update.await(
        'UPDATE mechanic_employees SET grade = ? WHERE shop_id = ? AND citizenid = ?',
        { newGrade, shopId, targetCitizenId }
    )
    if changed < 1 then return false, 'employee_not_found' end

    local Target = Framework.GetPlayerByCitizenId(targetCitizenId)
    if Target then Target.Functions.SetJob(Config.JobName, newGrade) end
    return true
end

function Business.updateEmployeeWage(shopId, targetCitizenId, newWage)
    return MySQL.update.await(
        'UPDATE mechanic_employees SET wage = ? WHERE shop_id = ? AND citizenid = ?',
        { newWage, shopId, targetCitizenId }
    ) > 0
end

return Business
