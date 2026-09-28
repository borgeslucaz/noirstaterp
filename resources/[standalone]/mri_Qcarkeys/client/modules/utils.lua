local Utils = {}
local VehicleKeys = require 'client.interface'

function Utils:IsBlacklistedWeapon()
    if VehicleKeys.currentWeapon then
        for _, v in pairs(Shared.BlackListedWeapon) do
            if VehicleKeys.currentWeapon == joaat(v) then
                return true
            end
        end
    end
    return false
end

function Utils:GetPedsInVehicle(vehicle)
    if not vehicle then return end
    local otherPeds = {}
    for seat=-1,GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        if not IsPedAPlayer(pedInSeat) and pedInSeat ~= 0 then
            otherPeds[#otherPeds+1] = pedInSeat
        end
    end
    return otherPeds
end

---Nivel da habilidade (Shared.skills.name) no noir_skills; sem o resource, nivel 1 (chance base).
---O XP nao passa por aqui: o noir_skills so aceita ganho no servidor.
---@return number
function Utils:GetSkillLevel()
    if GetResourceState('noir_skills') ~= 'started' then return 1 end
    return exports.noir_skills:GetLevel(Shared.skills.name) or 1
end

-- Marca local de ligacao direta: cobre o intervalo ate o state bag do servidor chegar, nos dois
-- sentidos (true logo apos ligar, false logo apos desligar). Expira para nao mascarar o estado real.
local hotwiredLocal = {}

---Carro rodando sem chave (ligacao direta, lockpick, tomado de NPC)?
---@param vehicle number
---@return boolean
function Utils:IsHotwired(vehicle)
    if not vehicle or vehicle == 0 then return false end
    local localValue = hotwiredLocal[vehicle]
    if localValue ~= nil then return localValue end
    return Entity(vehicle).state.hotwired == true
end

---@param vehicle number
---@param value boolean
function Utils:SetHotwired(vehicle, value)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if self:IsHotwired(vehicle) == value then return end
    hotwiredLocal[vehicle] = value
    SetTimeout(2000, function()
        if hotwiredLocal[vehicle] == value then hotwiredLocal[vehicle] = nil end
    end)
    TriggerServerEvent('mri_Qcarkeys:server:setHotwired', NetworkGetNetworkIdFromEntity(vehicle), value)
end

function Utils:RemoveSpecialCharacter(txt)
    if not txt then return 'undefined' end
    return (txt:gsub("%W", "")):upper()
end

return Utils