// Preview da NUI no navegador. Raiz = pasta do resource; dev/ não entra no fxmanifest.
import { createReadStream, existsSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const oxImages = path.resolve(here, '../../../[ox]/ox_inventory/web/images');

export default {
  root: path.resolve(here, '..'),
  plugins: [{
    name: 'ox-images',
    // nui://ox_inventory/web/images/* vira /ox-images/* no preview.
    configureServer(server) {
      // Lista de imagens para o seletor do admin (no jogo vem do ScanImages do server.lua).
      server.middlewares.use('/ox-images-list', (req, res) => {
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(readdirSync(oxImages).filter((f) => f.endsWith('.png')).sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()))));
      });
      server.middlewares.use('/ox-images', (req, res, next) => {
        const file = path.join(oxImages, decodeURIComponent(req.url.split('?')[0]));
        if (!file.startsWith(oxImages) || !existsSync(file)) return next();
        res.setHeader('Content-Type', 'image/png');
        createReadStream(file).pipe(res);
      });
    },
  }],
};
