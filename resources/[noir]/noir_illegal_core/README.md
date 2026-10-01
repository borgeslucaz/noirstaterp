# noir_illegal_core

Server-only criminal progression domain service for Qbox.

## Installation

1. Add ensure noir_illegal_core after oxmysql, qbx_core, and noir_gangs.
2. Configure categories, activities, unlocks, levels, and caller permissions.
3. Keep every activity disabled until its owner performs complete server-side gameplay validation.

The resource intentionally has no client scripts, gameplay events, NUI, territory,
inventory, dispatch, or concrete crime implementation.

## Server export convention

Every export returns two values: ok, dataOrError.

Example:

~~~lua
local ok, result = exports.noir_illegal_core:RecordActivity(
    source,
    'drug_sale',
    '575c1c60-03ad-4a64-9849-0b7fe8d43d4f',
    { metadata = { zoneId = 'davis' } }
)
~~~

The caller must be present in shared/permissions.lua and in the activity callers
list. The transaction UUID must remain stable across retries.

## Progressão da gang

É aqui, e só aqui, que mora a reputação da gang. O `noir_gangs` não guarda número próprio: o
painel dele lê `GetOrganizationProgress`.

A gang tem **uma reputação só**, a categoria `gang` (a única com `organization = true` em
`Config.Categories`), qualquer que seja o produto do `noir_gangs`. As outras categorias (`street`,
`drug`, `weapons`, `items`, `ammo`, `attachments`) são **pessoais**: a validação do start recusa
activity que dê valor de gang fora de `gang`. `GetOrganizationProgress` devolve só a linha `gang`,
e `GetOrganizationLevel(source, categoria)` responde o nível de `gang` qualquer que seja a
categoria pedida.

A reputação da gang só sobe com o que só gang faz — bairro, outpost e as rotas do
`noir_gathering`. Crime que qualquer pessoa faz (venda de rua, roubos) rende reputação pessoal.
Tudo que a gang ganha passa por um teto de **50 em 24h** (`Config.Organization`), e algumas
fontes têm o seu por baixo (`dailyCap`: venda do outpost 12, rota de carga 12). Perda nunca é
cortada.

Os contatos usam o nível de `gang` (`shared/levels.lua`): `contact_meth` no nível 2 (500) e
`contact_coke` no nível 4 (1500), por unlock automático de organização (`shared/unlocks.lua`).
Unlock de gang é avaliado com a reputação e os unlocks da gang, nunca com os de quem fez a ação;
revogado por admin não volta sozinho.

`HasUnlock(source, key)` responde pelo escopo do unlock: para `contact_coke`, a pergunta é se a
gang de quem está ali tem o contato.

### De onde vem a reputação

Nenhum resource de gameplay registra atividade direto. Cada um anuncia o fato por evento local
de servidor, e um adaptador em `server/adapters/` registra em nome do core — que é o único
`publicRecorder`. Os valores ficam em `shared/activities.lua`, com a conta de ritmo no cabeçalho.

| Fato | Evento | Atividade | Valor |
|---|---|---|---|
| venda de rua fechada | `noir_drugselling:server:saleCompleted` | `drug_sale` | pessoal `drug` +2, `street` +1, × grau × peso da droga (`Config.SaleWeight`) |
| outpost tomado | `noir_outposts:server:claimCompleted` | `outpost_claim` | gang +30 (nada se o posto foi da gang em 7 dias); pessoal `street` +2 |
| venda passiva do outpost | `noir_outposts:server:saleCommitted` | `outpost_sale` | gang +0,1, até 12 por dia |
| outpost assaltado | `noir_outposts:server:robberyCompleted` | `outpost_robbery` + `outpost_robbed` | pessoal `street` +2; gang dona −5 |
| bairro tomado | `noir_territories:server:ownerChanged` | `territory_taken` | gang +25, uma vez por bairro e gang por dia |
| bairro perdido | `noir_territories:server:ownerChanged` | `territory_lost` | gang −15 (troca por admin não cobra) |
| bairro segurado | laço a cada `Config.Territories.checkSeconds` | `territory_held` | gang +8 por dia, só com atividade da gang no bairro em 24h |
| rota de coleta concluída | `noir_gathering:server:routeCompleted` | `gathering_delivery` | gang até 20 por entrega (valor da rota), até 12 por dia |

`gathering_delivery` é a única atividade de **prêmio variável** (`variable`): o valor vem no
pedido, porque é configurado por rota pelo admin, e vai sempre para `gang` (a categoria da rota é
ignorada na reputação). A atividade guarda o teto por entrega; acima dele, o pedido é recusado
inteiro.

O adaptador confere `GetInvokingResource()` antes de aceitar o evento: qualquer resource pode dar
`TriggerEvent` com o mesmo nome.

### Heat do personagem

O heat vai de 0 a 100 e decai `Config.Heat.decayPerSecond` (9 por hora) **só enquanto o
personagem está online**: no login o relógio recomeça (o tempo fora não conta) e no logout o que
decaiu é gravado (`server/services/heat_sessions.lua`). O retorno decrescente corta reputação,
nunca heat: quem repete o crime é visto todas as vezes. `GetHeat(source)` lê o valor atual.

Crimes que só somam heat (sem reputação), pelo adaptador `server/adapters/crimes.lua`:

| Fato | Evento | Atividade | Heat |
|---|---|---|---|
| roubo de casa concluído (cada participante) | `noir_houserobbery:server:robberyCompleted` | `house_robbery` | 8 |
| smash & grab / parquímetro | `noir_prettycrimes:server:crimeCompleted` | `petty_smashgrab` / `petty_parkingmeter` | 2 / 1 |
| caixa / cofre de loja | `qbx_storerobbery:server:registerRobbed` / `safeRobbed` | `store_register` / `store_safe` | 4 / 6 |
| vitrine da joalheria | `qbx_jewelery:server:vitrineRobbed` | `jewelery_vitrine` | 2 |
| banco aberto | `qbx_bankrobbery:server:bankOpened` | `bank_fleeca` / `bank_paleto` / `bank_pacific` | 12 / 16 / 20 |
| carro-forte saqueado | `qbx_truckrobbery:server:truckLooted` | `truck_robbery` | 12 |
| ligação direta / lockpick (mesmo carro 1×/dia) | `mri_Qcarkeys:server:vehicleBrokenInto` | `vehicle_break_in` | 2 |
| arma pronta retirada da bancada | `noir_guncraft:server:craftCollected` | `gun_craft` | 3 |

### Atividade de gang

`subject = 'organization'` marca atividade sem autor — o fato é da gang, não de um jogador
online. Ela é registrada por `RecordOrganizationActivity(organizationId, activityKey,
transactionId, options)`, só mexe na reputação da organização, pode ter delta negativo (o total
fica preso em zero) e não aceita heat, cooldown nem requisitos. O retorno decrescente, se houver,
é por organização. A validação do start recusa qualquer outra combinação.

## Leitura para outros resources

| Export | Devolve |
|---|---|
| `GetOrganizationProgress(organizationId)` | por categoria: rótulo, produto, reputação, nível, piso do nível e próximo limiar |
| `GetOrganizationLevel(source, category)` | nível da gang de quem está ali (0 sem gang) |
| `GetOrganizationReputation(source, category)` | reputação da gang de quem está ali |
| `HasUnlock(source, key)` | se tem o unlock, pelo escopo dele |
| `GetCatalog()` | categorias com nível máximo, unlocks de gang e teto do prêmio da coleta |

## Database

At startup, the resource executes migrations/001_initial.sql statement by
statement. The migrator accepts only CREATE TABLE IF NOT EXISTS and INSERT
IGNORE statements. Existing tables and migration records are therefore left
untouched. After migration, startup validates every required table and fails
closed if the schema is unavailable.
