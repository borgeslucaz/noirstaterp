# Noir Truck V2 — Mercado global baseado em rotas e progressão por XP

> Status: especificação funcional, técnica e de NUI para implementação.
>
> Resource atual: resources/[standalone]/peak-trucking.
>
> Nome final do resource: resources/[standalone]/noir-truckjob.
>
> Este documento substitui as decisões conflitantes do NOIR_TRUCK_V1.md. O V1 continua sendo referência apenas para fluxos não alterados explicitamente aqui.
>
> A V2 será instalada em ambiente de desenvolvimento com banco limpo. Não haverá migração de empresas, reputação ou missões legadas.

## 1. Visão do produto

O Noir Truck V2 usa uma única unidade de trabalho: a **rota**.

Não existem empresas, confiança, reputação ou missões como conceitos funcionais. As 37 rotas físicas atuais continuam preservadas, mas passam a formar um catálogo plano. Cada oferta da rotação aponta diretamente para uma rota.

~~~text
Central de fretes
      ↓
16 ofertas globais da rotação atual
      ↓
rotas elegíveis ordenadas por XP previsto
      ↓
primeiro motorista elegível inicia
      ↓
coleta → transporte → entrega → devolução
      ↓
nota S–D + dinheiro + XP + histórico
~~~

A progressão é única e cumulativa:

~~~text
entrega concluída → XP global → nível global
                              → libera mais rotas e caminhões
~~~

## 2. Decisões fechadas

1. A unidade funcional é a rota; o conceito de missão será removido.
2. O sistema de empresas será removido completamente.
3. Não existirão confiança, reputação, pontos ou desbloqueios por empresa.
4. O catálogo terá 37 rotas canônicas planas.
5. Coordenadas, spawns, destinos, veículos, carretas, cargas e fluxos especiais atuais serão preservados.
6. Cada rotação terá exatamente 16 ofertas: 4 low, 5 medium e 7 high.
7. Cada oferta continuará global, única e com capacidade para um motorista.
8. O jogador poderá iniciar no máximo uma oferta por rotação.
9. Rotas serão desbloqueadas somente por XP global convertido em nível.
10. Os requisitos de nível serão mínimos cumulativos; níveis altos mantêm acesso às rotas inferiores.
11. A aba Missões exibirá somente ofertas disponíveis e elegíveis da rotação atual.
12. A lista será ordenada por XP previsto crescente.
13. A tela Principal conterá o stats-row e, abaixo, um Top 5 compacto.
14. A navegação será: Principal | Missões | Classificação | Perfil.
15. O app-shell terá largura e altura reduzidas linearmente em 25%.
16. O ranking será ordenado por nível, XP e quantidade de rotas concluídas.
17. O banco será reinstalado do zero durante o desenvolvimento; não haverá compatibilidade com dados legados.
18. O resource peak-trucking será renomeado para noir-truckjob em todos os pontos públicos e internos da V2.

## 3. Renomeação do resource

O nome final será **noir-truckjob**. A renomeação deve ser completa e não apenas visual.

Alterar:

- pasta resources/[standalone]/peak-trucking para resources/[standalone]/noir-truckjob;
- nome e descrição no fxmanifest.lua;
- marca “Peak Trucking” no header, títulos e textos da NUI;
- nomes de eventos e callbacks com prefixo peak-trucking para noir-truckjob;
- exports que incluam o nome antigo;
- comandos, logs e tags de debug que identifiquem o resource;
- documentação, README, mocks e comentários relevantes;
- entradas ensure/start da configuração do servidor;
- nomes das tabelas do banco na instalação limpa.

Nomes canônicos das novas tabelas:

- noir_truckjob_players;
- noir_truckjob_offers;
- noir_truckjob_deliveries.

Não será mantido alias, evento legado ou camada de compatibilidade com peak-trucking. Dependências externas do servidor que chamem exports ou eventos antigos deverão ser atualizadas para o novo nome.

## 4. Terminologia

| Termo | Definição |
|---|---|
| Rota | Trabalho físico completo: coleta, veículo/carreta, carga, destino, devolução e metadados econômicos. |
| Catálogo | As 37 rotas canônicas preservadas e organizadas em uma coleção plana. |
| Oferta | Instância global e temporária de uma rota na rotação atual. |
| Rotação | Janela global de 60 minutos com exatamente 16 ofertas. |
| Tier | Classificação low, medium ou high usada para geração e bônus. |
| Nível mínimo | Menor nível necessário para iniciar uma rota; nunca funciona como nível máximo. |
| XP previsto | XP da oferta assumindo nota B, sem bônus ilegal. |
| Disponível para o jogador | Oferta globalmente disponível, elegível por nível e com pelo menos um caminhão compatível desbloqueado. |

Os nomes “missão” e “empresa” podem aparecer apenas ao descrever estruturas legadas que serão removidas. Eles não fazem parte do contrato final da V2.

## 5. Catálogo plano de rotas

### 5.1 Identidade

Cada rota terá um identificador estável de route_01 a route_37.

Durante a refatoração, a chave legada missionId:routeIndex serve apenas para localizar os dados atuais. Ela não será exposta pela NUI nem persistida nas novas tabelas.

Estrutura final:

~~~lua
Config.Routes = {
    {
        id = 'route_01',
        title = 'LS Dock → Paleto',
        cargoType = 'madeira',
        tier = 'low',
        estimatedMinutes = 30,
        baseXP = 520,
        reqLevel = 10,

        -- dados físicos atuais preservados
        vehicles = {},
        trailerModel = 'trailerlogs',
        pickupSpawns = {},
        destination = vector3(0, 0, 0),
    },
}
~~~

Config.Missions, companyIndex, reqPoint e requirementsLabel deixam de ser fontes funcionais. Informações compartilhadas pela antiga missão devem ser copiadas uma única vez para cada rota durante a conversão do catálogo.

Na conversão inicial:

- title recebe o header descritivo legado;
- routeLabel recebe o label legado da rota;
- cargoType recebe um valor canônico da seção 5.3;
- os demais dados físicos são movidos sem alteração.

### 5.2 Níveis provisórios por distância/duração

Os níveis iniciais serão calculados pela duração estimada já derivada da distância real. Estes valores são provisórios e poderão ser rebalanceados depois.

| Tier | Duração estimada | reqLevel |
|---|---:|---:|
| low | até 15 min | 1 |
| low | 16–20 min | 5 |
| low | 21–30 min | 10 |
| low | acima de 30 min | 14 |
| medium | até 25 min | 15 |
| medium | 26–28 min | 20 |
| medium | 29–30 min | 25 |
| medium | acima de 30 min | 30 |
| high | até 14 min | 35 |
| high | 15–18 min | 40 |
| high | 19–23 min | 45 |
| high | 24–27 min | 50 |
| high | 28–31 min | 55 |
| high | acima de 31 min | 60 |

Tabela inicial das 37 rotas:

| routeId | Chave legada | Tier | Minutos | baseXP | reqLevel |
|---|---|---|---:|---:|---:|
| route_01 | 1:1 | low | 30 | 520 | 10 |
| route_02 | 1:2 | low | 32 | 560 | 14 |
| route_03 | 1:3 | low | 30 | 540 | 10 |
| route_04 | 2:1 | low | 14 | 320 | 1 |
| route_05 | 2:2 | low | 18 | 380 | 5 |
| route_06 | 3:1 | medium | 32 | 820 | 30 |
| route_07 | 3:2 | medium | 33 | 840 | 30 |
| route_08 | 4:1 | medium | 28 | 780 | 20 |
| route_09 | 4:2 | medium | 30 | 800 | 25 |
| route_10 | 5:1 | medium | 28 | 760 | 20 |
| route_11 | 5:2 | medium | 34 | 860 | 30 |
| route_12 | 5:3 | medium | 29 | 780 | 25 |
| route_13 | 6:1 | medium | 28 | 760 | 20 |
| route_14 | 15:1 | medium | 24 | 700 | 15 |
| route_15 | 15:2 | medium | 25 | 720 | 15 |
| route_16 | 16:1 | medium | 29 | 800 | 25 |
| route_17 | 16:2 | medium | 30 | 820 | 25 |
| route_18 | 7:1 | high | 11 | 620 | 35 |
| route_19 | 7:2 | high | 13 | 660 | 35 |
| route_20 | 8:1 | high | 16 | 760 | 40 |
| route_21 | 8:2 | high | 21 | 860 | 45 |
| route_22 | 8:3 | high | 23 | 900 | 45 |
| route_23 | 9:1 | high | 26 | 980 | 50 |
| route_24 | 9:2 | high | 18 | 820 | 40 |
| route_25 | 9:3 | high | 12 | 700 | 35 |
| route_26 | 10:1 | high | 14 | 760 | 35 |
| route_27 | 10:2 | high | 17 | 820 | 40 |
| route_28 | 11:1 | high | 34 | 1200 | 60 |
| route_29 | 11:2 | high | 34 | 1200 | 60 |
| route_30 | 12:1 | high | 16 | 800 | 40 |
| route_31 | 12:2 | high | 13 | 740 | 35 |
| route_32 | 12:3 | high | 22 | 920 | 45 |
| route_33 | 13:1 | high | 25 | 1100 | 50 |
| route_34 | 13:2 | high | 31 | 1250 | 55 |
| route_35 | 13:3 | high | 24 | 1080 | 50 |
| route_36 | 14:1 | high | 25 | 1150 | 50 |
| route_37 | 14:2 | high | 25 | 1150 | 50 |

### 5.3 Tipos de carga

Cada rota deve possuir cargoType explícito. Não inferir esse campo de requirementsLabel, pois os textos legados possuem inconsistências.

Mapeamento inicial:

| Rotas | cargoType |
|---|---|
| route_01–route_03 | madeira |
| route_04–route_05 | equipamentos_tv |
| route_06–route_07 | cigarros_embalados |
| route_08–route_09 | tabaco_embalado |
| route_10–route_12 | graos_fardos |
| route_13 | alimentos_uvas |
| route_14–route_15 | moveis_ferramentas |
| route_16–route_17 | caixas_manuais |
| route_18–route_19 | veiculos_luxo |
| route_20–route_21 | barcos |
| route_22 | jet_ski |
| route_23–route_25 | computadores |
| route_26–route_27 | chips |
| route_28–route_32 | petroleo |
| route_33–route_35 | veiculos_militares |
| route_36–route_37 | carga_militar_especial |

Esses identificadores são internos e estáveis. A NUI traduz cada cargoType para um rótulo localizado em português.

A carga ilegal continua sendo um complemento opcional da sessão e não um tipo principal de rota.

## 6. Rotação e geração

### 6.1 Ciclo

A rotação dura 60 minutos e é alinhada ao relógio do servidor. Restart dentro da mesma janela não cria outra rotação.

### 6.2 Quantidade

Cada rotação gera exatamente:

| Tier | Ofertas |
|---|---:|
| low | 4 |
| medium | 5 |
| high | 7 |
| Total | 16 |

Não duplicar routeId dentro da mesma rotação. Rotas usadas nas duas rotações anteriores podem receber peso menor, mantendo o comportamento determinístico atual.

### 6.3 Faixas cumulativas

Os tiers possuem apenas nível mínimo:

~~~lua
levelBands = {
    low = { min = 1 },
    medium = { min = 15 },
    high = { min = 35 },
}
~~~

Não existe max. Um jogador de nível 35 pode iniciar ofertas low, medium ou high, desde que atenda também ao reqLevel da rota e ao nível do caminhão.

### 6.4 Concorrência e estados

Os estados internos completos serão mantidos:

- available;
- starting;
- in_progress;
- completed;
- failed;
- failed_system;
- expired;
- unavailable.

A projeção pode marcar uma oferta como locked para um jogador inelegível, sem alterar o estado global available salvo no servidor.

Somente ofertas que satisfaçam todos estes critérios aparecem na aba Missões:

~~~text
estado global = available
AND jogador atende reqLevel
AND jogador atende o mínimo do tier
AND existe caminhão compatível desbloqueado
AND jogador ainda não iniciou oferta nesta rotação
AND jogador não possui sessão ativa
~~~

Quando outro motorista inicia uma oferta, ela desaparece da lista após o evento de atualização ou ressincronização. Estados não disponíveis continuam persistidos para concorrência, histórico, métricas e recuperação, mas não aparecem nessa lista.

## 7. XP, nível e recompensa

XP é global. O perfil armazena nível atual e XP restante dentro do nível atual, conforme o sistema existente.

Fórmula exata:

~~~text
xpFinal = floor(baseXP × (1 + bonusXpTier) × multiplicadorDaNota)
          + bonusXpIlegal
~~~

O xpPreview exibido na oferta é:

~~~text
xpPreview = floor(baseXP × (1 + bonusXpTier))
~~~

Portanto, o preview assume nota B, multiplicador 1,00, e não inclui carga ilegal.

| Nota | Multiplicador de XP |
|---|---:|
| S | 1,25 |
| A | 1,10 |
| B | 1,00 |
| C | 0,75 |
| D | 0,40 |

A conclusão concede pagamento, XP, histórico e estatísticas. Não concede empresa, confiança, reputação ou pontos.

O relatório final mostra nota, pagamento, XP recebido, nível anterior, nível atual e progresso para o próximo nível.

## 8. NUI

### 8.1 Tamanho do app-shell

Somente o app-shell será redimensionado. HUD da entrega, notificações, relatório e chamada telefônica mantêm os tamanhos atuais.

O shell atual ocupa aproximadamente 91vw × 91,2vh. A redução linear de 25% define o alvo desktop:

~~~css
.app-shell {
    width: 68.25vw;
    height: 68.4vh;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
}
~~~

A animação de entrada deve incorporar translate(-50%, -50%) em todos os keyframes para não deslocar o shell.

### 8.2 Navegação

A navegação final será:

~~~text
Principal | Missões | Classificação | Perfil
~~~

Mapeamento recomendado:

~~~ts
type Page = 'main' | 'routes' | 'leaderboard' | 'profile'
~~~

A página Companies e o componente CompaniesView serão removidos. Não haverá uma página separada de Progressão.

### 8.3 Principal

A área de conteúdo da Principal contém somente:

1. o stats-row existente;
2. abaixo dele, o ranking compacto Top 5.

O header e a navegação permanecem fora dessa regra de conteúdo.

O stats-row mantém motorista, rotas concluídas, ganhos totais, nível/XP e contador da próxima rotação.

Devem ser removidos da Principal os contratos, frota, missões diárias e checkout atualmente renderizados pelo DispatchView.

### 8.4 Top 5 da Principal

Ordem SQL e desempate:

~~~sql
ORDER BY level DESC, xp DESC, globalCompleted DESC, identifier ASC
LIMIT 5
~~~

Se todos os três valores empatarem, usar identifier ASC apenas como último desempate técnico estável. O identifier nunca será enviado para a NUI.

O ranking considera apenas jogadores com pelo menos uma rota concluída. O cache continua com 60 segundos. A Principal usa a métrica fixa level; não há seletor nesse ranking compacto.

Cada linha mostra posição, avatar, nome, nível e XP atual. Se o usuário não estiver no Top 5, sua posição não é adicionada ao widget compacto.

A aba Classificação completa continua existindo e pode manter as métricas Nível e Rotas concluídas. Seu backend deve usar globalCompleted como quantidade de rotas concluídas.

### 8.5 Aba Missões

Apesar do rótulo visual “Missões”, esta aba trabalha exclusivamente com ofertas de rota da rotação atual. Não existe entidade Mission no código novo.

Ela mostra somente ofertas disponíveis para o jogador conforme a regra da seção 6.4.

Ordenação obrigatória:

~~~text
xpPreview ASC
reqLevel ASC
routeId ASC
~~~

Cada card mostra:

- título da rota;
- tipo de carga;
- trajeto usando o label canônico atual da rota;
- XP previsto;
- nível mínimo;
- tier;
- pagamento previsto;
- duração estimada;
- caminhões compatíveis;
- ação para selecionar caminhão e iniciar.

Estados vazios obrigatórios:

- nenhuma oferta elegível nesta rotação;
- jogador já usou sua oferta da rotação;
- jogador possui rota ativa;
- carregando;
- falha de sincronização.

### 8.6 Perfil

O Perfil mantém estatísticas e histórico, usando routeId, título da rota, carga, tier, nota, dinheiro, XP, status e data.

Não mostrar empresa ou reputação.

### 8.7 Contrato de dados

~~~ts
type RouteOffer = {
  offerId: string
  rotationId: string
  routeId: string
  title: string
  cargoType: string
  routeLabel: string
  tier: 'low' | 'medium' | 'high'
  reqLevel: number
  estimatedMinutes: number
  paymentPreview: number
  basePayPreview: number
  xpPreview: number
  moneyBonusPercent: number
  xpBonusPercent: number
  status: 'available' | 'starting' | 'in_progress' | 'completed' |
          'failed' | 'failed_system' | 'expired' | 'unavailable'
  eligible: boolean
  lockReasons: string[]
  mine: boolean
  compatibleTrucks: TruckProjection[]
}
~~~

O snapshot envia todos os estados necessários para sincronização, mas o client filtra a lista visível com status available e eligible true. O servidor repete todas as validações ao iniciar.

Pedido de início:

~~~ts
{ offerId: string, truckModel: string }
~~~

O client nunca envia rota completa, XP, nível, pagamento, tier, carga ou coordenadas.

## 9. Remoção completa de empresas e missões

Remover:

- Config.Companies;
- Config.Reputation e GetReputationTier;
- Config.Missions após a conversão para Config.Routes;
- companyIndex, companyName, points, reputation e reputationPreview;
- reqPoint e verificações de reputação;
- página e componente CompaniesView;
- traduções exclusivas de empresa/reputação;
- empresa no relatório e histórico;
- reputation_awarded nas entregas;
- bônus reputation dos tiers e notas;
- sincronização de points;
- eventos ou callbacks de desbloqueio por empresa;
- mocks, tipos e estilos sem consumidores.

Missões diárias:

- remover a diária two_companies;
- remover campos e recompensas reputation de todas as diárias;
- manter somente diárias baseadas em conclusão, nota, tier, integridade ou prazo;
- recompensas diárias permanecem em XP, salvo balanceamento posterior.

Nenhuma entidade, campo ou regra funcional de empresa, company, confiança, trust, reputação, reputation, missão ou mission deve permanecer. O rótulo visual da aba “Missões” e o subsistema independente de missões diárias não recriam a entidade de catálogo removida.

## 10. Banco e instalação limpa

A V2 não implementará migração de dados legados. Durante o desenvolvimento, o administrador removerá as tabelas do resource e fará uma instalação limpa.

Tabelas antigas a remover antes da instalação limpa:

- peak_trucking;
- peak_trucking_global_offers;
- peak_trucking_deliveries.

O novo schema não terá:

- points;
- unlockedMissions;
- mission_id;
- route_index;
- company_index;
- reputation_awarded;
- campos JSON de reputação ou empresa.

Ofertas e entregas persistirão route_id. O perfil preservará somente dados globais necessários: identifier, xp, level, totalEarnings, completedJobs, failedJobs, globalCompleted, globalFailed, name, avatar e dados das missões diárias ainda válidas.

O install.sql será a fonte canônica do schema e criará somente noir_truckjob_players, noir_truckjob_offers e noir_truckjob_deliveries. O código de inicialização não deve recriar tabelas ou colunas legadas.

Esta política é adequada apenas ao ambiente de implementação atual. Antes de produção, qualquer mudança destrutiva de schema exigirá backup e migration explícita.

## 11. Segurança server-authoritative

O servidor valida:

- identidade e estado da oferta;
- routeId existente no catálogo;
- nível mínimo da rota e do tier;
- caminhão compatível e desbloqueado;
- limite de uma oferta por jogador/rotação;
- ausência de outra sessão ativa;
- proximidade da central, coleta, destino e devolução;
- entidades esperadas de caminhão, carreta e carga;
- tempo mínimo plausível;
- conclusão idempotente;
- pagamento e XP concedidos uma única vez.

## 12. Arquivos esperados

| Área | Mudança |
|---|---|
| shared/config.lua | substituir Config.Missions por Config.Routes plano e preservar dados físicos |
| shared/contract_config.lua | mover metadados para rotas, remover empresas/reputação e máximos dos tiers |
| server/rotation.lua | gerar/projetar ofertas por routeId |
| server/contracts.lua | validar reqLevel sem reputação e concluir por routeId |
| server/dailymissions.lua | remover empresas e two_companies |
| server/main.lua | novo schema, perfil limpo e Top 5 |
| install/install.sql | schema limpo baseado em route_id |
| ui/src/App.tsx | nova navegação e páginas |
| ui/src/components | Principal compacta, aba de rotas e remoção de CompaniesView |
| ui/src/types/trucking.ts | tipos baseados em RouteOffer |
| ui/src/styles.css | shell 75% nas duas dimensões e layouts compactos |
| locales e mockData | remover empresas/reputação e atualizar rotas |
| pasta do resource e fxmanifest.lua | renomear peak-trucking para noir-truckjob |
| eventos, callbacks e exports | substituir namespace peak-trucking por noir-truckjob |
| server.cfg e integrações externas | atualizar ensure, eventos e exports para o novo resource |

## 13. Critérios de aceite

### Catálogo e progressão

- existem exatamente 37 Config.Routes com routeId único;
- nenhuma coordenada, spawn, destino, carreta, carga ou fluxo especial foi alterado;
- cada rota possui tier, estimatedMinutes, baseXP, reqLevel e cargoType;
- todos os requisitos são níveis mínimos cumulativos;
- jogador de nível alto continua elegível para rotas de nível inferior;
- nenhuma elegibilidade consulta empresa ou reputação.

### Mercado

- cada rotação possui exatamente 16 ofertas: 4 low, 5 medium e 7 high;
- cada routeId aparece no máximo uma vez por rotação;
- somente uma pessoa pode adquirir cada oferta;
- cada jogador inicia no máximo uma oferta por rotação;
- a aba Missões mostra apenas ofertas available e eligible da rotação atual;
- a lista é ordenada por xpPreview, reqLevel e routeId.

### Interface

- navegação final: Principal, Missões, Classificação e Perfil;
- Principal contém stats-row e Top 5, além do header global;
- Top 5 usa nível, XP e rotas concluídas como desempate;
- app-shell mede 75% da largura e 75% da altura anteriores;
- HUD, relatório, notificações e telefone não são redimensionados;
- nenhum texto ou componente de empresa/reputação permanece.

### Dados e segurança

- o resource inicia com o nome noir-truckjob;
- nenhum texto, evento, export, log ou referência funcional usa peak-trucking;
- server.cfg e integrações externas usam o novo nome;
- somente as tabelas noir_truckjob_players, noir_truckjob_offers e noir_truckjob_deliveries são criadas;
- instalação limpa cria schema sem colunas legadas;
- ofertas e entregas usam route_id;
- XP usa a fórmula e arredondamento definidos;
- xpPreview assume nota B e exclui carga ilegal;
- client não controla elegibilidade, rota, pagamento ou XP;
- conclusão, pagamento e XP são idempotentes;
- restart não recria ofertas nem recompensas dentro da mesma rotação.

## 14. Matriz mínima de testes

1. Gerar rotação com 4 low, 5 medium e 7 high sem routeId duplicado.
2. Confirmar que nível 35 pode ver rotas elegíveis low, medium e high.
3. Confirmar que oferta abaixo do reqLevel não aparece na aba Missões.
4. Confirmar ordenação por xpPreview e desempates.
5. Iniciar simultaneamente a mesma oferta com dois jogadores; apenas um vence.
6. Confirmar desaparecimento da oferta adquirida.
7. Confirmar limite de uma oferta por jogador na rotação.
8. Validar Top 5 e desempate por globalCompleted.
9. Confirmar dimensões do app-shell em resolução de referência.
10. Confirmar que HUD e relatório mantêm tamanho.
11. Concluir notas S, B e D e validar XP exato.
12. Reiniciar resource e confirmar idempotência.
13. Executar busca por resíduos de empresa/reputação no código final.
14. Instalar banco vazio e confirmar ausência das colunas legadas.
15. Executar as 37 rotas e validar preservação de coordenadas e fluxos especiais.
16. Iniciar o resource por ensure noir-truckjob e validar eventos, exports e callbacks renomeados.
17. Buscar resíduos de peak-trucking no resource final e confirmar que não há referências funcionais.
