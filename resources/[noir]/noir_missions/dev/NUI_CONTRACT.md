# noir_missions — contrato Lua ↔ NUI

A NUI é uma página só (`web/mission-editor/index.html`) com três camadas independentes:

1. **Editor** (admin, com foco): lista de missões e editor de uma missão.
2. **HUD de missão** (sem foco): objetivo discreto, cartão de informação revelada.
3. **Oferta** (com foco): "ligação" com ACEITAR / RECUSAR.

Sem build: HTML + CSS + ES modules (`<script type="module">`). Fontes em `fonts/`.
Visual: `resources/docs/DESIGN_v4.md` (Parte 1 inteira). O editor é uma janela de
comando de admin (não coberta pela Parte 2): composição livre com os fundamentos da v4.

## Lua → NUI

`window.addEventListener('message', e => e.data = { action, data })`. Ignorar `action`
desconhecida.

| action | data |
|---|---|
| `editor:open` | `{ missions: MissionSummary[], instances: InstanceSummary[], schema, lists }` |
| `editor:close` | `{}` |
| `editor:missions` | `{ missions }` |
| `editor:instances` | `{ instances }` |
| `editor:placement` | `{ active: boolean }` — enquanto `true`, o editor some inteiro (o jogador está posicionando no mundo); `false` volta como estava |
| `editor:placementResult` | `{ requestId, ok, position?: {x,y,z,w} }` |
| `hud:objective` | `{ visible, title, text, progress: {current,max} \| null, timer: {label, seconds} \| null, completed: [{text}], infos: [{title, lines}], expanded, toggleKey }` — `expanded` mostra informação fixa + passos cumpridos; recolhido, só o objetivo |
| `hud:info` | `{ title, lines: [{label, value}], seconds }` |
| `hud:infoClose` | `{}` |
| `hud:offer` | `{ offerId, caller, title, text, seconds }` |
| `hud:offerClose` | `{ offerId }` |
| `hud:reset` | `{}` — esconde HUD, info e oferta |

`lists`: `{ items: [{name,label}], minigames: [{id,label,available}], weapons: string[] }`

`MissionSummary`: `{ id, name, category, status: 'draft'|'published'|'disabled', minPlayers, maxPlayers, steps, errors, updatedAt, publishedAt, hasUnpublished }`

`InstanceSummary`: `{ instanceId, missionId, name, step, participants, test, startedAt }`

## NUI → Lua

`fetch('https://' + GetParentResourceName() + '/' + name, { method: 'POST', body: JSON })`.
Toda resposta é `{ ok: boolean, code?: string, ... }`. Falha de rede = `{ ok: false, code: 'transport_error' }`.

| callback | corpo | resposta |
|---|---|---|
| `uiReady` | `{}` | `{ ok }` |
| `editorClose` | `{}` | `{ ok }` |
| `editorLoad` | `{ id }` | `{ ok, record, definition, errors }` |
| `editorCreate` | `{ id, name }` | `{ ok, code?, record, definition, errors }` |
| `editorSave` | `{ definition }` | `{ ok, code?, record, definition, errors, missions }` |
| `editorDuplicate` | `{ id, newId, newName }` | `{ ok, code?, missions }` |
| `editorDelete` | `{ id }` | `{ ok, code?, missions }` |
| `editorSetStatus` | `{ id, status }` | `{ ok, code?, errors?, record?, missions }` — `published` copia o rascunho salvo para a versão publicada |
| `editorPlace` | `{ requestId, kind: 'position'\|'ped'\|'vehicle'\|'object', model?, heading, current? }` | `{ ok }` — resultado chega por `editor:placementResult` |
| `editorTeleport` | `{ position }` | `{ ok }` |
| `editorPreview` | `{ kind, model, position }` | `{ ok, code? }` |
| `editorValidateModel` | `{ kind, model }` | `{ ok, valid, code? }` |
| `editorTest` | `{ id, mode: 'full'\|'step'\|'sandbox', step? }` | `{ ok, code?, instanceId? }` |
| `editorTestTool` | `{ id, tool, ref? }` | `{ ok, code? }` — tool: `spawn_group`, `spawn_vehicle`, `spawn_prop`, `reinforcement`, `chase`, `delivery`, `teleport_step`, `reset` |
| `editorStopInstance` | `{ instanceId }` | `{ ok, instances }` |
| `editorDebug` | `{ enabled, id? }` | `{ ok }` |
| `offerAnswer` | `{ offerId, accept }` | `{ ok, code? }` |
| `infoClose` | `{}` | `{ ok }` |

`record`: `{ id, status, updatedAt, publishedAt, hasUnpublished }`
`errors`: `[{ path: 'steps[3].interaction', message }]`

Códigos de erro (texto pt-BR na NUI): `not_allowed`, `invalid_id`, `id_exists`, `not_found`,
`invalid_definition`, `busy`, `rate_limited`, `no_instance`, `not_enough_players`, `cooldown`,
`gang_required`, `mission_disabled`, `max_instances`, `invalid_model`, `internal_error`,
`transport_error`, `expired`.

## Esquema

`schema` é `Schema.export()` de `shared/types/schema.lua` (`dev/schema.json` é o mesmo em
JSON). A definição de missão tem os campos de `schema.general` no topo, `start` como objeto
com `schema.start`, uma lista por coleção (`schema.collections[].key`), `steps`, `triggers` e
`rewards`. Todo item de coleção, passo e gatilho tem `id` (`^[a-z0-9][a-z0-9_-]*$`).
Exemplo completo: `missions/meth_elysian_precursors.json` (campo `draft`).
