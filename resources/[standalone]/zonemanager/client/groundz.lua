-- Ground-Z resolver (client). Turns a map X/Y into a world Z so placed points sit on the ground:
-- streams collision around the point via a focus override (no ped movement), samples ground height,
-- caches by grid cell with a TTL. Editor-only; resolved Z is persisted and never re-resolved at boot.

-- grid cell size for the Z cache (game units); TTL is how long a cell stays warm
local gridSize = 10.0
local cacheTtl = 120000
-- descending sweep heights fed to GetGroundZFor_3dCoord at the streamed point
local searchHeights = { 1000.0, 800.0, 600.0, 400.0, 300.0, 200.0, 150.0, 100.0, 75.0, 50.0, 25.0, 0.0, -50.0 }
local zCache = {}
-- True while comprehensiveLookup holds a focus override; cleared on resource-stop so the streaming
-- system isn't left latched on the point.
local inFlight = false

-- round to the grid so nearby points share a cache cell
local function cacheKey(x, y)
	return ('%d_%d'):format(math.floor(x / gridSize), math.floor(y / gridSize))
end

---@return number|false
local function getCachedZ(x, y)
	local cached = zCache[cacheKey(x, y)]
	if cached then
		if GetGameTimer() - cached.timestamp < cacheTtl then
			return cached.z
		end
		zCache[cacheKey(x, y)] = nil
	end
	return false
end

local function cacheZ(x, y, z)
	zCache[cacheKey(x, y)] = { z = z, timestamp = GetGameTimer() }
end

-- Stream collision around a remote point WITHOUT moving the player, sweep for ground height, fall
-- back to a downward ray. SetFocusPosAndVel forces the engine to load the world around an arbitrary
-- coord, so the player ped is never teleported / frozen / hidden - on foot, driving, or riding as a
-- passenger, the player is left entirely undisturbed (the old approach warped the ped to the point,
-- which ripped a seated ped out of its vehicle and desynced the car).
---@return number|false
local function comprehensiveLookup(x, y)
	---@type number|false
	local foundZ = false
	inFlight = true
	SetFocusPosAndVel(x, y, 0.0, 0.0, 0.0, 0.0)
	RequestCollisionAtCoord(x, y, 0.0)
	RequestCollisionAtCoord(x, y, 100.0)
	RequestCollisionAtCoord(x, y, 500.0)
	-- Focus streaming isn't instant; poll the sweep until ground resolves or we give up (~3s).
	local attempts = 0
	while attempts < 30 and not foundZ do
		for _, height in ipairs(searchHeights) do
			local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)
			if found and groundZ ~= 0.0 then
				foundZ = groundZ
				break
			end
		end
		if not foundZ then
			Wait(100)
			attempts = attempts + 1
		end
	end
	if not foundZ then
		-- Ignore the local ped so a focus point near the player can't self-hit.
		local rayHandle = StartShapeTestRay(x, y, 1000.0, x, y, -100.0, 1, PlayerPedId(), 7)
		local state, hit, endCoords = 1, false, nil
		local rayWaited = 0
		repeat
			Wait(0)
			state, hit, endCoords = GetShapeTestResult(rayHandle)
			rayWaited = rayWaited + 1
		until state ~= 1 or rayWaited > 100
		if hit == 1 and endCoords and endCoords.z ~= 0.0 then
			foundZ = endCoords.z
		end
	end
	ClearFocus()
	inFlight = false
	return foundZ
end

-- Fast path: collision is normally already streamed around the editing player, so the ground
-- resolves with no teleport. Keeps the LOWEST hit - GetGroundZ returns the highest surface below
-- the query z, so a point under a building would snap to the roof; lowest is the street. False when
-- nothing is streamed.
---@return number|false
local function directGroundZ(x, y)
	---@type number|false
	local best = false
	for _, height in ipairs(searchHeights) do
		local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)
		if found and groundZ ~= 0.0 and (not best or groundZ < best) then
			best = groundZ
		end
	end
	return best
end

-- Resolve a whole point list in one pass, replying once. Each point tries cache, then direct
-- sample, then the teleport fallback only if the area isn't streamed. zs is aligned 1:1 with points
-- (number|false per entry).
---@param points table list of { x = number, y = number }
---@param cb fun(zs: table)
function resolveGroundZBatch(points, cb)
	CreateThread(function()
		local zs = {}
		for i = 1, #points do
			local p = points[i]
			local z = getCachedZ(p.x, p.y)
			if not z then
				z = directGroundZ(p.x, p.y)
				if not z then
					z = comprehensiveLookup(p.x, p.y)
				end
				if z then
					cacheZ(p.x, p.y, z)
				end
			end
			zs[i] = z
		end
		cb(zs)
	end)
end

-- A stop/restart while comprehensiveLookup holds a focus override never runs its ClearFocus tail,
-- leaving the streaming system latched on the point. Clear it.
AddEventHandler('onClientResourceStop', function(res)
	if res ~= GetCurrentResourceName() then return end
	if inFlight then
		ClearFocus()
		inFlight = false
	end
end)
