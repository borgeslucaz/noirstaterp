-- NUI bridge (client). Opens/closes the editor and relays its fetchNui calls: save, fetch,
-- getPointsZ, viewZone. Round-trips go through the await shim (client/cb.lua); openEditor arrives
-- on a raw net event.

local editorOpen, pauseGuardRunning = false, false

-- SetNuiFocus(true, true) routes keyboard to the NUI, but Escape (pause menu) leaks through anyway
-- - a cfx quirk. Block pause controls every frame the editor is open; grace frames swallow the same
-- Escape that closes it.
local function ensurePauseGuard()
	if pauseGuardRunning then return end
	pauseGuardRunning = true
	CreateThread(function()
		local grace = 10
		while editorOpen or grace > 0 do
			DisableControlAction(0, 199, true)
			DisableControlAction(0, 200, true)
			grace = editorOpen and 10 or grace - 1
			Wait(0)
		end
		pauseGuardRunning = false
	end)
end

-- Feed live player position to the map marker while the editor is open. Single guarded thread;
-- self-stops on close.
local playerFeedRunning = false
local function ensurePlayerFeed()
	if playerFeedRunning then return end
	playerFeedRunning = true
	CreateThread(function()
		while editorOpen do
			local coords = GetEntityCoords(PlayerPedId(), false)
			SendNUIMessage({ action = 'playerPos', data = { x = coords.x, y = coords.y } })
			Wait(200)
		end
		playerFeedRunning = false
	end)
end

local function openEditor()
	-- push the server's current list so a re-open shows fresh data; the UI's onMount pull only
	-- fires on first load.
	local zones = await('zonemanager:fetch')
	editorOpen = true
	ensurePauseGuard()
	ensurePlayerFeed()
	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'loadZones', data = zones or {} })
	SendNUIMessage({ action = 'setVisible', data = true })
end

local function closeEditor()
	editorOpen = false
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'setVisible', data = false })
end

-- the admin-gated server command signals this client to open the editor.
RegisterNetEvent('zonemanager:openEditor', openEditor)

RegisterNUICallback('hideFrame', function(_, cb)
	closeEditor()
	cb({ ok = true })
end)

-- persist the editor's full zone list to the server, reply ok / collision.
RegisterNUICallback('zonemanager:save', function(payload, cb)
	-- UI wraps the array as { zones = [...] }; await returns the server's result table or false.
	local res = await('zonemanager:save', payload.zones)
	if not res then
		cb({ ok = false, error = 'save unavailable' })
		return
	end
	cb(res)
end)

-- hand the editor the server's saved zone list.
RegisterNUICallback('zonemanager:fetch', function(_, cb)
	local zones = await('zonemanager:fetch')
	cb({ zones = zones or {} })
end)

-- Keep only points with numeric x/y. resolveGroundZBatch drives a streaming focus override
-- (SetFocusPosAndVel), so a forged non-numeric point would flow straight into a native.
-- Hard cap so even a forged payload can't queue an unbounded resolve loop.
local maxPoints = 512
local function sanitizePoints(points)
	local out, n = {}, 0
	if type(points) ~= 'table' then return out end
	for i = 1, #points do
		if n >= maxPoints then break end
		local p = points[i]
		if type(p) == 'table' and type(p.x) == 'number' and type(p.y) == 'number' then
			n = n + 1
			out[n] = { x = p.x, y = p.y }
		end
	end
	return out
end

-- resolve every placed point's world Z in one pass so the UI makes a single round trip. Gated on
-- editorOpen: this callback drives the streaming focus override, so a player forging it via CEF
-- DevTools while shut could hold the streamer on an arbitrary coord at will.
local groundZBusy = false
RegisterNUICallback('zonemanager:getPointsZ', function(payload, cb)
	-- Debounce: an overlapping call (double-fire or forged spam) would stack focus-override threads.
	if not editorOpen or groundZBusy then
		cb({ zs = {} })
		return
	end
	groundZBusy = true
	resolveGroundZBatch(sanitizePoints(payload and payload.points), function(zs)
		groundZBusy = false
		cb({ zs = zs })
	end)
end)

-- frame a zone in the in-game 3D viewer.
RegisterNUICallback('zonemanager:viewZone', function(payload, cb)
	if not editorOpen then
		cb({ ok = false })
		return
	end
	startZoneViewer(payload.zone)
	cb({ ok = true })
end)

-- A stop/restart with the editor open never runs closeEditor, leaving SetNuiFocus(true,true)
-- latched (locked cursor + dead pause menu) until reconnect. Release it on stop.
AddEventHandler('onClientResourceStop', function(res)
	if res ~= GetCurrentResourceName() then return end
	editorOpen = false
	SetNuiFocus(false, false)
end)
