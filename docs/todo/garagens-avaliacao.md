# Garagens: avaliação e pendências

- **Status:** decidido ficar no `qbx_garages` (2026-09-23). O que acrescentar
  fica para depois.
- **Não fazer:** estacionamento físico (carro visível parado na vaga).

## Scripts avaliados

| Script | Versão / commit | Onde o carro nasce | Veredito |
|---|---|---|---|
| `qbx_garages` (atual) | 1.1.4 + 2 patches nossos | servidor | manter |
| [rhd_garage](https://github.com/RHD-FiveM/rhd_garage) | 1.0.0 / `ff511ea` | cliente | descartado |
| [drs_garages](https://github.com/DrSnyder86/drs_garages) | 2.8.0-drs.2 / `7807ef5` | servidor | descartado pelo custo |
| [mGarage](https://github.com/Mono-94/mGarage) | 2.0.7 / `50162cb` | servidor | descartado |
| [snowy_garages](https://github.com/SSnowly/snowy_garages) | 1.0.0 / `74e99ec` | cliente | descartado |

### rhd_garage
- Interface NUI em React, com prévia 3D, apelido e histórico do carro, e
  transferência entre garagens.
- O cliente decide o preço do depósito (`payDepotInvoice` recebe `price`).
- `saveVehicle`, `setVehicleOut`, renomear e mudar de garagem não conferem o
  dono no servidor: dá para apagar ou alterar o carro de outra pessoa.
- Bugs: `#vehicles < 0` ignora os pontos de saída, e `addVehicleLogs` é chamado
  sem a placa. O `web/build` não vem no repositório.

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

- **`qbx_garages` `spawnVehicle`**
  (`resources/[qbx]/qbx_garages/server/spawn-vehicle.lua`) não confere
  `groups` nem `canAccess`. Hoje nenhuma garagem é `shared`, então só vale o
  próprio carro. Se alguma garagem virar `shared = true`, qualquer jogador
  perto do ponto de acesso tira os carros dela. Corrigir antes de usar
  `shared`.
- **`qbx_police`** (sobe pelo `ensure [qbx]`):
  - `police:server:Impound` não confere emprego e aceita preço livre ou
    apreensão permanente de qualquer placa;
  - `police:server:TakeOutImpound` só confere a distância até o pátio.
  - Se ele não é usado, `stop qbx_police` no `server.cfg` fecha a brecha.

## Ideias para acrescentar

**Sem tocar no `qbx_garages`** (resource nosso, via exports e `bgrz_core`):
1. **Frota de empresa ou gang** (`noir_fleet`):
   - tabela própria, menu e ponto de retirada próprios;
   - carro nasce no servidor por `bgrz_core:SpawnVehicle`, com chave por
     `GiveVehicleKeys`;
   - cargo mínimo por carro;
   - compra pelo chefe com `RemoveOrgMoney`, com devolução se a criação falhar;
   - carro sumido volta à sede no restart.
2. **Transferência paga entre garagens**, pela export `SetVehicleGarage`.
3. **Histórico do carro**, pelo evento `qbx_garages:server:vehicleSpawned` e
   pelos ganchos do `qbx_vehicles`.
4. **Apreensão completa:** motivo, prazo mínimo e quem apreendeu. O preço
   continua no `depotprice`.

**Exigem patch pequeno no `qbx_garages`:**
5. Checagem de grupo no `spawnVehicle`.
6. Apelido do carro no menu da garagem.
7. Estacionamento pago por hora.

**Já existe, não precisa fazer:**
- Última posição após restart: `qbx:vehiclePersistenceType "full"`, hoje em
  `semi`.
- Carro apagado com `/dv` vai para o depósito: o `qbx_garages` já mostra no
  depósito o carro "fora" que não existe no mundo.
- Localizar o carro: o `sd-phone` resolve pelo `GetGarages`.
