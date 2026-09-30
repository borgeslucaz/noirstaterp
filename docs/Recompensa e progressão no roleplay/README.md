# Recompense o que gera cena, não o que gera volume

> Pesquisa de set/2026 sobre recompensa e progressão em jogos e como levar isso para o roleplay do servidor. Complementa o relatório [Progressão e recompensa em empregos](../../reports/Progressão%20e%20recompensa%20em%20empregos.md), que já cobre dopamina e erro de previsão, esquemas de reforço, Teoria da Autodeterminação, limiar perceptivo de aumento (5–8%), curvas de XP e dark patterns. Esses pontos não se repetem aqui. As fontes e as ressalvas de cada afirmação estão nas notas:
> - [RPG de mesa e RP em texto](notas/rpg_de_mesa_e_rp_em_texto.md)
> - [MMOs sandbox: risco, perda e status](notas/mmos_sandbox_risco_e_status.md)
> - [Servidores FiveM de RP](notas/servidores_fivem_rp.md)

Tudo o que um sistema recompensa vira o jogo que as pessoas jogam. No D&D antigo, 1 peça de ouro valia 1 XP, e o combate virou um custo a evitar: o jogo passou a ser planejar o roubo e sair vivo com o saque. Quando o 2e tirou esse XP, só matar monstro rendia, e o combate virou o padrão. No NoPixel 4.0, a gangue passou a ser medida pela produção diária de moeda. As gangues criaram "street teams" para fazer o grind por elas, e a própria wiki registra que "a vontade de grindar morreu". Nas facções brasileiras, a meta semanal de farm fica em planilha de bot de Discord. Num servidor de roleplay, portanto, a pergunta de design não é "quanto pagar", e sim **"que comportamento o pagamento cria"**. As pesquisas convergem em seis regras:
1. Recompensar o fechamento, e não a produção.
2. Colocar reputação e risco na mesma ação.
3. Deixar a progressão morar nas coisas: variedade, pureza, território.
4. Tirar estoque e nunca progresso.
5. Separar por zona quem aceitou o risco de quem não aceitou.
6. Dar plateia ao que o jogador conquistou.

E um alerta: não tentar medir "RP bom", porque qualquer métrica vira alvo.

## 1. O que conta como recompensa define o jogo

No OD&D e no AD&D 1e, o tesouro só vira XP **depois de sair da masmorra** e ser guardado. Tesouro fácil vale menos, e subir de nível exige treino pago ([EN World, primer do DMG 1e](https://www.enworld.org/threads/experience-points-leveling-a-brief-primer-on-xp-in-the-1e-dmg-and-why-it-still-matters.679663/); [DMDavid](https://dmdavid.com/tag/the-fun-and-realism-of-unrealistically-awarding-experience-points-for-gold/)). O resultado, nas palavras de quem joga, é que monstros viram "dangerous obstacles rather than XP piñatas" ([Kate Plays](https://kateplays.substack.com/p/xp-for-gold)). O mesmo princípio aparece do lado negativo no FiveM:
- no Eclipse RP, o script premiava produção, e "criminosos ficam sentados em apartamentos por horas todo dia" fabricando droga ([fórum Eclipse](https://forum.eclipse-rp.net/topic/109242-why-criminal-script-discourages-roleplay/));
- no NoPixel 4.0, a gangue medida em BUT Coin por dia terceirizou o grind ([Civ Gang/4.0](https://nopixel.fandom.com/wiki/Civ_Gang/4.0); [Street Team/3.0](https://nopixel.fandom.com/wiki/Street_Team/3.0));
- as facções brasileiras usam bot com "metas semanais" e "faltas" ([faction-bot](https://github.com/peSuperSam/faction-bot); [BOSS XP](https://www.bossxp.com.br/)).

Para o servidor, isso vira três regras:
- **Reputação de venda conta na venda concluída, nunca na colheita nem na mesa.** Perder a carga para a polícia ou para um assalto tira progresso de verdade, e o transporte vira parte do jogo. A skill de cultivo pode continuar subindo na colheita, porque ali o próprio cuidado com a planta é o comportamento desejado.
- **Nível de gangue sobe por marco (prova, contato, território), nunca por quilo entregue.** Contador de volume favorece quem tem mais gente ralando e transforma membro em funcionário.
- **Nenhuma reputação por kill.** A lição do 2e é que, quando só a violência paga, o jogo vira violência.

## 2. Reputação e heat saem da mesma ação

Blades in the Dark é o sistema publicado mais próximo de uma gangue de GTA RP, e o SRD oficial é aberto ([SRD](https://github.com/amazingrando/blades-in-the-dark-srd-content/blob/main/Blades-in-the-Dark-SRD.md)):
- **Rep e heat.** Golpe feito em silêncio dá **0 de rep e 0 de heat**. Golpe barulhento dá rep e heat, e qualquer morte soma +2 de heat, "whether the crew did the killing or not".
- **Rep pela diferença de tier.** A rep por golpe é 2, com +1 por tier que o alvo tem acima da crew e −1 por tier abaixo. Uma crew grande não farma em cima de uma pequena.
- **Nível de procurado.** Com 9 de heat, a crew ganha 1 nível de procurado, e esse nível só cai com **prisão** de alguém ligado a ela.
- **Subir de tier.** Custa dinheiro (novo tier × 8) e deixa a crew com domínio fraco até se consolidar. Território barateia a subida ([Heat](https://bladesinthedark.com/heat); [Faction Game](https://bladesinthedark.com/faction-game)).

Essa estrutura resolve problemas que servidores costumam resolver com regra escrita e staff:
- a gangue escolhe entre discrição (dinheiro sem fama) e fama (contato novo, mas polícia em cima);
- a polícia ganha um objetivo mecânico, porque prender alguém da gangue baixa o nível de procurado dela;
- a gangue ganha o dilema de "quem assume".

A tensão continua depois de subir, porque o nível novo chega frágil.

## 3. A progressão mora nas coisas, não só no personagem

O que as wikis de fã do NoPixel registram como marco nunca é "nível 30":
- a Aurora Kush chegou a "Legendary", a maior reputação de variedade da cidade;
- o Street Team produzia meth com 90–100% de pureza;
- a Seaside conquistou 36 sprays de território ([Street Team/3.0](https://nopixel.fandom.com/wiki/Street_Team/3.0); [Seaside/3.0/Territory](https://nopixel.fandom.com/wiki/Seaside/3.0/Territory)).

O Star Wars Galaxies fez disso o centro do jogo. Segundo Koster, a sensação de poder deveria vir de capacidades novas, "not from incrementing the maximum value of some bars". O nome do artesão ficava permanente no item, "this is how the best crafters in the game build their reputation" ([Koster](https://www.raphkoster.com/2015/04/21/designing-a-living-society-in-swg-part-one/); [SWGR](https://swgr.org/wiki/crafting/)). No mercado de scripts, o Lation leva a pureza da planta da colheita até o saquinho e usa esse valor no preço de rua ([Lation Weed](https://lationscripts.com/product/weed-growing)).

Isso confirma a regra que já adotamos: **o tier e a qualidade da droga são o eixo, e o nível do vendedor é só multiplicador**. Os próximos passos naturais para o `noir_weed`:
- **Pureza como metadado**, da saúde da planta na colheita até o bud e o saquinho. O preço de rua sai da pureza. Assim a skill de cultivo passa a valer em dinheiro por outro caminho além da quantidade de buds.
- **Lote e autoria no saquinho** (quem embalou, qualidade, lote). Isso dá reputação de produto, dá à polícia rastreabilidade em RP e dá escolha ao comprador. É barato de fazer pelo metadata do ox_inventory.
- **Reputação da variedade na cidade.** Sobe com saquinho de boa pureza vendido e cai com produto ruim ou apreendido. Quem sustenta qualidade alta pode batizar a variedade, e o nome circula entre personagens.

## 4. Perder dá significado, desde que o jogador tenha escolhido o risco

Dean Hall, sobre DayZ: "This potential of loss is probably the most powerful vector of DayZ … It means you value it" ([Engadget](https://engadget.com/2013/03/29/gdc-2013-dean-hall-on-the-pillars-of-dayzs-design)). A pesquisa acadêmica sobre permadeath chega à condição que falta nessa frase: a perda é positiva quando é **significativa**, fruto de escolha e de contexto. Quando é aleatória, só frustra ([Carter & Allison 2017](https://intellectdiscover.com/content/journals/10.1386/jgvw.9.2.143_1)). O Ultima Online mostra o custo do erro. Koster chama o player killing de "our biggest mistake": com Trammel, a população "roughly doubled; our churn rate fell massively" ([UO postmortem](https://www.raphkoster.com/2018/03/28/uo-postmortem-from-gdc2018/)).

O UO ensina outra coisa. Toda punição que o criminoso pode contornar foi contornada:
- o confisco de banco fez os assassinos guardarem os bens em casa;
- a flag criminal curta fez os ladrões andarem nus ([Game Developer](https://www.gamedeveloper.com/design/a-brief-history-of-murder-in-ultima-online)).

Para o servidor, ficam quatro regras:
- **Apreensão tira estoque e dinheiro em mão, nunca nível, skill ou receita.** É o meio-termo entre significado e frustração num RP que não faz wipe.
- **O tamanho da carga é a decisão do jogador.** Sair com 5 saquinhos ou com 3 tijolos é escolha, e a perda precisa ser proporcional a ela. Perda por bug ou por NPC que surge do nada é a "morte ruim".
- **Calibrar para a aversão à perda.** Perder pesa cerca de 2× o mesmo ganho (λ ≈ 2,25, com faixa de 1,5 a 2,5 e críticas: [resumo](https://en.wikipedia.org/wiki/Loss_aversion)). Com chance de apreensão *p* e perda *L*, o lucro de uma viagem bem-sucedida precisa ficar na ordem de 2·p·L para ser *sentido* como vantajoso.
- **Punir o que não se esconde**: tempo (prisão), acesso (ficha alta fecha outpost e loja) e reputação da gangue. Multa sobre saldo bancário vai ser contornada.

## 5. Risco por zona protege quem não escolheu o crime

Bartle descreve uma dinâmica de população mais útil que a própria tipologia: "increasing the number of killers will decrease the number of socialisers by a much greater degree". Ele acrescenta que regras fortes de roleplay ajudam o equilíbrio ([Bartle 1996](https://mud.co.uk/richard/hcds.htm)). O EVE e o Albion traduzem isso em geografia:
- no high-sec do EVE, o CONCORD "does not exist to defend players; they simply enforce the consequences". No low-sec e no null-sec, a resposta diminui e a renda sobe ([EVE Uni](https://wiki.eveuniversity.org/Suicide_ganking));
- na zona amarela do Albion, a morte é só knockdown. Nas zonas vermelha e preta, há full loot, e parte do que cai é destruída ([Albion Wiki](https://wiki.albiononline.com/wiki/Open_World)).

A tradução para o servidor:
- **Emprego legal é "zona amarela".** O motorista pode ser assaltado em RP e perder o dinheiro em mão, mas não perde veículo da empresa nem progresso.
- **Circuito da droga é "zona vermelha".** Quem pega tijolo aceita perder a carga inteira.
- **Centro da cidade é high-sec.** Venda de rua ali paga pouco e a polícia chega rápido.
- **Outposts e pontos remotos são low-sec.** Pagam mais, com resposta mais lenta e risco real de roubo entre gangues.
- **A polícia funciona como o CONCORD.** Ela garante que a consequência seja certa e proporcional, e não que o crime seja impossível.

## 6. Interdependência vem de vantagem, não de proibição

No SWG, "the idea that people you don't know well at all are in fact crucial to your survival" sustentava a sociedade inteira. O NGE cortou 34 profissões para 9, e a base debandou ([Koster](https://www.raphkoster.com/2015/04/21/designing-a-living-society-in-swg-part-one/); [Wikipedia](https://en.wikipedia.org/wiki/Star_Wars_Galaxies)). Os dados de Yee com 3.000 jogadores mostram que as motivações não se excluem, com correlações abaixo de 0,10 ([Yee 2006](https://nickyee.com/pubs/Yee%20-%20Motivations%20(2007).pdf)). Não faz sentido trancar papel. O taxista de dia pode embalar à noite.

A cadeia plantador → embalador → vendedor só é real se cada elo tiver um diferencial que o outro não copia barato:
- **o plantador** define a pureza;
- **o embalador** define o rendimento, e o Foco do Albion é o modelo: uma cota diária que melhora o retorno e custa menos a quem se especializa ([Albion Wiki](https://wiki.albiononline.com/wiki/Crafting_Focus));
- **o vendedor** tem território e confiança por zona, com retorno decrescente, como no Var ([comparativo](https://www.var-fivem.com/en/guides/best-fivem-drug-script)).

O jogador solo pode fazer tudo, com rendimento pior. O NoPixel mostra o melhor efeito colateral disso: insumo vindo de emprego legal (placas, madeira) gerou negociação de preço entre civis e gangues, e até guerra por preço de material ([Chang Gang/4.0](https://nopixel.fandom.com/wiki/Chang_Gang/4.0)). No nosso caso, saquinho vazio e fertilizante podem sair da cadeia legal.

## 7. Plateia é recompensa

"MMORPGs are in essence reputation games … without an audience of other players to whom these items could be displayed, the game would make little sense" ([Ducheneaut et al., CHI 2006](http://www.nickyee.com/pubs/Ducheneaut,%20Yee,%20Nickell,%20Moore%20-%20Alone%20Together%20(2006).pdf)). As matérias sobre por que o GTA RP prende citam gente e histórias, não dinheiro ([NME](https://www.nme.com/features/gaming-features/why-a-grand-theft-auto-roleplaying-mod-is-so-popular-among-streamers-3135169)). O que as wikis guardam são primeiros:
- "primeira a roubar o cofre inteiro";
- "primeiro grupo a 100/dia" ([City Vault/3.0](https://nopixel.fandom.com/wiki/City_Vault_(Pacific_Standard_Public_Deposit_Bank)/3.0)).

Status funciona melhor quando é sinal custoso, difícil de fingir: uma nave de torneio com tiragem limitada, o nome no item.

Para o servidor:
- **Separar fama de ficha**, como o UO separou fame de karma. Um traficante famoso e um taxista famoso têm fama alta, mas só um tem ficha.
- **Mural público da cidade** (app no celular ou jornal) com os marcos da semana: maior apreensão, variedade mais bem avaliada, primeira gangue a mover tijolo num outpost, taxista com mais corridas. Transforma número privado em fama.
- **Decair o disputável, preservar o conquistado.** Território e ranking do mês decaem. Nível de gangue e skill não. O honor do WoW vanilla, com decaimento de 20% por semana, virou obrigação de logar ([Wowpedia](https://wowpedia.fandom.com/wiki/Honor_system_(Classic))).
- **Horizontal no topo.** Depois do nível máximo, liberar opções, cosméticos e a capacidade de treinar novatos, em vez de mais porcentagem.

## 8. Não tente medir "RP bom"

"When a measure becomes a target, it ceases to be a good measure" ([Goodhart/Strathern](https://en.wikipedia.org/wiki/Goodhart's_law)). As comunidades de RP persistente que já tentaram:
- **Armageddon MUD:** o karma era dado pela staff e colheu acusações de favoritismo ("good rpers… stay at 0-2 karma for life", [fórum](https://armageddonmud.boards.net/thread/724/armageddon-incentivized-roleplay));
- **GTA World:** ouviu da comunidade que RP bom deveria ser o normal, e não algo premiado ([fórum](https://forum.gta.world/en/topic/73306-rewarding-good-rp/), lido só pelo trecho do buscador);
- **Arx MUSH:** usa 13 votos cegos por semana, com retorno decrescente, mais recompensas objetivas como cena com personagem novo e diário ([Arx XP Guide](https://play.arxmush.org/topics/XP%20Guide/));
- **Space Station 13:** vive sem progressão persistente e só usa horas jogadas para liberar cargos de chefia ([tgstation config](https://github.com/tgstation/tgstation/blob/master/config/config.txt)).

Os RPGs de mesa têm duas ideias que escalam para servidor:
- **Recompensar a ousadia, não o resultado.** No Blades, "It doesn't matter if the action is successful or not". No Dungeon World, "Any time you roll a 6- you get XP right away" ([DW SRD](https://www.dungeonworldsrd.com/playing-the-game/)).
- **Pagar por aceitar complicação voluntária**: o compel do Fate, o Devil's Bargain do Blades ([Fate SRD](https://fate-srd.com/fate-core/invoking-compelling-aspects)).

Hierarquia recomendada, da mais segura para a mais arriscada:

| # | Tipo de recompensa | Exemplo no servidor | Risco |
|---|---|---|---|
| 1 | Gatilho objetivo por log, com teto semanal | venda concluída fora do território, operação contra gangue de nível maior, pena cumprida sem deslogar, cena com novato, falha em minigame | Goodhart (provocar a polícia pelo bônus): premiar só risco real |
| 2 | Complicação aceita em troca de pagamento | "entregar num ponto quente: +X% de pagamento, +heat"; recusar é sempre possível | baixo; o preço é explícito |
| 3 | Confiança da staff para liberar papel | liderança de gangue alta, comando de polícia: horas + ficha limpa + aprovação | favoritismo, se virar recurso |
| 4 | Voto cego entre jogadores | poucos votos, retorno decrescente, voto da mesma gangue vale menos; só cosmético ou social | troca de votos |
| – | **Evitar** | staff dando dinheiro, rep ou XP por "RP bonito"; XP por kill | favoritismo, RP performático, deathmatch |

## 9. A economia do crime precisa de dreno e de polícia paga

Os fóruns do Eclipse registram as duas falhas no mesmo servidor. Em 2017, "nenhum RP criminal dá dinheiro". Em 2023, "faço 20k numa hora em emprego legal", e as gangues sumiram ([2017](https://forum.eclipse-rp.net/topic/5210-character-server-criminal-new-player-economy-eco-system-improvements/); [2023](https://forum.eclipse-rp.net/topic/141104-the-lack-of-gangs/)). Os guias de economia de FiveM (blogs de terceiros, não auditáveis) repetem a mesma receita:
- o crime rende 30–50% a mais em potencial, mas tem **valor esperado parecido** com o legal depois do risco;
- de cada $1 que entra, $0,60–0,90 precisa sair por algum dreno ([FiveBrowse](https://fivebrowse.com/blog/your-economy-is-broken-balancing-money-jobs-and-progression); [Cybernex](https://cybernex.lk/knowledge-base/fivem-roleplay-server-economy)).

A principal causa de inflação apontada é "renda de droga que cai como dinheiro limpo" ([Var](https://www.var-fivem.com/en/guides/best-fivem-drug-script)).

Os mundos persistentes que duram gerenciam isso com drenos desejáveis e com medição:
- o OSRS cobra 2% de imposto no Grand Exchange e recompra itens raros para apagá-los ([Jagex](https://secure.runescape.com/m=news/grand-exchange-tax--item-sink?oldschool=1));
- o Albion cobra 6,5–10,5% no mercado e destrói itens na morte;
- o EVE publica um relatório econômico mensal.

O corte bruto de renda do EVE (a "Scarcity") funcionou na economia, mas derrubou logins, segundo quem acompanha os relatórios ([TAGN](https://tagn.wordpress.com/2026/06/17/the-may-2026-eve-online-monthly-economic-report-and-how-much-isk-is-too-much-isk/)).

Aplicações:
- **Meta do crime em relação à âncora de ~$550/h.** Por hora *ativa*: 1,5–2× bruto e 1,1–1,3× depois do risco. Por hora *logada*: não mais que ~1,5×, porque planta e outpost têm espera.
- **Dinheiro sujo desde o início.** Saquinho e tijolo pagam em dinheiro marcado, e a lavagem custa 20–30% e tempo. É dreno, e é cena para o negócio de um jogador civil.
- **Apreensão é o dreno natural do crime.** A droga apreendida é destruída. O policial ganha uma fração do valor de rua (10–20%, com teto por hora), sempre menor que o valor destruído, para o dreno continuar líquido.
- **A polícia precisa receber antes de o crime pagar bem.** Hoje o `qbx_core` está com `paycheckEnabled = false`, e a polícia tem `payment` 50/75. Na prática, não há salário automático. Plantão perto da âncora civil, mais o bônus de apreensão, faz a polícia querer a cena.
- **Mínimo de policiais por tabela pública**, como os servidores brasileiros fazem ([FOX RP](https://foxrp.com.br/regras.html)):
  - saquinho sem mínimo, mas com preço ligado à polícia em serviço (×0,7 com 0 policial, ×1,0 com 1–2, ×1,2 com 3 ou mais);
  - tijolo com 2 ou mais policiais, conferido no aceite **e** na entrega. O bug conhecido do mercado é a venda continuar depois que a polícia desloga ([Cfx.re](https://forum.cfx.re/t/advanced-drug-sales/5196911?page=3)).
- **Sem mercado global de droga.** O preço varia por bairro e cai com saturação do ponto, o que preserva o papel do vendedor.
- **Instrumentar antes de ajustar.** Registrar emissão e remoção por fonte (táxi, ônibus, caminhão, saquinho, tijolo, lavagem, multa, apreensão) e somar por semana. Preferir adicionar dreno desejável a cortar pagamento que o jogador vê.

## 10. Aplicação por sistema

### Skill de cultivo (feedback "tá pouco recompensador")

A pesquisa explica a queixa: a skill só mexe num número, a quantidade de buds. Pelo que as três notas mostram, o que torna uma skill sentida é:
- **marcos que mudam o que o jogador faz**, na linha da proposta anterior: planta bebe menos, cresce mais rápido, devolve semente, libera mais um vaso;
- **um segundo eixo de valor**: nível mais alto dá pureza maior, e pureza maior dá preço maior;
- **falha que dá progresso parcial**, já que planta mal cuidada ainda rende XP proporcional aos buds;
- **reconhecimento**: a variedade mais bem avaliada da semana no mural, com direito a batizar.

A progressão de venda fica no `trafico`, contada na venda concluída.

### Gangues (níveis 0–5)

- rep por operação *vista*, ajustada pelo tier do alvo;
- heat de 0 a 9 que vira nível de procurado de 0 a 4, que só baixa com prisão de alguém ligado à gangue;
- subir de nível custa dinheiro e começa com domínio fraco;
- território barateia a subida e decai; o nível não decai;
- nível alto libera contato, tipo de droga e capacidade (estoque, plantas simultâneas), nunca multiplicador de preço. Isso segue o modelo atual (reputação abre contato, prova libera droga) e não amarra à gangue o que já foi decidido que é livre, como semente e plantio.

### Polícia

- salário de plantão mais bônus por apreensão;
- progressão por atendimento registrado (prisão com processo, apreensão), nunca por kill;
- armário de pertences na saída da prisão, uma solução do Eclipse que custa zero;
- o mesmo personagem não pode estar na polícia e numa gangue.

### Empregos legais

Seguem o relatório de empregos: degraus de ~8%, nenhum nível silencioso, especialização horizontal. Dois acréscimos desta pesquisa:
- **zona amarela**: perde-se só o dinheiro em mão;
- **insumo para a cadeia ilegal**: o caminhão pode entregar a carga que abastece a loja de onde saem saquinho e fertilizante.

### Todos os sistemas

- mural público de marcos;
- fama separada de ficha;
- ficha criminal que decai por horas *jogadas* (como o murder count do UO) e baixa com serviço legal;
- teto de 6 criminosos por ação com polícia (regra do NoPixel).

## O que evitar

- Recompensar volume produzido: meta de farm, moeda de gangue por quantidade.
- Venda a NPC como a melhor venda do servidor. A venda entre jogadores precisa ter espaço para ser mais lucrativa no atacado.
- Droga pagando em dinheiro limpo.
- Punição monetária que se contorna escondendo dinheiro.
- Perda de progresso na apreensão ou na morte.
- Decaimento agressivo de nível.
- Staff premiando RP subjetivamente.
- XP por kill.
- Chance de chamar a polícia em 99% das vendas (o padrão do qb-drugs): vira spam que a polícia ignora. Melhor 5–15%, subindo com repetição no mesmo ponto.
- Corte visível de pagamento sem anúncio.

## Próximos passos, por custo e impacto

1. **Instrumentar a economia**: log de emissão e remoção por fonte, relatório semanal. Sem isso, os números acima são estimativa.
2. **Salário da polícia e bônus por apreensão**, antes de subir os preços da droga.
3. **Pureza e lote no `noir_weed`**, com preço de rua pela pureza. Dá sentido à skill de cultivo e prepara a reputação de variedade.
4. **Revisar a skill de cultivo** com marcos, e não só porcentagem.
5. **Dinheiro sujo e lavagem** antes de ligar tijolo e outposts.
6. **Heat e nível de procurado de gangue**, integrados à polícia.
7. **Mural público de marcos.**

A incerteza continua empírica. Nenhuma fonte mede retenção em servidor de RP comparando esses modelos. A evidência vem de regra publicada, entrevista de designer, wiki de fã e relato de jogador, e o Reddit e o fórum do GTA World ficaram inacessíveis na coleta. Por isso a ordem acima começa por medir.
