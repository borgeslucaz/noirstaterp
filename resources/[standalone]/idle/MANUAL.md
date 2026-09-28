# idle — Manual

Substitui a animação de parado (idle) padrão do personagem masculino multiplayer por uma versão alternativa, via asset em stream.

---

## Sumário

1. [Dependências](#dependências)
2. [Instalação](#instalação)
3. [Como funciona](#como-funciona)
4. [Estrutura de arquivos](#estrutura-de-arquivos)

---

## Dependências

| Recurso | Obrigatório | Observação |
|---|---|---|
| — | — | Standalone. Não depende de framework, `ox_lib` nem banco de dados |

---

## Instalação

1. Copie a pasta `idle` para `resources/`.
2. Adicione ao `server.cfg`:
   ```
   ensure idle
   ```
3. Reinicie o servidor. O asset em `stream/` é carregado automaticamente pelos clientes.

Não há SQL, itens, comandos, permissões ou configuração.

**Conflitos** — qualquer outro recurso que faça stream do mesmo clip dictionary (`move_m@generic_idles@std`) vai conflitar. Rode só um deles.

---

## Como funciona

O recurso é essencialmente um asset replacement. O arquivo `stream/move_m@generic_idles@std.ycd` sobrescreve o clip dictionary padrão do jogo com o mesmo nome, que é o usado pelo personagem masculino multiplayer quando fica parado. Não há lógica em runtime: o motor do GTA V toca a animação nova no lugar da original sozinho.

O `client.lua` existe mas está **inteiramente comentado** — nenhuma linha é executada. Ele guarda uma implementação alternativa (um loop que chamava `TaskPlayAnim` a cada frame) que não é necessária, já que a substituição do `.ycd` resolve por si.

A animação em si é de autoria de terceiros (`-EcLiPsE-`, via GTA5-Mods); este recurso só a empacota para FiveM.

---

## Estrutura de arquivos

```
idle/
├── stream/
│   └── move_m@generic_idles@std.ycd   — clip dictionary que substitui a idle padrão do MP male
├── client.lua                          — totalmente comentado, não executa nada
├── README.md
├── readme.txt                          — cópia do README.md
└── fxmanifest.lua
```
