---Layout no cliente: lê do GlobalState o que o servidor publicou e avisa os módulos
---quando o editor salva (`noir_police:client:layoutChanged`, com o tipo).

local Codec = require 'shared.layout'

local Layout = {}

local cache = {}

local function read(kind)
    if cache[kind] == nil then
        local data = GlobalState[('noirPolice:%s'):format(kind)]
        cache[kind] = type(data) == 'table' and Codec.decode[kind](data) or {}
    end
    return cache[kind]
end

function Layout.stations() return read('stations') end
function Layout.radars() return read('radars') end
function Layout.cameras() return read('cameras') end

for _, kind in ipairs({ 'stations', 'radars', 'cameras' }) do
    AddStateBagChangeHandler(('noirPolice:%s'):format(kind), 'global', function()
        -- O handler só agenda: quem reage cria e apaga zonas e blips.
        SetTimeout(0, function()
            cache[kind] = nil
            TriggerEvent('noir_police:client:layoutChanged', kind)
        end)
    end)
end

return Layout
