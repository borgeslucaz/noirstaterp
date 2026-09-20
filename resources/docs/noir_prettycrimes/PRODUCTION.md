# noir_prettycrimes — checklist de produção

O que conferir e o que mudar antes de subir. Escrito a partir do estado real dos
arquivos, não de memória; os valores abaixo são os que estão no repositório agora.

Resource: `resources/[bgrz]/noir_prettycrimes`
Crime ativo: **smashgrab** (objetos visíveis dentro de veículos estacionados)

---

## 1. Antes de subir — o que precisa de decisão

Nada aqui está quebrado. São escolhas que foram feitas para testar e que você
precisa confirmar conscientemente para produção.

### 1.1. `Config.debug` — **confirmar que está `false`**

`config/shared.lua`

```lua
debug = false,
```

Estado atual: **`false`** ✅

Ligado, ele faz duas coisas: solta uma linha de diagnóstico por varredura (a cada
1,5 s, por jogador) e registra quatro comandos. Em produção as duas custam.

| Com `debug = true` | |
| --- | --- |
| `[smashgrab] varredura #N: ...` | uma linha por varredura, por jogador |
| `/smashdebug` | overlay 3D sobre cada objeto — **usa `Wait(0)`** |
| `/smashinfo` | veredito do carro mirado |
| `/spawnsmashloot` | força objeto no veículo mais próximo |
| `/smashstate` | contagem de decididos / reservados / levados |

Os comandos de servidor ficam atrás de `debugAce` (`group.admin`) **além** do
`debug`. Os de client não têm gate além do `debug` — mais um motivo para deixá-lo
desligado.

### 1.2. `spawnChance` — está em **80%**

`config/smashgrab_server.lua`

```lua
spawnChance = 0.80,
```

**Decidido ficar em 80%.** Registrando o que isso significa para quando a economia
for revisada:

| Carros elegíveis ao alcance | Com objeto |
| --- | --- |
| 5 | ~4 |
| 10 | ~8 |
| 20 | ~16 |

São 80% dos **elegíveis** — estacionado, vazio, inteiro, não pertencente a jogador,
classe e modelo permitidos. Trânsito em movimento e carro com NPC dentro nem entram
no sorteio. Numa rua com tráfego, tipicamente um terço dos carros é elegível.

O valor original do desenho era `0.12`. A faixa sugerida caso a saída de itens
incomode: **0.25 a 0.35**. É uma linha.

### 1.3. Animação da quebra — **não verificada neste build**

`config/smashgrab.lua`

```lua
breakAnim = {
    dict = 'veh@break_in@0h@p_m_zero@',
    clip = 'low_force_entry_ds',
    flag = 49,
},
```

`p_m_zero@` não aparece em nenhum outro resource deste servidor. Se em jogo o
personagem ficar parado durante o 1 s da quebra, o dicionário existe mas o clip
está errado — troque para `p_m_one@`, que está em produção em quatro resources
(`qbx_storerobbery`, `qbx_houserobbery`, `noir_houserobbery`, `qbx_vehiclekeys`)
com os clips `low_force_entry_ds` e `std_force_entry_rds`.

Os dois modos de falha têm sintomas diferentes:

* **dicionário ausente** → aviso no console, barra roda sem animação;
* **clip errado** → silêncio total, barra roda, personagem parado.

A animação do roubo (`mp_car_bomb` / `car_bomb_mechanic`) está em produção no
`qbx_vineyard` e no `qbx_recyclejob` daqui.

### 1.4. `renderDistance` — 60 m

`config/smashgrab.lua`

```lua
activationDistance = 80.0,   -- pergunta ao servidor
renderDistance     = 60.0,   -- cria o prop
cleanupDistance    = 120.0,  -- destrói o prop
```

O prop só nasce a 60 m. Se em jogo os objetos parecerem aparecer só quando você já
está em cima do carro, subir `renderDistance` para 80 (igualando à ativação) é o
knob. Custo: mais props na tela ao mesmo tempo.

### 1.5. Valores de ritmo — conferir se batem com o desenho

Estão todos em `config/smashgrab_server.lua`, exceto as durações.

| Ajuste | Atual | Nota |
| --- | --- | --- |
| alarme | **65%**, 15 s | dispara na quebra do vidro |
| dispatch | **25%**, no gatilho `reserved` | sai quando o jogador enfia o braço |
| espera entre roubos | 8 s por jogador | |
| espera entre quebras | 750 ms | é o piso do `rateLimit.default` |
| animação de quebra | 1 s | |
| animação de roubo | 3 s | o servidor exige 80% disso decorrido |
| validade da reserva | 15 s | cobre desconexão no meio da animação |

---

## 2. Integrações desligadas por opção

As três são estruturas prontas que **não** fazem nada hoje. Nenhuma precisa ser
ligada para o crime funcionar.

| Opção | Arquivo | Estado | O que exige para ligar |
| --- | --- | --- | --- |
| `progression.enabled` | `config/server.lua` | `false` | registrar `noir_prettycrimes` em `noir_illegal_core/shared/permissions.lua` (`publicRecorders`) **e** declarar a activity `petty_smashgrab` nas activities de lá. Sem isso o core recusa em silêncio. |
| `classMultipliers.enabled` | `config/smashgrab_server.lua` | `false` | nada — mas passa a exigir `bgrz_core:GetVehicleClass` no caminho da validação de spawn. |
| `witnesses.enabled` | `config/smashgrab_server.lua` | `false` | uma contagem de NPCs feita **no servidor**. Contagem vinda do client é palpite do client. Enquanto ela não existir, mantenha desligado. |

---

## 3. Dependências e ordem de start

```cfg
ensure ox_lib
ensure oxmysql
ensure qbx_core
ensure ox_inventory
ensure ox_target
ensure bgrz_core
ensure noir_prettycrimes
```

O manifest declara apenas `/onesync`, `ox_lib` e `bgrz_core`. `qbx_core`,
`ox_target` e `ox_inventory` **não** são declarados de propósito: toda interação com
eles passa pelo bridge, e eles são dependência *dele* (§6.2 do
`SCRIPT_GOOD_PRACTICES.md`).

### 3.1. Este resource depende de exports acrescentados ao `bgrz_core`

Se o `bgrz_core` for revertido para uma versão anterior, **este resource para**.
Os exports adicionados foram:

| Export | Lado | Para quê |
| --- | --- | --- |
| `GetItemLabel(item)` | servidor | rótulo de item na notificação de saque |
| `GetVehicleClass(model)` | servidor | só com `classMultipliers` ligado |
| `AddLocalEntityTarget(entity, options)` | client | acrescentado, hoje **não usado** (o alvo mora no veículo) |
| `RemoveLocalEntityTarget(entity, names)` | client | idem |

Os dois primeiros são usados. Os dois últimos ficaram como capacidade do bridge
(§3.4 lista "target/zones" como lacuna conhecida) e podem ser removidos se você
preferir manter o bridge enxuto — nada os consome hoje.

Testes do bridge: `cd resources/[bgrz]/bgrz_core && lua5.4 tests/unit/<spec>.lua`
(13 specs, incluindo `vehicle_class_spec.lua` novo e `target_spec` / `inventory_spec`
estendidos).

---

## 4. Conteúdo que precisa existir no servidor

Tudo já foi conferido contra os arquivos reais. Vale reconferir se alguém mexer no
`ox_inventory` ou trocar de build.

### 4.1. Itens de loot — 18, todos existentes

`armour`, `bandage`, `beer`, `binoculars`, `burner_phone`, `cryptostick`,
`diamond_ring`, `goldchain`, `id_card`, `laptop`, `lockpick`, `phone`, `radio`,
`rolex`, `sandwich`, `screwdriver`, `tablet`, `vodka` — mais dinheiro (`cash`).

Conferidos contra `resources/[ox]/ox_inventory/data/items.lua`.

> O sketch original pedia `cash` e `headphones`: **nenhum dos dois existe** neste
> servidor. Viraram `money` e eletrônicos reais.

### 4.2. Props — 6, todos existentes

`prop_cs_shopping_bag`, `prop_michael_backpack`, `prop_amb_handbag_01`,
`prop_cs_cardbox_01`, `prop_laptop_01a`, `prop_ld_case_01`.

Conferidos contra `resources/[standalone]/ps_lib/modules/streamed_assets/shared/objectList.lua`.

**Prop que não existe no build do Enhanced derruba o cliente na thread de render.**
O módulo valida com `IsModelValid` + `IsModelInCdimage` no start e recusa o que
faltar, mas conferir na lista antes de acrescentar continua sendo obrigatório.

---

## 5. O que o console ainda mostra com `debug = false`

Isto **não** é ruído — se aparecer, algo precisa de atenção.

| Mensagem | Significa |
| --- | --- |
| `bgrz_core não está started: nenhuma recompensa será concedida.` | o bridge caiu; o resource recusa reserva e entrega |
| `prop "X" não existe neste build: Y` | prop inválido, sai do desenho (boot) |
| `prop indisponível neste build: X` | idem, detectado no spawn |
| `dicionário de animação ausente neste build: X` | animação não toca, resto funciona |
| `crime desconhecido em Config.crimes: "X"` | erro de digitação na config |
| `"X" ainda não tem módulo; mantenha desligado.` | crime do roadmap ligado cedo demais |
| `falha ao carregar .../X` · `erro no start de X` | o crime não subiu |
| `erro na varredura: X` | exceção dentro do scan (não derruba o laço) |

---

## 6. Verificação antes de liberar

```bash
cd resources/[bgrz]/noir_prettycrimes
for f in $(find . -name '*.lua'); do luac5.4 -p "$f" || echo "FALHOU $f"; done
```

Em jogo, com `debug = true` temporariamente:

1. `/smashinfo` mirando um carro parado → deve dizer `elegível: true`.
2. Console deve imprimir `varredura #N` **continuamente**, a pé **e dirigindo**.
   Se parar de numerar, a thread morreu.
3. Aproximar de um carro com objeto → alvo **"Quebrar vidro"** aparece na janela
   daquele banco.
4. Quebrar (1 s) → vidro estoura para todos por perto, alarme pode disparar (65%).
5. Alvo vira **"Roubar <objeto>"** → 3 s → prop some para **todos** e o loot entra.
6. Segundo jogador na mesma bolsa → deve receber recusa, não um segundo loot.
7. Desligar `debug` de novo.

### Suítes automatizadas

Ficam fora do repositório (foram construídas durante o desenvolvimento). Se quiser
mantê-las, o lugar natural é `resources/[bgrz]/noir_prettycrimes/tests/`.

---

## 7. Knobs de emergência

Ordem do mais rápido para o mais drástico.

| Sintoma | Ação | Arquivo |
| --- | --- | --- |
| loot demais na economia | `spawnChance` para `0.30` | `config/smashgrab_server.lua` |
| polícia recebendo alerta demais | `dispatch.chance` para `0.10`, ou `trigger = 'claimed'` | `config/smashgrab_server.lua` |
| alarme irritando | `alarm.enabled = false` | `config/smashgrab_server.lua` |
| impacto de CPU no client | `scanInterval` para `2500` | `config/smashgrab.lua` |
| desligar o crime inteiro | `crimes.smashgrab = false` | `config/shared.lua` |

`crimes.smashgrab = false` não é "carrega e fica quieto": o arquivo do crime nem
chega a ser lido, nenhum alvo é registrado e nenhum evento passa a existir. Restart
do resource basta.

---

## 8. Limitações conhecidas

* **NPC dentro do carro só é visto pelo client.** O servidor não enxerga ped de
  ambiente. Carro com NPC não recebe prop, mas se um NPC entrar depois, a entrega
  não recusa por isso. Jogador dentro é conferido dos dois lados.
* **Quebrar o vidro não gera dispatch.** O servidor não consegue verificar estado de
  vidro, e um gatilho que o client dispara sozinho vira spam de polícia. O alarme
  cobre esse momento da cena.
* **O prop some se alguém entrar no carro ou sair dirigindo.** Deliberado: o servidor
  recusaria a entrega nesse estado.
* **O restart re-sorteia o mapa de objetos.** A tabela de decisões vive em memória do
  servidor e não é persistida.
* **A consulta custa um round-trip.** Um carro que entra no raio aparece na varredura
  seguinte (1,5 s), não instantaneamente.

---

## 9. Custo em produção

Medido com os números da config, não estimado:

| | |
| --- | --- |
| threads no client | **1** (a varredura) |
| `Wait(0)` em produção | **nenhum** (o único está no overlay de debug) |
| tráfego com 64 jogadores | **~2 KB/s** agregados |
| entidades de servidor criadas | **0** (props são locais, não networked) |
| tabelas no servidor | decisões e reservas, podadas a cada 5 min |

A varredura roda a 1,5 s a pé **e dirigindo** — procurar carro estacionado enquanto
se roda a cidade é o loop do crime. O backoff para 5 s acontece por **região vazia**
(nenhum veículo ao alcance), não por estar dirigindo.
