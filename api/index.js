// Entrada do deploy na Vercel: a API Express vira uma função única e atende
// /api/*. O site (frontend/) é publicado como estático pelo vercel.json.
// No Windows continue usando "npm start" dentro de backend/.
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Repassa a pasta do site para o app servir os arquivos se algo cair aqui.
process.env.FRONTEND_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  'frontend',
);

const { default: app } = await import('../backend/src/app.js');
export default app;
