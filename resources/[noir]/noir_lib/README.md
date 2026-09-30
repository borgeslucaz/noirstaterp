# noir_lib

Componentes compartilhados da Noir State. Client-only, depende só do `ox_lib`.

## Teclas visíveis

As pílulas `[ESC] FECHAR` do DESIGN_v4 §7, para resources que não têm NUI própria.
Um conjunto na tela por vez: quem mostra é o dono, só o dono troca ou esconde, e se o
dono parar sem esconder as teclas somem sozinhas.

```lua
exports.noir_lib:ShowKeyHints({
    position = 'baixo', -- 'cima' | 'baixo' | 'esquerda' | 'direita' (padrão 'baixo')
    keys = {
        { key = 'W', label = 'Levantar' },
        { key = 'Esc', label = 'Fechar' },
    },
}) --> true, ou false (dados inválidos ou outro resource já mostrando; o motivo vai para o F8)

exports.noir_lib:HideKeyHints()   --> true se escondeu
exports.noir_lib:IsKeyHintsOpen() --> as teclas DE QUEM CHAMA estão na tela?
```

- `cima`/`baixo`: centralizadas na borda, em linha, separadas por `/`.
- `esquerda`/`direita`: empilhadas no meio da borda.
- Até 8 teclas. `label` vai em caixa alta pela NUI; escreva em caixa normal.
- Chamar `ShowKeyHints` de novo troca o conteúdo sem repetir a animação de entrada.

## Fala do ped

Um balão acima da cabeça do ped, no lugar de uma notificação no canto: o NPC que recusou
diz "Quero essa merda não, vou chamar a polícia" e a reação fica na cena. Com uma lista, uma
das falas é sorteada, então a mesma reação não repete sempre o mesmo texto.

```lua
local id = exports.noir_lib:PedSay(ped, {
    'Quero essa merda não, vou chamar a polícia!',
    'Tá maluco? Vou ligar pros homi agora.',
}, {
    tone = 'alert',     -- 'neutral' (padrão) | 'alert': borda vermelha, para ameaça e polícia
    duration = 4000,    -- ms; padrão pelo tamanho do texto (3,5 a 7 s)
    offset = 0.28,      -- metros acima do centro da cabeça
    maxDistance = 15.0, -- até onde aparece
}) --> id do balão, ou nil (ped ou texto inválido; o motivo vai para o F8)

exports.noir_lib:PedSayStop(idOuPed) --> true se tirou
exports.noir_lib:IsPedSaying(ped)    --> o ped está com balão na tela?
```

- Aceita um texto ou uma lista de textos, até 140 caracteres cada.
- Um balão por ped: fala nova no mesmo ped troca a anterior. Até 8 balões na tela.
- O balão acompanha a cabeça e some com o ped longe, atrás de parede ou fora da tela.
- Só quem chama vê (é client). Se o resource que criou parar, os balões dele somem.
- As falas ficam no config de quem chama, como `Config.PedSpeech` no `noir_drugselling`.

## Preview no navegador

`dev/index.html` carrega o `web/index.html` real e faz o papel do Lua. Sirva a raiz do
resource (ex.: `python3 -m http.server 9071`) e abra `/dev/index.html?pos=direita`. Os
botões "Fala" mostram o balão numa posição fixa.
`dev/` não está em `files{}` e não vai para o jogo.
