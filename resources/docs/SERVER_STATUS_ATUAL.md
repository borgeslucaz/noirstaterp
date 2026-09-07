# Noir State RP — Status atual do servidor

> Snapshot técnico do repositório em **06/09/2026**. Este documento descreve o que existe no workspace e as decisões de integração aplicadas. Ele não substitui o estado de execução: o `server.cfg` é ignorado pelo Git e não está presente neste checkout.

## Leitura rápida

| Estado | Significado |
|---|---|
| **Confirmado** | É possível provar pelo arquivo, código ou localização no repositório. |
| **Pretendido** | É a configuração que o projeto deve usar; confirmar no `server.cfg`/txAdmin. |
| **Não confirmado** | O resource existe no disco, mas não há como saber se foi iniciado sem o `server.cfg` ou console. |

O servidor usa **FiveM GTA V Enhanced**, **Qbox/QBX**, `ox_*` e os módulos próprios Noir/BGRZ. A HUD em uso pretendida é `noir_hud`; o mapa Atlas foi incorporado nela nesta revisão.

## Fonte de verdade operacional

- Recursos instalados: `resources/`.
- Ordem e recursos efetivamente iniciados: `server.cfg` (ausente deste checkout e não deve ser versionado por conter credenciais).
- Empregos registrados: `[qbx]/qbx_core/shared/jobs.lua`.
- Empregos oferecidos pela prefeitura: `[qbx]/qbx_cityhall/config/shared.lua`.

Para confirmar o runtime, use no console do FXServer:

```text
ensure noir_hud
stop neen-atlasmap-en2
stop minimal-hud_enhanced
```

Depois valide pelo console/txAdmin quais resources estão `started`. Nunca deixe duas HUDs ou dois resources de roubo residencial iniciados ao mesmo tempo.

## Base e dependências — pretendidas ativas

| Camada | Recursos | Papel |
|---|---|---|
| Banco e utilitários | `oxmysql`, `ox_lib` | Banco MySQL e biblioteca comum. |
| Qbox | `qbx_core`, `qbx_spawn`, `qbx_smallresources`, `qbx_density`, `qbx_radialmenu`, `qbx_adminmenu`, `qbx_scoreboard`, `qbx_idcard`, `qbx_management` | Personagens, permissões, spawn, qualidade de vida, administração e empresas. |
| OX | `ox_inventory`, `ox_target`, `ox_fuel`, `ox_doorlock` | Inventário, interações, combustível e portas. |
| Voz | `pma-voice`, `mm_radio`, `mana_audio` | Voz de proximidade, rádio e áudio. |
| Interface e aparência | `noir_hud`, `noir_chat`, `noir_pausemenu`, `illenium-appearance`, `scully_emotemenu`, `loadscreen` | HUD, chat, pause, aparência, emotes e carregamento. |
| Economia/mundo | `Renewed-Banking`, `Renewed-Weathersync`, `vehiclehandler`, `qbx_vehiclekeys`, `qbx_garages`, `qbx_vehicles`, `qbx_vehicleshop`, `qbx_vehiclesales`, `qbx_customs`, `qbx_carwash` | Banco, clima, veículos, chaves, garagens, loja e customização. |

Os resources acima existem no repositório. A palavra “ativa” nesta tabela é intenção arquitetural; a confirmação final continua sendo o `server.cfg`.

## Desenvolvimento próprio Noir/BGRZ

| Resource | Origem/status | Responsabilidade atual |
|---|---|---|
| `bgrz_core` | Próprio | Camada server-side de leitura normalizada sobre Qbox: personagem, emprego, gangue, dinheiro, licenças e fingerprint. Não cria economia ou empregos. |
| `bgrz_interact_examples` | Próprio/demonstração | Exemplos de interações/NPCs. Não é sistema de gameplay essencial; avaliar se deve rodar em produção. |
| `noir_multichar` | Próprio | Seleção/criação de personagens integrada ao Qbox e Illenium Appearance. |
| `noir_chat` | Próprio | Chat de texto e comandos. Substitui o chat CFX padrão quando iniciado. |
| `noir_hud` | Fork customizado para Noir | HUD de status/veículo e minimapa quadrado; bridge Qbox. Agora também hospeda o mapa Atlas e o zoom do radar. |
| `noir_pausemenu` | Próprio | Pause menu e foto; coordena visibilidade com a HUD. |
| `noir_taxijob` | Próprio | Taxi V2: central, aluguel, taxímetro/dispatcher, perfil, Confiança e ranking server-authoritative. É atividade autônoma: não muda `PlayerData.job`. |
| `noir_graffiti` | Próprio | Graffiti ligado ao domínio ilegal Noir. |
| `noir_illegal_core` | Próprio | Serviço de progressão criminal server-authoritative. |
| `noir_gangs` | Próprio | Gestão de gangues Qbox. |
| `noir_burnerphone` | Próprio | Burner phone para atividades ilegais. |
| `noir_houserobbery` | Próprio, baseado em `qbx_houserobbery` | Contratos de roubo residencial Tier 1. |
| `noir_shell` | Próprio | Biblioteca para spawn e entrada/saída de interiores shell. |
| `noir_shell_test` | Teste interno | Recurso descartável de teste de shells; não é necessário em produção. |

## HUD e mapa — decisão atual

### `noir_hud`: ativo pretendido

`noir_hud` é o único resource que deve controlar a interface de HUD e o minimapa. Sua configuração atual deixa `minimapAlways = false`, portanto o comportamento esperado é:

- a pé: minimapa desligado;
- dentro de veículo: minimapa ligado.

O código reafirma esse estado periodicamente para impedir que scripts de spawn/login do Qbox deixem o radar ligado indevidamente.

### Atlas: migrado para `noir_hud`

Os 80 assets do `neen-atlasmap-en2` foram migrados para `[hud]/noir_hud/stream_enhanced/`:

- 65 arquivos `minimap_*.ydd`;
- 13 arquivos `minimap_*.ytd`;
- `gfx/minimap_main_map.gfx` e `gfx/int3232302352.gfx`.

O `noir_hud` recebeu `this_is_a_map("yes")` e as configurações de zoom do Atlas. Os arquivos próprios `minimap.gfx`, `minimap.ytd` e `squaremap.ytd` continuam no Noir e controlam a interface/máscara do radar.

**Ação obrigatória:** não iniciar `neen-atlasmap-en2` no `server.cfg`. O diretório foi mantido apenas como histórico/backup; seu `stream/` está vazio depois da migração.

### HUDs que não devem coexistir

| Resource | Situação |
|---|---|
| `noir_hud` | **Usar.** |
| `minimal-hud_enhanced` | Instalado, mas é HUD concorrente. **Não iniciar** junto com `noir_hud`. |
| `qbx_hud` | Removido do repositório em mudança anterior; substituído por HUD customizada. |
| `element_hud`, `lcp_hud_v4`, `rember-hud` | Removidos do repositório em mudanças anteriores; não fazem parte da pilha atual. |

## Empregos iniciais

### Emprego padrão de um personagem novo

O único emprego padrão confirmado pelo Qbox é:

| Chave | Nome exibido | Grade inicial |
|---|---|---|
| `unemployed` | Civilian | Freelancer (0) |

O personagem nasce como `unemployed`. O `noir_multichar` cria/carrega o personagem; o Qbox persiste o emprego. Apartamentos iniciais Qbox estão desativados na configuração documentada do projeto.

### Empregos oferecidos na prefeitura

O menu de emprego de `qbx_cityhall` está habilitado e oferece estes trabalhos na configuração presente:

| Chave | Emprego |
|---|---|
| `unemployed` | Desempregado |
| `trucker` | Caminhoneiro |
| `taxi` | Táxi |
| `tow` | Guincho |
| `reporter` | Repórter |
| `garbage` | Coletor de lixo |
| `bus` | Motorista de ônibus |

Esses são os empregos públicos iniciais configurados para troca pela prefeitura. A seleção define o emprego principal em grade 0.

### Catálogo de empregos Qbox registrados

Além dos públicos acima, o Qbox reconhece:

| Categoria | Chaves |
|---|---|
| Segurança e saúde | `police`, `bcso`, `sasp`, `ambulance` |
| Empresas e serviços | `realestate`, `cardealer`, `mechanic`, `reporter` |
| Justiça | `judge`, `lawyer` |
| Atividades públicas | `trucker`, `taxi`, `tow`, `garbage`, `bus`, `vineyard`, `hotdog` |
| Estado inicial | `unemployed` |

Os recursos de gameplay presentes para atividades/empregos incluem `qbx_busjob`, `qbx_garbagejob`, `qbx_towjob`, `qbx_vineyard`, `qbx_recyclejob`, `qbx_pawnshop`, `qbx_mechanicjob`, `qbx_newsjob`, `qbx_ambulancejob`, `qbx_police` e `peak-trucking`.

Observações importantes:

- `noir_taxijob` é renda extra independente. O jogador pode trabalhar nele sem trocar seu emprego principal para `taxi`.
- `peak-trucking` é o Truck V1 Noir (mercado global) e usa a identidade de caminhoneiro como contexto de gameplay.
- A existência de um emprego no Qbox não confirma que existe um ponto/atividade pública acessível; isso depende de cada resource e do `server.cfg`.

## Crime, serviços e gameplay instalados

| Área | Recursos presentes |
|---|---|
| Policial/médica | `qbx_police`, `qbx_ambulancejob`, `qbx_medical`, `ps-mdt`, `xt-prison` |
| Roubos | `qbx_bankrobbery`, `qbx_jewelery`, `qbx_storerobbery`, `qbx_truckrobbery`, `noir_houserobbery` |
| Ilegal | `qbx_drugs`, `qbx_weed`, `op-drugselling`, `noir_illegal_core`, `noir_gangs`, `noir_graffiti`, `noir_burnerphone` |
| Corridas/veículos | `qbx_lapraces`, `qbx_streetraces`, `qbx_binoculars`, `qbx_divegear`, `qbx_diving` |
| Utilidades | `qbx_fireworks`, `qbx_idcard`, `qbx_properties`, `qbx_cityhall`, `qbx_management` |
| Minigames | `mhacking`, `safecracker`, `ultra-voltlab`, `peuren_minigames` |

## Mapa, interiores e assets

| Tipo | Recursos presentes |
|---|---|
| Mapa visual/base | `visual_enhanced`, mapa Atlas migrado para `noir_hud` |
| Hospital e locais | `pillbox`, `PillboxHospital`, `burgershot_enhanced`, `ingot_taxi_enhanced`, `interior_ballas` |
| Shells/interiores | `lev-apartments`, `lynx_shells`, `shells`, `noir_shell`, `bob74_ipl` |
| Aparência/mundo | `dragnova_enhanced`, `appearance_redesign`, `phmc` |

Os assets são compatíveis com a organização Enhanced do projeto, que usa diretórios `stream_enhanced` em resources customizados.

## Confirmadamente desativado, removido ou destinado a não iniciar

| Item | Estado | Motivo/ação |
|---|---|---|
| `[disabled]/qb-interior` | **Desativado confirmado** | Está fisicamente na pasta `[disabled]`; não incluir em `ensure`. |
| `neen-atlasmap-en2` | **Desativar** | Assets e zoom migrados para `noir_hud`; não iniciar. |
| `minimal-hud_enhanced` | **Desativar se `noir_hud` iniciar** | Evita disputa por `minimap.gfx`, `minimap.ytd` e radar. |
| `noir_shell_test` | **Desativar em produção** | É resource de teste manual. |
| `qbx_houserobbery` | **Verificar/evitar duplicação** | Há o substituto Noir `noir_houserobbery`; não rodar ambos sem decisão explícita. |
| `qbx_hud`, `qbx_scrapyard`, `element_hud`, HUDs legadas | **Removidos** | Não existem mais no workspace atual; aparecem apenas no histórico Git/documentação antiga. |

## Inventário por grupo

| Grupo | Conteúdo principal |
|---|---|
| `[bgrz]` | Core Noir, multichar, domínio ilegal, gangues, burnerphone, house robbery e shells. |
| `[hud]` | `noir_hud` e a alternativa concorrente `minimal-hud_enhanced`. |
| `[qbx]` | Core, empregos, veículos, polícia, médico, crimes e utilitários Qbox. |
| `[ox]` | Lib, banco, inventário, target, combustível e portas. |
| `[voice]` | Voz e rádio. |
| `[standalone]` | Aparência, telefone, banco, pause, chat, táxi, caminhão, prisão, minigames e integrações. |
| `[assets]` | MLOs, shells, mapas e melhorias visuais. |
| `[tools]` | Ferramentas de desenvolvimento: `dolu_tool` e `Shadowforge-devtools`; evitar em produção salvo necessidade. |
| `[disabled]` | Conteúdo explicitamente desativado. |

## Checklist de operação após esta revisão

1. Garanta `ensure noir_hud`.
2. Remova/pare `neen-atlasmap-en2` e `minimal-hud_enhanced`.
3. Não rode `noir_shell_test` em produção.
4. Escolha somente um roubo residencial: a intenção atual é `noir_houserobbery`.
5. Reinicie o servidor e entre com um personagem:
   - a pé, o minimapa deve ficar desligado;
   - ao entrar em veículo, o minimapa deve aparecer;
   - ao sair, deve sumir;
   - o mapa grande e o minimapa devem usar a textura Atlas.
6. Atualize este documento quando o `server.cfg` mudar. Uma cópia sanitizada da ordem de `ensure` (sem licença, banco, tokens ou webhooks) permitiria confirmar o estado de runtime.

## Documentos relacionados

- `GENERAL.MD`: manual geral anterior; contém referências históricas que precisam ser lidas com esta atualização em mente.
- `CORE.md`: API e limites de `bgrz_core`.
- `MULTICHAR.md`: multicharacter.
- `noir_taxi/TAXI_V2.md`: Taxi V2 implementado.
- `noir_truckjob/NOIR_TRUCK_V1.md`: especificação/estado do Truck V1.
- `ilegal/`: domínio ilegal Noir.
