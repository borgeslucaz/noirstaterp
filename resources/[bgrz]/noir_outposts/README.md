# noir_outposts

Outposts disputados por organizações criminosas, com dealers NPC que vendem estoque
passivamente enquanto o local estiver sob controle.

O resource é dono do domínio (posse, dealers, estoque, agenda, carteira, roubo). As dependências
de integração são o `bgrz_core` e o `peuren_minigames`. Nenhum arquivo chama `qbx_core`, `noir_gangs`,
`ox_inventory`, `ox_target`, `sd-phone`, dispatch ou `ox_doorlock` diretamente.

A organização dona de um outpost é a gang do personagem, lida do `GetCharacter` do bridge.
Vale o `name` da gang como `organizationId` e o `grade.level` como cargo. Um personagem em
`none` não tem organização e não consegue tomar, contratar, abastecer nem coletar.

## Instalação

1. Garanta a ordem de start: `ox_lib` / `oxmysql` → `qbx_core` e providers → `bgrz_core` /
   `peuren_lib` → `peuren_minigames` → `noir_outposts`. As dependências também estão declaradas
   nos manifests.
2. `bgrz_core` precisa estar na versão `0.5.0` ou superior: o resource usa os adapters de
   inventário, target, phone, dispatch e os exports `SendPhoneAppMessage` e `CountOnDutyJob`.
3. As migrations rodam sozinhas no start (apenas `CREATE TABLE IF NOT EXISTS` e
   `INSERT IGNORE`). O start falha fechado se qualquer tabela obrigatória estiver ausente.
5. Para textos em português, defina `setr ox:locale pt-br` no `server.cfg`. Sem isso o
   ox_lib carrega `locales/en.json`.

### Corredores em campo

Os corredores andam pela própria esquina em vez de ficar parados, via `dealerWander` em
`config/shared.lua`. A caminhada é ancorada na **coordenada cadastrada da esquina**, publicada
no state bag `noir:dealerCorner`, e não na posição atual do ped. Ancorar na posição atual faria
o corredor derivar alguns metros a cada vez que um jogador novo o transmitisse, até ele acabar
longe do posto. A âncora é encaixada no ponto navegável mais próximo, então a coordenada não
precisa ser exata.

O deslocamento não usa a perambulação ambiente do jogo, que se mostrou não confiável com ped
criado pelo servidor. Um único loop no client sorteia um destino dentro do raio, manda o
corredor até lá, espera a chegada e repete, com teto de 20 segundos por trecho para caminho
bloqueado não travar ninguém. É um loop só para todos os corredores, não uma thread por ped.

**Boa parte do mapa não tem malha de navegação de pedestre**, docas e pátios industriais
inclusive, e nesses lugares tanto a perambulação ambiente quanto o cálculo de rota falham em
silêncio. Por isso o destino é resolvido em dois níveis: com malha o corredor usa rota, sem
malha ele vai em linha reta sobre o chão bruto. Um ponto sem chão, como água, é descartado.

**O corredor para de circular quando há jogador a menos de 18 metros.** Isso não é só
ambientação. A posição que o servidor enxerga de um ped em movimento fica defasada, e foi
medida com 38 metros de erro em teste, o que quebrava a checagem de distância do assalto. Com
o ped parado a posição converge e a validação volta a ser confiável. É disso que depende a
posição gravada na rendição: quem aponta a arma está a menos de 18 metros, então o corredor já
está parado quando o servidor tira a foto. Enquanto segura o posto ele toca uma animação, então
não fica congelado.

Ao chegar num destino o corredor tem 45% de chance de parar para alguma coisa por 8 a 20
segundos, em vez de aguardar imóvel: fumar, mexer no celular, ficar de vigia, a lista está em
`dealerWander.idle.scenarios`. É o que devolve a naturalidade que a perambulação ambiente dava
de graça.

Em linha reta não há quem contorne obstáculo, então o destino só é aceito se houver caminho
livre até ele, verificado por um teste de visada na altura do peito contra mundo, veículos e
objetos. Outros peds não contam como obstáculo. Se ainda assim o corredor encostar em algo, ele
é detectado parado em dois tiques seguidos e troca de destino, em vez de empurrar a parede até
o teto de 20 segundos.

A IA roda no client que for dono de rede do ped, como qualquer ped, e o loop reaplica a
caminhada quando a propriedade troca de mão. Eles continuam mortais.

### O corredor não corre

A fuga é barrada em quatro camadas, porque nenhuma delas cobre tudo sozinha.

**Atributos, em toda troca de estado.** O atributo de combate 17, que é "sempre fugir", fica
desligado; 5 e 46, "sempre lutar" e "encara ped armado mesmo desarmado", ficam ligados. Estes
dois não estão lá para deixar o corredor agressivo: desarmado e sem eles, a resposta padrão do
jogo a uma arma apontada é a corrida. Tudo isso é reaplicado em toda transição — assentar,
começar a andar, parar, render, reagir — porque trocar de dono de rede ou de tarefa devolve o ped
ao padrão do modelo, e o padrão é correr.

**Bloqueio de evento enquanto ele está parado.** `SetBlockingOfNonTemporaryEvents` é o único
freio que não depende de atributo de combate, e ligado durante a caminhada ele cancela a tarefa
de destino junto: o corredor não anda, só toca a animação de ócio. Isso foi testado e reprovado,
e é por isso que `dealerWander.blockEvents` está em **false** — não tente de novo. Mas parado não
há destino a cancelar, então parado ele entra sempre, e é aí que importa: a abordagem exige 12
metros e a parada por jogador perto começa em 18, então quem aponta uma arma encontra o corredor
já parado e já surdo a susto. Vale para a parada por jogador, para a pausa entre trechos e para a
rendição.

**Nada de tarefa de fuga.** A reação hostil sem alvo resolvido neste client chamava
`TaskReactAndFleePed` e mandava o corredor correr — do jogador local, que quase nunca é quem
apontou a arma. Agora ele fica firme e armado até o servidor encerrar a hostilidade. E o combate
é dado com o bloqueio de evento ligado em seguida: sem isso, levar tiro durante a briga gerava o
evento que larga o combate e vira fuga.

**Coleira.** Empurrão, carro e ragdoll não são susto, e nenhum atributo cobre eles. Passando de
`dealerWander.leashDistance` da esquina, o corredor larga o que está fazendo e volta andando, em
vez de ficar parado onde foi parar. Essa volta tem precedência sobre a parada por jogador perto:
parado longe do posto ele não é abordável nem assaltável, e é justamente o que não pode durar.

**Fora de serviço.** Corredor em recuperação — de assalto ou de morte — sai da lógica de venda,
mas continua na rua e continua sendo um ped. O laço largava a caminhada dele e não colocava nada
no lugar, e ped largado volta à IA do jogo: era ele que fugia da arma apontada durante os dez
minutos inteiros de recuperação. Agora ele é fixado parado, blindado e com cenário de esquina,
uma vez por estado, e corpo caído nunca recebe tarefa. O mesmo vale para o corredor em serviço
cuja caminhada não pôde começar, por config desligado ou por esquina que ainda não chegou pelo
state bag.

Enquanto rendidos ou hostis a caminhada para, e volta quando a abordagem termina.

### Quando a abordagem é recusada

Apontar a arma nem sempre vira abordagem, e as recusas vinham caladas. O efeito era o pior
possível: o corredor não reagia, o jogador não recebia explicação nenhuma, e a leitura era de que
o NPC estava quebrado. São três janelas, e todas terminam sozinhas:

- **10 minutos de recuperação** depois de um assalto bem-sucedido, ou 20 depois de uma morte. O
  corredor está fora de serviço, e `dealer_unavailable` ou `dealer_cooldown` explicam.
- **2 minutos de cooldown de abordagem**, contados da abordagem anterior, que existem para
  ninguém ficar rolando o dado até tirar a rendição. Este tem código próprio,
  `holdup_cooldown`: usar o mesmo do assalto fazia a mensagem dizer "já foi roubado" para quem
  só tinha abordado.
- **Fora de alcance**, que continua em silêncio de propósito: mirar de longe é acidente comum, a
  correção é andar, e avisar aqui viraria spam a cada volta do laço de mira.

Nas duas primeiras a mensagem aparece e a próxima tentativa é adiada em 15 segundos, porque a
resposta não vai mudar nos próximos segundos e mirar é contínuo. `/outposts recover <id>` devolve
quem está em recuperação, e `/outposts cooldowns <id>` zera também os cooldowns de abordagem.

**E o corredor nessas janelas fica agachado com medo**, no `cowerScenario` do config do client, em
vez de voltar a circular como se nada tivesse acontecido. Vale para os dois casos: o abalado da
abordagem recente e o que está em recuperação de assalto. A postura é a pista visível de que ali
não há o que tirar agora — a mensagem explica, mas quem chega de longe lê a cena antes de mirar.

### Gang dona offline

Sem nenhum membro da organização dona online, **o corredor deixa de ser alvo**: não pode ser
abordado nem assaltado, e as duas recusas saem como `owner_offline`. A checagem mora em
`Dealer.rivalTarget`, que é por onde a abordagem e o assalto passam, então é uma trava só para
os dois caminhos.

A venda passiva já parava sozinha nesse período, por `sales.requireOwnerMemberOnline`. Faltava
a outra metade: com a venda travada e o roubo aberto, a madrugada virava ganho de graça para o
rival e perda unilateral para quem não tinha ninguém para reagir. Ligado, o posto fica congelado
enquanto a gang está fora — não rende e não perde. É `ownerOffline.protectDealers`, em
`config/server.lua`, e o `config_spec` recusa a combinação incoerente: se a gang offline não
ganha nada, ela também não pode perder nada.

Vale um membro online de qualquer cargo, em qualquer lugar do mapa — o mesmo critério da venda.
A presença vem do cache de `server/integration.lua`, alimentado pelos eventos de login, troca de
gang e queda do `bgrz_core`.

A trava é revalidada na conclusão do assalto, não só na abertura: quem começou a revista com a
gang online e viu o último membro cair no meio dela não conclui. E ela precede a checagem de
distância, então um rival fora de alcance recebe `owner_offline` em vez de `too_far` — a resposta
que não muda por andar até lá é a que deve aparecer.

**Matar o corredor continua possível**, porque ele é um ped como qualquer outro e não há como
blindá-lo sem deixá-lo imortal. Mas isso não tira nada da organização: sem carteira nem estoque
a menos, ele volta sozinho pelo cooldown de morte, que corre mesmo com o servidor vazio.

Uma organização que se desfaz deixa o posto num estado parado: ele continua `controlled` com um
dono que não tem mais ninguém, então não pode ser tomado — o status não é `available` — nem
roubado, pela trava acima. Não é um caso a tratar em código. A rotação o desativa no fim do
ciclo, e `/outposts release <id>` resolve na hora.

### Estado é do ped, não do corredor

Tudo que é transitório vive em memória por `dealerId` e sobrevive à troca do ped, e isso já custou
dois sintomas. Uma abordagem em curso que sobreviveu ao ped recusa todas as seguintes até vencer
sozinha, e foi ela que fez o "já está sendo abordado" aparecer sem ninguém abordando. A última
posição reportada do ped anterior pode estar longe da esquina nova, e o salto até lá é grande o
bastante para ser recusado como teleporte, o que trava toda checagem de distância do corredor.

Por isso `Entities.spawnDealer` zera, no ped novo, a abordagem em curso, o cooldown de abordagem,
o medo e as leituras de posição. **O cooldown de roubo não:** ele é do corredor, não do ped, está
na linha do banco, e é o que impede assaltar duas vezes trocando o ped no meio.

No client vale o mesmo, e pelo motivo mais direto: o FiveM recicla net ID, então o corredor
recriado costuma herdar o número do anterior. `detach` esquece caminhada, fixação, propriedade de
rede, reação e recuo de mira de uma vez só. Um `wanderOwned` esquecido era o bastante para deixar
o ped novo parado para sempre — a caminhada dele constava como já iniciada, e ninguém a iniciava
de novo.

### Já foi abordado

Quem já reagiu responde `holdup_done`, "Este corredor já foi abordado", e não "está sendo
abordado": quem está levando tiro dele não precisa ouvir que a abordagem está em curso. De mãos
para o alto, sim, ela está em curso, e a janela pertence a quem a abriu. A inspeção mostra o mesmo
— o estado exibido é o que se vê, não o da linha do banco, que continua dizendo "em campo" para
quem reagiu ou está agachado.

E o recuo do laço de mira agora vale para os dois resultados. Só a rendição o tinha, então depois
de uma reação o client voltava a pedir abordagem a cada três segundos enquanto o corredor atirava
de volta, e era isso que enchia a tela de recusa.

O abalado é um estado transitório novo, `shaken`, publicado no state bag e por evento quando a
abordagem termina com o cooldown ainda correndo, e desfeito pelo `tick` quando ele vence. Nenhuma
regra do servidor o consulta: quem recusa a abordagem seguinte continua sendo o cooldown em
memória, e o estado existe só para o client saber o que encenar. Ele aparece no `/outposts status`
como `holdupState`, que é o que explica um corredor agachado sem ninguém por perto. O corredor
abalado continua respondendo ao alvo de inspeção — está agachado, não fora do ar —, enquanto o
que está em recuperação continua fora, como já era.

Essa parada depende de duas coisas que já custaram caro. A reação chega ao client por evento e
por state bag, e o bag atrasa: durante esse intervalo a manutenção ainda lia `deployed` e
retomava a caminhada por cima da rendição. Por isso a reação recebida por evento tem precedência
durante `holdup.reactionGraceMs`, e só depois o bag volta a mandar, que é o que cobre troca de
dono de rede e quem entrou no servidor com a abordagem já em curso. A animação de mãos para o
alto também precisa ser de corpo inteiro: em animação secundária de tronco as pernas seguem
livres e o corredor anda de mãos levantadas.

E a reação corta as tarefas de forma imediata. `ClearPedTasks` não interrompe um cenário de
ócio: o ped toca a animação de saída inteira antes de obedecer, então quem apontava a arma
esperava o cigarro acabar para o corredor se render.

### A rendição é de quem chegar

A janela de revista **não pertence a quem abriu a abordagem**. `Robbery.start` confere que o
corredor está rendido e não confere quem o rendeu, então dois rivais podem dividir o trabalho: um
aponta a arma e tira a rendição na sorte, o outro revista. Também significa que um terceiro que
estava passando leva o loot de uma rendição que não é dele.

Isso é intencional, e está escrito aqui porque no código se lê como esquecimento — a correção
"óbvia" seria comparar o `source` de quem abordou com o de quem revista. Não compare. O que
pertence a quem abriu é só a recusa da abordagem seguinte (`holdup_in_progress`), que existe para
ninguém rolar o dado de novo em cima de um corredor já rendido.

### Identidade do corredor

O perfil é o arquétipo contratado: preço, ritmo de venda, capacidade, comissão. Ele não é mais o
sujeito. Quando a tomada termina, nome e ped são sorteados para todos os perfis a partir das
listas em `dealerIdentities` e o elenco é gravado no outpost. A contratação copia a identidade
reservada para a linha do corredor. Tudo fica gravado de propósito: mudar o config não troca o
rosto de quem já está na rua, demitir e recontratar preserva a pessoa durante aquele controle,
e um restart não redistribui ninguém. Uma nova tomada gera outro elenco.

O sorteio evita repetir nome ou ped no mesmo elenco. Cada lista precisa cobrir todos os perfis,
e `config_spec` barra uma configuração menor.

Corredores contratados antes desta mudança ficam com as colunas nulas e caem no nome e no modelo
do arquétipo, então nada quebra sem backfill. O feed guarda o nome dentro da operação: um
corredor demitido leva o dele embora, e sem essa cópia o histórico passaria a mostrar o
arquétipo no lugar de quem estava lá.

### Atendente do terminal

O terminal é um NPC, e é a única forma de abrir o painel. A zona de alvo invisível que existia
antes foi removida: os postos ficam em doca e pátio, a céu aberto, onde não há MLO nem objeto
para mirar, e o alvo de esfera ficava suspenso no ar sem nada visível dizendo onde interagir.

```lua
terminalNpc = {
    model = 'a_m_o_beach_01',
    scenario = nil,
    checkIntervalMs = 5000,
},
```

Sem cenário, como o NPC do `noir-truckjob`: ele só fica de pé. Com `scenario` preenchido o ped
toca o cenário e o laço o reinicia se ele parar; sem cenário o laço apenas reafirma as flags.

O ped é local e não networked. Ele não carrega autoridade nenhuma: serve de âncora de
interação, e toda callback revalida distância no servidor contra a coordenada `computer` do
posto, que é exatamente onde o ped nasce. Uma coordenada, dois usos, sem chance de divergirem.

Como o atendente virou a única porta, uma falha de criação deixaria o local inacessível. Por
isso um laço no client confere a cada `checkIntervalMs` se cada posto ativo ainda tem o seu de
pé, e refaz o que faltar. Isso cobre o streaming de modelo falhando e o engine removendo o ped.
O aviso de falha sai uma vez por local, não a cada volta.

A coordenada `computer` é usada como está. O ped nasce exatamente nela e fica congelado, então o
que está no config é a posição final: não há busca de chão nem correção de altura. Cadastre a
coordenada já no ponto onde o atendente deve ficar.

Ele é mobília com voz: imune a dano, sem ragdoll, sem reagir a nada ao redor e congelado no
lugar. As garantias extras, como prova contra explosão, passam por `optional`, que só chama o
nativo se ele existir nesta build. Isso não é zelo à toa: um nativo inventado é `nil` no client
e derruba o resource inteiro, e foi o que aconteceu com `SetPedDiesFromLowHealth`. Nativo sem
uso em nenhum outro resource do servidor entra por ali ou fica de fora. O laço de manutenção reafirma esse estado junto
com a existência do ped, porque uma explosão perto ou outro resource mexendo em peds da região
pode soltar a animação sem apagar a entidade.

**Cuidado com `addGlobalPed` de outros resources.** Quem registra assim no ox_target coloca a
opção em todo ped do mapa, e o ox_target 1.18.1 não tem como excluir uma entidade dessa lista:
quem decide é o `canInteract` de quem registrou. Nada que se faça aqui dentro tira a opção do
atendente. O `op-drugselling` oferecia venda de droga nele, e foi resolvido lá, com a flag
`Config.GlobalPedDealing.Enable` desligando o alvo global e deixando só a venda de esquina, que
já ignora entidade de missão. Um resource novo com o mesmo padrão precisa do mesmo tipo de
ajuste do lado dele.

### Coordenadas

As coordenadas de `docks`, `cypress` e `lamesa` em `config/shared.lua` ainda são **placeholders**
e precisam ser capturadas in-game antes de produção: `computer` (terminal), `entrance` (blip) e
no mínimo seis `dealerCorners` por local. O start aborta se algum local tiver menos corners que o
limite de dealers, e o `config_spec` recusa duas esquinas a menos de 20 metros.

O `pier` é o único com coordenada real. Ele também é o mais espalhado, com 265 metros entre as
esquinas extremas, e foi por causa dele que o chamado da polícia passou a sair da posição do
corredor em vez da entrada do posto.

Todas as coordenadas são usadas como estão, sem correção de altura em lugar nenhum.

### Rotação fixada para teste

`rotation.forced` em `config/server.lua` prende a rotação nos postos listados e desativa todos os
outros. Ela vale por cima da rotação já persistida do ciclo, não só do sorteio, senão a mudança
só apareceria até 24 horas depois.

Está em `{ pier = 'drug' }` e precisa ser esvaziada antes de abrir para os jogadores, junto com
`claim.minOnlinePlayers` e `claim.minPolice`, que também estão zerados para teste. Os três estão
marcados com `--TODO: NÃO SUBIR PRA PRODUÇÃO ASSIM`.

## Configuração

| Arquivo | Conteúdo | Vai para o client |
|---|---|---|
| `config/shared.lua` | IDs, labels, coordenadas, perfis públicos, limites visuais | sim |
| `config/client.lua` | animações, blips, distâncias visuais, debug | sim |
| `config/server.lua` | preços, chances, rate limits, permissões, providers | **não** |

Nenhum preço, payout, chance de dispatch ou regra anti-exploit existe fora de
`config/server.lua`. O teste `tests/unit/config_spec.lua` falha se isso mudar.

## Loop de gameplay

1. No boot e a cada ciclo (24h por padrão), o servidor sorteia os outposts ativos e **persiste**
   a rotação por `cycle_key`. Restart dentro do mesmo ciclo restaura a mesma seleção.
2. Quando o outpost está livre, o terminal mostra apenas sua descrição e a ação de tomada. O
   jogador precisa concluir o `StartTypewriter`; em seguida o claim é travado no banco
   (`status = claiming` + `claim_session_id`) e começa o tempo configurado da tomada. Assim, duas
   organizações não concluem ao mesmo tempo.
3. O líder contrata até quatro dealers; cada um ocupa um corner livre e é rotacionado a cada
   20 minutos.
4. Membros abastecem o estoque virtual pelo painel, com os itens saindo do inventário.
5. Um scheduler único processa as vendas vencidas a cada 5 segundos. Preço, quantidade,
   comissão e payout são resolvidos no servidor.
6. A receita líquida acumula na carteira do outpost em dinheiro sujo.
7. Um líder autorizado coleta a carteira; a entrega é idempotente por `request_id`.
8. Rivais abordam um corredor apontando uma arma. O servidor rola 60% de chance de reação:
   reagindo ele saca e revida, se rendendo ele levanta as mãos e abre a janela de revista.
   Só o corredor rendido pode ser revistado, e o assalto em si segue com a barra de progresso.
   Abordar de novo o mesmo corredor tem cooldown, para ninguém ficar rolando o dado.
9. O corredor assaltado entra em recuperação por 10 minutos, e nesse período não vende nem
   pode ser assaltado de novo.
10. Matar um corredor o tira de operação, e por quanto tempo depende de ter havido assalto
    antes: **1 minuto numa morte limpa, 20 minutos se ele já tinha sido revistado**. O corpo
    fica caído onde estava, deixa de ser mantido à força e some sozinho quando a área esvazia.
    Na recuperação o que tiver sobrado é removido e um ped novo assume o posto, com o mesmo nome
    e o mesmo rosto. Corredor em recuperação não vende, não pode ser roubado e não aceita a
    opção de observar. Ver "Matar: os dois prazos", abaixo.
11. Ao expirar o controle ou mudar o ciclo, dealers e estoque são encerrados.

### Como a morte é detectada

A vida de um ped só vale enquanto algum client o transmite: **sem dono de rede o servidor lê vida
zero num ped perfeitamente vivo**, e confiar nessa leitura já derrubou todos os corredores de
outposts vazios de uma vez. Por isso a regra exige dono e uma observação anterior de vivo, e por
isso ela não pode ser afrouxada — está fixada no `validators_spec` como regressão.

O que fica frágil é a *hora* de olhar. A varredura roda a cada `dealers.auditSeconds`, e nessa
janela quem matou pode sair de perto: o corpo perde o dono, a vida deixa de valer, e o corredor
fica preso "em campo" com um cadáver na esquina, vendendo. Três coisas fecham isso:

- **O ped nasce já observado vivo**, com o servidor lendo a vida do ped que ele mesmo acabou de
  criar. Esperar a varredura fazer essa primeira observação abria um buraco permanente: ped morto
  antes dela nunca mais era dado como morto, porque a observação de vivo só liga com vida acima de
  zero e a vida já era zero.
- **O dono de rede avisa quando olhar.** O reporte de posição, que já existia e já é validado
  contra o dono verdadeiro do ped, carrega um `dead`. Ele não derruba ninguém: quem decide é a
  leitura do servidor, com a mesma regra de sempre. Um client mentindo encontra um ped vivo e não
  consegue nada. E no instante da morte sempre há dono, porque quem matou está ali.
- **`/outposts recover` põe o estado em dia antes de recuperar**, em vez de esperar a varredura.
  Sem isso, matar e recuperar em seguida encontrava o corredor ainda em campo e o comando
  respondia zero, como se não houvesse nada a fazer. A resposta também passou a dizer quantos
  estão em campo e quantos em recuperação, porque zero sozinho não distinguia "não havia o que
  recuperar" de "o comando não funcionou".

Sobra um caso: quem mata e desconecta no mesmo segundo não gera aviso nenhum, e aí a morte volta a
depender de outro jogador estar por perto na varredura seguinte.

### Matar: os dois prazos

| Como | Fora de operação | Ledger | Alerta |
|---|---|---|---|
| Morte limpa, sem assalto antes | **1 minuto** | `dealer_down` | sim |
| Execução depois da revista | **20 minutos** | só o roubo | só o roubo |

**A morte limpa é curta de propósito.** Matar não é a forma de tirar um posto de operação: quem
só atira devolve o corredor em um minuto, então a sabotagem por tiro não compensa e o roubo
continua sendo o caminho. Render e matar sem concluir a revista cai aqui, não no prazo longo — o
carimbo do assalto só é gravado quando a revista termina, e até lá o corredor ainda está em campo.
O rival que estava assaltando perde a revista junto, porque a conclusão revalida e encontra o
corredor fora de operação.

**A execução depois da revista é o caminho caro.** Ela substitui o que restava do roubo pelo prazo
cheio, e o prazo só anda para frente: matar nunca devolve o corredor mais cedo do que deixá-lo
vivo. O `config_spec` trava as duas relações — `downAfterRobberyCooldownSeconds` precisa ser maior
que `robbery.cooldownSeconds`, e `downCooldownSeconds` precisa ser menor que ele.

Isso só funciona porque `markDown` aceita corredor em `recovering`. O assalto grava esse estado no
mesmo `UPDATE` que debita a carteira, então, no instante em que a revista termina, o corredor já
não está mais em campo. Enquanto `markDown` exigia `deployed`, a morte dele era recusada em
silêncio: ele voltava no prazo do roubo, sem linha no ledger, sem alerta e sem o corpo marcado para
a engine recolher. Executar o rendido não custava nada.

**A segunda passagem é autorizada pelo carimbo do assalto, e o carimbo é consumido nela.** Sem isso
a varredura reencontraria o mesmo corpo a cada dez segundos e empurraria o prazo para sempre.
Consumido o carimbo, remarcar o mesmo corredor é recusado como sempre foi.

**A execução não abre registro próprio.** Para a organização o episódio é um só, e o alerta de
roubo já saiu: não há linha `dealer_down` no ledger nem segunda notificação no telefone. O que muda
é o prazo, não o aviso. O `Log` do servidor registra os dois casos, com `afterRobbery`, porque ele
é diagnóstico e não o histórico que o jogador lê. A morte limpa, essa sim, abre linha e alerta.

Houve uma punição reduzida — matar até 60 segundos depois do assalto custaria 2 minutos em vez de
20 — e ela **foi removida**, junto com `dealers.robbedGraceSeconds`,
`dealers.robbedDownCooldownSeconds` e o `V.downCooldown` que os consumia. Nunca chegou a funcionar:
o carimbo que alimentava a conta era apagado na recuperação, e até lá o corredor estava sempre em
`recovering`, fora do alcance do `markDown`. Hoje cada caminho tem a sua chave própria.

### Estados

```text
INACTIVE ──rotação──> AVAILABLE ──claim──> CLAIMING ──concluído──> CONTROLLED
                          ^                    │                        │
                          └──cancelado/falhou──┘                        │
                          └──────────expiração / rotação────────────────┘
```

`CONTESTED` e `COOLDOWN` existem nas constantes e nas transições válidas, mas a disputa com
janela de ataque é fase 4 e ainda não tem serviço.

## Autoridade

O client envia apenas intenção e identificadores opacos:

```lua
{ outpostId = 'docks', dealerId = 14, requestId = 'r18f2a3b9c1' }
```

O servidor resolve organização, permissão, produto, quantidade, preço, split, estoque, saldo,
loot, chance de polícia, cooldown e posição. Pontos de controle:

- `server/security.lua`: rate limit por `source + ação`, resolução do ator, allowlist de
  outpost/perfil/produto, validação de distância, bucket e net ID;
- `server/sessions.lua`: sessões opacas com máquina de estado, TTL e cleanup idempotente;
- `server/entity_manager.lua`: o net ID enviado pelo client precisa resolver exatamente para
  a entidade registrada do dealer, com modelo e tipo conferidos;
- **distância até o corredor**: a checagem mede o jogador até onde o servidor acredita que o
  ped está, e o alcance depende de essa crença ser fato ou palpite.

  A posição de um ped conduzido por IA não existe no servidor: ele fica parado na coordenada de
  spawn. Por isso **o dono de rede reporta**, a cada `dealerWander.reportIntervalMs`, onde os
  corredores que ele possui estão. É a fonte principal, e o que tornou a validação honesta.

  O reporte é alegação de client, então chega limitado. **O limite é de continuidade, não de
  área.** Um corredor assustado foge e pode parar bem longe, e esse comportamento é desejado:
  prendê-lo ao raio de caminhada tornaria impossível assaltar exatamente quem correu.

  A âncora começa na esquina cadastrada, que o servidor conhece de fato, e cada reporte só pode
  afastá-la o que um ped percorre no tempo decorrido, por `reportedPositionMaxSpeed`. A posição
  acompanha a fuga a qualquer distância, mas ninguém teleporta o corredor para o próprio colo:
  arrastar a âncora custa o mesmo tempo que andar até lá de verdade. Sem esse limite, um client
  modificado drenaria a carteira da organização sem sair de casa.

  O primeiro reporte depois de ancorar recebe o raio de caminhada como orçamento, porque ali o
  corredor legitimamente já pode estar em qualquer ponto da área dele. E `reportedPositionMaxGap`
  limita o orçamento acumulado, já que sem dono o ped fica parado e um intervalo longo não deve
  virar licença para teleporte.

  Só o dono de rede daquele ped é ouvido, o evento tem limite de taxa e teto de itens por envio,
  e o reporte vence em `reportedPositionTtlSeconds`, para que um dono que saiu não deixe rastro.

  Sem reporte fresco, o servidor cai na leitura própria e na heurística antiga: uma leitura que
  saiu da coordenada de spawn, medida em 3D, prova que a sincronização chega, porque o servidor
  não simula física para estes peds. Essa prova é **por corredor**. Já foi global e estava errado:
  bastava um provar para todos passarem ao alcance apertado, inclusive um cuja leitura ainda era
  o spawn. No píer isso quebrou o assalto, porque o Z cadastrado fica metros acima do chão e a
  distância é medida em 3D.

  No assalto a medida não é uma leitura nova: é a **posição gravada no instante da rendição**,
  em `holdup_service`. Congelar o ponto impede arrastar o alvo para perto de quem está roubando
  durante a janela de revista, e mantém a revista válida mesmo se o corpo escorregar.

  `/outpostsdebug` imprime contra o que cada corredor está sendo medido, se a posição é confiável
  e se a sincronia já se provou;
- progress bars longas revalidam tudo na conclusão e recusam conclusão mais rápida que a
  duração autorizada.

State bags carregam apenas `noir:outpostId`, `noir:dealerId` e `noir:dealerState`. Nenhuma delas
autoriza qualquer coisa.

## Persistência

Sete tabelas próprias, criadas em `migrations/001_initial.sql` e evoluídas pelas migrations
seguintes. A `006_claim_dealer_roster.sql` persiste o elenco sorteado na tomada. O migrador aplica os arquivos em ordem e aceita apenas
`CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS` e `INSERT IGNORE`; nenhuma consulta a schema de terceiros.
Valores monetários são inteiros e timestamps são epoch UTC.

| Tabela | Papel |
|---|---|
| `noir_outposts` | estado, dono, elenco sorteado, carteira disponível/pendente, lock de claim |
| `noir_outpost_dealers` | perfil, identidade sorteada, corner, agenda, recuperação e acumulados |
| `noir_outpost_stock` | estoque virtual por produto |
| `noir_outpost_operations` | ledger idempotente de toda operação econômica e fonte do feed |
| `noir_outpost_rotations` | seleção persistida por ciclo |
| `noir_outpost_organizations` | cooldown de claim por organização |
| `noir_outpost_player_settings` | preferências de alerta e marcador de feed limpo |

Venda, roubo, depósito e coleta usam `UPDATE` condicional com guardas de estado, dono, estoque
e `version` do dealer, então uma corrida perde em vez de corromper. Onde a fronteira é externa
(inventário), a operação é compensada: o depósito devolve exatamente os itens removidos se o
estoque recusar, e a coleta restaura a carteira se a entrega falhar.

O ledger mantém 15 dias de histórico. Na inicialização e depois a cada 12 horas, o scheduler
remove operações mais antigas em lotes limitados, independentemente do status. O índice de
`created_at` mantém essa limpeza barata mesmo quando a tabela acumula muitas vendas.

## Integrações

```lua
-- bgrz_core (server)
AddItem, RemoveItem, GetItemCount, CanCarryItem
AddMoney, RemoveMoney, GetCharacter, Notify
SendPhoneNotification, SendDispatch, CountOnDutyJob

-- bgrz_core (client)
AddEntityTarget, RemoveEntityTarget, AddSphereZoneTarget, RemoveZoneTarget
RegisterPhoneApp, SendPhoneAppMessage, IsLoggedIn, Notify
```

Provider parado devolve `provider_unavailable` e o resource degrada sem falso sucesso: sem
telefone não há notificação e sem dispatch não há alerta, mas a venda continua válida.

Não há progressão externa. Toda telemetria sai do próprio ledger em
`noir_outpost_operations`, que registra venda, depósito, coleta, roubo, contratação,
demissão e tomada com valor, item, quantidade e autor.

## Telefone

O app `exchange` ("The Exchange") é registrado pelo contrato do `bgrz_core` e servido de
`html/phone/`. Ele tem duas abas: **Rede** (pontos conhecidos, status, rota) e **Operação**
(dealers, estoque e carteira da própria organização).

Três abas: **Rede**, **Operação** e **Notificações**. Na aba de notificações o topo ganha dois
botões: limpar e configurações.

**Limpar** não apaga nada do ledger. Ele grava em `noir_outpost_player_settings` até quando
aquele personagem já viu, e o feed passa a entregar só o que veio depois. A marca é por
personagem, então limpar o seu não mexe no de ninguém.

**Configurações** escolhe quais categorias chegam como alerta no telefone: `sales`, `stock`,
`security` e `control`. O filtro vale **apenas para o alerta empurrado**. Dentro do app o
histórico é sempre completo, e existe teste garantindo que desligar o alerta de vendas não
some com as vendas do feed. A de notificações é o ledger de
`noir_outpost_operations` filtrado pela organização, com scroll infinito. A paginação é por
keyset, com o cursor apontando para a última linha entregue, então uma venda nova durante a
rolagem não desloca a janela como um `OFFSET` faria. A página tem tamanho fixo em
`limits.feedPageSize`, o cursor é validado no servidor e o feed nunca sai do escopo da própria
organização.

A interface copia a disposição e as medidas do app **Páginas** do `sd-phone`, não o guia de NUI
do servidor: espaçador de 58px para a barra de status, título de 34px com ação à direita, lista
rolável de cartões com 16px de raio e 12px de espaçamento, e barra de abas fixa embaixo com
ícone de 33px e rótulo de 15px.

Essas medidas estão em `rem` no CSS. O telefone desenha a interface num espaço lógico de 440px
de largura e escala o conjunto, mas o iframe do app não herda essa escala, então px fixo sairia
proporcionalmente maior que nos apps nativos. Ancorando `1rem` em `100vw / 27.5`, que dá 16px a
440px de largura, cada medida acompanha a largura real do frame. A paleta iOS usa os mesmos
nomes de token do telefone. O tema
claro e escuro vem do atributo `data-theme` que o telefone escreve no `body`, então trocar o
tema do celular troca o do app junto. O gate do ícone é apenas visual; cada
callback revalida permissão no servidor.

A página do app roda num iframe dinâmico criado pelo telefone, onde nenhuma fonte de nome de
resource é confiável sozinha. O `resourceName` injetado pelo provider aponta para quem
registrou o app, que é o `bgrz_core`. O `GetParentResourceName()` devolve o nome interno do
frame. Por isso a página valida cada candidato contra o formato de nome de resource antes de
montar a URL dos callbacks, e cai num literal como último recurso.

`phone.defaultApp = true` põe o ícone direto na tela inicial. Com `false` o app aparece só na
App Store do celular e o jogador precisa instalar antes de abrir. Para exigir o cartão na fase 2, defina
`phone.requiresItem = 'outposts_exchange_card'` em `config/shared.lua` e crie o item.

## Comandos

```text
/outposts status          lista estado, dono, dealers, estoque e carteira
/outposts cooldowns <id> [organização]  libera recuperação, abordagem, dispatch e espera de tomada
/outposts release <id>    libera o controle de um outpost
/outposts rotate <id>     rotaciona os corners dos dealers
```

Protegidos pelo ACE `noir.outposts.admin`, pelo ACE `command` ou pelo console. Para conceder o
específico, basta uma linha no `server.cfg`:

```cfg
add_ace group.admin noir.outposts.admin allow
```

Sem permissão o comando responde dizendo o que falta, em vez de não fazer nada.

## Testes

```bash
cd resources/[bgrz]/noir_outposts
for spec in tests/unit/*_spec.lua tests/integration/*_spec.lua; do lua "$spec" || exit 1; done
```

- `validators_spec`: fórmulas de intervalo, quantidade, preço, comissão, loot e transições;
- `config_spec`: sigilo do config público, coerência de limites, catálogo e locales;
- `sessions_spec`: máquina de estado, expiração, cleanup por drop/rotação e painéis;
- `domain_spec`: contratação, limite de dealers, depósito com compensação, venda atômica,
  estoque nunca negativo, coleta idempotente, roubo por rival e rate limit, contra repositórios
  e providers falsos.

## Escopo entregue

Fases 0 a 3 da especificação: contratos, domínio, mundo/interação e interfaces.

Fora do MVP (fase 4): outpost de lavagem de `black_money`, compradores visuais a pé e de carro,
cartão de acesso com metadata, `ox_doorlock`, pistas de descoberta, disputa organizada por
janela de ataque e dashboard de balanceamento.

## Balanceamento

Os valores de `config/server.lua` são ponto de partida. Antes de ajustar, colete:

- receita bruta e líquida por outpost por hora;
- unidades vendidas por produto e tempo até o estoque zerar;
- comissão média dos dealers;
- frequência e valor dos roubos;
- número de dispatches disparados;
- comparação com a receita por hora do `op-drugselling`.

A venda passiva deve render menos por unidade que a venda ativa, porque exige menos exposição.
Os preços iniciais ficam no piso da faixa do `op-drugselling` e o teste de config falha se
caírem abaixo dele.
