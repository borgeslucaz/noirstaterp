# Noir Taxi V2 — Planejamento funcional, técnico e de NUI

> Status: **implementado em 2026-09-05** no resource `noir_taxijob` (v2.1.0). As decisões da seção 31 foram aplicadas com os defaults deste documento e podem ser ajustadas em `serverConfig.lua` (`Progression`, `Ranking`, `Central`, `Migration`) e `config.lua` (`RentalVehicles`, `Depot`).
>
> Resource alvo: `noir_taxijob`.
>
> Referências internas obrigatórias: `resources/docs/DESIGN_v2.MD`, `resources/docs/TAXI.md`, implementação atual do `noir_taxijob` e implementação histórica do `ak4y-taxi` no commit `91242a71`.

## 1. Visão do produto

O Taxi V2 mantém o fluxo automático e server-authoritative do Taxi Job atual, mas recupera os melhores conceitos do resource antigo:

- perfil persistente do taxista;
- progressão por nível;
- ranking;
- histórico agregado de trabalho;
- veículos liberados por nível;
- uma NUI de central antes de alugar o veículo.

A implementação antiga serve somente como referência de produto. Não devem ser restaurados callbacks, dependências, queries concatenadas, nomes `ak4y-*`, loops ou decisões de confiança no client antigo.

O princípio do V2 é:

```text
CENTRAL DO TÁXI
      ↓
consulta perfil e catálogo
      ↓
NUI: Overview / Veículos / Ranking
      ↓
jogador escolhe um veículo permitido pelo seu nível
      ↓
servidor valida e cria o veículo sem alterar o emprego do personagem
      ↓
NUI fecha
      ↓
HUD compacto e trabalho automático atual
```

O menu da central e o HUD do taxímetro são duas experiências diferentes dentro da mesma identidade visual:

- **Menu da central:** NUI interativa, com mouse e teclado, aberta somente fora do veículo e perto do atendente;
- **HUD de trabalho:** apresentação compacta, sem foco NUI e sem mouse, ativa enquanto o jogador dirige.

## 2. Objetivos

### 2.1 Objetivos funcionais

1. Permitir que qualquer personagem conheça seu perfil e alugue um táxi como renda extra.
2. Mostrar nível atual e Confiança necessária para o próximo nível.
3. Mostrar ganhos do dia e total de corridas concluídas.
4. Exibir um catálogo de veículos com bloqueio por nível.
5. Impedir no servidor o aluguel de veículos ainda bloqueados.
6. Exibir ranking geral de taxistas.
7. Atualizar progressão e estatísticas somente após uma corrida validada pelo servidor.
8. Preservar o dispatcher, taxímetro, conforto e pagamento server-authoritative existentes.
9. Suportar vários taxistas simultaneamente sem estado global compartilhado incorretamente.
10. Manter custo de CPU, tráfego NUI e consultas ao banco previsíveis.

### 2.2 Objetivos de UX

- A NUI deve tornar a progressão compreensível em poucos segundos.
- O botão principal do Overview deve levar claramente ao catálogo de veículos.
- Veículos bloqueados devem continuar visíveis para comunicar metas futuras.
- O jogador nunca deve descobrir um bloqueio apenas depois de clicar.
- A interface deve parecer parte do mesmo equipamento do taxímetro atual.
- O centro da tela deve permanecer visualmente respirável, conforme o Noir Design V2.
- Abrir ou fechar a central nunca deve alterar emprego, grade ou duty.
- Trabalhar como taxista não deve substituir a profissão principal do personagem.

### 2.3 Fora do escopo desta versão

- restaurar o código antigo literalmente;
- implementar as funcionalidades neste documento;
- missões diárias;
- compra permanente de veículos;
- garagem pessoal de táxi;
- customização de veículo;
- temporadas competitivas;
- prêmio monetário por posição no ranking;
- multiplicador de pagamento por veículo;
- escolha manual de região de trabalho;
- ranking em tempo real a cada corrida;
- painel administrativo de balanceamento;
- aplicativo de celular para taxistas;
- equipes, empresas ou frotas compartilhadas.

Esses itens podem ser extensões futuras, mas não devem aumentar o MVP silenciosamente.

## 3. Terminologia

| Termo | Significado no V2 |
|---|---|
| Confiança | Pontuação persistente de progressão do Taxi Job. Substitui o termo XP na interface. |
| Nível de Confiança | Nível derivado exclusivamente da Confiança acumulada. |
| Confiança restante | Quantidade necessária para atingir o próximo nível. |
| Ganhos de hoje | Soma de pagamentos de corridas validadas dentro do dia canônico do servidor. |
| Corridas concluídas | Total vitalício de corridas NPC pagas e confirmadas. |
| Catálogo | Lista configurada no servidor com os veículos de trabalho. |
| Veículo bloqueado | Veículo cujo nível mínimo é maior que o nível atual do jogador. |
| Aluguel | Concessão temporária de um veículo de trabalho criado pelo servidor. |
| Perfil | Registro persistente da progressão e dos agregados do taxista. |
| Sessão da central | Autorização curta, vinculada ao jogador e à proximidade do NPC, para usar a NUI. |

O texto visível ao jogador deve usar **Confiança**, nunca `XP`, `jobrep`, `metadata` ou nomes internos.

## 4. Base histórica que será reaproveitada conceitualmente

A versão antiga continha:

- seis níveis calculados por XP;
- catálogo com `taxi` no nível 1, `tailgater` no nível 3 e `stretch` no nível 6;
- Top 10 ordenado por XP;
- total ganho;
- rotas concluídas;
- seleção de veículo;
- bloqueio server-side por nível;
- perfil e progresso para o próximo nível;
- imagens dos veículos e elementos visuais temáticos.

O V2 reaproveita os conceitos, mas substitui:

| Legado | Taxi V2 |
|---|---|
| XP | Confiança |
| `ak4y-core` | Qbox + `bgrz_core`, conforme o contrato final do resource |
| tabela com JSON de rotas/tarefas | tabelas normalizadas e agregados atômicos |
| SQL concatenado | queries preparadas/parametrizadas |
| client selecionando dados sensíveis | servidor resolvendo catálogo, nível e recompensa |
| spawn iniciado pelo client | entidade criada e registrada pelo servidor |
| menu grande com muitos cards | composição Noir V2 com linhas fantasma e poucos painéis |
| região escolhida manualmente | dispatcher automático existente |
| taxímetro manual | máquina de estados e taxímetro automáticos existentes |
| atualização contínua de ranking | cache sob demanda |

## 5. Fluxo completo do jogador

### 5.0 Regra de atividade autônoma

O Taxi V2 é uma **atividade de renda extra**, não uma profissão Qbox.

- qualquer personagem carregado pode utilizar a central;
- um personagem `unemployed` permanece `unemployed` antes, durante e depois do trabalho;
- um personagem com qualquer outro emprego mantém exatamente o mesmo job, grade e duty;
- o resource não chama `SetJob`, `SetJobDuty` ou evento equivalente;
- o resource não exige `HasJob('taxi')` para abrir a central, alugar, receber chamadas ou concluir corridas;
- a autorização para trabalhar vem da sessão interna de aluguel do `noir_taxijob`;
- `taxista` significa, neste documento, um personagem com sessão válida do Taxi V2 — não um valor em `PlayerData.job`.

O job principal pode ser lido apenas para contexto, auditoria ou uma futura regra explícita de incompatibilidade. Ele não faz parte do requisito padrão do MVP.

#### Consequências técnicas obrigatórias

A implementação atual ainda foi construída em torno de `Config.Job = 'taxi'` e `Config.RequireDuty`. Na implementação do V2, essa autorização deve ser substituída por capacidade interna:

```text
PODE TRABALHAR
    = perfil válido
    + aluguel ativo pertencente ao jogador
    + veículo da sessão existente
    + jogador no banco do motorista
    + sessão não encerrada
```

Mudanças planejadas:

- `Taxi.canWork()` deixa de verificar `job.name` e `job.onDuty`;
- `Taxi.canWork()` passa a refletir a sessão/autorização devolvida pelo servidor;
- `Sessions.isEligible` deixa de chamar `HasJob`;
- `setAvailable`, aluguel, dispatcher e conclusão validam `ActiveRentals[source]` e o net ID correspondente;
- `Config.Job` e `Config.RequireDuty` deixam de ser requisitos de acesso e devem ser removidos ou marcados como legados;
- o callback atual de retirada nunca chama `qbx_core:SetJob` nem `qbx_core:SetJobDuty`;
- eventos `jobUpdated` e `dutyUpdated` não desativam corrida ou aluguel;
- trocar de profissão durante a atividade não recria nem encerra a sessão;
- pagamento continua usando a identidade do personagem e exports financeiros server-side do Qbox, sem depender do job;
- disconnect, devolução, destruição do veículo e encerramento explícito continuam sendo condições de cleanup.

O servidor não deve aceitar apenas um booleano client-side como `isTaxiWorker`. A capacidade deriva do registro autoritativo de aluguel/sessão mantido pelo próprio resource.

### 5.1 Primeiro acesso de qualquer personagem

```text
Jogador usa ox_target no atendente
      ↓
client pede abertura ao servidor
      ↓
servidor valida login + proximidade + estado permitido
      ↓
servidor cria sessão curta da central
      ↓
NUI abre em Overview
      ↓
jogador consulta progressão / veículos / ranking
      ↓
jogador escolhe veículo de nível 1 e confirma ALUGAR
      ↓
servidor revalida tudo
      ↓
servidor registra uma sessão autônoma de trabalho
      ↓
servidor cria veículo, entrega chaves e registra aluguel
      ↓
NUI fecha e HUD do taxímetro assume
```

Abrir a NUI ou alugar um veículo não altera o emprego. Depois de um aluguel válido, o servidor cria apenas a sessão interna do Taxi V2 e mantém `PlayerData.job` intacto.

### 5.2 Jogador com progressão existente

- Abre a mesma NUI.
- Recebe seu perfil persistente.
- Pode consultar o ranking sem iniciar trabalho.
- Pode alugar qualquer veículo liberado pelo nível.
- O duty da profissão principal não é consultado nem modificado.

### 5.3 Jogador empregado ou desempregado

Todos recebem o mesmo acesso à renda extra. O target permanece visível independentemente do cache de emprego. Polícia, mecânico, médico, desempregado ou qualquer outra profissão configurada não são convertidos para `taxi` e não precisam sair de seus empregos.

Se futuramente alguma profissão precisar ser impedida por regra de cidade, isso deve ser uma denylist explícita e server-side, desabilitada por padrão. Não usar a ausência do job `taxi` como bloqueio indireto.

### 5.4 Fechamento sem alugar

- Job, grade e duty permanecem inalterados.
- Nenhum veículo é criado.
- A sessão curta da central é invalidada.
- O foco NUI é liberado somente depois da animação de saída ou imediatamente em caso de resource stop.

## 6. Progressão de Confiança

### 6.1 Fonte de verdade

A Confiança deve ser calculada, armazenada e alterada pelo servidor.

O browser e o client recebem somente uma representação para exibição. Eles nunca enviam:

- nível calculado;
- Confiança atual;
- Confiança recebida;
- percentual de progresso;
- requisito de desbloqueio;
- quantidade de corridas;
- ganhos do dia.

O servidor deve derivar todos esses dados da persistência e da configuração.

### 6.2 Curva inicial proposta

Valores abaixo são defaults de planejamento. O módulo server-side do próprio `noir_taxijob` mantém a configuração canônica; o client recebe apenas a projeção necessária para apresentação.

| Nível | Confiança mínima | Próximo nível | Identidade sugerida |
|---:|---:|---:|---|
| 1 | 0 | 100 | Iniciante |
| 2 | 100 | 250 | Motorista |
| 3 | 250 | 500 | Profissional |
| 4 | 500 | 850 | Especialista |
| 5 | 850 | 1.300 | Veterano |
| 6 | 1.300 | máximo inicial | Elite |

Não devem existir intervalos ou sobreposições. O nível é o maior nível cuja confiança mínima seja menor ou igual à Confiança do jogador.

Exemplo:

```text
Confiança atual: 184
Nível atual: 2
Próximo nível começa em: 250
Confiança restante: 66
Progresso dentro do nível: (184 - 100) / (250 - 100) = 56%
```

No nível máximo:

- mostrar `NÍVEL MÁXIMO`;
- a barra fica completa;
- não mostrar um número artificial de Confiança restante;
- continuar acumulando Confiança para ranking, com limite técnico configurável para evitar overflow.

### 6.3 Ganho de Confiança proposto

A conclusão validada de uma corrida gera Confiança. A base inicial deve aproveitar a satisfação já calculada pelo servidor:

| Resultado | Confiança proposta |
|---|---:|
| Corrida concluída | +10 base |
| Passageiro satisfeito | +5 adicionais |
| Passageiro neutro | +2 adicionais |
| Passageiro insatisfeito | sem bônus |
| Chamada ignorada | 0 |
| Corrida cancelada | 0 |
| Corrida inválida/rejeitada | 0 |

No MVP não se recomenda remover Confiança por cancelamento, desconexão ou falha de NPC. Latência, crash e migração de entidade podem gerar falsos positivos. Penalidades futuras exigem telemetria e critérios separados.

O valor final deve ser calculado no mesmo ponto server-side que autoriza o pagamento. Uma corrida não pode atualizar dinheiro e falhar silenciosamente em atualizar progressão, nem ser contabilizada duas vezes por repetição do callback.

### 6.4 Independência do metadata do Qbox

A progressão do Taxi V2 pertence integralmente ao `noir_taxijob`.

Decisão definitiva:

- a tabela própria do Taxi V2 é a única fonte de verdade para Confiança, nível, ranking e estatísticas;
- `PlayerData.metadata.jobrep.taxi` não será lido;
- `PlayerData.metadata.jobrep.taxi` não será importado;
- `PlayerData.metadata.jobrep.taxi` não será atualizado nem usado como espelho;
- o resource não chama `GetJobReputation` ou `AddJobReputation` do `bgrz_core`;
- perfil, desbloqueios e ranking são sempre resolvidos pelo módulo de persistência do próprio resource;
- ausência de perfil cria uma linha própria com Confiança zero;
- falha na persistência própria não pode ser mascarada por fallback para metadata.

O Qbox continua sendo utilizado para identidade do personagem, sessão e pagamento server-side. Ele não controla a progressão específica do táxi.

### 6.5 Atualizações idempotentes

Cada corrida server-side deve possuir um `fareId` não reutilizável. A conclusão só produz efeitos uma vez:

1. validar sessão e estado `COMPLETING`;
2. verificar se `fareId` ainda não foi finalizado;
3. marcar a corrida como consumida no servidor;
4. registrar resultado persistente com chave única;
5. atualizar perfil e estatística diária;
6. efetuar pagamento pelo export server-side do Qbox;
7. retornar snapshot atualizado ao client.

Repetir a solicitação com o mesmo `fareId` deve retornar o resultado já conhecido ou uma rejeição idempotente, nunca pagar ou pontuar novamente.

## 7. Estatísticas

### 7.1 Ganhos de hoje

`Total ganho hoje` representa somente dinheiro recebido por corridas NPC do Taxi Job.

Não entram no total:

- dinheiro inicial do personagem;
- pagamentos administrativos;
- transferências entre jogadores;
- gorjetas manuais fora do sistema;
- reembolso de aluguel;
- corridas canceladas;
- estimativas ainda não pagas.

O dia deve ser determinado pelo servidor, nunca pelo relógio do browser. Configuração proposta:

```lua
Config.Progression.DayUtcOffsetMinutes = -180
Config.Progression.DayResetHour = 0
```

O servidor gera um `dayKey` determinístico, por exemplo `2026-09-05`, usando epoch, offset configurado e hora de corte. Se o projeto adotar UTC como regra global, usar offset `0` e documentar isso para o jogador.

Não é necessário zerar linhas em uma thread à meia-noite. Cada dia recebe sua própria chave; a NUI consulta apenas a chave atual. Isso evita timer permanente, corrida de reset e perda de histórico.

### 7.2 Corridas concluídas

O Overview mostra o total vitalício de corridas pagas.

Regras:

- incrementar exatamente uma vez por `fareId`;
- só incrementar depois das validações de destino, distância, tempo, veículo e sessão;
- não confiar em contador enviado pelo client;
- uma corrida com pagamento zero por regra de satisfação ainda pode contar somente se for considerada conclusão legítima pelo produto;
- o MVP deve decidir essa regra explicitamente. Default proposto: corrida válida conta, mesmo quando o multiplicador resultar em valor muito baixo, desde que não seja cancelada.

### 7.3 Dados mostrados depois da corrida

O HUD pode continuar mostrando por alguns segundos:

```text
CORRIDA FINALIZADA
$92
+15 Confiança
```

O client pode atualizar o snapshot local do Overview com a resposta do servidor, mas a próxima abertura sempre recarrega a fonte server-side.

## 8. Ranking

### 8.1 Ranking inicial

O MVP terá um ranking geral, sem temporadas, ordenado por Confiança acumulada.

Ordem determinística:

1. Confiança, decrescente;
2. corridas concluídas, decrescente;
3. instante em que atingiu a pontuação atual, crescente;
4. identificador interno apenas como último desempate, nunca exibido.

### 8.2 Conteúdo

A tela mostra:

- pódio visual discreto para posições 1, 2 e 3;
- lista do 4º ao 10º;
- posição do jogador separada caso esteja fora do Top 10;
- nome do personagem;
- nível;
- Confiança total;
- corridas concluídas.

Não exibir:

- citizen ID;
- license, Discord ID ou qualquer identificador;
- saldo do personagem;
- localização;
- status online sem uma necessidade real;
- URL externa de avatar não validada.

Fotos de perfil não fazem parte do MVP. Pode-se usar iniciais ou um ícone local para evitar dependência externa, tracking e falhas de carregamento.

### 8.3 Cache e custo

O ranking não precisa de atualização em tempo real.

Estratégia:

- consulta lazy quando a aba Ranking é aberta;
- cache server-side global com TTL inicial de 60 segundos;
- todas as pessoas dentro do TTL recebem o mesmo snapshot imutável;
- a conclusão de corrida marca o cache como `dirty`, mas não dispara query imediatamente;
- a próxima solicitação após o TTL reconstrói o cache;
- impedir múltiplas reconstruções concorrentes com uma promise/flag única;
- limitar a resposta a Top 10 + posição do solicitante;
- não criar thread para atualizar ranking continuamente;
- índice SQL alinhado a `confidence DESC, completed_rides DESC`.

Um botão `ATUALIZAR` é opcional. Se existir, deve respeitar o mesmo TTL e mostrar o instante do snapshot, sem forçar query por jogador.

## 9. Catálogo e aluguel de veículos

### 9.1 Catálogo inicial

Base conceitual da versão antiga:

| ID estável | Veículo | Modelo | Nível mínimo | Estado inicial |
|---|---|---|---:|---|
| `standard` | Táxi Standard | `taxi` | 1 | liberado para todos |
| `executive` | Executivo | `tailgater` | 3 | bloqueado até nível 3 |
| `limousine` | Limousine | `stretch` | 6 | bloqueado até nível 6 |

Os IDs estáveis são enviados pelo browser. O model hash, nível mínimo, preço e spawn continuam exclusivamente resolvidos pelo servidor.

Os modelos precisam também constar na allowlist usada para ativar o Taxi Job. Liberar um veículo no catálogo sem liberá-lo na validação do taxímetro é erro de configuração e deve ser detectado na inicialização do resource.

### 9.2 Campos planejados de configuração

```lua
Config.RentalVehicles = {
    standard = {
        label = 'Táxi Standard',
        model = 'taxi',
        requiredLevel = 1,
        rentalFee = 0,
        image = 'img/vehicles/taxi.webp',
        description = 'O clássico da cidade. Confiável e econômico.',
    },
    executive = {
        label = 'Executivo',
        model = 'tailgater',
        requiredLevel = 3,
        rentalFee = 0,
        image = 'img/vehicles/tailgater.webp',
        description = 'Atendimento executivo para motoristas experientes.',
    },
    limousine = {
        label = 'Limousine',
        model = 'stretch',
        requiredLevel = 6,
        rentalFee = 0,
        image = 'img/vehicles/stretch.webp',
        description = 'O nível máximo de confiança da central.',
    },
}
```

Valores são ilustrativos. O MVP começa sem multiplicador de pagamento por veículo. Desbloqueios devem representar prestígio e variedade, não vantagem econômica descontrolada.

### 9.3 Estado visual do veículo

Cada item deve estar em exatamente um estado:

- **Disponível:** nível suficiente e nenhuma restrição operacional;
- **Selecionado:** item com foco de decisão antes da confirmação;
- **Bloqueado:** nível insuficiente;
- **Indisponível:** desabilitado administrativamente ou model indisponível;
- **Em uso:** já alugado pelo jogador;
- **Carregando:** solicitação de aluguel em andamento.

Para bloqueado, mostrar simultaneamente:

- ícone de cadeado;
- texto `DESBLOQUEIA NO NÍVEL 3`;
- nível atual do jogador;
- baixa opacidade na imagem e nos dados;
- botão desabilitado e não focável como ação válida.

Não usar somente cor para comunicar bloqueio.

### 9.4 Fluxo de aluguel

1. Jogador abre a aba Veículos.
2. Seleciona um veículo liberado.
3. Painel de detalhes mostra nome, descrição, nível e eventual taxa.
4. Pressiona `ALUGAR VEÍCULO`.
5. Botão entra em loading e bloqueia cliques duplicados.
6. Browser envia apenas `vehicleId` ao client.
7. Client encaminha `vehicleId` e token da sessão ao callback server-side.
8. Servidor revalida proximidade, identidade, nível, catálogo, aluguel ativo e spawn.
9. Servidor cria a sessão autônoma sem alterar job, grade ou duty.
10. Servidor cobra taxa, se configurada, usando export server-side.
11. Servidor cria o veículo via OneSync, registra net ID e entrega chaves.
12. Client recebe sucesso, reproduz saída da NUI e libera foco.
13. O jogador é colocado no banco do motorista somente depois de a entidade existir e estar válida.
14. A state machine detecta o veículo vinculado à sessão e ativa `AVAILABLE`.

### 9.5 Regras server-side obrigatórias

Antes de criar o veículo:

- `source` corresponde a jogador conectado e carregado;
- sessão da central existe, não expirou e pertence ao `source`;
- ped está no mesmo routing bucket da central;
- ped está dentro da distância configurada do NPC;
- jogador está a pé;
- o emprego atual é irrelevante e não será modificado;
- jogador não está impedido por uma denylist opcional explicitamente habilitada;
- `vehicleId` é string curta e existe no catálogo server-side;
- veículo não está desabilitado;
- nível é recalculado com a Confiança persistida;
- nível atende `requiredLevel`;
- jogador não possui outro veículo de aluguel ativo;
- não existe solicitação concorrente de aluguel para o mesmo jogador;
- há spawn point livre no mesmo bucket;
- model está na allowlist e pode ser criado;
- taxa é válida e há saldo, quando aplicável;
- rate limit foi respeitado.

Depois do spawn:

- confirmar entidade e net ID;
- aplicar placa gerada server-side;
- atribuir chave server-side;
- registrar proprietário e `vehicleId` em memória;
- aplicar state bags de baixa frequência;
- retornar somente dados necessários ao client.

Se qualquer etapa posterior à cobrança falhar, a operação deve compensar a taxa e limpar entidade/sessão parcial. A ordem precisa evitar criar sessão ou cobrar antes de saber que existe uma vaga, sempre que possível.

### 9.6 State bags planejados

Usar somente metadados estáveis e pequenos:

```text
entity.state['noirTaxi:rental'] = true
entity.state['noirTaxi:owner'] = serverId ou identificador efêmero da sessão
entity.state['noirTaxi:vehicleId'] = 'standard'
```

Não replicar por state bag:

- tarifa atual a cada segundo;
- distância acumulada;
- Confiança;
- saldo;
- dados completos do perfil;
- tabela inteira do catálogo.

State bags não substituem os mapas autoritativos do servidor.

### 9.7 Retorno e cleanup

- Um jogador precisa devolver o aluguel atual antes de alugar outro.
- O servidor valida net ID, proprietário, proximidade e entidade.
- Veículo destruído encerra o vínculo.
- Mudança de job ou duty não interfere na sessão autônoma do táxi.
- Disconnect agenda ou executa cleanup seguro.
- Resource stop remove entidades controladas que ainda existam.
- O cleanup deve ser idempotente.
- Uma entidade migrada entre owners continua pertencendo à sessão server-side original.

## 10. Arquitetura da NUI

### 10.1 Modos do documento

Uma única página pode suportar dois modos de raiz claramente separados:

```text
root[data-mode='closed']  → nada visível
root[data-mode='menu']    → central interativa
root[data-mode='hud']     → HUD compacto atual
```

Alternativamente, menu e HUD podem usar roots irmãos. Em qualquer solução:

- nunca deixar menu invisível segurando foco;
- nunca mostrar HUD por baixo do menu sem intenção;
- o root e o documento permanecem transparentes;
- somente elementos visíveis recebem superfície;
- nenhum overlay fullscreen opaco;
- nenhum `backdrop-filter` fullscreen.

### 10.2 Navegação principal

Ordem fixa:

1. **OVERVIEW**
2. **VEÍCULOS**
3. **RANKING**

O botão `ALUGAR VEÍCULO` do Overview navega para o segundo item e posiciona o foco no primeiro veículo disponível. Ele não cria veículo diretamente.

### 10.3 Wireframe geral

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  NOIR CAB CO.                                            CENTRAL · LOS SANTOS │
│  NÍVEL 2 · MOTORISTA                                      ESC · FECHAR       │
│                                                                              │
│  OVERVIEW                                                                   │
│  VEÍCULOS        │      conteúdo da seção ativa                             │
│  RANKING         │                                                          │
│                  │                                                          │
│                  │                                                          │
│                  │                                                          │
│                  │                                                          │
└──────────────────────────────────────────────────────────────────────────────┘
```

A navegação fica à esquerda e o conteúdo ocupa uma faixa lateral/central limitada. O lado direito pode carregar contexto curto. O centro não deve virar uma parede opaca.

## 11. Tela Overview

### 11.1 Objetivo

Responder imediatamente:

1. Qual é meu nível?
2. Quanto falta para o próximo?
3. Quanto ganhei hoje?
4. Quantas corridas já concluí?
5. Como começo a trabalhar?

### 11.2 Conteúdo obrigatório

```text
OVERVIEW

NÍVEL DE CONFIANÇA · 2
MOTORISTA

184 CONFIANÇA
[███████████░░░░░░░░] 56%
FALTAM 66 PARA O NÍVEL 3

GANHOS DE HOJE · $1.240
CORRIDAS CONCLUÍDAS · 38

[ ALUGAR VEÍCULO ]
```

### 11.3 Hierarquia

- Nível é o principal valor do perfil.
- Confiança atual e restante aparecem juntas, sem exigir cálculo mental.
- A barra indica progresso apenas dentro do nível atual, não contra o total máximo.
- Ganhos de hoje e corridas concluídas são pares `label · valor`.
- Valores monetários usam `pt-BR`, `$ 1.240` ou `$1.240` de forma consistente no resource.
- Números usam `font-variant-numeric: tabular-nums`.
- `ALUGAR VEÍCULO` é a única ação primária da tela.

### 11.4 Estados

**Perfil novo**

```text
NÍVEL 1 · INICIANTE
0 CONFIANÇA
FALTAM 100 PARA O NÍVEL 2
GANHOS DE HOJE · $0
CORRIDAS CONCLUÍDAS · 0
```

**Nível máximo**

```text
NÍVEL 6 · ELITE
1.842 CONFIANÇA
NÍVEL MÁXIMO
```

**Erro de carregamento**

- manter a navegação e identidade da tela;
- mostrar `Não foi possível carregar seu perfil. Tente novamente.`;
- oferecer `TENTAR NOVAMENTE` com cooldown;
- não exibir zeros falsos como se fossem dados reais;
- desabilitar aluguel até o servidor confirmar nível e catálogo.

**Loading**

- skeleton discreto ou labels com valores ocultos;
- sem animação infinita pesada;
- após aproximadamente 500 ms, mostrar feedback claro;
- timeout deve encerrar loading e oferecer nova tentativa.

## 12. Tela Veículos

### 12.1 Estrutura

```text
VEÍCULOS
Escolha um veículo liberado pelo seu Nível de Confiança.

TÁXI STANDARD                         DISPONÍVEL
NÍVEL 1                               [imagem]
────────────────────────────────────────────────
EXECUTIVO                             BLOQUEADO
DESBLOQUEIA NO NÍVEL 3                [imagem escurecida + cadeado]
────────────────────────────────────────────────
LIMOUSINE                             BLOQUEADO
DESBLOQUEIA NO NÍVEL 6                [imagem escurecida + cadeado]

Detalhes do selecionado
Táxi Standard · Nível 1
O clássico da cidade. Confiável e econômico.

[ ALUGAR VEÍCULO ]
```

### 12.2 Lista

- Usar linhas fantasma com hairline do Design V2.
- Não transformar cada veículo em card pesado.
- Imagem pode aparecer em uma área de preview única para o item selecionado.
- A lista permanece legível sem depender das imagens.
- Ordenar por `requiredLevel`, depois por ordem configurada.
- Veículos futuros bloqueados continuam visíveis.
- Item bloqueado pode receber foco para leitura, mas não pode executar aluguel.
- Ao selecionar bloqueado, o painel explica o requisito; o botão fica desabilitado.

### 12.3 Confirmação

Se `rentalFee > 0`, abrir modal:

```text
ALUGAR TÁXI STANDARD
O aluguel custa $250 e será cobrado da sua conta definida pela central.

[ VOLTAR ]   [ CONFIRMAR ALUGUEL ]
```

Se o aluguel for gratuito, o MVP pode confirmar diretamente pelo botão, mantendo loading e prevenção de clique duplo.

Não usar modal para informar bloqueio; o estado da própria tela já deve explicar isso.

### 12.4 Erros humanos

| Motivo server-side | Mensagem ao jogador |
|---|---|
| nível insuficiente | `Este veículo exige Nível de Confiança 3.` |
| atividade indisponível | `A central de táxi está indisponível para seu personagem neste momento.` |
| aluguel existente | `Devolva seu táxi atual antes de alugar outro.` |
| sem vaga | `As vagas da central estão ocupadas. Tente novamente em instantes.` |
| saldo insuficiente | `Você não possui dinheiro suficiente para este aluguel.` |
| longe da central | `Aproxime-se do atendente para alugar um veículo.` |
| sessão expirada | `Sua sessão na central expirou. Abra o atendimento novamente.` |
| spawn falhou | `Não foi possível preparar o veículo. Nenhum valor foi cobrado.` |
| rate limit | não repetir toast a cada clique; manter botão brevemente bloqueado |

## 13. Tela Ranking

### 13.1 Estrutura

```text
RANKING
Os motoristas com maior Confiança na central.

1  Helena Duarte       NÍVEL 6     2.480     164 CORRIDAS
2  Rafael Nunes        NÍVEL 6     2.110     151 CORRIDAS
3  Marina Costa        NÍVEL 5     1.090      88 CORRIDAS
────────────────────────────────────────────────────────
4  ...
...
10 ...

SUA POSIÇÃO
27 Você                 NÍVEL 2       184      38 CORRIDAS

ATUALIZADO HÁ 32 S
```

### 13.2 Pódio

- O Top 3 pode ter maior hierarquia tipográfica e pequenos marcadores 1/2/3.
- Evitar caixas, coroas grandes, dourado excessivo ou composição de e-sports.
- O primeiro lugar pode usar o âmbar forte do táxi.
- Segundo e terceiro usam hierarquia de branco/opacidade.
- Cor não deve ser a única indicação; sempre mostrar o número da posição.

### 13.3 Lista vazia e jogador sem posição

- Se não houver dados: `O ranking ainda não possui corridas registradas.`
- Perfil novo pode aparecer com Confiança zero somente se a política do ranking incluir zeros.
- Default proposto: ranking geral lista apenas quem concluiu ao menos uma corrida.
- O bloco `SUA POSIÇÃO` ainda pode mostrar `Ainda sem classificação`.

## 14. Direção visual — Noir Design V2 com prioridade Taxi

### 14.1 Princípio

A estrutura segue o `DESIGN_v2.MD`; a extensão cromática do táxi tem prioridade onde representa marca, progresso ou ação principal.

Não criar uma interface amarela inteira. O amarelo/âmbar funciona como instrumento do taxímetro:

- nível e Confiança;
- progresso;
- item selecionado;
- ação primária;
- primeiro lugar;
- estados operacionais do táxi.

Texto, navegação e metadados continuam usando a hierarquia branca do Noir V2.

### 14.2 Tokens propostos

Reutilizar os tokens do HUD atual:

```css
:root {
  --taxi-accent: #d6a23a;
  --taxi-accent-strong: #efbd4f;
  --taxi-accent-dim: rgba(214, 162, 58, 0.58);
  --taxi-accent-faint: rgba(214, 162, 58, 0.18);
  --taxi-accent-hairline: rgba(214, 162, 58, 0.24);
  --taxi-panel: rgba(10, 10, 12, 0.82);
  --taxi-panel-border: rgba(255, 255, 255, 0.08);
}
```

Somar aos tokens canônicos do Design V2, sem duplicar literais em componentes.

### 14.3 Tipografia

- Plus Jakarta Sans 600 como fonte principal.
- Inter 300/400 somente em explicações e modais.
- Fontes devem estar empacotadas localmente; não depender de Google Fonts durante o jogo.
- Labels em caixa alta com tracking largo.
- Nomes de personagem e descrições em caixa normal.
- Valores numéricos com algarismos tabulares.
- Não usar Anton, Pricedown ou fonte caricata de táxi.

### 14.4 Superfícies

- Root completamente transparente.
- Gradiente lateral localizado atrás da navegação e conteúdo, nunca overlay escuro fullscreen.
- Linhas de menu e veículos sem fundo.
- Hairlines de 1px.
- Painel sólido/translúcido somente em modal e preview que realmente precise proteger a imagem.
- Raio de 2px.
- Sem neon, glow intenso ou gradiente amarelo colorido.
- Imagens de veículos com tratamento consistente e fallback local.

### 14.5 Composição

- Margem externa: `5vh`.
- Navegação: largura aproximada de `22–26vh`, lateral esquerda.
- Conteúdo: largura máxima em `vh`, sem crescer indefinidamente no ultrawide.
- Contexto da central: canto superior direito, alinhado à direita.
- Preview do veículo: lado direito do conteúdo, preservando o centro da cena quando possível.
- Safe zone respeitada em todas as resoluções.

### 14.6 Movimento

Menu da central é tela narrativa:

- entrada de 900 ms com `--noir-ease-out`;
- navegação e conteúdo entram da esquerda;
- contexto/preview entra pela direita;
- stagger de aproximadamente 120 ms;
- saída reversa em 550 ms;
- troca de aba em 250–350 ms, sem refazer a coreografia completa;
- hover em 150 ms somente por cor/hairline;
- `prefers-reduced-motion` reduz tudo para transição praticamente instantânea.

Não usar animação contínua na barra de progresso, ranking ou veículos.

## 15. Controles, foco e integração com ESC

### 15.1 Ao abrir

1. Servidor autoriza a sessão.
2. Client define estado `menuOpen = true`.
3. Client envia bootstrap para NUI.
4. `SetNuiFocus(true, true)`.
5. `SetNuiFocusKeepInput(false)`.
6. Foco DOM vai para a aba Overview ou último item seguro.

O menu é uma exceção deliberada à regra de HUD sem foco. O foco existe apenas na central, fora do gameplay normal.

### 15.2 Ao fechar

- `Escape` fecha ou volta de um modal.
- Se não houver modal, inicia coreografia de saída.
- NUI envia `closeComplete` ao client.
- Client executa `SetNuiFocus(false, false)` e invalida estado local.
- Deve existir timeout de segurança para liberar foco caso o browser não responda.
- `onResourceStop`, player unload e morte/teleporte para longe liberam foco imediatamente.

O `noir_pausemenu` não deve abrir enquanto esta NUI possuir foco. O clique/pressionamento que fecha a central não pode ser reutilizado no mesmo frame para abrir o pause menu.

### 15.3 Navegação acessível

- `Tab` percorre abas, lista e ação.
- Setas cima/baixo navegam veículos e ranking.
- Setas esquerda/direita ou atalhos navegam abas.
- `Enter` seleciona e confirma ação segura.
- `Escape` volta/fecha.
- Todo foco possui outline visível.
- Alvos têm pelo menos `4vh`.
- Bloqueio usa texto + ícone, não apenas cor.
- HTML semântico: `nav`, `main`, `section`, `button`, listas e headings.
- `aria-live` apenas para resultados importantes; não anunciar cada alteração decorativa.

## 16. Contratos de dados da NUI

### 16.1 Bootstrap

Mensagem client → NUI:

```json
{
  "action": "taxiMenu:open",
  "data": {
    "sessionId": "token-opaco",
    "serverTime": 1788613200,
    "profile": {
      "displayName": "João Silva",
      "confidence": 184,
      "level": 2,
      "levelLabel": "Motorista",
      "levelStart": 100,
      "nextLevelAt": 250,
      "confidenceRemaining": 66,
      "progressPercent": 56,
      "maxLevel": false,
      "earnedToday": 1240,
      "completedRides": 38
    },
    "vehicles": [
      {
        "id": "standard",
        "label": "Táxi Standard",
        "description": "O clássico da cidade. Confiável e econômico.",
        "requiredLevel": 1,
        "rentalFee": 0,
        "image": "img/vehicles/taxi.webp",
        "status": "available"
      },
      {
        "id": "executive",
        "label": "Executivo",
        "description": "Atendimento executivo para motoristas experientes.",
        "requiredLevel": 3,
        "rentalFee": 0,
        "image": "img/vehicles/tailgater.webp",
        "status": "locked"
      }
    ]
  }
}
```

Embora o payload contenha `status`, o servidor deve recalcular permissão quando receber o aluguel. O status enviado à NUI serve apenas à apresentação.

### 16.2 Ranking lazy

O bootstrap não precisa carregar o ranking. Ao entrar na aba:

```json
{
  "action": "taxiMenu:setRanking",
  "data": {
    "generatedAt": 1788613168,
    "entries": [
      {
        "position": 1,
        "displayName": "Helena Duarte",
        "confidence": 2480,
        "level": 6,
        "completedRides": 164
      }
    ],
    "self": {
      "position": 27,
      "displayName": "João Silva",
      "confidence": 184,
      "level": 2,
      "completedRides": 38
    }
  }
}
```

### 16.3 Callbacks NUI planejados

| Callback | Entrada aceita | Resultado |
|---|---|---|
| `uiReady` | vazio | client reenvia estado atual se necessário |
| `closeMenu` | motivo curto conhecido | inicia fechamento client-side |
| `closeComplete` | vazio | client libera foco |
| `requestRanking` | vazio | snapshot cacheado do servidor |
| `rentVehicle` | `{ vehicleId }` | sucesso ou código de erro |
| `retryBootstrap` | vazio | nova solicitação rate-limited |

Todo `RegisterNUICallback` deve sempre chamar `cb(...)`, inclusive em erro, para não deixar fetch pendente.

O browser nunca chama evento de pagamento, progressão ou spawn diretamente.

## 17. Contratos client/server planejados

Nomes finais podem mudar, mas devem permanecer namespaced.

| Tipo | Nome sugerido | Responsabilidade |
|---|---|---|
| callback | `noir_taxijob:server:openCentral` | valida abertura e retorna bootstrap/token |
| callback | `noir_taxijob:server:getRanking` | retorna cache Top 10 + self |
| callback | `noir_taxijob:server:rentVehicle` | valida e cria aluguel |
| callback | `noir_taxijob:server:returnVehicle` | valida e encerra aluguel |
| evento client | `noir_taxijob:client:rentalReady` | resolve entidade e transição visual, se necessário |
| evento local | `noir_taxijob:client:menuClosed` | cleanup interno, não networked |

Preferir callbacks para ações que precisam de resultado. Eventos de mesmo contexto devem usar `AddEventHandler`, sem `RegisterNetEvent` desnecessário.

### 17.1 Códigos de erro estáveis

Servidor retorna códigos, client traduz:

```text
not_loaded
not_near
invalid_session
session_expired
activity_restricted
invalid_vehicle
vehicle_locked
already_rented
request_in_progress
no_spawn_space
insufficient_funds
spawn_failed
rate_limited
internal_error
```

Não retornar stack trace, nome de tabela ou detalhes de segurança ao browser.

## 18. Persistência planejada

### 18.1 Perfil

Tabela sugerida `noir_taxi_profiles`:

| Coluna | Tipo conceitual | Regra |
|---|---|---|
| `citizenid` | varchar, PK | identidade do personagem, nunca server ID |
| `display_name` | varchar | snapshot sanitizado para ranking |
| `confidence` | unsigned int/bigint | default 0, nunca negativo |
| `completed_rides` | unsigned int | default 0 |
| `total_earned` | unsigned bigint | default 0; útil para perfil futuro |
| `confidence_reached_at` | timestamp | desempate do ranking |
| `schema_version` | smallint | controla migração única |
| `created_at` | timestamp | auditoria |
| `updated_at` | timestamp | auditoria/cache |

Índices:

- PK por `citizenid`;
- índice de ranking por Confiança e corridas;
- limitar comprimento e charset de nome.

### 18.2 Estatística diária

Tabela sugerida `noir_taxi_daily_stats`:

| Coluna | Regra |
|---|---|
| `citizenid` | parte da chave composta |
| `day_key` | parte da chave composta |
| `earned` | soma validada do dia |
| `completed_rides` | corridas do dia, disponível para extensão |
| `confidence_earned` | opcional para telemetria/balanceamento |
| `updated_at` | auditoria |

Chave primária: `(citizenid, day_key)`.

Atualizar com UPSERT atômico. Não carregar ou regravar JSON completo a cada corrida.

### 18.3 Ledger de conclusão

Tabela sugerida `noir_taxi_fare_results`:

| Coluna | Uso |
|---|---|
| `fare_id` | chave única gerada pelo servidor |
| `citizenid` | dono da corrida |
| `fare_amount` | pagamento final calculado |
| `confidence_delta` | Confiança concedida |
| `distance_meters` | auditoria/balanceamento |
| `satisfaction` | auditoria/balanceamento |
| `day_key` | agregação diária |
| `completed_at` | auditoria |

O ledger garante idempotência e oferece base para corrigir agregados. Política de retenção pode compactar registros antigos posteriormente; não criar cleanup agressivo no MVP.

### 18.4 Acesso ao banco

- Usar `oxmysql` já presente no stack, sem nova dependência fechada.
- Queries parametrizadas/preparadas.
- UPSERT para criação de perfil e estatística diária.
- Transação para ledger + perfil + diário.
- Nunca montar SQL com nome ou identifier concatenado.
- Toda query possui tratamento de erro e log contextual sem dados sensíveis.
- Não consultar banco por frame, tick do meter ou mudança de FAN.

## 19. Migração

Há duas fontes históricas possíveis, ambas pertencentes ao resource antigo:

1. tabela antiga `ak4y_taxi`;
2. tabela renomeada/orfã `noir_taxijob` com `xp`, `completedroutes`, `tasks`, `earnedmoney`;

Plano:

1. criar schema novo sem destruir tabela antiga;
2. ao criar perfil V2 pela primeira vez, procurar dados legados de forma controlada;
3. converter XP legado para Confiança com fator configurável;
4. importar total de rotas somente após JSON válido e com limite razoável;
5. importar dinheiro como total histórico, nunca como dinheiro na conta;
6. marcar `schema_version` e origem da migração;
7. nunca repetir importação para o mesmo personagem;
8. gerar relatório de contagens migradas/rejeitadas;
9. manter backup e rollback antes de remover qualquer tabela antiga.

Regra de conflito proposta:

```text
confiança inicial = XP legado validado × fator de conversão aprovado
corridas iniciais = total legado validado
ganhos de hoje = 0 (não inferir data de um total histórico)
```

O fator de conversão deve ser aprovado durante balanceamento. Não assumir que XP legado e Confiança V2 possuem a mesma escala.

## 20. Segurança server-side

### 20.1 Regra central

Para cada mensagem client → server, responder:

> O que impede um executor de chamar isto diretamente, fora da central e com dados falsos?

### 20.2 Abertura da central

Validar:

- jogador carregado;
- ped válido;
- proximidade real server-side;
- routing bucket;
- jogador não está em veículo;
- menu não está aberto em outra sessão;
- personagem não está em uma denylist opcional de atividade;
- rate limit.

Gerar token opaco, curto e não previsível, vinculado a `source`, com validade sugerida de 2 minutos. O token não substitui nenhuma revalidação.

### 20.3 Aluguel

Além das regras da seção 9:

- mutex/flag por jogador durante a operação;
- tamanho e tipo de `vehicleId` sanitizados;
- nunca aceitar model hash do client;
- nunca aceitar nível ou custo do client;
- nunca aceitar coordenada de spawn do client;
- validar novamente após qualquer `await` importante;
- tratar disconnect durante query/spawn;
- limpar flag em caminho de sucesso e erro;
- logar rejeição suspeita com throttle;
- não banir automaticamente por uma única falha.

### 20.4 Ranking e perfil

- client não escolhe `citizenid` consultado;
- endpoint `self` sempre deriva do `source`;
- ranking retorna somente campos públicos permitidos;
- paginação/tamanho possuem limite fixo server-side;
- strings de nome são sanitizadas antes da NUI;
- resposta não contém query ou erro SQL.

### 20.5 Corrida e progressão

Preservar as validações atuais:

- sessão autônoma ativa e pertencente ao jogador;
- sessão e estado esperado;
- fare ID;
- veículo permitido e motorista no banco correto;
- NPC/sessão correspondentes;
- proximidade do destino;
- tempo mínimo;
- distância plausível;
- limite tarifável;
- prevenção de teleport/deltas impossíveis;
- pagamento e Confiança calculados no servidor;
- marcação contra duplicidade antes de responder.

## 21. Controle de threads, CPU e rede

### 21.1 Servidor

Não criar uma thread por jogador, veículo, ranking ou tela aberta.

Estratégia:

- progressão é atualizada por evento de conclusão;
- Overview é carregado sob demanda;
- ranking é lazy e cacheado;
- reset diário é derivado por `dayKey`, sem timer de meia-noite;
- aluguel é callback transacional, sem polling;
- cleanup periódico, se necessário, usa um único loop lento e só percorre mapas ativos;
- dispatcher e meter permanecem em um único scheduler com intervalo aproximado de 1 segundo;
- estruturas indexadas por `source`, `fareId` e net ID evitam buscas globais repetidas.

Intervalos propostos:

| Trabalho | Intervalo |
|---|---:|
| meter/dispatcher ativo | ~1.000 ms |
| cleanup de sessão expirada | 30–60 s |
| TTL ranking | 60 s |
| persistência de corrida | por conclusão, sem loop |
| perfil/Overview | por abertura, com cache curto opcional |

Se não houver sessão ativa, loops de gameplay devem dormir mais ou não executar trabalho interno.

### 21.2 Client

- ox_target cuida da interação; não adicionar loop de distância `Wait(0)`.
- NUI fechada não recebe snapshots.
- Menu não precisa de thread Lua própria.
- HUD recebe mudanças de estado e snapshots no intervalo já definido.
- Não enviar `SendNUIMessage` todo frame.
- Contagem visual de oferta pode ser feita no browser enquanto visível, sincronizada por deadline do servidor.
- Resolver veículo por net ID com timeout limitado, nunca loop infinito.
- Threads de missão devem ter condição de saída e cleanup em todos os estados terminais.

### 21.3 Browser/NUI

- registrar listeners uma única vez;
- cancelar timers/fetches ao fechar;
- nenhum `requestAnimationFrame` permanente para valores estáticos;
- barra de progresso é CSS baseada em valor recebido;
- lista de três veículos e Top 10 não exige virtualização;
- evitar rerender completo em cada hover;
- imagens em WebP/PNG otimizadas e locais;
- não carregar fontes ou assets por CDN;
- debounce somente onde necessário; ações críticas usam estado `pending`.

### 21.4 Banco

- uma transação de progressão por corrida concluída;
- nenhuma query por metro rodado;
- nenhuma query por atualização de temperatura/FAN;
- cache de ranking compartilhado;
- índices coerentes com lookup e ordenação;
- selecionar somente colunas necessárias;
- limitar histórico retornado.

## 22. Rate limits iniciais

Defaults para avaliação:

| Ação | Janela sugerida |
|---|---:|
| abrir central | 1.000 ms |
| retry bootstrap | 2.000 ms |
| pedir ranking | 5.000 ms por jogador, respeitando cache global |
| alugar veículo | 3.000 ms |
| devolver veículo | 2.000 ms |
| falha repetida sem sessão | log no máximo a cada 5.000 ms |

Rate limit deve rejeitar trabalho, não travar o client. O callback sempre responde com estrutura estável.

## 23. Estados e concorrência

### 23.1 Estado do menu

```text
CLOSED
  → OPENING
  → READY
  → RENTING
  → CLOSING
  → CLOSED

OPENING/READY
  → ERROR
  → RETRYING
  → READY
```

Durante `RENTING`:

- bloquear navegação que causaria envio duplicado;
- Escape não deve abandonar silenciosamente uma operação já aceita pelo servidor;
- se a operação exceder timeout, client pede reconciliação antes de permitir nova tentativa.

### 23.2 Estado server-side de aluguel

```text
NONE
  → VALIDATING
  → SPAWNING
  → ACTIVE
  → RETURNING
  → NONE

VALIDATING/SPAWNING
  → FAILED
  → NONE
```

Um mutex por `source` impede duas chamadas simultâneas de criarem dois veículos.

### 23.3 Integração com a state machine de corrida

O menu não substitui os estados atuais:

```text
NUI da central fecha
      ↓
veículo válido + taxista no banco do motorista
      ↓
HIDDEN → AVAILABLE
      ↓
OFFER → EN_ROUTE → BOARDING → HIRED → COMPLETING
      ↓
AVAILABLE
```

Progressão só ocorre na transição validada de `COMPLETING` para `AVAILABLE` após resultado persistido.

## 24. Observabilidade

### 24.1 Logs estruturados

Em debug:

```text
[noir_taxijob] central_open src=12 activity=allowed
[noir_taxijob] rental_started src=12 vehicleId=standard
[noir_taxijob] rental_ready src=12 netId=483 level=1
[noir_taxijob] fare_progress cid=... fareId=... confidence=+15 earned=92
[noir_taxijob] ranking_cache rebuilt entries=10 durationMs=8
```

Produção deve evitar spam e identifiers completos. Webhook de segurança usa throttle e separa falha operacional de tentativa claramente inválida.

### 24.2 Métricas úteis

- tempo de bootstrap da NUI;
- tempo de query do ranking;
- hit rate do cache de ranking;
- alugueis iniciados/sucesso/falha por motivo;
- corridas concluídas e canceladas;
- Confiança média por corrida;
- distribuição por nível;
- veículos escolhidos por nível;
- falhas de spawn;
- tempo médio de sessão.

Métricas não devem exigir loop de alta frequência; incrementar contadores em eventos existentes.

## 25. Tratamento de falhas

| Falha | Comportamento |
|---|---|
| NUI não carregou | timeout, liberar foco, notificar e permitir reabrir |
| callback de bootstrap falhou | tela de erro sem dados falsos |
| ranking falhou | Overview/Veículos continuam disponíveis |
| imagem falhou | fallback local com ícone do veículo |
| jogador afastou-se | servidor invalida aluguel; menu fecha |
| disconnect durante aluguel | limpar mutex, entidade parcial e cobrança conforme estágio |
| spawn falhou | não manter aluguel ativo; compensar taxa |
| client não resolveu net ID | servidor mantém autoridade e oferece reconciliação/cleanup |
| DB indisponível | não conceder progressão parcial silenciosa; registrar erro e usar política explícita |
| resource stop | liberar foco, esconder menu/HUD, remover peds/blips e limpar entidades controladas |
| job/duty mudou | não alterar a sessão; o Taxi V2 é renda extra independente |

## 26. Responsividade e acessibilidade

Testar obrigatoriamente:

- 1280×720;
- 1920×1080;
- 2560×1440;
- 16:10;
- 21:9;
- safe zone reduzida;
- textos e nomes longos;
- escala de UI maior;
- `prefers-reduced-motion`.

Regras:

- dimensões da tela em `vh`;
- sem largura baseada apenas em `vw`;
- truncar nomes no ranking com tooltip/nome acessível quando necessário;
- manter conteúdo essencial dentro da safe zone;
- contraste mínimo do Design V2;
- scroll visível e controlável por teclado;
- estado bloqueado anunciado por texto;
- não capturar teclas quando NUI estiver fechada.

## 27. Estrutura de arquivos sugerida

Planejamento, não obrigação rígida:

```text
noir_taxijob/
├── client/
│   ├── central.lua          # abertura, foco, callbacks NUI
│   ├── rental.lua           # resolução da entidade e cleanup client
│   ├── client.lua           # state machine de trabalho existente
│   └── ui.lua               # mensagens do HUD/menu
├── server/
│   ├── central.lua          # bootstrap e sessão curta
│   ├── progression.lua      # níveis, ledger e agregados
│   ├── ranking.lua          # cache e consultas
│   ├── rental.lua           # validação e spawn server-side
│   ├── 00_security.lua      # sanitização/rate limit
│   └── server.lua           # integração existente
├── shared/
│   └── progression.lua      # labels/apresentação sem autoridade de escrita
├── html/
│   ├── index.html
│   ├── main.css
│   ├── app.js
│   ├── fonts/
│   └── img/vehicles/
├── migrations/
│   └── 001_taxi_v2.sql
└── config.lua
```

Evitar um único arquivo com progressão, ranking, aluguel, dispatcher e UI misturados.

## 28. Ordem de implementação futura

1. Congelar contratos e balanceamento de níveis.
2. Criar schema/migration sem apagar legado.
3. Implementar módulo server-side de perfil e cálculo de nível.
4. Integrar ledger e atualização atômica à conclusão atual.
5. Implementar cache de ranking e testes de concorrência.
6. Refatorar aluguel server-side com catálogo por ID.
7. Criar contratos client/NUI e estados de foco.
8. Construir shell visual conforme Design V2.
9. Implementar Overview.
10. Implementar Veículos e estados de bloqueio.
11. Implementar Ranking lazy.
12. Integrar saída da NUI ao HUD atual.
13. Implementar migração controlada.
14. Testar carga, segurança, reconexão e falhas.
15. Remover assets e traduções legadas realmente não usados somente após validação e backup.

## 29. Testes planejados

### 29.1 Progressão

- perfil novo começa no nível 1;
- valores exatos nos limites 99/100, 249/250 etc.;
- nível máximo não divide por zero;
- Confiança restante nunca fica negativa;
- duas conclusões simultâneas não perdem update;
- repetir `fareId` não duplica Confiança;
- corrida cancelada não pontua;
- satisfação aplica bônus correto;
- metadata do Qbox não é lido ou escrito durante criação, migração ou uso do perfil.

### 29.2 Estatísticas

- pagamento válido incrementa ganhos do dia e total de corridas;
- mudança de `dayKey` mostra zero sem apagar o dia anterior;
- offset e hora de reset funcionam perto da meia-noite;
- pagamento duplicado é rejeitado;
- total monetário suporta valores grandes sem overflow;
- ganhos históricos não entram em `ganhos de hoje` durante migração.

### 29.3 Ranking

- ordenação e desempates são determinísticos;
- Top 10 possui no máximo dez entradas;
- self aparece fora do Top 10;
- nomes longos não quebram layout;
- cache evita queries repetidas;
- apenas uma rebuild ocorre sob concorrência;
- dados privados nunca aparecem no payload;
- falha do ranking não derruba outras telas.

### 29.4 Veículos

- nível 1 aluga somente Standard;
- nível 2 ainda não aluga Executivo;
- nível 3 aluga Executivo;
- nível 6 aluga Limousine;
- modificar DOM para desbloquear não passa pelo servidor;
- enviar model/hash/nível falsos não altera decisão;
- dois cliques simultâneos criam um veículo;
- sem spawn livre não cobra nem cria sessão indevidamente;
- taxa insuficiente falha sem side effects;
- disconnect durante spawn limpa estado;
- veículo devolvido pode ser alugado novamente;
- model liberado ativa a state machine e o HUD.

### 29.5 NUI e foco

- target abre Overview, não cria veículo;
- Overview mostra valores server-side;
- botão `ALUGAR VEÍCULO` navega à segunda aba;
- bloqueado mostra cadeado e requisito;
- mouse, Tab, setas, Enter e Escape funcionam;
- Escape fecha a NUI sem abrir pause menu no mesmo pressionamento;
- foco é sempre liberado em erro/resource stop;
- HUD não recebe foco durante trabalho;
- root transparente não produz tela preta;
- reduced motion funciona;
- layouts alvo e ultrawide não cortam ações.

### 29.6 Segurança e carga

- abrir remotamente longe do NPC falha;
- token de outro jogador falha;
- token expirado falha;
- callback spammado respeita rate limit;
- client não consegue definir Confiança, dinheiro ou corridas;
- 32/64 jogadores abrindo ranking compartilham cache;
- servidor sem taxistas não executa trabalho novo por frame;
- profiler não mostra thread nova com custo significativo ocioso;
- queries por minuto permanecem proporcionais a aberturas/conclusões, não a FPS ou quantidade de metros.

## 30. Critérios de aceite do Taxi V2

- [ ] O target abre a NUI antes de qualquer spawn.
- [ ] Overview é a primeira tela.
- [ ] Overview mostra nível, Confiança atual, restante e progresso.
- [ ] Overview mostra ganhos do dia e corridas vitalícias.
- [ ] `ALUGAR VEÍCULO` navega para Veículos.
- [ ] Veículos exibe catálogo completo, inclusive bloqueados.
- [ ] Bloqueio mostra nível necessário em texto e ícone.
- [ ] Alterar a NUI não contorna bloqueio server-side.
- [ ] Standard libera no nível 1, Executivo no 3 e Limousine no 6.
- [ ] Aluguel é criado pelo servidor e só existe um por jogador.
- [ ] Emprego, grade e duty nunca são alterados pelo Taxi V2.
- [ ] Personagens empregados e desempregados acessam a mesma atividade.
- [ ] Ranking geral mostra Top 10 e posição do jogador.
- [ ] Ranking usa cache e não possui loop de atualização contínua.
- [ ] Corrida válida atualiza dinheiro, Confiança e estatísticas uma vez.
- [ ] Browser nunca envia recompensa ou nível.
- [ ] Persistência usa queries parametrizadas e updates atômicos.
- [ ] NUI segue `DESIGN_v2.MD` e tokens do taxímetro.
- [ ] Root permanece transparente.
- [ ] Menu suporta mouse e teclado; HUD continua sem foco.
- [ ] Escape não deixa NUI presa nem abre pause menu no mesmo frame.
- [ ] Threads ficam ociosas ou inexistentes quando não há trabalho.
- [ ] Cleanup cobre disconnect, encerramento da atividade, resource stop e entidade perdida.
- [ ] Nenhuma dependência fechada/Asset Escrow é adicionada.
- [ ] Migração possui backup e não destrói dados legados automaticamente.

## 31. Decisões a aprovar antes da implementação

1. Confirmar thresholds dos seis níveis.
2. Confirmar ganho de Confiança por satisfação.
3. Confirmar se aluguel será gratuito no MVP.
4. Confirmar se `tailgater` e `stretch` permanecem no catálogo final.
5. Confirmar dia canônico e horário de reset.
6. Confirmar política de migração do XP existente nas tabelas legadas do táxi.
7. Confirmar se nomes do ranking podem ser públicos para todos os personagens.
8. Confirmar se corrida válida com pagamento final zero conta como concluída.
9. Confirmar se alguma denylist excepcional de atividade será necessária; default é permitir todos.
10. Confirmar se o jogador é colocado automaticamente no banco após o aluguel.

Enquanto essas decisões não forem aprovadas, os valores deste documento são defaults de planejamento e não regras irreversíveis de produção.

## 32. Referências técnicas para a implementação futura

A implementação deve consultar as fontes oficiais atuais antes de escrever os contratos finais:

- CFX Fullscreen NUI e foco;
- CFX NUI callbacks;
- CFX Secure Your Events;
- CFX OneSync e entidades criadas pelo servidor;
- CFX State Bags;
- profiler do CFX para validar custo de threads;
- tipos de PlayerData e exports server-side do Qbox;
- `qbx_taxijob` oficial apenas como referência de integração;
- `resources/docs/DESIGN_v2.MD` como fonte visual canônica;
- `resources/docs/TAXI.md` como fonte do fluxo automático e segurança das corridas.

Nenhuma referência externa autoriza confiar no client para pagamento, Confiança, nível, desbloqueio ou spawn.
