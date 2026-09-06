--- ============================================================
--- CUSTOM SERVER HOOKS
--- Use this file to add your own custom logic, overrides, and integrations.
--- Core files are never modified here, keeping upgrades clean.
--- ============================================================

Open = Open or {}

-- ============================================================
-- PERMISSIONS & VALIDATION
-- ============================================================

--- Called before a global contract is acquired by the server.
--- Return false to deny.
--- @param source number Player server ID
--- @param offer table Offer projection (missionId, routeIndex, tier)
--- @return boolean
function ServerCanStartMission(source, offer)
    -- Example: require a minimum player count
    -- if #GetPlayers() < 2 then return false end
    return true
end

-- ============================================================
-- JOB LIFECYCLE EVENTS
-- ============================================================

--- Called when a delivery is completed and payment has been issued.
--- @param source number
--- @param missionId number
--- @param payment number Final payment
--- @param result table Full result breakdown (grade, score, xp, reputation...)
function OnServerMissionCompleted(source, missionId, payment, result)
    Peak.Utils.Debug('[Custom] Mission complete — source:', source, 'id:', missionId, 'pay:', payment)
    -- TriggerEvent('your_script:onTruckingPaid', source, payment, result)
end

--- Called when a delivery ends without full payment.
--- @param source number|nil
--- @param missionId number
--- @param reason string
function OnServerMissionFailed(source, missionId, reason)
    Peak.Utils.Debug('[Custom] Mission failed — source:', source, 'id:', missionId, 'reason:', reason)
end

-- ============================================================
-- PLAYER HOOKS
-- ============================================================

--- Called when a player loads into the server.
--- @param source number
function Open.OnPlayerLoaded(source)
end

--- Called when a player disconnects.
--- @param source number
function Open.OnPlayerUnloaded(source)
end

-- ============================================================
-- CUSTOM MONEY OVERRIDES
-- ============================================================
-- Return a truthy result to override; return nil to use default framework logic.
-- Noir State: toda comunicação com o Qbox passa pela bridge do bgrz_core.

local function HasBgrzCore()
    return GetResourceState('bgrz_core') == 'started'
end

--- Override to give money using a custom system.
--- @param source number
--- @param amount number
--- @param moneyType string 'cash'|'bank'
--- @return boolean|nil
function Open.AddMoney(source, amount, moneyType)
    if HasBgrzCore() then
        local ok, res = pcall(function()
            return exports.bgrz_core:AddMoney(source, moneyType or 'cash', amount, 'peak-trucking')
        end)
        if ok then return res == true end
        Peak.Utils.Warn('bgrz_core:AddMoney failed:', res)
        return false
    end
    return nil
end

--- Override to remove money using a custom system.
--- @param source number
--- @param amount number
--- @param moneyType string
--- @return boolean|nil
function Open.RemoveMoney(source, amount, moneyType)
    if HasBgrzCore() then
        local ok, res = pcall(function()
            return exports.bgrz_core:RemoveMoney(source, moneyType or 'cash', amount, 'peak-trucking')
        end)
        if ok then return res == true end
        return false
    end
    return nil
end
