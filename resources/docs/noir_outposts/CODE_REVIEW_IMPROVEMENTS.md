# Melhorias pendentes — `noir_outposts`

> Revisão registrada em 2026-09-12.
>
> Escopo: estado atual de `resources/[bgrz]/noir_outposts`, confrontado com
> `resources/docs/SCRIPT_GOOD_PRACTICES.md` e
> `resources/docs/noir_outposts/OUTPOST_NPC_DRUGSELL.md`.

Este documento registra os riscos e as melhorias priorizados na revisão do resource.

## P0 — Integridade e autorização

### Validar routing bucket nas ações presenciais

`Security.isNear` valida somente a coordenada do ped. Claim, contratação, demissão, depósito e
coleta não confirmam que o jogador está no mesmo routing bucket esperado pelo outpost. Um callback
forjado pode, portanto, executar uma ação a partir de uma instância privada na mesma coordenada.

Arquivos relacionados:

- `server/security.lua` (`Security.isNear`);
- `server/services/claim_service.lua` (`validate`);
- `server/services/dealer_service.lua` (`ownedEntry`).

Ação recomendada:

- definir explicitamente o bucket esperado pelo outpost, usando `0` como padrão;
- validar o bucket no início e na conclusão de toda ação presencial;
- retornar um código estável, como `invalid_bucket`;
- adicionar teste para claim, depósito e coleta a partir de bucket diferente.

Critério de aceite: nenhuma mutação presencial pode ocorrer quando o jogador estiver fora do
bucket configurado para o outpost.

### Tornar as operações econômicas recuperáveis após falha parcial

Existem janelas nas quais inventário/dinheiro e banco do domínio podem divergir:

- a contratação cobra antes de persistir uma operação `prepared`, e o reembolso não verifica nem
  registra a própria falha;
- a coleta não verifica a inserção no ledger nem o resultado de `settlePending`;
- a venda aplica estoque, carteira e agenda antes de inserir a operação correspondente, fora da
  mesma transação;
- o roubo não verifica todas as restaurações e atualizações finais;
- o bootstrap não reconcilia operações `prepared` ou `pending`;
- `(citizenid, request_id)` possui apenas um índice comum, sem constraint `UNIQUE`.

Arquivos relacionados:

- `server/services/dealer_service.lua`;
- `server/services/stock_service.lua`;
- `server/services/sale_service.lua`;
- `server/services/robbery_service.lua`;
- `server/repositories/operation_repository.lua`;
- `migrations/001_initial.sql`.

Ação recomendada:

- adotar uma state machine persistente (`prepared` → `pending` → `paid`/`committed` ou
  `compensated`/`failed`);
- inserir o registro da operação antes do primeiro efeito externo;
- executar mutação do domínio e ledger na mesma transação SQL;
- verificar e registrar o retorno de toda compensação;
- reconciliar operações incompletas no startup sem repetir payout;
- criar constraint única para o escopo de idempotência escolhido;
- preservar operações incompletas durante a rotina de retenção.

Critério de aceite: restart ou falha de banco/provider em qualquer etapa não pode duplicar nem
perder silenciosamente dinheiro, item, estoque ou purse.

### Revalidar owner e versão dentro das queries de mutação

`hire`, `fire` e `deposit` validam o proprietário antes de operações que cedem a execução. A query
final não repete status, organização proprietária e versão do agregado. Uma expiração ou rotação
concorrente pode fazer uma ação do owner anterior atingir o estado novo.

Arquivos relacionados:

- `server/services/dealer_service.lua`;
- `server/services/stock_service.lua`;
- `server/repositories/dealer_repository.lua`;
- `server/repositories/stock_repository.lua`.

Ação recomendada:

- passar `organizationId` e `outpost.version` para a operação de persistência;
- condicionar `INSERT`, `DELETE` e `UPDATE` ao outpost continuar `controlled`, com o mesmo owner e
  a versão esperada;
- recarregar o agregado e retornar `conflict` quando nenhuma linha for afetada;
- incluir cenários concorrentes nos testes.

Critério de aceite: uma ação iniciada antes da troca de controle nunca altera o estado do novo
proprietário.

### Aplicar cooldown depois de claim cancelado ou abandonado

`config.claim.cancelCooldownSeconds` está definido, mas não é consumido. O cancelamento libera o
lock imediatamente, permitindo que um jogador elegível inicie e cancele claims repetidamente para
impedir outras organizações de disputar o outpost.

Arquivos relacionados:

- `config/server.lua` (`claim.cancelCooldownSeconds`);
- `server/services/claim_service.lua` (`cancel` e handler de abort);
- `server/sessions.lua`.

Ação recomendada:

- persistir cooldown por organização em cancelamento, timeout, desconexão e falha de conclusão;
- diferenciar falha interna de abandono voluntário para não punir o jogador por indisponibilidade
  do servidor;
- adicionar rate limit/cooldown por `organizationId + outpostId`, não somente por `source`.

Critério de aceite: a mesma organização não consegue manter um outpost livre permanentemente
bloqueado por ciclos de start/cancel.

## P1 — Exposição de dados e operação

### Reduzir o snapshot público e proteger ferramentas de diagnóstico

`State.publicSnapshot` afirma não expor owner, mas envia `ownerOrganizationId` a todos os clients.
O callback `DEBUG_TARGET` e o comando `outpostsdebug` também ficam disponíveis mesmo quando
`clientConfig.debug` está desligado. O diagnóstico revela posições, tolerâncias e a forma como a
validação server-side está sendo calculada.

Arquivos relacionados:

- `server/state.lua` (`publicSnapshot`);
- `server/api.lua` (`DEBUG_TARGET`);
- `client/interaction.lua` (`outpostsdebug`);
- `config/client.lua`.

Ação recomendada:

- enviar ao público somente `controlled`/`isMine` quando o ID do owner não for necessário;
- filtrar informações conforme o papel descrito na especificação;
- registrar comando e callback de diagnóstico apenas quando debug estiver habilitado;
- exigir ACE administrativo no servidor para `DEBUG_TARGET`.

Critério de aceite: um jogador comum não recebe identidade de owner nem detalhes internos do
anti-exploit que não sejam necessários ao gameplay.

### Executar somente migrations ainda não aplicadas

A tabela `noir_outpost_migrations` é preenchida, mas nunca consultada. Todos os arquivos de
migration, inclusive DDL, são executados em todo start do resource. Isso contraria o guia de boas
práticas e pode causar metadata locks ou falhas desnecessárias durante restart.

Arquivo relacionado: `server/init.lua` (`runMigration` e `runMigrations`).

Ação recomendada:

- criar/garantir primeiro a tabela de controle;
- consultar migrations aplicadas antes de executar cada arquivo;
- registrar a aplicação somente depois de todas as instruções concluírem;
- tratar a gravação da versão como obrigatória;
- documentar estratégia de rollback/recuperação.

Critério de aceite: depois da primeira aplicação, um restart normal não executa novamente o DDL
das migrations antigas.

### Preservar códigos de erro dos providers

Alguns fluxos descartam o segundo retorno do `bgrz_core`. Com isso, `provider_unavailable` pode
virar `insufficient_funds`, `not_enough_items` ou `cannot_carry`, dificultando diagnóstico e
produzindo feedback incorreto.

Arquivos relacionados:

- `server/integration.lua`;
- `server/services/dealer_service.lua`;
- `server/services/stock_service.lua`;
- `server/services/robbery_service.lua`.

Ação recomendada:

- propagar `ok, errorCode` integralmente pelos serviços;
- distinguir indisponibilidade, capacidade, saldo e falha interna;
- registrar falha de refund/compensação com `operationId`;
- adicionar testes com bridge e provider parados.

Critério de aceite: provider parado retorna `provider_unavailable` sem falso sucesso e sem ser
traduzido para erro de regra de negócio.

### Resolver divergência com `noir_illegal_core`

`OUTPOST_NPC_DRUGSELL.md` define activities, heat, diminishing returns e `RecordActivity` como
integração obrigatória. A implementação e o README decidiram não usar progressão externa, e o
teste de configuração exige que `noir_illegal_core` não seja dependência.

Arquivos relacionados:

- `resources/docs/noir_outposts/OUTPOST_NPC_DRUGSELL.md`;
- `resources/[bgrz]/noir_outposts/README.md`;
- `resources/[bgrz]/noir_outposts/tests/unit/config_spec.lua`.

Ação recomendada:

- decidir qual contrato é autoritativo;
- se a integração for mantida fora do resource, atualizar a especificação e documentar o
  mecanismo substituto de heat, anti-farm e telemetria;
- se a especificação continuar válida, implementar activities idempotentes e retry sem repetir a
  venda.

Critério de aceite: README, testes, manifest e especificação descrevem a mesma decisão, com uma
proteção explícita contra farm econômico.

## Testes a adicionar

- claim, coleta e depósito no routing bucket incorreto;
- falha SQL antes e depois de cada efeito externo;
- restart com operação `prepared` e `pending`;
- falha durante refund, restore de estoque e `settlePending`;
- troca de owner durante hire, fire e deposit;
- duas requisições simultâneas com o mesmo `requestId`;
- claim start/cancel repetido por source e organização;
- acesso de jogador comum ao callback de debug;
- snapshot público sem campos privados;
- bridge, banco, inventário, phone e dispatch indisponíveis;
- soak test com restart e conferência final entre ledger, estoque e purse.

## Aspectos já adequados

- queries parametrizadas e restritas ao schema próprio;
- preços, quantidades, loot e cooldowns resolvidos no servidor;
- allowlist para outposts, perfis e produtos;
- rate limit e resolução server-side do ator;
- validação de net ID contra o registro server-side;
- NUI sem `eval`, CDN ou inserção de HTML arbitrário;
- cleanup de sessões, entidades, blips e foco;
- scheduler único, loops com `Wait` e sem query por frame.
