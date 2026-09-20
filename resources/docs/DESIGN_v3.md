# Guia de design de interfaces v3 — Noir State RP

> Padrão visual para NUIs operacionais, painéis administrativos, cadastros, listas, formulários, modais e ferramentas de configuração. A v3 consolida os fundamentos de `DESIGN.md` e `DESIGN_v2.MD` com a linguagem visual das três referências fornecidas: superfícies grafite, tipografia geométrica, controles compactos, navegação clara e preservação da cena do jogo.

> Revisão aplicada: este documento também incorpora os padrões validados no `noir_taxijob`: rail expansível contextual, logo visível somente no estado aberto, conteúdo separado por aba, resumos com no máximo três itens e rolagem restrita às regiões que realmente crescem. Do `noir_gangs` veio o tratamento da barra de rolagem (6.5).

## 0. Escopo e precedência

A v3 é a referência canônica para interfaces novas. As versões anteriores continuam úteis como histórico, mas, em caso de conflito, prevalece este documento.

Use a v3 em:

- gestão de organizações, membros, cargos e permissões;
- inventários administrativos, lojas, templates e editores;
- tabelas, históricos, formulários e fluxos CRUD;
- modais, confirmações e configurações densas.

Uma tela narrativa, seleção de personagem ou pause menu pode conservar a composição mais aberta da v2. Mesmo nesses casos, deve herdar os tokens, a tipografia, os estados de controle, a acessibilidade e as regras de transparência da v3.

### Como as referências foram interpretadas

As capturas são referências visuais, não especificações de conteúdo. Textos como nomes, datas, rótulos em inglês, contadores de FPS, marca d'água, mensagens do jogo e legendas promocionais não são requisitos da interface.

Padrões aproveitados:

- painel escuro sobre a cena, sem perder o contexto do jogo;
- uma navegação dominante e uma área de trabalho claramente separada;
- títulos fortes e geométricos, corpo discreto e alta legibilidade;
- campos, cartões e linhas com pouco relevo, borda fina e raio pequeno;
- ação primária branca, ação destrutiva semântica e estados neutros grafite;
- modal central compacto com backdrop escuro;
- chips arredondados para filtros ou seleção múltipla;
- densidade maior em ferramentas operacionais do que em telas narrativas.

## 1. O que mudou da v2 para a v3

| Tema | v2 | v3 |
|---|---|---|
| Direção | conteúdo quase sem caixas | superfícies discretas voltam para organizar ferramentas densas |
| Fonte | Plus Jakarta Sans 600 | Poppins variável como família principal; Inter como fallback |
| Unidade | quase tudo em `vh` | escala híbrida com `rem`, `px` e `clamp()`; shell em viewport |
| Layout | elementos flutuantes nas bordas | dois shells oficiais: janela de comando e workspace dividido |
| Navegação | linhas fantasma | rail vertical ou tabs superiores, com seleção por superfície/contraste |
| Primário | botão ghost | botão branco preenchido com texto escuro |
| Cards | régua lateral sem caixa | cards grafite baixos, borda quase invisível e hierarquia interna |
| Formulários | mínimos e abertos | campos compactos em superfície `field`, labels sempre visíveis |
| Cor de marca | quase ausente | acento configurável por serviço; a cor não altera a estrutura |
| Movimento | coreografia narrativa longa | feedback curto em ferramentas; coreografia longa só em telas narrativas |

Mantidos: raiz transparente, ausência de blur fullscreen, uma ação primária por contexto, teclado, foco visível, contraste, `prefers-reduced-motion`, pt-BR e safe zone.

## 2. Direção visual

O Noir v3 é uma interface de comando: escura, precisa, compacta e silenciosa. Ela deve parecer integrada ao jogo, não um site aberto por cima dele.

Princípios:

- **a cena continua presente:** use um shell parcial ou uma janela destacada em vez de cobrir a tela sem necessidade;
- **densidade com ordem:** ferramentas podem exibir muitos dados, desde que títulos, grupos, divisores e alinhamentos tornem a leitura imediata;
- **contraste por camadas:** diferencie canvas, painel, card e campo com pequenos degraus de luminância;
- **branco é a ação mais forte:** o botão primário é claro e raro;
- **o acento identifica o contexto:** a cor do serviço vive principalmente no rail e em pequenos indicadores; posição e geometria permanecem iguais entre resources;
- **forma contida:** raios pequenos em painéis e campos; raio pill somente para chips;
- **sem efeitos de moda:** não use neon, glassmorphism, glow intenso, gradientes coloridos ou sombras volumosas.

## 3. Tipografia

### 3.1 Família canônica

A forma arredondada e geométrica observada nas referências é traduzida por **Poppins**. Hospede a fonte no próprio resource; uma NUI não deve depender do Google Fonts ou de outra CDN. A família pode ser variável ou dividida nos pesos `400`, `500`, `600` e `700`. Quando forem usados arquivos estáticos, declare cada peso explicitamente:

```css
@font-face {
  font-family: "Poppins";
  src: url("./fonts/Poppins-400.woff2") format("woff2");
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: "Poppins";
  src: url("./fonts/Poppins-500.woff2") format("woff2");
  font-weight: 500;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: "Poppins";
  src: url("./fonts/Poppins-600.woff2") format("woff2");
  font-weight: 600;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: "Poppins";
  src: url("./fonts/Poppins-700.woff2") format("woff2");
  font-weight: 700;
  font-style: normal;
  font-display: swap;
}

:root {
  --font-ui: "Poppins", Inter, "Segoe UI", Arial, sans-serif;
}

body {
  font-family: var(--font-ui);
  font-weight: 400;
}
```

Se o resource ainda não tiver Poppins empacotada, use Inter temporariamente. Não simule Poppins com uma fonte display estreita. Anton, Pricedown e fontes temáticas ficam restritas a peças narrativas que justifiquem essa identidade.

### 3.2 Escala e pesos

| Uso | Tamanho recomendado | Peso | Line-height | Tratamento |
|---|---:|---:|---:|---|
| Título promocional/narrativo | `clamp(40px, 4vw, 68px)` | 800 | `1.0` | tracking `-.035em`, opcional |
| Título de página | `24–32px` | 700 | `1.15` | tracking `-.025em` |
| Valor de destaque | `22–30px` | 700 | `1.1` | números tabulares |
| Título de seção/modal | `18–22px` | 600–700 | `1.25` | tracking `-.015em` |
| Título de card/linha | `14–18px` | 600–700 | `1.3` | caixa normal |
| Corpo | `13–15px` | 400 | `1.5` | caixa normal |
| Label de campo | `12–13px` | 600 | `1.35` | caixa normal |
| Eyebrow/grupo | `10–12px` | 600 | `1.3` | caixa alta, tracking `.10em` |
| Metadado | `10–12px` | 400–500 | `1.4` | cor fraca |
| Botão | `12–14px` | 600 | `1` | caixa normal por padrão |

Regras:

- use `font-variant-numeric: tabular-nums` em dinheiro, datas, horários, rankings e contagens;
- títulos não devem ocupar mais de duas linhas;
- não use peso 800 em parágrafos, labels ou listas inteiras;
- caixa alta é reservada a categorias curtas, nunca a mensagens e descrições;
- o texto da interface é pt-BR, mesmo quando a referência visual estiver em inglês.

## 4. Tokens fundamentais

Todos os frontends devem centralizar os valores. O nome do token descreve a função; não use cores literais espalhadas nos componentes.

```css
:root {
  /* Documento e shell */
  --noir-canvas: rgba(7, 7, 8, 0.94);
  --noir-canvas-solid: #080809;
  --noir-sidebar: rgba(10, 10, 11, 0.97);
  --noir-panel: #111113;
  --noir-panel-raised: #171719;
  --noir-card: #141416;
  --noir-card-hover: #1b1b1e;
  --noir-field: #101012;
  --noir-field-hover: #151517;
  --noir-overlay: rgba(0, 0, 0, 0.76);

  /* Texto */
  --noir-text-strong: rgba(255, 255, 255, 0.96);
  --noir-text: rgba(255, 255, 255, 0.76);
  --noir-text-muted: rgba(255, 255, 255, 0.50);
  --noir-text-faint: rgba(255, 255, 255, 0.30);
  --noir-on-light: #111113;

  /* Estrutura */
  --noir-border-soft: rgba(255, 255, 255, 0.055);
  --noir-border: rgba(255, 255, 255, 0.11);
  --noir-border-strong: rgba(255, 255, 255, 0.22);
  --noir-divider: rgba(255, 255, 255, 0.075);
  --noir-scroll-thumb: rgba(255, 255, 255, 0.13);
  --noir-scroll-thumb-hover: rgba(255, 255, 255, 0.28);

  /* Marca e semântica */
  /* Tema do serviço — sobrescrever no resource */
  --noir-accent: #737983;
  --noir-accent-deep: #4c5159;
  --noir-on-accent: #fff;
  --noir-accent-soft: rgba(115, 121, 131, 0.16);
  --noir-success: #39df45;
  --noir-success-soft: rgba(57, 223, 69, 0.16);
  --noir-warning: #d7a84b;
  --noir-danger: #d51a1a;
  --noir-danger-hover: #ef2929;
  --noir-info: #6e9fbd;

  /* Forma */
  --radius-xs: 3px;
  --radius-sm: 5px;
  --radius-md: 7px;
  --radius-pill: 999px;

  /* Elevação */
  --shadow-window: 0 14px 42px rgba(0, 0, 0, 0.48);
  --shadow-modal: 0 20px 60px rgba(0, 0, 0, 0.62);

  /* Movimento */
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-soft: cubic-bezier(0.22, 1, 0.36, 1);
  --duration-fast: 120ms;
  --duration-control: 180ms;
  --duration-panel: 240ms;
}
```

### Tema de serviço configurável

A cor do rail **não é parte fixa da identidade v3**. Ela contextualiza o serviço aberto, enquanto a posição, a largura, o espaçamento e o comportamento do menu permanecem invariáveis. Exemplos: amarelo para táxi, azul para caminhoneiro, vermelho para gangue e uma cor institucional para polícia ou hospital.

Cada resource sobrescreve o conjunto completo, inclusive a cor do conteúdo sobre o acento:

```css
/* Táxi */
[data-service="taxi"] {
  --noir-accent: #e2b714;
  --noir-accent-deep: #9b7600;
  --noir-on-accent: #111113;
  --noir-accent-soft: rgba(226, 183, 20, 0.16);
}

/* Caminhoneiro */
[data-service="trucker"] {
  --noir-accent: #2878d0;
  --noir-accent-deep: #174982;
  --noir-on-accent: #fff;
  --noir-accent-soft: rgba(40, 120, 208, 0.16);
}

/* Gestão de gangue */
[data-service="gang"] {
  --noir-accent: #d20b0b;
  --noir-accent-deep: #920606;
  --noir-on-accent: #fff;
  --noir-accent-soft: rgba(210, 11, 11, 0.16);
}
```

Regras:

- `accent`: rail, navegação ativa e indicador de contexto;
- `danger`: expulsar, apagar, desconectar ou outra consequência negativa;
- `warning`: aviso temporário ou condição que requer atenção;
- cor temática nunca muda o significado de `danger`, `warning`, `success` ou `info`;
- garanta contraste mínimo de `4.5:1` entre `--noir-on-accent` e o rail;
- componentes internos continuam predominantemente neutros; não espalhe a cor do serviço por todos os cards e botões.

Quando o tema for vermelho ou amarelo, texto, ícone, posição e contexto devem continuar distinguindo navegação de perigo ou alerta.

## 5. Escala, dimensões e densidade

Use base de 4px:

```text
4, 8, 12, 16, 20, 24, 32, 40, 48, 64
```

Aplicação:

- `4px`: microgap entre ícone e metadado;
- `8px`: label e campo, controles adjacentes;
- `12px`: conteúdo interno compacto;
- `16px`: padding padrão de cards e grupos;
- `20–24px`: padding de painel;
- `32px`: separação de seções;
- `40–64px`: margem externa de shells.

A v3 abandona a regra de “tudo em `vh`”. Use:

- `rem` ou `px` para tipografia, controles, bordas e ícones;
- `clamp()` para margens e dimensões que devem respirar;
- `%`, `dvw` e `dvh` para o shell e as regiões principais;
- `minmax()` para grades;
- nunca apenas `vw` para texto ou alvos interativos.

Alvos interativos devem ter pelo menos `40px` em ferramentas de desktop e `44px` quando forem isolados. Ícones podem ter `16–20px`, mas sua área clicável permanece maior.

## 6. Arquitetura de layout

A v3 possui dois shells oficiais. Escolha um por tela; não misture os dois.

### 6.1 Janela de comando

Indicada para gestão de gangues, empresas, permissões, membros e históricos. É uma janela grande centralizada, cercada pela cena.

```text
┌──────────────────────────────────────────── cena ─┐
│                                                   │
│      ┌────┬────────────────────────────────┐      │
│      │rail│ cabeçalho / identidade / ações │      │
│      │    ├────────────────────────────────┤      │
│      │    │ conteúdo principal             │      │
│      │    │                                │      │
│      └────┴────────────────────────────────┘      │
│                                                   │
└───────────────────────────────────────────────────┘
```

```css
.command-window {
  --rail-width: clamp(68px, 4.1vw, 78px);
  position: fixed;
  inset: 50% auto auto 50%;
  width: min(78vw, 1500px);
  height: min(82dvh, 870px);
  transform: translate(-50%, -50%);
  display: grid;
  grid-template-columns: var(--rail-width) minmax(0, 1fr);
  grid-template-rows: 82px minmax(0, 1fr) 46px;
  overflow: hidden;
  border: 1px solid var(--noir-border-soft);
  border-radius: var(--radius-md);
  background: var(--noir-canvas);
  box-shadow: var(--shadow-window);
  transition: grid-template-columns var(--duration-panel) var(--ease-out);
}

.command-window[data-rail="open"] {
  --rail-width: clamp(210px, 13vw, 236px);
}
```

Regras:

- rail estreito e contínuo à esquerda;
- cabeçalho entre `64–84px`, com contexto à esquerda e perfil/saída à direita;
- conteúdo com padding `clamp(16px, 1.7vw, 28px)`;
- o container central usa `min-height: 0` e `overflow: hidden`;
- não crie uma barra de rolagem única para toda a área central; catálogos, rankings, históricos e tabelas longas rolam dentro da própria região;
- em 720p, reduza padding e altura do cabeçalho antes de reduzir fonte;
- a janela pode ocupar mais espaço quando houver tabelas, mas mantenha pelo menos `24px` de safe zone.

### 6.2 Workspace dividido

Indicado para criação de lojas, roupas, personagens, objetos ou qualquer editor no qual a cena seja uma prévia útil.

```text
┌──────────────────── editor ────────────────────┬──── cena ────┐
│ tabs                                           │              │
├──────────────┬─────────────────────────────────┤              │
│ lista/contexto│ formulário / configuração      │ prévia viva  │
│               │                                 │              │
└──────────────┴─────────────────────────────────┴──────────────┘
```

```css
.split-workspace {
  width: clamp(720px, 45vw, 980px);
  height: 100dvh;
  display: grid;
  grid-template-columns: clamp(240px, 16vw, 320px) minmax(420px, 1fr);
  grid-template-rows: 58px minmax(0, 1fr);
  background: var(--noir-canvas-solid);
  border-right: 1px solid var(--noir-border-soft);
}
```

Regras:

- editor ancorado à esquerda e cena livre à direita;
- tabs ocupam o topo de todo o editor;
- coluna de lista recebe `border-right` sutil;
- conteúdo deve ter largura de leitura de `480–620px`; não estique campos sem necessidade;
- ações persistentes ficam no rodapé do painel, não sobre a cena;
- se a prévia da cena não tiver valor funcional, use a janela de comando.

### 6.3 Painéis e grids internos

- use CSS Grid para resumos: `repeat(3, minmax(0, 1fr))`;
- em detalhes, prefira `minmax(0, 2fr) minmax(280px, 1fr)`;
- coloque ações de gestão na coluna menor;
- em largura insuficiente, empilhe a coluna de ação abaixo do conteúdo;
- `min-width: 0` é obrigatório em filhos de grid que contenham texto truncável.

### 6.4 Conteúdo por aba, resumo e rolagem

Cada aba deve representar um contexto claro. Não repita blocos de resumo, progressão ou perfil dentro de uma aba dedicada a catálogo ou ranking.

- **Central/resumo:** saudação, métricas, progressão e uma prévia curta do próximo conteúdo acionável;
- **Catálogo:** somente cabeçalho contextual, mensagens necessárias e a coleção completa;
- **Ranking:** introdução curta, posição do jogador, lista e atualização;
- **Configuração:** somente os campos e ações daquele contexto.

Quando a Central antecipar um catálogo, mostre **no máximo três itens**. Esse limite é apenas de apresentação; a coleção completa continua disponível na aba dedicada e não deve ser truncada na fonte de dados.

```js
const visibleItems = activeTab === "overview"
  ? allItems.slice(0, 3)
  : allItems
```

Para uma Central sem rolagem global, organize as seções em linhas previsíveis:

```css
.main[data-tab="overview"] {
  display: grid;
  grid-template-rows: auto auto minmax(0, 1fr);
  gap: 16px;
  min-height: 0;
  overflow: hidden;
}

.catalog-panel,
.ranking-panel,
.history-panel {
  min-height: 0;
}

.catalog-list,
.ranking-list,
.history-list {
  min-height: 0;
  overflow-y: auto; /* a aparência da barra vem da regra global de 6.5 */
}
```

Se a altura for curta, reduza padding, gaps, mídia e metadados secundários antes de remover nomes, estados ou ações essenciais. Em uma prévia compacta de 720p, descrição e preço auxiliar podem ser ocultados; nome, disponibilidade e ação principal permanecem visíveis.

### 6.5 Barra de rolagem

A barra é parte da interface, não do sistema. Sem tratamento, o que aparece no CEF é a barra larga do Chromium — com setas, calha clara e cantos retos — encostada em painéis grafite.

Estilize **apenas pelos pseudo-elementos `::-webkit-scrollbar`**, e declare a regra uma vez para o documento inteiro:

```css
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

/* A borda transparente com `background-clip` afina o polegar dentro da calha: ele fica com
   4px visíveis e não encosta no conteúdo. */
::-webkit-scrollbar-thumb {
  border: 2px solid transparent;
  border-radius: var(--radius-pill);
  background-color: var(--noir-scroll-thumb);
  background-clip: content-box;
  transition: background-color var(--duration-control) var(--ease-soft);
}

::-webkit-scrollbar-thumb:hover {
  background-color: var(--noir-scroll-thumb-hover);
}

::-webkit-scrollbar-corner {
  background: transparent;
}
```

**Não declare `scrollbar-width` nem `scrollbar-color`.** A partir do Chromium 121, qualquer uma das duas num elemento faz o navegador desligar o `::-webkit-scrollbar` dele e desenhar a barra do sistema. Como a versão do CEF varia entre builds do FiveM, manter as duas famílias produz uma barra em cada máquina — e a do padrão não aceita raio, recuo nem hover. Uma NUI tem um alvo só; escolha o que dá controle.

Regras:

- a regra é global no documento, não por região: uma barra diferente por aba é inconsistência sem defesa, e quem adiciona a próxima lista não precisa lembrar de estilizá-la;
- polegar neutro. A cor do serviço vive no rail e em indicadores pequenos; pintar a barra com ela é acento decorativo;
- calha transparente, sem setas, sem borda e sem fundo próprio;
- o polegar responde ao hover, porque ele é arrastável;
- a barra ocupa espaço no fluxo: a coluna encolhe quando a lista passa a rolar, então textos truncáveis precisam de `text-overflow: ellipsis` de qualquer forma;
- barra visível não substitui `min-height: 0` na região que cresce — sem isso ela não rola, ela estoura.

## 7. Navegação

### 7.1 Rail vertical

O rail usa a cor temática do serviço como superfície de identidade. Sua posição é fixa à esquerda do shell, do topo à base, independentemente da cor escolhida. Ele possui dois estados oficiais:

| Estado | Largura | Topo | Itens |
|---|---:|---|---|
| Recolhido | `68–78px` | apenas controle `>`; não exibe logo | somente ícones, com tooltip |
| Aberto | `210–236px` | faixa com logo e controle `<` integrado à direita | ícone e rótulo visível |

O cabeçalho principal continua exibindo a identidade completa do serviço nos dois estados. O logo dentro do rail é informação complementar e aparece **somente quando o rail está aberto**.

```css
.nav-rail {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 14px 10px;
  background: linear-gradient(
    180deg,
    var(--noir-accent),
    var(--noir-accent-deep)
  );
}

.nav-rail__brand {
  display: none;
  width: 100%;
  height: 46px;
  grid-template-columns: 24px minmax(0, 1fr);
  align-items: center;
  gap: 11px;
  padding: 0 54px 0 10px;
  overflow: hidden;
  border: 1px solid rgba(17, 17, 19, 0.18);
  border-radius: var(--radius-sm);
  background: rgba(255, 255, 255, 0.12);
}

.command-window[data-rail="open"] .nav-rail__brand {
  display: grid;
}

.nav-rail__toggle {
  width: 46px;
  height: 42px;
  display: grid;
  place-items: center;
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
  background: transparent;
  color: var(--noir-on-accent);
}

.nav-rail__toggle-icon::before { content: ">"; }

.command-window[data-rail="open"] .nav-rail__toggle {
  position: absolute;
  top: 14px;
  right: 10px;
  width: 42px;
  height: 46px;
  border: 0;
  border-left: 1px solid rgba(17, 17, 19, 0.12);
  border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
  background: rgba(17, 17, 19, 0.07);
}

.command-window[data-rail="open"] .nav-rail__toggle-icon::before {
  content: "<";
}

.nav-rail__item {
  width: 46px;
  height: 46px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
  background: transparent;
  color: color-mix(in srgb, var(--noir-on-accent) 72%, transparent);
}

.nav-rail__label {
  max-width: 0;
  overflow: hidden;
  opacity: 0;
  white-space: nowrap;
}

.command-window[data-rail="open"] .nav-rail__item {
  width: 100%;
  justify-content: flex-start;
  gap: 12px;
  padding: 0 14px;
}

.command-window[data-rail="open"] .nav-rail__label {
  max-width: 140px;
  opacity: 1;
}

.nav-rail__item:hover,
.nav-rail__item[aria-selected="true"] {
  background: rgba(0, 0, 0, 0.16);
  color: var(--noir-on-accent);
}

.nav-rail__item[aria-selected="true"] {
  border-color: rgba(255, 255, 255, 0.14);
}
```

- o rail permanece à esquerda, ocupa toda a altura do shell e não muda de lado entre serviços;
- o botão de expansão usa `aria-expanded` e atualiza o `aria-label` entre “Abrir menu lateral” e “Fechar menu lateral”;
- `>` sempre significa abrir; `<` sempre significa recolher;
- a ordem dos itens e a seleção atual não mudam ao alternar o estado;
- tooltip é obrigatória no estado recolhido e dispensável quando o rótulo estiver visível;
- estado ativo combina superfície, contraste e `aria-selected` em tabs, ou `aria-current` em links; não dependa apenas da cor;
- use setas `↑`/`↓`, `Home` e `End` quando o rail implementar um `tablist` vertical;
- a transição de largura dura aproximadamente `240ms`, sem deslocar o shell para fora da safe zone;
- ações globais ou perigosas ficam separadas no fim do rail.

### 7.2 Tabs superiores

- altura entre `52–60px`;
- tab inativa sem fundo, texto `muted`;
- tab ativa em branco, texto escuro e raio `5px`;
- padding horizontal `14–18px`;
- navegação por setas esquerda/direita, `Home` e `End`;
- use `role="tablist"`, `role="tab"` e `aria-selected`.

Não transforme cada seção do formulário em tab. Tabs trocam contextos equivalentes; grupos internos usam títulos e espaço.

### 7.3 Lista lateral

Cada item apresenta nome forte e metadado abaixo. O item ativo pode receber fundo `--noir-card`, mas não uma borda grossa.

```css
.side-list__item {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
  background: transparent;
  text-align: left;
  color: var(--noir-text);
}

.side-list__item:hover { background: var(--noir-card); }
.side-list__item[aria-selected="true"] {
  border-color: var(--noir-border);
  background: var(--noir-panel-raised);
  color: var(--noir-text-strong);
}
```

## 8. Superfícies, cards e divisores

A v3 permite caixas quando elas ajudam a agrupar informação operacional. O efeito deve vir da diferença sutil entre tons, não de sombra ou borda forte.

### Card de resumo

- fundo `--noir-card`;
- borda `--noir-border-soft`;
- raio `--radius-sm`;
- padding `16–20px`;
- valor grande primeiro; label ou explicação abaixo;
- altura consistente entre cards irmãos.

### Card de seção

- cabeçalho com título e descrição curta;
- divisor `1px` antes do conteúdo quando houver controles;
- conteúdo com padding próprio;
- não aninhe mais de dois níveis de superfície.

### Linha de histórico

- fundo um degrau mais claro que o painel;
- título `600–700`, descrição em `muted`;
- data/hora alinhada à direita, com números tabulares;
- em telas estreitas, a data passa para uma segunda linha;
- hover só quando a linha for realmente clicável.

Divisores devem usar `--noir-divider`. Não desenhe uma borda em todos os lados quando um divisor simples explicar a estrutura.

## 9. Formulários

### 9.1 Campo padrão

```css
.field {
  width: 100%;
  min-height: 40px;
  padding: 0 12px;
  border: 1px solid var(--noir-border);
  border-radius: var(--radius-sm);
  background: var(--noir-field);
  color: var(--noir-text-strong);
  font: 400 13px/1 var(--font-ui);
  transition:
    background-color var(--duration-control) var(--ease-soft),
    border-color var(--duration-control) var(--ease-soft);
}

.field:hover { background: var(--noir-field-hover); }
.field:focus {
  outline: none;
  border-color: var(--noir-border-strong);
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.07);
}

.field[aria-invalid="true"] {
  border-color: color-mix(in srgb, var(--noir-danger) 68%, transparent);
}
```

Regras:

- label sempre visível, `8px` acima do campo;
- placeholder é exemplo, nunca substituto de label;
- campos relacionados podem formar duas colunas; em 720p ou textos longos, empilhe;
- preserve o valor após erro;
- erro aparece abaixo do campo com texto e ícone, não só cor;
- botão de envio fica no fim do fluxo e bloqueia reenvio durante loading;
- use `autocomplete` adequado quando a informação não for sensível;
- `select` mantém seta visível e área clicável suficiente.

### 9.2 Busca

Busca usa ícone à esquerda, botão de limpar à direita quando houver valor e label acessível. Debounce entre `150–250ms` em listas locais. Mostre “Nenhum resultado” sem apagar filtros ativos.

### 9.3 Checkbox, switch e seleção

- checkbox para selecionar itens independentes;
- radio para uma opção entre várias;
- switch apenas para efeito imediato liga/desliga;
- permissões em modal devem usar checkbox, salvo se cada mudança for salva instantaneamente;
- área clicável inclui texto e controle;
- estado marcado deve incluir ícone/check, não apenas troca de cor.

## 10. Chips e filtros

Chips aparecem na referência de editor como categorias selecionáveis. São o único controle comum com raio pill.

```css
.chip {
  min-height: 32px;
  padding: 0 13px;
  border: 1px solid var(--noir-border);
  border-radius: var(--radius-pill);
  background: transparent;
  color: var(--noir-text-muted);
  font: 500 12px/1 var(--font-ui);
}

.chip:hover {
  border-color: var(--noir-border-strong);
  color: var(--noir-text-strong);
}

.chip[aria-pressed="true"] {
  border-color: #fff;
  background: #fff;
  color: var(--noir-on-light);
}
```

- chips quebram linha com gap de `8px`;
- seleções exclusivas usam radio/tabs, não uma coleção de toggles ambígua;
- inclua contagem apenas se ela ajudar a decisão;
- não use chips para ações como salvar, apagar ou cancelar.

## 11. Botões e ações

### 11.1 Primário

O primário é branco preenchido, com texto quase preto. Há apenas um por formulário ou região de decisão.

```css
.button--primary {
  min-height: 40px;
  padding: 0 16px;
  border: 1px solid #fff;
  border-radius: var(--radius-sm);
  background: #fff;
  color: var(--noir-on-light);
  font: 600 13px/1 var(--font-ui);
}

.button--primary:hover { background: rgba(255, 255, 255, 0.88); }
.button--primary:active { background: rgba(255, 255, 255, 0.78); }
```

### 11.2 Secundário e ghost

- secundário: `--noir-panel-raised`, borda `--noir-border`, texto forte;
- ghost: transparente, sem borda ou com borda suave conforme o contexto;
- hover muda fundo e/ou borda; não use zoom;
- botão de voltar pode ser ghost com seta à esquerda;
- “Cancelar (Esc)” é ghost discreto no topo ou rodapé.

### 11.3 Destrutivo

- vermelho preenchido é permitido somente na decisão destrutiva explícita;
- em listas, a ação destrutiva começa neutra e revela vermelho no hover/foco;
- o label nomeia a consequência: `EXPULSAR MEMBRO`, não `CONFIRMAR`;
- ação irreversível abre confirmação e nunca é o foco inicial;
- `danger` inclui ícone ou texto inequívoco, pois um tema de serviço também pode usar vermelho.

### 11.4 Desabilitado e loading

```css
button:focus-visible,
[role="button"]:focus-visible {
  outline: 2px solid rgba(255, 255, 255, 0.78);
  outline-offset: 2px;
}

button:disabled,
button[aria-disabled="true"] {
  opacity: 0.38;
  cursor: not-allowed;
}
```

No loading:

- preserve largura e label do botão quando possível;
- adicione spinner de `14–16px` e `aria-busy="true"`;
- bloqueie cliques repetidos;
- não use loading infinito sem mensagem quando a espera exceder alguns segundos.

## 12. Modais e confirmações

O modal das referências é central, compacto e nitidamente acima do conteúdo.

```css
.modal-backdrop {
  position: fixed;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 24px;
  background: var(--noir-overlay);
}

.modal {
  width: min(430px, calc(100vw - 48px));
  max-height: min(720px, calc(100dvh - 48px));
  overflow: auto;
  border: 1px solid var(--noir-border);
  border-radius: var(--radius-md);
  background: var(--noir-panel-raised);
  box-shadow: var(--shadow-modal);
}
```

Estrutura:

1. cabeçalho de `52–60px` com ícone opcional, título e fechar;
2. divisor sutil;
3. conteúdo com padding `20px`;
4. ações no rodapé, alinhadas à direita ou em largura total quando houver uma única ação.

Comportamento:

- `role="dialog"`, `aria-modal="true"`, título associado;
- prenda o foco dentro do modal;
- foco inicial no primeiro campo ou ação segura;
- `Escape` fecha apenas quando não houver risco de perda silenciosa;
- restaure foco ao controle que abriu o modal;
- backdrop não usa `backdrop-filter` em FiveM;
- modal não deve ser usado apenas para mostrar um toast ou uma descrição curta.

## 13. Tabelas, listas e estados vazios

### Tabelas

- cabeçalho `10–12px`, peso 600, cor `muted`;
- linhas entre `44–52px`;
- divisores horizontais, sem grade completa;
- texto à esquerda, números à direita;
- ações da linha aparecem no fim, com tooltip quando forem só ícone;
- cabeçalho fixo somente em listas realmente longas;
- coluna de ação não muda de largura entre estados.

### Catálogos em cards

- a aba dedicada contém apenas o catálogo e seus estados de loading, erro ou vazio;
- use `grid-template-columns: repeat(3, minmax(210px, 1fr))` quando houver espaço;
- a lista recebe `min-height: 0` e `overflow-y: auto`; a aparência da barra é a de 6.5;
- imagens usam uma caixa de altura definida, `overflow: hidden` e `object-fit: contain` para nunca invadir nome, descrição ou ação;
- itens bloqueados continuam legíveis, mas imagem, descrição e ação podem receber menor opacidade;
- a ação principal permanece no fim do card para alinhar cartões com descrições diferentes;
- o resumo de outra aba nunca duplica todo o catálogo: mostra no máximo três cards.

### Rankings longos

A posição do jogador é contexto persistente, não uma linha perdida no meio da classificação. Ela fica acima da lista, separada por divisor, e não participa da rolagem.

```css
.ranking-panel {
  display: flex;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  flex-direction: column;
}

.ranking-self {
  flex: 0 0 auto;
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--noir-divider);
}

.ranking-list {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
}
```

- ordem visual: introdução, `SUA POSIÇÃO`, lista e horário de atualização;
- apenas `.ranking-list` rola;
- a linha do jogador usa borda/acento, texto e posição para ser reconhecida sem depender somente da cor;
- pódio pode receber contraste discreto; apenas o primeiro lugar usa o acento principal;
- valores, posições e corridas usam números tabulares.

### Estados vazios

Um estado vazio contém título, uma frase explicativa e, quando aplicável, uma única ação. Não preencha a tela com ilustração decorativa. Diferencie:

- lista realmente vazia;
- busca sem resultado;
- ausência de permissão;
- falha de carregamento.

### Skeleton e carregamento

Use skeleton apenas quando a estrutura final for previsível. Caso contrário, spinner pequeno com mensagem. Skeleton mantém os mesmos raios e dimensões dos elementos finais e respeita `prefers-reduced-motion`.

## 14. Perfil, status e semântica

O cartão compacto de perfil no cabeçalho pode usar um filete lateral de status, como na referência.

- avatar/ícone `20px`;
- nome em `13–15px`, peso 600;
- cargo/status em `10–11px`, cor `muted`;
- indicador de status com `3–5px` de largura;
- verde comunica online/disponível/sucesso, não ação primária;
- nunca use apenas o filete para comunicar um estado crítico.

Use cores semânticas em pequenas áreas: ícone, filete, badge ou texto curto. Evite cartões inteiros verdes/amarelos/vermelhos, exceto o botão destrutivo explícito.

## 15. Ícones

Use uma única família linear, preferencialmente Lucide:

- traço `1.5–1.75px`;
- `16px` em campos e botões;
- `18–20px` em navegação;
- `22px` no rail apenas quando necessário;
- `stroke="currentColor"` para herdar estados;
- ícone decorativo com `aria-hidden="true"`;
- botão somente ícone com `aria-label` e tooltip.

Não misture ícones filled, emoji, Font Awesome sólido e Lucide na mesma interface. Ícone não substitui label em ações pouco familiares.

## 16. Movimento

Ferramentas operacionais precisam responder rápido:

- hover/foco: `120–180ms`;
- abrir dropdown/popover: `160–200ms`;
- modal: backdrop `180ms`; caixa `220ms` com fade e `translateY(8px)`;
- janela/split workspace: `220–300ms` com fade curto e deslocamento de `12–20px`;
- stagger no máximo `30ms` entre poucos grupos; não anime cada linha de uma tabela longa.

Telas narrativas podem usar a coreografia de até `900ms` definida na v2. CRUD, gestão e formulários não usam essa duração.

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    scroll-behavior: auto !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

## 17. Legibilidade sobre a cena

Ordem de preferência:

1. superfície do próprio shell;
2. gradiente localizado atrás de conteúdo solto;
3. sombra curta de texto;
4. backdrop escuro somente quando o fluxo estiver bloqueado por modal.

Não aplique overlay preto fullscreen apenas para aumentar contraste de uma janela que já é opaca. No workspace dividido, a divisão entre editor e cena deve ser limpa; não escureça a metade da cena que permanece livre.

## 18. Responsividade e safe zone

Teste em `1280×720`, `1920×1080`, `2560×1440`, `3440×1440` e com UI scale diferente de 100%.

Breakpoints de comportamento, não de dispositivo:

- abaixo de `900px` úteis: grid de resumo passa de 3 para 2 colunas;
- abaixo de `720px` úteis: detalhes e ações empilham;
- altura abaixo de `760px`: reduza gaps/padding em um degrau, compacte as mídias das prévias e remova metadados secundários que já existam na aba detalhada;
- altura abaixo de `640px`: cabeçalhos compactam e somente as listas preparadas para crescimento rolam; não reintroduza scrollbar no container central;
- ultrawide: limite a largura do shell; não estique formulários e linhas.

Em `1280×720`, valide os dois estados do rail. O estado aberto reduz a largura útil do conteúdo e, por isso, é o cenário mais restritivo. A Central deve continuar sem overflow vertical, com ações essenciais inteiras e sem imagens atravessando o conteúdo dos cards.

Safe zone:

- mínimo absoluto de `24px` para janela central;
- `clamp(24px, 4vh, 56px)` recomendado;
- widgets próximos ao HUD devem respeitar a configuração de safe zone do jogador;
- dados e ações nunca ficam sob minimapa, chat ou notificações do jogo.

Textos e dados imprevisíveis:

- nomes em uma linha usam reticências e `title`/tooltip acessível;
- descrições quebram linha;
- datas e valores não encolhem abaixo do tamanho legível;
- teste traduções 30% maiores que o exemplo.

## 19. Acessibilidade e controles

- ordem de foco igual à ordem visual;
- todo controle tem estado `focus-visible`;
- `Enter` envia apenas quando seguro e esperado;
- `Escape` volta/fecha sem descartar mudanças silenciosamente;
- setas navegam tabs, radios e componentes compostos;
- contraste mínimo `4.5:1` para texto comum e `3:1` para texto grande;
- `muted` e `faint` nunca carregam informação essencial;
- cor não é o único indicador;
- use elementos HTML nativos antes de `div` com evento de clique;
- anuncie erros e resultados assíncronos com `aria-live` apropriado;
- não remova outline sem substituição;
- limite `user-select: none` a controles e elementos decorativos.

## 20. Conteúdo e linguagem

A interface final usa português do Brasil consistente:

- ações começam com verbo: `CRIAR CARGO`, `SALVAR ALTERAÇÕES`, `EXPULSAR MEMBRO`;
- labels são substantivos: `NOME`, `CARGO`, `PREÇO BASE`, `PERMISSÕES`;
- botão descreve a ação, não usa `OK` ou `CONFIRMAR` quando houver ambiguidade;
- sem ponto final em labels e botões;
- frases explicativas usam pontuação;
- evite termos internos como resource, callback, citizenid ou evento;
- datas seguem `dd/mm/aaaa` e horários `HH:mm`, salvo exigência de domínio;
- dinheiro segue localidade e moeda configuradas pelo servidor.

## 21. Notificações

Notificações continuam compactas e não substituem validação inline.

| Tipo | Uso | Duração sugerida |
|---|---|---:|
| Sucesso | ação concluída | 3–4 s |
| Informação | atualização neutra | 4–5 s |
| Alerta | atenção sem bloqueio | 5–7 s |
| Erro | falha que exige ciência | 6–8 s ou persistente |

- largura máxima `360px`;
- fundo `--noir-panel-raised`, borda `--noir-border`;
- filete ou ícone semântico, não superfície inteira colorida;
- máximo de três visíveis; agrupe repetições;
- não cubra menus, botões persistentes ou o HUD;
- erro de campo aparece no campo; toast relata apenas o resultado geral;
- escreva `Cargo criado` e o próximo passo quando houver, não `Sucesso!` sozinho.

## 22. Transparência obrigatória no FiveM

Toda NUI mantém documento e raiz totalmente transparentes. Apenas os componentes visíveis recebem fundo.

```css
html,
body,
#root,
#app {
  width: 100%;
  height: 100%;
  margin: 0;
  overflow: hidden;
  background: transparent !important;
}
```

Regras críticas:

- nunca defina preto no documento ou container fullscreen;
- não aplique `color-scheme: dark` em `:root`, `html` ou `body` de uma NUI transparente; no CEF/FiveM isso pode pintar de preto o canvas da página mesmo quando todos os componentes estiverem ocultos;
- declare a transparência crítica no `<head>` e repita-a no CSS principal para evitar um frame preto durante o carregamento do stylesheet;
- o shell (`.command-window` ou `.split-workspace`) recebe o fundo escuro;
- backdrop fullscreen existe somente enquanto um modal bloqueador estiver aberto;
- não use `backdrop-filter` em elementos fullscreen transparentes; no FiveM ele pode renderizar a cena como preto;
- a barra de rolagem é outra em que a versão do CEF muda o resultado: estilize pelos pseudo-elementos e não declare `scrollbar-width`/`scrollbar-color` (6.5);
- feche a NUI e libere foco quando o usuário sair do fluxo.

## 23. Modelo base de componentes

```css
.noir-surface {
  border: 1px solid var(--noir-border-soft);
  border-radius: var(--radius-sm);
  background: var(--noir-card);
  color: var(--noir-text);
}

.noir-control {
  min-height: 40px;
  border: 1px solid var(--noir-border);
  border-radius: var(--radius-sm);
  background: var(--noir-field);
  color: var(--noir-text-strong);
  font-family: var(--font-ui);
  transition:
    color var(--duration-control) var(--ease-soft),
    background-color var(--duration-control) var(--ease-soft),
    border-color var(--duration-control) var(--ease-soft);
}

.noir-control:hover {
  border-color: var(--noir-border-strong);
  background: var(--noir-field-hover);
}
```

Essas classes são fundações, não convite para transformar cada texto em card ou cada ação em botão preenchido.

## 24. Antipadrões

Não use:

- fundo opaco em `html`, `body`, `#root` ou aplicação fullscreen;
- blur em toda a viewport;
- gradiente colorido decorativo, neon ou glow;
- bordas claras em todas as caixas ao mesmo tempo;
- raio acima de `8px` fora de chips, avatares e botões circulares;
- botão primário colorido quando o branco já comunica a ação;
- cor do serviço aplicada a ações normais só para “combinar” com o rail;
- hover com zoom em linhas, cards, campos ou botões de texto;
- placeholder como label;
- modal dentro de modal;
- texto essencial em opacidade abaixo de 50%;
- animação longa em formulário ou gestão;
- tipografia dimensionada apenas em `vw` ou `vh`;
- dependência de fonte, ícone ou CSS carregado por CDN;
- logo compacto persistente no rail recolhido; nesse estado, preserve somente o controle `>` e os ícones de navegação;
- seta de recolher solta abaixo do logo quando o rail estiver aberto; integre `<` ao lado direito da faixa de identidade;
- scrollbar em toda a área central para resolver o crescimento de uma única lista;
- `scrollbar-width`/`scrollbar-color` junto com `::-webkit-scrollbar`; no Chromium 121+ a primeira desliga a segunda e a barra muda de aparência conforme o build;
- barra de rolagem com a cor do serviço, setas ou calha visível;
- progressão, saudação ou métricas repetidas dentro das abas de catálogo e ranking;
- mais de três itens de catálogo na prévia da Central.

## 25. Checklist de revisão

- [ ] escolheu um shell oficial: janela de comando ou workspace dividido;
- [ ] mantém a cena visível na proporção adequada ao fluxo;
- [ ] usa Poppins empacotada localmente, com fallback definido;
- [ ] centraliza cores, forma, movimento e tipografia em tokens;
- [ ] usa branco para a única ação primária do contexto;
- [ ] define os tokens de tema do serviço e mantém o rail na posição padrão;
- [ ] o rail recolhido oculta o logo, mostra `>` e mantém tooltip nos itens somente com ícone;
- [ ] o rail aberto mostra a faixa de identidade, integra `<` à direita e revela os rótulos;
- [ ] distingue cor do serviço de estados destrutivo, alerta, sucesso e informação;
- [ ] possui hover, foco, ativo, desabilitado, loading, erro e vazio;
- [ ] labels de formulário permanecem visíveis;
- [ ] chips são usados apenas para seleção/filtro;
- [ ] modal prende e restaura foco;
- [ ] funciona com teclado e foco visível;
- [ ] não depende somente de cor, ícone ou som;
- [ ] mantém contraste sobre cenas claras e escuras;
- [ ] raiz da NUI é transparente e não usa blur fullscreen;
- [ ] respeita HUD, safe zone e áreas roláveis;
- [ ] a área central não possui scrollbar global quando apenas uma coleção cresce;
- [ ] catálogos e rankings longos rolam internamente;
- [ ] a barra de rolagem usa os pseudo-elementos, é global e não declara `scrollbar-width`/`scrollbar-color`;
- [ ] a Central mostra no máximo três itens de prévia e a aba dedicada mostra a coleção completa;
- [ ] “Sua posição” permanece acima e fora da lista rolável do ranking;
- [ ] foi testada em 720p, 1080p, 1440p e ultrawide;
- [ ] foi testada em 720p com o rail aberto e fechado;
- [ ] suporta nomes, valores e traduções maiores;
- [ ] usa pt-BR e rótulos orientados à ação;
- [ ] respeita `prefers-reduced-motion`;
- [ ] build final foi gerado quando o resource carrega `dist`/`build`.

## 26. Regra para exceções

Celular, terminal policial, painel de veículo, minigame ou recurso com identidade narrativa própria pode adaptar cor, tipografia display e composição. Ainda assim, conserva obrigatoriamente:

- raiz transparente;
- legibilidade e contraste;
- estados completos de controle;
- semântica de ações e cores;
- navegação por teclado quando aplicável;
- safe zone e responsividade;
- feedback de loading e erro;
- ausência de blur fullscreen no FiveM.

Qualquer exceção recorrente deve virar token ou variante documentada antes de ser copiada entre resources.
