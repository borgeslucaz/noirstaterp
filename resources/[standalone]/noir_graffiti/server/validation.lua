NoirValidation = {}

local fontWhitelist = {}
for _, font in ipairs(Config.Fonts) do fontWhitelist[font.id] = true end

local function characterLength(value)
    local ok, length = pcall(utf8.len, value)
    if not ok or not length then return end
    return length
end

function NoirValidation.text(value)
    if type(value) ~= 'string' then return nil, 'Texto inválido.' end
    if not Config.Text.allowLineBreaks and value:find('[\r\n]') then return nil, 'Quebras de linha não são permitidas.' end
    if value:find('[%z\1-\8\11\12\14-\31\127]') then return nil, 'O texto contém caracteres inválidos.' end
    if value:find('[<>{}]') then return nil, 'O texto contém caracteres não permitidos.' end
    value = value:gsub('%s+', ' '):match('^%s*(.-)%s*$')
    local length = characterLength(value)
    if not length then return nil, 'O texto não é UTF-8 válido.' end
    if length < Config.Text.minLength or length > Config.Text.maxLength then
        return nil, ('O texto deve ter entre %d e %d caracteres.'):format(Config.Text.minLength, Config.Text.maxLength)
    end
    return value
end

function NoirValidation.font(value)
    if type(value) ~= 'string' or not fontWhitelist[value] then return nil, 'Fonte inválida.' end
    return value
end

local function finite(value)
    value = tonumber(value)
    return value and value == value and math.abs(value) < math.huge and value or nil
end

function NoirValidation.placement(data)
    if type(data) ~= 'table' or data.type ~= 'text' then return nil, 'Tipo de graffiti inválido.' end
    local x, y, z = finite(data.x), finite(data.y), finite(data.z)
    local nx, ny, nz = finite(data.nx), finite(data.ny), finite(data.nz)
    local scale, rotation = finite(data.scale), finite(data.rotation)
    if not x or not y or not z or not nx or not ny or not nz or not scale or not rotation then return nil, 'Posição inválida.' end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then return nil, 'Posição fora do mapa.' end
    local normalLength = math.sqrt(nx * nx + ny * ny + nz * nz)
    if normalLength < 0.8 or normalLength > 1.2 or math.abs(nz) > Config.Placement.maxWallNormalZ then return nil, 'A superfície não é uma parede válida.' end
    if scale < Config.Placement.minScale or scale > Config.Placement.maxScale then return nil, 'Escala inválida.' end
    if rotation < -720 or rotation > 720 then return nil, 'Rotação inválida.' end
    return {
        coords = vector3(x, y, z),
        normal = vector3(nx / normalLength, ny / normalLength, nz / normalLength),
        scale = scale,
        rotation = ((rotation + 180) % 360) - 180,
    }
end

function NoirValidation.player(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    return player, player.PlayerData.citizenid
end

function NoirValidation.gang(source, player)
    if GetResourceState('noir_gangs') == 'started' then
        local ok, gang = pcall(function() return exports.noir_gangs:GetGang(source) end)
        if ok and gang and gang.name and gang.name ~= 'none' then return gang end
    end
    local gang = player and player.PlayerData.gang
    if gang and gang.name and gang.name ~= 'none' then return gang end
end

function NoirValidation.hasItem(source, item, slot)
    slot = tonumber(slot)
    if slot then
        local itemData = exports.ox_inventory:GetSlot(source, slot)
        return itemData and itemData.name == item, itemData
    end
    local itemData = exports.ox_inventory:GetSlotWithItem(source, item)
    return itemData ~= nil, itemData
end

function NoirValidation.consumeSpray(source, slot)
    local exists, itemData = NoirValidation.hasItem(source, Config.Items.spray, slot)
    if not exists then return false end
    slot = tonumber(slot) or itemData.slot
    if not Config.Items.useMetadata then return exports.ox_inventory:RemoveItem(source, Config.Items.spray, 1, nil, slot) end

    local uses = tonumber(itemData and itemData.metadata and itemData.metadata.uses) or Config.Items.defaultUses
    uses = uses - 1
    if uses <= 0 then return exports.ox_inventory:RemoveItem(source, Config.Items.spray, 1, nil, slot) end
    local metadata = itemData.metadata or {}
    metadata.uses = uses
    exports.ox_inventory:SetMetadata(source, slot, metadata)
    return true
end

function NoirValidation.territory(coords)
    if GetResourceState('noir_territories') ~= 'started' then return end
    local ok, territory = pcall(function() return exports.noir_territories:GetTerritoryAtCoords(coords) end)
    if not ok or not territory then return end
    return type(territory) == 'table' and (territory.id or territory.name) or tostring(territory)
end
