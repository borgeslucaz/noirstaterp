# bgrz_core

Camada de abstração dos resources Noir/BGRZ sobre Qbox e providers substituíveis.

## Capacidades

`GetCapabilities()` está disponível no client e no server e retorna um snapshot novo:

```lua
{
    version = '0.5.0',
    inventory = { available = boolean, provider = 'ox_inventory', maxItemAmount = 100000 },
    target = { available = boolean, provider = 'ox_target' },
    phone = { available = boolean, provider = 'sd-phone' },
    dispatch = { available = boolean, provider = string|nil },
}
```

Inventário e target são dependências essenciais. Phone e dispatch são opcionais; adapters opcionais retornam `provider_unavailable` quando nenhum provider utilizável está ativo.

## Jogador e grupos

```lua
-- client
local job = exports.bgrz_core:GetJob()
local gang = exports.bgrz_core:GetGang()   -- { name, label, grade, gradeName, isBoss }
```

`name` pode vir como `'none'`, que é a gang padrão do Qbox: quem consome decide se isso conta
como organização. O server tem `GetGang(source)` com o mesmo formato.

Entrar ou sair de um job/gang não dispara `OnGangUpdate` nem `OnJobUpdate` no Qbox, só o
`onGroupUpdate` genérico, sem dizer qual dos dois mudou. O bridge escuta esse evento, compara
com o último valor conhecido e reemite `bgrz_core:*:gangUpdated` ou `jobUpdated` apenas para o
que mudou de verdade. Sem isso um consumidor perde a saída de gang e fica com dado velho.

## Inventário (server)

```lua
local ok, err = exports.bgrz_core:AddItem(holder, item, amount, metadata)
local ok, err = exports.bgrz_core:RemoveItem(holder, item, amount, metadata)
local count, err = exports.bgrz_core:GetItemCount(holder, item, metadata)
local canCarry, err = exports.bgrz_core:CanCarryItem(holder, item, amount, metadata)
```

`holder` aceita source inteiro positivo ou ID não vazio de inventário. Quantidades são inteiros entre 1 e `BGRZConfig.Limits.maxItemAmount`. A allowlist de itens continua obrigatória no resource consumidor.

## Target (client)

```lua
local ok, err = exports.bgrz_core:AddEntityTarget(entityOrNetId, options)
local ok, err = exports.bgrz_core:RemoveEntityTarget(entityOrNetId, optionNames)
local ok, err = exports.bgrz_core:AddSphereZoneTarget({
    name = 'computer:docks',
    coords = vec3(0.0, 0.0, 0.0),
    radius = 2.0,
    options = options,
})
local ok, err = exports.bgrz_core:RemoveZoneTarget('computer:docks')
```

Cada option e cada zona precisam de `name`. O bridge cria nomes internos por caller, impede remoção cruzada, reidrata registros após restart do provider e remove automaticamente opções e zonas quando o resource dono para. A autorização da ação permanece server-side no consumidor.

## Phone (client/server)

```lua
-- client
local ok, err = exports.bgrz_core:RegisterPhoneApp(definition)

-- server
local ok, err = exports.bgrz_core:SendPhoneNotification(source, payload)
```

Apps são registrados por caller. Identificadores não podem colidir entre resources; registros são reidratados após restart do `sd-phone` e removidos quando o dono para. O gate visual de app não substitui autorização server-side.

```lua
-- client: envia uma mensagem para a UI do app registrado pelo próprio caller
local ok, err = exports.bgrz_core:SendPhoneAppMessage('exchange', { action = 'state', data = snapshot })
```

Do ponto de vista do `sd-phone`, quem registrou o app é o **bridge**, porque é ele que invoca
o export. Então o `resourceName` que o provider injeta na página do app aponta para
`bgrz_core`, não para o resource dono. A página do app não deve usar esse valor para montar
a URL dos próprios callbacks: use `GetParentResourceName()`, ou derive de `location.hostname`,
que vem como `cfx-nui-<resource>`.

Somente o resource dono do identificador pode enviar mensagens. A mensagem chega ao iframe do app via `window.postMessage`. Códigos: `invalid_identifier`, `invalid_message`, `not_registered`, `not_owner`, `provider_unavailable`, `operation_failed`.

## Jobs em serviço (server)

```lua
local count, err = exports.bgrz_core:CountOnDutyJob('police')
```

Retorna a quantidade de jogadores em serviço no job informado ou `nil` com `invalid_job`, `provider_unavailable` ou `operation_failed`.

## Dispatch (server)

```lua
local ok, resultOrError = exports.bgrz_core:SendDispatch({
    code = '10-90',
    title = 'Atividade suspeita',
    message = 'Possível venda de drogas',
    coords = { x = 0.0, y = 0.0, z = 0.0 },
    jobs = { 'police' },
    duration = 150,
    radius = 80.0,
})
```

Coordenadas explícitas e finitas são obrigatórias. O adapter tenta `sd-phone:mdtCreateCall`; se o MDT recusar ou falhar, envia `police:client:policeAlert` diretamente apenas aos jobs configurados e em serviço. Em sucesso, o segundo retorno informa `provider`, e também `id` ou `recipients` conforme o caminho.

## Testes

Execute na raiz do resource:

```bash
for spec in tests/unit/*_spec.lua tests/integration/*_spec.lua; do
    lua "$spec" || exit 1
done
```
