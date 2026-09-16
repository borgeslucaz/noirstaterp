NoirValidation = {}

local fonts = {}
for _, font in ipairs(Config.Fonts) do fonts[font.id] = true end

---Comprimento em caracteres, não em bytes: 'ção' são 3 caracteres e 5 bytes.
local function characterLength(value)
    local ok, length = pcall(utf8.len, value)
    if not ok or not length then return end
    return length
end

---Aceita várias linhas. A quebra é o único caractere de controle que passa; o resto da
---faixa de \0 a \31 continua barrado. O limite de comprimento conta caracteres visíveis,
---sem as quebras, para o jogador não gastar a cota criando linhas vazias.
function NoirValidation.text(value)
    if type(value) ~= 'string' then return nil, 'Texto inválido.' end
    value = value:gsub('\r\n', '\n'):gsub('\r', '\n')
    if value:find('[%z\1-\8\11-\31\127]') then return nil, 'O texto contém caracteres inválidos.' end
    -- O texto vai parar em duas superfícies HTML (preview e renderer). As duas escrevem
    -- por textContent, nunca por innerHTML, mas isto aqui é o cinto de segurança.
    if value:find('[<>]') then return nil, 'O texto contém caracteres não permitidos.' end

    local lines, length = {}, 0
    for line in (value .. '\n'):gmatch('(.-)\n') do
        line = line:gsub('[ \t]+', ' '):match('^%s*(.-)%s*$')
        if line ~= '' then
            local count = characterLength(line)
            if not count then return nil, 'O texto não é UTF-8 válido.' end
            lines[#lines + 1] = line
            length = length + count
        end
    end

    if #lines > Config.Text.maxLines then
        return nil, ('O texto pode ter no máximo %d linhas.'):format(Config.Text.maxLines)
    end
    if length < Config.Text.minLength or length > Config.Text.maxLength then
        return nil, ('O texto deve ter entre %d e %d caracteres.'):format(
            Config.Text.minLength, Config.Text.maxLength)
    end
    return table.concat(lines, '\n')
end

function NoirValidation.font(value)
    if type(value) ~= 'string' or not fonts[value] then return nil, 'Fonte inválida.' end
    return value
end

function NoirValidation.color(value)
    if type(value) ~= 'string' or not value:match('^#%x%x%x%x%x%x$') then return nil, 'Cor inválida.' end
    return value:upper()
end

function NoirValidation.thickness(value)
    value = tonumber(value)
    if not value or value ~= value then return nil, 'Espessura inválida.' end
    value = math.floor(value + 0.5)
    if value < Config.Thickness.min or value > Config.Thickness.max then
        return nil, 'Espessura inválida.'
    end
    return value
end

local function finite(value)
    value = tonumber(value)
    return value and value == value and math.abs(value) < math.huge and value or nil
end

function NoirValidation.placement(data)
    if type(data) ~= 'table' then return nil, 'Posição inválida.' end
    local x, y, z = finite(data.x), finite(data.y), finite(data.z)
    local nx, ny, nz = finite(data.nx), finite(data.ny), finite(data.nz)
    local rotation, scale = finite(data.rotation), finite(data.scale)
    if not x or not y or not z or not nx or not ny or not nz or not rotation or not scale then
        return nil, 'Posição inválida.'
    end
    if scale < Config.Placement.minScale or scale > Config.Placement.maxScale then
        return nil, 'Tamanho inválido.'
    end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then
        return nil, 'Posição fora do mapa.'
    end
    local length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length < 0.8 or length > 1.2 then return nil, 'Superfície inválida.' end
    nx, ny, nz = nx / length, ny / length, nz / length
    if math.abs(nz) > Config.Placement.maxWallNormalZ then return nil, 'A superfície não é uma parede.' end
    return {
        coords = vector3(x, y, z),
        normal = vector3(nx, ny, nz),
        rotation = rotation % 360,
        scale = scale,
    }
end

---Gang do jogador, pelo bridge. Ausência e 'none' viram nil: quem não tem gang picha igual,
---só não reivindica território. A tag continua sendo dele pelo `placed_by`.
---@return string?
function NoirValidation.gang(source)
    local ok, gang = pcall(function() return exports.bgrz_core:GetGang(source) end)
    if not ok or type(gang) ~= 'table' then return end

    local name = gang.name
    if type(name) ~= 'string' or name == '' or name == 'none' then return end
    return name
end

function NoirValidation.citizenId(source)
    local ok, citizenId = pcall(function() return exports.bgrz_core:GetCitizenId(source) end)
    if not ok or type(citizenId) ~= 'string' then return end
    return citizenId
end

---Diferença de altura entre o graffiti e o personagem. O cliente já barra, mas quem
---decide o que entra no banco é daqui.
function NoirValidation.withinHeight(source, coords, up, down)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return false end
    local rise = coords.z - GetEntityCoords(ped).z
    return rise <= up and rise >= -down
end

function NoirValidation.nearPlayer(source, coords, maxDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= maxDistance
end

---@return boolean has, table? itemData
function NoirValidation.hasItem(source, item, slot)
    slot = tonumber(slot)
    if slot then
        local itemData = exports.ox_inventory:GetSlot(source, slot)
        return itemData ~= nil and itemData.name == item, itemData
    end
    local itemData = exports.ox_inventory:GetSlotWithItem(source, item)
    return itemData ~= nil, itemData
end

---Gasta um uso da lata; some com ela quando zera.
function NoirValidation.consumeSpray(source, slot)
    local exists, itemData = NoirValidation.hasItem(source, Config.Items.spray, slot)
    if not exists or not itemData then return false end
    slot = itemData.slot
    local uses = (tonumber(itemData.metadata and itemData.metadata.uses) or Config.Items.uses) - 1
    if uses <= 0 then
        return exports.ox_inventory:RemoveItem(source, Config.Items.spray, 1, nil, slot) == true
    end
    local metadata = itemData.metadata or {}
    metadata.uses = uses
    exports.ox_inventory:SetMetadata(source, slot, metadata)
    return true
end
