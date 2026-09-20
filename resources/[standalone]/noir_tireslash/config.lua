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

-- Tempo que o personagem tem para girar de frente para a roda antes do corte
-- começar (ms). O giro acontece antes da progress, nunca junto.
Config.turnDuration = 750

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

-- Fumaça saindo do pneu depois do corte. É enfeite: se o asset não existir neste
-- build, o pneu fura do mesmo jeito e só o efeito fica de fora. O nome do efeito
-- não tem native que valide, então um nome errado simplesmente não aparece.
-- Alternativas: 'ent_amb_smoke_foundry' (mais densa), 'exp_grd_bzgas_smoke'.
-- Defina Config.ptfx = false para desligar.
Config.ptfx = {
    asset = 'core',
    effect = 'ent_sht_steam',
    scale = 0.7,
    duration = 3000,
    rotation = vec3(0.0, 0.0, 0.0),

    -- Cada offset é um emissor próprio em volta do osso da roda. É assim que se
    -- engrossa a nuvem: o jogo não deixa pedir "mais partículas" de um efeito, então
    -- mais partículas no ar = mais emissores. Cada um custa, não exagere na lista.
    emitters = {
        vec3(0.0, 0.0, 0.0),
        vec3(0.0, 0.12, -0.06),
        vec3(0.0, -0.12, 0.06),
        vec3(0.06, 0.0, 0.10),
        vec3(-0.06, 0.06, -0.02),
    },
}

-- Liga o comando /tiresound (cliente) para caçar o nome do áudio em jogo, e faz o
-- servidor avisar no console cada vez que manda tocar. Desligue depois de achar.
Config.debug = true

-- Som do pneu furando, tocado a partir do veículo para todo mundo por perto
-- (via mana_audio). Defina Config.sound = false para desligar.
-- ATENÇÃO: nome/ref errado não dá erro nenhum, só não sai som.
-- Outros candidatos de pneu confirmados no dump do gta_sound_tester:
--   audioName = 'CAR_STEAL_3_AGENT_TYRE_BURST',  audioRef = 'CAR_STEAL_3_AGENT'
--   audioName = 'TAKINGS_TIRES_PEELAWAY_master', audioRef = '0'
Config.sound = {
    audioName = 'tyre_burst',
    audioRef = 'DLC_sum20_Open_Wheel_Racing_Sounds',
    audioBank = nil,
}
