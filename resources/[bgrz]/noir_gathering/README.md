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

Por item da rota: quantidade mínima e máxima, tempo de coleta, ferramenta com desgaste,
stress, ordem aleatória, rota sem fim, animação, itens extras e chance de alerta policial
própria. Por rota: nome, modo, ponto de início, grupos com acesso (job ou gang, com cargo
mínimo), veículo exigido e alerta policial.

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
| `server/routes.lua` | registro, persistência e publicação em `GlobalState['noir_gathering:routes']` |
| `server/storage.lua` | SQL da tabela `noir_gathering_routes` |
| `client/collect.lua` | turno, coleta e AFK do lado do jogador |
| `client/creator.lua` | menus de admin |
| `*/integrations.lua` | único lugar que chama outro resource |

## Dependências

`bgrz_core` (inventário, durabilidade, grupos, stress, notificação, dispatch), `ox_target`
(exceção do §2.5), `noir_lib` (teclas visíveis ao marcar pontos), `ox_lib`, `oxmysql`.

A ferramenta não pode ser item com `degrade`: nesses o ox_inventory guarda um instante
de validade no lugar da durabilidade, e o bridge ignora o slot.

## Veículo exigido

Conferido no servidor: o jogador está a pé, o **último veículo** dele (OneSync) é do
model da rota, e esse veículo está a até `distance.vehicle` metros.

## Testes

```sh
cd resources/[bgrz]/noir_gathering
for f in tests/unit/*_spec.lua; do lua5.4 "$f" || break; done
```
