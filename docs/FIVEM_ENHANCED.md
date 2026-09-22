# FiveM Enhanced — Guia de Desenvolvimento (Lua + TypeScript)

Guia interno para desenvolvimento de resources exclusivamente para **FiveM for GTAV Enhanced**.

Foco: Lua/CfxLua 5.4, TypeScript → JavaScript, networking, entidades, eventos, State Bags, NUI/DUI, performance e compatibilidade.

Última revisão das regras do Enhanced: **2026-09-22**.

---

## 1. Objetivo

Este documento deve ser usado como **regra de desenvolvimento** para resources novos.

O objetivo **não** é manter compatibilidade automática com FiveM Legacy. Quando houver diferença entre Legacy e Enhanced, o comportamento do **Enhanced tem prioridade**.

### Stack esperada

- FiveM for GTAV Enhanced
- `fxmanifest.lua`
- Lua / CfxLua 5.4
- TypeScript compilado para JavaScript
- Qbox quando o resource depender de framework
- `ox_lib`, `ox_target` e demais resources explicitamente declarados como dependência
- NUI em HTML/CSS/TypeScript quando necessário

---

## 2. Regras obrigatórias

### 2.1 Server authoritative

Sempre que uma informação afetar:

- dinheiro;
- inventário;
- reputação;
- território;
- permissões;
- propriedade;
- recompensa;
- progressão;
- estado persistente;
- criação de entidades importantes;

o **servidor** deve ser a autoridade.

O client pode **solicitar** uma ação, mas nunca determinar o resultado final.

**ERRADO**

```lua
-- client
TriggerServerEvent('example:reward', 50000)
```

```lua
-- server
RegisterNetEvent('example:reward', function(amount)
    GiveMoney(source, amount)
end)
```

**CORRETO**

```lua
-- client
TriggerServerEvent('example:completeMission', missionId)
```

```lua
-- server
RegisterNetEvent('example:completeMission', function(missionId)
    local src = source

    if type(missionId) ~= 'string' then
        return
    end

    local mission = Missions[missionId]
    if not mission then
        return
    end

    if not CanPlayerCompleteMission(src, mission) then
        return
    end

    GiveMoney(src, mission.reward)
end)
```

O client informa **intenção**.
O servidor calcula **resultado**.

---

## 3. Diferenças do Enhanced que afetam código

### 3.1 Networking não deve ser tratado como P2P Legacy

FiveM Enhanced não utiliza o antigo modelo P2P de sincronização.

O projeto deve ser desenvolvido considerando:

```
client
   ↓
server authoritative
   ↓
clients relevantes
```

Não desenvolva lógica nova dependendo de comportamento histórico de ownership/migração do Legacy.

### 3.2 OneSync "big" deve ser assumido

No Enhanced, o modo antigo non-big não existe.

Consequência importante: um client **não deve assumir** que conhece todos os players ou todas as entidades existentes no servidor.

**Não faça**

```lua
-- NÃO tratar isso como lista global do servidor
local players = GetActivePlayers()
```

`GetActivePlayers()` representa os players **conhecidos/relevantes** para aquele client.

Para uma informação global, obtenha-a no servidor.

**Server**

```lua
local players = GetPlayers()
```

O servidor mantém o estado global e envia ao client somente o necessário.

### 3.3 Eventos de presença não são uma lista global no client

Código client-side não deve manter uma lista global de jogadores baseado apenas em eventos de entrada/saída ou entidades visíveis.

Exemplo de arquitetura correta:

```
SERVER
    PlayerRegistry
        ├── player 1
        ├── player 2
        ├── player 3
        └── player N

CLIENT
    recebe somente:
        - players relevantes
        - dados necessários para UI
        - dados necessários para gameplay local
```

---

## 4. Lua no Enhanced

FiveM utiliza CfxLua baseado em Lua 5.4.

Não é necessário:

```lua
lua54 'yes'
```

Essa opção está obsoleta.

### 4.1 Padrão de thread

Evite loops agressivos sem necessidade.

**ERRADO**

```lua
CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        TriggerServerEvent('example:updateCoords', coords)
    end
end)
```

Além do custo local, isso gera tráfego de rede desnecessário.

**MELHOR**

```lua
CreateThread(function()
    while true do
        Wait(1000)

        local ped = PlayerPedId()

        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            UpdateLocalState(coords)
        end
    end
end)
```

Envie informações pela rede somente quando realmente necessário.

---

## 5. TypeScript no FiveM

FiveM executa JavaScript, não TypeScript diretamente.

Fluxo obrigatório:

```
TypeScript
    ↓
build
    ↓
JavaScript
    ↓
FiveM runtime
```

Não dependa do FXServer para transpilar TypeScript.

Isso é particularmente importante no Enhanced porque **resource builders foram removidos**.

Produza os arquivos de `dist/` **antes** de iniciar/reiniciar o resource.

---

## 6. Estrutura recomendada

Para resource principalmente Lua:

```
my_resource/
├── fxmanifest.lua
├── client/
│   ├── main.lua
│   └── modules/
├── server/
│   ├── main.lua
│   └── modules/
├── shared/
│   ├── config.lua
│   └── constants.lua
└── web/
```

Para TypeScript:

```
my_resource/
├── fxmanifest.lua
├── package.json
├── tsconfig.json
├── src/
│   ├── client/
│   │   └── index.ts
│   ├── server/
│   │   └── index.ts
│   └── shared/
│       └── types.ts
└── dist/
    ├── client.js
    └── server.js
```

Para resource híbrido:

```
my_resource/
├── fxmanifest.lua
├── client/
│   └── main.lua
├── server/
│   └── main.lua
├── src/
│   ├── client/
│   └── server/
├── dist/
│   ├── client.js
│   └── server.js
└── web/
```

---

## 7. fxmanifest recomendado

Exemplo híbrido Lua + TypeScript:

```lua
fx_version 'cerulean'
game 'gta5'

author 'Noir State'
description 'Enhanced resource'
version '1.0.0'

-- Para server-side JavaScript/TypeScript compilado.
node_version '22'

shared_scripts {
    'shared/**/*.lua'
}

client_scripts {
    'client/**/*.lua',
    'dist/client.js'
}

server_scripts {
    'server/**/*.lua',
    'dist/server.js'
}

dependencies {
    '/onesync'
}
```

**Não adicionar**

```lua
lua54 'yes'
```

Não é mais necessário.

---

## 8. TypeScript: typings

Use os pacotes oficiais para autocomplete/tipagem:

```bash
npm install -D typescript @citizenfx/client @citizenfx/server
```

Não trate esses pacotes como uma SDK que precisa ser importada para chamar natives. As funções FiveM são expostas pelo runtime.

Exemplo client:

```ts
const ped = PlayerPedId();

if (DoesEntityExist(ped)) {
    const coords = GetEntityCoords(ped, false);
    console.log(coords);
}
```

---

## 9. Client TypeScript != NUI TypeScript

São runtimes diferentes.

### FiveM client script

```
src/client/index.ts
```

Tem acesso a:

- natives;
- `on`;
- `onNet`;
- `emit`;
- `emitNet`;
- `setTick`;
- APIs CitizenFX.

Não deve assumir que existe:

- DOM;
- `window.document` como uma página normal;
- Node.js APIs;
- `fs`;
- `path`;
- filesystem arbitrário.

### NUI

```
web/src/*
```

É aplicação web. Pode usar:

- DOM;
- CSS;
- React/Vue/Svelte;
- browser APIs suportadas pelo CEF;
- `fetch()` para callbacks NUI.

Mantenha as duas camadas separadas.

---

## 10. Server TypeScript e Node.js

No server-side é possível utilizar APIs Node suportadas pelo runtime.

Se o resource depende da versão moderna configurada:

```lua
node_version '22'
```

### Atenção à thread de Node

Callbacks disparados pelo event loop do Node podem estar fora da thread principal do game.

Ao voltar para APIs/natives CitizenFX, utilize `setImmediate` quando necessário.

Exemplo:

```ts
import fs from 'node:fs';

const resourcePath = GetResourcePath(GetCurrentResourceName());

fs.readFile(`${resourcePath}/data.json`, 'utf8', (error, data) => {
    if (error) {
        console.error(error);
        return;
    }

    setImmediate(() => {
        emitNet('my_resource:data', -1, data);
    });
});
```

---

## 11. Eventos: Lua

Client → Server

```lua
TriggerServerEvent('noir_example:server:requestAction', {
    id = actionId
})
```

Server

```lua
RegisterNetEvent('noir_example:server:requestAction', function(payload)
    local src = source

    if type(payload) ~= 'table' then
        return
    end

    if type(payload.id) ~= 'string' then
        return
    end

    HandleAction(src, payload.id)
end)
```

---

## 12. Eventos: TypeScript

Client

```ts
emitNet('noir_example:server:requestAction', {
    id: actionId,
});
```

Server

```ts
interface ActionPayload {
    id: string;
}

function isActionPayload(value: unknown): value is ActionPayload {
    if (typeof value !== 'object' || value === null) {
        return false;
    }

    const payload = value as Record<string, unknown>;
    return typeof payload.id === 'string';
}

onNet('noir_example:server:requestAction', (payload: unknown) => {
    const src = source;

    if (!isActionPayload(payload)) {
        return;
    }

    handleAction(src, payload.id);
});
```

---

## 13. Capture `source` imediatamente

Em Lua e JavaScript/TypeScript, `source` é contextual ao evento.

Se houver:

- `Wait`;
- `await`;
- callback async;
- Promise;
- timer;

capture antes.

### Lua

**ERRADO**

```lua
RegisterNetEvent('example:test', function()
    Wait(1000)

    print(source)
end)
```

**CORRETO**

```lua
RegisterNetEvent('example:test', function()
    local src = source

    Wait(1000)

    print(src)
end)
```

### TypeScript

```ts
onNet('example:test', async () => {
    const src = source;

    await doSomethingAsync();

    handlePlayer(src);
});
```

---

## 14. Nunca confiar em payload client-side

Sempre validar:

- tipo;
- faixa numérica;
- tamanho;
- string;
- enum;
- existência;
- permissões;
- distância;
- ownership;
- cooldown;
- estado atual da ação.

### Exemplo

Client envia:

```ts
emitNet('shop:buy', {
    item: 'water',
    amount: 2,
});
```

Client **não** envia:

```ts
emitNet('shop:buy', {
    item: 'water',
    amount: 2,
    price: 1,
    total: 2,
    moneyToRemove: 2,
});
```

Preço vem do servidor.

---

## 15. Eventos locais vs eventos de rede

Se um evento só precisa existir dentro do mesmo lado do resource, não o exponha para rede.

### Lua

Local:

```lua
AddEventHandler('resource:internalAction', function()
end)
```

Rede:

```lua
RegisterNetEvent('resource:networkAction', function()
end)
```

### TypeScript

Local:

```ts
on('resource:internalAction', () => {
});
```

Rede:

```ts
onNet('resource:networkAction', () => {
});
```

Quanto menor a superfície de eventos de rede, melhor.

---

## 16. Entidades: regra principal

Não envie **entity handles locais** entre client e servidor.

**ERRADO**

```lua
TriggerServerEvent('vehicle:use', vehicle)
```

O número usado para representar uma entidade no client não deve ser tratado como identificador global.

Use **Network ID** quando precisar referenciar uma entidade pela rede.

---

## 17. Network IDs

Client Lua

```lua
local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

if vehicle ~= 0 and DoesEntityExist(vehicle) then
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerServerEvent('vehicle:server:action', netId)
end
```

Server Lua

```lua
RegisterNetEvent('vehicle:server:action', function(netId)
    local src = source

    if type(netId) ~= 'number' then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)

    if entity == 0 or not DoesEntityExist(entity) then
        return
    end

    HandleVehicleAction(src, entity)
end)
```

O servidor ainda deve validar se aquele player realmente pode executar a ação naquela entidade.

---

## 18. TypeScript + Network IDs

Client

```ts
const vehicle = GetVehiclePedIsIn(PlayerPedId(), false);

if (vehicle !== 0 && DoesEntityExist(vehicle)) {
    const netId = NetworkGetNetworkIdFromEntity(vehicle);

    emitNet('vehicle:server:action', netId);
}
```

Server

```ts
onNet('vehicle:server:action', (netId: unknown) => {
    const src = source;

    if (typeof netId !== 'number') {
        return;
    }

    const entity = NetworkGetEntityFromNetworkId(netId);

    if (entity === 0 || !DoesEntityExist(entity)) {
        return;
    }

    handleVehicleAction(src, entity);
});
```

---

## 19. Entidades podem sair do scope

Nunca assuma:

```
tenho NetID
=
tenho entidade local
```

No client, uma entidade pode:

- ainda não ter sido criada localmente;
- ter saído do scope;
- ter sido removida;
- não ser relevante naquele momento.

Sempre valide.

```lua
local entity = NetworkGetEntityFromNetworkId(netId)

if entity == 0 then
    return
end

if not DoesEntityExist(entity) then
    return
end
```

---

## 20. Não mantenha handles por muito tempo

Evite

```lua
CurrentTarget = vehicle
```

e reutilizar esse handle minutos depois sem validar.

Prefira manter:

```
networkId
databaseId
vehicleId
logicalId
```

e resolver a entidade quando necessário.

---

## 21. Entidades persistentes importantes

Para entidades importantes para gameplay:

- veículos de missão;
- NPCs de missão;
- objetos de território;
- props compartilhados;
- objetos persistentes;

prefira uma arquitetura onde o server controla a **existência lógica**.

Exemplo:

```
SERVER
    entity logical id
    position
    model
    state
    ownership/game rules

CLIENT
    representação local quando estiver em scope
```

Não use a existência da entidade em um único client como banco de dados.

---

## 22. State Bags no Enhanced

State Bags são úteis para estados pequenos associados a:

- player;
- entidade;
- estado global.

No Enhanced há duas regras especialmente importantes:

1. callbacks devem ser tratados considerando a existência real da entidade;
2. quando a replicação for importante, seja explícito sobre ela.

---

## 23. State Bags: escrita explícita

Lua

```lua
Entity(entity).state:set('locked', true, true)
```

Formato:

```
state:set(key, value, replicate)
```

Se a intenção é sincronizar, não dependa de comportamento implícito.

---

## 24. State Bags: TypeScript

```ts
Entity(entity).state.set('locked', true, true);
```

---

## 25. State Bag Change Handler

Mesmo no Enhanced, escreva handlers defensivos.

Lua

```lua
AddStateBagChangeHandler('locked', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)

    if entity == 0 or not DoesEntityExist(entity) then
        return
    end

    FreezeEntityPosition(entity, value == true)
end)
```

TypeScript

```ts
AddStateBagChangeHandler(
    'locked',
    null,
    (bagName: string, _key: string, value: unknown) => {
        const entity = GetEntityFromStateBagName(bagName);

        if (entity === 0 || !DoesEntityExist(entity)) {
            return;
        }

        FreezeEntityPosition(entity, value === true);
    },
);
```

---

## 26. State Bags são shallow

Evite armazenar estruturas gigantes e ficar lendo propriedades internas repetidamente.

**Evite**

```
Entity(entity).state.vehicleData.engine.damage.current
```

Prefira chaves granulares:

```
Entity(entity).state['engine:damage']
Entity(entity).state['engine:running']
Entity(entity).state['door:locked']
```

---

## 27. Não use State Bag como banco de dados

State Bag é estado de sincronização, não armazenamento persistente.

**Bom uso**

```
doorLocked
missionState
territoryOwner
isBeingRobbed
animationState
vehicleStatus
```

**Mau uso**

```
histórico completo do player
lista gigante de inventário
logs
centenas de registros
dados permanentes
```

Dados persistentes continuam no servidor/banco.

---

## 28. Não atualize State Bags todo frame

**ERRADO**

```lua
CreateThread(function()
    while true do
        Wait(0)

        LocalPlayer.state:set('coords', GetEntityCoords(PlayerPedId()), true)
    end
end)
```

Além de desnecessário, o Enhanced possui **rate limiters** para State Bags e eventos.

Use mudança por evento, threshold ou intervalos razoáveis.

---

## 29. Replicação por relevância

O client deve receber somente o que precisa.

Exemplo: territórios.

Não é necessário enviar:

```
500 objetos
+
estado completo
+
histórico
+
dados administrativos
```

para todo client.

Prefira:

```
server possui estado completo
        ↓
client recebe resumo
        ↓
detalhe é enviado sob demanda
```

---

## 30. Rate limiters do Enhanced

O Enhanced possui limitadores para categorias como:

- network events;
- State Bags;
- comandos;
- endpoints HTTP;
- handshake.

Portanto, nunca desenvolva arquitetura que dependa de:

```
TriggerServerEvent em cada frame
StateBag update em cada frame
centenas de eventos pequenos por segundo
```

Se precisa sincronizar algo frequentemente:

1. questione se realmente precisa da rede;
2. mantenha a simulação local quando possível;
3. envie somente mudanças;
4. faça debounce/throttle;
5. agregue payloads quando fizer sentido.

---

## 31. Network event não é RPC confiável

Não trate:

```lua
TriggerServerEvent(...)
```

como chamada de função síncrona.

Evite fluxo:

```
client envia
↓
client fica bloqueado esperando
↓
server responde
```

Prefira estado assíncrono.

```
REQUEST
    requestId

SERVER
    processa

RESPONSE
    requestId
    result
```

Ou use uma biblioteca de callbacks já adotada pelo projeto, desde que a validação continue no servidor.

---

## 32. NUI

NUI continua apropriada para:

- HUD;
- menus;
- tablet;
- celular;
- checklist;
- inventário;
- interfaces complexas.

Arquitetura:

```
NUI
 ↕
client script
 ↕
server
```

Evite:

```
NUI → lógica crítica
```

A NUI nunca decide dinheiro, reward, permissão ou conclusão de atividade.

---

## 33. NUI Callback — Lua

```lua
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)

    cb({
        ok = true
    })
end)
```

Sempre responda o callback.

---

## 34. NUI Callback — TypeScript

```ts
RegisterNuiCallbackType('close');

on('__cfx_nui:close', (_data: unknown, cb: (response: unknown) => void) => {
    SetNuiFocus(false, false);

    cb({
        ok: true,
    });
});
```

---

## 35. NUI → Client

Exemplo no browser:

```ts
async function closeUi(): Promise<void> {
    await fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
    });
}
```

Considere toda informação vinda da NUI como input do usuário.

---

## 36. Client → NUI

Lua

```lua
SendNUIMessage({
    action = 'open',
    data = {
        title = 'Noir State'
    }
})
```

TypeScript

```ts
SendNUIMessage({
    action: 'open',
    data: {
        title: 'Noir State',
    },
});
```

---

## 37. DUI

DUI é útil quando a interface precisa ser renderizada em uma textura no mundo.

Exemplos:

- telas;
- placas;
- graffiti dinâmico;
- display;
- monitor;
- painel.

Mas DUI deve ser tratado como recurso caro em comparação com dados simples.

### Regras

- não crie DUI sem lifecycle;
- destrua quando não for mais utilizado;
- não atualize conteúdo sem necessidade;
- evite dezenas/centenas de páginas vivas apenas porque existem dezenas/centenas de objetos;
- use distância/visibilidade para controlar atualização;
- mantenha lógica de gameplay fora do DUI.

---

## 38. Streaming e scope

Ao trabalhar com objetos no mundo:

```
servidor sabe que objeto existe
↓
client entra no scope
↓
client obtém entidade
↓
client aplica representação visual
↓
client sai do scope
↓
referência local deixa de ser válida
```

O script precisa funcionar mesmo que a entidade:

- desapareça;
- reapareça;
- mude de owner;
- seja recriada;
- entre novamente no scope.

---

## 39. Evite polling quando existe evento

**Evite**

```lua
CreateThread(function()
    while true do
        Wait(0)

        if SomeStateChanged() then
            ...
        end
    end
end)
```

Prefira:

```
event
state bag handler
zone enter/exit
framework callback
entity creation/state transition
```

Use polling somente quando não houver alternativa adequada.

---

## 40. Loops por distância

Quando polling for necessário, use frequência adaptativa.

```lua
CreateThread(function()
    while true do
        local sleep = 1500

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        if #(coords - targetCoords) < 100.0 then
            sleep = 250
        end

        if #(coords - targetCoords) < 10.0 then
            sleep = 0
        end

        Wait(sleep)
    end
end)
```

Não use `Wait(0)` globalmente por conveniência.

---

## 41. Qbox / framework

Framework é camada de aplicação.
Enhanced é camada de runtime/network/game.

Não misture responsabilidades.

```
Enhanced / CitizenFX
    ├── entities
    ├── networking
    ├── natives
    └── state bags

Qbox
    ├── player data
    ├── jobs
    ├── groups
    ├── money
    └── framework abstractions

Resource
    └── regra de negócio
```

Se uma regra puder existir sem Qbox, mantenha-a desacoplada quando fizer sentido.

---

## 42. ox_lib

Pode ser usado para abstrações como:

- callbacks;
- zones;
- progress;
- context;
- input;
- cache;
- locale.

Mas não use biblioteca como desculpa para ignorar as regras de networking.

Mesmo com callback:

```
CLIENT INPUT
    ↓
SERVER VALIDATION
    ↓
SERVER DECISION
```

---

## 43. ox_target

Target deve detectar intenção/interação. Não deve conceder resultado diretamente.

Client

```
player seleciona target
↓
client solicita interação
```

Server

```
valida:
    player
    distância
    estado
    permissão
    cooldown
    entidade

executa
```

---

## 44. Distância deve ser validada no servidor quando relevante

Se uma ação exige estar próximo de algo:

```
client diz:
"quero interagir com X"

server verifica:
"você realmente pode interagir com X?"
```

Não aceite:

```ts
emitNet('robbery:complete', true);
```

como prova de conclusão.

---

## 45. Identificadores lógicos

Para sistemas complexos, use IDs lógicos.

Exemplo:

```
territory: strawberry_01
house: house_0042
graffiti: graffiti_183
mission: robbery_992
vehicle: database vehicle id
```

Não use entity handle como ID de negócio.

---

## 46. Routing Buckets

Ao trabalhar com instâncias:

- servidor define bucket;
- servidor mantém membership;
- entidades da instância pertencem à instância;
- não dependa de client para informar em qual bucket deveria estar;
- cleanup deve existir.

Exemplo de fluxo:

```
create robbery
↓
allocate bucket
↓
move players
↓
spawn/control state
↓
finish/cancel/disconnect
↓
cleanup entities
↓
restore players
↓
release bucket
```

---

## 47. Cleanup é obrigatório

Todo resource que cria algo precisa saber destruir.

Checklist:

```
[ ] entities
[ ] blips
[ ] zones
[ ] DUI
[ ] runtime textures
[ ] NUI focus
[ ] threads/state
[ ] temporary tables
[ ] routing buckets
[ ] callbacks/listeners quando aplicável
```

Teste também `restart resource_name`.

---

## 48. onResourceStop

Exemplo Lua:

```lua
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    SetNuiFocus(false, false)

    CleanupLocalEntities()
    CleanupZones()
    CleanupDui()
end)
```

---

## 49. Resource restart deve ser suportado

Durante desenvolvimento, o resource será reiniciado várias vezes.

Não assuma que:

```
resource start
=
player acabou de conectar
```

Ao iniciar:

1. descubra o estado atual;
2. reconstrua o necessário;
3. registre handlers;
4. não duplique entidades/listeners;
5. recupere estado do servidor se necessário.

---

## 50. Developer Mode no Enhanced

Para desenvolvimento:

```
sv_devMode true
```

No Enhanced, dev mode é habilitado pelo servidor.

O antigo:

```
+set moo 31337
```

foi removido.

`sv_devMode` não deve ficar habilitado em produção.

---

## 51. Teste com dois clients

Enhanced permite lançar client adicional através das ferramentas de desenvolvimento quando `sv_devMode` está ativo.

Todo sistema de sincronização deve ser testado com pelo menos:

```
Client A
Client B
Server
```

Teste:

- A cria/interage;
- B observa;
- A sai do scope;
- B continua;
- A volta;
- entidade é recriada;
- resource reinicia;
- A desconecta;
- B desconecta;
- bucket muda.

---

## 52. `sv_syncTickRate`

Enhanced possui:

```
set sv_syncTickRate 60
```

Faixa suportada documentada:

```
1 - 120
```

Não desenvolva um resource supondo que aumentar isso resolverá arquitetura ruim.

Se o script precisa de:

```
120 updates de aplicação por segundo
```

o problema provavelmente está no design.

---

## 53. Pure Mode

No Enhanced, Pure Mode está sempre habilitado.

Portanto, não projete feature dependendo de modificação arbitrária dos arquivos locais do GTA do jogador.

Tudo necessário para o resource deve vir de mecanismos suportados pela plataforma.

---

## 54. Asset Escrow

No Enhanced, Asset Escrow ainda não está implementado segundo a documentação de migração.

Para este projeto: prefira código aberto/modificável e assets compatíveis com Enhanced.

Não crie dependência arquitetural em resource cujo funcionamento dependa de Escrow no Enhanced.

---

## 55. Resource builders

No Enhanced, resources não podem mais atuar como builders.

Para TypeScript:

**ERRADO**

```
FXServer inicia
↓
resource magicamente transpila TS
↓
executa
```

**CORRETO**

```
npm install
↓
npm run build
↓
dist/client.js
dist/server.js
↓
FXServer inicia resource
```

Use:

- build local;
- CI;
- deploy script;
- watcher externo no ambiente de desenvolvimento.

---

## 56. Build TypeScript

Exemplo de `package.json` usando `esbuild`:

```json
{
  "scripts": {
    "build:client": "esbuild src/client/index.ts --bundle --platform=browser --format=iife --outfile=dist/client.js",
    "build:server": "esbuild src/server/index.ts --bundle --platform=node --format=cjs --target=node22 --outfile=dist/server.js",
    "build": "npm run build:client && npm run build:server"
  },
  "devDependencies": {
    "@citizenfx/client": "latest",
    "@citizenfx/server": "latest",
    "esbuild": "latest",
    "typescript": "latest"
  }
}
```

Evite importar dependências Node no bundle client.

---

## 57. Tipos compartilhados

É útil compartilhar tipos, não código runtime incompatível.

```ts
export interface TerritoryState {
    id: string;
    owner: string | null;
    reputation: Record<string, number>;
}
```

Pode ser usado no build client e server.

Mas não coloque em `shared` código que importe:

```
fs
Node APIs
DOM
server-only functions
client-only natives
```

---

## 58. Boundary validation em TypeScript

TypeScript não valida payload em runtime.

Isto:

```ts
onNet('event', (payload: TerritoryState) => {
});
```

não torna o payload confiável.

O usuário pode mandar qualquer coisa.

Faça validação runtime.

```ts
function isString(value: unknown): value is string {
    return typeof value === 'string';
}
```

Para estruturas maiores, considere uma biblioteca de schema validation compatível com seu build.

---

## 59. Dados vindos do client são `unknown`

Padrão recomendado:

```ts
onNet('resource:event', (payload: unknown) => {
    if (!isValidPayload(payload)) {
        return;
    }

    // somente daqui para frente payload é confiável estruturalmente
});
```

Mesmo após validar estrutura, ainda valide regra de negócio.

---

## 60. Separação por camada

Estrutura sugerida:

```
transport
    eventos/callbacks

application
    casos de uso

domain
    regras

infrastructure
    database/framework/external resources
```

Exemplo:

```
server/events/territory.lua
server/services/territory.lua
server/repositories/territory.lua
```

ou:

```
src/server/events/territory.ts
src/server/services/territory.ts
src/server/repositories/territory.ts
```

Handler de evento deve ser pequeno.

---

## 61. Não espalhar nomes de eventos

Lua:

```lua
Events = {
    RequestSpray = 'noir_gangs:server:requestSpray',
    TerritoryUpdated = 'noir_gangs:client:territoryUpdated'
}
```

TypeScript:

```ts
export const Events = {
    requestSpray: 'noir_gangs:server:requestSpray',
    territoryUpdated: 'noir_gangs:client:territoryUpdated',
} as const;
```

Evita typo e facilita refactor.

---

## 62. Namespace de eventos

Use:

```
resource:server:event
resource:client:event
```

Exemplo:

```
noir_gangs:server:sellDrug
noir_gangs:client:territoryUpdated
```

Evite:

```
update
sync
event
test
callback
```

como nomes globais genéricos.

---

## 63. Não sincronizar o que pode ser derivado

Exemplo: se o client já possui:

```
startTime
duration
```

não envie:

```
progress = 1%
progress = 2%
progress = 3%
...
```

O client calcula visualmente o progresso.

Servidor valida conclusão usando seu próprio relógio/estado.

---

## 64. UI não precisa receber estado todo frame

Prefira eventos:

```
open
update
close
```

Exemplo:

```ts
SendNUIMessage({
    action: 'updateTerritory',
    data: territory,
});
```

Não reenvie toda a aplicação a cada tick.

---

## 65. Timers server-side

Evite um thread individual por entidade quando a escala pode crescer.

Potencialmente ruim

```
1000 graffiti
=
1000 loops
```

Prefira scheduler central quando aplicável.

```
1 scheduler
↓
processa itens vencidos/relevantes
```

---

## 66. Cache

Cache pode ser usado para:

- configuração;
- lookup por ID;
- estado derivado;
- dados lidos frequentemente.

Mas defina:

```
source of truth
invalidations
lifecycle
```

Nunca tenha dois lugares diferentes sendo tratados como autoridade para o mesmo estado.

---

## 67. Logs

Logs devem conter contexto.

Ruim

```
failed
```

Melhor

```
[noir_gangs] sellDrug rejected src=42 territory=strawberry reason=too_far
```

Não logue segredos, tokens ou payloads sensíveis.

---

## 68. Erros

Client não deve receber stack trace interno.

Server:

```lua
print(('[resource] failed to process action for %s'):format(src))
```

Client:

```
Não foi possível concluir a ação.
```

Detalhes internos permanecem no log do servidor.

---

## 69. Config

Separe:

```
shared config
server-only config
client-only config
```

Nunca coloque segredo em:

```
shared.lua
client.lua
NUI
```

Qualquer coisa entregue ao client deve ser considerada pública.

---

## 70. ConVars

Credenciais/configuração operacional devem preferir ambiente ou ConVars server-side quando apropriado.

Exemplo:

```lua
local endpoint = GetConvar('my_resource_endpoint', '')
```

Não enviar segredo ao client posteriormente.

---

## 71. Compatibilidade com Enhanced

Antes de adicionar uma dependência externa, verificar:

```
[ ] funciona no Enhanced?
[ ] usa Asset Escrow?
[ ] depende de assets Legacy?
[ ] depende de comportamento P2P?
[ ] depende de OneSync non-big?
[ ] depende de client modificado?
[ ] depende de builder antigo?
[ ] depende de native/comportamento removido?
[ ] funciona depois de sair/entrar no entity scope?
```

---

## 72. Assets

Código Lua/TypeScript pode estar correto e o resource ainda falhar por asset incompatível.

Trate separadamente:

```
CODE COMPATIBILITY
ASSET COMPATIBILITY
```

Para:

- YDR;
- YTD;
- YBN;
- YMAP;
- YTYP;
- veículos;
- roupas;
- MLOs;

verifique compatibilidade/conversão para Enhanced.

Não tente mascarar erro de asset com workaround em Lua.

---

## 73. Gamebuild

Evite hardcode baseado em comportamento de um gamebuild sem necessidade.

Se alguma feature depende de gamebuild:

```
documente
configure
valide
falhe de forma explícita
```

Não suponha silenciosamente que todo servidor está executando a mesma configuração histórica do Legacy.

---

## 74. Performance: prioridade

Ordem de otimização:

1. eliminar trabalho desnecessário;
2. reduzir frequência;
3. reduzir quantidade de entidades;
4. reduzir tráfego de rede;
5. reduzir serialização;
6. cachear quando correto;
7. otimizar microcódigo por último.

Um loop Lua muito simples pode custar menos que uma arquitetura ruim de sincronização.

---

## 75. Checklist de code review

Antes de aceitar código novo:

### Networking

```
[ ] O client está enviando somente intenção?
[ ] O servidor valida o payload?
[ ] O servidor valida regra de negócio?
[ ] Há spam de eventos?
[ ] Está usando NetID em vez de entity handle pela rede?
```

### Enhanced

```
[ ] Funciona sem P2P Legacy?
[ ] Funciona com OneSync big/scoping?
[ ] Não depende de lista global de players no client?
[ ] State Bag replication está explícita quando necessária?
[ ] Handler lida com entidade inexistente/fora de scope?
```

### Lua

```
[ ] `source` foi salvo antes de Wait?
[ ] loops têm Wait adequado?
[ ] não existe `Wait(0)` desnecessário?
[ ] cleanup existe?
```

### TypeScript

```
[ ] TypeScript é compilado antes do deploy?
[ ] client bundle não usa Node APIs?
[ ] payload de rede entra como `unknown`?
[ ] `source` é salvo antes de await?
[ ] callbacks Node voltam para game thread quando necessário?
```

### UI

```
[ ] NUI só controla apresentação/input?
[ ] callbacks sempre respondem?
[ ] focus é liberado?
[ ] não há segredo no browser?
```

### Lifecycle

```
[ ] resource restart funciona?
[ ] disconnect funciona?
[ ] entity scope in/out funciona?
[ ] bucket cleanup funciona?
[ ] DUI/props/zones são removidos?
```

---

## 76. Anti-patterns proibidos

Não introduzir código novo que dependa de:

```
❌ client determinando dinheiro/reward
❌ client determinando propriedade
❌ entity handle enviado como ID de rede
❌ GetActivePlayers() como lista global
❌ entidade local como source of truth
❌ TriggerServerEvent por frame
❌ State Bag update por frame
❌ payload client tipado como confiável
❌ source utilizado depois de await/Wait sem captura
❌ Node APIs no client runtime
❌ lógica crítica dentro da NUI
❌ segredo em client/shared/NUI
❌ resource builder para transpilar TS no start
❌ dependência de P2P Legacy
❌ dependência de OneSync non-big
❌ ausência de cleanup
```

---

## 77. Padrão mental para novos resources

Para cada feature, responder:

### 1. Quem é autoridade?

Normalmente:

```
server
```

### 2. O que o client precisa saber?

Somente o necessário para:

```
render
input
feedback
animação
interação
```

### 3. O que precisa ser networked?

Somente estado compartilhado.

### 4. O que acontece se a entidade sair do scope?

O sistema deve continuar consistente.

### 5. O que acontece se o resource reiniciar?

O estado deve ser reconstruído ou recuperado.

### 6. O que acontece se o client mentir?

O servidor deve rejeitar a ação.

---

## 78. Modelo recomendado de feature

Exemplo genérico:

```
PLAYER INTERACTS
        │
        ▼
CLIENT
- detecta interação
- anima/UI
- envia request
        │
        ▼
SERVER
- valida player
- valida posição
- valida entidade
- valida cooldown
- valida estado
- calcula resultado
- persiste
        │
        ├────────────► DB
        │
        ▼
STATE/EVENT
        │
        ▼
RELEVANT CLIENTS
- atualizam visual
```

Esse deve ser o padrão principal dos resources Enhanced.

---

## 79. Regra para agentes de código

Ao gerar ou modificar código deste projeto:

**Nunca assuma comportamento do FiveM Legacy quando existir uma alternativa compatível com Enhanced.**

O agente deve:

1. preferir APIs atuais;
2. escrever código Lua 5.4;
3. tratar TypeScript como build-time;
4. usar server authority;
5. considerar OneSync big e entity scope;
6. validar eventos;
7. usar Network IDs entre contextos;
8. usar State Bags de forma pequena e explícita;
9. evitar network polling;
10. implementar cleanup;
11. indicar quando uma solução depende de asset/native ainda não confirmado no Enhanced.

Se uma feature depende de comportamento obscuro da engine: implementar somente depois de confirmar o comportamento **especificamente no FiveM Enhanced**.

Isto é especialmente importante para:

- minimap;
- Scaleform;
- runtime textures;
- DUI;
- render targets;
- map internals;
- streaming;
- YMAP/YBN;
- manipulação de assets;
- natives pouco documentados.

---

## 80. Referências oficiais

- FiveM — What's Changed in FiveM for GTAV Enhanced
  https://docs.fivem.net/docs/developers/legacy-vs-enhanced/
- FiveM — Lua runtime
  https://docs.fivem.net/docs/scripting-manual/runtimes/lua/
- FiveM — JavaScript / TypeScript runtime
  https://docs.fivem.net/docs/scripting-manual/runtimes/javascript/
- FiveM — State Bags
  https://docs.fivem.net/docs/scripting-manual/networking/state-bags/
- FiveM — OneSync
  https://docs.fivem.net/docs/scripting-reference/onesync/
- FiveM — Resource Manifest
  https://docs.fivem.net/docs/scripting-reference/resource-manifest/
- FiveM — Server Commands / Enhanced-only ConVars
  https://docs.fivem.net/docs/server-manual/server-commands/
- FiveM — Events
  https://docs.fivem.net/docs/scripting-manual/working-with-events/

---

## Resumo

Para desenvolvimento novo no Enhanced:

```
Lua 5.4 / TypeScript
        +
server authoritative
        +
OneSync big aware
        +
entity scope aware
        +
NetIDs
        +
State Bags explícitos
        +
event validation
        +
baixo tráfego de rede
        +
cleanup correto
        +
build TS externo
```

Não programe Enhanced como se fosse apenas o FiveM Legacy executando GTA V com gráficos novos.

A maior mudança para resources é assumir desde o início um modelo de sincronização e lifecycle mais rigoroso.
