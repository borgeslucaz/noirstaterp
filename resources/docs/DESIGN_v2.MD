# Guia de design de interfaces v2 — Noir State RP

> Padrão visual para novas NUIs, menus, notificações, confirmações e outros componentes do servidor. A referência principal é o `rome_pausemenu` (`[standalone]/rome_pausemenu/ui`). A v1 deste guia (`DESIGN.md`) permanece como referência histórica.

## 0. O que mudou da v1 para a v2

| Tema | v1 | v2 |
|---|---|---|
| Fonte | Inter 400–500 | Plus Jakarta Sans 600 como padrão; Inter 300 só em corpo de modal |
| Unidades | px (escala de 4px) | `vh` (escala junto com a viewport do jogo) |
| Menus e listas | superfície translúcida em caixa | linhas fantasma separadas por hairline, sem fundo |
| Hover | borda + fundo + cor | apenas cor (texto/ícone clareiam, hairline acende) |
| Movimento | 160–200ms sempre | operações 150–350ms; telas narrativas 900ms com stagger e ease expo-out |
| Danger | vermelho no hover | destrutivo mais apagado que os normais em repouso; vermelho claro só no hover |
| Cards de info | caixa com borda | texto flutuante com régua lateral de 1px |
| Contraste | superfícies e overlays | também text-shadow/drop-shadow sobre a cena |

Mantidos da v1: navegação por teclado, foco visível, `prefers-reduced-motion`, contraste mínimo, proibição de `backdrop-filter` fullscreen, raiz transparente, linguagem pt-BR e regra de exceções.

## 1. Direção visual

O padrão Noir v2 é cinematográfico, translúcido e quase sem caixas. A interface flutua sobre o jogo: texto direto na cena, separadores finos, nenhuma superfície onde um gradiente ou uma sombra resolver.

Princípios:

- o jogo é o fundo; a interface nunca o cobre por completo;
- hierarquia feita com opacidade de branco, tamanho e tracking — não com fundos;
- composição ancorada nas bordas da tela, centro livre para o personagem;
- separadores hairline de 1px em vez de cards; caixas só em modais e confirmações;
- labels em caixa alta com tracking largo; corpo de texto em caixa normal;
- movimento como coreografia de entrada/saída de tela, não como decoração;
- cor semântica somente quando comunica estado, risco ou resultado.

Evite gradientes coloridos, neon, glow intenso, sombras pesadas de caixa, bordas muito arredondadas, excesso de ícones e qualquer fundo opaco atrás de conteúdo que não seja modal.

## 2. Fonte de verdade

A referência canônica é o build do `rome_pausemenu` em `[standalone]/rome_pausemenu/ui`. A fonte padrão é:

```css
font-family: "Plus Jakarta Sans", Inter, sans-serif;
font-weight: 600; /* peso padrão da v2 */
```

Regras:

- Plus Jakarta Sans 600 é o peso de trabalho: títulos, labels, valores, itens de menu;
- Inter 300 é reservada a corpo de texto em modais e confirmações (frases completas);
- fonte display (Arame, Chakra Petch etc.) apenas quando o universo do recurso exigir identidade própria, nunca em textos longos, formulários ou dados operacionais;
- não use Anton, Pricedown ou o verde legado `#88cfcd` do Tailwind.

## 3. Tokens fundamentais

Centralize os valores abaixo; replique os nomes em vez de espalhar literais.

```css
:root {
  /* Texto — hierarquia por alpha */
  --noir-white: #fff;
  --noir-text-strong: rgba(255, 255, 255, 0.96); /* títulos, hover */
  --noir-text: rgba(255, 255, 255, 0.72);        /* labels de menu */
  --noir-text-dim: rgba(255, 255, 255, 0.50);    /* ícones em repouso */
  --noir-text-faint: rgba(255, 255, 255, 0.30);  /* labels de dado */
  --noir-text-ghost: rgba(255, 255, 255, 0.15);  /* separadores tipográficos */

  /* Hairlines e bordas */
  --noir-hairline: rgba(255, 255, 255, 0.06);       /* divisor de linha de menu */
  --noir-hairline-hover: rgba(255, 255, 255, 0.18); /* divisor no hover / régua de card */
  --noir-border: rgba(255, 255, 255, 0.12);         /* botões ghost, painéis */
  --noir-border-hover: rgba(255, 255, 255, 0.30);

  /* Painéis — apenas modais e confirmações */
  --noir-panel: rgba(10, 10, 12, 0.88);
  --noir-panel-border: rgba(255, 255, 255, 0.08);
  --noir-backdrop: rgba(0, 0, 0, 0.50);

  /* Estados */
  --noir-success: #78a98b;
  --noir-warning: #c9a86a;
  --noir-danger: #ff8282;                      /* texto destrutivo no hover */
  --noir-danger-text: #ff9696;                 /* ação destrutiva em confirmação */
  --noir-danger-border: rgba(255, 100, 100, 0.35);
  --noir-danger-border-hover: rgba(255, 100, 100, 0.60);
  --noir-info: #829bab;

  /* Legibilidade sobre a cena */
  --noir-text-shadow: 0 1px 2px rgb(0 0 0), 0 2px 6px rgba(0, 0, 0, 0.85);
  --noir-drop-shadow: 0 1px 4px rgba(0, 0, 0, 0.50);
  --noir-gradient-side: linear-gradient(
    to right,
    rgba(0, 0, 0, 0.52) 0%,
    rgba(0, 0, 0, 0.28) 45%,
    transparent 100%
  );

  /* Forma e movimento */
  --noir-radius: 2px;
  --noir-ease-out: cubic-bezier(0.16, 1, 0.3, 1);   /* expo-out: entradas de tela */
  --noir-ease-soft: cubic-bezier(0.22, 1, 0.36, 1); /* modais e confirmações */
  --noir-transition-fast: 150ms var(--noir-ease-out);
  --noir-transition: 250ms var(--noir-ease-out);
}
```

## 4. Unidades: tudo em `vh`

NUIs de tela cheia dimensionam **tudo em `vh`** (1vh = 1% da altura da viewport). Assim a interface escala com a proporção da tela do jogo, igual ao `rome_pausemenu`.

Referência em 1080p (1vh ≈ 10,8px):

```text
Espaçamento: 0.4, 0.55, 1.1, 1.6, 2.2, 3.5, 5 vh
Margens externas de tela cheia: 5vh (≈54px em 1080p)
Largura de menu lateral: 26vh
```

- `px` continua aceitável em HUDs pequenos e fixos (ícones de 16/20/24px) e em componentes que não podem escalar;
- nunca dimensione apenas com `vw`: em ultrawide tudo estoura;
- alvos interativos: no mínimo `2.6vh` para botões circulares compactos e `4vh` (≈44px em 1080p) para linhas de lista e botões de texto.

## 5. Hierarquia tipográfica

Plus Jakarta Sans salvo indicação contrária.

| Uso | Tamanho | Peso | Tratamento |
|---|---:|---:|---|
| Título de card (nome de jogador) | `1.9vh` | 600 | tracking `.02em` |
| Título curto / nome de servidor | `1.8vh` | 600 | caixa alta, tracking `.10em` |
| Item de menu | `1.45vh` | 600 | tracking `.04em` |
| Valor numérico / contagem | `1.1–1.35vh` | 600 | tracking `.02–.06em`, `tabular-nums` |
| Label de dado | `0.95vh` | 600 | caixa alta, tracking `.06–.12em` |
| Metadado (ID) | `1.15vh` | 600 | tracking `.02em`, cor dim |
| Corpo de modal | `1.35vh` | Inter 300 | caixa normal, `line-height 1.6` |
| Botão de modal | `1.15vh` | Inter 400 | tracking `.06em` |

Caixa alta é para labels, ações curtas e metadados — nunca para parágrafos ou mensagens explicativas.

### Padrão label · valor

Labels de dado terminam com um separador tipográfico `·` em opacidade baixa, e o valor vem logo após, um degrau maior que o label:

```css
.label::after {
  content: "·";
  margin-left: 0.5vh;
  color: var(--noir-text-ghost);
}
```

```text
CASH · $5.200      EMPREGO · Policial     JOGADORES · 42/64
```

## 6. Composição e ancoragem

Telas cheias ancoram o conteúdo nas bordas e deixam o centro livre para o personagem/cena (padrão do pause menu):

```text
┌────────────────────────────────────────────┐
│ card do jogador (5vh)        info servidor │
│                                             │
│ MENU                                       │
│ vertical                              cena │
│ centrado (5vh)                              │
│                                             │
└────────────────────────────────────────────┘
```

- card principal: canto superior esquerdo, margens de `5vh`;
- card de contexto/servidor: canto superior direito, texto alinhado à direita;
- menu de navegação: lateral esquerda, centrado verticalmente (`translateY(-50%)`), largura de `26vh`;
- larguras de card com `min-width` em `vh` (ex.: `22vh`), sem larguras fixas;
- widgets flutuantes de HUD (photomode, câmera): cantos com margens de `2.2vh`.

Mantenha alinhamentos previsíveis e bastante espaço livre. Outras NUIs podem reancorar, mas preservam hierarquia e centro respirável.

## 7. Overlays e legibilidade sobre a cena

Proteja o texto com o recurso mais leve que resolver, nesta ordem:

1. **Gradiente direcional lateral** — `--noir-gradient-side` em até 48% da largura, do lado que contém texto; espelhe com `to left` para o lado direito. Nunca um véu opaco na tela inteira.
2. **Text-shadow** — para texto e valores que flutuam diretamente sobre a cena, use `--noir-text-shadow` em vez de fundo.
3. **Drop-shadow** — botões circulares translúcidos usam `box-shadow: var(--noir-drop-shadow)` para destacar da cena.
4. **Painel** — só em modais e confirmações: `--noir-panel` + `--noir-panel-border`.

O overlay acompanha o lado do texto. Se um gradiente localizado resolve o contraste, não use fundo.

## 8. Menus e listas fantasma

O componente central da v2. Itens **sem fundo, sem caixa, sem escala**: linhas transparentes separadas por hairline, feedback apenas por cor.

```css
.menu-item {
  display: flex;
  align-items: center;
  gap: 1.6vh;
  width: 100%;
  padding: 1.1vh 0;
  border: none;
  border-bottom: 1px solid var(--noir-hairline);
  background: transparent;
  cursor: pointer;
  text-align: left;
  transition: border-color var(--noir-transition);
}

.menu-item .icon {
  min-width: 2.4vh;
  color: var(--noir-text-dim);
  transition: color var(--noir-transition);
}

.menu-item .label {
  font-size: 1.45vh;
  letter-spacing: 0.04em;
  color: var(--noir-text);
  transition: color var(--noir-transition);
}

.menu-item:hover { border-bottom-color: var(--noir-hairline-hover); }
.menu-item:hover .icon { color: var(--noir-text-strong); }
.menu-item:hover .label { color: var(--noir-white); }
```

Regras:

- o hover muda **apenas cor** (ícone, label e o hairline da própria linha); nunca fundo, escala ou tamanho;
- ícone linear opcional à esquerda com `min-width` fixo para alinhar labels;
- itens agrupados por espaço, não por caixas aninhadas;
- ação destrutiva fica no fim da lista e usa o padrão da seção 10;
- listas grandes mantêm busca ou categorias; a rolagem, quando necessária, fica visível.

## 9. Cards de informação

Cards de dados (jogador, servidor, stats) **não são caixas**: são texto flutuando com uma régua lateral de 1px como âncora visual.

```css
.card {
  min-width: 22vh;
  padding-left: 1.2vh;
  border-left: 1px solid var(--noir-hairline-hover);
}
```

- card alinhado à direita (canto superior direito): sem régua, apenas alinhamento à direita;
- pares label · valor empilhados com gaps de `0.55vh`; grupos internos com `2vh`;
- números que mudam usam `font-variant-numeric: tabular-nums`;
- nomes e valores imprevisíveis truncam com reticências.

## 10. Ação destrutiva ("danger escondido")

Item destrutivo (sair do servidor, apagar personagem) **disfarça-se entre os normais** em repouso e só revela o vermelho no hover:

```css
.menu-item.danger .icon,
.menu-item.danger .label {
  color: rgba(255, 255, 255, 0.45); /* um degrau ABAIXO do normal (0.72) */
}

.menu-item.danger:hover .icon,
.menu-item.danger:hover .label {
  color: var(--noir-danger); /* #ff8282 */
}
```

Em confirmações, a ação destrutiva usa borda `--noir-danger-border` e texto `--noir-danger-text`; no hover a borda reforça (`--noir-danger-border-hover`) e o texto vai a branco. Nunca pinte o componente inteiro de vermelho.

## 11. Botões e ações

### Ação primária

- apenas uma ação primária por contexto;
- botão ghost: fundo transparente, borda `1px` `--noir-border`, texto claro, padding `0.9vh 2.2vh`;
- label curta com verbo, em caixa alta com tracking `.06em`;
- hover: borda `--noir-border-hover` + texto branco — sem fundo.

### Botões circulares flutuantes

Para controles sobre a cena (photomode, câmera):

```css
.circle-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.6vh;
  height: 2.6vh;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.20);
  background: rgba(0, 0, 0, 0.28);
  color: var(--noir-text-strong);
  box-shadow: var(--noir-drop-shadow);
  transition: background var(--noir-transition-fast),
    border-color var(--noir-transition-fast), transform 100ms var(--noir-ease-out);
}

.circle-btn:hover {
  background: rgba(0, 0, 0, 0.42);
  border-color: rgba(255, 255, 255, 0.35);
  transform: scale(1.05);
}

.circle-btn:active { transform: scale(0.92); }
```

Escala no hover é aceitável **apenas** em botões circulares flutuantes — nunca em linhas de lista ou botões de texto.

### Estados obrigatórios

Todo controle precisa de repouso, hover, `focus-visible`, pressionado (quando perceptível), desabilitado (baixa opacidade, sem interação) e carregando (bloqueia novos envios).

```css
button:focus-visible {
  outline: 1px solid rgba(255, 255, 255, 0.70);
  outline-offset: 3px;
}

button:disabled {
  opacity: 0.32;
  cursor: not-allowed;
}
```

## 12. Movimento e coreografia

Duas escalas de movimento, sem meio-termo.

### Operações rotineiras (hover, widgets, micro-feedback)

- `150–160ms` para hover e micro-feedback;
- `350ms` com `--noir-ease-out` para entrada de widgets flutuantes, com delays curtos entre grupos (`+60ms` por grupo);
- sem animação infinita fora de loading;
- feedback imediato ao clique; progresso real quando a espera passar de ~500ms.

### Telas narrativas (pause, multichar, transições de cena)

Entrada como coreografia, saída como coreografia reversa:

```css
entrada: opacity 0→1 + slide x:-40 (menu lateral), x:±35% (cards laterais)
duração: 900ms, ease var(--noir-ease-out)
delay: 200ms base + índice × 120ms (stagger crescente)

saída: opacity 1→0 + slide x:-40 (menu) / x:±100% (cards saem para o próprio lado)
duração: 550ms, ease var(--noir-ease-out)
delay: stagger REVERSO — o último item sai primeiro, passo 90ms
```

- o card da direita entra/sai para a direita; o da esquerda e o menu, para a esquerda;
- aguarde a saída completar antes de liberar foco/estados (sincronizar com `closeComplete` via NUI);
- em telas com poucos elementos, o stagger pode ser substituído por um único slide de tela.

### Modais e confirmações

Backdrop com fade de `300ms`; caixa sobe `y: 12→0` com fade, `300ms`, `--noir-ease-soft`.

### Acessibilidade de movimento

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

## 13. Notificações

Mensagens breves sobre o resultado de uma ação; nunca modais.

```text
[ícone/indicador] TÍTULO CURTO
                  Explicação objetiva, quando necessária.
```

| Tipo | Uso | Cor de apoio | Duração sugerida |
|---|---|---|---:|
| Sucesso | ação concluída | `--noir-success` | 3–4 s |
| Informação | atualização neutra | `--noir-info` | 4–5 s |
| Alerta | atenção sem bloqueio | `--noir-warning` | 5–7 s |
| Erro | falha que exige ciência | `--noir-danger` | 6–8 s ou persistente |

- área consistente, respeitando HUD, minimapa e safe zone;
- largura máxima de ~`36vh`;
- fundo `rgba(10, 10, 12, 0.88)`, borda `--noir-panel-border`, raio `2px`;
- cor semântica apenas em filete de `2px`, ícone ou título;
- no máximo três visíveis; agrupe repetições;
- pause o tempo no hover quando houver texto relevante; fechamento manual em avisos persistentes;
- escreva `Personagem criado` + próximo passo, nunca `Sucesso!` sozinho;
- notificações não cobrem menus ativos nem recebem foco; erro de formulário aparece junto ao campo.

## 14. Modais e confirmações

Use modal somente quando a ação bloquear o fluxo ou exigir decisão imediata.

```css
.backdrop {
  position: fixed;
  inset: 0;
  background: var(--noir-backdrop);
  display: flex;
  align-items: center;
  justify-content: center;
}

.confirm-box {
  max-width: 38vh;
  padding: 3vh 3.5vh;
  border: 1px solid var(--noir-panel-border);
  background: var(--noir-panel);
  text-align: center;
}

.confirm-box p {
  font-family: Inter, sans-serif;
  font-weight: 300;
  font-size: 1.35vh;
  line-height: 1.6;
  color: rgba(255, 255, 255, 0.75);
}
```

Uma confirmação contém: título com a ação, objeto afetado, consequência em linguagem direta, ação segura e destrutiva distintas, suporte a `Escape`, foco inicial na ação segura.

Ações lado a lado com gap de `1vh`: botão neutro ghost e botão destrutivo (seção 10). Para exclusão permanente, exija pressione-e-segure, digitação ou duas etapas, e informe que não há desfazer. Não use `backdrop-filter` no backdrop (renderiza preto no FiveM).

## 15. Formulários

- label sempre visível; placeholder não substitui label;
- campos com altura mínima de `4vh`;
- mesma largura e alinhamento dentro do grupo;
- instrução e unidade próximas do campo (`ALTURA`, `180 cm`);
- erro abaixo do campo, legível, com ícone/indicador além da cor;
- não apague valores após tentativa inválida;
- marque opcionais explicitamente;
- bloqueie envio duplicado enquanto processa;
- botão principal no fim do fluxo;
- caixa normal no conteúdo digitado; datas, dinheiro e números em `pt-BR`.

## 16. Ícones

- lineares, simples, traço de `1.5px` (padrão lucide), `stroke="currentColor"`;
- tamanhos: `1.05vh` dentro de botões circulares, `2.4vh` de coluna em linhas de menu (o svg pode ser menor, a área é essa), `16/20/24px` em HUDs fixos;
- cor herda o estado do texto do item (repouso dim, hover forte);
- decorativos com `aria-hidden="true"`; ações só-ícone com `aria-label` e área mínima de `2.6vh`;
- não misture famílias de peso/preenchimento diferentes na mesma interface.

## 17. Acessibilidade e controles

Mesmo em NUI de jogo, todos os fluxos funcionam sem depender exclusivamente do mouse.

- ordem de foco acompanha a ordem visual;
- foco visível em todo controle;
- `Enter` confirma a ação principal quando não houver risco destrutivo;
- `Escape` fecha ou volta quando não causa perda inesperada;
- setas navegam em listas, abas e carrosséis;
- contraste mínimo de `4.5:1` para texto comum e `3:1` para texto grande — atenção aos degraus fracos (`faint`/`ghost`), nunca usados em texto essencial;
- cor nunca é o único indicador de estado;
- alvos interativos com pelo menos `2.6vh` (compactos) ou `4vh` (comuns);
- HTML semântico e nomes acessíveis;
- restrinja `user-select: none` a controles e decorativos, nunca a dados que o usuário possa copiar.

## 18. Responsividade e safe zone

Valide em `1280×720`, `1920×1080`, `2560×1440` e ultrawide. Como a v2 dimensiona em `vh`, verifique principalmente variações de **proporção** (21:9, 16:10) e de altura:

- margens seguras: `5vh` em telas cheias, `2.2vh` em widgets de canto;
- nada essencial colado às bordas;
- sem dimensões só em `vw`; larguras com `min-width`/`max-width` em `vh`;
- trunque nomes e valores imprevisíveis com reticências; permita quebra quando truncar remover sentido;
- valide com textos maiores que os exemplos reais.

## 19. Linguagem e conteúdo

pt-BR consistente.

- ações começam com verbo: `JOGAR COM PERSONAGEM`, `SAIR DO SERVIDOR`;
- labels são substantivos: `DINHEIRO`, `EMPREGO`, `JOGADORES`;
- mensagens explicam causa e solução quando possível;
- sem termos técnicos do resource, callbacks ou nomes internos;
- sem ponto final em labels e botões; com ponto final em frases completas;
- prefira mensagens humanas: `Não foi possível carregar os personagens. Tente novamente.`

## 20. Modelo base de componente

Linha de menu (componente padrão da v2):

```css
.noir-row {
  display: flex;
  align-items: center;
  gap: 1.6vh;
  width: 100%;
  padding: 1.1vh 0;
  border: none;
  border-bottom: 1px solid var(--noir-hairline);
  background: transparent;
  color: var(--noir-text);
  font-family: "Plus Jakarta Sans", Inter, sans-serif;
  font-weight: 600;
  font-size: 1.45vh;
  letter-spacing: 0.04em;
  cursor: pointer;
  transition: border-color var(--noir-transition), color var(--noir-transition);
}

.noir-row:hover {
  border-bottom-color: var(--noir-hairline-hover);
  color: var(--noir-white);
}

.noir-row__label {
  font-size: 0.95vh;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--noir-text-faint);
}
```

Painel (apenas modais/confirmações):

```css
.noir-panel {
  border: 1px solid var(--noir-panel-border);
  border-radius: var(--noir-radius);
  background: var(--noir-panel);
  color: var(--noir-text);
}
```

O ponto de partida é a linha fantasma; transformar tudo em card é antipadrão na v2.

## 21. Checklist de revisão

- [ ] usa os tokens v2 (sem literais espalhados);
- [ ] dimensões em `vh` (ou px justificado em HUD fixo);
- [ ] listas/menus como linhas fantasma com hairline, sem fundo;
- [ ] hover apenas por cor (exceto botões circulares flutuantes);
- [ ] tela cheia com entrada/saída coreografada (stagger + ease-out) quando narrativa;
- [ ] uma única ação primária por contexto;
- [ ] estados de hover, foco, desabilitado e loading;
- [ ] funciona por teclado, com foco visível;
- [ ] não depende apenas de cor ou som;
- [ ] texto legível sobre qualquer cena (gradiente lateral, text-shadow ou painel);
- [ ] destrutivo mais apagado em repouso, vermelho claro no hover;
- [ ] testada em 720p, 1080p, 1440p e ultrawide;
- [ ] trata nomes, traduções e valores longos;
- [ ] confirmação reforçada para ações irreversíveis;
- [ ] respeita HUD e margens seguras;
- [ ] sem Anton, Pricedown ou verde legado;
- [ ] compilada quando o resource carrega arquivos de `dist`.

## 22. Regra para exceções

Uma interface pode sair do padrão quando o universo do recurso exigir identidade própria — celular, terminal policial, painel de veículo. Mesmo nesses casos, mantenha: legibilidade, hierarquia por alpha, escala em `vh`, feedback por cor, navegação por teclado, estados semânticos e safe zone.

Todo token novo ou exceção recorrente deve ser documentado aqui antes de ser replicado em vários resources.

## IMPORTANT — FiveM NUI transparency

All HUD-style NUI pages MUST have a fully transparent document/root
background.

html, body, #root and the top-level application container MUST NOT
define an opaque background.

Only the actual visible UI components may define backgrounds.

Never use a fullscreen black/dark overlay as the application root.

Avoid backdrop-filter on transparent Fullscreen NUI elements because
it may render the game backdrop as black in FiveM.

Default:

html,
body,
#root {
    margin: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
    background: transparent !important;
}
