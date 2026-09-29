# noir_fazenda

Receita do Noir State: **ledger de movimentação** e **apuração de imposto de renda**.

Serviço de domínio, `server_only`. Não tem client, não tem NUI, não tem comando de
jogador. Alíquota, base de cálculo e dívida nunca chegam ao cliente.

**A cobrança nasce desligada.** Ver [Ligar o imposto](#ligar-o-imposto).

---

## Por que ele existe

O extrato do banco é um blob JSON por conta, reescrito inteiro a cada transação,
sem limite e sem índice. Dá para **mostrar**, não dá para **somar**: não existe
como perguntar "quanto entrou para este cidadão na semana passada" sem decodificar
todo o histórico de todo mundo. Sem essa resposta não há imposto.

O `noir_fazenda` mantém a mesma informação em formato consultável: uma linha por
movimento, com o período fiscal já calculado na escrita. Apurar vira um `SUM` com
índice em cima.

---

## A decisão de desenho que importa

O pedido original foi "imposto de renda **baseado na movimentação** da conta".
Movimentação e renda são coisas diferentes, e a escolha decide se o sistema
funciona:

**Taxar movimentação faz o jogador fugir do banco.** Ele recebe em espécie, paga
em espécie, e a conta vira um cofre que ninguém usa. O imposto arrecada perto de
zero e sobra um resource que ninguém sente.

**Taxar entradas sobrevive** porque neste servidor dinheiro em espécie é item de
inventário — pode ser roubado. Guardar no banco custa imposto; guardar no bolso
custa risco. É essa tensão que faz o sistema virar jogo em vez de planilha.

Foi essa a opção implementada: **só entradas são tributadas**. Saída nunca é.

### O caso que decide tudo

O banco não distingue entrada de renda de entrada de bolso. Depositar o próprio
dinheiro em espécie e receber um pagamento chegam os dois como `deposit`.

O que separa os dois é que **transferência gera duas pernas ligadas pelo mesmo
id**, e depósito em espécie gera uma perna solta. É por isso que o patch no banco
passa o `transID` cru adiante, e é por isso que o payload do bridge tem
`isTransferLeg`.

Sem essa distinção, o sistema cobraria imposto de alguém **por usar o banco** —
exatamente o comportamento que faria a conta ser abandonada.

| o que aconteceu | chega como | categoria | tributa? |
|---|---|---|---|
| depositou o próprio dinheiro em espécie | `deposit` solto | `deposito_proprio` | não |
| alguém transferiu para ele | `deposit` com perna ligada | `transferencia_recebida` | **sim** |
| sacou ou transferiu para fora | `withdraw` | `saida` | não |
| conta de organização, qualquer direção | — | — | não (ainda) |

---

## Como a movimentação chega aqui

```
Renewed-Banking  handleTransaction()
      │          (uma linha: TriggerEvent com o movimento cru)
      ▼
bgrz_core  server/banking.lua          ← traduz as manias do provider
      │    bgrz_core:bankMovement      ← payload neutro, sem nome de banco
      ▼
noir_fazenda  server/bridges/banking.lua
      ▼
ledger service → storage → noir_fazenda_ledger
```

**Este resource não sabe qual banco o servidor usa.** O nome do provider não
aparece em nenhum arquivo de código dele — só em comentário. Isso não é zelo
teórico: o banco deste servidor já foi trocado duas vezes. Há um teste que
falha se alguém escrever o nome do provider aqui dentro.

O patch no lado do banco está documentado em
`resources/[standalone]/Renewed-Banking/PATCHES-NOIR.md`.

### O que o feed bancário NÃO vê

`handleTransaction` só enxerga o que passa pela interface do banco. **Salário,
pagamento de job e recompensa creditados direto na carteira por outro script são
invisíveis para ele.**

Esses produtores entram pelo export `RecordIncome`. Enquanto nenhum resource
chamar esse export, a base tributável cobre só pagamento entre contas — o que é
suficiente para começar a medir, mas não é a renda total de um jogador.

---

## Períodos

Semana fiscal, abrindo na segunda. `Period.timezoneOffsetHours` define em que fuso
a semana vira — o servidor roda em UTC, mas o jogador pensa em Brasília.

A conversão data ↔ dia é aritmética pura (algoritmo de Howard Hinnant), sem
`os.time`. `os.time` interpretaria a data no fuso do processo, e a semana fiscal
viraria em hora diferente dependendo de onde o servidor estivesse hospedado.

A chave carrega o modo (`W2026-09-14`, `D2026-09-20`), então mudar
`Period.mode` não reinterpreta período já gravado.

---

## Ligar o imposto

Estado de fábrica:

```lua
Tax.collectionEnabled  = false   -- ninguém é cobrado
Tax.assessmentEnabled  = true    -- mas a conta é calculada
Assessment.autoClose   = false   -- e o fechamento é manual
```

Com a cobrança desligada, `/fazenda apurar` fecha o período e grava a apuração
com status `simulated`: o número existe, aparece no comando e no export, e **não
é dívida**.

É de propósito. Alíquota escolhida no escuro é como se quebra economia de RP — o
caminho é rodar algumas semanas assim, olhar `/fazenda status` e as apurações
simuladas, e só então mexer nas faixas.

Para ligar de verdade:

1. ajuste `Tax.brackets` com base no que foi medido;
2. `Tax.collectionEnabled = true`;
3. `Assessment.autoClose = true` quando confiar no fechamento.

As faixas são **progressivas na margem**, como IR de verdade: base de 30k paga 0%
sobre os primeiros 25k e 5% só sobre os 5k que passaram. A primeira faixa com
`rate = 0` **é** a faixa de isenção — não existe outro parâmetro de isenção de
propósito, porque dois jeitos de dizer a mesma coisa é como se cria divergência
entre config e comportamento.

`Tax.minAssessment` dispensa imposto de valor baixo: cobrar $7 de alguém gera mais
atrito de RP do que receita.

---

## Cobrança: o que falta, e como deve ser feito

O que **não** se deve construir aqui é uma cobrança paralela.

Multa criminal **já existe e já cobra**: o `ps-mdt` debita de verdade em
`charges.lua` e `sentencing.lua`, e registra em `mdt_reports_charges`, que é tabela
indexada. Reconstruir isso seria duplicar máquina funcionando.

O caminho pretendido é:

> imposto vence → vira dívida → vira **acusação no MDT** → polícia cobra com o
> sistema de multa que já existe

O gancho é o export `GetOutstanding`, que responde quanto um cidadão deve. Quem
faz a ponte com o MDT é outro resource; o `noir_fazenda` só responde a pergunta.

**Multa de radar** hoje passa por fora do MDT (`police:server:Radar` debita e
credita `police` direto), então não há registro de quem levou. Rotear por aqui é
trabalho separado, ainda não feito.

---

## Conta da Receita

`Treasury.accountId = 'fazenda'`, criada pelo próprio resource via
`bgrz_core:EnsureOrgAccount`. Não existe job de governo no `qbx_core` e **não foi
criado um** — editar core para atender um script é anti-padrão (§25).

A criação **não** acontece no start deste resource. O banco publica
`Started resource` antes de carregar as contas, e criar conta nessa janela bate em
`Duplicate entry` — o cache dele ainda está vazio e ele não enxerga a linha que já
existe no banco de dados. Quem dispara é `bgrz_core:bankingReady`, emitido quando a
carga do banco termina de verdade. Sem laço, sem retry.

**Limitação conhecida, cosmética.** `Treasury.accountLabel` só vale no momento da
criação. Quando o banco reinicia, ele recarrega as contas do banco de dados e
renomeia cada uma com `GetSocietyLabel(id)`, que procura o id na lista de jobs e
gangues e, não achando, devolve o próprio id. A conta passa a se chamar
`fazenda` em vez de "Receita de San Andreas".

Não foi corrigido porque as duas saídas são piores que o sintoma: criar um job de
governo no `qbx_core` é editar core para atender um script (§25), e o export
`changeAccountName` do banco renomeia o **id** da conta, não o rótulo — usá-lo
aqui trocaria o identificador que o resource inteiro referencia.

Hoje isso é invisível: o rótulo só aparece para quem tem autorização na conta, e
ninguém tem. Vira problema no dia em que existir um job de fiscal com acesso.

---

## API

Todos os exports são server-side.

| export | devolve |
|---|---|
| `IsReady()` | boolean |
| `CurrentPeriodKey()` | chave do período corrente |
| `PeriodBounds(periodKey)` | início e fim (unix) |
| `RecordIncome(payload)` | `ok, errorCode` |
| `GetTaxableBase(citizenId, periodKey?)` | base tributável, isenta, saídas, contagem |
| `GetStatement(citizenId, limit?, periodKey?)` | extrato do ledger |
| `GetAssessment(citizenId, periodKey?)` | apuração de um período |
| `GetOutstanding(citizenId)` | total devido e vencido |
| `ClosePeriod(periodKey?)` | fecha e apura |
| `SettleTax(source, amount?)` | quita debitando do banco |
| `GetTreasuryBalance()` | saldo da Receita |

### `RecordIncome`

```lua
exports.noir_fazenda:RecordIncome({
    subjectId = citizenId,
    amount = 2500,
    category = 'salario',
    counterparty = 'Prefeitura',
    eventId = ('folha:%s:%s'):format(citizenId, periodo), -- idempotência
})
```

**Forneça `eventId` sempre que houver um id estável da operação.** É ele que
impede que um retry vire base de imposto em dobro. Sem ele, o id é derivado do
conteúdo e do segundo corrente — protege contra replay imediato e nada mais.

---

## Comandos

ACE `noir.fazenda.admin` (console sempre pode).

```
/fazenda status              -- saúde, contagens, saldo da Receita, flags
/fazenda periodo             -- período corrente, janela e anterior
/fazenda extrato <citizenid> -- base do período e quanto daria de imposto hoje
/fazenda devendo <citizenid> -- apurações em aberto
/fazenda apurar [periodo]    -- fecha o período (simulado enquanto a cobrança está off)
```

---

## Schema

`migrations/001_initial.sql`, tabelas `noir_fazenda_*`. Nenhuma query do resource
toca tabela de outro resource — há teste que verifica isso.

- **`noir_fazenda_ledger`** — um movimento por linha. `event_id` único garante
  idempotência: as duas pernas de uma transferência têm ids distintos porque o id
  inclui sujeito e direção, senão a segunda perna seria descartada como duplicata
  e quem recebeu nunca seria tributado.
- **`noir_fazenda_assessments`** — uma linha por (cidadão, período). Reapurar
  recalcula base e imposto mas **nunca** mexe em `paid` nem ressuscita apuração
  quitada.
- **`noir_fazenda_payments`** — histórico de pagamento.

`occurred_at` é gravado com offset UTC explícito em vez de `FROM_UNIXTIME`, que
converteria usando o fuso da sessão MySQL e faria a mesma linha gravar hora
diferente conforme a configuração do banco.

---

## Testes

```bash
cd resources/[bgrz]/noir_fazenda
lua5.4 tests/unit/rules_spec.lua
lua5.4 tests/unit/manifest_spec.lua
lua5.4 tests/integration/feed_spec.lua
```

- **`rules_spec`** — calendário fiscal, classificação e cálculo progressivo.
- **`manifest_spec`** — regras de arquitetura: arquivo órfão fora do manifest,
  SQL fora do storage, tabela de outro resource, nome de provider no código, e a
  garantia de que a cobrança nasce desligada.
- **`feed_spec`** — a corrente inteira com o runtime do CFX stubado, do evento do
  banco até os parâmetros que chegam ao `INSERT`. É o teste que importa: os dois
  resources conversam por evento, e cada lado pode estar certo sozinho sem a ponta
  encaixar.
