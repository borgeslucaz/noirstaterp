# noir_gangs

Gestão de gang em jogo: registro das gangs do servidor, lista de membros, convite por
proximidade, cargos editáveis com permissão, reputação, tipo de produto operado e o mapa dos
bairros dominados.

O resource não fala com o framework. Membros, cargos, personagens e alvos chegam pelos exports
do `bgrz_core`; nenhum arquivo chama `qbx_core` ou `ox_target` diretamente, e o manifest declara
só `ox_lib`, `oxmysql` e `bgrz_core`. Um teste guarda isso.

## Instalação

1. Ordem de start: `ox_lib` / `oxmysql` → `qbx_core` e providers → `bgrz_core` → `noir_gangs`.
   As dependências também estão nos manifests, então um boot limpo já respeita a ordem.
2. `bgrz_core` precisa ter a API de gang (`GetGangInfo`, `GetGangMembers`, `SetGangGrade`,
   `RemoveFromGang`, `GetCharacterNames`, `UpsertGangGrade`) e o `AddBoxZoneTarget`. Se você
   reiniciar só o `noir_gangs` depois de atualizar o bridge, o start falha em `AddBoxZoneTarget`:
   reinicie o `bgrz_core` primeiro.
3. O schema roda sozinho no start, a partir de `migrations/noir_gangs.sql`. Só DDL idempotente e
   não destrutivo passa — `DROP`, `MODIFY` e `RENAME` são recusados e abortam o start, porque o
   arquivo roda inteiro toda vez e nada ali pode apagar dado.
4. Ace `noir.gangsetup` para os comandos de admin.

## Standalone: gang saiu do Qbox

Este resource é o **dono** de gang. O Qbox não guarda mais membresia nem cargo de gang.

Enquanto guardava, o mesmo dado vivia em dois lugares — `player_groups.grade` e o JSON
`players.gang` — e ele conseguia atualizar um sem o outro. A cada republicação de gang,
todo membro online era comparado contra a escada nova e, se ela chegasse vazia por um
instante, caía para `level = 0` com `isboss` e `bankAuth` desligados. Os cargos voltavam;
o nível do jogador, não. E o login relê justamente a coluna corrompida, então não havia
conserto por relog.

| o que | onde mora agora |
|---|---|
| Membresia | `noir_gang_members` (uma linha por personagem) |
| Cargos e permissões | `noir_gang_ranks` |
| Gang do jogador, no client | state bag `noirGang`, escrito pelo servidor daqui |
| Quem é a pessoa (citizenid, nome, source) | **continua no Qbox**, pelo bridge |

Essa última linha é a fronteira: gang saiu, identidade não. Não faz sentido este resource
manter um sistema de personagem próprio.

Quem precisa da gang de alguém pergunta ao `bgrz_core`, que resolve pelo provider
configurado em `Providers.gangs`. O contrato de retorno é o mesmo de antes, de propósito:
nenhum consumidor precisou mudar por causa da troca. O `Renewed-Banking` foi a exceção —
ele lia a tabela de gangs do Qbox direto, e está documentado em `PATCHES-NOIR.md`.

O `qbx_management` fica parado (`stop` no `server.cfg`): as duas zonas de boss menu dele
eram justamente vagos e lostmc, e ele promovia por hierarquia implícita.

## Autoridade: o que é nosso e o que é do Qbox

Esta divisão explica quase todas as decisões do resource.

| | Onde mora | Sincroniza com o Qbox |
|---|---|---|
| Quais gangs existem | `noir_gang_state` | **sim**, via `CreateGangs` |
| Rótulo e cor da gang | `noir_gang_state` | rótulo sim, cor não |
| Quem está na gang, e em que nível | Qbox (`player_groups`) | é dele |
| Rótulo do cargo | `noir_gang_ranks` | **sim**, via `UpsertGangGrade` |
| Permissões do cargo | `noir_gang_ranks` | não |
| Reputação | `noir_gang_state` | não |
| Produtos | `noir_gang_products` | não |

Membresia fica no Qbox porque ele é dono da persistência do personagem: a gang é salva e
carregada no mesmo ciclo do resto, e `PlayerData.gang` é o formato que qualquer resource de
terceiro espera. Reimplementar isso seria refazer o ciclo de vida do personagem.

**Quais gangs existem**, porém, é nosso. O `shared/gangs.lua` do `qbx_core` não lista mais
nenhuma: ele ficou só com a gang vazia `none`, e o resto do dicionário é montado em memória
a partir do nosso registro. Ver [Registro de gangs](#registro-de-gangs).

O **rótulo** precisa viajar para o Qbox porque `PlayerData.gang.grade.name` é o que aparece fora
daqui, e porque `AddPlayerToGang` recusa um nível que a gang não tenha. É por isso que o arquétipo
`mc`, com seis cargos, funciona numa gang que tinha quatro em `shared/gangs.lua`: publicamos os
cargos no start. A publicação usa `commitToFile = false` de propósito — gravar naquele arquivo
atropelaria edições feitas à mão lá.

Permissão, reputação e produto o Qbox não conhece. São nossos, sem sincronização nenhuma.

## Registro de gangs

Quais gangs existem é dado nosso, em `noir_gang_state`, com rótulo, cor e arquétipo. No start
a lista é registrada no Qbox com `CreateGangs`, e cada cargo em seguida com `UpsertGangGrade`
— os dois com `commitToFile = false`, porque gravar naquele arquivo criaria uma segunda
verdade que venceria no restart seguinte.

### Por que o Qbox precisa da lista

Ele não precisa da gang para si. Ele precisa do **dicionário** para montar `PlayerData.gang`,
que é o que o resto do servidor lê — inclusive o `Renewed-Banking`, que decide o acesso ao
dinheiro por `bankAuth`. A linha do personagem em `player_groups` guarda só o nome da gang e o
número do cargo; rótulo, nome do cargo, `isboss` e `bankAuth` saem do dicionário.

### O arquivo é espelho, e a ordem de gravação não é detalhe

O `shared/gangs.lua` é reescrito pelo próprio Qbox, pela API dele, a partir do que está em
memória — no fim do nosso bootstrap, ao criar uma gang e ao trocar o arquétipo de uma. Assim
o dicionário já nasce correto no boot seguinte, antes de qualquer personagem carregar.

**Gravar só depois dos cargos publicados.** O arquivo sai com gangs *e* escadas, e o provider
apaga de `player_groups` toda linha cujo **cargo** não exista. Um arquivo com gang de escada
vazia apaga a membresia de todo mundo no próximo boot. Um teste percorre cada gravação e
exige que nenhuma gang saia sem cargo.

**Publicar uma gang não é publicar a lista.** `CreateGangs` atribui a entrada e zera a escada
de cada gang que recebe; `UpsertGangData` mescla. Por isso a lista inteira só vai para o
provider quando o dicionário dele está vazio — start dele, ou restart — e sempre seguida da
republicação dos cargos. Renomear uma gang usa o caminho que mescla; usar o outro apagaria a
escada de todas as outras, e o erro só apareceria quando alguém tentasse entrar em alguma.

**A escada viaja junto com a gang, no mesmo `CreateGangs`.** Não é otimização: o Qbox avisa
todo jogador online quando a escada de uma gang muda, e cada um procura o **próprio nível**
na escada nova. Quem não se acha é rebaixado para `level = 0`, com `isboss` e `bankAuth`
desligados.

Enquanto os cargos iam depois, um a um, existia uma janela de milissegundos com a escada
vazia — e **todo membro de cargo diferente de 0 saía dela como recruta**. Os cargos voltavam
logo em seguida, mas o nível do jogador já era 0: dali para frente ele só encontrava
`grades[0]` e o rótulo virava "Recruit" permanentemente. O save seguinte gravava isso em
`players.gang`, enquanto `player_groups` seguia com o nível certo — os dois discordando, sem
conserto por relog.

Acontecia a cada restart deste resource ou do `qbx_core`, em silêncio, sem nada no log. Por
isso `publishGangsToProvider` roda **depois** de `loadRanks`, e não antes. Há um teste que
põe membros online em cargos altos, republica, e exige que ninguém tenha se mexido.

### Duas redes, e por que as duas

**`qbx:cleanPlayerGroups` fica `false`** (é o padrão do Qbox; o `server.cfg` daqui o trazia
ligado). Ligado, ele varre `player_groups` no start e **apaga** toda linha cuja gang ele não
conheça *naquele instante* — e nesse instante nós ainda não registramos, porque dependemos
dele para subir. Foi o que apagou a membresia deste servidor em 18/09/2026 03:58. Desligado,
linha desconhecida fica adormecida e volta sozinha quando a gang é registrada. A varredura
continua disponível sob demanda, pelo comando `cleanplayergroups` no console.

**O resource escuta o start do provider e republica** lista, cargos e arquivo. Cobre o
`qbx_core` reiniciando sozinho, quando a memória dele volta a ser só o que está no arquivo.

Uma das duas já basta; as duas juntas significam que nenhuma falha isolada apaga membresia.

### Semente

`Config.Gangs` é a semente, no mesmo acordo dos cargos: gang que não está no banco é criada a
partir dela no start, e depois nunca mais é tocada — quem manda passa a ser o `/gangsetup`.
Gang criada em jogo não está no config e fica sem produto, que é o previsto.

## A tela

A gestão é uma NUI, seguindo o `resources/docs/DESIGN_v3.md`: shell de **janela de comando**,
rail vermelho à esquerda com a cor do serviço, Poppins empacotada no próprio resource e raiz
transparente. Abre pelo radial (*Gang → Minha Gang*) ou pelo ponto de gestão.

| Aba | O que mostra |
|---|---|
| Central | Reputação, membros ativos, bairros e total de membros; abaixo, produto, cargos e até três pessoas acordadas |
| Membros | A lista inteira, com busca, convite e as ações de cargo |
| Cargos | O editor: criar, renomear, marcar o que cada cargo pode e excluir |
| Território | O mapa dos bairros e de quem é cada um |
| Atividade | O histórico, já em português e com nome no lugar do identificador |

Sair da gang fica separado, no fim do rail: é ação de consequência, não navegação.

**Convidar fecha a tela.** O convite é ação de mundo — a pessoa está do seu lado, e ficar
olhando uma janela depois de chamá-la não faz sentido. Por isso o aviso de sucesso sai pela
notificação do jogo, como no radial: uma mensagem dentro de uma tela que fecha em seguida
ninguém leria. A recusa é o contrário — fica na tela, com o motivo, porque "essa pessoa já tem
um convite pendente" é coisa que se lê e se resolve ali mesmo.

### O que a tela não decide

A página **esconde** o que a pessoa não pode fazer, mas isso é cortesia. Toda ação volta ao
servidor, que valida de novo e responde com um código estável (`no_permission`,
`boss_protected`, `cooldown`…); a tradução para português mora só no `html/app.js`. É por isso
que promover alguém para chefe não tem botão **e** é recusado no servidor: a tela some com a
promessa, o servidor cumpre a regra.

Toda ação bem-sucedida devolve o snapshot novo junto com a resposta — a lista nunca fica
mostrando o mundo de antes da ação que a pessoa acabou de tomar.

A trava de clique repetido também é cortesia, e por isso o snapshot tem defesa própria no
servidor: ele é a leitura mais cara daqui (roster, nomes e histórico), então a parte que vem
do banco é cacheada por gang durante `Config.SnapshotCacheTTL` segundos e uma guarda por
jogador impede que um mesmo pedido seja montado duas vezes ao mesmo tempo. O cache guarda a
matéria-prima, nunca o snapshot pronto: o pronto depende do cargo de quem pediu. Quem o
derruba é qualquer mutação da gang, então o refresh de depois de uma ação lê dados novos.

Quem sofre a ação (promovido, rebaixado, desligado) continua recebendo notificação do jogo:
essa pessoa não está com a tela aberta, e é o único aviso que ela tem.

### Território

O mapa é do `noir_territories`, que é dono dos bairros, das cores e dos tiles. Esta tela pede
tudo por `exports.noir_territories:GetTerritoryMap()` — geometria, estado de cada bairro e a
projeção dos tiles — e desenha com o Leaflet empacotado em `html/vendor`.

O `noir_territories` **não** é dependência no manifest, de propósito: o mapa é informação de
apoio, e a aba sabe explicar a ausência. Declarar a dependência faria a gestão de gang inteira
deixar de subir por causa de uma tela de território.

Os tiles não são copiados para cá: a página carrega `nui://noir_territories/web/tiles/...`, e
esse caminho chega pronto no payload — o `html/app.js` só guarda uma cópia dele como último
recurso. Uma segunda pasta com 350 imagens divergiria da primeira no dia em que o mapa fosse
trocado.

## Cargos e permissões

Cada cargo declara exatamente o que pode. **Não há herança entre cargos**: um cargo alto que não
liste `invite` não convida, mesmo que o cargo abaixo dele convide. Quem controla é o config.

O catálogo é fechado e um nome fora dele **derruba o start**. Isso é de propósito: permissão com
erro de digitação não estoura, ela simplesmente nunca é verdadeira, e o erro só aparece no dia em
que alguém precisa dela.

```
view_members · view_offline_members · invite · remove_member
promote · demote · view_reputation · view_products · manage_ranks
```

### Editor de cargos

Quem tem `manage_ranks` edita a escada da gang pela aba **Cargos**: criar, renomear, marcar
o que o cargo pode e excluir. Só o cargo de chefe nasce com essa permissão — daí ele pode
concedê-la a outro cargo, editando aquele cargo.

**O chefe sempre tem `manage_ranks`**, e isso é garantido a cada start, não só pelo config.
O cargo de chefe é o único que o editor não edita, então é o único que ninguém conserta de
dentro do jogo: um chefe sem essa permissão trancaria a gang fora do editor para sempre. É
também por esse caminho que uma permissão nova alcança quem já tinha cargos gravados — com
o config valendo só como semente, nada mais reescreve aquelas linhas.

Três coisas o editor **não** mexe, e cada uma protege uma regra que já existia:

| O que | Por quê |
|---|---|
| O cargo de chefe | É o `isBoss` dele que torna a chefia intocável. Se desse para desmarcar, qualquer um com `manage_ranks` desligaria o chefe em dois passos |
| O próprio cargo de quem edita | Seria auto-promoção: bastaria marcar todas as permissões no cargo em que a pessoa já está |
| O nível de um cargo | Mudar o nível é mover todo mundo que está nele |

#### `level` é identidade; `sort_order` é posição

São duas colunas, e a separação é a razão de o editor ser seguro.

**`level` nunca muda depois que o cargo nasce.** É o identificador que o Qbox usa: é ele que
está em `player_groups.grade`, em `players.gang`, nas chaves de `shared/gangs.lua` e no
histórico deste resource. Renumerar um cargo significa mover **cada membro dele** de grade,
nos dois lados do Qbox.

**`sort_order` é onde o cargo aparece na escada**, e muda à vontade: nada persiste contra
ela.

Enquanto as duas eram a mesma coluna, criar um cargo abaixo do chefe exigia *subir o chefe
de nível* — e com isso mover toda a chefia de grade, com compensação manual se falhasse no
meio. Foi esse caminho que dessincronizou uma gang de verdade: um cargo criado no meio da
escada empurrou o Boss de 3 para 4, a migração passou pelo `AddPlayerToGang` do `qbx_core`,
e o caminho **offline** dele grava o `player_groups` mas não atualiza a gang primária —
deixando `player_groups` num nível e `players.gang` em outro, sem conserto por relog.

Hoje nada disso acontece: criar cargo não move ninguém.

**Cargo novo nasce logo abaixo do chefe na escada**, sem nenhuma permissão, e recebe o
**próximo identificador livre** — sempre acima de todos, nunca entre dois existentes. O
chefe é empurrado uma casa em `sort_order`, o que é de graça.

O número de um cargo excluído **não volta a circular**: o histórico grava `oldGrade` e
`newGrade` como números, e reaproveitar faria "promovido para o cargo 4" significar dois
cargos diferentes em épocas diferentes. A marca d'água sai do próprio provider, que nunca
esquece um grade.

#### Alterar cargo, não promover um degrau

A tela tem **um** botão, `ALTERAR CARGO`, e um modal onde se escolhe o cargo de destino.

Antes eram dois botões, cada um movendo um degrau. Isso parou de querer dizer alguma coisa
quando a escada deixou de ser contígua: com um cargo novo no meio dela, "promover" podia
significar mandar alguém exatamente para o cargo que ninguém queria — e para pular dois
degraus era preciso clicar duas vezes, gerando duas linhas de histórico para uma decisão só.

A permissão continua sendo a mesma de antes, e a **direção** é que decide qual: subir na
escada exige `promote`, descer exige `demote`. Quem tem só uma das duas vê o botão e recebe
a recusa se escolher o lado errado. O modal não oferece o cargo de chefe nem o cargo atual
da pessoa.

A direção é medida por `sort_order`, nunca pelo número do cargo — comparar `level` chamaria
de promoção o que é rebaixamento, porque um cargo criado depois tem número maior sem estar
mais alto.

Duas recusas existem para não deixar ninguém preso:

- **cargo ocupado não é excluído.** Essas pessoas cairiam num nível sem cargo: sem permissão
  nenhuma, sem rótulo, e sem promoção que as tirasse de lá. Mova quem está lá primeiro.
- **a gang não fica só com o chefe.** Precisa sobrar um cargo comum, que é por onde entra
  quem aceita um convite — e a entrada usa o menor cargo que a gang **tem**, não um número
  fixo, justamente porque o editor pode apagar o mais baixo.

O teto é `Config.Ranks.max`. Ele existe porque cada cargo vira também um grade no Qbox,
publicado por nós e **nunca removido de lá** — apagar um grade do provider arriscaria deixar
algum personagem num nível que ele recusa. O grade de um cargo excluído fica órfão e
inofensivo: ninguém está nele, e nada nosso aponta para ele.

Rótulo e `bankAuth` viajam para o Qbox a cada edição, porque `PlayerData.gang.grade.name` é
o que o resto do servidor lê e o `Renewed-Banking` decide o acesso ao dinheiro da gang por
`bankAuth`. Permissão não viaja: o provider não tem conceito dela.

### As duas regras estruturais

Acima da permissão existem só duas regras no código, e as duas protegem o chefe (`isBoss`):

- **Chefe não é desligado nem muda de cargo.** Nem promoção, nem rebaixamento, nem remoção.
- **Ninguém é promovido *para* chefe.** Seria passar a liderança por mecanismo de jogador.

Não existe comparação entre o cargo de quem age e o de quem recebe. Quem tem `promote`, promove —
inclusive alguém de cargo mais alto. Se um cargo não deve poder, ele não recebe a permissão.

### Arquétipos

Três no config, e cada gang aponta para um. Gang que existe no Qbox e não está em `Config.Gangs`
cai em `Config.FallbackArchetype` e funciona, sem produto.

| Arquétipo | Cargos |
|---|---|
| `gueto` | Recruit · Enforcer · Shot Caller · **Boss** |
| `mc` | Prospect · Member · Road Captain · Sergeant at Arms · Vice President · **President** |
| `cartel` | Halcón · Sicario · Lugarteniente · Jefe de Plaza · **Patrón** |

O cargo logo abaixo do chefe sempre gere de verdade (`promote`, `demote`, `remove_member`), e um
teste exige isso. Com o chefe intocável e a promoção parando antes dele, se só o chefe gerisse, um
chefe inativo deixaria a gang sem gestão e sem saída.

Os níveis não precisam ser contíguos: uma gang com cargos 0, 2 e 5 é válida, e promover pula para
o próximo que existe de verdade.

## Reputação

Um inteiro por gang. **Ninguém edita a própria reputação pelo menu** — quem tem `view_reputation`
só vê. Ajustar é coisa de admin (`/gangrep`) ou de outro resource, via export.

Todo ajuste entra no histórico da gang com quem fez, quanto e por quê. Além do teto total
(`Config.Reputation.min/max`), existe um teto por ajuste (`maxDelta`): sem ele, um zero a mais
digitado no comando estoura o placar de uma vez. Ajuste que bateria no limite retorna `at_limit`
em vez de fingir que aplicou.

## Produtos

O que a gang opera, para destravar craft, laboratório e tipo de missão nos outros resources.

A tabela é `(gang_name, product_type)`, chave composta — então **mais de um produto por gang já
funciona hoje**, é só listar no config. Na prática cada gang tem um.

| Gang | Arquétipo | Produto |
|---|---|---|
| `ballas`, `families`, `vagos` | gueto | `drugs` |
| `lostmc` | mc | `weapons` |
| `cartel` | cartel | `items` |
| `triads` | cartel | `attachments` |

Os tipos vivem em `Config.ProductTypes` (`drugs`, `weapons`, `items`, `ammo`, `attachments`).
Produto fora do catálogo derrubaria o start, igual permissão.

Quem consome pergunta por export — não há materialização para bancada nativa do `ox_inventory`.

**Quem manda é a tela, não o config.** Produtos seguem o mesmo acordo dos cargos: o
`Config.Gangs` é semente. Gang que nunca foi semeada recebe a lista de lá no start; a partir
daí quem vale é o que o `/gangsetup` gravou — inclusive a escolha de não operar nada. A marca
fica em `noir_gang_state.products_seeded`, e é ela que separa "nunca foi semeada" de "foi
esvaziada de propósito"; sem ela, tirar o último produto em jogo seria desfeito no start
seguinte. `Config.ProductsFromConfig = true` devolve o comportamento antigo, de reescrever
tudo a cada start.

É isso que fecha o ciclo da gang criada em jogo: antes ela nascia sem produto e só ganhava um
pela edição do arquivo mais um restart.

## Convites e saída

Convite é por proximidade e é validado **duas vezes**: no envio e de novo no aceite, quando
distância, permissão, gang e validade são conferidas outra vez. Convite tem expiração e cooldown
por remetente.

A checagem "já tem gang" olha todas as gangs do personagem, não só a primária. O servidor roda com
uma gang por personagem (`qbx:max_gangs_per_player` no padrão 1), e é justamente por isso: alguém
que constasse em `gangs` com a primária em `none` passaria pelo convite para falhar na entrada,
com a mensagem errada.

Sair da gang não tem trava. Como não existe transferência de liderança por jogador, exigir que o
chefe passasse o cargo antes o prenderia na gang para sempre. Chefe que sai deixa a gang sem topo,
e quem recompõe é a administração.

## `/gangsetup`

Ferramenta de administração, atrás do ace `noir.gangsetup`. É a mesma página da gestão em
outro modo — um resource tem um `ui_page` só — com o acento neutro do guia em vez do vermelho
da gang: ferramenta de admin não é a tela da gang, e vestir as duas igual faria uma passar
pela outra. As duas nunca abrem juntas.

| Aba | O que faz |
|---|---|
| Gangs | Cria gang (identificador, nome, arquétipo, produtos e cor), edita as que existem e define o primeiro chefe |
| Pontos | Todos os pontos de gestão do mundo: teleportar, mover e excluir |

O **identificador** é definido só na criação e nunca muda: é ele que vai para o `player_groups`
e é por ele que cada personagem aponta para a gang — renomear deixaria órfã toda pessoa que já
está dentro. O que se edita é o rótulo, que é só apresentação.

O **primeiro chefe** aparece só onde falta um: gang que tem a escada montada e ninguém no
topo. A lista oferece quem está online e fora de qualquer gang, pela mesma regra do convite —
o servidor roda com uma gang por personagem. Com um chefe em pé a opção some, porque **trocar
quem lidera continua sendo `/setgang`**: não existe caminho de jogador que passe ou tome a
liderança, e a tela de admin não abre uma exceção silenciosa para isso. O que ela evita é a
volta pelo console logo depois de criar a gang.

O **arquétipo** define a escada de cargos. Trocá-lo reescreve a escada inteira, então só é
permitido **enquanto a gang está vazia**: com gente dentro, cada pessoa cairia num nível que
talvez não exista do outro lado. A tela desabilita a troca e diz quantas pessoas estão lá.

A **cor** é identidade da gang. Ela viaja para os clientes junto com o nome e o rótulo, e é de
lá que o mapa de território pinta cada bairro — antes ele tinha a própria lista de cores, que
envelhecia sozinha.

São duas formas de guardá-la: o **nome de uma da paleta** (`Config.Colors`) ou **`#RRGGBB`**,
quando foi escolhida no seletor livre. O nome é preferível quando serve, porque mexer na paleta
do config repinta todas as gangs que a usam; o hexadecimal existe para o que a paleta não cobre.

Livre, mas não invisível: a tela e o mapa são quase pretos, e uma gang em `#101014` sumiria
exatamente onde ela mais precisa ser vista. O piso é o contraste mínimo que o guia pede para
objeto gráfico — 3:1, medido contra o fundo do mapa, pela mesma conta do WCAG. A régua é
objetiva e não gosto pessoal: toda a paleta passa com folga, e um teste exige isso dela. A tela
avisa na hora; quem recusa é o servidor.

O seletor usa sliders de matiz, saturação e brilho, mais um campo hexadecimal. Não é
`input[type=color]` porque ele abre um diálogo nativo que o CEF não tem, e não é um quadrado
2D porque aquilo não se opera pelo teclado — `range` anda com as setas de fábrica.

Adicionar ou mover um ponto solta o foco e esconde a tela: não dá para escolher um lugar no
mundo olhando para uma janela. A tela volta com o resultado.

**Apagar gang não existe**, de propósito. Não há como fazê-lo sem deixar em silêncio, no
próximo login, todo personagem que estivesse dentro dela.

## Pontos de gestão

Zonas de caixa criadas em jogo pelo admin (`/gangsetup`), persistidas e visíveis só para membros
da gang dona. As zonas são registradas pelo `bgrz_core`, que as limpa sozinho quando o resource
para.

Quem pede a lista é o client, ao entrar e a cada restart do resource — um empurrão do servidor no
start se perderia, porque os dois lados reiniciam juntos e o client ainda não registrou o evento.
Como o pedido vem de fora, tem teto por source. Edições do admin continuam saindo por broadcast.

## Comandos

| Comando | Quem | O que faz |
|---|---|---|
| `/gangsetup` | ace `noir.gangsetup` | Cria e edita gangs, e cuida dos pontos de gestão |
| `/gangrep <gang> <pontos>` | ace `noir.gangsetup` | Soma reputação; número negativo tira |
| `/gangstatus` | ace `noir.gangsetup` | Diz se o bootstrap passou, e quantas gangs e pontos estão no ar |
| `/gangmembro <id> <gang\|none> [cargo]` | ace `noir.gangsetup` | Põe ou tira alguém de uma gang, por fora da tela |

`/gangmembro` substitui o `/setgang` do `qbx_core`. O comando do Qbox continua existindo,
mas **escreve num lugar que ninguém mais lê**: a membresia é deste resource desde que o
Qbox deixou de ser dono dela. Sem cargo, a pessoa entra pelo cargo de entrada — o mais
baixo que a gang **tem**, não um número fixo.

## Integração

```lua
exports.noir_gangs:GetGang(source)                       --> { name, label, grade, gradeName, isBoss }
exports.noir_gangs:HasGangPermission(source, permission) --> boolean
exports.noir_gangs:GetGangMembers(gangName)              --> { { citizenId, grade }, ... }
exports.noir_gangs:GetCitizenGang(citizenId)            --> gang por citizenid, inclusive offline
exports.noir_gangs:GetGangRanks(gangName)                --> { [level] = { label, isBoss, permissions } }

exports.noir_gangs:GetGangReputation(gangName)           --> integer
exports.noir_gangs:AddGangReputation(gangName, delta, motivo) --> total | nil, errorCode

exports.noir_gangs:GetGangProducts(gangName)             --> { 'drugs', ... }
exports.noir_gangs:HasGangProduct(gangName, tipo)        --> boolean
exports.noir_gangs:PlayerHasGangProduct(source, tipo)    --> boolean

exports.noir_gangs:GetGangManagementLocations(gangName)  --> { { id, coords, size, heading }, ... }

exports.noir_gangs:GetGangList()                         --> { { name, label, color, archetype }, ... }
exports.noir_gangs:GetGangColor(gangName)                --> '#RRGGBB'

exports.noir_gangs:IsReady()                             --> boolean
```

`IsReady` existe porque as outras respostas mentem por omissão quando o bootstrap falha: o
registro fica vazio, e vazio é indistinguível de "essa gang não opera nada". Quem toma decisão
a partir daqui pergunta primeiro.

No **cliente** o diretório também está disponível, para quem desenha e não pode perguntar ao
servidor a cada quadro:

```lua
exports.noir_gangs:GetGangColor(gangName)     --> '#RRGGBB'
exports.noir_gangs:GetGangDirectory()         --> { [gangName] = { name, label, color, colorHex } }
```

`GetGang` devolve a gang já normalizada pelo bridge: `grade` é o **nível** (número) e o nome do
cargo vem em `gradeName`. Ler `grade.level` aqui não estoura — cai no `or 0` e todo mundo vira
cargo 0 em silêncio.

Consumidores hoje: `noir_illegal_core` (`server/bridges/gangs.lua`) e `noir_graffiti`
(`server/validation.lua`).

## Persistência

| Tabela | Guarda |
|---|---|
| `noir_gang_locations` | Pontos de gestão |
| `noir_gang_activity` | Histórico de toda ação de gestão |
| `noir_gang_state` | O registro: quais gangs existem, com rótulo, cor, arquétipo e reputação |
| `noir_gang_products` | Produtos por gang |
| `noir_gang_members` | **Membresia.** Uma linha por personagem: gang e nível. É a fonte de verdade — o Qbox não guarda mais gang nenhuma |
| `noir_gang_ranks` | Cargos: rótulo, `isBoss`, `bankAuth`, permissões, e `sort_order` (posição na escada, separada do `level`) |

`is_boss` e `bank_auth` são `TINYINT(1)`, e um `TINYINT(1)` não tem representação única do
lado do Lua: dependendo do driver e da versão, o mesmo `1` chega como número, como `true` ou
como string. A conversão acontece num lugar só, em `loadRanks`, quando a linha entra na
memória. Comparar com `1` puro acerta numa representação e falha calado nas outras — e
falhar ali significa gang sem chefe, ou seja, chefia desprotegida e editor de cargos que não
abre para ninguém. Por isso um chefe ausente agora vira erro no console em vez de silêncio.

Ações gravadas no histórico: `invitation_sent`, `invitation_declined`, `member_joined`,
`member_promoted`, `member_demoted`, `member_removed`, `member_left`, `reputation_changed`,
`rank_created`, `rank_updated`, `rank_deleted`, `gang_created`, `gang_updated`,
`management_point_created`, `management_point_moved`, `management_point_deleted`,
`boss_assigned`.

### Histórico: índice e retenção

A leitura é `WHERE gang_name = ? ORDER BY id DESC LIMIT Config.ActivityLimit`, e o índice é
`(gang_name, id)` exatamente por causa dela: com a ordem vindo do índice, o banco lê as
linhas que a tela mostra e para. O índice antigo terminava em `created_at`, o que obrigava a
ordenar à parte — um filesort sobre tudo que aquela gang já tinha feito, crescendo para
sempre. Em banco que já existe, o índice velho continua lá; ele não atrapalha, e apagá-lo é
manual, porque `migrations/noir_gangs.sql` roda a cada start e nada lá pode destruir:

```sql
DROP INDEX `idx_noir_gang_activity_gang_created` ON `noir_gang_activity`;
```

A tabela também não cresce mais sem fim. Cada gang guarda as `Config.ActivityRetention`
linhas mais novas (500 por padrão, dez vezes o que a tela mostra); o corte é por contagem e
por gang, e não por data, porque assim ele usa o mesmo índice da leitura. A poda passa no
start e a cada `Config.ActivityPruneInterval` horas. `Config.ActivityRetention = 0` desliga a
poda e guarda tudo.

### `Config.RanksFromConfig`

Quem manda nos **cargos**: o config ou o banco.

`false` (padrão): o arquétipo é **semente**. Uma gang sem nenhum cargo recebe os do arquétipo
no start; uma gang que já tem cargos nunca mais é tocada, porque a partir dali ela é editada
em jogo. É o modo que faz o editor existir — com `true`, toda edição some no restart seguinte.

`true`: o config reescreve `noir_gang_ranks` a cada start, como antes do editor. Serve para
servidor que prefere versionar a hierarquia no arquivo, e para desfazer uma bagunça: sobe uma
vez com `true`, volta para `false`.

**Produtos não dependem desta chave.** Eles não têm editor, então continuam saindo do config a
cada start. **Reputação nunca é tocada** por nenhum dos dois modos, e um teste garante isso.

## Quando o bootstrap falha

`NoirGangs.bootstrap()` reprova quando o config tem erro, o schema é recusado ou o banco não
responde. O que isso deixa para trás não é "servidor sem gangs": é **gang nenhuma publicada no
provider** — e o Qbox, ao carregar alguém cuja gang não está no dicionário, descarta a gang
daquela pessoa com um aviso no console e nada mais.

Por isso o resource não serve o registro vazio. Sem bootstrap:

- o snapshot volta com `notReady`, e o menu diz que o sistema não subiu, em vez de "sem acesso";
- toda ação — convite, membro, cargo, gang, ponto — recusa com `not_ready`;
- o console repete o erro a cada `Config.BootstrapAlertInterval` segundos, porque a linha do
  start some em minutos num servidor movimentado;
- `/gangstatus` e o export `IsReady` respondem o estado a quem perguntar.

Nada disso conserta o start; serve para que a falha apareça como falha, e não como "perdi
minha gang".

## Uma ação por gang de cada vez

As ações de membro e de cargo passam por uma tranca **por gang**, no servidor. A tela já tranca
o clique repetido, mas essa tranca é do cliente, e o problema não é só clique repetido: o teto
de cargos é contado da memória antes da escrita, e a escrita cede o controle. Dois chefes
criando cargo ao mesmo tempo passavam os dois pela contagem, e disputavam o mesmo nível.

Quem chega no meio recebe `busy` e tenta de novo — a fila seria pior: ela executaria, minutos
depois, uma decisão tomada sobre uma tela que já não existe.

## O que não existe, de propósito

- **Transferir liderança.** Trocar quem lidera é `/setgang` do admin. Não há caminho de jogador
  que passe ou tome a liderança.
- **Se colocar numa gang.** Entrar depende de convite de outra pessoa.
- **Locales.** Os textos estão em pt-BR no código e no `html/app.js`. Os irmãos
  (`noir_outposts`, `noir_busjob`, `noir_houserobbery`) usam `ox_lib 'locale'` com
  `locales/*.json`; aqui isso ainda não foi feito. Os códigos de erro do servidor já são
  estáveis, então traduzir é trocar um mapa de strings de lugar.
- **Editar território pela tela.** O mapa é leitura. Bairro se domina pichando, no
  `noir_graffiti`.

## Testes

Lua 5.4, a partir da raiz do resource:

```
lua5.4 tests/unit/config_spec.lua
lua5.4 tests/unit/state_spec.lua
lua5.4 tests/unit/server_spec.lua
```

- `config_spec` — acoplamento (nada de `qbx_core`/`ox_target`), catálogo de permissões, um chefe
  por arquétipo no topo, gestão abaixo do chefe, gangs do config existindo no Qbox, schema
  idempotente, e a tela: tudo que a página pede existe no disco, está em `files` e não vem de
  CDN — um arquivo faltando não dá erro no CEF, a tela só não aparece.
- `state_spec` — roda `server/state.lua` contra um banco em memória: schema, validação do config,
  seed dos cargos, publicação do rótulo no provider, permissão por cargo, produtos (inclusive
  vários por gang) e limites da reputação.
- `server_spec` — regras de membro com o `NoirGangs` stubado: chefe intocável, promoção parando
  antes do chefe, ausência de comparação de hierarquia, convite, cooldown e limpeza no
  `playerDropped`. Cobre também o custo do snapshot: pedido repetido sai do cache sem tocar o
  banco, mutação derruba o cache, e pedido concorrente do mesmo jogador não abre uma segunda
  montagem.
