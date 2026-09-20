---Parquímetro — a interação: o que o jogador faz com o poste.
---
---São dois gestos, como no smash & grab, e pela mesma razão: o primeiro é o que
---compromete, o segundo é o que paga.
---
---  1. **forçar a fechadura** — minigame do ox_lib e uma barra de progresso. É
---     aqui que o alerta policial pode sair;
---  2. **recolher as moedas** — a segunda barra, e só então o servidor entrega.
---
---A reserva vem ANTES dos dois. É diferente do smash & grab, em que a quebra do
---vidro acontece antes de qualquer pedido, e a diferença tem motivo: lá o vidro
---quebrado é um estado visível que o mundo inteiro passa a enxergar, então quebrar
---já é parte do crime. Aqui não há nada a ver antes do fim, e deixar o jogador
---fazer minigame e duas barras para só então descobrir que outro chegou primeiro
---seria cruel. O servidor responde em um round-trip, antes da primeira animação.

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local CrimeConfig = require 'config.parkingmeter'
local Rules = require 'shared.parkingmeter_rules'
local Integrations = require 'client.integrations'

local CRIME = Constants.crimes.parkingmeter
local DebugPrint = Utils.debugPrint(CRIME)

local EVENT_RESERVE = Constants.event('server', CRIME, 'reserve')
local EVENT_RELEASE = Constants.event('server', CRIME, 'release')
local EVENT_CLAIM = Constants.event('server', CRIME, 'claim')

local Interaction = {}

---Trava local de reentrada. A trava que vale é a do servidor; esta só evita que o
---mesmo jogador abra duas barras ao mesmo tempo.
local busy = false

---Dicionário de animação -> existe neste build. São dois dicionários possíveis
---(forçar e recolher), então o cache é por dicionário: com uma flag só, o
---primeiro conferido responderia pelos dois e o outro nunca seria validado.
---@type table<string, boolean>
local animChecked = {}

---Código de recusa do servidor -> chave de locale. Os códigos são estáveis e
---legíveis por máquina; o texto é localizado aqui (§20.1).
local CODE_LOCALE = {
    busy = 'pm_reason_busy',
    cooldown = 'pm_reason_cooldown',
    too_far = 'pm_reason_too_far',
    reserved = 'pm_reason_reserved',
    already_taken = 'pm_reason_already_taken',
    bad_model = 'pm_reason_bad_model',
    bad_coords = 'pm_reason_bad_coords',
    out_of_area = 'pm_reason_out_of_area',
    no_tool = 'pm_reason_no_tool',
    too_much_heat = 'pm_reason_too_much_heat',
    too_soon = 'pm_reason_too_soon',
    expired = 'pm_reason_expired',
    invalid_player = 'pm_failed',
    provider_unavailable = 'pm_reason_provider_unavailable',
    mismatch = 'pm_failed',
    server_error = 'pm_reason_server_error',
}

---@return table? anim
local function animOption(anim)
    if type(anim) ~= 'table' or type(anim.dict) ~= 'string' then return nil end

    if animChecked[anim.dict] == nil then
        animChecked[anim.dict] = DoesAnimDictExist(anim.dict)
        if not animChecked[anim.dict] then
            lib.print.warn(('dicionário de animação ausente neste build: %s'):format(anim.dict))
        end
    end

    return animChecked[anim.dict] and anim or nil
end

---@param entity number
---@return boolean
local function withinReach(entity)
    if not DoesEntityExist(entity) then return false end
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(entity)) <= CrimeConfig.maxDistance
end

---Vigia a cena durante a barra e cancela quando ela deixa de fazer sentido.
---A progress do ox_lib não sabe nada sobre o poste; é esta thread que sabe. Ela
---vive só enquanto a barra estiver na tela.
---@param entity number
local function watchProgress(entity)
    CreateThread(function()
        while lib.progressActive() do
            if not withinReach(entity) or IsEntityDead(cache.ped) or cache.vehicle then
                lib.cancelProgress()
                return
            end
            Wait(200)
        end
    end)
end

---Recusas que fazem parte do jogo.
---
---Chegar num poste que outro acabou de esvaziar, estar sem a ferramenta ou no
---cooldown não é defeito de nada: é o sistema funcionando. Isso vai para o
---`DebugPrint` e some com `Config.debug` desligado.
---
---O que NÃO está nesta lista continua saindo em `warn` mesmo em produção,
---porque significa que alguma coisa precisa de conserto — e a diferença entre
---"o jogo te disse não" e "o jogo quebrou" é exatamente o que um console
---silencioso apaga.
local EXPECTED_CODES = {
    busy = true,
    cooldown = true,
    too_far = true,
    reserved = true,
    already_taken = true,
    no_tool = true,
    too_much_heat = true,
    too_soon = true,
    expired = true,
    -- Os dois abaixo o SERVIDOR já registra em `warn`, com a chave e o hash.
    -- Repetir no client seria a mesma notícia em dois consoles.
    bad_model = true,
    out_of_area = true,
}

---Mostra a recusa ao jogador e registra o motivo no console.
---@param code string?
local function refuse(code)
    -- `nil` não é recusa: é o servidor não tendo respondido dentro do prazo.
    -- Tratar os dois como a mesma coisa esconde a diferença entre "uma regra me
    -- barrou" e "a mensagem não chegou" — problemas de natureza oposta.
    if code == nil then
        lib.print.warn(('parquímetro: servidor não respondeu em %dms')
            :format(CrimeConfig.callbackTimeout))
        return Integrations.notify(locale('pm_reason_no_answer'), 'error')
    end

    local key = CODE_LOCALE[code]
    if not key then
        -- Código que o servidor devolveu e este mapa não conhece. O jogador vê a
        -- frase genérica, mas o console diz qual é — senão some.
        lib.print.warn(('parquímetro: código de recusa desconhecido "%s"'):format(code))
        return Integrations.notify(locale('pm_failed'), 'error')
    end

    if EXPECTED_CODES[code] then
        DebugPrint('recusado:', code)
    else
        lib.print.warn(('parquímetro recusado pelo servidor: %s'):format(code))
    end
    Integrations.notify(locale(key), 'error')
end

---O payload do pedido: coordenada e model, nada mais.
---
---Repare no que NÃO vai: valor, chave do poste, tempo decorrido, resultado do
---minigame. O client manda onde está e o que está olhando; o resto é do servidor
---(§7.1). A coordenada vira tabela porque é assim que ela atravessa o callback
---sem depender de vector3 do outro lado.
---@param entity number
---@return table coords
---@return number model
local function payloadFor(entity)
    local coords = GetEntityCoords(entity)
    return { x = coords.x, y = coords.y, z = coords.z }, GetEntityModel(entity)
end

---@return boolean passed
local function pickLock()
    local config = CrimeConfig.skillCheck
    if not config.enabled then return true end
    return lib.skillCheck(config.difficulty, config.keys) == true
end

---@param entity number handle do poste, JÁ extraído do payload do ox_target
function Interaction.rob(entity)
    if busy then return end

    -- A guarda é contra quem chama, não contra o jogador. O `onSelect` do
    -- ox_target entrega uma tabela, e quem esquecer de tirar o `.entity` dela
    -- chegava aqui e só descobria o engano dentro de um native, com uma
    -- mensagem que não cita este arquivo. Falhar na porta é mais barato.
    if type(entity) ~= 'number' or not DoesEntityExist(entity) then
        lib.print.error(('Interaction.rob recebeu %s em vez de um handle de entidade')
            :format(type(entity)))
        return
    end

    busy = true

    local coords, model = payloadFor(entity)

    -- A reserva é o primeiro round-trip e acontece antes de qualquer animação: o
    -- servidor confere distância, área, ferramenta, cooldown e teto de uma vez.
    local reserved = lib.callback.await(EVENT_RESERVE, CrimeConfig.callbackTimeout, coords, model)
    if type(reserved) ~= 'table' or not reserved.ok then
        busy = false
        return refuse(type(reserved) == 'table' and reserved.code or nil)
    end

    ---Devolve o poste para a prateleira em vez de deixá-lo trancado até o
    ---timeout. Quem desistiu não deve atrapalhar quem está do lado.
    local function giveUp()
        lib.callback.await(EVENT_RELEASE, CrimeConfig.callbackTimeout, coords)
        busy = false
    end

    TaskTurnPedToFaceEntity(cache.ped, entity, 1000)

    if not pickLock() then
        giveUp()
        return Integrations.notify(locale('pm_failed_lock'), 'error')
    end

    watchProgress(entity)
    local pried = lib.progressCircle({
        label = locale('pm_progress_pry'),
        duration = CrimeConfig.pryDuration,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = animOption(CrimeConfig.pryAnim),
    })
    if not pried or not withinReach(entity) then return giveUp() end

    watchProgress(entity)
    local collected = lib.progressCircle({
        label = locale('pm_progress_collect'),
        duration = CrimeConfig.collectDuration,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = animOption(CrimeConfig.collectAnim),
    })
    if not collected or not withinReach(entity) then return giveUp() end

    local result = lib.callback.await(EVENT_CLAIM, CrimeConfig.callbackTimeout, coords, model)
    busy = false

    if type(result) ~= 'table' or not result.ok then
        return refuse(type(result) == 'table' and result.code or nil)
    end

    -- O poste sai da lista pelo aviso que o servidor manda a todo mundo, e a
    -- notificação do que veio dentro também é dele. Nada a fazer aqui.
end

---@return boolean
function Interaction.isBusy()
    return busy
end

---@param key string? chave do poste, já calculada por quem chamou
---@return boolean
function Interaction.canStart(key)
    if busy or lib.progressActive() or cache.vehicle then return false end
    if IsEntityDead(cache.ped) then return false end
    if not Integrations.isLoggedIn() then return false end
    return type(key) == 'string'
end

---Chave do poste a partir da entidade mirada. Um wrapper de uma linha, mas é o
---único lugar do client que sabe COMO um poste vira chave — trocar a regra é
---mexer em `shared/parkingmeter_rules.lua` e em mais nada.
---@param entity number
---@return string? key
function Interaction.keyFor(entity)
    if not DoesEntityExist(entity) then return nil end
    return Rules.meterKey(GetEntityCoords(entity))
end

return Interaction
