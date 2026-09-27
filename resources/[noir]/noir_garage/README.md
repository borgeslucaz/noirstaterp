# noir_garage

Garagens e pátio da Noir State. Substitui o `qbx_garages`.

- Servidor: lógica do `qbx_garages` 1.1.4 com os nossos patches (motor
  desligado, porta destrancada, modelo validado pela lista do `qbx_core`, cópia
  da chave e troca de fechadura pelo `mri_Qcarkeys`).
- Interface: menu na lateral direita, no estilo do `lib.registerMenu` do ox_lib
  (setas, Enter e Backspace), em colunas lado a lado, com os tokens do
  `docs/DESIGN_v3.md` e as fontes Saira Condensed e Rajdhani (empacotadas).
  Prévia 3D, apelido, histórico, transferência entre garagens, cópia de chave e
  troca de fechadura. A câmera da prévia vem do
  [rhd_garage](https://github.com/RHD-FiveM/rhd_garage) 1.0.0.
- O cliente só manda o id do carro. Garagem, guichê, dono, preço e modelo são
  conferidos no servidor.

## Instalação

- `ensure [noir]` no `server.cfg`, depois de `[qbx]` e do `mri_Qcarkeys`.
- A tabela `noir_garage_vehicles` (apelido e histórico) é criada no start.

## Editor no jogo

`/garagem` abre o editor (ACE `noir.garageadmin`, dada ao `group.admin` no
`permissions.cfg`). Cria, edita e apaga garagens: nome, tipo de veículo, pátio,
compartilhada, grupos e os pontos de acesso (balcão, vagas de saída, ponto de
guardar, blip, atendente e interação). "Marcar" esconde o editor: ande até o lugar e aperte E (Backspace cancela).

- As garagens ficam na tabela `noir_garage_locations`. No primeiro start ela é
  preenchida com as garagens de `config/server.lua`; daí em diante o config só
  serve de semente.
- Salvar e apagar valem na hora para todos (zonas e blips são recriados).
- Garagem com carros guardados não pode ser apagada.
- Cada ponto tem até 10 vagas de saída, tentadas em ordem: o carro sai na
  primeira sem veículo por perto (`distanceCheck`); só com todas ocupadas vem o
  aviso de falta de espaço. Sem ponto de guardar marcado, guarda na vaga 1.
  No editor, as vagas ficam numa coluna própria: "Adicionar vaga" e
  "Reposicionar" usam um carro de teste que segue a mira (o modelo do carro em
  que o admin está, ou um Sultan a pé); Enter numa vaga abre Remover/Reposicionar.
- Cada ponto pode ter um atendente (PED local, com modelo e animação) e abrir
  por "Aperte E" (marcador no chão) ou por ox_target (no atendente ou numa esfera
  no balcão), pelo target do `bgrz_core`. Guardar o carro continua no E. O
  atendente nasce na posição e direção de quem marcou o balcão, ou numa posição
  própria ("Posicionar atendente": o PED segue o chão para onde a câmera mira, a
  roda do mouse gira, Enter confirma), com giro de 45° em 45° no editor. O
  `object_gizmo` não é usado: no Enhanced ele desenha as alças mas não pega o
  clique. O target acompanha o PED; a área do E fica no balcão. O modelo do PED é conferido no cliente antes de criar: modelo inexistente não
  cria nada (no Enhanced, derrubaria o jogo).

## Configuração

- `config/server.lua`: garagens iniciais (`garages`, só no primeiro start),
  preços da chave e da fechadura, transferência, apelido, distâncias e a ACE do
  editor (`adminAce`).
- `config/client.lua`: motor ligado ao sair e marcadores.

## Interface

A fonte fica em `web/src`. O `web/build` vai no git, porque o servidor não
compila nada.

```bash
cd web
npm ci
npm run build
```

`npm run dev` abre a tela no navegador com dados falsos (botões "Abrir garagem"
e "Abrir pátio", no canto inferior esquerdo).

## Para outros resources

- Exports: `GetGarages`, `RegisterGarage`, `SetVehicleGarage`,
  `SetVehicleDepotPrice`.
- Evento de servidor: `noir_garage:server:vehicleSpawned` (entidade do carro).

## Licença

Derivado do `qbx_garages` (GPL-3.0, ver `LICENSE-qbx_garages`), então o
resource segue a GPL-3.0. A câmera da prévia vem do `rhd_garage` (MIT, ver
`LICENSE-rhd_garage`).
