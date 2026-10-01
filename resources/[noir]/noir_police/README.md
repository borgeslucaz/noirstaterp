# noir_police

Polícia do servidor. Substitui o `qbx_police` (agora em `disabled_resources/qbx_police`).
Nasceu de um fork do [ND_Police](https://github.com/ND-Framework/ND_Police) (commit
`a8a1d6f`) e herda a licença **GPL-3.0** (`LICENSE.md`). O plano completo está em
`docs/Plano da polícia (noir_police).md`, na raiz do repositório.

## O que tem

| Módulo | Cliente | Servidor |
|---|---|---|
| Contenção | mãos para cima (X, segurar ajoelha), algema, zip tie, arrombar algema, escolta, carregar no ombro, viatura | `server/state.lua` é a verdade; state bag é espelho regravado se o cliente mexer |
| Serviço | ponto de duty por delegacia, blips de colegas (polícia e EMS) | `GetCopCount`, `police:SetCopCount` (legado) |
| Evidência | cápsula e projétil por tiro, sangue, digital, GSR, exame, DNA, leitor de digital | pontos no servidor, só policial em serviço recebe |
| Apreensão | depósito da `seized_box`, pendências, gaveta, destino; bônus de 15% do valor de rua na destruição para quem depositou, teto de $1.000/h (`seizure.bonus`) | hook `swapItems` registra pendência; tabela no banco; bônus de offline pago no próximo ponto |
| Frota | garagem e heliponto por delegacia, armário de uniforme | uma viatura ativa por policial |
| Campo | menu F6: status, área interditada, reunião, limpar evidência, 10-99; multa, licença, tornozeleira, prisão (xt-prison) | teto por departamento, log; multa (campo e radar) vira fatura bloqueante no Renewed-Banking via `bgrz_core:CreateInvoice` |
| Equipamento | objetos do porta-malas, spike strip, escudo | objetos e spikes criados no servidor |
| Vigilância | radar, câmeras de segurança, helicóptero (câmera, holofote, rapel) | velocidade medida no servidor, ANPR, placas marcadas |

## Editor de posições (`/policiaeditor`)

Só admin (ACE `noir.police.admin`, dada ao `group.admin` no `permissions.cfg`). Edita:
- **delegacias**: nome, departamentos, blip, pontos de serviço, armários, sala de evidências, leitor de digital, mesa de câmeras, garagens e vagas;
- **radares** (posição, direção e limite);
- **câmeras de segurança** (captura a posição e o ângulo da câmera do jogo; dá para ver por ela antes de salvar);
- **sensores do shotspotter**.

Posiciona por mira, como o editor do noir_garage: o ponto segue o chão, a roda do mouse gira (Shift acelera), Enter confirma e Backspace cancela. Vaga de viatura usa uma viatura fantasma. "Mostrar marcadores" desenha tudo o que está perto.

Cada alteração é salva na hora na tabela `noir_police_layout`, validada inteira no servidor (`shared/layout.lua`), e as zonas de todos os jogadores se refazem sem restart. Tipo sem linha no banco usa o config, que fica só como semente. "Voltar ao config" apaga a linha.

Os arsenais são lojas do `noir_shops` e têm o editor dele (`/smartshopedit`).

## Departamentos

Polícia é todo job `type = 'leo'` que esteja em `config/shared.lua > departments`
(hoje `police`, `bcso`, `sasp`), **em serviço**, conferido no servidor. Grade mínima
por ação em `grades` (sobrescreve por departamento em `departments.<job>.grades`).
Subunidade (K9, SWAT) por grade mínima ou lista de citizenId em `subunits`.

## Integrações

- Tudo de jogador, dinheiro, metadata, itens, dispatch e veículo passa pelo
  `bgrz_core` (`server/integrations.lua`, `client/integrations.lua`).
- `ox_target` é chamado direto (§2.5 do SCRIPT_GOOD_PRACTICES).
- `ox_inventory` é chamado direto **só** para hook, stash, container e inventário
  aberto à força: o `registerHook` guarda o dono por `GetInvokingResource()`, e pelo
  bridge o hook ficaria atribuído ao `bgrz_core`.
- Prisão: evento `police:server:JailPlayer` do xt-prison (ele confere polícia e distância).

## Exports

Servidor: `IsCuffed(src)`, `ReleaseRestraints(src)`, `GetCopCount(department?)`,
`Alert(src, message, coords?)`, `AddBloodDrop(src, coords?)`, `AddFingerprint(src, coords?)`,
`IsPlateFlagged(plate)`, `SetCameraOnline(index|indexes, online)`, `SetAllCamerasOnline(online)`.

Cliente: `IsHandcuffed()`, `GetCopCount()`, e os usos de item
(`useCuffs`, `useZipties`, `useCuffKey`, `useCutters`, `useShield`, `useSpikestrip`).

Eventos de rede aceitos de outros resources: `noir_police:server:alert` (mensagem),
`noir_police:server:fingerprintDrop` e `noir_police:server:bloodDrop` (coords), todos
com rate limit e posição conferida no servidor. Evento local
`noir_police:client:setEvidenceStatus` (status, segundos) para consumíveis.

## Pendências de teste em jogo

- **Escudo**: a mira de uma mão vem do `ND_GunAnims` (`[standalone]`, GPL-3.0), como no ND; sem ele o escudo funciona, mas a mira fica com as duas mãos.
- **Props do ND**: convertidos para v159 e em `stream_enhanced/` (`cuffs.customProps = true`).
  Os originais legacy (v165) ficam em `assets/pending_stream` só como referência.
- **Áudio do ND** (`assets/pending_audio`): testar se `AUDIO_WAVEPACK` carrega no
  Enhanced antes de ligar `cuffs.customSound`.
- **Coordenadas de Paleto** (armário, evidência, leitor, garagem) e o ponto das
  câmeras em Mission Row foram estimados: acertar com o `/policiaeditor`.
- **Uniformes** (`config/outfits.lua`) usam roupa do jogo base; capturar os reais com
  `/noir_police_outfit`.
- Escudo: ossos da mão e das costas escolhidos sem teste.

## Testes

```
cd resources/[noir]/noir_police
for s in tests/unit/*_spec.lua; do lua5.4 $s; done
```
