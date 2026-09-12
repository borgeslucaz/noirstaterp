-- Zone engine (client). Builds a zone from a vector2 ring + Z band, tests point-in-shape, polls the
-- player to fire boundary transitions. Polygon is default; circle (squared-distance) and entity
-- (model box following a live entity) are kind-tagged variants sharing the poll loop.

zoneEngine = {}

-- live, non-destroyed zone instances the poll loop scans
local active = {}
-- base poll cadence; each zone's waitMs is honored on top via a next-due stamp
local baseTickMs = 100
-- Distance-based backoff for static zones: outside the near ring, re-test at 400ms; outside the far
-- ring, 1000ms. 120m at 1000ms holds even for aircraft (~120 m/s), so a crossing is seen at most
-- one stretched tick late.
local backoff = {
	nearDist = 40.0,
	nearMs = 400,
	farDist = 120.0,
	farMs = 1000,
}

-- File-scope so neither reallocates per frame (drawEntityBox runs every frame while debug is on).
local function worldCorner(ent, lx, ly, lz)
	return GetOffsetFromEntityInWorldCoords(ent, lx, ly, lz)
end

local function drawEdge(p, q)
	DrawLine(p.x, p.y, p.z, q.x, q.y, q.z, 0, 220, 90, 200)
end

-- Wireframe an entity zone's box (8 local corners -> world, 12 edges) so the detection volume is
-- visible in-world while testing.
local function drawEntityBox(zone)
	local ent = zone.entity
	local mn, mx = zone.boxMin, zone.boxMax
	local b1, b2 = worldCorner(ent, mn.x, mn.y, mn.z), worldCorner(ent, mx.x, mn.y, mn.z)
	local b3, b4 = worldCorner(ent, mx.x, mx.y, mn.z), worldCorner(ent, mn.x, mx.y, mn.z)
	local t1, t2 = worldCorner(ent, mn.x, mn.y, mx.z), worldCorner(ent, mx.x, mn.y, mx.z)
	local t3, t4 = worldCorner(ent, mx.x, mx.y, mx.z), worldCorner(ent, mn.x, mx.y, mx.z)
	drawEdge(b1, b2)
	drawEdge(b2, b3)
	drawEdge(b3, b4)
	drawEdge(b4, b1)
	drawEdge(t1, t2)
	drawEdge(t2, t3)
	drawEdge(t3, t4)
	drawEdge(t4, t1)
	drawEdge(b1, t1)
	drawEdge(b2, t2)
	drawEdge(b3, t3)
	drawEdge(b4, t4)
end

-- One shared draw loop; runs only while >=1 entity zone has debug on, self-stops when none remain.
local debugThreadRunning = false
local function ensureDebugThread()
	if debugThreadRunning then return end
	debugThreadRunning = true
	CreateThread(function()
		while true do
			local any = false
			for zone in pairs(active) do
				if zone.debug and zone.kind == 'entity' and DoesEntityExist(zone.entity) then
					any = true
					drawEntityBox(zone)
				end
			end
			if not any then
				debugThreadRunning = false
				return
			end
			Wait(0)
		end
	end)
end

local zoneMethods = {}
zoneMethods.__index = zoneMethods

-- cb(isInside, point) fires only on a state change, at most every waitMs.
function zoneMethods:onTransition(cb, waitMs)
	self.transition = cb
	self.waitMs = waitMs or 500
end

---@param point vector3
---@return boolean
function zoneMethods:isPointInside(point)
	local kind = self.kind
	if kind == 'circle' then
		-- cylinder: optional vertical band reject, then 2D squared-distance compare (no sqrt on the
		-- hot path).
		local pz = point.z
		if self.minZ and pz < self.minZ then
			return false
		end
		if self.maxZ and pz > self.maxZ then
			return false
		end
		local c = self.center
		local dx, dy = point.x - c.x, point.y - c.y
		return dx * dx + dy * dy <= self.radiusSq
	end
	if kind == 'entity' then
		local entity = self.entity
		if not DoesEntityExist(entity) then
			return false
		end
		-- inverse-transform the world point into entity-local space, then test the model's
		-- axis-aligned box - follows live position + rotation via the entity matrix.
		local lp = GetOffsetFromEntityGivenWorldCoords(entity, point.x, point.y, point.z)
		local mn, mx = self.boxMin, self.boxMax
		if lp.x < mn.x or lp.x > mx.x or lp.y < mn.y or lp.y > mx.y then
			return false
		end
		if self.useZ and (lp.z < mn.z or lp.z > mx.z) then
			return false
		end
		return true
	end
	local px, py, pz = point.x, point.y, point.z
	-- cheap bbox reject before the ray cast
	if px < self.minX or px > self.maxX or py < self.minY or py > self.maxY then
		return false
	end
	if self.minZ and pz < self.minZ then
		return false
	end
	if self.maxZ and pz > self.maxZ then
		return false
	end
	return zoneGeometry.pointInRing(self.points, px, py)
end

function zoneMethods:setPaused(paused)
	self.paused = paused and true or false
end

-- Toggle the in-world debug box (entity zones only); starts the draw loop when on.
function zoneMethods:setDebug(on)
	self.debug = on and true or false
	if self.debug then
		ensureDebugThread()
	end
end

function zoneMethods:destroy()
	active[self] = nil
end

-- Squared horizontal gap between the player and the zone's outer edge; 0 when on/inside the
-- footprint. Drives the poll backoff for static zones.
---@param zone table
---@param px number
---@param py number
---@return number
local function slackSq(zone, px, py)
	if zone.kind == 'circle' then
		local c = zone.center
		local dx, dy = px - c.x, py - c.y
		local dSq = dx * dx + dy * dy
		if dSq <= zone.radiusSq then
			return 0.0
		end
		-- one sqrt only when already outside the radius, off the hot inside path
		local slack = math.sqrt(dSq) - math.sqrt(zone.radiusSq)
		return slack * slack
	end
	local dx = math.max(zone.minX - px, px - zone.maxX, 0.0)
	local dy = math.max(zone.minY - py, py - zone.maxY, 0.0)
	return dx * dx + dy * dy
end

---@param points table ring of vector2 game coords
---@param opts ZoneCreateOpts?
---@return ZoneInstance
function zoneEngine.create(points, opts)
	opts = opts or {}
	-- precompute the bounding box for a cheap reject before the ray cast.
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	for i = 1, #points do
		local v = points[i]
		if v.x < minX then minX = v.x end
		if v.x > maxX then maxX = v.x end
		if v.y < minY then minY = v.y end
		if v.y > maxY then maxY = v.y end
	end
	local zone = setmetatable({
		points = points,
		name = opts.name,
		minZ = opts.minZ,
		maxZ = opts.maxZ,
		debug = opts.debug,
		paused = false,
		minX = minX,
		minY = minY,
		maxX = maxX,
		maxY = maxY,
		inside = false,
		nextDue = 0,
	}, zoneMethods)
	active[zone] = true
	return zone
end

-- Cylinder zone: 2D radius around center, optional vertical band (minZ/maxZ). Omit the band for an
-- infinite-height column.
---@param center vector3 zone center in game coords
---@param radius number
---@param opts ZoneCircleOpts?
---@return ZoneInstance
function zoneEngine.createCircle(center, radius, opts)
	opts = opts or {}
	local zone = setmetatable({
		kind = 'circle',
		center = center,
		radiusSq = radius * radius,
		minZ = opts.minZ,
		maxZ = opts.maxZ,
		name = opts.name,
		debug = opts.debug,
		paused = false,
		inside = false,
		nextDue = 0,
	}, zoneMethods)
	active[zone] = true
	return zone
end

-- Zone bound to a live entity: tracks its model box, following position + rotation each poll. useZ
-- defaults true; pass useZ=false to test the footprint only.
---@param entity integer
---@param opts ZoneEntityOpts?
---@return ZoneInstance
function zoneEngine.createEntity(entity, opts)
	opts = opts or {}
	assert(DoesEntityExist(entity), 'zoneEngine.createEntity: entity does not exist')
	-- Box is the model AABB; opts.padding (meters) grows every side outward.
	local boxMin, boxMax = GetModelDimensions(GetEntityModel(entity))
	local pad = opts.padding or 0
	if pad ~= 0 then
		boxMin = boxMin - vector3(pad, pad, pad)
		boxMax = boxMax + vector3(pad, pad, pad)
	end
	local zone = setmetatable({
		kind = 'entity',
		entity = entity,
		boxMin = boxMin,
		boxMax = boxMax,
		useZ = opts.useZ ~= false,
		name = opts.name,
		debug = opts.debug,
		paused = false,
		inside = false,
		nextDue = 0,
	}, zoneMethods)
	active[zone] = true
	if zone.debug then
		ensureDebugThread()
	end
	return zone
end

-- Poll loop: each base tick, sample the player once, then test every active non-paused zone whose
-- per-zone due stamp has elapsed. Fire the transition only on an inside-ness flip. Static zones far
-- from the player re-test on the stretched backoff cadence instead of every waitMs; entity zones
-- always use waitMs (the host moves, the gap math would lie).
local nearSq = backoff.nearDist * backoff.nearDist
local farSq = backoff.farDist * backoff.farDist
CreateThread(function()
	while true do
		-- Nothing built/attached: skip the per-tick coord sample entirely.
		if next(active) == nil then
			Wait(baseTickMs)
			goto continue
		end
		local now = GetGameTimer()
		local ped = PlayerPedId()
		local coords = GetEntityCoords(ped, false)
		for zone in pairs(active) do
			if not zone.paused and zone.transition and now >= zone.nextDue then
				local isInside = zone:isPointInside(coords)
				if isInside ~= zone.inside then
					zone.inside = isInside
					zone.transition(isInside, coords)
				end
				local due = zone.waitMs
				if not isInside and zone.kind ~= 'entity' then
					local gapSq = slackSq(zone, coords.x, coords.y)
					if gapSq > farSq then
						due = backoff.farMs
					elseif gapSq > nearSq then
						due = backoff.nearMs
					end
				end
				zone.nextDue = now + due
			end
		end
		Wait(baseTickMs)
		::continue::
	end
end)
