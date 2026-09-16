# noir_skills

Habilidades de personagem: XP por atividade, níveis com curva configurável e um painel
(tecla `J`) que mostra o progresso.

Fork do [evolent_skills](https://github.com/evolent-labs/evolent_skills) (GPLv3, ver
[LICENSE](LICENSE)), reescrito para este servidor: adaptador de quatro frameworks fora,
`bgrz_core` no lugar, curva de XP refeita, UI em Svelte 5 sem CDN.

O resource não fala com o framework. `citizenid`, notificação e ciclo de vida do personagem
chegam pelos exports e eventos do `bgrz_core`; nenhum arquivo chama `qbx_core`, e o manifest
declara só `ox_lib`, `oxmysql` e `bgrz_core`. Um teste guarda isso.

## Instalação

1. Ordem de start: `ox_lib` / `oxmysql` → `qbx_core` → `bgrz_core` → `noir_skills`. O
   `ensure [bgrz]` do `server.cfg` já cobre, porque o `bgrz_core` sobe antes da coleção.
2. O schema roda sozinho no start, a partir de `migrations/noir_skills.sql`. Só DDL
   idempotente e não destrutivo passa — `DROP`, `MODIFY` e `RENAME` são recusados e abortam
   o start, porque o arquivo roda inteiro toda vez e nada ali pode apagar XP de ninguém.
3. Ace `noir.skills` para os comandos de admin (já concedido ao `group.admin` no
   `permissions.cfg`).
4. A UI é versionada em `web/build`, fontes incluídas. Só precisa de build quem mexer em
   `web/src`: `cd web && npm install && npm run build`.

## Habilidades

Uma habilidade é uma entrada em `shared/config.lua`. Não há código por habilidade: quem
concede XP é outro resource, chamando o export daqui.

```lua
arrombamento = {
    label = 'Arrombamento',
    baseXp = 90,       -- XP para sair do nível 1 para o 2
    growth = 1.18,     -- o custo do próximo nível é o anterior vezes isto
    maxLevel = 15,
    icon = 'key',      -- conjunto embutido na UI (web/src/lib/Icon.svelte)
    color = '#FFC96B',
},
```

O painel lista **só o que o personagem já treinou**: habilidade com 0 de XP não aparece, e
entra na lista sozinha no primeiro ganho. Quem não treinou nada vê o estado vazio em vez de um
catálogo de barras zeradas.

Tirar uma habilidade do config **não apaga** o XP de ninguém: a linha continua no banco e é
ignorada até a habilidade voltar. Habilidade mal configurada derruba o start com o motivo no
console — número errado em curva não estoura sozinho, ele só entrega nível errado para sempre.

### A curva

O custo é **somado**, não multiplicado: o nível N pede `baseXp * growth^(N-2)` de XP, e o
total até ele é a soma de todos os anteriores. Era aqui o problema do upstream, que tratava o
valor multiplicado como total acumulado — com os números que vinham no config
(`growth` 1.4, `maxLevel` 100), o último nível pedia 4 × 10¹⁴ de XP e metade da tabela era
inalcançável por construção.

`growth` entre 1.05 e 1.25 dá uma curva que o jogador sente subir sem travar. Para conferir
antes de publicar, `/skillcurve <habilidade>` imprime o custo de cada nível e o total no
console do servidor.

## Integração

XP nasce no servidor. Não existe evento de rede que conceda XP — o ganho vem de outro
resource chamando o export, e é o servidor que valida, grampeia no teto e grava.

```lua
-- servidor
exports.noir_skills:AddXp(source, 'arrombamento', 15)
exports.noir_skills:RemoveXp(source, 'trafico', 40)
exports.noir_skills:SetLevel(source, 'mecanica', 5)   -- zera o progresso dentro do nível
exports.noir_skills:ResetSkill(source, 'mecanica')

exports.noir_skills:GetXp(source, 'arrombamento')        --> XP bruto acumulado
exports.noir_skills:GetLevel(source, 'arrombamento')     --> nível
exports.noir_skills:HasLevel(source, 'arrombamento', 5)  --> portão de conteúdo
exports.noir_skills:GetAll(source)                       --> tudo, já com nível e progresso
```

No cliente os mesmos dados respondem **sem ida ao servidor** — o cliente guarda o XP bruto e
calcula com a mesma curva (`shared/xp.lua` é shared por isso). Pode chamar dentro de loop:

```lua
-- cliente
exports.noir_skills:GetLevel('arrombamento')
exports.noir_skills:HasLevel('arrombamento', 5)
exports.noir_skills:GetAll()
```

Eventos para quem quer reagir:

| Evento | Lado | Argumentos |
|---|---|---|
| `noir_skills:server:xpChanged` | servidor | `source, habilidade, xpNovo, xpAnterior` |
| `noir_skills:server:levelChanged` | servidor | `source, habilidade, nível, nívelAnterior` |
| `noir_skills:client:levelUp` | cliente | `habilidade, nível` |

`levelChanged` também dispara quando o nível **desce** (admin removendo XP): compare com o
nível anterior antes de soltar recompensa.

## Comandos de admin

Todos no ace `noir.skills`. O nome da habilidade aceita a chave ou o rótulo, com ou sem
acento, em qualquer caixa (`trafico`, `Tráfico`, `TRAFICO`).

| Comando | O que faz |
|---|---|
| `/addskillxp <id> <habilidade> <xp>` | dá XP; valor negativo remove |
| `/setskilllevel <id> <habilidade> <nível>` | põe no piso do nível |
| `/resetskill <id> <habilidade>` | zera |
| `/skillcurve <habilidade>` | imprime a curva no console do servidor |

## Dados

Uma linha por `(citizenid, habilidade)` em `noir_skills`, guardando só o XP bruto. Nível não
é coluna: sai da curva do config, então mudar a curva não pede migração de dado. A gravação é
upsert na mudança — entrar no servidor não escreve nada.

## Testes

Lua puro, sem runtime do FiveM. Da raiz do resource:

```bash
for spec in xp config server client; do lua5.4 "tests/unit/${spec}_spec.lua" || break; done
```

`xp_spec` cobre a curva (a parte que o upstream errava); `server_spec` carrega o
`server/main.lua` com o runtime stubado e exercita teto, piso, eventos e limpeza de cache;
`client_spec` faz o mesmo com o `client/main.lua` e cobre o que entra no painel, o aviso de
nível e os exports locais; e `config_spec` guarda o acoplamento, a migração idempotente, o
build da UI no lugar e as regras de NUI do guia de design.

## O que mudou em relação ao upstream

- **Framework.** O adaptador de QB/QBX/ESX/OX saiu inteiro; `citizenid`, notificação e ciclo
  de vida vêm do `bgrz_core`.
- **Curva de XP.** Custo por nível somado em vez de multiplicado (ver acima), XP grampeado no
  teto da habilidade e config validado no start.
- **Vazamento de cache.** O upstream nunca limpava o cache do jogador; aqui
  `playerUnloaded` e `playerDropped` limpam.
- **Crash com jogador não carregado.** `addXp`/`removeXp` indexavam o cache sem checar, e
  qualquer chamada antes do load derrubava o handler. Agora recusam com aviso nomeando o
  resource que chamou.
- **Notificação do comando de admin.** Ia para o alvo em vez de para o admin (`source` e
  `target` trocados na validação).
- **Banco.** `INSERT` por habilidade a cada login deu lugar a upsert na mudança; a chave é
  `(citizenid, skill)`.
- **Cliente.** Os exports respondiam por callback com `await` — bloqueavam e não serviam para
  loop. Agora o cliente tem o estado e calcula local.
- **UI.** Svelte 4 → Svelte 5, Vite 4 → 7, e o visual refeito no
  [guia v3](../../docs/DESIGN_v3.md): tokens `--noir-*`, Poppins empacotada no resource,
  tipografia em px (nada de `vw`), raiz transparente declarada também no `<head>`, rolagem só
  na lista e `prefers-reduced-motion` respeitado. Font Awesome e Google Fonts (CDN, que falha
  em silêncio sem internet) saíram; os ícones são SVG desenhados no próprio componente. A cor
  da habilidade ficou restrita ao ícone e à barra — superfície e texto seguem neutros, como a
  v3 pede para cor semântica. Tamanho e posição do painel (lateral direita) foram mantidos
  porque já estavam validados em jogo. Textos em português.
- **Comandos.** `addxp` / `removexp` / `setlevel` eram genéricos demais para conviver com o
  resto do servidor; viraram `addskillxp` / `setskilllevel` / `resetskill`, mais
  `/skillcurve`. O ace é config (`Config.AdminAce`), não `group.admin` fixo.
