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

---Carro de jogador (linha no player_vehicles)? Devolve o id e o citizenid do dono (nil para frota).
---@param rawPlate string placa como o jogo/banco guarda
---@return integer? vehicleId, string? ownerCitizenId
local function GetPlayerVehicleOwner(rawPlate)
    if GetResourceState('qbx_vehicles') ~= 'started' then return end
    local ok, vehicleId = pcall(function() return exports.qbx_vehicles:GetVehicleIdByPlate(rawPlate) end)
    if not ok or not vehicleId then return end
    local ok2, row = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(vehicleId) end)
    return vehicleId, ok2 and row and row.citizenid or nil
end

---@param src number
---@param plate string placa ja normalizada
local function GivePermanentKey(src, plate)
    if HasKeyItem(src, plate) then return end
    Bridge:AddItem(src, 'vehiclekey', { label = 'CHAVE-' .. plate, plate = plate })
end

---Unica porta de entrada de chave pedida por evento/export de compatibilidade:
--- - carro de jogador: nada. Ele so abre com o item de chave, que vem na compra
---   (export GivePermanentKey) ou do admin (/givekeys) -- tirar da garagem nao da chave;
--- - carro sem dono (missao/emprego/admin): chave temporaria.
---`trusted` = chamada de outro resource no servidor; pedido do cliente exige estar junto do carro.
---@param src number
---@param plate string
---@param trusted boolean
---@return boolean
local function GrantVehicleKey(src, plate, trusted)
    if type(plate) ~= 'string' or plate == '' then return false end
    local normalized = RemoveSpecialCharacter(plate)
    local vehicles = GetVehiclesByPlate(normalized)
    local rawPlate = vehicles[1] and GetVehicleNumberPlateText(vehicles[1]) or plate

    if GetPlayerVehicleOwner(rawPlate) then
        return false
    end

    if not trusted then
        local near = false
        for i = 1, #vehicles do
            if IsNear(src, vehicles[i], MAX_KEY_DISTANCE) then near = true break end
        end
        if not near then
            print(('[mri_Qcarkeys] chave negada: src %s longe da placa %s (%d veiculo(s))'):format(src, normalized, #vehicles))
            return false
        end
    end
    GiveTempKeys(src, normalized)
    return true
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
    GrantVehicleKey(source, plate, false)
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
    GrantVehicleKey(source, plate, false)
end)

-- @compat qb: scripts pedem "a chave" deste carro; aqui vira chave temporaria, igual ao SetOwner.
RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    GrantVehicleKey(source, plate, false)
end)

---Ligacao direta, lockpick na ignicao, assalto e chave tirada de NPC nao dao chave: o carro fica
---marcado enquanto o motor roda. Quem dirige o cliente limpa a marca quando o motor para.
RegisterNetEvent('mri_Qcarkeys:server:setHotwired', function(netId, value)
    local src = source
    if type(netId) ~= 'number' then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if not IsNear(src, vehicle, MAX_KEY_DISTANCE) then return end
    Entity(vehicle).state:set('hotwired', value == true, true)
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

---Chave definitiva (item) para quem compra o carro. Para lojas/concessionarias no servidor.
---@param src number
---@param plate string
---@return boolean
exports('GivePermanentKey', function(src, plate)
    if type(src) ~= 'number' or type(plate) ~= 'string' or plate == '' then return false end
    GivePermanentKey(src, RemoveSpecialCharacter(plate))
    return true
end)

HasKeyItemForPlate = HasKeyItem
GivePermanentKeyForPlate = GivePermanentKey
GrantVehicleKeyTrusted = function(src, plate) return GrantVehicleKey(src, plate, true) end
HasTempKeyForPlate = HasTempKey
NormalizePlate = RemoveSpecialCharacter

-- lib.versionCheck('SOH69/mm_carkeys')