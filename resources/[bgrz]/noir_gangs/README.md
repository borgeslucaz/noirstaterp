# noir_gangs

Gestão de gang em jogo: lista de membros, convite por proximidade, cargos com permissão,
reputação e tipo de produto operado.

O resource não fala com o framework. Membros, cargos, personagens e alvos chegam pelos exports
do `bgrz_core`; nenhum arquivo chama `qbx_core` ou `ox_target` diretamente, e o manifest declara
só `ox_lib`, `oxmysql` e `bgrz_core`. Um teste guarda isso.

## Instalação

1. Ordem de start: `ox_lib` / `oxmysql` → `qbx_core` e providers → `bgrz_core` → `noir_gangs`.
   As dependências também estão nos manifests, então um boot limpo já respeita a ordem.
2. `bgrz_core` precisa ter a API de gang (`GetGangInfo`, `GetGangMembers`, `SetGangGrade`,
   `RemoveFromGang`, `GetCharacterNames`, `UpsertGangGrade`) e o `AddBoxZoneTarget`. Se você
   reiniciar só o `noir_gangs` depois de atualizar o bridge, o start falha em `AddBoxZoneTarget`:
   reinicie o `bgrz_core` primeiro.
3. O schema roda sozinho no start, a partir de `migrations/noir_gangs.sql`. Só DDL idempotente e
   não destrutivo passa — `DROP`, `MODIFY` e `RENAME` são recusados e abortam o start, porque o
   arquivo roda inteiro toda vez e nada ali pode apagar dado.
4. Ace `noir.gangsetup` para os comandos de admin.

## Autoridade: o que é nosso e o que é do Qbox

Esta divisão explica quase todas as decisões do resource.

| | Onde mora | Sincroniza com o Qbox |
|---|---|---|
| Quem está na gang, e em que nível | Qbox (`player_groups`) | é dele |
| Rótulo do cargo | `noir_gang_ranks` | **sim**, via `UpsertGangGrade` |
| Permissões do cargo | `noir_gang_ranks` | não |
| Reputação | `noir_gang_state` | não |
| Produtos | `noir_gang_products` | não |

Membresia fica no Qbox porque ele é dono da persistência do personagem: a gang é salva e
carregada no mesmo ciclo do resto, e `PlayerData.gang` é o formato que qualquer resource de
terceiro espera. Reimplementar isso seria refazer o ciclo de vida do personagem.

O **rótulo** precisa viajar para o Qbox porque `PlayerData.gang.grade.name` é o que aparece fora
daqui, e porque `AddPlayerToGang` recusa um nível que a gang não tenha. É por isso que o arquétipo
`mc`, com seis cargos, funciona numa gang que tinha quatro em `shared/gangs.lua`: publicamos os
cargos no start. A publicação usa `commitToFile = false` de propósito — gravar naquele arquivo
atropelaria edições feitas à mão lá.

Permissão, reputação e produto o Qbox não conhece. São nossos, sem sincronização nenhuma.

## Cargos e permissões

Cada cargo declara exatamente o que pode. **Não há herança entre cargos**: um cargo alto que não
liste `invite` não convida, mesmo que o cargo abaixo dele convide. Quem controla é o config.

O catálogo é fechado e um nome fora dele **derruba o start**. Isso é de propósito: permissão com
erro de digitação não estoura, ela simplesmente nunca é verdadeira, e o erro só aparece no dia em
que alguém precisa dela.

```
view_members · view_offline_members · invite · remove_member
promote · demote · view_reputation · view_products
```

### As duas regras estruturais

Acima da permissão existem só duas regras no código, e as duas protegem o chefe (`isBoss`):

- **Chefe não é desligado nem muda de cargo.** Nem promoção, nem rebaixamento, nem remoção.
- **Ninguém é promovido *para* chefe.** Seria passar a liderança por mecanismo de jogador.

Não existe comparação entre o cargo de quem age e o de quem recebe. Quem tem `promote`, promove —
inclusive alguém de cargo mais alto. Se um cargo não deve poder, ele não recebe a permissão.

### Arquétipos

Três no config, e cada gang aponta para um. Gang que existe no Qbox e não está em `Config.Gangs`
cai em `Config.FallbackArchetype` e funciona, sem produto.

| Arquétipo | Cargos |
|---|---|
| `gueto` | Recruit · Enforcer · Shot Caller · **Boss** |
| `mc` | Prospect · Member · Road Captain · Sergeant at Arms · Vice President · **President** |
| `cartel` | Halcón · Sicario · Lugarteniente · Jefe de Plaza · **Patrón** |

O cargo logo abaixo do chefe sempre gere de verdade (`promote`, `demote`, `remove_member`), e um
teste exige isso. Com o chefe intocável e a promoção parando antes dele, se só o chefe gerisse, um
chefe inativo deixaria a gang sem gestão e sem saída.

Os níveis não precisam ser contíguos: uma gang com cargos 0, 2 e 5 é válida, e promover pula para
o próximo que existe de verdade.

## Reputação

Um inteiro por gang. **Ninguém edita a própria reputação pelo menu** — quem tem `view_reputation`
só vê. Ajustar é coisa de admin (`/gangrep`) ou de outro resource, via export.

Todo ajuste entra no histórico da gang com quem fez, quanto e por quê. Além do teto total
(`Config.Reputation.min/max`), existe um teto por ajuste (`maxDelta`): sem ele, um zero a mais
digitado no comando estoura o placar de uma vez. Ajuste que bateria no limite retorna `at_limit`
em vez de fingir que aplicou.

## Produtos

O que a gang opera, para destravar craft, laboratório e tipo de missão nos outros resources.

A tabela é `(gang_name, product_type)`, chave composta — então **mais de um produto por gang já
funciona hoje**, é só listar no config. Na prática cada gang tem um.

| Gang | Arquétipo | Produto |
|---|---|---|
| `ballas`, `families`, `vagos` | gueto | `drugs` |
| `lostmc` | mc | `weapons` |
| `cartel` | cartel | `items` |
| `triads` | cartel | `attachments` |

Os tipos vivem em `Config.ProductTypes` (`drugs`, `weapons`, `items`, `ammo`, `attachments`).
Produto fora do catálogo derrubaria o start, igual permissão.

Quem consome pergunta por export — não há materialização para bancada nativa do `ox_inventory`.

## Convites e saída

Convite é por proximidade e é validado **duas vezes**: no envio e de novo no aceite, quando
distância, permissão, gang e validade são conferidas outra vez. Convite tem expiração e cooldown
por remetente.

A checagem "já tem gang" olha todas as gangs do personagem, não só a primária. O servidor roda com
uma gang por personagem (`qbx:max_gangs_per_player` no padrão 1), e é justamente por isso: alguém
que constasse em `gangs` com a primária em `none` passaria pelo convite para falhar na entrada,
com a mensagem errada.

Sair da gang não tem trava. Como não existe transferência de liderança por jogador, exigir que o
chefe passasse o cargo antes o prenderia na gang para sempre. Chefe que sai deixa a gang sem topo,
e quem recompõe é a administração.

## Pontos de gestão

Zonas de caixa criadas em jogo pelo admin (`/gangsetup`), persistidas e visíveis só para membros
da gang dona. As zonas são registradas pelo `bgrz_core`, que as limpa sozinho quando o resource
para.

Quem pede a lista é o client, ao entrar e a cada restart do resource — um empurrão do servidor no
start se perderia, porque os dois lados reiniciam juntos e o client ainda não registrou o evento.
Como o pedido vem de fora, tem teto por source. Edições do admin continuam saindo por broadcast.

## Comandos

| Comando | Quem | O que faz |
|---|---|---|
| `/gangsetup` | ace `noir.gangsetup` | Cria, move, teleporta e apaga pontos de gestão |
| `/gangrep <gang> <pontos>` | ace `noir.gangsetup` | Soma reputação; número negativo tira |

Entrar e tirar alguém de uma gang é do `qbx_core`: `/setgang <id> <gang> <cargo>`, e
`/setgang <id> none` desliga. Não duplicamos isso aqui.

## Integração

```lua
exports.noir_gangs:GetGang(source)                       --> { name, label, grade, gradeName, isBoss }
exports.noir_gangs:HasGangPermission(source, permission) --> boolean
exports.noir_gangs:GetGangMembers(gangName)              --> { { citizenId, grade }, ... }
exports.noir_gangs:GetGangRanks(gangName)                --> { [level] = { label, isBoss, permissions } }

exports.noir_gangs:GetGangReputation(gangName)           --> integer
exports.noir_gangs:AddGangReputation(gangName, delta, motivo) --> total | nil, errorCode

exports.noir_gangs:GetGangProducts(gangName)             --> { 'drugs', ... }
exports.noir_gangs:HasGangProduct(gangName, tipo)        --> boolean
exports.noir_gangs:PlayerHasGangProduct(source, tipo)    --> boolean

exports.noir_gangs:GetGangManagementLocations(gangName)  --> { { id, coords, size, heading }, ... }
```

`GetGang` devolve a gang já normalizada pelo bridge: `grade` é o **nível** (número) e o nome do
cargo vem em `gradeName`. Ler `grade.level` aqui não estoura — cai no `or 0` e todo mundo vira
cargo 0 em silêncio.

Consumidores hoje: `noir_illegal_core` (`server/bridges/gangs.lua`) e `noir_graffiti`
(`server/validation.lua`).

## Persistência

| Tabela | Guarda |
|---|---|
| `noir_gang_locations` | Pontos de gestão |
| `noir_gang_activity` | Histórico de toda ação de gestão |
| `noir_gang_state` | Reputação e arquétipo aplicado |
| `noir_gang_products` | Produtos por gang |
| `noir_gang_ranks` | Cargos: rótulo, `isBoss`, `bankAuth`, permissões |

Ações gravadas no histórico: `invitation_sent`, `invitation_declined`, `member_joined`,
`member_promoted`, `member_demoted`, `member_removed`, `member_left`, `reputation_changed`,
`management_point_created`, `management_point_moved`, `management_point_deleted`.

### `Config.RanksFromConfig`

Enquanto não existe editor de cargos em jogo, **o config manda**: a cada start ele reescreve
`noir_gang_ranks` e `noir_gang_products`. **Reputação nunca é tocada** — é dado vivo, e um teste
garante que o reseed a preserva.

No dia em que o editor entrar, vire a chave para `false` e o banco passa a ser a verdade, sem
migração: as tabelas já estão no formato final, por gang.

## O que não existe, de propósito

- **Transferir liderança.** Trocar quem lidera é `/setgang` do admin. Não há caminho de jogador
  que passe ou tome a liderança.
- **Se colocar numa gang.** Entrar depende de convite de outra pessoa.
- **Editor de cargos em jogo.** Cargos e permissões vêm do config; ver `RanksFromConfig`.
- **Locales.** Os textos estão em pt-BR no código. Os irmãos (`noir_outposts`, `noir_busjob`,
  `noir_houserobbery`) usam `ox_lib 'locale'` com `locales/*.json`; aqui isso ainda não foi feito.

## Testes

Lua 5.4, a partir da raiz do resource:

```
lua5.4 tests/unit/config_spec.lua
lua5.4 tests/unit/state_spec.lua
lua5.4 tests/unit/server_spec.lua
```

- `config_spec` — acoplamento (nada de `qbx_core`/`ox_target`), catálogo de permissões, um chefe
  por arquétipo no topo, gestão abaixo do chefe, gangs do config existindo no Qbox, schema
  idempotente.
- `state_spec` — roda `server/state.lua` contra um banco em memória: schema, validação do config,
  seed dos cargos, publicação do rótulo no provider, permissão por cargo, produtos (inclusive
  vários por gang) e limites da reputação.
- `server_spec` — regras de membro com o `NoirGangs` stubado: chefe intocável, promoção parando
  antes do chefe, ausência de comparação de hierarquia, convite, cooldown e limpeza no
  `playerDropped`.
