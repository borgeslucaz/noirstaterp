# Revisão do ilegal e da progressão (set/2026)

> Estado de tudo o que é crime, skill, reputação de gang e heat no servidor, cruzado com a pesquisa [Recompensa e progressão no roleplay](Recompensa%20e%20progressão%20no%20roleplay/README.md). Fonte: quatro auditorias só de leitura no código e no `server.cfg`, feitas em 30/09/2026. Onde há número, ele vem do config. Onde há "recomendo", é opinião.

## Resumo

O servidor tem as **peças** de um ecossistema criminal bom, mas elas **não conversam**:

- **Skills.** O `noir_skills` tem 4 habilidades. Três funcionam (`arrombamento`, `trafico`, `cultivo`) e uma está órfã (`mecanica`). A maioria dos crimes não dá XP.
- **Reputação de gang.** O `noir_illegal_core` tem reputação, níveis de 0 a 5, unlocks (`contact_meth`, `contact_coke`) e um ledger, mas **ninguém consome os unlocks e ninguém escuta os eventos dele**. Os níveis de gang não liberam nada no jogo.
- **Heat.** Existe só por personagem, com valor de 0 a 100. Só a venda de rua e o outpost somam heat, e **nada lê esse valor**. Venda de rua sozinha nunca aquece, porque o heat decai mais rápido do que sobe.
- **Economia.**
  - Meth não tem origem; coca só sai pronta de uma rota de teste.
  - Tijolo não tem receita.
  - Lavagem não existe.
  - Vários crimes pagam **dinheiro limpo**, e o maior é o bônus de 10 mil da carga ilegal do caminhão.
- **Polícia.** Não recebe salário. Todo crime aceita **0 policiais**. A venda de rua não chama a polícia. O MDT registra ficha, mas é uma ilha que nenhum sistema lê.
- **Segurança.** Dois eventos do `qbx_police` (`SeizeCash` e `RobPlayer`) não conferem emprego. Qualquer jogador pode disparar.

Pelas regras da pesquisa, o problema não é falta de conteúdo, e sim de **ligações**:
- a reputação conta volume em vez de marco;
- o risco não tem consequência;
- o que a gang conquista não muda nada;
- o crime paga mais limpo que sujo.

## 1. Skills do personagem (`noir_skills`)

| Skill | Quem dá XP | Quem usa o nível | Situação |
|---|---|---|---|
| arrombamento | mri_Qcarkeys: ligação direta (10), lockpick de carro (8), cooldown 20 s | chance da ligação direta | funciona |
| trafico | noir_drugselling: venda fechada (5 a 50 por tipo de ped) | bônus de preço de 1% a 10% | funciona |
| cultivo | noir_weed: colheita (10 + 2 por bud) | rendimento, teto do grau, vantagens | funciona |
| mecanica | ninguém | ninguém | órfã: `qbx_mechanicjob` e `qbx_customs` estão parados |

Os eventos `xpChanged` e `levelChanged` **não têm ouvinte**, então nenhum sistema reage à subida de nível.

**Crimes ligados que não dão XP nenhum:**

| Crime | Onde contar (servidor, no sucesso) | Skill sugerida |
|---|---|---|
| noir_houserobbery | `completeContract` → `finalizeRobbery(…, true)`; porta arrombada | nova `furto`; porta dá `arrombamento` |
| noir_prettycrimes (smash, parquímetro) | loot entregue | `furto`, pouco XP |
| qbx_storerobbery, jewelery, truckrobbery, bankrobbery | saque entregue | `furto`, crescendo com o risco |
| noir_guncraft | pickup da arma pronta (nunca no início: o cancelamento devolve o material) | nova `armeiro` |
| noir_weed, mesa de embalar | fim da rodada | fração de `trafico`, se quiser |
| noir_gathering | entrega da rota | opcional; hoje dá reputação de gang |
| tireslash, graffiti | — | não dar XP: é trivial e fácil de farmar. O graffiti já pesa no território |

**Regra da pesquisa (§1 e §8):** contar na conclusão validada pelo servidor. A falha pode dar uma fração do XP, com cooldown. Nunca contar no minigame do cliente.

**Empregos legais** (táxi, ônibus, caminhão) já têm nível, ranking e histórico próprios. **Manter separados.** No máximo, espelhar no painel `/skills` só para leitura.

**O que não contamos e deveríamos (estatística por personagem):** colheitas, embalagens, roubos concluídos, carros roubados, apreensões sofridas, prisões e crafts. Existe o ledger de reputação do core, mas ele é restrito a quem pode gravar. **Recomendo um ledger de estatística genérico** (`citizenid, stat, delta, at`). Ele alimenta o mural público da pesquisa (§7), o killboard e o relatório de economia (§9).

## 2. Reputação e nível da gang (`noir_illegal_core`)

| Atividade | Reputação da gang | Problema |
|---|---|---|
| Venda de rua | drug +0,5 por venda (pessoal drug +2, street +1) | **volume**: retorno decrescente por jogador por hora, então mais membros multiplicam; o piso de 0,2 é eterno; sem teto diário; ignora droga e grau |
| Venda passiva do outpost | drug +0,1 | até ~170/dia com estoque cheio, contra meta de 15–25 |
| Tomar outpost | drug +25, street +5 | sem retorno decrescente; a mesma gang retoma o próprio posto |
| Roubar outpost | 0 para quem rouba; −5 para a dona | ok |
| Segurar bairro | drug +5 por bairro por dia | **renda passiva eterna**: `KeepOwnerAtThreshold` segura a gang parada como dona |
| Tomar bairro | **0** | o marco mais visível do jogo não paga nada |
| Perder bairro | −15 | cobra até na troca feita por admin (`force`) |
| Rota de carga (gathering) | até 100 por entrega | 3 entregas = meth liberada; o cooldown vive em memória e zera no restart; **contraria "missão não dá reputação"** |
| Graffiti | só influência de bairro | ok |
| houserobbery, prettycrimes, guncraft, tireslash, weed | nada | houserobbery, guncraft e prettycrimes deveriam contar alguma coisa |

**Unlocks.** `contact_meth` (drug 2) e `contact_coke` (drug 4) são concedidos, mas **nenhum sistema os usa**. Níveis 1, 3 e 5, e todas as outras categorias (street, weapons, items, ammo, attachments), não liberam nada. O `unlockGranted` não tem ouvinte, então **o contato não liga**. Não existem missões de prova nem laboratório.

**Dois planos em conflito para a origem da coca:**
- a memória de 23/09 diz que o **unlock pela reputação** libera o contato, e a missão de prova libera a droga;
- o `resources/docs/ilegal/04_NOIR_LABS.md` diz que o **laboratório de Davis segue quem controla o bairro** (2000 de influência).

Precisa escolher um, ou combinar os dois (ver próximos passos).

**Pelas regras da pesquisa:**
- **§1, marco em vez de volume:** a venda conta por quantidade, e tomar bairro, que é o marco, paga zero. Está invertido.
- **§2, reputação e heat saem da mesma ação:** hoje não saem (ver §3).
- **§7, decair o que se disputa e preservar o conquistado:** o nível não decai (certo), mas o **controle do bairro também não decai para quem está parado** (errado).

## 3. Heat

- **Onde existe:** só por personagem, de 0 a 100 (`noir_illegal_player_heat`).
  - Decai 9 por hora de **relógio**, mesmo com o jogador offline.
  - O retorno decrescente **também reduz o heat**, então quem mais vende menos aquece.
  - Venda de rua dá no máximo ~7 por hora, abaixo do decaimento. Na prática, **vender não aquece nunca**.
- **Quem soma heat:** só a venda de rua (0,35), a tomada de outpost (2) e o roubo de outpost (4). **Nenhum outro crime aquece.**
- **Quem lê heat:** ninguém. A única regra é o `dealer_contact` (heat abaixo de 25), e nenhum sistema usa esse unlock.
- **Heat de gang:** não existe. O core **recusa de propósito** ("heat é de uma pessoa").

**Quem chama a polícia hoje:**

| Crime | Alerta | Mínimo de policiais |
|---|---|---|
| Venda de rua | **nenhum** (`dispatchScript = "none"`) | — |
| Outpost | venda passiva 10%; roubo e dealer morto 75%; tomada, nada | `minPolice = 0` (TODO de teste) |
| houserobbery | só se o morador acordar | 0 |
| prettycrimes | 20–25% | — |
| roubos qbx | sim, com chances variadas | **0 em todos** |
| arrombamento de carro | nenhum (a flag `AlertSend` não é usada) | — |
| tireslash, graffiti, guncraft, weed | nenhum | — |

**O dispatch perde informação.** Não há provider configurado, então tudo cai no fallback do `qbx_police`, que manda só coordenada e mensagem. Code, prioridade e duração se perdem. Nenhum alerta leva gang, veículo ou suspeito, e o MDT não vê os chamados.

**Pelas regras da pesquisa:**
- **§2:** o heat precisa sair da mesma ação que dá reputação, **na gang**, com procurado de 0 a 4 que só baixa com prisão.
- **§4, punir o que não se esconde:** tempo, acesso e reputação. Hoje o heat não pune nada.

## 4. Economia e conteúdo ilegal

**Origem das drogas:**

| Droga | Origem hoje |
|---|---|
| Maconha (buds, saquinho) | noir_weed |
| Semente nível 3, saquinho vazio, mesa | **sem fonte** (o black market não existe) |
| Tijolo de maconha | **sem receita** (a prensa não existe). Drugselling e outposts compram mesmo assim |
| Coca | pronta, da rota de teste `NOVA` do gathering, sem exigir `contact_coke` |
| Meth, crack | **sem fonte** |

**Dinheiro sujo.** Só compra arma, na `BlackMarketArms`: punhal 5 mil, pistola 50 mil. **Não existe lavagem**, embora os preços de droga já contem 25% dela.

**Crime pagando limpo (furo):**

| Onde | Quanto |
|---|---|
| noir-truckjob, carga ilegal | **+10.000 por entrega** |
| qbx_pawnshop | joia vira dinheiro limpo (lavanderia de itens) |
| noir_houserobbery | pilha de 100–800 |
| noir_prettycrimes | tudo |
| qbx_storerobbery, caixa | 80–200 |

**Insumos sem fonte:**
- bancada, blueprints, pólvora e peças do guncraft;
- spray do graffiti;
- `advancedlockpick`;
- thermite e trojan_usb (banco);
- `burner_phone` (só 10% num único loot).

**Polícia contra o crime:**
- planta queimada e mesa apreendida são dreno, mas não pagam nada ao policial;
- droga no inventário fica com quem revistou;
- o `/seizecash` entrega o dinheiro limpo apreendido ao policial;
- `black_money` não é apreendido;
- a polícia não recebe salário (`paycheckEnabled = false`).

## 5. Segurança (antes de tudo)

1. **`qbx_police` `SeizeCash` e `RobPlayer`:** os eventos de rede não conferem emprego. `RobPlayer` transfere o dinheiro de qualquer jogador para quem disparar o evento.
2. **Resíduos de teste:**
   - `forced = { pier = 'drug' }`, `minOnlinePlayers = 0` e `minPolice = 0` nos outposts (marcados "NÃO SUBIR PRA PRODUÇÃO");
   - tempos de teste no `noir_territories` e `drug_sale = 150` de influência (quatro vendas tomam um bairro);
   - `ballas / contact_coke` concedido à mão no banco, sem o pré-requisito;
   - rota `NOVA` de teste.

## Próximos passos

A ordem segue a da pesquisa: medir e fechar furos → dar consequência → dar sentido ao que se conquista → conteúdo novo.

### Fase 0: furos (curto, sem design novo)
1. Conferir emprego e serviço nos eventos `SeizeCash` e `RobPlayer` do `qbx_police`. O dinheiro apreendido vai para o cofre da polícia ou é destruído, não para o policial.
2. Reverter os TODOs de teste de outposts e territórios. Limpar o unlock e a rota de teste no banco.
3. **Crime paga sujo:** carga ilegal do caminhão, pawnshop (ou só itens legais), houserobbery, prettycrimes e caixa registradora passam a pagar `black_money`. Revisar o valor da carga ilegal (10 mil é de 18 a 30 vezes uma venda de saquinho).
4. Mínimo de policiais em serviço por crime, em tabela pública: saquinho 0 (preço cai sem polícia), tijolo e outpost 2, roubos qbx 2 a 4.

### Fase 1: a polícia existe na economia
5. **Salário de plantão da polícia** perto da âncora civil, e bônus por apreensão como fração do valor destruído, com teto por hora. A droga e o `black_money` apreendidos são destruídos (dreno).
6. **Dispatch da venda de rua** ligado pelo `bgrz_core`, com chance baixa (5–15%) que sobe com repetição no mesmo ponto. Configurar um provider de dispatch que chegue ao MDT sem perder code e prioridade.

### Fase 2: heat que pesa (personagem e gang)
7. **Heat de personagem que acumula:**
   - tirar o retorno decrescente do heat;
   - decair por **hora jogada**, não por relógio;
   - todo crime soma heat pelo adaptador do core: houserobbery, prettycrimes, roubos qbx, arrombamento, guncraft e tomada de bairro.
8. **Heat de gang de 0 a 9 → procurado de 0 a 4** (Blades):
   - sobe com as ações vistas da gang (tomada, roubo de outpost, morte em operação +2);
   - o procurado **só baixa com prisão** de um membro, ligando `xt-prison` ao core;
   - procurado alto aumenta alerta, trava contato e dá sinal à polícia.
9. **Ficha por personagem:** ler do MDT (`IsCidFelon`, acusações) ou ter uma ficha própria que decai por hora jogada. Ficha alta fecha outpost, contato e loja.

### Fase 3: reputação que premia marco, não volume
10. **Tomar bairro paga** um marco (+15 a +25 por bairro, gang e período). Os +5 por dia saem de quem não teve atividade no período. O controle de bairro decai para a gang parada.
11. **Teto diário por organização** em `drug_sale` e `outpost_sale`. Considerar grau e droga no valor (a qualidade é o eixo).
12. `outpost_claim` sem pagamento na retomada do mesmo posto. `gathering_delivery` com teto baixo (10–15) e cooldown persistido.
13. Contar houserobbery, guncraft e prettycrimes na reputação pessoal `street`, e na da gang só quando for operação vista.

### Fase 4: o que se conquista muda o jogo
14. **Listener de `unlockGranted`:** o contato liga no celular descartável (`noir_burnerphone`).
15. **Missão de prova** por contato, concedendo `drug_meth` e `drug_coke`. A missão não dá reputação.
16. **Origem de meth e coca.** Decisão pendente entre os dois planos. Recomendo combinar:
    - o **unlock da gang** libera a receita (quem sabe fazer);
    - o **laboratório** fica num bairro e segue quem o controla (onde fazer).
    - Assim, território e reputação empurram o mesmo lado, e o laboratório vira alvo de disputa.
17. **Cada nível de gang libera algo concreto** (contato, capacidade, tipo de droga, estoque), nunca multiplicador de preço. Dar uso a street, weapons, items, ammo e attachments ou tirar essas categorias.

### Fase 5: fechar a cadeia e a economia
18. **Black market** (sistema separado; o `noir_shops` é só dinheiro limpo): semente nível 3, saquinho vazio, mesa, prensa, insumos do guncraft, spray e lockpick avançado, em dinheiro sujo.
19. **Prensa e receita de tijolo** (o drugselling e os outposts já compram tijolo).
20. **Lavagem de dinheiro:** 20–30%, com tempo, por negócio de jogador ou NPC com limite diário. Os preços já contam com ela.
21. **Ledger de estatística por personagem** e **mural público da cidade**: maior apreensão, variedade mais bem avaliada, primeira gang a mover tijolo num outpost.
22. **Skills novas** `furto` e `armeiro`. Decidir se `mecanica` sai ou espera um emprego de mecânico.

### Decisões que precisam de você
- A origem da coca: unlock da gang, controle do bairro ou os dois (recomendo os dois, item 16).
- O pawnshop continua comprando joia roubada em dinheiro limpo? Recomendo pagar sujo, ou comprar só o que não é de roubo.
- O guncraft ganha fonte de insumos (produto `weapons` da lostmc) ou sai do ar? Hoje concorre com a `BlackMarketArms`.
- Heat de gang: tirar a trava "heat é só de pessoa" do core (necessário para o item 8).
