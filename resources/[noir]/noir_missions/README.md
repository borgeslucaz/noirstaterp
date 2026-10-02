# noir_missions

Missões montadas dentro do jogo. Um editor NUI (`/noirmissions`) monta a missão posicionando
NPCs, veículos, carga, interações, zonas, reforços, perseguições e entregas; um runtime genérico
executa qualquer missão montada assim. O runtime conhece só conceitos — passo, gatilho, ação,
condição, variável, entidade, carga, grupo de NPC, veículo, rota, entrega. "Elysian", "meth" ou
"tambor" não aparecem no código: a missão Elysian é um arquivo de definição.

## Comandos e permissão

Todos exigem a ACE `noir.missions` (já em `permissions.cfg` para `group.admin`).

| Comando | O que faz |
|---|---|
| `/noirmissions` | abre o editor |
| `/noirmissionsdebug` | liga/desliga o painel da instância em execução (passo, variáveis, grupos, carga) |
| `/nmoffer <missão> [id]` | liga oferecendo a missão (ACEITAR/RECUSAR) para o jogador |
| `/nmstart <missão> [ids...]` | começa uma missão publicada direto com esses jogadores |
| `/nmstop <instância>` | encerra uma execução |
| `/nmcooldown <missão>` | zera o cooldown |

A tecla de largar carga é `G` por padrão (Configurações → Teclas → FiveM → "Noir: largar carga").

## Fluxo de trabalho

1. `/noirmissions` → **CRIAR MISSÃO** (id e nome).
2. Cada seção do editor é uma coleção: Variáveis, Zonas, NPCs, Veículos, Objetos, Carga,
   Interações, Reforços, Perseguições, Entregas. Todo campo de posição tem **DEFINIR POSIÇÃO**
   (a NUI some, mira no mundo, roda gira, `Shift`+roda sobe/desce, `G` usa onde você está — ou o
   veículo em que está —, `E` confirma, `Backspace` cancela), **TELEPORTAR** e **PRÉVIA**.
3. **Passos**: a sequência da missão, reordenável por arrasto. Cada passo tem condição
   (pulado se falsa), ações ao começar e ao concluir.
4. **Gatilhos**: "quando acontecer X (e a condição for verdadeira), espere N s e faça isto".
5. **SALVAR** grava o rascunho. **Teste** roda o rascunho com você sozinho, sem gang, sem
   cooldown e sem recompensa.
6. **PUBLICAR** copia o rascunho para a versão publicada. Só ela roda de verdade. Uma execução
   leva uma cópia da definição, então publicar ou editar não mexe em missão em curso.

## A missão Elysian

`missions/meth_elysian_precursors.json` foi gerada de `dev/seed/meth_elysian_precursors.lua`
(`lua5.4 dev/build_seed.lua meth_elysian_precursors`). Está como **rascunho** porque as
coordenadas são aproximadas: reposicionar no editor tudo (galpão, guardas, notebook, 8 tambores,
van, ponto do reforço, pontos de perseguição, entregas) e publicar.

O que ela usa, tudo por configuração: ligação → ir até a ilha (gatilho de zona cria 3 grupos de
seguranças que avisam antes e ficam hostis por zona restrita, tiro, dano ou alarme) → hack do
notebook (minigame `noir:circuit`; sucesso mostra o manifesto e desliga o alarme, falha liga o
alarme) → 8 tambores, 4 certos sorteados, etiqueta com o lote sorteado → carregar na van (3/4,
4/4) → com alarme, o primeiro tambor chama a SUV de reforço em 30 s (dois gatilhos, uma variável
garante um reforço só) → sair da ilha com a van → SMS, sorteio da entrega, 60% de perseguição
20–40 s depois, com segunda onda de motos → entrega (van parada 3 s, NPC que recebe) →
`chemical_precursor` x2 para cada participante.

`tests/unit/elysian_flow_spec.lua` roda essa missão inteira no runtime de verdade.

## Arquitetura

```
shared/types/schema.lua       o que existe e com que campos (alimenta o editor e a validação)
shared/types/definition.lua   normaliza e valida a definição, guiada pelo esquema
shared/utils/                 condições, template {{var}}, escolha de ponto de perseguição
server/missions/repository    rascunho/publicada/status, cooldown (KVP)
server/persistence/storage    JSON em missions/ (trocar por banco = trocar este arquivo)
server/instances/runtime      execução: passos, gatilhos, ações, variáveis, retrato p/ clientes
server/instances/world        entidades OneSync + registro de IA replicado
server/instances/monitor      uma volta por segundo sobre as instâncias ativas
server/instances/starter      começar (gang, jogadores, cooldown, limite)
server/components/*           componentes registrados (passos e ações)
server/participants, rewards, offers, editor, api
client/entities/registry      laço do dono de rede
client/npc, client/vehicles   tarefas de ped e direção (carro, moto, barco, aeronave)
client/cargo/carry            carga nas mãos
client/interactions           alvos e interações
client/runtime                HUD, blips, tiro, NPC/zona de início
client/editor                 editor, posicionamento, debug
web/mission-editor            NUI (editor + HUD + oferta)
```

### Componentes

Cada arquivo em `server/components/` chama `MissionComponents.register(nome, { steps, actions,
init, start, tick, event, view, resolve, participantLeft, cleanup, debug })`. Para um tipo novo
de passo ou ação: a entrada no esquema (`shared/types/schema.lua`) e o handler no componente. O
editor desenha o formulário sozinho a partir do esquema. O boot do servidor acusa passo ou ação
do esquema sem handler.

Passos: `vehicle_enter`, `goto`, `interact`, `eliminate`, `cargo`, `leave_area`, `deliver`, `wait`,
`condition`, `actions`.

### Comboio

Coleção "Comboios": rota em pontos, fila de veículos (líder, carga, escolta) com tripulação. O
primeiro vivo conduz pela rota; cada um dos outros segue o da frente (`TaskVehicleEscort`).
Tiro perto, tripulante ferido ou morto, ou veículo batido = ataque: todos param e descem para
defender, ou a carga foge pelo fim da rota enquanto as escoltas lutam. Carga pode nascer dentro
de um veículo do comboio (`startConvoy`); os jogadores tiram ("Tirar carga") e levam para outro
veículo — ainda no comboio, não conta como "no veículo", salvo `sourceCounts`. Para montar a
missão: eventos `convoy_attacked`, `convoy_arrived`, `convoy_destroyed`; valores
`convoy.<id>.alive`, `.attacked`, `.arrived`. Um veículo só com fim "repetir" é patrulha. Ações: variáveis, NPC (criar, remover, hostilidade), veículos e objetos, interação e
carga, SMS, aviso, informação, blip, sorteio de entrega, reforço, perseguição, dispatch, timer,
esperar, se/chance (ramificação), ir para passo, dar/tirar item, som, concluir, falhar.

### Autoridade e rede

- Estado só no servidor. O cliente recebe um retrato (objetivo, blips, alvos) e manda intenções;
  pegar carga, carregar, interagir e entregar são conferidos no servidor (participante, estado,
  distância pela posição do servidor, tempo mínimo da interação).
- Duas pessoas pegando o mesmo tambor: o primeiro pedido muda o estado; o segundo é recusado.
- NPCs e veículos são criados pelo servidor (orphan mode "manter"). A descrição de cada um
  (configuração + tarefa) vai para todos os clientes; quem é dono de rede aplica, e quem passa a
  ser dono reaplica. Vida e colete são aplicados uma vez (marca no state bag, escrita pelo
  servidor depois de conferir o dono), para troca de dono não curar ninguém.
- Carga nas mãos é um state bag do jogador; cada cliente cria o objeto local na mão dele.
  Desconectou ou caiu carregando: o servidor recria o tambor no chão onde ele estava.
- Todos saíram: a execução falha e tudo é apagado (NPCs, veículos, objetos, blips, alvos).

### Bridge

Personagem, gang, itens, dinheiro, chave, SMS, dispatch e "caído" vão pelo `bgrz_core`
(`server/integrations.lua`). `ox_target` é chamado direto (§2.5) só de `client/integrations.lua`.
`noir_lib` (pílulas de tecla, fala de ped) e `noir_minigames` são opcionais.

O veículo da missão **não** usa `SpawnVehicle` do bridge: ele espera um cliente virar dono em até
5 s e desiste, e a van nasce longe de todos. Cria pelo native de servidor; a chave vai pelo bridge.

## API

```lua
exports.noir_missions:startMission('meth_elysian_precursors', { leader, other })  --> instanceId, code
exports.noir_missions:offerMission('meth_elysian_precursors', source)              --> ok, code
exports.noir_missions:getPlayerInstance(source)
exports.noir_missions:getInstance(instanceId)
exports.noir_missions:setVariable(instanceId, 'alarm_active', true)  -- dispara var_changed
exports.noir_missions:endMission(instanceId, reason)
```

Eventos locais do servidor: `noir_missions:missionStarted`, `stepStarted`, `stepCompleted`,
`cargoCollected`, `alarmTriggered`, `missionCompleted`, `missionFailed` e `noir_missions:event`
(todos os eventos da missão).

## Testes

```bash
for spec in tests/unit/*_spec.lua; do lua5.4 "$spec" || exit 1; done
```

- `elysian_flow_spec`: a Elysian inteira em quatro caminhos (limpo com perseguição e segunda onda;
  hack falho com alarme, reforço e disconnect carregando; tiro deixando guardas hostis; teste do
  editor a partir de um passo).
- `pure_spec`: condições, template, validação da definição, escolha de ponto de perseguição.
- `manifest_spec`: o que vai e o que não vai para o cliente, dependências, chamadas a outros
  resources só nos arquivos de integração.

`tests/testlib.lua` é um servidor falso mínimo (natives usados, entidades em tabela, relógio,
bridge fingido). O que ele **não** prova: comportamento de IA, direção, colisão, NUI — isso é
teste no jogo.

## Preview da NUI

`dev/index.html` carrega a NUI real com mocks (ver `dev/README.md`). `dev/schema.json` é o
esquema exportado (`lua5.4 dev/export_schema.lua > dev/schema.json`).

## Fases seguintes

Comboio e patrulha de veículo existem e foram exercitados em teste automatizado; falta jogo.
Falta para a Fase 3: editor de rota avançado, pouso/decolagem de avião, e as missões Convoy,
Boat e Airstrip montadas no editor. Também ficaram de fora nesta versão: carga visível dentro do
veículo, início por item usável e portas (`ox_doorlock`).
