# noir_scoreboard

Placar da cidade e **tabela pública de policiamento mínimo**. Fork do
[qbx_scoreboard](https://github.com/Qbox-project/qbx_scoreboard) (GPL-3.0), que foi
para `disabled_resources/`.

## O que o jogador vê

Tecla padrão **HOME**. O atalho se chama `scoreboard`, o mesmo nome do qbx_scoreboard,
então quem já tinha trocado a tecla nas configurações do FiveM continua com a dele.

- **Todo mundo:** quantos jogadores estão na cidade e, conforme `idVisibility`, os números
  acima da cabeça de quem está perto.
- **Só membro de gang:** a tabela de crimes, com o mínimo de policiais de cada um e o estado
  agora (liberado, polícia insuficiente, em andamento). Quem não está numa gang nem recebe os
  números: a tabela não vai em `GlobalState` nem em arquivo enviado ao cliente.

A gang vem do `bgrz_core` (`GetCharacterGangs`), não do `players.gang` do Qbox.

## A tabela é a fonte única

`config/server.lua` → `crimes`. Os crimes não têm mais mínimo próprio: perguntam aqui, no
servidor, e o número do placar é o que o jogo exige.

| key | Quem pergunta | Onde |
|---|---|---|
| `storerobbery` | qbx_storerobbery | caixa (início e target) e cofre |
| `houserobbery` | noir_houserobbery | antes do skillcheck da porta |
| `outpost` | noir_outposts | tomada (início, conclusão e painel) |
| `jewellery` | qbx_jewelery | caixa de luz |
| `truckrobbery` | qbx_truckrobbery | início da missão |
| `bankrobbery` | qbx_bankrobbery | Fleeca (o cliente recebe o mínimo no login) |
| `paleto` | qbx_bankrobbery | Paleto |
| `pacific` | qbx_bankrobbery | Pacific e termite da usina |

A polícia em serviço é contada pelo `noir_police` (`GetCopCount`). Se ele não responder,
nenhum crime libera.

## API (servidor)

```lua
---@return boolean ok, string? code, integer? minimumPolice, integer? police
local ok, code, minimum, police = exports.noir_scoreboard:CheckPolice('storerobbery')
-- code: 'unknown_crime' | 'police_unavailable' | 'not_enough_police'

---@return integer? minimumPolice
exports.noir_scoreboard:GetMinimumPolice('paleto')

---Marca o crime como em andamento no placar.
exports.noir_scoreboard:SetActivityBusy('jewellery', true)
```

O evento `qb-scoreboard:server:SetActivityBusy`, que o qbx_jewelery e o qbx_bankrobbery
disparam, continua funcionando, mas agora é **local** (`AddEventHandler`). No qbx_scoreboard
ele era de rede e qualquer cliente marcava ou desmarcava um banco.

Quem chama usa `pcall` e trata falha como "não libera": os crimes sobem antes do placar no
`server.cfg` e só perguntam na hora da ação.

## Testes

```bash
lua5.4 tests/unit/rules_spec.lua
```

## Preview

`dev/index.html` carrega a `web/` real com cenários `?preset=gang|semGang|semPolicia`.
