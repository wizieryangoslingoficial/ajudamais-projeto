// Persistência real: cria dados pela interface, sai, inicia uma sessão nova
// do zero (navegador limpo), entra de novo e confirma que tudo voltou do MySQL.
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
function makeCpf() {
  const n = Array.from({ length: 9 }, () => Math.floor(Math.random() * 10));
  for (const len of [9, 10]) {
    let sum = 0;
    for (let i = 0; i < len; i++) sum += n[i] * (len + 1 - i);
    n.push(((sum * 10) % 11) % 10);
  }
  return n.join('');
}
const rnd = () => Math.random().toString(36).slice(2, 8);

const CHROME = chromePath();
const launch = () => chromium.launch({ executablePath: CHROME, args: chromeArgs });

const email = `persist.${rnd()}@teste.local`;
const cpf = makeCpf();
const phone = `(14) 9${String(Math.floor(10000000 + Math.random() * 89999999))}`;
const password = 'SenhaForte123';
const marcador = 'PERSIST' + rnd();

// ---- Sessão 1: cadastro e criação de dados ------------------------------
let browser = await launch();
let context = await browser.newContext({ viewport: { width: 1366, height: 900 } });
let page = await context.newPage();
page.on('dialog', (d) => d.accept());

console.log('== 1. cadastro e criação dos dados ==');
await page.goto(BASE + '/acesso.html', { waitUntil: 'networkidle' });
await page.check('#terms-checkbox');
await page.click('#btn-signup');
await page.waitForURL('**/cadastro.html');
await page.fill('#name', 'Carla Persistência');
await page.fill('#email', email);
await page.fill('#cpf', cpf);
await page.fill('#password', password);
await page.fill('#confirm', password);
await page.click('button[type="submit"]');
await page.waitForURL('**/index.html', { timeout: 15000 });
await page.waitForTimeout(1000);

// Perfil
await page.click('[data-section="Perfil"]');
await page.waitForSelector('#profile-form');
await page.fill('#pf-name', 'Carla Persistência Silva');
await page.fill('#pf-display', 'Carla P.');
await page.fill('#pf-phone', phone);
await page.fill('#pf-birth', '1990-05-20');
await page.click('#profile-form button[type="submit"]');
await page.waitForTimeout(1500);
ok('perfil salvo', sql(`SELECT CONCAT(full_name,'|',display_name,'|',DATE_FORMAT(birth_date,'%Y-%m-%d')) FROM users WHERE email='${email}'`) === 'Carla Persistência Silva|Carla P.|1990-05-20');

// Endereço
await page.fill('#ad-street', 'Rua Persistente, 77');
await page.fill('#ad-label', 'Casa');
await page.fill('#ad-city', 'Botucatu');
await page.click('#address-form button[type="submit"]');
await page.waitForTimeout(1400);
ok('endereço salvo', sql(`SELECT COUNT(*) FROM addresses a JOIN users u ON u.id=a.user_id WHERE u.email='${email}' AND a.street='Rua Persistente, 77'`) === '1');

// Doação em dinheiro
await page.click('[data-section="Doar Dinheiro"]');
await page.waitForSelector('#donation-form');
await page.click('.preset-btn[data-val="200"]');
await page.waitForTimeout(300);
await page.fill('#donor-phone', phone);
await page.click('#donation-form button[type="submit"]');
await page.waitForFunction(() => /Doação registrada/.test(document.querySelector('.toast')?.textContent || ''), null, { timeout: 10000 }).catch(() => {});
ok('doação em dinheiro salva', sql(`SELECT amount FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}' AND d.donation_type='dinheiro'`) === '200.00');

// Doação de itens
await page.click('[data-section="Doar Itens"]');
await page.waitForSelector('#item-donation-form');
await page.click('.item-plus-btn[data-item="Arroz"]');
await page.waitForTimeout(300);
await page.click('.item-plus-btn[data-item="Arroz"]');
await page.waitForTimeout(300);
await page.fill('#item-donor-phone', phone);
await page.fill('#item-donor-address', 'Rua Coleta, 12');
await page.fill('#item-donor-city', 'Botucatu');
await page.click('#item-donation-form button[type="submit"]');
await page.waitForFunction(() => /Doação de itens registrada/.test(document.querySelector('.toast')?.textContent || ''), null, { timeout: 12000 }).catch(() => {});
ok('doação de itens salva', sql(`SELECT COUNT(*) FROM donation_items i JOIN donations d ON d.id=i.donation_id JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}'`) === '1');

// Solicitação
await page.click('[data-section="Solicitações"]');
await page.waitForSelector('#request-form');
await page.fill('#req-title', 'Pedido ' + marcador);
await page.fill('#req-description', 'Descrição que precisa sobreviver ao logout');
await page.selectOption('#req-priority', 'alta');
await page.fill('#req-city', 'Botucatu');
await page.fill('#req-uf', 'SP');
await page.fill('#req-people', '3');
await page.fill('.req-item-desc', 'Cobertor');
await page.fill('.req-item-qty', '2');
await page.click('#request-form button[type="submit"]');
await page.waitForTimeout(1600);
ok('solicitação salva', sql(`SELECT COUNT(*) FROM assistance_requests WHERE title='Pedido ${marcador}'`) === '1');

const antes = {
  doacoes: Number(sql(`SELECT COUNT(*) FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}'`)),
  enderecos: Number(sql(`SELECT COUNT(*) FROM addresses a JOIN users u ON u.id=a.user_id WHERE u.email='${email}'`)),
  solicitacoes: Number(sql(`SELECT COUNT(*) FROM assistance_requests r JOIN users u ON u.id=r.requester_user_id WHERE u.email='${email}'`)),
};

console.log('== 2. sair e fechar o navegador (sessão encerrada) ==');
await page.click('[data-action="logout"]');
await page.waitForURL('**/acesso.html', { timeout: 10000 });
ok('token removido no logout', (await page.evaluate(() => localStorage.getItem('ajudamais_token'))) === null);
await browser.close();

console.log('== 3. sessão nova e login (dados vêm do MySQL) ==');
browser = await launch();
context = await browser.newContext({ viewport: { width: 1366, height: 900 } });
page = await context.newPage();
page.on('dialog', (d) => d.accept());
await page.goto(BASE + '/login.html', { waitUntil: 'networkidle' });
await page.fill('#cpf', cpf);
await page.fill('#password', password);
await page.click('button[type="submit"]');
await page.waitForURL('**/index.html', { timeout: 15000 });
await page.waitForTimeout(1500);

await page.click('[data-section="Perfil"]');
await page.waitForSelector('#profile-form');
await page.waitForTimeout(800);
ok('perfil recuperado após novo login', (await page.inputValue('#pf-name')) === 'Carla Persistência Silva', await page.inputValue('#pf-name'));
ok('apelido recuperado', (await page.inputValue('#pf-display')) === 'Carla P.', await page.inputValue('#pf-display'));
ok('nascimento recuperado', (await page.inputValue('#pf-birth')) === '1990-05-20', await page.inputValue('#pf-birth'));
ok('endereço aparece no perfil', (await page.textContent('#app')).includes('Rua Persistente, 77'));

await page.click('[data-section="Doações"]');
await page.waitForTimeout(1200);
const minhas = await page.textContent('#app');
ok('minhas doações recuperadas', (minhas.match(/Pendente/g) || []).length >= 2, null);
ok('valor R$ 200,00 aparece na lista', minhas.includes('200,00'), null);

await page.click('[data-section="Solicitações"]');
await page.waitForTimeout(1200);
ok('solicitação recuperada', (await page.textContent('#app')).includes('Pedido ' + marcador), null);

await page.click('[data-section="Início"]');
await page.waitForTimeout(1500);
const valores = await page.$$eval('.stat-value', (els) => els.map((e) => e.textContent.trim()));
ok('estatísticas continuam carregando', valores.length > 0 && valores.every((v) => v && v !== '—'), valores);
ok('saudação com o nome salvo', (await page.textContent('#welcome-title')).includes('Carla'), null);

console.log('== 4. conferência direta no MySQL ==');
ok('doações no banco após login', Number(sql(`SELECT COUNT(*) FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}'`)) === antes.doacoes, antes.doacoes);
ok('endereços no banco após login', Number(sql(`SELECT COUNT(*) FROM addresses a JOIN users u ON u.id=a.user_id WHERE u.email='${email}'`)) === antes.enderecos, antes.enderecos);
ok('solicitações no banco após login', Number(sql(`SELECT COUNT(*) FROM assistance_requests r JOIN users u ON u.id=r.requester_user_id WHERE u.email='${email}'`)) === antes.solicitacoes, antes.solicitacoes);
ok('senha continua como hash após novo login', /^\$2[aby]\$/.test(sql(`SELECT password_hash FROM users WHERE email='${email}'`)));
ok('sessões antigas revogadas, sessão nova ativa',
  Number(sql(`SELECT COUNT(*) FROM sessions s JOIN users u ON u.id=s.user_id WHERE u.email='${email}' AND s.revoked_at IS NULL`)) === 1);

// ---- Celular: os mesmos dados aparecem --------------------------------
console.log('== 5. celular: dados após login ==');
const mob = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
const mpage = await mob.newPage();
mpage.on('dialog', (d) => d.accept());
await mpage.goto(BASE + '/login.html', { waitUntil: 'networkidle' });
await mpage.fill('#cpf', cpf);
await mpage.fill('#password', password);
await mpage.click('button[type="submit"]');
await mpage.waitForURL('**/index.html', { timeout: 15000 });
await mpage.waitForTimeout(1200);
await mpage.click('.menu-toggle');
await mpage.waitForTimeout(250);
await mpage.click('[data-section="Doações"]');
await mpage.waitForTimeout(1400);
ok('celular: minhas doações carregadas', (await mpage.textContent('#app')).includes('200,00'), null);
await mpage.click('.menu-toggle');
await mpage.waitForTimeout(250);
await mpage.click('[data-section="Perfil"]');
await mpage.waitForTimeout(1200);
ok('celular: perfil carregado', (await mpage.inputValue('#pf-name')) === 'Carla Persistência Silva', null);
ok('celular: sem rolagem horizontal', (await mpage.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)) <= 2, null);
await mpage.screenshot({ path: '/tmp/mobile-persistencia.png', fullPage: true });
await mob.close();

await browser.close();
console.log(`\n${failures === 0 ? 'TODOS OS TESTES DE PERSISTÊNCIA PASSARAM' : failures + ' FALHA(S)'}`);
process.exit(failures === 0 ? 0 : 1);
