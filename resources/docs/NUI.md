# Interfaces NUI próprias — estado atual

## Escopo

A principal NUI própria da base é a interface React de `resources/[bgrz]/noir_multichar/ui`. O `noir_chat` usa outro frontend CFX compilado/adaptado e não compartilha componentes com o multicharacter. Não existe uma NUI `bgrz_identity` separada.

A aparência do personagem não é implementada pelo multicharacter: após a criação, o fluxo é entregue ao `illenium-appearance` pelo evento compatível `qb-clothes:client:CreateFirstCharacter`.

## Stack

- React 18 e React DOM;
- Redux Toolkit e React Redux;
- Vite 5;
- Tailwind CSS;
- React Router;
- styled-components, react-datepicker e carousel permanecem nas dependências, embora o formulário Noir atual use componentes próprios.

`main.jsx` monta Redux, `BrowserRouter` e `ConfigProvider`. `App.jsx` mantém a visibilidade geral e o estado de tela fica no slice Redux `screen`.

## Desenvolvimento e build

Na pasta `resources/[bgrz]/noir_multichar/ui`:

```bash
npm run dev
npm run lint
npm run build
npm run preview
```

`npm run dev` inicia o Vite em `0.0.0.0` (porta padrão `5173`). Fora do FiveM e somente em modo Vite DEV, `utils/browserDevelopment.js` ativa automaticamente o modo navegador:

- exibe a seleção;
- fornece personagens locais de exemplo;
- simula callbacks NUI sem fazer POST para o CEF;
- abre o formulário ao escolher um slot vazio.

Em produção, `import.meta.env.DEV` é falso e os mocks não são usados. O build usa base `/ui/dist/` e gera os arquivos referenciados pelo `fxmanifest.lua`. Alterar `ui/src` sem executar `npm run build` não altera a NUI carregada pelo FiveM.

## Transparência e composição

`html`, `body` e `#root` têm fundo transparente. O espaço vazio visto no navegador representa a câmera GTA/FiveM em jogo.

A seleção e a criação são overlays cinematográficos. A seleção usa gradientes em `charDetails.css` e a criação usa a vignette lateral de `registration.css`; nenhuma delas fornece uma imagem de fundo para a cena real.

## Comunicação

As mensagens Lua → NUI usam:

```js
{ action: "nome", data: valor }
```

`utils/nuicallback.js` envia NUI → Lua por POST JSON para:

```js
https://${window.GetParentResourceName()}/${eventName}
```

A função espera resposta JSON. No modo navegador, ela desvia para `browserNuiCallback` em vez de usar um resource fictício.

### Mensagens Lua → NUI ativas

| `action` | `data` | Uso |
|---|---|---|
| `visible` | boolean | mostra ou oculta o fluxo principal |
| `characterselection` | array de slots | atualiza a lista após operações como exclusão |
| `charactercreator` | número do slot | abre o formulário de criação |
| `loadingscreen` | boolean | controla a tela de loading |
| `adminpanel` | array de personagens | abre o painel administrativo |
| `profilepicture` | array de perfis | abre o editor de foto |

### Callbacks NUI → Lua ativos

| Callback | Finalidade |
|---|---|
| `GetCharacters` | retorna os slots/personagens disponíveis |
| `PreviewCharacter` | troca o ped de pré-visualização |
| `playcharacter` | entra com personagem ou inicia criação de slot vazio |
| `CreateCharacter` | valida e cria o personagem |
| `exitcharactercreator` | sai do formulário de criação |
| `DeleteCharacter` | exclui o personagem selecionado |
| `getConfig` | retorna cenas, idioma e limites de data |
| `getcurrentscene` / `UpdateScene` | consulta ou altera a cena da seleção |
| `hover` / `click` / `SOUND2` | reproduz sons frontend do GTA |
| `GetAllCharacters` / `GetSlots` / `updateslot` | painel administrativo |
| `saveprofilepicture` | salva URL de foto em KVP local |
| `exit` | fecha painéis auxiliares |

Callbacks comentados no Lua não fazem parte do contrato ativo.

## Estados de tela

| Estado Redux | Tela |
|---|---|
| `characterselection` | seleção de personagens |
| `charactercreator` | criação de personagem |
| `settings` | seletor de cenas |
| `deleteconfirm` | confirmação de exclusão |
| string vazia | nenhuma dessas telas |

Loading, painel administrativo e editor de foto mantêm visibilidade própria baseada em mensagens.

## Seleção de personagens

`CharDetails` chama `GetCharacters` ao entrar em `characterselection`. A interface mostra marca, slot, nome, dinheiro, emprego, última localização e cards de slots ocupados/vazios.

- clique em outro card: `PreviewCharacter`;
- setas esquerda/direita: navegação entre cards;
- Enter ou botão principal: `playcharacter`;
- configurações: estado `settings`;
- exclusão: estado `deleteconfirm` e depois `DeleteCharacter`.

Os ícones principais são SVG inline. Valores textuais são apresentados em maiúsculas e dinheiro é formatado no frontend.

## Criação de personagem

`Register` abre ao receber `charactercreator` e mantém o slot recebido no payload. O formulário atual envia exatamente:

```js
{
  slot,
  firstName,
  lastName,
  DOB,
  nationality,
  gender
}
```

Não existe mais campo de altura na NUI.

Os labels visuais estão em inglês: `FIRST NAME`, `LAST NAME`, `DATE OF BIRTH`, `NATIONALITY` e `GENDER`. Os valores de gênero continuam sendo `Male` e `Female`, conforme esperado pelos adapters Lua.

A data é exibida como `MM / DD / YYYY`, mas mantém o formato de backend já existente:

```text
YYYY/D/M
```

O seletor de data e o dropdown de nacionalidade:

- abrem preferencialmente à esquerda do campo;
- usam posicionamento relativo ao próprio campo;
- caem para baixo quando não há espaço horizontal suficiente;
- reavaliam a posição ao redimensionar a viewport;
- são mutuamente exclusivos;
- fecham ao clicar fora;
- não deslocam os outros campos.

Com um popup aberto, a tecla Escape fecha o popup. Sem popup aberto, Escape chama `exitcharactercreator`. O botão visual `ESC / BACK` chama diretamente a saída existente.

`CreateCharacter` só remove a tela React quando o Lua responde `true`. Validação e criação permanecem no Lua/framework.

## Aparência e routing bucket

O editor visual de aparência pertence ao `illenium-appearance`, não à NUI React. No fluxo Qbox, o multicharacter aguarda `QBX.PlayerData.charinfo`, dispara os eventos de player loaded e então chama `qb-clothes:client:CreateFirstCharacter`.

Durante seleção/criação, o jogador permanece no bucket privado atribuído ao entrar no multicharacter. O fluxo não retorna prematuramente ao bucket público `0` antes de abrir a aparência. O `illenium-appearance` usa um bucket individual durante a customização e retorna ao bucket `0` ao finalizar ou cancelar.

## Cenas

`SceneSelector` chama `getcurrentscene`, lê `Config.Scenes` e envia `UpdateScene`. As imagens ficam em `ui/images` e seguem `../images/ID.png`. Escape retorna à seleção.

## Exclusão e loading

`DeleteConfirm` envia `DeleteCharacter`; o Lua exclui e envia uma lista atualizada via `characterselection`. A opção não aparece em slot vazio.

`LoadingScreen` reage a `loadingscreen`. `modules/loadresource.lua` encerra as telas de loading do CFX antes de abrir a seleção.

## Fotos

`Profiles` recebe `profilepicture`, lista slots ocupados, aceita uma URL, mostra preview e chama `saveprofilepicture`. O Lua grava a URL em KVP local por slot. Não existe upload, validação de domínio ou armazenamento remoto.

## Painel administrativo

`AdminPanel` recebe personagens, filtra por primeiro nome, consulta slots com `GetSlots` e altera com `updateslot`. A permissão é validada ao abrir e novamente no servidor.

## Sons e assets

Hover e clique chamam callbacks Lua para sons frontend nativos do GTA. O manifest inclui HTML, CSS, JS, PNG, GIF, fontes, SVG e `ui/images`. Cada cena depende de uma imagem cujo nome corresponda ao ID configurado.

## NUI do chat

`noir_chat` usa `dist/ui.html`, `index.css` e `chat.js`. Ele possui mensagens, sugestões, templates, temas, histórico e visibilidade próprios; não compartilha o React do multicharacter.

## Limites de escopo

Não há adapter visual de aparência próprio no multicharacter. Genética, rosto, cabelo, overlays, roupas e salvamento de skin continuam sob responsabilidade do `illenium-appearance`.

Veja também `MULTICHAR.md`, `IDENTITY.MD`, `CHAT.md` e `GENERAL.MD`.
