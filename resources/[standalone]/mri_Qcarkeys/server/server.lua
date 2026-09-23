local Bridge = require 'server.bridge'

local VehicleList = {}
local getItemInfo = Shared.Inventory == 'qb' and function(item) return item.info end or function(item) return item.metadata end

local function RemoveSpecialCharacter(txt)
    return (txt:gsub("%W", "")):upper()
end

-- Distancia maxima entre jogador e veiculo para eventos de cliente que concedem chave ou mexem na
-- tranca. Mesmo valor do qbx_vehiclekeys (distanceToVehicle).
local MAX_KEY_DISTANCE = 7.5
local ALLOWED_LOCKPICKS = { lockpick = true, advancedlockpick = true }

---@param plate string placa ja normalizada
---@return number[]
local function GetVehiclesByPlate(plate)
    local found = {}
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if RemoveSpecialCharacter(GetVehicleNumberPlateText(vehicles[i])) == plate then
            found[#found + 1] = vehicles[i]
        end
    end
    return found
end

---@param src number
---@param vehicle number
---@return boolean
local function IsNear(src, vehicle, maxDistance)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(vehicle) then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) <= maxDistance
end

---O jogador e o dono do veiculo persistente (vehicleid posto pelo qbx_garages/qbx_vehicles)?
---@param src number
---@param vehicle number
---@return boolean
local function IsOwner(src, vehicle)
    local vehicleId = Entity(vehicle).state.vehicleid
    if not vehicleId or GetResourceState('qbx_vehicles') ~= 'started' then return false end
    local ok, row = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vehicleId) end)
    return ok and row ~= nil and row.citizenid ~= nil and row.citizenid == Bridge:GetPlayerCitizenId(src)
end

---Evento vindo do cliente so concede chave se existe um veiculo com a placa e o jogador esta junto
---dele, ou e o dono (a garagem pode soltar o carro a mais de 7.5m do guiche).
---@param src number
---@param plate string
---@return boolean
local function CanClaimKey(src, plate)
    if type(plate) ~= 'string' or plate == '' then return false end
    local vehicles = GetVehiclesByPlate(RemoveSpecialCharacter(plate))
    for i = 1, #vehicles do
        if IsNear(src, vehicles[i], MAX_KEY_DISTANCE) or IsOwner(src, vehicles[i]) then
            return true
        end
    end
    print(('[mri_Qcarkeys] chave negada: src %s placa %s (%d veiculo(s) com a placa)'):format(src, plate, #vehicles))
    return false
end

---@param src number
---@param plate string placa ja normalizada
---@return boolean
local function HasKeyItem(src, plate)
    for _, v in pairs(Bridge:GetPlayerItemsByName(src, 'vehiclekey') or {}) do
        local info = getItemInfo(v)
        if info and info.plate and RemoveSpecialCharacter(info.plate) == plate then return true end
    end
    for _, bag in pairs(Bridge:GetPlayerItemsByName(src, 'keybag') or {}) do
        local info = getItemInfo(bag)
        for _, v in pairs(info and info.plates or {}) do
            if v.plate and RemoveSpecialCharacter(v.plate) == plate then return true end
        end
    end
    return false
end

---@param src number
---@param plate string placa ja normalizada
---@return boolean
local function HasTempKey(src, plate)
    local list = VehicleList[Bridge:GetPlayerCitizenId(src)]
    return list ~= nil and lib.table.contains(list, plate)
end

function GiveTempKeys(id, plate)
    local citizenid = Bridge:GetPlayerCitizenId(id)
    if not VehicleList[citizenid] then VehicleList[citizenid] = {} end
    plate = RemoveSpecialCharacter(plate)
    if Shared.keepKeysInVehicle and not HasKeyItem(id, plate) then
        local info = {}
		info.label = "CHAVE-"..plate
        info.plate = plate
		Bridge:AddItem(id, 'vehiclekey', info)
    end

    if not lib.table.contains(VehicleList[citizenid], plate) then
        table.insert(VehicleList[citizenid], plate)
    end
    local ndata = {
        title = 'Recebido',
        description = 'Você recebeu a chave temporária para o veículo',
        type = 'success'
    }
    TriggerClientEvent('ox_lib:notify', id, ndata)
    TriggerClientEvent('mm_carkeys:client:addtempkeys', id, plate)
end

function RemoveTempKeys(id, plate)
    local citizenid = Bridge:GetPlayerCitizenId(id)
    plate = RemoveSpecialCharacter(plate)
    local list = VehicleList[citizenid]
    if list then
        for i = #list, 1, -1 do
            if list[i] == plate then table.remove(list, i) end
        end
    end
    TriggerClientEvent('mm_carkeys:client:removetempkeys', id, plate)
end

exports('GiveTempKeys', function(src, plate)
    if not plate then
        local nData = {
            title = 'Falha',
            description = 'Nenhuma placa de veículo encontrada',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, nData)
        return
    end
    GiveTempKeys(src, plate)
end)

exports('RemoveTempKeys', function(src, plate)
    if not plate then
        local nData = {
            title = 'Falha',
            description = 'Nenhuma placa de veículo encontrada',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, nData)
        return
    end
    RemoveTempKeys(src, plate)
end)

exports('GiveKeyItem', function(src, plate, netId)
    if not plate or not netId then
        local nData = {
            title = 'Falha',
            description = 'Nenhum dado de veículo encontrado',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, nData)
        return
    end
    TriggerClientEvent('mm_carkeys:client:setplayerkey', src, plate, netId)
end)

exports('RemoveKeyItem', function(src, plate)
    if not plate then
        local nData = {
            title = 'Falha',
            description = 'Nenhum dado de veículo encontrado',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, nData)
        return
    end
    TriggerClientEvent('mm_carkeys:client:removeplayerkey', src, plate)
end)

exports('HaveTemporaryKey', function(src, plate)
    if not plate then
        return 
    end
    return lib.callback.await('mm_carkeys:client:havekey', src, 'temp', plate)
end)

exports('HavePermanentKey', function(src, plate)
    if not plate then
        return
    end
    return lib.callback.await('mm_carkeys:client:havekey', src, 'perma', plate)
end)

lib.callback.register('mm_carkeys:server:getvehiclekeys', function(source)
    local citizenid = Bridge:GetPlayerCitizenId(source)
    return VehicleList[citizenid] or {}
end)

---source vazio = TriggerEvent de outro resource no servidor (ex.: qbx_garages ao soltar o carro).
local function SetLockStateFromEvent(src, vehNetId, state)
    if type(vehNetId) ~= 'number' or type(state) ~= 'number' then return end
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if src and src > 0 and not IsNear(src, vehicle, 10.0) then return end
    SetVehicleDoorsLocked(vehicle, state == 2 and 2 or 1)
end

RegisterNetEvent('mm_carkeys:server:setVehLockState', function(vehNetId, state)
    SetLockStateFromEvent(tonumber(source), vehNetId, state)
end)

RegisterNetEvent('qb-vehiclekeys:server:setVehLockState', function(vehNetId, state)
    SetLockStateFromEvent(tonumber(source), vehNetId, state)
end)

RegisterNetEvent('mm_carkeys:server:acquiretempvehiclekeys', function(plate)
    local src = source
    if not CanClaimKey(src, plate) then return end
    GiveTempKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:removetempvehiclekeys', function(plate)
    local src = source
    if type(plate) ~= 'string' then return end
    RemoveTempKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:removelockpick', function(item)
    if not ALLOWED_LOCKPICKS[item] then return end
    Bridge:RemoveItem(source, item)
end)

RegisterNetEvent('mm_carkeys:server:acquirevehiclekeys', function(plate)
    local src = source
    if not CanClaimKey(src, plate) then return end
    plate = RemoveSpecialCharacter(plate)
    if HasKeyItem(src, plate) then return end
	local Player = Bridge:GetPlayer(src)
    if Player then

        local info = {}
		info.label = "CHAVE-" ..plate ---@old: model.. '-' ..plate
        info.plate = plate
		Bridge:AddItem(src, 'vehiclekey', info)
	end
end)

-- @compat qb: scripts pedem "a chave" deste carro; aqui vira chave temporaria, igual ao SetOwner.
RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    if not CanClaimKey(src, plate) then return end
    GiveTempKeys(src, plate)
end)

RegisterNetEvent('qb-vehiclekeys:server:removeKeys', function(plate)
    if type(plate) ~= 'string' then return end
    RemoveTempKeys(source, plate)
end)

RegisterNetEvent('mm_carkeys:server:removevehiclekeys', function(plate)
    local src = source
    if type(plate) ~= 'string' then return end
    plate = RemoveSpecialCharacter(plate)
    local keys = Bridge:GetPlayerItemsByName(src, 'vehiclekey')
    for _, v in pairs(keys) do
        local info = getItemInfo(v)
        if info.plate and RemoveSpecialCharacter(info.plate) == plate then
            Bridge:RemoveItem(src, 'vehiclekey', v.slot)
            break
        end
    end
end)

RegisterNetEvent('mm_carkeys:server:stackkeys', function()
    local src = source
    local bagFound = Bridge:GetPlayerItemByName(src, 'keybag')
    local keys = Bridge:GetPlayerItemsByName(src, 'vehiclekey')
    local plates = {}
    local platestxt = ''
    for _, v in pairs(keys) do
        local info = getItemInfo(v)
        if info.plate then
            plates[#plates+1] = {
                plate = info.plate,
                label = info.label
            }
            platestxt = platestxt..info.plate..', '
            Bridge:RemoveItem(src, 'vehiclekey', v.slot)
        end
    end
    if bagFound then
        local info = getItemInfo(bagFound)
        local getplates = info.plates
        for _, v in pairs(getplates) do
            plates[#plates+1] = {
                plate = v.plate,
                label = v.label
            }
            platestxt = platestxt..v.plate..', '
        end
        Bridge:RemoveItem(src, 'keybag', bagFound.slot)
    end
    Bridge:AddItem(src, 'keybag', {plates = plates, platestxt = platestxt})
end)

RegisterNetEvent('mm_carkeys:server:unstackkeys', function()
    local src = source
    local bag = Bridge:GetPlayerItemByName(src, 'keybag')
    if not bag then
        local ndata = {
            description = 'Você não tem uma bolsa de chave',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, ndata)
        return
    end
    Bridge:RemoveItem(src, 'keybag', bag.slot)
    local itemInfo = getItemInfo(bag)
    for _, v in pairs(itemInfo.plates) do
        local info = {}
		info.label = v.label
        info.plate = v.plate
        Bridge:AddItem(src, 'vehiclekey', info)
    end
end)

HasKeyItemForPlate = HasKeyItem
HasTempKeyForPlate = HasTempKey
NormalizePlate = RemoveSpecialCharacter

-- lib.versionCheck('SOH69/mm_carkeys')