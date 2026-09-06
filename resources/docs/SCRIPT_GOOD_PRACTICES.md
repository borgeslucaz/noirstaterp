# Boas práticas para scripts Noir State — Qbox, Cfx.re e `bgrz_core`

## 1. Objetivo

Este documento define o padrão técnico obrigatório para desenvolver novos resources de gameplay no Noir State sobre FiveM/FXServer, Qbox e ecossistema OX.

Ele se aplica especialmente a atividades com NUI, sessão de trabalho, veículos, pagamentos, progressão, itens, NPCs, zonas, callbacks e estado sincronizado. O guia visual dessas interfaces está em `resources/docs/NUI_JOB.md`; este arquivo trata arquitetura, autoridade, integração, segurança, desempenho, ciclo de vida, persistência e manutenção.

As normas foram construídas a partir de:

- implementação instalada em `resources/[bgrz]/bgrz_core`;
- padrões observados em `resources/[standalone]/noir_taxijob`;
- [Developer's Guide oficial do Qbox](https://docs.qbox.re/developers);
- [Release Readiness oficial do Qbox](https://docs.qbox.re/release);
- [convenções de contribuição do Qbox](https://docs.qbox.re/contributors);
- [exports server-side do `qbx_core`](https://docs.qbox.re/resources/qbx_core/exports/server);
- [biblioteca server-side do `qbx_core`](https://docs.qbox.re/resources/qbx_core/modules/lib/server);
- [exports de `qbx_vehiclekeys`](https://docs.qbox.re/resources/qbx_vehiclekeys/exports/server);
- [guia de segurança de eventos da Cfx.re](https://docs.fivem.net/docs/developers/server-security/);
- [documentação de eventos da Cfx.re](https://docs.fivem.net/docs/scripting-manual/working-with-events/);
- [documentação de NUI callbacks da Cfx.re](https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/);
- [documentação de state bags da Cfx.re](https://docs.fivem.net/docs/scripting-manual/networking/state-bags/);
- [documentação de OneSync da Cfx.re](https://docs.fivem.net/docs/scripting-reference/onesync/);
- [documentação de resource manifest da Cfx.re](https://docs.fivem.net/docs/scripting-reference/resource-manifest/);
- [documentação de `Citizen.Wait`](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Wait);
- [profiler da Cfx.re](https://docs.fivem.net/docs/scripting-manual/debugging/using-profiler/).

Sempre conferir a documentação oficial antes de adicionar uma integração nova. APIs e recomendações podem mudar.

---

## 2. Decisão arquitetural central

### 2.1. `bgrz_core` é a ponte obrigatória

O resource existente no repositório chama-se **`bgrz_core`**. Embora “`brgz_core`” possa aparecer informalmente, a grafia canônica em manifests, exports e eventos é `bgrz_core`.

Todo script próprio Noir/BGRZ deve falar com `bgrz_core` para capacidades pertencentes ao framework ou a provedores substituíveis. O resource de gameplay **não deve chamar `qbx_core`, `qbx_vehiclekeys`, `ox_fuel` ou alternativas equivalentes diretamente** quando a capacidade fizer parte do contrato do bridge.

```text
resource de gameplay
        │
        │ API estável Noir/BGRZ
        ▼
    bgrz_core
        │
        ├── adapter Qbox: jogador, job, money, metadata, grupos
        ├── adapter veículos: spawn, persistência, propriedades
        ├── adapter chaves: qbx_vehiclekeys hoje, outro amanhã
        ├── adapter combustível: ox_fuel/native hoje, outro amanhã
        ├── adapter notificações
        └── outros adapters de infraestrutura aprovados
                │
                ▼
       Qbox / OX / provider instalado
```

Isso é uma **camada anticorrupção**: estruturas, nomes, eventos e peculiaridades do Qbox ficam confinados ao bridge. Se chaves, combustível, framework, inventário ou mecanismo de veículos mudar, altera-se um adapter central em vez de cada atividade.

### 2.2. Benefícios obrigatórios

- uma única implementação para trocar provider de chaves;
- uma única implementação para ler/escrever combustível;
- contratos normalizados para dados de jogador;
- motivos de transação e erros padronizados;
- menos dependências diretas em resources de gameplay;
- atualizações do Qbox com menor superfície de quebra;
- testes unitários por adapter;
- observabilidade central de integrações;
- capacidade de adicionar fallback ou feature detection;
- eventos próprios estáveis mesmo se o evento original mudar.

### 2.3. O bridge não é um “god resource”

`bgrz_core` deve conter **integração genérica**, não regras de uma atividade específica.

Pertence ao bridge:

- obter identidade normalizada;
- consultar job/grupo/duty;
- adicionar/remover dinheiro com motivo;
- ler/gravar metadata por contrato;
- notificar;
- criar/deletar veículo temporário por contrato;
- dar/remover/testar chaves;
- ler/definir combustível;
- normalizar lifecycle do jogador;
- adaptar provider de target/inventário quando houver decisão explícita de centralização.

Não pertence ao bridge:

- tabela de níveis de taxista;
- cálculo de recompensa de entrega;
- rota de uma missão;
- cooldown de um assalto;
- catálogo de uma atividade;
- lógica de NPC específica;
- sessão operacional de um job;
- schema SQL do domínio de outro resource;
- textos ou aparência da NUI.

Regra simples: se a função ainda faria sentido sem conhecer qualquer atividade concreta, ela pode pertencer ao bridge. Se contém nome, recompensa, etapa ou configuração de um job, fica no resource do job.

### 2.4. O consumidor depende de contratos, não de providers

Correto:

```lua
local ok, err = exports.bgrz_core:GiveVehicleKeys(source, vehicle)
local fuel = exports.bgrz_core:GetVehicleFuel(vehicle)
```

Incorreto:

```lua
exports.qbx_vehiclekeys:GiveKeys(source, vehicle)
Entity(vehicle).state.fuel = 100
exports.qbx_core:AddMoney(source, 'cash', reward)
```

As chamadas incorretas podem funcionar hoje, mas espalham detalhes do provider e tornam uma migração cara.

---

## 3. Estado atual do `bgrz_core`

No momento desta especificação, `resources/[bgrz]/bgrz_core/fxmanifest.lua` declara versão `0.2.0` e dependências em `ox_lib`, `qbx_core` e `qbx_vehiclekeys`.

### 3.1. Capacidades server-side existentes

| Export | Finalidade |
|---|---|
| `GetCharacter(source)` | personagem normalizado |
| `GetJob(source)` | job atual normalizado |
| `HasJob(source, jobName, requireDuty?)` | valida job/duty |
| `AddMoney(source, account, amount, reason?)` | crédito validado |
| `RemoveMoney(source, account, amount, reason?)` | débito validado |
| `GetMetadata(source, key)` | leitura de metadata |
| `SetMetadata(source, key, value)` | gravação de metadata |
| `GetJobReputation(source, jobName)` | reputação normalizada |
| `AddJobReputation(source, jobName, delta)` | alteração de reputação |
| `Notify(source, message, type?, duration?)` | notificação |
| `SpawnVehicle(source, model, coords, warp?, plate?)` | spawn server-side + chaves |
| `GiveVehicleKeys(source, vehicle)` | entrega de chave via provider atual |

### 3.2. Capacidades client-side existentes

| Export | Finalidade |
|---|---|
| `GetJob()` | job atual normalizado |
| `IsLoggedIn()` | status de personagem carregado |
| `GetMetadata(key?)` | metadata do snapshot local |
| `Notify(message, type?, duration?)` | notificação |
| `GiveVehicleKeys(vehicle)` | solicita chave de veículo networked |

### 3.3. Eventos próprios existentes

Client-side:

- `bgrz_core:client:playerLoaded`;
- `bgrz_core:client:playerUnloaded`;
- `bgrz_core:client:jobUpdated`;
- `bgrz_core:client:dutyUpdated`.

Server-side:

- `bgrz_core:server:playerLoaded`;
- `bgrz_core:server:playerUnloaded`;
- `bgrz_core:server:jobUpdated`;
- `bgrz_core:server:dutyUpdated`.

Resources novos devem consumir esses eventos em vez dos nomes `QBCore:*`.

### 3.4. Lacunas antes de novos consumidores

O bridge atual ainda não expõe contrato público completo para:

- obter saldo sem carregar a estrutura de personagem inteira;
- remover/testar chaves;
- alterar lock state;
- combustível;
- veículo temporário versus persistente de forma explícita;
- remoção segura de veículo criado pelo bridge;
- grupos/ACE normalizados;
- inventário/itens;
- target/zones;
- logging/auditoria genéricos;
- capability/version handshake.

Se um resource novo precisar de uma dessas capacidades, **primeiro ampliar `bgrz_core` com uma API pequena, documentada e testada**; depois consumir essa API. Não contornar a ausência chamando o provider diretamente.

---

## 4. Contratos propostos para adapters

Esta seção define a direção recomendada. Ela não afirma que todos os exports abaixo já existem. Implementá-los no `bgrz_core` somente quando houver consumidor real.

### 4.1. Chaves e travas

Contrato server-side sugerido:

```lua
---@param source number
---@param vehicle number server entity handle
---@param options? { silent?: boolean }
---@return boolean ok
---@return string? errorCode
exports('GiveVehicleKeys', function(source, vehicle, options) end)

---@param source number
---@param vehicle number
---@param options? { silent?: boolean }
---@return boolean ok
---@return string? errorCode
exports('RemoveVehicleKeys', function(source, vehicle, options) end)

---@param source number
---@param vehicle number
---@return boolean hasKeys
exports('HasVehicleKeys', function(source, vehicle) end)

---@param vehicle number
---@param state 'locked'|'unlocked'
---@return boolean ok
---@return string? errorCode
exports('SetVehicleLock', function(vehicle, state) end)
```

O adapter atual traduz para `qbx_vehiclekeys:GiveKeys`, `RemoveKeys`, `HasKeys` e `SetLockState`. O consumidor não conhece os valores internos `'lock'`/`'unlock'`, state bag `keysList` ou session ID de chave.

Regras:

- operação sensível preferencialmente server-side;
- validar `source`, existência da entidade e tipo de veículo;
- se a requisição nasce no client, validar proximidade ou posse no servidor;
- usar entity handle no servidor e net ID somente no transporte;
- nunca aceitar placa enviada pelo client como prova de propriedade;
- nunca entregar chaves apenas porque o client enviou um net ID válido;
- devolver código estável como `invalid_player`, `invalid_vehicle`, `not_near`, `provider_unavailable`.

### 4.2. Combustível

Contrato sugerido:

```lua
---@param vehicle number
---@return number? fuel value clamped to 0..100
---@return string? errorCode
exports('GetVehicleFuel', function(vehicle) end)

---@param vehicle number
---@param amount number
---@param options? { replicate?: boolean, reduceOnly?: boolean }
---@return boolean ok
---@return string? errorCode
exports('SetVehicleFuel', function(vehicle, amount, options) end)
```

No provider instalado, `ox_fuel` documenta leitura por `GetVehicleFuelLevel(vehicle)` ou `Entity(vehicle).state.fuel`, e escrita por state bag. O adapter deve decidir qual é a fonte canônica e esconder essa decisão.

Regras:

- normalizar o intervalo para `0..100`;
- rejeitar `NaN`, infinito, string e entidade inválida;
- definir combustível inicial no fluxo de spawn/propriedades sempre que possível;
- para veículo persistente, manter `fuelLevel` nas propriedades reconhecidas pelo sistema de veículos;
- não permitir que evento de client aumente combustível sem validação de compra/item/regra;
- quando o provider mudar, apenas o adapter muda;
- evitar manter dois valores concorrentes, por exemplo decorator e state bag, sem sincronização claramente definida.

### 4.3. Veículos temporários

Contrato sugerido:

```lua
---@param source number
---@param request {
---  model: string|number,
---  coords: vector3|vector4,
---  warp?: boolean,
---  plate?: string,
---  fuel?: number,
---  lockState?: 'locked'|'unlocked',
---  giveKeys?: boolean,
---  bucket?: number,
---  properties?: table
---}
---@return { netId: number, entity: number }? result
---@return string? errorCode
exports('SpawnTemporaryVehicle', function(source, request) end)
```

O spawn deve ocorrer no servidor via OneSync/Qbox. O Qbox recomenda passar propriedades no próprio `spawnVehicle`, em vez de aplicá-las manualmente depois, pois o client pode não ser o owner da entidade.

Após spawn:

1. validar entidade e net ID;
2. aplicar/confirmar routing bucket;
3. entregar chaves pelo adapter;
4. configurar lock state pelo adapter;
5. configurar combustível pelo adapter ou propriedades iniciais;
6. registrar ownership lógico da sessão do job;
7. devolver somente dados necessários ao consumidor.

Veículo temporário não deve ser inserido em `player_vehicles`.

### 4.4. Veículos persistentes

Veículos possuídos exigem contrato separado, usando APIs públicas de `qbx_vehicles`. O Qbox recomenda definir o state bag `vehicleid` com o ID estável da tabela de veículos e passar propriedades no spawn.

Nunca reutilizar o helper de veículo temporário para criar ownership persistente implicitamente.

Fluxo conceitual:

1. criar registro via API pública de veículos;
2. obter `vehicleId` estável;
3. spawn com properties;
4. definir/confirmar state bag `vehicleid`;
5. entregar chaves via bridge;
6. tratar falhas com compensação, evitando registro órfão ou entidade sem registro.

O resource de gameplay não deve consultar ou alterar diretamente `player_vehicles`.

### 4.5. Economia

Contrato atual de `AddMoney`/`RemoveMoney` deve permanecer a única passagem para dinheiro de jogador.

Melhorias recomendadas:

```lua
---@param source number
---@param account 'cash'|'bank'|'crypto'
---@return number? balance
---@return string? errorCode
exports('GetMoney', function(source, account) end)

---@param source number
---@param account string
---@param amount number
---@param reason string
---@param context? table
---@return boolean ok
---@return string? errorCode
exports('AddMoney', function(source, account, amount, reason, context) end)
```

Regras:

- `amount` finito, positivo e arredondado conforme política econômica;
- `reason` obrigatório em produção, estável e pesquisável;
- cálculo da recompensa no servidor;
- saldo e débito no servidor;
- não usar `SetMoney` para transações normais;
- falha em `RemoveMoney` nunca deve ser ignorada;
- operações com várias escritas precisam de transação/compensação;
- logar valores relevantes sem expor dados sensíveis;
- não confiar no preço enviado pela NUI.

Exemplos de reasons:

```text
resource:action:credit
resource:action:fee
resource:action:refund
```

### 4.6. Jogador, personagem, jobs e grupos

O consumidor usa `GetCharacter`, `GetJob`, `HasJob`, lifecycle e futuros contratos de grupos. Ele não lê `Player.PlayerData` diretamente.

Regras:

- tratar jogador ausente como condição normal durante load/unload;
- não guardar o objeto Qbox `Player` em cache de longo prazo;
- guardar IDs estáveis e buscar estado atual antes de transação;
- grade deve ser numérica e normalizada;
- duty deve ser booleano explícito;
- se job atualizado invalidar a sessão, encerrá-la imediatamente;
- permissões administrativas novas devem usar ACE/ox_lib, pois exports antigos de permissão do Qbox estão depreciados;
- eventos do bridge precisam normalizar payload, não repassar objetos internos inteiros.

### 4.7. Metadata

Metadata é apropriada para dados pequenos ligados ao personagem e que pertencem ao contrato do core. Dados extensos ou consultados frequentemente devem ter storage próprio do resource.

Regras:

- uma chave top-level por domínio, por exemplo `noir_activity`;
- schema versionado dentro do valor quando necessário;
- validar tipo antes de usar;
- copiar tabela antes de mutar quando houver risco de referência compartilhada;
- evitar atualizar metadata a cada tick;
- não armazenar histórico ilimitado;
- não usar metadata como substituto de tabela relacional;
- documentar default e migração.

### 4.8. Inventário e itens

Se scripts Noir precisarem trocar provider de inventário no futuro, adicionar um adapter dedicado no `bgrz_core`, com operações pequenas:

- `HasItem`;
- `CanCarryItem`;
- `AddItem`;
- `RemoveItem`;
- `GetItemCount`.

Regras:

- nomes de item vêm de allowlist server-side;
- quantidade inteira, positiva e limitada;
- metadata de item validada;
- capacidade conferida antes de conceder;
- remoção e recompensa precisam de ordem segura/compensação;
- nunca aceitar item e quantidade arbitrários do client.

### 4.9. Notificações

Todas as notificações próprias usam `bgrz_core:Notify`. O adapter converte tipos próprios para o provider instalado.

Contrato de tipos recomendado:

```text
inform | success | warning | error
```

Textos permanecem localizados no resource consumidor ou em domínio compartilhado explícito. O bridge não deve conhecer mensagens de jobs.

---

## 5. Regras oficiais do Qbox adotadas pelo projeto

### 5.1. Não modificar código do core

O Qbox recomenda não modificar `qbx_core` porque isso dificulta upgrades e diagnóstico. A customização Noir acontece em:

- configuração pública;
- exports/eventos/hooks oficiais;
- adapters do `bgrz_core`;
- resource de domínio próprio.

Se faltar uma capacidade, criar adapter em `bgrz_core` sobre API pública. Se a própria API pública não existir, reavaliar a necessidade e acompanhar o upstream; não editar silenciosamente arquivos internos do Qbox.

### 5.2. Não acessar tabelas de banco pertencentes ao core

O Qbox alerta que acesso direto ao schema de `qbx_core`/`qbx_vehicles` quebra consumidores quando o schema evolui.

Proibido em resources de gameplay:

```sql
SELECT money FROM players ...
UPDATE players SET metadata = ...
INSERT INTO player_vehicles ...
```

Use exports oficiais por meio de `bgrz_core`. Cada resource acessa diretamente somente as tabelas que ele próprio possui.

### 5.3. Não usar APIs depreciadas

- não copiar padrões antigos de QB sem verificar a API Qbox atual;
- não obter “core object” em código Noir novo;
- não usar exports de permissão marcados deprecated;
- não usar utilitários Qbox antigos quando ox_lib/API moderna resolve;
- registrar na documentação do bridge a versão mínima da API upstream.

### 5.4. Usar PlayerData client-side pelo módulo apropriado

O padrão Qbox de release recomenda o módulo de PlayerData no client. No projeto Noir, somente `bgrz_core` importa e interpreta esse módulo; consumidores recebem dados normalizados por export/evento BGRZ.

### 5.5. Configuração modular

Para resources novos, preferir:

```text
config/
├── shared.lua
├── client.lua
└── server.lua
```

Cada arquivo retorna uma tabela. Não permitir que código mutile a configuração em runtime. Segredos, webhooks e regras exclusivamente server-side nunca ficam em `shared.lua`.

### 5.6. Dependências explícitas e estáveis

- declarar dependências reais no manifest;
- verificar versão/capability quando necessário;
- não depender de commit não lançado sem decisão documentada;
- entender que reiniciar uma dependência pode parar/invalidar consumidores;
- evitar dependência em provider direto quando `bgrz_core` já o encapsula.

---

## 6. Estrutura recomendada de resource

```text
noir_activity/
├── fxmanifest.lua
├── README.md
├── config/
│   ├── shared.lua
│   ├── client.lua
│   └── server.lua
├── locales/
│   ├── pt-br.json
│   └── en.json
├── shared/
│   ├── constants.lua
│   └── types.lua
├── client/
│   ├── main.lua
│   ├── state.lua
│   ├── interaction.lua
│   ├── entities.lua
│   └── ui.lua
├── server/
│   ├── 00_security.lua
│   ├── main.lua
│   ├── sessions.lua
│   ├── service.lua
│   └── storage.lua
├── html/
│   ├── index.html
│   ├── main.css
│   ├── app.js
│   ├── fonts/
│   └── img/
└── migrations/
    └── 001_initial.sql
```

Criar apenas arquivos que tenham responsabilidade real. Um script pequeno não precisa imitar toda essa árvore.

### 6.1. Responsabilidades

| Camada | Responsabilidade |
|---|---|
| `config` | valores operacionais, sem estado mutável |
| `shared` | constantes/tipos puros usados nos dois lados |
| `client` | apresentação, input, entidades locais e feedback |
| `server` | autoridade, sessão, validação, recompensa e persistência |
| `storage` | único ponto de SQL pertencente ao resource |
| `html` | apresentação NUI, sem regra econômica |
| `migrations` | mudanças versionadas do schema próprio |

### 6.2. Manifest recomendado

```lua
fx_version 'cerulean'
game 'gta5'

author 'Noir State'
description 'Descrição objetiva do resource'
version '0.1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/fonts/*.woff2',
    'html/img/**/*',
    'locales/*.json',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/*.lua',
}

client_scripts {
    'config/client.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/00_security.lua',
    'server/*.lua',
}

dependencies {
    'ox_lib',
    'bgrz_core',
}
```

Observações:

- `lua54 'yes'` não é necessário em artifacts modernos; a Cfx.re informa que essa diretiva se tornou deprecated porque Lua 5.4 já é o runtime padrão;
- incluir `oxmysql` somente se o resource possuir storage próprio;
- incluir `ui_page`/`files` somente se houver NUI;
- não declarar `qbx_core`, `qbx_vehiclekeys` ou `ox_fuel` no consumidor se toda interação ocorrer pelo bridge;
- declarar providers como dependências de `bgrz_core`, onde o adapter vive;
- não habilitar OAL experimental sem benchmark, testes e compreensão das incompatibilidades.

---

## 7. Autoridade: servidor decide, client apresenta

### 7.1. O client nunca é confiável

A Cfx.re alerta que clientes adulterados podem disparar eventos e manipular valores. Todo dado vindo do client é uma alegação, não um fato.

O client pode enviar:

- intenção (`start`, `cancel`, `accept`);
- identificador opaco selecionado;
- input estritamente necessário;
- net ID como referência candidata;
- sequência/request ID.

O client não decide:

- preço;
- recompensa;
- quantidade concedida;
- item real;
- modelo autorizado;
- nível mínimo;
- job/duty;
- saldo;
- posição válida;
- propriedade do veículo;
- duração da atividade;
- resultado da missão;
- cooldown;
- progressão.

### 7.2. Matriz de validação server-side

Toda ação sensível deve considerar, conforme aplicável:

| Categoria | Validação |
|---|---|
| jogador | conectado e personagem carregado |
| sessão | existe, pertence ao source, não expirou |
| estado | transição permitida a partir do estado atual |
| posição | ped server-side dentro da distância |
| entidade | existe, tipo correto, net ID resolve |
| propriedade | sessão/owner/provider confirma |
| job/grupo | consultado pelo bridge no momento da ação |
| duty | consultado no servidor |
| item | allowlist, quantidade, posse e capacidade |
| dinheiro | conta, saldo, valor e reason |
| tempo | cooldown e janela de ação server-side |
| payload | tipo, tamanho, faixa e enum |
| frequência | rate limit por jogador/ação |

### 7.3. Validação de distância

```lua
local function isNear(source, target, maxDistance)
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - target) <= maxDistance
end
```

Distância do client pode melhorar UX, mas a decisão final usa coordenadas server-side. O Qbox também recomenda a forma `#(vector3 - vector3)` em vez de `GetDistanceBetweenCoords`.

### 7.4. Allowlist

```lua
local catalogById = {}
for i = 1, #config.catalog do
    local entry = config.catalog[i]
    catalogById[entry.id] = entry
end

local function resolveEntry(id)
    if type(id) ~= 'string' or #id > 32 then return nil end
    return catalogById[id]
end
```

O client envia `id`; o servidor resolve model, custo, requisito e recompensa na configuração própria.

### 7.5. Rate limit

Aplicar rate limit antes de trabalho caro e registrar abuso sem inundar logs.

```lua
local nextAllowedAt = {}

local function consumeRateLimit(source, action, intervalMs)
    local now = GetGameTimer()
    local byAction = nextAllowedAt[source] or {}
    nextAllowedAt[source] = byAction
    if (byAction[action] or 0) > now then return false end
    byAction[action] = now + intervalMs
    return true
end
```

Limpar no `playerDropped`/player unload. Para cooldown persistente ou multi-instância, usar relógio/armazenamento apropriado em vez de `GetGameTimer`.

### 7.6. Idempotência

Ações críticas precisam resistir a duplo clique, retry e resposta atrasada:

- bloquear estado `PROCESSING` no servidor antes do await;
- request ID por operação quando necessário;
- não pagar duas vezes pelo mesmo completion ID;
- marca/registro único no banco para entrega única;
- callback repetido devolve resultado conhecido ou `already_processed`;
- liberar lock em erro tratado e cleanup.

---

## 8. Eventos e callbacks

### 8.1. Escolha correta

A Cfx.re diferencia:

- `AddEventHandler`: evento somente no mesmo contexto;
- `RegisterNetEvent`: evento que precisa atravessar client/server.

Não registrar como networked um evento que só circula no servidor ou só no client. Isso reduz superfície de ataque.

### 8.2. Namespace

Usar:

```text
noir_resource:client:eventName
noir_resource:server:eventName
bgrz_core:client:eventName
bgrz_core:server:eventName
```

Nomes descrevem direção/destino, não apenas “doThing”. Evitar eventos globais genéricos.

### 8.3. `source`

Em handler server-side acionado pelo client:

```lua
RegisterNetEvent('noir_activity:server:start', function(itemId)
    local src = source
    -- validar src e payload antes de qualquer await
end)
```

Capturar `source` em variável local antes de operação assíncrona. Nunca aceitar `source` como argumento do client.

### 8.4. Eventos server → client

Se um evento client-side só deveria ser disparado pelo servidor, aplicar a verificação de origem recomendada pela Cfx.re quando compatível com o fluxo:

```lua
RegisterNetEvent('noir_activity:client:applyResult', function(payload)
    if source ~= 65535 then return end
    -- aplicar resultado
end)
```

Isso não torna o client autoritativo; apenas reduz chamadas locais indevidas.

### 8.5. Callbacks OX

Callbacks são adequados para request/response curto. Não manter callback aguardando uma interação humana longa.

Regras:

- validar antes de acessar tabelas;
- retornar envelope estável;
- possuir timeout lógico na UI/client;
- impedir chamadas simultâneas da mesma ação;
- não retornar objetos internos completos;
- usar evento para notificação assíncrona e callback para resposta direta.

### 8.6. NUI callbacks

A Cfx.re exige que `cb` seja chamado em todos os caminhos; caso contrário o `fetch` expira e a falha sobe para o browser.

```lua
RegisterNUICallback('startAction', function(data, cb)
    if Ui.state ~= 'READY' then
        cb({ ok = false, code = 'invalid_state' })
        return
    end

    local id = type(data) == 'table' and data.id or nil
    if type(id) ~= 'string' then
        cb({ ok = false, code = 'invalid_id' })
        return
    end

    local result = lib.callback.await('noir_activity:server:start', false, id)
    cb(result or { ok = false, code = 'internal_error' })
end)
```

No browser:

```js
const resource = typeof GetParentResourceName === "function"
  ? GetParentResourceName()
  : "noir_activity";

async function post(name, data = {}) {
  try {
    const response = await fetch(`https://${resource}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data),
    });
    return await response.json();
  } catch {
    return { ok: false, code: "transport_error" };
  }
}
```

Dados nos dois sentidos precisam ser serializáveis em JSON. Não enviar vector userdata, entity handle Lua, função ou referência circular diretamente à NUI.

---

## 9. Sessões e máquinas de estado

### 9.1. Sessão server-side

Atividades com recompensa, veículo ou progressão devem possuir sessão autoritativa por jogador.

Exemplo conceitual:

```lua
local sessions = {}

sessions[source] = {
    id = createOpaqueSessionId(),
    state = 'READY',
    startedAt = os.time(),
    expiresAt = os.time() + config.sessionTtl,
    selectedId = nil,
    vehicleNetId = nil,
    progress = 0,
}
```

Não usar token previsível como apenas `source` ou timestamp. O token serve para correlacionar e reduzir confusão de sessão; ainda assim, toda ação revalida o source.

### 9.2. Transições explícitas

```text
CLOSED → OPENING → READY
READY → PROCESSING → READY
READY → ACTIVE → COMPLETING → READY
READY/ACTIVE → CLOSING → CLOSED
qualquer estado → ABORTED/CLOSED por cleanup
```

Defina tabela de transições válidas ou funções guard. Não permitir que duas ações mudem o mesmo estado concorrentemente.

### 9.3. Cleanup

Limpar sessão e entidades em:

- término normal;
- cancelamento;
- morte, quando aplicável;
- troca de job/duty que invalide a atividade;
- player unload;
- `playerDropped`;
- `onResourceStop`;
- entidade removida;
- timeout;
- falha parcial.

Cleanup precisa ser idempotente. Se uma entidade já não existir ou uma sessão já tiver sido removida, retornar sem erro.

### 9.4. Fonte do tempo

- `GetGameTimer`: intervalos curtos no mesmo processo;
- `os.time`: expiração server-side em segundos;
- timestamp do banco: persistência/concorrência entre reinícios;
- nunca usar `Date.now()` da NUI para determinar recompensa ou cooldown.

---

## 10. Entidades e OneSync

### 10.1. Criação server-side

Preferir entidades criadas no servidor por APIs OneSync/Qbox. Isso dá ao servidor controle do ciclo de vida e reduz dependência do network owner client-side.

Para veículos, usar o adapter `bgrz_core`, que internamente pode usar `qbx.spawnVehicle`.

### 10.2. Handles e net IDs

- entity handle é local ao contexto;
- net ID é referência transportável, não autorização;
- resolver com `NetworkGetEntityFromNetworkId` no servidor;
- depois validar `DoesEntityExist`, `GetEntityType`, model, distância e vínculo com sessão;
- não guardar apenas handle de client no servidor;
- aguardar replicação com limite de tentativas, nunca loop infinito.

### 10.3. Ownership e migração

Não presumir que o client que pediu o spawn continuará network owner. Configurações relevantes devem nascer no spawn server-side ou ser gravadas pelo servidor em state bag/propriedades.

### 10.4. Persistência

Use persistência somente quando a entidade precisa sobreviver à distância/relevância/restart conforme domínio. Para entidades que precisam permanecer no servidor, seguir a orientação OneSync e avaliar orphan mode `KeepEntity`. Não marcar toda entidade como persistente por padrão.

### 10.5. Routing buckets

- player e entidades relacionadas precisam estar no mesmo bucket;
- validar bucket no servidor;
- alocar IDs sem colisão;
- restaurar bucket no cleanup;
- bucket isola roteamento, não substitui validação de segurança;
- não usar bucket para instanciar interiores que dependam de comportamento populacional sem avaliar limitações.

### 10.6. Deleção

- servidor que cria deve ser capaz de remover;
- confirmar existência antes de deletar;
- desvincular sessão/registry mesmo se a entidade já sumiu;
- remover chaves/estado lógico quando aplicável;
- para veículo persistente, distinguir deletar entidade de deletar registro;
- nunca apagar registro permanente ao apenas despawnar.

---

## 11. State bags

### 11.1. Uso adequado

State bags servem a pequenos estados replicados ligados a entidade, jogador ou mundo:

- `vehicleid`;
- combustível;
- lock state;
- flag operacional pequena;
- identificador de sessão de entidade não sensível.

Não são banco de dados nem local para payload grande.

### 11.2. Estrutura rasa

A Cfx.re explica que getters/setters serializam o estado inteiro e mutação aninhada não replica como esperado.

Evitar:

```lua
Entity(vehicle).state.activity.status = 'active'
```

Preferir chaves granulares:

```lua
Entity(vehicle).state:set('noir:activityStatus', 'active', true)
Entity(vehicle).state:set('noir:activityOwner', citizenId, true)
```

### 11.3. Autoridade

Por padrão, owner client-side pode escrever state da entidade. Portanto:

- state bag replicado não é prova de autorização;
- valores econômicos/progressão nunca dependem apenas dele;
- servidor valida antes de consumir;
- servidor deve ser o writer de estados autoritativos;
- avaliar `sv_stateBagStrictMode` no nível do servidor conforme compatibilidade global, pois a Cfx.re documenta que ele restringe escrita ao servidor.

### 11.4. Change handlers

Usar `AddStateBagChangeHandler` para reagir a mudança, evitando polling, mas:

- filtrar key e bag;
- resolver entidade com segurança;
- considerar que entidade pode ainda não existir localmente;
- handler pode disparar mais de uma vez;
- operação deve ser idempotente;
- remover hooks próprios quando API/provider exigir.

---

## 12. Banco de dados e persistência própria

### 12.1. Propriedade do schema

Cada resource lê/escreve diretamente somente tabelas que ele criou e versiona. Dados de Qbox, veículos, inventário e banking são acessados por APIs públicas/bridge.

### 12.2. Storage isolado

Centralizar SQL em `server/storage.lua` ou diretório `server/storage/`. Outras camadas chamam funções de domínio, não espalham queries.

### 12.3. Queries

- sempre parametrizadas;
- nunca concatenar input em SQL;
- selecionar somente colunas necessárias;
- índices para filtros e ordenações frequentes;
- limite em ranking/listagens;
- evitar query por jogador dentro de loop quando uma consulta em lote resolve;
- usar operação await somente onde a sequência depende do resultado;
- tratar retorno `nil` e falha.

### 12.4. Transações

Usar transação quando várias escritas precisam ser atômicas:

- consumir item + registrar entrega;
- debitar + criar compra persistente;
- atualizar progressão + inserir histórico obrigatório.

APIs externas ao banco podem exigir compensação porque não participam da mesma transação SQL.

### 12.5. Migrações

- arquivos numerados e imutáveis depois de aplicados;
- uma mudança lógica por migration;
- defaults compatíveis com dados existentes;
- índices e constraints explícitos;
- documentar rollback quando possível;
- não executar DDL a cada start do resource sem motivo;
- manter schema versionado.

### 12.6. Identidade

- `source` é efêmero e vale só durante a conexão;
- `citizenId` identifica personagem persistente;
- identificadores de conta/license têm outro domínio;
- registrar claramente qual identidade uma tabela usa;
- não misturar source com citizen ID em chave persistente.

---

## 13. Concorrência e falhas parciais

Lua cooperativa não elimina concorrência lógica: qualquer `await`/`Wait` permite que outro fluxo rode.

### 13.1. Lock por jogador/ação

```lua
if session.state ~= 'READY' then
    return { ok = false, code = 'request_in_progress' }
end

session.state = 'PROCESSING'
local ok = performOperation()
session.state = ok and 'ACTIVE' or 'READY'
```

Definir o lock **antes** do primeiro await.

### 13.2. Compensação

Exemplo: débito realizado, spawn falhou.

1. tentar spawn;
2. se falhar, devolver exatamente o valor debitado com reason de refund;
3. registrar erro e compensação;
4. não deixar sessão em `PROCESSING`;
5. responder erro seguro ao jogador.

Evitar debitar antes de validar espaço/model/estado quando a ordem puder reduzir compensações.

### 13.3. Timeouts

- todo retry tem limite;
- toda espera por entidade tem máximo de tentativas;
- sessão tem TTL;
- NUI não bloqueia para sempre;
- timeout não significa automaticamente que operação não ocorreu: usar idempotência antes de repetir transação.

---

## 14. Loops, threads e desempenho

### 14.1. Event-driven primeiro

O Qbox recomenda não criar threads desnecessárias. Preferir:

- eventos de load/unload/job/duty;
- ox_target/zones;
- callbacks;
- state bag change handlers;
- cache do ox_lib;
- timer somente enquanto uma sessão está ativa.

### 14.2. Todo loop espera

A Cfx.re alerta que `while true` sem `Wait` pode travar o jogo.

```lua
CreateThread(function()
    while active do
        -- trabalho limitado
        Wait(500)
    end
end)
```

### 14.3. Sleep adaptativo

```lua
CreateThread(function()
    while enabled do
        local sleep = 1500
        local distance = #(GetEntityCoords(cache.ped) - target)

        if distance < 30.0 then sleep = 250 end
        if distance < 3.0 then
            sleep = 0
            -- somente desenho/input que exige frame
        end

        Wait(sleep)
    end
end)
```

Use `Wait(0)` apenas para comportamento que precisa de cada frame. Distância, validação e estado raramente precisam rodar a cada frame.

### 14.4. Escopo do loop

- loop de job apenas para jogador elegível;
- loop de sessão apenas enquanto sessão existe;
- loop de NUI apenas enquanto visível;
- sair imediatamente no unload/stop;
- não varrer todos os players/entidades a cada tick;
- processar em lote quando possível.

### 14.5. Natives e cache

- usar `cache.ped`, `cache.vehicle` e mecanismos equivalentes do ox_lib;
- evitar native caro por frame;
- armazenar hash constante com literal CfxLua/backtick ou `joaat` uma vez;
- não chamar `PlayerPedId()` dezenas de vezes no mesmo frame;
- medir antes de micro-otimizar.

### 14.6. Estruturas Lua

Seguir convenções Qbox:

- quatro espaços;
- variáveis/funções locais em `camelCase`;
- APIs globais em `PascalCase`;
- preferir `local` a global;
- nomes descritivos;
- booleanos com `is`/`has` quando ajuda;
- arrays no plural;
- `items[#items + 1] = value` em vez de `table.insert` no hot path;
- reduzir duplicação com função pequena e testável;
- anotar exports com LuaLS.

### 14.7. Profiling

Não declarar performance “boa” por impressão. Medir:

- `resmon true` para CPU/memória por resource;
- `profiler record 500` em client e servidor;
- `profiler status`;
- `profiler view` ou `profiler saveJSON`;
- NUI devtools para render, listeners e network;
- cenários parado, perto da interação, menu aberto, atividade ativa e muitos jogadores.

Registrar baseline e resultado depois de otimização relevante.

---

## 15. NUI e foco

### 15.1. Separação

- Lua envia snapshot/estado;
- browser formata e apresenta;
- browser envia intenção/ID;
- servidor valida e executa;
- browser nunca calcula regra autoritativa.

### 15.2. Envelope

```lua
SendNUIMessage({
    action = 'noirActivity:setState',
    data = snapshot,
})
```

Namespace evita colisões. Frontend usa allowlist de handlers e ignora mensagens desconhecidas.

### 15.3. Prontidão

Depois de registrar listeners, NUI envia `uiReady`. O client reenvia:

- visibilidade;
- snapshot atual;
- menu aberto, se aplicável;
- keybinds exibidos.

Isso torna reload do CEF recuperável.

### 15.4. Foco

- `SetNuiFocus(true, true)` somente após abertura autorizada;
- `SetNuiFocusKeepInput(false)` para menu modal normal;
- HUD informativo não captura foco;
- menu aberto oculta HUD sobreposto quando necessário;
- fechar por Escape/botão, morte, unload, distância, veículo e resource stop;
- `SetNuiFocus(false, false)` sempre no cleanup.

### 15.5. Fechamento seguro

Para saída animada:

1. NUI pede fechamento;
2. client verifica estado crítico;
3. NUI anima;
4. NUI envia `closeComplete`;
5. client libera foco;
6. timeout de segurança libera foco se o browser não responder.

Nunca depender exclusivamente do evento visual para liberar o jogador.

### 15.6. Estado completo e updates

- snapshot completo ao abrir e em reidratação;
- update incremental apenas para valores frequentes;
- cada snapshot suficiente para reconstruir a tela;
- limpar timers/listeners/estado ao fechar;
- não enviar mensagens por frame.

### 15.7. Segurança do browser

- `textContent` para dados externos;
- sem `eval`;
- sem HTML arbitrário do servidor;
- sem CDN;
- sem segredo no bundle;
- validar comprimento de texto/URL;
- `GetParentResourceName()` em callback, nunca nome hardcoded em produção;
- tratar fetch rejeitado e JSON inválido.

Para aparência e acessibilidade, seguir `resources/docs/NUI_JOB.md`.

---

## 16. Keybinds e input

### 16.1. Key mapping editável

Usar `RegisterCommand` + `RegisterKeyMapping` para ações configuráveis pelo jogador. A Cfx.re documenta que esses bindings aparecem nas configurações de teclas.

```lua
RegisterCommand('+noirActivityAction', function()
    if not canUseAction() then return end
    performLocalIntent()
end, false)

RegisterCommand('-noirActivityAction', function()
end, false)

RegisterKeyMapping(
    '+noirActivityAction',
    'Noir: ação da atividade',
    'keyboard',
    'E'
)
```

### 16.2. Regras

- nome do comando namespaced e estável;
- label legível para o jogador;
- tecla é default, não verdade fixa;
- NUI recebe/exibe o binding efetivo quando possível;
- não usar `IsControlJustPressed` em loop permanente se key mapping resolve;
- respeitar chat, pause menu, NUI focus, morte e estados bloqueados;
- não registrar duas ações no mesmo comando;
- cleanup de estado “pressionado” em unload/fechamento.

### 16.3. Bridge e key logic

Keybind de gameplay específico fica no resource. A **lógica de chaves de veículo** fica em `bgrz_core`. São conceitos diferentes e não devem ser misturados.

---

## 17. NPCs, models, animações e zonas

### 17.1. Models

```lua
local model = joaat(config.pedModel)
lib.requestModel(model)
-- criar entidade
SetModelAsNoLongerNeeded(model)
```

Regras:

- model vem de configuração allowlisted;
- validar `IsModelInCdimage`/tipo quando input não for totalmente estático;
- timeout no carregamento;
- liberar model;
- não solicitar o mesmo model repetidamente;
- entidade de cenário tem cleanup.

### 17.2. NPCs

- preferir spawn local para decoração sem autoridade, quando apropriado;
- para NPC de missão relevante, definir ownership/ciclo de vida conscientemente;
- congelar/invencível/bloquear events apenas quando necessário;
- target é convite à interação, não autorização;
- servidor revalida distância e sessão.

### 17.3. Zonas

- criar uma vez e remover no cleanup;
- evitar polling manual de dezenas de coordenadas;
- callback de zona só atualiza estado local/UX;
- ação sensível continua validada server-side;
- configurar debug de zona somente em desenvolvimento.

### 17.4. Animações

- solicitar anim dict com timeout;
- interromper em morte/cancel/unload;
- limpar tasks com cuidado para não quebrar outro sistema;
- servidor não concede resultado só porque o client informou fim da animação;
- duração crítica controlada/validada pela sessão.

---

## 18. Progressão, recompensa e anti-exploit

### 18.1. Fonte autoritativa

Servidor guarda:

- início;
- etapa atual;
- objetivos escolhidos;
- distância/tempo acumulado relevante;
- limites;
- completion já processado;
- recompensa calculada;
- progressão concedida.

### 18.2. Recompensa

Calcular a partir de dados server-side/configuração:

```lua
local reward = calculateReward({
    base = entry.baseReward,
    verifiedDistance = session.distance,
    verifiedDuration = elapsed,
    serverModifiers = modifiers,
})
```

Aplicar:

- mínimo/máximo;
- arredondamento;
- limites por tempo/distância;
- razão econômica;
- reason de money;
- log de outlier;
- uma concessão por completion ID.

### 18.3. Movimento e teleporte

Quando distância influencia resultado:

- acumular deltas server-authoritative ou validados;
- rejeitar salto acima do máximo plausível por intervalo;
- limitar distância tarifável/recompensável;
- contar ocorrências impossíveis;
- cancelar ou reduzir resultado conforme regra documentada;
- não confiar na distância total enviada no final pelo client.

### 18.4. Randomização

- escolha de objetivo no servidor;
- seed/resultado não enviado antes da necessidade;
- lista de candidatos allowlisted;
- evitar `math.random` para token de segurança; usar identificador opaco apropriado;
- aleatoriedade de gameplay não substitui validação.

---

## 19. Configuração e localização

### 19.1. Shared versus server

Shared pode conter:

- labels públicas;
- coordenadas que o client precisa;
- limites visuais;
- IDs de catálogo apresentados;
- defaults de keybind.

Server-only deve conter:

- recompensas reais quando ocultação for útil;
- regras anti-exploit;
- webhooks/tokens;
- detalhes de storage;
- limites de rate limit;
- providers sensíveis;
- regras que o client não precisa.

Não tratar shared config como segredo: ela é enviada ao jogador.

### 19.2. Imutabilidade

Config retorna tabela e não é usada como storage runtime. Estado fica em estruturas próprias. Não adicionar campos de sessão dentro de `Config`.

### 19.3. Locales

- nenhuma string de jogador espalhada por server/client/browser sem motivo;
- código de erro estável, tradução local;
- placeholder tipado/limitado;
- locale padrão e fallback;
- manter acentos em UTF-8;
- não enviar stack trace ou erro SQL ao jogador.

---

## 20. Erros, logs e observabilidade

### 20.1. Envelope de resultado

```lua
return {
    ok = false,
    code = 'no_spawn_space',
}
```

Códigos são estáveis e legíveis por máquina. Texto é localizado separadamente.

### 20.2. Classificação

| Tipo | Exemplo | Tratamento |
|---|---|---|
| input inválido | ID/tipo/faixa | rejeitar, possível contador |
| estado inválido | ação concorrente | resposta previsível |
| regra de negócio | saldo/job/requisito | mensagem normal |
| provider indisponível | dependency stop/export falhou | log error + fallback seguro |
| falha interna | exceção/SQL | correlation ID, texto genérico ao player |
| suspeita | teleporte/event spam | log estruturado e política anti-exploit |

### 20.3. Logs

O Qbox recomenda substituir prints soltos por `lib.print`. Usar níveis e contexto:

```lua
lib.print.error(('[noir_activity] spawn failed source=%s code=%s'):format(src, code))
```

Não logar:

- token de sessão reutilizável;
- license/identificador completo sem necessidade;
- payload inteiro com dados pessoais;
- credenciais;
- cada tick normal;
- erro esperado como stack trace ruidoso.

### 20.4. Métricas operacionais úteis

- sessões abertas/ativas;
- completions e cancelamentos;
- falhas por code;
- compensações/refunds;
- spawn failure;
- callback latency;
- rate limits atingidos;
- resource/provider indisponível.

---

## 21. Lifecycle de resources e dependências

### 21.1. Ordem

Provider inicia antes do bridge; bridge antes do consumidor:

```text
ox_lib / oxmysql
qbx_core e providers
bgrz_core
resources Noir/BGRZ consumidores
```

Manifest deve expressar dependências essenciais; não depender apenas da ordem no `server.cfg`.

### 21.2. Resource stop

No consumidor:

```lua
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- liberar NUI focus, zones, peds, vehicles, blips, timers e estado
end)
```

No bridge, adapters devem lidar com provider ausente de forma segura e retornar `provider_unavailable`, não explodir consumidores com nil access.

### 21.3. Restart de bridge/provider

Como reinício pode invalidar estado:

- não fazer hot restart de core/provider em produção com atividade crítica ativa;
- reidratar capability/estado quando possível;
- consumidores tratam `bgrz_core` stop como encerramento seguro;
- bridge documenta se um adapter mantém memória transitória;
- não presumir que entity handles sobreviveram.

### 21.4. Versionamento de API

Mudança compatível:

- campo opcional novo;
- export novo;
- código de erro novo documentado.

Mudança breaking:

- remover/renomear export;
- trocar tipo/semântica;
- tornar campo obrigatório;
- alterar unidade.

Em breaking change, versionar contrato, atualizar consumidores em conjunto e registrar migration guide.

---

## 22. Testabilidade

### 22.1. Funções puras

Extrair para funções puras:

- cálculo de recompensa;
- progressão;
- validação de payload;
- transição de estado;
- formatação de resposta;
- escolha de candidato.

I/O com Qbox, banco, entities e relógio fica nas bordas.

### 22.2. Adapter testável

Cada adapter deve permitir simular provider:

```lua
local vehicleKeysProvider = {
    give = function(source, vehicle, options) end,
    remove = function(source, vehicle, options) end,
    has = function(source, vehicle) end,
}
```

O contrato BGRZ é testado contra fake; o adapter real recebe teste de integração.

### 22.3. Casos mínimos

- jogador não carregado;
- disconnect durante await;
- job/duty muda durante sessão;
- ID inválido/desconhecido;
- entidade não existe;
- net ID de entidade distante/alheia;
- saldo insuficiente;
- débito ok + spawn falha;
- duplo clique;
- callback repetido;
- provider parado;
- imagem/NUI indisponível;
- resource stop com foco;
- timeout de sessão;
- banco indisponível;
- valor negativo, enorme, NaN/string;
- veículo migra de owner;
- state bag atrasada.

### 22.4. Teste de carga

Simular múltiplos jogadores iniciando/finalizando, catálogo/ranking simultâneo e spam dentro do rate limit. Observar query count, hitch, CPU, memória e entidades órfãs.

---

## 23. Checklist para ampliar `bgrz_core`

Antes de adicionar um adapter/export:

- [ ] Há consumidor real e capacidade genérica?
- [ ] A lógica não pertence a um job específico?
- [ ] Existe API pública oficial do provider?
- [ ] O adapter evita acesso a tabela/código interno do Qbox?
- [ ] Assinatura usa tipos normalizados BGRZ?
- [ ] Entrada possui validação de tipo/faixa/entidade?
- [ ] Operação sensível é server-side?
- [ ] Client request recebe validação de distância/posse?
- [ ] Retorno é estável (`ok`, valor e/ou `errorCode`)?
- [ ] Provider ausente é tratado?
- [ ] Export tem anotação LuaLS?
- [ ] API foi documentada?
- [ ] Existe teste de sucesso e falha?
- [ ] Evento upstream foi reemitido com payload normalizado quando necessário?
- [ ] Não há estado de domínio armazenado no bridge?
- [ ] Dependência/provider consta no manifest do bridge?
- [ ] Mudança mantém consumidores existentes?

---

## 24. Checklist para novo resource

### Arquitetura

- [ ] Regras de domínio ficam no resource.
- [ ] Integrações framework/provider passam por `bgrz_core`.
- [ ] Não há chamada direta a `qbx_core` no consumidor.
- [ ] Não há chamada direta a `qbx_vehiclekeys`/`ox_fuel` no consumidor.
- [ ] Não há query em tabela pertencente a outro resource.
- [ ] Dependências são mínimas, explícitas e estáveis.
- [ ] Config está separada em shared/client/server conforme sigilo.
- [ ] Storage próprio está isolado.

### Segurança

- [ ] Toda ação sensível é validada no servidor.
- [ ] Client envia apenas intenção e IDs.
- [ ] `source` vem do runtime, nunca do payload.
- [ ] ID/model/item pertencem a allowlist.
- [ ] Posição é verificada server-side.
- [ ] Entidade/net ID é resolvida e validada.
- [ ] Job, grade, duty, saldo e itens são consultados no servidor.
- [ ] Existe rate limit.
- [ ] Existe idempotência para recompensa/transação.
- [ ] Quantidades possuem faixa máxima.
- [ ] Não há evento networked desnecessário.
- [ ] Evento local usa `AddEventHandler`.

### Estado e concorrência

- [ ] Sessão server-side possui state e TTL.
- [ ] Transições permitidas são explícitas.
- [ ] Lock é definido antes de await.
- [ ] Cleanup é idempotente.
- [ ] Player drop/unload limpa memória.
- [ ] Job/duty update invalida sessão quando necessário.
- [ ] Falha parcial possui compensação.
- [ ] Toda espera/retry tem limite.

### Veículos

- [ ] Spawn é server-side pelo bridge.
- [ ] Temporário e persistente são fluxos diferentes.
- [ ] Properties são passadas no spawn quando possível.
- [ ] Veículo persistente usa `vehicleid` state bag.
- [ ] Chaves passam pelo adapter.
- [ ] Lock passa pelo adapter.
- [ ] Combustível passa pelo adapter.
- [ ] Net ID não é tratado como autorização.
- [ ] Entidade possui owner lógico e cleanup.

### Economia e persistência

- [ ] Reward/cost são calculados no servidor.
- [ ] Money passa pelo bridge com reason.
- [ ] Falha de débito é tratada.
- [ ] Dupla concessão é impossível.
- [ ] SQL é parametrizado.
- [ ] Queries pertencem somente ao schema próprio.
- [ ] Operações atômicas usam transação/compensação.
- [ ] Migration está versionada.
- [ ] `source` não é persistido como identidade.

### Performance

- [ ] Não existem threads desnecessárias.
- [ ] Todo loop chama `Wait`.
- [ ] Sleep aumenta quando longe/inativo.
- [ ] `Wait(0)` aparece apenas quando cada frame é necessário.
- [ ] Job loop roda somente para elegíveis/ativos.
- [ ] Natives frequentes são cacheadas quando seguro.
- [ ] Não há query em loop por frame.
- [ ] State bag substitui polling somente quando adequado.
- [ ] `resmon` e profiler foram usados em cenários reais.

### NUI

- [ ] Todo NUI callback chama `cb` em todos os caminhos.
- [ ] Payload e retorno são JSON-safe.
- [ ] Fetch usa `GetParentResourceName()`.
- [ ] Browser trata erro de transporte.
- [ ] Snapshot completo reidrata a tela.
- [ ] `uiReady` está implementado.
- [ ] Foco é liberado no fechamento e resource stop.
- [ ] Saída animada possui timeout de segurança.
- [ ] NUI não calcula regra autoritativa.
- [ ] Design segue `NUI_JOB.md`.

### Qualidade

- [ ] Código usa quatro espaços e naming consistente.
- [ ] Globals são evitadas.
- [ ] Exports têm LuaLS annotations.
- [ ] Não há API deprecated.
- [ ] Logs usam níveis e contexto.
- [ ] README/API/config/migrations estão documentados.
- [ ] Estados de falha foram testados.
- [ ] Não há foco, entidade, zone, blip ou timer órfão após restart.

---

## 25. Anti-padrões proibidos

- editar `qbx_core` para atender um único script;
- importar `QBCore`/core object em resource Noir novo;
- ler `players`, `player_vehicles` ou tabelas de provider diretamente;
- chamar Qbox/chaves/fuel diretamente fora de `bgrz_core`;
- colocar regra de job dentro de `bgrz_core`;
- confiar em preço/reward/model/item enviado pelo client;
- usar net ID, placa ou state bag como prova única de posse;
- registrar todo evento como `RegisterNetEvent`;
- esquecer `cb` em retorno de erro NUI;
- aguardar entidade sem timeout;
- pagar antes de validar completion/idempotência;
- deixar estado `PROCESSING` após falha;
- criar veículo de job no client sem necessidade;
- aplicar properties persistentemente depois do spawn por owner incerto;
- duplicar combustível em decorator/state bag/native sem fonte canônica;
- usar `while true` sem `Wait`;
- rodar distância a cada frame quando 250–1500ms atende;
- guardar objeto Player Qbox por toda a sessão;
- persistir `source` como identidade;
- guardar segredo em shared config/NUI;
- logar tokens e payloads sensíveis;
- deixar NUI focus preso em stop/error;
- criar migration destrutiva sem estratégia;
- engolir erro de provider e fingir sucesso.

---

## 26. Exemplo completo de fluxo

Exemplo genérico de uma atividade que cria veículo temporário e inicia sessão:

```text
1. Client detecta interação via target.
2. Client chama callback server `openActivity` sem enviar preço/job/reward.
3. Server obtém personagem/job via bgrz_core.
4. Server valida distância, elegibilidade, cooldown e ausência de sessão.
5. Server cria sessão opaca e monta snapshot.
6. Client recebe snapshot, captura foco e abre NUI.
7. Jogador escolhe item; NUI envia somente itemId.
8. Client valida forma básica e encaminha callback.
9. Server aplica rate limit, valida sessão/estado/distância/item.
10. Server resolve model/custo/requisito na config server-side.
11. Server define sessão como PROCESSING.
12. Server remove dinheiro via bgrz_core, se houver custo.
13. Server pede SpawnTemporaryVehicle ao bgrz_core com properties/fuel.
14. Bridge usa qbx.spawnVehicle e adapters de keys/lock/fuel.
15. Em falha, server compensa débito via bgrz_core e restaura READY.
16. Em sucesso, server vincula netId à sessão e entra em ACTIVE.
17. Resposta `ok` retorna; NUI confirma e fecha.
18. Client conclui animação, informa closeComplete e libera foco.
19. Durante atividade, updates necessários vêm do servidor/sessão.
20. Completion é validado por estado, tempo, distância e entidade.
21. Server calcula reward e paga uma vez via completion ID.
22. Server atualiza storage próprio e devolve snapshot de resultado.
23. Cleanup remove veículo temporário, chaves/estado e sessão.
24. Drop, unload, stop e timeout executam o mesmo cleanup idempotente.
```

Essa sequência é referência estrutural. A atividade concreta pode não ter custo, veículo, NUI ou progressão.

---

## 27. Resumo normativo

Para qualquer novo script Noir State:

1. O resource contém seu domínio; `bgrz_core` contém integração genérica.
2. Toda dependência do Qbox ou de provider substituível passa pelo bridge.
3. Se faltar chave, combustível ou outra capacidade, ampliar primeiro o `bgrz_core`.
4. Não modificar o core nem consultar tabelas que outro resource possui.
5. O servidor é autoritativo para estado, posição, permissão, entidade, item, dinheiro e recompensa.
6. O client e a NUI enviam intenção, nunca verdade econômica.
7. Eventos têm escopo mínimo, payload validado, namespace e rate limit.
8. Callbacks sempre respondem.
9. Sessões usam máquina de estado, TTL, idempotência e cleanup.
10. Veículos são criados server-side; temporários e persistentes não se confundem.
11. Chaves, trava e combustível são contratos do bridge.
12. State bags são rasas, pequenas e nunca prova única de segurança.
13. Loops são raros, condicionais e medidos com profiler/resmon.
14. Storage é isolado, parametrizado, versionado e pertence ao próprio resource.
15. Toda falha parcial tem retorno seguro e, quando necessário, compensação.
16. NUI possui reidratação, foco seguro e fechamento com fallback.
17. Código público, config e migrations são documentados e testados.

O resultado esperado é um conjunto de atividades independentes do Qbox em sua superfície de domínio, mas plenamente integradas por uma ponte única e substituível. Quando o servidor trocar chaves, combustível, veículos ou outra infraestrutura, a mudança deve se concentrar no `bgrz_core`, não se espalhar por todos os scripts.
