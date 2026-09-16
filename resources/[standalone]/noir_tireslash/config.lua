Config = {}

-- Distance the target option stays visible from (meters).
Config.targetDistance = 1.5

-- How long the slashing animation/progress takes (ms).
Config.slashDuration = 3000

-- true  = tyre is shredded down to the rim
-- false = tyre just goes flat (more realistic for a knife)
Config.burstOnRim = false

-- Respect bulletproof tyres (vehicles with tyre burst disabled cannot be slashed).
Config.respectBulletproofTyres = true

-- Server-side anti-spam: minimum delay between two slash requests from the same player (ms).
Config.cooldown = 1500

-- Server-side sanity check: max distance between the player and the vehicle for a
-- slash request to be accepted (meters). Do not set this too low, the vehicle
-- origin is its center, not the wheel.
Config.maxDistance = 8.0

-- Weapons allowed to slash a tyre, as a hash lookup.
Config.allowedWeapons = {
    [`WEAPON_KNIFE`] = true,
    [`WEAPON_BOTTLE`] = true,
    [`WEAPON_DAGGER`] = true,
    [`WEAPON_HATCHET`] = true,
    [`WEAPON_MACHETE`] = true,
    [`WEAPON_SWITCHBLADE`] = true,
    [`WEAPON_BATTLEAXE`] = true,
    [`WEAPON_STONE_HATCHET`] = true,
}

-- Wheel bone -> tyre index used by the tyre natives. Shared so the server can
-- validate whatever index a client sends.
Config.wheelBones = {
    ['wheel_lf'] = 0,
    ['wheel_rf'] = 1,
    ['wheel_lm1'] = 2,
    ['wheel_rm1'] = 3,
    ['wheel_lm2'] = 45,
    ['wheel_rm2'] = 47,
    ['wheel_lm3'] = 46,
    ['wheel_rm3'] = 48,
    ['wheel_lr'] = 4,
    ['wheel_rr'] = 5,
}

Config.validTyreIndex = {}

for _, index in pairs(Config.wheelBones) do
    Config.validTyreIndex[index] = true
end

-- Animation played during the slash. Kept from the original resource; swap for
-- 'melee@knife@streamed_core' if you prefer the third person variant.
Config.anim = {
    dict = 'melee@knife@streamed_core_fps',
    clip = 'ground_attack_on_spot',
    flag = 1,
}
