-- Zone Manager module (server). Persists data/zones.json, serves it to clients, hosts the
-- admin-gated editor command.

-- ZoneManager is one LuaLS symbol across the two separate server/client Lua states.
---@diagnostic disable: duplicate-set-field

ZoneManager = {}

local resourceName = GetCurrentResourceName()
local zonesFile = 'data/zones.json'
-- Bump on any persisted-shape change; migrateSchema upgrades older files on load. v2 dropped
-- per-point ids + the derived 2d_map pixel pair - the UI regenerates both from x/y at load.
local schemaVersion <const> = 2
---@type ZoneData[]
local zones = {}
-- name -> zone, rebuilt whenever `zones` is replaced; backs the point queries.
---@type table<string, ZoneData>
local byName = {}
-- Size caps so a crafted (admin-gated) save can't write an unbounded zones.json and broadcast it.
local maxZones = 256
local maxPoints = 512
-- Detection floor drops this far below the lowest resolved point z in the query band check,
-- mirroring the client engine's ground buffer.
local groundFloorBuffer = 1.0

-- Selected framework adapter; answers "is this player an admin?".
local framework = loadModule(('server/framework/%s.lua'):format(config.framework))

-- Global (not local) so the callback shim in server/cb.lua, a separate chunk, can reach it.
---@param src number
---@return boolean
function isAdmin(src)
	if config.allowEveryone then
		return type(src) == 'number' and src > 0
	end
	return framework.isAdmin(src) == true
end

---@param msg string
local function logmsg(msg)
	print(('[zonemanager] %s'):format(msg))
end

local canonicalName = zoneGeometry.canonicalName

-- NaN/inf pass type(n) == 'number' but serialize as invalid JSON, corrupting the file so every
-- zone drops on the next boot. Reject them at the door.
---@param n any
---@return boolean
local function isFiniteNumber(n)
	return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

-- Validate one decoded zone. Returns false + reason on any malformed field.
---@param zone any
---@return boolean, string?
local function validateZone(zone)
	if type(zone) ~= 'table' then
		return false, 'zone is not a table'
	end
	if type(zone.name) ~= 'string' or canonicalName(zone.name) == '' then
		return false, 'name must be a non-empty string'
	end
	-- Hex only: color is interpolated into Leaflet divIcon HTML on the client, so reject anything
	-- that could break out of the style attribute.
	if type(zone.color) ~= 'string' or not zone.color:match('^#%x%x%x%x%x%x$') then
		return false, 'color must be a #rrggbb hex string'
	end
	if type(zone.visible) ~= 'boolean' then
		return false, 'visible must be a boolean'
	end
	if not isFiniteNumber(zone.height) or zone.height < 0 then
		return false, 'height must be a non-negative number'
	end
	local kind = zone.kind
	if kind ~= nil and kind ~= 'poly' and kind ~= 'circle' then
		return false, 'kind must be "poly" or "circle"'
	end
	local minPoints = kind == 'circle' and 1 or 3
	if type(zone.points) ~= 'table' or #zone.points < minPoints then
		return false, ('points must be an array of at least %d entries'):format(minPoints)
	end
	if #zone.points > maxPoints then
		return false, ('points exceed the cap of %d'):format(maxPoints)
	end
	for i = 1, #zone.points do
		local point = zone.points[i]
		if type(point) ~= 'table' or not isFiniteNumber(point.x) or not isFiniteNumber(point.y) then
			return false, ('point %d must be {x, y} numbers'):format(i)
		end
		if point.z ~= nil and not isFiniteNumber(point.z) then
			return false, ('point %d z must be a number'):format(i)
		end
	end
	if kind == 'circle' and not (isFiniteNumber(zone.radius) and zone.radius > 0) then
		return false, 'circle radius must be a positive number'
	end
	return true
end

-- Iterative deep clone so consumers can't mutate internal state. No recursion (depth is
-- user-supplied).
---@param src table
---@return table
local function deepCopy(src)
	local root = {}
	local stack = { { src, root } }
	while #stack > 0 do
		local frame = stack[#stack]
		stack[#stack] = nil
		local from, to = frame[1], frame[2]
		for k, v in pairs(from) do
			if type(v) == 'table' then
				local nested = {}
				to[k] = nested
				stack[#stack + 1] = { v, nested }
			else
				to[k] = v
			end
		end
	end
	return root
end

-- json.encode can't order keys, so the file is emitted by hand in a fixed field order.
-- Scalars defer to json.encode for correct escaping/number formatting.
local indentUnit = '    '

local function jsonScalar(v)
	if v == nil then
		return 'null'
	end
	return json.encode(v)
end

-- Ground-Z lookups return long floats; cap persisted z at 4 decimals.
local function round4(n)
	return tonumber(('%.4f'):format(n))
end

---@param p table
---@param indent string
local function encodePoint(p, indent)
	local z = isFiniteNumber(p.z) and round4(p.z) or nil
	return ('%s{ "x": %s, "y": %s, "z": %s }'):format(
		indent, jsonScalar(p.x), jsonScalar(p.y), jsonScalar(z))
end

---@param z table
---@param indent string
local function encodeZone(z, indent)
	local i1 = indent .. indentUnit
	local kind = z.kind or 'poly'
	local lines = {
		indent .. '{',
		i1 .. '"name": ' .. jsonScalar(z.name) .. ',',
		i1 .. '"kind": ' .. jsonScalar(kind) .. ',',
		i1 .. '"visible": ' .. jsonScalar(z.visible == true) .. ',',
		i1 .. '"height": ' .. jsonScalar(z.height) .. ',',
		i1 .. '"color": ' .. jsonScalar(z.color) .. ',',
	}
	if kind == 'circle' then
		lines[#lines + 1] = i1 .. '"radius": ' .. jsonScalar(z.radius) .. ','
	end
	local pts = z.points or {}
	if #pts == 0 then
		lines[#lines + 1] = i1 .. '"points": []'
	else
		lines[#lines + 1] = i1 .. '"points": ['
		local body = {}
		for i = 1, #pts do
			body[i] = encodePoint(pts[i], i1 .. indentUnit)
		end
		lines[#lines + 1] = table.concat(body, ',\n')
		lines[#lines + 1] = i1 .. ']'
	end
	lines[#lines + 1] = indent .. '}'
	return table.concat(lines, '\n')
end

-- Emit the full versioned envelope ({ schemaVersion, zones }) deterministically.
---@param list table
---@return string
local function encodeZonesFile(list)
	local lines = {
		'{',
		indentUnit .. '"schemaVersion": ' .. schemaVersion .. ',',
	}
	if #list == 0 then
		lines[#lines + 1] = indentUnit .. '"zones": []'
	else
		lines[#lines + 1] = indentUnit .. '"zones": ['
		local body = {}
		for i = 1, #list do
			body[i] = encodeZone(list[i], indentUnit .. indentUnit)
		end
		lines[#lines + 1] = table.concat(body, ',\n')
		lines[#lines + 1] = indentUnit .. ']'
	end
	lines[#lines + 1] = '}'
	return table.concat(lines, '\n')
end

-- Write the canonical list to disk in the versioned envelope shape.
---@param list ZoneData[]
---@return boolean
local function writeFile(list)
	return SaveResourceFile(resourceName, zonesFile, encodeZonesFile(list), -1) and true or false
end

-- Migrate data/zones.json forward to the current schema. Runs once on load.
-- File version = numeric top-level `schemaVersion`, or 0 for a legacy bare array.
-- No-op when already current, absent, or malformed.
local function migrateSchema()
	local raw = LoadResourceFile(resourceName, zonesFile)
	if not raw or raw == '' then
		return
	end
	local ok, decoded = pcall(json.decode, raw)
	if not ok or type(decoded) ~= 'table' then
		return
	end
	local fileVersion = type(decoded.schemaVersion) == 'number' and decoded.schemaVersion or 0
	if fileVersion >= schemaVersion then
		return
	end
	logmsg(('data/zones.json schema v%d is out of date (expected v%d) -- backing up and migrating')
		:format(fileVersion, schemaVersion))
	-- Back up the untouched original before the rewrite so a bad migration is recoverable.
	SaveResourceFile(resourceName, ('%s.v%d.bak'):format(zonesFile, fileVersion), raw, -1)
	-- An envelope carries the list under `zones`; a legacy bare array is the list.
	local list = type(decoded.zones) == 'table' and decoded.zones or decoded
	-- Per-version migration goes here (transform `list` in place, oldest bump first).
	-- writeFile re-emits in the current schema, so a pure key-shape change (v1's per-point id +
	-- 2d_map drop) needs no code; add a step only when a value must actually change.
	writeFile(list)
end

-- Rebuild the name index after `zones` is replaced.
local function reindex()
	byName = {}
	for i = 1, #zones do
		byName[zones[i].name] = zones[i]
	end
end

-- Read data/zones.json, drop invalid + duplicate-name zones into `zones`.
-- Reads both the versioned envelope and the legacy bare array. Missing/malformed yields an empty
-- list.
local function loadZones()
	zones = {}
	local raw = LoadResourceFile(resourceName, zonesFile)
	if not raw or raw == '' then
		reindex()
		return
	end
	local ok, decoded = pcall(json.decode, raw)
	if not ok or type(decoded) ~= 'table' then
		logmsg('data/zones.json is malformed -- starting with no zones')
		reindex()
		return
	end
	-- An envelope carries a `zones` list under a numeric `schemaVersion`; a bare array is legacy.
	local list
	if type(decoded.schemaVersion) == 'number' then
		list = type(decoded.zones) == 'table' and decoded.zones or {}
	else
		list = decoded
	end
	local result, seen = {}, {}
	for i = 1, #list do
		local zone = list[i]
		local valid, reason = validateZone(zone)
		if not valid then
			logmsg(('dropping invalid zone at index %d: %s'):format(i, reason))
		else
			local key = canonicalName(zone.name)
			if seen[key] then
				logmsg(('dropping duplicate zone name %q (kept first)'):format(key))
			else
				seen[key] = true
				zone.name = key
				result[#result + 1] = zone
			end
		end
	end
	zones = result
	reindex()
end

-- Validate + persist an incoming list. Rejects any invalid zone or duplicate name.
-- On success: write the file, replace `zones`, push the rebuild to all clients.
---@param list any
---@return boolean, string?, string?
local function saveZones(list)
	if type(list) ~= 'table' then
		return false, 'payload is not a list'
	end
	if #list > maxZones then
		return false, ('zone count exceeds the cap of %d'):format(maxZones)
	end
	local validated, seen = {}, {}
	for i = 1, #list do
		local zone = list[i]
		local valid, reason = validateZone(zone)
		if not valid then
			return false, ('zone %d invalid: %s'):format(i, reason)
		end
		local key = canonicalName(zone.name)
		if seen[key] then
			return false, ('duplicate zone name: %s'):format(key), key
		end
		seen[key] = true
		-- Normalize to exactly these fields, dropping stray editor state (UI-side point ids,
		-- dirty flags). `radius` rides along only for circles.
		local points = {}
		for p = 1, #zone.points do
			local point = zone.points[p]
			points[p] = { x = point.x, y = point.y, z = point.z }
		end
		local clean = {
			name = key,
			kind = zone.kind or 'poly',
			visible = zone.visible == true,
			height = zone.height,
			color = zone.color,
			points = points,
		}
		if clean.kind == 'circle' then
			clean.radius = zone.radius
		end
		validated[#validated + 1] = clean
	end
	-- Back up the current file before overwriting so a bad save is recoverable.
	local current = LoadResourceFile(resourceName, zonesFile)
	if current and current ~= '' then
		SaveResourceFile(resourceName, zonesFile .. '.bak', current, -1)
	end
	if not writeFile(validated) then
		return false, 'failed to write data/zones.json'
	end
	zones = validated
	reindex()
	TriggerClientEvent('zonemanager:sync', -1, zones)
	return true
end

-- 2D shape test against one canonical zone; optional z checks the vertical band (lowest point z
-- minus the ground buffer, up to + height).
---@param zone ZoneData
---@param x number
---@param y number
---@param z number?
---@return boolean
local function testZone(zone, x, y, z)
	if z ~= nil then
		local floor = math.huge
		for i = 1, #zone.points do
			local pz = zone.points[i].z
			if type(pz) == 'number' and pz < floor then floor = pz end
		end
		if floor ~= math.huge then
			if z < floor - groundFloorBuffer or z > floor + zone.height then
				return false
			end
		end
	end
	if zone.kind == 'circle' then
		local c = zone.points[1]
		local dx, dy = x - c.x, y - c.y
		return dx * dx + dy * dy <= zone.radius * zone.radius
	end
	return zoneGeometry.pointInRing(zone.points, x, y)
end

---@return ZoneData[]
function ZoneManager:GetZones()
	return deepCopy(zones)
end

-- Server-authoritative point test against the canonical persisted list - gate server logic on it
-- instead of trusting a client-reported enter/exit.
---@param name string
---@param x number
---@param y number
---@param z number?
---@return boolean, string?
function ZoneManager:IsPointInZone(name, x, y, z)
	local zone = byName[canonicalName(name)]
	if not zone then
		return false, 'no such zone'
	end
	if not isFiniteNumber(x) or not isFiniteNumber(y) then
		return false, 'coords must be numbers'
	end
	return testZone(zone, x, y, z)
end

-- Names of every canonical zone containing the point.
---@param x number
---@param y number
---@param z number?
---@return string[]
function ZoneManager:GetZonesAt(x, y, z)
	local hits = {}
	if not isFiniteNumber(x) or not isFiniteNumber(y) then
		return hits
	end
	for i = 1, #zones do
		if testZone(zones[i], x, y, z) then
			hits[#hits + 1] = zones[i].name
		end
	end
	return hits
end

-- A joining client requests the current set.
RegisterNetEvent('zonemanager:clientReady', function()
	local src = source
	TriggerClientEvent('zonemanager:sync', src, zones)
end)

-- Privileged editor command; admin gate is server-side. source 0 (console) no-ops.
RegisterCommand('zonemanager', function(source)
	if not isAdmin(source) then
		return
	end
	TriggerClientEvent('zonemanager:openEditor', source)
end, false)

-- Public server surface. Flat-function table: msgpack strips metatables across the
-- resource boundary, so no `:` metatable (self is just arg 1). Each call is an IPC hop.
exports('FetchModule', function()
	return {
		GetZones = function(self)
			return ZoneManager:GetZones()
		end,
		IsPointInZone = function(self, name, x, y, z)
			return ZoneManager:IsPointInZone(name, x, y, z)
		end,
		GetZonesAt = function(self, x, y, z)
			return ZoneManager:GetZonesAt(x, y, z)
		end,
	}
end)

-- Direct exports are easier for small resources to consume and avoid transporting a table of
-- function references across the resource boundary.
exports('GetZones', function()
	return ZoneManager:GetZones()
end)

exports('IsPointInZone', function(name, x, y, z)
	return ZoneManager:IsPointInZone(name, x, y, z)
end)

exports('GetZonesAt', function(x, y, z)
	return ZoneManager:GetZonesAt(x, y, z)
end)

-- Boot: migrate + load zones, then register the editor round-trips. Deferred so
-- registerCallback (server/cb.lua) exists regardless of glob load order.
CreateThread(function()
	migrateSchema()
	loadZones()
	-- requires='admin' re-checks isAdmin(src) server-side: the callback channel is a
	-- separate ingress a player can forge past the command gate.
	registerCallback('zonemanager:save', { requires = 'admin' }, function(_, list)
		local ok, err, collision = saveZones(list)
		if ok then
			return { ok = true }
		end
		return { ok = false, error = err, collision = collision }
	end)
	-- The client fetches the saved list when the editor opens.
	registerCallback('zonemanager:fetch', nil, function()
		return ZoneManager:GetZones()
	end)
end)
