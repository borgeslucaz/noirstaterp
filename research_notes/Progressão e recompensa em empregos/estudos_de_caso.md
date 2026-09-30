# Estudos de caso: progressão em empregos de trabalho repetitivo (simuladores de direção, MMOs, servidores de RP)

Contexto de aplicação: servidor FiveM/Qbox com empregos legais. Caminhão (1 entrega por hora, faixas nos níveis 1/15/35), ônibus (10 níveis, rotas fixas), táxi (pagamento fixo de ~$550/h, 6 níveis que só liberam veículos).

Legenda: [OFICIAL/VERIFICADO] = mecânica documentada por wiki/desenvolvedor/guia; [COMUNIDADE] = opinião de jogador ou crítico.

## 1. Euro Truck Simulator 2 / American Truck Simulator: XP, habilidades, garagens, recepção

### Takeaway
No ETS2/ATS, cada ponto de habilidade faz uma de duas coisas: **abre um tipo novo de carga** (ADR, Frágil, Alto Valor, Just-in-Time) ou **tira um limite** (Longa Distância). Os bônus percentuais (+5% por rank) vêm junto com esse acesso. No fim do jogo, o dinheiro se acumula sem ter onde gastar, e a fase de empresa (garagens e motoristas contratados) acaba reforçando isso.

### Cited Findings
- [OFICIAL] ETS2 e ATS têm XP e níveis. Completar entregas dá XP; subir de nível dá pontos de habilidade que liberam habilidades e cargas novas. — [Truck Simulator Wiki (wiki.gg)](https://trucksimulator.wiki.gg/wiki/Skills); [Wiki (resumo em busca)](https://trucksimulator.wiki.gg/wiki/Skills)
- [OFICIAL] São seis habilidades: ADR, Longa Distância, Carga de Alto Valor, Carga Frágil, Just-In-Time e Eco-Driving. — [Truck Simulator Wiki](https://trucksimulator.wiki.gg/wiki/Skills)
- [OFICIAL] ADR não é linear: cada ponto libera uma classe ADR específica. Carga explosiva (munição, explosivos) só aparece no mercado com a classe ADR certa **e** Frágil. — [Truck Simulator Wiki (via busca)](https://trucksimulator.wiki.gg/wiki/Skills)
- [OFICIAL] Longa Distância: no início só aparecem trabalhos de até 250 km (155 mi). — [Truck Simulator Wiki](https://trucksimulator.wiki.gg/wiki/Skills)
- Longa Distância por rank, segundo a GameRant: R1 400 mi, R2 650 mi, R3 1.000 mi, R6 "qualquer rota". Dá +25% de XP em entregas acima de 250 mi. (Obs.: a GameRant fala em "miles"; o wiki usa km. Unidade a conferir.) — [GameRant](https://gamerant.com/euro-truck-simulator-2-best-skills/)
- Alto Valor: +5% de pagamento por rank, chegando a +30% no R6, e +18% de XP nessas cargas. — [GameRant](https://gamerant.com/euro-truck-simulator-2-best-skills/); [Truck Simulator Wiki (via busca)](https://trucksimulator.wiki.gg/wiki/Skills)
- Frágil: +5% no R1 até +30% no R6, e +22% de XP. — [GameRant](https://gamerant.com/euro-truck-simulator-2-best-skills/)
- Just-In-Time: o rank 1 abre entregas "importantes" (+3% por rank e +20% de XP); o rank 2 abre entregas "urgentes" (+5% por rank e +30% de XP). — [Truck Simulator Wiki (via busca)](https://trucksimulator.wiki.gg/wiki/Skills)
- Eco-Driving reduz o consumo: −10% (R1), −15% (R2), −20% (R3), −35% (R6). — [GameRant](https://gamerant.com/euro-truck-simulator-2-best-skills/)
- [OFICIAL/COMUNIDADE] Com dinheiro suficiente, o jogador compra garagens em outras cidades e contrata motoristas NPC. Esses motoristas ganham XP com o tempo, o que aumenta o que rendem por entrega, e o jogador escolhe em que cada um se especializa. — [Steam discussions ETS2/ATS (via busca)](https://steamcommunity.com/app/227300/discussions/0/2579854400738020014/?ctp=2)
- [COMUNIDADE] Relato de enjoo no fim do jogo: depois de comprar tudo, o jogo fica chato; tem gente com 1 bilhão no banco sem ter no que gastar. Com mais de ~20 motoristas, "faz dinheiro demais para gastar". — [Steam ETS2 discussions (via busca)](https://steamcommunity.com/app/227300/discussions/0/2579854400738020014/?ctp=2)
- [COMUNIDADE] "O jogo é sobre ser caminhoneiro, não gerente de empresa; não há gestão séria." Para dar variedade, a comunidade pede vagas de estacionamento mais difíceis, pátios mais movimentados e diário de bordo com descanso realista, ou seja, desafio na própria direção em vez de mais dinheiro. — [Steam ETS2/ATS discussions (via busca)](https://steamcommunity.com/app/270880/discussions/0/3194740972126544000)

### Inferences
- No ETS2, o bônus percentual nunca aparece sozinho: ele vem junto com a liberação de uma carga nova (tipo de trailer, cor de ADR, distância). O jogador *vê* no mercado o que desbloqueou. Para o caminhão do servidor, cada faixa (1/15/35) deveria abrir algo visível, como carga nova, rota longa ou trailer diferente, e não só um multiplicador.
- Muitos bônus de XP (+18% a +30%) ficam presos a cargas específicas. Isso incentiva escolher contrato, não só repetir. É uma alavanca barata para o limite de 1 entrega por hora: se a entrega é rara, a *escolha* do contrato passa a ser o conteúdo.
- O "dinheiro sem destino" no fim do ETS2 alerta contra renda passiva escalável (motoristas NPC). Num servidor RP com economia compartilhada, isso inflaciona a economia.

### Gaps
- Não consegui números oficiais de XP por nível, pontos por nível nem rank máximo por habilidade (a página do wiki.gg não traz; a da Fandom deu 402).
- Não achei postmortem nem blog da SCS sobre o desenho do sistema de habilidades.

## 2. Outros simuladores de direção e de trabalho (Bus Simulator 21, Taxi Life, Crazy Taxi, Motor Town, Stardew Valley)

### Takeaway
Onde a progressão é só "mais dinheiro" ou "veículo com mais desempenho" (Taxi Life, modo carreira do Bus Simulator 21), a crítica é sempre "falta sensação de progressão". O que funciona: capacidade que muda o trabalho (Motor Town: ônibus maior a cada faixa de nível), habilidade medida na hora (Crazy Taxi: gorjeta por manobra, combo que zera ao bater) e escolha que muda a identidade (profissões do Stardew).

### Cited Findings
- **Taxi Life** [COMUNIDADE/crítica]: "a maioria dos trabalhos é pegar e deixar passageiro, fica repetitivo muito rápido"; "não há sensação real de progressão... não há recompensa por fazer bem". — [eXputer review](https://exputer.com/reviews/taxi-life-a-city-driving-simulator/)
- **Taxi Life** [crítica]: subir de posição libera veículos novos para dirigir e personalizar, mas as melhorias são quase só de desempenho e "raramente transformam a experiência". — [Game Critix](https://gamecritix.co.uk/taxi-life-complete-edition-review/); [GameGrin](https://www.gamegrin.com/reviews/taxi-life-a-city-driving-simulator-review/)
- **Crazy Taxi** [OFICIAL/guias]: "Crazy maneuvers" durante a corrida fazem o passageiro jogar moedas, somadas à tarifa. Quanto mais combos, maior o pagamento. Bater num carro zera o combo. "Crazy Through" (passar rente ao tráfego) paga um pouco mais a cada carro. — [GameFAQs guide](https://gamefaqs.gamespot.com/dreamcast/196990-crazy-taxi/faqs/37349); [XBLAFans](https://xblafans.com/crazy-taxi-guide-how-to-drive-like-a-pro-18658.html)
- **Motor Town** [wiki/guia]: são sete profissões, todas começando no nível 1. Dirigir e fazer trabalhos dá XP e sobe de nível, o que libera veículos e melhorias. — [Motor Town wiki (via busca)](https://motortown.fandom.com/wiki/Experience)
- **Motor Town, ônibus**: no começo só o micro-ônibus. Nível 5 libera o ônibus urbano (28 passageiros) e nível 10 o de turismo (49 lugares). — [Motor Town Bus Job wiki (via busca)](https://motortown.fandom.com/wiki/Bus_Job); [Steam Jobs Guide](https://steamcommunity.com/sharedfiles/filedetails/?l=english&id=2726210461)
- **Motor Town, carga**: começa com caminhão pequeno, depois trailer pequeno; "com nível de entrega 15 você entrega basicamente qualquer coisa". — [Steam Jobs Guide (via busca)](https://steamcommunity.com/sharedfiles/filedetails/?l=english&id=2726210461)
- **Bus Simulator 21, modo carreira** [OFICIAL astragon]: tudo desbloqueado desde o início, o único recurso limitado é o dinheiro. — [astragon news](https://www.astragon.com/news/detail/bus-simulator-21-next-stop-big-update-career-mode-next-gen-map-expansion-gold-edition-and-more-1)
- **Bus Simulator 21** [crítica]: "não há sensação real de progressão, mas você ainda precisa ganhar dinheiro e comprar ônibus"; "pode parecer repetitivo às vezes". — [resultado de busca agregando reviews](https://opencritic.com/game/11922/bus-simulator-21/reviews); [TheSixthAxis](https://www.thesixthaxis.com/2021/09/17/bus-simulator-21-review/)
- **Stardew Valley** [OFICIAL wiki]: cinco habilidades. No nível 5 o jogador escolhe uma entre duas profissões, e essa escolha define as duas opções do nível 10 (seis profissões por habilidade, das quais cada personagem só vê duas). Exemplos: Tiller +10% no valor das colheitas; Rancher +20% em produtos animais; Artisan +40% em bens artesanais; Agriculturist +10% de velocidade de crescimento; Blacksmith +50% em barras. Trocar custa 10.000g na Statue of Uncertainty. — [Stardew Valley Wiki](https://stardewvalleywiki.com/Skills); [stardewvalleyids](https://stardewvalleyids.com/professions)

### Inferences
- O táxi do servidor (pagamento fixo por hora, níveis que só liberam veículo) reproduz exatamente o que a crítica condena no Taxi Life. As alavancas documentadas contra isso são: gorjeta proporcional à qualidade da corrida (tempo, sem colisão, conforto), no estilo Crazy Taxi, e veículo novo que *muda o trabalho* (mais passageiros, corrida VIP), não só troca a skin.
- O ônibus pode copiar o Motor Town: faixas de nível que aumentam a capacidade ou abrem uma categoria de rota (micro → urbano → turismo), em vez de 10 níveis de +x%.
- O Stardew mostra que um bônus percentual funciona melhor quando é *escolha* (bifurcação no nível 5/10) do que quando é automático, porque a escolha cria identidade.

### Gaps
- Não pesquisei a fundo Farming Simulator, PowerWash Simulator nem Truckers of Europe; faltou orçamento de buscas.
- Não confirmei a curva de XP do Motor Town nem o bônus de pagamento por nível (a wiki Fandom deu 402).

## 3. GTA Online e Red Dead Online

### Takeaway
No RDO, os papéis (Trader, Bounty Hunter etc.) têm 20 ranks em faixas de 5. Cada faixa libera equipamento que muda o próprio trabalho (carroça de entrega média, depois grande), e cada rank dá tokens para cosméticos. No GTA Online, a crítica mais recorrente é "grind demais para preços altos": os pagamentos ficaram parados enquanto os preços subiam, e há suspeita de que isso empurra a venda de Shark Cards.

### Cited Findings
- [OFICIAL/guia] O papel de Trader no RDO custa 15 Gold Bars (grátis no PS4) e tem 20 ranks. Cada rank dá 2–3 Role Tokens para cosméticos e equipamentos. — [GTABase Trader Role](https://www.gtabase.com/red-dead-redemption-2/roles/trader-role)
- [OFICIAL/guia] Ranks do Trader com liberação notável: R6 melhoria da bolsa de ingredientes; R7 Awareness; R8 Canine Warning; R11 Efficiency; R13 melhoria da bolsa de materiais; R16 Protection. — [GTABase](https://www.gtabase.com/red-dead-redemption-2/roles/trader-role)
- [OFICIAL/guia] Faixas de equipamento: Novice (1–5) com panela e martelo; Promising (6–10) com a **carroça de entrega média**; Established (11–15) com a **carroça de caça e a carroça de entrega grande**; Distinguished (16–20) com pelagens premium de cavalo e cosméticos. Carroças maiores levam cargas maiores e dão mais lucro. Ataques ao acampamento geram pressão para comprar melhorias de proteção. — [GTABase](https://www.gtabase.com/red-dead-redemption-2/roles/trader-role)
- [OFICIAL] Moonshiner fica travado atrás do Trader. Bounty Hunter é independente (licença de 15 Gold Bars com a Legendary Bounty Hunter em Rhodes). — [busca agregando GTABase/RDR2.org](https://www.gtabase.com/red-dead-redemption-2/online/all-specialist-roles-in-red-dead-online-frontier-pursuits-guide-bounty-hunter-trader-collector)
- [COMUNIDADE/imprensa] "Uma das críticas mais frequentes ao GTA Online é que é grind demais, não recompensa o suficiente, preços altos demais em relação à velocidade de ganhar dinheiro." — [GTA BOOM](https://www.gtaboom.com/gta-online-why-in-game-prices-must-be-high-4475)
- [imprensa] Inflação no GTA Online: um Mini novo custa mais que uma Ferrari antiga. Os pagamentos de missão e dos Shark Cards ficaram praticamente iguais. No lançamento, atividades simples davam ~$20.000 (o bastante para um carro); hoje "não valem quase nada". — [GTABase: Shark Cards need an upgrade](https://www.gtabase.com/news/grand-theft-auto-v/gta-online-shark-cards-need-an-upgrade-to-fix-inflation); [Screen Rant](https://screenrant.com/gta-online-shark-cards-grand-theft-auto-economy/)
- [COMUNIDADE] A Rockstar é acusada de manipular a economia para forçar a compra de Shark Cards. — [Sportskeeda](https://sportskeeda.com/gta/why-gta-6-online-shark-cards)

### Inferences
- O Trader do RDO é o modelo mais parecido com o caminhão do servidor. As faixas liberam *capacidade de entrega* (carroça média → grande), que o jogador vê e usa na hora, e cada rank tem uma recompensa pequena garantida (tokens). Faixas de 5 ranks mantêm o intervalo entre recompensas curto.
- A lição do GTA Online para o servidor: se os preços dos bens (carro, casa) sobem ou o crime paga muito mais, emprego legal com ganho fixo perde sentido. A relação entre renda legal e preços precisa ser revisada junto.

### Gaps
- Não peguei números específicos de negócios do GTA Online (carga CEO, bunker), como pagamento por hora e cooldown; as fontes encontradas são opinativas.
- Não peguei a tabela completa do Bounty Hunter (fonte oficial da Rockstar não aberta).

## 4. Profissões de coleta/craft em MMOs (RuneScape; WoW, BDO, Albion e EVE não cobertos)

### Takeaway
No RuneScape, cada nível de habilidade libera atividade, equipamento ou local novo, e o nível máximo tem um marcador social forte (capa de 99, com "trim" quando se tem uma segunda 99). A Jagex planeja expansões de cap (99 → 110 → 120) com cerca de 11 liberações novas a cada 10 níveis.

### Cited Findings
- [OFICIAL] "Níveis mais altos de habilidade liberam atividades novas: equipamento para fazer, locais para explorar, quests e muito mais." — [RuneScape official skills guide](https://www.runescape.com/game-guide/skills); [RuneScape Wiki Skills](https://runescape.wiki/w/Skills)
- [OFICIAL Jagex] Plano de subir habilidades até 110 "numa cadência regular", em 2–3 anos, depois 120. "Um 110 típico viria com 11 novas liberações de nível." — [Right Click Examine: Future Skilling Content](https://secure.runescape.com/m=news/right-click-examine-future-skilling-content)
- [OFICIAL wiki] A Cape of Accomplishment (skillcape) marca o nível 99 numa habilidade e custa 99.000 coins, vendida pelo mestre da habilidade. Com uma segunda 99, todas as capas ganham um acabamento ("trim") de cor diferente, o que identifica visualmente quem tem várias 99. — [RuneScape Wiki](https://runescape.wiki/w/Capes_of_Accomplishment); [OSRS Wiki](https://oldschool.runescape.wiki/w/Cape_of_Accomplishment)

### Inferences
- Densidade de ~1 liberação por nível ao passar de 99 para 110 (11 em 10 níveis) é a referência de cadência da Jagex. O táxi do servidor tem 6 níveis e só troca veículo; o caminhão tem faixas espaçadas (1/15/35), com buracos de 14 a 20 níveis sem nada visível. Vale pôr liberações pequenas (título, pintura, gorjeta, rota) dentro dessas faixas.
- A capa de 99 mostra que um marcador social visível (roupa, pintura do veículo, título no /me ou no crachá) é uma recompensa de fim de linha barata e muito valorizada.

### Gaps
- Não cobri WoW, Black Desert, Albion nem EVE (transporte). Nenhuma busca foi feita sobre eles, por limite de orçamento.

## 5. Servidores FiveM/RP e scripts de emprego

### Takeaway
Os scripts de caminhoneiro do mercado FiveM convergem para XP por entrega, com nível que libera caminhão ou carga e aumenta o multiplicador, mais ranking entre jogadores. Nos servidores de RP, o emprego civil costuma ser visto como jeito de "pagar as contas". Não achei dados confiáveis de proporção entre renda legal e ilegal nos servidores grandes (NoPixel, Cidade Alta, Complexo).

### Cited Findings
- [produto/descrição de vendedor] Quasar Trucker Job: XP por entrega libera cargas novas e missões mais difíceis, com ranking dos melhores motoristas do servidor por entregas, ganhos e XP. — [Quasar Store](https://www.quasar-store.com/product/trucker-job)
- [produto] DoItDigital Trucker: o motorista começa com veículo básico e libera caminhões mais fortes e contratos que pagam mais conforme sobe de nível. — [DoItDigital Tebex](https://tebex.doitdigital.shop/package/7323667)
- [produto] Ultimate Trucker Simulator (ESX/QB): 4 categorias de habilidade, 24 níveis, veículos por nível, grupo (party) e motoristas NPC. — [Cfx.re forum](https://forum.cfx.re/t/paid-ultimate-trucker-simulator-fivem-script-esx-qbcore-party-system-npc-drivers/5368455)
- [produto] Advanced Trucker Job (grátis): trabalhos curto, médio e longo; o nível sobe o pagamento; 60 pontos de entrega aleatórios por tipo. — [fivem-tebex](https://fivem-tebex.io/tebex-shop/free-advanced-trucker-job-with-ui-xp-system/)
- [wiki de servidor RP russo, via busca] Caminhoneiro: "a cada 16 entregas bem-sucedidas o nível sobe e aumenta o multiplicador de pagamento; níveis liberam pedidos mais lucrativos". — [gta5grand wiki](https://gta5grand.com/wiki/trucker-4/)
- [COMUNIDADE GTA World] O transporte de carga no GTA:W é descrito como popular, com "pagamento generoso" e oportunidade de desenvolver a história do personagem. Há tópicos "Where are the truckers?" e "Trucking Overhaul" (sugestão encaminhada, 10+ páginas), o que indica insatisfação recorrente com o sistema. — [GTA World forums (via busca)](https://forum.gta.world/en/topic/150262-trucking-overhaul/page/10/); [Where are the truckers?](https://forum.gta.world/en/topic/69573-where-are-the-truckers/)
- [COMUNIDADE/guia] NoPixel: os papéis civis (lixo, mineração, entregas, guincho) formam a base da economia legal, mas "alguns jogadores os veem só como forma de pagar taxa de veículo e aluguel". — [nopixelv.top jobs guide](https://www.nopixelv.top/en/jobs/nopixel-v-jobs)
- [COMUNIDADE Steam] "No GTA Online o foco é dinheiro; em servidores RP não é". Alguns servidores (DOJ RP) deixam escolher o status financeiro para eliminar a tentação de grind. — [Steam GTA V discussion (via busca)](https://steamcommunity.com/app/271590/discussions/0/2154350647532634188)
- [OFICIAL regras BR] Servidores brasileiros definem "emprego legal" como zona e veículo onde crime é proibido (ex.: Rise RP, Universe RP). O Complexo (2021) é o principal concorrente do Cidade Alta. — [Rise RP regras](https://rise-group.gitbook.io/regras-or-rise-rp/empregos-legais); [Universe regras](https://regras.universebr.com/empregos-legais); [Manual dos Games](https://manualdosgames.com/os-principais-servidores-de-gta-rp-do-brasil/)

### Inferences
- O padrão de mercado (XP → caminhão/carga nova → multiplicador → ranking) é o mesmo do ETS2. A diferença possível para o servidor está no limite de 1 entrega/h: com poucas entregas, cada uma precisa render XP visível e ter chance de algo raro ou escolha de contrato, senão a faixa 35 fica inalcançável.
- A percepção de emprego legal como "pagar contas" (NoPixel) combina com a crítica ao Taxi Life. Emprego legal sem identidade (título, uniforme, pintura, reputação pública) vira obrigação.

### Gaps
- Não achei números públicos da relação entre renda legal e crime no NoPixel, Cidade Alta ou Complexo. O artigo do Tecnoblog ("Meu segundo emprego é no GTA") deu 403. O guia de trucking do GTA World também deu 403, então não tenho a tabela de níveis dele.
- Não abri threads do Reddit (r/GTARP, r/FiveM) diretamente.

## 6. O que os jogadores relatam como recompensador ou chato (percentual pequeno vs liberação visível)

### Takeaway
Nas críticas e fóruns, o padrão é: progressão que só aumenta número (dinheiro, desempenho) é chamada de "sem progressão" (Taxi Life, BS21 carreira, fim do ETS2). Liberação que muda o que se faz ou mostra status (carga ADR, ônibus maior, carroça grande, capa de 99) sustenta o loop. Não achei estudo quantitativo comparando os dois.

### Cited Findings
- "Não há sensação real de progressão... não há recompensa por fazer bem" (Taxi Life). — [eXputer](https://exputer.com/reviews/taxi-life-a-city-driving-simulator/)
- "Melhorias raramente transformam a experiência." — [Game Critix](https://gamecritix.co.uk/taxi-life-complete-edition-review/)
- BS21 carreira com tudo liberado: "não há sensação de progressão". — [agregado de reviews](https://opencritic.com/game/11922/bus-simulator-21/reviews)
- Fim do ETS2: dinheiro sem destino, "fica chato depois de comprar tudo"; os pedidos de melhoria são sobre desafio na direção, não sobre mais dinheiro. — [Steam ETS2](https://steamcommunity.com/app/227300/discussions/0/2579854400738020014/?ctp=2)
- GTA Online: pagamento parado mais preço inflacionado viram "grind que não recompensa". — [GTABase](https://www.gtabase.com/news/grand-theft-auto-v/gta-online-shark-cards-need-an-upgrade-to-fix-inflation)

### Inferences
- Recomendação para o servidor: cada nível do ônibus e do táxi deveria liberar algo *usável ou visível* (rota nova, veículo com mais capacidade, gorjeta ou bônus por qualidade, pintura ou título), com o percentual como complemento. O caminhão precisa de marcos intermediários entre 1, 15 e 35.
- Pagamento por desempenho (gorjeta tipo Crazy Taxi, bônus JIT do ETS2 com +20–30% de XP) dá variação e sensação de habilidade que o pagamento fixo por hora não dá.

### Gaps
- Não há dado empírico (retenção, telemetria) comparando +x% com liberação visível. As evidências são críticas e fóruns.
