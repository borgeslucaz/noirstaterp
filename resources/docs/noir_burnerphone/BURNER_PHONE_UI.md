# noir_burnerphone — UI atual

`noir_burnerphone` tem uma NUI própria; usar o item `burner_phone` não abre o
`sd-phone`. A integração com ele permanece desativada por padrão em
`BurnerPhoneConfig.phoneIntegration.enabled`.

## Aparência e abertura

A interface representa um celular touchscreen antigo, com corpo plástico
grafite, bordas grossas, alto-falante superior e tela escura. Ela aparece no
canto inferior direito (`right: 4vw`, `bottom: 4vh`), com 286 px de largura,
e entra/sai verticalmente em 260/220 ms. Enquanto fechada, a NUI não é exibida
nem recebe cliques.

A tela usa fundo `#090909`, barra mínima com ícones de sinal e bateria, fonte
`Segoe UI`/Inter e tiles Metro. Não há teclado físico, botões de navegação,
marca, título de sistema, "Início" ou "Burner OS".

## Tela inicial

A primeira tela apresenta, nesta ordem, cinco tiles grandes e inteiramente
clicáveis:

1. Telefone
2. Contatos
3. Mensagens
4. Atividades Ilegais
5. Fechar

Os tiles têm bloco de ícone azul `#1f4f82`, fundo escuro e feedback de
hover/pressão. O tile **Fechar** usa ícone cinza e chama o callback NUI
`close`; não existe botão X separado.

## Navegação e conteúdo

As páginas são alternadas localmente pelo frontend, com links de retorno no
formato `‹ seção`.

| Seção | Comportamento atual |
| --- | --- |
| Telefone | Exibe `Chamadas não configuradas.` Não há chamadas integradas. |
| Contatos | Mostra o contato de invasões; nome e número vêm de `houseRobberyContact` na abertura da NUI. |
| Mensagens | Abre a conversa do canal de trabalho. O rótulo visual atual é `Ninguém` / `Canal de trabalho`. |
| Atividades Ilegais | Disponibiliza `Venda na rua` e `Invasões`. |
| Venda na rua | Exibe um botão para iniciar a venda. Ao acioná-lo, a NUI é fechada e o client executa `/venderdrogas` através de `op-drugselling`, se esse resource estiver iniciado. |
| Invasões | Abre a mesma conversa do contato de invasões. |

O menu de venda na rua é renderizado atualmente independentemente de
`BurnerPhoneConfig.activities.drugSales`; essa chave não é consultada pelo
frontend nem pelo callback client atual.

## Conversa de invasões

O campo de mensagem aceita até 120 caracteres. O placeholder recebe
`houseRobberyContact.requestText`, cujo padrão é `Preciso de trabalho.`.
O servidor só encaminha um pedido quando o texto, após remover espaços nas
extremidades e ignorar maiúsculas/minúsculas, coincide exatamente com esse
valor. Qualquer outro conteúdo recebe uma resposta do contato explicando a
frase esperada.

Com contratos habilitados (`activities.contracts = true`) e
`noir_houserobbery` iniciado, o pedido é encaminhado pelo export server-side
`exports.noir_houserobbery:RequestHouseContract(source)`. Respostas recebidas
por `noir_burnerphone:client:contactMessage` são adicionadas à conversa. Se
incluírem localização, o client define automaticamente o waypoint e também
disponibiliza o botão `ABRIR GPS` na mensagem.

Atividades podem responder pelo export server-side:

~~~lua
exports.noir_burnerphone:sendContactMessage(source, message, location)
~~~

`location` deve conter ao menos `x` e `y`; `z` e `label` são preservados na
mensagem. O texto enviado pelo export é limitado a 240 caracteres.

## Comunicação NUI preservada

O client envia as seguintes ações para a interface:

| Ação | Dados |
| --- | --- |
| `burner:open` | Histórico local de mensagens, contato de invasões e estado de contratos. Sempre abre na tela inicial. |
| `burner:message` | Nova mensagem do contato. |
| `burner:close` | Solicita o fechamento visual da interface. |

Os callbacks NUI ativos são `ready`, `close`, `typing`, `startStreetSale`,
`sendHouseMessage` e `setWaypoint`. O frontend também fecha com `Escape`.

## Estado e restrições de uso

Ao abrir, o recurso adquire foco NUI, toca a animação de celular e emite
`noir_burnerphone:client:openState` com `true`; ao fechar, libera o foco,
interrompe a animação e emite o mesmo evento com `false`.

O aparelho não abre se estiver desativado, se o jogador estiver morto ou
nadando (configurável), nem enquanto o `sd-phone` reportar indisponibilidade.
Se o `sd-phone` abrir, se o jogador morrer/nadar, se o pause menu for ativado,
no logout ou na parada do resource, o burner phone é fechado. Com
`allowMovement = true`, o jogador pode se mover enquanto navega, mas os
controles de combate são bloqueados; ao digitar, os controles de movimento e
interação também são bloqueados.
