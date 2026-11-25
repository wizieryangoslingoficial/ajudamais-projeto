// Teste de navegador focado em: dados digitados permanecem nos campos ao
// navegar e ao usar botões internos; todos os botões do painel respondem;
// responsividade no celular. Confere o resultado no MySQL real.
import { execSync } from 'node:child_process';
import { chromium } from '/opt/freecode-tools/node_modules/playwright/index.mjs';
import { chromePath, chromeArgs } from './chrome.mjs';

const BASE = process.env.SITE ?? 'http://127.0.0.1:3111';
const SOCK = process.env.DB_SOCKET ?? '/tmp/run/bt.sock';
let failures = 0;

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
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
page.on('dialog', (d) => d.accept());

const email = `bot.${rnd()}@teste.local`;
const cpf = makeCpf();
const phone = `(14) 9${String(Math.floor(10000000 + Math.random() * 89999999))}`;
const password = 'SenhaForte123';

console.log('== 1. cadastro ==');
await page.goto(BASE + '/acesso.html', { waitUntil: 'networkidle' });
await page.check('#terms-checkbox');
await page.click('#btn-signup');
await page.waitForURL('**/cadastro.html');
await page.fill('#name', 'Pedro Botões');
await page.fill('#email', email);
await page.fill('#cpf', cpf);
await page.fill('#password', password);
await page.fill('#confirm', password);
await page.click('button[type="submit"]');
await page.waitForURL('**/index.html', { timeout: 15000 });
await page.waitForTimeout(1200);
ok('cadastro entrou no painel', page.url().includes('index.html'), page.url());

console.log('== 2. doação em dinheiro: campos sobrevivem aos cliques ==');
await page.click('[data-section="Doar Dinheiro"]');
await page.waitForSelector('#donation-form');
await page.fill('#donor-name', 'Pedro Botões Digitados');
await page.fill('#donor-phone', phone);
await page.fill('#custom-amount', 'R$ 75,00');
await page.evaluate(() => document.getElementById('custom-amount').blur());
await page.waitForTimeout(400);
ok('nome mantido após blur do valor', (await page.inputValue('#donor-name')) === 'Pedro Botões Digitados', await page.inputValue('#donor-name'));
await page.click('.preset-btn[data-val="100"]');
await page.waitForTimeout(400);
ok('nome mantido após escolher valor', (await page.inputValue('#donor-name')) === 'Pedro Botões Digitados', await page.inputValue('#donor-name'));
ok('telefone mantido após escolher valor', (await page.inputValue('#donor-phone')) === phone, await page.inputValue('#donor-phone'));
await page.click('.pay-btn[data-pay="pix"]');
await page.waitForTimeout(400);
ok('nome mantido após escolher pagamento', (await page.inputValue('#donor-name')) === 'Pedro Botões Digitados', null);
ok('valor escolhido é R$ 100 na tela', (await page.textContent('#donation-form')).includes('100,00'), null);
await page.click('#donation-form button[type="submit"]');
await page.waitForFunction(() => {
  const t = document.querySelector('.toast');
  return t && /Doação registrada/.test(t.textContent);
}, null, { timeout: 10000 }).catch(() => {});
const moneyRow = sql(`SELECT CONCAT(d.amount,'|',d.payment_method,'|',d.donor_name) FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}' AND d.donation_type='dinheiro' LIMIT 1`);
ok('doação gravada com valor e nome corretos', moneyRow === '100.00|pix|Pedro Botões Digitados', moneyRow);

console.log('== 3. doar itens: +/- e categoria preservam o formulário ==');
await page.click('[data-section="Doar Itens"]');
await page.waitForSelector('#item-donation-form');
await page.fill('#item-donor-address', 'Rua Botões, 10');
await page.fill('#item-donor-city', 'Botucatu');
await page.click('.item-cat-btn[data-cat="Roupas"]');
await page.waitForTimeout(400);
ok('endereço mantido após trocar categoria', (await page.inputValue('#item-donor-address')) === 'Rua Botões, 10', null);
await page.click('.item-plus-btn[data-item="Camisetas"]');
await page.click('.item-plus-btn[data-item="Camisetas"]');
await page.waitForTimeout(400);
ok('endereço mantido após + item', (await page.inputValue('#item-donor-address')) === 'Rua Botões, 10', null);
ok('contador de itens mostra 2', (await page.textContent('#item-donation-form')).includes('2'), null);
await page.click('.item-minus-btn[data-item="Camisetas"]');
await page.waitForTimeout(300);
ok('endereço mantido após − item', (await page.inputValue('#item-donor-address')) === 'Rua Botões, 10', null);
await page.fill('#item-donor-phone', phone);
await page.click('#item-donation-form button[type="submit"]');
await page.waitForFunction(() => {
  const t = document.querySelector('.toast');
  return t && /Doação de itens registrada/.test(t.textContent);
}, null, { timeout: 12000 }).catch(() => {});
const itemRow = sql(`SELECT CONCAT((SELECT COALESCE(SUM(quantity),0) FROM donation_items i WHERE i.donation_id=d.id),'|',a.city) FROM donations d JOIN users u ON u.id=d.donor_user_id LEFT JOIN addresses a ON a.id=d.dropoff_address_id WHERE u.email='${email}' AND d.donation_type='itens' LIMIT 1`);
ok('doação de itens gravada com endereço', itemRow === '1.00|Botucatu', itemRow);

console.log('== 4. dados preenchidos persistem ao trocar de aba ==');
await page.click('[data-section="Solicitações"]');
await page.waitForSelector('#request-form');
await page.fill('#req-title', 'Rascunho digitado');
await page.fill('#req-description', 'Texto que não pode desaparecer');
await page.click('[data-section="Perfil"]');
await page.waitForSelector('#profile-form');
await page.click('[data-section="Solicitações"]');
await page.waitForTimeout(600);
ok('título do rascunho continua após ir e voltar', (await page.inputValue('#req-title')) === 'Rascunho digitado', await page.inputValue('#req-title'));

console.log('== 5. botões do painel ==');
await page.click('[data-section="Início"]');
await page.waitForTimeout(800);
const chatBtn = await page.$('[data-action="chat"]');
if (chatBtn) {
  await chatBtn.click();
  await page.waitForTimeout(300);
  ok('botão de ajuda abre o painel', await page.evaluate(() => document.querySelector('.chat-panel').classList.contains('is-open')), null);
  await page.click('[data-action="close-chat"]');
  ok('botão fechar ajuda funciona', await page.evaluate(() => !document.querySelector('.chat-panel').classList.contains('is-open')), null);
}
const gotoDonate = await page.$('[data-action="goto-donate"]');
if (gotoDonate) {
  await gotoDonate.click();
  await page.waitForTimeout(400);
  ok('atalho "doar agora" abre o formulário', !!(await page.$('#donation-form')), null);
}
await page.click('[data-section="Início"]');
await page.waitForTimeout(500);
const newDonationReset = await page.$('#btn-new-donation');
ok('botão de nova doação só aparece no sucesso', !newDonationReset, null);

await page.click('[data-section="Minhas Doações"]').catch(async () => {
  await page.click('[data-section="Doações"]');
});
await page.waitForTimeout(900);
const cancelBtn = await page.$('.btn-cancelar-doacao');
if (cancelBtn) {
  const before = Number(sql(`SELECT COUNT(*) FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}' AND d.status='pendente'`));
  await cancelBtn.click();
  await page.waitForTimeout(1200);
  const after = Number(sql(`SELECT COUNT(*) FROM donations d JOIN users u ON u.id=d.donor_user_id WHERE u.email='${email}' AND d.status='pendente'`));
  ok('botão cancelar muda o status no MySQL', after === before - 1, `${before} -> ${after}`);
}

console.log('== 6. Necessidades: filtros e ação "Quero Ajudar" ==');
// Cria uma necessidade própria pela tela de Solicitações, que aparece na lista.
await page.click('[data-section="Solicitações"]');
await page.waitForSelector('#request-form');
await page.fill('#req-title', 'Cestas para vizinhos');
await page.fill('.req-item-desc', 'Cesta básica');
await page.fill('.req-item-qty', '2');
await page.click('#request-form button[type="submit"]');
await page.waitForTimeout(1500);
await page.click('[data-section="Necessidades"]');
await page.waitForTimeout(900);
const need = sql(`SELECT id FROM assistance_requests WHERE requester_user_id=(SELECT id FROM users WHERE email='${email}') LIMIT 1`);
if (need) {
  await page.click('.btn-ver-detalhes');
  await page.waitForTimeout(300);
  ok('"Ver detalhes" mostra aviso', (await page.textContent('.toast')).length > 5, null);
  await page.click('.btn-quero-ajudar');
  await page.waitForTimeout(500);
  ok('"Quero Ajudar" leva ao formulário de doação', !!(await page.$('#donation-form')) || !!(await page.$('#item-donation-form')), null);
} else {
  ok('necessidade existente para testar ações', false, need);
}

console.log('== 7. perfil: remover endereço ==');
await page.click('[data-section="Perfil"]');
await page.waitForSelector('#address-form');
await page.fill('#ad-street', 'Rua Remover, 5');
await page.fill('#ad-city', 'Botucatu');
await page.click('#address-form button[type="submit"]');
await page.waitForTimeout(1200);
const addrCount = Number(sql(`SELECT COUNT(*) FROM addresses a JOIN users u ON u.id=a.user_id WHERE u.email='${email}' AND a.street='Rua Remover, 5'`));
ok('endereço criado antes de remover', addrCount === 1, addrCount);
const addrId = sql(`SELECT a.id FROM addresses a JOIN users u ON u.id=a.user_id WHERE u.email='${email}' AND a.street='Rua Remover, 5' LIMIT 1`);
const delBtn = await page.$(`.btn-del-address[data-id="${addrId}"]`);
if (delBtn) {
  await delBtn.click();
  await page.waitForTimeout(1200);
  ok('endereço removido do MySQL', sql(`SELECT COUNT(*) FROM addresses a JOIN users u ON u.id=a.user_id WHERE u.email='${email}' AND a.street='Rua Remover, 5'`) === '0', null);
}

console.log('== 8. celular: telas principais ==');
const mob = await browser.newContext({
  viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true,
  storageState: await context.storageState(),
});
const mpage = await mob.newPage();
const mobErrors = [];
mpage.on('pageerror', (e) => mobErrors.push(e.message));
mpage.on('dialog', (d) => d.accept());
await mpage.goto(BASE + '/index.html', { waitUntil: 'networkidle' });
await mpage.waitForTimeout(1200);
for (const [secao, texto] of [['Doar Dinheiro', 'Doar Dinheiro'], ['Doar Itens', 'Doar Itens'], ['Necessidades', 'Necessidades'], ['Solicitações', 'Pedir Ajuda'], ['Perfil', 'Meu Perfil']]) {
  await mpage.click('.menu-toggle');
  await mpage.waitForTimeout(250);
  await mpage.click(`[data-section="${secao}"]`);
  await mpage.waitForTimeout(700);
  const conteudo = await mpage.textContent('#app');
  ok(`celular: ${secao} abre`, conteudo.includes(texto), null);
  const overflow = await mpage.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  ok(`celular: ${secao} sem rolagem horizontal`, overflow <= 2, overflow);
}
await mpage.screenshot({ path: '/tmp/mobile-final.png', fullPage: true });
ok('celular: sem erro de script', mobErrors.length === 0, mobErrors.join('; '));
await mob.close();

console.log('== 9. console ==');
const real = errors.filter((e) => !/Failed to load resource.*(favicon|401|422)/.test(e));
ok('desktop: sem erro de console', real.length === 0, real.slice(0, 3).join(' | '));

await browser.close();
console.log(`\n${failures === 0 ? 'TODOS OS TESTES DE BOTÕES PASSARAM' : failures + ' FALHA(S)'}`);
process.exit(failures === 0 ? 0 : 1);
