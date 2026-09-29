import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { isEnvBrowser } from './utils/misc.ts'

import DeathApp from './DeathApp.tsx'
import DebugButtons from './components/DebugButtons.tsx'

import './index.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <DeathApp />
    <DebugButtons />
  </StrictMode>,
)

// Fora do jogo nao ha a cena do GTA atras da tela: no navegador vai a mesma foto do noir_multichar.
// O vite dev serve web/dev/; o build nao referencia o arquivo, entao ele nao vai para o jogo.
if (isEnvBrowser()) {
  document.documentElement.style.setProperty('background', '#000 url(/dev/sinner.png) center/cover no-repeat', 'important');
}
