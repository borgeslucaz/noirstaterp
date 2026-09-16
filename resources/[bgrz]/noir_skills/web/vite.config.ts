import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte()],
  // A NUI carrega por `nui://`, então tudo precisa ser relativo.
  base: './',
  build: {
    outDir: 'build',
    emptyOutDir: true,
    // Um arquivo de cada: o manifest publica `web/build/**/*` e menos arquivo é menos
    // chance de um faltar no stream.
    assetsInlineLimit: 0,
  },
});
