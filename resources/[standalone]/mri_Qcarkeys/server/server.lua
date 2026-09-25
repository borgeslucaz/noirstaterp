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
-- Populacao "random" do GTA (trafego, estacionados, cenario): carro de NPC, nao criado por script.
local AMBIENT_POPULATION = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }

---@param vehicle number
---@return boolean
local function IsAmbient(vehicle)
    return AMBIENT_POPULATION[GetEntityPopulationType(vehicle)] == true
end

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

-- Fechadura: cada placa de carro de jogador tem uma geracao. A chave (item) guarda a geracao em que
-- foi feita e so abre se for a atual. Trocar a fechadura (garagem) ou trocar o dono do carro sobe a
-- geracao e invalida todas as chaves antigas. Placa sem linha = geracao 0 (as chaves de antes valem).
local Locks = {} ---@type table<string, { generation: integer, owner: string? }>

---@param plate string placa ja normalizada
---@return integer
local function CurrentGeneration(plate)
    local lock = Locks[plate]
    return lock and lock.generation or 0
end

-- Os clientes so recebem as placas com geracao > 0; o resto e 0 por padrao.
local function PublishGenerations()
    local map = {}
    for plate, lock in pairs(Locks) do
        if lock.generation > 0 then map[plate] = lock.generation end
    end
    GlobalState.mriKeyGen = map
end

local function SaveLock(plate)
    local lock = Locks[plate]
    MySQL.prepare.await('INSERT INTO `mri_vehicle_locks` (`plate`, `generation`, `owner`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `generation` = VALUES(`generation`), `owner` = VALUES(`owner`)', {
        plate, lock.generation, lock.owner
    })
end

---@param plate string placa ja normalizada
---@param owner string? citizenid do dono depois da troca
local function BumpGeneration(plate, owner)
    local lock = Locks[plate] or { generation = 0 }
    lock.generation = lock.generation + 1
    lock.owner = owner
    Locks[plate] = lock
    SaveLock(plate)
    PublishGenerations()
end

---Registra o dono da placa; se ele mudou (venda por qualquer caminho), troca a fechadura.
---@param plate string placa ja normalizada
---@param owner string citizenid atual no player_vehicles
---@return boolean ownerChanged
local function SyncOwner(plate, owner)
    local lock = Locks[plate]
    if lock and lock.owner == owner then return false end
    if not lock or not lock.owner then
        Locks[plate] = { generation = lock and lock.generation or 0, owner = owner }
        SaveLock(plate)
        return false
    end
    BumpGeneration(plate, owner)
    return true
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mri_vehicle_locks` (
            `plate` VARCHAR(16) NOT NULL,
            `generation` INT UNSIGNED NOT NULL DEFAULT 0,
            `owner` VARCHAR(50) NULL,
            PRIMARY KEY (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    for _, row in ipairs(MySQL.query.await('SELECT `plate`, `generation`, `owner` FROM `mri_vehicle_locks`') or {}) do
        Locks[row.plate] = { generation = row.generation, owner = row.owner }
    end
    PublishGenerations()
end)

---@param info table metadata de vehiclekey ou entrada do keybag
---@param plate string placa ja normalizada
---@return boolean
local function KeyOpens(info, plate)
    return info ~= nil and info.plate ~= nil and RemoveSpecialCharacter(info.plate) == plate
        and (tonumber(info.gen) or 0) == CurrentGeneration(plate)
end

---@param src number
---@param plate string placa ja normalizada
---@return boolean
local function HasKeyItem(src, plate)
    for _, v in pairs(Bridge:GetPlayerItemsByName(src, 'vehiclekey') or {}) do
        if KeyOpens(getItemInfo(v), plate) then return true end
    end
    for _, bag in pairs(Bridge:GetPlayerItemsByName(src, 'keybag') or {}) do
        local info = getItemInfo(bag)
        for _, v in pairs(info and info.plates or {}) do
            if KeyOpens(v, plate) then return true end
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
---@param copy? boolean copia paga: entrega mesmo que o jogador ja tenha uma chave desta placa
---@return boolean
local function GivePermanentKey(src, plate, copy)
    if not copy and HasKeyItem(src, plate) then return true end
    local metadata = { label = 'CHAVE-' .. plate, plate = plate, gen = CurrentGeneration(plate) }
    return exports.ox_inventory:AddItem(src, 'vehiclekey', 1, metadata) == true
end

---@param src number
---@param vehicle number
---@return boolean
local function HasKeyForVehicle(src, vehicle)
    local plate = RemoveSpecialCharacter(GetVehicleNumberPlateText(vehicle))
    return HasTempKey(src, plate) or HasKeyItem(src, plate)
end

---Unica porta de entrada de chave pedida por evento/export de compatibilidade:
--- - carro de jogador: nada. Ele so abre com o item de chave, que vem na compra
---   (export GivePermanentKey), do admin (/givekeys) ou da garagem (copia paga). Excecao: se o
---   dono mudou desde a ultima vez (venda), a fechadura e trocada e o dono novo recebe a chave;
--- - carro criado por script sem dono (missao/emprego/admin): chave temporaria. Carro de NPC
---   (populacao ambiente) nunca: so ligacao direta.
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

    local vehicleId, owner = GetPlayerVehicleOwner(rawPlate)
    if vehicleId then
        if owner and SyncOwner(normalized, owner) and owner == Bridge:GetPlayerCitizenId(src) then
            GivePermanentKey(src, normalized)
            return true
        end
        return false
    end

    if not trusted then
        local allowed, seen = false, {}
        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            seen[#seen + 1] = GetEntityPopulationType(vehicle)
            if IsNear(src, vehicle, MAX_KEY_DISTANCE) and not IsAmbient(vehicle) then allowed = true break end
        end
        if not allowed then
            print(('[mri_Qcarkeys] chave negada: src %s placa %s (populacao %s)'):format(src, normalized, table.concat(seen, ',')))
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
---Jogador precisa estar perto e ter a chave. Sem chave, so trancar carro de NPC (assalto que falhou,
---LockNPCVehicle). Destrancar sem chave e pelo lockpick (evento proprio) ou pelo assalto (setHotwired).
local function SetLockStateFromEvent(src, vehNetId, state)
    if type(vehNetId) ~= 'number' or type(state) ~= 'number' then return end
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local lock = state == 2
    if src and src > 0 then
        if not IsNear(src, vehicle, 10.0) then return end
        if not HasKeyForVehicle(src, vehicle) and not (lock and IsAmbient(vehicle)) then return end
    end
    SetVehicleDoorsLocked(vehicle, lock and 2 or 1)
end

-- Carro estacionado do mundo (populacao 2, "random parked") ja nasce trancado: abre so com lockpick.
-- Carro de script (dono, missao, admin) e populacao 7 e nao entra aqui.
if Shared.LockParkedVehicles then
    AddEventHandler('entityCreated', function(entity)
        if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
        if GetEntityPopulationType(entity) ~= 2 then return end
        SetVehicleDoorsLocked(entity, 2)
    end)
end

---Lockpick de porta bem-sucedido. O cliente manda antes de consumir o lockpick, entao o item ainda
---esta no inventario aqui.
RegisterNetEvent('mri_Qcarkeys:server:lockpickUnlock', function(netId, isAdvanced)
    local src = source
    if type(netId) ~= 'number' then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not IsNear(src, vehicle, MAX_KEY_DISTANCE) then return end
    local item = isAdvanced and 'advancedlockpick' or 'lockpick'
    if (exports.ox_inventory:Search(src, 'count', item) or 0) < 1 then return end
    SetVehicleDoorsLocked(vehicle, 1)
end)

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
---Marcar: so quem esta no banco do motorista (ligacao direta, lockpick na ignicao) ou em carro de NPC
---(assalto, chave de NPC) -- e so este ultimo destranca. Desmarcar: basta estar perto.
RegisterNetEvent('mri_Qcarkeys:server:setHotwired', function(netId, value)
    local src = source
    if type(netId) ~= 'number' then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if not IsNear(src, vehicle, MAX_KEY_DISTANCE) then return end
    if value == true then
        local ambient = IsAmbient(vehicle)
        if not ambient and GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(src) then return end
        if ambient then SetVehicleDoorsLocked(vehicle, 1) end
    end
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

---Chave definitiva (item). Para a loja na compra e para a copia paga na garagem (`copy = true`).
---@param src number
---@param plate string
---@param copy? boolean
---@return boolean entregue
exports('GivePermanentKey', function(src, plate, copy)
    if type(src) ~= 'number' or type(plate) ~= 'string' or plate == '' then return false end
    return GivePermanentKey(src, RemoveSpecialCharacter(plate), copy == true)
end)

---Troca a fechadura (garagem): invalida todas as chaves da placa e entrega uma nova ao jogador.
---Confere espaco antes, para nao deixar o dono sem chave nenhuma.
---@param src number
---@param plate string
---@return boolean
exports('ChangeLock', function(src, plate)
    if type(src) ~= 'number' or type(plate) ~= 'string' or plate == '' then return false end
    if not exports.ox_inventory:CanCarryItem(src, 'vehiclekey', 1) then return false end
    local normalized = RemoveSpecialCharacter(plate)
    BumpGeneration(normalized, Bridge:GetPlayerCitizenId(src))
    return GivePermanentKey(src, normalized, true)
end)

---Troca de dono pela API do qbx_vehicles (transferencia do admin, scripts): fechadura nova e, se o
---dono novo esta online, a chave vai para ele. A venda do qbx_vehiclesales mexe no SQL direto e e
---pega pelo SyncOwner no primeiro pedido de chave do comprador.
local function OnOwnerChanged(payload)
    local ok, row = pcall(function() return exports.qbx_vehicles:GetPlayerVehicle(payload.vehicleId) end)
    local plate = ok and row and row.props and row.props.plate
    if not plate then return end
    plate = RemoveSpecialCharacter(plate)
    BumpGeneration(plate, payload.newCitizenId)
    local player = payload.newCitizenId and exports.qbx_core:GetPlayerByCitizenId(payload.newCitizenId)
    if player then GivePermanentKey(player.PlayerData.source, plate) end
end

local function RegisterOwnerHook()
    if GetResourceState('qbx_vehicles') ~= 'started' then return end
    exports.qbx_vehicles:registerHook('changeVehicleOwner', function(payload)
        CreateThread(function() OnOwnerChanged(payload) end)
        return true
    end)
end

AddEventHandler('onServerResourceStart', function(resource)
    if resource == 'qbx_vehicles' then RegisterOwnerHook() end
end)
CreateThread(RegisterOwnerHook)

HasKeyItemForPlate = HasKeyItem
GivePermanentKeyForPlate = GivePermanentKey
GrantVehicleKeyTrusted = function(src, plate) return GrantVehicleKey(src, plate, true) end
HasTempKeyForPlate = HasTempKey
NormalizePlate = RemoveSpecialCharacter

-- lib.versionCheck('SOH69/mm_carkeys')