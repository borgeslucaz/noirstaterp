# Guia de design de interfaces v4 — Noir State RP

> A v4 é o sistema visual das NUIs da Noir State: fontes, cor, superfícies, transparência, controles, janelas e as regras de cada **tipo de interface**. A Parte 1 vale para toda interface; a Parte 2 descreve os tipos (hoje, o **Menu Lateral** e a **Janela de Compra**) e cresce conforme novos tipos forem criados.

> Nasceu na garagem (`resources/[noir]/noir_garage/web`), que é a implementação de referência: `src/index.css` (tokens e visual), `src/components/Menu.tsx` (coluna do menu lateral), `src/components/Modal.tsx` e `Dialogs.tsx` (janela central), `src/app/GarageApp.tsx` e `src/app/EditorApp.tsx` (dois usos do menu lateral). A Janela de Compra tem referência própria no `noir_shops` (§JC).

## 0. Precedência

A v4 **substitui a v3** no que ela define: tipografia, forma, cor das superfícies, botões, janela central e teclas. Continua valendo da v3 o que a v4 não redefine: tokens semânticos (`--noir-success`, `--noir-warning`, `--noir-danger`, `--noir-info`), foco visível, acessibilidade, barra de rolagem (§6.5), `prefers-reduced-motion`, pt-BR e safe zone. Tipos de interface que a v4 ainda não cobre (janela de comando, workspace dividido) seguem a composição da v3 **com os fundamentos da v4**.

---

# Parte 1 — Fundamentos

## 1. Tipografia

### 1.1 Famílias

Duas famílias, **empacotadas no resource** (nunca CDN), vindas do `@fontsource` (subset latin, cobre os acentos do pt-BR):

| Papel | Família | Pesos | Onde |
|---|---|---|---|
| **Display** | **Saira Condensed** | 500, 700 | títulos, itens de menu, nomes em destaque, teclas, botões |
| **Texto** | **Rajdhani** | 400, 500, 600, 700 | subtítulos, descrições, metadados, placas, valores, campos, avisos, corpo de janelas |

```css
:root {
  --font-display: "Saira Condensed", "Rajdhani", Arial, sans-serif;
  --font-ui: "Rajdhani", Arial, sans-serif;
}

@font-face {
  font-family: "Saira Condensed";
  src: url("./assets/fonts/SairaCondensed-700.woff2") format("woff2");
  font-weight: 700;
  font-style: normal;
  font-display: swap;
}
/* repetir para cada peso usado de cada família */
```

Para buscar os arquivos: `npm pack @fontsource/saira-condensed` e `npm pack @fontsource/rajdhani`, copiar `files/<familia>-latin-<peso>-normal.woff2` para `src/assets/fonts/`. Empacote só os pesos usados.

Testadas e descartadas (não reabrir sem motivo novo): Poppins (redonda demais ao lado de display condensada), Big Shoulders Display (estreita demais para ler itens), Barlow (neutra), Oswald (larga, sem identidade), Bebas/Anton (um peso só).

### 1.2 Tratamento

- **Display sempre em caixa alta**; texto em caixa normal.
- **Sem itálico** (testado e retirado).
- Display em **700** para títulos, teclas e botões; **500** para itens de lista e nomes em destaque — rótulo de item não é negrito.
- A Rajdhani desenha pequena: textos miúdos ficam **um degrau acima** do usual (12,5 px em vez de 11 px).
- Números (dinheiro, porcentagem, placa, datas) com `font-variant-numeric: tabular-nums`.

### 1.3 Escala

| Uso | Família | Tamanho | Peso | Extra |
|---|---|---:|---:|---|
| Título de tela/coluna | Display | 34 px | 700 | `line-height: 1`, tracking `.01em` |
| Subtítulo | Texto | 15 px | 500 | abaixo do título |
| Título de janela central | Display | 24 px | 700 | |
| Nome em destaque (resumo) | Display | 22 px | 500 | |
| Item de lista | Display | 18 px | 500 | tracking `.02em` |
| Botão | Display | 15 px | 700 | tracking `.03em` |
| Tecla (pílula) | Display | 14 px | 700 | tracking `.03em` |
| Corpo, campo, aviso | Texto | 14 px | 400–500 | |
| Valor à direita (preço, %) | Texto | 14 px | 600 | tabular |
| Descrição / metadado | Texto | 12,5 px | 400–500 | |
| Placa / etiqueta | Texto | 11,5 px | 600 | tracking `.08em`, borda fina |

## 2. Transparência e fundo

Toda NUI mantém `html`, `body` e `#root` **totalmente transparentes**; só os componentes visíveis têm fundo (regra da v3 §22, sem exceção):

```css
html, body, #root {
  width: 100%;
  height: 100%;
  margin: 0;
  overflow: hidden;
  background: transparent !important;
}
```

- Não aplicar `color-scheme: dark` na raiz (no CEF pode pintar o canvas de preto).
- Sem `backdrop-filter` nem blur em tela cheia.
- Overlay escuro de tela inteira **só** com uma janela central aberta.

### 2.1 Superfícies

| Superfície | Valor |
|---|---|
| Painel ativo | `linear-gradient(180deg, rgba(12,14,18,.94), rgba(12,14,18,.80))` |
| Painel de trás / inativo | `linear-gradient(180deg, rgba(12,14,18,.86), rgba(12,14,18,.70))` e conteúdo não destacado com `opacity: .72` |
| Cabeçalho | `linear-gradient(180deg, rgba(0,0,0,.55), rgba(0,0,0,.25))`, sem divisor embaixo |
| Bloco de destaque (resumo) | `rgba(255,255,255,.04)` |
| Campo | `--noir-field #101012`, borda `--noir-border` |
| Janela central | `--noir-panel-raised #171719`, borda `--noir-border`, sombra `--shadow-modal` |
| Overlay da janela | `--noir-overlay rgba(0,0,0,.76)` |

Painéis **sem borda e sem sombra**: a separação vem do gradiente.

## 3. Cor

- **Seleção:** faixa branca `#f2f2f2` com texto `#111113` (ícones e valores também escuros; descrição `rgba(17,17,19,.72)`).
- **Texto sobre escuro:** `--noir-text-strong` (títulos, rótulos), `--noir-text` (corpo), `--noir-text-muted` (metadado). Ícones de lista em `rgba(255,255,255,.82)`.
- **Semântica** (v3): sucesso `#39df45`, alerta `#d7a84b`, perigo `#d51a1a` / `#ef2929` no hover, informação `#6e9fbd`. Em área pequena (ponto de estado, filete, ícone, rótulo), nunca em superfície inteira — exceto o botão da ação.
- **Acento de serviço** (`--noir-accent`) só em detalhes; a seleção é branca, não a cor do serviço.

### 3.1 Barras de estado

Barra de 4 px, valor à direita em números tabulares:

| Valor | Cor |
|---|---|
| até 35% | perigo |
| 36–60% | alerta |
| acima de 60% | sucesso |

Use só para métrica em que mais é melhor (combustível, carroceria, motor). Métrica sem juízo de valor (velocidade, frenagem) deveria ser neutra.

## 4. Forma e espaçamento

- **Raio 2 px** em campos, botões, janelas, avisos, ícones de destaque, pílulas. **0** em linhas de lista.
- Base de 4 px (v3 §5). Padding lateral padrão de linha e cabeçalho: **20 px**.
- Alvos clicáveis com pelo menos 40 px de altura.

## 5. Botões

| Tipo | Visual | Uso |
|---|---|---|
| **Confirmar** | fundo `--noir-success`, texto `#111113` | salvar, transferir, confirmar — a ação positiva |
| **Destrutivo** | fundo `--noir-danger`, texto branco | apagar, descartar alterações |
| **Secundário** | `--noir-panel-raised`, borda `--noir-border`, texto forte | cancelar |
| **Ícone** | transparente, 32–40 px | fechar (X), estrela de favorito |

- Rótulo em display 700, caixa alta, verbo no começo (`SALVAR APELIDO`, `TRANSFERIR VEÍCULO`).
- **Custo nunca dentro do botão**: vai numa linha própria do conteúdo (`Custo: $5.000`).
- Loading: spinner de 16 px dentro do botão, `aria-busy`, bloqueia novo clique.

## 6. Janela central

Para **digitar** ou **confirmar**. Informação que cabe numa linha não abre janela.

```text
┌───────────────────────────────────────┐
│ TÍTULO DA AÇÃO                     ✕  │
├───────────────────────────────────────┤
│ Nome do objeto  [PLACA]               │
│ Texto simples explicando a consequência.
│ Custo: $5.000                         │
│                                       │
│ [   CANCELAR   ] [    CONFIRMAR    ]  │
└───────────────────────────────────────┘
```

- Centro da tela, `min(430px, 100vw - 48px)`, overlay escuro atrás.
- Primeira linha identifica o objeto; depois **texto simples** — sem card colorido em volta de aviso.
- Rodapé em **duas metades iguais**: Cancelar à esquerda, ação à direita.
- Foco inicial no campo (digitação) ou em **Cancelar** (confirmação: um Enter sem querer não executa).
- Foco preso; Esc cancela; ao fechar, o foco volta a quem abriu.
- **A tecla não vaza** para a interface de trás: `stopPropagation` no keydown da janela, e a interface de trás ignora eventos vindos de dentro dela. Sem isso, o Esc que fecha a janela também age atrás.
- Enquanto aberta, a interface de trás não responde ao teclado e as teclas visíveis (§7) somem.

## 7. Teclas visíveis

Pílulas no **canto inferior direito da tela**, fixas, mostrando só as teclas do contexto atual:

```css
.menu__keys { position: fixed; right: 16px; bottom: 16px; display: flex; gap: 8px; }
.menu__key { padding: 5px 10px 5px 6px; background: rgba(0,0,0,.72); border-radius: 2px;
  font: 700 14px var(--font-display); text-transform: uppercase; color: #fff; }
.menu__key kbd { background: #f2f2f2; color: #111113; font: 700 11px/1.4 var(--font-ui); border-radius: 2px; }
```

Exemplo: `[↵] ESCOLHER / [ESC] FECHAR`. Sem rodapé com botão de fechar: fechar é o X do cabeçalho e o Esc.

Resource **sem NUI própria** (sentar, encostar, interações em Lua puro) não usa textUI do ox_lib: mostra as pílulas pelo `noir_lib` (`exports.noir_lib:ShowKeyHints({ position, keys })`, veja o README dele). Nesse caso a posição é escolhida por quem chama (`cima`, `baixo`, `esquerda`, `direita`), porque não há menu no canto para acompanhar.

## 8. Campos e busca

- Campo escuro de 36–40 px, borda fina, raio 2 px, texto 14 px.
- Busca sem rótulo visível (rótulo só para leitor de tela), placeholder que diz o que busca: `Buscar por nome, modelo ou placa`.
- Erro abaixo do campo, com ícone e texto, não só cor.

## 9. Movimento

Curto e funcional (v3 §16): painel entra em 240 ms deslizando 16 px; janela em 220 ms com `translateY(8px)`; hover 120–180 ms. Nada de coreografia em menus.

## 10. Preview no navegador

Toda NUI nasce testável fora do jogo:

- `isEnvBrowser()` (sem `window.invokeNative`) liga os mocks: `fetchNui` devolve `mock.data`; eventos simulados por `debugData`.
- Botões de preview no **canto inferior esquerdo**, só no navegador (`Abrir garagem`, `Abrir pátio`, `Abrir editor`).
- Fundo do preview: a foto de cena do `noir_multichar` (`web/dev/sinner.png`), servida só pelo `vite dev`, aplicada em `html` com `!important` inline; o build não inclui o arquivo.
- Os mocks cobrem os casos difíceis: item travado, texto longo, lista longa (rolagem), erro do servidor, recusa.
- Servir com `vite --host 127.0.0.1` atrás do Caddy com `basic_auth`; o vite 6 precisa de `__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS=<domínio>`.

## 11. FiveM Enhanced

- **Modelo de PED, prop ou animação que não existe no build derruba o cliente.** Confira `IsModelInCdimage` + `IsModelAPed`/`IsModelAVehicle` antes de qualquer `request`; na dúvida, não crie. Cenário com objeto na mão (prancheta, celular, cigarro) é testado uma vez no jogo antes de ir para produção.
- Entidade local criada pela interface (atendente, prévia) nasce ao chegar perto e morre ao sair; o target sai antes do `DeleteEntity`.
- Target sempre pelo bridge do `bgrz_core` (`AddLocalEntityTarget`, `AddSphereZoneTarget`).

---

# Parte 2 — Tipos de interface

Cada tipo define **composição e comportamento**; a aparência vem da Parte 1. Tipos novos entram aqui com a mesma estrutura: quando usar, layout, anatomia, interação, variações e checklist.

## Menu Lateral

### ML.1 Quando usar

Interação aberta **num ponto do mundo** com uma lista de escolhas e poucos níveis: garagem, pátio, serviços de balcão com poucas opções (chaves, aluguel), escolha de rota, editor de pontos de admin. A cena continua visível e útil (o carro na prévia, o balcão).

Não use para gestão densa (tabelas, históricos longos, permissões em massa): isso é janela de comando. Catálogo com imagem e carrinho (comprar vários itens de uma vez) é Janela de Compra (§JC).

### ML.2 Layout: colunas na borda direita

```text
┌──────────────── cena livre ────────────────┬── coluna 3 ──┬── coluna 2 ──┬── coluna 1 ──┐
│                                            │  (ativa)     │  aba aberta  │  aba aberta  │
│                                            │              │              │              │
│                                            │              │              │              │
│                                   [↵ ESCOLHER] / [ESC VOLTAR]            (canto inf. dir.)│
└────────────────────────────────────────────┴──────────────┴──────────────┴──────────────┘
```

```css
.menus { position: fixed; top: 0; right: 0; bottom: 0; display: flex; flex-direction: row-reverse; }
.menu  { width: clamp(320px, 20vw, 380px); height: 100%; display: flex; flex-direction: column; overflow: hidden; }
```

- A **coluna 1** (raiz) fica colada na borda direita, **de cima a baixo**.
- Cada submenu abre uma **coluna nova à esquerda** da anterior; as de trás continuam visíveis (estilo `lib.registerMenu` do ox_lib, espalhado em colunas).
- **No máximo três colunas** em menus de jogador. Se precisar de uma quarta, o nível mais fundo vira janela central (digitar/confirmar) ou a coluna anterior absorve a lista.
- **Editor de admin pode ter quatro** (ex.: garagens → garagem → ponto → vagas): ~1 520 px em 1920; admin usa em resolução de desktop.
- Só a lista rola, dentro da coluna (`min-height: 0; overflow-y: auto`), com `padding-bottom: 64px` para as teclas não cobrirem o último item.

### ML.3 Anatomia da coluna

**Cabeçalho** (104 px; 64 px abaixo de 760 px de altura de tela)
- Título em display 34 px à esquerda; subtítulo em texto 15 px abaixo (`Garagem`, `Pátio`, um identificador).
- **X no canto superior direito de todas as colunas**: na raiz fecha a interface; nas outras fecha aquela coluna e as à esquerda.
- Submenu de 3º nível **não repete** no topo o nome que já está na coluna ao lado.

**Resumo** (opcional, quando a coluna é "sobre" um objeto)
- Ícone 48 px, nome em display 22 px, linha secundária opcional, etiquetas (placa, estado).
- **Altura fixa** (96 px): com ou sem linha secundária, as opções abaixo não pulam.
- Ação de estado do objeto mora aqui (ex.: estrela de favorito à direita do nome).

**Aviso** (opcional)
- Faixa com filete semântico de 3 px + ícone, abaixo do cabeçalho/resumo: motivo de algo travado, resultado de ação, erro.

**Lista**
- Busca como primeiro item quando a lista pode crescer.
- Itens (ML.4).

**Sem rodapé**: fechar é o X e o Esc; as teclas ficam no canto da tela (Parte 1 §7).

### ML.4 Itens

Estrutura: `[ícone 18 px] [RÓTULO + descrição] [valor à direita]`, linha de borda a borda, sem raio.

- Altura mínima **48 px**. Item com descrição que só aparece quando ativo tem **altura fixa de 56 px**, já reservada: ao ativar, só o rótulo sobe e a descrição aparece — **o menu nunca pula**. Não combine descrição fixa e descrição de ativo no mesmo item.
- **Item ativo:** faixa branca com texto escuro (Parte 1 §3).
- O lado direito é **só informação**: preço, `Grátis`, `%`, `Sim`/`Não`, contagem, estrela, cadeado. **Sem seta `>`** — o submenu abre à esquerda.

| Tipo | Comportamento | Visual |
|---|---|---|
| Ação | Enter/clique executa | hover |
| Submenu | abre coluna à esquerda; **clicar de novo no mesmo item fecha a coluna** | vira **aba** (ML.5) enquanto aberta |
| Alternância | Enter/clique troca o valor (`Sim ↔ Não`, `Carro → Aeronave → Barco`) | valor à direita |
| Ciclo com limite | liga → sobe um degrau → … → desliga (ex.: cargo mínimo) | caixa de marcar + degrau na descrição |
| Campo | digita na própria linha | campo 36 px sob o rótulo |
| Informação | nada | sem hover (barras, registros, cabeçalho de seção) |
| Travado | não abre nem executa | **cadeado** no lugar do valor; motivo na descrição ou no aviso |
| Destrutivo | abre janela de confirmação | rótulo em vermelho |

Estados da lista:
- Indisponível vira linha informativa com cadeado. Exceção explícita quando ainda há algo útil a fazer (no pátio, carro na rua abre só para chave/fechadura).
- Favoritos no topo; ao reordenar, **o destaque segue o objeto aberto**, não a posição.
- Vazio e "nenhum resultado" são linhas informativas com frase explicativa.
- Referência que não existe mais aparece em vermelho com "(não existe mais)"; Enter remove.

### ML.5 Colunas de trás

- Fundo mais transparente; cabeçalho, resumo e itens não escolhidos com `opacity: .72`.
- O item que abriu a coluna seguinte vira **aba**: `rgba(242,242,242,.88)` com texto escuro, sem apagar — o caminho aberto (lista → objeto → detalhe) se lê de relance.
- Clicar num item de uma coluna de trás fecha as colunas à esquerda dela e escolhe o item (trocar de objeto num clique).

### ML.6 Teclado e mouse

| Tecla | Ação |
|---|---|
| ↑ / ↓ | navega (circular) |
| Home / End | primeiro / último |
| Enter | escolhe o item ativo |
| ← | abre o submenu do item ativo |
| → , Backspace, Esc | volta uma coluna; na raiz, fecha |

- Só a coluna ativa (a mais à esquerda) responde ao teclado e ao hover.
- Campo ativo recebe foco sozinho; Backspace dentro dele apaga texto.
- Teclas visíveis: `ESCOLHER / FECHAR` na raiz, `ESCOLHER / VOLTAR` nas outras.

### ML.7 Variação: editor (admin)

O mesmo menu lateral serve para editar dados (ex.: `/garagem`):

- Colunas **lista → objeto → detalhe**; busca e "Nova …" no topo da lista.
- Campos na própria linha; alternâncias pelo valor à direita; listas de escolha como submenu com seções (a dica de uso fica na linha da seção, não repetida em cada item).
- **Rascunho**: nada vale até "Salvar". Trocar de objeto ou fechar com alterações pendentes pede "Descartar alterações?" **uma vez** (guarde o estado "alterado" numa ref).
- **Marcar posição**: a interface some, o jogador anda até o lugar, `E` marca, `Backspace` cancela; o que já foi marcado fica desenhado no chão.
- **Posicionar entidade** (atendente, vaga de carro): a interface some e uma entidade de teste translúcida e sem colisão segue o chão para onde a câmera mira; roda do mouse gira (Shift = mais rápido), `Enter` confirma, `Backspace` cancela. Não use o `object_gizmo`: no Enhanced ele não pega o clique.
- **Item de lista com mais de uma ação** (reposicionar ou remover uma vaga): Enter abre uma janela central com as duas ações lado a lado; Esc fecha sem mudar nada.
- A interface monta o rascunho; o servidor valida tudo o que chega.

### ML.8 Antipadrões

- Seta `>` quando o submenu abre à esquerda.
- Descrição de ativo ou resumo que mudam de altura (menu pulando).
- Repetir no topo do submenu o nome da coluna ao lado.
- Rodapé com faixa de fundo atrás de um botão de fechar.
- Quarta coluna em menu de jogador.
- Formulário longo dentro da coluna: digitação vai para a janela central.

### ML.9 Checklist

- [ ] colunas de altura total na borda direita; submenu abre à esquerda; no máximo três (quatro em editor de admin);
- [ ] X em todas as colunas; sem rodapé; teclas no canto inferior direito;
- [ ] itens com alturas fixas onde há descrição de ativo; resumo com altura fixa;
- [ ] sem setas; lado direito só com informação; cadeado em travado;
- [ ] aba branca no item que abriu a coluna seguinte; destaque segue o objeto ao reordenar;
- [ ] clicar de novo no submenu aberto fecha a coluna;
- [ ] digitar/confirmar em janela central (Parte 1 §6);
- [ ] preview no navegador com mocks dos casos difíceis (Parte 1 §10).

---

## Janela de Compra

Implementação de referência: `resources/[noir]/noir_shops/html` — `ui.html` (marcação da loja), `css/shop.css` (visual, escopo `.store-app`), funções `renderItems`/`renderCart`/`setPaymentModal` em `js/script.js`; preview em `dev/`.

### JC.1 Quando usar

Comprar **vários itens de uma vez** num ponto do mundo, escolhendo pela imagem: loja de conveniência, bebidas, ferramentas, Ammu-Nation, qualquer NPC que vende catálogo. O jogador monta um carrinho e paga uma vez.

Não use quando:
- a escolha é **uma coisa só** ou um serviço (chave, aluguel, reparo): Menu Lateral;
- é venda **do jogador para o NPC** ou troca item por item: isso é inventário (ox_inventory);
- o catálogo tem 1–2 itens sem quantidade: uma confirmação na janela central basta.

### JC.2 Layout: janela central com duas áreas

```text
┌──────────────────────────────────────────────────────────────┬──────────────────┐
│ LOJA DE CONVENIÊNCIA                                          │               ✕  │  cabeçalho 88 px
├──────────────────────────────────────────────────────────────┼──────────────────┤
│ [🔍 Buscar item                                            ]  │ CARRINHO         │
│ [TODOS] [COMIDA] [BEBIDA]                                     │ BURGER      $20 🗑│
│ ┌────────┐ ┌────────┐ ┌────────┐                              │ 2 × $10          │
│ │  img   │ │  img   │ │  img   │   (grade rola aqui)          │ ÁGUA        $10 🗑│
│ │ BURGER │ │ ÁGUA   │ │ SPRUNK │                              │                  │
│ │ $10    │ │ $10    │ │ $10    │                              │ Total      $280  │
│ │[-1+][ADICIONAR]   │ │ ...    │                              │ [FINALIZAR COMPRA]│
│ └────────┘ └────────┘ └────────┘                              │                  │
└──────────────────────────────────────────────────────────────┴──────────────────┘
                                                                   [ESC] FECHAR   (canto inf. dir. da tela)
```

- Janela no centro, `width: min(1120px, 100vw - 96px)`, `height: min(720px, 100vh - 120px)`: **altura fixa**, não cresce com o catálogo — só a grade e a lista do carrinho rolam.
- Superfície de **painel ativo** (Parte 1 §2.1), raio 2 px, sem borda e sem sombra; **sem overlay** atrás (a cena do balcão continua visível). Entra em 240 ms subindo 16 px.
- Duas áreas lado a lado: **catálogo** (flexível, à esquerda) e **carrinho** (340 px fixos, à direita, fundo `rgba(0,0,0,.22)` sobre o painel).
- Uma janela só — sem colunas, sem submenus. Categoria é filtro (aba), não navegação.

### JC.3 Anatomia

**Cabeçalho** (88 px)
- Título em display 34 px com o **nome da loja** (`LOJA DE CONVENIÊNCIA`, `AMMU-NATION`); gradiente de cabeçalho, sem divisor.
- X (ícone 40 px) no canto direito: fecha a loja.

**Catálogo**
- **Busca** primeiro (campo 40 px, Parte 1 §8), placeholder `Buscar item`; X de limpar dentro do campo quando há texto.
- **Abas de categoria** abaixo da busca: display 14 px 700 caixa alta, 32 px de altura, raio 2 px; ativa = seleção branca com texto escuro; inativas = `--noir-panel-raised` com borda. `TODOS` sempre primeira. Sem categoria nos itens → sem abas.
- **Grade** `repeat(auto-fill, minmax(196px, 1fr))`, espaço de 12 px; em 1200 px de janela cabem 3 colunas.
- Nenhum resultado: linha informativa em texto (`Nenhum item encontrado.`), não card vazio.

**Card de item**
- Bloco de destaque `rgba(255,255,255,.04)` (hover `.07`), raio 2 px, padding 16 px, **sem borda, sem sombra, sem subir no hover**.
- Imagem 80 px centrada numa área de 96 px (altura fixa: nomes curtos e longos alinham).
- Nome em display 18 px 500 caixa alta, **uma linha** com reticências; preço em texto 16 px 600 tabular, cor de texto (não acento).
- Ações na base: seletor de quantidade `[– 1 +]` (campo 40 px, raio 2 px) + botão **ADICIONAR** (secundário, ocupa o resto). O botão não repete o preço.
- Item que exige licença: ícone discreto no canto superior direito (`fa-id-card`, texto muted). Item sem a licença **não aparece** (o servidor recusa de novo no checkout).
- Preço variável (preço dinâmico): valor em `--noir-warning`, sem animação.

**Carrinho**
- Título `CARRINHO` em display 22 px 700.
- Linhas de lista (raio 0, divisor embaixo, mín. 56 px): nome em display 18 px 500 + descrição `2 × $10` (12,5 px muted); **subtotal à direita** em 14 px 600 tabular; lixeira como ícone 32 px (muted → perigo no hover).
- Mesmo item adicionado de novo **soma na linha existente** (respeitando o máximo), não duplica.
- Vazio: linha informativa `Seu carrinho está vazio`.
- Rodapé fixo com divisor em cima: linha `Total` (texto muted à esquerda, valor em display 26 px 700 à direita) e, abaixo, **FINALIZAR COMPRA** em botão de confirmar (verde, 44 px, largura toda). Carrinho vazio → botão desabilitado (`opacity .35`). O total fica **fora do botão** (Parte 1 §5).

**Janela de pagamento** (janela central, Parte 1 §6)
- Título `FORMA DE PAGAMENTO` + X; linha `Total da compra ........ $280`; frase `Escolha como pagar.`.
- Rodapé em **duas metades iguais**: `DINHEIRO` e `CARTÃO`, ambos secundários (branco no hover). Não há verde aqui: são duas ações equivalentes, e cancelar é o X/Esc.
- Foco inicial em `DINHEIRO`; com a janela aberta, as teclas visíveis somem.

**Teclas visíveis**: `[ESC] FECHAR` no canto inferior direito (Parte 1 §7).

### JC.4 Interação

| Entrada | Ação |
|---|---|
| clique em ADICIONAR | põe a quantidade escolhida no carrinho e volta o seletor para 1 |
| `–` / `+` / digitar | quantidade de 1 até o máximo do item |
| lixeira | remove a linha inteira |
| FINALIZAR COMPRA | abre a janela de pagamento |
| DINHEIRO / CARTÃO | envia o carrinho e fecha a loja; o resultado vem por notificação |
| Esc | com a janela de pagamento aberta, fecha só ela; senão, fecha a loja |

- O cliente só **monta** o carrinho: preço, quantidade inteira, máximo por item, licença, cargo, distância do balcão e dinheiro são **validados no servidor** (o carrinho que chega é tratado como sugestão).
- Valores em dinheiro formatados em pt-BR (`$1.000`), tabulares.

### JC.5 Variações

- **Loja restrita** (emprego/gangue): mesma janela; quem não tem acesso não vê o atendente nem o blip.
- **Catálogo pequeno** (≤ 3 itens, sem categoria): mesma janela, sem abas; a grade simplesmente não enche.
- **Preview no navegador** (Parte 1 §10): `dev/` fora do fxmanifest, com cenários de cada tipo de loja, com e sem licença e um catálogo de 10 itens para ver a rolagem. A NUI roda num iframe do tamanho da janela em pixel 1:1 (`?res=1920x1080` simula outra resolução).

### JC.6 Antipadrões

- Janela que cresce/encolhe com o catálogo, ou página inteira rolando em vez da grade.
- Card que sobe, brilha ou aumenta a imagem no hover.
- Preço dentro do botão (`ADICIONAR $10`, `PAGAR $280`).
- Cor de acento de serviço em preço, título ou aba ativa (a seleção é branca).
- Overlay escuro atrás da loja (só com a janela de pagamento aberta).
- Carrinho com cards arredondados em vez de linhas.
- Confiar em preço/quantidade vindos da NUI.

### JC.7 Checklist

- [ ] janela central de altura fixa; só grade e carrinho rolam; sem overlay;
- [ ] busca primeiro, abas de categoria com seleção branca, "nenhum resultado" como linha;
- [ ] card sem borda/sombra/movimento; imagem em área fixa; nome em uma linha; preço tabular;
- [ ] quantidade + ADICIONAR secundário no card; soma na linha existente do carrinho;
- [ ] total fora do botão; FINALIZAR COMPRA verde, desabilitado com carrinho vazio;
- [ ] pagamento em janela central com duas metades; Esc fecha só ela;
- [ ] `[ESC] FECHAR` no canto; somem com a janela aberta;
- [ ] servidor valida tudo (distância, quantidade inteira, máximo, licença, forma de pagamento);
- [ ] preview no navegador com lista longa e item com licença.

---

# Checklist geral (toda interface)

- [ ] raiz transparente, sem blur, overlay só com janela central;
- [ ] Saira Condensed (display, caixa alta, sem itálico) + Rajdhani (texto), empacotadas, só os pesos usados;
- [ ] seleção branca com texto escuro; semântica só em áreas pequenas;
- [ ] raio 2 px; linhas de lista sem raio;
- [ ] confirmar verde, destrutivo vermelho, cancelar secundário; custo fora do botão;
- [ ] janela central com metades iguais, foco correto e tecla que não vaza;
- [ ] teclas visíveis no canto inferior direito;
- [ ] barras 35/60 só em métrica "quanto mais, melhor";
- [ ] preview no navegador;
- [ ] modelos/props/animações conferidos antes de criar (Enhanced);
- [ ] build gerado quando o resource carrega `web/build`.
