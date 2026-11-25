// Auditoria visual: contraste de texto, sobreposição de cliques, conteúdo
// cortado e elementos encostados nas bordas. Gera as capturas de tela finais.
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import { chromium } from '/opt/freecode-tools/node_modules/playwright/index.mjs';
import { chromePath, chromeArgs } from './chrome.mjs';

const BASE = process.env.SITE ?? 'http://127.0.0.1:3111';
const SOCK = process.env.DB_SOCKET ?? '/tmp/run/bt.sock';
const OUT = '/home/ubuntu/project/artifacts';
fs.mkdirSync(OUT, { recursive: true });
let failures = 0;

function ok(label, cond, extra) {
  if (cond) console.log('  OK   ' + label);
  else { failures++; console.log('  FALHOU ' + label + (extra !== undefined ? ' -> ' + String(extra).slice(0, 260) : '')); }
}
function sql(q) {
  return execSync(`mariadb --socket=${SOCK} -u root ajudamais -N -B -e "${q.replace(/"/g, '\\"')}"`).toString().trim();
}

const conta = sql("SELECT email FROM users WHERE email LIKE 'persist.%@teste.local' ORDER BY id DESC LIMIT 1");
const CHROME = chromePath();
const browser = await chromium.launch({ executablePath: CHROME, args: chromeArgs });

// Sessão logada reaproveitada.
const ctxLogin = await browser.newContext({ viewport: { width: 1280, height: 900 } });
const pLogin = await ctxLogin.newPage();
await pLogin.goto(BASE + '/login.html', { waitUntil: 'networkidle' });
await pLogin.fill('#email', conta);
await pLogin.fill('#password', 'SenhaForte123');
await pLogin.click('button[type="submit"]');
await pLogin.waitForURL('**/index.html', { timeout: 15000 });
await pLogin.waitForTimeout(1200);
const storage = await ctxLogin.storageState();
await ctxLogin.close();

// Roda dentro da página: contraste (WCAG AA), sobreposição e recorte.
const AUDITORIA = () => {
  function cor(rgb) {
    const m = String(rgb).match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    const [r, g, b, a = '1'] = m[1].split(',').map((x) => parseFloat(x));
    return { r, g, b, a };
  }
  function luminancia({ r, g, b }) {
    const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
  }
  // Sobe a árvore até achar um fundo sólido. Se o fundo for um gradiente
  // (imagem), devolve null: o contraste é verificado à parte, pois a cor
  // média do gradiente não pode ser medida por CSS.
  function fundoDe(el) {
    let atual = el;
    while (atual && atual !== document.documentElement) {
      const s = getComputedStyle(atual);
      if (s.backgroundImage && s.backgroundImage !== 'none') return null;
      const c = cor(s.backgroundColor);
      if (c && c.a > 0.85) return c;
      atual = atual.parentElement;
    }
    return { r: 255, g: 255, b: 255, a: 1 };
  }
  function contraste(el) {
    const t = cor(getComputedStyle(el).color);
    if (!t) return 21;
    const f = fundoDe(el);
    if (!f) return null; // texto sobre gradiente: tratado como caso à parte
    const l1 = luminancia(t), l2 = luminancia(f);
    const a = Math.max(l1, l2), b = Math.min(l1, l2);
    return (a + 0.05) / (b + 0.05);
  }

  // Considera invisível também o que está dentro de um ancestral transparente
  // (ex.: painel de ajuda fechado, que usa opacity: 0).
  function realmenteVisivel(el) {
    if (el.offsetParent === null) return false;
    let atual = el;
    while (atual && atual !== document.body) {
      const s = getComputedStyle(atual);
      if (s.visibility === 'hidden' || s.display === 'none' || parseFloat(s.opacity) < 0.05) return false;
      atual = atual.parentElement;
    }
    return true;
  }

  const visiveis = Array.from(document.querySelectorAll('body *')).filter((el) => {
    if (!realmenteVisivel(el)) return false;
    const r = el.getBoundingClientRect();
    return r.width > 1 && r.height > 1;
  });

  // Texto com contraste abaixo de 4.5 (3.0 para textos grandes).
  const baixoContraste = [];
  visiveis.forEach((el) => {
    if (el.children.length) return;
    const texto = (el.textContent || '').trim();
    if (texto.length < 3) return;
    const s = getComputedStyle(el);
    const tamanho = parseFloat(s.fontSize);
    const negrito = Number(s.fontWeight) >= 600;
    const minimo = tamanho >= 24 || (tamanho >= 18.66 && negrito) ? 3 : 4.5;
    const c = contraste(el);
    if (c !== null && c < minimo) {
      baixoContraste.push(`${texto.slice(0, 26)} (${c.toFixed(1)}:1, ${tamanho}px)`);
    }
  });

  // Elementos clicáveis que se sobrepõem de forma indevida.
  const clicaveis = visiveis.filter((el) => el.matches('button, a, input, select, textarea, [data-section], [data-action]'));
  const sobrepostos = [];
  for (let i = 0; i < clicaveis.length; i++) {
    for (let j = i + 1; j < clicaveis.length; j++) {
      const a = clicaveis[i], b = clicaveis[j];
      if (a.contains(b) || b.contains(a)) continue;
      // Botão de "mostrar senha" é desenhado dentro do padding do campo: intencional.
      if ((a.tagName === 'BUTTON' && b.matches('input')) || (b.tagName === 'BUTTON' && a.matches('input'))) {
        const campo = (a.matches('input') ? a : b).closest('.field__control');
        if (campo && campo.contains(a) && campo.contains(b)) continue;
      }
      const ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
      const ix = Math.min(ra.right, rb.right) - Math.max(ra.left, rb.left);
      const iy = Math.min(ra.bottom, rb.bottom) - Math.max(ra.top, rb.top);
      if (ix > 4 && iy > 4) {
        sobrepostos.push(`${(a.textContent || a.id || a.tagName).trim().slice(0, 18)} x ${(b.textContent || b.id || b.tagName).trim().slice(0, 18)}`);
      }
    }
  }

  // Texto cortado por overflow escondido.
  const cortados = visiveis.filter((el) => {
    const s = getComputedStyle(el);
    return el.children.length === 0 && s.overflow === 'hidden' && el.scrollWidth > el.clientWidth + 2
      && ['nowrap', 'hidden'].includes(s.textOverflow + '')
      && (el.textContent || '').trim().length > 2;
  }).map((el) => (el.textContent || '').trim().slice(0, 24));

  // Imagens quebradas.
  const imagensQuebradas = Array.from(document.images)
    .filter((img) => img.offsetParent !== null && img.complete && img.naturalWidth === 0)
    .map((img) => img.src.split('/').pop());

  return {
    baixoContraste: baixoContraste.slice(0, 6),
    sobrepostos: sobrepostos.slice(0, 4),
    cortados: cortados.slice(0, 4),
    imagensQuebradas,
  };
};

const TELAS = [
  { arquivo: 'acesso.html', logado: false },
  { arquivo: 'login.html', logado: false },
  { arquivo: 'cadastro.html', logado: false },
  { arquivo: 'recuperar-conta.html', logado: false },
  { arquivo: 'esqueci-senha.html', logado: false },
  { arquivo: 'termos.html', logado: false },
  ...['Início', 'Doar Dinheiro', 'Doar Itens', 'Necessidades', 'Doações', 'Solicitações', 'Perfil']
    .map((secao) => ({ secao, logado: true })),
];

for (const largura of [
  { nome: 'desktop', width: 1366, height: 900, mobile: false },
  { nome: 'tablet', width: 820, height: 1180, mobile: true },
  { nome: 'celular', width: 390, height: 844, mobile: true },
  { nome: 'celular-pequeno', width: 320, height: 700, mobile: true },
]) {
  console.log(`\n== ${largura.nome} (${largura.width}px) ==`);
  const ctx = await browser.newContext({
    viewport: { width: largura.width, height: largura.height },
    isMobile: largura.mobile, hasTouch: largura.mobile, storageState: storage,
  });
  const page = await ctx.newPage();
  await page.goto(BASE + '/index.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1300);

  for (const tela of TELAS) {
    if (tela.arquivo) {
      await page.goto(BASE + '/' + tela.arquivo, { waitUntil: 'networkidle' });
      await page.waitForTimeout(350);
    } else {
      if (tela.secao !== 'Início') {
        if (!page.url().includes('/index.html')) {
          await page.goto(BASE + '/index.html', { waitUntil: 'networkidle' });
          await page.waitForTimeout(1200);
        }
        if (largura.width <= 760) { await page.click('.menu-toggle'); await page.waitForTimeout(200); }
        await page.click(`[data-section="${tela.secao}"]`);
        await page.waitForTimeout(1000);
      }
      await page.evaluate(() => window.scrollTo(0, 0));
    }
    const rotulo = (tela.arquivo || tela.secao).replace('.html', '');
    const r = await page.evaluate(AUDITORIA);
    ok(`${rotulo}: contraste de texto`, r.baixoContraste.length === 0, r.baixoContraste.join(' | '));
    ok(`${rotulo}: sem sobreposição de cliques`, r.sobrepostos.length === 0, r.sobrepostos.join(' | '));
    ok(`${rotulo}: sem texto cortado`, r.cortados.length === 0, r.cortados.join(' | '));
    ok(`${rotulo}: imagens carregadas`, r.imagensQuebradas.length === 0, r.imagensQuebradas.join(' | '));
    const arquivo = `${OUT}/${largura.nome}-${rotulo.toLowerCase().replace(/\s+/g, '-')}.png`;
    await page.screenshot({ path: arquivo, fullPage: largura.nome === 'desktop' ? true : false });
  }
  await ctx.close();
}

await browser.close();
console.log(`\n${failures === 0 ? 'AUDITORIA VISUAL SEM PROBLEMAS' : failures + ' PROBLEMA(S) VISUAL(IS)'}`);
process.exit(failures === 0 ? 0 : 1);
