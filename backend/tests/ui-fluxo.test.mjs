// Teste de interface real: abre o site no Chromium, preenche os formulários
// como um usuário e confere no MySQL que os dados foram gravados.
import { execSync } from 'node:child_process';
import { chromium } from '/opt/freecode-tools/node_modules/playwright/index.mjs';
import { chromePath, chromeArgs } from './chrome.mjs';

const BASE = process.env.SITE ?? 'http://127.0.0.1:3111';
const SOCK = process.env.DB_SOCKET ?? '/tmp/run/bt.sock';
let failures = 0;
const consoleErrors = [];

function ok(label, cond, extra) {
  if (cond) console.log('  OK   ' + label);
  else { failures++; console.log('  FALHOU ' + label + (extra !== undefined ? ' -> ' + String(extra).slice(0, 240) : '')); }
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

const browser = await chromium.launch({
  executablePath: chromePath(),
  args: chromeArgs,
});
const context = await browser.newContext({ viewport: { width: 1366, height: 900 } });
const page = await context.newPage();
page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('pageerror', (e) => consoleErrors.push('pageerror: ' + e.message));

const email = `ui.${rnd()}@teste.local`;
const cpf = makeCpf();
const phone = `(14) 9${String(Math.floor(10000000 + Math.random() * 89999999))}`;
const password = 'SenhaForte123';

console.log('== A. páginas carregam sem erro ==');
for (const p of ['acesso.html', 'login.html', 'cadastro.html', 'recuperar-conta.html', 'esqueci-senha.html', 'termos.html', 'index.html']) {
  const resp = await page.goto(BASE + '/' + p, { waitUntil: 'networkidle' });
  ok(`${p} responde 200`, resp && resp.status() === 200, resp && resp.status());
}

console.log('== B. cadastro pela tela ==');
await page.goto(BASE + '/acesso.html', { waitUntil: 'networkidle' });
await page.check('#terms-checkbox');
await page.click('#btn-signup');
await page.waitForURL('**/cadastro.html');
await page.fill('#name', 'Joana Interface');
await page.fill('#email', email);
await page.fill('#cpf', cpf.replace(/^(\d{3})(\d{3})(\d{3})(\d{2})$/, '$1.$2.$3-$4'));
await page.fill('#password', password);
await page.fill('#confirm', password);
await page.click('button[type="submit"]');
await page.waitForURL('**/index.html', { timeout: 15000 });
ok('cadastro redireciona para o painel', page.url().includes('index.html'), page.url());
ok('usuário existe no MySQL', sql(`SELECT COUNT(*) FROM users WHERE email='${email}'`) === '1');
const token = await page.evaluate(() => localStorage.getItem('ajudamais_token'));
ok('token salvo no navegador', !!token);

console.log('== C. painel mostra dados do banco ==');
await page.waitForTimeout(1500);
const welcome = await page.textContent('#welcome-title');
ok('saudação usa o nome do usuário', welcome.includes('Joana'), welcome);
const statValues = await page.$$eval('.stat-value', (els) => els.map((e) => e.textContent.trim()));
ok('estatísticas carregadas (não vazias)', statValues.every((v) => v && v !== '—'), statValues);
ok('estatísticas batem com o banco', statValues[0] === 'R$ ' + Number(sql("SELECT COALESCE(SUM(amount),0) FROM donations WHERE deleted_at IS NULL AND donation_type='dinheiro' AND status IN ('confirmada','em_transito','recebida')")).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), statValues[0]);

console.log('== D. doação em dinheiro pela tela ==');
await page.click('[data-section="Doar Dinheiro"]');
await page.waitForSelector('#donation-form');
await page.click('.preset-btn[data-val="50"]');
await page.waitForSelector('#donation-form');
await page.fill('#donor-phone', phone);
await page.click('#donation-form button[type="submit"]');
await page.waitForTimeout(2000);
const moneyCount = sql(`SELECT COUNT(*) FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}' AND d.donation_type='dinheiro'`);
ok('doação em dinheiro gravada', moneyCount === '1', moneyCount);
const amount = sql(`SELECT d.amount FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}' AND d.donation_type='dinheiro'`);
ok('valor R$ 50,00 no banco', amount === '50.00', amount);
ok('tela de sucesso aparece', (await page.content()).includes('Doação aprovada com sucesso'), null);

console.log('== E. doação de itens pela tela ==');
await page.click('[data-section="Doar Itens"]');
await page.waitForSelector('#item-donation-form');
await page.click('.item-plus-btn[data-item="Arroz"]');
await page.waitForSelector('#item-donation-form');
await page.click('.item-plus-btn[data-item="Arroz"]');
await page.waitForSelector('#item-donation-form');
await page.click('.item-plus-btn[data-item="Feijão"]');
await page.waitForSelector('#item-donation-form');
await page.fill('#item-donor-phone', phone);
await page.fill('#item-donor-address', 'Rua das Flores, 45');
await page.fill('#item-donor-city', 'Botucatu');
await page.click('#item-donation-form button[type="submit"]');
await page.waitForTimeout(2500);
const itemDonation = sql(`SELECT d.id FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}' AND d.donation_type='itens' LIMIT 1`);
ok('doação de itens gravada', !!itemDonation, itemDonation);
ok('2 linhas de itens no banco', sql(`SELECT COUNT(*) FROM donation_items WHERE donation_id=${itemDonation || 0}`) === '2', null);
ok('quantidade total 3', sql(`SELECT SUM(quantity) FROM donation_items WHERE donation_id=${itemDonation || 0}`) === '3.00', null);
const addrId = sql(`SELECT dropoff_address_id FROM donations WHERE id=${itemDonation || 0}`);
ok('endereço de coleta vinculado', addrId && addrId !== 'NULL', addrId);
ok('endereço de coleta no banco', sql(`SELECT CONCAT(street,'|',city) FROM addresses WHERE id=${addrId || 0}`) === 'Rua das Flores, 45|Botucatu', null);

console.log('== F. Minhas Doações ==');
await page.click('[data-section="Doações"]');
await page.waitForTimeout(1800);
const doacoesHtml = await page.textContent('#app');
ok('lista mostra o código da doação', /AJM[A-Z0-9]{5}/.test(doacoesHtml), null);
ok('lista mostra as duas doações', (doacoesHtml.match(/Pendente/g) || []).length >= 2, null);

console.log('== G. perfil: editar dados ==');
await page.click('[data-section="Perfil"]');
await page.waitForSelector('#profile-form');
await page.fill('#pf-display', 'Joana I.');
await page.fill('#pf-birth', '1995-07-14');
await page.click('#profile-form button[type="submit"]');
await page.waitForTimeout(1800);
ok('apelido salvo no MySQL', sql(`SELECT display_name FROM users WHERE email='${email}'`) === 'Joana I.', null);
ok('nascimento salvo no MySQL', sql(`SELECT DATE_FORMAT(birth_date,'%Y-%m-%d') FROM users WHERE email='${email}'`) === '1995-07-14', null);

console.log('== H. perfil: adicionar endereço ==');
await page.click('[data-section="Perfil"]');
await page.waitForSelector('#address-form');
await page.fill('#ad-street', 'Av. Central, 900');
await page.fill('#ad-label', 'Casa');
await page.fill('#ad-city', 'Botucatu');
await page.click('#address-form button[type="submit"]');
await page.waitForTimeout(1800);
ok('endereço do perfil no MySQL', sql(`SELECT COUNT(*) FROM addresses a JOIN users u ON u.id=a.user_id WHERE u.email='${email}' AND a.street='Av. Central, 900'`) === '1', null);

console.log('== I. solicitação de ajuda ==');
await page.click('[data-section="Solicitações"]');
await page.waitForSelector('#request-form');
await page.fill('#req-title', 'Cobertores para família');
await page.fill('#req-description', 'Precisamos de cobertores para o inverno');
await page.selectOption('#req-priority', 'urgente');
await page.fill('#req-city', 'Botucatu');
await page.fill('#req-uf', 'sp');
await page.fill('#req-people', '4');
await page.fill('.req-item-desc', 'Cobertor');
await page.fill('.req-item-qty', '3');
await page.click('#request-form button[type="submit"]');
await page.waitForTimeout(2000);
const reqRow = sql(`SELECT CONCAT(r.id,'|',r.priority,'|',r.state_code) FROM assistance_requests r JOIN users u ON u.id=r.requester_user_id WHERE u.email='${email}' LIMIT 1`);
ok('solicitação gravada', !!reqRow, reqRow);
ok('prioridade e UF corretas', reqRow && reqRow.includes('|urgente|SP'), reqRow);
const reqId = (reqRow || '0|').split('|')[0];
ok('item da solicitação gravado', sql(`SELECT description FROM request_items WHERE request_id=${reqId}`) === 'Cobertor', null);
ok('solicitação aparece na tela', (await page.textContent('#app')).includes('Cobertores para família'), null);

console.log('== J. necessidades vindas do banco ==');
await page.click('[data-section="Necessidades"]');
await page.waitForTimeout(1800);
const needs = await page.textContent('#app');
ok('necessidade criada aparece na lista', needs.includes('Cobertores para família'), null);
ok('filtro de urgentes funciona', needs.includes('Urgentes'), null);

console.log('== K. troca de senha ==');
await page.click('[data-section="Perfil"]');
await page.waitForSelector('#password-form');
const hashBefore = sql(`SELECT password_hash FROM users WHERE email='${email}'`);
await page.fill('#pw-current', password);
await page.fill('#pw-new', 'NovaSenha789');
await page.click('#password-form button[type="submit"]');
// Espera a resposta real da API antes de checar o banco.
await page.waitForFunction(
  () => { const t = document.querySelector('.toast'); return t && /Senha alterada/.test(t.textContent); },
  null, { timeout: 10000 },
).catch(() => {});
const hashAfter = sql(`SELECT password_hash FROM users WHERE email='${email}'`);
ok('hash da senha mudou no MySQL', !!hashBefore && hashBefore !== hashAfter, null);
const loginOld = await fetch(BASE + '/api/auth/login', {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password }),
});
ok('senha antiga deixa de valer (401)', loginOld.status === 401, loginOld.status);
const loginNew = await fetch(BASE + '/api/auth/login', {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password: 'NovaSenha789' }),
});
ok('nova senha vale na API (200)', loginNew.status === 200, loginNew.status);

console.log('== L. sair e entrar por CPF ==');
await page.click('[data-action="logout"]');
await page.waitForURL('**/acesso.html', { timeout: 10000 });
ok('logout leva à tela de acesso', page.url().includes('acesso.html'), page.url());
ok('token removido do navegador', (await page.evaluate(() => localStorage.getItem('ajudamais_token'))) === null, null);
await page.goto(BASE + '/login.html', { waitUntil: 'networkidle' });
await page.fill('#cpf', cpf.replace(/^(\d{3})(\d{3})(\d{3})(\d{2})$/, '$1.$2.$3-$4'));
await page.fill('#password', 'NovaSenha789');
await page.click('button[type="submit"]');
await page.waitForURL('**/index.html', { timeout: 15000 });
ok('login por CPF funciona pela tela', page.url().includes('index.html'), page.url());

console.log('== M. recuperar conta e redefinir senha ==');
await page.goto(BASE + '/recuperar-conta.html', { waitUntil: 'networkidle' });
await page.fill('#contact', email);
await page.click('button[type="submit"]');
// A tela redireciona para a redefinição após ~1,2s; lemos o aviso antes disso.
const foundMsg = await page.waitForFunction(
  () => { const t = document.getElementById('toast'); return t && !t.hidden ? t.textContent : null; },
  null, { timeout: 8000 },
).then((h) => h.jsonValue()).catch(() => '');
ok('recuperação encontra a conta', /Conta encontrada/.test(foundMsg), foundMsg);
await page.waitForURL('**/esqueci-senha.html*', { timeout: 8000 });
ok('redireciona para redefinir senha levando o e-mail', page.url().includes('esqueci-senha.html'), page.url());
ok('e-mail preenchido na tela de redefinição', (await page.inputValue('#email')) === email, await page.inputValue('#email'));

// Redefine a senha pela própria tela e confirma que a nova senha passa a valer.
await page.fill('#cpf', cpf.replace(/^(\d{3})(\d{3})(\d{3})(\d{2})$/, '$1.$2.$3-$4'));
await page.fill('#password', 'Redefinida321');
await page.fill('#confirm', 'Redefinida321');
await page.click('#form button[type="submit"]');
await page.waitForURL('**/login.html', { timeout: 12000 }).catch(() => {});
ok('redefinição volta para o login', page.url().includes('login.html'), page.url());
const redefineLogin = await fetch(BASE + '/api/auth/login', {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password: 'Redefinida321' }),
});
ok('senha redefinida pela tela funciona', redefineLogin.status === 200, redefineLogin.status);
const sessionPassword = 'Redefinida321';

console.log('== N. celular: navegação ==');
const mob = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
const mpage = await mob.newPage();
const mobErrors = [];
mpage.on('pageerror', (e) => mobErrors.push(e.message));
await mpage.goto(BASE + '/login.html', { waitUntil: 'networkidle' });
await mpage.fill('#cpf', cpf.replace(/^(\d{3})(\d{3})(\d{3})(\d{2})$/, '$1.$2.$3-$4'));
await mpage.fill('#password', sessionPassword);
await mpage.click('button[type="submit"]');
await mpage.waitForURL('**/index.html', { timeout: 15000 });
await mpage.waitForTimeout(1500);
const visibleNav = await mpage.$$eval('.nav-link', (els) => els.filter((e) => e.offsetParent !== null).length);
ok('no celular só a aba ativa aparece (menu fechado)', visibleNav === 1, visibleNav);
await mpage.click('.menu-toggle');
await mpage.waitForTimeout(400);
const openNav = await mpage.$$eval('.nav-link', (els) => els.filter((e) => e.offsetParent !== null).length);
ok('menu abre todas as abas no celular', openNav === 7, openNav);
await mpage.screenshot({ path: '/tmp/mobile-menu.png', fullPage: false });
await mpage.click('[data-section="Perfil"]');
await mpage.waitForTimeout(1500);
ok('navega para Perfil no celular', (await mpage.textContent('#app')).includes('Meu Perfil'), null);
const overflow = await mpage.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
ok('sem rolagem horizontal no celular', overflow <= 2, overflow);
await mpage.screenshot({ path: '/tmp/mobile-perfil.png', fullPage: true });
ok('sem erro de script no celular', mobErrors.length === 0, mobErrors.join('; '));
await mob.close();

console.log('== O. console do navegador ==');
const realErrors = consoleErrors.filter((e) => !/Failed to load resource.*(favicon|401)/.test(e));
ok('sem erros no console', realErrors.length === 0, realErrors.slice(0, 3).join(' | '));

await page.screenshot({ path: '/tmp/desktop-final.png', fullPage: false });
await browser.close();

console.log(`\n${failures === 0 ? 'TODOS OS TESTES DE INTERFACE PASSARAM' : failures + ' FALHA(S)'}`);
process.exit(failures === 0 ? 0 : 1);
