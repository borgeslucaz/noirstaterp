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
8. Rivais podem roubar dealers, que entram em recuperação por 20 minutos.
   Matar um corredor tem o mesmo efeito: ele sai de operação, o corpo deixa a esquina e um
   novo ped assume a posição quando o cooldown acaba. Corredor em recuperação não vende e
   não pode ser roubado.
9. Ao expirar o controle ou mudar o ciclo, dealers e estoque são encerrados.

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
- progress bars longas revalidam tudo na conclusão e recusam conclusão mais rápida que a
  duração autorizada.

State bags carregam apenas `noir:outpostId`, `noir:dealerId` e `noir:dealerState`. Nenhuma delas
autoriza qualquer coisa.

## Persistência

Seis tabelas próprias em `migrations/001_initial.sql`; nenhuma consulta a schema de terceiros.
Valores monetários são inteiros e timestamps são epoch UTC.

| Tabela | Papel |
|---|---|
| `noir_outposts` | estado, dono, carteira disponível/pendente, lock de claim |
| `noir_outpost_dealers` | perfil, corner, agenda, recuperação e acumulados |
| `noir_outpost_stock` | estoque virtual por produto |
| `noir_outpost_operations` | ledger idempotente de toda operação econômica |
| `noir_outpost_rotations` | seleção persistida por ciclo |
| `noir_outpost_organizations` | cooldown de claim por organização |

Venda, roubo, depósito e coleta usam `UPDATE` condicional com guardas de estado, dono, estoque
e `version` do dealer, então uma corrida perde em vez de corromper. Onde a fronteira é externa
(inventário), a operação é compensada: o depósito devolve exatamente os itens removidos se o
estoque recusar, e a coleta restaura a carteira se a entrega falhar.

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
(dealers, estoque e carteira da própria organização). O gate do ícone é apenas visual; cada
callback revalida permissão no servidor.

`phone.defaultApp = true` põe o ícone direto na tela inicial. Com `false` o app aparece só na
App Store do celular e o jogador precisa instalar antes de abrir. Para exigir o cartão na fase 2, defina
`phone.requiresItem = 'outposts_exchange_card'` em `config/shared.lua` e crie o item.

## Comandos

```text
/outposts status          lista estado, dono, dealers, estoque e carteira
/outposts release <id>    libera o controle de um outpost
/outposts rotate <id>     rotaciona os corners dos dealers
```

Protegidos pelo ACE `noir.outposts.admin` (ou console).

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
