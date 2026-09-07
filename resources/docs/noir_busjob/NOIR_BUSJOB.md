# NOIR_BUSJOB — Especificação

## 1. Objetivo

Refatorar o `qbx_busjob` oficial para transformá-lo no sistema de transporte público do Noir State RP, mantendo Qbox como framework e preservando somente as partes úteis da implementação atual. Transformá-lo no `noir_busjob` dentro de `[bgrz]`.

O novo resource deve deixar de ser um loop simples de:

```
pegar ônibus
  → ir até um ponto
  → pegar um NPC
  → levar até outro ponto
  → receber dinheiro
  → repetir
```

e passar a representar uma carreira de motorista de transporte público, com:

- linhas fixas
- paradas reais
- passageiros persistindo durante a linha
- embarque e desembarque
- capacidade do veículo
- abertura manual das portas
- avaliação das paradas
- qualidade de condução
- horário/pontualidade
- retorno obrigatório ao terminal
- XP próprio do resource
- níveis
- ranking
- desbloqueio progressivo de linhas
- desbloqueio de categorias de serviço
- estatísticas persistentes
- NUI principal seguindo `NUI_JOB.md`
- HUD mínimo durante a condução
- autoridade server-side para sessão, pagamento, XP e progressão

O objetivo é melhorar o gameplay mantendo o emprego acessível para jogadores novos.

## 2. Regras obrigatórias antes de implementar

Antes de alterar qualquer arquivo:

- Ler o `NUI_JOB.md` existente no projeto.
- Tratar `NUI_JOB.md` como fonte de verdade da NUI principal.
- Ler integralmente o `qbx_busjob` atual.
- Identificar tudo que pode ser reaproveitado:
  - integração Qbox
  - job/duty
  - spawn de veículos
  - keys
  - garagem
  - localização do depot
  - locales
  - blips
  - lifecycle do resource
- Remover ou substituir a lógica antiga de:
  - NPC individual
  - pagamento por pickup
  - rota circular baseada em um único índice
  - `NpcPay`
  - progressão controlada pelo client
- Não adicionar nenhuma dependência com Asset Escrow.
- Não utilizar sistema de XP/reputação do Qbox.
- Não utilizar `metadata.jobrep` para este emprego.
- Não utilizar job grade do Qbox como nível de motorista.

O Qbox deverá continuar responsável apenas por:

- identidade
- job
- duty
- dinheiro
- spawn/ownership do veículo
- integração geral com o servidor

A progressão de motorista será responsabilidade exclusiva do `qbx_busjob`.

O `qbx_busjob` oficial atual já utiliza `qbx_core` + `ox_lib`, possui spawn server-side de ônibus e uma implementação bastante simples de pontos/NPCs; essa integração deve servir como fundação, não o gameplay antigo.

## 3. Problemas da implementação atual

O fluxo atual do `qbx_busjob` deve ser considerado legado. Atualmente a lógica é essencialmente:

```
NPC no ponto
  → motorista chega
  → E
  → NPC entra
  → pagamento
  → próximo ponto
```

Isso possui vários problemas:

- não existe conceito real de linha
- não existe terminal inicial/final
- o passageiro não permanece durante múltiplas paradas
- não há passageiros simultâneos
- não há capacidade do ônibus
- não há carreira
- não há XP
- não há ranking
- não há avaliação de direção
- não há avaliação de parada
- pagamento ocorre durante o serviço
- não existe razão forte para completar a linha
- o gameplay se torna previsível rapidamente

A implementação atual também possui loops locais vinculados às zonas e avança boa parte da missão pelo client.

A nova implementação deve substituir esse modelo por uma **Route Session server-authoritative**.

## 4. Fontes de referência analisadas

A implementação deve combinar conceitos de várias referências, mas não copiar cegamente a arquitetura de nenhuma delas.

### qbx_busjob

Usar para:

- Qbox
- duty
- veículo
- keys
- garagem
- padrões atuais do framework

### debux-busjob

Usar como referência para:

- níveis
- XP
- linhas bloqueadas por level
- capacidade por modelo
- coordenada separada para ônibus e passageiros
- embarque/desembarque
- retorno/parking

O Debux possui uma estrutura de 10 níveis, rotas com `minLevel`, XP por missão e capacidade configurável por modelo.

### Lachee/fivem-busdriver

Usar como fonte principal das linhas e paradas iniciais.

O projeto mantém as paradas separadas das linhas e monta cada linha por uma sequência de IDs, exatamente o padrão que queremos no Noir.

### esx-blarglebus

Não portar o código. Usar apenas como referência conceitual para:

- capacidade
- destinos dos passageiros
- parada terminal
- alguns passageiros descendo
- todos os passageiros descendo
- reutilização das mesmas paradas em várias linhas

Não utilizar sua implementação antiga de entidades/OneSync.

### hm_busjob

Usar como referência para:

- perfil persistente
- level
- XP
- estatísticas
- leaderboard
- exibição da posição do jogador

Não copiar seu modelo de pagamento/XP vindo do client. O servidor do Noir deve determinar integralmente dinheiro e XP.

## 5. Filosofia do gameplay

O emprego deve seguir esta regra:

> O jogador deve melhorar porque aprendeu a operar o ônibus melhor e desbloqueou novos tipos de serviço, não simplesmente porque repetiu um checkpoint várias vezes.

Progressão deve liberar principalmente:

- linhas
- distâncias maiores
- ônibus
- categorias de serviço
- linhas expressas
- serviço regional
- serviço intermunicipal

Evitar:

```
LEVEL 2 = +5% dinheiro
LEVEL 3 = +10% dinheiro
LEVEL 4 = +15% dinheiro
```

O aumento financeiro deve ocorrer porque linhas de maior nível são:

- mais longas
- mais difíceis
- transportam mais passageiros
- possuem exigência maior de qualidade

## 6. State machine

Não implementar o resource com dezenas de booleanos independentes. Criar uma máquina de estados explícita.

```lua
BusState = {
    IDLE = 'IDLE',
    DEPOT = 'DEPOT',
    SPAWNING = 'SPAWNING',
    DEADHEAD = 'DEADHEAD',
    APPROACHING_STOP = 'APPROACHING_STOP',
    DOCKED = 'DOCKED',
    BOARDING = 'BOARDING',
    WAITING_DOORS = 'WAITING_DOORS',
    DEPARTING = 'DEPARTING',
    RETURNING_DEPOT = 'RETURNING_DEPOT',
    PARKING = 'PARKING',
    COMPLETING = 'COMPLETING',
    SUMMARY = 'SUMMARY',
    CANCELLED = 'CANCELLED',
}
```

Fluxo:

```
IDLE
  → DEPOT
  → seleciona linha
  → SPAWNING
  → DEADHEAD
  → APPROACHING_STOP
  → DOCKED
  → abrir portas
  → BOARDING
  → fechar portas
  → DEPARTING
  → APPROACHING_STOP
  → ...
  → ÚLTIMA PARADA
  → RETURNING_DEPOT
  → PARKING
  → COMPLETING
  → pagamento + XP
  → SUMMARY
  → IDLE
```

Toda alteração de estado deve passar por uma função central:

```lua
setBusState(newState, context)
```

## 7. Route Session

Cada turno ativo deve possuir uma sessão server-side.

Exemplo conceitual:

```lua
activeSessions[source] = {
    id = 'uuid',

    citizenid = '...',
    routeId = 'small_metro',

    state = 'DEADHEAD',

    vehicleNetId = 123,
    vehicleModel = 'bus',

    startedAt = os.time(),

    currentStopIndex = 1,
    completedStops = 0,

    passengers = {},
    passengerCount = 0,
    totalBoarded = 0,
    totalDropped = 0,

    stopScores = {},

    safetyPenalty = 0,
    servicePenalty = 0,

    expectedFinishAt = ...,

    finalized = false,
}
```

O client nunca deve possuir autoridade para definir:

- `payout`
- `xp`
- `level`
- `routeCompleted`
- `finalScore`
- `passengerReward`

## 8. Estrutura das paradas

Separar completamente `Stops` de `Routes`. Nunca duplicar coordenadas em cada linha.

Estrutura:

```lua
Config.BusStops = {
    [3] = {
        name = 'Strawberry Ave',
        coords = vec4(...)
    },

    [5] = {
        name = 'San Andreas Ave',
        coords = vec4(...)
    },
}
```

Linhas apenas referenciam IDs:

```lua
Config.Routes.smallMetro = {
    stops = { 3, 5, 6, 8, 38 }
}
```

Isso permite que uma parada seja reutilizada por várias linhas.

## 9. Dataset inicial obrigatório de paradas

Usar como base inicial as coordenadas do Lachee/fivem-busdriver. Adicionar comentário de atribuição no arquivo:

```lua
-- Initial stop dataset adapted from Lachee/fivem-busdriver (MIT).
```

Dataset:

```lua
Config.BusStops = {
    [3]  = { name='Strawberry Ave', coords=vec4(308.745,-761.421,29.2311,163.148) },
    [5]  = { name='San Andreas Ave', coords=vec4(118.576,-786.144,31.419,70.0) },
    [6]  = { name='Alta St', coords=vec4(-171.367,-816.120,31.166,159.84) },
    [8]  = { name='Peaceful St / Vespucci', coords=vec4(-273.329,-827.684,31.7272,341.344) },

    [10] = { name='San Andreas Ave East', coords=vec4(-511.119,-667.722,33.0639,270.944) },
    [11] = { name='San Andreas Ave West', coords=vec4(-696.408,-668.147,30.8236,270.0) },
    [12] = { name='Vespucci Blvd / Ginger St', coords=vec4(-707.914,-827.722,23.4815,90.0) },
    [13] = { name='Ginger St', coords=vec4(-740.696,-755.317,26.4751,0.307) },
    [14] = { name='Vespucci Blvd East', coords=vec4(-563.812,-846.385,27.0341,270.158) },

    [16] = { name='Strawberry Ave / Macdonald St', coords=vec4(47.9691,-1538.26,29.3447,320.0) },
    [18] = { name='Carson Ave', coords=vec4(437.213,-2026.75,23.3423,223.246) },

    [22] = { name='Popular St South', coords=vec4(826.433,-1634.42,30.5628,174.695) },
    [24] = { name='Popular St / Olympic Fwy', coords=vec4(788.697,-1364.43,26.451,178.864) },
    [25] = { name='Popular St North', coords=vec4(771.680,-938.991,25.6343,185.068) },

    [27] = { name='Hawick Ave / Boulevard Del Perro', coords=vec4(-496.892,20.1225,44.8445,89.5643) },
    [28] = { name='Boulevard Del Perro / Rockford Dr', coords=vec4(-690.275,-6.08575,38.2245,111.799) },
    [29] = { name='Boulevard Del Perro / Mad Wayne Thunder Dr', coords=vec4(-933.817,-127.573,37.5776,117.067) },
    [30] = { name='Boulevard Del Perro West', coords=vec4(-1521.73,-464.107,35.3015,123.086) },

    [31] = { name='Marathon Ave', coords=vec4(-1161.27,-400.291,35.695,98.1812) },
    [32] = { name='Marathon Ave / Prosperity St', coords=vec4(-1407.29,-568.154,30.3818,119.23) },

    [36] = { name='Bay City Ave / Invention Ct', coords=vec4(-1213.41,-1213.33,7.59806,190.893) },
    [37] = { name='Magellan Ave / Aguja St', coords=vec4(-1170.57,-1468.27,4.28024,215.321) },

    [38] = { name='Dashound Terminal', coords=vec4(459.736,-625.933,28.4958,32.803) },

    [40] = { name='Sandy Shores', coords=vec4(1933.47,3716.51,33.2505,120.577) },
    [41] = { name='Grand Senora Desert', coords=vec4(1183.0,2691.27,38.6443,89.3957) },

    [45] = { name='Route 68 West', coords=vec4(-2531.68,2343.37,33.8786,32.8264) },
    [46] = { name='Route 68 / Harmony', coords=vec4(-1110.78,2680.36,19.6074,130.767) },

    [49] = { name='Palomino Ave / Lindsay Circus', coords=vec4(-620.165,-921.596,23.2675,1.94309) },
    [50] = { name='Hawick Ave / Alta Pl', coords=vec4(160.988,-209.049,54.1357,249.776) },
}
```

A ordem e o conjunto inicial de linhas abaixo vêm diretamente do dataset de rotas do projeto MIT usado como referência.

## 10. Linhas iniciais

### Linha M01 — Centro

Fonte: **Small Metro Route**

```lua
{
    id = 'small_metro',
    code = 'M01',
    name = 'Linha M01 · Centro',
    sourceName = 'Small Metro Route',

    minimumLevel = 1,
    vehicleClass = 'urban',

    stops = {
        3,
        5,
        6,
        8,
        38,
    }
}
```

Percurso:

1. Strawberry Ave
2. San Andreas Ave
3. Alta St
4. Peaceful St / Vespucci
5. Dashound Terminal

Características:

- 5 paradas
- urbana
- curta
- nível inicial

## 11. Linha I02 — Industrial

Fonte: **Industry**

```lua
{
    id = 'industry',
    code = 'I02',
    name = 'Linha I02 · Industrial',
    sourceName = 'Industry',

    minimumLevel = 1,
    vehicleClass = 'urban',

    stops = {
        50,
        25,
        24,
        22,
        18,
        16,
        38,
    }
}
```

Percurso:

1. Hawick Ave / Alta Pl
2. Popular St North
3. Popular St / Olympic Fwy
4. Popular St South
5. Carson Ave
6. Strawberry Ave / Macdonald St
7. Dashound Terminal

Características:

- 7 paradas
- industrial / sul da cidade
- urbana média

## 12. Linha M03 — Metropolitana

Fonte: **Medium Metro Route**

```lua
{
    id = 'medium_metro',
    code = 'M03',
    name = 'Linha M03 · Metropolitana',
    sourceName = 'Medium Metro Route',

    minimumLevel = 2,
    vehicleClass = 'urban',

    stops = {
        5,
        31,
        32,
        36,
        12,
        13,
        11,
        10,
        38,
    }
}
```

Percurso:

1. San Andreas Ave
2. Marathon Ave
3. Marathon Ave / Prosperity St
4. Bay City Ave
5. Vespucci Blvd / Ginger St
6. Ginger St
7. San Andreas Ave West
8. San Andreas Ave East
9. Dashound Terminal

Características:

- 9 paradas
- oeste + centro
- nível 2

## 13. Linha C04 — Costa Oeste

Fonte: **Long Beach Route**

```lua
{
    id = 'long_beach',
    code = 'C04',
    name = 'Linha C04 · Costa Oeste',
    sourceName = 'Long Beach Route',

    minimumLevel = 3,
    vehicleClass = 'urban',

    stops = {
        27,
        28,
        29,
        30,
        36,
        37,
        49,
        14,
        8,
        38,
    }
}
```

Percurso:

1. Hawick
2. Rockford
3. Mad Wayne Thunder Dr
4. Del Perro
5. Bay City
6. Magellan Ave
7. Palomino Ave
8. Vespucci Blvd
9. Peaceful St
10. Dashound Terminal

Características:

- 10 paradas
- linha urbana longa
- nível 3
- alta movimentação de passageiros

## 14. Expresso X05 — Sandy Shores

Fonte: **Sandy Shores X-Press**

```lua
{
    id = 'sandy_express',
    code = 'X05',
    name = 'Expresso X05 · Sandy Shores',
    sourceName = 'Sandy Shores X-Press',

    minimumLevel = 5,
    vehicleClass = 'coach',

    stops = {
        38,
        40,
        38,
    }
}
```

Percurso:

1. Dashound Terminal
2. Sandy Shores
3. Dashound Terminal

Características:

- expresso
- longa distância
- poucas paradas
- Coach
- nível 5

## 15. Regional R06 — Route 68

Fonte: **Long Rural Route**

```lua
{
    id = 'long_rural',
    code = 'R06',
    name = 'Regional R06 · Route 68',
    sourceName = 'Long Rural Route',

    minimumLevel = 7,
    vehicleClass = 'coach',

    stops = {
        38,
        40,
        41,
        46,
        45,
        38,
    }
}
```

Percurso:

1. Dashound Terminal
2. Sandy Shores
3. Grand Senora Desert
4. Harmony / Route 68
5. Route 68 West
6. Dashound Terminal

Características:

- regional
- longa distância
- Coach
- nível 7

## 16. Waypoints de rota

Parada de passageiro e waypoint de navegação são conceitos diferentes. Criar suporte a `route.pathPoints`.

Exemplo:

```lua
{
    stop = 40,

    via = {
        vec3(...),
        vec3(...),
    }
}
```

`via` serve para obrigar a rota a:

- entrar por determinada avenida
- utilizar highway correta
- não cortar bairro
- não escolher atalho absurdo do GPS

Waypoints:

- não embarcam passageiros
- não concedem XP
- não contam como parada
- não aparecem no resumo
- não modificam `completedStops`

Esse padrão é inspirado em scripts de transporte que distinguem pontos de passagem de pontos reais de parada.

## 17. Validação manual das coordenadas

As coordenadas importadas são apenas o dataset inicial.

Antes de considerar uma linha pronta:

- teletransportar para cada parada
- spawnar o modelo bus
- verificar:
  - alinhamento com meio-fio
  - sentido correto
  - heading
  - espaço para o ônibus
  - obstáculos
  - trânsito
  - entradas de garagem
  - MLOs/mapas do Noir
- ajustar coordenadas quando necessário
- registrar a alteração como override Noir

Não alterar silenciosamente o dataset original. Preferir:

```lua
Config.StopOverrides = {
    [27] = {
        coords = vec4(...)
    }
}
```

ou documentar a mudança no commit.

## 18. Coordenada de passageiros

Cada parada deve possuir também `passengerSpawn` ou `passengerArea`.

Exemplo:

```lua
[3] = {
    name = 'Strawberry Ave',

    bus = vec4(...),

    passengerArea = {
        center = vec3(...),
        radius = 4.0,
    }
}
```

Não spawnar todos os NPCs exatamente no mesmo ponto. Gerar pequenas posições dentro da área.

## 19. Progressão própria

#### Regra absoluta

Não utilizar:

- `qbx_core` metadata
- `jobrep`
- `AddJobReputation`
- job grade

para progressão. Criar sistema completamente próprio.

## 20. Banco de dados

Criar:

```sql
CREATE TABLE IF NOT EXISTS busjob_driver_profiles (
    citizenid VARCHAR(50) NOT NULL,

    last_known_name VARCHAR(100) NULL,

    level INT NOT NULL DEFAULT 1,
    xp_total INT NOT NULL DEFAULT 0,

    routes_completed INT NOT NULL DEFAULT 0,
    stops_completed INT NOT NULL DEFAULT 0,

    passengers_transported INT NOT NULL DEFAULT 0,
    perfect_stops INT NOT NULL DEFAULT 0,

    total_earned BIGINT NOT NULL DEFAULT 0,
    distance_meters BIGINT NOT NULL DEFAULT 0,

    score_sum DECIMAL(14,2) NOT NULL DEFAULT 0,
    best_score DECIMAL(5,2) NOT NULL DEFAULT 0,

    last_route_id VARCHAR(50) NULL,
    last_route_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (citizenid),

    INDEX idx_busjob_level_xp (level, xp_total),
    INDEX idx_busjob_xp (xp_total),
    INDEX idx_busjob_routes (routes_completed)
);
```

## 21. Histórico de linhas

Criar tabela independente:

```sql
CREATE TABLE IF NOT EXISTS busjob_route_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    citizenid VARCHAR(50) NOT NULL,
    route_id VARCHAR(50) NOT NULL,

    vehicle_model VARCHAR(50) NOT NULL,

    started_at DATETIME NOT NULL,
    completed_at DATETIME NOT NULL,

    duration_seconds INT NOT NULL,

    stops_completed INT NOT NULL,
    passengers_transported INT NOT NULL,

    stop_score DECIMAL(5,2) NOT NULL,
    safety_score DECIMAL(5,2) NOT NULL,
    punctuality_score DECIMAL(5,2) NOT NULL,
    service_score DECIMAL(5,2) NOT NULL,
    final_score DECIMAL(5,2) NOT NULL,

    payout INT NOT NULL,
    xp_earned INT NOT NULL,

    PRIMARY KEY (id),

    INDEX idx_bus_history_driver (citizenid, completed_at),
    INDEX idx_bus_history_route (route_id, completed_at)
);
```

Usar esta tabela para:

- histórico pessoal
- auditoria
- estatísticas
- futuras conquistas
- debugging de payout
- detecção de farming

## 22. Fonte de verdade do nível

`xp_total` é a fonte primária. `level` é cache persistente.

Sempre calcular:

```lua
newLevel = calculateLevel(xpTotal)
```

e atualizar `level` junto com XP na mesma transação. Nunca incrementar level cegamente com:

```lua
level = level + 1
```

## 23. Curva inicial de XP

Utilizar 10 níveis. Curva inicial inspirada no modelo analisado no Debux:

```lua
Config.Progression = {
    [1] = {
        xp = 0,
        title = 'Motorista Aprendiz',
    },

    [2] = {
        xp = 1500,
        title = 'Motorista Urbano',
    },

    [3] = {
        xp = 3000,
        title = 'Operador Municipal',
    },

    [4] = {
        xp = 5000,
        title = 'Motorista Sênior',
    },

    [5] = {
        xp = 7500,
        title = 'Motorista Expresso',
    },

    [6] = {
        xp = 10000,
        title = 'Motorista Regional',
    },

    [7] = {
        xp = 15000,
        title = 'Motorista Intermunicipal',
    },

    [8] = {
        xp = 20000,
        title = 'Especialista de Frota',
    },

    [9] = {
        xp = 25000,
        title = 'Supervisor de Linha',
    },

    [10] = {
        xp = 30000,
        title = 'Mestre de Operações',
    },
}
```

## 24. Unlocks

#### Level 1

- M01 · Centro
- I02 · Industrial
- Veículo: Bus

#### Level 2

- M03 · Metropolitana

#### Level 3

- C04 · Costa Oeste

#### Level 4

Desbloquear perfil de serviço **HORÁRIO DE PICO**. Esse perfil utiliza linhas urbanas existentes com:

- demanda maior
- mais passageiros
- dwell time maior
- XP maior

#### Level 5

- X05 · Sandy Shores
- Veículo: Coach

#### Level 6

Desbloquear perfil **EXPRESSO**. Pode utilizar versões futuras das linhas com menos paradas.

#### Level 7

- R06 · Route 68

#### Level 8

Desbloquear categoria **TURISMO / TOUR**. Preparar arquitetura, mesmo que não exista rota de turismo no MVP.

#### Level 9

Desbloquear **SERVIÇO PRIORITÁRIO**. Perfil com:

- horário mais rigoroso
- qualidade mínima maior
- bônus de XP

#### Level 10

Desbloquear todo o conteúdo operacional disponível.

Não criar veículo exclusivo inexistente apenas para justificar o nível.

## 25. XP não é ganho por checkpoint

Não persistir `+20 XP` imediatamente em cada parada.

Isso incentiva:

- fazer 3 paradas
- cancelar
- recomeçar

A sessão pode acumular XP provisório, mas a persistência ocorre somente após:

1. linha concluída
2. ônibus devolvido ao terminal
3. sessão validada

## 26. Fórmula de XP

Cada rota define `baseXp`.

Sugestão inicial:

```lua
small_metro   = 120
industry      = 150
medium_metro  = 180
long_beach    = 230
sandy_express = 300
long_rural    = 380
```

Calcular:

```
XP FINAL = XP BASE × multiplicador de qualidade + bônus limitado de passageiros
```

Qualidade:

| Nota da parada | Multiplicador |
|---|---|
| 50 ou menos | 0.75x |
| 60 | 0.85x |
| 70 | 0.95x |
| 80 | 1.00x |
| 90 | 1.10x |
| 95+ | 1.15x |

Bônus de passageiros: máximo +15% do XP base.

Nunca permitir multiplicadores absurdos.

## 27. Level up

Quando XP ultrapassar threshold:

```
LEVEL UP

NÍVEL 4 ALCANÇADO

MOTORISTA SÊNIOR

Novo serviço disponível
HORÁRIO DE PICO
```

Não abrir modal durante condução. Mostrar isso somente:

- no resumo da linha
- ou após retornar ao depot

## 28. Ranking

Criar ranking global do emprego.

Ordenação principal: `xp_total DESC`

Desempates:

1. `routes_completed DESC`
2. `average_score DESC`
3. `passengers_transported DESC`

`average_score`:

```
average_score = score_sum / routes_completed
```

## 29. Leaderboard

Exibir no máximo **Top 50** na API.

Na NUI inicial: **Top 20**, com paginação/scroll quando necessário.

Dados: `POS`, `MOTORISTA`, `NÍVEL`, `XP`, `LINHAS`, `NOTA MÉDIA`

Exemplo:

| POS | MOTORISTA | NÍVEL | XP | LINHAS | NOTA MÉDIA |
|---|---|---|---|---|---|
| 01 | Ethan Miller | 10 | 42.840 XP | 188 | 94,7 |
| 02 | Lucas Carter | 9 | 37.210 XP | 172 | 91,4 |
| 03 | James Turner | 9 | 35.820 XP | 165 | 93,1 |

Nunca exibir:

- citizenid
- license
- FiveM identifier
- Discord ID

## 30. Posição do jogador

A NUI deve mostrar `SUA POSIÇÃO · #27` mesmo que o jogador não esteja no top 20.

Calcular server-side. Cachear leaderboard por 30–60 segundos para evitar query a cada abertura.

## 31. NUI principal

#### Regra de precedência

Antes de desenvolver a NUI, ler `NUI_JOB.md`.

`NUI_JOB.md` define:

- shell
- tokens
- tipografia
- posicionamento
- interações
- componentes compartilhados
- comportamento responsivo

Esta especificação define conteúdo e estado, não deve criar um design system paralelo.

Se houver conflito visual, `NUI_JOB.md` vence.

## 32. Quando abrir a NUI

A NUI principal somente deve abrir no depot, fora de uma linha.

Pode utilizar `[E] Central de Transporte` ou mecanismo já padronizado pelo Noir.

Ao abrir, `SetNuiFocus(true, true)` é permitido.

Durante uma linha: `SetNuiFocus(false, false)`

O motorista nunca deve precisar usar mouse dirigindo.

## 33. Conteúdo da NUI principal

A tela deve possuir semanticamente:

**TRANSPORTE PÚBLICO**

- PERFIL DO MOTORISTA
- LINHAS
- PROGRESSÃO
- RANKING

Se o `NUI_JOB.md` definir outra navegação, encaixar essas áreas no componente correspondente.

## 34. Cabeçalho de perfil

Mostrar:

```
MOTORISTA SÊNIOR

NÍVEL 4

4.380 / 7.500 XP

RANKING · #27

████████████░░░░░
```

Não usar XP do Qbox. Todos os valores vêm de `busjob_driver_profiles`.

## 35. Aba LINHAS

Esta deve ser a página principal.

Lista:

```
M01 · CENTRO
5 paradas · Urbano

I02 · INDUSTRIAL
7 paradas · Urbano

M03 · METROPOLITANA
9 paradas · Urbano

C04 · COSTA OESTE
10 paradas · Urbano

X05 · SANDY SHORES
3 paradas · Expresso

R06 · ROUTE 68
6 paradas · Regional
```

Linhas bloqueadas continuam visíveis. Exemplo:

```
R06 · ROUTE 68
NÍVEL 7 NECESSÁRIO
```

Não simplesmente esconder conteúdo futuro.

## 36. Estado de linha bloqueada

Mostrar:

```
BLOQUEADA
NÍVEL 7
```

A linha:

- não recebe hover de ação
- não pode ser selecionada para início
- possui opacidade menor
- continua legível

## 37. Detalhes da linha

Ao selecionar uma linha:

```
C04 · COSTA OESTE

TIPO · URBANO
PARADAS · 10
VEÍCULO · BUS
TEMPO ESTIMADO · 22 MIN
XP BASE · 230
NÍVEL · 3
```

Mostrar também a sequência:

1. Hawick
2. Rockford
3. Mad Wayne Thunder Dr
4. Del Perro
5. Bay City
6. Magellan Ave
7. Palomino Ave
8. Vespucci Blvd
9. Peaceful St
10. Dashound Terminal

## 38. Não utilizar mapa gigante

A NUI principal não precisa obrigatoriamente renderizar um mapa de Los Santos.

Priorizar: linha + lista de paradas.

Um mapa pode ser adicionado futuramente, desde que previsto pelo `NUI_JOB.md`.

## 39. Ação principal

Uma única ação principal: **INICIAR LINHA**

Ao pressionar:

1. NUI solicita início
2. server valida
3. server cria session
4. server spawna ônibus
5. client recebe `vehicleNetId`
6. NUI fecha
7. GPS recebe primeiro ponto

Nunca spawnar o ônibus antes da validação server-side.

## 40. Aba PROGRESSÃO

Mostrar os 10 níveis verticalmente.

Exemplo:

```
01 MOTORISTA APRENDIZ       CONCLUÍDO
02 MOTORISTA URBANO         CONCLUÍDO
03 OPERADOR MUNICIPAL       CONCLUÍDO
04 MOTORISTA SÊNIOR         ATUAL
05 MOTORISTA EXPRESSO       7.500 XP
06 MOTORISTA REGIONAL       10.000 XP
...
```

Ao lado de cada nível, mostrar unlocks. Exemplo:

```
NÍVEL 5
MOTORISTA EXPRESSO

DESBLOQUEIA
• Expresso X05 · Sandy Shores
• Coach
```

## 41. Aba RANKING

Visual seguindo obrigatoriamente o padrão de lista definido no `NUI_JOB.md`.

Conteúdo:

| # | MOTORISTA | NÍVEL | XP | LINHAS |
|---|---|---|---|---|
| 1 | Ethan Miller | 10 | 42840 | 188 |
| 2 | Lucas Carter | 9 | 37210 | 172 |
| 3 | James Turner | 9 | 35820 | 165 |

Destacar o jogador atual apenas de maneira sutil. Não transformar top 3 em cards extravagantes se isso conflitar com `NUI_JOB.md`.

## 42. HUD durante a linha

A NUI grande fecha completamente. Durante a condução existe somente um pequeno HUD.

Exemplo:

```
M03 · METROPOLITANA

PRÓXIMA PARADA
Marathon Ave

4 / 9
620 m

PASSAGEIROS · 7 / 11
```

Adicionar `HORÁRIO · +00:18` quando o sistema de timetable estiver habilitado.

## 43. HUD na parada

Ao entrar na área correta:

```
MARATHON AVE

PARE NO PONTO
```

Depois que o ônibus estiver corretamente parado:

```
MARATHON AVE

[G] ABRIR PORTAS
```

Portas abertas:

```
EMBARQUE

3 DESEMBARCANDO
4 EMBARCANDO
```

Finalizado:

```
[G] FECHAR PORTAS
```

Depois:

```
PRÓXIMA PARADA
Prosperity St

1,2 km
```

## 44. Key mapping das portas

Registrar por `RegisterKeyMapping`.

- Default: `G`
- Nome: `Ônibus: abrir/fechar portas`

Não hardcodar apenas Control ID.

## 45. Segurança das portas

Só permitir abertura quando:

- route session ativa
- player é motorista
- veículo correto
- stop atual correto
- distância <= configured radius
- velocidade <= limite

Sugestão:

```lua
Config.Stop.MaxDoorSpeedKmh = 3.0
```

Não abrir portas a 40 km/h.

## 46. Door profiles

Portas variam por modelo. Criar:

```lua
Config.VehicleProfiles = {
    bus = {
        class = 'urban',
        capacity = 11,
        doors = {...},
    },

    coach = {
        class = 'coach',
        capacity = 9,
        doors = {...},
    },

    tourbus = {
        class = 'tour',
        capacity = 9,
        doors = {...},
    },
}
```

Capacidades iniciais podem utilizar os valores conservadores presentes na referência Debux.

Não adivinhar índices de portas. Testar cada veículo no Enhanced.

Antes de chamar native de abertura:

- verificar se a porta existe
- ignorar índices inválidos

Não portar os índices antigos do blarglebus cegamente.

## 47. Passageiros

O passageiro agora possui destino real. Não fazer isto automaticamente:

```
NPC entra
  → próxima parada
  → NPC sai
```

Quando um NPC embarca:

```lua
Passenger = {
    id = ...,
    boardingStop = 2,
    destinationStop = 6,
}
```

Ele permanece durante várias paradas.

## 48. Manifesto server-side

O servidor deve criar um manifesto lógico.

Exemplo:

```lua
session.passengers = {
    {
        id = 1,
        boardedAt = 2,
        destination = 5,
    },

    {
        id = 2,
        boardedAt = 2,
        destination = 7,
    },
}
```

O client é responsável pela representação visual dos peds.

O servidor é responsável por:

- quantos passageiros existem
- quando entram
- onde descem
- quantidade transportada
- capacidade lógica

## 49. Geração de demanda

Cada parada possui:

```lua
demand = {
    min = 0,
    max = 5,
}
```

Perfis podem alterar demanda:

| Perfil | Multiplicador |
|---|---|
| STANDARD | 1.0x |
| PEAK | 1.5x |
| NIGHT | 0.6x |
| EXPRESS | 0.8x |

Não gerar sempre o mesmo número.

## 50. Destino de passageiros

Para cada passageiro: `destination > currentStop`

- Escolher aleatoriamente entre as paradas futuras.
- Favorecer destinos intermediários.
- Última parada deve sempre poder receber passageiros.

## 51. Terminal

A parada terminal força que todos os passageiros descem.

Depois:

```
PASSAGEIROS · 0 / capacidade
```

## 52. Spawn dos NPCs

Não criar todos os passageiros da linha ao iniciar.

Spawnar somente `current stop`, ou no máximo elementos necessários para `current stop` + próximo contexto visual.

Distância sugerida:

```lua
Config.Passengers.SpawnDistance = 150.0
```

## 53. Peds como representação visual

Os NPCs são principalmente visuais.

Se um ped:

- travar
- não encontrar porta
- errar path
- ficar preso na calçada

não permitir que o emprego inteiro trave.

Exemplo:

```
TaskEnterVehicle
  → timeout 10s
  → retry
  → timeout
  → resolver embarque logicamente
  → cleanup do ped problemático
```

O manifesto server-side continua sendo a fonte de verdade.

## 54. Capacidade

Nunca permitir `passengers > capacity`.

Quando cheio:

```
LOTAÇÃO MÁXIMA

11 / 11
```

Passageiros excedentes permanecem visualmente na parada ou não são spawnados.

## 55. Assentos

Escolher apenas assentos disponíveis. Nunca `driver seat`.

Priorizar assentos passageiros reais.

Se o modelo possuir menos assentos que o configurado:

- detectar
- emitir warning de configuração
- utilizar o menor valor

## 56. Avaliação da parada

Cada parada gera uma nota. Critérios:

- posição
- velocidade
- alinhamento
- portas

Peso sugerido:

| Critério | Peso |
|---|---|
| posição | 50% |
| velocidade | 25% |
| procedimento | 25% |

## 57. Distância do ponto ideal

Exemplo inicial:

| Distância | Avaliação |
|---|---|
| 0–2.5 m | Excelente |
| 2.5–5 m | Bom |
| 5–8 m | Aceitável |
| >8 m | Fora da parada |

Não permitir embarque se extremamente distante.

## 58. Velocidade

Para considerar ônibus parado: `<= 2 km/h`

Usar tolerância suficiente para física do GTA.

## 59. Procedimento

Parada perfeita:

```
chega
  → para
  → abre portas
  → passageiros movimentam
  → fecha portas
  → parte
```

Mover com porta aberta: service penalty. Não cancelar a linha imediatamente.

## 60. Feedback da parada

Não mostrar nota gigante em toda parada. Feedback pequeno:

```
PARADA PERFEITA
```

ou:

```
PARADA BOA
```

ou:

```
MUITO DISTANTE DO MEIO-FIO
```

Desaparece rapidamente.

## 61. Qualidade da condução

Criar quatro categorias:

- PARADAS
- SEGURANÇA
- PONTUALIDADE
- SERVIÇO

Peso:

```lua
Config.ScoreWeights = {
    stops = 0.35,
    safety = 0.30,
    punctuality = 0.20,
    service = 0.15,
}
```

## 62. Segurança

Avaliar:

- colisões relevantes
- frenagens muito fortes
- aceleração agressiva
- velocidade de serviço absurda
- saída extrema da linha
- movimento com portas abertas

Não punir excessivamente pequenas colisões provocadas pela IA do GTA.

## 63. Telemetria

Preferir informações verificáveis server-side sempre que possível.

Para eventos de alta frequência que precisem de client telemetry:

- `hardBrake`
- `collision`
- `hardAcceleration`

o client envia apenas:

- tipo do evento
- timestamp/session id

Nunca:

```lua
finalSafetyScore = 100
```

O servidor:

- aplica cooldown
- limita quantidade
- limita penalidade
- valida session
- nunca aceita score pronto

## 64. Base payout não depende totalmente da telemetria

Como parte da condução depende de informação client-side:

- base payout é definido pela rota
- score pode gerar bônus moderado
- client não consegue aumentar arbitrariamente o valor

Máximo sugerido de bônus por qualidade: **+20%**

## 65. Pontualidade

Cada linha deve possuir timetable.

Estrutura futura:

```lua
timing = {
    segmentTargets = {
        110,
        95,
        120,
        150,
    }
}
```

Representando segundos esperados entre paradas.

Não inventar tempos sem teste. Antes de release:

- dirigir cada linha normalmente
- medir
- executar várias amostras
- usar valor médio com tolerância

## 66. Janela de pontualidade

Exemplo:

- até 20s cedo → aceitável
- até 45s atrasado → aceitável

Chegar cedo demais não dá bônus. O jogador não deve ser incentivado a correr.

## 67. Qualidade final

Calcular:

```
finalScore = stopScore * 0.35 + safetyScore * 0.30 + punctualityScore * 0.20 + serviceScore * 0.15
```

Notas:

| Faixa | Conceito |
|---|---|
| 95–100 | S |
| 90–94 | A |
| 80–89 | B |
| 70–79 | C |
| 60–69 | D |
| <60 | E |

## 68. Pagamento

Pagamento somente após:

```
última parada
  → todos passageiros descem
  → retornar ao Dashound
  → estacionar corretamente
  → server validar
  → pagar
```

Não pagar por checkpoint.

## 69. Valores iniciais de desenvolvimento

Centralizar tudo em config.

Exemplo:

```lua
Config.Routes.small_metro.reward = {
    basePay = 180,
    baseXp = 120,
}

Config.Routes.industry.reward = {
    basePay = 220,
    baseXp = 150,
}

Config.Routes.medium_metro.reward = {
    basePay = 280,
    baseXp = 180,
}

Config.Routes.long_beach.reward = {
    basePay = 360,
    baseXp = 230,
}

Config.Routes.sandy_express.reward = {
    basePay = 520,
    baseXp = 300,
}

Config.Routes.long_rural.reward = {
    basePay = 700,
    baseXp = 380,
}
```

Esses valores são defaults de desenvolvimento. Não tratá-los como balanceamento econômico final.

## 70. Pagamento por passageiros

Pode existir componente moderado: `perPassenger = ...`

Mas aplicar limite. Exemplo:

```
basePay + passengerPay + qualityBonus
```

Não transformar passageiro em forma de farm infinito.

## 71. Fórmula conceitual

```lua
passengerBonus =
    math.min(
        passengersTransported * perPassenger,
        basePay * 0.25
    )

qualityBonus =
    calculateQualityBonus(finalScore)

finalPay =
    basePay +
    passengerBonus +
    qualityBonus
```

## 72. Qbox money

Pagamento ocorre exclusivamente server-side. Usar API atual do Qbox:

```lua
exports.qbx_core:AddMoney(
    source,
    'cash',
    finalPay,
    'bus-route-completed'
)
```

Não receber `finalPay` do client.

## 73. Finalização atômica

Finalização deve ocorrer uma única vez.

Ordem:

```
lock session
  → validate
  → mark finalized
  → DB transaction
       ├ XP
       ├ level
       ├ stats
       └ history
  → AddMoney
  → remove session
```

Evitar double payout.

## 74. Resumo final

Após estacionar:

```
LINHA C04 CONCLUÍDA

Costa Oeste

PARADAS            10 / 10
PASSAGEIROS             34

PARADAS                 96
SEGURANÇA               91
PONTUALIDADE            88
SERVIÇO                 94

AVALIAÇÃO                A

PAGAMENTO              $428
EXPERIÊNCIA           +246 XP
```

Se subir de nível:

```
NOVO NÍVEL

NÍVEL 4
MOTORISTA SÊNIOR

HORÁRIO DE PICO DESBLOQUEADO
```

## 75. Retorno ao depot

A última parada não significa pagamento.

Estado: `RETURNING_DEPOT`

HUD:

```
SERVIÇO ENCERRADO

RETORNE À GARAGEM
1,8 km
```

Chegando:

```
ESTACIONE O ÔNIBUS
```

Só então: `COMPLETING`

## 76. Cancelamento

Permitir cancelar linha.

Cancelamento normal:

- 0 dinheiro
- 0 XP

Não aplicar punição financeira automática.

Situações:

- jogador abandona ônibus
- veículo destruído
- job alterado
- duty desligado
- disconnect
- morte
- resource restart

## 77. Abandono do ônibus

Se sair:

```
RETORNE AO ÔNIBUS
60 segundos
```

Se retornar: continua.

Se não: cancel session + cleanup.

## 78. Server authority

Client deve enviar intenções, não resultados.

Permitido:

```lua
startRoute(routeId)
arrivedAtStop(sessionId)
toggleDoors(sessionId)
boardingComplete(sessionId)
requestCancel(sessionId)
parkVehicle(sessionId)
```

Proibido:

```lua
giveXP(5000)
payMe(25000)
routeComplete(100)
setLevel(10)
setPassengers(500)
```

## 79. Validação de início

Servidor verifica:

- Player existe
- `job.name == bus`
- `onduty == true`
- route existe
- level suficiente
- sem session ativa
- próximo do depot
- vehicle class disponível
- cooldown válido

Depois cria session.

## 80. Validação de parada

Quando client sinaliza chegada:

- session existe
- source é dono
- state correto
- vehicleNetId correto
- player é driver
- stop index correto
- posição próxima
- velocidade plausível
- ordem não foi pulada

Só então: `DOCKED`

## 81. Não aceitar stop index arbitrário

Client não envia `stopIndex = 9` como autoridade.

Servidor conhece `session.currentStopIndex`.

Client apenas pede: confirm current stop.

## 82. Não aceitar XP

Servidor possui `Config.Routes[routeId].reward.baseXp` e calcula todo o resto.

## 83. Ranking server-side

Leaderboard deve ser obtido por callback server-side.

Não enviar tabela SQL inteira ao client. Retornar somente DTO necessário:

```lua
{
    rank = 1,
    name = '...',
    level = 8,
    xp = 22400,
    routes = 118,
    averageScore = 92.4,
}
```

## 84. Arquitetura de arquivos

Estrutura sugerida:

```
qbx_busjob/
│
├── fxmanifest.lua
│
├── install.sql
│
├── locales/
│
├── shared/
│   ├── config.lua
│   ├── routes.lua
│   ├── stops.lua
│   ├── progression.lua
│   └── vehicles.lua
│
├── client/
│   ├── main.lua
│   ├── state.lua
│   ├── depot.lua
│   ├── route.lua
│   ├── stops.lua
│   ├── passengers.lua
│   ├── doors.lua
│   ├── telemetry.lua
│   ├── hud.lua
│   └── cleanup.lua
│
├── server/
│   ├── main.lua
│   ├── sessions.lua
│   ├── progression.lua
│   ├── leaderboard.lua
│   ├── passengers.lua
│   ├── rewards.lua
│   ├── security.lua
│   └── cleanup.lua
│
└── ui/
    ├── src/
    │   ├── App.*
    │   ├── components/
    │   ├── pages/
    │   │   ├── Routes.*
    │   │   ├── Progression.*
    │   │   └── Leaderboard.*
    │   └── hud/
    │       ├── RouteHud.*
    │       └── RouteSummary.*
    └── dist/
```

Não quebrar a arquitetura atual desnecessariamente caso já exista padrão melhor no resource.

## 85. NUI messaging

NUI deve receber estado declarativo.

Exemplo:

```lua
SendNUIMessage({
    action = 'bus:setJobData',
    data = {
        driver = profile,
        routes = routes,
        leaderboard = leaderboard,
    }
})
```

HUD:

```lua
SendNUIMessage({
    action = 'bus:setRouteHud',
    data = {
        visible = true,
        routeCode = 'M03',
        routeName = 'Metropolitana',

        stopName = 'Marathon Ave',
        stopIndex = 4,
        stopCount = 9,

        distance = 620,

        passengers = 7,
        capacity = 11,

        scheduleDelta = 18,
    }
})
```

Evitar dezenas de mensagens (`hideA`, `showB`, `toggleC`, `updateD`) quando um único snapshot de estado resolve.

## 86. Transparência NUI

Obrigatório:

```css
html,
body,
#root {
    width: 100%;
    height: 100%;
    margin: 0;
    overflow: hidden;
    background: transparent !important;
}
```

Nunca criar fullscreen black background fora do que `NUI_JOB.md` explicitamente definir como modal/surface.

## 87. Responsividade

Validar:

- 1280×720
- 1920×1080
- 2560×1440
- 3440×1440
- 3840×1600

A NUI principal deve seguir `NUI_JOB.md`.

HUD deve:

- usar safe zone
- não depender apenas de `vw`
- permanecer compacto em ultrawide
- não invadir minimapa
- não invadir HUD do veículo
- manter hierarquia em 720p

## 88. Performance

Meta arquitetural:

Em idle: nenhuma thread `Wait(0)` desnecessária.

Fora do emprego: praticamente zero trabalho contínuo.

Durante linha:

- atualizar GPS somente quando necessário
- passageiros apenas perto da parada
- telemetria em intervalos adequados
- não enviar NUI message a cada frame
- não buscar leaderboard durante gameplay
- não fazer query SQL por parada

O rewrite comunitário do qb-busjob também é uma referência útil de modularização e redução do trabalho permanente por frame.

## 89. Intervalos sugeridos

| Tarefa | Intervalo |
|---|---|
| vehicle/session sanity | 1000 ms |
| distance to remote stop | 500–1000 ms |
| near current stop | 100–250 ms |
| telemetry | 250–500 ms |
| HUD numeric refresh | 250–500 ms |
| leaderboard cache | 30–60 s |

`Wait(0)` somente quando realmente necessário por poucos segundos/contextos.

## 90. NPC cleanup

Remover passageiros quando:

- desembarcam e se afastam
- linha cancela
- linha termina
- player disconnect
- vehicle destroyed
- resource stop

Nunca deixar NPCs antigos na cidade.

## 91. Blips

Manter somente o objetivo atual (`current stop` ou `depot`).

Nunca deixar todas as paradas marcadas simultaneamente.

## 92. GPS

Fluxo:

```
linha inicia
  → GPS primeira parada

parada concluída
  → remove route antiga
  → GPS próxima parada

última parada
  → GPS depot
```

## 93. Debug tooling

Criar:

```lua
Config.Debug = false
```

Quando ativo:

- desenhar stop radius
- mostrar stop ID
- mostrar coords
- heading
- session state
- currentStop
- passenger manifest
- score
- target time

Comandos dev opcionalmente:

```
/busdebug
/busnext
/busprofile
/busroute <id>
```

Protegidos adequadamente ou somente em debug/dev.

## 94. Métricas para balanceamento

Adicionar logs debug da conclusão:

- route
- duration
- passengers
- score
- pay
- xp
- player level

Isso permitirá ajustar:

- dinheiro
- XP
- duração
- demanda
- dificuldade

## 95. Migração do código antigo

Remover:

- `NpcPay`
- single-NPC route loop
- payment per boarding
- old route index globals
- legacy NPC lifecycle

Não deixar código morto comentado. Não manter:

```lua
-- old system
-- TODO maybe use later
```

O Git já guarda histórico.

## 96. Compatibilidade

Manter como dependências principais:

- `qbx_core`
- `ox_lib`
- `oxmysql`

Não introduzir:

- QBCore legacy bridge desnecessária
- skill framework externo
- XP framework
- leaderboard externo
- Asset Escrow
- Keymaster dependency adicional

## 97. Separação entre Qbox e Bus Progression

Deixar isso explícito em documentação e código:

**QBOX JOB** (`"bus"`) define:

- pode trabalhar ou não
- duty
- pagamento

**BUS PROGRESSION** define:

- level
- XP
- ranking
- linhas
- veículos
- estatísticas

Uma coisa nunca deve substituir a outra.

## 98. Gameplay final esperado

```
JOGADOR CHEGA AO DASHOUND
              ↓
      abre Central
              ↓
┌──────────────────────────┐
│ TRANSPORTE PÚBLICO       │
│                          │
│ Nível 3                  │
│ Operador Municipal       │
│ 3.820 / 5.000 XP         │
│ Ranking #27              │
│                          │
│ LINHAS                   │
│ PROGRESSÃO               │
│ RANKING                  │
└──────────────────────────┘
              ↓
       seleciona M03
              ↓
        INICIAR LINHA
              ↓
       ônibus spawnado
              ↓
      NUI principal fecha
              ↓
      GPS primeira parada
              ↓
        dirige até lá
              ↓
      posiciona ônibus
              ↓
       [G] abrir portas
              ↓
 passageiros desembarcam
              ↓
 passageiros embarcam
              ↓
       [G] fechar portas
              ↓
       próxima parada
              ↓
             ...
              ↓
        última parada
              ↓
 todos passageiros descem
              ↓
      RETORNE À GARAGEM
              ↓
       estaciona ônibus
              ↓
     servidor valida tudo
              ↓
       pagamento + XP
              ↓
       resumo da linha
              ↓
        ranking atualizado
```

## 99. MVP obrigatório

A primeira versão não deve ser considerada concluída sem:

- [ ] linhas reais
- [ ] dataset compartilhado de paradas
- [ ] 6 linhas iniciais
- [ ] progressão própria
- [ ] SQL próprio
- [ ] 10 níveis
- [ ] XP
- [ ] desbloqueio por nível
- [ ] ranking
- [ ] passageiros múltiplos
- [ ] passageiros com destinos diferentes
- [ ] capacidade
- [ ] embarque
- [ ] desembarque
- [ ] portas manuais
- [ ] avaliação da parada
- [ ] qualidade de condução
- [ ] retorno ao depot
- [ ] payout somente no final
- [ ] XP somente no final
- [ ] session server-side
- [ ] NUI conforme `NUI_JOB.md`
- [ ] HUD durante condução
- [ ] cleanup robusto

## 100. Fora do MVP

Preparar arquitetura, mas não atrasar release inicial por:

- passageiro cadeirante
- turistas especiais
- eventos de trânsito
- desvios dinâmicos
- linhas temporariamente fechadas
- ônibus quebrando
- conexão entre jogadores
- empresa administrada por players
- passes/tickets físicos
- tour guide
- NPC motorista

Podem ser implementados depois.

## 101. Testes funcionais obrigatórios

#### Progressão

- [ ] novo motorista começa level 1
- [ ] XP carrega após reconnect
- [ ] XP não utiliza Qbox metadata
- [ ] level é derivado corretamente
- [ ] múltiplos level ups funcionam
- [ ] linha bloqueada não pode iniciar
- [ ] restart não perde XP

#### Rotas

- [ ] M01 completa
- [ ] I02 completa
- [ ] M03 completa
- [ ] C04 completa
- [ ] X05 completa
- [ ] R06 completa
- [ ] stop não pode ser pulado
- [ ] stop anterior não pode ser repetido para farm
- [ ] GPS avança corretamente
- [ ] último ponto retorna ao depot

#### Passageiros

- [ ] múltiplos embarcam
- [ ] destinos são posteriores ao embarque
- [ ] passageiros descem na parada correta
- [ ] capacidade é respeitada
- [ ] terminal esvazia ônibus
- [ ] ped travado não trava linha
- [ ] cancelamento remove peds

#### Portas

- [ ] G abre
- [ ] G fecha
- [ ] não abre em alta velocidade
- [ ] não abre fora do ponto
- [ ] não quebra veículos custom
- [ ] índices inválidos são ignorados

#### Segurança

- [ ] client não consegue escolher payout
- [ ] client não consegue escolher XP
- [ ] client não consegue escolher level
- [ ] evento duplicado não paga duas vezes
- [ ] conclusão fora do depot é rejeitada
- [ ] conclusão com linha incompleta é rejeitada
- [ ] outro veículo não completa sessão
- [ ] outro player não consegue completar sessão
- [ ] routeId bloqueado é rejeitado

#### Ranking

- [ ] top drivers correto
- [ ] desempate correto
- [ ] jogador fora do top é informado de sua posição
- [ ] nenhum identifier privado aparece na NUI
- [ ] cache funciona

## 102. Testes multiplayer

Testar no mínimo:

- 2 motoristas na mesma linha
- 2 motoristas em linhas diferentes

As sessões precisam ser independentes.

Nunca usar um global server:

```lua
CurrentBusRoute = ...
```

Usar:

```lua
activeSessions[source]
```

## 103. Testes de performance

Medir Resource Monitor em:

- fora do emprego
- no depot
- dirigindo
- aproximando parada
- 5 NPCs embarcando
- 5 NPCs desembarcando
- linha longa

Objetivo: idle praticamente 0.00 ms, e custo durante gameplay concentrado apenas quando existe trabalho real.

Não sacrificar gameplay por números artificiais, mas eliminar polling permanente desnecessário.

## 104. Testes de resolução da NUI

Obrigatório testar:

- 1280×720
- 1920×1080
- 2560×1440
- 3440×1440
- 3840×1600

Verificar:

- lista
- textos longos
- ranking
- progressão
- HUD
- safe zones
- scroll
- foco
- navegação por teclado

## 105. Critério final de implementação

O novo `qbx_busjob` não deve parecer um checkpoint job com XP adicionado por cima.

Ele deve parecer um sistema coerente de transporte público:

```
linha
  → paradas
  → passageiros
  → procedimento
  → qualidade
  → conclusão
  → carreira
```

O núcleo da experiência deve continuar simples para um jogador novo:

```
escolher linha
  → dirigir
  → parar
  → abrir portas
  → fechar portas
  → continuar
```

Toda a profundidade adicional deve existir ao redor desse loop sem torná-lo burocrático.

## 106. Entrega esperada do agente

Ao finalizar, apresentar:

- arquivos alterados
- arquivos novos
- migrations SQL
- state machine implementada
- lista das seis linhas
- lista das paradas importadas/ajustadas
- progressão implementada
- fórmula de XP
- fórmula de payout
- estrutura do leaderboard
- eventos client/server
- callbacks
- key mappings
- NUI implementada conforme `NUI_JOB.md`
- mudanças de segurança
- cleanup implementado
- resultados de Resmon
- resoluções de NUI testadas
- funcionalidades antigas removidas
- limitações conhecidas

Nenhuma funcionalidade antiga deve permanecer apenas por compatibilidade se ela comprometer a nova arquitetura.
