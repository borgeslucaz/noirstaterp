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

- verde: localização/se necessario esse icone marca no mapa a localizaçao (exemplo script de houserobbery);
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

~~js
{
  active: [{ id, label, status, canResume, canAbandon }],
  available: [{ id, label, tier, difficulty }]
}
~~

Os IDs são opacos e devem voltar sem transformação nos callbacks NUI. As ações
previstas são `loadContracts`, `acceptContract`, `resumeContract` e
`abandonContract`; os nomes finais devem ser definidos junto ao client Lua e
documentados ao implementá-los.

### Implementação (nomes finais)

Implementado em 2026-09-03. Nomes definitivos:

**NUI → client (`noir_burnerphone/client/main.lua`)**

| Callback          | Payload    | Resposta                                  |
| ----------------- | ---------- | ----------------------------------------- |
| `loadContracts`   | —          | `{ ok, contracts }`                       |
| `acceptContract`  | `{ id }`   | `{ ok, contracts }` ou `{ ok=false, error }` |
| `resumeContract`  | `{ id }`   | idem                                      |
| `abandonContract` | `{ id }`   | idem                                      |

**client → NUI**: `burner:open` já inclui `contracts`; `burner:contracts`
substitui as listas sem fechar o aparelho nem trocar de página.

**client → server (`noir_burnerphone/server/main.lua`)**:
`noir_burnerphone:server:getContracts` e
`noir_burnerphone:server:contractAction(action, id)` com `action` em
`accept | resume | abandon`. O server valida posse do `burner_phone`, aplica um
cooldown curto por jogador e delega ao provider configurado em
`server/config.lua` → `contracts.providers`.

**Provider `noir_houserobbery`** (exports server-side):
`GetBurnerContracts(source)`, `AcceptBurnerContract(source, offerId)`,
`ResumeBurnerContract(source, contractId)`, `AbandonBurnerContract(source,
contractId)`. As ofertas são por tier (`house:tier:N` → "Roubo a casa
simples/média/grande"); a casa concreta só é sorteada ao aceitar, como no fluxo
por mensagem. `Resume` dispara `noir_houserobbery:client:contractRoute`, que
remarca blip e waypoint. Após atribuir ou encerrar um contrato o houserobbery
chama `exports.noir_burnerphone:refreshContracts(source)`.

O fluxo legado `RequestHouseContract(source)` (mensagem do burner) continua
funcionando e não foi removido.

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
