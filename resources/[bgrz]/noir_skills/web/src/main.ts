import { mount } from 'svelte';
import App from './App.svelte';
import { isBrowser } from './lib/nui';
import './app.css';

// Fora do jogo não há a cena do GTA atrás da tela: no navegador vai a foto do noir_multichar.
// O vite dev serve web/dev/; o build não referencia o arquivo, então ele não vai para o jogo.
if (isBrowser()) {
  document.documentElement.style.setProperty('background', '#000 url(/dev/sinner.png) center/cover no-repeat', 'important');
}

export default mount(App, { target: document.getElementById('app')! });
