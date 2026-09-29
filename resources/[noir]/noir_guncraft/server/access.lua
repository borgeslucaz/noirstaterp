-- Controle de acesso às bancadas.
--
-- O upstream aceitava o benchId que o cliente mandava sem conferir nada. Como o
-- id é um inteiro sequencial, um `for i = 1, 500 do TriggerServerEvent(...) end`
-- no console do cliente abria a storage de todo mundo, craftava com o material
-- alheio e cancelava a fila dos outros. Todo evento vindo do cliente passa aqui
-- antes de tocar em qualquer coisa.

Access = {}

local BENCHES, QUEUE = Database.BENCHES, Database.QUEUE

local function notify(src, message)
    TriggerClientEvent('noir_guncraft:showNotification', src, message, 'error')
end

---Valida que o valor é um id inteiro positivo, e não um float, string ou NaN.
---@param value any
---@return integer|nil
function Access.toId(value)
    if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 or value <= 0 then
        return nil
    end
    return value
end

---Normaliza a quantidade pedida num craft. O upstream fazia só
---`math.min(quantity or 1, 10)`, que deixa passar negativo e fracionário --- e
---quantidade negativa devolvia usos ao blueprint em vez de gastar.
---@param value any
---@return integer
function Access.toQuantity(value)
    local n = tonumber(value)
    if not n or n ~= n then return 1 end
    n = math.floor(n)
    if n < 1 then return 1 end
    return math.min(n, Config.Security.maxCraftQuantity)
end

---Carrega a bancada e confere que este jogador pode mexer nela agora.
---Roda dentro do coroutine do handler, então pode usar .await.
---@param src number
---@param benchId any
---@param opts? { owner?: boolean, silent?: boolean }
---@return table|nil bench Linha da bancada, ou nil se o acesso foi negado.
function Access.check(src, benchId, opts)
    opts = opts or {}

    local id = Access.toId(benchId)
    if not id then return nil end

    local Player = Systems.Framework.GetPlayer(src)
    if not Player then return nil end

    local bench = MySQL.single.await(
        ('SELECT id, owner, serial, x, y, z FROM %s WHERE id = ?'):format(BENCHES), { id })

    if not bench then
        if not opts.silent then notify(src, 'Bench not found') end
        return nil
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end

    local distance = #(GetEntityCoords(ped) - vec3(bench.x, bench.y, bench.z))
    if distance > Config.Security.maxDistance then
        if not opts.silent then notify(src, 'You are too far from the bench') end
        return nil
    end

    if (opts.owner or Config.Security.requireOwnerForStash)
        and bench.owner ~= Systems.Framework.GetCitizenId(Player) then
        if not opts.silent then notify(src, 'This bench is not yours') end
        return nil
    end

    return bench
end

---Mesma validação, partindo de uma linha da fila de craft.
---@param src number
---@param queueId any
---@param opts? { owner?: boolean, silent?: boolean }
---@return table|nil queue, table|nil bench
function Access.checkQueue(src, queueId, opts)
    local id = Access.toId(queueId)
    if not id then return nil end

    local row = MySQL.single.await(
        ('SELECT id, bench_id, item, quantity, finish_time FROM %s WHERE id = ?'):format(QUEUE), { id })
    if not row then
        notify(src, 'Item not found')
        return nil
    end

    local bench = Access.check(src, row.bench_id, opts)
    if not bench then return nil end

    return row, bench
end

---Registra as três stashes de uma bancada. Era chamado solto em 8 lugares
---diferentes com os números escritos na mão em cada um.
---@param serial string
function Access.ensureStashes(serial)
    local cfg = Config.Stashes
    Systems.Inventory.RegisterStash('bench_' .. serial .. '_materials',
        'Materials #' .. serial, cfg.materials.slots, cfg.materials.weight)
    Systems.Inventory.RegisterStash('bench_' .. serial .. '_blueprints',
        'Blueprints #' .. serial, cfg.blueprints.slots, cfg.blueprints.weight)
    Systems.Inventory.RegisterStash('bench_' .. serial .. '_storage',
        'Storage #' .. serial, cfg.storage.slots, cfg.storage.weight)
end

---@param serial string
---@param kind 'materials'|'blueprints'|'storage'
---@return string
function Access.stashName(serial, kind)
    return ('bench_%s_%s'):format(serial, kind)
end
