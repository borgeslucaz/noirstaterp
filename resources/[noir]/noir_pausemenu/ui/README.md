# Noir Pause Menu UI

Reconstructed, maintainable source for the resource NUI.

## Development

```bash
npm install
npm run dev
```

For the in-game production bundle:

```bash
npm run build
```

Vite writes the compiled interface to `ui/dist`, which is the page loaded by
the resource's `fxmanifest.lua`.

## NUI contract

Lua sends these actions to the interface: `setLocale`, `updatePlayerData`,
`updateServerInfo`, `updateFilter`, `updateBlur`, `route`, `setVisible`,
`requestClose`, and `close`.

The interface calls these Lua callbacks: `close`, `closeComplete`,
`openSettings`, `openMap`, `enterPhotomode`, `exitPhotomode`, `rotateCamera`,
`cycleFilter`, `setFilterIndex`, `photomodeDrag`, `photomodeZoom`, `toggleBlur`,
and `exitServer`.
