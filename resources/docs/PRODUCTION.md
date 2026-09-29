# Antes de ir para produção

Lista do que está em valor de teste, desligado ou aberto e precisa ser revisto antes de abrir o
servidor para jogadores. Cada item diz onde está e o que o valor de jogo deveria ser, quando já
se sabe. Riscar o item aqui quando for resolvido; item novo entra na seção certa.

Levantado em 29/09/2026, a partir da análise do ilegal.

## 1. Valores de teste

Estão assim de propósito, para exercitar os sistemas em minutos. Voltar ao valor de jogo.

| Onde | Hoje | Em jogo |
|---|---|---|
| `[noir]/noir_territories/shared/config.lua:55` — `Influence.Rates.drug_sale` | 150 (quatro vendas tomam um bairro) | 10 |
| `[noir]/noir_territories/shared/config.lua:86-87` — `Decay.AfterSeconds` / `EverySeconds` | 1 h de abandono, passo de 10 min | ~48 h, um passo por dia |
| `[noir]/noir_outposts/config/server.lua:25` — `forced = { pier = 'drug' }` | posto do píer fixo | remover; rotação normal |
| `[noir]/noir_outposts/config/server.lua:160` — `minOnlinePlayers` | 0 | 8 |
| `[noir]/noir_outposts/config/server.lua:161` — `minPolice` | 0 | 2 |
| `[noir]/noir_illegal_core/shared/config.lua:42` — `developmentActivityCommand` | `true` (`/noirillegal activity` registra atividade na mão) | `false` |
| `[noir]/noir_tireslash/config.lua:95` — `Config.debug` | `true` (`/tiresound` e log no console) | `false` |

## 2. Polícia mínima e dispatch

Todo roubo abre com zero policial em serviço. Definir o mínimo de cada um junto com o tamanho
real da polícia.

| Onde | Hoje |
|---|---|
| `[qbx]/qbx_bankrobbery/config/client.lua:8-11` — Paleto, Pacific, Fleeca, termite | 0 |
| `[qbx]/qbx_jewelery/config/server.lua:3` — `minimumPolice` | 0 |
| `[qbx]/qbx_storerobbery/config/shared.lua:2` — `minimumCops` | 0 |
| `[qbx]/qbx_truckrobbery/config/server.lua:2` — `numRequiredPolice` | 0 |
| `[noir]/noir_houserobbery/config/server.lua:3` — `minimumPolice` | 0 |
| `[noir]/noir_drugselling/config/MainConfig.lua:18` — `dispatchScript` | `"none"`: a venda de droga nunca chama a polícia, apesar de `dispatchCallChance = 15` |

O ps-mdt não recebe chamado de nenhum crime: tudo cai no fallback do `qbx_police` pelo
`bgrz_core SendDispatch`, porque não há provider de MDT configurado.

## 3. Brechas de servidor confiando no cliente

- **noir_drugselling — recusa prévia no cliente.** Ao abrir a conversa, o cliente sorteia o
  `refuseChance` do tipo de ped (`client/client.lua`, `sellDrugMenu`). Um cliente adulterado
  pula esse sorteio e fica só com o do servidor, que já tem faixa de recusa própria. Ganho
  pequeno de chance; mover o sorteio para o servidor se virar problema.
- **noir_drugselling — medir o log `venda recusada, ped inválido`.** Desde 29/09 o servidor
  recusa venda para ped que não é de rede. Com OneSync e população ligados, ped de rua é de
  rede; se o log aparecer com jogador honesto, algum ped legítimo está caindo fora.
- ~~Preço da venda vindo do cliente sem faixa~~ — resolvido em 29/09.
- ~~Venda sem ped / um negócio por ped só no cliente~~ — resolvido em 29/09.
- ~~`pedType` vindo do cliente~~ — resolvido em 29/09.

## 4. Economia a revisar

- **qbx_pawnshop paga em dinheiro limpo** e o preço de cada item é `math.random(50, 100)`
  sorteado uma vez quando o config carrega (`[qbx]/qbx_pawnshop/config/shared.lua`) — fica fixo
  até o restart. Três fontes de joia (houserobbery, joalheria, cofre de loja) descarregam aqui.
- **Não há lavagem de dinheiro.** `black_money` só serve na loja `BlackMarketArms`
  (`[ox]/ox_inventory/data/shops.lua`) e nos outposts.
- **BlackMarketArms vende arma pronta** e concorre com o `noir_guncraft`, que por sua vez não
  tem fonte de peça, blueprint nem bancada no jogo.
- **Rota de carga dá reputação de gang** (`gathering_delivery`, teto 100, 6 por hora com retorno
  decrescente). Contraria o "missão não dá reputação"; medir no ledger se virou farm.
- **Rota "NOVA" do noir_gathering** (id 2, banco `noir_gathering_routes`) entrega `cokebaggy`
  pronta para os ballas sem exigir `contact_coke`. É a única fonte de droga do servidor.
- **Venda do outpost** paga 55 / 155 / 460 por unidade (`[noir]/noir_outposts/config/server.lua:57-70`)
  contra a faixa de rua 50-100 / 150-250 / 450-700. Revisar junto quando houver tier de qualidade.

## 5. Dados de teste no banco

- `noir_illegal_unlocks`: `organization / ballas / contact_coke` concedido na mão, sem o
  `contact_meth` que é pré-requisito dele.
- `noir_illegal_organization_reputation` e `noir_illegal_activity_ledger`: 15 atividades de
  teste (ballas com 5 de `drug`).
- Rotas do `noir_gathering` criadas em teste.
- Territórios e outposts tomados durante os testes.

Decidir o que zera antes da abertura. O ledger é imutável por desenho; limpar é por `DELETE`
consciente, não por ferramenta do core.

## 6. Resources de desenvolvimento no server.cfg

- `ensure [tools]` sobe `dolu_tool`, `Shadowforge-devtools` e `freecamera`.
- `ensure [bgrz]` sobe `bgrz_interact_examples`, que é demonstração.
- `noir_shell_test` já está com `stop`.
- Conferir quem está em `group.admin` e com as ACEs `noir.illegal.admin`, `noir.gangsetup` e as
  de território/outpost.

## 7. Conteúdo incompleto que aparece para o jogador

Não quebra nada, mas o jogador encontra a porta e ela não leva a lugar nenhum.

- `noir_houserobbery`: uma casa cadastrada; tiers 2 e 3 desligados.
- `noir_burnerphone`: só o contrato de roubo a casa; `drugSales`, `deliveries` e `blackMarket`
  desligados. O burner só sai como loot do smashgrab (10%).
- `noir_prettycrimes`: `progression.enabled = false`, e as atividades `petty_smashgrab` /
  `petty_parkingmeter` que ele chama não existem no `noir_illegal_core`. Allowlist do
  parquímetro vazia.
- `noir_skills`: a habilidade `mecanica` não é treinada nem lida por nada.
- Droga: `weed_brick` e `meth` não nascem no jogo; o `qbx_weed` roda mas não tem semente em
  loja/loot e não produz tijolo.
- `noir_outposts`: cargo checado por número fixo (claim 3, hire 2, stock 1, collect 3), que não
  bate com os arquétipos mc (chefe 5) e cartel (chefe 4) do `noir_gangs`.

## 8. Resolvido

- 29/09 — `qbx_storerobbery`: cofre entregava `markedbills`, item que não existe; agora entrega
  `black_money` no mesmo valor.
- 29/09 — `ox_inventory`: criados `10kgoldchain` (joalheria e pawnshop) e `diamond`
  (derretimento do pawnshop).
- 29/09 — `qbx_pawnshop`: `iphone` e `samsungphone` saíram da lista de compra; nada os entrega.
- 29/09 — `noir_drugselling`: preço preso na faixa do config no servidor.
- 29/09 — `noir_drugselling`: o cliente manda o netId do ped; o servidor confere que ele existe,
  é ped, não é jogador, está a até `DealLimits.MaxDistance` + 2 m e ainda não negociou (lista
  no servidor, limpa por `entityRemoved` ou em 30 min). O tipo do ped sai do modelo.
