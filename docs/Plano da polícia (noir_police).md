# Plano da polícia: `noir_police` (set/2026)

> Troca do `qbx_police` por um resource nosso, feito a partir de um fork do [ND_Police](https://github.com/ND-Framework/ND_Police) (commit `a8a1d6f`, 04/09/2025). Traz os módulos do `qbx_police` que fazem falta e algumas ideias do [ars_policejob](https://github.com/Arius-Scripts/ars_policejob). A comparação dos três está na conversa de 30/09/2026. Aqui fica só o que vamos fazer.

## Decisão

- **Base:** o ND_Police. Cada mecânica fica num arquivo, o framework fica isolado num bridge, os dados ficam em `data/` e o estado vai por state bag.
- **Troca direta:**
  - O servidor não está em produção, então pode ficar sem polícia durante a migração.
  - O `qbx_police` vai para `disabled_resources/` assim que o `noir_police` subir. Não há fase de coexistência.
- **Nada de camada de compatibilidade genérica.** Só religamos os contratos que outros resources usam de verdade (tabela da seção 3). O resto quebra e é tratado resource por resource.
- **O ars_policejob não entra como código:**
  - está abandonado desde 06/2024;
  - tem brechas graves: o cliente escolhe os `jobs` que autorizam receber item, e a multa não tem teto.
  - Só aproveitamos ideias (seção 5).
- **Licença:** o que vem do ND é GPL-3.0, e o `noir_police` herda essa licença.

## 1. Estrutura do `noir_police`

```
[noir]/noir_police/
  fxmanifest.lua
  bridge/            server.lua e client.lua, só bgrz_core
  data/              config, departments, evidence, shotspotter, clothing, locker_rooms
  shared/            departamento e permissão (funções puras)
  client/  server/   um arquivo por módulo
  stream/            props convertidos para v159
  audiodata/  audiodirectory/
  locales/           pt-br.json e en.json
```

Regras:
- Toda leitura de job, duty, grade, dinheiro e metadata passa pelo **bgrz_core** (exports e eventos). Nada de `exports.qbx_core` nem `qb-core` dentro do `noir_police`.
- **Um bridge fixo**, declarado em `dependencies`. O `shared/bridge.lua` do ND escolhe o framework por `GetResourceState` e quebra quando o restart muda a ordem de start. Esse arquivo sai.
- Saem também `bridge/esx`, `bridge/qb`, `bridge/nd` e o suporte a ox_core.
- Antes de entregar, auditar contra o §24 do `resources/docs/SCRIPT_GOOD_PRACTICES.md`.

## 2. Mudanças no código do ND

### 2.1 Departamentos (novo)

O ND só tem uma lista `policeGroups = {"lspd","sahp","bcso"}`, que nem bate com os nossos jobs. Vira:

- **Quem é polícia:** `job.type == 'leo'` **e** `onDuty`, conferido **no servidor**. No `qbx_core/shared/jobs.lua` hoje são `police` (LSPD), `bcso` e `sasp`.
- **`data/departments.lua`**, uma entrada por job, com:
  - delegacias (blip, ponto de duty);
  - armários e roupas;
  - garagem e viaturas por grade;
  - impound;
  - grade mínima por ação.
- **Subunidade (K9, SWAT, etc.):**
  - No Qbox o jogador tem um job só, então o `groups = {"canine"}` do ND nunca bateria.
  - A subunidade vira permissão na config (grade mínima ou lista de citizenid), seguindo a regra de permissão por config e não por hierarquia implícita.
- O `shotspotter.ignoredJobs` passa a usar a mesma regra (`leo` em serviço) e não uma lista própria.

### 2.2 Brechas do servidor a corrigir

| Evento ND | Problema | Correção |
|---|---|---|
| `setPlayerEscort` | Sem checagem de job nem de algema. Qualquer cliente escolta qualquer um a 10 m e coloca em qualquer veículo | Policial em serviço, alvo algemado, distância ≤ 3 m, veículo perto dos dois |
| `gsrTest` | Sem checagem de job nem de distância | Policial em serviço, distância ≤ 3 m |
| `collectEvidence` | Os pontos vêm do cliente, sem distância. Dá para coletar no mapa todo | Cada ponto a ≤ N m do ped no servidor, e só policial em serviço |
| `distributeEvidence` | O cliente cria evidência onde quiser e em qualquer quantidade | Ponto perto do ped, limite de nós e de itens por chamada, taxa por jogador |
| `cuffCheck` | O `and`/`or` sem parênteses faz a algema pular as checagens do próprio policial | Reescrever com parênteses explícitos |
| `impoundVehicle` | `Bridge.notify(info)` sem `src`, então o erro nunca chega | Passar o `src` (ou reescrever, seção 4) |
| `deploySpikestrip` | `data.size` e o segmento vêm do cliente | Limitar o `size`, segmento perto do ped e com comprimento máximo |
| `shotspotter` | O cliente diz onde houve tiro | Confirmar a posição do ped e o cooldown no servidor |

Toda ação de polícia (algemar, escoltar, GSR, evidência, impound) confere **no servidor** que quem chama é `leo` em serviço. A exceção é o **zip tie**, que é liberado para qualquer um usar no crime (sequestro). A **algema** é só para a polícia (decisão 1 da seção 7).

### 2.3 Itens

| Item ND | Decisão |
|---|---|
| `cuffs` | Usar o nosso `handcuffs`, que já existe no `ox_inventory`. **Só `leo` em serviço usa.** Com civil, o uso é recusado no servidor |
| `zipties` | Novo item, **qualquer um usa**. Exige o alvo de mãos para cima, como no ND |
| `handcuffkey` | Novo item |
| `tools` | **Não usar.** No ND ele é o hotwire do NDCore, e aqui hotwire é do `mri_Qcarkeys`. Para cortar zip tie, criar um item próprio (ex.: `cutters`) ou aceitar um item que já exista |
| — | `seized_box`: novo item, container do ox_inventory, que é a caixa de apreensão. Vem vazia do arsenal (seção 4.1) |
| `shield` | Novo item |
| `spikestrip` | Novo item (hoje a spike é por comando) |
| `casing`, `projectile` | Novos itens, com o hook `createItem` do ND |

Os itens entram no `ox_inventory/data/items.lua` com `client.export = 'noir_police.<fn>'`.

### 2.4 Assets (Enhanced)

- **Props:** `police_cuffs.ydr` e `police_zip_tie_positioned.ydr` estão em RSC7 **v165 (legacy)**. Converter para v159 antes do primeiro start. O `cuffs_main.ytyp` está em v2 e deve servir, mas conferir.
- **Áudio:** `AUDIO_WAVEPACK` e `AUDIO_SOUNDDATA` (`nd_police.awc`, `dat54.rel`). Não sabemos se carregam no Enhanced.
  - Testar num start isolado.
  - Se não carregar, trocar por som por NUI ou nativo e seguir, sem insistir.
- Checar se a animação de escolta, algema e escudo existe no build. Prop ou anim ausente derruba o cliente na thread de render.

## 3. Contratos que o resto do servidor usa

Levantado por grep em `resources/` (sem o próprio `qbx_police` e o `qbx_core`).

| Contrato | Quem usa | O que fazemos |
|---|---|---|
| metadata `ishandcuffed` | bgrz_core, qbx_core, clothingmenu, illenium-appearance, qbx_medical, qbx_binoculars, qbx_newsjob, qbx_noshuff, qbx_tackle, sky_phone | **Manter.** O servidor grava ao algemar e desalgemar, junto com o state bag `isCuffed` do ND. Também `invBusy` |
| export `IsHandcuffed` (cliente) | sky_phone (via config) | **Manter** em `noir_police` e ajustar o `sky_phone/config/functions.lua` para o nome novo |
| `police:client:policeAlert` | fallback do `bgrz_core/server/dispatch.lua` (o primário é `ps-mdt:mdtCreateCall`) | **Manter** o handler no cliente (blip e aviso), ou mudar o fallback do bgrz_core para um evento do `noir_police` |
| `police:server:policeAlert` | noir_houserobbery, qbx_drugs, qbx_houserobbery, qbx_jewelery, qbx_storerobbery, qbx_truckrobbery, qbx_bankrobbery, xt-prison (comentado) | **Migrar os chamadores para `bgrz_core:SendDispatch`**, em vez de recriar o evento. Os `noir_*` primeiro. Os `qbx_*` entram na lista de ajustes |
| `police:SetCopCount` | qbx_drugs, qbx_bankrobbery (ouvem no cliente) | **Export novo** no servidor: `exports.noir_police:GetCopCount(department?)`, que conta `leo` em serviço, total ou por departamento. Os crimes passam a conferir o mínimo **no servidor** por esse export. O evento `police:SetCopCount` continua sendo emitido só enquanto qbx_drugs e qbx_bankrobbery não forem migrados. Os mínimos por crime são da revisão do ilegal |
| callback `qbx_police:server:isPoliceForcePresent` | só o próprio qbx_police | Não recriar |
| `police:server:JailPlayer` | radial | **Já é do xt-prison** (`bridge/compat/server.lua`). Não recriar |
| `police:client:SendToJail` | ps-mdt (sentença) | O xt-prison cobre. Confirmar que o handler não depende do qbx_police |
| `police:client:showFingerprint` | ps-mdt (config) | Vem com a digital (segunda leva). Até lá, a opção do ps-mdt fica sem efeito |
| `police:server:SearchPlayer` | ps_lib (bridge lj) | Revistar vira ação do `noir_police` (ox_inventory `openInventory` no alvo, com checagens). Ajustar o ps_lib se o bridge `lj` estiver em uso |
| `police:client:GetCuffed`, `DeEscort` | qbx_medical, qbx_adminmenu | Trocar por export ou evento do `noir_police` (soltar da algema e da escolta ao morrer, e admin uncuff) |
| `police:client:UpdateBlips` | qbx_ambulancejob | Blips de colegas (seção 4). Se não portarmos, o ambulance fica sem blip de polícia |
| `evidence:server:CreateFingerDrop` | noir_houserobbery, qbx_bankrobbery, qbx_houserobbery, qbx_jewelery, qbx_storerobbery | **Portar** (segunda leva). Até lá, os eventos disparam sem ouvinte e não quebram nada |
| `evidence:server:CreateBloodDrop` | qbx_medical | **Portar**, junto com a digital |
| `evidence:client:SetStatus` | qbx_consumables | **Portar**, junto com a digital (status de evidência: cheiro, olhos vermelhos) |
| `police:server:DisableAllCameras` e irmãos | qbx_bankrobbery | Só se portarmos as câmeras |
| Opções `police:*` do radial | qbx_radialmenu (config e client) | **Reescrever o bloco de polícia do radial** para chamar o `noir_police` |

## 4. O que importar do `qbx_police`

Cada item vira um módulo novo (`client/<modulo>.lua` e `server/<modulo>.lua`), reescrito no padrão do fork (bridge bgrz, departamento, checagem no servidor). Não é copiar o código do qbx.

### Primeira leva (junto com o fork)

| Módulo | No qbx_police | Como fica |
|---|---|---|
| **Duty** | `ToggleDuty` + zona do ox_target em `locations.duty` | Ponto de duty por delegacia em `departments.lua`, via bgrz_core |
| **Blips de colegas** | `police:client:UpdateBlips` | Só `leo` e `ems` em serviço, com a mesma lista enviada pelo servidor |
| **Garagem de viatura** | `openGarageMenu`, `takeOutVehicle`, `qbx_policejob:server:spawnVehicle`, `locations.vehicle` | Frota por departamento e grade, placa com prefixo, chave via mri (`GivePermanentKey`), spawn no servidor. A garagem `police` do `noir_garage` sai (lacuna 6) |
| **Heliponto** | `spawnHelicopter`, `locations.helicopter` | Entra na garagem como tipo `air`, com grade mínima |
| **Impound** | `police:client:ImpoundVehicle`, `police:server:Impound`, `TakeOutImpound`, `/impound`, `/depot` | **Não vira módulo:** o ps-mdt já tem o impound no local (target no veículo, formulário, pátio, histórico). Ver seção 9 |
| **Multa** | `police:server:BillPlayer` + `Renewed-Banking` | Teto por departamento, distância, só em serviço. Vira **fatura bloqueante** no banco (`bgrz_core:CreateInvoice`): o dinheiro só sai quando a pessoa paga, e cai na conta do departamento. Até pagar, saque e transferência ficam travados |
| **Objetos** | `/pobject`, `spawnObject`, `objects` (cone, barreira, placa, tenda, luz…) | Menu do porta-malas da viatura (ideia do ars), spawn e remoção no servidor, limite por policial |
| **Revistar e apreender** | `SearchPlayer`, `SeizeCash` (hoje sem checagem de emprego; o dinheiro vira `moneybag` no bolso do policial) | A revista é a tela nativa do ox. O policial leva os itens para o próprio inventário, e o hook `swapItems` registra as pendências. Caixa e gaveta de evidências na seção 4.1 |
| **Contagem de policiais** | `UpdateCurrentCops`, `police:SetCopCount` | Export `GetCopCount(department?)` no servidor (seção 3) |
| **Licenças** | `/grantlicense`, `/revokelicense`, `licenseRank` | Grade mínima por departamento |
| **Callsign** | `/callsign` | Metadata via bgrz_core. É usado no "officer down" |
| **Officer down** | `SendPoliceEmergencyAlert` | Via `bgrz_core:SendDispatch` com prioridade alta, para polícia e EMS |

### 4.1 Apreensão e gaveta de evidências

Substitui o `SeizeCash` do qbx, que tira o dinheiro vivo do alvo e dá um `moneybag` para o policial.

**Fluxo na rua.** Exemplo: o suspeito se rende e levanta as mãos, e o policial tira a arma dele ali mesmo.
1. **Revista:** a tela nativa do ox_inventory. O policial abre o inventário do alvo e arrasta o que quiser **para o próprio inventário**. Não há trava de alvo: dá para revistar qualquer um.
2. **Registro automático:** um hook `swapItems` do ox_inventory no `noir_police` **não bloqueia nada**. Ele só registra cada item que sai do inventário de outro jogador para o de um policial: item, quantidade, serial ou metadata, alvo, policial, local e hora. Essas são as **pendências** do policial.
3. **Caixa:** depois, o policial coloca tudo numa `seized_box` e a leva à delegacia.

**O que pode ser apreendido:**
- `black_money` (sujo): **sempre**, porque dinheiro sujo é crime por si só.
- `money` (limpo): depende da situação, e o motivo é obrigatório no depósito.
- Armas e itens ilegais.

**A `seized_box`:**
- É um item novo, **container do ox_inventory** (`setContainerProperties('seized_box', …)`). Quem está com ela pode abrir, tirar e colocar coisas. Os slots e o peso máximo vêm da config.
- Vem vazia do arsenal, e cada uma tem um id na metadata.
- **Peso:** o item vazio pesa 2,00 kg (`weight = 2000`). O ox_inventory soma o conteúdo ao peso do container (`Inventory.ContainerWeight`). Para o total ficar sempre em 2,00 kg, seria preciso alterar essa função no ox_inventory.
- Pode ser entregue, largada ou roubada como qualquer item. Perder a caixa antes do depósito é jogo: um criminoso pode levar a evidência.

**Depósito na sala de evidências:**
- A sala de evidências é um ponto por departamento em `departments.lua`, com uma stash do ox_inventory (`evidence_<departamento>`) de grade mínima para abrir.
- Um `leo` em serviço entrega a `seized_box` no ponto e preenche **alvo** (escolhido entre os das pendências dele) e **motivo**, que é obrigatório quando há dinheiro limpo.
- O servidor move o conteúdo da caixa para a gaveta como `filled_evidence_bag` (o item já existe), com metadata de alvo, policial, data e hora, local, motivo e conteúdo. Depois apaga a caixa e registra quem depositou.
- **Conferência:** o servidor compara o que foi depositado com as pendências daquele policial.
  - O que bate sai das pendências.
  - O que **foi tirado de alguém e não chegou à gaveta** continua pendente e, depois de um prazo definido na config, vai para o log como desvio.
  - Assim a supervisão enxerga o policial que embolsa, e a mecânica continua sem trava.
- Uma caixa já depositada, pelo id, é recusada e vai para o log.
- Cápsula, projétil, digital e sangue coletados são itens de evidência comuns, levados à sala e guardados na mesma gaveta.

**Destino do que está na gaveta** (ações com grade mínima e log):
- sujo e ilegal: **destruir**;
- limpo: **devolver** ao dono, pelo citizenid da metadata, ou **incorporar** à sociedade do departamento, com decisão registrada.

**Log:** toda retirada de jogador, depósito, pendência vencida, destruição e devolução, com quem fez.

### 4.2 Arsenal (`noir_shops`)

O arsenal é uma loja do `noir_shops` com NPC, uma por delegacia e departamento (`JobRestriction = 'police'`, `'bcso'`, `'sasp'`), com `grade` por item. O que o `noir_shops` já faz e serve:
- restrição por job, blip e target só para quem tem acesso;
- grade mínima por item, validada no servidor;
- distância do checkout;
- item de preço 0 (o `RemoveMoney(0)` do qbx_core passa);
- metadata fixa por item: o ox_inventory clona a metadata antes de preencher `registered` e `serial`, então uma compra não contamina a próxima.

**O que precisa adaptar no `noir_shops`:**

| # | Falta | Por quê | Adaptação |
|---|---|---|---|
| 1 | Exigir serviço | Hoje a restrição olha só o nome do job. Policial fora de serviço compra no arsenal | Campo `DutyRequired = true` na loja, conferido no servidor (checkout) e no cliente (target e blip) |
| 2 | Limite de posse | Com preço 0, o `maxQty` vale só por carrinho. Dá para repetir o checkout, juntar 50 pistolas e vender para o crime | Campo `maxHeld` por item: o servidor conta com `ox_inventory:Search` o que o jogador já tem e recusa acima do limite |
| 3 | Log | `Config.LogType = 'discord'` com `WebhookURL = ''`, então hoje nenhum log sai | Trocar para `lib.logger`, que já manda para o fivemanage. Toda retirada no arsenal fica registrada |

**Configuração do catálogo (sem código novo):**
- **Preço 0** e **sem `license`** nos itens do arsenal. Porte de arma é regra de civil.
- **Armas:** `metadata = { registered = '<departamento>', serial = '<prefixo>' }`.
  - O prefixo precisa ter **até 3 letras** (`POL`, `BCS`, `SAS`). O `GenerateSerial` do ox devolve o texto como serial fixo quando ele tem mais de 3 letras, e todas as armas sairiam com o mesmo serial.
  - Uma arma com `registered = 'LSPD'` na mão de civil vira evidência de desvio.
- **Itens:** armas e munição por grade, `handcuffs`, `handcuffkey`, `spikestrip`, `shield`, `evidence_case` (bolsa de evidências) e `seized_box`.
- **Zip tie e cortador:** também vão para a loja de ferramentas (`hardware`), porque o zip tie é liberado para civil.
- **Remover** o `PoliceArmoury` do `ox_inventory/data/shops.lua`, para não haver dois arsenais.

Fica para depois: cobrar a retirada da conta do departamento, em vez de sair de graça, e a cautela, que é devolver o equipamento ao sair de serviço.

### Segunda leva (quando fizer falta)

| Módulo | No qbx_police | Nota |
|---|---|---|
| Radar de velocidade e multa | `client/anpr.lua`, `police:server:Radar`, `radars.speedFines` | **Entra.** Multa automática com a faixa do config. A velocidade vem do cliente, então o servidor precisa limitar o valor e a frequência por jogador. O dinheiro vai para a sociedade do departamento |
| ANPR e placa marcada | `/flagplate`, `/unflagplate`, `/plateinfo`, `isPlateFlagged` | O ps-mdt pode ser a fonte da flag |
| Câmeras de segurança | `client/camera.lua`, `/cam`, eventos de câmera | O qbx_bankrobbery desliga as câmeras no roubo |
| Tornozeleira | `client/tracker.lua`, `/anklet`, `/ankletlocation` | |
| Heli: câmera e holofote | `client/heli.lua`, `heli:spotlight` | Checar os natives de câmera no Enhanced |
| Digital e sangue | `client/evidence.lua` (sangue, digital), NUI de digital, `/takedna` | **Entra.** Atende `CreateFingerDrop`, `CreateBloodDrop` e `SetStatus` (seção 3), e a coleta vai para a mesma gaveta de evidências (seção 4.1). A NUI de digital vai para a v4 |
| Pagar reboque e advogado | `/paytow`, `/paylawyer` | Só se houver os jobs |

### Não importar

| O quê | Por quê |
|---|---|
| Algema, soft cuff e escolta do qbx | Substituídas pelas do ND |
| Cápsula do qbx | Substituída pela cápsula e projétil por munição do ND |
| Spike por comando (`/spikestrip`) | Substituída pelo item do ND |
| Prisão (`/jail`, `/unjail`, `JailPlayer`) | Já é do xt-prison com o ps-mdt |
| Callbacks deprecated do QBCore (`police:IsPlateFlagged` etc.) | Legado |

### Interações de cidadão (também vêm do qbx_police)

O submenu **"Interação" do `qbx_radialmenu`** é de todo mundo, não só da polícia, e hoje quem responde a ele é o qbx_police. Se o qbx_police sair sem substituto, os civis perdem estas ações:

| Opção do radial | Evento qbx | O que faz hoje | Como fica |
|---|---|---|---|
| Algemar | `police:client:CuffPlayer` | Algema com o item `handcuffs`, sem checar emprego | Algema e zip tie do ND. Algema só para `leo` em serviço; zip tie liberado para qualquer um |
| Escoltar | `police:client:EscortPlayer` | Civil escolta alvo algemado, morto ou caído; `leo` e `ems` escoltam qualquer um | Escolta do ND com as mesmas condições, validadas no servidor |
| Colocar e tirar do veículo | `PutPlayerInVehicle`, `SetPlayerOutVehicle` | Qualquer um, com o alvo algemado, morto ou caído | Mesma regra, no módulo de escolta |
| Sequestrar | `police:client:KidnapPlayer` | Carrega no ombro (`firemans_carry`) alvo algemado, morto ou caído | Carregar no ombro, no mesmo módulo |
| Roubar | `police:client:RobPlayer` | Leva **todo** o dinheiro vivo de quem está de mãos para cima, algemado ou morto, sem checar emprego | Só `openNearbyInventory`. O `canSteal` do ox já faz o resto (lacuna 4). O dinheiro é roubado como item |
| Revistar | `police:server:SearchPlayer` | | Módulo de revista (primeira leva) |
| Fazer refém | `police:client:TakeHostage` | **Nada:** não há handler em nenhum resource | Tirar do radial, ou fazer depois como mecânica própria |

Essas ações moram no `noir_police`, porque dividem estado com ele (algema, escolta, mãos para cima). Mas não exigem `leo`: cada uma tem a sua condição sobre o **alvo**.

## 5. O que vem do ND (mecânicas)

| Mecânica | Arquivo ND | Ajuste |
|---|---|---|
| Mãos para cima (clique) e ajoelhar (segurar) | `client/cuff.lua` | Keybind por `lib.addKeybind`. Bloquear com arma na mão, se decidirmos |
| Algema e zip tie com prop e som, frente e costas, normal e agressiva | `client/cuff.lua`, `server/cuff.lua` | Checagens da seção 2.2, metadata `ishandcuffed` |
| Fuga da algema agressiva por skillcheck | `client/cuff.lua` | O resultado é decidido pelo callback que o servidor controla |
| Escolta com animação e pôr no veículo | `client/escort.lua` | Checagens da seção 2.2. Soltar ao desalgemar |
| Cápsula e projétil por tipo de munição | `client/evidence.lua`, `server/evidence.lua`, `data/evidence.lua` | Anti-spam na criação |
| GSR (15 min, sai na água em 1 min) | `client/gsr.lua` | Teste só em serviço e perto |
| Escudo balístico | `client/shield.lua` | Checar o prop do escudo no Enhanced |
| Spike strip com quantidade e animação | `client/spikes.lua` | Limites no servidor |
| Shotspotter (zonas, ignora supressor) | `client/shotspotter.lua`, `data/shotspotter.lua` | Alerta via `bgrz_core:SendDispatch` (hoje `Bridge.shotSpotter` é vazio no qb) |
| Armário de roupa por departamento | `client/locker_rooms.lua`, `data/*` | Roupa via illenium-appearance. O `/getclothing` do NDCore não existe aqui, então é preciso uma forma de capturar a roupa |

## 6. Ideias do ars (reescritas do zero)

- **Área interditada:** o policial marca um raio no mapa e todos veem o blip por X minutos. Só em serviço, com limite por policial.
- **Status de unidade:** "Adam-12 em patrulha, local X", avisado aos colegas do departamento.
- **Chamar reunião:** motivo e frequência de rádio, aviso para o departamento.
- **Quebrar algema com lockpick:** skillcheck no cliente, **resultado validado no servidor** (tempo mínimo, item consumido) e metadata atualizada. No ars só o cliente sabia.

## 7. Decisões (30/09/2026)

1. **Algema e zip tie:** qualquer um algema (algema ou zip tie) quem está rendido: mãos para cima, ajoelhado ou caído. Só o `leo` em serviço algema quem não se rendeu, na algemação agressiva com chance de fuga (revisto no teste de 30/09).
2. **Apreensão de dinheiro:** sujo e limpo. O sujo é sempre crime; o limpo depende da situação e exige motivo. Na rua, o policial tira os itens para o próprio inventário, depois põe tudo numa `seized_box` e deposita na sala de evidências do departamento. O que foi tirado de alguém e não foi depositado vira pendência no log (seção 4.1).
3. **Contagem de policiais:** export `GetCopCount(department?)` no servidor, entrando agora (seção 3). Os mínimos por crime ficam para a revisão do ilegal.
4. **Digital e sangue:** portar, na segunda leva (seção 4).
5. **Radar de velocidade:** entra, na segunda leva (seção 4).

## 7.1 Lacunas da revisão (30/09/2026)

Achadas ao cruzar o plano com o código do ND, do ox_inventory e dos resources que já rodam. Cada item traz uma recomendação.

### Estado e segurança

1. **O cliente é dono do estado de algema no ND.**
   - `isCuffed`, `handsUp`, `gettingCuffed` e `isCuffing` são gravados pelo próprio cliente no state bag (`state:set(..., true)`), e o `client/main.lua:24` zera `isCuffed` a cada start. Um cliente modificado se desalgema sozinho, e o servidor confia nesses valores no `cuffCheck`.
   - **Recomendação:** `isCuffed`, `cuffType` e `isEscorted` são gravados só pelo servidor. O cliente só aplica o efeito e grava apenas `handsUp`, que é o consentimento dele próprio.
2. **Relogar solta a algema.** O qbx manda `SetHandcuffStatus(false)` no unload, e o ND zera no start.
   - **Recomendação:** guardar `ishandcuffed` e `cuffType` na metadata e reaplicar no login. Sair do jogo algemado não livra ninguém.
3. **O ox_inventory já deixa a polícia revistar qualquer um e levar os itens para o próprio bolso.**
   - Com `inventory:police = ["police","bcso","sasp"]`, o policial abre o inventário de qualquer jogador a 1,8 m (`ox_inventory/client.lua:195`).
   - **Decisão (30/09):** fica assim. Na rua, o policial tira a arma do suspeito rendido para o próprio inventário e depois põe na `seized_box`.
   - O hook `swapItems` só **registra** as pendências. A conferência acontece no depósito (seção 4.1).
   - O ox confere o grupo e não o serviço, então policial fora de serviço também revista. **Recomendação:** o hook recusa só esse caso (policial fora de serviço tirando item de outro jogador).
4. **"Roubar" já é nativo do ox.** O `canSteal` libera o inventário de quem está de mãos para cima, algemado ou morto.
   - A opção do radial só precisa chamar `openNearbyInventory`. Não existe módulo novo.
   - Atenção: a animação de ajoelhado do ND (`random@arrests@busted`) não está na lista do `canOpenTarget` do ox. Ajoelhado **sem algema** não pode ser roubado. Recomendo manter assim, porque ajoelhar é render-se para a polícia.

### Sobreposição com o que já existe

5. **Impound já existe em dois lugares.**
   - O `ps-mdt` tem `server/backend/impound.lua` (tabela `mdt_impound`, pátios em `Config.Impound.Lots`, histórico).
   - O `noir_garage` cobra a taxa de depot (`SetVehicleDepotPrice`).
   - **Recomendação:** o `noir_police` só faz a ação no mundo (ox_target na viatura, progress, checagens) e grava pelo backend do ps-mdt, com o preço pelo `noir_garage`. Não cria tabela própria. Confirmar o export do ps-mdt.
6. **O `noir_garage` já tem uma garagem de job `police`** (`config/server.lua`, `groups = 'police'`, só LSPD).
   - **Recomendação:** as viaturas da frota (lista por departamento e grade, sem dono) ficam no `noir_police`, e a garagem `police` sai do `noir_garage`. Assim sobra um caminho só.
7. **Arsenal:** o plano não tinha. **Decisão (30/09):** fica no `noir_shops` (seção 4.2).
8. **Gaveta de evidências:** o ox_inventory já tem uma nativa (`data/evidence.lua` com `mrpd_evidence`, `inventory:evidencegrade 2`).
   - **Recomendação:** a gaveta do `noir_police` substitui essa. Tirar o `mrpd_evidence` do ox para não haver duas salas.
9. **Mãos para cima em dobro.** O `scully_emotemenu` tem um módulo `handsup` com keybind próprio, que não grava o state bag do ND. O zip tie nunca reconheceria esse gesto.
   - **Recomendação:** desligar o handsup do scully e deixar só o do `noir_police`.

### Departamentos fora da polícia

10. **Configs com `police` fixo**, onde BCSO e SASP ficam de fora:
    - `mm_radio/shared/shared.lua`: canais policiais só para `{"police","ambulance"}`;
    - `sky_phone/config/config.lua`: serviço de emergência com `Job = "police"`;
    - `noir_garage` (item 6);
    - `ps-mdt` `Config.Impound.Lots`: conferir se há pátio por departamento;
    - `ox_doorlock`: portas das delegacias por grupo.

    **Recomendação:** revisar todos no mesmo passo em que o `departments.lua` nasce.

### Detalhes que faltavam

11. **Saco de evidência:** o qbx exigia `empty_evidence_bag` por coleta. **Decidido nos testes:** bolsa de evidências (`evidence_case`, container do ox_inventory, como a caixa de apreensão). A coleta de cápsula, projétil, digital, sangue e DNA cai direto dentro dela, sem gastar item; sem bolsa não coleta. A bancada de DNA lê as amostras no bolso e dentro da bolsa. O policial também colhe sangue de quem está contido, rendido ou caído.
12. **Cápsula sem serial:** o ND identifica a cápsula só pelo tipo de munição, e o qbx gravava o serial da arma. **Recomendação:** gravar o `serial` da arma (metadata do ox) na cápsula. É o que liga arma e cena do crime.
13. **Pólvora em dobro:** ao portar o `SetStatus` do qbx, o status `gunpowder` duplica o GSR do ND. **Recomendação:** tirar o `gunpowder` da lista do qbx e ficar com o GSR do ND.
14. **Log:** o servidor já usa `ox:logger = fivemanage`. **Recomendação:** tudo pelo `lib.logger`, sem canal novo.
15. **Persistência:** as pendências e os ids de caixa depositados precisam sobreviver a restart. **Recomendação:** tabelas no banco: `noir_police_seizures` (item tirado, alvo, policial, status, datas) e `noir_police_deposits`.
16. **Interface:** as telas próprias (depósito, gaveta, frota, digital) seguem a DESIGN_v4. Menu simples fica em `lib.registerContext`.
17. **Não importar:** `/911p` (o 911 do sky_phone cobre) e a lixeira da delegacia (`policetrash`), porque o destino "destruir" da gaveta já cobre.

## 8. Ordem de execução

1. **Fork:** copiar o ND para `[noir]/noir_police`, tirar os bridges e o detector, escrever `bridge/bgrz` e `data/departments.lua`.
2. **Assets:** converter os ydr para v159 e testar áudio, props e anims isolados.
3. **Brechas:**
   - corrigir tudo da seção 2.2 e ajustar os itens da seção 2.3;
   - servidor dono do estado de algema, persistência no relog e hook `swapItems` de pendências (lacunas 1 a 3).
4. **Primeira leva do qbx:**
   - duty, blips, garagem e heli, impound, multa, objetos, revista, licenças, callsign, officer down;
   - apreensão com gaveta de evidências e o export `GetCopCount`;
   - arsenal no `noir_shops`, com as adaptações da seção 4.2;
   - as interações de cidadão do radial.
5. **Contratos:**
   - ajustar o radial, o sky_phone, o qbx_medical e o qbx_adminmenu;
   - migrar os `policeAlert` para `SendDispatch`;
   - tirar a garagem `police` do noir_garage, o `mrpd_evidence` do ox e o handsup do scully (lacunas 6, 8 e 9);
   - revisar as configs com `police` fixo (lacuna 10).
6. **Tirar o `qbx_police`:** mover para `disabled_resources/[qbx]/qbx_police`, conferir que nenhum `provide` ou nome sobra, reiniciar e fazer o join.
7. **Auditoria:** §24 do SCRIPT_GOOD_PRACTICES e teste em jogo de cada ação com dois jogadores.
8. **Segunda leva** e ideias do ars, sob demanda.

## 9. Estado da implementação (30/09/2026)

Aplicado no working tree, sem commit. Detalhes de uso em `resources/[noir]/noir_police/README.md`.

**Feito:**
- `resources/[noir]/noir_police`: todos os módulos das seções 4, 4.1, 5 e 6, a primeira e a segunda leva, e as lacunas 1 a 17.
- Impound: ficou com o **impound no local do ps-mdt** (`client/impound_onsite.lua` dele), que já faz a ação no mundo, o formulário e o histórico. O `noir_police` não tem módulo de impound.
- `bgrz_core`:
  - `GetJob` traz `type`;
  - exports novos `SetJobDuty` e `GetOnDutyPlayersByType`;
  - evento novo `bgrz_core:server:playerRespawned`;
  - o fallback de dispatch aponta para o `noir_police`;
  - testes atualizados.
- `ox_inventory`:
  - itens novos (`zipties`, `handcuffkey`, `cutters`, `seized_box`, `shield`, `spikestrip`, `casing`, `projectile`), e `handcuffs` passou a usar o `noir_police`;
  - saíram o `PoliceArmoury` e a gaveta `mrpd_evidence`.
- `noir_shops`:
  - `DutyRequired`, `maxHeld` e log pelo `lib.logger`;
  - arsenais `armory_mrpd`, `armory_mrpd_sasp` e `armory_paleto`;
  - zip tie e alicate na loja de ferramentas.
- Religados:
  - `qbx_radialmenu`: cidadão e polícia, BCSO e SASP usando o menu da polícia, porta-malas;
  - `qbx_medical`: sangue e respawn;
  - `qbx_adminmenu`;
  - `qbx_consumables`;
  - `qbx_ambulancejob`;
  - `qbx_bankrobbery`: alerta, digital e câmeras;
  - `qbx_jewelery`, `qbx_storerobbery`, `qbx_houserobbery`, `qbx_drugs` e `noir_houserobbery`: alerta e digital.
- Departamentos fora da polícia: `mm_radio` (canais), `xt-prison` (`PoliceJobs`) e `sky_phone` (voz) agora incluem `bcso` e `sasp`. A garagem `police` saiu do `noir_garage`; nenhum veículo estava guardado nela.
- `server.cfg`: `ensure noir_police` depois do `noir_houserobbery`, e `setr scully_emotemenu:handsUpKey ""`.
- `qbx_police` movido para `disabled_resources/qbx_police`.

**Falta (precisa de jogo):**
1. Reiniciar o servidor e fazer o join. Conferir o console do `noir_police`: migration, stash e hooks.
2. Converter os props do ND para v159 e testar o áudio (seção 2.4).
3. Acertar as coordenadas com o **`/policiaeditor`** (editor em jogo: delegacias, garagens e vagas, radares, câmeras, shotspotter; salva no banco e aplica na hora). O arsenal de Paleto é acertado pelo `/smartshopedit` do noir_shops.
4. Capturar os uniformes reais com `/noir_police_outfit`.
5. Testar cada ação com dois jogadores (seção 8, passo 7).

**Fora do escopo, anotado:**
- `ps-mdt`: `Config.Fingerprint` (`police:client:showFingerprint`) aponta para um evento que não existe mais. A leitura de digital agora é o leitor da delegacia do `noir_police`.
- `sky_phone`: o serviço de emergência (empresa `police`) ainda é só LSPD.
- `ox_doorlock`: conferir se as portas das delegacias liberam `bcso` e `sasp` (a configuração fica no banco).
- `ps-mdt`: a sentença dispara `police:client:SendToJail`, que não tem ouvinte. Já era assim antes: com o xt-prison ligado, o qbx_police não registrava esse evento. A prisão funciona pelo `Prender` do `noir_police`, que usa o `police:server:JailPlayer` do xt-prison e solta a algema de quem entra na cela.
- `ps_lib` (bridge `lj`): chama `police:server:SearchPlayer`, mas o servidor usa o bridge do ox_inventory.
- Ajoelhado conta como algemação agressiva, como no ND: minigame de fuga e algema nas costas. Só a mão para cima de pé é algemação normal.
