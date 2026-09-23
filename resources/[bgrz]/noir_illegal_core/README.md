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

O nível da gang é a reputação `drug` da organização (faixas em `shared/levels.lua`). Cada faixa
abre um contato — `contact_meth` no nível 2, `contact_coke` no nível 4 — por unlock automático de
organização (`shared/unlocks.lua`). Unlock de gang é avaliado com a reputação e os unlocks da
gang, nunca com os de quem fez a ação; revogado por admin não volta sozinho.

`HasUnlock(source, key)` responde pelo escopo do unlock: para `contact_coke`, a pergunta é se a
gang de quem está ali tem o contato.

### De onde vem a reputação

Nenhum resource de gameplay registra atividade direto. Cada um anuncia o fato por evento local
de servidor, e um adaptador em `server/adapters/` registra em nome do core — que é o único
`publicRecorder`. Os valores ficam em `shared/activities.lua`, com a conta de ritmo no cabeçalho.

| Fato | Evento | Atividade |
|---|---|---|
| venda de rua fechada | `noir_drugselling:server:saleCompleted` | `drug_sale` |
| venda passiva do outpost | `noir_outposts:server:saleCommitted` | `outpost_sale` (gang) |
| outpost tomado | `noir_outposts:server:claimCompleted` | `outpost_claim` |
| outpost assaltado | `noir_outposts:server:robberyCompleted` | `outpost_robbery` + `outpost_robbed` (gang dona) |
| bairro perdido | `noir_territories:server:ownerChanged` | `territory_lost` (gang anterior) |
| bairro segurado | laço a cada `Config.Territories.checkSeconds` | `territory_held`, uma vez por bairro por dia |

O adaptador confere `GetInvokingResource()` antes de aceitar o evento: qualquer resource pode dar
`TriggerEvent` com o mesmo nome.

### Atividade de gang

`subject = 'organization'` marca atividade sem autor — o fato é da gang, não de um jogador
online. Ela é registrada por `RecordOrganizationActivity(organizationId, activityKey,
transactionId, options)`, só mexe na reputação da organização, pode ter delta negativo (o total
fica preso em zero) e não aceita heat, cooldown nem requisitos. O retorno decrescente, se houver,
é por organização. A validação do start recusa qualquer outra combinação.

## Database

At startup, the resource executes migrations/001_initial.sql statement by
statement. The migrator accepts only CREATE TABLE IF NOT EXISTS and INSERT
IGNORE statements. Existing tables and migration records are therefore left
untouched. After migration, startup validates every required table and fails
closed if the schema is unavailable.
