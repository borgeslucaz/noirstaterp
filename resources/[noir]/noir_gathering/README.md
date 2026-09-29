# noir_gathering

Rotas de coleta criadas em jogo, pelo admin, sem arquivo de config. Fork do
[mri_Qfarm](https://github.com/mri-Qbox-Brasil/mri_Qfarm) (commit `34b114d`, 2026-07-23)
reescrito sobre o `bgrz_core`, com o servidor decidindo tudo o que antes o cliente decidia.

## Como funciona

**Turno com ponto de início.** O jogador vai ao ponto de início, abre o menu da rota e
escolhe o item. O servidor sorteia ou sequencia o ponto, o GPS leva até ele, o jogador
coleta com uma barra de progresso e o próximo ponto aparece. Sem "rota sem fim", o turno
acaba depois de tantas coletas quantos pontos houver. `F7` (editável em Configurações >
Teclas) encerra.

**Sem início.** Os pontos ficam sempre ativos para quem tem acesso; cada coleta é
independente. Com **AFK**, a coleta se repete no mesmo ponto até o jogador apertar `F7`,
sair de perto ou algo falhar.

**Carga.** O jogador fala com o NPC do início e recebe o veículo da rota numa vaga
definida pelo admin (ou traz um do model exigido). Vai até a pilha de caixas, pega uma
caixa de cada vez e guarda no veículo, que pode ser van, avião ou barco, até completar a
carga. Com a carga completa, a polícia pode ser alertada e o olheiro pode avisar as gangs
rivais. Ele leva o veículo até o destino, tira as caixas uma a uma e deixa no ponto de
entrega. Com a última caixa, recebe os itens da rota e a gang ganha reputação no
`noir_illegal_core`. Sem espaço no inventário, o pagamento fica pendente no ponto de entrega.
Uma rota tem uma carga por vez, com intervalo configurável entre uma saída e a próxima.

Tudo isso é visto por quem está por perto, não só por quem carrega: o NPC e a pilha são
criados em cada client que se aproxima, mesmo sem acesso à rota (sem acesso, só não há
opção no NPC); a caixa na mão é marcada pelo servidor no state bag `noirGatheringCarry`
do jogador, e cada client por perto põe uma caixa na mão dele. São props locais: nada de
entidade de rede para ficar órfã quando alguém cai.
`F7` desiste, depois de confirmar.

Por item da rota: quantidade mínima e máxima, tempo de coleta, ferramenta com desgaste,
stress, ordem aleatória, rota sem fim, animação, itens extras e chance de alerta policial
própria. Por rota: nome, modo, ponto de início, grupos com acesso (job ou gang, com cargo
mínimo), veículo exigido, NPC no início, requisito da gang e alerta policial (chance e raio
da área).

Por rota de carga: pilha (modelo da lista em `config/shared.lua` e posição pela mira),
quantidade de caixas, vaga do veículo, ponto de entrega, itens de recompensa, reputação
da gang (categoria e valor, até o teto da atividade `gathering_delivery` do core), olheiro
(chance e raio) e intervalo.

## Requisito da gang

A rota pode exigir um **desbloqueio** de gang do `noir_illegal_core` (`HasUnlock`), um
**nível mínimo** numa categoria (`GetOrganizationLevel`), ou os dois. O que vale é o da
gang de quem vai jogar. Sem o core no ar, rota com requisito não abre.

## Alertas

**Polícia.** O alerta mostra uma área do raio configurado, com o centro sorteado dentro
de 60% do raio: o círculo cobre o lugar sem apontar para ele. No turno e na coleta livre,
o alerta sai da coleta. Na carga, sai da pilha quando a carga fica completa.

**Olheiro.** Na carga, quando ela fica completa, quem está online numa gang **diferente**
da de quem carregou e que opera o **produto** da categoria da rota (`HasGangProduct` do
`noir_gangs`) recebe uma mensagem no celular e uma área marcada no mapa por
`haul.scoutBlipSeconds`.

## Admin

`/rotascoleta` abre o criador para quem tem o ACE `noir.gathering.admin`
(`permissions.cfg` libera para `group.admin`). Tudo é editado num rascunho e só vale ao
**Salvar**; o servidor revalida a rota inteira, inclusive se cada item existe. Salvar ou
apagar uma rota encerra o turno de quem estava nela. Dá para duplicar, exportar o JSON
para a área de transferência e importar colando o JSON.

Rota salva sem ponto de início (em modo turno) ou sem nenhum ponto não aparece para os
jogadores; o menu avisa.

## O que mudou em relação ao mri_Qfarm

| mri_Qfarm | noir_gathering |
|---|---|
| `getRewardItem` pagava a qualquer chamada, sem conferir ponto, distância nem tempo | o servidor abre a coleta, confere distância, veículo, ferramenta e acesso, e só paga depois do tempo, perto do ponto, uma vez por coleta |
| callback que gravava metadata arbitrária em qualquer slot | removido; durabilidade só pelo `ConsumeItemDurability` do bridge |
| durabilidade e stress aplicados antes da barra, mesmo cancelando | aplicados só na coleta concluída |
| rota sem início não entregava item | entrega |
| extras conferiam o peso do item principal | cada extra confere o próprio |
| recompensa, alerta e extras publicados para todos os clientes | só a visão pública (pontos, tempo, animação) vai para o client |
| `qb-core`, `ps-dispatch`, job `police` fixo, PolyZone, emote menu | `bgrz_core` para tudo; `ox_target` direto (§2.5); dispatch pelo `SendDispatch` |
| `print` a cada coleta | silencioso; `debug = true` em `config/shared.lua` |

Saíram também: modo sem ox_target (marker/PolyZone), integração com `mri_Qbox`, animação
por comando de emote e o "tipo" do alerta do ps-dispatch.

## Arquivos

| Arquivo | Papel |
|---|---|
| `config/shared.lua` | alvo, marcador, blip, tecla, animação padrão, limites |
| `config/server.lua` | ACE, comando, distâncias, tempo mínimo, TTL, dispatch (não vai ao client) |
| `shared/rules.lua` | validação da rota, visão pública, próximo ponto — puro e testado |
| `server/sessions.lua` | turno e coleta, com estados `ACTIVE` → `COLLECTING` → `PROCESSING` |
| `server/hauls.lua` | carga, com fases `LOAD` → `UNLOAD` → `PAY`, trava por rota e veículo |
| `client/haul.lua` | pilha, veículo, destino e olheiro do lado do jogador |
| `client/carry.lua` | caixa na mão de quem carrega, desenhada por todo client por perto |
| `client/npc.lua` | NPC do início, criado perto e apagado longe |
| `client/scenery.lua` | pilha de caixas das rotas de carga, criada perto e apagada longe |
| `client/placement.lua` | posicionar pela mira (NPC, veículo, pilha, entrega), como no noir_garage |
| `server/routes.lua` | registro, persistência e publicação em `GlobalState['noir_gathering:routes']` |
| `server/storage.lua` | SQL da tabela `noir_gathering_routes` |
| `client/collect.lua` | turno, coleta e AFK do lado do jogador |
| `client/creator.lua` | menus de admin |
| `*/integrations.lua` | único lugar que chama outro resource |

## Dependências

`bgrz_core` (inventário, durabilidade, grupos, stress, notificação, dispatch, spawn e
chave do veículo, celular), `ox_target` (chamado direto, §2.5), `noir_lib` (teclas visíveis ao marcar pontos), `ox_lib`,
`oxmysql`.

Opcionais, consultados na hora: `noir_illegal_core` (requisito, catálogo de categorias e
reputação por entrega, pelo evento `noir_gathering:server:routeCompleted`) e `noir_gangs`
(produto das gangs, para o olheiro).

A ferramenta não pode ser item com `degrade`: nesses o ox_inventory guarda um instante
de validade no lugar da durabilidade, e o bridge ignora o slot.

## Veículo exigido

No turno e na coleta livre, a rota não entrega veículo: o jogador traz o dele. Conferido no
servidor: o jogador está a pé e existe um veículo do model da rota a até `distance.vehicle`
metros (60 m).

Na carga, com vaga definida, a rota entrega o veículo com a chave, e o apaga ao fim quando
ninguém está dentro. Sem vaga, o primeiro veículo do model em que o jogador guardar uma
caixa vira o da carga, e nenhum outro serve depois. O veículo do jogador nunca é apagado.

A chave física da van (`vehiclekey` com a placa `CRG…` e a marca `noirHaul`) vai para o
inventário ao pegar a carga e sai quando ela acaba. Carga interrompida por queda ou restart
não consegue tirar a chave, porque o jogador já saiu. Essa chave é recolhida no próximo
login e em todo start do resource (`RemoveItemsWithMetadata` do bridge).

Com **motorista na entrega** (ponto posicionado no menu Carga), o veículo não some: na
última caixa o servidor cria um NPC ali, que entra no veículo e sai dirigindo pela cidade,
à vista de todos. O client de quem entregou dá as ordens; se o NPC não entrar em
`haul.driverEnterMs`, o servidor o põe no banco. Depois de `haul.driveAwayMs` dirigindo,
o servidor apaga o motorista e o veículo.

## Testes

```sh
cd resources/[noir]/noir_gathering
for f in tests/unit/*_spec.lua; do lua5.4 "$f" || break; done
```
