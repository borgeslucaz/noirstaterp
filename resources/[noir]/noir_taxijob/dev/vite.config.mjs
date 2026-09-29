// Preview da NUI no navegador. Raiz = pasta do resource; dev/ não entra no fxmanifest.
//     <vite da garagem> --config dev/vite.config.mjs --host 127.0.0.1 --port 9120
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));

export default {
  root: path.resolve(here, '..'),
  server: { allowedHosts: ['taxi.noirstate.com.br'] },
};
