# Alterações locais no Renewed-Banking

Upstream: Renewed-Banking 2.1.4. Ao atualizar o resource, reaplicar o que está aqui.

## 1. Interface substituída (`web/`)

O NUI Svelte deu lugar a uma aplicação React seguindo o `DESIGN_v3.md`. **Nenhuma linha de Lua
foi alterada por causa disso** e o `fxmanifest.lua` está intocado: ele já serve
`web/public/**/*`, e é para lá que o build escreve.

Detalhes do port, contrato de NUI e armadilhas de build estão em `web/README.md`.

## 2. `client/framework.lua` — restart deixava o banco sem ped

O upstream registra a inicialização assim:

```lua
AddEventHandler('onResourceStart', function(resourceName)   -- evento de SERVIDOR
```

**`onResourceStart` é server-side e nunca dispara num script de client.** O evento de client é
`onClientResourceStart`. Consequência: `initalizeBanking()` só rodava pelo caminho do
`QBCore:Client:OnPlayerLoaded` -- e num restart, com o jogador já logado, esse evento não se
repete. Sem `initalizeBanking`, sem `CreatePeds`, sem ped.

Confirmado em jogo por um comando de diagnóstico: `FullyLoaded=true`, jogador a 1 metro do banco,
`pontos de ped ativos: 0`. Ou seja, a condição estava satisfeita e a função simplesmente não era
chamada.

Os dois eventos ficam registrados agora. Chamar duas vezes é inofensivo: `CreatePeds` guarda com
`pedSpawned`. A espera com teto pelo state bag ficou junto -- num restart ele pode ainda não ter
replicado.

> **Correção de rumo.** Uma versão anterior deste documento atribuía o bug a `FullyLoaded` ser
> lido uma vez no carregamento e ficar preso em falso. Isso era uma hipótese minha, não o que
> acontecia: o diagnóstico mostrou `FullyLoaded=true`. A causa é o nome do evento.

O mesmo engano existe em outros resources deste servidor -- `ps_lib/bridge/framework/qbx/client.lua`
e `mm_radio/client/event.lua` também usam `onResourceStart` em client. Eles não quebram porque
têm um caminho de login que cobre o caso.

## 3. `server/main.lua` — guard da UI apontava para o bundle Svelte

O resource valida no start se a interface foi compilada. O guard original procurava
`web/public/build/bundle.js`, o artefato do NUI Svelte de fábrica:

```lua
if not LoadResourceFile("Renewed-Banking", 'web/public/build/bundle.js') ... then
    error(locale("ui_not_built"))
    return StopResource("Renewed-Banking")
```

A interface daqui não gera esse arquivo, então o resource **se auto-parava no start** com
"Unable to load UI".

A intenção do guard continua valendo e é ela que reproduzimos: o `index.html` publicado só
referencia `assets/` depois que o build rodou. Verificado nos dois sentidos -- passa com a UI
compilada, bloqueia sem ela. A trava de renomear o resource ficou intacta.

## 4. `locales/pt-br.json` (arquivo novo)

O servidor define `setr ox:locale "pt-br"` (em `ox.cfg`) e o Renewed só trazia `pt.json`, então
o lado Lua dele caía em inglês -- era o aviso `could not load 'locales/pt-br.json'` no console.
Cópia de `pt.json`, que é a convenção que os resources `noir_*` e `ox_*` já seguem aqui.

Isso afeta as mensagens do servidor e os rótulos dos menus do ox_lib no ped. O NUI não depende
disso: o idioma dele é embutido no bundle.

## 5. `/bancodiag` (comando novo, `client/framework.lua`)

Despeja no console (F8) o estado ao vivo do banco: `isLoggedIn`, `FullyLoaded`, quantos pontos de
ped existem, quantos peds estão criados agora, o estado do `ox_target` e a distância até a agência
mais próxima.

Ficou permanente. Foi ele que localizou o evento errado do item 2 -- `FullyLoaded=true` e
`pontos de ped ativos: 0` mostraram, em uma linha, que a condição estava satisfeita e a função
simplesmente não era chamada. Custa nada estar disponível.

## 6. `server/main.lua` — feed de movimentação para a Receita

`handleTransaction` é o ponto único por onde passa todo movimento de conta neste resource.
Uma linha lá dá alimentação completa e em tempo real para quem precisar — hoje o
`noir_fazenda`, que precisa somar movimentação por pessoa e período e não consegue fazer isso
lendo o extrato nativo (blob JSON por conta, sem índice, reescrito inteiro a cada transação).

```lua
if accountKind then
    TriggerEvent('Renewed-Banking:noir:transaction', account, accountKind, transaction, transID)
end
```

Junto veio um `local accountKind` marcado nos dois ramos do `if` que já existia: o upstream
sabia a diferença entre conta de organização e conta pessoal e descartava a informação.

Três coisas deliberadas nessa linha:

**Não há regra de negócio nela.** Classificar o que é renda é problema de quem consome. Esta
linha só relata o que aconteceu. Cada linha de política aqui dentro seria dívida de manutenção
num arquivo de terceiro.

**O `transID` cru vai junto.** É o argumento original, não o do objeto `transaction`, e é a
única forma de distinguir "recebi um pagamento" de "depositei meu próprio dinheiro". As duas
coisas chegam aqui como `trans_type = 'deposit'`; o que as separa é que transferência gera duas
chamadas e a segunda recebe o id da primeira. Sem isso, a Receita cobraria imposto de alguém
por usar o banco.

**Evento local, não networked.** `TriggerEvent`, não `TriggerClientEvent`. Nada disso vira
tráfego de rede.

Quem escuta não é o `noir_fazenda` direto: é o `bgrz_core` (`server/banking.lua`), que traduz
para um payload neutro e reemite como `bgrz_core:bankMovement`. O consumidor não conhece o nome
deste resource — o que importa porque este servidor já trocou de banco duas vezes.

Verificado com o runtime do CFX stubado, do evento até os parâmetros do `INSERT`:
`resources/[bgrz]/noir_fazenda/tests/integration/feed_spec.lua`.

## 7. `server/main.lua` — aviso de que as contas terminaram de carregar

```lua
TriggerEvent('Renewed-Banking:noir:ready')
```

Última linha da thread de startup, depois de `MySQL.transaction.await(query)`.

`cachedAccounts` só existe depois dessa thread, e o evento `Started resource Renewed-Banking`
é publicado bem antes — antes do `Wait(500)` do começo dela e antes da query de contas voltar.
Quem chamasse `CreateJobAccount` nessa janela não encontrava a conta no cache, tentava o
`INSERT` e batia em `Duplicate entry`. Pior: `MySQL.insert` ali é sem `await`, então `success`
volta `nil` e o próprio Renewed levanta `error("Database error: nil")`, derrubando a chamada
de quem pediu.

Foi exatamente isso que aconteceu com o `noir_fazenda` ao criar a conta da Receita.

A alternativa era o consumidor ficar em retry até o cache aparecer. Um evento no fim da carga
é determinístico, não precisa de laço e não tem janela para adivinhar.

Quem consome é o `bgrz_core`, que marca prontidão e reemite como `bgrz_core:bankingReady` —
e derruba a flag no `onResourceStop` do banco, porque o cache morre junto com o resource.

Regressão coberta em `resources/[bgrz]/noir_fazenda/tests/integration/feed_spec.lua`, com um
banco falso que reproduz a janela: criação antes da carga é recusada, criação depois do aviso
reusa a conta existente em vez de duplicar.

## 8. `server/framework.lua` — gang saiu do Qbox

`PlayerData.gang` não é mais mantido por ninguém: a membresia e os cargos de gang passaram a
ser do `noir_gangs`, e o Qbox deixou de ter gang. Três funções liam de lá e todas devolveriam
`none` para todo mundo — na prática, **ninguém acessaria a conta da gang**.

| função | lia | agora |
|---|---|---|
| `GetGang` | `Player.PlayerData.gang.name` | `bgrz_core:GetGang(source)` |
| `IsGangAuth` | `Gangs[gang].grades[level].bankAuth` | o `bankAuth` que o bridge já devolve resolvido |
| `GetSocietyLabel` / `GetFrameworkGroups` | `exports.qbx_core:GetGangs()` | `exports.noir_gangs:GetGangList()` |

As duas últimas importam por um motivo que não é óbvio: `GetFrameworkGroups` é o que este
resource percorre no start para **criar as contas**. Sem a lista de gangs vindo do lugar
certo, gang nova nunca ganharia conta, e as existentes perderiam o rótulo (viraria o id).

O acesso vai pelo `bgrz_core` e não pelo `noir_gangs` direto onde dá, porque é o bridge que
sabe qual resource é o provider de gangs — igual ao que já é feito com inventário e target.

A ordem de start já favorece: `[bgrz]` é ensured antes de `[standalone]`.
