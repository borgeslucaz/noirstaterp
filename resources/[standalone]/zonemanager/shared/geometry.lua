-- Shared zone helpers: registry-key normalization + pure point-in-shape math.
-- Loaded on both sides via shared_scripts; no natives, no state.

zoneGeometry = {}

-- Registry key form: trim, lowercase, spaces -> underscore. One canonical form
-- shared by the server file, the client registry, and every API lookup, so
-- "Legion Square" and "legion_square" always collapse to the same key.
---@param name string
---@return string
function zoneGeometry.canonicalName(name)
	return (name:gsub('^%s+', ''):gsub('%s+$', ''):lower():gsub('%s+', '_'))
end

-- Even-odd ray cast over a ring. Entries only need .x/.y, so vector2 vertices
-- (client engine) and plain point tables (server data) both work.
---@param ring table
---@param px number
---@param py number
---@return boolean
function zoneGeometry.pointInRing(ring, px, py)
	local n = #ring
	local inside = false
	local j = n
	for i = 1, n do
		local vi, vj = ring[i], ring[j]
		local yi, yj = vi.y, vj.y
		if (yi > py) ~= (yj > py) then
			local xi, xj = vi.x, vj.x
			if px < (xj - xi) * (py - yi) / (yj - yi) + xi then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end
