// Verifica o fluxo real: cadastro, login por CPF, perfil, endereço,
// doações, solicitações, categorias e estatísticas, lendo de volta do MySQL.
import { execSync } from 'node:child_process';

const BASE = process.env.API_URL ?? 'http://127.0.0.1:3111';
const SOCK = process.env.DB_SOCKET ?? '/tmp/run/bt.sock';
// Banco usado nas leituras SQL de conferência (deve ser o mesmo da API).
const DB = process.env.DB_NAME ?? 'ajudamais';
let failures = 0;

function ok(label, cond, extra) {
  if (cond) console.log('  OK   ' + label);
  else { failures++; console.log('  FALHOU ' + label + (extra ? ' -> ' + JSON.stringify(extra).slice(0, 300) : '')); }
}

async function api(method, path, token, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  return { status: res.status, body: json };
}

function sql(q) {
  return execSync(`mariadb --socket=${SOCK} -u root ${DB} -N -B -e "${q.replace(/"/g, '\\"')}"`).toString().trim();
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

console.log('== 1. cadastro ==');
const email = `fluxo.${rnd()}@teste.local`;
const cpf = makeCpf();
const phone = `(14) 9${String(Math.floor(10000000 + Math.random() * 89999999))}`;
const reg = await api('POST', '/api/auth/register', null, {
  full_name: 'Maria Fluxo Teste', email, cpf, phone, password: 'SenhaForte123', terms_accepted: true,
});
ok('cadastro devolve token', reg.status === 201 && !!reg.body.token, reg.body);
let token = reg.body.token;
ok('usuário gravado no MySQL', sql(`SELECT COUNT(*) FROM users WHERE email='${email}'`) === '1');

console.log('== 2. login por CPF ==');
const byCpf = await api('POST', '/api/auth/login', null, { cpf, password: 'SenhaForte123' });
ok('login por CPF funciona', byCpf.status === 200 && !!byCpf.body.token, byCpf.body);
const byEmail = await api('POST', '/api/auth/login', null, { email, password: 'SenhaForte123' });
ok('login por e-mail continua', byEmail.status === 200);
const wrong = await api('POST', '/api/auth/login', null, { cpf, password: 'errada' });
ok('senha errada devolve 401', wrong.status === 401);
token = byCpf.body.token;

console.log('== 3. recuperar conta ==');
const rec = await api('POST', '/api/auth/recover-account', null, { metodo: 'email', valor: email });
ok('encontra conta por e-mail', rec.status === 200 && rec.body.found === true, rec.body);
ok('não expõe e-mail completo', rec.body && rec.body.masked_email && !rec.body.masked_email.includes('fluxo.'), rec.body);
const recPhone = await api('POST', '/api/auth/recover-account', null, { metodo: 'phone', valor: phone });
ok('encontra conta por celular', recPhone.status === 200 && recPhone.body.found === true, recPhone.body);
const recNone = await api('POST', '/api/auth/recover-account', null, { metodo: 'email', valor: 'nao.existe.' + rnd() + '@x.local' });
ok('conta inexistente não revela nada', recNone.body.found === false);

console.log('== 4. perfil ==');
const me = await api('GET', '/api/users/me', token);
ok('GET /users/me devolve perfil', me.status === 200 && me.body.user.full_name === 'Maria Fluxo Teste', me.body);
const up = await api('PATCH', '/api/users/me', token, { display_name: 'Maria F.', birth_date: '1992-03-10', phone });
ok('PATCH perfil', up.status === 200, up.body);
ok('perfil atualizado no MySQL', sql(`SELECT display_name FROM users WHERE email='${email}'`) === 'Maria F.');

console.log('== 5. endereço de coleta ==');
const addr = await api('POST', '/api/users/me/addresses', token, {
  label: 'Coleta', address_type: 'coleta', street: 'Rua Teste, 123', city: 'Botucatu', state_code: 'SP',
});
ok('cria endereço', addr.status === 201 && addr.body.address.id > 0, addr.body);
const addressId = addr.body.address.id;
ok('endereço no MySQL', sql(`SELECT COUNT(*) FROM addresses WHERE id=${addressId}`) === '1');
const addrList = await api('GET', '/api/users/me', token);
ok('endereço aparece no perfil', addrList.body.addresses.some((a) => a.id === addressId));

console.log('== 6. doação em dinheiro ==');
const money = await api('POST', '/api/donations', token, {
  donation_type: 'dinheiro', amount: 137.5, payment_method: 'pix',
  donor_name: 'Maria Fluxo Teste', donor_email: email, donor_phone: phone,
});
ok('doação em dinheiro criada', money.status === 201, money.body);
const moneyId = money.body.donation.id;
ok('valor gravado no MySQL', sql(`SELECT amount FROM donations WHERE id=${moneyId}`) === '137.50');

console.log('== 7. doação de itens com endereço ==');
const items = await api('POST', '/api/donations', token, {
  donation_type: 'itens', donor_name: 'Maria Fluxo Teste', donor_email: email,
  dropoff_address_id: addressId,
  items: [
    { description: 'Arroz', quantity: 2, unit_code: 'un', item_condition: 'novo', category_id: 1 },
    { description: 'Feijão', quantity: 3, unit_code: 'un', item_condition: 'novo', category_id: 1 },
  ],
});
ok('doação de itens criada', items.status === 201, items.body);
const itemsId = items.body.donation.id;
ok('2 itens gravados no MySQL', sql(`SELECT COUNT(*) FROM donation_items WHERE donation_id=${itemsId}`) === '2');
ok('endereço de coleta vinculado', sql(`SELECT dropoff_address_id FROM donations WHERE id=${itemsId}`) === String(addressId));

console.log('== 8. minhas doações ==');
const mine = await api('GET', '/api/donations/mine', token);
ok('lista minhas doações', mine.status === 200 && mine.body.donations.length >= 2, mine.body.donations && mine.body.donations.length);
const cancel = await api('DELETE', `/api/donations/${moneyId}`, token);
ok('cancela doação pendente', cancel.status === 200, cancel.body);
ok('status cancelada no MySQL', sql(`SELECT status FROM donations WHERE id=${moneyId}`) === 'cancelada');

console.log('== 9. solicitações ==');
const req = await api('POST', '/api/requests', token, {
  title: 'Cesta básica para família', description: 'Família com 3 crianças',
  priority: 'urgente', city: 'Botucatu', state_code: 'SP', beneficiary_count: 5, category_id: 1,
  items: [{ description: 'Cesta básica', quantity_requested: 2, unit_code: 'un', category_id: 1 }],
});
ok('cria solicitação', req.status === 201, req.body);
const reqId = req.body.request.id;
ok('solicitação no MySQL', sql(`SELECT COUNT(*) FROM assistance_requests WHERE id=${reqId}`) === '1');
ok('item da solicitação no MySQL', sql(`SELECT COUNT(*) FROM request_items WHERE request_id=${reqId}`) === '1');
const pub = await api('GET', '/api/requests?limit=100', null);
ok('aparece na lista pública com itens', pub.body.requests.some((r) => r.id === reqId && r.items.length === 1));
const mineReq = await api('GET', '/api/requests/mine/list', token);
ok('aparece nas minhas solicitações', mineReq.body.requests.some((r) => r.id === reqId));
const detail = await api('GET', `/api/requests/${reqId}`, null);
ok('detalhe da solicitação', detail.status === 200, detail.body);

console.log('== 10. categorias e estatísticas ==');
const cats = await api('GET', '/api/categories', null);
ok('categorias vêm do banco', cats.status === 200 && cats.body.categories.length >= 8, cats.body.categories && cats.body.categories.length);
ok('categoria alimentos presente', cats.body.categories.some((c) => c.slug === 'alimentos'));
const st0 = await api('GET', '/api/stats', null);
ok('estatísticas respondem', st0.status === 200, st0.body);
ok('doação pendente não entra nas estatísticas', Number(st0.body.items_total) === 0, st0.body.items_total);

// Administração confirma a doação de itens; ela passa a contar nas estatísticas
// e a aparecer na lista pública de doações recentes.
const promoted = await api('POST', '/api/_test/promote', token, { email, role: 'admin' });
ok('promoção de teste funciona', promoted.status === 200, promoted.body);
const adminTok = (await api('POST', '/api/auth/login', null, { cpf, password: 'SenhaForte123' })).body.token;
const conf = await api('PATCH', `/api/donations/${itemsId}/status`, adminTok, { status: 'confirmada' });
ok('admin confirma doação', conf.status === 200, conf.body);
const st1 = await api('GET', '/api/stats', null);
ok('itens somam após confirmação (5 un.)', Number(st1.body.items_total) === 5, st1.body.items_total);
ok('doações de itens contadas', Number(st1.body.items_donations) === 1, st1.body.items_donations);
const recent = await api('GET', '/api/donations/recent', null);
const shown = recent.body.donations.find((d) => d.id === itemsId);
ok('doação confirmada aparece em recentes', !!shown, recent.body.donations);
ok('recentes mostram só o primeiro nome', shown && shown.name === 'Maria', shown && shown.name);
ok('recentes sem e-mail/telefone', !JSON.stringify(recent.body).includes(email) && !JSON.stringify(recent.body).includes('99876'), null);

console.log('== 11. troca de senha ==');
const pw = await api('POST', '/api/users/me/password', token, { current_password: 'SenhaForte123', new_password: 'OutraSenha456' });
ok('troca de senha', pw.status === 200, pw.body);
const fresh = await api('POST', '/api/auth/login', null, { cpf, password: 'OutraSenha456' });
ok('login com nova senha', fresh.status === 200);

console.log('== 12. logout ==');
const out = await api('POST', '/api/auth/logout', token, {});
ok('logout', out.status === 200);
const after = await api('GET', '/api/users/me', token);
ok('token revogado após logout', after.status === 401);

console.log(`\n${failures === 0 ? 'TODOS OS TESTES DE FLUXO PASSARAM' : failures + ' FALHA(S)'}`);
process.exit(failures === 0 ? 0 : 1);
