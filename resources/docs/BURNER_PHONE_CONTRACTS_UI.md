# Burner phone — tela de contratos

Implementar a seção **Contratos** no `noir_burnerphone`, seguindo a referência
visual fornecida. Este documento descreve a nova UI; não altera o contrato de
integração já existente entre `noir_burnerphone` e `noir_houserobbery`.

## Escopo visual

Manter o mesmo aparelho, posição, barra de status, tipografia e paleta da UI
atual. A tela é escura (`#090909`), plana e no estilo Metro; não usar cards
modernos, gradientes, modais ou barras de navegação de Android/iOS.

Na home, substituir o tile **Telefone** por **Contratos**, como primeiro item.
Ele usa um ícone simples de contrato/trabalho em azul `#1f4f82`. Os demais
tiles mantêm a ordem atual:

1. Contratos
2. Contatos
3. Mensagens
4. Atividades Ilegais
5. Fechar

O tile deve abrir a página `contracts`. A página antiga de telefone não deve
ser exibida pela home; não é necessário removê-la nesta etapa.

## Página de contratos

A página não possui cabeçalho de aplicativo, título decorativo ou botão X. O
conteúdo começa próximo ao topo da tela e tem duas seções, nesta ordem:

1. **Contratos ativos**
2. **Contratos disponíveis**

Cada título é clicável e controla apenas a expansão da sua própria lista. Use
um pequeno indicador de seta/chevron ao lado do texto para comunicar o estado:

- seção expandida: chevron para baixo;
- seção recolhida: chevron para a direita;
- a área inteira do título deve ser clicável.

Ao abrir o telefone, ambas as seções começam expandidas. Recolher uma delas
não descarta os dados nem altera o estado do contrato no servidor.

### Estado vazio

Sem itens, mostrar imediatamente abaixo do respectivo título, centralizado e
em itálico discreto:

- `Nenhum contrato ativo`
- `Nenhum contrato disponível`

Não mostrar placeholders genéricos, contadores "0" ou ações indisponíveis.

### Item de contrato ativo

Um contrato ativo é uma linha compacta, sem card elevado. Exemplo visual da
referência: `Roubo a casa`.

À direita do item, mostrar duas ações quadradas de tamanho de toque adequado:

- verde: aceitar/iniciar ou retomar a ação do contrato;
- vermelho: abandonar/recusar o contrato.

Os botões devem ter ícones SVG claros (confirmação e X); a cor não pode ser a
única forma de comunicar a ação. Enquanto o servidor responde, desabilitar as
duas ações do item para impedir duplo envio. A ação destrutiva deve pedir uma
confirmação compacta dentro da própria tela antes de ser enviada.

O significado operacional da ação verde depende do status que vier do
servidor. Para um contrato já atribuído, ela deve preferir "ver rota"/"retomar"
em vez de tentar atribuir novamente o mesmo contrato.

### Item de contrato disponível

Um contrato disponível é uma linha textual clicável — por exemplo, `Roubo a
casa simples`. Ao tocar, abrir o detalhe inline da própria página, contendo ao
menos nome, risco/dificuldade quando fornecido e uma ação explícita
**Aceitar contrato**. O item não deve iniciar nem reservar o contrato só por
abrir o detalhe.

Após aceitar com sucesso, remover o item da lista de disponíveis e movê-lo para
ativos. Em uma recusa, erro ou indisponibilidade superveniente, preservar a
lista e mostrar uma mensagem curta de erro na tela.

## Dados e integração

O frontend recebe somente dados já validados pelo client/server. Não expor
coordenadas, recompensas, IDs internos ou regras de elegibilidade na interface
sem necessidade de jogo.

Formato mínimo proposto para renderização:

~~~js
{
  active: [{ id, label, status, canResume, canAbandon }],
  available: [{ id, label, tier, difficulty }]
}
~~~

Os IDs são opacos e devem voltar sem transformação nos callbacks NUI. As ações
previstas são `loadContracts`, `acceptContract`, `resumeContract` e
`abandonContract`; os nomes finais devem ser definidos junto ao client Lua e
documentados ao implementá-los.

### Limite da implementação existente

Hoje `noir_houserobbery` já oferece o callback server-side
`noir_houserobbery:server:getContract`, que retorna o contrato ativo do
jogador ao client, e o export `RequestHouseContract(source)`, acionado pela
mensagem do burner. Ele ainda não fornece uma lista pública de contratos
disponíveis, nem callbacks para aceitar, recusar ou abandonar contratos pela
NUI.

Portanto, a entrega desta tela requer:

1. uma ponte client Lua que busque o contrato ativo e envie um snapshot para a
   NUI;
2. uma API server-side autorizada para listar ofertas e aceitar/abandonar;
3. validação server-side de disponibilidade, cooldown, requisitos, limite de
   jogadores e propriedade antes de qualquer mudança;
4. uma atualização da NUI após toda resposta de sucesso ou evento de mudança
   no contrato.

Não chamar exports de `noir_houserobbery` diretamente do JavaScript e não
manter a NUI como fonte de verdade. Enquanto essa API não existir, a tela deve
renderizar os estados vazios, em vez de simular contratos.

## Comportamento e acessibilidade

- Reutilizar os estilos de interação existentes: hover sutil e pressão com
  `scale(.985)`; evitar animações longas.
- Preservar `Escape`, o tile **Fechar**, o callback `close` e o ciclo atual de
  foco NUI.
- Usar botões semânticos, `aria-label` nos controles de ícone e foco visível
  por teclado.
- Se o contrato for atualizado enquanto o burner estiver aberto, atualizar só
  as listas; não fechar o aparelho nem retornar o jogador à home.
- Não remover o fluxo de conversa de invasões até a nova API de contratos
  substituí-lo explicitamente.
