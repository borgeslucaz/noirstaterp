# Migração do terminal para interior shell — `noir_outposts`

> Registrado em 2026-09-12, sobre o commit `22071c51`.
>
> Escopo: proposta de substituir o atendente NPC do terminal por um interior shell com entrada
> própria, contendo o computador e props de ambientação.
>
> Relacionado: `PLANO_VS_IMPLEMENTACAO.md` (estado da entrega) e `CODE_REVIEW_IMPROVEMENTS.md`
> (P0 de routing bucket, que esta proposta transforma em pré-requisito).

## 1. Motivação

O atendente NPC existe porque a zona de alvo invisível anterior ficava suspensa no ar: os quatro
locais são a céu aberto, sem MLO nem objeto para mirar, e nada indicava visualmente onde
interagir. O NPC resolveu a visibilidade, mas custou um laço de manutenção permanente no client,
um conjunto de flags de blindagem reaplicadas a cada volta e a ressalva de conflito com
`addGlobalPed` de outros resources.

Um interior shell resolve o problema original de forma mais direta — passa a existir um lugar
físico, com um computador visível para mirar — e permite ambientação com props. A contrapartida é
que ele muda a natureza da validação de posição, conforme a seção 3.

## 2. Decisões

### 2.1 Como se toma um outpost sem dono — **decidido**

**O cartão é a chave da tomada, não da posse.** Ele abre a porta de um outpost **ainda não
tomado**; concluída a tomada, qualquer membro da gang dona entra por filiação, sem cartão. Um
rival não entra num posto já controlado.

Isso encaixa sem atrito na regra que já existe: `Claim.start` só aceita outpost com status
`available`, então "ainda não tomado" no desenho do jogo é exatamente o estado em que o claim já é
permitido no código.

Efeito colateral desejável: duas gangs com cartão podem estar na mesma sala disputando a tomada,
porque o bucket é do outpost e não de quem entrou. O lock de claim que já existe
(`Sessions.activeForOutpost` devolvendo `claim_in_progress`) cobre a corrida.

### 2.2 Bucket por outpost ou por organização — **decidido**

**Estático por outpost.** Uma linha de config por local, sem alocação nem coleta, determinístico e
sobrevivente a restart. É também o que o modelo sessão→bucket do `noir_shell` já pressupõe, e o
único que permite a gang se reunir lá dentro *e* preserva o confronto.

Descartados: o modelo por organização (exigiria ciclo de vida de bucket e tornaria a gestão
ininterrompível) e o por jogador do `noir_shell_test`, em que membros da mesma gang não se veem.

A Fase A já reservou a faixa `7100-7199` em `config/server.lua`, com todos os postos em `0`.

### 2.3 Um shell por outpost, em coordenadas distintas

Recomendação: sim, em vez de reaproveitar um único shell para os quatro locais.

Com coordenadas distintas, o bucket é defesa em profundidade e o pior caso de uma falha na
checagem é não conseguir abrir o painel. Com um shell único compartilhado, o bucket passa a ser a
única coisa separando o outpost A do outpost B, e uma falha ali permite operar o outpost errado.
O custo da diferença é posicionar quatro shells em vez de um.

## 3. Impacto em segurança

Hoje toda ação presencial é validada por distância contra `definition.computer`, em três pontos:

- `server/api.lua` (`Api.buildPanelSnapshot`);
- `server/services/claim_service.lua` (`validate`);
- `server/services/dealer_service.lua` (`ownedEntry`), que cobre hire, fire, deposit e collect.

Um interior shell coloca vários jogadores nas **mesmas coordenadas do mundo**, em instâncias
diferentes. A partir daí, distância deixa de distinguir quem está no interior legítimo de quem
está parado na mesma coordenada em outro bucket — exatamente o cenário descrito no P0 de routing
bucket do `CODE_REVIEW_IMPROVEMENTS.md`, com a diferença de que passa de furo teórico a mecanismo
central da feature.

Por isso a Fase A é pré-requisito, e não um acompanhamento.

Observação: `Security.sameBucket` compara o jogador contra o bucket de uma **entidade**, e serve
para corredor e abordagem. Aqui é necessária uma primitiva nova, que compare o jogador contra o
bucket **esperado do outpost**.

## 4. Fases

### Fase A — routing bucket

Independente do shell. Entrega valor mesmo se a proposta de interior for abandonada, porque já
consta como P0 em `CODE_REVIEW_IMPROVEMENTS.md`.

1. Adicionar `bucket` à definição de cada outpost em `config/shared.lua`, com `0` para todos
   inicialmente.
2. Criar `Security.inOutpostBucket(source, outpostId)`.
3. Aplicar a checagem nos três pontos listados na seção 3.
4. Retornar código de recusa estável `invalid_bucket`.
5. Adicionar testes de claim, depósito e coleta a partir de bucket diferente.

Arquivos relacionados:

- `config/shared.lua`;
- `server/security.lua`;
- `server/api.lua`;
- `server/services/claim_service.lua`;
- `server/services/dealer_service.lua`;
- `tests/integration/domain_spec.lua`.

Critério de aceite: com todos os outposts em bucket `0` o comportamento em jogo é idêntico ao
atual, e nenhuma mutação presencial ocorre a partir de bucket diferente do configurado.

Efeito colateral desejável: como `Notification.refreshPanels` fecha o painel quando
`buildPanelSnapshot` devolve `nil`, sair do bucket passa a fechar o painel automaticamente, sem
código adicional.

### Fase B — interior sem cartão

1. **Configuração** em `config/shared.lua`, como dado público:

   ```lua
   interior = {
       shell = 'modelo_do_shell',
       origin = vec3(0.0, 0.0, 0.0),
       computer = vec4(0.0, 0.0, 0.0, 0.0),
       exit = vec3(0.0, 0.0, 0.0),
       props = { { model = 'prop_x', coords = vec4(0.0, 0.0, 0.0, 0.0) } },
   }
   ```

   O `computer` do outpost passa a ser a coordenada dentro do shell. Os três pontos de validação
   da Fase A seguem essa coordenada sem alteração de código.

2. **Client**: criar shell e props ao entrar no bucket e removê-los ao sair, com a mesma
   disciplina já aplicada ao atendente — timeout no `requestModel`, `SetModelAsNoLongerNeeded`,
   cleanup idempotente e aviso único por local. O alvo do computador passa a ficar sobre um prop
   visível, que era a queixa original.

3. **Server**: entrada e saída autoritativas. A porta valida organização, permissão e distância
   contra `entrance`; em seguida aplica `SetPlayerRoutingBucket` e teleporta. A saída faz o
   inverso. Recomenda-se `SetRoutingBucketPopulationEnabled(bucket, false)`, para não nascer
   trânsito e pedestre ambiente dentro do shell, e avaliar lockdown estrito de entidades no
   bucket.

4. **Lifecycle**, que é onde este tipo de feature costuma quebrar:

   - `playerDropped` e `bgrz_core:server:playerUnloaded` devolvem o jogador ao bucket `0`;
   - a reconexão também precisa cair para `0`, senão quem desconectar dentro acorda num bucket
     vazio, nas coordenadas do shell;
   - `onResourceStop` evacua todos os jogadores em buckets de interior — bucket `0` mais
     teleporte para a `entrance` —, no mesmo lugar onde hoje roda `Entities.despawnAll()`.

5. **Remoção do atendente**: `createTerminal`, `removeTerminal`, `hardenTerminal`,
   `syncTerminals`, `clearTerminals`, o helper `optional`, a thread de manutenção por
   `checkIntervalMs`, o bloco `terminalNpc` de `config/shared.lua` e as seções correspondentes do
   `README.md`. A ressalva sobre `addGlobalPed` de outros resources deixa de se aplicar.

Arquivos relacionados:

- `config/shared.lua`;
- `client/entities.lua`;
- `client/main.lua` (blip da entrada);
- `server/init.lua` (lifecycle e `onResourceStop`);
- `server/security.lua`.

Critério de aceite: o painel abre dentro do interior; a mesma chamada feita de fora do bucket é
recusada com `invalid_bucket`; nenhum jogador permanece em bucket de interior após queda,
unload, reconexão ou parada do resource.

### Fase C — cartão de acesso

1. Criar o item `outposts_exchange_card` no `ox_inventory`, com metadata
   `{ outpost, validUntil, issuedTo, nonce }`.
2. Validar no servidor, na porta: item presente, `outpost` correspondente, `validUntil` no
   futuro e `issuedTo` igual à organização atual do ator.
3. Definir a emissão, que a especificação §6.3 nunca cobriu: emissão na conclusão da tomada,
   emissão sob demanda pelo painel, ou compra.
4. Manter `shared.phone.requiresItem` como está — ele governa apenas a visibilidade do ícone do
   app e não deve ser confundido com o controle de acesso ao interior.

Regra inegociável: **o cartão abre a porta e não autoriza nada**. Toda permissão econômica
continua resolvida por `Security.requirePermission`. Sem isso, um cartão vazado vira acesso à
carteira da organização.

Critério de aceite: possuir o cartão sem a grade necessária não permite contratar, abastecer,
coletar nem demitir; e um cartão de outro outpost ou de outra organização não abre a porta.

### Fase D — porta física (opcional)

Somente se a entrada for uma porta real do mundo. Exige o adapter `SetDoorAccess` no
`bgrz_core`, que nunca foi implementado, e passa a usar o campo `doorId`, hoje presente e nulo
nos quatro locais de `config/shared.lua`.

## 5. Riscos conhecidos

- **Jogador preso em bucket.** É a falha mais provável da Fase B. Cobrir queda, unload,
  reconexão e parada do resource, e tratar a evacuação como idempotente.
- **População ambiente dentro do shell.** Sem `SetRoutingBucketPopulationEnabled`, nascem
  pedestres e trânsito dentro do interior.
- **Gestão ininterrompível.** Com bucket por organização, um rival nunca mais interrompe uma
  coleta. É mudança de balanceamento, não detalhe técnico, e motiva a recomendação 2.2.
- **Claim inacessível.** Se a decisão 2.1 não for fechada antes, a Fase C torna impossível tomar
  um outpost sem dono.
- **Cartão como autorização.** Ver a regra inegociável da Fase C.

## 6. Ordem recomendada

1. ~~Fechar as decisões 2.1, 2.2 e 2.3.~~ Feito: cartão para posto sem dono, bucket estático por
   outpost, um shell por outpost. Segue aberta só a emissão do cartão (Fase C, item 3).
2. ~~Executar a Fase A.~~ Feito — `Security.atComputer`, `expectedBucket`, bloco `buckets` no
   config e `invalid_bucket` nas locales, com todos os postos em bucket `0`.
3. Executar a Fase B e remover o atendente.
4. Avaliar a Fase C junto do restante da expansão prevista para a fase 4 da especificação.

## 7. Área de shells

Os interiores ficam numa área dedicada sob o mundo, fora do alcance do mapa jogável.

```lua
-- Início da área de shells do noir_outposts
vec4(-323.78, -942.35, -95.82, 175.11)
```

Os quatro postos recebem origens distintas a partir daqui, afastadas uma da outra. Origem única
para todos funcionaria — o bucket separa —, mas aí o bucket vira a única coisa distinguindo um
posto do outro, e a distância deixa de valer como segunda linha.

**Vizinhança verificada em 2026-09-13:** o único outro interior sob o mundo neste servidor é o do
`noir_houserobbery`, em torno de `(266, -1007, -101)`, hoje comentado. O shell de drogas abaixo
fica a ~697 m dele — folgado, mas é a direção a evitar se a área crescer.

### 7.1 Capturado

Os interiores são **por planta**, não por posto: mesmo shell e mesma planta interna, o que muda por
outpost é o bucket e a porta de entrada no mundo.

**Shell de drogas (`drug1`)** — modelo `shell_store1` (joaat `-1894535671`, conferido):

| Campo | Coordenada | Observação |
|---|---|---|
| `origin` | `vec4(-430.44, -1000.92, -79.35, 326.35)` | onde o `noir_shell` cria o shell |
| `door` | `vec4(-430.24, -995.5, -78.26, 151.87)` | entrada e saída; é o destino do teleporte |
| `computer` | `vec4(-433.65, -1002.92, -78.26, 78.23)` | **mesma coordenada do prop do laptop** |

Props:

```lua
{ model = 'xm_prop_x17_laptop_agent14_01', coords = vector4(-433.65, -1002.92, -78.26, 78.23) },
```

Porta → computador são **8,2 m**, contra `interaction.computerDistance = 2.0`. O jogador nasce na
porta e anda até o laptop, que é o comportamento desejado.

**Duas lições que custaram caro aqui, e que o `config_spec` agora trava:**

`computer` e o prop do laptop **têm que coincidir**. Elas nasceram separadas, e ao mover o laptop o
ponto de validação do servidor ficou para trás, enterrado sob o piso — o painel continuou abrindo
por tolerância de distância, então nada denunciou. Hoje existe asserção exigindo exatamente um prop
sobre `computer`.

E **o Z que a ferramenta devolve é o centro do ped**, cerca de um metro acima do chão. Para o
laptop calhou bem, porque bate com altura de mesa; para peça que fica no chão, desça ~1,0. Foi essa
diferença que manteve o laptop invisível por quatro rodadas: ele estava 0,6 m sob o piso, existindo,
na coordenada certa, e simplesmente dentro da geometria.

**Shell de lavagem:** pendente, e só faz sentido junto do serviço de lavagem, que não existe.

### 7.2 Portas de entrada, por outpost

Todos os postos são do tipo **droga**: o sorteio entre `drug` e `money` foi removido, e nenhum
`typePool` aceita lavagem. Todos apontam para a planta `drug1`.

| Outpost | Bucket | `entrance` |
|---|---|---|
| `pier` | 7104 | `vec4(-1487.56, -910.05, 10.36, 140.1)` |
| `docks` | 7101 | placeholder, a recapturar |
| `cypress` | 7102 | placeholder, a recapturar |
| `lamesa` | 7103 | placeholder, a recapturar |

Nota: a `origin` do shell de drogas fica a ~123 m do ponto registrado acima como início da área.
Se a intenção era manter tudo dentro dela, o início precisa ser corrigido; se a área cresce nessa
direção, está certo como está.

## 8. O que capturar ao montar os shells

Para a Fase B, por outpost:

- **modelo do shell** e a **origem** (`vec4`), que precisa ser estática e distinta entre os postos;
- **coordenada do computador**, em **valor absoluto de mundo** — não o offset relativo;
- **ponto de entrada** (onde o jogador aparece dentro) e **ponto de saída**;
- **lista de props**: modelo mais `vec4` de cada um.

O `noir_shell` traz `/testshell <model>` para subir um shell na sua posição e `/shelloffset` para
imprimir a posição atual como offset relativo a ele.

**A armadilha:** o servidor valida distância contra a coordenada absoluta do computador, e ela só é
constante porque a origem do shell é fixa. **Mover a origem depois obriga a recapturar o
computador junto** — senão o painel deixa de abrir, com `too_far`, sem nada óbvio explicando.
