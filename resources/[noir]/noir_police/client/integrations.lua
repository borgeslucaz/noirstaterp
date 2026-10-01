---Único arquivo do cliente que conhece outro resource pelo nome.
---
---Jogador, job, metadata e notificação passam pelo `bgrz_core`. O `ox_target` é
---chamado direto (§2.5 do SCRIPT_GOOD_PRACTICES), com as options no namespace
---`noir_police:*`. O `ox_inventory` do cliente (abrir inventário próximo, contar item,
---arma atual) e o `illenium-appearance` (recarregar a roupa salva) também moram aqui.

local CORE = 'bgrz_core'

local Integrations = {}

local function started(resource)
    return GetResourceState(resource) == 'started'
end

-- Jogador --------------------------------------------------------------------------

---@return table? job { name, label, type, grade, onDuty }
function Integrations.getJob()
    if not started(CORE) then return nil end
    local ok, job = pcall(function() return exports[CORE]:GetJob() end)
    return ok and job or nil
end

---@param key string
function Integrations.getMetadata(key)
    if not started(CORE) then return nil end
    local ok, value = pcall(function() return exports[CORE]:GetMetadata(key) end)
    return ok and value or nil
end

---@return boolean
function Integrations.isLoggedIn()
    if not started(CORE) then return false end
    local ok, value = pcall(function() return exports[CORE]:IsLoggedIn() end)
    return ok and value == true
end

---@param message string
---@param kind? 'inform'|'success'|'warning'|'error'
function Integrations.notify(message, kind)
    if started(CORE) then
        exports[CORE]:Notify(message, kind or 'inform')
    else
        lib.notify({ description = message, type = kind or 'inform' })
    end
end

-- ox_target ------------------------------------------------------------------------

function Integrations.addGlobalPlayer(options) exports.ox_target:addGlobalPlayer(options) end
function Integrations.addGlobalVehicle(options) exports.ox_target:addGlobalVehicle(options) end
function Integrations.addModel(models, options) exports.ox_target:addModel(models, options) end
function Integrations.addEntity(netIds, options) exports.ox_target:addEntity(netIds, options) end
function Integrations.removeEntity(netIds, names) exports.ox_target:removeEntity(netIds, names) end
-- ND_GunAnims (mira de uma mão do escudo) ------------------------------------------

---@param name 'default'|'gang'|'hillbilly'
function Integrations.setAimAnim(name)
    if GetResourceState('ND_GunAnims') ~= 'started' then return end
    pcall(function() exports.ND_GunAnims:setAimAnim(name) end)
end

---@return string
function Integrations.getAimAnim()
    if GetResourceState('ND_GunAnims') ~= 'started' then return 'default' end
    local ok, name = pcall(function() return exports.ND_GunAnims:getAimAnim() end)
    return ok and name or 'default'
end

function Integrations.addSphereZone(data) return exports.ox_target:addSphereZone(data) end
function Integrations.removeZone(id) exports.ox_target:removeZone(id) end
function Integrations.disableTargeting(state) exports.ox_target:disableTargeting(state) end

-- ox_inventory ---------------------------------------------------------------------

---@param item string
---@return integer
function Integrations.itemCount(item)
    local ok, count = pcall(function() return exports.ox_inventory:Search('count', item) end)
    return ok and tonumber(count) or 0
end

function Integrations.openNearbyInventory()
    exports.ox_inventory:openNearbyInventory()
end

---@param invType string
---@param data any
function Integrations.openInventory(invType, data)
    exports.ox_inventory:openInventory(invType, data)
end

---@return table? weapon { name, metadata }
function Integrations.currentWeapon()
    local ok, weapon = pcall(function() return exports.ox_inventory:getCurrentWeapon() end)
    return ok and weapon or nil
end

---Passa o uso do item pelo ox_inventory (consome, fecha a tela) e chama `cb`.
function Integrations.useItem(data, cb)
    exports.ox_inventory:useItem(data, cb)
end

-- Teclas visíveis (noir_lib, DESIGN_v4 §7) ------------------------------------------

---@param keys { key: string, label: string }[]
function Integrations.showKeys(keys)
    if not started('noir_lib') then return end
    pcall(function() exports.noir_lib:ShowKeyHints({ position = 'baixo', keys = keys }) end)
end

function Integrations.hideKeys()
    if not started('noir_lib') then return end
    pcall(function() exports.noir_lib:HideKeyHints() end)
end

-- Porta-malas (qbx_radialmenu) --------------------------------------------------------

-- Prisão (xt-prison) ----------------------------------------------------------------

---Manda para a prisão pelo contrato do xt-prison, que confere polícia e distância.
---@param target integer
---@param months integer
function Integrations.jail(target, months)
    TriggerServerEvent('police:server:JailPlayer', target, months)
end

-- Aparência ------------------------------------------------------------------------

---Volta para a roupa salva do personagem (sair do uniforme).
function Integrations.reloadSavedAppearance()
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end

return Integrations
