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

## Preview no navegador

`dev/index.html` carrega o `web/index.html` real e faz o papel do Lua. Sirva a raiz do
resource (ex.: `python3 -m http.server 9071`) e abra `/dev/index.html?pos=direita`.
`dev/` não está em `files{}` e não vai para o jogo.
