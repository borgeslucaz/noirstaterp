---Único ponto do client que conhece outro resource pelo nome.
---
---O alvo fala com o `ox_target` direto (§2.5).

local TARGET = 'ox_target'

local Integrations = {}

---Alvo pelo `ox_target` direto (§2.5). As options já vêm com o namespace do resource.
---@param data { name: string, coords: vector3, size: vector3, rotation: number, debug: boolean, options: table[] }
---@return integer? zoneId
function Integrations.addZone(data)
    if GetResourceState(TARGET) ~= 'started' then return nil end
    local ok, id = pcall(function()
        return exports[TARGET]:addBoxZone({
            name = data.name,
            coords = data.coords,
            size = data.size,
            rotation = data.rotation,
            debug = data.debug,
            options = data.options,
        })
    end)
    return ok and id or nil
end

---@param id integer?
function Integrations.removeZone(id)
    if not id or GetResourceState(TARGET) ~= 'started' then return end
    pcall(function() exports[TARGET]:removeZone(id) end)
end

return Integrations
