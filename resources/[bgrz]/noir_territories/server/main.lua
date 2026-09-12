local function canonicalName(name)
    if type(name) ~= 'string' then return end
    return name:gsub('^%s+', ''):gsub('%s+$', ''):lower():gsub('%s+', '_')
end

local function areaLabel(name)
    local label = name:gsub('_', ' ')
    return label:gsub('(%a)([%w]*)', function(first, rest)
        return first:upper() .. rest
    end)
end

local function readCoords(coords)
    if coords == nil then return end

    local ok, x, y, z = pcall(function()
        return tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    end)
    if not ok or not x or not y then return end
    return x, y, z
end

local function decorate(zone)
    if type(zone) ~= 'table' or type(zone.name) ~= 'string' then return end
    zone.id = zone.name
    zone.label = areaLabel(zone.name)
    return zone
end

local function getTerritories()
    if GetResourceState('zonemanager') ~= 'started' then return {} end

    local ok, zones = pcall(function() return exports.zonemanager:GetZones() end)
    if not ok or type(zones) ~= 'table' then return {} end

    for i = 1, #zones do decorate(zones[i]) end
    return zones
end

local function getTerritory(id)
    local wanted = canonicalName(id)
    if not wanted then return end

    local zones = getTerritories()
    for i = 1, #zones do
        if zones[i].name == wanted then return zones[i] end
    end
end

local function getTerritoryAtCoords(coords)
    local x, y, z = readCoords(coords)
    if not x then return end

    if GetResourceState('zonemanager') ~= 'started' then return end

    local ok, names = pcall(function() return exports.zonemanager:GetZonesAt(x, y, z) end)
    if not ok or type(names) ~= 'table' or not names[1] then return end
    return getTerritory(names[1])
end

local function isInsideTerritory(id, coords)
    local name = canonicalName(id)
    local x, y, z = readCoords(coords)
    if not name or not x then return false end

    if GetResourceState('zonemanager') ~= 'started' then return false end

    local ok, inside = pcall(function()
        return exports.zonemanager:IsPointInZone(name, x, y, z)
    end)
    return ok and inside == true
end

exports('GetTerritoryAtCoords', getTerritoryAtCoords)
exports('GetTerritory', getTerritory)
exports('GetTerritories', getTerritories)
exports('IsInsideTerritory', isInsideTerritory)
