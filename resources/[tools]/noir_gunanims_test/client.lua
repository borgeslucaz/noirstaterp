---Menu de teste do ND_GunAnims: troca a mira, toca cada animação de sacar/guardar e
---alterna o coldre da roupa. Lê a configuração do próprio ND_GunAnims, então o que
---aparece aqui é o que está valendo no servidor.

local ANIMATIONS = lib.load('@ND_GunAnims.data.animations')
local HOLSTERS = lib.load('@ND_GunAnims.data.holster')

local AIMS = {
    { id = 'default', label = 'Padrão (duas mãos)' },
    { id = 'gang', label = 'Gang (uma mão)' },
    { id = 'hillbilly', label = 'Hillbilly' },
}

local function notify(text, kind) lib.notify({ title = 'Animações de arma', description = text, type = kind or 'inform' }) end

local function weaponLabel()
    local hasWeapon, weapon = GetCurrentPedWeapon(cache.ped, true)
    if not hasWeapon or weapon == `WEAPON_UNARMED` then return 'nenhuma (desarmado)' end
    return ('%s (grupo %s)'):format(weapon, GetWeapontypeGroup(weapon))
end

---Toca uma animação do mesmo jeito que o ND_GunAnims (client/animations.lua).
local function play(info)
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    if not pcall(lib.requestAnimDict, info.dict, 3000) then return notify(('Animação não carregou: %s'):format(info.dict), 'error') end
    TaskPlayAnimAdvanced(ped, info.dict, info.clip, coords.x, coords.y, coords.z, 0, 0, GetEntityHeading(ped),
        8.0, 3.0, info.duration * 2, 50, 0.1)
    RemoveAnimDict(info.dict)
    Wait(info.duration)
    if info.cancel then StopAnimTask(ped, info.dict, info.clip, 2.0) end
end

local function playVariant(variant)
    if variant.dict then return play(variant) end
    for _, info in ipairs(variant) do play(info) end
end

local function openMenu()
    local current = exports.ND_GunAnims:getAimAnim()
    local options = {
        { title = 'Arma na mão', description = weaponLabel(), icon = 'fa-solid fa-gun', disabled = true },
    }

    for _, aim in ipairs(AIMS) do
        options[#options + 1] = {
            title = ('Mira: %s'):format(aim.label),
            description = aim.id == current and 'Em uso' or 'Segure o botão direito para ver',
            icon = aim.id == current and 'fa-solid fa-circle-check' or 'fa-regular fa-circle',
            onSelect = function()
                exports.ND_GunAnims:setAimAnim(aim.id)
                notify(('Mira: %s'):format(aim.label), 'success')
                openMenu()
            end,
        }
    end

    local names = {}
    for name in pairs(ANIMATIONS.animations or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local set = ANIMATIONS.animations[name]
        for _, variant in ipairs({ 'unholster', 'holster' }) do
            local info = set[variant]
            if info then
                options[#options + 1] = {
                    title = ('%s: %s'):format(variant == 'unholster' and 'Sacar' or 'Guardar', name),
                    description = info.dict and ('%s / %s (%d ms)'):format(info.dict, info.clip, info.duration) or 'sequência',
                    icon = variant == 'unholster' and 'fa-solid fa-hand' or 'fa-solid fa-hand-back-fist',
                    onSelect = function()
                        playVariant(info)
                        openMenu()
                    end,
                }
            end
        end
    end

    options[#options + 1] = {
        title = 'Alternar coldre da roupa',
        description = ('Componente 7 atual: %d. Usa os pares de data/holster.lua'):format(GetPedDrawableVariation(cache.ped, 7)),
        icon = 'fa-solid fa-shirt',
        onSelect = function()
            local male = GetEntityModel(cache.ped) == `mp_m_freemode_01`
            local now = GetPedDrawableVariation(cache.ped, 7)
            for _, holster in ipairs(HOLSTERS or {}) do
                local pair = male and holster.male or holster.female
                if pair then
                    local nextDrawable = now == pair[1] and pair[2] or now == pair[2] and pair[1] or nil
                    if nextDrawable then
                        SetPedComponentVariation(cache.ped, holster.variation, nextDrawable, 0, 0)
                        notify(('Coldre: %d → %d'):format(now, nextDrawable), 'success')
                        return openMenu()
                    end
                end
            end
            local first = HOLSTERS and HOLSTERS[1] and (male and HOLSTERS[1].male or HOLSTERS[1].female)
            if first then
                SetPedComponentVariation(cache.ped, 7, first[1], 0, 0)
                notify(('Sem coldre conhecido; vestido o %d'):format(first[1]), 'inform')
            else
                notify('Nenhum coldre configurado (os do ND são de um pacote EUP que o servidor não tem)', 'error')
            end
            openMenu()
        end,
    }

    lib.registerContext({ id = 'noir_gunanims_test', title = 'Animações de arma (ND_GunAnims)', options = options })
    lib.showContext('noir_gunanims_test')
end

RegisterNetEvent('noir_gunanims_test:open', function()
    if GetResourceState('ND_GunAnims') ~= 'started' then return notify('ND_GunAnims não está rodando', 'error') end
    openMenu()
end)
