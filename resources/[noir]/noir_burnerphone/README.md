# noir_burnerphone

Burner phone touchscreen com interface Metro para atividades ilegais. O item
`burner_phone` registrado no `ox_inventory` abre a NUI pelo export
`noir_burnerphone.useDevice`.

## Autoridade e posse

A abertura e cada atividade são autorizadas pelo servidor. O jogador precisa
ter ao menos um `burner_phone` no próprio inventário no momento da validação.
Atividades disponíveis são definidas exclusivamente em `server/config.lua`.

## Estado por personagem

Contatos e mensagens são armazenados na metadata `noirBurnerPhone` do Qbox.
Portanto, o estado pertence ao `citizenid`, e não ao slot ou à metadata do item:

- duas unidades usadas pelo mesmo personagem exibem o mesmo estado;
- ao transferir o item, o novo portador vê o estado do próprio personagem;
- trocar de personagem carrega outro estado.

Recursos server-side podem consultar e substituir o estado pelos exports
`getPlayerState(source)` e `setPlayerState(source, state)`. As listas são
normalizadas e limitadas antes de persistir.

## Contratos

A tela **Contratos** lista contratos ativos e disponíveis fornecidos por outros
resources ("providers"), configurados em `server/config.lua` → `contracts`.
Cada provider expõe quatro exports server-side:

| Export (nome configurável) | Assinatura                   | Retorno                               |
| -------------------------- | ---------------------------- | ------------------------------------- |
| `list`                     | `(source)`                   | `{ active = {...}, available = {...} }` |
| `accept`                   | `(source, offerId)`          | `ok, reason`                          |
| `resume`                   | `(source, contractId)`       | `ok, reason`                          |
| `abandon`                  | `(source, contractId)`       | `ok, reason`                          |

Formato dos itens: `active = { id, label, status, canResume, canAbandon }` e
`available = { id, label, tier, difficulty }`. Os ids são opacos; este resource
os prefixa com o índice do provider antes de enviá-los à NUI e remove o prefixo
ao devolver a ação. Coordenadas, recompensas e regras de elegibilidade nunca
chegam ao JavaScript.

Fluxo: NUI → callbacks `loadContracts`, `acceptContract`, `resumeContract`,
`abandonContract` (client) → `noir_burnerphone:server:getContracts` /
`noir_burnerphone:server:contractAction` (server: posse do item + cooldown) →
export do provider. Toda resposta de sucesso devolve um snapshot novo. Providers
devem chamar `exports.noir_burnerphone:refreshContracts(source)` após qualquer
mudança de contrato para que um aparelho aberto atualize só as listas.

O provider atual é `noir_houserobbery` (`GetBurnerContracts`,
`AcceptBurnerContract`, `ResumeBurnerContract`, `AbandonBurnerContract`). A
lógica de invasão residencial em si não faz parte deste resource.
