-- Crafting-specific logic

local QUEUE = Database.QUEUE

local function notify(src, message, kind)
    TriggerClientEvent('noir_guncraft:showNotification', src, message, kind)
end

-- Start crafting
RegisterNetEvent('crafting:startCraft', function(benchId, itemName, quantity)
    local src = source

    if type(itemName) ~= 'string' then return end

    local recipe = Config.Recipes[itemName]
    if not recipe then
        notify(src, 'Recipe not found', 'error')
        return
    end

    -- Sem isto, quantity negativa passava na checagem de material e depois
    -- *devolvia* usos ao blueprint em vez de gastar; string quebrava math.min.
    quantity = Access.toQuantity(quantity)

    local bench = Access.check(src, benchId)
    if not bench then return end

    Access.ensureStashes(bench.serial)

    local materialsStashName = Access.stashName(bench.serial, 'materials')
    local blueprintsStashName = Access.stashName(bench.serial, 'blueprints')
    local materialsStash = exports.ox_inventory:GetInventory(materialsStashName)
    local blueprintsStash = exports.ox_inventory:GetInventory(blueprintsStashName)

    if not materialsStash or not materialsStash.items then
        notify(src, 'No materials available', 'error')
        return
    end

    -- Check materials for quantity
    for material, needed in pairs(recipe.materials) do
        local available = 0
        for _, item in pairs(materialsStash.items) do
            if item.name == material then
                available = available + item.count
            end
        end
        if available < (needed * quantity) then
            notify(src, ('Not enough %s for %dx crafting'):format(material, quantity), 'error')
            return
        end
    end

    -- Check blueprint usage for quantity
    local blueprintName = recipe.blueprint
    local blueprintConfig = Config.Blueprints[blueprintName]
    if not blueprintConfig then
        notify(src, 'Recipe has no blueprint configured', 'error')
        return
    end

    local blueprintSlot, blueprintItem
    if blueprintsStash and blueprintsStash.items then
        for slot, item in pairs(blueprintsStash.items) do
            if item.name == blueprintName then
                local currentUses = item.metadata and item.metadata.uses or 0
                if (blueprintConfig.maxUses - currentUses) >= quantity then
                    blueprintSlot, blueprintItem = slot, item
                    break
                end
            end
        end
    end

    if not blueprintSlot then
        notify(src, ('Blueprint not found or not enough uses left for %dx crafting'):format(quantity), 'error')
        return
    end

    -- Remove materials for quantity
    for material, needed in pairs(recipe.materials) do
        Systems.Inventory.RemoveItem(materialsStashName, material, needed * quantity)
    end

    -- Consume blueprint uses for quantity
    local currentUses = blueprintItem.metadata and blueprintItem.metadata.uses or 0
    local newUses = currentUses + quantity

    if newUses >= blueprintConfig.maxUses then
        exports.ox_inventory:RemoveItem(blueprintsStashName, blueprintName, 1, blueprintItem.metadata, blueprintSlot)
    else
        local metadata = blueprintItem.metadata or {}
        metadata.uses = newUses
        metadata.description = ('Uses: %d/%d'):format(newUses, blueprintConfig.maxUses)
        metadata.durability = math.floor(((blueprintConfig.maxUses - newUses) / blueprintConfig.maxUses) * 100)
        exports.ox_inventory:SetMetadata(blueprintsStashName, blueprintSlot, metadata)
    end

    local now = os.time() * 1000
    local maxFinish = MySQL.scalar.await(
        ('SELECT MAX(finish_time) FROM %s WHERE bench_id = ?'):format(QUEUE), { bench.id })

    -- math.max com o agora é o que impede craft instantâneo: MAX(finish_time)
    -- inclui itens já prontos e não coletados, então uma fila parada no passado
    -- fazia todo craft novo nascer com finish_time vencido.
    local lastFinishTime = math.max(tonumber(maxFinish) or 0, now)

    if recipe.massCraft then
        MySQL.insert.await(
            ('INSERT INTO %s (bench_id, item, finish_time, quantity, start_time) VALUES (?, ?, ?, ?, ?)'):format(QUEUE),
            { bench.id, itemName, now + (recipe.time * quantity), quantity, now })
    else
        for i = 1, quantity do
            MySQL.insert.await(
                ('INSERT INTO %s (bench_id, item, finish_time, quantity, start_time) VALUES (?, ?, ?, ?, ?)'):format(QUEUE),
                { bench.id, itemName, lastFinishTime + (recipe.time * i), 1, lastFinishTime + (recipe.time * (i - 1)) })
        end
    end

    notify(src, ('Started crafting %dx %s'):format(quantity, recipe.label or itemName), 'success')
    TriggerClientEvent('crafting:refreshUI', src)

    local spent = {}
    for material, needed in pairs(recipe.materials) do
        spent[material] = needed * quantity
    end
    Discord.logCrafting(GetPlayerName(src) or tostring(src), src, itemName,
        recipe.label or itemName, quantity, bench.id, spent, recipe.time)
end)
