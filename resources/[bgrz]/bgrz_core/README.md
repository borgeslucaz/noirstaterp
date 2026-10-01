# bgrz_core

Camada de abstração dos resources Noir/BGRZ sobre Qbox e providers substituíveis.

## Capacidades

`GetCapabilities()` está disponível no client e no server e retorna um snapshot novo:

```lua
{
    version = '0.5.0',
    inventory = { available = boolean, provider = 'ox_inventory', maxItemAmount = 100000 },
    target = { available = boolean, provider = 'ox_target' },
    phone = { available = boolean, provider = 'sky_phone' },
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

```lua
local list, err = exports.bgrz_core:GetItemList()                          -- { { name, label } }, ordenado por label
local ok, err = exports.bgrz_core:HasItemDurability(holder, item, cost)
local ok, err, remaining = exports.bgrz_core:ConsumeItemDurability(holder, item, cost)
```

Durabilidade de ferramenta na escala 0–100 do provider. `cost = 0` só exige posse. Slot sem `durability` conta como 100; slot acima de 100 é item com `degrade` (o provider guarda ali um instante de validade) e é ignorado. Erros: `not_enough_items`, `low_durability`, `invalid_amount`, `provider_unavailable`.

```lua
local minutes, err = exports.bgrz_core:GetItemDegrade(item)                -- validade do item em minutos, ou nil
```

Para quem cria o item gravar a própria validade (`metadata = { durability = instante, degrade = minutes }`) — o `noir_weed` arredonda para a hora cheia, e itens do mesmo lote empilham. Item sem validade devolve `nil` sem erro. Erros: `invalid_item`, `unknown_item`, `provider_unavailable`.

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
local ok, err = exports.bgrz_core:AddLocalEntityTarget(entity, options)
local ok, err = exports.bgrz_core:RemoveLocalEntityTarget(entity, optionNames)
local ok, err = exports.bgrz_core:AddModelTarget(models, options)
local ok, err = exports.bgrz_core:RemoveModelTarget(models, optionNames)
```

Cada option e cada zona precisam de `name`. O bridge cria nomes internos por caller, impede remoção cruzada, reidrata registros após restart do provider e remove automaticamente opções, zonas e models quando o resource dono para. A autorização da ação permanece server-side no consumidor.

`AddModelTarget` cobre o que as outras não cobrem: **prop de mapa**. Parquímetro, lixeira e caixa de correio não são entidades que alguém criou — não têm netId, não existem no servidor, e o handle local muda conforme o streaming carrega a região. `models` aceita nome, hash ou uma lista dos dois; tudo é normalizado para hash uint32 antes de ir ao provider, então nome e hash do mesmo model contam como um registro só. O target é um convite à interação: a distância e a permissão continuam sendo conferidas no servidor do consumidor, que no caso de prop de mapa não consegue resolver a entidade e precisa validar por coordenada.

## Phone (client/server)

```lua
-- client
local ok, err = exports.bgrz_core:RegisterPhoneApp(definition)

-- server
local ok, err = exports.bgrz_core:SendPhoneNotification(source, payload)
```

Apps são registrados por caller. Identificadores não podem colidir entre resources; registros são reidratados após restart do `sky_phone` e removidos quando o dono para. Registrar de novo o mesmo identificador, pelo mesmo dono, atualiza o app. O gate visual de app não substitui autorização server-side.

No `sky_phone` o bridge usa a API de adapter (`AddCustomAppFromAdapter`, `UpdateCustomAppFromAdapter`, `RemoveCustomAppFromAdapter`, `SendCustomAppMessageFromAdapter`): o app fica em nome do resource que chamou, e por isso `ui` e `icon` precisam ser URLs `https://cfx-nui-<dono>/...`. O `bgrz_core` precisa estar em `Config.CustomApps.TrustedAdapters` do `sky_phone`. Da definição, vão para o telefone `identifier` (como `id`), `name`, `description`, `developer`, `ui`, `icon` e `defaultApp` (como `defaultInstalled`); `requires` é validado mas o `sky_phone` não tem gate por item.

```lua
-- server: SMS de sistema pela linha de serviço de uma empresa do sky_phone (ex.: 911 da LSPD)
local ok, sentOrErr = exports.bgrz_core:SendPhoneServiceMessage('police', citizenId, 'texto')
```

`SendPhoneServiceMessage` grava a mensagem na conversa com a linha da empresa e avisa quem estiver com o telefone; com o personagem offline, a mensagem espera nos chips registrados no nome dele. Códigos: `invalid_company`, `invalid_recipient`, `invalid_message`, `no_sim` (personagem sem chip registrado), `provider_unavailable`.

`SendPhoneNotification` vai pelo alias de compatibilidade `qs-smartphone:sendPhoneNotification` do `sky_phone`, que notifica por source sem exigir policy de app. `appId` agrupa a notificação no telefone (sem ele, ou fora do formato `^[a-z0-9][a-z0-9._-]+$`, vai como `noir`); sem `body`, o texto repete o título. O alias não devolve resultado: jogador sem telefone equipado não recebe, e o retorno continua `true`.

```lua
-- client: envia uma mensagem para a UI do app registrado pelo próprio caller
local ok, err = exports.bgrz_core:SendPhoneAppMessage('exchange', { action = 'state', data = snapshot })
```

A página do app não deve confiar no `resourceName` que o telefone injeta para montar a URL
dos próprios callbacks: use `GetParentResourceName()`, ou derive de `location.hostname`, que
vem como `cfx-nui-<resource>`.

Somente o resource dono do identificador pode enviar mensagens. A mensagem chega ao iframe do app via `window.postMessage`. Códigos: `invalid_identifier`, `invalid_message`, `not_registered`, `not_owner`, `provider_unavailable`, `operation_failed`.

## Jobs em serviço (server)

```lua
local count, err = exports.bgrz_core:CountOnDutyJob('police')
```

Retorna a quantidade de jogadores em serviço no job informado ou `nil` com `invalid_job`, `provider_unavailable` ou `operation_failed`.

```lua
local sources, err = exports.bgrz_core:GetOnDutyPlayersByType('leo')  -- todos os jobs da categoria
local ok, err = exports.bgrz_core:SetJobDuty(source, true)
```

`GetOnDutyPlayersByType` devolve os sources em serviço de uma categoria de job (`leo`, `ems`...)
ou `nil` com `invalid_job_type`, `provider_unavailable` ou `operation_failed`. `SetJobDuty`
devolve `false` com `invalid_player`, `invalid_state` ou `provider_unavailable`; a mudança sai
como `bgrz_core:server:dutyUpdated`. `GetJob` (server e client) traz também `type`, a categoria
do job: é ela que diz "é polícia", não o nome.

## Dinheiro (server)

```lua
local balance = exports.bgrz_core:GetMoney(source, 'bank')   -- 0 se o personagem não está carregado
local ok = exports.bgrz_core:RemoveMoney(source, 'cash', amount, 'reason')
local ok = exports.bgrz_core:AddMoney(source, 'cash', amount, 'reason')
```

### Faturas e multas (server)

Cobrança que fica pendente no banco (Renewed-Banking, `bank_invoices`) até o devedor pagar pela agência, caixa ou app Faturas do celular. O valor cai em `issuerAccount`, que precisa ser conta de organização do banco. Multa (`kind = 'fine'`) é bloqueante por padrão: com multa aberta, a conta pessoal não saca nem transfere.

```lua
local id, err = exports.bgrz_core:CreateInvoice({
    recipientSource = target,          -- ou recipientCid
    issuerAccount = 'police',          -- conta de organização
    issuerLabel = 'LSPD',
    issuerSource = source,             -- opcional, ou issuerCid
    kind = 'fine',                     -- 'fine' | 'invoice'
    title = 'Multa de trânsito',
    description = 'Excesso de velocidade',
    amount = 500,
    dueDays = 7,
})
local ok = exports.bgrz_core:CancelInvoice(id, actorCitizenId)
local total, count = exports.bgrz_core:GetBlockingDebt(citizenId)
```

Antes de `bgrz_core:bankingReady`, `CreateInvoice` devolve `provider_not_ready`.

## Médico (server)

```lua
local downed = exports.bgrz_core:IsPlayerDowned(source)   -- caído (last stand) ou morto
local ok, err = exports.bgrz_core:RevivePlayer(source)
```

O provider é `qbx_medical` (`BGRZConfig.Providers.medical`). `IsPlayerDowned` lê o state bag
`isDead` que ele replica. `RevivePlayer` devolve `false` com `invalid_source` ou `provider_unavailable`.

```lua
-- client
local info = exports.bgrz_core:GetDownedInfo()      -- { state = 'laststand'|'dead', seconds } ou nil
local accepted = exports.bgrz_core:RequestRespawn()  -- só morto e com respawn liberado
AddEventHandler('bgrz_core:client:playerRespawned', function() end)
```

`RequestRespawn` substitui o "segure E" do `qbx_medical` para quem prende o teclado numa NUI:
o próprio loop de respawn dele executa no segundo seguinte, sem correr junto com o automático.
`bgrz_core:client:playerRespawned` sai quando o respawn no hospital é aceito — o jogador ainda
fica com `isDead` até levantar da cama.

No servidor, `bgrz_core:server:playerRespawned` (source) sai no mesmo momento. É onde quem
segura o jogador (algema, escolta) solta.

## Remover pelo metadata (server)

```lua
local ok, removed = exports.bgrz_core:RemoveItemsWithMetadata(source, 'vehiclekey', { noirHaul = true })
```

Remove todo slot do item, inclusive os de equipamento, cujo metadata contém os campos
pedidos. Os demais campos do slot não importam. Uma marca vazia é recusada, porque
removeria todos os slots do item.

## Metadata no tooltip (client)

```lua
local ok, err = exports.bgrz_core:DisplayItemMetadata('grade', 'Grau')
```

Mostra o campo do metadata no tooltip de todo item que o tiver ("Grau: A"). Item sem o campo
não ganha linha. Chamar de novo com o mesmo rótulo não duplica. Erros: `invalid_key`,
`invalid_label`, `provider_unavailable`.

## Por slot (server)

```lua
local slots, err = exports.bgrz_core:GetItemSlots(source, 'weed_skunk_baggy') -- { { slot, count, metadata } }, por slot
local ok, err = exports.bgrz_core:RemoveItemFromSlot(source, 'weed_skunk_baggy', amount, slot)
```

Para item cujo metadata separa lotes que o resource distingue, como o grau da droga do
`noir_weed`. O `RemoveItem` do provider só casa metadata idêntico, e a validade gravada no
slot muda de lote para lote. Por isso o resource lê os slots, escolhe e tira de um deles.
O metadata devolvido é uma cópia. `RemoveItemFromSlot` recusa com `not_enough_items_in_slot` quando
o slot não tem a quantidade inteira. Erros: `invalid_item`, `invalid_slot`,
`provider_unavailable`.

## Veículo (server)

```lua
local netId, vehicle = exports.bgrz_core:SpawnVehicle(source, model, coords, warp, plate)
local ok = exports.bgrz_core:GiveVehicleKeys(source, vehicle, plate)
```

`SpawnVehicle` cria no servidor e já entrega a chave. A chave é temporária, do provider
`vehiclekeys` (`mri_Qcarkeys`, pelo `GiveTempKeys`). O `qbx_vehiclekeys` não existe mais aqui.
Quem troca a placa deve passá-la em `GiveVehicleKeys`, porque logo depois de
`SetVehicleNumberPlateText` o servidor ainda pode ler a placa antiga.

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

Coordenadas explícitas e finitas são obrigatórias. O chamado vai para o MDT de `Providers.dispatch` (nesta base o `ps-mdt`, pelo export `mdtCreateCall`), com código, título, prioridade e duração, **e** o aviso com blip vai pelo fallback: `police:client:policeAlert` só para os jobs configurados e em serviço, com o texto `[código] título: mensagem`. Os dois caminhos são independentes; basta um funcionar. Em sucesso, o segundo retorno informa `provider` (o MDT, ou o fallback quando o MDT não respondeu), `id` do chamado no MDT quando houver e `recipients` do aviso.

## Testes

Execute na raiz do resource:

```bash
for spec in tests/unit/*_spec.lua tests/integration/*_spec.lua; do
    lua "$spec" || exit 1
done
```
