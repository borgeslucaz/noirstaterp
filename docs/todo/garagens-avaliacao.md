# Garagens: avaliação e pendências

- **Status (2026-09-27):** o `qbx_garages` foi substituído pelo
  `resources/[noir]/noir_garage`: a lógica de servidor do `qbx_garages` 1.1.4
  com os nossos patches, mais a interface React do `rhd_garage` 1.0.0 (prévia
  3D, apelido, histórico e transferência entre garagens), com o servidor
  conferindo dono, distância e preço. Os nomes das garagens são os mesmos, então
  os carros já guardados continuam aparecendo. Apelido e histórico ficam na
  tabela `noir_garage_vehicles`.
  - UI: fonte em `web/src`, build com `npm ci && npm run build` dentro de
    `web/` (o `web/build` vai no git).
  - Exports mantidos: `GetGarages`, `RegisterGarage`, `SetVehicleGarage`,
    `SetVehicleDepotPrice`. Evento: `noir_garage:server:vehicleSpawned`.
- **Status anterior:** decidido ficar no `qbx_garages` (2026-09-23).
- **Não fazer:** estacionamento físico (carro visível parado na vaga).

## Scripts avaliados

| Script | Versão / commit | Onde o carro nasce | Veredito |
|---|---|---|---|
| `qbx_garages` | 1.1.4 + patches nossos | servidor | base do servidor do `noir_garage` |
| [rhd_garage](https://github.com/RHD-FiveM/rhd_garage) | 1.0.0 / `ff511ea` | cliente | só a interface, no `noir_garage` |
| [drs_garages](https://github.com/DrSnyder86/drs_garages) | 2.8.0-drs.2 / `7807ef5` | servidor | descartado pelo custo |
| [mGarage](https://github.com/Mono-94/mGarage) | 2.0.7 / `50162cb` | servidor | descartado |
| [snowy_garages](https://github.com/SSnowly/snowy_garages) | 1.0.0 / `74e99ec` | cliente | descartado |
| [rhd_garage (fork MRI)](https://github.com/mri-Qbox-Brasil/rhd_garage) | 1.4.1 / `9646db2` | servidor, com modelo do cliente | descartado |

### rhd_garage
- Interface NUI em React, com prévia 3D, apelido e histórico do carro, e
  transferência entre garagens.
- O cliente decide o preço do depósito (`payDepotInvoice` recebe `price`).
- `saveVehicle`, `setVehicleOut`, renomear e mudar de garagem não conferem o
  dono no servidor: dá para apagar ou alterar o carro de outra pessoa.
- Bugs: `#vehicles < 0` ignora os pontos de saída, e `addVehicleLogs` é chamado
  sem a placa. O `web/build` não vem no repositório.

### rhd_garage (fork da MRI Qbox Brasil)
- Versão antiga do rhd (1.4.1), não a de React. Menus do ox_lib em pt-br,
  criador de garagens no jogo, pátio da polícia, loja de carro de emprego,
  menu radial e transferência de carro entre jogadores.
- O servidor confia no cliente:
  - `rhd_garage:server:spawnVehicle` cria o modelo, na posição e com as
    modificações que o cliente mandar;
  - `saveGarageZone` deixa qualquer jogador reescrever as garagens (sem
    checagem de admin);
  - `buyVehicle` usa o preço do cliente, e `removeMoney` desconta o valor e a
    conta que o cliente pedir;
  - `swapGarage` e `updateState` mudam qualquer placa sem conferir o dono;
  - `policeImpound.impoundveh` apreende qualquer carro, sem conferir emprego;
  - a transferência entre jogadores usa `WHERE citizenid = ? AND plate = ? OR
    fakeplate = ?`, que deixa passar o carro alheio pelo `fakeplate`.

### drs_garages
- Fork do `lunar_garage` 2.0.3 (GPL-3), com cerca de 26,8 mil linhas de Lua.
- Carro nasce no servidor e o servidor valida tudo. Tem frota de empresa,
  contratos, apreensão com histórico e última posição após restart.
- Substitui o `qbx_garages`, o `qbx_properties` (fork próprio) e o
  `qbx_vehicleshop` (`drs_vehicleshop`). Não expõe `RegisterGarage` nem
  `GetGarages`, o que quebra o `sd-phone`.
- Mexe no `player_vehicles`: cria colunas, um índice UNIQUE na placa e seis
  tabelas próprias. Fala direto com o framework, sem passar pelo `bgrz_core`.

### mGarage
- Depende do `mVehicle` e de colunas que o Qbox não tem (`stored`, `pound`,
  `metadata`, `type`).
- No Qbox, `isAdmin()` retorna `true`, e o callback `mGarage:GarageZones`
  deixa qualquer jogador criar, editar ou apagar garagens.
- O callback `mGarage:Interact` confia no `data` que vem do cliente:
  - modelo em `spawncustom`;
  - preço em `spawnrent`;
  - apreensão livre em `setimpound` e `changeimpound`;
  - conta da empresa que recebe (`society`);
  - posição de saída (`spawnpos`).
- A checagem de tipo e de emprego nunca bloqueia nada
  (`not x == y`). Sem commits desde 03/2025.

### snowy_garages
- Escrito do zero, com 3 commits. Tem criador de garagens no jogo, cobrança
  por hora e apreensão com multa, prazo e motivo. Carro de empresa ou gang
  pela coluna `company`, sem dono pessoal.
- `storeVehicle` grava `vehicle` e `hash` a partir do `modelName` e do
  `modelHash` enviados pelo cliente, o que permite trocar o modelo do carro.
- `vehicleSpawned(plate, netId)` não confere se a entidade tem aquela placa, o
  que permite ganhar a chave de carro alheio. O mesmo acontece em
  `giveImpoundKeys`.
- O carro nasce no cliente, o que quebra com `sv_entityLockdown`.
- A cada start, manda para o depósito todo carro com `garage IS NULL` e apaga
  o `citizenid` dos carros com `company`. Os carros guardados hoje não têm
  `garageSpotID` e não apareceriam.

## Brechas conhecidas (deixadas como estão)

- ~~`qbx_garages` `spawnVehicle` não confere `groups` nem `canAccess`~~:
  resolvido no `noir_garage`. Todo callback passa por `GetGarageAtAccessPoint`,
  que confere grupo, `canAccess` e a distância até o guichê.
- **`qbx_police`** (sobe pelo `ensure [qbx]`):
  - `police:server:Impound` não confere emprego e aceita preço livre ou
    apreensão permanente de qualquer placa;
  - `police:server:TakeOutImpound` só confere a distância até o pátio.
  - Se ele não é usado, `stop qbx_police` no `server.cfg` fecha a brecha.

## Ideias para acrescentar

**Feito no `noir_garage` (2026-09-27):**
- Transferência entre garagens (`Config.transfer.price`, hoje 0).
- Histórico do carro (retirar, guardar, pátio, apelido, transferência,
  chave e fechadura).
- Checagem de grupo no `spawnVehicle`.
- Apelido do carro.

**Pendentes:**
1. **Frota de empresa ou gang** (`noir_fleet`):
   - tabela própria, menu e ponto de retirada próprios;
   - carro nasce no servidor por `bgrz_core:SpawnVehicle`, com chave por
     `GiveVehicleKeys`;
   - cargo mínimo por carro;
   - compra pelo chefe com `RemoveOrgMoney`, com devolução se a criação falhar;
   - carro sumido volta à sede no restart.
2. **Apreensão completa:** motivo, prazo mínimo e quem apreendeu. O preço
   continua no `depotprice`. O pátio do `noir_garage` só mostra o carro
   apreendido (estado 2); a retirada fica com a polícia.
3. Estacionamento pago por hora.

**Já existe, não precisa fazer:**
- Última posição após restart: `qbx:vehiclePersistenceType "full"`, hoje em
  `semi`.
- Carro apagado com `/dv` vai para o depósito: o `noir_garage` já mostra no
  depósito o carro "fora" que não existe no mundo.
- Localizar o carro: o `sd-phone` resolve pelo `GetGarages`.
