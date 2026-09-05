# Roteiro de Testes — advance-mechanic (v1.1.1)

Roteiro manual para validar o recurso `advance-mechanic` no servidor Qbox. Cada caso tem
pré-condição, passos e resultado esperado. Os valores citados (preços, distâncias, tempos)
foram extraídos de `shared/config.lua` e do código do recurso; se a config mudar, ajuste o roteiro.

Legenda de prioridade: **P0** bloqueia o uso do recurso · **P1** funcionalidade principal · **P2** secundário.

---

## 0. Preparação do ambiente

### 0.1 Contas e personagens

| Papel | Requisito |
|---|---|
| **ADMIN** | Personagem com ACE `group.admin` (usado para `/advsetmechanic`, `/advcreateshop`) |
| **MEC** | Personagem comum que virá a ser mecânico/dono da oficina. Precisa de **$100.000 em dinheiro vivo** (cash) para comprar a oficina e mais ~$60.000 cash para tuning/pintura/motor (`Config.Economy.payWithCash = true`) |
| **FUNC** | Segundo personagem comum, será contratado como funcionário |
| **CLI** | Cliente com **veículo próprio registrado em `player_vehicles`** (compre numa concessionária ou insira via SQL). Precisa estar online para receber fatura |

### 0.2 Itens (dar ao MEC via `/giveitem`)

Todos existem em `ox_inventory/data/items.lua`:

```
toolbox, diagnostic_tool, engine_oil x3, brake_fluid x3, coolant x3, car_battery x2,
car_door, car_hood, car_trunk, car_wheel, car_window, car_bumper,
motor_mount_v8, motor_mount_v6, wiring_harness x2, ecu_adapter
```

### 0.3 Banco de dados

1. Importar `install.sql` **uma vez**.
2. Confirmar tabelas:

```sql
SHOW TABLES LIKE 'mechanic_%';            -- mechanic_shops, mechanic_lifts, mechanic_employees, mechanic_schedules
SHOW TABLES LIKE 'vehicle_%';             -- vehicle_nitro, vehicle_suspension, vehicle_engines, vehicle_maintenance_history, vehicle_component_analytics
SHOW TABLES LIKE 'suspension_presets';
SHOW TABLES LIKE 'wrap_catalog';
SHOW COLUMNS FROM player_vehicles LIKE '%_data';   -- inspection_data, fluid_data, damage_data
```

### 0.4 server.cfg (já conferido neste repo)

- `ensure advance-mechanic` está na linha 113, depois de `ox_lib`, `oxmysql`, `qbx_core`, `ox_inventory`, `ox_target`.
- `qbx_mechanicjob` e `grot_fastmechanic` estão com `stop` (evita conflito de job/target).
- `qbx:enableBridge "true"` (o recurso usa `exports['qb-core']:GetCoreObject()`).
- `sd-phone` ensurado antes (faturas usam `exports.gksphone:NewBilling`, que o sd-phone provê via `provide 'gksphone'`).

### 0.5 Consultas SQL úteis durante o teste

```sql
-- Oficinas criadas
SELECT id, name, owner, price, JSON_LENGTH(lifts) AS lifts FROM mechanic_shops;

-- Resetar dono (para re-testar compra)
UPDATE mechanic_shops SET owner = NULL WHERE id = 1;
DELETE FROM mechanic_employees WHERE shop_id = 1;

-- Forçar fluidos baixos num veículo (para testar efeitos sem esperar degradação)
UPDATE player_vehicles SET fluid_data = JSON_OBJECT(
  'oilLevel', 20, 'coolantLevel', 20, 'brakeFluidLevel', 25, 'powerSteeringLevel', 25,
  'transmissionFluidLevel', 100, 'tireWear', 85, 'batteryLevel', 15, 'gearBoxHealth', 40,
  'lastUpdate', UNIX_TIMESTAMP()) WHERE plate = 'PLACA123';

-- Ver estado após serviços
SELECT plate, fluid_data, inspection_data, last_diagnostic, mileage FROM player_vehicles WHERE plate = 'PLACA123';
SELECT * FROM vehicle_nitro; SELECT * FROM vehicle_suspension; SELECT * FROM vehicle_engines;
```

---

## 1. Inicialização e integração (P0)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 1.1 | Start limpo | `restart advance-mechanic` no console do servidor | Console mostra `[Advanced Mechanic] Server initialized successfully` e `Database tables initialized`, sem erros Lua |
| 1.2 | Cliente sem erros | Entrar no servidor, abrir F8 | Nenhum erro de `advance-mechanic` (locale faltando, require falhando, ox_target) |
| 1.3 | Job existe | `/setjob [id] mechanic 4` via qbx_core no MEC | Job aplicado (grades 0–4, grade 4 = Manager/boss) |
| 1.4 | Comando admin | ADMIN: `/advsetmechanic [id MEC] 0` | MEC recebe notificação "You are now a mechanic"; personagem comum sem ACE recebe "no permission" ao tentar |
| 1.5 | Menu sem oficina | MEC (job mechanic, sem oficina) aperta **F6** ou `/mechanicmenu` | Notificação **"You must be assigned to a mechanic shop."** — menu NÃO abre |
| 1.6 | Menu sem job | CLI aperta F6 / `/mechanicmenu` | F6: nada acontece. `/mechanicmenu`: "Access Denied – You are not a mechanic" |

---

## 2. Criação da oficina — ADMIN (P0)

Pré: ADMIN em pé, num local amplo (ex. LS Customs / Bennys). O fluxo é **sequencial e longo**; anote as posições.

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 2.1 | Permissão | CLI digita `/advcreateshop` | "You do not have permission to do this." |
| 2.2 | Início | ADMIN digita `/advcreateshop` (ou `/createshop`) | Notificação "Shop creation started"; TextUI pede a primeira zona; marcador amarelo segue a mira (raycast) |
| 2.3 | Zonas obrigatórias (ordem fixa) | Mirar no chão e apertar **E** para cada uma: 1) Management Point 2) Storage Area 3) Inspection Area 4) Service Vehicle Garage 5) Paint Booth 6) Parts Shop 7) Customer Waiting Area | A cada E: notificação "zone placed: <nome>"; TextUI avança para a próxima |
| 2.4 | Elevadores | Para cada elevador: **entry** (onde o carro entra), **pos** (centro do elevador), **control** (painel). Após o 1º, diálogo "Add another lift?" (máx. 4) | Colocar **2 elevadores** para testar concorrência. Cancelar no diálogo encerra a etapa |
| 2.5 | Spawns | 3 pontos "Service Vehicles" + 5 pontos "Customer Parking" (todos obrigatórios) | TextUI mostra "<tipo> #n" |
| 2.6 | Nome e preço | Diálogo final: nome (3–50 chars), preço (default 100000) | Notificação "Shop created"; blip (sprite 446, cor 5) aparece no mapa no ponto de Management |
| 2.7 | Persistência | `SELECT * FROM mechanic_shops` | 1 linha, `owner` NULL, `zones` com 7 chaves, `lifts` com 2 entradas, `vehicleSpawns.service` 3 e `.customer` 5 |
| 2.8 | Sync | Outro jogador online sem relog | Recebe blip e zonas (evento `mechanic:client:shopsUpdated`) |
| 2.9 | Cancelar | Reiniciar `/advcreateshop` e apertar **Backspace** na 2ª zona | "Shop creation cancelled"; nada gravado no banco |
| 2.10 | Nome inválido | Criar com nome de 2 caracteres | Servidor rejeita silenciosamente (sem linha no banco) — anotar que não há feedback ao usuário |
| 2.11 | Duplo início | Iniciar criação e digitar `/advcreateshop` de novo | "Shop creation in progress" |

---

## 3. Compra da oficina e vínculo de job (P0)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 3.1 | Menu de gestão | MEC vai ao ponto Management (≤2 m), aparece TextUI, aperta **E** | Menu com "Shop Info – Owner: No owner" e opção "Purchase shop – $100000" |
| 3.2 | Sem dinheiro | MEC com < $100k cash compra | "Insufficient funds"; owner continua NULL |
| 3.3 | Compra | MEC com ≥ $100k cash compra | Cash debitado; notificação "Shop purchased"; job vira `mechanic` grade **4**; `mechanic_shops.owner` = citizenid do MEC |
| 3.4 | Menu liberado | MEC aperta F6 | Menu "Mechanic Menu" abre com 10 opções: Inspect Vehicle, Diagnostic Tablet, Tuning Menu, Paint Booth, Vehicle Wrapping, Suspension Setup, Engine Swap, Create Invoice, Start Mission, Tow Vehicle |
| 3.5 | Gestão como dono | Reabrir Management | Agora exibe "Spawn Service Vehicle" e "Manage Employees" (grade ≥ 4) |
| 3.6 | Já vinculado | FUNC já contratado (após §4) tenta comprar segunda oficina | Servidor recusa (retorna false) — anotar ausência de mensagem |
| 3.7 | Relog | MEC reloga | Job mantém `mechanic` 4; F6 continua abrindo o menu |

---

## 4. Funcionários (P1)

Pré: MEC dono (grade 4); FUNC online, sem job mechanic.

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 4.1 | Contratar | Management → Manage Employees → Hire Employee: ID do servidor do FUNC, grade "Mechanic" (1), salário 15 | "Employee hired"; FUNC recebe job `mechanic` grade 1; linha em `mechanic_employees` |
| 4.2 | FUNC usa menu | FUNC aperta F6 | Menu abre (vinculado via `mechanic_employees`) |
| 4.3 | FUNC sem permissão | FUNC vai ao Management | Vê "Spawn Service Vehicle" mas NÃO "Manage Employees" (grade 1 < 4) |
| 4.4 | Salário fora do range | Contratar com salário 5 ou 50 | Diálogo bloqueia (min 10 / max 30) |
| 4.5 | ID inválido | Contratar ID 999 | "Hire failed – player_not_found" |
| 4.6 | Já contratado | Contratar o FUNC de novo | "Hire failed" com mensagem de já vinculado |
| 4.7 | Lista | Manage Employees → Employee List | FUNC listado com nome, grade, salário, status (on/off duty), horas |
| 4.8 | Mudar grade | Detalhes → Change Grade → Supervisor (3) | "Grade changed"; job do FUNC vira grade 3 em tempo real |
| 4.9 | Mudar salário | Change Wage → 25 | "Wage changed"; coluna `wage` = 25.00 |
| 4.10 | Demitir | Fire Employee → confirmar | "Employee fired"; FUNC vira `unemployed` 0; F6 do FUNC deixa de abrir o menu; linha removida |
| 4.11 | Auto-gestão via admin | ADMIN (não dono) abre Manage Employees | Permitido (admin bypass) |

---

## 5. Garagem e veículos de serviço (P1)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 5.1 | Spawn via Management | Management → Spawn Service Vehicle → `flatbed` | Veículo aparece no 1º spawn "service"; MEC é colocado no banco do motorista; placa `MECH####`; recebe chaves (qbx_vehiclekeys bridge trata `vehiclekeys:client:SetOwner`) |
| 5.2 | Spawn via zona Garage | Ir ao ponto Garage (≤2 m, E) → Spawn Vehicle → `towtruck` | Mesmo comportamento. Testar também `towtruck2` e `forklift` |
| 5.3 | Rate limit | Spawnar 2 veículos em < 2 s | Segundo é ignorado |
| 5.4 | Guardar | Dentro do veículo de serviço, Garage → Store Vehicle | "Vehicle stored"; veículo deletado |
| 5.5 | Guardar veículo comum | Dentro do carro do CLI, Store Vehicle | "Vehicle cannot be stored" |
| 5.6 | Não-mecânico | CLI no ponto Garage | TextUI não aparece |
| 5.7 | Spawn bloqueado | Spawn point ocupado por outro veículo | Anotar comportamento (código não checa área livre — provável sobreposição) |

---

## 6. Elevadores (P0 — várias funções dependem do estado `onLift`)

Pré: MEC dirigindo o carro do CLI (ou o CLI dirigindo).

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 6.1 | Posicionar | Dirigir até o ponto **entry** do elevador 1 (raio 10 m) | TextUI "Position vehicle on lift"; ao ficar a **< 1,5 m** do `pos`: notificação "Vehicle positioned – use lift controls" |
| 6.2 | Sair sem elevar | Sair da área com o carro ainda no chão | Estado `onLift` limpo (verificar que Tuning volta a dizer "must be on lift") |
| 6.3 | Controle | Sair do carro, ir ao ponto **control** (≤2 m), **E** | Menu "Lift Control": Raise, Lower, Lock, Unlock, Inspect Vehicle |
| 6.4 | Subir | Raise Lift ×4 | Carro sobe 0,5 m por clique (0,25 m/s) até **2,0 m**; 5º clique → "Lift at limit" |
| 6.5 | Descer | Lower Lift até 0 | Retorna ao chão; abaixo de 0 → "Lift at limit" |
| 6.6 | Em movimento | Clicar Raise duas vezes rápido | Segundo clique → "Lift in use" |
| 6.7 | Lock/Unlock | Lock Vehicle → tentar empurrar/entrar e acelerar → Unlock | Travado: veículo congelado. Unlock: volta a mover |
| 6.8 | Inspect no elevador (capô fechado) | Inspect Vehicle | "Open hood first" |
| 6.9 | Inspect no elevador (capô aberto) | Abrir capô (ex. `/door 4` ou via menu do veículo), Inspect Vehicle | Inspeção roda com progress **2,5 s por item** (8 itens) |
| 6.10 | Sem carro | Ir ao control de elevador vazio | "No vehicle on lift" |
| 6.11 | Sync | FUNC observa MEC elevando | FUNC vê o carro subir; se FUNC estiver com o mesmo elevador ativo, recebe "Lift in use" |
| 6.12 | Dois elevadores | Carro A no elevador 1, carro B no elevador 2 | Controle de cada painel move só o seu carro |
| 6.13 | Restart com carro travado | Lock → `restart advance-mechanic` | Carro é destravado no `onResourceStop` |

---

## 7. Inspeção (P1)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 7.1 | Veículo não registrado | F6 → Inspect Vehicle perto de um carro de NPC/`/car` | "Vehicle not owned" |
| 7.2 | Dentro da oficina | Com o carro do CLI a < 50 m da zona Inspection, F6 → Inspect | Sem exigir toolbox; se capô fechado, aviso informativo "Open hood recommended"; 8 progress bars de **5 s** (Engine, Brakes, Oil, Battery, Transmission, Coolant, Suspension, Tires) |
| 7.3 | Zona Inspection | Dirigir o carro até a zona Inspection (≤3 m) | TextUI "Inspect Vehicle"; **E** inicia a inspeção sem menu |
| 7.4 | Fora sem toolbox | Levar o carro a > 50 m, remover `toolbox`, inspecionar | "Toolbox required outside" |
| 7.5 | Fora com toolbox | Devolver `toolbox`, inspecionar | Funciona |
| 7.6 | Resultado | Ao terminar | Menu "Inspection Results" com barra por item (verde ≥70 %, vermelho <70 %), "Repair All (n issues)" e "Paint Vehicle" |
| 7.7 | Cancelar | Apertar X durante um progress | "Inspection cancelled"; nada salvo |
| 7.8 | Persistência | `SELECT inspection_data FROM player_vehicles` | JSON com 8 chaves, `health` 0–100 e `lastChecked` |
| 7.9 | Pneu furado | Furar um pneu e inspecionar | Tires = 0 % |
| 7.10 | Repair All | Danificar o carro (engine ~300), inspecionar → Repair All → confirmar $1000 | Progress 15 s com efeito de solda; cash −1000; `SetVehicleFixed`; engine/body 1000; inspection_data zerada em 100 |
| 7.11 | Repair All sem dinheiro | Cash < 1000 | "Insufficient Funds"; carro não conserta |

---

## 8. Manutenção de fluidos via ox_target (P1)

Pré: MEC vinculado; mirar no carro do CLI (≤3 m) com ox_target.

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 8.1 | Opção aparece | Olhar o carro com ox_target | Opção "Perform Maintenance" (ícone lata de óleo); CLI não vê |
| 8.2 | Menu | Selecionar | 4 opções: Engine Oil, Brake Fluid, Coolant, Car Battery, com contagem "In inventory"; opções sem item ficam desabilitadas |
| 8.3 | Capô fechado | Engine Oil com capô fechado | "Open hood first" |
| 8.4 | Óleo | Abrir capô → Engine Oil | Progress 8 s + efeito no motor; 1× `engine_oil` consumido; "Maintenance complete"; `fluid_data.oilLevel` = 100; statebag `oilLevel` do veículo = 100 |
| 8.5 | Freio | Brake Fluid (capô não exigido) | `brake_fluid` −1; `brakeFluidLevel` = 100 |
| 8.6 | Coolant / Bateria | Idem com capô aberto | `coolantLevel` / `batteryLevel` = 100 |
| 8.7 | Veículo não registrado | Manutenção em carro `/car` | Progress roda mas servidor recusa → "Missing item"; item **não** consumido |
| 8.8 | Cancelar | X durante o progress | Item não consumido |

---

## 9. Instalação de peças via ox_target (P2)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 9.1 | Menu | ox_target no carro → "Install Parts" | 6 peças (Car Door, Hood, Trunk, Wheel, Window, Bumper) com contagem; sem item = desabilitado |
| 9.2 | Porta | Arrancar uma porta (bater) → Car Door | Progress 8 s; `car_door` −1; portas restauradas |
| 9.3 | Janela | Quebrar vidro → Window | Vidros consertados |
| 9.4 | Pneu | Furar → Wheel | Pneus consertados |
| 9.5 | Para-choque | Body health 500 → Bumper | Body +350 (máx 1000) |
| 9.6 | Distância | Afastar > 8 m durante o progress | Servidor recusa o consumo → "Missing part"; item mantido |

---

## 10. Loja de peças (P2)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 10.1 | Abrir | Ponto Parts (≤2 m) → **E** | Menu "Parts Shop" com 3 seções: Maintenance Supplies ($100 cada), Vehicle Parts (preço ×1,5: door 750, hood 600, trunk 675, wheel 450, window 300, bumper 525), Tools ($500: toolbox, wrench, diagnostic_tool, welding_torch, hydraulic_jack) |
| 10.2 | Comprar | Engine Oil, qtd 3 | Cash −300; 3× `engine_oil` no inventário; "Purchase successful" |
| 10.3 | Qtd limite | Qtd 11 | Diálogo bloqueia (máx 10) |
| 10.4 | Sem dinheiro | Cash 0 | "Purchase failed – insufficient funds" |
| 10.5 | Inventário cheio | Comprar 10× `car_door` (12 kg cada) | Anotar: verificar se o servidor recusa ou perde o item/dinheiro |
| 10.6 | Não-mecânico | CLI no ponto Parts | TextUI aparece e menu abre (zona não filtra job) — validar se é o desejado |

---

## 11. Tablet de diagnóstico (P2)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 11.1 | Não registrado | F6 → Diagnostic Tablet perto de `/car` | "No vehicle data" |
| 11.2 | Menu | Perto do carro do CLI | 6 submenus: Vehicle Information, System Diagnostics, Maintenance History, Performance Analysis, Damage Report, Fluid Levels |
| 11.3 | Vehicle Info | Abrir | Modelo, placa, dono (citizenid), body/engine %, quilometragem |
| 11.4 | Fluid Levels | Após forçar fluidos baixos por SQL (§0.5) | Cores: verde ≥70, amarelo 30–69, vermelho <30 |
| 11.5 | Relatório | System Diagnostics → Generate Report | Sucesso; `last_diagnostic` no banco com `date`, `mechanic` (nome) e 8 componentes |
| 11.6 | Rate limit | Abrir o tablet 2× em < 1,5 s | Segundo retorna "No vehicle data" (esperado pelo rate limit — anotar UX) |
| 11.7 | Item | Remover `diagnostic_tool` | Tablet **continua abrindo** (config `requiredTool` não é aplicada — ver §19) |

---

## 12. Tuning (P1)

Pré: carro do CLI **no elevador** (estado `onLift`, §6.1). O servidor confere também que o veículo está a ≤3 m do `pos` do elevador cadastrado.

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 12.1 | Fora do elevador | F6 → Tuning Menu com carro no chão | "Vehicle must be on lift" |
| 12.2 | Menu | Com carro no elevador | Performance Tuning, Visual Tuning, Nitro System |
| 12.3 | Capô | Performance com capô fechado | "Open hood first" |
| 12.4 | Engine nível 1 | Performance → Engine → nível 1 | Preço = 5000 × nível; cash debitado; "Upgrade installed"; `props` do veículo salvo no banco; mod visível em `lib.getVehicleProperties` |
| 12.5 | Nível máximo | Engine nível 4 | Recusado (maxLevel 3). Brakes máx 2, Transmission máx 2, Suspension máx 3, Armor máx 4, Turbo toggle |
| 12.6 | Visual | Visual Tuning → Spoilers → índice | Preço fixo por categoria (3000/2500/2500/2000/1500); spoiler aplicado e persistido |
| 12.7 | Nitro instalar | Nitro System → Install 50 | $5000; `vehicle_nitro` (capacity 50, level 50); statebags `nitroCapacity/nitroLevel` |
| 12.8 | Nitro upgrade 100 | Install 100 | $8000; capacity 100 |
| 12.9 | Nitro usar | Dirigir e usar a keybind de nitro (ver `lib.addKeybind` do tuning) | Boost aplicado; level decresce; ao zerar "Nitro empty" |
| 12.10 | Refill | Refill Nitro | $2000; level volta a capacity |
| 12.11 | Remover | Remove Nitro | Linha removida de `vehicle_nitro`; statebags nil |
| 12.12 | Sem dinheiro | Qualquer mod com cash insuficiente | Recusa, sem aplicar mod |
| 12.13 | Persistência | Sair/entrar no carro, relogar, retirar da garagem | Mods permanecem (`props` gravado) |

---

## 13. Cabine de pintura (P1)

Pré: carro a **≤10 m da zona Paint Booth** (não exige elevador).

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 13.1 | Fora da cabine | F6 → Paint Booth com carro longe da zona | Menu abre, mas ao confirmar o servidor recusa (`vehicle_outside_booth`) — anotar se há feedback |
| 13.2 | Preview | Dentro da cabine: escolher Metallic → cor | Cor aplicada em preview no carro antes de pagar |
| 13.3 | Cancelar preview | Fechar menu sem confirmar | Cor original restaurada |
| 13.4 | Confirmar | Confirmar Standard | Cash −500 (base 500 × 1,0); cor persistida no `props` |
| 13.5 | Multiplicadores | Metallic 750 · Matte 1000 · Pearlescent 1250 (pede cor da perola) · Chrome 1500 | Preços conforme tabela |
| 13.6 | Veículo não registrado | Pintar `/car` | Recusado (`vehicle_unowned`) |
| 13.7 | Via inspeção | Inspection Results → Paint Vehicle | Abre o mesmo menu |

---

## 14. Wrapping (P2)

Pré: carro ≤10 m da zona Paint Booth.

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 14.1 | Menu | F6 → Vehicle Wrapping | Primary Zone, Secondary Zone, Liveries (n available), Wrap Catalog |
| 14.2 | Material | Primary → Gloss → cor | Preview; confirmar cobra 2000 × mult (gloss 1,0 · matte 1,3 · satin 1,5 · carbon 2,0) |
| 14.3 | Livery | Carro com liveries (ex. `sultan`) → Liveries → escolher | Livery aplicada e persistida |
| 14.4 | Sem livery | Carro sem liveries | Opção desabilitada "0 available" |
| 14.5 | Catálogo vazio | Wrap Catalog | Lista vazia (tabela `wrap_catalog` sem linhas). Inserir uma linha por SQL e reabrir → aparece e aplica |

---

## 15. Setup de suspensão (P2)

Pré: carro **no elevador**.

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 15.1 | Fora do elevador | F6 → Suspension Setup no chão | "Suspension requires lift" |
| 15.2 | Sliders | Suspension Setup → 7 sliders (altura diant./tras., rigidez, camber diant./tras., toe diant./tras.) | Valores default = atual |
| 15.3 | Aplicar | Alterar 2 parâmetros → confirmar | Preço = 1000 + 200 × parâmetros alterados; cash debitado; linha em `vehicle_suspension`; efeito visível (altura/camber) |
| 15.4 | Persistência | Sair/entrar no carro | Suspensão mantida (statebag `suspensionData`) |
| 15.5 | Preset salvar | Save preset "Drift" | Linha em `suspension_presets` da oficina; máx 20 |
| 15.6 | Preset carregar | Load preset noutro carro | Aplica e cobra |

---

## 16. Troca de motor (P1 — fluxo mais longo)

Pré: carro **no elevador**; MEC com `motor_mount_v8` + `wiring_harness` e ≥ $20.000 cash. Carros classe Sports (ex. `sultan`) usam default `v6_turbo` RWD; Muscle (`dominator`) `v8_ls3` RWD; Compact (`blista`) `i4_stock` FWD.

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 16.1 | Fora do elevador | F6 → Engine Swap no chão | "Engine requires lift" |
| 16.2 | Menu | No elevador | Cabeçalho com motor atual (HP, torque, peso, wear N/A), Browse Engines (6 available), Remove Engine (desabilitado se stock) |
| 16.3 | Compatibilidade | Browse num carro FWD (blista) | V6 Turbo / V8 / LS3 marcados incompatíveis (só RWD/AWD) |
| 16.4 | Peças faltando | Instalar V8 Stock sem `motor_mount_v8` | Recusado (`missing_parts`) — anotar feedback |
| 16.5 | Instalar | Sultan (RWD) → V8 Stock com peças e dinheiro | Progress **280 s** com solda; cash −20000; `motor_mount_v8` e `wiring_harness` consumidos; linha em `vehicle_engines`; statebag `engineData` |
| 16.6 | Cancelar no meio | X durante o progress | Nada cobrado/consumido |
| 16.7 | Segunda troca | Instalar `v8_ls3` (precisa `ecu_adapter` também) | Motor antigo `v8_stock` vira **item** no inventário com metadata `wear`; se inventário cheio → recusa e reembolsa |
| 16.8 | Efeitos | Dirigir forte por alguns minutos | Temperatura sobe (aviso 90 °C, crítico 105 °C); wear cresce; sync ao servidor a cada 30 s (`total_km`, `wear`, `temperature`) |
| 16.9 | Remover | Remove Engine | Progress 120 s; volta ao stock; linha removida; motor devolvido como item |
| 16.10 | Relog | Sair e entrar no carro após relog | Motor custom recarregado do banco (`loadEngineStateBag`) |

---

## 17. Faturamento (P1)

Pré: CLI online a **≤5 m** do MEC; `sd-phone` iniciado.

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 17.1 | Sem jogador perto | F6 → Create Invoice sozinho | "No player nearby" |
| 17.2 | Menu | Perto do CLI | Add Labor, Add Part, Invoice Total ($0), Send Invoice (desabilitado) |
| 17.3 | Mão de obra | Add Labor: "Troca de óleo", 1,5 h, $50/h | Item listado; total 75 |
| 17.4 | Limites | Horas 0 ou 11; taxa 20 ou 200 | Diálogo bloqueia (0,5–10 h; $25–150) |
| 17.5 | Peça | Add Part → Car Door, qtd 2 | 2 × 750 = 1500; total 1575 |
| 17.6 | Enviar | Send Invoice | MEC "Invoice sent"; CLI "Invoice Received – $1575"; fatura aparece no app de faturas do sd-phone do CLI |
| 17.7 | Distância | CLI se afasta > 5 m antes do envio | "Invoice failed" |
| 17.8 | Auto-fatura | Só MEC e FUNC (ambos mecânicos): faturar a si mesmo | Impossível pelo menu (alvo é o jogador mais próximo) |
| 17.9 | Total alto | Itens somando > 250.000 | Servidor recusa (`maxInvoiceTotal`) |

---

## 18. Missões NPC (P1 — ver risco em §19)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 18.1 | Iniciar | F6 → Start Mission | "Mission started – repair <modelo>"; blip com rota para 1 dos 3 locais (Strawberry, Vinewood, Mirror Park) |
| 18.2 | Veículo | Chegar ao local | Veículo spawnado (engine 250, body 500), **não dirigível**, portas trancadas |
| 18.3 | Duplo início | Start Mission de novo | "Mission already active" |
| 18.4 | Completar sem reparar | Ir ao ponto (≤2 m), **E** | "Mission repair required" |
| 18.5 | Reparar | Tentar consertar o veículo até engine ≥ 900 e body ≥ 900 usando as ferramentas do recurso | **Ponto crítico**: o veículo de missão não está em `player_vehicles`, então Inspect ("Vehicle not owned"), Manutenção e Tablet são recusados. Só "Install Parts → Bumper" (body +350) funciona; não há caminho para o motor. Registrar se a missão é completável sem comandos de admin |
| 18.6 | Completar (com `/fix` ou similar como admin) | E no ponto | "Mission Complete – earned $X" (300–600 no **banco**); veículo deletado; blip removido |
| 18.7 | Cooldown | Start Mission em < 5 min | Nada acontece (retorno false) — anotar falta de mensagem |
| 18.8 | Tempo mínimo | Completar em < 30 s após início | Recusado (`minDuration`) |
| 18.9 | Desconexão | Sair do servidor com missão ativa | Missão limpa no servidor; ao voltar pode iniciar nova (após cooldown) |

---

## 19. Reboque (P2)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 19.1 | Fora de veículo | F6 → Tow Vehicle a pé | "Must be in tow vehicle" |
| 19.2 | Veículo comum | Dentro do carro do CLI → Tow Vehicle | "Not tow vehicle" |
| 19.3 | Sem alvo | No `flatbed`, sem carro em 10 m | "No vehicle to tow" |
| 19.4 | Engatar flatbed | `flatbed` a ≤10 m de um carro vazio → Tow Vehicle | "Vehicle attached"; carro preso na caçamba; statebag `towed` = true |
| 19.5 | Ocupado | Alvo com jogador dentro | "Vehicle cannot be towed" |
| 19.6 | Desengatar | Apertar **E** dentro do guincho | "Vehicle detached" |
| 19.7 | Guincho (towtruck) | `towtruck`: engatar, usar **↑/↓** | Força aplicada puxando/soltando o carro |
| 19.8 | Segundo engate | Engatar outro com um já preso | "Another vehicle attached" |
| 19.9 | Restart | Com carro engatado, `restart advance-mechanic` | Carro solto no `onResourceStop` |

---

## 20. Fluidos, degradação e efeitos (P2 — lento; use SQL de §0.5)

Pré: forçar `fluid_data` baixo no carro do CLI, guardar e retirar da garagem (recarrega do banco).

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 20.1 | Freio < 50 % | Dirigir e frear | Freio a 60 %; aviso de fluido de freio baixo (1× por nível) |
| 20.2 | Freio < 30 % | Idem com 25 | Freio a 30 % |
| 20.3 | Óleo < 30 % | Dirigir 1 min | Engine health cai 0,5/s; top speed 70 %; aviso "Low engine oil" |
| 20.4 | Coolant < 30 % | Dirigir | Temperatura sobe; aviso "Low coolant"; ao chegar a 120 °C motor desliga (engine −100) |
| 20.5 | Direção < 50 / < 30 % | Curvas | Direção pesada / muito pesada |
| 20.6 | Bateria < 40 / < 20 % | Faróis; motor | Faróis a 70 % / 30 %; abaixo de 20 % desligamentos aleatórios |
| 20.7 | Pneus > 80 % desgaste | Dirigir rápido | Tração reduzida; chance de estouro |
| 20.8 | Recuperação | Fazer manutenção (§8) de cada fluido | Efeito desaparece imediatamente; handling original restaurado |
| 20.9 | Degradação natural | Carro com 100 %: dirigir 10 min > 120 km/h | Óleo/coolant caem perceptivelmente (base 0,1 %/30 s ×1,5–2 em alta velocidade); `fluid_data` sincronizado no banco (~5 min) |
| 20.10 | Anti-cheat | Simular via F8 statebag `oilLevel` = 200 | Servidor clampa em 0–100 (`updateVehicleFluidData`) |

---

## 21. Danos e colisões (P2)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 21.1 | Colisão média | Bater lateral a ~60 km/h | Notificação "Wheel misaligned – vehicle pulls to side" quando dano ≥ 30 %; roda deslocada visualmente; statebag `wheelMisalignment` |
| 21.2 | Servidor | Após colisão | Evento `vehicleDamaged` grava `damage_data` no banco (rate limit 1,5 s) |
| 21.3 | Falha de motor | Engine < 10 % | Motor falha (`engineFailureThreshold`) |
| 21.4 | Conserto | Repair All (§7.10) | Desalinhamento removido |

---

## 22. Segurança e negativos (P1)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 22.1 | Callback sem job | CLI (não mecânico) executa via F8: `lib.callback.await('mechanic:server:repairVehicle', false, VehToNet(GetVehiclePedIsIn(PlayerPedId())))` | Retorna false; console do servidor loga `LogDenied ... not_mechanic` |
| 22.2 | Distância | MEC a 20 m chama `performMaintenance` via F8 | false |
| 22.3 | Rate limit | Chamar `applyPerformanceMod` 3× em 1 s | Apenas a 1ª processa |
| 22.4 | Deletar veículo alheio | CLI dispara `TriggerServerEvent('mechanic:server:deleteVehicle', netId)` num carro qualquer | Ignorado (só veículos de serviço; dono/motorista/admin) |
| 22.5 | Payload inválido | `createShop` com tabela vazia | Ignorado, sem erro no console |
| 22.6 | Preço custom | `installNitro` passando preço 1 | Servidor usa o preço da config (5000/8000) |

---

## 23. Reinício e persistência (P1)

| ID | Caso | Passos | Esperado |
|---|---|---|---|
| 23.1 | Restart | `restart advance-mechanic` com jogadores online | Zonas, blips, keybind F6 e ox_target voltam sem relog; sem TextUI "preso" na tela |
| 23.2 | Relog completo | Todos relogam | Estado da oficina, funcionários, mods, motor, nitro, suspensão preservados |
| 23.3 | Restart do servidor | Reiniciar o FXServer | Idem; `mechanic_shops` carregada (`Shops.LoadAll`) |

---

## 24. Pontos de atenção encontrados na leitura do código

Registre estes itens como "conhecidos" antes de testar, para não gastar tempo os redescobrindo:

1. **Missão provavelmente não completável** (§18.5): o veículo de missão não é registrado, e Inspect/Manutenção/Repair All exigem veículo em `player_vehicles`. O servidor até isenta o custo de `repairVehicle` para veículo de missão, mas o cliente nunca chega lá.
2. **Zona Storage sem função**: `Inventory.CreateStockZone` nunca é chamada e o stash `mechanic_shop_<id>` nunca é registrado no ox_inventory. A zona é obrigatória na criação mas não faz nada.
3. **Sem UI para**: vender oficina (`sellShop`), bater ponto (`clockIn/Out`), gestão de estoque/restock (`ManageStock`, `restockItem`, fundos da oficina) e cobrança rápida (`sendQuickBill`). Os callbacks existem, mas nenhum menu os chama.
4. **`Config.Inspection.requiredTool = 'diagnostic_tool'` não é aplicado** em lugar nenhum; `toolbox` é o único item exigido (inspeção fora da oficina).
5. **Itens sem uso**: `transmission_fluid`, `power_steering_fluid`, `suspension_parts`, `engine_part`, `brake_part`, `transmission_part`, `suspension_part`, `toolkit`, `tow_rope`. A manutenção só cobre óleo, freio, coolant e bateria.
6. **Zona Customer Waiting Area** e a segunda/terceira posição de spawn "service" não são usadas (spawn sempre usa `service[1]`).
7. **Falhas silenciosas**: várias recusas do servidor (nome inválido, cooldown de missão, fora da cabine, peças faltando no motor) retornam `false` sem notificar o jogador.
8. **Zona Parts não filtra job**: qualquer jogador abre a loja de peças.
9. **README desatualizado**: cita `/createshop` como principal, "Full Service" de 45 s, turbo por nível, e níveis de mod diferentes da config real.
10. **Elevador é movido no cliente** (`SetEntityCoords` a cada frame por quem controla); em rede fraca outros jogadores podem ver o carro "pulando".

---

## 25. Registro de resultados

Copie a tabela e preencha durante a execução.

| ID | Resultado (OK / FALHA / N/A) | Observações / evidência (print, log, SQL) |
|---|---|---|
| 1.1 | | |
| 2.6 | | |
| 3.3 | | |
| … | | |

Critério de aceite sugerido: todos os **P0** OK, todos os **P1** OK ou com falha documentada e aceita, **P2** apenas registrados.
