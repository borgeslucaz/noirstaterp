---@class NoirElevatorStop
---@field label string nome no painel e no contador
---@field level integer andar físico; o contador anda de um em um entre a origem e o destino
---@field coords vector4 centro da cabine, onde o jogador viaja; w = heading de frente para a porta
---@field target? vector3 centro do botão; sem ele, sai de `button` do elevador

---@class NoirElevatorButton
---@field forward number metros do centro da cabine até o botão, na direção da porta (w)
---@field right number metros para a direita de quem olha a porta
---@field up number metros acima do z da cabine
---@field size number aresta da caixa do alvo

---@class NoirElevator
---@field label string
---@field secondsPerFloor number tempo de viagem por andar
---@field minSeconds number viagem mínima, para um andar não passar num piscar
---@field waitInterior boolean o destino é MLO/IPL e precisa estar pronto antes de soltar o jogador
---@field button NoirElevatorButton
---@field stops NoirElevatorStop[]

---Andares do Wiwang: os 20 MLOs são o mesmo andar empilhado (mesmo X/Y no ipl.lua do mapa),
---3,8 m um do outro. As posições do script antigo variavam até 0,5 m de captura para captura;
---aqui o centro da cabine é o do Andar 1 e só o z muda, para a troca cair no mesmo enquadramento.
local function wiwangFloors()
    local floors = {}
    for level = 1, 20 do
        floors[level] = {
            label = ('Andar %d'):format(level),
            level = level,
            coords = vec4(-824.11, -717.47, 41.57 + (level - 1) * 3.8, 221.3),
        }
    end
    return floors
end

local wiwangStops = wiwangFloors()
table.insert(wiwangStops, 1, {
    label = 'Lobby',
    level = 0,
    coords = vec4(-819.82, -699.8, 28.07, 90.216),
    -- Botão medido no ShadowForge.
    target = vec3(-821.24, -698.82, 28.24),
})

return {
    -- Imprime cada passo da viagem no F8 (vai para o CitizenFX.log). Desligar depois de estável.
    trace = false,

    -- Desenha a caixa do botão (debug do ox_target), para conferir a posição nos andares.
    debugTargets = false,

    -- Quanto a câmera treme com a cabine andando (ShakeCam 'HAND_SHAKE').
    shakeAmplitude = 0.35,

    -- Piscada curta só na troca de andar: o andar de destino é outro IPL e precisa carregar.
    swapFadeMs = 250,

    -- Limite para o interior e a colisão do destino carregarem antes de soltar o jogador.
    loadTimeoutMs = 6000,

    sounds = {
        set = 'MP_PROPERTIES_ELEVATOR_DOORS',
        close = 'CLOSED',
        open = 'OPENED',
    },

    ---@type table<string, NoirElevator>
    elevators = {
        wiwang = {
            label = 'Wiwang Hotel',
            secondsPerFloor = 0.9,
            minSeconds = 3.0,
            -- Só um andar do Wiwang existe por vez (map_wiwang_hotel_enh/ipl.lua troca por zona).
            waitInterior = true,
            -- Botão dos andares, medido no ShadowForge no Andar 2 (-823.97, -719.03, 45.59) em relação
            -- à cabine dele. O lobby tem botão próprio (`target`).
            button = { forward = 1.26, right = 0.92, up = 0.22, size = 0.25 },
            stops = wiwangStops,
        },
    },
}
