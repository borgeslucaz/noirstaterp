-- ---------------------------------------------------------------------------
--  Status module - health / armor / hunger / thirst
-- ---------------------------------------------------------------------------
--  * health and armor read every Config.Tick.status ms from the player ped.
--  * hunger and thirst either come from the active framework or decay
--    internally over time as described in the spec.
--  * On respawn, hunger and thirst reset to Config.Status.respawn* per spec.
-- ---------------------------------------------------------------------------

local lastSnapshot = { health = -1, armor = -1, hunger = -1, thirst = -1 }
local internalHunger, internalThirst = 100.0, 100.0

local function activeSource()
    local src = Config.Status.source or 'auto'
    if src == 'auto' then
        if Bridge.framework == 'esx' or Bridge.framework == 'qb' or Bridge.framework == 'qbox' then
            return 'framework'
        end
        return 'internal'
    end
    return src
end

-- ---------- ESX status integration ---------------------------------------
--
-- ESX status pushes ticks roughly every 5 seconds with a percent value 0-100k.
-- We listen and store the latest values.
local esxHunger, esxThirst = nil, nil

AddEventHandler('esx_status:onTick', function(data)
    if not data then return end
    for _, status in ipairs(data) do
        if status.name == 'hunger' then
            esxHunger = math.floor((status.val or 0) / 10000)
        elseif status.name == 'thirst' then
            esxThirst = math.floor((status.val or 0) / 10000)
        end
    end
end)

-- ---------- Helpers ------------------------------------------------------

local function getHungerThirst()
    local source = activeSource()

    if source == 'framework' then
        if Bridge.framework == 'esx' then
            return esxHunger or 100, esxThirst or 100
        elseif Bridge.framework == 'qb' or Bridge.framework == 'qbox' then
            local s = Bridge.getFrameworkStatus()
            if s then
                return s.hunger or 100, s.thirst or 100
            end
        end
        -- Framework was selected but no data yet: fall back to internal.
    end

    return math.floor(internalHunger + 0.5), math.floor(internalThirst + 0.5)
end

-- ---------- Internal decay loop ------------------------------------------
--
-- Drains internalHunger / internalThirst by an amount per second that
-- corresponds to Config.Status.decayMinutes*. Uses a fixed 1s tick which
-- is cheap and stable.

CreateThread(function()
    local lastTime = GetGameTimer()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        local dt = (now - lastTime) / 1000.0
        lastTime = now

        local mh = math.max(0.1, Config.Status.decayMinutesHunger or 50)
        local mt = math.max(0.1, Config.Status.decayMinutesThirst or 45)

        internalHunger = math.max(0.0, internalHunger - (100.0 / (mh * 60.0)) * dt)
        internalThirst = math.max(0.0, internalThirst - (100.0 / (mt * 60.0)) * dt)
    end
end)

-- ---------- Respawn handler ----------------------------------------------

local function handleRespawn()
    internalHunger = Config.Status.respawnHunger or 100.0
    internalThirst = Config.Status.respawnThirst or 100.0
end

-- esx_ambulancejob / qb-ambulancejob revive events
AddEventHandler('esx_ambulancejob:revive', handleRespawn)
AddEventHandler('hospital:client:Revive', handleRespawn)
RegisterNetEvent('lcp_hud_v4:revive', handleRespawn)

-- Detect respawn via native loop (fallback for standalone).
CreateThread(function()
    local wasDead = false
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local dead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
        if wasDead and not dead then
            handleRespawn()
        end
        wasDead = dead
    end
end)

-- ---------- Main poll loop -----------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.Tick.status or 250)
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            local health = math.max(0, GetEntityHealth(ped) - 100) -- 100 = min health in GTA
            local maxHp  = math.max(1, GetEntityMaxHealth(ped) - 100)
            health = math.floor((health / maxHp) * 100 + 0.5)
            if IsEntityDead(ped) then
                health = lastSnapshot.health >= 0 and lastSnapshot.health or 0
            end

            local armor = math.floor(GetPedArmour(ped) + 0.5)
            local hunger, thirst = getHungerThirst()

            if health ~= lastSnapshot.health
                or armor  ~= lastSnapshot.armor
                or hunger ~= lastSnapshot.hunger
                or thirst ~= lastSnapshot.thirst then

                lastSnapshot.health = health
                lastSnapshot.armor  = armor
                lastSnapshot.hunger = hunger
                lastSnapshot.thirst = thirst

                HUD.state.health = health
                HUD.state.armor  = armor
                HUD.state.hunger = hunger
                HUD.state.thirst = thirst

                SendNUIMessage({
                    type   = 'status',
                    health = health,
                    armor  = armor,
                    hunger = hunger,
                    thirst = thirst,
                })
            end
        end
    end
end)
