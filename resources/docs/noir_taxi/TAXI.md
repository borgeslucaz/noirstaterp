Prompt — Redesign e novo fluxo do Taxi Job do Noir State
1. Contexto
Estamos trabalhando no Taxi Job do Noir State RP, servidor baseado em Qbox e executado no ecossistema FiveM/CFX.
Existe atualmente um sistema funcional de táxi contendo:
- taxímetro;
- sistema de ar-condicionado/FAN;
- corridas;
- passageiros NPC;
- pagamento;
- interface NUI.
A implementação atual apresenta problemas de UX:
- taxímetro grande demais;
- painel de ar-condicionado ocupando o centro da tela;
- vários atalhos permanentes;
- necessidade de ativar mouse para operar equipamentos;
- excesso de informação enquanto o jogador dirige;
- fluxo excessivamente manual para corridas NPC.
A tarefa é refatorar o fluxo completo do Taxi Job e sua NUI, preservando funcionalidades úteis existentes, mas substituindo o comportamento e o design conforme especificado abaixo.
Antes de escrever código, inspecione todo o resource atual:
1. fxmanifest.lua;
2. client scripts;
3. server scripts;
4. config;
5. NUI;
6. lógica atual do taxímetro;
7. lógica do ar-condicionado;
8. spawning/cleanup de NPC;
9. pagamento;
10. integração Qbox;
11. keybinds;
12. eventos client/server.
Não faça uma reescrita cega. Reaproveite funcionalidades corretas e elimine as partes que entram em conflito com esta especificação.
2. Objetivo de UX
O princípio central é:
O jogador deve trabalhar como taxista dirigindo, e não operando uma NUI.

Durante o uso normal do emprego:
- não usar mouse;
- não liberar cursor;
- não abrir menu central;
- não usar ox_target dentro do veículo;
- não obrigar o jogador a ligar/desligar o taxímetro manualmente em corridas NPC;
- não criar interfaces grandes sobre a cena.
O HUD do Taxi Job deve ocupar somente o canto superior direito.
Visualmente deverá existir apenas:
┌──────────────────────────────┐
│ TAXI · OCUPADO               │
│                              │
│ TARIFA             DISTÂNCIA │
│ $18,70               2,4 km  │
└──────────────────────────────┘

┌──────────────────────────────┐
│ ❄ 21°C      FAN ● ● ● ○ ○   │
└──────────────────────────────┘

      [G] para alterar a FAN
Nenhum outro painel permanente do Taxi Job deve ficar visível.
3. Não usar NUI focus durante o gameplay
A NUI é apenas um HUD de apresentação.
Não usar:
SetNuiFocus(true, true)
para operar taxímetro, FAN, aceitar corrida ou qualquer ação normal do Taxi Job.
A página NUI continua sendo tecnicamente um fullscreen NUI do FiveM, mas seu documento/root deve permanecer transparente e os controles devem continuar no jogo. O CFX implementa fullscreen NUI como uma camada sobre o jogo e mantém uma pilha de foco; portanto, este HUD deve receber dados com SendNUIMessage, sem tomar foco durante a direção. Cfx Documentation
Remover completamente o antigo conceito:
M → ACTIVE MOUSE
Também remover qualquer UI equivalente.
4. State machine obrigatória
Não espalhe vários booleanos como:
hasPassenger
meterActive
lookingForJob
hasCall
isPickingUp
Crie uma máquina de estados explícita.
Estados:
HIDDEN
AVAILABLE
OFFER
EN_ROUTE
BOARDING
HIRED
COMPLETING
PAUSED
Fluxo principal:
                     ┌──────────────┐
                     │    HIDDEN    │
                     └──────┬───────┘
                            │
                      entra no taxi
                            │
                            ▼
                     ┌──────────────┐
                     │  AVAILABLE   │
                     └──────┬───────┘
                            │
                    chamada encontrada
                            │
                            ▼
                     ┌──────────────┐
                     │    OFFER     │
                     └───┬──────┬───┘
                         │      │
                     aceita   timeout
                         │      │
                         ▼      └──→ AVAILABLE
                   ┌──────────────┐
                   │   EN_ROUTE   │
                   └──────┬───────┘
                          │
                  chega no passageiro
                          │
                          ▼
                   ┌──────────────┐
                   │   BOARDING   │
                   └──────┬───────┘
                          │
                    NPC entrou
                          │
                          ▼
                   ┌──────────────┐
                   │    HIRED     │
                   └──────┬───────┘
                          │
                    chega destino
                          │
                          ▼
                   ┌──────────────┐
                   │  COMPLETING  │
                   └──────┬───────┘
                          │
                     pagamento
                          │
                          ▼
                     AVAILABLE
Toda transição deve acontecer através de funções claras.
Exemplo conceitual:
setTaxiState(TAXI_STATE.AVAILABLE)
setTaxiState(TAXI_STATE.OFFER)
setTaxiState(TAXI_STATE.EN_ROUTE)
A mudança de estado é responsável por atualizar:
- HUD;
- blips;
- GPS;
- NPC;
- input permitido;
- cleanup relacionado.
5. Início do emprego
Fluxo desejado:
Jogador pega o táxi
        ↓
Entra como motorista
        ↓
Sistema confirma:
- é taxista
- está em serviço
- veículo é permitido
        ↓
Taxímetro aparece automaticamente
        ↓
AVAILABLE
        ↓
Central começa a procurar corridas automaticamente
Não deve existir:
Pressione X para procurar passageiros
O motorista estar:
- trabalhando;
- dentro de um táxi válido;
- no banco do motorista;
- disponível;
já significa:
estou aceitando chamadas.

O Qbox expõe no PlayerData o job atual, job.onduty e também metadata.jobrep.taxi, que pode ser aproveitado posteriormente para progressão. Qbox Documentation
Acompanhe também mudanças de emprego usando os eventos do Qbox, em vez de assumir que o job permanece taxi durante toda a sessão. O Qbox disponibiliza QBCore:Client:OnJobUpdate para essa atualização. Qbox Documentation
6. Estado AVAILABLE
Assim que o jogador estiver apto:
TAXI · DISPONÍVEL

TARIFA          DISTÂNCIA
$0,00              0,0 km
Embaixo:
❄ 21°C        FAN ● ● ● ○ ○
E:
[G] para alterar a FAN
Não mostrar:
PROCURANDO...
PROCURANDO...
PROCURANDO...
constantemente de maneira chamativa.
Pode existir uma informação secundária em baixa opacidade:
AGUARDANDO CHAMADA
A central fica buscando uma corrida automaticamente em background.
7. Geração automática de chamadas NPC
Implementar um dispatcher NPC.
Enquanto estiver em AVAILABLE, o servidor pode gerar uma oferta após um intervalo configurável:
dispatch = {
    minDelay = 10000,
    maxDelay = 30000,
}
Não usar exatamente os mesmos tempos sempre.
A chamada deve ser criada server-side.
A sessão deve possuir, no mínimo:
{
    id = ...,
    source = ...,
    status = 'offered',

    pickupIndex = ...,
    dropoffIndex = ...,

    pickup = vector3(...),
    dropoff = vector3(...),

    createdAt = ...,
    expiresAt = ...,

    expectedDistance = ...,
    maxBillableDistance = ...,
}
O client não escolhe quanto a corrida vale.
8. Seleção inteligente de pickup
Não escolher qualquer ponto aleatório do mapa.
A seleção deve considerar a posição atual do taxista.
Configuração inicial sugerida:
pickup = {
    minDistance = 300.0,
    idealMaxDistance = 1800.0,
    absoluteMaxDistance = 3000.0,
}
Priorizar pickups suficientemente próximos para que o emprego tenha ritmo, mas não tão próximos que todas as chamadas ocorram no mesmo quarteirão.
Evitar:
taxista em Downtown
→ passageiro em Paleto Bay
como corrida normal.
Longas distâncias podem futuramente ser liberadas por reputação.
9. Não spawnar o NPC imediatamente
Quando uma oferta é criada, ainda não é necessário colocar um Ped no mundo.
Fluxo:
Servidor cria OFFER
        ↓
jogador aceita
        ↓
EN_ROUTE
        ↓
motorista se aproxima da coleta
        ↓
spawn do NPC
Por exemplo:
npcSpawnDistance = 180.0
Isso evita dezenas de peds de missão esperando por taxistas que nunca aceitaram ou chegaram.
10. Interface da nova chamada
Quando surgir uma chamada, não crie outro card em outro canto da tela.
O próprio taxímetro deve expandir verticalmente.
Exemplo:
┌────────────────────────────────┐
│ NOVA CORRIDA                    │
│                                │
│ ORIGEM · Mirror Park           │
│ ATÉ A COLETA · 1,2 km          │
│ ESTIMATIVA · $85 — $110        │
│                                │
│ [E] ACEITAR              09 s  │
└────────────────────────────────┘

┌────────────────────────────────┐
│ ❄ 21°C       FAN ● ● ● ○ ○    │
└────────────────────────────────┘

        [G] para alterar a FAN
Não liberar mouse.
Não criar botão clicável.
E aceita.
Ignorar a solicitação até o contador terminar equivale a recusá-la.
Não é necessário criar outro botão para "recusar".
Após aproximadamente 10 segundos:
OFFER
→ timeout
→ AVAILABLE
Depois de pequeno cooldown, outra chamada poderá aparecer.
11. Keybindings
Use RegisterKeyMapping em vez de hardcode puro de control ID para comandos permanentes, permitindo que o jogador altere os bindings nas configurações do FiveM. O CFX documenta esse mecanismo de key mapping e sua exposição nas configurações do cliente. Cfx Documentation
Defaults sugeridos:
G = alterar FAN
E = aceitar chamada quando houver OFFER
J = pausar/retomar chamadas
Todos devem ser configuráveis.
Não usar E globalmente em loops; ele só deve ter efeito de Taxi Job quando o state for OFFER.
12. Aceitando a chamada
Ao pressionar E:
OFFER
   ↓
client solicita accept(sessionId)
   ↓
server valida
   ↓
server marca sessão accepted
   ↓
client recebe confirmação
   ↓
EN_ROUTE
O client deve enviar somente algo semelhante a:
sessionId
Nunca:
payment
fare
reward
distance
reputation
O servidor já possui os dados da corrida.
13. EN_ROUTE
Depois de aceitar:
- adicionar blip no pickup;
- ativar rota GPS;
- alterar o estado do taxímetro.
Visual:
TAXI · A CAMINHO

COLETA · Mirror Park
620 m
Não mostrar ainda uma tarifa ativa.
O passageiro ainda não entrou.
14. Blips e GPS
Use o sistema nativo do GTA/FiveM.
A própria implementação oficial do qbx_taxijob usa blip de coordenada e ativa rota até o NPC em vez de depender de uma enorme UI de navegação. GitHub
Manter no máximo:
1 blip de coleta
ou
1 blip de destino
Nunca ambos simultaneamente.
Remover blips antigos imediatamente nas transições.
15. Spawn do passageiro
Ao motorista chegar dentro da distância de streaming configurada, criar o passageiro.
Preferir uma arquitetura compatível com OneSync e criação server-side de entidades.
Isso é particularmente importante porque os modos de entity lockdown do OneSync podem impedir entidades criadas pelo client: strict bloqueia qualquer criação client-side e relaxed bloqueia entidades script-owned criadas pelo client. O modo full também existe especificamente para GTAV Enhanced. Cfx Documentation
Portanto:
não projete o Taxi Job dependendo obrigatoriamente de CreatePed() client-side.

Preferência:
SERVER
  cria mission ped
      ↓
obtém network id
      ↓
envia netId ao motorista
      ↓
CLIENT
  executa apresentação/AI necessária
State bags podem ser utilizados apenas quando realmente houver estado que outros clientes precisem observar. Estado replicado criado pelo servidor é adequado para isso, e deve continuar compatível com sv_stateBagStrictMode. Cfx Documentation
Exemplos possíveis:
noirTaxi:fareId
noirTaxi:driver
noirTaxi:passenger
Não armazenar recompensa financeira em state bag.
16. Comportamento do NPC aguardando
Enquanto espera:
- permanecer próximo à posição de pickup;
- pode executar uma animação/scenario discreto;
- não ficar andando pela rua aleatoriamente;
- bloquear comportamentos ambientais que façam a missão quebrar;
- marcar adequadamente como mission entity;
- limpar corretamente ao cancelar.
Quando o táxi chegar:
distância <= 8 m
e
velocidade <= 5 km/h
entrar em:
BOARDING
Não exigir:
Pressione E para chamar passageiro
O passageiro deve perceber que o táxi chegou.
17. Embarque automático
Selecionar assento traseiro preferencialmente.
Ordem sugerida:
rear-right
rear-left
front passenger
Não usar o banco do motorista.
Se não houver assento:
Não há assento disponível para o passageiro.
Não iniciar a corrida.
Use TaskEnterVehicle para o Ped.
O qbx_taxijob oficial já possui uma implementação funcional usando TaskEnterVehicle para embarque e TaskLeaveVehicle para desembarque; use isso como referência de comportamento, não necessariamente copiando sua arquitetura inteira. GitHub
Implementar timeout.
Por exemplo:
tentativa
  ↓ 10s
retry
  ↓ 10s
cancelar/recriar situação
Não deixar o Taxi Job preso para sempre em BOARDING.
18. Início automático do taxímetro
Esta é uma regra fundamental.
Quando:
NPC realmente entrou no veículo
então:
BOARDING
   ↓
HIRED
   ↓
taxímetro inicia automaticamente
   ↓
pickup blip removido
   ↓
GPS recebe destino
O jogador não aperta N.
O jogador não abre menu.
O jogador não liga o taxímetro manualmente.
Essa corrida é gerenciada pelo próprio sistema.
19. Estado HIRED
Visual:
┌──────────────────────────────┐
│ TAXI · OCUPADO               │
│                              │
│ TARIFA             DISTÂNCIA │
│ $18,70               2,4 km  │
└──────────────────────────────┘

┌──────────────────────────────┐
│ ❄ 21°C      FAN ● ● ● ○ ○   │
└──────────────────────────────┘

      [G] para alterar a FAN
Os números usam:
font-variant-numeric: tabular-nums;
Não permitir mudanças de largura visual conforme números mudam.
20. Pagamento precisa ser server-authoritative
Não repetir um padrão onde o client calcula:
currentFare
e depois executa:
TriggerServerEvent('pay', currentFare)
Mesmo que existam limites.
A documentação de segurança do CFX é explícita: eventos client→server podem ser acionados por clientes maliciosos e valores relevantes devem ser obtidos/validados no servidor. Cfx Documentation
Inclusive, a implementação atual do qbx_taxijob recebe o valor calculado do client em NpcPay, apesar de posteriormente aplicar validações de localização, limite e cooldown. Para o Noir, melhorar esse modelo e não aceitar o valor financeiro vindo do client. GitHub
21. Taxímetro server-side
O servidor deve manter:
activeFares[source] = {
    id = ...,
    state = 'hired',

    pickup = ...,
    dropoff = ...,

    vehicleNetId = ...,
    npcNetId = ...,

    startedAt = ...,

    distanceMeters = 0,
    currentFare = 0,

    lastCoords = ...,

    maxDistanceMeters = ...,
    maxFare = ...,
}
Ao iniciar HIRED:
currentFare = startingFare
Em intervalo de aproximadamente:
1000 ms
o servidor atualiza a distância usando a posição server-side do motorista/veículo.
Não precisa executar uma thread Wait(0) para isso.
22. Cálculo da tarifa
Configuração:
meter = {
    startingFare = 15.0,
    pricePerKm = 12.0,

    updateInterval = 1000,

    maxRouteMultiplier = 1.8,
    extraDistanceTolerance = 500.0,
}
Conceito:
tarifa =
bandeirada
+
distância válida percorrida × preço/km
O NUI recebe somente snapshots:
SendNUIMessage({
    action = 'taxi:updateMeter',
    fare = ...,
    distance = ...
})
A NUI apenas exibe.
Ela nunca é fonte de verdade.
23. Evitar farm dirigindo em círculos
Uma corrida NPC não pode permitir:
passageiro entra
→ jogador dirige 40 minutos em círculos
→ recebe fortuna
Quando a sessão for criada, calcular uma distância esperada aproximada.
Definir:
maxBillableDistance =
expectedDistance * multiplier
+ tolerance
Exemplo:
distância esperada: 4 km
limite tarifável: 7,7 km
Depois disso a tarifa deixa de crescer.
Isso também deve possuir um limite absoluto configurável.
24. Proteções de teleporte
Ao integrar distância:
position[n]
→ position[n+1]
se existir um salto fisicamente impossível em um intervalo de 1 segundo, não contabilizar esse trecho.
Exemplo:
maxValidDeltaPerTick = 150.0
Não necessariamente punir automaticamente.
Primeiro:
- ignorar trecho;
- registrar debug quando ativado;
- cancelar corrida se comportamento impossível persistir.
25. Finalização automática
Não exigir E no destino.
Quando:
distância do dropoff <= 12 m
AND
velocidade <= 3 km/h
AND
NPC está no veículo
por aproximadamente:
1–2 segundos
entrar:
COMPLETING
Fluxo:
HIRED
  ↓
destino alcançado
  ↓
meter congela
  ↓
server valida sessão
  ↓
pagamento
  ↓
NPC sai
  ↓
resultado
26. Validação final no servidor
Antes de pagar, verificar:
- sessão existe;
- pertence ao source;
- status é HIRED;
- jogador ainda possui job correto;
- jogador está on-duty se isso for obrigatório;
- veículo da sessão é válido;
- jogador está próximo ao destino;
- corrida não foi finalizada antes;
- distância mínima plausível foi percorrida;
- tempo mínimo plausível;
- payout ainda não ocorreu.
Após pagamento:
activeFares[source] = nil
antes de permitir novo payout.
27. Integração financeira Qbox
Usar a API server-side atual do Qbox.
Preferir:
exports.qbx_core:AddMoney(
    source,
    'cash',
    amount,
    'noir-taxi-npc-fare'
)
em vez de depender de Player.Functions.AddMoney.
A documentação atual do Qbox disponibiliza AddMoney, GetMoney, SetMetadata, GetMetadata, SetJobDuty etc. como exports server-side, enquanto a tabela Functions no tipo Player está marcada como deprecated. Qbox Documentation
28. Reputação de táxi
Não criar imediatamente uma tabela SQL paralela apenas para XP.
O Qbox já possui:
metadata.jobrep.taxi
no PlayerData. Qbox Documentation
Usar isso como primeira opção.
Após corrida concluída:
+ reputação configurável
Exemplo:
reputation = {
    basePerFare = 5,
}
Fluxo server-side conceitual:
GetMetadata(source, 'jobrep')
      ↓
atualizar taxi
      ↓
SetMetadata(source, 'jobrep', updatedTable)
Essa reputação poderá posteriormente liberar:
- corridas longas;
- aeroporto;
- executivos;
- veículos;
- passageiros especiais.
Não implementar toda essa progressão agora se não fizer parte do resource atual.
A arquitetura apenas deve permitir isso.
29. Resumo da corrida
Quando terminar:
┌──────────────────────────────┐
│ CORRIDA FINALIZADA           │
│                              │
│ TARIFA · $92                 │
│ REPUTAÇÃO · +5               │
└──────────────────────────────┘
Mostrar por aproximadamente:
3 segundos
Depois:
AVAILABLE
Não abrir modal.
Não exigir botão.
Não mostrar três notificações duplicadas.
30. Próxima corrida
Após concluir:
COMPLETING
     ↓
resultado por 3s
     ↓
AVAILABLE
     ↓
cooldown
     ↓
dispatcher novamente
O jogador pode continuar trabalhando indefinidamente sem interagir com menus.
31. Pausar chamadas
O taxista precisa poder:
- abastecer;
- conversar;
- parar em algum lugar;
- fazer RP;
- resolver alguma coisa sem receber chamadas.
Adicionar:
[J] pausar chamadas
somente quando não existir uma corrida ativa.
Estado:
PAUSED
UI:
TAXI · INDISPONÍVEL

CHAMADAS PAUSADAS
J novamente:
AVAILABLE
Não permitir pausar após aceitar uma corrida.
Keybind deve ser configurável.
32. Ar-condicionado / FAN
Eliminar completamente o painel grande atual.
O ar-condicionado fica imediatamente abaixo do taxímetro:
┌──────────────────────────────┐
│ ❄ 21°C      FAN ● ● ● ○ ○   │
└──────────────────────────────┘
Abaixo:
[G] para alterar a FAN
Pressionar G alterna:
0 → 1 → 2 → 3 → 4 → 5 → 0
Exemplo:
FAN ○ ○ ○ ○ ○
FAN ● ○ ○ ○ ○
FAN ● ● ○ ○ ○
FAN ● ● ● ○ ○
...
Sem mouse.
Sem slider.
Sem abrir outra interface.
33. Preservar gameplay existente do AC
Se o resource atual possui mecânica em que:
- FAN;
- temperatura;
- conforto;
- satisfação do passageiro;
afetam gameplay, preserve a lógica quando ela fizer sentido.
A mudança obrigatória é principalmente:
controle e apresentação.

Se FAN/temperatura influenciam dinheiro ou reputação, não confie cegamente em um valor arbitrário enviado pelo client.
Validar transições server-side.
34. Noir Taxi Design System
Use o Noir Design v2 fornecido como base, criando somente uma extensão cromática para táxi.
Adicionar tokens:
:root {
    --taxi-accent: #d6a23a;
    --taxi-accent-strong: #efbd4f;
    --taxi-accent-dim: rgba(214, 162, 58, 0.58);
    --taxi-accent-faint: rgba(214, 162, 58, 0.18);
    --taxi-accent-hairline: rgba(214, 162, 58, 0.24);

    --taxi-panel: rgba(10, 10, 12, 0.82);
    --taxi-panel-border: rgba(255, 255, 255, 0.08);
}
O amarelo representa:
- serviço de táxi;
- estado operacional;
- tarifa;
- FAN ativa;
- pequenos indicadores.
Não transformar toda a interface em amarelo.
Continuar usando branco/alpha para hierarquia.
35. Taxímetro visual
Estrutura desejada:
┌──────────────────────────────────┐
│ TAXI · OCUPADO                   │
│ ──────────────────────────────── │
│                                  │
│ TARIFA                 DISTÂNCIA │
│ $18,70                   2,4 km  │
└──────────────────────────────────┘
Características:
- Plus Jakarta Sans;
- weight 600;
- radius máximo 2px;
- fundo escuro translúcido localizado;
- borda hairline;
- sem glow;
- sem neon;
- sem gradiente colorido;
- sem sombra pesada;
- amarelo quente, não amarelo neon;
- valores com tabular-nums.
O status pode usar:
color: var(--taxi-accent-strong);
Tarifa:
color: var(--taxi-accent);
Distância continua branca.
36. Exceção ao padrão "sem cards"
O guia Noir v2 normalmente prefere conteúdo flutuante sem superfícies.
Este componente é uma exceção legítima conforme a própria regra de interfaces com identidade específica:
painel de veículo.

Taxímetro físico precisa parecer um equipamento.
Portanto é permitido usar --taxi-panel.
Mas:
- somente atrás do taxímetro;
- somente atrás do AC;
- nunca criar um backdrop fullscreen.
37. Responsividade
Este HUD precisa funcionar bem em:
1280×720
1920×1080
2560×1440
3440×1440 / 21:9
3840×1600 / 21:9
O fato de uma interface parecer boa apenas em 1920×1080 é considerado bug.
Ancoragem:
.taxi-hud {
    position: absolute;
    top: clamp(16px, 2.2vh, 32px);
    right: clamp(16px, 2.2vh, 32px);

    width: clamp(220px, 27vh, 360px);
}
Pode utilizar px nos limites do clamp() porque este é um HUD compacto, exceção explicitamente permitida pelo Noir Design v2.
Não usar:
width: 20vw;
como única regra.
Em ultrawide isso cresce horizontalmente sem necessidade.
38. Tipografia responsiva
Evitar que labels fiquem microscópicas em 720p.
Exemplo:
.status {
    font-size: clamp(11px, 1.05vh, 14px);
}

.data-label {
    font-size: clamp(10px, 0.95vh, 13px);
}

.fare {
    font-size: clamp(22px, 2.5vh, 34px);
}

.distance {
    font-size: clamp(18px, 2.1vh, 28px);
}
A hierarquia visual deve continuar a mesma independentemente da resolução.
39. Stack do HUD
Usar uma única coluna:
taximeter
    ↓ 0.55vh
climate
    ↓ 0.55vh
hint
Algo como:
.taxi-stack {
    display: flex;
    flex-direction: column;
    gap: 0.55vh;
}
Nada deve aparecer no centro da tela.
40. Interface de OFFER responsiva
O painel pode aumentar verticalmente:
AVAILABLE
┌─────────────┐
│   meter     │
└─────────────┘
vira:
OFFER
┌─────────────┐
│ nova corrida│
│ origem      │
│ distância   │
│ estimativa  │
│ aceitar     │
└─────────────┘
A largura permanece estável.
Isso evita elementos "pulando" lateralmente.
Nomes longos:
overflow: hidden;
text-overflow: ellipsis;
white-space: nowrap;
quando possível.
41. Movimento
Entrada inicial do Taxi HUD:
opacity 0 → 1
translateX(1.5vh) → 0
350ms
--noir-ease-out
Mudança de estado:
150–250ms
Nova corrida:
- conteúdo expande;
- sem bounce;
- sem scale;
- sem flash.
Fare atualizando:
não animar o painel inteiro.

Somente trocar números.
42. Reduced motion
Respeitar obrigatoriamente:
@media (prefers-reduced-motion: reduce) {
    *,
    *::before,
    *::after {
        animation-duration: 0.01ms !important;
        transition-duration: 0.01ms !important;
    }
}
43. Transparência FiveM
Obrigatório:
html,
body,
#root {
    margin: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
    background: transparent !important;
}
Nunca:
body {
    background: #000;
}
Nunca criar overlay fullscreen escuro.
Não usar backdrop-filter na página/root.
O fullscreen NUI do CFX ocupa uma camada completa sobre o jogo, mesmo quando somente uma pequena parte visual está sendo exibida; por isso a transparência do root é essencial. Cfx Documentation
44. NUI architecture
Preferir mensagens declarativas.
Exemplo:
SendNUIMessage({
    action = 'taxi:setState',
    state = 'HIRED',
    data = {
        fare = 18.70,
        distance = 2.4,
        temperature = 21,
        fan = 3
    }
})
Não espalhar:
openA
closeB
toggleThing
resetAnotherThing
hideOtherThing
se isso puder ser representado por estado.
A UI deve poder renderizar o estado inteiro a qualquer momento.
45. Eventos NUI
Se callbacks NUI ainda forem necessários para partes secundárias, usar o mecanismo atual de NUI callbacks e sempre responder ao callback.
A documentação do CFX alerta que callbacks que não retornam resposta podem deixar o request pendente até timeout. Cfx Documentation
Neste HUD, entretanto, praticamente todos os inputs devem vir do gameplay/keymapping e não do browser.
46. Arquitetura Client / Server / UI
Separar claramente:
SERVER
│
├── autoridade da corrida
├── dispatcher
├── sessão
├── validações
├── cálculo da tarifa
├── payout
├── reputação
└── cleanup global
       │
       ▼
CLIENT
│
├── gameplay
├── keybindings
├── blips
├── GPS
├── AI do passageiro
├── detecção local
└── bridge para NUI
       │
       ▼
NUI
│
└── APRESENTAÇÃO
A NUI não contém regra de negócio.
47. Estrutura sugerida
Adapte ao resource existente, mas caminhe para algo como:
noir_taxijob/
├── fxmanifest.lua
│
├── config/
│   ├── client.lua
│   ├── server.lua
│   └── shared.lua
│
├── client/
│   ├── main.lua
│   ├── state.lua
│   ├── dispatch.lua
│   ├── npc.lua
│   ├── meter.lua
│   └── ui.lua
│
├── server/
│   ├── main.lua
│   ├── dispatch.lua
│   ├── sessions.lua
│   ├── meter.lua
│   └── security.lua
│
├── locales/
│   └── pt-br.json
│
└── ui/
    ├── src/
    └── dist/
Não force essa estrutura se o resource atual já possuir uma organização boa.
48. Configuração
Nenhum valor de gameplay importante deve ficar perdido no código.
Centralizar:
Config.Dispatch
Config.Meter
Config.Passenger
Config.Climate
Config.Reputation
Config.AllowedVehicles
Config.Keybinds
Config.Debug
Exemplo:
Config.Dispatch = {
    OfferTimeout = 10000,
    MinDelay = 10000,
    MaxDelay = 30000,

    MinPickupDistance = 300.0,
    IdealPickupDistance = 1800.0,
    MaxPickupDistance = 3000.0,
}

Config.Passenger = {
    SpawnDistance = 180.0,
    BoardingDistance = 8.0,
    MaxBoardingSpeed = 5.0,

    DropoffDistance = 12.0,
    MaxDropoffSpeed = 3.0,
}

Config.Meter = {
    StartingFare = 15,
    PricePerKm = 12,

    UpdateInterval = 1000,

    MaxRouteMultiplier = 1.8,
    ExtraDistanceTolerance = 500.0,
}
49. Performance
Não criar loops Wait(0) continuamente apenas para:
verificar se jogador entrou no taxi
verificar se existe chamada
verificar se HUD está aberto
Preferir:
- eventos;
- cache de veículo;
- intervalos adequados;
- zonas somente quando existe missão;
- lógica ativa somente durante Taxi Job.
Atualização do meter:
~1 Hz server authoritative
A UI pode interpolar visualmente se necessário, mas sem alterar o valor real.
Não enviar SendNUIMessage todo frame.
50. Cleanup obrigatório
Implementar cleanup robusto para:
- jogador sai do servidor;
- resource para;
- job muda;
- duty acaba;
- veículo é destruído;
- jogador abandona o táxi;
- passenger morre/desaparece;
- chamada expira;
- corrida é cancelada;
- NPC fica preso;
- novo character é carregado.
Cleanup deve remover:
NPC
blip
route
session
timer
NUI state
state bags relacionados
threads/timers da sessão
Nunca deixar Ped de Taxi Job abandonado pela cidade.
51. Multiplayer
Dois taxistas precisam conseguir trabalhar simultaneamente.
Nunca usar uma variável global client-side como:
CurrentNpc
como se existisse somente um taxista.
No servidor:
activeFares[source]
ou estrutura equivalente.
Se possível, reservar temporariamente pickup locations usadas:
reservedPickups[pickupIndex] = sessionId
para evitar dois passageiros de missão ocupando exatamente o mesmo local.
52. Segurança dos eventos
Todo evento client→server precisa responder:
"O que impede um cheater de chamar isso diretamente?"

Validar:
- source;
- job;
- duty;
- state da sessão;
- session ID;
- posição;
- veículo;
- sequência esperada;
- cooldown;
- duplicidade.
A recomendação oficial do CFX é executar o máximo de lógica confiável server-side e validar dados enviados pelo cliente, inclusive posição, permissões, estado e experiência. Cfx Documentation
Exemplo proibido:
RegisterNetEvent('taxi:pay', function(amount)
    AddMoney(source, amount)
end)
O evento de conclusão ideal não recebe valor monetário algum.
53. Não punir falso positivo agressivamente
Uma validação falhar não significa necessariamente cheat.
Pode haver:
- lag;
- entity migration;
- packet delay;
- NPC bugado;
- teleport administrativo.
Prefira:
reject
→ cleanup
→ log em debug
para inconsistências menores.
Apenas casos claramente maliciosos e repetitivos devem chegar a sistema de exploit/ban.
54. Resultado esperado do fluxo completo
O comportamento final deve ser:
PEGOU O TÁXI
      ↓
taxímetro aparece
      ↓
TAXI · DISPONÍVEL
      ↓
dispatcher trabalha automaticamente
      ↓
NOVA CORRIDA
Mirror Park
1,2 km
[E] Aceitar
      ↓
E
      ↓
GPS até passageiro
      ↓
TAXI · A CAMINHO
      ↓
chega e para
      ↓
NPC entra automaticamente
      ↓
taxímetro começa automaticamente
      ↓
TAXI · OCUPADO
$18,70       2,4 km
      ↓
dirige ao destino
      ↓
para no destino
      ↓
NPC sai automaticamente
      ↓
servidor calcula e paga
      ↓
CORRIDA FINALIZADA
$92
+5 reputação
      ↓
3 segundos
      ↓
TAXI · DISPONÍVEL
      ↓
próxima chamada
Em qualquer momento sem corrida:
[J]
→ pausar chamadas
E durante todo o fluxo:
[G]
→ altera FAN
55. Critérios de aceite
A implementação não está concluída até validar todos estes cenários:
- entrar em táxi válido mostra HUD automaticamente;
- sair do táxi esconde HUD;
- jogador que não é taxista não ativa sistema;
- duty é respeitado;
- nenhuma operação normal exige mouse;
- SetNuiFocus(true, true) não é usado durante o trabalho normal;
- antigo M → ACTIVE MOUSE foi removido;
- nenhuma corrida NPC exige ativação manual do meter;
- chamadas surgem automaticamente;
- chamada expira se ignorada;
- E aceita somente durante OFFER;
- pickup recebe GPS;
- NPC entra automaticamente;
- rear seat é priorizado;
- taxímetro começa quando NPC entra;
- destino recebe GPS;
- corrida termina automaticamente ao parar no destino;
- client nunca envia reward/fare final;
- payout é calculado server-side;
- repetir evento de conclusão não paga duas vezes;
- concluir longe do destino não paga;
- dirigir em círculos não permite recompensa infinita;
- teleporte não adiciona quilômetros artificiais;
- dois taxistas conseguem trabalhar simultaneamente;
- disconnect limpa sessão;
- vehicle destroyed limpa sessão;
- job change limpa sessão;
- resource restart não deixa NPC/blip;
- FAN muda com G;
- nenhuma tela central de AC permanece;
- HUD mantém root transparente;
- nenhuma black screen ocorre ao iniciar a NUI;
- 1280×720 validado;
- 1920×1080 validado;
- 2560×1440 validado;
- 21:9 validado;
- conteúdo não cresce horizontalmente em ultrawide;
- prefers-reduced-motion respeitado;
- UI compilada caso o resource utilize dist.
56. Referências técnicas obrigatórias
Use a documentação de Fullscreen NUI / SendNUIMessage / foco do CFX como base para separar gameplay de apresentação. Cfx Documentation
Use a documentação oficial de NUI Callbacks quando houver comunicação browser→client. Cfx Documentation
Use Secure Your Events como regra para toda comunicação client→server, especialmente payout e conclusão de corrida. Cfx Documentation
Use as referências de OneSync e State Bags para entidades networkadas e compatibilidade com entity lockdown/Enhanced. Cfx Documentation
Use os tipos de PlayerData do Qbox para job, onduty e metadata.jobrep.taxi. Qbox Documentation
Use os server exports do Qbox para dinheiro, metadata e demais operações server-side. Qbox Documentation
Use o qbx_taxijob oficial como referência para integração Qbox, configuração de veículos, taxímetro, pontos NPC, blips, TaskEnterVehicle/TaskLeaveVehicle e criação server-side do veículo, mas não replique cegamente o modelo de payout baseado em valor recebido do client. GitHub
Links diretos para consulta:
CFX — Fullscreen NUI
CFX — NUI Callbacks
CFX — Secure Your Events
CFX — OneSync
CFX — State Bags
Qbox — Player types
Qbox — Server exports
Qbox — qbx_taxijob oficial
57. Resultado da implementação
Ao terminar:
1. descreva quais arquivos foram alterados;
2. descreva a nova state machine;
3. explique como o pagamento passou a ser server-authoritative;
4. liste os eventos client/server criados;
5. liste os keybindings;
6. informe os valores adicionados ao config;
7. informe qualquer funcionalidade antiga removida;
8. apresente os testes realizados;
9. deixe eventuais extensões futuras claramente fora do MVP;
10. não mantenha código legado morto ou a NUI antiga escondida no projeto.
Eu adicionaria ainda uma exigência ao agente: não introduzir nenhuma nova dependência fechada/Asset Escrow nesse refactor, para manter o resource utilizável no stack atual do Noir State/Enhanced.
