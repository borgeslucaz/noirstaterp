import path from 'node:path';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [svelte(), tailwindcss()],
	base: './',
	build: {
		outDir: 'dist',
		emptyOutDir: true,
		assetsInlineLimit: 0,
		// NUI ships one fat bundle to offline CEF (full Iconify set inlined);
		// code-splitting breaks offline resolve, so the size warning is N/A.
		chunkSizeWarningLimit: 10000,
	},
	resolve: {
		alias: {
			'@': path.resolve(__dirname, './src'),
		},
	},
	server: {
		// Fixed framework-wide dev port. NEVER change.
		port: 5174,
	},
});
