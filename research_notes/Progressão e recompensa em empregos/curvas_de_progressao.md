# Curvas de progressão, níveis, desbloqueios e cadência de recompensa

Contexto aplicado: emprego de caminhão (1 entrega/hora, tiers baixo/médio/alto em níveis 1/15/35, máximo 100 → proposta 60, pagamento ~$861 → ~$2.072, +0,6%/nível), táxi âncora ~$550/h com 6 níveis (só veículos), ônibus com 10 níveis (vários vazios). Queixa: progressão não parece recompensadora.

Nota de método: runescape.wiki, oldschool.runescape.wiki e bulbapedia devolveram 403; fórmulas vieram de espelhos/fandom e sites de referência (citados). Não consegui abrir o artigo do Michigan sobre o leak de Destiny (DNS falhou).

## 1. Formas de curva de XP e metas de tempo por nível

### Takeaway
A prática dominante é "rápido no começo, lento depois": curvas polinomiais (Pokémon, cúbica) ou exponenciais (RuneScape, dobra a cada 7 níveis). A exponencial faz os últimos níveis valerem metade de todo o esforço — o que só funciona se esses níveis carregam status/identidade; quando cada nível não entrega nada, designers (Blizzard) cortam níveis em vez de acelerar XP.

### Cited Findings
- RuneScape: XP total para o nível L = ⌊¼ · Σ(x=1..L−1) ⌊x + 300·2^(x/7)⌋⌋. — [RuneScape experience formula (search result / OSRS Fandom)](https://oldschoolrunescape.fandom.com/wiki/Experience); [tritecode](http://tritecode.wikidot.com/article:2008:09:16:runescape-exp)
- Após ~nível 20 a XP total dobra a cada 7 níveis; 1→92 = 6.517.253 XP e 92→99 = 6.517.178 XP, i.e. 92 é "metade do 99". — [OSRS Wiki Fandom, Experience](https://oldschoolrunescape.fandom.com/wiki/Experience)
- RuneScape: nível 120 exige 104.273.167 XP; teto de 200 milhões de XP por skill (XP continua contando após o nível máximo). — [Wikipedia, Experience point](https://en.wikipedia.org/wiki/Experience_point)
- Pokémon, 6 grupos (XP total no nível n): Fast = 4n³/5 (800.000 no 100); Medium Fast = n³ (1.000.000); Medium Slow = 6n³/5 − 15n² + 100n − 140 (1.059.860); Slow = 5n³/4 (1.250.000); Erratic (piecewise, 600.000; lento no começo, muito rápido no fim); Fluctuating (piecewise, 1.640.000; rápido no começo, muito lento no fim). — [Pokestats growth rates](https://pokestats.gg/growth-rates); [Serebii](https://www.serebii.net/games/exp.shtml)
- Os 4 grupos originais são cúbicos; Erratic/Fluctuating são efetivamente quárticos (cubo × função linear). — [pret/pokecrystal wiki](https://github.com/pret/pokecrystal/wiki/Erratic-and-Fluctuating-experience-growth-rates)
- Alternativa comum: manter XP por nível constante mas reduzir a XP ganha pela mesma tarefa conforme o nível sobe. — [Wikipedia, Experience point](https://en.wikipedia.org/wiki/Experience_point)
- WoW Shadowlands (2020): nível 120 virou 50, cap novo 60; 1→50 projetado para ser mais que 2× mais rápido; ~35 h de 1→60 para novatos (estimativa). — [Icy Veins](https://www.icy-veins.com/wow/shadowlands-leveling-changes-after-level-squish); [Wikipedia Shadowlands](https://en.wikipedia.org/wiki/World_of_Warcraft:_Shadowlands)
- Motivo do squish (Ion Hazzikostas): com o sistema de talentos atual o jogador não ganha ponto a cada nível, "most level-up moments don't bring much"; subir 1→120 era "kind of an empty experience" sem sensação de poder; cada expansão somando níveis "não era saudável". — [Wolfshead Online](https://wolfsheadonline.com/blizzard-dev-ion-hazzikostas-admits-wow-leveling-is-pretty-broken/); [Blizzard Watch](https://blizzardwatch.com/2020/09/24/world-warcraft-need-level-squish/)
- Crítica: o squish foi "a bad idea" segundo blogueiro veterano (TAGN) — contraponto de opinião, não dado. — [TAGN](https://tagn.wordpress.com/2024/01/02/the-shadowlands-era-level-squish-was-a-bad-idea/)
- Casual (Kladova, Game Developer, 2020): level-up nos primeiros 3–5 rounds; 7–15 níveis em 30–60 rounds; depois do início ~1 nível a cada 10–20 rounds (bons jogadores) ou 20+ (fracos). Fórmula "mais rápida no começo, mais lenta depois"; alerta que progressão rápida demais gera excedente de moeda e fim precoce. — [Game Developer](https://www.gamedeveloper.com/design/creating-a-casual-game-progression-curve)
- Schreiber (Game Balance Concepts, 2010): definir a duração desejada do jogo antes de balancear; recompensas esparsas desmoralizam, grandes demais perdem impacto; muitos ganhos pequenos > um grande; agenda variável (atrelada à ação) reforça mais que fixa; escalonar ganhos de poder, novas áreas e história para não coincidirem. — [Game Balance Concepts, Level 7](https://gamebalanceconcepts.wordpress.com/2010/08/18/level-7-advancement-progression-and-pacing/)
- Artigo recente descreve "hook" com curva rasa nos ~30 primeiros minutos em F2P/live-service e níveis altos caros como status. — [DEV Community (2026, blog, fonte fraca)](https://dev.to/sam_novak_574b07811e18495/curves-are-the-real-game-design-language-and-most-broken-games-got-the-curve-wrong-4dg1)

### Inferences
- Com 1 entrega/hora, o "round" do caminhão é de 1 hora — muito mais longo que qualquer referência (rounds de minutos). Seguindo Kladova, o primeiro level-up deveria vir nas primeiras 1–3 entregas, não depois de muitas horas.
- Níveis 1/15/35 como únicos marcos em 60 (ou 100) níveis replicam exatamente o problema que a Blizzard citou: a maioria dos "dings" não entrega nada. O corte 100→60 é coerente com o squish, mas só resolve se os níveis restantes ganharem conteúdo.
- Inconsistência a verificar: +0,6%/nível por 59 níveis dá ~+35% (≈ $1.165 partindo de $861), não $2.072 (+141%). O salto de ~2,4× deve vir dos tiers; então o pagamento real sobe em degraus (1→15→35), e os +0,6% por nível são quase imperceptíveis (~$5 por entrega por nível).
- Curva exponencial estilo RuneScape (metade do esforço nos últimos ~8% dos níveis) só é aceitável se o topo for prestígio/identidade (como a capa do 99); para um emprego com teto de pagamento, curva polinomial suave ou lineares com marcos é mais adequada.

### Gaps
- Não achei fonte primária com meta numérica genérica "X minutos por nível" em MMOs; os números concretos são de jogo casual e do WoW (horas totais).
- Não consegui abrir as wikis oficiais (403) para confirmar as tabelas; os números vêm de espelhos concordantes.

## 2. Ritmo de desbloqueios: algo novo a cada nível vs níveis mortos; horizontal vs vertical; cosmético vs poder

### Takeaway
Os designers tratam o nível como um cronograma de recompensas: cada nível deve entregar algo percebido (poder, opção, área, história ou status) e os tipos devem se alternar. Níveis vazios foram a razão explícita do squish do WoW. Recompensas horizontais/cosméticas preservam o equilíbrio econômico sem inflacionar pagamento.

### Cited Findings
- Blizzard: a perda do ponto de talento por nível tornou a maioria dos level-ups sem significado. — [Wolfshead Online](https://wolfsheadonline.com/blizzard-dev-ion-hazzikostas-admits-wow-leveling-is-pretty-broken/)
- Schreiber: níveis fazem parte de um sistema integrado de recompensas (poder, novas áreas, história), escalonados; muitos ganhos pequenos geram mais satisfação que um grande. — [Game Balance Concepts](https://gamebalanceconcepts.wordpress.com/2010/08/18/level-7-advancement-progression-and-pacing/)
- Schreiber: habilidade do jogador e poder do personagem são intercambiáveis na dificuldade percebida: PerceivedDifficulty = (SkillChallenge + PowerChallenge) − (PlayerSkill + PlayerPower). — [Game Balance Concepts](https://gamebalanceconcepts.wordpress.com/2010/08/18/level-7-advancement-progression-and-pacing/)
- Hades (Mirror of Night): cada slot tem duas versões alternativas (roxa = poder puro; verde = troca com custo); reset barato devolve toda a Darkness → progressão que é de escolha (horizontal) além de poder. Várias moedas, cada uma ligada a um tipo de progressão. — [Hades Wiki](https://hades.fandom.com/wiki/Mirror_of_Night); [TheGamer](https://www.thegamer.com/hades-mirror-of-night-roguelite-progression/)
- CoD: prestígio clássico (Black Ops 6) reseta ao nível 1 ao chegar a 55 em troca de cosméticos exclusivos por prestígio; 10 prestígios ≈ 550 níveis. MW recentes: prestígio sem relock de conteúdo, limitado por temporada. — [Game8](https://game8.co/games/Call-of-Duty-Black-Ops-6/archives/468369); [Activision support](https://support.activision.com/black-ops-6/articles/progression-in-black-ops-6)

### Inferences
- Para o caminhão: distribuir 60 níveis com algo a cada nível, alternando tipos — ex. a cada nível: +XP/pagamento pequeno visível; a cada 5: cosmético (skin/placa/uniforme/título); a cada 10: vantagem horizontal (rota nova, carga especial, escolha de contrato); 15/35: tier. Nenhum nível "silencioso".
- Táxi com 6 níveis só de veículos e ônibus com níveis vazios: vale acrescentar marcos horizontais (rotas, títulos, cosméticos) em vez de aumentar pagamento, para não quebrar a âncora de $550/h.

### Gaps
- Não encontrei dado quantitativo (retenção A/B) comparando "algo novo a cada nível" vs níveis vazios; a evidência é de declaração de designers.

## 3. Prestígio, maestria, títulos, coleções e battle passes (e FOMO)

### Takeaway
Prestígio e marcos de maestria dão metas de longo prazo baratas economicamente (status, cosmético). Battle passes com prazo são criticados por FOMO; tendência recente (Helldivers 2, Halo Infinite, Marvel Rivals) é passe que não expira.

### Cited Findings
- CoD prestígio: reset em 55, recompensas cosméticas exclusivas por rank de prestígio, máx. 10 prestígios. — [Game8](https://game8.co/games/Call-of-Duty-Black-Ops-6/archives/468369); [CoD Wiki](https://callofduty.fandom.com/wiki/Prestige_Mode)
- RuneScape: XP continua acumulando até 200M após 99 (meta pós-cap). — [Wikipedia](https://en.wikipedia.org/wiki/Experience_point)
- Battle passes: temporadas de 2–3 meses, exclusividade temporária e aversão à perda impulsionam uso diário; estudo de 2023 com jogadores descreveu os timers como exploratórios/FOMO (fonte secundária). — [Simply Put Psych](https://simplyputpsych.co.uk/gaming-psych/ethical-considerations-and-concerns-surrounding-battle-passes); [Grokipedia, Battle pass (fonte fraca)](https://grokipedia.com/page/Battle_pass)
- FOMO formalizado por Przybylski et al. (2013): "a pervasive apprehension that others might be having rewarding experiences from which one is absent". — [Medium/Bootcamp](https://medium.com/design-bootcamp/product-design-and-psychology-the-exploitation-of-fear-of-missing-out-fomo-in-video-game-design-5b15a8df6cda)
- Helldivers 2: Warbonds nunca expiram; um Warbond de 10 páginas se obtém em ~25–100 h de jogo. — [Twinfinite](https://twinfinite.net/features/helldivers-2s-battlepass-system-battles-fomo/); [PC Gamer](https://www.pcgamer.com/games/third-person-shooter/helldivers-2-and-marvel-rivals-convinced-me-battle-passes-should-never-expire/)
- Halo Infinite migrou para passes permanentes. — [Game Rant](https://gamerant.com/helldiver-2-battle-pass-rewards-progress-good-bad-why/)

### Inferences
- Para RP: título/placa "Caminhoneiro Nv 60" e uma "capa" (uniforme exclusivo) no cap equivalem à capa do 99 — status sem inflação. Prestígio com reset só faz sentido se o reset não tirar renda (estilo MW: prestígio sem relock).
- Evitar passe sazonal com prazo; se houver trilha de marcos, que seja permanente.

### Gaps
- Não obtive detalhes verificáveis de Destiny seasonal ranks / artigo do leak (site inacessível).
- Detalhes da capa de skill do RuneScape (requisitos, bônus) não confirmados por fonte aberta nesta sessão.

## 4. Loops curto/médio/longo e meta-progressão

### Takeaway
Loops entregam valor pelo exercício repetido e constroem maestria; arcos são únicos e se consomem. Jogo fica chato quando o padrão já foi dominado e nada novo há para aprender (Koster). Meta-progressão boa (Hades) acrescenta escolha, não só números.

### Cited Findings
- Cook: loop = modelo mental → ação → resposta do sistema → feedback → modelo atualizado; loops são fractais em várias escalas; "An arc is a broken loop you exit immediately"; "Loops tend to deliver value through the act of being exercised"; loops constroem "wisdom". Menciona risco de engajamento problemático em loops que exploram recompensa (TF2). — [Lostgarden, Loops and Arcs (2012)](https://lostgarden.com/2012/04/30/loops-and-arcs/)
- Koster: diversão é aprendizado de padrões; o jogo fica chato quando o padrão foi aprendido ou é trivial, e frustrante quando é difícil demais. — [Shortform summary](https://www.shortform.com/summary/a-theory-of-fun-for-game-design-summary-raph-koster); [Theory of Fun](https://www.theoryoffun.com/press.shtml)
- Hades: múltiplas moedas cada uma ligada a um tipo de progressão; mirror com opções alternativas e respec barato. — [TheGamer](https://www.thegamer.com/hades-mirror-of-night-roguelite-progression/); [Hades Wiki](https://hades.fandom.com/wiki/Mirror_of_Night)

### Inferences
- Caminhão: loop curto = a entrega (1 h, sem variação = padrão dominado rápido → tédio, segundo Koster); loop médio = sessão/dia; longo = tiers e cap. Faltam variações no loop curto (tipos de carga, eventos, contratos com escolha) e marcos no médio (metas diárias/semanais).

### Gaps
- Não encontrei transcrição de GDC específica ("Juicing your game", "The Art of Balancing Progression") nesta rodada.

## 5. Economia: faucets e sinks, inflação, recompensas não monetárias

### Takeaway
Toda recompensa em dinheiro é faucet; sem sinks equivalentes, gera inflação. Progressão que paga mais por nível é faucet crescente — preferir recompensas de status/escolha e controlar o faucet pela âncora.

### Cited Findings
- Ludgate (Game Developer, 2011): modelo "money-in, money-out"; faucets = drops/quests, drains = compras NPC/taxas; preços de NPC criam piso e teto; "the real faucets in many MMORPGs aren't the cash drops: it's everything else" (excesso de itens deflaciona); defende degradação/perda de equipamento e economia de crafting estilo EVE. — [Game Developer, The F-Words of MMOs: Faucets](https://www.gamedeveloper.com/design/the-f-words-of-mmos-faucets)
- Quando faucets superam sinks, cada moeda compra menos e novos jogadores não alcançam; estúdios monitoram velocidade do dinheiro, riqueza por faixa, índice de preços. — [QuickRef blog](https://quickref.me/blog/faucets-sinks-and-bonds-how-online-game-economies-stay-balanced/); [Medium, Şahin](https://medium.com/@msahinn21/designing-game-economies-inflation-resource-management-and-balance-fa1e6c894670)
- Progressão rápida demais gera excedente de moeda. — [Game Developer, Kladova](https://www.gamedeveloper.com/design/creating-a-casual-game-progression-curve)

### Inferences
- Caminhão a $861–$2.072 por entrega-hora vs táxi $550/h: já no nível 1 o caminhão paga ~1,6× a âncora e no topo ~3,8×. Se o problema é "não recompensador", aumentar dinheiro agrava o faucet; melhor recompensa não monetária (títulos, cosméticos, rotas) e custos operacionais (combustível, manutenção, seguro) como sink atrelado ao tier.

### Gaps
- Não consultei relatórios econômicos mensais da EVE (MER) nem material de Machinations/Dormans nesta rodada.

## 6. Diárias, semanais, streaks e anti-FOMO

### Takeaway
O padrão anti-FOMO mais citado é o rested XP do WoW: bônus acumulado offline que favorece quem joga pouco, reembalado de penalidade para bônus. Passes sem prazo e caps semanais são as alternativas a streaks punitivos.

### Cited Findings
- WoW Classic rested: 1 "bolha" = 5% da XP do nível; 10 h deslogado em inn/cidade enchem uma bolha (fora: 1/4 da velocidade); máximo 30 bolhas = 1,5 nível (~300 h ≈ 12,5 dias); 200% XP de kills enquanto rested (quests não). — [Warcraft Tavern](https://www.warcrafttavern.com/wow-classic/guides/rested-experience/)
- Wowpedia: 1 bolha a cada 8 h descansando (valores variam por versão; no WoW atual o cap é 150% de um nível). — [Wowpedia, Rest](https://wowpedia.fandom.com/wiki/Rest); conflito de números 8 h vs 10 h com [Warcraft Tavern](https://www.warcrafttavern.com/wow-classic/guides/rested-experience/)
- Origem: beta-testers rejeitavam penalidade por jogar demais; Blizzard trocou por bônus de 200% — "same numbers seen from the opposite point of view". — [Wowpedia, Rest](https://wowpedia.fandom.com/wiki/Rest)
- Passes que não expiram eliminam FOMO para quem tem pouco tempo (Helldivers 2, Marvel Rivals). — [PC Gamer](https://www.pcgamer.com/games/third-person-shooter/helldivers-2-and-marvel-rivals-convinced-me-battle-passes-should-never-expire/)

### Inferences
- O limite de 1 entrega/hora é, na prática, um cap rígido (penalidade). Reenquadrar como rested: acumular "cargas" ou bônus de XP enquanto offline/fazendo outra coisa (ex. até 3 entregas acumuladas, ou 1ª entrega do dia com XP dobrada) entrega o mesmo teto de faucet percebido como bônus.
- Metas semanais com cap (não diárias com streak que zera) protegem quem joga em dias irregulares.

### Gaps
- Sem dados quantitativos de retenção para streaks vs caps semanais nesta pesquisa.
