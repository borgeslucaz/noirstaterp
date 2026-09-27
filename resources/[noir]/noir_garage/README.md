# noir_garage

Garagens e pátio da Noir State. Substitui o `qbx_garages`.

- Servidor: lógica do `qbx_garages` 1.1.4 com os nossos patches (motor
  desligado, porta destrancada, modelo validado pela lista do `qbx_core`, cópia
  da chave e troca de fechadura pelo `mri_Qcarkeys`).
- Interface: a do [rhd_garage](https://github.com/RHD-FiveM/rhd_garage) 1.0.0
  (React + Mantine), em pt-br, com prévia 3D, apelido, histórico e
  transferência entre garagens.
- O cliente só manda o id do carro. Garagem, guichê, dono, preço e modelo são
  conferidos no servidor.

## Instalação

- `ensure [noir]` no `server.cfg`, depois de `[qbx]` e do `mri_Qcarkeys`.
- A tabela `noir_garage_vehicles` (apelido e histórico) é criada no start.

## Configuração

- `config/server.lua`: garagens (`garages`), preços da chave e da fechadura,
  transferência, apelido e distâncias.
- `config/client.lua`: motor ligado ao sair e marcadores.

## Interface

A fonte fica em `web/src`. O `web/build` vai no git, porque o servidor não
compila nada.

```bash
cd web
npm ci
npm run build
```

`npm run dev` abre a tela no navegador com dados falsos (botão "Abrir garagem").

## Para outros resources

- Exports: `GetGarages`, `RegisterGarage`, `SetVehicleGarage`,
  `SetVehicleDepotPrice`.
- Evento de servidor: `noir_garage:server:vehicleSpawned` (entidade do carro).

## Licença

Derivado do `qbx_garages` (GPL-3.0, ver `LICENSE-qbx_garages`), então o
resource segue a GPL-3.0. A interface e a câmera vêm do `rhd_garage` (MIT, ver
`LICENSE-rhd_garage`).
