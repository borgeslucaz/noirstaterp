# noir_busjob

Sistema de carreira de transporte publico para o Noir State. Substitui o `qbx_busjob` legado.

## Instalação

1. O resource executa `migrations/001_initial.sql` e `002_editor.sql` ao iniciar (só `CREATE TABLE IF NOT EXISTS`).
2. No primeiro boot com as tabelas do editor vazias, o catálogo é gravado a partir de `data/seed.lua`. Daí em diante o banco é a fonte: paradas, linhas, veículos, níveis e ajustes mudam pelo editor in-game.
3. Garanta que `bgrz_core`, `ox_lib`, `ox_target`, `oxmysql` e `noir_lib` iniciem antes.
4. Qualquer jogador pode falar com o atendente da Central; linha com grupo em "Quem pode fazer" só aparece para quem é do grupo.

## Editor in-game (`/editoronibus`)

ACE `noir.busjob.editor` (liberada para `group.admin` em `permissions.cfg`). Menu Lateral da v4 (§ML.7):

- **Paradas**: ir até, nome, onde o ônibus encosta (pare o veículo no lugar e aperte E), área dos passageiros, testar passageiros, ativa. A lista filtra "só sem área" para revisar uma a uma.
- **Área dos passageiros** (no molde do ZoneBuilder do ShadowForge, gravando direto na parada): centro na sua posição ou na mira, comprimento/largura/altura/rotação digitados com prévia no mundo, alinhar com o encosto, girar 90°, ir até a área. Também dá para desenhar pela mira (E nas duas pontas da calçada, roda ajusta a largura) ou colar um snippet do ShadowForge (ox_lib, ox_target, PolyZone ou JSON).
- **Mapa das linhas** (também por `/onibusmap`, mesma ACE): debug sobre os tiles do `/territorymap` (vêm do `noir_territories`). Menu para escolher a linha: trajeto em linha reta na ordem das paradas, paradas numeradas, áreas dos passageiros e a Central; "Todas as linhas" mostra tudo, com as paradas sem área em amarelo.
- **No mundo**: o editor desenha encosto e área de tudo num raio de 150 m; dá para manter o desenho com o editor fechado e revisar andando.
- **Linhas**: código, nome, nível, pagamento, XP, paradas em ordem, veículos permitidos, quem pode fazer (job/gang com cargo mínimo), mostrar no mapa. A estimativa de $/h e XP/h usa a mesma conta do servidor.
- **Veículos**: modelo (conferido no build antes de salvar), nome, capacidade, portas, nível.
- **Níveis**, **Central** (atendente e vaga do ônibus posicionados pela mira) e **Ajustes** (parada, passageiros, pagamento, tempo, horário de pico, quebra).

Nada vale até salvar; o servidor valida tudo de novo (`shared/rules.lua`) e registra em `busjob_editor_log`. Uma volta em andamento guarda a própria cópia da linha: editar o catálogo não mexe nela.

## Testes e preview

```sh
for f in tests/unit/*_spec.lua; do lua5.4 "$f" || break; done
lua5.4 dev/mock.lua > dev/mock.json   # preview: dev/index.html?preset=central|linhas|hud|editor|parada|area|linha|ajustes
```

## Fluxo

`IDLE -> DEADHEAD -> DOCKED -> BOARDING -> DEPARTING -> RETURNING_DEPOT -> PARKING -> COMPLETING -> SUMMARY`

O servidor cria, valida e finaliza cada sessão. O browser e o client enviam somente intenções. Dinheiro e XP são concedidos somente após o estacionamento no depot.

A Central usa `ox_target`. Se o jogador retornar ao atendente durante uma linha, a NUI oferece a devolução do ônibus; confirmar cancela a sessão sem recompensa e remove o veículo. As linhas são apresentadas do menor para o maior nível exigido.

O atendente recebe um blip curto no mapa, configurado em `Config.Depot.blip`. Ele some enquanto uma linha está em serviço, porque nesse período o objetivo da vez (próxima parada ou garagem) já é marcado pelo blip de rota; volta ao encerrar ou cancelar a linha. Remover a chave `blip` da config desliga o marcador.

## Interface

A NUI segue o `resources/docs/DESIGN_v3.md`, na mesma aplicação feita no `noir_taxijob`: janela de comando com rail vertical expansível à esquerda, cabeçalho com identidade e perfil, e conteúdo separado por aba.

- **Central** — saudação, métricas, progressão compacta, linha em serviço e uma prévia de até três linhas;
- **Linhas** — catálogo completo com a lista à esquerda e o detalhe (itinerário e ação) à direita;
- **Progressão** — anel de nível, barra de XP e a tabela de níveis da carreira;
- **Ranking** — `SUA POSIÇÃO` fixa acima da lista rolável.

O tema do serviço é definido em `[data-service="bus"]`, dentro de `html/main.css`. Só o acento muda entre resources; posição, largura e comportamento do rail permanecem iguais. A fonte Poppins é empacotada em `html/fonts`, sem CDN, e a barra de rolagem é estilizada uma única vez pelos pseudo-elementos `::-webkit-scrollbar` (v3 §6.5).
