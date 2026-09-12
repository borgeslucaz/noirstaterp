# noir_outposts

Outposts disputados por organizações criminosas, com dealers NPC que vendem estoque
passivamente enquanto o local estiver sob controle.

O resource é dono do domínio (posse, dealers, estoque, agenda, carteira, roubo). A única
dependência de integração é o `bgrz_core`. Nenhum arquivo chama `qbx_core`, `noir_gangs`,
`ox_inventory`, `ox_target`, `sd-phone`, dispatch ou `ox_doorlock` diretamente.

A organização dona de um outpost é a gang do personagem, lida do `GetCharacter` do bridge.
Vale o `name` da gang como `organizationId` e o `grade.level` como cargo. Um personagem em
`none` não tem organização e não consegue tomar, contratar, abastecer nem coletar.

## Instalação

1. Garanta a ordem de start: `ox_lib` / `oxmysql` → `qbx_core` e providers → `bgrz_core` →
   `noir_outposts`. O `server.cfg` já traz essa ordem explícita antes do `ensure [bgrz]`.
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
caminhada quando a propriedade troca de mão. Eles não fogem de tiro, por atributo de fuga, e
continuam mortais. Enquanto rendidos ou hostis a caminhada para, e volta quando a abordagem
termina.

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

### Identidade do corredor

O perfil é o arquétipo contratado: preço, ritmo de venda, capacidade, comissão. Ele não é mais o
sujeito. Nome e ped são sorteados no momento da contratação, das listas em `dealerIdentities`, e
gravados na linha do corredor. Ficam gravados de propósito: mudar a lista no config não troca o
rosto de quem já está na rua, e um restart não redistribui ninguém.

O sorteio evita repetir nome ou ped já em uso no mesmo posto. Com tudo tomado ele repete em vez
de recusar a contratação, o que só acontece se a lista ficar menor que o teto de corredores por
posto, e `config_spec` barra essa configuração.

Corredores contratados antes desta mudança ficam com as colunas nulas e caem no nome e no modelo
do arquétipo, então nada quebra sem backfill. O feed guarda o nome dentro da operação: um
corredor demitido leva o dele embora, e sem essa cópia o histórico passaria a mostrar o
arquétipo no lugar de quem estava lá.

### Atendente do terminal

O computador é uma zona de alvo invisível, então um local sem MLO ou objeto próprio não
tem nada para mirar. Por isso `config/shared.lua` traz `terminalNpc`, um NPC local criado no
client em cima da coordenada do terminal, que serve de âncora de interação.

```lua
terminalNpc = {
    enabled = true,
    model = 's_m_m_highsec_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD',
},
```

Ele é auxiliar de teste. Quando um local ganhar um objeto próprio, marque
`terminalNpc = false` naquele outpost, ou desligue `enabled` para todos. Onde há atendente a
zona invisível não é criada, então nunca existem duas opções de abrir o mesmo terminal.

O ped nasce exatamente na coordenada `computer`, sem ajuste de altura. Como as ferramentas de
dev copiam a posição do jogador, que fica cerca de um metro acima do chão, desconte esse metro
ao cadastrar um local novo, ou o atendente vai flutuar.

O ped não é networked e não carrega estado: toda autorização continua no servidor, que
revalida a distância até a coordenada do terminal, não até o NPC.

### Coordenadas

As coordenadas em `config/shared.lua` são **placeholders** e precisam ser capturadas in-game
antes de produção: `computer` (terminal), `entrance` (blip/dispatch) e no mínimo seis
`dealerCorners` por local. O start aborta se algum local tiver menos corners que o limite de
dealers.

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
2. Uma organização com grade suficiente inicia a tomada no terminal. O claim é travado no banco
   (`status = claiming` + `claim_session_id`), então duas organizações não concluem ao mesmo tempo.
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
10. Matar um corredor também o tira por 20 minutos. O corpo fica caído onde estava, deixa de
    ser mantido à força e some sozinho quando a área esvazia. Na recuperação o que tiver
    sobrado é removido e um ped novo assume o posto. Corredor em recuperação não vende, não
    pode ser roubado e não aceita a opção de observar.
    **Exceção:** matar dentro de 60 segundos após o assalto tira ele por apenas 2 minutos.
    Sem essa regra, roubar e executar o rendido removeria o corredor por 20 minutos de graça,
    transformando o assalto em sabotagem barata em vez de escolha entre levar ou punir.
11. Ao expirar o controle ou mudar o ciclo, dealers e estoque são encerrados.

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

  O servidor só enxerga um ped movido por IA se o client dono estiver sincronizando a posição.
  Ele descobre isso sozinho: uma leitura que saiu da esquina de spawn, no plano X/Y, só pode ter
  chegado pela sincronização, porque ninguém move aquele ped no servidor. A primeira leitura
  assim liga `positionSyncProven` para o resource inteiro, e a partir daí a medida é a real, com
  a distância de interação sem folga nenhuma. Antes disso a medida cai na **esquina cadastrada**
  somando `dealerWander.radius` como folga, o que é frouxo mas confina a ação à área do posto.

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

Sete tabelas próprias, criadas em `migrations/001_initial.sql` indexadas para o feed em
`migrations/002_operation_feed.sql` e completadas por `migrations/003_player_settings.sql`. O migrador aplica os arquivos em ordem e aceita apenas
`CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS` e `INSERT IGNORE`; nenhuma consulta a schema de terceiros.
Valores monetários são inteiros e timestamps são epoch UTC.

| Tabela | Papel |
|---|---|
| `noir_outposts` | estado, dono, carteira disponível/pendente, lock de claim |
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
/outposts cooldowns <id>  libera recuperação, abordagem, dispatch e espera de tomada
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
