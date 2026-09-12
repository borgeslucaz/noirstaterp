# Proposta de implementação — Outposts e venda passiva por NPC

> **Status:** especificação técnica para implementação  
> **Resource proposto:** `noir_outposts`  
> **Stack:** Qbox, `ox_lib`, `oxmysql`, `ox_inventory`, `ox_target`, `bgrz_core`, `noir_illegal_core`, `noir_gangs` e `sd-phone`

## 1. Objetivo

Criar um sistema próprio do Noir State no qual organizações criminosas disputam outposts, contratam dealers NPC, abastecem estoque e recebem o resultado de vendas passivas. O sistema deve complementar — e não substituir — a venda ativa jogador → NPC já oferecida pelo `op-drugselling`.

A referência Juice-CornerBoys combina territórios, contratação de NPCs, estoque por produto, carteira acumulada, progressão, compradores a pé/de carro e risco de roubo.[1] O `prp-outposts` acrescenta outposts ativos rotativos, controle por KingPin/grupo, dealers com atributos, venda passiva, lavagem, alertas policiais e cartões de acesso com metadata.[2]

A implementação recomendada aproveita esses conceitos, mas mantém regras, banco e código próprios. Não se deve copiar código protegido ou criar dependência runtime desses produtos.

---

## 2. Decisão de arquitetura

### 2.1 Resource separado

Implementar em:

```text
resources/[bgrz]/noir_outposts/
```

Não alterar o core de `op-drugselling`. O resource existente continua responsável pelo loop ativo de rua (`/venderdrogas`), enquanto `noir_outposts` será responsável por:

- seleção e rotação dos outposts;
- posse por organização;
- contratação e implantação dos dealers;
- estoque virtual controlado pelo servidor;
- agenda de vendas passivas;
- carteira por dealer/outpost;
- roubos e retomadas;
- progressão via `noir_illegal_core`;
- UI no computador e aplicativo no `sd-phone`.

Essa separação evita acoplamento com um script de terceiros, permite balancear as duas formas de venda independentemente e preserva uma única autoridade sobre cada domínio.

### 2.2 Limite do MVP

O MVP deve implementar primeiro o **outpost de drogas**. O outpost de lavagem pode entrar na segunda fase usando a mesma infraestrutura, sem bloquear o lançamento da mecânica principal.

Escopo do MVP:

1. três locais cadastrados;
2. um ou dois locais ativos por ciclo;
3. posse por organização;
4. até quatro dealers por outpost;
5. estoque de `weed_brick`, `meth` e `cokebaggy`;
6. venda passiva server-side;
7. carteira em dinheiro sujo;
8. coleta pelo líder autorizado;
9. roubo de dealer;
10. dispatch com cooldown;
11. painel no computador;
12. notificações no telefone.

Fase posterior:

- outpost de lavagem de `black_money`;
- compradores visuais a pé e em veículos;
- cartões e pistas;
- disputa organizada com janela de ataque;
- upgrades permanentes e histórico detalhado.

---

## 3. Compatibilidade com o servidor atual

### 3.1 Recursos já disponíveis

A inspeção do servidor encontrou:

| Capacidade | Resource atual | Uso proposto |
|---|---|---|
| Framework | `qbx_core` | identidade e jobs, sempre via bridge próprio |
| Bridge genérico | `bgrz_core` | dinheiro, personagem e notificações |
| Progressão ilegal | `noir_illegal_core` | reputação, heat, unlocks e ledger idempotente |
| Organizações | `noir_gangs` | identidade persistente do grupo dono |
| Inventário | `ox_inventory` | itens dos jogadores, exclusivamente pelo adapter do `bgrz_core` |
| Interação | `ox_target` | provider atual de target, encapsulado pelo `bgrz_core` |
| UI/utilitários | `ox_lib` | callbacks, progress, dialogs, zones e locale |
| Banco | `oxmysql` | schema próprio do resource |
| Telefone | `sd-phone` | provider atual de app/notificações, encapsulado pelo `bgrz_core` |
| Venda ativa | `op-drugselling` | catálogo econômico de referência, sem chamada ao core protegido |
| Doorlock | `ox_doorlock` | provider opcional de portas, encapsulado pelo `bgrz_core` |

### 3.2 Catálogo já existente

O `op-drugselling/config/MainConfig.lua` já trabalha com os itens:

| Item | Faixa configurada | Máximo por venda ativa |
|---|---:|---:|
| `weed_brick` | 50–100 | 5 |
| `meth` | 150–250 | 7 |
| `cokebaggy` | 450–700 | 4 |

Os quatro itens necessários (`weed_brick`, `meth`, `cokebaggy` e `black_money`) já existem em `ox_inventory/data/items.lua`.

**Regra econômica:** `noir_outposts` terá IDs, labels e ícones públicos em `config/shared.lua`, mas preço, quantidade real, requisitos e multiplicadores ficam em `config/server.lua`. Os preços devem ser calibrados em conjunto com `op-drugselling`. Venda passiva precisa render menos por unidade do que venda ativa, porque reduz exposição e trabalho do jogador.

Sugestão inicial:

```lua
products = {
    weed_brick = {
        label = 'Tijolo de maconha',
        unitPrice = 55,
        quantity = { min = 1, max = 2 },
        requiredDrugLevel = 1,
    },
    meth = {
        label = 'Metanfetamina',
        unitPrice = 155,
        quantity = { min = 1, max = 3 },
        requiredDrugLevel = 2,
    },
    cokebaggy = {
        label = 'Pacote de cocaína',
        unitPrice = 460,
        quantity = { min = 1, max = 2 },
        requiredDrugLevel = 3,
    },
}
```

Esses valores são ponto de partida, não valores finais de produção.

### 3.3 Lacunas que devem ser resolvidas antes do resource

1. `bgrz_core` ainda não expõe contratos completos para inventário, target, phone, dispatch e doorlock.
2. `noir_illegal_core/shared/activities.lua` aceita `drug_sale` apenas do caller `noir_illegal_core`; `noir_outposts` precisa ser incluído ou receber uma activity própria.
3. O dispatch do `op-drugselling` está configurado como `none`; não se deve assumir que existe integração policial funcional nem chamá-lo como provider do novo resource.
4. O item `outposts_exchange_card` e os itens de pista ainda não existem.
5. Não existe hoje um resource implementado de território/outpost; há especificações em `resources/docs/ilegal`, mas não runtime pronto para reutilização.

---

## 4. Integrações obrigatórias

### 4.1 `bgrz_core`

Antes de implementar o resource, adicionar ao bridge APIs pequenas, documentadas e testadas para todas as capacidades de provider usadas: inventário, target, phone, dispatch e doorlock. `noir_outposts` não chama `qbx_core`, `ox_inventory`, `ox_target`, `sd-phone`, `ox_doorlock` ou o dispatch instalado diretamente.

Contrato sugerido:

```lua
---@param holder number|string source do jogador ou id interno permitido de stash
---@param item string
---@param amount integer
---@param metadata? table
---@return boolean ok, string? errorCode
exports('AddItem', function(holder, item, amount, metadata) end)

exports('RemoveItem', function(holder, item, amount, metadata) end)
exports('GetItemCount', function(holder, item, metadata) end)
exports('CanCarryItem', function(holder, item, amount, metadata) end)

---@return boolean ok, string? errorCode
exports('AddEntityTarget', function(entityOrNetId, options) end)
exports('RemoveEntityTarget', function(entityOrNetId, optionNames) end)

exports('RegisterPhoneApp', function(definition) end) -- client-side
exports('SendPhoneNotification', function(source, payload) end) -- server-side
exports('SendDispatch', function(request) end) -- server-side
exports('SetDoorAccess', function(doorId, state, context) end) -- server-side
```

Regras:

- validar item por allowlist no consumidor;
- aceitar somente quantidade inteira, positiva e limitada;
- normalizar erros do provider;
- não receber preço, recompensa ou item arbitrário do client;
- registrar `reason`/contexto nas operações econômicas quando o provider permitir;
- usar `bgrz_core:AddMoney`/`RemoveMoney` para dinheiro de conta;
- usar o adapter de inventário para `black_money`, caso o payout seja item.
- retornar `provider_unavailable` sem explodir o consumidor quando integração opcional estiver parada;
- manter no `bgrz_core` somente tradução genérica de provider; nomes, textos e regras dos outposts continuam em `noir_outposts`;
- documentar capability/version handshake e testar cada adapter com fake + provider real.

### 4.2 `noir_illegal_core`

Adicionar activities específicas para separar telemetria e balanceamento:

```lua
NoirIllegal.Activities.outpost_claim = {
    enabled = true,
    callers = { 'noir_outposts' },
    cooldownSeconds = 0,
    personal = { street = 2 },
    organization = { street = 5 },
    heat = 2.0,
    requirements = { organization = true },
    metadata = { allow = { 'outpostId', 'previousOwnerId' } },
}

NoirIllegal.Activities.outpost_sale = {
    enabled = true,
    callers = { 'noir_outposts' },
    cooldownSeconds = 0,
    personal = { drug = 0 },
    organization = { drug = 1 },
    heat = 0.10,
    diminishingReturns = {
        windowSeconds = 3600,
        softCap = 30,
        floorMultiplier = 0.20,
        curve = 'linear',
        key = 'organization:activity',
    },
    requirements = { organization = true },
    metadata = { allow = { 'outpostId', 'dealerId', 'product', 'quantity' } },
}

NoirIllegal.Activities.outpost_robbery = {
    enabled = true,
    callers = { 'noir_outposts' },
    cooldownSeconds = 900,
    personal = { street = 2 },
    organization = {},
    heat = 4.0,
    requirements = {},
    metadata = { allow = { 'outpostId', 'dealerId', 'lootValue' } },
}
```

Também adicionar `noir_outposts` em `noir_illegal_core/shared/permissions.lua` apenas para operações privilegiadas realmente necessárias. Para vendas comuns, preferir `RecordActivity`, que já valida o caller declarado na definição da activity.

A posse do outpost deve guardar o `organization.id` retornado por:

```lua
exports.noir_illegal_core:GetOrganization(source)
```

Nunca persistir `source` como dono: ele muda a cada conexão.

### 4.3 `noir_gangs`

Usar a organização retornada pelo bridge do `noir_illegal_core` como identidade canônica. A autorização precisa ser baseada em:

- `organizationId` atual do jogador;
- rank/grade do membro;
- permissões configuradas (`claim`, `hire`, `stock`, `collect`, `fire`);
- revalidação server-side no momento de cada ação.

Configuração sugerida:

```lua
permissions = {
    claim = 3,
    hire = 2,
    fire = 2,
    stock = 1,
    collect = 3,
    view = 0,
}
```

Se `noir_gangs` não expuser grade/permissões por export, ampliar seu contrato ou o bridge de gangs do `noir_illegal_core`. Não consultar tabelas internas de outro resource.

### 4.4 `sd-phone`

Registrar um app customizado, por exemplo `exchange`, através do contrato client-side proposto no `bgrz_core`. O adapter traduz esse payload para o export atual do `sd-phone`:

```lua
exports.bgrz_core:RegisterPhoneApp({
    identifier = 'exchange',
    name = 'The Exchange',
    description = 'Rede de operações clandestinas',
    ui = 'https://cfx-nui-noir_outposts/html/phone/index.html',
    icon = 'https://cfx-nui-noir_outposts/html/assets/exchange.webp',
    requires = {
        item = 'outposts_exchange_card',
    },
})
```

O adapter deve confirmar e normalizar o formato usado pelo `sd-phone` no momento da implementação. A documentação local do provider alerta que o gate controla somente a visibilidade do ícone; todos os callbacks continuam exigindo autorização no servidor. O resource consumidor nunca depende dessa forma específica.

Para notificações online:

```lua
exports.bgrz_core:SendPhoneNotification(source, {
    app = 'The Exchange',
    appId = 'exchange',
    title = 'Venda concluída',
    body = 'Um runner concluiu uma venda no outpost.',
})
```

Notificar apenas membros online e autorizados da organização. Não enviar uma notificação por venda em servidores movimentados; agregar em janelas de 30–60 segundos ou enviar somente eventos importantes.

### 4.5 Dispatch

Criar `SendDispatch` no `bgrz_core`. O provider e seu formato específico devem existir apenas no adapter server-side do bridge.

Contrato sugerido:

```lua
exports('SendDispatch', function(request)
    -- request.code, title, message, coords, jobs, duration, radius
end)
```

Política inicial:

- chance por venda: 10%;
- cooldown do alerta por outpost: 180 segundos;
- código: `10-90`;
- blip aproximado, não coordenada perfeita;
- duração: 150 segundos;
- jobs: `police` e equivalentes configurados;
- roubo dispara alerta independente com chance maior;
- nunca aceitar coords, código ou chance enviados pelo client.

O `prp-outposts` descreve chance de 10% por venda e blip policial temporário.[2] O cooldown local é uma adaptação necessária para impedir spam de dispatch quando vários dealers vendem simultaneamente.

### 4.6 Configuração e sigilo

Cada arquivo de configuração retorna uma tabela e nunca é usado como storage mutável de runtime.

```text
config/shared.lua  → IDs, labels, modelos/coords públicos e limites visuais
config/client.lua  → apresentação, distâncias visuais e debug local
config/server.lua  → preços, payouts, chances, rate limits, requisitos e providers
```

Nenhum segredo, webhook, regra anti-exploit ou valor econômico que não precise ser público fica em shared config ou NUI. Textos de jogador ficam em `locales/pt-br.json`, com códigos de erro estáveis separados da tradução.

---

## 5. Loop de gameplay

### 5.1 Ciclo global

1. No boot ou na rotação diária, o servidor escolhe os outposts ativos.
2. Um local recebe tipo `drug`; opcionalmente outro recebe tipo `money`.
3. Uma organização elegível inicia a tomada pelo computador.
4. Após progress bar validada no servidor, a organização vira controladora.
5. Líderes contratam até quatro dealers.
6. Membros abastecem o estoque pelo painel ou por encontro com o NPC.
7. Cada dealer processa vendas em seu próprio intervalo.
8. Receita líquida acumula na carteira do outpost/dealer.
9. Líder autorizado coleta a carteira.
10. Rivais podem roubar dealers ou disputar o controle em janela válida.
11. No fim do ciclo, dealers e posse são encerrados ou migrados conforme configuração.

Esse loop preserva o modelo de “contratar, abastecer, deixar vender e coletar” da primeira referência.[1] O limite de quatro dealers e a rotação de posições seguem a estrutura documentada do `prp-outposts`.[2]

### 5.2 Estado do outpost

```text
INACTIVE
  └── rotação ──> AVAILABLE
                    └── claim iniciado ──> CLAIMING
                                            ├── cancelado/falhou ──> AVAILABLE
                                            └── concluído ──> CONTROLLED
CONTROLLED
  ├── janela de disputa ──> CONTESTED
  │                           ├── defesa ──> CONTROLLED
  │                           └── tomada ──> COOLDOWN ──> CONTROLLED
  └── expiração/rotação ──> INACTIVE
```

Toda transição deve ocorrer no servidor e ser persistida. A NUI apenas apresenta o snapshot.

### 5.3 Regras de claim

Recomendação inicial:

```lua
claim = {
    durationMs = 45000,
    interactionDistance = 2.0,
    minOnlinePlayers = 8,
    minPolice = 2,
    requiresOrganization = true,
    requiredGangGrade = 3,
    ownerDurationHours = 24,
    defendCooldownMinutes = 30,
}
```

Antes de iniciar e antes de concluir, validar novamente:

- jogador conectado e personagem carregado;
- organização e grade atuais;
- outpost ativo e no estado correto;
- quantidade de jogadores/polícia;
- distância server-side do computador;
- ped vivo e não algemado, se a API estiver disponível;
- ausência de outro claim em andamento;
- cooldown da organização;
- cartão válido, se essa fase estiver habilitada.

### 5.4 Dealers

Cada perfil contém:

```lua
{
    key = 'ghost',
    name = 'Ghost',
    model = `g_m_y_mexgang_01`,
    description = 'Discreto, porém exige participação maior.',
    hirePrice = 6500,
    stats = {
        speed = 70,
        capacity = 55,
        negotiation = 60,
        split = 18,
    },
}
```

Interpretação:

- `speed`: reduz intervalo entre vendas;
- `capacity`: define estoque operacional do dealer ou lote máximo;
- `negotiation`: modifica discretamente preço e chance de sucesso;
- `split`: percentual removido da receita bruta;
- `hirePrice`: pago uma vez por contratação/ciclo.

A segunda referência descreve doze perfis com preço e quatro atributos equivalentes (`speed`, `weight`, `talking`, `split`).[2] Para o MVP, seis perfis bem balanceados são suficientes; expandir para doze após telemetria.

### 5.5 Scheduler de venda passiva

Não criar uma thread por dealer e não depender de client online para calcular dinheiro. Manter um scheduler server-side único:

```text
A cada 5 segundos:
  1. buscar dealers ativos com next_sale_at <= agora;
  2. adquirir lock lógico por dealer;
  3. conferir outpost CONTROLLED e estoque disponível;
  4. sortear produto/quantidade dentro da allowlist;
  5. calcular bruto, split, líquido e heat;
  6. executar uma transação SQL;
  7. agendar next_sale_at;
  8. registrar activity/evento;
  9. notificar/dispatch fora da transação;
```

Implementar com `SetTimeout` rearmado ou loop que obrigatoriamente chama `Wait(5000)`. O scheduler encerra no stop e não executa query, native ou varredura a cada frame.

Fórmula inicial:

```text
intervalo = baseInterval * (1.20 - speed / 100)
preçoUnitário = preçoBase * aleatório(0.95, 1.05) * (1 + negotiation / 1000)
bruto = quantidade * preçoUnitário
comissão = floor(bruto * split / 100)
líquido = bruto - comissão
```

Limites obrigatórios:

- `intervalo` mínimo de 30 segundos;
- variação de preço pequena e server-side;
- quantidade limitada pelo produto, pelo dealer e pelo estoque;
- sem catch-up ilimitado após restart;
- processar no máximo uma venda atrasada por dealer ao iniciar;
- pausar vendas se o owner expirar, estoque acabar ou outpost entrar em disputa;
- opcionalmente exigir ao menos um membro da organização online.

**Decisão de performance:** a venda econômica é simulada no servidor. Compradores a pé/de carro são ambientação opcional para players próximos, nunca a autoridade da venda. Isso evita spawn global de dezenas de compradores, peds órfãos e pagamentos dependentes de network ownership.

### 5.6 Estoque virtual, não stash livre

Para o MVP, guardar estoque em tabela própria, não ler continuamente um stash aberto de `ox_inventory`.

Fluxo de depósito:

1. player escolhe item e quantidade na UI;
2. servidor valida organização, permissão, distância e allowlist;
3. cria `operation_id` único com estado `prepared`;
4. remove o item do inventário via `bgrz_core`;
5. incrementa o estoque em transação SQL;
6. marca operação como `committed`;
7. se o SQL falhar, devolve exatamente os itens removidos e marca `compensated`.

Esse modelo torna o loop de vendas totalmente transacional dentro das tabelas do resource. Abrir um stash genérico facilita transferência não auditada e cria uma transação distribuída difícil entre o banco do inventário e o banco do domínio.

### 5.7 Coleta da carteira

Escolher uma política e não misturar duas fontes de verdade:

- **Recomendado:** `purse` persistida em SQL e payout como item `black_money`;
- alternativa: payout em `cash` via `bgrz_core:AddMoney`;
- nunca manter simultaneamente purse em SQL e pilhas equivalentes em stash.

Fluxo idempotente:

1. criar `collection_id` único;
2. travar a linha do outpost;
3. mover valor de `purse_available` para `purse_pending`;
4. tentar entregar `black_money`;
5. marcar como `paid` em caso de sucesso;
6. em falha de capacidade, restaurar para `available`;
7. retry do mesmo `collection_id` não pode pagar novamente.

### 5.8 Roubo de dealer

Qualquer jogador que não pertença ao owner pode mirar um dealer ativo. A referência `prp-outposts` usa progress bar de 12,5 segundos e transfere dinheiro/drogas carregados pelo dealer.[2]

Proposta:

- duração: 12,5 segundos;
- cooldown por dealer: 20 minutos;
- apenas um assalto por dealer de cada vez;
- dealer precisa estar `DEPLOYED` e não saqueado;
- robber deve estar a até 2,5 m no início e na conclusão;
- animação, arma/ameaça e estado do ped podem ser requisitos configuráveis;
- loot limitado a uma porcentagem de purse + lote operacional;
- o estoque central inteiro nunca deve ficar exposto em um único roubo;
- dispatch com chance de 50–100%, conforme balanceamento;
- dealer entra em `RECOVERING` e retorna depois de cooldown;
- registrar activity, audit log e transaction ID.

O roubo não deve aceitar `dealerId`, item, quantidade ou valor sem resolver tudo no servidor.

---

## 6. Outposts, posições e acesso

### 6.1 Configuração de locais

```lua
outposts = {
    docks = {
        label = 'Terminal de Elysian',
        typePool = { 'drug', 'money' },
        computer = vec3(0.0, 0.0, 0.0),
        entrance = vec3(0.0, 0.0, 0.0),
        doorId = nil,
        dealerCorners = {
            vec4(0.0, 0.0, 0.0, 0.0),
            vec4(0.0, 0.0, 0.0, 0.0),
            vec4(0.0, 0.0, 0.0, 0.0),
            vec4(0.0, 0.0, 0.0, 0.0),
            vec4(0.0, 0.0, 0.0, 0.0),
            vec4(0.0, 0.0, 0.0, 0.0),
        },
        dispatch = {
            radius = 80.0,
            label = 'Atividade suspeita',
        },
    },
}
```

Cadastrar pelo menos seis `dealerCorners` por local, mesmo com limite de quatro NPCs. A cada 20 minutos, rotacionar dealers para posições livres, como descrito na referência de outposts.[2]

As coordenadas acima são placeholders e devem ser capturadas in-game.

### 6.2 Seleção de locais ativos

Algoritmo diário:

1. ler `rotation_date` persistida em UTC;
2. se já existe rotação válida, restaurá-la;
3. senão, sortear locais distintos;
4. atribuir exatamente um `drug` e opcionalmente um `money`;
5. salvar antes de anunciar;
6. encerrar dealers de locais desativados;
7. publicar snapshot aos clients.

O `prp-outposts` seleciona dois de três locais no start, sendo um de dinheiro e outro de drogas.[2] Para evitar reroll explorável em restart, o sorteio do Noir deve ser persistido por data/ciclo.

### 6.3 Cartão de acesso

Fase 2:

```lua
['outposts_exchange_card'] = {
    label = 'Cartão da Exchange',
    weight = 10,
    stack = false,
    close = true,
    description = 'Credencial temporária de acesso.',
}
```

Metadata obrigatória:

```lua
{
    outpost = 'docks',
    validUntil = 1780000000,
    issuedTo = 'organization-id',
    nonce = 'opaque-id',
}
```

A referência usa metadata `outpost` para liberar o local correspondente por aquele dia.[2] No Noir, também validar expiração, organização e nonce server-side. A porta física pode ser integrada ao `ox_doorlock`, mas destrancar a porta não concede autorização econômica.

---

## 7. Entidades, target e cleanup

### 7.1 Dealer NPC

Preferir ped networked criado pelo servidor/OneSync. Cada entidade recebe somente state bags não sensíveis:

```text
noir:outpostId
noir:dealerId
noir:dealerState
```

Não armazenar saldo, estoque, owner completo ou permissão em state bag.

O client usa `bgrz_core:AddEntityTarget(netId, options)`; o adapter atual traduz para `ox_target` e exibe:

- conversar/abrir painel;
- abastecer, se autorizado;
- coletar, se autorizado;
- roubar, se rival;
- inspecionar status básico.

Cada callback target revalida no servidor:

- net ID resolve para a entidade registrada;
- modelo e dealer correspondem;
- distância server-side;
- mesmo routing bucket;
- estado válido;
- organização e grade atuais;
- rate limit.

### 7.2 Compradores visuais

Fase 2 opcional:

- somente clientes dentro de 80–100 m recebem vignette;
- um host visual é eleito ou cada client renderiza peds locais não networked;
- buyer caminha/dirige até perto do dealer, executa cenário e vai embora;
- nenhuma entidade visual decide venda, preço ou estoque;
- limitar a um buyer visual por outpost;
- se não houver player próximo, a venda continua sem animação.

O Juice-CornerBoys destaca compradores a pé/de carro e cleanup ao sair/reiniciar.[1] A separação entre simulação econômica e ambientação preserva essa experiência sem tornar client ou ped autoridade financeira.

### 7.3 Cleanup obrigatório

Executar cleanup em:

- rotação do outpost;
- demissão do dealer;
- dealer saqueado/desativado;
- troca de owner;
- `onResourceStop`;
- restart de dependência;
- entidade removida;
- configuração inválida;
- reset administrativo.

Cleanup precisa ser idempotente e remover:

- peds e props;
- opções de target;
- zonas;
- locks em memória;
- timers/agenda não persistida;
- foco NUI;
- registros de entidades, mesmo se a entidade já não existir.

Também limpar sessões transitórias de claim, roubo, depósito e coleta em `playerDropped`, player unload, morte/estado inválido, timeout e mudança de organização/grade. Todo carregamento de model/anim dict deve ter timeout; models devem ser validados, allowlisted e liberados com `SetModelAsNoLongerNeeded`.

---

## 8. Banco de dados

### 8.1 Tabelas propostas

```sql
CREATE TABLE noir_outposts (
    id VARCHAR(40) PRIMARY KEY,
    status VARCHAR(20) NOT NULL,
    operation_type VARCHAR(16) NULL,
    rotation_id BIGINT UNSIGNED NULL,
    owner_organization_id VARCHAR(64) NULL,
    kingpin_citizenid VARCHAR(64) NULL,
    claimed_at DATETIME NULL,
    expires_at DATETIME NULL,
    purse_available BIGINT UNSIGNED NOT NULL DEFAULT 0,
    purse_pending BIGINT UNSIGNED NOT NULL DEFAULT 0,
    version INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_outposts_owner (owner_organization_id),
    INDEX idx_outposts_rotation (rotation_id, status)
);

CREATE TABLE noir_outpost_dealers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    outpost_id VARCHAR(40) NOT NULL,
    profile_key VARCHAR(40) NOT NULL,
    status VARCHAR(20) NOT NULL,
    corner_index SMALLINT UNSIGNED NULL,
    hired_by_citizenid VARCHAR(64) NOT NULL,
    hired_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    next_sale_at DATETIME NULL,
    robbed_until DATETIME NULL,
    lifetime_sales BIGINT UNSIGNED NOT NULL DEFAULT 0,
    version INT UNSIGNED NOT NULL DEFAULT 0,
    UNIQUE KEY uk_outpost_profile (outpost_id, profile_key),
    INDEX idx_dealers_due (status, next_sale_at),
    CONSTRAINT fk_dealer_outpost FOREIGN KEY (outpost_id)
        REFERENCES noir_outposts(id) ON DELETE CASCADE
);

CREATE TABLE noir_outpost_stock (
    outpost_id VARCHAR(40) NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (outpost_id, item_name),
    CONSTRAINT fk_stock_outpost FOREIGN KEY (outpost_id)
        REFERENCES noir_outposts(id) ON DELETE CASCADE
);

CREATE TABLE noir_outpost_operations (
    operation_id CHAR(36) PRIMARY KEY,
    operation_type VARCHAR(24) NOT NULL,
    outpost_id VARCHAR(40) NOT NULL,
    dealer_id BIGINT UNSIGNED NULL,
    citizenid VARCHAR(64) NULL,
    organization_id VARCHAR(64) NULL,
    item_name VARCHAR(64) NULL,
    quantity INT UNSIGNED NULL,
    gross_amount BIGINT UNSIGNED NULL,
    net_amount BIGINT UNSIGNED NULL,
    status VARCHAR(20) NOT NULL,
    payload JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    committed_at DATETIME NULL,
    INDEX idx_operations_outpost (outpost_id, created_at),
    INDEX idx_operations_status (status, created_at)
);

CREATE TABLE noir_outpost_rotations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cycle_key VARCHAR(32) NOT NULL UNIQUE,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    state JSON NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 8.2 Regras de consistência

- todas as queries parametrizadas;
- SQL concentrado em `server/repositories/`;
- `SELECT ... FOR UPDATE` em venda, coleta, claim e roubo;
- coluna `version` para optimistic locking onde útil;
- `operation_id` UUID único para idempotência;
- nenhuma tabela lê/escreve schema interno de Qbox, gangs ou inventário;
- migration numerada e não DDL improvisado a cada start;
- valores monetários como inteiros;
- timestamps em UTC;
- retenção/arquivamento periódico da tabela de operações.

### 8.3 Venda atômica

Dentro de uma transação:

```text
1. lock dealer + outpost + stock;
2. confirmar status/owner/next_sale_at;
3. decrementar estoque somente se quantity >= pedido;
4. incrementar purse_available pelo valor líquido;
5. atualizar next_sale_at e lifetime_sales;
6. inserir operation_id único;
7. commit.
```

Depois do commit:

- `RecordActivity` no `noir_illegal_core`;
- disparar notificação agregada;
- avaliar dispatch;
- atualizar clients próximos.

Falha em notificação/dispatch não reverte a venda. Falha no `RecordActivity` deve ser registrada e reenfileirada com o mesmo transaction ID, sem repetir a venda.

---

## 9. Segurança

### 9.1 O client envia intenção, não resultado

Payload permitido:

```lua
{ outpostId = 'docks', dealerId = 14, requestId = 'uuid' }
```

O servidor resolve:

- organização;
- permissão;
- produto;
- quantidade;
- preço;
- split;
- estoque;
- saldo;
- loot;
- chance de polícia;
- cooldown;
- posição válida.

### 9.2 Matriz mínima de validação

| Ação | Validações server-side |
|---|---|
| abrir painel | personagem, organização, distância, outpost ativo |
| claim | estado, grade, distância, mínimos online, cooldown, lock |
| contratar | owner, grade, dinheiro, limite, perfil disponível |
| demitir | owner, grade, dealer, lock, política de reembolso |
| abastecer | owner, grade, item allowlisted, quantidade, capacidade, posse |
| coletar | owner, grade, purse, capacidade, idempotência |
| roubar | rival, distância, estado, cooldown, simultaneidade |
| concluir progress | mesma sessão, TTL, distância novamente, estado atual |

### 9.3 Proteções adicionais

- rate limit por `source + ação`;
- sessão opaca para progress bars longas;
- request IDs para depósito/coleta/claim;
- locks definidos antes do primeiro `await`;
- limite de tamanho/tipo para payload NUI;
- audit log para alteração de owner, hire/fire, estoque, coleta, roubo e admin;
- comandos administrativos protegidos por ACE;
- nenhum comando de XP/debug habilitado em produção;
- nunca confiar em state bag como autorização;
- não usar evento client → server para “venda concluída”.

### 9.4 Eventos, callbacks e logs

- namespace obrigatório: `noir_outposts:client:*` e `noir_outposts:server:*`;
- usar `RegisterNetEvent` somente quando o evento realmente cruza client/server;
- usar `AddEventHandler` para eventos locais e lifecycle;
- capturar `local src = source` antes do primeiro `await`; `source` nunca vem no payload;
- callback curto usa `lib.callback`; progress bar longa usa sessão server-side com estado e TTL;
- respostas seguem `{ ok = boolean, code = string?, data = table? }`;
- eventos server → client verificam origem quando o fluxo permitir;
- logs usam `lib.print` com nível, contexto e correlation/operation ID;
- não logar tokens de sessão, payload integral, credenciais ou identificadores completos sem necessidade;
- falha de provider retorna `provider_unavailable`; falha interna retorna mensagem genérica ao jogador e detalhe somente no log.

---

## 10. UI e experiência

### 10.1 Computador do outpost

Views:

**Mercado**

- catálogo de dealers;
- atributos e custo;
- contratar/demitir;
- limite atual;
- requisitos bloqueados.

**Runners**

- dealer, posição e status;
- próximo ciclo estimado;
- estoque total;
- produtos ativos;
- purse disponível;
- abastecer e coletar;
- histórico recente.

A NUI recebe snapshot já filtrado. Ela não recebe campos internos, não calcula payout e não decide se um botão é autorizado.

### 10.2 Aplicativo “The Exchange”

O app do `sd-phone` deve oferecer:

- mapa/lista dos outposts conhecidos;
- tipo e status;
- owner da própria organização, sem revelar tudo a rivais;
- dealers ativos;
- estoque agregado e purse para membros autorizados;
- deep link para navegação;
- notificações de venda agregadas, estoque baixo, roubo, claim e expiração.

O Trap Phone da primeira referência centraliza descoberta/claim, enquanto o Burner Phone administra estoque, produto e carteira.[1] No Noir, essas funções podem viver em um único app com abas **Rede** e **Operação**, reduzindo a quantidade de itens/UI sem perder a separação funcional.

### 10.3 Visibilidade de informação

| Papel | Pode ver |
|---|---|
| público/rival | existência aproximada, dealer visível no mundo |
| membro | owner, status, dealers e estoque resumido |
| gestor | estoque detalhado, purse e histórico |
| líder | claim, hire/fire, coleta e configuração |
| polícia | apenas alertas e evidências geradas pelo gameplay |

### 10.4 Contrato obrigatório da NUI

- abrir foco somente depois de autorização server-side;
- todo `RegisterNUICallback` chama `cb` em todos os caminhos, inclusive erro;
- payload e retorno são JSON-safe; não enviar vector userdata, entity handle ou referências Lua;
- o browser usa `GetParentResourceName()` e trata fetch rejeitado/JSON inválido;
- renderizar dados externos com `textContent`, sem `eval`, HTML arbitrário ou CDN;
- nenhum segredo ou regra econômica autoritativa entra no bundle;
- implementar handshake `uiReady` e reenviar snapshot completo para reidratação;
- updates incrementais são permitidos, mas o snapshot completo sempre reconstrói a tela;
- liberar foco em Escape, botão fechar, morte, distância inválida, unload e `onResourceStop`;
- fechamento animado possui timeout de segurança para executar `SetNuiFocus(false, false)`;
- limpar listeners e timers ao fechar;
- aparência e acessibilidade seguem `resources/docs/NUI_JOB.md`.

### 10.5 Sessões de interação

Claim, roubo, depósito e coleta usam sessões autoritativas independentes da tela:

```text
CLOSED → OPENING → READY → PROCESSING → READY → CLOSING → CLOSED
                         └──────────────→ ABORTED → CLOSED
```

A sessão contém ID opaco, `source`, citizen ID, organização esperada, action, outpost/dealer, `startedAt`, `expiresAt` e estado. Toda conclusão revalida personagem, organização/grade, posição, entidade e transição. Desconexão, mudança de grupo, timeout ou resource stop executam o mesmo cleanup idempotente.

---

## 11. Estrutura de arquivos

```text
noir_outposts/
├── fxmanifest.lua
├── README.md
├── config/
│   ├── shared.lua
│   ├── client.lua
│   └── server.lua
├── shared/
│   ├── constants.lua
│   └── validators.lua
├── client/
│   ├── main.lua
│   ├── entities.lua
│   ├── interaction.lua
│   ├── phone.lua
│   └── ui.lua
├── server/
│   ├── init.lua
│   ├── api.lua
│   ├── security.lua
│   ├── scheduler.lua
│   ├── entity_manager.lua
│   ├── services/
│   │   ├── rotation_service.lua
│   │   ├── claim_service.lua
│   │   ├── dealer_service.lua
│   │   ├── stock_service.lua
│   │   ├── sale_service.lua
│   │   ├── robbery_service.lua
│   │   └── notification_service.lua
│   ├── repositories/
│   │   ├── outpost_repository.lua
│   │   ├── dealer_repository.lua
│   │   ├── stock_repository.lua
│   │   └── operation_repository.lua
│   └── integration.lua
├── html/
│   ├── index.html
│   ├── app.js
│   ├── styles.css
│   ├── phone/
│   │   └── index.html
│   └── assets/
├── locales/
│   ├── pt-br.json
│   └── en.json
├── migrations/
│   └── 001_initial.sql
└── tests/
    ├── unit/
    └── integration/
```

Manifest inicial:

```lua
fx_version 'cerulean'
game 'gta5'

name 'noir_outposts'
author 'Noir State'
description 'Outposts e venda passiva por dealers NPC'
version '0.1.0'

ui_page 'html/index.html'

files {
    'html/**/*',
    'locales/*.json',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/*.lua',
}

client_scripts {
    'config/client.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/repositories/*.lua',
    'server/services/*.lua',
    'server/*.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'bgrz_core',
    'noir_illegal_core',
}
```

`noir_outposts` depende de contratos, não dos providers concretos. `sd-phone`, `ox_target`, `ox_inventory`, dispatch e `ox_doorlock` ficam nas dependências/adapters do `bgrz_core`. Capacidades opcionais devem ser consultadas por handshake do bridge, possuir fallback seguro e ser testadas com o provider parado.

Ordem operacional:

```text
ox_lib / oxmysql
qbx_core e providers
bgrz_core
noir_gangs / noir_illegal_core
noir_outposts
```

O manifest deve expressar as dependências essenciais; a ordem do `server.cfg` não substitui isso.

---

## 12. Ordem de implementação

### Fase 0 — contratos

- [ ] adicionar adapter de inventário ao `bgrz_core`;
- [ ] adicionar adapters de target, phone, dispatch e doorlock ao `bgrz_core` conforme necessidade real;
- [ ] documentar e testar capability/version handshake e `provider_unavailable`;
- [ ] definir export de grade/permissão da organização;
- [ ] criar activities `outpost_*` no `noir_illegal_core`;
- [ ] configurar bridge de dispatch;
- [ ] decidir payout final (`black_money` recomendado);
- [ ] aprovar catálogo e multiplicadores econômicos.

### Fase 1 — domínio sem NPC/NUI

- [ ] migrations e repositories;
- [ ] rotação persistida;
- [ ] claim server-side;
- [ ] hire/fire;
- [ ] depósito e estoque virtual;
- [ ] scheduler de vendas;
- [ ] coleta idempotente;
- [ ] testes unitários das fórmulas e estados.

### Fase 2 — mundo e interação

- [ ] spawn server-side dos dealers;
- [ ] targets e progress bars;
- [ ] rotação de corners;
- [ ] cleanup/restart;
- [ ] roubo;
- [ ] dispatch.

### Fase 3 — interfaces

- [ ] NUI do computador;
- [ ] app customizado do `sd-phone`;
- [ ] notificações agregadas;
- [ ] locais, textos e acessibilidade;
- [ ] validação de escaping e handlers NUI.

### Fase 4 — expansão

- [ ] cartão de acesso + metadata;
- [ ] `ox_doorlock`;
- [ ] outpost de lavagem;
- [ ] compradores visuais;
- [ ] pistas e descoberta;
- [ ] conflito organizado por janela;
- [ ] dashboard de balanceamento.

---

## 13. Testes e critérios de aceite

### 13.1 Funcionais

- [ ] rotação não muda após restart no mesmo ciclo;
- [ ] duas organizações não concluem claim simultaneamente;
- [ ] não é possível contratar acima do limite;
- [ ] depósito remove exatamente os itens confirmados;
- [ ] falha SQL compensa o inventário;
- [ ] venda nunca deixa estoque negativo;
- [ ] comissão e líquido fecham com o bruto;
- [ ] coleta repetida com mesmo ID paga uma vez;
- [ ] rival pode roubar e owner não pode usar a mesma opção;
- [ ] cooldown de roubo persiste após restart;
- [ ] outpost sem estoque não gera dinheiro;
- [ ] owner expirado não vende;
- [ ] UI fechada/recarregada recupera snapshot;
- [ ] restart limpa NPCs e recria somente os necessários.
- [ ] unload/drop/mudança de organização encerra sessões transitórias;
- [ ] carregamento de model/anim dict expira com segurança e libera recursos.

### 13.2 Segurança

- [ ] chamar callbacks fora de distância falha;
- [ ] forjar organization ID falha;
- [ ] forjar preço/quantidade/item é ignorado;
- [ ] spam de callbacks é rate-limited;
- [ ] net ID de outro ped não é aceito;
- [ ] grade é revalidada no servidor;
- [ ] app oculto não concede acesso ao callback;
- [ ] event replay não duplica depósito, claim ou coleta;
- [ ] nenhum payout nasce de evento “sale complete” do client.
- [ ] todo NUI callback responde em sucesso, regra de negócio, input inválido e exceção tratada;
- [ ] `source` enviado no payload é ignorado e o runtime permanece canônico;
- [ ] provider parado retorna `provider_unavailable`, sem falso sucesso.

### 13.3 Carga e economia

- [ ] 8 dealers ativos sem thread por entidade;
- [ ] 48 players com target/phone sem polling pesado;
- [ ] scheduler processa vendas em lote;
- [ ] resmon/profiler medidos parado, perto e com UI aberta;
- [ ] dispatch respeita cooldown por outpost;
- [ ] receita passiva/hora é inferior à venda ativa/hora;
- [ ] telemetria mostra estoque consumido, bruto, comissão, líquido e roubos.

### 13.4 Cenário de soak

Executar teste de 2–4 horas com:

- dois outposts controlados;
- quatro dealers em cada;
- entradas/saídas frequentes de players;
- restart de `noir_outposts`;
- estoque zerando e sendo reposto;
- roubos concorrentes;
- queda temporária do phone/dispatch;
- rotação de corners;
- conferência final entre operations, estoque e purse.

---

## 14. Configuração inicial recomendada

```lua
return {
    rotation = {
        activeDrugOutposts = 1,
        activeMoneyOutposts = 0,
        durationHours = 24,
        rotateDealersMinutes = 20,
    },
    limits = {
        maxDealersPerOutpost = 4,
        maxStockTotal = 400,
        maxStockPerDeposit = 100,
    },
    sales = {
        baseIntervalSeconds = 75,
        minimumIntervalSeconds = 30,
        requireOwnerMemberOnline = true,
        maxStartupCatchupSalesPerDealer = 1,
        dispatchChance = 10,
        dispatchCooldownSeconds = 180,
    },
    robbery = {
        durationMs = 12500,
        cooldownSeconds = 1200,
        pursePercent = { min = 10, max = 25 },
        stockPercent = { min = 5, max = 15 },
        dispatchChance = 75,
    },
    claim = {
        durationMs = 45000,
        minOnlinePlayers = 8,
        minPolice = 2,
        ownerDurationHours = 24,
    },
}
```

Ajustar apenas depois de coletar dados reais. Os principais indicadores são:

- receita bruta/líquida por outpost/hora;
- unidades vendidas por produto;
- tempo até estoque zero;
- comissão média dos dealers;
- frequência e valor de roubos;
- número de dispatches;
- taxa de disputa/defesa;
- comparação com receita do `op-drugselling`.

---

## 15. Decisões que precisam de aprovação

Antes de escrever o resource, fechar estas decisões de design:

1. posse exclusivamente por organização ou também por jogador solo;
2. um ou dois outposts de drogas simultâneos;
3. payout em `black_money` ou conta `cash`;
4. vendas somente com membro da organização online;
5. perda total/parcial de dealers ao trocar o owner;
6. reembolso ao demitir dealer;
7. duração do controle e horário de disputa;
8. integração policial escolhida;
9. localizações/MLOs definitivos;
10. cartão de acesso no MVP ou fase 2.

### Defaults recomendados

- posse somente por organização;
- um outpost de drogas no MVP;
- payout em `black_money`;
- exigir um membro online;
- dealers são perdidos quando o owner muda;
- demissão sem reembolso;
- controle por 24 horas com cooldown de 30 minutos após tomada;
- cartão e lavagem somente na fase 2.

---

## 16. Resumo executivo

A melhor implementação para este servidor é um resource próprio `noir_outposts`, integrado à progressão existente e separado do `op-drugselling`. O servidor deve ser a autoridade de posse, estoque, agenda, preços e pagamentos. Dealers são entidades visuais ligadas a um estado persistente; buyers podem ser apenas ambientação. Estoque e purse ficam em tabelas próprias, com operações idempotentes e compensação nas fronteiras com inventário/dinheiro.

O caminho seguro é começar pelos contratos ausentes em `bgrz_core` e `noir_illegal_core`, entregar um MVP de um outpost de drogas sem compradores visuais e só depois adicionar lavagem, cartões, portas e cenas de buyers. Isso reduz o risco econômico e permite balancear com dados reais antes de ampliar a automação.

---

## 17. Conformidade com `SCRIPT_GOOD_PRACTICES.md`

| Área normativa | Como esta proposta atende |
|---|---|
| Bridge obrigatório | Providers substituíveis passam por contratos do `bgrz_core`; o consumidor não chama Qbox/OX/phone/dispatch/doorlock diretamente |
| Domínio isolado | Posse, dealers, estoque, vendas e roubos ficam em `noir_outposts`, não no bridge |
| Server authoritative | Claim, preço, quantidade, estoque, payout, loot, posição e permissão são resolvidos no servidor |
| Configuração | shared contém somente dados públicos; economia, rate limits e anti-exploit ficam server-side |
| Sessão/concorrência | máquina de estado, TTL, lock antes de await, request ID e idempotência |
| Persistência | schema próprio, SQL parametrizado, migrations, transações e compensação |
| Identidade | persiste citizen ID/organization ID; nunca `source` |
| Eventos/callbacks | namespace, escopo mínimo, `source` do runtime e envelopes estáveis |
| NPCs/target | entidade com lifecycle explícito; target não autoriza; distância e net ID são revalidados |
| State bags | apenas estado pequeno e não sensível; nunca prova de autorização |
| Performance | scheduler único com espera; sem thread por dealer, query por frame ou buyer econômico client-side |
| NUI | `uiReady`, snapshot completo, callbacks sempre respondem, foco seguro, escaping, sem CDN e sem regra econômica |
| Lifecycle | cleanup em stop, unload/drop, timeout, mudança de organização e remoção de entidade |
| Observabilidade | `lib.print`, operation/correlation ID, audit log e métricas econômicas |
| Testes | unitários, integração, segurança, provider indisponível, carga, resmon/profiler e soak |

Esta conformidade é requisito de implementação: um item descrito aqui não é considerado entregue até existir no código e passar pelos testes correspondentes.

## Sources

[1] https://forum.cfx.re/t/juice-cornerboys-fivem-npc-npc-drug-dealing-system/5381750 — Juice-CornerBoys – NPC Drug Dealing System
[2] https://docs.prodigyrp.net/crime/prp-outposts — prp-outposts – Prodigy Studios
