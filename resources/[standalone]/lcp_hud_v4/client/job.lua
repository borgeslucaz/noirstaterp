-- ---------------------------------------------------------------------------
--  Job module
-- ---------------------------------------------------------------------------
--  Pushes the player's job to the HUD. Re-reads on a slow tick AND reacts
--  to ESX job change events for instant updates.
-- ---------------------------------------------------------------------------

local last = { name = nil, grade = nil }

local function iconFor(name)
    if not name then return 'user' end
    return (Config.Job.icons and Config.Job.icons[name]) or 'user'
end

local function refresh()
    if not Config.Job.enabled then return end
    local job = Bridge.getJob()
    if not job then
        if last.name ~= '' then
            last.name = ''
            last.grade = ''
            HUD.state.job = nil
            HUD.pushJob(nil)
        end
        return
    end

    if job.name ~= last.name or (Config.Job.showGrade and job.grade ~= last.grade) then
        last.name  = job.name
        last.grade = job.grade
        local payload = {
            name  = job.name,
            label = job.label,
            grade = Config.Job.showGrade and job.grade or nil,
            icon  = iconFor(job.name),
        }
        HUD.state.job = payload
        HUD.pushJob(payload)
    end
end

CreateThread(function()
    while true do
        Wait(Config.Tick.job or 2000)
        refresh()
    end
end)

-- ESX event hooks (no-ops on QB / standalone).
RegisterNetEvent('esx:setJob', function() refresh() end)
RegisterNetEvent('esx:playerLoaded', function() refresh() end)

-- QBCore event hook for future-proofing.
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() refresh() end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() refresh() end)
