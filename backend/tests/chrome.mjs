// Localiza o Chromium do Playwright sem depender do número da versão instalada.
// Usado pelos testes de navegador deste projeto.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const RAIZES = [
  process.env.PLAYWRIGHT_BROWSERS_PATH,
  path.join(os.homedir(), '.cache', 'ms-playwright'),
  '/root/.cache/ms-playwright',
  '/ms-playwright',
].filter(Boolean);

function procurar(dir) {
  if (!fs.existsSync(dir)) return null;
  const candidatos = [];
  for (const entrada of fs.readdirSync(dir)) {
    if (!entrada.startsWith('chromium-')) continue; // ignora headless-shell e ffmpeg
    for (const sub of ['chrome-linux64/chrome', 'chrome-linux/chrome']) {
      const exe = path.join(dir, entrada, sub);
      if (fs.existsSync(exe)) candidatos.push({ exe, versao: Number(entrada.split('-')[1]) || 0 });
    }
  }
  candidatos.sort((a, b) => b.versao - a.versao);
  return candidatos[0]?.exe ?? null;
}

export function chromePath() {
  if (process.env.CHROME_PATH && fs.existsSync(process.env.CHROME_PATH)) return process.env.CHROME_PATH;
  for (const raiz of RAIZES) {
    const achado = procurar(raiz);
    if (achado) return achado;
  }
  throw new Error('Chromium não encontrado. Rode: npx playwright install chromium');
}

export const chromeArgs = ['--no-sandbox', '--disable-dev-shm-usage'];
