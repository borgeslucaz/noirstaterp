-- Interior do outpost no client: shell, props e o alvo do computador.
--
-- O shell é local e não networked — só existe para quem o criou. Por isso ele pode ser montado
-- antes de qualquer troca de bucket, e por isso dois jogadores em postos diferentes podem ocupar a
-- mesma coordenada sem se ver. Quem separa jogadores é o routing bucket, do lado do servidor.
--
-- Ordem da entrada, e ela importa: monta o shell primeiro, pede para entrar depois. Teleportar
-- para 80 metros abaixo do mapa antes de a colisão existir é queda livre, e foi para isso que o
-- `noir_shell` ganhou timeout de colisão.
NoirOutposts = NoirOutposts or {}

local Interior = {}
NoirOutposts.Interior = Interior

local shared = require 'config.shared'
local clientConfig = require 'config.client'
local C = NoirOutposts.Constants

---@type { outpostId: string, shellId: any, props: integer[] }?
local current = nil
local busy = false

local function notify(code)
    NoirOutposts.Client.notify(NoirOutposts.Client.message(code), 'error')
end

---Remove shell, props e alvo. Idempotente: roda na saída, na expulsão e no stop do resource.
local function teardown()
    if not current then return end
    local state = current
    current = nil

    for index = 1, #state.props do
        local prop = state.props[index]
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, true, true)
            DeleteEntity(prop)
        end
    end

    exports.bgrz_core:RemoveZoneTarget('interior:exit')
    exports.bgrz_core:RemoveZoneTarget('interior:computer')

    if state.shellId then
        exports.noir_shell:Destroy(state.shellId)
    end
end

Interior.teardown = teardown

---@return string? outpostId
function Interior.outpostId()
    return current and current.outpostId or nil
end

---Estado do interior para o `/outpostsdebug`.
---A diferença de altura entre você e cada prop está aqui de propósito: foi ela que revelou o
---laptop enterrado, depois de três rodadas procurando no lugar errado.
---@return string[] lines
function Interior.report()
    if not current then return { 'interior: fora' } end

    local shell = shared.shells[shared.outposts[current.outpostId].shell]
    local lines = {
        ('interior: %s (planta %s, shell id %s)'):format(
            current.outpostId, shared.outposts[current.outpostId].shell, tostring(current.shellId)),
        ('  props: %d de %d'):format(#current.props, #(shell.props or {})),
    }

    local me = GetEntityCoords(cache.ped)
    for index = 1, #current.props do
        local prop = current.props[index]
        local declared = shell.props[index]
        if DoesEntityExist(prop) then
            local at = GetEntityCoords(prop)
            lines[#lines + 1] = ('  %s em %.2f, %.2f, %.2f | a %.2fm | %.2fm abaixo de você'):format(
                declared and declared.model or '?', at.x, at.y, at.z, #(me - at), me.z - at.z)
        else
            lines[#lines + 1] = ('  %s SUMIU depois de criado'):format(declared and declared.model or '?')
        end
    end
    return lines
end

---Cria a decoração da planta. Locais e não networked, como o shell que os cerca: cada client monta
---os seus, e por isso a mesma coordenada serve a todos os postos sem cópia por bucket.
---
---Chamado DEPOIS do teleporte. Criados antes, nascem a mais de mil metros do jogador e não
---renderizam — objeto local só existe para quem está perto o bastante para recebê-lo.
---@param shell table
---@return integer[] props, integer? computerProp
local function spawnProps(shell)
    local created = {}
    local computerProp
    for index = 1, #(shell.props or {}) do
        local definition = shell.props[index]
        local model = joaat(definition.model)
        if not lib.requestModel(model, 5000) then
            lib.print.warn(('[noir_outposts] prop do interior não carregou: %s'):format(definition.model))
        else
            local coords = definition.coords
            local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
            SetModelAsNoLongerNeeded(model)
            if prop and prop ~= 0 and DoesEntityExist(prop) then
                SetEntityHeading(prop, coords.w or 0.0)
                FreezeEntityPosition(prop, true)
                created[#created + 1] = prop
                -- O computador é o prop que fica na coordenada que o servidor valida. O
                -- `config_spec` garante que exista exatamente um.
                if math.abs(coords.x - shell.computer.x) < 0.01
                    and math.abs(coords.y - shell.computer.y) < 0.01 then
                    computerProp = prop
                end
            else
                lib.print.warn(('[noir_outposts] prop do interior não nasceu: %s'):format(definition.model))
            end
        end
    end
    return created, computerProp
end

---@param outpostId string
function Interior.enter(outpostId)
    if busy or current then return end
    busy = true

    local definition = shared.outposts[outpostId]
    local shell = definition and shared.shells[definition.shell] or nil
    if not shell then
        busy = false
        return notify('internal_error')
    end

    -- Shell antes de tudo. Falhar aqui é barato: nada visível aconteceu ainda, e o jogador
    -- continua do lado de fora.
    -- `model` aceita string ou hash: o `noir_shell` converte. Passar o nome deixa o erro dele
    -- legível se o modelo não existir.
    local shellId, shellError = exports.noir_shell:Create({
        model = shell.model,
        origin = shell.origin,
    })
    if not shellId then
        busy = false
        lib.print.warn(('[noir_outposts] shell do interior falhou: %s'):format(tostring(shellError)))
        return notify('internal_error')
    end

    current = { outpostId = outpostId, shellId = shellId, props = {} }

    local response = lib.callback.await(C.Callbacks.ENTER_INTERIOR, false, { outpostId = outpostId })
    if not response or not response.ok then
        teardown()
        busy = false
        return NoirOutposts.Client.handleFailure(response)
    end

    -- Só agora o jogador desce. A colisão do shell já está carregada, então ele pousa no chão em
    -- vez de atravessá-lo.
    local door = response.data.door or shell.door
    SetEntityCoords(cache.ped, door.x, door.y, door.z, false, false, false, false)
    SetEntityHeading(cache.ped, door.w or 0.0)

    -- Só agora a decoração: com o jogador dentro, a área está transmitida.
    local props, computerProp = spawnProps(shell)
    current.props = props

    -- A saída. Sem ela o jogador entra e não tem como voltar — a porta é o mesmo ponto por onde
    -- ele chegou, então a zona nasce em cima dele.
    local exitOk, exitError = exports.bgrz_core:AddSphereZoneTarget({
        name = 'interior:exit',
        coords = vector3(shell.door.x, shell.door.y, shell.door.z),
        radius = shared.interaction.doorDistance,
        drawSprite = true,
        options = {
            {
                name = 'leave',
                icon = clientConfig.target.icons.door,
                label = locale('target.leave_outpost'),
                onSelect = function() Interior.leave() end,
            },
        },
    })
    if not exitOk then
        lib.print.warn(('[noir_outposts] saída do interior falhou: %s'):format(tostring(exitError)))
    end

    -- Zona com sprite, centrada na coordenada do laptop. Alvo de entidade também funciona, mas não
    -- desenha marcador: ele só destaca quando você já está mirando o objeto. A bolinha que aparece
    -- ao segurar a tecla de alvo é do sprite da zona, e é ela que diz onde interagir de longe.
    --
    -- `computer` é a mesma coordenada do prop, garantido pelo `config_spec`, então a bolinha nasce
    -- em cima do notebook. Antes as duas viviam separadas e o marcador flutuava a metros dele.
    local computerOk, computerError = exports.bgrz_core:AddSphereZoneTarget({
        name = 'interior:computer',
        coords = vector3(shell.computer.x, shell.computer.y, shell.computer.z),
        radius = shared.interaction.computerDistance,
        drawSprite = true,
        options = {
            {
                name = 'open',
                icon = clientConfig.target.icons.computer,
                label = locale('target.open_terminal'),
                onSelect = function()
                    NoirOutposts.Interaction.openComputer(outpostId)
                end,
            },
        },
    })
    if not computerOk then
        lib.print.warn(('[noir_outposts] alvo do computador falhou: %s'):format(tostring(computerError)))
    end
    if not computerProp then
        lib.print.warn('[noir_outposts] laptop do interior não subiu: alvo ficou sem objeto embaixo')
    end

    busy = false
end

function Interior.leave()
    if busy or not current then return end
    busy = true

    local response = lib.callback.await(C.Callbacks.LEAVE_INTERIOR, false, {})
    busy = false
    if not response or not response.ok then return end
    -- O teleporte de volta vem pelo evento de expulsão, que o servidor dispara na mesma chamada.
end

---O servidor mandou sair: saída normal, queda do resource, perda de acesso ou expiração.
RegisterNetEvent(C.Events.INTERIOR_EVICT, function(payload)
    if source ~= 65535 then return end
    if type(payload) ~= 'table' then return end

    local entrance = payload.entrance
    if entrance then
        SetEntityCoords(cache.ped, entrance.x, entrance.y, entrance.z, false, false, false, false)
        SetEntityHeading(cache.ped, entrance.w or 0.0)
    end
    teardown()

    if payload.reason and payload.reason ~= 'client' then
        NoirOutposts.Client.notify(NoirOutposts.Client.message(payload.reason), 'error')
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    teardown()
end)
