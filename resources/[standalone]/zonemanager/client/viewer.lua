-- 3D zone viewer (client). Drops a free camera over the zone, draws its polygon + height band, lets
-- the editor tweak height live, restores gameplay on exit.

-- one viewer at a time; all viewer state is file-local
local active = false
---@type integer|false
local cam = false
local camCoords = vector3(0.0, 0.0, 0.0)
local camRot = vector3(0.0, 0.0, 0.0)
---@type ZonePoint[]
local drawPoints = {}
local drawColor, baseZ, height, editorOpen = { 34, 197, 94 }, 0.0, 150.0, true
local origCoords, origHeading = nil, 0.0

-- control indices (PAD): mouse look, WASD, vertical, speed, height, exit
local controls = {
	lookLr = 1,
	lookUd = 2,
	wheelDown = 14,
	wheelUp = 15,
	sprint = 21,
	forward = 32,
	back = 33,
	left = 34,
	right = 35,
	up = 38,
	down = 44,
	heightUp = 172,
	heightDown = 173,
	exit = 177,
}

-- "#RRGGBB" -> {r,g,b}; falls back to green on a malformed string.
local function hexToRgb(hex)
	if type(hex) ~= 'string' then
		return { 34, 197, 94 }
	end
	local r, g, b = hex:match('^#?(%x%x)(%x%x)(%x%x)$')
	if not r then
		return { 34, 197, 94 }
	end
	return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

-- polygon centroid (avg of vertex x/y) + average vertex z as the base plane.
local function centroidOf(points)
	local n = #points
	local sx, sy, sz = 0.0, 0.0, 0.0
	for i = 1, n do
		local p = points[i]
		sx = sx + p.x
		sy = sy + p.y
		sz = sz + (p.z or 0.0)
	end
	return sx / n, sy / n, sz / n
end

-- footprint half-extent: half the larger of the polygon's x/y span. Drives the camera pull-back so
-- any zone size frames to fit.
local function radiusOf(points)
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	for i = 1, #points do
		local p = points[i]
		if p.x < minX then minX = p.x end
		if p.x > maxX then maxX = p.x end
		if p.y < minY then minY = p.y end
		if p.y > maxY then maxY = p.y end
	end
	return math.max(maxX - minX, maxY - minY) * 0.5
end

-- Solid walls: each edge is a filled quad (two tris) from the ground ring to the top ring. DrawPoly
-- is single-sided, so each tri is drawn both windings to show from inside and outside. Drawn fresh
-- each frame.
local function drawBand()
	local n = #drawPoints
	local r, g, b = drawColor[1], drawColor[2], drawColor[3]
	for i = 1, n do
		local a = drawPoints[i]
		local c = drawPoints[i % n + 1]
		-- per-vertex ground z so the floor follows terrain; top is its own ground + height.
		local az = a.z or baseZ
		local cz = c.z or baseZ
		local at = az + height
		local ct = cz + height
		DrawPoly(a.x, a.y, az, c.x, c.y, cz, c.x, c.y, ct, r, g, b, 110)
		DrawPoly(a.x, a.y, az, c.x, c.y, ct, a.x, a.y, at, r, g, b, 110)
		DrawPoly(a.x, a.y, az, c.x, c.y, ct, c.x, c.y, cz, r, g, b, 110)
		DrawPoly(a.x, a.y, az, a.x, a.y, at, c.x, c.y, ct, r, g, b, 110)
		DrawLine(a.x, a.y, az, c.x, c.y, cz, r, g, b, 220)
		DrawLine(a.x, a.y, at, c.x, c.y, ct, r, g, b, 220)
	end
end

-- push the live height back so the editor UI reflects the in-world tweak.
local function pushHeight()
	SendNUIMessage({
		action = 'zonemanager:viewerUpdate',
		data = { height = height },
	})
end

-- stop the viewer: drop the cam, restore the ped, re-focus the editor.
local function stopViewer()
	if not active then
		return
	end
	active = false
	if cam then
		RenderScriptCams(false, true, 500, true, false)
		DestroyCam(cam, false)
		cam = false
	end
	local ped = PlayerPedId()
	SetEntityVisible(ped, true, false)
	SetEntityCollision(ped, true, true)
	FreezeEntityPosition(ped, false)
	if origCoords then
		SetEntityCoords(ped, origCoords.x, origCoords.y, origCoords.z, false, false, false, false)
		SetEntityHeading(ped, origHeading)
	end
	if editorOpen then
		SetNuiFocus(true, true)
		SendNUIMessage({ action = 'zonemanager:viewerStopped', data = { height = height } })
	end
end

-- free-fly loop: mouse look, WASD + Q/E, wheel speed, arrows for height.
---@param viewerCam integer
local function flyLoop(viewerCam)
	local moveSpeed = 1.0
	local rotSpeed = 3.0
	local heightCooldown = 0.0
	CreateThread(function()
		while active do
			Wait(0)
			drawBand()
			DisableAllControlActions(0)
			local dx = GetDisabledControlNormal(0, controls.lookLr) * rotSpeed
			local dy = GetDisabledControlNormal(0, controls.lookUd) * rotSpeed
			camRot = vector3(
				math.max(-89.0, math.min(89.0, camRot.x - dy)),
				camRot.y,
				camRot.z - dx
			)
			local radX = math.rad(camRot.x)
			local radZ = math.rad(camRot.z)
			local forward = vector3(-math.sin(radZ) * math.cos(radX), math.cos(radZ) * math.cos(radX),
				math.sin(radX))
			local right = vector3(math.cos(radZ), math.sin(radZ), 0.0)
			if IsDisabledControlPressed(0, controls.wheelUp) then
				moveSpeed = math.min(moveSpeed * 1.1, 10.0)
			elseif IsDisabledControlPressed(0, controls.wheelDown) then
				moveSpeed = math.max(moveSpeed * 0.9, 0.1)
			end
			local move = vector3(0.0, 0.0, 0.0)
			if IsDisabledControlPressed(0, controls.forward) then
				move = move + forward
			end
			if IsDisabledControlPressed(0, controls.back) then
				move = move - forward
			end
			if IsDisabledControlPressed(0, controls.left) then
				move = move - right
			end
			if IsDisabledControlPressed(0, controls.right) then
				move = move + right
			end
			if IsDisabledControlPressed(0, controls.down) then
				move = move - vector3(0.0, 0.0, 1.0)
			end
			if IsDisabledControlPressed(0, controls.up) then
				move = move + vector3(0.0, 0.0, 1.0)
			end
			if IsDisabledControlPressed(0, controls.sprint) then
				move = move * 3.0
			end
			camCoords = camCoords + (move * moveSpeed)
			SetCamCoord(viewerCam, camCoords.x, camCoords.y, camCoords.z)
			SetCamRot(viewerCam, camRot.x, camRot.y, camRot.z, 2)
			if heightCooldown <= 0.0 then
				local changed = false
				if IsDisabledControlPressed(0, controls.heightUp) then
					height = height + 1.0
					heightCooldown = 100.0
					changed = true
				elseif IsDisabledControlPressed(0, controls.heightDown) and height > 1.0 then
					height = height - 1.0
					heightCooldown = 100.0
					changed = true
				end
				if changed then
					pushHeight()
				end
			else
				heightCooldown = heightCooldown - GetFrameTime() * 1000.0
			end
			if IsDisabledControlJustPressed(0, controls.exit) then
				stopViewer()
			end
		end
	end)
end

-- resource-local global: editor.lua calls this directly (same side, same resource)
---@param zone ZoneData
function startZoneViewer(zone)
	if not zone then
		return
	end
	-- A circle has no ring; synthesize one from center + radius so the band renderer + framing math
	-- run unchanged.
	if zone.kind == 'circle' then
		local c = type(zone.points) == 'table' and zone.points[1]
		if type(c) ~= 'table' or type(c.x) ~= 'number' or type(c.y) ~= 'number'
			or type(zone.radius) ~= 'number' then
			return
		end
		local cz = type(c.z) == 'number' and c.z or nil
		local ring, segments = {}, 24
		for i = 0, segments - 1 do
			local a = (i / segments) * math.pi * 2.0
			ring[#ring + 1] = {
				x = c.x + math.cos(a) * zone.radius,
				y = c.y + math.sin(a) * zone.radius,
				z = cz,
			}
		end
		zone = {
			name = zone.name,
			visible = zone.visible,
			color = zone.color,
			height = zone.height,
			points = ring,
		}
	end
	if type(zone.points) ~= 'table' or #zone.points < 3 then
		return
	end
	-- Zone arrives from a forgeable NUI callback; every vertex must be numeric before it reaches
	-- the centroid/cam math + DrawPoly.
	for i = 1, #zone.points do
		local p = zone.points[i]
		if type(p) ~= 'table' or type(p.x) ~= 'number' or type(p.y) ~= 'number'
			or (p.z ~= nil and type(p.z) ~= 'number') then
			return
		end
	end
	-- A prior flyLoop death without a clean exit wedges `active` true and no-ops later opens; tear
	-- the old viewer down first.
	if active then
		stopViewer()
	end
	drawPoints = zone.points
	drawColor = hexToRgb(zone.color)
	height = zone.height or 150.0
	editorOpen = true
	local cx, cy, cz = centroidOf(zone.points)
	baseZ = cz
	-- Pull the cam back + up by the footprint so the whole band frames at a 3/4 angle regardless of
	-- zone size.
	local radius = radiusOf(zone.points)
	local dist = math.max(radius * 2.0, 40.0)
	local camZ = baseZ + height * 0.5 + math.max(radius * 1.5, 30.0)
	local targetZ = baseZ + height * 0.5
	-- pitch from the cam-to-target drop over the ground distance; yaw 0 looks +Y
	local pitch = -math.deg(math.atan(camZ - targetZ, dist))
	local ped = PlayerPedId()
	origCoords = GetEntityCoords(ped)
	origHeading = GetEntityHeading(ped)
	cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
	camCoords = vector3(cx, cy - dist, camZ)
	camRot = vector3(pitch, 0.0, 0.0)
	SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
	SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
	SetCamFov(cam, 60.0)
	RenderScriptCams(true, true, 500, true, false)
	SetEntityVisible(ped, false, false)
	SetEntityCollision(ped, false, false)
	FreezeEntityPosition(ped, true)
	SetEntityCoords(ped, cx, cy, baseZ, false, false, false, false)
	active = true
	SetNuiFocus(false, false)
	-- flyLoop's first DisableAllControlActions is a tick away (CreateThread defers); without this a
	-- stray pause input leaks through that gap.
	DisableAllControlActions(0)
	SendNUIMessage({ action = 'zonemanager:viewerStarted', data = { height = height } })
	flyLoop(cam)
end

-- a resource stop mid-view must not leave the player frozen + invisible.
AddEventHandler('onClientResourceStop', function(res)
	if res == GetCurrentResourceName() then
		stopViewer()
	end
end)
