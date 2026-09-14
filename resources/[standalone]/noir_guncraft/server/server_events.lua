-- Framework compatibility
local frameworkType, Framework
if GetResourceState('qbx_core') == 'started' then
    frameworkType, Framework = 'qbox', exports.qbx_core
elseif GetResourceState('qb-core') == 'started' then
    frameworkType, Framework = 'qbcore', exports['qb-core']:GetCoreObject()
end

local BENCHES, QUEUE = Database.BENCHES, Database.QUEUE

-- Unified notification function
local function sendNotification(src, message, type)
    if frameworkType == 'qbox' then
        Framework:Notify(src, message, type)
    else
        TriggerClientEvent('QBCore:Notify', src, message, type)
    end
end

-- Load theme from JSON file
local function loadTheme()
    local file = LoadResourceFile(GetCurrentResourceName(), Config.ThemeFile)
    if file then
        local success, theme = pcall(json.decode, file)
        if success and theme then
            return theme
        end
    end
    return nil
end

local currentTheme = loadTheme()

local function playerName(src)
    return GetPlayerName(src) or ('src:' .. tostring(src))
end

---Reenvia a lista de bancadas. O cliente é quem decide o que vira objeto, por
---distância; aqui é só o snapshot.
local function broadcastBenches(target)
    MySQL.query(('SELECT id, x, y, z, heading, model FROM %s'):format(BENCHES), {}, function(result)
        TriggerClientEvent('crafting:loadBenches', target or -1, result or {})
    end)
end

-- Generate bench with serial
local function GenerateBenchSerial()
    return 'BENCH_' .. math.random(100000, 999999) .. '_' .. os.time()
end

-- Command to give bench item with serial
RegisterCommand('givebench', function(source, args)
    local src = source
    local Player = Systems.Framework.GetPlayer(src)
    if not Player then return end

    if not Systems.Framework.HasPermission(src, 'admin') then
        sendNotification(src, 'No permission', 'error')
        return
    end

    local benchSerial = GenerateBenchSerial()
    local success = Systems.Inventory.AddItem(src, Config.BenchItem, 1, { serial = benchSerial })

    if success then
        sendNotification(src, 'Bench given with serial: ' .. benchSerial, 'success')
    else
        sendNotification(src, 'Failed to give bench', 'error')
    end
end)

-- Item usage with framework compatibility
Systems.Framework.CreateUseableItem(Config.BenchItem, function(source, item)
    local src = source
    if not item then return end

    local benchSerial = item.info and item.info.serial or item.metadata and item.metadata.serial

    -- Generate serial if missing
    if not benchSerial then
        benchSerial = GenerateBenchSerial()
        exports.ox_inventory:SetMetadata(src, item.slot, { serial = benchSerial })
    end

    TriggerClientEvent('crafting:placeBench', src)
end)

-- Save bench to database
--
-- O upstream aceitava serial e slot do cliente e só tentava consumir o item
-- *depois* de inserir a bancada: um slot inexistente fazia o RemoveItem falhar
-- em silêncio e a bancada nascia de graça, com 3 stashes junto. Aqui o item é
-- localizado e consumido no servidor antes de qualquer INSERT.
RegisterNetEvent('crafting:saveBench', function(x, y, z, heading)
    local src = source
    local Player = Systems.Framework.GetPlayer(src)
    if not Player then return end

    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' or type(heading) ~= 'number'
        or x ~= x or y ~= y or z ~= z or heading ~= heading then
        sendNotification(src, 'Invalid placement data', 'error')
        return
    end

    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 1000 then
        sendNotification(src, 'Invalid placement parameters', 'error')
        return
    end

    -- A bancada tem que ser colocada onde o jogador está, não onde ele mandar.
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - vec3(x, y, z)) > 15.0 then
        sendNotification(src, 'Invalid placement position', 'error')
        return
    end

    -- Acha o item de verdade no inventário do jogador.
    local inventory = exports.ox_inventory:GetInventory(src)
    if not inventory or not inventory.items then return end

    local slot, benchSerial
    for itemSlot, item in pairs(inventory.items) do
        if item.name == Config.BenchItem then
            slot = itemSlot
            benchSerial = item.metadata and item.metadata.serial
            break
        end
    end

    if not slot then
        sendNotification(src, 'You do not have a crafting bench', 'error')
        return
    end

    if not benchSerial or type(benchSerial) ~= 'string' or #benchSerial > 50
        or not benchSerial:match('^[A-Za-z0-9_%-]+$') then
        benchSerial = GenerateBenchSerial()
    end

    -- Consome primeiro. Se o INSERT falhar, devolve.
    if not exports.ox_inventory:RemoveItem(src, Config.BenchItem, 1, nil, slot) then
        sendNotification(src, 'Failed to consume the bench item', 'error')
        return
    end

    MySQL.insert(('INSERT INTO %s (owner, x, y, z, heading, model, serial) VALUES (?, ?, ?, ?, ?, ?, ?)')
        :format(BENCHES), {
        Systems.Framework.GetCitizenId(Player), x, y, z, heading, Config.BenchModel, benchSerial
    }, function(insertId)
        if not insertId then
            exports.ox_inventory:AddItem(src, Config.BenchItem, 1, { serial = benchSerial })
            sendNotification(src, 'Failed to place bench', 'error')
            return
        end

        Access.ensureStashes(benchSerial)
        broadcastBenches()

        Discord.logBenchPlacement(playerName(src), src, benchSerial, { x = x, y = y, z = z })
    end)
end)

-- Load benches for client
local syncCooldowns = {}
RegisterNetEvent('crafting:requestBenches', function()
    local src = source
    local now = os.time()
    -- Net event livre que dispara um SELECT: sem isto, spam vira DoS no MySQL.
    if syncCooldowns[src] and (now - syncCooldowns[src]) < Config.Security.benchSyncCooldown then
        return
    end
    syncCooldowns[src] = now
    broadcastBenches(src)
end)

-- Open stash
RegisterNetEvent('crafting:openStash', function(benchId, stashType)
    local src = source

    if stashType ~= 'materials' and stashType ~= 'blueprints' and stashType ~= 'storage' then
        stashType = 'materials'
    end

    local bench = Access.check(src, benchId)
    if not bench then return end

    Access.ensureStashes(bench.serial)
    Systems.Inventory.OpenInventory(src, 'stash', Access.stashName(bench.serial, stashType))
end)

-- Get crafting data
RegisterNetEvent('crafting:getCraftingData', function(benchId)
    local src = source

    local bench = Access.check(src, benchId)
    if not bench then return end

    Access.ensureStashes(bench.serial)

    local materialsStash = Systems.Inventory.GetStashInventory(Access.stashName(bench.serial, 'materials'))
    local blueprintsStash = Systems.Inventory.GetStashInventory(Access.stashName(bench.serial, 'blueprints'))

    local playerBlueprints = {}
    local materials = {}

    if blueprintsStash and blueprintsStash.items then
        for _, item in pairs(blueprintsStash.items) do
            local blueprintConfig = Config.Blueprints[item.name]
            if blueprintConfig then
                local currentUses = item.metadata and item.metadata.uses or 0
                playerBlueprints[item.name] = {
                    unlocked = true,
                    uses = currentUses,
                    maxUses = blueprintConfig.maxUses,
                    remaining = blueprintConfig.maxUses - currentUses
                }
            end
        end
    end

    if materialsStash and materialsStash.items then
        for _, item in pairs(materialsStash.items) do
            materials[item.name] = (materials[item.name] or 0) + item.count
        end
    end

    local availableRecipes = {}
    for recipeName, recipe in pairs(Config.Recipes) do
        if playerBlueprints[recipe.blueprint] then
            availableRecipes[recipeName] = {
                label = recipe.label,
                materials = recipe.materials,
                time = recipe.time,
                blueprint = recipe.blueprint,
                prop = recipe.prop,
                massCraft = recipe.massCraft,
                blueprintUses = playerBlueprints[recipe.blueprint]
            }
        end
    end

    local rows = MySQL.query.await(
        ('SELECT id, item, finish_time, start_time, quantity FROM %s WHERE bench_id = ?'):format(QUEUE),
        { bench.id }) or {}

    local craftingQueue = {}
    local currentTime = os.time() * 1000

    for _, row in pairs(rows) do
        craftingQueue[tostring(row.id)] = {
            item = row.item,
            timeLeft = math.max(0, row.finish_time - currentTime),
            finishTime = row.finish_time,
            startTime = row.start_time,
            -- A coluna `completed` do upstream nunca era escrita, valia 0 para
            -- sempre. O estado real é só uma comparação de tempo.
            completed = currentTime >= row.finish_time,
            quantity = row.quantity or 1
        }
    end

    TriggerClientEvent('crafting:showCrafting', src, {
        recipes = availableRecipes,
        materials = materials,
        queue = craftingQueue,
        theme = currentTheme
    })
end)

-- Pickup bench
local pickupLocks = {}

RegisterNetEvent('crafting:pickupBench', function(benchId)
    local src = source

    local bench = Access.check(src, benchId, { owner = true })
    if not bench then return end

    if pickupLocks[bench.id] then return end
    pickupLocks[bench.id] = true

    local ok, err = pcall(function()
        local now = os.time() * 1000
        local queueItems = MySQL.query.await(
            ('SELECT id, item, finish_time, quantity FROM %s WHERE bench_id = ?'):format(QUEUE),
            { bench.id }) or {}

        for _, item in pairs(queueItems) do
            if now < item.finish_time then
                sendNotification(src, 'Cannot pickup bench while items are being crafted', 'error')
                error('active', 0)
            end
        end

        Access.ensureStashes(bench.serial)
        local storage = Access.stashName(bench.serial, 'storage')

        local moved = 0
        for _, item in pairs(queueItems) do
            if exports.ox_inventory:AddItem(storage, item.item, item.quantity or 1) then
                MySQL.execute.await(('DELETE FROM %s WHERE id = ?'):format(QUEUE), { item.id })
                moved = moved + 1
            end
        end

        if moved > 0 then
            sendNotification(src, moved .. ' completed items moved to storage', 'success')
        end

        MySQL.execute.await(('DELETE FROM %s WHERE bench_id = ?'):format(QUEUE), { bench.id })
        MySQL.execute.await(('DELETE FROM %s WHERE id = ?'):format(BENCHES), { bench.id })

        exports.ox_inventory:AddItem(src, Config.BenchItem, 1, { serial = bench.serial })
        broadcastBenches()
    end)

    pickupLocks[bench.id] = nil

    if not ok and err ~= 'active' then
        print(('[noir_guncraft] pickupBench falhou para a bancada %s: %s'):format(bench.id, err))
    end
end)

-- Admin command to refund bench
RegisterNetEvent('crafting:refundBench', function(benchSerial)
    local src = source
    local Player = Systems.Framework.GetPlayer(src)
    if not Player then return end

    if not Systems.Framework.HasPermission(src, 'admin') then
        sendNotification(src, 'No permission', 'error')
        return
    end

    if type(benchSerial) ~= 'string' or benchSerial == '' or #benchSerial > 50
        or not benchSerial:match('^[A-Za-z0-9_%-]+$') then
        sendNotification(src, 'Invalid serial number', 'error')
        return
    end

    -- Recusa serial de bancada que ainda está no chão: duas bancadas com o mesmo
    -- serial compartilhariam as três stashes.
    if MySQL.scalar.await(('SELECT id FROM %s WHERE serial = ?'):format(BENCHES), { benchSerial }) then
        sendNotification(src, 'That serial belongs to a bench that is still placed', 'error')
        return
    end

    if Systems.Inventory.AddItem(src, Config.BenchItem, 1, { serial = benchSerial }) then
        sendNotification(src, 'Bench refunded with serial: ' .. benchSerial, 'success')
    else
        sendNotification(src, 'Failed to refund bench', 'error')
    end
end)

-- Pickup completed item
local pickupCooldowns = {}
RegisterNetEvent('crafting:pickupItem', function(queueId)
    local src = source

    local now = os.time()
    if pickupCooldowns[src] and (now - pickupCooldowns[src]) < 1 then return end
    pickupCooldowns[src] = now

    local row, bench = Access.checkQueue(src, queueId)
    if not row then return end

    if (os.time() * 1000) < row.finish_time then
        TriggerClientEvent('noir_guncraft:showNotification', src, 'Item not ready yet', 'error')
        return
    end

    Access.ensureStashes(bench.serial)
    local storage = Access.stashName(bench.serial, 'storage')

    -- Apaga primeiro: se dois pedidos chegarem juntos, só um vê affectedRows > 0
    -- e só um entrega o item.
    if (MySQL.execute.await(('DELETE FROM %s WHERE id = ?'):format(QUEUE), { row.id }) or 0) < 1 then
        return
    end

    if exports.ox_inventory:AddItem(storage, row.item, row.quantity or 1) then
        TriggerClientEvent('noir_guncraft:showNotification', src, 'Item picked up and added to storage', 'success')
    else
        -- Storage cheia: recoloca a linha para o item não evaporar.
        MySQL.insert.await(
            ('INSERT INTO %s (id, bench_id, item, finish_time, start_time, quantity) VALUES (?, ?, ?, ?, ?, ?)')
            :format(QUEUE), { row.id, row.bench_id, row.item, row.finish_time, row.finish_time, row.quantity })
        TriggerClientEvent('noir_guncraft:showNotification', src, 'Bench storage is full', 'error')
    end

    TriggerClientEvent('crafting:refreshUI', src)
end)

-- Cancel crafting
RegisterNetEvent('crafting:cancelCraft', function(queueId)
    local src = source

    local row, bench = Access.checkQueue(src, queueId)
    if not row then return end

    -- O DELETE é o lock: quem não apagar nada não reembolsa nada. Sem isso, dois
    -- cancelamentos simultâneos do mesmo craft devolviam material duas vezes.
    if (MySQL.execute.await(('DELETE FROM %s WHERE id = ?'):format(QUEUE), { row.id }) or 0) < 1 then
        return
    end

    local recipe = Config.Recipes[row.item]
    if recipe then
        local craftQuantity = row.quantity or 1
        local materialsStash = Access.stashName(bench.serial, 'materials')
        local blueprintsStash = Access.stashName(bench.serial, 'blueprints')

        Access.ensureStashes(bench.serial)

        for material, amount in pairs(recipe.materials) do
            exports.ox_inventory:AddItem(materialsStash, material, amount * craftQuantity)
        end

        -- Devolve usos ao blueprint que ainda existe. O upstream, quando não
        -- achava o blueprint na stash, *criava um novo do nada* --- gastar o
        -- último uso e cancelar o craft gerava blueprint infinito.
        local blueprintConfig = Config.Blueprints[recipe.blueprint]
        local stash = exports.ox_inventory:GetInventory(blueprintsStash)

        if blueprintConfig and stash and stash.items then
            for slot, item in pairs(stash.items) do
                if item.name == recipe.blueprint then
                    local currentUses = item.metadata and item.metadata.uses or 0
                    local newUses = math.max(0, currentUses - craftQuantity)
                    local metadata = item.metadata or {}
                    metadata.uses = newUses
                    metadata.description = ('Uses: %d/%d'):format(newUses, blueprintConfig.maxUses)
                    metadata.durability = math.floor(((blueprintConfig.maxUses - newUses) / blueprintConfig.maxUses) * 100)
                    exports.ox_inventory:SetMetadata(blueprintsStash, slot, metadata)
                    break
                end
            end
        end
    end

    TriggerClientEvent('noir_guncraft:showNotification', src, 'Crafting cancelled, materials refunded', 'success')
    TriggerClientEvent('crafting:refreshUI', src)
end)

-- Craft antigo e não coletado.
--
-- O upstream fazia `DELETE FROM crafting_queue WHERE finish_time < agora - 2h`
-- e pronto: quem não coletasse a tempo perdia o item e o material junto. Aqui a
-- linha só sai depois que o item entra na storage da bancada.
CreateThread(function()
    while true do
        Wait(600000) -- 10 min

        local cutoff = (os.time() - Config.AutoCollectAfter) * 1000
        local rows = MySQL.query.await(([[
            SELECT q.id, q.item, q.quantity, b.serial
            FROM %s q JOIN %s b ON q.bench_id = b.id
            WHERE q.finish_time < ?
        ]]):format(QUEUE, BENCHES), { cutoff }) or {}

        for _, row in pairs(rows) do
            Access.ensureStashes(row.serial)
            if exports.ox_inventory:AddItem(Access.stashName(row.serial, 'storage'), row.item, row.quantity or 1) then
                MySQL.execute.await(('DELETE FROM %s WHERE id = ?'):format(QUEUE), { row.id })
            end
            -- Storage cheia: fica na fila e tenta de novo no próximo ciclo.
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    syncCooldowns[src] = nil
    pickupCooldowns[src] = nil
end)

-- Bancadas já no banco quando o recurso sobe: registra as stashes para que
-- abrir uma não dependa de alguém ter passado por um evento antes.
CreateThread(function()
    MySQL.ready(function()
        local rows = MySQL.query.await(('SELECT serial FROM %s'):format(BENCHES)) or {}
        for _, row in pairs(rows) do
            Access.ensureStashes(row.serial)
        end
        if Config.Debug then
            print(('[noir_guncraft] %d bancadas carregadas'):format(#rows))
        end
    end)
end)
