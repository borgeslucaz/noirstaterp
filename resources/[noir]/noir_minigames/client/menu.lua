---Menu de teste (/minigames). O servidor confere a ACE e só então manda abrir; aqui é
---só apresentação: escolhe fornecedor, jogo e dificuldade, roda e mostra o resultado.

local Catalogue = require 'shared.catalogue'

local MENU = 'noir_minigames:menu'

local function providerMenuId(provider) return ('%s:%s'):format(MENU, provider) end

local function report(id, passed, detail, seconds)
    local def = Catalogue.byId[id]
    if detail == 'busy' then
        lib.notify({ type = 'error', description = locale('busy') })
    elseif detail == 'unavailable' then
        lib.notify({ type = 'error', description = locale('unavailable', def.label) })
    elseif detail == 'unknown' then
        lib.notify({ type = 'error', description = locale('unknown', id) })
    elseif type(detail) == 'table' and detail.looted then
        lib.notify({ type = 'inform', description = locale('result_looting', def.label, detail.looted, seconds) })
    else
        lib.notify({
            type = passed and 'success' or 'error',
            description = locale(passed and 'result_passed' or 'result_failed', def.label, seconds),
        })
    end
end

local function play(id, difficulty, back)
    -- onSelect vem de callback da NUI do ox_lib; a partida espera, então roda em thread.
    CreateThread(function()
        local started = GetGameTimer()
        local passed, detail = Play.run(id, difficulty)
        report(id, passed, detail, (GetGameTimer() - started) / 1000)
        -- Volta para a lista do fornecedor para testar o próximo sem digitar de novo.
        lib.showContext(back)
    end)
end

local function difficultyMenu(id, back)
    local def = Catalogue.byId[id]
    local menuId = ('%s:%s'):format(MENU, id)
    local options = {}
    for _, d in ipairs(Catalogue.difficulties) do
        options[#options + 1] = {
            title = d.label,
            icon = 'gauge',
            onSelect = function() play(id, d.value, back) end,
        }
    end
    lib.registerContext({ id = menuId, title = locale('menu_difficulty_title', def.label), menu = back, options = options })
    lib.showContext(menuId)
end

local function buildMenus()
    local byProvider, providerOrder = {}, {}
    for _, id in ipairs(Catalogue.order) do
        local provider = Catalogue.byId[id].provider
        if not byProvider[provider] then
            byProvider[provider] = {}
            providerOrder[#providerOrder + 1] = provider
        end
        local list = byProvider[provider]
        list[#list + 1] = id
    end

    local root = {}
    for _, provider in ipairs(providerOrder) do
        local info = Catalogue.providers[provider]
        local available = Play.available(provider)
        local menuId = providerMenuId(provider)

        local options = {}
        for _, id in ipairs(byProvider[provider]) do
            local def = Catalogue.byId[id]
            options[#options + 1] = {
                title = def.label,
                description = def.blurb,
                icon = 'gamepad',
                disabled = not available,
                onSelect = function()
                    if def.params or def.provider == 'noir' then
                        difficultyMenu(id, menuId)
                    else
                        play(id, 2, menuId)
                    end
                end,
            }
        end
        lib.registerContext({ id = menuId, title = info.label, menu = MENU, options = options })

        root[#root + 1] = {
            title = info.label,
            description = available and locale('menu_provider_desc', #byProvider[provider])
                or locale('menu_unavailable', info.resource),
            icon = available and 'puzzle-piece' or 'ban',
            menu = menuId,
            arrow = true,
        }
    end

    lib.registerContext({ id = MENU, title = locale('menu_title'), options = root })
end

RegisterNetEvent('noir_minigames:client:openMenu', function()
    if GetInvokingResource() then return end
    -- Remonta a cada abertura: o estado dos resources de fora pode ter mudado.
    buildMenus()
    lib.showContext(MENU)
end)
