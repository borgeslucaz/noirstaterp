-- Inventário no client: só apresentação. Criar e tirar item é coisa do servidor.
BGRZ = BGRZ or {}

---Mostra o campo `key` do metadata no tooltip de todo item que tiver esse campo, com o
---rótulo `label` ("Grau: A"). Chamar de novo com o mesmo rótulo não duplica a linha.
---@param key string
---@param label string
---@return boolean ok
---@return string? errorCode
function BGRZ.DisplayItemMetadata(key, label)
    if type(key) ~= 'string' or key == '' or #key > 64 then return false, 'invalid_key' end
    if type(label) ~= 'string' or label == '' or #label > 64 then return false, 'invalid_label' end
    local provider = BGRZ.Provider.name('inventory')
    if not BGRZ.Provider.isAvailable('inventory') then return false, 'provider_unavailable' end

    local called = pcall(function()
        exports[provider]:displayMetadata(key, label)
    end)
    if not called then return false, 'provider_unavailable' end
    return true
end

exports('DisplayItemMetadata', BGRZ.DisplayItemMetadata)

---Guarda a arma que está na mão, pelo inventário: trocar direto pelo native deixa o provider
---achando que a arma continua equipada.
---@param noAnim? boolean sem a animação de guardar
---@return boolean ok
---@return string? errorCode
function BGRZ.HolsterWeapon(noAnim)
    if not BGRZ.Provider.isAvailable('inventory') then return false, 'provider_unavailable' end
    local provider = BGRZ.Provider.name('inventory')
    TriggerEvent(('%s:disarm'):format(provider), noAnim == true)
    return true
end

exports('HolsterWeapon', BGRZ.HolsterWeapon)

---Trava o inventário do jogador (abrir, usar item, hotbar), para quem está com as mãos
---ocupadas numa atividade. Quem trava destrava; o bridge não guarda dono da trava.
---@param busy boolean
---@return boolean ok
---@return string? errorCode
function BGRZ.SetInventoryBusy(busy)
    if type(busy) ~= 'boolean' then return false, 'invalid_state' end
    if not BGRZ.Provider.isAvailable('inventory') then return false, 'provider_unavailable' end
    LocalPlayer.state:set('invBusy', busy, false)
    return true
end

exports('SetInventoryBusy', BGRZ.SetInventoryBusy)

---@return boolean
function BGRZ.IsInventoryBusy()
    return LocalPlayer.state.invBusy == true
end

exports('IsInventoryBusy', BGRZ.IsInventoryBusy)
