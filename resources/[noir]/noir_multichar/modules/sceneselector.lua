-- Cena da seleção de personagem: sorteada a cada vez que a seleção monta a cena (abrir, excluir
-- personagem, logout), evitando repetir a anterior. Não há mais escolha pelo jogador.
local currentScene = nil

PickRandomScene = function()
    local scenes = Config.CharacterSelection
    local candidates = {}
    for i = 1, #scenes do
        if scenes[i] ~= currentScene then candidates[#candidates + 1] = scenes[i] end
    end
    if #candidates == 0 then candidates = scenes end

    currentScene = candidates[math.random(1, #candidates)]
    return currentScene
end

---Cena em uso agora (a criação de personagem volta para ela ao sair).
GetCurrentScene = function()
    return currentScene or PickRandomScene()
end
