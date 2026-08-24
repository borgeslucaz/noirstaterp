No resource `resources/[standalone]/element_hud`, crie o tema visual Noir apenas para os indicadores circulares de status (`CircleStatIndicator` em `web/src/components/Vehicle/main.tsx`).

Escopo:
- Alterar somente o preenchimento interno dos status circulares.
- Não alterar posição, tamanho, espaçamento, lógica dos valores, eventos NUI, stores, configurações ou ícones usados.
- Não modificar `SpeedometerGauge`, `RpmBars`, `speedDisplay`, HUD de veículo, velocímetro, minimapa ou tipografia.
- Não adicionar dependências.

Visual desejado:
- Cada status mantém o círculo atual, borda fina clara e fundo carvão escuro/translúcido.
- O ícone fica sempre branco quente (`#f3f3f1`), independente do status e do valor.
- O preenchimento colorido ocorre atrás do ícone, recortado perfeitamente dentro do círculo.
- O preenchimento sobe de baixo para cima, como nível de líquido:
  - 100% ocupa todo o círculo;
  - 50% ocupa exatamente a metade inferior;
  - 0% não exibe cor.
- A linha superior do líquido deve ser horizontal, com uma ondulação muito sutil apenas durante mudanças de valor.
- Em repouso, o líquido fica estático.

Paleta Noir:
- health: `#c85a5a`
- armour / info: `#829bab`
- hunger: `#c9a86a`
- thirst: `#829bab`
- voice inativo: cinza escuro; voice ativo: `#829bab`
- fundo: `rgba(7, 9, 11, 0.78)`
- borda: `rgba(243, 243, 241, 0.35)`

Performance:
- Implementar com CSS/DOM; não usar Canvas, SVG filters, blur, backdrop-filter, Lottie ou animação infinita.
- Animar apenas `transform` e/ou `height`, entre 180–250 ms.
- A ondulação deve ocorrer uma única vez quando o valor mudar e parar em seguida.
- Usar `overflow: hidden` e `border-radius: 50%` para recortar o líquido.
- Evitar glow, neon e sombras coloridas.

Critérios de aceite:
1. Ícones sempre brancos.
2. Saúde em 100% deixa o círculo interno totalmente vermelho.
3. Fome em 50% deixa somente metade inferior âmbar.
4. O preenchimento acompanha o valor suavizado já existente.
5. Velocímetro permanece visual e funcionalmente idêntico.
6. Executar `npm run build` dentro de `resources/[standalone]/element_hud/web` ao final.
