local T = dofile('tests/testlib.lua')

function vector3(x, y, z) return { x = x, y = y, z = z } end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end

local now = 1700000000
local pruneCalls = {}
local pruneLog
local waits = 0

NoirOutposts = {
    Constants = {
        OutpostStatus = { CONTROLLED = 'controlled' },
        DealerStatus = { DEPLOYED = 'deployed' },
    },
    Log = {
        info = function(event, fields)
            if event == 'operations_pruned' then pruneLog = fields end
        end,
        error = function() end,
    },
    State = {
        outposts = {},
    },
    Sessions = { tick = function() end },
    Security = { pruneRequestIds = function() end },
    Entities = {
        deadDealers = function() return {} end,
        syncAll = function() end,
    },
    Repositories = {
        Operation = {
            prune = function(olderThan, limit)
                pruneCalls[#pruneCalls + 1] = { olderThan = olderThan, limit = limit }
                return #pruneCalls == 1 and 1000 or 0
            end,
        },
    },
    Services = {
        Holdup = { tick = function() end },
        Dealer = { recoverDue = function() end },
        Sale = {},
        Rotation = { isCycleExpired = function() return false end },
        Notification = { flush = function() end },
    },
}

local originalTime = os.time
os.time = function() return now end

function CreateThread(callback) callback() end
function Wait()
    waits = waits + 1
    if waits == 2 then NoirOutposts.Scheduler.stop() end
end

dofile('server/scheduler.lua')
NoirOutposts.Scheduler.start()
os.time = originalTime

local retention = T.loadConfig('config/server.lua').operationRetention
T.equal(#pruneCalls, 2, 'one maintenance run deletes in batches and does not rerun on the next tick')
T.equal(pruneCalls[1].olderThan, now - 15 * 24 * 60 * 60, 'retention cutoff')
T.equal(pruneCalls[1].limit, retention.batchSize, 'configured prune batch size')
T.equal(pruneLog.removed, 1000, 'removed rows are logged')
T.equal(pruneLog.retentionDays, 15, 'retention window is logged')

print('scheduler_spec: ok')
