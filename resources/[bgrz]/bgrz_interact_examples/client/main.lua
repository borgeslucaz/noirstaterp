local resourceName = GetCurrentResourceName()
local spawnedNPCs = {}
local relationships = {}
local testBlip
local npcStates = {}

local function notify(message, kind)
    lib.notify({ title = 'Teste envi-interact', description = message, type = kind or 'inform' })
end

local function restoreNPC(menuID)
    local state = npcStates[menuID]
    if not state or not DoesEntityExist(state.ped) or not state.scenario then return end
    SetTimeout(1100, function()
        if DoesEntityExist(state.ped) then
            TaskStartScenarioInPlace(state.ped, state.scenario, 0, true)
        end
    end)
end

local function close(data)
    exports['envi-interact']:CloseMenu(data.menuID)
    restoreNPC(data.menuID)
end
local function leaveOption() return { key = 'X', label = 'Encerrar conversa', reaction = 'GENERIC_BYE', selected = close } end
local function updateSpeech(data, text)
    exports['envi-interact']:UpdateSpeech(data.menuID, text)
end

local function say(data, text)
    local finalMenuID = data.menuID .. '-finish'
    npcStates[finalMenuID] = npcStates[data.menuID]
    updateSpeech(data, text)
    exports['envi-interact']:OpenChoiceMenu({
        title = 'Fim da conversa',
        speech = text,
        menuID = finalMenuID,
        position = 'right',
        options = {
            {
                key = 'E',
                label = 'Finalizar conversa',
                selected = function()
                    exports['envi-interact']:CloseEverything()
                    restoreNPC(finalMenuID)
                end
            }
        },
        onESC = function()
            exports['envi-interact']:CloseEverything()
            restoreNPC(finalMenuID)
        end
    })
end

local function guideOptions()
    return {
        { key = 'E', label = 'Como interagir?', reaction = 'GENERIC_YES', selected = function(data) say(data, 'Olhe para um NPC, aproxime-se e pressione E. Use a roda do mouse quando houver mais opcoes.') end },
        { key = 'G', label = 'Quais exemplos existem?', selected = function(data) say(data, 'Ha dialogos, menus aninhados, slider, barra percentual, reacoes, camera e atualizacao de fala.') end },
        leaveOption()
    }
end

local function simpleOptions()
    return {
        { key = 'E', label = 'Cumprimentar', reaction = 'GENERIC_THANKS', selected = function(data) notify('A recepcionista retribuiu o cumprimento.', 'success'); say(data, 'O cumprimento foi concluido. Pressione o botao abaixo para encerrar.') end },
        { key = 'G', label = 'Fazer uma pergunta', reaction = 'CHAT_STATE', selected = function(data) say(data, 'A area reune varios estilos de conversa. Experimente todos!') end },
        leaveOption()
    }
end

local function progressOptions(npc)
    return {
        { key = 'E', label = 'Executar diagnostico', reaction = 'GENERIC_YES', stayOpen = true, selected = function(data)
            local barId = 'bgrz-diagnostic-' .. npc.id
            exports['envi-interact']:PercentageBar(barId, 25, 'DIAGNOSTICO: 25%', 'top', 'always')
            updateSpeech(data, 'Verificando motor, pneus e transmissao...')
            CreateThread(function()
                Wait(900); exports['envi-interact']:PercentageBar(barId, 65, 'DIAGNOSTICO: 65%', 'top', 'always')
                Wait(900); exports['envi-interact']:PercentageBar(barId, 100, 'DIAGNOSTICO: 100%', 'top', 'always')
                say(data, 'Teste concluido. Nenhuma alteracao foi feita no veiculo.')
            end)
        end },
        { key = 'G', label = 'Fechar barras', selected = function() exports['envi-interact']:CloseAllPercentBars() end },
        leaveOption()
    }
end

local function sliderOptions()
    return {
        { key = 'E', label = 'Fazer oferta', reaction = 'GENERIC_HOWS_IT_GOING', stayOpen = true, selected = function(data)
            updateSpeech(data, 'Escolha um valor entre $50 e $500.')
            exports['envi-interact']:UseSlider(data.menuID, {
                title = 'Oferta de teste', min = 50, max = 500, sliderState = 'unlocked', sliderValue = 250, nextState = 'locked',
                confirm = function(newValue)
                    notify(('Oferta ficticia escolhida: $%s'):format(newValue), 'success')
                    say(data, ('Voce escolheu $%s. Nenhum dinheiro foi movimentado.'):format(newValue))
                end
            })
        end },
        leaveOption()
    }
end

local function nestedOptions()
    return {
        { key = 'E', label = 'Ver carreiras', reaction = 'GENERIC_YES', selected = function()
            exports['envi-interact']:OpenChoiceMenu({
                title = 'Carreiras de teste', speech = 'Escolha uma area. Isto nao altera seu emprego.', menuID = 'bgrz-npc-careers', position = 'right',
                options = {
                    { key = 'E', label = 'Servicos publicos', selected = function(data) say(data, 'Policia, saude e prefeitura dependem de processos proprios do servidor.') end },
                    { key = 'G', label = 'Servicos civis', selected = function(data) say(data, 'Taxi, mecanica e logistica sao bons exemplos de trabalhos civis.') end },
                    { key = 'X', label = 'Fechar tudo', selected = function() exports['envi-interact']:CloseAllMenus(); restoreNPC('bgrz-npc-careers') end }
                }
            })
        end },
        leaveOption()
    }
end

local function speechOptions()
    return {
        { key = 'E', label = 'Estou bem', reaction = 'GENERIC_THANKS', selected = function(data) say(data, 'Otimo! A fala mudou sem fechar o menu.') end },
        { key = 'G', label = 'Preciso de ajuda', reaction = 'GENERIC_SHOCKED_MED', selected = function(data) say(data, 'Em um sistema real, a solicitacao seria validada pelo servidor.'); notify('Triagem registrada apenas localmente.') end },
        leaveOption()
    }
end

local standardLabels = {
    police = { 'Pedir informacoes', 'Consultar regras da area' }, taxi = { 'Praca para aeroporto', 'Praca para hospital' },
    reporter = { 'Dar entrevista', 'Recusar educadamente' }, bartender = { 'Ver bebida sem alcool', 'Ver petisco' }
}

local function standardOptions(npc)
    local labels = standardLabels[npc.example]
    return {
        { key = 'E', label = labels[1], reaction = 'GENERIC_YES', selected = function(data) say(data, ('Voce escolheu: %s. Este resultado e somente demonstrativo.'):format(labels[1])) end },
        { key = 'G', label = labels[2], reaction = 'CHAT_STATE', selected = function(data) say(data, ('Voce escolheu: %s. Nenhum estado persistente mudou.'):format(labels[2])) end },
        leaveOption()
    }
end

local function quizOptions()
    return {
        { key = 'E', label = 'Parar no sinal vermelho', reaction = 'GENERIC_THANKS', selected = function(data) say(data, 'Correto! Esta pergunta demonstra feedback imediato.'); notify('Resposta correta.', 'success') end },
        { key = 'G', label = 'Acelerar no sinal vermelho', reaction = 'GENERIC_NO', selected = function(data) say(data, 'Resposta incorreta. Tente a outra opcao.'); notify('Resposta incorreta.', 'error') end },
        leaveOption()
    }
end

local function relationshipOptions(npc)
    relationships[npc.id] = relationships[npc.id] or 50
    local function update(data, amount, message)
        relationships[npc.id] = math.max(0, math.min(100, relationships[npc.id] + amount))
        local value = relationships[npc.id]
        exports['envi-interact']:PercentageBar('bgrz-relationship', value, ('RELACAO: %d%%'):format(value), 'top', 'hover')
        say(data, message)
    end
    return {
        { key = 'E', label = 'Ser gentil', reaction = 'GENERIC_THANKS', selected = function(data) update(data, 15, 'Talvez voce seja confiavel. A relacao aumentou localmente.') end },
        { key = 'G', label = 'Provocar', reaction = 'GENERIC_CURSE_HIGH', selected = function(data) update(data, -20, 'Cuidado com suas palavras. A relacao diminuiu localmente.') end },
        leaveOption()
    }
end

local factories = {
    guide = guideOptions, simple = simpleOptions, progress = progressOptions, slider = sliderOptions, nested = nestedOptions,
    speech = speechOptions, police = standardOptions, taxi = standardOptions, reporter = standardOptions,
    bartender = standardOptions, quiz = quizOptions, relationship = relationshipOptions
}

local function spawnNPC(npc)
    if npc.enabled == false then return end
    local factory = factories[npc.example]
    if not factory then print(('[%s] Exemplo desconhecido no NPC %s: %s'):format(resourceName, npc.id, tostring(npc.example))); return end

    local ped = exports['envi-interact']:CreateNPC({ model = npc.model, coords = vector3(npc.coords.x, npc.coords.y, npc.coords.z), heading = npc.coords.w, isFrozen = true }, {
        title = npc.title, speech = npc.speech, speechOptions = { duration = 1200 }, menuID = 'bgrz-npc-' .. npc.id,
        position = 'right', greeting = npc.greeting, focusCam = true, distance = 2.5, radius = 1.25,
        options = factory(npc), onESC = function()
            exports['envi-interact']:CloseEverything()
            restoreNPC('bgrz-npc-' .. npc.id)
        end
    })
    npcStates['bgrz-npc-' .. npc.id] = { ped = ped, scenario = npc.scenario }
    if npc.example == 'nested' then npcStates['bgrz-npc-careers'] = npcStates['bgrz-npc-' .. npc.id] end
    if npc.scenario then TaskStartScenarioInPlace(ped, npc.scenario, 0, true) end
    spawnedNPCs[#spawnedNPCs + 1] = ped
end

CreateThread(function()
    while GetResourceState('envi-interact') ~= 'started' do Wait(250) end
    for _, npc in ipairs(Config.NPCs) do spawnNPC(npc) end
    if Config.ShowBlip then
        testBlip = AddBlipForCoord(Config.TestLocation.x, Config.TestLocation.y, Config.TestLocation.z)
        SetBlipSprite(testBlip, 280); SetBlipColour(testBlip, 46); SetBlipScale(testBlip, 0.8); SetBlipAsShortRange(testBlip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString('Teste de NPCs'); EndTextCommandSetBlipName(testBlip)
    end
    print(('[%s] %d NPCs de teste criados na Legion Square. Use /npctest.'):format(resourceName, #spawnedNPCs))
end)

RegisterCommand('npctest', function()
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, Config.TestLocation.x, Config.TestLocation.y, Config.TestLocation.z, false, false, false, false)
    SetEntityHeading(playerPed, Config.TestLocation.w)
    notify('Voce chegou a area de NPCs na Legion Square.', 'success')
end, false)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource ~= resourceName then return end
    if GetResourceState('envi-interact') == 'started' then
        exports['envi-interact']:CloseEverything()
    end
    for _, ped in ipairs(spawnedNPCs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    if testBlip and DoesBlipExist(testBlip) then RemoveBlip(testBlip) end
end)
