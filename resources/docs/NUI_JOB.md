# NUI de atividade — especificação visual e de experiência

## 1. Objetivo deste documento

Este documento define como construir uma NUI de atividade compatível com a linguagem visual do Noir State, tomando como referência a janela da central existente em `resources/[standalone]/noir_taxijob/html` e a captura aprovada em 1920 × 1080.

O objetivo **não** é reproduzir o emprego de táxi, suas regras, seus veículos, sua progressão ou seu ranking. O objetivo é preservar o sistema visual e comportamental da interface: composição sobre o mundo do jogo, atmosfera escura e translúcida, hierarquia editorial, navegação, cards, estados, movimento, acessibilidade e integração segura com o FiveM.

Este arquivo deve orientar agentes futuros na criação de NUIs de outras atividades. Sempre separar:

- **invariantes de design**, que mantêm a família visual Noir;
- **tokens temáticos**, que mudam conforme a atividade;
- **módulos de conteúdo**, que só existem quando o produto precisa deles;
- **regras de negócio**, que pertencem ao recurso específico e nunca devem ser inferidas deste guia.

As referências de implementação são:

- `resources/[standalone]/noir_taxijob/html/index.html` — anatomia semântica;
- `resources/[standalone]/noir_taxijob/html/main.css` — tokens, escala, layout e movimento;
- `resources/[standalone]/noir_taxijob/html/app.js` — estados visuais e interação;
- `resources/[standalone]/noir_taxijob/client/ui.lua` — mensagens Lua → NUI;
- `resources/[standalone]/noir_taxijob/client/central.lua` — foco, callbacks e fechamento seguro.

---

## 2. O que é obrigatório e o que é variável

### 2.1. Invariantes da família visual

Toda NUI de atividade baseada neste padrão deve conservar:

1. Uma única janela central escura e translúcida, sobre o mundo ainda reconhecível.
2. Ocupação aproximada de 92% da largura e 90% da altura da viewport, sem encostar nas bordas.
3. Estrutura vertical em três partes: cabeçalho, conteúdo rolável e rodapé discreto.
4. Cabeçalho em três zonas: identidade à esquerda, navegação no centro e perfil/saída à direita.
5. Predomínio de preto, branco translúcido e cinzas; a cor temática aparece com parcimônia.
6. Hierarquia apoiada em tipografia, espaço negativo e hairlines de 1 px — não em caixas pesadas.
7. Tipografia majoritariamente em caixa alta para navegação, rótulos e ações; texto explicativo em peso leve e caixa normal.
8. Um único CTA preenchido por contexto. Ações secundárias são outline ou texto.
9. Cards sóbrios, quase integrados ao fundo, com bordas discretas e mídia recortada em fundo transparente.
10. Estados bloqueados visualmente silenciosos: dessaturação, opacidade menor e ícone de cadeado; nunca uma explosão de cor.
11. Movimento curto, coordenado e funcional.
12. Transparência real no documento NUI: `html`, `body` e raiz nunca devem pintar o fundo da viewport.
13. Navegação completa por mouse e teclado, foco visível e semântica ARIA coerente.
14. O frontend apenas apresenta e solicita ações; o servidor continua autoritativo.

### 2.2. Tokens obrigatoriamente substituíveis

Estes itens devem ser configuráveis por atividade, preferencialmente em um único objeto de tema e em custom properties CSS:

- cor de acento e suas variações;
- ícone da atividade;
- nome da organização ou central;
- contexto/localidade exibida;
- textos institucionais do rodapé;
- nomenclatura da unidade de progressão, caso exista;
- ilustrações e imagens de catálogo;
- labels das abas;
- mensagens e CTAs.

O amarelo da referência é uma extensão temática do táxi. **Não é uma cor global obrigatória do Noir State.** Outra NUI pode usar vermelho queimado, azul frio, verde, cobre ou outra cor adequada, desde que mantenha contraste suficiente e preserve o uso contido descrito neste documento.

### 2.3. Conteúdo opcional

Nenhum dos módulos abaixo é obrigatório só porque existe na referência:

- saudação pelo horário;
- status de turno ou serviço;
- progressão, nível, reputação ou confiança;
- métricas do dia;
- ranking;
- catálogo de veículos, itens, contratos ou missões;
- confirmação de custo;
- informação de item/veículo atualmente em uso.

Troque esses módulos pela informação necessária à atividade. Preserve a gramática visual, não a semântica do táxi.

### 2.4. Regra de adaptação

Antes de implementar, o agente deve responder internamente:

- Qual decisão principal o jogador toma nesta janela?
- Quais duas ou três informações ajudam essa decisão?
- Quais estados impedem a ação?
- Existe conteúdo suficiente para abas ou uma única visão resolve melhor?
- Qual elemento visual representa a atividade sem depender apenas da cor?

Se não houver resposta funcional para uma seção, a seção deve ser removida. Espaço vazio intencional é preferível a métricas fictícias.

---

## 3. Direção estética

### 3.1. Conceito

A direção é **painel operacional cinematográfico, sóbrio e editorial**. A interface parece pertencer ao mundo do jogo, mas não imita um aplicativo genérico, tablet, dashboard SaaS ou HUD futurista. Ela funciona como uma camada de vidro fumê sobre a cena.

Palavras-chave:

- noir;
- institucional;
- contido;
- preciso;
- urbano;
- premium sem luxo ornamental;
- legível sem parecer brilhante;
- integrado à cena, não isolado dela.

### 3.2. Memória visual desejada

O elemento memorável é a relação entre três camadas:

1. o mundo do GTA permanece visível;
2. uma grande lâmina quase preta reduz o ruído da cena;
3. informação clara e econômica flutua em uma grade rigorosa.

Não adicionar blur intenso, glows neon, gradientes coloridos decorativos, glassmorphism leitoso, bordas luminosas ou sombras de cartão de aplicativo. Esses recursos quebram a austeridade da família Noir.

### 3.3. Distribuição de contraste

Use a regra prática:

- 80–90% da superfície em preto/cinza neutro;
- 8–15% em tipografia branca de diferentes opacidades;
- menos de 5% em cor de acento;
- cor semântica de sucesso, alerta ou erro apenas quando o estado existir.

A cor de acento deve orientar, não decorar. Ela é adequada para:

- ícone da marca;
- nome da atividade;
- eyebrow;
- indicador da aba ativa;
- progresso preenchido;
- destaque do item selecionado;
- CTA principal;
- dado realmente prioritário.

Não colorir simultaneamente títulos, todas as bordas, todos os ícones, todos os valores e todos os botões.

---

## 4. Fundação da viewport

### 4.1. Documento transparente

O mundo do jogo é o background. A base mínima deve ser:

```css
html,
body,
#root {
  margin: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: transparent !important;
}

*,
*::before,
*::after {
  box-sizing: border-box;
}
```

Não usar uma imagem estática da cidade como fundo da build de produção. Para desenvolvimento no navegador, uma cena simulada pode existir atrás da raiz, protegida por modo DEV e ausente do build final.

### 4.2. Janela principal

Medida de referência:

```css
.activity-window {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: min(92vw, 176vh);
  height: 90vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
```

Em 1920 × 1080 isso produz aproximadamente 1766 × 972 px, com respiro de cerca de 77 px nas laterais e 54 px em cima e embaixo, como na captura.

O limite em `vh` impede que a janela se torne larga demais em monitores ultrawide. O limite em `vw` mantém margem segura em proporções comuns. Não substituir por uma largura fixa em pixels.

### 4.3. Superfície

Valores de referência:

```css
:root {
  --activity-window: rgba(10, 11, 12, 0.92);
  --activity-panel: rgba(10, 10, 12, 0.88);
  --activity-panel-border: rgba(255, 255, 255, 0.08);
  --activity-radius: 2px;
}

.activity-window {
  background: var(--activity-window);
  border: 1px solid var(--activity-panel-border);
  border-radius: var(--activity-radius);
  box-shadow: 0 2vh 6vh rgba(0, 0, 0, 0.35);
}
```

O alpha `0.92` é proposital: a cena aparece como contexto e textura, mas não disputa leitura. Ajustes aceitáveis ficam aproximadamente entre `0.88` e `0.94`, sempre testados sobre cenas claras, escuras e muito coloridas.

Não aplicar `backdrop-filter` como dependência principal. Além do custo no CEF, um blur pesado destrói a presença do ambiente vista na referência.

### 4.4. Safe area

A janela deve permanecer inteira em 16:9, 16:10, 21:9 e resoluções reduzidas. Nenhum controle essencial pode ocupar os últimos 2% da tela. Em conteúdo alto, apenas o miolo rola; cabeçalho e rodapé permanecem estáveis.

---

## 5. Tokens de design

### 5.1. Neutros

Use os tokens abaixo como ponto de partida. Não espalhe valores RGBA arbitrários pelos componentes.

```css
:root {
  --noir-white: #fff;
  --noir-text-strong: rgba(255, 255, 255, 0.96);
  --noir-text: rgba(255, 255, 255, 0.72);
  --noir-text-dim: rgba(255, 255, 255, 0.50);
  --noir-text-faint: rgba(255, 255, 255, 0.30);
  --noir-text-ghost: rgba(255, 255, 255, 0.15);
  --noir-hairline: rgba(255, 255, 255, 0.06);
  --noir-hairline-hover: rgba(255, 255, 255, 0.18);
  --noir-border: rgba(255, 255, 255, 0.12);
  --noir-border-hover: rgba(255, 255, 255, 0.30);
  --noir-panel: rgba(10, 10, 12, 0.88);
  --noir-panel-border: rgba(255, 255, 255, 0.08);
  --noir-backdrop: rgba(0, 0, 0, 0.50);
  --noir-track: rgba(255, 255, 255, 0.10);
}
```

Hierarquia de texto:

| Token | Função |
|---|---|
| `text-strong` | título, valor primário, nome selecionado |
| `text` | conteúdo normal, item não selecionado |
| `text-dim` | descrição, navegação inativa, status neutro |
| `text-faint` | rótulos, metadados e auxílio |
| `text-ghost` | rodapé e informação de baixíssima prioridade |

### 5.2. Acento temático

Defina uma família, não uma única cor:

```css
:root {
  --activity-accent: #d6a23a;
  --activity-accent-strong: #efbd4f;
  --activity-accent-dim: rgba(214, 162, 58, 0.58);
  --activity-accent-faint: rgba(214, 162, 58, 0.18);
  --activity-accent-hairline: rgba(214, 162, 58, 0.24);
}
```

Ao trocar o tema, gere todas as variantes a partir da mesma matiz e confira:

- texto de acento sobre fundo preto: contraste mínimo de 4.5:1 quando transmite informação;
- botão preenchido: texto escuro com contraste mínimo de 4.5:1;
- bordas de acento não podem ser a única indicação de estado;
- versões `faint` e `hairline` não são adequadas para texto pequeno.

### 5.3. Cores semânticas

As cores semânticas não mudam junto com o tema:

```css
--noir-success: #78a98b;
--noir-warning: #c9a86a;
--noir-danger: #ff8282;
--noir-info: #829bab;
```

Sempre combinar cor com texto, forma, ícone ou atributo de estado. Um ponto verde isolado não basta para jogadores com deficiência de visão cromática.

### 5.4. Bordas e raio

- borda estrutural: 1 px;
- separador/hairline: 1 px com 6% de branco;
- hover: subir para aproximadamente 18% de branco;
- seleção: usar acento com alpha próximo de 55%;
- raio padrão: 2 px;
- barras de progresso e pontos podem ser totalmente arredondados.

Evitar cards com raio de 12–24 px. A geometria quase reta é parte da identidade.

### 5.5. Movimento

```css
--noir-ease-out: cubic-bezier(0.16, 1, 0.3, 1);
--noir-ease-soft: cubic-bezier(0.22, 1, 0.36, 1);
--noir-transition-fast: 150ms var(--noir-ease-out);
--noir-transition: 250ms var(--noir-ease-out);
```

Use `150ms` para hover/foco, `250ms` para mudança de estado, `300ms` para aba/modal e `420ms` para a entrada coordenada da janela.

---

## 6. Tipografia

### 6.1. Famílias e carregamento

A referência empacota fontes localmente para não depender de internet durante o jogo:

- **Plus Jakarta Sans 600**: marca, títulos, números, navegação, rótulos e botões;
- **Inter 300/400**: texto explicativo, descrições e mensagens longas.

Uma NUI nova pode reutilizar essas fontes para manter consistência. Se escolher outras, deve manter a relação “display geométrica semibold + body neutra leve” e empacotar todos os arquivos no recurso.

```css
@font-face {
  font-family: "Plus Jakarta Sans";
  font-style: normal;
  font-weight: 600;
  font-display: swap;
  src: url("fonts/PlusJakartaSans-600.woff2") format("woff2");
}
```

Registrar cada arquivo em `fxmanifest.lua`. Não usar Google Fonts, CDNs ou recursos remotos.

### 6.2. Escala de referência

| Papel | Tamanho aproximado | Peso | Tracking | Caixa |
|---|---:|---:|---:|---|
| saudação/hero | `2.9vh` | 600 | `0.05em` | alta |
| valor grande | `2.3vh` | 600 | `0.02em` | livre |
| título de módulo | `1.9vh` | 600 | `0.08em` | alta |
| título de modal | `1.45vh` | 600 | `0.10em` | alta |
| nome de card | `1.35vh` | 600 | `0.02em` | normal |
| body | `1.15–1.35vh` | 300/400 | normal | sentença |
| navegação | `1.05vh` | 600 | `0.16em` | alta |
| label | `0.8–0.95vh` | 600 | `0.12–0.16em` | alta |
| rodapé | `0.8vh` | 600 | `0.22em` | alta |

Para HUDs pequenos fora do modal, `clamp()` é apropriado. Dentro da janela, unidades em `vh` mantêm a escala ligada à altura do jogo. Adicione mínimos em pixels quando o elemento puder se tornar ilegível.

### 6.3. Regras editoriais

- labels curtos: caixa alta, tracking amplo, opacidade baixa;
- títulos: caixa alta, forte, sem sombra luminosa;
- descrições: caixa normal, peso 300, `line-height` de 1.5 a 1.6;
- números: `font-variant-numeric: tabular-nums`;
- nomes variáveis: uma linha com ellipsis quando não houver espaço;
- textos jamais devem ser reduzidos até caber; truncar ou reorganizar o layout;
- não misturar mais de dois pesos e duas famílias sem necessidade.

---

## 7. Anatomia da janela

```text
activity-menu (viewport transparente)
└── activity-window
    ├── window__header
    │   ├── brand
    │   ├── primary-nav
    │   └── profile + separator + close
    ├── window__main (única região rolável)
    │   ├── seção de resumo/decisão principal (opcional)
    │   ├── seção de estado/progressão (opcional)
    │   ├── seção de catálogo/lista (opcional)
    │   ├── seção alternativa por aba (opcional)
    │   └── estado de erro geral
    └── window__footer

backdrop (irmão da janela, acima dela)
└── confirm-dialog
```

O backdrop de confirmação deve cobrir a viewport, inclusive a janela, e não ficar limitado pelo scroll do conteúdo.

---

## 8. Cabeçalho

### 8.1. Grade

```css
.window__header {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  align-items: center;
  gap: 2.4vh;
  min-height: 7vh;
  padding: 0 3.2vh;
  border-bottom: 1px solid var(--noir-hairline);
}
```

As colunas laterais simétricas mantêm as abas geometricamente centradas, mesmo quando marca e perfil têm larguras diferentes. Não usar `justify-content: space-between` para simular esse efeito.

### 8.2. Identidade à esquerda

A marca contém:

- ícone linear de aproximadamente `2.1vh`;
- nome em acento forte, `1.25vh`, tracking `0.16em`;
- contexto em `0.8vh`, tracking `0.14em`, texto dim.

Preferir SVG inline com `currentColor`, `stroke-width` entre 1.5 e 1.75, cantos simples e sem preenchimentos complexos. O ícone deve comunicar o domínio mesmo com o acento alterado.

Nome e contexto devem truncar com ellipsis. O cabeçalho nunca cresce verticalmente por causa de dados externos.

### 8.3. Navegação central

- usar `nav` com `role="tablist"` quando troca painéis no mesmo documento;
- cada botão usa `role="tab"`, `aria-selected`, `aria-controls` e roving `tabindex`;
- gap de referência: `3.2vh`;
- altura clicável mínima: `4vh`;
- aba inativa: texto dim;
- hover/ativa: branco;
- ativa: linha inferior de 2 px na cor de acento.

Use entre duas e quatro abas. Com apenas um módulo, remova a navegação. Com mais de quatro, reavalie a arquitetura; não comprima labels até ficarem ilegíveis.

### 8.4. Perfil e saída à direita

A zona direita contém:

- nome do jogador ou identidade contextual, alinhado à direita;
- metadado curto abaixo;
- separador vertical de 1 px e `2.6vh`;
- botão textual de fechar com um `<kbd>ESC</kbd>`.

O nome tem largura máxima e ellipsis. O botão fechar precisa funcionar por clique e Escape. O `<kbd>` é visual, mas o texto `FECHAR` torna a ação inequívoca.

---

## 9. Conteúdo principal

### 9.1. Região rolável

```css
.window__main {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 0 3.2vh;
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.25) transparent;
}
```

`min-height: 0` é necessário em filhos flex para o scroll funcionar sem empurrar o rodapé. A scrollbar deve ser fina e neutra. Nunca rolar a página inteira.

### 9.2. Seções

Separe módulos com hairline horizontal e padding vertical de `2.8–3.2vh`. Evite envolver cada módulo em um painel próprio. A grande superfície já é o painel; divisórias e alinhamento fazem a organização.

### 9.3. Resumo/hero

Quando a atividade precisa de uma decisão principal, usar duas colunas:

```css
.activity-hero {
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr);
  align-items: end;
  gap: 4vh;
  padding: 3vh 0 3.2vh;
}
```

Coluna esquerda:

1. eyebrow temática pequena;
2. título ou saudação grande;
3. nota curta em body leve;
4. CTA principal e status adjacente.

Coluna direita:

- até três métricas úteis;
- valores grandes e tabulares;
- separadores verticais entre métricas;
- alinhamento à direita.

Não inventar métricas para preencher o espaço. Se houver uma só, use-a como informação lateral. Se não houver nenhuma, a coluna pode receber contexto operacional ou ser removida com ajuste da grade.

### 9.4. CTA principal e status

O CTA principal deve ter cerca de `24vh × 4.6vh` na referência e largura estável entre estados. Isso evita salto quando o texto muda de “iniciar” para “finalizar” ou “processando”.

Ao lado, um status usa ponto + label:

- neutro: círculo apenas contornado e texto dim;
- ativo/sucesso: círculo preenchido e texto success;
- erro: círculo vermelho e texto danger;
- pendente: texto descritivo e botão bloqueado; não depender de spinner infinito.

### 9.5. Métricas

Cada métrica é uma pilha de label e valor. Use padding lateral de `3vh` e borda esquerda de hairline, exceto no primeiro item. Valores monetários, contadores e posições usam numerais tabulares e não quebram linha.

---

## 10. Módulo de progressão ou estado equivalente

Este módulo é opcional. Pode representar reputação, domínio, licença, capacidade, estoque, risco ou qualquer progressão legítima da atividade.

### 10.1. Layout

```css
.progress-module {
  display: grid;
  grid-template-columns: minmax(0, 1.8fr) minmax(0, 1fr);
  align-items: center;
  gap: 4vh;
  padding: 2.8vh 0 3vh;
  border-top: 1px solid var(--noir-hairline);
}
```

A área principal pode conter um indicador circular, título, barra, fração, próximo marco e restante. A lateral contém um resumo operacional atual, separado por linha vertical.

### 10.2. Anel

- diâmetro externo: `8.6vh`;
- miolo: `6.9vh`;
- preenchimento com `conic-gradient`;
- trilha neutra em 10% de branco;
- valor central na cor de acento forte.

Exemplo genérico:

```js
const pct = Math.max(0, Math.min(100, Number(progress) || 0));
const deg = Math.round(pct * 3.6);
ring.style.background =
  `conic-gradient(var(--activity-accent) 0deg,
   var(--activity-accent) ${deg}deg,
   var(--noir-track) ${deg}deg)`;
```

O anel deve ter `role="img"` com descrição acessível. A barra linear recebe `role="progressbar"`, `aria-valuemin`, `aria-valuemax` e `aria-valuenow`.

### 10.3. Fim da progressão

No nível máximo, não renderizar “faltam 0” ou um próximo nível inexistente. Trocar a fração por um total significativo, anunciar o estado máximo e ocultar o restante.

---

## 11. Catálogos, listas e cards

O card da referência representa veículo, mas o mesmo componente pode representar equipamento, missão, contrato, rota, receita, carga ou opção de serviço.

### 11.1. Grade

```css
.catalog-list {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(24vh, 1fr));
  gap: 1.2vh;
}
```

Com três itens em 16:9, a grade forma três colunas. Com menos espaço, `auto-fit` reorganiza. Não definir três colunas fixas sem fallback.

### 11.2. Anatomia do card

Ordem recomendada:

1. status ou requisito;
2. mídia/ilustração;
3. nome + chevron;
4. descrição;
5. metadado/preço opcional;
6. ação secundária ou contextual.

Medidas de referência:

- padding: `1.2vh 1.4vh 1.4vh`;
- gap interno: `0.8vh`;
- mídia compacta: `12vh`;
- mídia na aba dedicada: `20vh`;
- fundo: branco com alpha de `0.015`;
- borda: hairline;
- raio: 2 px.

### 11.3. Imagens

- usar PNG/WebP com fundo transparente e recorte limpo;
- `object-fit: contain`;
- limitar a aproximadamente 92% da largura e 88% da altura da área;
- sombra apenas na imagem: `drop-shadow(0 4px 10px rgba(0,0,0,.6))`;
- fornecer fallback SVG quando o arquivo não existe ou falha;
- textos alternativos só quando a imagem acrescenta informação; se o nome já estiver imediatamente presente, avaliar `alt=""` para evitar duplicidade.

Não usar screenshots retangulares sem tratamento dentro de cards translúcidos.

### 11.4. Estados do card

| Estado | Tratamento visual | Comportamento |
|---|---|---|
| disponível | mídia normal, ponto semântico | selecionável e acionável |
| hover | borda 18% branca, fundo 2.5% branco | cursor pointer |
| selecionado | borda do acento ~55%, chevron em acento | `aria-selected="true"`, `tabindex="0"` |
| bloqueado | cadeado, mídia a 45%, saturação 40% | ação desabilitada e requisito textual |
| em uso/ativo | status em acento ou success | ação adequada ao domínio |
| indisponível | status ghost, CTA desativado | explica indisponibilidade |
| pendente | CTA a 70%, sem eventos repetidos | mantém label de processo |
| imagem ausente | SVG fallback | layout preservado |

O card selecionado não deve ficar preenchido com a cor temática. A indicação é refinada: borda, leve sombra interna e chevron.

### 11.5. Ação interna

A ação de cada card é outline em acento, não preenchida. O preenchimento pertence ao CTA principal da página. Cards indisponíveis usam `disabled`, `aria-disabled="true"` e texto que explica o requisito.

### 11.6. Seleção por teclado

Aplicar padrão listbox:

- container: `role="listbox"` e nome acessível;
- card: `role="option"`;
- apenas o selecionado tem `tabindex="0"`;
- demais itens têm `tabindex="-1"`;
- setas movem a seleção;
- Enter executa ou abre confirmação;
- foco acompanha seleção iniciada pelo teclado.

Se os cards contiverem muitos controles independentes, não usar `listbox`; use lista semântica com botões. Não misturar padrões ARIA incompatíveis.

---

## 12. Listas competitivas ou tabulares

Ranking é opcional. Quando existir uma lista comparativa, evitar tabela pesada com cabeçalho colorido e células encaixotadas. A referência usa linhas editoriais:

```css
.data-row {
  display: grid;
  grid-template-columns: 2.8vh minmax(0, 1fr) 7vh 6vh 9vh;
  align-items: baseline;
  gap: 1.2vh;
  min-height: 4vh;
  padding: 0.9vh 0;
  border-bottom: 1px solid var(--noir-hairline);
}
```

Princípios:

- coluna de nome absorve espaço e trunca;
- números têm largura previsível e alinhamento à direita;
- metadados usam caixa alta e texto faint;
- primeiras posições ganham hierarquia tipográfica, não medalhas enormes;
- o primeiro item pode usar o acento;
- a linha do próprio jogador fica separada e identificada;
- estado vazio e erro aparecem no mesmo lugar da lista;
- horário de atualização é ghost e não compete com os dados.

Em dados realmente tabulares, usar `<table>` semanticamente e reproduzir a mesma estética. Não sacrificar semântica para copiar a grade CSS.

---

## 13. Botões e ações

### 13.1. Base

```css
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 4vh;
  padding: 0.9vh 2.2vh;
  border: 1px solid var(--noir-border);
  border-radius: 2px;
  background: transparent;
  font: inherit;
  font-size: 1.15vh;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--noir-text-strong);
}
```

### 13.2. Hierarquia

1. **Primário preenchido:** uma decisão dominante; fundo em acento e texto quase preto.
2. **Primário outline:** ação importante dentro de card ou modal; borda/acento, sem fundo.
3. **Secundário neutro:** cancelar, voltar, tentar novamente.
4. **Textual:** fechar ou navegação.

Não exibir dois botões preenchidos lado a lado. Em modal, confirmação pode ser outline em acento para não criar um segundo grande bloco colorido sobre a página.

### 13.3. Estados

- hover: aumentar contraste da borda ou do acento;
- focus-visible: outline branco de 1 px com offset de 3 px;
- disabled: opacidade aproximada de 0.32–0.45, cursor `not-allowed`;
- pending: texto de processo, cursor `progress`, bloqueio contra repetição;
- sucesso: mensagem adjacente; não deixar botão verde permanentemente;
- erro: manter contexto e permitir nova tentativa quando seguro.

---

## 14. Modal de confirmação

Use confirmação apenas para custo, consequência irreversível ou ação que mereça revisão. A seleção comum não precisa de modal.

### 14.1. Backdrop

```css
.modal-backdrop {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.50);
}
```

O background adicional reduz a janela sem apagá-la. Não usar blur.

### 14.2. Caixa

- largura máxima: `42vh`;
- padding: `3vh 3.5vh`;
- fundo: painel a 88%;
- borda: 8% branca;
- raio: 2 px;
- texto centralizado;
- título em `1.45vh`, uppercase e tracking `0.10em`;
- descrição em `1.35vh`, peso 300, `line-height: 1.6`;
- ações centralizadas com gap de `1vh`.

### 14.3. Comportamento

- `role="dialog"` e `aria-modal="true"`;
- `aria-labelledby` aponta para o título;
- ao abrir, foco vai para cancelar/voltar, que é a opção segura;
- Escape fecha somente o modal, não a janela por trás;
- enquanto aberto, navegação e atalhos da página ficam suspensos;
- ao fechar, foco retorna ao item que abriu o modal;
- confirmar bloqueia novas submissões até resposta;
- o texto deve nomear o item e a consequência, incluindo valores formatados quando aplicável.

Para implementação completa, manter o foco preso dentro do diálogo. A referência move o foco inicial e suspende atalhos, mas novas NUIs devem também implementar focus trap quando houver mais elementos focáveis na página.

---

## 15. Estados que toda NUI deve projetar

Não entregar somente a tela populada. Para cada módulo assíncrono, definir:

### 15.1. Fechado

- raiz ou menu com `hidden`;
- nenhum foco NUI retido;
- nenhum listener/timer causando trabalho visual desnecessário.

### 15.2. Abrindo

- superfície entra por fade;
- conteúdo aparece em stagger curto;
- interação só fica disponível quando os dados mínimos existem;
- foco inicial vai para a primeira aba ou ação mais adequada.

### 15.3. Carregando

A referência oculta valores com blocos neutros estáticos. O padrão evita spinners eternos:

```css
[data-status="loading"] .skeleton-value {
  color: transparent;
  background: rgba(255,255,255,.08);
  border-radius: 2px;
  text-shadow: none;
}
```

Skeleton deve aproximar o tamanho final para não causar layout shift. Listas podem mostrar “CARREGANDO” em label discreto. Não usar shimmer chamativo.

### 15.4. Vazio

- explicar que não há itens;
- se houver ação possível, indicar o próximo passo;
- preservar a geometria do módulo;
- nunca mostrar `undefined`, array vazio serializado ou espaço sem contexto.

### 15.5. Bloqueado/indisponível

- explicar requisito ou motivo;
- usar cadeado ou status textual;
- manter item reconhecível, porém dessaturado;
- não enviar callback quando a ação está desabilitada.

### 15.6. Pendente

- bloquear repetição no frontend;
- texto do CTA muda para verbo contínuo, por exemplo “PROCESSANDO”; 
- backend também bloqueia concorrência;
- a janela não pode ser fechada no meio de uma transação crítica sem regra explícita.

### 15.7. Sucesso

- atualizar snapshot local somente com resposta confirmada;
- mensagem curta em success;
- quando a consequência fecha a janela, permitir breve confirmação visual antes da saída;
- nunca assumir sucesso porque o fetch foi enviado.

### 15.8. Erro recuperável

- mensagem próxima da ação que falhou;
- linguagem direta e sem código interno;
- botão/ação volta ao estado utilizável;
- manter seleção e contexto.

### 15.9. Erro de bootstrap

- ocultar módulos que dependeriam de dados incompletos;
- mostrar mensagem principal com `TENTAR NOVAMENTE`;
- manter cabeçalho e forma da janela para evitar sensação de quebra total;
- limitar novas tentativas no cliente e no servidor.

### 15.10. Sessão expirada

- impedir ações subsequentes;
- instruir o jogador a reabrir/interagir novamente;
- liberar foco com segurança se o fluxo exigir fechamento.

### 15.11. Fechando

- bloquear novas ações;
- executar animação curta;
- avisar o client quando a animação terminou;
- possuir timeout de segurança no Lua para liberar foco mesmo se o browser travar.

---

## 16. Movimento e microinteração

### 16.1. Entrada

A referência usa dois níveis:

- janela: fade de `420ms`;
- cabeçalho, conteúdo e rodapé: subida de `1vh` + fade, com `60ms` de stagger.

```css
[data-anim="enter"] .activity-window {
  animation: menu-fade-in 420ms var(--noir-ease-out) both;
}

[data-anim="enter"] .menu-fx {
  animation: menu-rise 420ms var(--noir-ease-out) both;
  animation-delay: calc(var(--i) * 60ms);
}
```

Não anime o `transform: translate(-50%, -50%)` da própria janela; isso costuma sobrescrever a centralização. Anime a opacidade da janela e o transform de filhos.

### 16.2. Saída

- fade/sink de aproximadamente `240ms`;
- liberar foco após confirmação de fim da animação;
- timeout Lua recomendado: aproximadamente `1200ms` como fallback.

### 16.3. Troca de aba

- fade + subida de `0.6vh` em `300ms`;
- reiniciar a animação somente no painel que ficou visível;
- não animar toda a janela novamente;
- evitar slides horizontais longos, que parecem carrossel.

### 16.4. Modal

- backdrop: fade de `300ms`;
- caixa: fade + subida de `1.2vh` em `300ms`;
- nada de bounce, spring ou escala exagerada.

### 16.5. Redução de movimento

Obrigatório:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-delay: 0ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

O JavaScript também deve respeitar `matchMedia("(prefers-reduced-motion: reduce)")` ao agendar timeouts puramente visuais.

---

## 17. Responsividade

### 17.1. Estratégia

O layout é desenhado para jogo em desktop, mas não pode presumir apenas 1920 × 1080. Testar no mínimo:

- 1280 × 720;
- 1366 × 768;
- 1600 × 900;
- 1920 × 1080;
- 2560 × 1440;
- 3440 × 1440.

### 17.2. Pouca altura

Em viewport com até `819px` de altura:

- reduzir paddings verticais do hero e seções;
- reduzir margem do CTA;
- mídia de card compacta de `12vh` para `10vh`;
- mídia da visão focada de `20vh` para `17vh`;
- preservar tamanho mínimo dos controles.

### 17.3. Largura limitada

Adicionar breakpoint próprio quando a grade de três zonas do cabeçalho deixar de caber. Ordem recomendada:

1. reduzir gaps;
2. limitar mais agressivamente nomes variáveis;
3. reduzir número de métricas por linha;
4. mover navegação para uma segunda linha interna do cabeçalho;
5. em último caso, transformar cards em uma coluna.

Não esconder o botão de fechar nem reduzir fontes abaixo do legível.

### 17.4. Ultrawide

Manter o limite `176vh`. O conteúdo não deve atravessar toda a largura de uma tela 21:9; linhas longas e cards excessivamente largos perdem a composição editorial.

### 17.5. Conteúdo internacionalizado

Mesmo em uma interface inicialmente pt-BR:

- reservar espaço para labels 30–40% maiores;
- usar ellipsis em nomes, nunca em mensagens críticas;
- permitir quebra em body e alertas quando necessário;
- não concatenar frases que deveriam vir completas da locale;
- usar `Intl.NumberFormat`/`toLocaleString` para números e valores.

---

## 18. Acessibilidade e teclado

### 18.1. Foco

Todo elemento interativo deve ter foco visível:

```css
button:focus-visible,
[role="option"]:focus-visible {
  outline: 1px solid rgba(255,255,255,.70);
  outline-offset: 3px;
}
```

Não remover `outline` sem substituto. Quando o modal fecha, devolver foco ao acionador. Quando a janela abre, focar a aba ativa ou ação inicial lógica.

### 18.2. Teclas mínimas

- Escape: fecha modal; sem modal, solicita fechamento da NUI;
- setas esquerda/direita: percorrem abas quando apropriado;
- setas cima/baixo: percorrem opções em listbox;
- Enter/Espaço: ativa controle focado;
- Tab/Shift+Tab: percorrem ações na ordem visual.

Atalhos do jogo não devem disparar ações por trás da NUI com foco.

### 18.3. Semântica

- usar `header`, `nav`, `main`, `section`, `aside` e `footer`;
- títulos em ordem lógica (`h1`, depois `h2`);
- `hidden` para painéis inativos;
- `role="tabpanel"` com `aria-labelledby`;
- alertas críticos com `role="alert"`;
- retornos assíncronos não críticos com `role="status"` ou região `aria-live="polite"`;
- imagens decorativas com `aria-hidden`/`alt=""`;
- ícones nunca substituem labels essenciais.

### 18.4. Contraste sobre o mundo

Testar a janela sobre:

- céu claro;
- fachada branca;
- cena noturna;
- iluminação vermelha/azul intensa;
- interior escuro;
- fundo visualmente complexo.

Se o body text perder leitura, aumente a opacidade da janela antes de tornar todo texto branco puro.

---

## 19. Arquitetura frontend recomendada

A estética independe de framework. Pode ser HTML/CSS/JS, React, Vue ou outra stack já adotada no recurso. Para interfaces pequenas, vanilla reduz build e dependências. Para muitas telas/estados, componentes podem justificar framework.

Independentemente da stack, separar:

1. **tokens e tema**;
2. **estrutura semântica**;
3. **renderização derivada de estado**;
4. **bridge NUI**;
5. **formatação/localização**;
6. **eventos de interação**.

Não misturar regra de pagamento, progressão, permissão ou unlock dentro do CSS/HTML. O browser recebe um snapshot pronto para apresentar.

### 19.1. Estado explícito

Evitar combinações soltas de booleanos como `isOpen`, `isLoading`, `isSubmitting`, `hasError` que podem formar estados impossíveis. Use uma máquina simples:

```js
const ui = {
  lifecycle: "closed", // closed | opening | ready | submitting | closing | error
  activeTab: "overview",
  selectedId: null,
  modal: null,
  data: null,
};
```

O DOM pode refletir estados em `data-*`:

```html
<div class="activity-menu" data-anim="enter" data-status="ready">
```

Isso permite que CSS cuide de apresentação sem espalhar classes imperativas.

### 19.2. Renderização segura

- inserir dados externos com `textContent`;
- usar `innerHTML` apenas para templates controlados e constantes locais, como SVGs próprios;
- validar arrays e números antes de renderizar;
- aplicar limites e fallbacks;
- nunca montar URL de asset ou HTML arbitrário vindo do client sem allowlist.

---

## 20. Contrato FiveM/NUI

### 20.1. Manifest

Estrutura mínima:

```lua
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/fonts/*.woff2',
    'html/img/**/*',
    'locales/*.json',
}
```

Todos os assets usados em runtime precisam constar em `files`. Não assumir que uma imagem existe no CEF porque funciona no navegador local.

### 20.2. Envelope Lua → NUI

Padronizar:

```lua
SendNUIMessage({
    action = 'activityMenu:open',
    data = payload,
})
```

O frontend mantém um mapa fechado de handlers:

```js
const handlers = {
  "activityMenu:open": openMenu,
  "activityMenu:close": closeMenu,
  "activityMenu:update": applySnapshot,
};

window.addEventListener("message", (event) => {
  const msg = event.data || {};
  const handler = handlers[msg.action];
  if (handler) handler(msg.data);
});
```

Não usar `eval`, dispatch dinâmico em propriedades globais ou ações sem namespace.

### 20.3. NUI → Lua

```js
const resource = typeof GetParentResourceName === "function"
  ? GetParentResourceName()
  : "resource_dev_fallback";

function post(name, body = {}) {
  return fetch(`https://${resource}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(body),
  }).then((r) => r.json());
}
```

Cada `RegisterNUICallback` deve chamar `cb` em todos os caminhos, inclusive erro, estado inválido e exceção tratada. Uma Promise pendurada deixa a interface sem resposta.

### 20.4. Snapshot de abertura

A mensagem de abertura deve trazer tudo que a primeira renderização precisa, por exemplo:

```json
{
  "sessionId": "opaque-server-token",
  "serverTime": 0,
  "theme": {
    "brand": "NOME DA ATIVIDADE",
    "context": "UNIDADE · LOCAL",
    "accent": "activity-theme-key"
  },
  "profile": {
    "displayName": "Nome",
    "metaLabel": "STATUS OU NÍVEL"
  },
  "summary": {},
  "sections": [],
  "items": [],
  "activeItemId": null,
  "capabilities": {
    "canStart": true,
    "canFinish": false
  }
}
```

Esse é um formato ilustrativo, não um schema obrigatório. O importante é:

- frontend não adivinha permissões;
- itens já chegam com estado apresentável (`available`, `locked`, `unavailable`, `active`);
- IDs são opacos;
- valores de negócio continuam validados no servidor;
- labels podem vir da locale/configuração do recurso.

### 20.5. Payload mínimo nas ações

O browser envia intenção e identificador, não dados autoritativos:

```json
{ "itemId": "standard" }
```

Nunca confiar em preço, recompensa, requisito, modelo, permissão, posição ou resultado enviados pelo browser. O servidor resolve esses dados por ID, valida distância/sessão/estado, executa a ação e devolve resposta explícita.

### 20.6. Respostas consistentes

Usar um envelope previsível:

```json
{ "ok": true, "data": {} }
```

ou:

```json
{ "ok": false, "code": "invalid_session" }
```

Mapear `code` para texto localizado no client/NUI; não expor stack trace, SQL ou mensagem interna.

---

## 21. Foco e ciclo de vida

### 21.1. Abertura

Fluxo recomendado:

1. jogador interage com ponto autorizado;
2. client verifica condições locais baratas;
3. servidor autoriza e retorna snapshot + sessão;
4. client chama `SetNuiFocus(true, true)`;
5. client envia `activityMenu:open`;
6. NUI renderiza e move foco para controle inicial.

Não abrir a janela de forma otimista antes da autorização quando isso cria flash de conteúdo ou permite ações inválidas.

### 21.2. Fechamento animado seguro

Fluxo recomendado:

1. Escape/botão envia `closeMenu`;
2. Lua verifica se a UI pode fechar;
3. NUI entra em `closing` e anima por cerca de 240ms;
4. NUI envia `closeComplete`;
5. Lua executa `SetNuiFocus(false, false)` e limpa a sessão visual;
6. timeout local libera foco se `closeComplete` nunca chegar.

Fechamentos por morte, unload, entrada em veículo, afastamento ou stop do resource devem ser imediatos e idempotentes.

### 21.3. Princípios

- função `forceClose()` pode ser chamada mais de uma vez sem efeitos colaterais;
- toda saída limpa timers, modal, dados e seleção transitória;
- HUD sem foco, se existir, fica oculto enquanto o menu com foco estiver aberto;
- `onResourceStop` sempre libera foco;
- não manter loop de distância permanente; rodar apenas durante a janela aberta;
- transação crítica pode bloquear fechamento, mas deve terminar ou expirar.

### 21.4. Prontidão da página

A NUI deve avisar `uiReady` depois de registrar handlers. O client então reenvia visibilidade e snapshot atuais. Isso cobre reload do CEF e ordem de inicialização sem depender de timing acidental.

---

## 22. Localização e formatação

Não espalhar frases no JavaScript de produção quando o recurso já usa locales. Definir chaves para:

- abas;
- labels;
- ações;
- estados;
- mensagens de erro;
- vazio;
- confirmações;
- unidades.

Para pt-BR:

```js
const formatInt = (value) =>
  Math.floor(Number(value) || 0).toLocaleString("pt-BR");

const formatMoney = (value) =>
  "$" + (Number(value) || 0).toLocaleString("pt-BR", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
```

Definir conscientemente se a moeda do roleplay usa `$`, `$ 1.000`, `$1.000` ou casas decimais. Manter o padrão em toda a NUI.

Horários relativos calculados no browser devem usar `serverTime` + tempo desde a abertura para reduzir divergência do relógio local.

---

## 23. Assets e iconografia

### 23.1. Ícones

- preferir SVG inline controlado pelo projeto;
- traço uniforme entre 1.5 e 1.75;
- `fill="none"`, `stroke="currentColor"` quando possível;
- tamanho coerente com o texto;
- evitar emojis como ícone principal da janela;
- não misturar bibliotecas com estilos incompatíveis.

### 23.2. Mídia temática

Cada atividade deve possuir uma assinatura visual além da cor: silhueta, ferramenta, documento, veículo, emblema ou objeto do mundo. Mantenha recortes realistas e discretos. A mídia deve ajudar reconhecimento, não transformar o modal em uma vitrine publicitária.

### 23.3. Organização sugerida

```text
html/
├── index.html
├── main.css
├── app.js
├── fonts/
│   ├── Display-600.woff2
│   └── Body-300.woff2
└── img/
    ├── icons/
    └── items/
```

Remover arquivos sem uso do manifest. Otimizar imagens antes de incluir no recurso.

---

## 24. Performance no CEF

- nenhuma dependência remota;
- evitar blur grande, filtros encadeados e sombras em muitas camadas;
- não animar propriedades de layout continuamente;
- usar `transform` e `opacity` em entrada/saída;
- marcar `will-change` apenas durante ou nos poucos elementos realmente animados;
- limpar `setTimeout`, `setInterval` e listeners transitórios ao fechar;
- atualizar somente o valor que mudou em mensagens frequentes;
- usar snapshot completo na abertura e updates incrementais quando necessário;
- não recriar listas grandes a cada tick;
- limitar imagens às dimensões reais necessárias;
- testar com profiler do CEF quando houver vídeo, filtros ou listas extensas.

Uma NUI de menu não precisa renderizar a 60 FPS enquanto está estática. Não criar loops de `requestAnimationFrame` sem motivo visual claro.

---

## 25. Segurança e autoridade

Design e segurança se encontram nos estados da interface, mas a UI nunca é a barreira de segurança.

Obrigatório no servidor:

- validar sessão;
- validar proximidade/contexto;
- validar identificador em allowlist;
- validar requisito, custo e saldo;
- validar estado atual e concorrência;
- aplicar rate limit;
- calcular recompensa e progressão;
- devolver códigos de erro estáveis;
- não confiar em campos escondidos ou botões disabled.

Obrigatório no frontend:

- bloquear repetição para boa UX;
- enviar somente IDs e intenções;
- escapar conteúdo por `textContent`;
- tratar resposta nula/falha de rede;
- não exibir segredo, token reutilizável ou dado interno desnecessário;
- não permitir que `message` arbitrária execute código fora do mapa de handlers.

---

## 26. Anti-padrões

Uma implementação está fora do padrão se fizer qualquer um destes sem justificativa de produto:

- fundo opaco que esconde completamente o mundo;
- janela encostada nas bordas ou painel pequeno tipo celular;
- muitos cards elevados, arredondados e com sombras individuais;
- roxo/azul em gradiente genérico ou neon sem relação com a atividade;
- cor temática usada como fundo de grandes áreas;
- todos os botões preenchidos;
- fonte de sistema ou CDN sem controle;
- cabeçalho desalinhado porque usa apenas `space-between`;
- navegação ativa marcada só pela cor do texto;
- fonte minúscula sem tracking/contraste adequado;
- loading infinito ou shimmer agressivo;
- animações spring/bounce, parallax ou escalas grandes;
- modal sem retorno de foco;
- Escape liberando foco antes de a janela fechar;
- callback que não chama `cb` em algum caminho;
- frontend calculando preço, permissão, rank, recompensa ou requisito;
- conteúdo de táxi copiado para uma atividade sem relação;
- seção vazia mantida só para imitar a captura;
- imagem quebrada colapsando o card;
- usar apenas cor para comunicar disponível/bloqueado/erro;
- ausência de estado de erro, vazio ou sessão expirada.

---

## 27. Processo de construção para agentes futuros

### Etapa 1 — investigar o recurso

- localizar `fxmanifest.lua`, HTML, CSS, JS/TS e bridge Lua;
- mapear como a interface abre e fecha;
- listar mensagens Lua → NUI e callbacks NUI → Lua;
- identificar dados autoritativos e ações críticas;
- procurar assets e fontes já aprovados;
- verificar instruções `AGENTS.md` aplicáveis.

### Etapa 2 — modelar a experiência

- escrever a decisão principal da tela em uma frase;
- listar módulos realmente necessários;
- separar conteúdo obrigatório de opcional;
- desenhar estados de cada ação;
- definir primeiro foco e fluxo de Escape;
- definir qual parte muda por tema.

### Etapa 3 — definir tema

- escolher acento coerente com a atividade;
- gerar variantes strong/dim/faint/hairline;
- escolher ícone e assinatura visual;
- validar contraste sobre `#0a0b0c`;
- manter cores semânticas independentes.

### Etapa 4 — construir shell

- documento transparente;
- janela `min(92vw, 176vh) × 90vh`;
- header de três colunas;
- main rolável;
- footer fixo;
- tokens centralizados.

### Etapa 5 — construir módulos

- semântica antes do acabamento;
- hero apenas se houver ação principal;
- cards apenas para escolhas comparáveis;
- tabelas/listas conforme natureza dos dados;
- modal apenas para consequência relevante;
- fallbacks de imagem e conteúdo.

### Etapa 6 — conectar estado

- snapshot completo na abertura;
- máquina de lifecycle explícita;
- handlers de mensagem allowlisted;
- callbacks sempre respondidos;
- estados loading/empty/error/disabled/pending/success;
- servidor autoritativo.

### Etapa 7 — teclado e foco

- roving tabindex em tabs/listbox;
- Escape em camadas;
- foco inicial;
- retorno de foco do modal;
- focus trap;
- focus-visible.

### Etapa 8 — movimento

- entrada coordenada;
- aba curta;
- saída com handshake;
- timeout de foco;
- reduced motion.

### Etapa 9 — validação visual

- testar todas as resoluções da seção 17;
- testar sobre cinco tipos de cena;
- testar textos longos e arrays vazios;
- testar item bloqueado e imagem ausente;
- testar com 1, 2, 3, 6 e muitos cards;
- testar scroll sem mover header/footer;
- testar contraste, foco e navegação sem mouse.

### Etapa 10 — validação técnica

- conferir assets no manifest;
- testar reload da NUI e `uiReady`;
- testar fechamento normal e forçado;
- simular timeout/erro do callback;
- verificar rate limit e concorrência no servidor;
- confirmar que o browser envia apenas IDs/intenção;
- verificar limpeza no `onResourceStop`.

---

## 28. Checklist de aceite

### Visual

- [ ] O mundo permanece visível e reconhecível atrás da janela.
- [ ] A janela ocupa aproximadamente 92vw × 90vh e está centralizada.
- [ ] A largura possui limite por altura para ultrawide.
- [ ] Header, main e footer têm hierarquia clara.
- [ ] O header usa grade de três zonas e a navegação está geometricamente centrada.
- [ ] Há apenas uma cor de acento temática dominante.
- [ ] O acento ocupa pequena parte da superfície.
- [ ] Texto usa pelo menos quatro níveis de contraste intencionais.
- [ ] Divisórias são hairlines de 1 px.
- [ ] Raio padrão é mínimo, próximo de 2 px.
- [ ] Existe no máximo um CTA preenchido no contexto principal.
- [ ] Cards selecionados usam borda/chevron, não grande preenchimento.
- [ ] Bloqueados possuem ícone + texto + redução visual.
- [ ] Imagens têm fundo transparente, contain e fallback.
- [ ] Não existem glows neon, blur pesado ou gradientes decorativos genéricos.

### Conteúdo

- [ ] A NUI contém somente módulos pertinentes à nova atividade.
- [ ] Nenhum texto, rank, veículo ou regra do táxi foi copiado sem necessidade.
- [ ] Marca, contexto, acento, ícone e labels são configuráveis.
- [ ] Nomes longos truncam sem quebrar o cabeçalho.
- [ ] Mensagens críticas podem quebrar linha e continuam legíveis.
- [ ] Números usam formatação local e algarismos tabulares.

### Estados

- [ ] Fechado, abrindo, pronto e fechando estão definidos.
- [ ] Loading não causa layout shift importante.
- [ ] Vazio possui explicação útil.
- [ ] Bloqueado e indisponível explicam o motivo.
- [ ] Pendente impede clique repetido.
- [ ] Sucesso depende de confirmação real.
- [ ] Erro recuperável preserva contexto.
- [ ] Erro de bootstrap oferece retry controlado.
- [ ] Sessão expirada bloqueia novas ações.
- [ ] Imagem ausente não quebra card.

### Interação e acessibilidade

- [ ] Todos os controles funcionam por teclado.
- [ ] Escape respeita a pilha modal → janela.
- [ ] Tabs possuem ARIA e roving tabindex.
- [ ] Lista de opções usa padrão semântico adequado.
- [ ] Foco visível nunca foi removido.
- [ ] Modal recebe foco, prende foco e o devolve ao acionador.
- [ ] Status e alertas possuem regiões acessíveis apropriadas.
- [ ] Cor nunca é o único canal de informação.
- [ ] Reduced motion está implementado no CSS e respeitado no JS.

### FiveM e segurança

- [ ] `html`, `body` e raiz são transparentes.
- [ ] Todos os assets constam no `fxmanifest.lua`.
- [ ] Ações Lua → NUI usam `{ action, data }` e namespace do recurso.
- [ ] Handlers do browser são allowlisted.
- [ ] Todo callback Lua chama `cb` em todos os caminhos.
- [ ] Browser envia apenas intenção e IDs opacos.
- [ ] Servidor recalcula e valida toda regra de negócio.
- [ ] Abertura depende de autorização/snapshot válido.
- [ ] Fechamento animado possui `closeComplete` e timeout de segurança.
- [ ] Fechamento forçado e `onResourceStop` liberam foco.
- [ ] `uiReady` permite reidratar estado após reload.
- [ ] Timers e estado transitório são limpos ao fechar.

### Testes

- [ ] Validado em 720p, 768p, 900p, 1080p, 1440p e ultrawide.
- [ ] Validado sobre fundos claros, escuros, coloridos e complexos.
- [ ] Validado com conteúdo mínimo, máximo e textos longos.
- [ ] Validado somente com teclado.
- [ ] Validado com falha e demora do backend.
- [ ] Validado abrindo/fechando repetidamente sem foco preso.

---

## 29. Resumo normativo

Ao criar uma nova NUI de atividade, copie a **linguagem**, não a tela do táxi:

- janela ampla, escura e translúcida;
- composição editorial em header, main e footer;
- marca à esquerda, abas ao centro, perfil/saída à direita;
- tipografia precisa e local, labels espaçados, body leve;
- neutros dominantes e acento substituível usado com disciplina;
- módulos separados por espaço e hairlines;
- cards discretos com mídia recortada e estados completos;
- um CTA preenchido;
- modais pequenos e sóbrios;
- movimento curto e coordenado;
- teclado, foco, ARIA e reduced motion;
- snapshot autoritativo, callbacks seguros e fechamento que nunca prende o foco.

Se uma decisão visual não estiver coberta aqui, escolher a opção mais silenciosa, alinhada e funcional. A interface deve parecer parte do Noir State antes de parecer parte de qualquer emprego específico.
