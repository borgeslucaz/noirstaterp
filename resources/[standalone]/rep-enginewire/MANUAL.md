# rep-enginewire — Manual

Minigame NUI de ligação direta (hotwire): o jogador conecta os pinos corretos do motor arrastando fios; o export devolve `true` ou `false`.

---

## Sumário

1. [Dependências](#dependências)
2. [Instalação](#instalação)
3. [Comandos](#comandos)
4. [Como jogar](#como-jogar)
5. [Entrypoints para outros recursos](#entrypoints-para-outros-recursos)
6. [Build da interface](#build-da-interface)
7. [Estrutura de arquivos](#estrutura-de-arquivos)

---

## Dependências

| Recurso | Obrigatório | Observação |
|---|---|---|
| — | — | O `fxmanifest.lua` não declara nenhuma dependência. O minigame é 100% NUI + nativas, sem framework |

O recurso é declarado para `gta5` e `rdr3`.

---

## Instalação

1. Copie a pasta `rep-enginewire` para `resources/`.
2. Adicione ao `server.cfg`:
   ```
   ensure rep-enginewire
   ```
3. A pasta `web/build/` já vem compilada — não é necessário buildar para usar. Só rebuilde se for alterar a interface (veja [Build da interface](#build-da-interface)).

Não há config, SQL, itens de inventário nem conflitos conhecidos.

---

## Comandos

| Comando | Permissão | Descrição |
|---|---|---|
| `/testminigame` | Nenhuma (aberto a todos) | Abre o minigame e imprime o resultado no console F8. Registrado com `restricted = false` |

> O comando é de teste e fica disponível para qualquer jogador. Remova-o de `client.lua` antes de ir para produção.

---

## Como jogar

O minigame abre em tela cheia com foco de NUI. O jogador arrasta fios entre os pinos; quando todas as conexões corretas são feitas, o jogo termina com sucesso. `ESC` cancela e conta como falha.

O resultado volta para o Lua pela callback NUI `finish` com o payload `{ result = true|false }`, que resolve a promise do export.

---

## Entrypoints para outros recursos

### Export `MiniGame`

Bloqueia até o jogador terminar ou cancelar o minigame e retorna um booleano.

```lua
local success = exports['rep-enginewire']:MiniGame()

if success then
    -- ligou o motor
else
    -- falhou ou apertou ESC
end
```

> Atenção ao nome: o export registrado no código é **`MiniGame`** (com o `G` maiúsculo). O `README.md` do upstream mostra `Minigame()`, que não existe.

---

## Build da interface

A UI é um projeto Vite + React + TypeScript em `web/`.

```bash
cd rep-enginewire/web
pnpm i
pnpm build
```

O build é gerado em `web/build/`, que é o `ui_page` declarado no `fxmanifest.lua`.

---

## Estrutura de arquivos

```
rep-enginewire/
├── client.lua                       — abre o NUI, aguarda a promise e devolve o resultado; registra o export MiniGame e /testminigame
├── web/
│   ├── build/                       — bundle compilado (é o ui_page do manifest)
│   │   ├── index.html
│   │   └── assets/                  — JS, CSS e imagens do minigame
│   ├── src/
│   │   ├── App.tsx                  — raiz do app React
│   │   ├── components/
│   │   │   ├── HotWire.tsx          — lógica do minigame: pinos, fios, canvas e envio do resultado
│   │   │   └── hotwire.module.scss  — estilos do minigame
│   │   ├── hooks/
│   │   │   ├── useKeyPress.ts       — captura de teclas
│   │   │   └── useNuiEvent.ts       — recebe SendNUIMessage do Lua
│   │   ├── utils/
│   │   │   ├── fetchNui.ts          — chamada das callbacks NUI (finish)
│   │   │   ├── debugData.ts         — mock para desenvolvimento no browser
│   │   │   ├── characterTypes.ts
│   │   │   └── misc.ts
│   │   ├── providers/LocaleProvider.tsx
│   │   ├── transitions/ScaleFade.tsx
│   │   └── assets/                  — fontes e imagens fonte
│   ├── package.json
│   ├── vite.config.ts
│   ├── tailwind.config.js
│   └── tsconfig.json
└── fxmanifest.lua
```
