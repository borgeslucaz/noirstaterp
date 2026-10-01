# dev/ — fora do jogo

Nada aqui é carregado pelo `fxmanifest.lua`.

- `schema.json` — `Schema.export()` em JSON (`lua5.4 dev/export_schema.lua > dev/schema.json`).
- `index.html` + `preview.js` — preview da NUI no navegador: a NUI real
  (`web/mission-editor/index.html`) roda num iframe e os callbacks caem no mock
  (`web/mission-editor/js/mock.js`, que só carrega fora do jogo).

## Rodar o preview

Servir a **raiz do resource** (o mock lê `missions/*.json` e `dev/schema.json`):

```sh
cd "resources/[noir]/noir_missions"
python3 -m http.server 9133 --bind 127.0.0.1
```

Abrir `http://127.0.0.1:9133/dev/index.html`. Botões no canto inferior esquerdo:
ABRIR EDITOR, ABRIR ELYSIAN, OBJETIVO, INFORMAÇÃO, OFERTA, FECHAR TUDO.

Cenário direto: `?preset=editor` (missão Elysian aberta), `list`, `hud`, `info`, `offer`.

O mock salva em memória (recarregar a página volta ao seed), valida obrigatório/referência/id
no formato do Lua (`steps[3].interaction`), e `editorPlace` devolve uma posição perto da atual
depois de ~600 ms, ligando e desligando `editor:placement` em volta.
