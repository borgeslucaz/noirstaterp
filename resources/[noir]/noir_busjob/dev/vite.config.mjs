// Preview da NUI no navegador. Raiz = pasta do resource; dev/ não entra no fxmanifest.
//     lua5.4 dev/mock.lua > dev/mock.json
//     <vite da garagem> --config dev/vite.config.mjs --host 127.0.0.1 --port 9110
import { createReadStream, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
// No jogo os tiles vêm de nui://noir_territories/web/tiles; aqui, do disco.
const tiles = path.resolve(here, '../../noir_territories/web/tiles');

export default {
  root: path.resolve(here, '..'),
  server: { allowedHosts: ['onibus.noirstate.com.br'] },
  plugins: [{
    name: 'territory-tiles',
    configureServer(server) {
      server.middlewares.use('/territory-tiles', (req, res, next) => {
        const file = path.join(tiles, decodeURIComponent(req.url.split('?')[0]));
        if (!file.startsWith(tiles) || !existsSync(file)) return next();
        res.setHeader('Content-Type', 'image/png');
        createReadStream(file).pipe(res);
      });
    },
  }],
};
