# Noir Truck V1 — Mercado global e novo loop de entregas

> Status: **documento de planejamento funcional, técnico e de NUI**. Nenhuma funcionalidade descrita aqui está implementada por este documento.
>
> Resource alvo: `resources/[standalone]/peak-trucking`.
>
> Base analisada: Peak Trucking `0.3.0`, commit `cb56ce784a1a89f51f4083c5681c4abd5c45e56b`.
>
> Regra de preservação: as 16 missões, 37 rotas, coordenadas, locais de spawn, destinos, modelos de caminhão/carreta/carga e fluxos especiais existentes permanecem canônicos e não devem ser reposicionados por esta versão.

## 1. Visão do produto

O Noir Truck V1 transforma a lista estática e repetível do Peak Trucking em um mercado de fretes rotativo, limitado e server-authoritative.

O jogador terá uma única fonte de trabalho: o **Mercado Global**, um quadro compartilhado por todo o servidor, atualizado a cada hora e composto por cargas únicas. Cada contrato pertence a exatamente um motorista: o primeiro pedido elegível processado pelo servidor inicia a entrega.

Não existe quadro pessoal, oferta garantida ou lista individual. Com isso, a atividade deixa de fornecer uma sequência infinita de trabalhos e passa a ter um teto econômico real por hora para a cidade inteira.

O objetivo é preservar o conteúdo de mundo já configurado e mudar somente a forma como esse conteúdo é ofertado, iniciado, avaliado e recompensado. Não haverá caminhão próprio, garagem pessoal, compra de frota ou manutenção patrimonial nesta versão. Todos os veículos continuam sendo fornecidos temporariamente pela empresa.

```text
NPC / CENTRAL DE FRETES
          ↓
servidor autoriza a abertura
          ↓
MERCADO GLOBAL
3–7 cargas únicas por hora
níveis baixo, médio e alto
primeiro motorista elegível a iniciar leva
          ↓
servidor valida oferta + motorista + disponibilidade
          ↓
empresa fornece caminhão e carga já existentes
          ↓
coleta → transporte → entrega → devolução
          ↓
relatório S–D + dinheiro + XP + reputação + histórico
```

## 2. Decisões fechadas

Estas decisões são requisitos do V1:

1. Haverá somente um quadro global, compartilhado por todo o servidor.
2. Não haverá quadro pessoal nem oferta individual garantida.
3. O quadro global será substituído a cada hora.
4. Cada rotação terá missões de nível baixo, médio e alto.
5. Por rotação, serão geradas de 1 a 2 ofertas baixas, de 1 a 2 médias e de 1 a 3 altas.
6. Cada oferta poderá ser iniciada por **um único motorista**.
7. Não haverá reserva, candidatura, fila, leilão ou sorteio.
8. O primeiro motorista elegível cujo pedido de início for confirmado pelo servidor recebe o contrato.
9. Um motorista poderá iniciar no máximo um contrato por rotação.
10. Ofertas terão bônus controlado de mercado sobre a recompensa-base da rota.
11. Contratos já iniciados sobrevivem à troca de rotação até conclusão ou falha.
12. Todos os caminhões continuarão pertencendo à empresa e serão temporários.
13. As rotas e localizações existentes não serão alteradas.
14. Pagamento, XP, reputação, disponibilidade e conclusão serão decididos pelo servidor.

## 3. Fora do escopo

Não fazem parte do Noir Truck V1:

- compra, financiamento ou venda de caminhões;
- garagem ou frota pessoal;
- seguro, manutenção ou customização de caminhão próprio;
- empresa de transporte criada por jogador;
- comboios com divisão de recompensa;
- candidatura ou seleção ponderada para contrato global;
- reserva temporária de contrato global;
- criação de novos pontos de coleta ou entrega;
- alteração das coordenadas existentes;
- substituição dos modelos de caminhão, carreta ou carga existentes;
- reconstrução completa da identidade visual do Peak Trucking;
- integração econômica de entregas com estoque real de lojas nesta primeira versão.

Esses elementos podem ser planejados posteriormente, mas não devem entrar no V1 silenciosamente.

## 4. Base atual compreendida

### 4.1 Resource

O resource atual possui:

- Lua 5.4;
- bridge para QBCore, Qbox e ESX;
- persistência por `oxmysql`;
- NUI React 19 + TypeScript + Vite;
- seleção de missão, rota e caminhão;
- nove caminhões liberados progressivamente;
- confiança separada para oito empresas;
- XP e 100 níveis;
- três missões diárias fixas;
- ranking dos oito maiores níveis;
- histórico de trabalhos;
- carga ilegal opcional;
- HUD reposicionável;
- cancelamento manual e automático por destruição de veículo/carga.

### 4.2 Loop atual

```text
abre NUI
  ↓
seleciona missão estática desbloqueada
  ↓
seleciona uma das rotas da missão
  ↓
seleciona caminhão permitido
  ↓
client cria caminhão/carreta/carga
  ↓
busca ou carrega a carga
  ↓
vai ao destino
  ↓
volta ao depósito
  ↓
client informa conclusão ao servidor
  ↓
servidor paga, sorteia 100–500 XP e entrega +1 confiança
```

O problema de produto é que a missão desbloqueada permanece disponível indefinidamente. O jogador pode escolher repetidamente a rota mais curta ou eficiente, transformando o emprego em farm previsível.

### 4.3 Interface atual

A NUI atual possui quatro páginas no cabeçalho:

| Página | Componente | Responsabilidade atual |
|---|---|---|
| NTS Main | `DispatchView.tsx` | missão, rota, caminhão, botão de início e missões diárias |
| Companies | `CompaniesView.tsx` | confiança e desbloqueio de missões por empresa |
| Leaderboard | `LeaderboardView.tsx` | Top 8 por nível/XP |
| Profile | `ProfileView.tsx` | trabalhos, ganhos, nível e histórico |

O `DispatchView` utiliza três colunas:

1. painel de missão com hero e lista de missões;
2. opções de rota e trilho de caminhões;
3. motorista, etapas, ação principal e missões diárias.

O V1 preserva essa composição, tipografia, tons escuros, bordas, cartões e cor de destaque. A mudança principal será transformar `NTS Main` no **Mercado Global** e fazer a coluna esquerda listar somente as ofertas únicas da rotação atual, não todo o catálogo estático.

O HUD atual continua sendo usado durante a viagem. Ele continuará exibindo rota, estado da carga/carreta, integridade, combustível, progresso de caixas e cancelamento. O relatório de conclusão será uma nova camada da mesma NUI.

## 5. Catálogo canônico preservado

### 5.1 Empresas existentes

| Índice | Empresa |
|---:|---|
| 0 | National Transfer & Storage Co. |
| 1 | The Grain Of Truth Company |
| 2 | Redwood Cigarettes Company |
| 3 | You Tool Company |
| 4 | Premium Deluxe Motorsport |
| 5 | Fruit Computers Company |
| 6 | Ron Oil Company |
| 7 | Merry Weather Security |

### 5.2 Missões existentes

| ID | Empresa | Missão | Pagamento atual | Nível atual | Rotas |
|---:|---:|---|---:|---:|---:|
| 1 | 0 | Paleto Forest Samwill Woods | $2.500 | inicial | 3 |
| 2 | 0 | Fame Or Shame TV Stuffs | $4.500 | confiança | 2 |
| 3 | 2 | Paleto Bay Tobaccos | $10.500 | 25 | 2 |
| 4 | 2 | Grapeseed Tobaccos | $14.500 | confiança | 2 |
| 5 | 1 | Grapeseed Grains | $5.500 | 25 | 3 |
| 6 | 1 | Grapeseed Grapes | $7.500 | confiança | 1 |
| 7 | 4 | LS Dock Luxury Vehicle Shipment | $15.500 | 35 | 2 |
| 8 | 4 | LSA Special Vehicle Shipment | $20.000 | confiança | 3 |
| 9 | 5 | iComputers Shipment | $25.000 | 40 | 3 |
| 10 | 5 | Life Invader Chip Cargo | $30.000 | confiança | 2 |
| 11 | 6 | Paleto Bay Oil Cargo | $50.000 | 50 | 2 |
| 12 | 6 | Murrieta Oil Field Transport | $35.000 | confiança | 3 |
| 13 | 7 | MWS Army Tank Transport | $65.000 | 60 | 3 |
| 14 | 7 | USAF Special Satellite Cargo | $80.000 | confiança | 2 |
| 15 | 3 | You Tool Furniture Shipment | $10.500 | 25 | 2 |
| 16 | 3 | You Tool Special Cargo | $14.500 | confiança | 2 |

Os valores acima registram o estado atual e não são uma aprovação do balanceamento. A geometria da missão é imutável; pagamento, XP, requisito e classificação podem ser rebalanceados pelo V1.

### 5.3 Regra de preservação de rotas

Uma oferta não copiará coordenadas. Ela deverá apontar para o catálogo canônico:

```lua
offer = {
    offerId = '20260905-18-global-01',
    rotationId = '20260905-18',
    missionId = 1,
    routeIndex = 2,
    tier = 'low',
}
```

No início, o servidor resolve:

```text
Config.Missions[missionId]
        + mission.routes[routeIndex]
        = caminhões permitidos
        + spawn de carreta
        + modelo da carreta
        + carga acoplada
        + destino
        + fluxo especial
```

É proibido criar uma segunda tabela de coordenadas para o quadro. Dessa forma, o V1 não diverge das 37 rotas existentes.

Devem permanecer intactos:

- `Config.NpcLocation`;
- `Config.IllegalNPC`;
- `Config.VehSpawn`;
- todos os `destination`;
- todos os `trailerSpawnAvaliableCoords`;
- todos os `vehicleSpawn` e `board` existentes;
- `trailerModel`, `attachModel` e `attachModelHeight`;
- lista `vehicle` de cada rota;
- fluxo manual de caixas da missão 16;
- fluxo atual da carga ilegal, salvo pelas validações autoritativas descritas neste documento.

## 6. Terminologia do V1

| Termo | Significado |
|---|---|
| Rotação | Janela canônica em que o quadro é gerado e permanece disponível. |
| Oferta | Instância temporária de uma missão e uma rota do catálogo. |
| Contrato global | Carga única compartilhada; apenas um motorista pode iniciá-la. Toda oferta do V1 é global. |
| Catálogo | As 16 missões e 37 rotas atuais em `Config.Missions`. |
| Tier | Faixa `low`, `medium` ou `high` utilizada para gerar e balancear ofertas. |
| Disponível | Oferta atual que ainda pode ser iniciada. |
| Em andamento | Oferta já atribuída definitivamente a um motorista. |
| Concluída | Entrega validada e paga pelo servidor. |
| Fracassada | Entrega iniciada que terminou sem pagamento integral. |
| Expirada | Oferta não iniciada antes da próxima rotação. |
| Reputação | Confiança vitalícia com uma empresa; não é moeda consumível. |
| Licença | Requisito de carreira para categoria de carga; não representa caminhão próprio. |
| Frota da empresa | Veículos temporários fornecidos pelo job. |

## 7. Relógio e identidade da rotação

### 7.1 Ciclo padrão

O default será uma rotação global a cada 60 minutos, alinhada à hora do servidor:

```text
18:00:00 → rotação 18 disponível
18:59:59 → último instante para iniciar oferta da rotação 18
19:00:00 → rotação 19 disponível
```

O intervalo deve ser configurável, mas a implementação e os testes do V1 usarão 60 minutos.

### 7.2 Identificador

O servidor deriva uma identidade estável:

```text
rotationNumber = floor(unixTime / 3600)
rotationId     = string(rotationNumber)
expiresAt      = (rotationNumber + 1) * 3600
```

O resultado não pode depender de tempo do client.

### 7.3 Restart e reconnect

- reiniciar o resource não gera outra lista dentro da mesma hora;
- reconectar não torna um contrato iniciado disponível novamente;
- reiniciar não torna contrato já iniciado disponível novamente;
- a geração deve ser determinística ou persistida;
- sessões ativas devem ser persistidas ou encerradas por uma política explícita de recuperação;
- nunca usar restart como forma de renovar pagamentos.

## 8. Mercado global

### 8.1 Escassez econômica real

Toda oferta do Noir Truck V1 é global. O quadro contém somente de três a sete cargas para a cidade inteira a cada hora. Quando todas forem iniciadas, não surgem entregas adicionais até a próxima rotação.

Essa ausência temporária de trabalho é intencional: trucking deixa de ser uma fonte infinita de renda e passa a ser uma oportunidade econômica disputada.

### 8.2 Quantidade por rotação

O servidor gera:

| Tier | Quantidade aleatória inclusiva |
|---|---:|
| Baixo | 1–2 |
| Médio | 1–2 |
| Alto | 1–3 |

O total global fica entre 3 e 7 contratos por hora. A seleção ocorre sem duplicar `missionId + routeIndex` dentro da mesma rotação.

### 8.3 Proteção das faixas

As ofertas usam nível mínimo e máximo para impedir que veteranos consumam todas as oportunidades de iniciantes:

| Tier | Elegibilidade padrão |
|---|---|
| Baixo | níveis 1–14 |
| Médio | níveis 15–34 |
| Alto | nível 35+ |

Os limites são server-side e configuráveis. Requisitos específicos mais altos das missões atuais continuam prevalecendo. Uma oferta baixa permanece visível para veteranos, mas aparece como destinada a iniciantes e não pode ser iniciada por eles.

### 8.4 Expiração

- oferta não iniciada expira na troca da hora;
- oferta iniciada continua normalmente após a troca da rotação;
- `completed` e `failed` nunca voltam para `available`;
- reconnect ou restart não repõe contrato consumido;
- cada personagem mantém progressão própria, mas todos enxergam o mesmo mercado;
- o motorista só pode manter uma entrega ativa.

### 8.5 Repetição de rotas

O gerador pode reutilizar qualquer rota canônica entre horas, mas deve reduzir a chance de repetir `missionId + routeIndex` usado nas duas rotações globais anteriores. Se o catálogo de um tier for pequeno, repetir é melhor que alterar coordenadas ou inventar uma rota.

### 8.6 Quadro esgotado

Se todos os contratos forem iniciados, o quadro permanece vazio até a próxima hora. Não existe fallback ilimitado, entrega emergencial, reroll individual ou botão de atualização manual.

A NUI mostra:

```text
TODAS AS CARGAS DESTA ROTAÇÃO FORAM DISTRIBUÍDAS
Novas oportunidades em 32:18
```

Uma atualização administrativa excepcional deve ser auditada e não pode ser exposta como comando comum de gameplay.

## 9. Aquisição e ciclo do contrato global

### 9.1 Uma carga, um motorista

Cada oferta global tem capacidade exatamente igual a um.

Não existem:

- número de vagas;
- reserva;
- candidatura;
- janela de interesse;
- fila;
- sorteio;
- prioridade manual.

O fluxo é direto:

```text
AVAILABLE
   ↓ primeiro StartGlobalOffer válido confirmado pelo servidor
IN_PROGRESS
   ├── COMPLETED
   └── FAILED
```

### 9.2 Primeiro a iniciar leva

O botão `INICIAR CONTRATO` dispara uma tentativa, não uma confirmação visual antecipada.

O servidor deve, na mesma operação lógica:

1. carregar a oferta canônica;
2. conferir `rotationId` e expiração;
3. conferir se o estado ainda é `available`;
4. conferir personagem, nível, reputação e licença;
5. conferir proximidade da central;
6. conferir ausência de outra entrega ativa;
7. conferir se o motorista ainda não iniciou contrato nessa rotação;
8. alterar condicionalmente o estado para `in_progress` e registrar o vencedor;
9. somente depois confirmar ao client e iniciar spawn/fluxo;
10. publicar a remoção/atualização da oferta para todos os viewers.

Se dois jogadores clicarem no mesmo frame, somente uma transição poderá afetar a oferta:

```sql
UPDATE noir_truck_global_offers
SET status = 'in_progress',
    driver_identifier = ?,
    started_at = NOW()
WHERE offer_id = ?
  AND rotation_id = ?
  AND status = 'available';
```

`affectedRows == 1` confirma o vencedor. `affectedRows == 0` responde conflito. O caminhão não pode ser criado antes dessa confirmação.

Resposta do perdedor:

```text
Esta carga acabou de ser iniciada por outro motorista.
```

### 9.3 Limite por motorista

- máximo de um contrato global iniciado por rotação;
- o limite é consumido quando o servidor confirma o início, não no pagamento;
- concluir rapidamente não libera outro global naquela hora;
- cancelar ou fracassar não devolve a participação;
- depois de encerrar a sessão, o motorista aguarda a rotação seguinte;
- não existe contrato alternativo pessoal para contornar o limite.

### 9.4 Falha e disponibilidade

Depois que o global é iniciado, a carga saiu do mercado. Portanto:

- cancelamento voluntário: `failed`, não retorna ao quadro;
- caminhão/carreta/carga destruída: `failed`, não retorna;
- abandono: `failed`, não retorna;
- resource stop: recuperação técnica ou `failed_system`, nunca `available` automaticamente;
- desconexão: pequena janela de recuperação da sessão; vencida a janela, `failed`;
- falha causada pelo servidor deve ser distinguida de abandono para não afetar confiabilidade.

Não recolocar a mesma carga evita duplicação econômica e mantém o significado de carga única.

## 10. Elegibilidade e tiers

### 10.1 Faixas iniciais

| Tier | Faixa sugerida |
|---|---|
| Baixo | nível 1–14 |
| Médio | nível 15–34 |
| Alto | nível 35+ |

O tier da oferta é metadado do novo sistema. Ele não altera o destino nem o fluxo físico da rota.

Missões atuais com `reqLevel` 40, 50 ou 60 continuam exigindo esses níveis específicos. `high` não reduz um requisito mais alto já definido.

### 10.2 Critérios

O servidor resolve a elegibilidade por:

```text
nível mínimo
+ contrato/empresa disponível
+ reputação mínima
+ licença, quando configurada
+ nenhuma sessão ativa
+ oferta vigente e não consumida
```

O client recebe `eligible` e uma lista de motivos apenas para apresentação. Ele não calcula autorização.

### 10.3 Caminhões empresariais

Os nove caminhões atuais continuam no catálogo e continuam liberados por nível. Eles são fornecidos pelo job e eliminados no cleanup.

O V1 não cria:

- propriedade;
- placa persistente pessoal;
- garagem;
- financiamento;
- melhoria mecânica;
- multiplicador de pagamento por modelo escolhido.

Selecionar caminhão continua limitado pela lista `route.vehicle` e pelo nível definido em `Config.Trucks`. O servidor deve revalidar ambos.

## 11. Novo loop da entrega

### 11.1 Seleção

```text
jogador abre a central
      ↓
consulta o Mercado Global da hora
      ↓
escolhe uma oferta
      ↓
consulta empresa, carga, tier, rota, duração estimada,
requisitos, pagamento, XP, reputação e bônus de mercado
      ↓
seleciona um caminhão empresarial compatível
      ↓
pressiona INICIAR
```

### 11.2 Início autoritativo

O NUI envia somente identificadores:

```json
{
  "rotationId": "496818",
  "offerId": "496818-g-3",
  "truckModel": "packer"
}
```

O browser não envia missão completa, pagamento, XP, reputação, rota completa ou requisito. Como toda oferta é global, não existe campo `board` ou `boardType` no pedido.

O servidor resolve `missionId` e `routeIndex`, valida tudo, registra a sessão e responde:

```json
{
  "ok": true,
  "sessionId": "uuid-ou-token-opaco",
  "missionId": 1,
  "routeIndex": 2
}
```

### 11.3 Coleta, viagem, entrega e devolução

As etapas físicas permanecem como hoje:

1. caminhão fornecido em `Config.VehSpawn`;
2. deslocamento até o spawn da carreta/carga da rota;
3. acoplamento ou carregamento manual;
4. deslocamento até `destination`;
5. validação de entrega;
6. retorno ao local atual da empresa;
7. devolução do caminhão;
8. conclusão autoritativa e relatório.

Missões sem carreta, cargas acopladas e missão 16 mantêm seus fluxos existentes.

### 11.4 Máquina de estados

```text
STARTING
   ↓
TO_PICKUP
   ↓
LOADING / ATTACHING
   ↓
IN_TRANSIT
   ↓
AT_DESTINATION
   ↓
RETURNING
   ↓
COMPLETING
   ├── COMPLETED
   ├── FAILED
   └── CANCELLED
```

O client conduz marcadores, animações, câmera, blips e HUD. O servidor mantém a sessão autoritativa, os timestamps e as transições necessárias para impedir pagamento falso.

## 12. Avaliação da entrega

### 12.1 Objetivo

A recompensa deve depender da execução e da duração da rota, não de XP aleatório nem apenas do ID da missão.

### 12.2 Critérios iniciais

| Critério | Peso padrão |
|---|---:|
| Integridade do caminhão/carga | 40% |
| Pontualidade | 25% |
| Conclusão correta das etapas | 20% |
| Devolução/manobra final | 15% |

O V1 não precisa implementar telemetria invasiva de cada aceleração. Os pesos devem usar sinais confiáveis já disponíveis e validações simples.

### 12.3 Notas

| Nota | Faixa | Multiplicador financeiro | Multiplicador de XP | Reputação |
|---|---:|---:|---:|---:|
| S | 95–100 | 1,20 | 1,25 | bônus máximo |
| A | 85–94 | 1,10 | 1,10 | bônus |
| B | 70–84 | 1,00 | 1,00 | normal |
| C | 50–69 | 0,75 | 0,75 | sem bônus |
| D | 0–49 | 0,40 | 0,40 | possível perda configurável |

Os valores são defaults de planejamento e devem ser calibrados com a economia real da cidade.

### 12.4 Relatório

Depois da devolução, a NUI mostra:

```text
ENTREGA CONCLUÍDA — NOTA A

Pagamento base                  $8.500
Bônus do Mercado Global (+15%)  $1.275
Bônus de qualidade (+10%)         $978
Penalidade por danos              -$350
──────────────────────────────────────
Total                           $10.403

XP recebido                        920
Reputação                           +3
```

O jogador precisa entender cada crédito e desconto. Não mostrar apenas o valor final.

## 13. Pagamento e controle econômico

### 13.1 Princípio

O número de ofertas limita repetição, mas não corrige sozinho valores incompatíveis com a economia. O balanceamento deve ter uma meta de renda por hora definida pela administração.

```text
basePay = targetIncomePerHour
        × estimatedMinutes / 60
        × difficultyMultiplier
```

Depois:

```text
finalPay = basePay
         × marketBonus
         × gradeMultiplier
         - validatedPenalties
```

`estimatedMinutes` pode ser configurado por `missionId + routeIndex` sem alterar coordenadas. Em uma fase posterior, poderá ser calculado a partir de telemetria real.

### 13.2 Bônus de mercado

| Tier | Dinheiro | XP | Reputação adicional |
|---|---:|---:|---:|
| Baixo | +10% | +15% | +1 |
| Médio | +15% | +20% | +1 |
| Alto | +20% a +25% | +25% | +2 |

O bônus financeiro de mercado não deve ultrapassar 25%. Ele não é enviado pelo client e não pode ser combinado duas vezes.

### 13.3 XP determinístico

O sorteio atual de 100–500 XP por entrega será removido do fluxo novo. Cada oferta terá `baseXP` derivado do tier/duração, e a nota aplicará seu multiplicador.

Dois motoristas que executarem ofertas equivalentes com a mesma nota devem receber recompensa equivalente.

### 13.4 Limites econômicos

- cada oferta paga uma vez para um único motorista;
- um motorista inicia um global por rotação;
- a injeção máxima por hora é a soma das 3–7 ofertas geradas, nunca uma cota multiplicada pelo número de jogadores;
- repetir evento de conclusão não repaga;
- `sessionId` concluído é idempotente;
- falha não volta a disponibilizar carga global;
- pagamento ocorre somente após devolução validada;
- bônus de mercado é limitado e auditável.

## 14. Reputação e desbloqueios

A confiança atual deixa de funcionar como moeda que é gasta ao desbloquear missões. No V1 ela passa a ser reputação vitalícia por empresa.

```text
Desconhecido → Parceiro → Confiável → Especialista → Elite
```

O desbloqueio compara o valor acumulado com o requisito, mas não subtrai pontos.

Consequências:

- `UnlockMission` não recebe objeto de missão do client;
- preferencialmente, missões são consideradas disponíveis automaticamente quando nível e reputação são suficientes;
- se houver botão explícito de desbloqueio, ele envia apenas `missionId` e não consome reputação;
- rotas com `reqPoint` passam a usar requisito de reputação, sem gasto;
- contratos globais podem conceder reputação adicional;
- a página Companies mostra progresso até o próximo patamar.

Uma migração deve preservar os pontos existentes. Não é possível reconstruir pontos já gastos historicamente sem fonte adicional; por isso a migração deve registrar a regra adotada e nunca reduzir o saldo atual.

## 15. Missões diárias

As missões diárias permanecem no V1, mas não podem criar entregas particulares nem contornar a escassez do quadro:

- concluir um contrato global quando conquistar uma oportunidade;
- obter nota A ou S;
- concluir duas empresas diferentes;
- concluir uma entrega média sem dano relevante;
- concluir um contrato antes da expiração da rotação.

Regras obrigatórias:

- progresso calculado pelo servidor a partir de conclusão validada;
- chave de missão validada antes de acesso;
- recompensa concedida uma única vez, com campo `claimed` ou transição atômica;
- eventos do client não concedem progresso diretamente;
- reset usa o relógio canônico do servidor;
- recompensas priorizam XP e reputação, evitando grandes injeções de dinheiro.

O bug atual que concede XP novamente enquanto `process == max` precisa ser eliminado.

## 16. Carga ilegal

A oferta ilegal continua sendo um ramo opcional durante uma entrega ativa, usando os mesmos NPC, board location e fluxo de dez caixas.

Para o V1:

- ela não cria um terceiro quadro;
- não altera coordenadas existentes;
- só pode ser aceita dentro de sessão de entrega válida;
- contagem de caixas precisa de validação de sessão, proximidade e intervalo;
- bônus é resolvido pelo servidor;
- `loadedIllegal` enviado pelo client não é prova suficiente;
- contrato não recebe automaticamente bônus ilegal maior;
- configuração pode impedir carga ilegal em tiers/empresas incompatíveis.

Qualquer expansão com polícia, fiscalização, perda de reputação legal ou mercado clandestino é posterior ao V1.

## 17. NUI planejada

### 17.1 Navegação principal

O cabeçalho continua com:

```text
NTS Main | Companies | Leaderboard | Profile
```

`NTS Main` passa a apresentar diretamente:

```text
[ MERCADO GLOBAL ]  Novas cargas em 37:42
```

Não existe seletor de quadro.

### 17.2 Coluna esquerda

Substituir a lista de missões estáticas pela lista global da rotação atual.

Cada linha mostra:

- imagem atual da missão;
- nome da missão;
- tier;
- empresa;
- duração estimada;
- pagamento previsto;
- status;
- badge de tier e bônus de mercado.

Estados visuais:

| Estado | Apresentação |
|---|---|
| available | card interativo normal |
| locked | cadeado + requisitos claros |
| starting | botão bloqueado + spinner curto |
| in_progress | destaque e texto `EM ANDAMENTO` |
| completed | reduzido + check + `CONCLUÍDO` |
| failed | reduzido + `FRACASSADO` |
| expired | indisponível + `EXPIRADO` |

No global, uma oferta ganha por outro motorista deve ser removida da lista ou animada para `INDISPONÍVEL` antes de desaparecer. Não mostrar nome do vencedor por padrão.

### 17.3 Hero da oferta

Reutilizar imagem e composição atuais, corrigindo o nome de empresa hoje fixo em National Transfer & Storage.

Mostrar:

```text
EMPRESA
NOME DA MISSÃO

Tier • carga • duração • rotas/requisito
Pagamento • XP • reputação • bônus de mercado
```

O contador atual rotulado como `routes` deve representar rotas da missão, não quantidade de missões visíveis.

### 17.4 Coluna central

Continua mostrando:

- rota selecionada pela oferta;
- caminhões compatíveis fornecidos pela empresa;
- nível necessário;
- requisitos de reputação/licença;
- pagamento extra já incorporado ao preview autoritativo.

Como uma oferta já representa `missionId + routeIndex`, o jogador não troca livremente para outra rota dentro do mesmo card. Para obter outra rota, seleciona outra oferta. Isso impede usar a oferta somente como atalho para a rota mais lucrativa.

### 17.5 Coluna direita

Continua mostrando motorista e etapas. Adicionar:

- timer até próxima rotação;
- aviso `1 CONTRATO POR ROTAÇÃO`;
- elegibilidade;
- resumo da recompensa;
- missões diárias abaixo.

O botão principal:

```text
disponível          → INICIAR CONTRATO
requisição pendente → INICIANDO...
sessão ativa        → CANCELAR ENTREGA
bloqueado           → REQUISITO NÃO ATENDIDO
```

Não usar texto `RESERVAR` em nenhum lugar.

### 17.6 Concorrência visual do global

Ao clicar:

1. o botão local entra em `INICIANDO...`;
2. a NUI aguarda resposta do servidor;
3. sucesso fecha o menu e inicia o fluxo;
4. conflito exibe notificação e atualiza o quadro;
5. timeout consulta novamente o snapshot antes de permitir outro clique;
6. nunca assumir vitória por animação do browser.

### 17.7 Perfil

Manter ganhos totais, trabalhos concluídos, nível e histórico. Adicionar ao histórico:

- nota;
- empresa;
- tier;
- pagamento base;
- bônus;
- total;
- resultado;
- `completedAt`.

O perfil deverá mostrar barra de XP, XP atual, requisito do próximo nível e últimas entregas sem carregar histórico ilimitado no payload inicial.

### 17.8 Ranking

O Top 8 pode permanecer no V1, mas:

- não exibir motoristas fictícios quando o banco estiver vazio;
- informar estado vazio real;
- mostrar posição do próprio jogador fora do Top 8;
- não entregar prêmio monetário automático;
- permitir métrica de nível e entregas globais concluídas;
- cache continua aceitável, com invalidação controlada.

### 17.9 Idioma

Textos novos e textos hardcoded atuais devem passar por locales. O V1 deve incluir `pt-BR` como idioma do Noir State e manter fallback para inglês.

## 18. Contrato de dados da NUI

### 18.1 Snapshot do despacho

```ts
type DispatchSnapshot = {
  serverNow: number
  rotation: {
    id: string
    expiresAt: number
    refreshSeconds: number
  }
  player: {
    name: string
    level: number
    xp: number
    usedThisRotation: boolean
    activeSessionId?: string
  }
  offers: ContractOffer[]
}

type ContractOffer = {
  offerId: string
  rotationId: string
  missionId: number
  routeIndex: number
  tier: 'low' | 'medium' | 'high'
  companyIndex: number
  title: string
  image: string
  routeLabel: string
  estimatedMinutes: number
  paymentPreview: number
  xpPreview: number
  reputationPreview: number
  moneyBonusPercent: number
  xpBonusPercent: number
  status: 'available' | 'locked' | 'in_progress' | 'completed' | 'failed' | 'expired'
  eligible: boolean
  lockReasons: string[]
  compatibleTrucks: TruckProjection[]
}
```

Valores de preview vêm do servidor. Mesmo assim, o servidor recalcula a recompensa final.

### 18.2 NUI → client

| Callback | Payload | Finalidade |
|---|---|---|
| `getDispatchBoard` | vazio | obter snapshot atual |
| `startContract` | `{rotationId, offerId, truckModel}` | tentar iniciar |
| `refreshDispatchBoard` | vazio | ressincronizar após conflito/timeout |
| `stopJob` | motivo local opcional | solicitar cancelamento |
| `getLeaderboard` | página/métrica | carregar ranking |

O callback legado `startJob` com objetos completos deixa de ser fonte de verdade.

### 18.3 Servidor → client/NUI

| Evento/ação | Uso |
|---|---|
| `dispatchSnapshot` | snapshot inicial/completo |
| `globalOfferClaimed` | remoção imediata do global iniciado |
| `rotationChanged` | novo timer e novas ofertas |
| `jobSessionStarted` | confirmação autoritativa |
| `jobResult` | relatório de conclusão |
| `jobFailed` | motivo de falha |

O evento `globalOfferClaimed` deve conter somente o necessário para remover a oferta, sem expor identifier.

## 19. Sessão server-authoritative

### 19.1 Estrutura mínima

```lua
ActiveJobs[source] = {
    sessionId = 'opaque-token',
    identifier = 'citizenid',
    rotationId = '496818',
    offerId = '496818-g-3',
    missionId = 1,
    routeIndex = 2,
    tier = 'low',
    truckModel = 'packer',
    startedAt = os.time(),
    phase = 'to_pickup',
    pickupConfirmedAt = nil,
    destinationConfirmedAt = nil,
    returningAt = nil,
    illegalBoxes = 0,
    completed = false,
}
```

### 19.2 Regras

- `source` é chave de acesso durante conexão, mas `identifier` é identidade persistente;
- sessão contém IDs canônicos, não tabelas enviadas pelo browser;
- `missionId` e `routeIndex` são resolvidos no servidor;
- fase nunca retrocede sem cleanup explícito;
- somente uma conclusão altera dinheiro;
- `sessionId` torna conclusão idempotente;
- cancelar invalida o token;
- abrir/fechar NUI não cria nem encerra sessão;
- mudança de rotação não substitui sessão ativa.

### 19.3 Validações de conclusão

Antes de pagar:

- sessão existe e pertence ao personagem;
- oferta corresponde à sessão;
- missão e rota existem no catálogo;
- fase esperada foi alcançada;
- tempo mínimo plausível passou;
- jogador e veículo estão na área de devolução atual;
- veículo da sessão corresponde ao net ID registrado;
- carreta/carga necessária foi validada;
- sessão ainda não foi paga;
- resultado é gravado antes ou atomicamente com o pagamento lógico.

Saúde informada pelo client pode contribuir para apresentação, mas não pode ser aceita cegamente como valor canônico.

## 20. Persistência

### 20.1 Problemas atuais

A tabela `peak_trucking` usa `LONGTEXT` para identifier e estruturas JSON, não possui chave primária e mantém todo o histórico dentro de uma coluna. O ranking busca colunas que a NUI não utiliza.

### 20.2 Modelo proposto

#### Perfil

```sql
CREATE TABLE noir_truck_profiles (
    identifier VARCHAR(64) PRIMARY KEY,
    level INT NOT NULL DEFAULT 1,
    xp INT NOT NULL DEFAULT 0,
    total_earnings BIGINT NOT NULL DEFAULT 0,
    completed_jobs INT NOT NULL DEFAULT 0,
    failed_jobs INT NOT NULL DEFAULT 0,
    global_completed INT NOT NULL DEFAULT 0,
    global_failed INT NOT NULL DEFAULT 0,
    name VARCHAR(128) NULL,
    avatar VARCHAR(512) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

#### Reputação

```sql
CREATE TABLE noir_truck_company_reputation (
    identifier VARCHAR(64) NOT NULL,
    company_index TINYINT UNSIGNED NOT NULL,
    reputation INT NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier, company_index)
);
```

#### Rotações globais

```sql
CREATE TABLE noir_truck_global_offers (
    offer_id VARCHAR(96) PRIMARY KEY,
    rotation_id VARCHAR(32) NOT NULL,
    mission_id INT NOT NULL,
    route_index INT NOT NULL,
    tier VARCHAR(16) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'available',
    driver_identifier VARCHAR(64) NULL,
    started_at TIMESTAMP NULL,
    finished_at TIMESTAMP NULL,
    result_reason VARCHAR(64) NULL,
    UNIQUE KEY uq_rotation_route (rotation_id, mission_id, route_index),
    UNIQUE KEY uq_rotation_driver (rotation_id, driver_identifier),
    KEY ix_rotation_status (rotation_id, status)
);
```

#### Histórico

```sql
CREATE TABLE noir_truck_deliveries (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    session_id VARCHAR(96) NOT NULL,
    identifier VARCHAR(64) NOT NULL,
    rotation_id VARCHAR(32) NOT NULL,
    offer_id VARCHAR(96) NOT NULL,
    mission_id INT NOT NULL,
    route_index INT NOT NULL,
    tier VARCHAR(16) NOT NULL,
    grade CHAR(1) NULL,
    score DECIMAL(5,2) NULL,
    base_payment INT NOT NULL DEFAULT 0,
    bonus_payment INT NOT NULL DEFAULT 0,
    penalty_payment INT NOT NULL DEFAULT 0,
    final_payment INT NOT NULL DEFAULT 0,
    xp_awarded INT NOT NULL DEFAULT 0,
    reputation_awarded INT NOT NULL DEFAULT 0,
    status VARCHAR(16) NOT NULL,
    result_reason VARCHAR(64) NULL,
    started_at TIMESTAMP NOT NULL,
    finished_at TIMESTAMP NULL,
    UNIQUE KEY uq_session (session_id),
    KEY ix_player_finished (identifier, finished_at),
    KEY ix_rotation (rotation_id)
);
```

Nomes finais podem permanecer sob prefixo `peak_trucking`, desde que os contratos e índices sejam equivalentes. A escolha de prefixo deve ser única durante a implementação.

## 21. Geração das ofertas

### 21.1 Pool

O catálogo continua em `Config.Missions`. Adicionar metadados em tabela separada ou nos registros existentes:

```lua
Config.RouteMeta = {
    ['1:1'] = { tier = 'low', estimatedMinutes = 18, baseXP = 450 },
    ['1:2'] = { tier = 'low', estimatedMinutes = 22, baseXP = 520 },
}
```

A chave `missionId:routeIndex` evita tocar em qualquer coordenada.

### 21.2 Algoritmo global

```text
sortear quantidade low 1–2
sortear quantidade medium 1–2
sortear quantidade high 1–3
→ selecionar rotas únicas por tier
→ persistir antes de publicar
→ disponibilizar snapshot para todos
```

O RNG roda apenas no servidor. O resultado da hora fica congelado.

### 21.3 Falta de candidatos no catálogo

Se os metadados ainda não classificarem todas as rotas:

1. não alterar coordenadas;
2. não criar missão fictícia;
3. registrar warning;
4. preencher com rota do tier mais próximo quando permitido;
5. nunca gerar oferta cujo `missionId` ou `routeIndex` não exista.

## 22. Configuração proposta

```lua
Config.ContractBoard = {
    rotationMinutes = 60,

    global = {
        low = { min = 1, max = 2 },
        medium = { min = 1, max = 2 },
        high = { min = 1, max = 3 },
        capacityPerOffer = 1,
        maxStartsPerPlayerPerRotation = 1,
        reservationEnabled = false,
        levelBands = {
            low = { min = 1, max = 14 },
            medium = { min = 15, max = 34 },
            high = { min = 35, max = nil },
        },
        bonuses = {
            low = { money = 0.10, xp = 0.15, reputation = 1 },
            medium = { money = 0.15, xp = 0.20, reputation = 1 },
            high = { money = 0.25, xp = 0.25, reputation = 2 },
        },
    },

    reconnectGraceSeconds = 180,
    completionIdempotency = true,
}
```

`reservationEnabled = false` documenta uma decisão de produto, não uma opção que a NUI deve expor.

## 23. Segurança obrigatória

O V1 deve corrigir, junto do novo loop:

1. Não aceitar tabela de missão vinda do client para desbloqueio.
2. Não aceitar pagamento, XP, tier, bônus ou requisito do client.
3. Não aceitar `StartJob(missionId)` como prova de contrato válido.
4. Não confiar no bloqueio React de nível/caminhão/reputação.
5. Não aceitar `routeLabel` livre como identificação canônica.
6. Não pagar apenas porque o client informou retorno ao depósito.
7. Não confiar em `vehicleHealth` sem verificação/plausibilidade server-side.
8. Não avançar missão diária por evento arbitrário do client.
9. Não contar caixas ilegais sem sessão, distância e rate limit.
10. Não permitir duas conclusões do mesmo `sessionId`.
11. Não permitir duas aquisições do mesmo global em concorrência.
12. Não permitir que reconnect ou restart recrie oferta consumida.

Todos os callbacks sensíveis retornam erros estruturados e logam anomalias sem expor dados internos ao jogador.

## 24. Cleanup e casos extremos

| Caso | Resultado esperado |
|---|---|
| Fecha NUI sem iniciar | nenhuma oferta consumida |
| Dois jogadores iniciam o mesmo global | um vence; outro recebe conflito; um caminhão é criado |
| Client envia offer inexistente | rejeição, log e nenhum spawn |
| Rotação muda com job ativo | job continua; oferta nova não substitui sessão |
| Caminhão destruído | cleanup e `failed` |
| Carreta/carga destruída | cleanup e `failed` |
| Cancelamento voluntário global | `failed`, carga não retorna ao quadro |
| Disconnect durante job | graça configurada e depois recuperação ou falha |
| Resource restart | rotação não muda; não duplica pagamentos |
| Banco indisponível no início global | falha fechada; não criar caminhão |
| Pagamento falha após persistência | estado reconciliável; nunca pagar em dobro |
| NUI timeout após clique global | consultar snapshot; não reenviar cegamente |
| Spawn ocupado | falhar início sem consumir oferta, desde que aquisição ainda possa ser revertida atomicamente antes da criação |

Para o último caso, a implementação deve decidir a ordem segura entre localizar spawn e adquirir oferta. Recomenda-se validar disponibilidade física imediatamente antes da transição atômica global e revalidar após a confirmação. Se uma falha técnica impedir o spawn, marcar `failed_system` e não punir o motorista.

## 25. Observabilidade e balanceamento

Registrar, sem loops de alto custo:

- ofertas geradas por tier/rotação;
- ofertas globais iniciadas, concluídas, fracassadas e expiradas;
- conflitos simultâneos de início;
- tempo médio por `missionId:routeIndex`;
- pagamento médio por minuto;
- notas médias;
- taxa de falha/cancelamento;
- quantidade de dinheiro injetada por rotação e tier;
- XP/reputação entregues;
- rotas mais e menos escolhidas;
- jogadores que falham globais repetidamente.

O balanceamento deve responder principalmente a:

```text
Quanto um motorista B/A ganha por hora real?
Quantos contratos globais são concluídos por rotação?
Quais rotas pagam acima da média por minuto?
Quantas ofertas globais expiram sem uso?
```

Não balancear apenas pelo valor nominal do contrato.

## 26. Plano de implementação por área

### Fase 1 — Recuperar e estabilizar a base

- corrigir a inclusão do `peak-trucking` no repositório, atualmente registrado como gitlink sem `.gitmodules`;
- garantir que o resource completo esteja disponível no checkout;
- preservar commit/base de referência;
- criar migration sem apagar dados atuais;
- adicionar PK/índices necessários;
- corrigir exploit de missão diária e eventos sensíveis.

### Fase 2 — Domínio de contratos

- criar tipos `Rotation`, `ContractOffer` e `JobSession`;
- criar classificação `RouteMeta` para as 37 rotas;
- implementar gerador global;
- persistir/estabilizar rotação;
- implementar aquisição global atômica;
- implementar limite de um global por rotação.

### Fase 3 — Novo início e sessão

- substituir payload completo por IDs;
- resolver missão/rota no servidor;
- validar nível, reputação, caminhão e proximidade;
- criar token idempotente;
- conectar sessão nova ao fluxo físico atual;
- preservar blips, spawns, carregamentos e destinos.

### Fase 4 — Recompensa e progressão

- configurar duração/tier/XP base das rotas;
- remover XP aleatório;
- implementar nota S–D;
- implementar breakdown financeiro;
- tornar reputação não consumível;
- adaptar missões diárias para eventos validados;
- gravar histórico normalizado.

### Fase 5 — NUI

- transformar o `DispatchView` em um quadro global único;
- substituir missão estática por oferta;
- adicionar timer baseado em `serverNow/expiresAt`;
- implementar estados de oferta;
- implementar disputa global e resposta de conflito;
- corrigir empresa fixa e contador de rotas;
- criar relatório de conclusão;
- atualizar perfil, ranking e locales pt-BR;
- manter HUD e edição de posição.

### Fase 6 — QA e tuning

- testes de concorrência;
- testes de reconnect/restart;
- testes de idempotência;
- verificar todas as 37 rotas;
- calibrar renda por hora;
- validar resolução 1440×900 e resoluções menores;
- gerar `ui/dist` e testar dentro do FiveM.

## 27. Mapeamento de arquivos esperado

| Arquivo atual | Mudança planejada |
|---|---|
| `shared/config.lua` | manter missões/coordenadas; adicionar configuração de quadro ou referência a RouteMeta |
| `shared/internal_config.lua` | substituir curva apenas se o rebalanceamento aprovar; não misturar coordenadas |
| `shared/locales.lua` | pt-BR e todos os textos novos |
| `server/main.lua` | sessão autoritativa, início e conclusão por oferta |
| `server/xp.lua` | XP determinístico/idempotente |
| `server/dailymissions.lua` | progressão por eventos server-side e recompensa única |
| novo módulo de rotação | geração, snapshot, expiração e persistência |
| novo módulo de contratos | aquisição global atômica e transições |
| `client/main.lua` | consumir sessão confirmada mantendo o fluxo físico atual |
| `ui/src/App.tsx` | estado/sincronização do mercado e relatório |
| `ui/src/components/DispatchView.tsx` | cards globais e início por IDs |
| `CompaniesView.tsx` | reputação não consumível e próximos requisitos |
| `ProfileView.tsx` | nota, breakdown e paginação de histórico |
| `LeaderboardView.tsx` | remover mocks em produção e posição própria |
| `JobHud.tsx` | manter; exibir tier/tipo se necessário |
| `ui/src/types/trucking.ts` | novos contratos TypeScript |
| `ui/src/styles.css` | estilos do mercado, estados e relatório sem trocar identidade |
| `install/install.sql` | tabelas/índices/migration |

## 28. Critérios de aceite

### 28.1 Preservação

- as 16 missões continuam resolvendo;
- as 37 rotas são iniciáveis quando elegíveis;
- nenhuma coordenada muda;
- nenhum spawn/destino é duplicado em outra configuração;
- modelos e cargas especiais permanecem iguais;
- missão 16 continua com carregamento manual;
- veículos continuam sendo fornecidos pela empresa.

### 28.2 Mercado global

- cada hora contém 1–2 baixas, 1–2 médias e 1–3 altas;
- cada global pode ter exatamente um vencedor;
- primeiro pedido válido processado ganha;
- não existe estado ou botão de reserva;
- dois starts simultâneos geram um único job/spawn;
- contrato iniciado desaparece para todos;
- vencedor não inicia outro global na mesma rotação;
- falha não devolve a carga ao quadro.

### 28.3 Economia e progressão

- dinheiro e XP não são enviados pelo client;
- XP deixa de ser sorteado;
- nota altera recompensa de forma explicável;
- global aplica bônus uma vez e até o teto;
- reputação não é gasta;
- missão diária paga uma única vez;
- conclusão duplicada é idempotente.

### 28.4 Interface

- o Mercado Global e seu estado de escassez são compreensíveis;
- timer usa horário do servidor;
- cards explicam bloqueios antes do clique;
- botão global usa `INICIAR`, nunca `RESERVAR`;
- conflito simultâneo tem feedback claro;
- empresa correta aparece no hero;
- contador de rotas está correto;
- ranking vazio não mostra personagens falsos;
- relatório final explica créditos e descontos;
- NUI fecha e libera foco corretamente;
- HUD permanece utilizável e reposicionável.

## 29. Matriz mínima de testes

| Teste | Resultado |
|---|---|
| Gerar rotação com seed fixa | mesmo conjunto após restart |
| Abrir com jogador nível 1 | somente ofertas baixas elegíveis podem ser iniciadas |
| Jogador avançado tenta oferta baixa | bloqueado pela faixa de nível |
| Dois clients iniciarem mesmo global | exatamente um sucesso |
| Vencedor clicar duas vezes | uma sessão e um veículo |
| Perder disputa e reenviar payload | oferta indisponível |
| Forjar missionId/routeIndex | ignorado/rejeitado |
| Forjar pagamento/XP | campos não aceitos |
| Concluir fora da devolução | sem pagamento |
| Repetir conclusão | mesmo resultado, sem segundo pagamento |
| Completar diária e repetir evento | uma recompensa |
| Rotação virar durante viagem | viagem permanece válida |
| Reconectar na mesma hora | consumos mantidos |
| Cancelar global | falha permanente na rotação |
| Destruir caminhão/carreta/carga | cleanup e falha |
| Testar missão 16 | dez caixas e fluxo preservado |
| Testar carga ilegal | bônus somente com dez caixas validadas |
| Abrir ranking vazio | empty state real |
| Build NUI | `tsc --noEmit` e Vite sem erro |

## 30. Resultado esperado

O Noir Truck V1 mantém o mundo e o conteúdo físico do Peak Trucking, mas troca um catálogo infinito por um sistema de oportunidades:

```text
Mercado global
→ cria de três a sete cargas únicas por hora
→ cada carga pertence ao primeiro motorista elegível que iniciar
→ entrega bônus controlado e prestígio
→ quando as cargas acabam, não há novas entregas até a próxima hora

Execução
→ usa os mesmos caminhões, carretas, cargas, spawns e destinos
→ avalia qualidade e devolução
→ paga uma vez, com cálculo explicado e autoritativo
```

O resultado deve parecer uma central logística viva, com escassez compreensível e progressão profissional, sem transformar o jogador em proprietário de frota e sem descartar o trabalho já feito nas rotas atuais.
