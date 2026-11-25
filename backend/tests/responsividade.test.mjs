// Responsividade: cada tela em três larguras, procurando elementos cortados,
// sobreposição, rolagem horizontal e botões fora da área visível.
import { execSync } from 'node:child_process';
import { chromium } from '/opt/freecode-tools/node_modules/playwright/index.mjs';
import { chromePath, chromeArgs } from './chrome.mjs';

const BASE = process.env.SITE ?? 'http://127.0.0.1:3111';
const SOCK = process.env.DB_SOCKET ?? '/tmp/run/bt.sock';
let failures = 0;

function ok(label, cond, extra) {
  if (cond) console.log('  OK   ' + label);
  else { failures++; console.log('  FALHOU ' + label + (extra !== undefined ? ' -> ' + String(extra).slice(0, 200) : '')); }
}
function sql(q) {
  return execSync(`mariadb --socket=${SOCK} -u root ajudamais -N -B -e "${q.replace(/"/g, '\\"')}"`).toString().trim();
}
const rnd = () => Math.random().toString(36).slice(2, 8);

// Conta existente criada pelo teste de persistência (dados reais no MySQL).
const conta = sql("SELECT email FROM users WHERE email LIKE 'persist.%@teste.local' ORDER BY id DESC LIMIT 1");
if (!conta) { console.error('Nenhuma conta de teste encontrada; rode persistencia.test.mjs antes.'); process.exit(1); }

const CHROME = chromePath();
const browser = await chromium.launch({ executablePath: CHROME, args: chromeArgs });

const LARGURAS = [
  { nome: 'celular-pequeno', width: 320, height: 700, mobile: true },
  { nome: 'celular', width: 390, height: 844, mobile: true },
  { nome: 'tablet', width: 820, height: 1180, mobile: true },
  { nome: 'tablet-estreito', width: 760, height: 1024, mobile: true },
  { nome: 'desktop', width: 1366, height: 900, mobile: false },
];

// Loga uma vez e reaproveita a sessão nas três larguras.
const loginCtx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
const loginPage = await loginCtx.newPage();
await loginPage.goto(BASE + '/login.html', { waitUntil: 'networkidle' });
await loginPage.fill('#email', conta);
await loginPage.fill('#password', 'SenhaForte123');
await loginPage.click('button[type="submit"]');
await loginPage.waitForURL('**/index.html', { timeout: 15000 });
await loginPage.waitForTimeout(1200);
const storage = await loginCtx.storageState();
await loginCtx.close();

const PAGINAS_PUBLICAS = ['acesso.html', 'login.html', 'cadastro.html', 'recuperar-conta.html', 'esqueci-senha.html', 'termos.html'];
const SECOES = ['Início', 'Doar Dinheiro', 'Doar Itens', 'Necessidades', 'Doações', 'Solicitações', 'Perfil'];

async function analisar(pagina, rotulo, largura, mobile) {
  const medidas = await pagina.evaluate(() => {
    const doc = document.documentElement;
    const overflow = doc.scrollWidth - doc.clientWidth;
    const larguraJanela = window.innerWidth;
    // Elementos que estouram a tela pela direita (excluindo menus escondidos).
    const estourados = [];
    document.querySelectorAll('body *').forEach((el) => {
      const estilo = getComputedStyle(el);
      if (estilo.display === 'none' || estilo.visibility === 'hidden' || estilo.position === 'fixed') return;
      if (el.offsetParent === null) return;
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) return;
      if (r.right > larguraJanela + 2 || r.left < -2) {
        estourados.push(`${el.tagName.toLowerCase()}${el.id ? '#' + el.id : ''}.${String(el.className).split(' ')[0]} [${Math.round(r.left)}..${Math.round(r.right)}]`);
      }
    });
    // Botões menores que a área mínima de toque recomendada no celular.
    const pequenos = [];
    // O CSS troca para o menu compacto em max-width: 760px.
    if (window.innerWidth <= 760) {
      document.querySelectorAll('button, a.primary-button, .nav-link').forEach((el) => {
        if (el.offsetParent === null) return;
        const r = el.getBoundingClientRect();
        if (r.width === 0) return;
        if (r.height < 28) pequenos.push(`${el.tagName.toLowerCase()}.${String(el.className).split(' ')[0]} h=${Math.round(r.height)}`);
      });
    }
    return { overflow, estourados: estourados.slice(0, 4), pequenos: pequenos.slice(0, 4) };
  });
  ok(`${rotulo}: sem rolagem horizontal`, medidas.overflow <= 2, medidas.overflow);
  ok(`${rotulo}: nada estourando a tela`, medidas.estourados.length === 0, medidas.estourados.join(' | '));
  if (mobile) ok(`${rotulo}: botões com altura tocável`, medidas.pequenos.length === 0, medidas.pequenos.join(' | '));
}

for (const largura of LARGURAS) {
  console.log(`\n== ${largura.nome} (${largura.width}px) ==`);
  const context = await browser.newContext({
    viewport: { width: largura.width, height: largura.height },
    isMobile: largura.mobile, hasTouch: largura.mobile,
    storageState: largura.nome === 'desktop' ? undefined : storage,
  });
  const page = await context.newPage();
  const erros = [];
  page.on('pageerror', (e) => erros.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') erros.push(m.text()); });

  for (const nome of PAGINAS_PUBLICAS) {
    await page.goto(BASE + '/' + nome, { waitUntil: 'networkidle' });
    await page.waitForTimeout(350);
    await analisar(page, `${largura.nome} ${nome}`, largura.width, largura.mobile);
  }

  // Painel logado: uma imagem por seção para inspeção visual.
  await page.goto(BASE + '/index.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1300);
  for (const secao of SECOES) {
    if (secao !== 'Início') {
      if (largura.width <= 760) {
        await page.click('.menu-toggle');
        await page.waitForTimeout(200);
      }
      await page.click(`[data-section="${secao}"]`);
      await page.waitForTimeout(1000);
    }
    await analisar(page, `${largura.nome} ${secao}`, largura.width, largura.mobile);
    await page.screenshot({ path: `/tmp/resp-${largura.nome}-${secao.replace(/\s+/g, '-').toLowerCase()}.png`, fullPage: false });
  }

  const reais = erros.filter((e) => !/Failed to load resource.*(favicon|401|422)/.test(e));
  ok(`${largura.nome}: sem erro de script`, reais.length === 0, reais.slice(0, 2).join(' | '));
  await context.close();
}

// Menu continua funcionando no menor celular.
console.log('\n== navegação no menor celular ==');
const ctx = await browser.newContext({ viewport: { width: 320, height: 700 }, isMobile: true, hasTouch: true, storageState: storage });
const p = await ctx.newPage();
await p.goto(BASE + '/index.html', { waitUntil: 'networkidle' });
await p.waitForTimeout(1200);
const fechado = await p.$$eval('.nav-link', (els) => els.filter((e) => e.offsetParent !== null).length);
await p.click('.menu-toggle');
await p.waitForTimeout(300);
const aberto = await p.$$eval('.nav-link', (els) => els.filter((e) => e.offsetParent !== null).length);
ok('menu fecha mostrando só a aba ativa', fechado === 1, fechado);
ok('menu abre as 7 abas', aberto === 7, aberto);
await p.click('[data-section="Perfil"]');
await p.waitForTimeout(900);
ok('navegação funciona no menor celular', (await p.textContent('#app')).includes('Meu Perfil'));
await ctx.close();

await browser.close();
console.log(`\n${failures === 0 ? 'TODOS OS TESTES DE RESPONSIVIDADE PASSARAM' : failures + ' FALHA(S)'}`);
process.exit(failures === 0 ? 0 : 1);
