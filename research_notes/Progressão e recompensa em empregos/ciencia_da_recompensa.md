# Ciência da recompensa aplicada à progressão de empregos (FiveM RP)

Context for the report writer: truck job = 1 delivery/hour, tiers at levels 1/15/35, cap 60; bus = 10 levels; taxi = flat pay. Complaint: progression doesn't feel rewarding. Constraints: no economy inflation, no predatory design. Notes in English; final report in Portuguese.

## 1. What does dopamine encode? (Schultz RPE; Berridge wanting vs liking) and implications for predictable vs surprising rewards and habituation

### Takeaway
Phasic dopamine encodes reward prediction error (actual minus expected), not pleasure: a fully predicted reward produces no phasic response, a better-than-expected one a burst, a worse-than-expected one a dip. Separately, Berridge shows dopamine drives "wanting" (incentive salience), not "liking" (hedonic impact). So a fixed, perfectly predictable paycheck stops generating a "reward signal" quickly, and any expectation you raise and then miss is actively aversive (negative prediction error).

### Cited Findings
- Schultz, Dayan & Montague (1997, Science 275:1593-1599): primate dopamine neurons' fluctuating output "apparently signals changes or errors in the predictions of future salient and rewarding events"; learning is driven by changes in expectations; formalised as temporal-difference learning. — [PubMed](https://pubmed.ncbi.nlm.nih.gov/9054347/); [PDF](https://www.gatsby.ucl.ac.uk/~dayan/papers/sdm97.pdf)
- Schultz (2016 review, Dialogues Clin Neurosci 18:23-32): most midbrain dopamine neurons in humans, monkeys and rodents are "activated by more reward than predicted (positive prediction error), remain at baseline activity for fully predicted rewards, and show depressed activity with less reward than predicted (negative prediction error)." — [Schultz 2016](https://www.tandfonline.com/doi/full/10.31887/DCNS.2016.18.1/wschultz)
- Corollary from the TD model: once learned, the phasic response transfers from the reward itself to the earliest cue that predicts it (the "anticipation" moment). — [Schultz, Dayan & Montague 1997](https://www.gatsby.ucl.ac.uk/~dayan/papers/sdm97.pdf)
- Fiorillo, Tobler & Schultz (2003, Science): phasic response scales monotonically with reward probability (prediction-error coding), but a separate, sustained ramp of activity before reward covaries with *uncertainty*, maximal at p = 0.5. — [PubMed](https://pubmed.ncbi.nlm.nih.gov/12649484/); [Science](https://www.science.org/doi/10.1126/science.1077349)
- Berridge & Robinson incentive-sensitization theory: mesolimbic dopamine mediates incentive motivation ("wanting") but not hedonic impact ("liking"); "liking" is mediated by smaller, not dopamine-dependent, hedonic hotspots; the two normally cohere but can dissociate, especially under dopamine manipulations. — [Robinson & Berridge 2025, Annu Rev Psychol, "30 years on"](https://sites.lsa.umich.edu/berridge-lab/wp-content/uploads/sites/743/2025/06/2025-Robinson-Berridge-The-incentive-sensitization-theory-of-addiction-30-years-on-An-Rev-Psychol.pdf); [Annual Reviews page](https://www.annualreviews.org/content/journals/10.1146/annurev-psych-011624-024031); [Berridge 2007 debate](https://sites.lsa.umich.edu/berridge-lab/wp-content/uploads/sites/743/2019/10/Berridge-2007-Debate-over-dopamine-incentive-salience-Psychopharmacology.pdf)
- Robinson et al. apply wanting/liking to gambling: cues and uncertainty can amplify "wanting" independently of how much the outcome is enjoyed. — [Robinson, Fischer, Ahuja, Lesser & Maniates 2015, Curr Top Behav Neurosci](https://robinsonlab.research.wesleyan.edu/files/2014/01/Robinson-2015-Curr-Top-Behav-Neurosci.pdf)

### Inferences
- Myth to debunk: "dopamine = pleasure" / "give players dopamine hits." Strong evidence says dopamine is a teaching/wanting signal about *surprise relative to expectation*. Pleasure ("liking") of the delivery payout is a different system.
- Flat taxi pay and a 1 delivery/hour truck loop become fully predicted rewards → baseline dopamine at payout → subjectively "nothing happens." This is a mechanistic explanation of the complaint, not a moral failing of players.
- Positive surprise can be delivered *without economic inflation* and without gambling: non-monetary surprises (rare contract types, route events, NPC dialogue, a cosmetic, a reputation mention, a "perfect delivery" commendation). Keep the *money* predictable; put the variance in content/recognition.
- Negative prediction errors matter: announcing bigger rewards than delivered, hidden deductions, or nerfs to known pay will be felt as punishments. Communicate changes explicitly and never under-deliver on a displayed number.
- The anticipatory signal transfers to predictive cues: visible "next unlock" indicators and announced upcoming milestones become motivating in themselves.

### Gaps
- No direct human study found that maps phasic RPE magnitude to game-reward design parameters; the application is inference from animal/human neurophysiology.

## 2. Operant conditioning: schedules, extinction, which fit a job loop, and the ethical line (variable ratio + money; loot boxes)

### Takeaway
Variable-ratio schedules produce the highest response rates and greatest resistance to extinction — which is exactly why they underlie gambling. Loot-box spending correlates reliably (moderate effect) with problem gambling. For a job loop, keep monetary pay on fixed/predictable schedules; use variability only for non-monetary, non-purchasable flavor.

### Cited Findings
- Four classic schedules (fixed/variable ratio/interval); variable ratio is "the most productive and the most resistant to extinction", helping explain the pull of gambling; continuous reinforcement extinguishes fastest because absence of reward is quickly noticed. (Textbook-level summaries.) — [Lumen/UCF General Psychology](https://pressbooks.online.ucf.edu/lumenpsychology/chapter/reading-reinforcement-schedules/); [Simply Psychology](https://www.simplypsychology.org/schedules-of-reinforcement.html)
- Partial reinforcement extinction effect (PREE): intermittently reinforced behavior persists longer after reward stops than continuously reinforced behavior; demonstrated in recent experimental work. — [PMC10524675](https://pmc.ncbi.nlm.nih.gov/articles/PMC10524675/)
- Zendle & Cairns (2018, PLOS One, large survey): loot-box spending linked to problem gambling, η² = 0.054; replication (2019) η² = 0.051; non-problem gamblers spent ~$11.14/month vs problem gamblers ~$38.24. — [2018 PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC6248934/); [2019 replication](https://pmc.ncbi.nlm.nih.gov/articles/PMC6405116/)
- Zendle et al. 2019: link to problem gambling holds regardless of features like cash-out or pay-to-win. — [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0747563219302468)
- Spicer et al. 2022 systematic review/meta-synthesis: 12 of 13 publications reported a positive loot box–problem gambling relationship, mean effect r ≈ .27. — [Spicer et al. 2022, New Media & Society](https://journals.sagepub.com/doi/10.1177/14614448211027175)
- Clark et al. 2009 (Neuron 61:481-490): gambling near-misses increased motivation to play and recruited win-related circuitry (ventral striatum, anterior insula) more than regular losses, despite being objective losses. Midbrain near-miss responses scale with gambling severity (Chase & Clark 2010). — [ResearchGate (Clark 2009)](https://www.researchgate.net/publication/24010632_Gambling_Near-Misses_Enhance_Motivation_to_Gamble_and_Recruit_Win-Related_Brain_Circuitry); [J Neurosci 2010](https://www.jneurosci.org/content/30/18/6180)
- Zendle's written evidence to UK Parliament on loot boxes/gambling regulation. — [UK Parliament GAM0022](https://committees.parliament.uk/writtenevidence/83/html/)

### Inferences
- Current loops map to schedules: taxi flat pay per ride ≈ fixed ratio (FR1); truck 1 delivery/hour ≈ fixed interval-ish gate. FR produces steady work with post-reinforcement pauses; FI produces "scalloping" (idle until the gate opens) — plausibly why the hourly truck gate feels like waiting, not working.
- Correlational caveat: loot-box studies are mostly cross-sectional; causality (gateway vs. gamblers seeking loot boxes) is unresolved — see [gateway hypothesis study](https://www.sciencedirect.com/science/article/pii/S0306460322000934). Still, the design lesson is conservative: don't combine randomized outcomes with money/real-value items.
- Ethical line for this server: randomness is acceptable in *what kind of work/event appears* (route, cargo, customer story) and in cosmetic/recognition drops that cannot be bought or sold; unacceptable: random cash multipliers, paid rerolls, "spin for bonus", engineered near-miss displays ("you almost got the rare contract!").
- Resistance to extinction cuts both ways: variable-ratio money payouts would make players keep grinding even when the loop is no longer fun — a retention metric win, a wellbeing loss.

### Gaps
- No study found on variable reward schedules specifically in roleplay-server job loops; evidence is from gambling/loot boxes and lab conditioning.
- Could not retrieve a peer-reviewed source for King & Delfabbro's specific loot-box arguments within the call budget (they argue loot boxes share structural features with gambling; verify before citing).

## 3. Self-Determination Theory (competence, autonomy, relatedness; PENS) and overjustification / crowding out

### Takeaway
Game enjoyment and future play are predicted by perceived competence and autonomy (and relatedness in multiplayer), not by reward size per se. Expected, tangible, contingent rewards undermine free-choice intrinsic motivation (d ≈ −0.28 to −0.40), while informational feedback that signals competence can raise it. Rewards should read as *information about mastery*, not as control.

### Cited Findings
- Ryan, Rigby & Przybylski (2006, Motivation and Emotion): four studies; perceived in-game autonomy and competence associated with enjoyment, preferences and pre-to-post changes in well-being; led to the PENS measure (Player Experience of Need Satisfaction), which adds Intuitive Controls and Presence. — [Springer](https://link.springer.com/article/10.1007/s11031-006-9051-8); [PDF](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf); [PENS page](https://selfdeterminationtheory.org/player-experience-of-needs-satisfaction-pens/)
- Przybylski, Rigby & Ryan (2010) "A motivational model of video game engagement" (Review of General Psychology) — the synthesis model of need satisfaction in games. — [SAGE](https://journals.sagepub.com/doi/abs/10.1037/a0019440)
- Deci, Koestner & Ryan (1999, Psych Bull 125:627-668), 128 studies: engagement-contingent, completion-contingent and performance-contingent rewards undermined free-choice intrinsic motivation (d = −0.40, −0.36, −0.28); also all tangible and all *expected* rewards; self-reported interest undermined by engagement/completion-contingent rewards (d = −0.15, −0.17). Verbal/informational feedback can enhance intrinsic motivation. — [PubMed](https://pubmed.ncbi.nlm.nih.gov/10589297); [PDF](https://home.ubalt.edu/tmitch/642/articles%20syllabus/Deci%20Koestner%20Ryan%20meta%20IM%20psy%20bull%2099.pdf)
- Contested: Eisenberger, Pierce & Cameron (1999) commented that effects depend on conditions and reward can be benign; the debate is ongoing but DKR's core undermining finding for expected tangible rewards is widely cited. — [PubMed comment](https://pubmed.ncbi.nlm.nih.gov/10589298)

### Inferences
- Pay in a job loop is by definition expected, tangible and contingent — the worst category for crowding out. You can't remove pay (it's the RP economy), but you can stop making *pay* the only signal of progression. Put progression weight on competence feedback (delivery rating, on-time %, damage-free streak, route mastery), autonomy (choosing cargo/route/contract, not just "next level"), and relatedness (convoys, company/crew, being recognized by name by dispatch or other players, bus riders who are real players).
- In RP specifically, relatedness and identity are strong: titles/licences/uniform/vehicle livery that other players *see* are recognition that doesn't inflate the economy.
- Avoid controlling framing ("you must do X deliveries today to keep your bonus") — this is the "controlling" reward type DKR find undermining.
- Caveat: effect sizes come mostly from lab tasks with children/students; transfer to MMO/RP adults is inference.

### Gaps
- Could not extract numerical results from the 2006 PENS PDF (binary fetch); report should cite qualitative conclusions only.
- No experimental study found on crowding-out specifically in in-game currencies for roleplay jobs.

## 4. Flow, goal-gradient, endowed progress, Zeigarnik, loss aversion/sunk cost, near-miss

### Takeaway
Effort accelerates as a visible goal approaches (goal-gradient) and artificially "pre-filled" progress raises completion (endowed progress). Flow depends on matching challenge to skill — a loop with no rising challenge has no flow. The popular Zeigarnik "memory for unfinished tasks" effect did not survive meta-analysis; only the tendency to *resume* (Ovsiankina) holds. Near-miss and sunk-cost exploitation belong to the dark side.

### Cited Findings
- Kivetz, Urminsky & Zheng (2006, J Marketing Research 43:39-58): coffee-card customers bought coffee more frequently as they approached the free reward; after earning it, engagement dropped and then re-accelerated toward the next reward ("post-reward reset"); a 12-stamp card with 2 pre-given stamps was completed faster than an empty 10-stamp card (illusionary goal progress); stronger acceleration toward the first reward predicted quicker re-engagement. — [Paper PDF](https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf); [SAGE](https://journals.sagepub.com/doi/abs/10.1509/jmkr.43.1.39)
- Nunes & Drèze (2006, J Consumer Research): 300 car-wash loyalty cards; 8-stamp card vs 10-stamp card with 2 pre-filled stamps (same 8 required): completion 19% vs 34%, and endowed customers washed at shorter intervals. (Numbers via secondary summaries; verify against primary.) — [Wikipedia: Goal pursuit](https://en.wikipedia.org/wiki/Goal_pursuit); [Madigan, Psychology of Games: endowed progress and quests](https://www.psychologyofgames.com/2010/11/endowed-progress-effect-and-game-quests/)
- Flow: experimental manipulations of game speed/difficulty (Keller & Bless 2008) support challenge–skill balance as a flow condition; flow linked to performance (Engeser & Rheinberg 2008). A review of flow in video games covers physiological correlates. — [PeerJ review 2020 (PMC7751419)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7751419/); ["Being enjoyably challenged" FPS experiment (PMC5954478)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5954478/)
- Skill–challenge balance in complex mobile games relates to flow and to the urge to keep playing (J Behav Addict 2020) — flow is also a retention lever with its own risk. — [Akadémiai](https://akjournals.com/view/journals/2006/9/3/article-p606.xml)
- Ghibellini & Meier (2025, Humanities & Social Sciences Communications) meta-analysis: no memory advantage for unfinished tasks (Zeigarnik), but a general tendency to resume interrupted tasks (Ovsiankina). — [Nature HSSC](https://www.nature.com/articles/s41599-025-05000-w)
- Near-misses recruit win-related circuitry and increase motivation to gamble (Clark et al. 2009) — see §2. — [J Neurosci 2010 follow-up](https://www.jneurosci.org/content/30/18/6180)

### Inferences
- Goal-gradient + post-reward reset predicts a specific failure: long gaps between meaningful milestones (truck tiers at 1 → 15 → 35 → 60) create long flat stretches far from any goal where motivation is lowest. Fix: many intermediate *discrete, visible* goals (every few levels something concrete), each close enough to feel reachable.
- Endowed progress is cheap and non-inflationary: e.g., new job starts showing progress already made (first level-ups fast, tutorial delivery counts), or cross-job credit (bus experience counts toward truck licence). It's ethical as long as it's real progress, not a fake bar that resets.
- Flow implies progression should raise *challenge* (heavier/fragile cargo, tighter windows, harder routes, trailers, night runs) together with pay — so higher tiers feel like mastery, not just higher numbers. A 1-per-hour gate gives no room for flow; the loop between deliveries is likely empty time.
- Drop Zeigarnik from any design rationale (myth-status); keep "players tend to resume unfinished tasks" (Ovsiankina) — e.g., multi-step contracts that can be resumed next session, without penalties for leaving.
- Loss aversion / sunk cost (Kahneman–Tversky prospect theory; not re-sourced here) are the mechanisms behind streak loss, decaying XP, and "don't lose your progress" pressure — treat as dark if used to compel return.

### Gaps
- Nunes & Drèze primary article not fetched; figures from secondary sources.
- No source retrieved for loss aversion/sunk cost in games within budget; treat as general-knowledge background, not a cited finding.

## 5. Hedonic adaptation to fixed income; discrete milestones vs small continuous increments (JND; is +0.6%/level perceptible?)

### Takeaway
People adapt quickly to stable, predictable gains; variety and surprise slow adaptation. Pay raises below roughly 5–8% are generally not perceived as meaningful (Mitra, Gupta & Jenkins). A +0.6% per-level increase is far below this threshold and will be invisible; the same total gain concentrated into fewer, larger, discrete, announced steps (and paired with new content) is perceptible.

### Cited Findings
- Mitra, Gupta & Jenkins (1997, J Organizational Behavior) "A drop in the bucket: when is a pay raise a pay raise?": psychophysical methods, n = 192 student employees; raises only noticed around 5–8%; below ~7% increases unlikely to evoke positive reactions. Field replication: Mitra et al. 2016, Human Resource Management. — [Wiley 1997](https://onlinelibrary.wiley.com/doi/10.1002/(SICI)1099-1379(199703)18:2%3C117::AID-JOB790%3E3.0.CO;2-1); [Wiley 2016](https://onlinelibrary.wiley.com/doi/10.1002/hrm.21712); [Psychology Today summary](https://www.psychologytoday.com/us/blog/of-leaders-and-traits/202311/the-7-percent-mystery-what-really-counts-as-a-pay-raise)
- Lyubomirsky (2010/2011) hedonic adaptation review / HAP model: adaptation to positive circumstances is faster when they become predictable and familiar; variety, surprise, savoring and attention slow adaptation; variable positive events keep aspiration levels from rising as fast. — [Lyubomirsky 2011 chapter](https://sonjalyubomirsky.com/wp-content/uploads/2024/03/Lyubomirsky-2011.pdf); [Sheldon & Lyubomirsky, HAP test](https://greatergood.berkeley.edu/images/uploads/The_Challenge_of_Staying_Happier.pdf)
- Consistent with Schultz: fully predicted rewards elicit no phasic dopamine response (§1). — [Schultz 2016](https://www.tandfonline.com/doi/full/10.31887/DCNS.2016.18.1/wschultz)

### Inferences
- Weber–Fechner framing: perception is relative; ~+0.6%/level ≈ roughly an order of magnitude below the 5–8% JND found for pay. Over 60 levels, compounding gives ~+43% total, but no single step is felt. Recommendation: same economic envelope, redistributed into ~5–8 visible steps of ~7–10% each, tied to tier/title changes. Economy-neutral in total.
- Better still, make many milestones non-monetary (new vehicle, route, uniform, title, access to contracts, dispatcher priority), which slows hedonic adaptation via variety and doesn't inject money.
- Money adaptation is fast; the taxi's flat pay offers nothing to adapt *to* — novelty must come from content (customer types, fares with stories) or skill-based bonuses that are deterministic (e.g., fixed tip for 5-star ride).
- Caveat: the JND studies are about salary percentages in employment; in-game currency perception is analogous but untested.

### Gaps
- No game-specific study found measuring the JND for in-game currency or XP rewards.

## 6. Dark patterns in games and what to avoid (daily login pressure, FOMO, grinding)

### Takeaway
Zagal, Björk & Lewis (2013) define dark game design patterns as elements used to work against players' interests, grouped (from the paper) as temporal, monetary and social-capital patterns. For a job loop, the relevant risks are grinding as the only progression path, "playing by appointment" (forced timing), and streak/FOMO mechanics. Scholarly critique warns the label depends on intent and context — grinding isn't dark per se.

### Cited Findings
- Zagal, Björk & Lewis (2013, FDG): develop the concept of dark game design patterns; "a game creator's interests may not align with the players'"; present examples, subtleties of identification, and guiding questions. — [Deceptive.design summary](https://deceptive.design/articles/dark-patterns-in-the-design-of-games/); [Semantic Scholar](https://www.semanticscholar.org/paper/Dark-patterns-in-the-design-of-games-Zagal-Bj%C3%B6rk/19a241378b06d868eb5f6b76027172c3aaca86f4); [FDG 2013 PDF](http://www.fdg2013.org/program/papers/paper06_zagal_etal.pdf)
- Named patterns in the paper (from my knowledge of the paper; the full PDF could not be fetched to verify wording): *Temporal* — Grinding, Playing by Appointment; *Monetary* — Pay to Skip, Pre-delivered Content, Monetized Rivalries; *Social capital* — Social Pyramid Schemes, Impersonation. — [FDG 2013 PDF (unverified fetch)](http://www.fdg2013.org/program/papers/paper06_zagal_etal.pdf)
- Critique: "Against 'Dark Game Design Patterns'" (Zagal-adjacent debate, DiGRA 2020) argues the concept is problematic/overbroad (content not extracted). — [White Rose eprint](https://eprints.whiterose.ac.uk/id/eprint/156460/1/DiGRA_2020_paper_189.pdf)
- Dark patterns in video game design — reference-work chapter (Springer 2024+). — [Springer](https://link.springer.com/rwe/10.1007/978-3-031-52643-5_4-1)
- Near-miss, variable ratio + money, loot boxes: see §2.

### Inferences
- The truck "1 delivery per hour" is structurally a Playing-by-Appointment/time-gate pattern: players must structure real time around the gate. If the gate exists for economy control, it can be kept but reframed: e.g., more deliveries per hour with lower pay each (same money/hour cap), or an XP/pay cap per session that doesn't require waiting idle.
- Grinding to level 60 with invisible increments is the core problem; it becomes "dark" if progression is extended deliberately to retain players rather than to provide challenge.
- Avoid: daily login streaks with loss on missing a day, limited-time job bonuses that create FOMO, decaying levels, paid/VIP multipliers for job XP (pay to skip), social pressure mechanics (recruit X friends).
- Acceptable: rested-XP style bonus (reward for returning, never penalty for absence), weekly caps instead of daily obligations, fully transparent formulas.

### Gaps
- Could not verify exact pattern names/definitions in Zagal et al. full text (PDF fetch failed: expired certificate/403); report should present them as the commonly cited taxonomy and note that.
- No GDC talk (e.g., Jamie Madigan) transcript retrieved; only Madigan's blog post on endowed progress.
