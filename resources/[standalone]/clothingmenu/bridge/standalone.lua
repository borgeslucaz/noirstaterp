-- Standalone Adapter (No Framework)

function Bridge.IsPlayerDead(src)
    if not src or src == 0 then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    return IsEntityDead(ped) or GetEntityHealth(ped) <= 100
end

function Bridge.IsPlayerHandcuffed(src)
    if not src or src == 0 then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    return IsPedCuffed(ped)
end

function Bridge.GetPlayerName(src)
    if not src or src == 0 then return nil end

    return GetPlayerName(src)
end
