# Interface do banco — Noir State

Substitui o NUI Svelte que vinha no Renewed-Banking, sem alterar **uma linha de Lua** do
resource. O `fxmanifest.lua` está intocado: ele já serve `web/public/**/*`, e é para lá que o
build escreve.

## Por que não é um fork do Renewed

O contrato de NUI dele é pequeno o bastante para a interface se encaixar por fora:

| Direção | Mensagem | Uso aqui |
|---|---|---|
| Lua → NUI | `setLoading {status}` | estado de carregando |
| Lua → NUI | `setVisible {status, accounts, atm}` | abre a tela; **as contas vêm juntas** |
| Lua → NUI | `notify {status}` | aviso na tela |
| NUI → Lua | `closeInterface` | fechar |
| NUI → Lua | `deposit` / `withdraw` / `transfer` | operação; **devolve as contas atualizadas** |

Esse retorno é o que dispensa recarregar depois de cada operação.

Criar, renomear e compartilhar conta são menus do ox_lib no ped do banco, do lado do Renewed.
Não passam pelo NUI e por isso não aparecem aqui.

## Duas telas, um backend

O `setVisible` traz `atm`, que diz se a tela foi aberta num caixa eletrônico ou no ped da agência.
O servidor não sabe da diferença -- é enquadramento, não permissão.

| | Agência (`atm: false`) | Caixa (`atm: true`) |
|---|---|---|
| Shell | janela cheia, rail à esquerda | janela estreita, sem rail |
| Destinos | Contas, Transações, Estatísticas | nenhum: tudo numa tela |
| Contas | tiras roláveis por categoria | chips de troca |
| Extrato | completo, com busca e filtro | os três últimos lançamentos |
| Operações | as mesmas três | as mesmas três |

Extrato completo e estatísticas ficam na agência, que é onde faz sentido sentar e olhar.

A janela do caixa tem **altura fixa** (`min(560px, calc(100dvh - 48px))`). Sem isso ela pulsava ao
trocar de conta: a lista de lançamentos muda de tamanho conforme a conta tem movimento ou não, e o
painel acompanhava. Os blocos de cima são `shrink-0` e a lista absorve a sobra, rolando se
precisar. São três lançamentos porque é o que cabe inteiro -- com quatro, a última linha aparecia
cortada pela metade na borda, o que num caixa lê como tela quebrada.

## Esc

Fecha o banco, chamando `closeInterface`. Com um modal de operação aberto, fecha só o modal.

A camada é feita pela fase do evento, não por estado compartilhado: o `ActionModal` escuta na
fase de **captura** e chama `stopPropagation`; o shell escuta na fase de **bolha**, que só é
alcançada quando ninguém interrompeu antes. Verificado nos dois modos.

## Formato dos dados

`getBankData` devolve uma lista chata de contas — a pessoal, as de job e gang em que o
personagem tem `bankAuth`, e as compartilhadas — todas no mesmo formato. É o que permite a tira
de contas desenhar as três categorias sem tratamento especial.

A conta pessoal é a única que traz `cash`; `src/types.ts` usa isso para distingui-la.

`transaction.time` vem em **segundos**, não milissegundos.

## Build

```bash
cd web && npm install && npm run build
```

Sai em `web/public/`, sobrescrevendo o que estava lá. O `public/` versionado já está gerado;
sem mexer em `web/src`, não é preciso rodar nada.

### Duas armadilhas do build

**`publicDir: false`** é obrigatório. O Vite dá significado especial à pasta `public`, e como ela
é o nosso `outDir`, sem isso ele tentaria copiá-la para dentro de si mesma. As fontes moram em
`src/fonts` por causa disso e saem como assets normais.

**`@source not "../public"`** no `index.css`: o Tailwind 4 detecta as fontes de conteúdo sozinho
e varreria o build anterior. Uma classe removida do código continuaria no CSS, seria relida e
regenerada para sempre — o `emptyOutDir` não protege, porque limpa depois da varredura.

## Design

Segue o `resources/docs/DESIGN_v3.md`: tokens centralizados, Poppins empacotada (sem CDN), raiz
transparente, sem `backdrop-filter`, barra de rolagem pelos pseudo-elementos, rail com a cor do
serviço e branco como única ação primária.

Idioma: pt-BR, embutido em `src/locale-pt.json`. Uma língua, dentro do bundle, sem busca em
runtime.
