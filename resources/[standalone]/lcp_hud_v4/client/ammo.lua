-- ---------------------------------------------------------------------------
--  Ammo module
-- ---------------------------------------------------------------------------
--  Shows current / max ammo while the player holds a weapon. Hides when
--  the player is unarmed. Polls every Config.Tick.ammo ms; nothing happens
--  in the NUI unless a value actually changed.
-- ---------------------------------------------------------------------------

local UNARMED = GetHashKey('WEAPON_UNARMED')

-- Human-readable label per weapon. We keep this small + use the weapon
-- hash as fallback display. NUI renders an SVG icon based on weapon class.
local function weaponLabel(hash)
    local name = nil
    -- GetWeapontypeModel / GetWeaponHumanNameFromHash exist in newer FiveM builds.
    local ok, label = pcall(function() return GetLabelText(GetWeapontypeModel(hash) or '') end)
    if ok and label and label ~= 'NULL' and label ~= '' then
        name = label
    end
    return name or string.format('0x%X', hash & 0xFFFFFFFF)
end

local last = { weapon = 0, current = -1, max = -1, visible = nil }

CreateThread(function()
    while true do
        Wait(Config.Tick.ammo or 150)
        if not Config.Ammo.enabled then
            if last.visible ~= false then
                last.visible = false
                SendNUIMessage({ type = 'ammo', visible = false })
            end
        else
            local ped = PlayerPedId()
            local hasWeapon, weapon = GetCurrentPedWeapon(ped, true)
            local show = hasWeapon and weapon and weapon ~= UNARMED and weapon ~= 0

            if not show then
                if last.visible ~= false then
                    last.visible = false
                    last.weapon  = 0
                    HUD.state.weapon = false
                    SendNUIMessage({ type = 'ammo', visible = false })
                end
            else
                -- GetAmmoInClip returns (bool, int) on some natives wrappers
                -- and (int) on others. Handle both safely.
                local clip
                local r1, r2 = GetAmmoInClip(ped, weapon)
                if type(r1) == 'number' then
                    clip = r1
                elseif type(r2) == 'number' then
                    clip = r2
                else
                    clip = 0
                end

                local total = GetAmmoInPedWeapon(ped, weapon) or 0
                local reserve = math.max(0, total - clip)

                if weapon ~= last.weapon or clip ~= last.current or reserve ~= last.max or last.visible ~= true then
                    last.weapon  = weapon
                    last.current = clip
                    last.max     = reserve
                    last.visible = true
                    HUD.state.weapon = true
                    HUD.state.ammo = { current = clip, max = reserve, weapon = weaponLabel(weapon) }
                    SendNUIMessage({
                        type    = 'ammo',
                        visible = true,
                        weapon  = weaponLabel(weapon),
                        weaponHash = weapon,
                        current = clip,
                        max     = reserve,
                    })
                end
            end
        end
    end
end)
