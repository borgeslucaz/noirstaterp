# noir_minigames

Os minigames do servidor num lugar só, com um menu de teste para admin.

- **Noir:** 12 minigames próprios na NUI deste resource, com o visual da DESIGN_v4.
  As regras seguem as do XS-Robberies, mas o código e o visual são nossos (o XS não
  permite redistribuir o dele). Um arquivo por jogo em `html/js/games/` e
  `html/css/games/`; a base comum (janela, relógio, teclado) é `html/js/core.js`.
- **Preview no navegador:** abrir `html/index.html` fora do jogo mostra um botão por
  jogo e o seletor de dificuldade no canto inferior esquerdo.
- **Ponte para os que já estão no servidor**, sem alterar nenhum deles: `ox_lib`
  (skillCheck), `ps_lib` (Circle, Maze, Scrambler, Thermite, VarHack), `peuren_minigames`
  (Lockpick, Hacking, Typewriter, Pressure, Looting), `rep-enginewire`, `mhacking`,
  `safecracker` e `ultra-voltlab`. Fornecedor parado aparece desativado no menu.

## Menu de teste

`/minigames` — exige a ACE `noir.minigames`:

```
add_ace group.admin noir.minigames allow
```

Fornecedor → jogo → dificuldade (Fácil, Normal, Difícil). O resultado sai num aviso
com o tempo, e o menu volta para a lista do fornecedor.

## Uso por outro resource (cliente)

```lua
local passed, detail = exports.noir_minigames:Play('noir:drill', 2)
-- detail: 'unknown' | 'unavailable' | 'busy' | 'error' | nil (ou tabela, no Saque)

local list = exports.noir_minigames:List() -- { id, label, provider, available }
```

Os ids estão em `shared/catalogue.lua`. Uma partida por vez; passou de
`timeoutSeconds` (config/client.lua) sem resposta, conta como falha. Na NUI própria,
Esc desiste. O resultado é do cliente: quem paga recompensa confere no servidor.

## Testes

```
lua5.4 tests/unit/catalogue_spec.lua
```
