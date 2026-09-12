-- Zone Manager module (client). Owns the name->zone registry, builds zones from the server list,
-- fans enter/exit to subscribers. Published via exports.zonemanager:FetchModule().

-- ZoneManager is one LuaLS symbol but server + client are separate Lua states.
---@diagnostic disable: duplicate-set-field

ZoneManager = {}

-- name -> { zone = <ZoneInstance>, enabled = bool }
local registry = {}
-- OnEnter/OnExit subscribers; each fires under pcall so a bad one can't break peers.
local enterSubs, exitSubs = {}, {}
-- Ground Z sits ~0.3m above a standing ped's root coord, so a zone floored exactly at ground Z
-- never contains the player. Drop the floor by this margin.
local groundFloorBuffer = 1.0

local canonicalName = zoneGeometry.canonicalName

-- pcall per entry so one throwing handler can't break the others or the poll loop. point is the
-- player position at the crossing sample (absent on the synthetic exit when a host entity dies).
---@param subs fun(name: string, point?: vector3)[]
---@param name string
---@param point vector3?
local function fire(subs, name, point)
	TriggerEvent(subs == enterSubs and 'zonemanager:enter' or 'zonemanager:exit', name, point)
	for i = 1, #subs do
		pcall(subs[i], name, point)
	end
end

-- Build every zone from the server's canonical list. Destroys prior built zones first, and reaps
-- registry entries whose zone left the server list (a deleted zone must not keep answering
-- IsEnabled).
---@param list ZoneData[]
local function buildZones(list)
	for _, entry in pairs(registry) do
		-- runtime-attached zones aren't in the server list; a re-sync must not tear them down.
		if not entry.runtime then
			if entry.zone then
				entry.zone:destroy()
			end
			entry.zone = nil
		end
	end
	local seenNames = {}
	if type(list) ~= 'table' then
		list = {}
	end
	for i = 1, #list do
		local zone = list[i]
		if type(zone) == 'table' and type(zone.name) == 'string' and type(zone.points) == 'table' then
			local height = type(zone.height) == 'number' and zone.height or 0
			local built
			if zone.kind == 'circle' then
				local center = zone.points[1]
				if type(center) == 'table' and type(center.x) == 'number'
					and type(center.y) == 'number' and type(zone.radius) == 'number' then
					-- z may be absent before ground-Z resolved; default 0 so the band is safe.
					local cz = type(center.z) == 'number' and center.z or 0.0
					built = zoneEngine.createCircle(
						vector3(center.x + 0.0, center.y + 0.0, cz),
						zone.radius,
						{
							name = zone.name,
							minZ = cz - groundFloorBuffer,
							maxZ = cz + height,
							debug = zone.visible == true,
						}
					)
				end
			else
				local ring, minZ, maxZ = {}, math.huge, -math.huge
				for p = 1, #zone.points do
					local point = zone.points[p]
					ring[p] = vector2(point.x + 0.0, point.y + 0.0)
					-- z may be absent on points saved before ground-Z resolved; default 0.
					local z = point.z or 0.0
					if z < minZ then minZ = z end
					if z > maxZ then maxZ = z end
				end
				built = zoneEngine.create(ring, {
					name = zone.name,
					minZ = minZ - groundFloorBuffer,
					maxZ = maxZ + height,
					debug = zone.visible == true,
				})
			end
			if built then
				local entry = registry[zone.name]
				if entry and entry.runtime then
					-- name owned by a runtime zone; sync must not clobber it, so drop the built
					-- shape.
					built:destroy()
				else
					if not entry then
						entry = { enabled = true }
						registry[zone.name] = entry
					end
					seenNames[zone.name] = true
					entry.zone = built
					built:setPaused(not entry.enabled)
					built:onTransition(function(isInside, point)
						local current = registry[zone.name]
						if not current or not current.enabled then
							return
						end
						fire(isInside and enterSubs or exitSubs, zone.name, point)
						-- waitMs 0: re-test every poll tick so a crossing fires near-instantly.
					end, 0)
				end
			end
		end
	end
	-- reap entries dropped from the server list (deleted in the editor)
	for name, entry in pairs(registry) do
		if not entry.runtime and not seenNames[name] then
			registry[name] = nil
		end
	end
end

-- cb(name, coords) fires whenever the player enters any enabled zone.
---@param cb fun(name: string, point?: vector3)
function ZoneManager:OnEnter(cb)
	enterSubs[#enterSubs + 1] = cb
end

-- cb(name, coords) fires whenever the player leaves any enabled zone.
---@param cb fun(name: string, point?: vector3)
function ZoneManager:OnExit(cb)
	exitSubs[#exitSubs + 1] = cb
end

---@param name string
---@return boolean, string?
function ZoneManager:Enable(name)
	local entry = registry[canonicalName(name)]
	if not entry then
		return false, 'no such zone'
	end
	entry.enabled = true
	if entry.zone then
		entry.zone:setPaused(false)
	end
	return true
end

---@param name string
---@return boolean, string?
function ZoneManager:Disable(name)
	local entry = registry[canonicalName(name)]
	if not entry then
		return false, 'no such zone'
	end
	entry.enabled = false
	if entry.zone then
		entry.zone:setPaused(true)
	end
	return true
end

---@param name string
---@return boolean
function ZoneManager:IsEnabled(name)
	local entry = registry[canonicalName(name)]
	return entry ~= nil and entry.enabled == true
end

-- Live inside-ness of one zone, no subscription needed.
---@param name string
---@return boolean
function ZoneManager:IsInside(name)
	local entry = registry[canonicalName(name)]
	return entry ~= nil and entry.zone ~= nil and entry.zone.inside == true
end

-- Names of every enabled zone the player is currently inside.
---@return string[]
function ZoneManager:GetCurrentZones()
	local names = {}
	for name, entry in pairs(registry) do
		if entry.enabled and entry.zone and entry.zone.inside then
			names[#names + 1] = name
		end
	end
	return names
end

-- Toggle the in-world debug box on an attached entity zone (visual test aid).
---@param name string
---@param on boolean
---@return boolean, string?
function ZoneManager:SetZoneDebug(name, on)
	local entry = registry[canonicalName(name)]
	if not entry then
		return false, 'no such zone'
	end
	if entry.zone then
		entry.zone:setDebug(on)
	end
	return true
end

-- Attach a runtime zone tracking a live entity's model box (position + rotation). Fires enter/exit
-- by name like a built zone, so Enable/Disable/IsEnabled and subscribers all work on it. Returns
-- false + reason on a taken name or dead entity; never raises.
---@param name string
---@param entity integer
---@param opts ZoneAttachOpts?
---@return boolean, string?
function ZoneManager:AttachZoneToEntity(name, entity, opts)
	local key = canonicalName(name)
	if registry[key] then
		return false, 'name in use'
	end
	if type(entity) ~= 'number' or not DoesEntityExist(entity) then
		return false, 'no such entity'
	end
	opts = type(opts) == 'table' and opts or {}
	if opts.padding ~= nil and type(opts.padding) ~= 'number' then
		return false, 'padding must be a number'
	end
	local built = zoneEngine.createEntity(entity, {
		name = key,
		useZ = opts.useZ,
		padding = opts.padding,
		debug = opts.debug,
	})
	local entry = { zone = built, enabled = true, runtime = true }
	registry[key] = entry
	built:onTransition(function(isInside, point)
		local current = registry[key]
		if not current or not current.enabled then
			return
		end
		fire(isInside and enterSubs or exitSubs, key, point)
	end, 0)
	-- Nothing else reaps an attached zone. When the host entity dies, drop the zone + registry
	-- entry so the poll loop doesn't scan a dead handle forever; emit a final exit if inside.
	CreateThread(function()
		while registry[key] == entry do
			if not DoesEntityExist(entity) then
				if entry.enabled and built.inside then
					fire(exitSubs, key)
				end
				built:destroy()
				registry[key] = nil
				return
			end
			Wait(1000)
		end
	end)
	return true
end

-- Tear down a runtime-attached zone by name. Returns false for an unknown name or a built
-- (server-list) zone, so a consumer can't detach a synced zone here.
---@param name string
---@return boolean, string?
function ZoneManager:DetachZone(name)
	local key = canonicalName(name)
	local entry = registry[key]
	if not entry or not entry.runtime then
		return false, 'no such attached zone'
	end
	if entry.zone then
		entry.zone:destroy()
	end
	registry[key] = nil
	return true
end

-- Server pushes the canonical list on join hand-off and every live-reload save.
RegisterNetEvent('zonemanager:sync', function(zones)
	buildZones(zones)
end)

-- Flat-function table over the export bus. No metatable: msgpack strips it across the boundary; `:`
-- still works since self is just arg 1. The value methods are IPC hops - never put a per-frame call
-- behind one.
exports('FetchModule', function()
	return {
		Enable = function(self, name)
			return ZoneManager:Enable(name)
		end,
		Disable = function(self, name)
			return ZoneManager:Disable(name)
		end,
		IsEnabled = function(self, name)
			return ZoneManager:IsEnabled(name)
		end,
		IsInside = function(self, name)
			return ZoneManager:IsInside(name)
		end,
		GetCurrentZones = function(self)
			return ZoneManager:GetCurrentZones()
		end,
		OnEnter = function(self, cb)
			return ZoneManager:OnEnter(cb)
		end,
		OnExit = function(self, cb)
			return ZoneManager:OnExit(cb)
		end,
		AttachZoneToEntity = function(self, name, entity, opts)
			return ZoneManager:AttachZoneToEntity(name, entity, opts)
		end,
		DetachZone = function(self, name)
			return ZoneManager:DetachZone(name)
		end,
		SetZoneDebug = function(self, name, on)
			return ZoneManager:SetZoneDebug(name, on)
		end,
	}
end)

-- Announce readiness so the server hands off the current set. Deferred one tick so the engine +
-- sibling globals resolve before the first sync lands.
CreateThread(function()
	TriggerServerEvent('zonemanager:clientReady')
end)
