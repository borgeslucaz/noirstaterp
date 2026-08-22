# Guia de design de interfaces — Noir State RP

> Padrão visual para novas NUIs, menus, notificações, confirmações e outros componentes do servidor. A referência principal é a seleção de personagens atual em `[bgrz]/noir_multichar/ui/src/components/charDetails`.

## 1. Direção visual

O padrão Noir é sóbrio, cinematográfico e funcional. A interface deve complementar a cena do jogo, sem parecer um painel web genérico nem competir com o personagem e o ambiente.

Princípios:

- superfícies escuras e translúcidas, preservando o contexto do jogo;
- branco quente para conteúdo e tons de branco com opacidade para hierarquia;
- composição limpa, com poucos elementos simultâneos;
- bordas finas, cantos discretos e quase nenhuma sombra;
- títulos fortes e textos auxiliares em caixa alta com espaçamento entre letras;
- animações curtas e silenciosas visualmente;
- cor semântica somente quando ela comunica estado, risco ou resultado.

Evite gradientes coloridos, neon, glow intenso, sombras pesadas, blur excessivo, bordas muito arredondadas e excesso de ícones. Esses recursos descaracterizam o estilo Noir.

## 2. Fonte de verdade

Para novas interfaces, considere `charDetails.css` a referência visual canônica. A configuração Tailwind ainda contém valores legados, como `primary: #88cfcd`, além das fontes Anton e Pricedown. Eles não fazem parte do padrão principal da seleção atual e não devem ser usados automaticamente em novos componentes.

A fonte padrão é:

```css
font-family: Inter, "Helvetica Neue", Arial, sans-serif;
```

Use uma fonte display apenas quando o contexto exigir identidade específica, nunca em textos longos, formulários, notificações ou dados operacionais.

## 3. Tokens fundamentais

Todo novo frontend deve centralizar os valores abaixo. Quando possível, importe um arquivo compartilhado ou replique os nomes, em vez de espalhar cores literais pelos componentes.

```css
:root {
  /* Texto */
  --noir-white: #f3f3f1;
  --noir-text: rgba(243, 243, 241, 0.96);
  --noir-muted: rgba(243, 243, 241, 0.56);
  --noir-subtle: rgba(243, 243, 241, 0.32);

  /* Estrutura */
  --noir-border: rgba(255, 255, 255, 0.24);
  --noir-border-hover: rgba(255, 255, 255, 0.48);
  --noir-surface: rgba(7, 9, 11, 0.48);
  --noir-surface-hover: rgba(7, 9, 11, 0.70);
  --noir-backdrop: rgba(2, 4, 6, 0.70);

  /* Estados */
  --noir-success: #78a98b;
  --noir-warning: #c9a86a;
  --noir-danger: #c85a5a;
  --noir-info: #829bab;

  /* Forma e movimento */
  --noir-radius: 2px;
  --noir-transition-fast: 160ms ease;
  --noir-transition: 180ms ease;
}
```

As cores de sucesso, alerta e informação são extensões semânticas do padrão. Use-as com moderação em ícone, filete, indicador ou texto curto; não pinte componentes inteiros sem necessidade.

## 4. Hierarquia tipográfica

| Uso | Tamanho recomendado | Peso | Tratamento |
|---|---:|---:|---|
| Título de tela | `32–48px` | `650` | tracking negativo leve |
| Título de modal | `22–32px` | `650` | frase curta |
| Título de item | `13–16px` | `600–650` | tracking de `.04em–.06em` |
| Corpo | `13–16px` | `400–500` | caixa normal |
| Label | `10–12px` | `500–600` | caixa alta, tracking de `.12em–.18em` |
| Ajuda/metadado | `9–12px` | `400–500` | cor muted |

Caixa alta funciona bem para labels, ações curtas e metadados. Não use caixa alta em parágrafos, erros explicativos ou mensagens longas: isso reduz a leitura.

Valores numéricos que mudam ou se alinham em colunas devem usar `font-variant-numeric: tabular-nums`.

## 5. Espaçamento e composição

Use uma escala baseada em 4 px:

```text
4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 64
```

Regras práticas:

- `4–8px` entre label e valor relacionado;
- `12–16px` entre ícone e texto;
- `16–24px` entre itens de uma lista;
- `24–32px` entre grupos de conteúdo;
- `32–64px` nas margens externas de telas cheias;
- botões e campos devem ter pelo menos `44px` de altura;
- painéis principais devem usar largura responsiva com `clamp()` ou `min()`/`max()`.

Mantenha alinhamentos previsíveis. A tela de multicharacter usa conteúdo principal à esquerda, contexto visual ao centro/direita e ações secundárias no rodapé. Outras NUIs podem mudar a composição, mas devem preservar uma hierarquia clara e bastante espaço livre.

## 6. Superfícies, bordas e overlays

Prefira superfícies `rgba(7, 9, 11, 0.48)` sobre a cena. Em hover ou seleção, aumente levemente a opacidade e o contraste da borda. O estado não deve depender apenas de escala.

Use:

- borda de `1px` com `--noir-border`;
- raio padrão de `2px`;
- divisores de `1px`, preferencialmente com fade para transparente;
- overlay direcional quando for necessário garantir contraste sobre o jogo;
- backdrop mais forte somente em modais, confirmações e bloqueios de fluxo.

Exemplo de proteção do conteúdo sobre uma cena:

```css
background: linear-gradient(
  90deg,
  rgba(3, 5, 7, 0.88) 0%,
  rgba(3, 5, 7, 0.70) 18%,
  rgba(3, 5, 7, 0.28) 34%,
  transparent 62%
);
```

O overlay deve acompanhar o lado que contém texto. Não aplique uma camada opaca sobre toda a tela quando um gradiente localizado resolver o contraste.

## 7. Botões e ações

### Ação primária

- apenas uma ação primária por contexto;
- altura entre `54px` e `62px` em telas de destaque, ou no mínimo `44px` em componentes compactos;
- superfície escura translúcida, borda fina e texto claro;
- label curta e específica: `JOGAR COM PERSONAGEM`, não `CONTINUAR` quando houver ambiguidade;
- ícone ou seta à direita pode reforçar direção, mas não substituir o texto.

### Ações secundárias

Use botão transparente ou de baixa ênfase. Ícone e texto devem compartilhar o mesmo estado de cor. Para ações destrutivas, mantenha a aparência neutra em repouso e revele `--noir-danger` no hover/foco.

### Estados obrigatórios

Todo botão precisa de:

- repouso;
- hover;
- `focus-visible`;
- pressionado, quando perceptível;
- desabilitado com baixa opacidade e sem interação;
- carregando, bloqueando novos envios.

```css
.noir-button:focus-visible {
  outline: 1px solid rgba(255, 255, 255, 0.70);
  outline-offset: 3px;
}

.noir-button:disabled {
  opacity: 0.32;
  cursor: not-allowed;
}
```

Não comunique hover apenas com zoom. Alterar borda, fundo e cor é mais estável e mantém o layout.

## 8. Menus

Menus devem ser curtos, escaneáveis e navegáveis por mouse e teclado.

- título ou contexto no topo;
- itens com ícone opcional, label e, quando útil, valor/atalho;
- item ativo com borda mais clara e superfície ligeiramente mais opaca;
- item desabilitado visível, mas sem aparência interativa;
- grupos separados por espaço ou divisor, não por caixas aninhadas;
- ação destrutiva separada das ações frequentes;
- listas grandes com busca ou categorias, sem esconder a rolagem quando ela for necessária para orientação.

Para cards selecionáveis, use o padrão do carrossel: borda neutra em repouso, borda mais clara no selecionado e conteúdo truncado com reticências. Inclua `aria-current`, `aria-selected` ou atributo equivalente.

## 9. Notificações

Notificações são mensagens breves sobre o resultado de uma ação; não devem se comportar como modais.

Estrutura recomendada:

```text
[ícone/indicador] TÍTULO CURTO
                  Explicação objetiva, quando necessária.
```

### Variantes

| Tipo | Uso | Cor de apoio | Duração sugerida |
|---|---|---|---:|
| Sucesso | ação concluída | `--noir-success` | 3–4 s |
| Informação | atualização neutra | `--noir-info` | 4–5 s |
| Alerta | atenção sem bloqueio | `--noir-warning` | 5–7 s |
| Erro | falha que exige ciência | `--noir-danger` | 6–8 s ou persistente |

Boas práticas:

- posicione em uma área consistente e respeite HUD, minimapa e safe zone;
- limite a largura a aproximadamente `360px`;
- use fundo `--noir-surface-hover`, borda `--noir-border` e raio de `2px`;
- aplique a cor semântica em um filete de `2px`, ícone ou título;
- permita no máximo três notificações visíveis; agrupe repetições;
- pause o tempo no hover quando houver texto relevante;
- ofereça fechamento manual em avisos persistentes;
- escreva `Personagem criado` e explique o próximo passo, em vez de `Sucesso!` sozinho.

Notificações não devem cobrir menus ativos nem receber foco automaticamente. Erros de formulário devem aparecer junto ao campo correspondente; use uma notificação apenas para a falha geral da operação.

## 10. Modais e confirmações

Use modal somente quando a ação bloquear o fluxo ou exigir decisão imediata. A camada de fundo pode ser mais escura que os painéis comuns, mas deve manter alguma percepção da cena.

Uma confirmação deve conter:

- título com a ação;
- objeto afetado, como o nome do personagem;
- consequência em linguagem direta;
- ação segura e ação destrutiva claramente distintas;
- suporte a `Escape` para cancelar, quando seguro;
- foco inicial na ação segura.

Para exclusão permanente, evite confirmação acidental por um único toque. Pode ser usado pressionar e segurar, digitar uma confirmação ou confirmar em duas etapas. Sempre informe que a ação não pode ser desfeita.

## 11. Formulários

- label sempre visível; placeholder não substitui label;
- campos com altura mínima de `44px`;
- mesma largura e alinhamento dentro do grupo;
- instrução e unidade próximas do campo (`ALTURA`, `180 cm`);
- erro abaixo do campo, em texto legível e com ícone/indicador além da cor;
- não apague valores após uma tentativa inválida;
- marque campos opcionais explicitamente;
- bloqueie envio duplicado enquanto processa;
- mantenha o botão principal no fim do fluxo.

Use caixa normal no conteúdo digitado, mesmo que labels e botões estejam em caixa alta. Datas, dinheiro e números devem seguir a localidade `pt-BR`, salvo quando o domínio do dado exigir outro formato.

## 12. Ícones

Adote ícones lineares, simples, com aproximadamente `1.5px` de traço. Tamanhos padrão:

- `16px` em ações compactas;
- `20px` em linhas de informação;
- `24px` apenas quando o ícone tiver maior destaque.

Ícones decorativos devem usar `aria-hidden="true"`. Ações que exibem apenas ícone precisam de nome acessível (`aria-label`) e área clicável mínima de `44 × 44px`.

Não misture famílias com pesos e preenchimentos muito diferentes na mesma interface.

## 13. Movimento e feedback

O movimento padrão deve durar entre `160ms` e `200ms`. Entradas de tela podem usar fade de `200ms`. Rolagem de carrossel pode ser suave. Reserve animações mais longas para transições narrativas do jogo, nunca para operações rotineiras.

- dê retorno imediato ao clique;
- mostre progresso real quando a espera ultrapassar cerca de 500 ms;
- não use animação infinita fora de loading;
- respeite `prefers-reduced-motion` nas NUIs que rodam em navegador;
- sons de hover/clique são complementares e nunca substituem feedback visual.

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

## 14. Acessibilidade e controles

Mesmo em uma NUI de jogo, todos os fluxos devem funcionar sem depender exclusivamente do mouse.

- ordem de foco acompanha a ordem visual;
- foco visível em todo controle;
- `Enter` confirma a ação principal quando não houver risco destrutivo;
- `Escape` fecha ou volta quando isso não causa perda inesperada;
- setas navegam em carrosséis, abas e opções relacionadas;
- contraste mínimo recomendado de `4.5:1` para texto comum e `3:1` para texto grande;
- cor nunca é o único indicador de estado;
- textos importantes não devem usar `--noir-subtle`;
- alvos interativos devem ter pelo menos `44 × 44px`;
- use HTML semântico e nomes acessíveis nos controles.

Não desabilite seleção de texto globalmente em interfaces com dados que o usuário possa precisar copiar. Restrinja `user-select: none` a controles e elementos decorativos.

## 15. Responsividade e safe zone

As interfaces devem ser verificadas em `1280×720`, `1920×1080`, `2560×1440` e proporções ultrawide. Use `clamp()` para margens e títulos e media queries por altura, pois NUIs de jogo frequentemente perdem espaço vertical antes do horizontal.

- não posicione informação essencial colada às bordas;
- respeite margem segura mínima de `24px`, preferindo `clamp(32px, 3vw, 72px)` em telas cheias;
- evite dimensões baseadas apenas em `vw`;
- trunque nomes e valores imprevisíveis com reticências;
- permita quebra de linha em títulos quando truncar remover sentido;
- valide a interface com textos maiores que os exemplos reais.

## 16. Linguagem e conteúdo

A interface deve usar português do Brasil consistente.

- ações começam com verbo: `CRIAR PERSONAGEM`, `SALVAR ALTERAÇÕES`;
- labels são substantivos: `DINHEIRO`, `EMPREGO`, `LOCALIZAÇÃO`;
- mensagens explicam causa e solução quando possível;
- evite termos técnicos do resource, callbacks e nomes internos;
- não use ponto final em labels ou botões;
- use ponto final em frases completas;
- prefira mensagens humanas: `Não foi possível carregar os personagens. Tente novamente.`

## 17. Modelo base de componente

```css
.noir-component {
  border: 1px solid var(--noir-border);
  border-radius: var(--noir-radius);
  background: var(--noir-surface);
  color: var(--noir-text);
  transition:
    border-color var(--noir-transition),
    background-color var(--noir-transition),
    color var(--noir-transition-fast);
}

.noir-component:hover {
  border-color: var(--noir-border-hover);
  background: var(--noir-surface-hover);
}

.noir-component__label {
  color: var(--noir-muted);
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}
```

Esse modelo é um ponto de partida, não uma obrigação de transformar todos os elementos em cards.

## 18. Checklist de revisão

Antes de aprovar uma nova interface, confirme:

- [ ] usa os tokens Noir em vez de cores isoladas;
- [ ] mantém uma única ação primária por contexto;
- [ ] possui estados de hover, foco, desabilitado e loading;
- [ ] funciona por teclado e tem foco visível;
- [ ] não depende apenas de cor ou som;
- [ ] mantém texto legível sobre qualquer cena do jogo;
- [ ] respeita HUD e margens seguras;
- [ ] foi testada em 720p, 1080p, 1440p e ultrawide;
- [ ] trata nomes, traduções e valores longos;
- [ ] usa confirmação reforçada para ações irreversíveis;
- [ ] evita verde legado, Anton e Pricedown sem justificativa de identidade;
- [ ] foi compilada quando o resource carrega arquivos de `dist`.

## 19. Regra para exceções

Uma interface pode sair deste padrão quando o universo do recurso exigir uma identidade própria — por exemplo, um celular, terminal policial ou painel de veículo. Mesmo nesses casos, mantenha os fundamentos compartilhados: legibilidade, escala de espaçamento, feedback, navegação por teclado, estados semânticos e respeito à safe zone.

Qualquer novo token global ou exceção recorrente deve ser documentado aqui antes de ser replicado em vários resources.
