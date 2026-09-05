CORE = exports["ak4y-core"]

local aktifTaksiciler = {}

CreateThread(function()
    if GetResourceState("ak4y-core") == "missing" then
        print("^1[ERROR]^7 Resource ^3'ak4y_core'^7 is ^1NOT STARTED^7. Please ensure it is started before this script.")
        print("^1[ERROR]^7 Resource ^3'ak4y_core'^7 is ^1NOT STARTED^7. Please ensure it is started before this script.")
        print("^1[ERROR]^7 Resource ^3'ak4y_core'^7 is ^1NOT STARTED^7. Please ensure it is started before this script.")
        print("^1[ERROR]^7 Resource ^3'ak4y_core'^7 is ^1NOT STARTED^7. Please ensure it is started before this script.")
        print("^1[ERROR]^7 Resource ^3'ak4y_core'^7 is ^1NOT STARTED^7. Please ensure it is started before this script.")
    end
end)

local function _S()
    Config.Security = Config.Security or {}
    local s = Config.Security
    if s.StartDistance == nil then s.StartDistance = 7.5 end
    if s.FinishDistance == nil then s.FinishDistance = 8.0 end
    if s.InvoiceDistance == nil then s.InvoiceDistance = 8.0 end
    if s.MinJobSeconds == nil then s.MinJobSeconds = 30 end
    if s.MaxMetersPerSecond == nil then s.MaxMetersPerSecond = 200.0 end
    if s.MinTripMeters == nil then s.MinTripMeters = 0.0 end
    if s.MinTripSeconds == nil then s.MinTripSeconds = 5 end
    if s.RL_StartJobMs == nil then s.RL_StartJobMs = 3000 end
    if s.RL_UpdateStateMs == nil then s.RL_UpdateStateMs = 250 end
    if s.RL_InvoiceMs == nil then s.RL_InvoiceMs = 1500 end
    if s.RL_TripMs == nil then s.RL_TripMs = 1500 end
    if s.RL_FinishJobMs == nil then s.RL_FinishJobMs = 3000 end
    if s.RL_PayBillMs == nil then s.RL_PayBillMs = 1500 end
    if s.MaxMeterTargets == nil then s.MaxMeterTargets = 6 end
    return s
end

local function sqlEscape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub("'", "''")
    return s
end

local function q(s)
    return "'" .. sqlEscape(s) .. "'"
end

local function safeJsonDecode(s, fallback)
    if type(s) ~= "string" or s == "" then return fallback end
    local ok, decoded = pcall(json.decode, s)
    if ok and decoded ~= nil then return decoded end
    return fallback
end

local function getCitizenId(src)
    local cid = CORE:GetCitizenId(src)
    if type(cid) ~= "string" or cid == "" then return nil end
    return cid
end

local function ensurePlayerRow(src)
    local cid = getCitizenId(src)
    if not cid then return nil end
    local firstName = CORE:GetFirstName(src) or ""
    local lastName = CORE:GetLastName(src) or ""
    local fullname = (firstName .. " " .. lastName):gsub("%s+$", "")
    if fullname == "" then fullname = "Unknown" end
    local playerAvatar = CORE:GetPlayerAvatar(src) or ""

    local sqlResult = CORE:ExecuteSql("SELECT * FROM ak4y_taxi WHERE identifier = " .. q(cid) .. " LIMIT 1")
    if sqlResult and sqlResult[1] then
        return sqlResult[1]
    end

    local tasksJson = json.encode(Config.Tasks or {})
    CORE:ExecuteSql(
        "INSERT INTO ak4y_taxi (identifier, xp, completedroutes, tasks, name, photo, earnedmoney) VALUES (" ..
        q(cid) .. ", 0, " .. q("{}") .. ", " .. q(tasksJson) .. ", " .. q(fullname) .. ", " .. q(playerAvatar) .. ", 0)"
    )

    local sqlResult2 = CORE:ExecuteSql("SELECT * FROM ak4y_taxi WHERE identifier = " .. q(cid) .. " LIMIT 1")
    return (sqlResult2 and sqlResult2[1]) or nil
end

local function readPlayerData(src)
    local row = ensurePlayerRow(src)
    if not row then return nil end
    local completedroutes = safeJsonDecode(row.completedroutes, {})
    local tasks = safeJsonDecode(row.tasks, Config.Tasks or {})
    return {
        id = src,
        xp = tonumber(row.xp) or 0,
        level = CalculateLevel(tonumber(row.xp) or 0),
        completedroutes = completedroutes,
        tasks = tasks,
        name = row.name or "",
        photo = row.photo or "",
        earnedmoney = tonumber(row.earnedmoney) or 0
    }
end

local function updateTasks(src, updater)
    local cid = getCitizenId(src)
    if not cid then return false end
    local row = CORE:ExecuteSql("SELECT tasks FROM ak4y_taxi WHERE identifier = " .. q(cid) .. " LIMIT 1")
    if not row or not row[1] then return false end
    local tasks = safeJsonDecode(row[1].tasks, Config.Tasks or {})
    local ok = pcall(updater, tasks)
    if not ok then return false end
    CORE:ExecuteSql("UPDATE ak4y_taxi SET tasks = " .. q(json.encode(tasks)) .. " WHERE identifier = " .. q(cid))
    return true
end

local function redeemXpIfReady(src, task)
    if not task then return end
    if task.taken then return end
    if type(task.Current) ~= "number" or type(task.Need) ~= "number" then return end
    if task.Current < task.Need then return end
    task.taken = true
    local xp = Security.sanitizeInt(task.xp, 1, 1000000)
    if not xp then return end
    local cid = getCitizenId(src)
    if not cid then return end
    CORE:ExecuteSql("UPDATE ak4y_taxi SET xp = xp + " .. tostring(xp) .. " WHERE identifier = " .. q(cid))
end

local function addTaskProgress(src, taskId, amount)
    amount = Security.sanitizeInt(amount, 1, 100000000)
    if not amount then return end
    updateTasks(src, function(tasks)
        for _, v in pairs(tasks) do
            if v.id == taskId then
                v.Current = (tonumber(v.Current) or 0) + amount
                redeemXpIfReady(src, v)
                break
            end
        end
    end)
end

local Sessions = {}
local PendingInvoices = {}

local function getTaxiPrice()
    return Security.sanitizeNumber(Config.PricePerMile, 0.0, 1000000.0) or 0.0
end

local function findNearestCabZone(src)
    local s = _S()
    local c = Security.getCoords(src)
    if not c then return nil end
    local bestKey, bestDist = nil, nil
    for k, v in pairs(Config.CabLocations or {}) do
        if v and v.AccesCoord then
            local d = #(c - vec3(v.AccesCoord.x, v.AccesCoord.y, v.AccesCoord.z))
            if (not bestDist) or d < bestDist then
                bestDist = d
                bestKey = k
            end
        end
    end
    if bestKey and bestDist and bestDist <= s.StartDistance then
        return bestKey
    end
    return nil
end

local function canStartJob(src, routeKey, vehicleIndex)
    local s = _S()
    if not Security.rateLimit(src, "start_job", s.RL_StartJobMs) then
        return Security.deny(src, "startJob", "rate_limited", { route = routeKey, vehicle = vehicleIndex })
    end

    local zone = findNearestCabZone(src)
    if not zone then
        return Security.deny(src, "startJob", "not_near_zone", { route = routeKey, vehicle = vehicleIndex })
    end

    if type(routeKey) ~= "string" or not Config.WorkZones or not Config.WorkZones[routeKey] then
        return Security.deny(src, "startJob", "invalid_route", { route = routeKey })
    end

    local vIdx = Security.sanitizeInt(vehicleIndex, 1, 999)
    if not vIdx or not Config.Vehicles or not Config.Vehicles[vIdx] then
        return Security.deny(src, "startJob", "invalid_vehicle", { vehicle = vehicleIndex })
    end

    local pdata = readPlayerData(src)
    if not pdata then
        return Security.deny(src, "startJob", "no_player_row", {})
    end

    local route = Config.WorkZones[routeKey]
    local veh = Config.Vehicles[vIdx]
    local requiredLevel = Security.sanitizeInt(route.minLevel, 1, 999) or 1
    local vehicleLevel = Security.sanitizeInt(veh.level, 1, 999) or 1
    local myLevel = Security.sanitizeInt(pdata.level, 0, 999) or 0

    if myLevel < requiredLevel or myLevel < vehicleLevel then
        return Security.deny(src, "startJob", "level_denied", { myLevel = myLevel, requiredLevel = requiredLevel, vehicleLevel = vehicleLevel })
    end

    local multiplier = Security.sanitizeNumber(veh.priceMultiplier, 0.1, 10.0) or 1.0
    Sessions[src] = {
        zone = zone,
        route = routeKey,
        vehicleIndex = vIdx,
        multiplier = multiplier,
        startAt = os.time(),
        lastCoords = Security.getCoords(src),
        totalMeters = 0.0,
        meterMeters = 0.0,
        meterOn = false,
        npcInTaxi = false,
        trips = 0,
        xpEarned = 0,
        moneyEarned = 0
    }

    return true
end

CreateThread(function()
    _S()
    while true do
        Wait(1000)
        local s = _S()
        for src, sess in pairs(Sessions) do
            if not GetPlayerName(src) then
                Sessions[src] = nil
            else
                local c = Security.getCoords(src)
                if c then
                    if not sess.lastCoords then
                        sess.lastCoords = c
                    else
                        local delta = #(c - sess.lastCoords)
                        if delta > s.MaxMetersPerSecond then
                            Security.reportSuspect(src, "job_tick", "teleport_delta", { delta = delta })
                            delta = s.MaxMetersPerSecond
                        end
                        sess.totalMeters = (sess.totalMeters or 0.0) + delta
                        if sess.meterOn then
                            sess.meterMeters = (sess.meterMeters or 0.0) + delta
                        end
                        sess.lastCoords = c
                    end
                end
            end
        end
        for token, inv in pairs(PendingInvoices) do
            if inv and inv.expiresAt and os.time() > inv.expiresAt then
                PendingInvoices[token] = nil
            end
        end
    end
end)

CORE:Register("ak4y-taxi:GetPlayerData", function(source)
    local src = source
    local pdata = readPlayerData(src)
    return pdata or false
end)

CORE:Register("ak4y-taxi:taksiciSayi", function(source)
    return aktifTaksiciler
end)

CORE:Register("ak4y-taxi:GetLeaderBoard", function()
    local results = CORE:ExecuteSql("SELECT * FROM ak4y_taxi ORDER BY xp DESC LIMIT 10")
    local leaderboard = {}
    for _, data in ipairs(results or {}) do
        table.insert(leaderboard, {
            name = data.name,
            xp = data.xp,
            level = CalculateLevel(tonumber(data.xp) or 0),
            completedroutes = #(safeJsonDecode(data.completedroutes, {})),
            photo = data.photo,
            percentage = GetLevelPercentage(tonumber(data.xp) or 0),
        })
    end
    return leaderboard
end)

CORE:Register("ak4y-taxi:StartJob", function(source, routeKey, vehicleIndex)
    local src = source
    local ok = canStartJob(src, routeKey, vehicleIndex)
    if ok == true then
        aktifTaksiciler[src] = src
        return { ok = true }
    end
    return { ok = false }
end)

RegisterNetEvent("ak4y-taxi:UpdateJobState", function(data)
    local src = source
    local s = _S()
    local sess = Sessions[src]
    if not sess then
        return
    end
    if type(data) ~= "table" then
        return
    end
    local npcInTaxi = data.npcInTaxi == true
    if npcInTaxi and not Security.rateLimit(src, "update_state", s.RL_UpdateStateMs) then
        return
    end
    sess.npcInTaxi = npcInTaxi
    sess.meterOn = (data.hired == true) and (data.time == true)
end)

RegisterNetEvent("ak4y-taxi:ResetNpcMeter", function()
    local src = source
    local sess = Sessions[src]
    if not sess then
        return
    end
    sess.meterMeters = 0.0
end)

local function finalizeTrip(src, addToJobPayout)
    local s = _S()
    local sess = Sessions[src]
    if not sess then return nil end
    if not sess.meterOn then
        return nil
    end
    local now = os.time()
    if sess.lastTripAt and (now - sess.lastTripAt) < s.MinTripSeconds then
        return nil
    end
    local meters = tonumber(sess.meterMeters) or 0.0
    if meters < s.MinTripMeters then
        return nil
    end
    local price = getTaxiPrice()
    local multiplier = Security.sanitizeNumber(sess.multiplier, 0.1, 10.0) or 1.0
    local amount = math.floor((meters / 1000.0) * price * multiplier)
    amount = Security.sanitizeInt(amount, 0, nil) or 0
    sess.meterMeters = 0.0
    sess.trips = (sess.trips or 0) + 1
    if addToJobPayout ~= false then
        sess.moneyEarned = (sess.moneyEarned or 0) + amount
    end
    sess.lastTripAt = now
    local route = Config.WorkZones and Config.WorkZones[sess.route]
    local tripXp = 0
    if route and route.xp and type(route.xp) == "table" then
        local minXp = Security.sanitizeInt(route.xp.min, 0, 100000) or 0
        local maxXp = Security.sanitizeInt(route.xp.max, minXp, 100000) or minXp
        local earned = 0
        if maxXp > 0 then
            earned = math.random(minXp, maxXp)
        end
        tripXp = earned
        sess.xpEarned = (sess.xpEarned or 0) + earned
    end
    addTaskProgress(src, 1, math.floor(meters))
    addTaskProgress(src, 2, 1)
    addTaskProgress(src, 4, amount)
    return { meters = meters, amount = amount, price = price, xp = tripXp }
end

RegisterNetEvent("ak4y-taxi:TripComplete", function()
    local src = source
    local s = _S()
    if not Security.rateLimit(src, "trip_complete", s.RL_TripMs) then
        return
    end
    local sess = Sessions[src]
    if not sess then
        if not Security.rateLimit(src, "trip_complete_no_session", 2000) then
            Security.reportSuspect(src, "TripComplete", "no_session_spam", {})
        end
        return
    end
    local res = finalizeTrip(src, false)
    if res then
        local addAmount = Security.sanitizeInt(res.amount, 0, nil) or 0
        if addAmount > 150 then addAmount = 150 end
        sess.moneyEarned = (sess.moneyEarned or 0) + addAmount
        sess.meterOn = false
        sess.npcInTaxi = false
    end
end)

local function sanitizeVec3FromPayload(raw)
    if type(raw) ~= "table" then return nil end
    local x = Security.sanitizeNumber(raw.x, -10000.0, 10000.0)
    local y = Security.sanitizeNumber(raw.y, -10000.0, 10000.0)
    local z = Security.sanitizeNumber(raw.z, -2000.0, 2000.0)
    if not x or not y or not z then return nil end
    return vec3(x, y, z)
end

local function coordInRoute(routeKey, point, tolerance)
    if not point then return false end
    local route = Config.WorkZones and Config.WorkZones[routeKey]
    if not route or type(route.coords) ~= "table" then return false end
    local tol = Security.sanitizeNumber(tolerance, 1.0, 100.0) or 25.0
    for _, c in pairs(route.coords) do
        if c then
            local test = vec3(c.x, c.y, c.z)
            if #(point - test) <= tol then
                return true
            end
        end
    end
    return false
end

CORE:Register("ak4y-taxi:CompleteNpcTrip", function(source, payload)
    local src = source
    local s = _S()
    if not Security.rateLimit(src, "complete_npc_trip", s.RL_TripMs) then
        return { ok = false }
    end

    local sess = Sessions[src]
    if not sess then
        if not Security.rateLimit(src, "complete_npc_trip_no_session", 2000) then
            Security.reportSuspect(src, "CompleteNpcTrip", "no_session_spam", {})
        end
        return { ok = false }
    end

    if not sess.meterOn or not sess.npcInTaxi then
        return { ok = false }
    end

    if type(payload) ~= "table" then
        Security.reportSuspect(src, "CompleteNpcTrip", "invalid_payload", payload)
        return { ok = false }
    end

    local pickup = sanitizeVec3FromPayload(payload.pickup)
    local drop = sanitizeVec3FromPayload(payload.drop)
    if not pickup or not drop then
        Security.reportSuspect(src, "CompleteNpcTrip", "invalid_trip_coords", payload)
        return { ok = false }
    end

    if not coordInRoute(sess.route, pickup, 35.0) or not coordInRoute(sess.route, drop, 35.0) then
        Security.reportSuspect(src, "CompleteNpcTrip", "coords_not_in_route", { route = sess.route })
        return { ok = false }
    end

    if not Security.isNearCoords(src, drop, 20.0) then
        return { ok = false }
    end

    local trip = finalizeTrip(src, false)
    if not trip then
        return { ok = false }
    end

    local baseAmount = Security.sanitizeInt(trip.amount, 0, nil) or 0
    if baseAmount > 150 then baseAmount = 150 end

    local expectedMeters = #(pickup - drop)
    expectedMeters = Security.sanitizeNumber(expectedMeters, 1.0, 100000.0) or 1.0
    local tripMeters = Security.sanitizeNumber(trip.meters, 0.0, 1000000.0) or 0.0
    local overchargePercent = ((tripMeters - expectedMeters) / expectedMeters) * 100.0
    if overchargePercent < 0 then overchargePercent = 0.0 end

    local satisfaction = Security.sanitizeNumber(payload.satisfaction, 0.0, 100.0) or 100.0
    local multiplier = 1.0
    local outcome = "satisfied"

    if overchargePercent > 50.0 then
        multiplier = 0.6
        outcome = "overcharge"
    elseif satisfaction <= 80.0 then
        multiplier = 0.7
        outcome = "dissatisfied"
    end

    local finalAmount = Security.sanitizeInt(math.floor(baseAmount * multiplier), 0, nil) or 0
    sess.moneyEarned = (sess.moneyEarned or 0) + finalAmount
    sess.meterOn = false
    sess.npcInTaxi = false

    return {
        ok = true,
        amount = finalAmount,
        xp = Security.sanitizeInt(trip.xp, 0, 1000000) or 0,
        outcome = outcome,
        overchargePercent = Security.sanitizeInt(math.floor(overchargePercent), 0, 100000) or 0
    }
end)

RegisterNetEvent("ak4y-taxi:SendTaximeterToPlayer", function(targetId, data)
    local src = source
    local s = _S()
    if not Security.rateLimit(src, "send_taximeter", 500) then
        return
    end
    local tid = Security.sanitizeInt(targetId, 1, 65535)
    if not tid or not GetPlayerName(tid) then
        Security.reportSuspect(src, "SendTaximeterToPlayer", "invalid_target", { targetId = targetId })
        return
    end
    if not Security.isNearCoords(src, Security.getCoords(tid) or vec3(0,0,0), 15.0) then
        Security.reportSuspect(src, "SendTaximeterToPlayer", "not_near_target", { targetId = tid })
        return
    end
    if type(data) ~= "table" then data = {} end
    local clean = {
        vacant = data.vacant == true,
        hired = data.hired == true,
        time = data.time == true
    }
    TriggerClientEvent("ak4y-taxi:ReceiveTaximeterDetails", tid, clean)
end)

RegisterNetEvent("ak4y-taxi:DistributeMeterData", function(targets, distance, price)
    local src = source
    local s = _S()
    if not Security.rateLimit(src, "meter_data", 750) then
        return
    end
    if type(targets) ~= "table" then
        Security.reportSuspect(src, "DistributeMeterData", "invalid_targets", targets)
        return
    end
    local dist = Security.sanitizeNumber(distance, 0.0, 100000.0) or 0.0
    local pr = Security.sanitizeNumber(price, 0.0, 100000000.0) or 0.0
    local sent = 0
    for _, targetId in ipairs(targets) do
        local tid = Security.sanitizeInt(targetId, 1, 65535)
        if tid and GetPlayerName(tid) then
            TriggerClientEvent("ak4y-taxi:UpdateMeterDisplay", tid, dist, pr)
            sent = sent + 1
            if sent >= s.MaxMeterTargets then
                break
            end
        end
    end
end)

local function buildInvoiceData(src, pid, fare, tokenText)
    local myname = (CORE:GetFirstName(src) or "") .. " " .. (CORE:GetLastName(src) or "")
    local customername = (CORE:GetFirstName(pid) or "") .. " " .. (CORE:GetLastName(pid) or "")
    local date = os.date("%d/%m/%Y %X")
    return {
        myname = myname,
        customername = customername,
        date = date,
        fare = fare,
        tokennmbr = tokenText
    }
end

local function inSameVehicleDriverPassenger(src, pid)
    local ped1 = GetPlayerPed(src)
    local ped2 = GetPlayerPed(pid)
    if not ped1 or ped1 == 0 or not ped2 or ped2 == 0 then return false end
    local v1 = GetVehiclePedIsIn(ped1, false)
    local v2 = GetVehiclePedIsIn(ped2, false)
    if not v1 or v1 == 0 or not v2 or v2 == 0 then return false end
    if v1 ~= v2 then return false end
    local driverPed = GetPedInVehicleSeat(v1, -1)
    if driverPed ~= ped1 then return false end
    return true
end

local function handleInvoiceRequest(src, targetId)
    local s = _S()
    if not Security.rateLimit(src, "request_invoice", s.RL_InvoiceMs) then
        return false
    end
    local sess = Sessions[src]
    if not sess then
        if not Security.rateLimit(src, "request_invoice_no_session", 2000) then
            Security.reportSuspect(src, "RequestInvoice", "no_session_spam", { targetId = targetId })
        end
        return false
    end
    local pid = Security.sanitizeInt(targetId, 1, 65535)
    if not pid or not GetPlayerName(pid) then
        Security.reportSuspect(src, "RequestInvoice", "invalid_target", { targetId = targetId })
        return false
    end
    if not inSameVehicleDriverPassenger(src, pid) then
        Security.reportSuspect(src, "RequestInvoice", "not_same_vehicle", { targetId = pid })
        return false
    end
    if not Security.isNearCoords(src, Security.getCoords(pid) or vec3(0,0,0), s.InvoiceDistance) then
        Security.reportSuspect(src, "RequestInvoice", "not_near_passenger", { targetId = pid })
        return false
    end
    local trip = finalizeTrip(src, false)
    if not trip then
        return false
    end
    local token = ("%d-%d-%d"):format(math.random(100000, 999999), math.random(100000, 999999), GetGameTimer())
    PendingInvoices[token] = {
        payer = pid,
        payee = src,
        amount = trip.amount,
        createdAt = os.time(),
        expiresAt = os.time() + 120
    }
    local data = buildInvoiceData(src, pid, trip.price, token)
    TriggerClientEvent("ak4y-taxi:ShowInvoice", pid, trip.amount, (trip.meters / 1000.0), data, src, token)
    return true
end

RegisterNetEvent("ak4y-taxi:RequestInvoice", function(targetId)
    handleInvoiceRequest(source, targetId)
end)

RegisterNetEvent("ak4y-taxi:SendInvoice", function(targetId)
    handleInvoiceRequest(source, targetId)
end)

CORE:Register("ak4y-taxi:RequestInvoiceCb", function(source, targetId)
    return handleInvoiceRequest(source, targetId) == true
end)

RegisterNetEvent("ak4y-taxi:CancelJob", function(forceStop)
    local src = source
    local sess = Sessions[src]
    if not sess then
        return
    end

    if forceStop == true then
        Sessions[src] = nil
        aktifTaksiciler[src] = nil
        return
    end

    sess.npcInTaxi = false
    sess.meterOn = false
    sess.meterMeters = 0.0
end)

CORE:Register("ak4y-taxi:paybill", function(source, token)
    local src = source
    local s = _S()
    if not Security.rateLimit(src, "paybill", s.RL_PayBillMs) then
        return false
    end
    if type(token) ~= "string" or #token < 6 or #token > 80 then
        Security.reportSuspect(src, "paybill", "invalid_token", { token = token })
        return false
    end
    local inv = PendingInvoices[token]
    if not inv then
        Security.reportSuspect(src, "paybill", "token_not_found", { token = token })
        return false
    end
    if inv.payer ~= src then
        Security.reportSuspect(src, "paybill", "payer_mismatch", { token = token })
        return false
    end
    if inv.expiresAt and os.time() > inv.expiresAt then
        PendingInvoices[token] = nil
        Security.reportSuspect(src, "paybill", "token_expired", { token = token })
        return false
    end
    local amount = Security.sanitizeInt(inv.amount, 1, nil)
    if not amount then
        PendingInvoices[token] = nil
        Security.reportSuspect(src, "paybill", "invalid_amount", inv)
        return false
    end
    if exports["ak4y-core"]:RemovePlayerMoney(src, amount) then
        exports["ak4y-core"]:AddPlayerMoney(tonumber(inv.payee), amount, "cash")
        PendingInvoices[token] = nil
        return true
    end
    return false
end)

CORE:Register("ak4y-taxi:FinishJob", function(source)
    local src = source
    local s = _S()
    if not Security.rateLimit(src, "finish_job", s.RL_FinishJobMs) then
        return { ok = false }
    end
    local sess = Sessions[src]
    if not sess then
        if not Security.rateLimit(src, "finish_job_no_session", 2000) then
            Security.reportSuspect(src, "FinishJob", "no_session_spam", {})
        end
        return { ok = false }
    end
    local zone = sess.zone
    local finishCoord = zone and Config.CabLocations and Config.CabLocations[zone] and Config.CabLocations[zone].FinishJob or nil
    if not finishCoord or not Security.isNearCoords(src, finishCoord, s.FinishDistance) then
        Security.reportSuspect(src, "FinishJob", "not_near_finish", { zone = zone })
        return { ok = false }
    end
    if sess.startAt and (os.time() - sess.startAt) < s.MinJobSeconds then
        Security.reportSuspect(src, "FinishJob", "min_time_not_met", { seconds = os.time() - sess.startAt })
        return { ok = false }
    end
    if sess.npcInTaxi == true and (tonumber(sess.meterMeters) or 0) >= s.MinTripMeters then
        finalizeTrip(src, true)
    end
    local payout = Security.sanitizeInt(math.floor(tonumber(sess.moneyEarned) or 0), 0, nil) or 0
    local xpEarned = Security.sanitizeInt(tonumber(sess.xpEarned) or 0, 0, 100000000) or 0
    local routeLabel = (Config.WorkZones and Config.WorkZones[sess.route] and Config.WorkZones[sess.route].label) or tostring(sess.route or "route")

    local cid = getCitizenId(src)
    if not cid then
        Sessions[src] = nil
        return { ok = false }
    end

    local row = ensurePlayerRow(src)
    if not row then
        Sessions[src] = nil
        return { ok = false }
    end

    local completedroutes = safeJsonDecode(row.completedroutes, {})
    table.insert(completedroutes, { name = routeLabel, money = payout, xp = xpEarned })

    exports["ak4y-core"]:AddPlayerMoney(src, payout, "cash")

    CORE:ExecuteSql(
        "UPDATE ak4y_taxi SET xp = xp + " .. tostring(xpEarned) ..
        ", completedroutes = " .. q(json.encode(completedroutes)) ..
        ", earnedmoney = earnedmoney + " .. tostring(payout) ..
        " WHERE identifier = " .. q(cid)
    )

    addTaskProgress(src, 3, 1)

    Sessions[src] = nil
    aktifTaksiciler[src] = nil
    return { ok = true, money = payout, xp = xpEarned }
end)

RegisterNetEvent("ak4y-taxi:AddTask-sv", function(id, amount)
    local src = source
    if GetInvokingResource() ~= nil then
        local taskId = Security.sanitizeInt(id, 1, 999)
        local amt = Security.sanitizeInt(amount, 1, 100000000)
        if taskId and amt then
            addTaskProgress(src, taskId, amt)
        end
        return
    end
    Security.reportSuspect(src, "AddTask-sv", "client_blocked", { id = id, amount = amount })
end)

function GetLevelPercentage(xp)
    for _, data in ipairs(Config.Levels or {}) do
        if type(data.max) == "string" and data.max == "∞" then
            if xp >= data.min then
                return 100
            end
        else
            if xp >= data.min and xp <= data.max then
                local levelXPRange = data.max - data.min
                local currentProgress = xp - data.min
                local percentage = math.floor((currentProgress / levelXPRange) * 100)
                return percentage
            end
        end
    end
    return 0
end

function CalculateLevel(xp)
    local level = 1
    for i = 1, #(Config.Levels or {}) do
        local levelData = Config.Levels[i]
        if type(levelData.max) == "string" and levelData.max == "∞" then
            if xp >= levelData.min then
                level = i
                break
            end
        else
            if xp >= levelData.min and xp <= levelData.max then
                level = i
                break
            end
        end
    end
    return level
end

AddEventHandler('playerDropped', function (reason, resourceName, clientDropReason)
    aktifTaksiciler[source] = nil 
end)