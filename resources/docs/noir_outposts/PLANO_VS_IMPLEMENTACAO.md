# Plano × implementação — `noir_outposts`

> Registrado em 2026-09-12, sobre o commit `22071c51`.
>
> Escopo: estado entregue de `resources/[bgrz]/noir_outposts`, confrontado com
> `resources/docs/noir_outposts/OUTPOST_NPC_DRUGSELL.md` (especificação primária).
>
> Complementa `CODE_REVIEW_IMPROVEMENTS.md`, que detalha os riscos técnicos. Este documento
> registra o que divergiu do plano, por quê, e o que falta decidir ou executar.

## 1. Estado da entrega

| Fase da especificação | Estado |
|---|---|
| Fase 0 — contratos | parcial: adapters do `bgrz_core` entregues; `noir_illegal_core` abandonado |
| Fase 1 — domínio sem NPC/NUI | completa |
| Fase 2 — mundo e interação | completa, com seis mecânicas além do escopo |
| Fase 3 — interfaces | completa, com uma aba de telefone além do escopo |
| Fase 4 — expansão | não iniciada, conforme planejado |

`CONTESTED` e `COOLDOWN` existem em `shared/constants.lua` e nas transições válidas de
`shared/validators.lua`, mas não possuem serviço. São estados mortos intencionais, já
documentados no `README.md` do resource.

## 2. Divergências deliberadas

### 2.1 `noir_illegal_core` foi removido do contrato

A especificação (§4.2) define `outpost_claim`, `outpost_sale` e `outpost_robbery` como
activities obrigatórias, com `heat`, `diminishingReturns` e `RecordActivity` no fluxo pós-venda.
Nenhum desses elementos existe na implementação, e `tests/unit/config_spec.lua` trava a decisão
proibindo o resource de declarar `noir_illegal_core` como dependência.

A identidade da organização também mudou de fonte: em vez de
`exports.noir_illegal_core:GetOrganization(source)`, o resource usa a gang do personagem
normalizada pelo bridge, em `server/integration.lua` (`organizationFrom`).

O substituto de telemetria é o ledger próprio `noir_outpost_operations`, que atende auditoria e
balanceamento melhor que a activity externa.

**Não há substituto para o anti-farm.** `diminishingReturns` era a única trava de receita por
hora prevista. Hoje o limite é indireto: `limits.maxStockTotal`, `sales.minimumIntervalSeconds` e
`sales.requireOwnerMemberOnline`. Na prática o gargalo passou a ser o abastecimento de estoque,
não o tempo decorrido. Isso pode ser suficiente, mas nunca foi declarado como decisão nem medido.

Arquivos relacionados:

- `resources/docs/noir_outposts/OUTPOST_NPC_DRUGSELL.md` (§4.2, §3.3, §5.5);
- `server/integration.lua`;
- `tests/unit/config_spec.lua`;
- `config/server.lua` (`limits`, `sales`).

Ação recomendada: ver seção 5, item P2-1.

### 2.2 Seis mecânicas construídas fora do escopo

| Adição | Previsão na especificação |
|---|---|
| Abordagem armada em duas etapas (`holdup_service.lua`), com reação/rendição sorteada no servidor e estados `hostile`/`surrendered`/`shaken` | apenas "animação, arma/ameaça e estado do ped podem ser requisitos configuráveis" do roubo (§5.8) |
| Caminhada dos corredores (`dealerWander`), com âncora na esquina, malha de navegação com fallback em linha reta, coleira e pausa por jogador próximo | nenhuma; os peds ficariam parados |
| Reporte de posição pelo dono de rede (`DEALER_POSITION`), limitado por continuidade de deslocamento | nenhuma; é consequência direta da caminhada |
| Morte do corredor com dois prazos (`dealers.downCooldownSeconds` e `downAfterRobberyCooldownSeconds`), detectada por dono de rede + observação anterior de vivo | nenhuma; a especificação não trata morte de dealer |
| Identidade sorteada por tomada (26 nomes, 25 modelos, roster persistido) | nome e modelo fixos no perfil (§5.4) |
| Proteção de gang dona offline (`ownerOffline.protectDealers`) | nenhuma |

Consequências estruturais: o resource tem dez serviços onde o plano previa sete
(`holdup_service`, `feed_service` e `settings_service` a mais), sete repositories onde o plano
previa quatro (`db`, `rotation_repository` e `settings_repository` a mais) e seis migrations onde
o plano previa uma.

O terminal também mudou de forma: a especificação previa um computador com zona de interação, e a
implementação usa um NPC atendente local, porque os locais escolhidos são a céu aberto e não há
MLO nem objeto para mirar.

### 2.3 Decisões técnicas trocadas

| Item | Plano | Implementação | Avaliação |
|---|---|---|---|
| Concorrência em SQL | `SELECT ... FOR UPDATE` em transação | `UPDATE` condicional único com guarda de status, dono e `version` | equivalente ou melhor; sem deadlock |
| Domínio + ledger | mesma transação | statements separados | pendência real, ver `CODE_REVIEW_IMPROVEMENTS.md` P0 |
| Timestamps | `DATETIME` | `INT UNSIGNED`, epoch UTC | coerente e documentado |
| Manifest | globs (`server/*.lua`) | lista explícita por arquivo, com `verifyServices()` abortando start incompleto | melhor: ordem determinística e falha fechada |
| `hirePrice` | dentro do perfil, em shared | `config.dealerHirePrice`, server-side | corrige sigilo econômico que o próprio plano violava |
| `requiredDrugLevel` | por produto | removido | dependia do `noir_illegal_core` |
| `requiredGangGrade` | valor único para claim | tabela `permissions` por ação | já sugerido em §4.3 |

Números de configuração alterados em relação a §14:

- `claim.ownerDurationHours`: 24 → 12;
- `robbery.cooldownSeconds`: 1200 → 600, com o valor 1200 migrando para
  `dealers.downAfterRobberyCooldownSeconds`;
- `claim.defendCooldownMinutes` → `claim.organizationCooldownMinutes`, mantido em 30.

Blocos de configuração que não existiam no plano: `holdup`, `dealers`, `ownerOffline`,
`operationRetention`, `validation`, `alerts` e `rateLimits` detalhado por ação.

### 2.4 Telefone ganhou uma terceira aba

O plano (§10.2) previa abas **Rede** e **Operação**, com notificações agregadas. A implementação
adicionou **Notificações**: feed do ledger paginado por keyset, marcação de "limpo" por
personagem e preferências de categoria de alerta. As migrations `002_operation_feed` e
`003_player_settings` nasceram dessa adição.

## 3. Divergências não registradas

Itens em que a implementação se afastou do plano sem decisão documentada. Os quatro primeiros
são os P0 de `CODE_REVIEW_IMPROVEMENTS.md`, confirmados abertos nesta revisão.

1. **Routing bucket.** §7.1 exige "mesmo routing bucket" em toda revalidação de callback.
   `Security.sameBucket` só é chamado em `Dealer.rivalTarget` e `Dealer.inspect`. Claim,
   contratação, demissão, depósito e coleta não verificam bucket nenhum.
2. **Migrations.** §8.2 exige "migration numerada e não DDL improvisado a cada start". A tabela
   `noir_outpost_migrations` é gravada em `server/init.lua`, mas nunca lida: todo o DDL roda em
   todo start do resource.
3. **Idempotência.** §8.2 exige `operation_id` único para idempotência. O escopo real de
   idempotência é `(citizenid, request_id)`, que tem apenas índice comum, sem `UNIQUE`. O boot
   também não reconcilia operações `prepared` ou `pending`.
4. **Cooldown de claim cancelado.** `config.claim.cancelCooldownSeconds` está definido e não é
   consumido em lugar nenhum. Sem ele, um membro elegível pode alternar start e cancel
   indefinidamente e manter um outpost livre bloqueado para as demais organizações, sem custo.
5. **Visibilidade por papel.** §10.3 restringe o owner ao papel "membro". `State.publicSnapshot`
   envia `ownerOrganizationId` a todos os clients, apesar do comentário afirmando o contrário.
6. **Diagnóstico em produção.** §9.3 proíbe comando de debug habilitado em produção. O callback
   `DEBUG_TARGET` e o comando `/outpostsdebug` são registrados sempre, independentemente de
   `clientConfig.debug`.
7. **Cobertura de testes.** §13 define quatro grupos de critérios. Existem seis specs
   (`validators`, `config`, `sessions`, `manifest`, `scheduler`, `domain`), sendo `manifest` e
   `scheduler` adições não previstas e não citadas no `README.md`. Continuam sem cobertura: bucket
   incorreto, falha de SQL em cada etapa, restart com operação incompleta, troca de dono durante a
   ação, `requestId` simultâneo, provider parado, carga (§13.3) e soak (§13.4).

## 4. Riscos secundários observados

- **Reembolso calculado com preço corrente.** `Service.fire` usa
  `config.dealerHirePrice[profile_key]` no momento da demissão, e não o valor efetivamente pago,
  que só existe no ledger. Alterar preços entre contratação e demissão descasa o reembolso.
- **`GetGameTimer()` estoura em aproximadamente 24,8 dias.** É a base de `consumeRateLimit`, da
  expiração de sessões e dos recuos de mira no client. Sem reinício dentro dessa janela, as
  comparações de expiração e de limite de taxa passam a decidir errado.
- **Retorno de compensação não verificado.** `Service.collect` não confere o resultado de
  `settlePending`, e marca a operação como `paid` de qualquer forma.

## 5. Próximos passos

### P0 — pré-abertura

1. **Desarmar os três overrides de teste e capturar coordenadas.** `rotation.forced`,
   `claim.minOnlinePlayers` e `claim.minPolice` estão marcados com
   `--TODO: NÃO SUBIR PRA PRODUÇÃO ASSIM` em `config/server.lua`. Em paralelo, capturar in-game
   `computer`, `entrance` e seis `dealerCorners` de `docks`, `cypress` e `lamesa`: só o `pier` tem
   coordenada real, então hoje os outros três locais são intestáveis.
2. **Consumir `cancelCooldownSeconds`.** É o P0 de menor custo e fecha griefing gratuito e
   ilimitado sobre outposts livres. Persistir por organização em cancelamento, timeout,
   desconexão e falha de conclusão, distinguindo abandono voluntário de falha interna.
3. **Validar routing bucket nas cinco ações presenciais.** Uma função de apoio e cinco pontos de
   chamada, com código de recusa estável (`invalid_bucket`).
4. **Fechar o diagnóstico.** `DEBUG_TARGET` exigindo ACE administrativo no servidor e
   `/outpostsdebug` registrado somente com `clientConfig.debug` ligado.

### P1 — dívida de integridade

5. Constraint `UNIQUE` para `(citizenid, request_id)` e reconciliação de operações `prepared` e
   `pending` no boot, sem repetir payout.
6. Guarda de dono e `version` do outpost dentro das queries de `hire`, `fire` e `deposit`.
7. Migrations aplicadas uma única vez, consultando `noir_outpost_migrations` antes de executar.
8. Propagação do `errorCode` do provider em `charge` e `refund` de `dealer_service.lua`, para
   `provider_unavailable` não virar `insufficient_funds`.

### P2 — decisão de produto

9. **Fechar a divergência do `noir_illegal_core`.** Recomendação: atualizar a especificação
   declarando que progressão, heat e telemetria externa ficam fora do resource — o código já está
   testado nessa direção e reverter seria caro —, **e** definir no mesmo ato o mecanismo de
   anti-farm que substitui `diminishingReturns`. Sem isso, README, testes, manifest e
   especificação continuam descrevendo sistemas diferentes.
10. **Rodar o soak de §13.4 e coletar a telemetria de §13.3** antes de calibrar preços. É esse
    dado que decide se o teto de estoque sozinho basta como trava econômica.

## 6. Armadilha conhecida

Reduzir `State.publicSnapshot` (item 5 da seção 3) não é uma edição de uma linha.
`Interaction.canRobDealer`, em `client/interaction.lua`, compara `outpost.ownerOrganizationId` com
a gang do jogador para decidir se exibe a opção de roubo. Remover o campo do snapshot desativa a
opção de roubo em silêncio.

O caminho é enviar um booleano `isMine` resolvido por destinatário. `Notification.sendPublicSnapshot`
já opera por `source`, mas `broadcastPublicSnapshot` usa `-1`, então a personalização exige
percorrer os jogadores. Com quatro outposts o custo é irrelevante; o que não existe é a versão
trivial dessa mudança.
