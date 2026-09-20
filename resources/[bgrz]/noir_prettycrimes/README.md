# noir_prettycrimes

Container de pequenos crimes de rua do Noir State RP.

Um resource, vários crimes independentes. Cada crime é um par de módulos
(`client/crimes/<id>` e `server/crimes/<id>`) que o container liga ou desliga pela
config, sem que nenhum deles conheça o outro.

Crimes implementados hoje: **smashgrab** e **parkingmeter**.

Os dois são petty crime de rua, e são deliberadamente diferentes por dentro: o
smash & grab age sobre uma **entidade de rede** (um veículo, com netId e state
bag) e o parquímetro age sobre um **prop de mapa** (sem netId, sem entidade no
servidor, sem state bag). Quase toda decisão de arquitetura do segundo sai dessa
única diferença, e ela está explicada onde aparece.

## Smash & Grab

Não é roubo de veículo, e não é "vasculhar um carro". É o jogador **ver** uma
mochila no banco de trás de um carro estacionado, quebrar aquele vidro e pegar.

```
carro estacionado com uma mochila no banco traseiro direito
        ↓
o jogador vê o objeto através do vidro, de longe
        ↓
chega perto e mira o vidro daquela porta
        ↓
ox_target: [ Quebrar vidro ]
        ↓
animação de 5s
        ↓
CRASH — o vidro estoura para todo mundo; o alarme pode disparar
        ↓
ox_target: [ Roubar mochila ]
        ↓
animação de 3s enfiando o braço no carro
        ↓
a mochila some, para todo mundo por perto
        ↓
o servidor decide e entrega o loot; a polícia pode ser avisada
```

São **dois gestos separados**, com duas animações e dois alvos. A quebra não
acontece de brinde quando o jogador escolhe o loot — é ela que faz barulho e chama
o alarme, e é ela que transforma "tem uma mochila ali" em "eu me comprometi".

Duas regras que moldam o resto:

**Só o vidro daquela porta serve.** Mochila no banco traseiro direito com o vidro
dianteiro quebrado continua fora de alcance: cada posição está amarrada à sua
janela. Quebrar o vidro errado não adianta nada.

**Os alvos ficam no veículo, não no prop.** O raycast do ox_target pega a primeira
entidade no caminho, que olhando um carro de fora é sempre a carroceria — um prop
no banco de trás fica atrás dela e nunca seria mirado. Por isso as duas opções
moram no veículo, filtradas pelos ossos daquela janela (`window_rr`, `door_pside_r`,
`seat_pside_r`), que é exatamente como o próprio ox_target faz as opções de porta e
assento. O prop é puramente visual.

**O objeto é físico.** Não existe loot invisível: se o jogador não viu um prop
pendurado no banco, não há nada para pegar ali.

## Parquímetro

Um poste na calçada com uma caixa de moedas. O jogador força a portinhola com uma
chave de fenda e leva o troco de meio quarteirão.

```
parquímetro na calçada (prop do mapa, sempre lá)
        ↓
o jogador chega perto e mira
        ↓
ox_target: [ Arrombar parquímetro ]
        ↓
o servidor confere ANTES de qualquer animação: distância, área,
ferramenta, cooldown, teto por hora, e se o poste já foi esvaziado
        ↓
minigame de fechadura (lib.skillCheck)
        ↓
barra de 4s forçando a portinhola  — aqui pode sair o 10-35
        ↓
barra de 3s recolhendo as moedas
        ↓
o servidor paga, marca o poste como vazio e avisa todo mundo
        ↓
o poste some dos alvos de todos os clients por meia hora
```

É inspirado no [`cbd-meters`](https://github.com/ChristianBDev/cbd-meters) na
ideia, e diferente dele em tudo que envolve autoridade. Vale listar, porque as
diferenças são exatamente o que o §7 do `SCRIPT_GOOD_PRACTICES` pede:

| No `cbd-meters` | Aqui |
| --- | --- |
| o client decide se roubou e dispara o evento no fim | o servidor autoriza **antes** e mede o tempo decorrido |
| `Config.Money` é sorteado uma vez, no load do config | a recompensa é sorteada no servidor, por arrombamento |
| o alerta policial é disparado pelo client | o alerta é do servidor, com a coordenada dele |
| o item é exigido pelo `items` do ox_target | o item é conferido no servidor (§7.1: esconder não é impedir) |
| a lista de postes roubados cresce para sempre e é comparada por raio de 10 m | cada poste tem identidade própria e expira sozinho |
| cooldown local, por client | cooldown e teto por `citizenId`, no servidor |

### O problema da identidade

Esta é a parte que vale entender antes de mexer no módulo.

Parquímetro é **prop de mapa**. Não foi criado por ninguém, não tem netId, não
existe no servidor, e o handle local muda cada vez que o streaming recarrega a
região. Nenhuma das coisas que identificam o veículo do smash & grab existe aqui.

O que sobra é a **coordenada** — e ela serve, porque prop de mapa não anda e a
posição dele é idêntica em todos os clients. Arredondada para células de meio
metro, ela vira uma chave que os dois lados calculam igual:

```lua
-- shared/parkingmeter_rules.lua
Rules.meterKey(vec3(360.12, -1800.44, 29.30))  --> '720:-3601:59'
```

O cálculo mora no shared e é função pura por um motivo prático: se client e
servidor divergissem no arredondamento, **nada daria erro**. O servidor esvaziaria
um poste, o client continuaria oferecendo o alvo do mesmo poste, e o jogador veria
uma recusa sem explicação. É o tipo de bug que só aparece em teste, e é por isso
que ele tem um.

### O que o servidor consegue validar (e o que não consegue)

O servidor **não consegue ver o poste**. Ele não tem como confirmar que existe um
parquímetro na coordenada que o client mandou. O que ele confere, em ordem de
custo:

| # | Checagem | Contra o quê |
| - | -------- | ------------ |
| 1 | rate limit por jogador (`attemptInterval`) | spam de evento |
| 2 | model na allowlist (§7.4) | arrombar "qualquer prop" |
| 3 | coordenada finita e dentro do mapa | payload lixo |
| 4 | **o jogador está na coordenada**, medido com a posição server-side do ped | saque à distância |
| 5 | a coordenada cai numa área onde parquímetro existe | poste imaginário no deserto |
| 6 | o poste não está vazio nem reservado por outro | duplicação e corrida |
| 7 | cooldown e teto por hora, por `citizenId` | farm |
| 8 | ferramenta no inventário, conferida no servidor | `items` do target é só UI |
| 9 | tempo decorrido entre `reserve` e `claim` (§17.4) | pular as animações |

O passo 4 é o que sustenta os outros: sem ele, coordenada seria só um número no
payload. Com ele, o cheater precisa estar fisicamente onde diz que está.

**O buraco que sobra, dito na cara:** quem está numa rua com postes de verdade
pode inventar coordenadas vizinhas e arrombar postes que não existem. O passo 5
não pega isso, porque a rua está dentro da área. Quem pega é o passo 7: com
`maxPerHour = 8`, o cheater ganha no máximo o que um jogador honesto ganharia
achando oito postes. Ele economiza a caminhada, não o dinheiro — e essa é a
diferença entre um exploit e um atalho sem graça.

Para fechar de vez, existe a allowlist estrita:

```lua
-- config/parkingmeter_server.lua
positions = {
    ['720:-3601:59'] = true,
    -- ...
}
```

Preenchida, ela passa a ser a única palavra. O jeito de levantá-la é o comando
`/dumpmeters`, que imprime no console as chaves de todos os postes em volta,
prontas para colar. Rode por alguns bairros e cole a saída.

### Configuração

`config/parkingmeter.lua` (**enviada ao cliente** — models, grade, durações,
minigame, animações) e `config/parkingmeter_server.lua` (**não enviada** — áreas,
ferramenta, cooldowns, teto, recompensa, dispatch).

Os números que mais mudam o jogo:

| Chave | Onde | Padrão | O que faz |
| --- | --- | --- | --- |
| `maxPerHour` | servidor | `8` | teto por jogador na janela deslizante; é a trava que segura a economia |
| `meterCooldown` | servidor | `1800` s | quanto tempo um poste fica vazio |
| `playerCooldown` | servidor | `45` s | espera entre dois arrombamentos **concluídos** |
| `attemptInterval` | servidor | `1500` ms | anti-spam, cobrado em toda tentativa |
| `reward.money` | servidor | `25`–`90` | é moeda de parquímetro, não pagamento de heist |
| `tool.items` | servidor | `screwdriver` | qualquer um da lista serve; conferido no servidor |
| `gridSize` | shared | `0.5` m | célula da identidade; mudar reseta a memória de postes vazios |
| `skillCheck` | shared | 3 rodadas | `enabled = false` deixa só as barras |

### Duas coisas que este módulo não faz

**Não tem thread.** Nenhuma. O alvo é registrado por model no ox_target, pelo
`bgrz_core`, e todo poste que o streaming carregar já nasce com a opção. O custo
em `resmon` com o jogador parado é zero. Compare com o smash & grab, que precisa
varrer o pool de veículos a cada 1,5 s porque não existe "target por model de
veículo com mochila dentro".

**Não persiste nada.** Sem tabela, sem migration. A memória de postes vazios e o
teto por jogador vivem em RAM e somem no restart — o que, para meia hora de
cooldown, é uma limitação e não um bug. Está listado nas limitações conhecidas.

## Dependências

| Resource    | Para quê                                                       |
| ----------- | -------------------------------------------------------------- |
| `ox_lib`    | `require`, locale, progress, callbacks, `cache`, `lib.print`    |
| `bgrz_core` | **tudo** o mais: notify, itens, dinheiro, dispatch, target, classe |
| OneSync     | state bags de entidade e resolução de netId no servidor          |

O parquímetro não usa OneSync para nada: não há entidade para resolver nem state
bag para escrever. Ele depende só de `ox_lib` e `bgrz_core`.

`ox_target`, `ox_inventory` e `qbx_core` **não** são dependências deste resource e
não são chamados em lugar nenhum dele: toda interação passa pelo `bgrz_core`, e os
providers são dependência dele. É o que o §2.1 e o §6.2 do
`resources/docs/SCRIPT_GOOD_PRACTICES.md` pedem do consumidor.

`bgrz_core` é dependência dura, e de propósito: com o bridge fora do ar o servidor
**recusa** a ação e avisa uma vez no boot, em vez de seguir por um segundo caminho
meio testado.

### Exports acrescentados ao `bgrz_core`

Lacunas do bridge foram preenchidas antes de este resource consumi-las, como manda
o §3.4 ("primeiro ampliar `bgrz_core`, depois consumir"):

| Export                                    | Lado     | Para quê                        |
| ----------------------------------------- | -------- | ------------------------------- |
| `GetItemLabel(item)`                      | servidor | rótulo de item para a notificação |
| `GetVehicleClass(model)`                  | servidor | classe do veículo (só com `classMultipliers`) |
| `AddLocalEntityTarget(entity, options)`   | client   | target em prop local             |
| `RemoveLocalEntityTarget(entity, names)`  | client   | remoção do target do prop        |
| `AddModelTarget(models, options)`         | client   | target em prop de **mapa** (parquímetro) |
| `RemoveModelTarget(models, names)`        | client   | remoção do target por model      |

`AddLocalEntityTarget` existe separado do `AddEntityTarget` genérico por um motivo
concreto: aquele resolve o handle testando `NetworkDoesNetworkIdExist` primeiro, e o
handle de um objeto local pode coincidir com um netId válido de **outra** entidade —
o target iria parar no carro errado.

`AddModelTarget` resolve o problema que nenhuma das duas resolve. Parquímetro é
prop de **mapa**: ninguém o criou, ele não tem netId, não existe no servidor, e o
handle local muda cada vez que o streaming recarrega a região. Não há o que passar
para uma API baseada em entidade. Registrando por model, o alvo vale também para os
postes que entrarem no streaming depois — e o módulo inteiro fica **sem uma única
thread**. Ele normaliza nome e hash para a mesma chave de posse, então
`{ 'prop_parknmeter_01', joaat('prop_parknmeter_01') }` conta como um registro só.

Cada export novo tem teste de sucesso e de falha em `bgrz_core/tests/unit/`.

## Instalação

1. Copie a pasta para `resources/[bgrz]/noir_prettycrimes`.
2. Garanta a ordem de start no `server.cfg`:

```cfg
ensure ox_lib
ensure oxmysql
ensure qbx_core
ensure ox_inventory
ensure ox_target
ensure bgrz_core
ensure noir_prettycrimes
```

3. Ajuste `config/shared.lua`, `config/smashgrab.lua` e `config/parkingmeter.lua`.

Nenhuma migration, nenhuma tabela, nenhum item novo. Todos os itens das tabelas de
saque e a ferramenta do parquímetro (`screwdriver`) já existem no
`ox_inventory` deste servidor.

## Arquitetura

```
noir_prettycrimes/
├── fxmanifest.lua
├── config/
│   ├── shared.lua              comum, ENVIADA ao cliente
│   ├── server.lua              comum, NÃO enviada
│   ├── smashgrab.lua           smash & grab, ENVIADA (prop, assento, janela)
│   ├── smashgrab_server.lua    smash & grab, NÃO enviada (loot, cooldown)
│   ├── parkingmeter.lua        parquímetro, ENVIADA (models, grade, durações)
│   └── parkingmeter_server.lua parquímetro, NÃO enviada (áreas, teto, recompensa)
├── shared/
│   ├── constants.lua           nomes de evento, state bags, lista de crimes
│   ├── utils.lua               DebugPrint, sorteio, validação de tipo
│   ├── smashgrab_rules.lua     formas e nomes: prop, assento, offset
│   └── parkingmeter_rules.lua  identidade do poste: coordenada -> chave de grade
├── client/
│   ├── main.lua                boot: carrega os crimes ligados
│   ├── integrations.lua        único ponto do client que conhece outro resource
│   ├── crimes/smashgrab/
│   │   ├── init.lua            a thread de varredura e o debug
│   │   ├── world.lua           elegibilidade e ciclo de vida do prop
│   │   └── interaction.lua     target no objeto e fluxo do roubo
│   └── crimes/parkingmeter/
│       ├── init.lua            alvo por model, sincronização e debug
│       ├── state.lua           lista local de postes já esvaziados
│       └── interaction.lua     minigame, barras e fluxo do arrombamento
├── server/
│   ├── main.lua                boot + API pública
│   ├── security.lua            rate limit, resolução de entidade, distância
│   ├── integrations.lua        único ponto do servidor que conhece outro resource
│   ├── crimes/smashgrab/
│   │   ├── init.lua            survey / reserve / claim / release, dispatch, debug
│   │   ├── spawn.lua           QUEM tem objeto — decidido e memorizado só aqui
│   │   ├── reservations.lua    máquina de estados do objeto
│   │   └── loot.lua            rolagem e concessão do conteúdo
│   └── crimes/parkingmeter/
│       ├── init.lua            sync / reserve / claim / release, dispatch, debug
│       ├── registry.lua        poste vazio, cooldown e teto por jogador
│       ├── sessions.lua        máquina de estados do arrombamento
│       └── loot.lua            rolagem e concessão do conteúdo
├── tests/
│   ├── testlib.lua             harness: require, relógio, natives
│   └── unit/                   os módulos puros, em Lua puro
└── locales/
```

Um crime pode ser um arquivo (`crimes/<id>.lua`) ou uma pasta
(`crimes/<id>/init.lua`). O carregador aceita os dois; o smashgrab virou pasta
quando passou de umas 200 linhas por lado.

Três regras sustentam o resto:

**`main.lua` não sabe o que nenhum crime faz.** Ele lê a config, carrega os módulos
ligados e os para no stop. Se você se pegar escrevendo `if crime == 'smashgrab'`
dentro de um `main.lua`, algo foi para o lugar errado.

**Crime desligado não é crime carregado.** `smashgrab = false` não quer dizer
"carrega e fica quieto": o `require` não acontece, o arquivo não é lido, nenhum
target é registrado e nenhum evento passa a existir. Isso vale para os dois lados.

**Ninguém fala com outro resource fora de `integrations.lua`.** Trocar notificação,
inventário, dispatch ou framework é mexer em um arquivo por lado. `exports.<algo>`
dentro de `client/crimes/` ou `server/crimes/` é sinal de wrapper faltando.

### Módulos de servidor não são enviados ao cliente

O `require` do ox_lib lê por `LoadResourceFile`, então **todo módulo que o client
carrega precisa estar em `files{}`**. Repare no que não está lá: nada de `server/`.
Listar a pasta do servidor mandaria as tabelas de saque e a lógica de validação
para dentro do cliente. Ao criar um crime novo, acrescente só o módulo de client.

## Como o spawn funciona

Nem todo carro tem objeto — o padrão é 12%. **Quem decide é o servidor, e só ele.**

```
client varre o pool de veículos que já tem carregado
        ↓
filtra por distância (80m) e elegibilidade
        ↓
junta os netIds que ainda não têm resposta — no máximo 40 por vez
        ↓
UMA consulta ao servidor por varredura
        ↓
servidor confere, para CADA netId:  existe? é veículo?
                                     está a menos de 100m de QUEM PERGUNTOU?
                                     é elegível?
        ↓
responde TRÊS coisas diferentes por netId:
    objeto   -> tem isto aqui
    false    -> decidido: não tem nada
    ausente  -> não deu para responder agora (longe, andando, ocupado)
        ↓
client desenha o primeiro, memoriza os dois primeiros, e volta a perguntar
o terceiro na varredura seguinte
```

A distinção entre `false` e ausente não é preciosismo: sem ela, uma recusa
temporária viraria "esse carro não tem nada" memorizado até ele sair dos 120 m.

A checagem de distância é o ponto inteiro. Sem ela, um client adulterado enumeraria
netIds de 1 a 65535 e receberia o mapa completo de maletas sem sair de casa. Com
ela, a resposta só sai sobre o que o jogador já teria como enxergar de qualquer
jeito — e o prop renderiza a 60m para todo mundo.

A decisão de cada veículo é tomada **uma vez** e guardada em
`server/crimes/smashgrab/spawn.lua`. Dois jogadores que perguntam sobre o mesmo
carro recebem a mesma coisa porque leem o mesmo registro, não porque recalculam.
O registro guarda a placa junto: netId é reciclado pelo jogo, e placa diferente
significa outro carro, então a decisão é refeita em vez de o prop de um Sultan
reaparecer dentro de um Blista.

O client **não tem como calcular nem adivinhar** — não existe fórmula nem semente
do lado dele. Sem resposta do servidor, não há prop.

### Custo

Medido com os números da config, não estimado no olho:

| Cenário | netIds por consulta | Sobe | Desce |
| --- | --- | --- | --- |
| a pé | 1–2 | 18 B | 15 B |
| correndo | 2–8 | 58 B | 42 B |
| dirigindo a 20 m/s | 27–107 (cortado em 40) | 158 B | 109 B |

Agregado com 64 jogadores: **cerca de 2 KB/s** e algumas centenas de resoluções de
entidade por segundo. Uma consulta por varredura, no máximo, e só com netIds que
ainda não têm resposta: carro já respondido nunca é perguntado de novo enquanto
estiver por perto.

A versão anterior era determinística (semente de salt + placa + modelo) e custava
zero rede, mas exigia publicar o salt em `GlobalState` — e com o salt um client
adulterado enumerava o mapa inteiro antes de sair de casa. A troca foi deliberada:
2 KB/s por fechar o ESP de localização.

## Configuração

A config é dividida por **sigilo**, não por conveniência. O que está em `files{}`
é enviado ao jogador; o resto nunca sai do servidor (§19.1).

| Arquivo                     | Enviado? | Contém                                    |
| --------------------------- | -------- | ----------------------------------------- |
| `config/shared.lua`         | sim      | `debug`, `crimes`                         |
| `config/server.lua`         | **não**  | `debugAce`, `rateLimit`, `limits`, `dispatch`, `progression` |
| `config/smashgrab.lua`      | sim      | prop, assento, janela, distâncias, animações        |
| `config/smashgrab_server.lua` | **não** | `spawnChance`, `classMultipliers`, `lootTables`, `alarm`, `playerCooldown`, `reservationTimeout`, `minElapsedFactor`, `breakCooldown`, `dispatch`, `witnesses` |

O client precisa de prop/assento/janela para desenhar o objeto — isso não é segredo,
está pendurado no banco de trás à vista de todos. O que vem **dentro** do objeto ele
descobre quando o servidor entrega.

### `config/smashgrab.lua`

**Toda chance nos arquivos de smash & grab é fração de 0 a 1.** `0.12` é doze por cento. Os
`weight` e os `chance` das loot tables é que são relativos (veja abaixo). O sketch
original misturava `0.12` com `AlarmChance = 65`; normalizar evita o erro de uma
casa decimal que ninguém percebe até o loot sair dez vezes demais.

| Bloco                | O que controla                                           |
| -------------------- | -------------------------------------------------------- |
| `spawnChance`        | fração dos carros elegíveis que carregam objeto           |
| `scanInterval`       | intervalo da varredura — **é o custo do sistema inteiro** |
| `activationDistance` / `renderDistance` / `cleanupDistance` | avaliar / criar / destruir |
| `maxDistance`        | alcance do roubo, no client e no servidor                 |
| `eligibility`        | quem pode receber objeto (veja abaixo)                    |
| `props`              | os objetos, com peso, rótulo e loot table                 |
| `seats`              | posição, osso, **janela correspondente** e peso           |
| `vehicleOffsets`     | override de offset por modelo                             |
| `breakDuration` / `breakAnim` | a animação de quebrar o vidro                    |
| `duration` / `anim`  | a animação de alcançar o interior                         |
| `playerCooldown`     | espera entre dois roubos do mesmo jogador                 |
| `reservationTimeout` | quanto tempo uma reserva sobrevive sem confirmação        |
| `alarm`              | chance e duração do alarme                                |
| `dispatch`           | chance, código e **gatilho** do alerta                    |
| `witnesses`          | gancho de testemunhas (desligado)                         |
| `classMultipliers`   | multiplicadores por classe (desligado)                    |
| `lootTables`         | o que vem dentro — **lido só no servidor**                |

### Animações

Uma por gesto:

| Gesto | Dicionário | Clip | Duração |
| --- | --- | --- | --- |
| Quebrar vidro | `veh@break_in@0h@p_m_two@` | `low_force_entry_ds` | 5 s |
| Roubar objeto | `mp_car_bomb` | `car_bomb_mechanic` | 3 s |

Dicionário que não existe no build do Enhanced derruba o cliente na thread de
render, e o `lib.requestAnimDict` da progress estoura antes disso. O módulo confere
com `DoesAnimDictExist` **por dicionário** — são dois, e um cache só para os dois
deixaria o segundo sem validação — e roda a barra sem animação quando falta,
deixando um aviso no console.

As duas falhas possíveis têm sintomas diferentes, e vale saber qual você está vendo:

* **dicionário ausente** → aviso no console, progress roda sem animação;
* **clip errado num dicionário que existe** → silêncio total: a barra roda, o
  personagem não faz nada, e nada é logado.

`mp_car_bomb` está em produção no `qbx_vineyard` e no `qbx_recyclejob` daqui.
`veh@break_in@0h@p_m_one@` (com **"one"**) está em quatro resources —
`qbx_storerobbery`, `qbx_houserobbery`, `noir_houserobbery` e `qbx_vehiclekeys` —
com os clips `low_force_entry_ds` e `std_force_entry_rds`. A variante `p_m_two@`
configurada acima não aparece em nenhum deles: é a única parte não verificada neste
build. Se o personagem ficar parado durante os 5 s, troque para `p_m_one`.

### Elegibilidade

Só recebem objeto: veículos de NPC, desocupados, parados, inteiros e que não sejam
de jogador.

| Filtro                                   | Onde é conferido    |
| ---------------------------------------- | ------------------- |
| `allowedTypes` (automobile)              | servidor            |
| `vehicleClassBlacklist` (moto, bici, barco, avião, helicóptero, emergência, militar, trem) | client |
| `vehicleModelBlacklist` (viatura, ambulância, bombeiro, ônibus, lixo…) | client **e** servidor |
| `blockOccupied` — jogador dentro         | client **e** servidor |
| `blockOccupied` — NPC dentro             | client              |
| `blockMoving`, `blockDestroyed`          | client **e** servidor |
| `blockPlayerOwned` (`persisted`, `vehicleid`) | client **e** servidor |

Classe e NPC ficam só no client porque o servidor não os enxerga — `GetVehicleClass`
não existe lá e ped de ambiente não é entidade de servidor. O que importa para
exploit está dos dois lados.

**Veículo persistente / de jogador:** a checagem lê as state bags que o Qbox já
marca (`persisted`, replicada; `vehicleid`, do servidor). Outro sistema de
propriedade entra acrescentando a chave dele em `eligibility.ownedStateBags` — sem
tocar em código.

### Props

Os seis modelos padrão foram conferidos contra a lista de objetos do `ps_lib`
(`modules/streamed_assets/shared/objectList.lua`), que é um dump real do jogo.

| Prop                     | Raridade | Loot table    |
| ------------------------ | -------- | ------------- |
| `prop_cs_shopping_bag`   | comum    | `cheap`       |
| `prop_michael_backpack`  | comum    | `common`      |
| `prop_amb_handbag_01`    | médio    | `common`      |
| `prop_cs_cardbox_01`     | médio    | `variable`    |
| `prop_laptop_01a`        | raro     | `electronics` |
| `prop_ld_case_01`        | raro     | `valuable`    |

Ao acrescentar um prop, confira o nome naquela lista antes. **Modelo que não existe
no build do Enhanced derruba o cliente na thread de render, sem erro de script.** O
módulo ainda valida com `IsModelValid` + `IsModelInCdimage` no start e recusa o que
faltar — mas o cinto não substitui olhar.

Um prop inválido sai do **desenho**, não do **sorteio**: tirá-lo do sorteio faria
client e servidor discordarem. O que se perde é o visual daquele objeto.

### Posição e janela

Cada posição amarra três coisas: o osso onde o prop gruda, a **janela que precisa
estar quebrada**, e o peso do sorteio.

| Posição          | Osso            | Janela | Índice |
| ---------------- | --------------- | ------ | ------ |
| `passengerFront` | `seat_pside_f`  | dianteira direita | 1 |
| `passengerFloor` | `seat_pside_f`  | dianteira direita | 1 |
| `rearLeft`       | `seat_dside_r`  | traseira esquerda | 2 |
| `rearRight`      | `seat_pside_r`  | traseira direita  | 3 |

`dside` é o lado do motorista (esquerda), `pside` o do passageiro (direita). São os
nomes padrão do GTA — os mesmos que o próprio `ox_target` usa nas opções de
assento. O banco do motorista fica de fora: é por onde o dono entra, e objeto
largado ali não passa a leitura de "esqueceram no carro".

O prop é **anexado ao osso** com `AttachEntityToEntity`, então acompanha o carro
sozinho, inclusive se alguém sair dirigindo. Não há atualização de posição por
frame em lugar nenhum.

Offsets não caem bem em todo modelo. `vehicleOffsets` sobrescreve por modelo e
posição; sem override, o padrão foi ajustado para carro comum de quatro portas.

### Loot tables

`rolls` é quantos sorteios. Cada sorteio escolhe **uma** entrada, com `chance`
valendo como peso em 100 — e se as chances somam menos de 100, **a diferença é a
chance daquele sorteio sair vazio**. É assim que se afina "quase sempre vem pouca
coisa" sem inventar outro campo.

```lua
common = {
    rolls = { min = 1, max = 2 },
    items = {
        { money = 'cash', min = 20, max = 110, chance = 28 },
        { item = 'phone',  min = 1, max = 1,   chance = 16 },
        -- ... soma 86: 14% de cada sorteio sair vazio
    },
},
```

`money = 'cash'|'bank'` entrega dinheiro; `item = '<nome>'` entrega item. Os 18
itens usados existem no `ox_inventory` deste servidor. O sketch original pedia
`cash` e `headphones`: **nenhum dos dois existe aqui**, então viraram `money` e
eletrônicos reais (`phone`, `tablet`, `laptop`, `burner_phone`, `cryptostick`).

Item que não cabe na mochila não é concedido — e também não aparece na
notificação. O jogador nunca lê que pegou algo que não recebeu.

## Sincronização e loot duplicado

O objeto tem três estados, e a transição é sempre do servidor:

```
available ──reserve──> reserved ──claim──> claimed
    ^                      │               (final)
    └──── release ─────────┘
           (ou expiração)
```

Duas verdades, de propósito:

* **a tabela em memória do servidor é a autoridade** — é ela que decide quem pode;
* **a state bag da entidade é a fachada** — é o que os clients leem para apagar o
  prop e esconder o alvo.

A state bag sozinha não serviria como autoridade (é replicada, e o servidor escreve
nela de forma assíncrona do ponto de vista dos clients). A tabela sozinha não
serviria como fachada (ninguém a enxerga).

**O que impede dois jogadores de levarem a mesma mochila:** `reserve` lê e escreve
sem ceder a thread. Entre a checagem e a marcação não existe janela. Lua de
servidor é um fio só; a atomicidade vem daí.

O jogador B que chega depois recebe `reserved` e a opção some do target dele. Se A
cancela, `release` devolve na hora. Se A desconecta, `playerDropped` solta tudo que
ele segurava. Se A trava, a reserva expira — e a expiração **limpa a state bag**, não só a
tabela. Isso é o que impede o pior caso: o client esconde os dois alvos enquanto a
bag não for nil, então uma reserva que morresse sem limpar deixaria o objeto
visível e intocável, sem ninguém para notar a expiração preguiçosa. Um timer
agendado na reserva garante que a trava caia mesmo que ninguém pergunte.

Quando o objeto é levado, a state bag vira `claimed` e um `AddStateBagChangeHandler`
apaga o prop **na hora** em todos os clients por perto. A varredura também cobre
isso, mas só no ciclo seguinte — e "o outro jogador continuou vendo a mochila por
um segundo e meio" é exatamente o que não pode acontecer.

## Segurança

O client pede; o servidor decide. O pedido carrega **netId, propKey e seatKey** — e
as duas últimas não são aceitas, só comparadas: o servidor recomputa o objeto
daquele carro pela semente e recusa se não bater.

| Situação                                | Como é pego                          |
| --------------------------------------- | ------------------------------------ |
| spam de evento                          | `Security.rateLimit`, por jogador    |
| jogador inválido / desconectado         | `Security.isValidPlayer`             |
| netId inexistente, negativo ou `nil`    | `Security.resolveEntity`             |
| entidade que não é veículo              | `GetEntityType`                      |
| fora de distância                       | coordenadas **do servidor**          |
| carro sem objeto                        | recomputa a semente → `no_loot`      |
| pedir um objeto que não é aquele        | recomputa a semente → `mismatch`     |
| `claim` sem `reserve`                   | a reserva é conferida antes de tudo  |
| `claim` duas vezes                      | `claimed` é final                    |
| carro inelegível (viatura, de jogador, em movimento, destruído, ocupado) | revalidado em cada pedido |
| `bgrz_core` fora do ar | conferido na reserva **e** antes de fechar o claim |

Três coisas valem ser ditas por extenso:

**O cooldown é cobrado no pedido, não no sucesso.** Pedido recusado também custa
espera — senão a recusa vira o caminho barato para martelar o servidor.

**Cada pedido revalida o mundo do zero.** `claim` não confia no que `reserve` viu:
entre um e outro o carro pode ter sumido, andado ou virado veículo de alguém.

**A reserva fecha antes da concessão.** `claimed` é marcado e só depois o loot rola
e é entregue.

## Performance

| | |
| --- | --- |
| threads em produção | **1** (a varredura) |
| `Wait(0)` em produção | **nenhum** |
| eventos de rede por veículo | **0** |
| entidades de servidor criadas | **0** |
| targets registrados | 1 por prop na tela |

A varredura **roda também dentro do veículo**: procurar carro estacionado enquanto
se roda a cidade é o loop natural deste crime, e desligá-la ali deixava o sistema
inerte justamente na hora da caça. O backoff é por **região vazia** (nenhum veículo
ao alcance na última varredura), não por estar dirigindo.

A varredura é um passo a cada `scanInterval` (1,5 s): pega o pool de veículos que o
client **já tem carregado**, filtra por distância, limpa o que saiu e considera o
que entrou. Não existe varredura por frame, não existe thread por veículo, não
existe target em todos os carros do mapa, e nenhum prop é criado antecipadamente.

Os props são objetos **locais e não networked**: cada client desenha o seu. É o que
torna o sistema barato — nenhuma entidade de servidor, nenhuma replicação de prop.
A consistência vem da decisão determinística, não da rede.

A avaliação de cada veículo fica em cache junto com a placa; handle de entidade é
reciclado pelo jogo, e a placa é o que detecta que o handle virou outro carro.

O único `Wait(0)` do resource está no overlay de debug, que só existe com
`Config.debug` ligado e só roda depois de `/smashdebug`.

## Cleanup

O prop é destruído quando o veículo some, sai de `cleanupDistance`, deixa de ser
elegível (alguém entrou, saiu dirigindo), o objeto é levado, ou o resource para.

### Apagar o prop: três coisas têm que estar certas

Custou dois crashes em produção (`exception at game RVA 0x1918`) chegar nisto:

1. **Soltar do osso antes.** `DetachEntity` e só então apagar — o jogo não gosta de
   destruir objeto com o vínculo de anexo de pé. Mesma ordem do `noir_graffiti`.
2. **`DeleteObject`, não `DeleteEntity`.** O prop é um CObject e este é o native
   dele; o genérico estoura. É o que o `sd-phone` usa para os props locais que
   sincroniza por state bag, e o que 47 arquivos deste servidor usam para objeto.
3. **Fora do handler de state bag.** O handler roda por `CreateThreadNow`, dentro
   do processamento do próprio state bag; destruir entidade ali reentra na gestão
   de entidades do jogo no meio dela. O `SetTimeout(0)` joga o trabalho para o tick
   seguinte do scheduler — imperceptível para o jogador, e fora daquele contexto.

Os três têm teste. O harness levanta erro se `DeleteEntity` for chamado num prop, e
há teste verificando que o handler **não** apaga nada de forma síncrona, só
enfileira.

`World.stop()` apaga todo prop rastreado — e é chamado pelo `client/main.lua` no
stop do resource, então restart não deixa mochila órfã pelo mapa. Do lado do
servidor, uma limpeza a cada 5 minutos descarta netIds de carros que já não
existem, para a tabela não crescer em uptime longo.

## Alarme e dispatch

**Alarme:** quando o servidor autoriza a quebra, ele rola `alarm.chance` e manda a
duração junto no evento. O alarme é o nativo do veículo (`SetVehicleAlarm` +
`SetVehicleAlarmTimeLeft`, o par que o `qbx_vehiclekeys` usa em produção aqui);
nenhum som artificial.

Quem aplica é o **dono de rede** do veículo, porque `SmashVehicleWindow` só replica
a partir dele — o servidor manda o recado direto para o dono em vez de pedir ao
ladrão que dispute o controle da entidade. Em troca, não existe disputa de controle
em lugar nenhum deste resource, e o alarme sai junto com o estouro para todo mundo
por perto, decidido uma vez só.

A configuração do alarme mora no config **server-only**: o client não lê nada dela,
só recebe a duração já decidida.

**Dispatch:** sai do servidor, por `DispatchSmashGrab` →
`Integrations.dispatch` → `bgrz_core:SendDispatch`. Nada chama provider direto, e
trocar de dispatch é mexer no wrapper.

O gatilho é configurável: `'reserved'` (padrão — o momento em que o jogador enfia o
braço), `'claimed'` ou `'both'`. **Quebrar o vidro não é gatilho**, de propósito: o
servidor não tem como verificar o estado do vidro, e um gatilho que o client dispara
sozinho vira spam de polícia. O alarme, que é local e não custa nada a ninguém,
cobre esse momento da cena.

**Testemunhas:** a estrutura existe e está desligada. Ligada,
`witnessMultiplier(context)` multiplica a chance de dispatch pelo número de NPCs que
viram. Quem for preencher precisa resolver a contagem **no servidor** — contagem
mandada pelo client é palpite do client, e viraria mais um número para forjar.

## Multiplicadores por classe

Desligados por padrão. Ligados, a classe entra na semente do spawn — e aí o
servidor também precisa saber a classe para validar, o que ele resolve por
`qbx_core:GetVehicleClass` (um cache que o core monta perguntando a um cliente).
Funciona, mas é uma dependência a mais no caminho da validação; com
`enabled = false` nada disso é tocado. `classMultipliers.loot` multiplica só o
dinheiro e roda só no servidor.

## Eventos públicos

Namespace `noir_prettycrimes:<side>:<crime>:<action>`, montado por
`Constants.event()`. Os três são callbacks do `ox_lib`:

| Evento                                       | Carga                      |
| -------------------------------------------- | -------------------------- |
| `noir_prettycrimes:server:smashgrab:survey`  | `netId[]` (máx. 40)        |
| `noir_prettycrimes:server:smashgrab:break`   | `netId`                    |
| `noir_prettycrimes:server:smashgrab:reserve` | `netId, propKey, seatKey`  |
| `noir_prettycrimes:server:smashgrab:claim`   | `netId`                    |
| `noir_prettycrimes:server:smashgrab:release` | `netId`                    |
| `noir_prettycrimes:server:parkingmeter:sync`    | — (devolve `key -> ms`)    |
| `noir_prettycrimes:server:parkingmeter:reserve` | `coords, model`            |
| `noir_prettycrimes:server:parkingmeter:claim`   | `coords, model`            |
| `noir_prettycrimes:server:parkingmeter:release` | `coords`                   |

Mais um evento de servidor para client, que não é callback:

| Evento                                          | Carga                      |
| ----------------------------------------------- | -------------------------- |
| `noir_prettycrimes:client:parkingmeter:emptied` | `key, ms` (broadcast, `-1`) |

Ele existe porque prop de mapa não tem state bag: não há entidade em que publicar
"este poste está vazio" para os clients lerem. O broadcast é o substituto, e o
payload é uma chave curta mais uma duração — informação pública de qualquer jeito,
já que quem passa na calçada vê a portinhola arrombada.

## Exports públicos

```lua
exports.noir_prettycrimes:IsCrimeEnabled('smashgrab')  --> boolean
exports.noir_prettycrimes:GetLoadedCrimes()            --> { 'parkingmeter', 'smashgrab' }
```

## State bags

Escritas **sempre** pelo servidor, com replicação ligada; o client só lê.

| Chave           | Onde    | Conteúdo                                              |
| --------------- | ------- | ----------------------------------------------------- |
| `noirSmashGrab` | veículo | `nil` disponível / `'reserved'` / `'claimed'` (escalar) |

O parquímetro **não aparece nesta tabela**, e a ausência é o ponto: prop de mapa
não é uma entidade em que se possa pendurar state bag. O estado equivalente viaja
como evento (veja acima) e vive numa tabela local em cada client, que não é
autoridade nenhuma — um client que a apagasse inteira só conseguiria ver alvos que
o servidor recusaria.

Não há `GlobalState` nenhum: a decisão de spawn não é publicada para o client em
lugar nenhum — ele só recebe resposta sobre veículos que já tem por perto.

Repare no que **não** está no payload do veículo: quem reservou. Essa informação
fica na tabela do servidor, porque state bag de entidade é pública para todo mundo
que estiver com a entidade carregada.

## Debug

```lua
Config.debug = true
```

| Comando             | Lado     | O que faz                                              |
| ------------------- | -------- | ------------------------------------------------------ |
| `/smashdebug`       | client   | overlay sobre cada objeto: prop, banco, netId, janela (INTEIRO/QUEBRADO) e estado |
| `/smashinfo`        | client   | explica o carro que você está mirando: elegível? por que não? tem objeto? qual? |
| `/spawnsmashloot`   | servidor | força objeto no veículo mais próximo                   |
| `/smashstate`       | servidor | quantos objetos reservados e levados                   |
| `/meterinfo`        | client   | a chave do poste mais próximo e por que ele está ou não disponível |
| `/meterstate`       | servidor | postes vazios, reservas e o teto do jogador que chamou |
| `/meterdiag`        | servidor | em qual elo a cadeia quebrou (nao depende de `Config.debug`) |
| `/meterreset`       | servidor | devolve as moedas a todos os postes esvaziados         |

Os comandos do servidor ficam atrás de `debugAce` além do `debug`.

**`/dumpmeters [raio]` é a exceção, e não depende de `Config.debug`.** Ele é
ferramenta de setup, não de debug: quem precisa dele precisa num servidor de
produção, e amarrá-lo à flag obrigava a ligar o debug inteiro — que também libera
comando de client para qualquer jogador — só para levantar uma lista. É comando
de servidor, atrás de `debugAce`, e só manda o evento de coleta para quem passou:

```
/dumpmeters 150
```

As chaves saem no **F8 de quem chamou**, prontas para colar em `positions`.

**`/meterdiag` segue a mesma regra** e responde a única pergunta que importa
quando o alvo não aparece: em qual elo a cadeia quebrou.

```
/meterdiag
```

O módulo tem cinco dependências em série — `bgrz_core` de pé, export presente,
`ox_target` de pé, alvo registrado, personagem carregado — e quando qualquer uma
falha o sintoma é o mesmo: nada acontece ao mirar o poste. O comando imprime o
estado de cada elo no F8 de quem chamou, a parte de servidor (área, teto,
ferramenta, reservas) no console do servidor, e fecha com um veredito apontando
o **primeiro** elo quebrado — os seguintes são consequência.

O caso mais comum de longe: `export AddModelTarget: AUSENTE`, que quer dizer
`restart bgrz_core` antes de `restart noir_prettycrimes`. Acontece em toda
atualização em que só o consumidor é reiniciado.

`/spawnsmashloot` não é um atalho que mente: ele escreve a placa numa lista que os
**dois lados** leem, então o objeto forçado é tão real quanto o sorteado — inclusive
passando pela mesma validação na entrega.

`/smashinfo` é o comando que responde "por que esse carro nunca tem nada": ele
imprime o motivo exato da recusa (`class`, `model`, `occupied`, `moving`,
`destroyed`, `player_owned`, `not_networked`) ou, se for elegível, se a rolagem de
spawn passou.

## Como adicionar um petty crime

Exemplo com `vendingmachine`. O `parkingmeter` foi acrescentado seguindo
exatamente estes passos, e serve de modelo pronto para copiar.

1. **Registre o id** em `shared/constants.lua`, movendo-o de `plannedCrimes` para
   `crimes`. É a allowlist que separa "ainda não existe" de "você digitou errado".

2. **Crie `config/vendingmachine.lua`**, devolvendo uma tabela. Se houver
   recompensa, limite ou regra anti-exploit, eles vão num
   `config/vendingmachine_server.lua` separado, que **não** entra em `files{}`.

3. **Crie `server/crimes/vendingmachine.lua`** (ou uma pasta com `init.lua`)
   devolvendo `{ start, onPlayerDropped? }`. Reuse `server/security.lua` para rate
   limit, resolução de entidade e distância, e `server/integrations.lua` para
   qualquer coisa que venha de fora.

4. **Crie `client/crimes/vendingmachine.lua`** devolvendo `{ start, stop }`.

5. **Liste os módulos de client em `files{}`** — e **não liste os de servidor**.

6. **Ligue em `config/shared.lua`**: `vendingmachine = true`.

7. **Rode os testes**: `lua tests/unit/manifest_spec.lua` confere os passos 1, 5 e
   6 e, principalmente, que nenhum config de servidor vazou para o cliente.

| Função               | Lado     | Quando                        |
| -------------------- | -------- | ----------------------------- |
| `start()`            | ambos    | obrigatória; no boot          |
| `stop()`             | client   | opcional; no stop do resource |
| `onPlayerDropped(s)` | servidor | opcional; ao desconectar      |

`Security.forget` já limpa o rate limit de quem sai; `onPlayerDropped` é para o
estado que for **seu**.

## Testes

```bash
cd resources/[bgrz]/noir_prettycrimes
for spec in tests/unit/*_spec.lua; do lua "$spec" || exit 1; done
```

Roda em Lua puro, sem servidor: `tests/testlib.lua` substitui o `require` do
ox_lib, `os.time` e `GetGameTimer`, então cooldown de meia hora e teto por hora
são testados movendo o relógio em vez de esperando.

- `parkingmeter_rules_spec`: identidade do poste — allowlist de model,
  arredondamento simétrico da grade, distância horizontal, áreas, e a coerência
  entre o config do client e o do servidor;
- `parkingmeter_registry_spec`: cooldown do poste, cooldown do jogador e janela
  deslizante do teto, incluindo a volta do jogador quando a janela desliza;
- `parkingmeter_sessions_spec`: dois jogadores no mesmo poste, um jogador em dois
  postes, entrega instantânea, entrega repetida, entrega alheia e expiração;
- `manifest_spec`: o contrato entre `Config.crimes`, `Constants` e o
  `fxmanifest` — e, principalmente, que nenhum `*_server.lua` está em `files{}`.

Os exports novos do bridge ficam do lado de lá:

```bash
cd resources/[bgrz]/bgrz_core
for spec in tests/unit/*_spec.lua; do lua "$spec" || exit 1; done
```

### Testando em jogo

Ligue `Config.debug = true` em `config/shared.lua` e reinicie o resource. Sem
isso nenhum comando de debug existe e nenhum `DebugPrint` sai.

```
restart noir_prettycrimes
```

1. **Ache um poste.** Vá a Legion Square, Del Perro ou Vinewood e rode
   `/dumpmeters 100` (funciona sem `Config.debug`, atrás de `debugAce`). Ele
   lista no seu F8 os parquímetros em volta com a chave de cada um. Zero
   resultados quer dizer que você não está numa área com postes.
2. **Pegue a ferramenta**: `/giveitem <id> screwdriver 1`.
3. **Mire e arrombe.** O alvo só aparece a pé, vivo e logado.
4. **Confirme que o servidor decidiu**, não o client: `/meterstate` mostra
   postes vazios, reservas e quantos você já fez na janela.

O que vale a pena quebrar de propósito:

| Cenário | Como | O que tem que acontecer |
| --- | --- | --- |
| poste já esvaziado | arrombe duas vezes seguidas | o alvo some para todo mundo por 30 min |
| sem ferramenta | `/removeitem <id> screwdriver 1` e tente | recusa **do servidor**, não sumiço do alvo |
| longe demais | ande para trás no meio da barra | a barra cancela e o poste é devolvido |
| dois jogadores | dois clients no mesmo poste | o segundo leva `pm_reason_reserved` antes de qualquer animação |
| teto por hora | 9 postes seguidos (baixe `playerCooldown` para testar) | o nono recusa com `pm_reason_too_much_heat` |
| desconexão no meio | alt-F4 durante a barra | o poste volta na hora, sem esperar o timeout |
| bridge fora do ar | `stop bgrz_core` | recusa limpa, sem erro no console |
| `/meterreset` | depois de esvaziar vários | todos voltam a ter moedas na hora, em todos os clients |

`/meterinfo` responde "por que esse não dá para arrombar" pelo que o **client**
sabe. Ele não sabe tudo de propósito: área, teto e ferramenta são do servidor, e
aparecem no console dele com `Config.debug` ligado.

## Progressão criminal (opcional)

`Config.progression.enabled = false` por padrão. Ligar exige, antes:

1. registrar `noir_prettycrimes` em `noir_illegal_core/shared/permissions.lua`
   (`publicRecorders`);
2. declarar a activity `petty_smashgrab` nas activities de lá, com este resource na
   lista de callers.

Sem isso o core recusa a chamada, e a recusa é silenciosa para o jogador. Com
`Config.debug` ligado, o motivo aparece no console.

## Limitações conhecidas

* **NPC dentro do carro só é visto pelo client.** O servidor não enxerga ped de
  ambiente. Um carro com NPC dentro não recebe prop, mas se um NPC entrar depois, a
  entrega não vai recusar por isso. Jogador dentro é conferido dos dois lados.
* **Quebrar o vidro não gera dispatch.** O servidor não consegue verificar o estado
  do vidro, e um gatilho que o client dispara sozinho vira spam de polícia.
* **O prop some se alguém entrar no carro ou sair dirigindo.** É deliberado: o
  servidor recusaria a entrega nesse estado, e um prop visível mas inpegável seria
  pior que o prop sumir.
* **O restart re-sorteia o mapa de objetos.** A tabela de decisões vive em memória
  do servidor e não é persistida.
* **A consulta custa um round-trip.** Um carro que entra no raio aparece na
  varredura seguinte, não instantaneamente. Com `scanInterval` de 1,5 s isso é
  imperceptível a pé; dirigindo, os props entram um pouco atrás do jogador.

Do parquímetro:

* **O servidor não vê o poste.** Ele valida a posição do jogador, a área e o teto
  por hora, mas não consegue confirmar que existe um parquímetro na coordenada.
  Quem está numa rua com postes pode inventar coordenadas vizinhas; o teto por
  hora é o que torna isso irrelevante. A allowlist `positions` fecha de vez.
* **O restart esquece quais postes estavam vazios.** A memória vive em RAM. Depois
  de um restart, todos os postes voltam a ter moedas — inclusive os arrombados
  cinco minutos antes.
* **O restart também zera o teto por hora.** Pela mesma razão. Num servidor que
  reinicia de hora em hora, o teto vale menos do que o número sugere.
* **Não há nada a ver num poste arrombado.** O parquímetro não tem estado visual:
  um poste vazio é idêntico a um cheio. O jogador descobre pela ausência do alvo,
  não pelo prop.
* **Dois jogadores no mesmo poste só descobrem ao tentar.** Sem state bag, não há
  como esconder o alvo de um poste que outro acabou de reservar. A recusa chega no
  primeiro round-trip, antes de qualquer animação, então o custo é um aviso.
* **As áreas são grossas.** As esferas de `areas` cobrem a cidade por bairro, não
  por calçada. Um poste dentro de um MLO na borda de uma esfera pode ficar de fora,
  e um lugar sem poste dentro dela fica dentro.

## Conformidade com `SCRIPT_GOOD_PRACTICES.md`

Auditado contra `resources/docs/SCRIPT_GOOD_PRACTICES.md`.

| Seção | Como é atendida |
| --- | --- |
| §2.1 ponte obrigatória | nenhuma chamada a `qbx_core`, `ox_target` ou `ox_inventory`; tudo pelo `bgrz_core` |
| §3.4 lacunas do bridge | 6 exports acrescentados ao `bgrz_core`, com teste, antes de serem consumidos |
| §5.5 / §19.1 config | dividida por sigilo; loot e rate limit fora de `files{}` |
| §6.2 manifest | sem `lua54`, sem provider nas dependências |
| §7 autoridade | client manda netId/coordenada + intenção; o servidor decide tudo, spawn e recompensa incluídos |
| §7.5 rate limit | por jogador e ação, cobrado no pedido, limpo no `playerDropped` |
| §7.6 idempotência | `claimed` é final; `claim` repetido devolve `already_taken` |
| §8.2 namespace | `noir_prettycrimes:<side>:<crime>:<action>` |
| §8.5 callbacks | sempre respondem envelope `{ ok, code }` |
| §9 sessão | `available → reserved → claimed` com TTL e expiração na leitura, nos dois crimes |
| §9.4 fonte do tempo | `GetGameTimer` para reserva e rate limit; `os.time` para cooldown de poste e teto por hora |
| §11.2 state bag rasa | valor escalar (`'reserved'` / `'claimed'`), nunca tabela |
| §11.3 autoridade | a tabela do servidor decide; a state bag é fachada |
| §13.1 lock antes do await | `reserve` marca sem ceder a thread |
| §14.1–14.3 loops | smash & grab: 1 thread com sleep adaptativo. Parquímetro: **nenhuma thread** |
| §17.1 models | `IsModelValid` + `IsModelInCdimage` + `lib.requestModel` com timeout |
| §17.4 animações | o servidor **mede** o tempo decorrido; não aceita "acabou" do client |
| §20.1 envelope | `code` estável, texto localizado |
| §20.3 logs | `lib.print` com nível, nenhum `print` solto |
| §21.2 stop | `World.stop()` apaga todo prop; nada órfão |
| §12.6 identidade | o teto e o cooldown do parquímetro são por `citizenId`; `source` nunca é identidade |
| §22 testabilidade | regras, registry e sessões rodam em Lua puro: `lua tests/unit/<spec>.lua` |

### §18.4 — decisão de spawn no servidor

Resolvido. A versão anterior publicava o salt do sorteio determinístico em
`GlobalState`, o que permitia a um client adulterado calcular onde estavam as
maletas no mapa inteiro. Hoje o client não tem fórmula nem semente: ele pergunta, e
o servidor só responde sobre veículos a menos de 100 m de quem perguntou.

Custou cerca de 2 KB/s agregados com 64 jogadores, uma tabela de decisões no
servidor (podada junto com as reservas, a cada 5 min, só para entidades que já não
existem) e um caminho de falha novo — consulta sem resposta não memoriza nada e o
veículo volta na varredura seguinte, em vez de o prop aparecer errado.
