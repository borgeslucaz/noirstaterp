-- Estúdio de fotos dos carros da central (/taxifotos). Ferramenta de admin: o client monta a
-- cena (carro no alto, parede verde, câmera de lado) e avisa; o servidor captura a tela pelo
-- `screencapture` e grava o PNG cru em `dev/fotos/<model>.png`. O recorte do verde e o PNG
-- transparente em `html/img/vehicles/` saem do `dev/fotos.sh` (ffmpeg).
local STUDIO = ServerConfig.Studio

local sessions = {} ---@type table<number, { queue: table[], taken: table<string, true> }>

local function isAdmin(src)
    return src > 0 and IsPlayerAceAllowed(src, STUDIO.AdminAce)
end

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local B64_INDEX = {}
for i = 1, #B64 do B64_INDEX[B64:sub(i, i)] = i - 1 end

---Base64 → bytes (a captura chega como data URI).
---@param text string
---@return string
local function decodeBase64(text)
    text = text:gsub('[^%w%+/=]', '')
    local out, buffer, bits = {}, 0, 0
    for i = 1, #text do
        local char = text:sub(i, i)
        if char == '=' then break end
        buffer = (buffer << 6) | B64_INDEX[char]
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            out[#out + 1] = string.char((buffer >> bits) & 0xFF)
        end
    end
    return table.concat(out)
end

lib.addCommand(STUDIO.Command, {
    help = 'Fotografa os carros da central de táxi (admin)',
    params = { { name = 'modo', type = 'string', help = 'teste = só o primeiro carro; <model> = todas as liveries desse carro', optional = true } },
}, function(src, args)
    if not isAdmin(src) then return end
    if GetResourceState('screencapture') ~= 'started' then
        exports.bgrz_core:Notify(src, 'O screencapture não está rodando.', 'error')
        return
    end
    local queue = {}
    for _, v in ipairs(Config.RentalVehicles) do
        if v.enabled ~= false then queue[#queue + 1] = { id = v.id, model = v.model, appearance = v.appearance } end
    end
    if args.modo == 'teste' then
        queue = { queue[1] }
    elseif args.modo then
        local found
        for _, shot in ipairs(queue) do
            if shot.model == args.modo then found = shot end
        end
        if not found then
            exports.bgrz_core:Notify(src, ('Nenhum carro da central com o model %s.'):format(args.modo), 'error')
            return
        end
        queue = { { id = found.id, model = found.model, appearance = found.appearance, liveries = true } }
    end
    sessions[src] = { queue = queue, taken = {} }
    TriggerClientEvent('noir_taxijob:client:studio', src, queue, STUDIO.Scene)
end)

---O client montou a cena de um carro: captura, grava e libera o próximo.
RegisterNetEvent('noir_taxijob:server:studioShot', function(index, variant)
    local src = source
    local session = sessions[src]
    index = math.tointeger(tonumber(index))
    local shot = session and index and session.queue[index]
    if not isAdmin(src) or not shot then return end
    -- Variante só no modo de liveries, e só nome simples (vira parte do arquivo).
    if variant ~= nil and (not shot.liveries or type(variant) ~= 'string' or not variant:match('^[%w_]+$') or #variant > 16) then return end
    local name = variant and ('%s_%s'):format(shot.model, variant) or shot.model
    if session.taken[name] then return end
    session.taken[name] = true

    -- O screencapture devolve o quadro guardado da captura anterior (medido: cada foto saía com o
    -- carro de antes). A primeira captura só atualiza esse quadro; vale a segunda.
    local options = { encoding = 'png', maxWidth = STUDIO.Width, maxHeight = STUDIO.Height }
    exports.screencapture:serverCapture(src, options, function()
        SetTimeout(300, function()
            exports.screencapture:serverCapture(src, options, function(data)
                local ok = false
                if type(data) == 'string' then
                    local bytes = decodeBase64(data:gsub('^data:[^,]*,', ''))
                    ok = #bytes > 0 and SaveResourceFile(GetCurrentResourceName(), ('dev/fotos/%s.png'):format(name), bytes, #bytes)
                end
                print(('[noir_taxijob] estúdio: %s %s'):format(name, ok and 'salvo em dev/fotos' or 'FALHOU'))
                -- nil no meio dos argumentos some com os seguintes na rede: variante vazia vai como false.
                TriggerClientEvent('noir_taxijob:client:studioSaved', src, index, variant or false, ok and true or false)
            end)
        end)
    end)
end)

---Diagnóstico do modo de liveries: cores, mods e extras do carro, no log.
RegisterNetEvent('noir_taxijob:server:studioInfo', function(index, info)
    local src = source
    local session = sessions[src]
    local shot = session and session.queue[math.tointeger(tonumber(index)) or 0]
    if not isAdmin(src) or not shot or type(info) ~= 'table' then return end
    print(('[noir_taxijob] estúdio %s: %s | liveries %s | mods %s | extras %s'):format(shot.model,
        tostring(info.colours):sub(1, 200), tostring(info.liveries), tostring(info.mods):sub(1, 300), tostring(info.extras):sub(1, 200)))
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)
