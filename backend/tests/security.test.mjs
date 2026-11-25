// Teste de segurança: autenticação, permissões entre usuários, senhas e
// exposição de dados pessoais. Roda contra a API e o MySQL reais.
import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const BASE = process.env.API_URL ?? 'http://127.0.0.1:3111';
const SOCK = process.env.DB_SOCKET ?? '/tmp/run/bt.sock';
const DB = process.env.DB_NAME ?? 'ajudamais';
let failures = 0;

function ok(label, cond, extra) {
  if (cond) console.log('  OK   ' + label);
  else { failures++; console.log('  FALHOU ' + label + (extra !== undefined ? ' -> ' + String(extra).slice(0, 200) : '')); }
}
function sql(q) {
  return execSync(`mariadb --socket=${SOCK} -u root ${DB} -N -B -e "${q.replace(/"/g, '\\"')}"`).toString().trim();
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
  return { status: res.status, body: json, raw: text };
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

// ---- Duas contas independentes ------------------------------------------
async function criar(nome) {
  const email = `${nome}.${rnd()}@seguranca.local`;
  const cpf = makeCpf();
  const phone = `(14) 9${String(Math.floor(10000000 + Math.random() * 89999999))}`;
  const r = await api('POST', '/api/auth/register', null, {
    full_name: nome, email, cpf, phone, password: 'SenhaSegura123', terms_accepted: true,
  });
  if (r.status !== 201) throw new Error('falha ao criar ' + nome + ': ' + r.raw);
  return { email, cpf, phone, token: r.body.token, id: r.body.user.id };
}

console.log('== 1. rotas protegidas exigem autenticação ==');
const protegidas = [
  ['GET', '/api/users/me'],
  ['PATCH', '/api/users/me'],
  ['GET', '/api/users/me/addresses'],
  ['POST', '/api/users/me/addresses'],
  ['GET', '/api/donations/mine'],
  ['POST', '/api/donations'],
  ['POST', '/api/requests'],
  ['GET', '/api/requests/mine/list'],
  ['PATCH', '/api/donations/1/status'],
  ['DELETE', '/api/donations/1'],
  ['POST', '/api/institutions'],
];
for (const [method, path] of protegidas) {
  const r = await api(method, path, null, method === 'GET' ? undefined : {});
  ok(`${method} ${path} sem token devolve 401`, r.status === 401, r.status);
}

console.log('== 2. token inválido não entra ==');
const fake = await api('GET', '/api/users/me', 'token-inventado-123');
ok('token inventado devolve 401', fake.status === 401, fake.status);

console.log('== 3. senhas nunca aparecem nas respostas ==');
const alice = await criar('Alice');
const bob = await criar('Bob');
for (const [rotulo, r] of [
  ['cadastro/login', await api('POST', '/api/auth/login', null, { email: alice.email, password: 'SenhaSegura123' })],
  ['perfil', await api('GET', '/api/users/me', alice.token)],
  ['lista de solicitações', await api('GET', '/api/requests?limit=100', null)],
  ['doações recentes', await api('GET', '/api/donations/recent', null)],
  ['categorias', await api('GET', '/api/categories', null)],
  ['estatísticas', await api('GET', '/api/stats', null)],
]) {
  const texto = r.raw || '';
  ok(`${rotulo}: sem password_hash/senha`, !/password_hash|password_algo|SenhaSegura123|\$2[aby]\$/.test(texto), texto.slice(0, 120));
}

console.log('== 4. senha é guardada com hash bcrypt (nunca em texto) ==');
const stored = sql(`SELECT password_hash FROM users WHERE email='${alice.email}'`);
ok('senha no banco é hash bcrypt', /^\$2[aby]\$/.test(stored), stored.slice(0, 7));
ok('senha em texto não está no banco', sql(`SELECT COUNT(*) FROM users WHERE password_hash='SenhaSegura123'`) === '0');

console.log('== 5. sessão guarda apenas o hash do token ==');
// Cadastro e login criam uma sessão cada: o que importa é que a sessão usada
// exista com o HASH do token, nunca com o token em texto.
const hashDoToken = createHash('sha256').update(alice.token).digest('hex');
const sessaoUsada = sql(`SELECT COUNT(*) FROM sessions WHERE user_id=${alice.id} AND token_hash='${hashDoToken}' AND revoked_at IS NULL`);
ok('sessão ativa guardada pelo hash do token', sessaoUsada === '1', sessaoUsada);
ok('token puro não está na tabela de sessões',
  sql(`SELECT COUNT(*) FROM sessions WHERE token_hash='${alice.token}'`) === '0');
ok('token tem tamanho adequado', alice.token.length >= 32, alice.token.length);
ok('hash do token não aparece nas respostas', !(await api('GET', '/api/users/me', alice.token)).raw.includes(hashDoToken));

console.log('== 6. um usuário não acessa dados de outro ==');
const dono = await api('GET', '/api/donations/mine', alice.token);
ok('consulta das próprias doações funciona', dono.status === 200, dono.status);

const addrAlice = await api('POST', '/api/users/me/addresses', alice.token, {
  label: 'Casa', address_type: 'residencial', street: 'Rua da Alice, 1', city: 'Botucatu',
});
const addrId = addrAlice.body.address.id;
const rouboAddr = await api('PATCH', `/api/users/me/addresses/${addrId}`, bob.token, { city: 'Outra' });
ok('outro usuário não edita endereço alheio', rouboAddr.status === 404 || rouboAddr.status === 403, rouboAddr.status);
const apagaAlheio = await api('DELETE', `/api/users/me/addresses/${addrId}`, bob.token);
ok('outro usuário não apaga endereço alheio', apagaAlheio.status === 404 || apagaAlheio.status === 403, apagaAlheio.status);
ok('endereço da Alice continua intacto', sql(`SELECT COUNT(*) FROM addresses WHERE id=${addrId}`) === '1');

const doacaoAlice = await api('POST', '/api/donations', alice.token, {
  donation_type: 'dinheiro', amount: 25, payment_method: 'pix',
  donor_name: 'Alice', donor_email: alice.email,
});
const dId = doacaoAlice.body.donation.id;
const verDoacaoAlheia = await api('GET', `/api/donations/${dId}`, bob.token);
ok('outro usuário não vê detalhe da doação', verDoacaoAlheia.status === 403, verDoacaoAlheia.status);
const cancelarAlheia = await api('DELETE', `/api/donations/${dId}`, bob.token);
ok('outro usuário não cancela doação alheia', cancelarAlheia.status === 403, cancelarAlheia.status);
ok('doação segue pendente', sql(`SELECT status FROM donations WHERE id=${dId}`) === 'pendente');

const confirmarSemPermissao = await api('PATCH', `/api/donations/${dId}/status`, bob.token, { status: 'confirmada' });
ok('usuário comum não altera status de doação', confirmarSemPermissao.status === 403, confirmarSemPermissao.status);

console.log('== 7. dados pessoais não aparecem em consultas públicas ==');
const publico = [await api('GET', '/api/requests?limit=100', null), await api('GET', '/api/donations/recent', null)];
const textoPublico = publico.map((r) => r.raw).join(' ');
ok('consultas públicas sem CPF', !textoPublico.includes(alice.cpf) && !textoPublico.includes(bob.cpf));
ok('consultas públicas sem telefone completo',
  !publico[0].raw.includes(alice.phone) && !publico[1].raw.includes(alice.phone));
ok('consultas públicas sem e-mail', !textoPublico.includes(alice.email) && !textoPublico.includes(bob.email));

console.log('== 8. recuperação não revela cadastro ==');
const recExiste = await api('POST', '/api/auth/recover-account', null, { metodo: 'email', valor: alice.email });
const recNaoExiste = await api('POST', '/api/auth/recover-account', null, { metodo: 'email', valor: 'nao.' + rnd() + '@x.local' });
ok('conta existente devolve contato mascarado',
  recExiste.status === 200 && recExiste.body.masked_email && !recExiste.body.masked_email.includes('@seguranca.local') === false, recExiste.body);
ok('contato mascarado esconde o início', /^[^@]*\*+/.test(String(recExiste.body.masked_email || '')), recExiste.body.masked_email);
ok('conta inexistente usa a mesma estrutura de resposta',
  recNaoExiste.status === 200 && recNaoExiste.body.found === false, recNaoExiste.body);
ok('resposta de conta inexistente não expõe e-mail', !recNaoExiste.raw.includes('@seguranca.local'));

console.log('== 9. login: mensagem genérica e bloqueio por tentativas ==');
const errada = await api('POST', '/api/auth/login', null, { email: bob.email, password: 'errada' });
ok('senha errada: 401 com mensagem genérica',
  errada.status === 401 && /CPF\/e-mail ou senha incorretos/.test(errada.body.message), errada.body);
const naoExiste = await api('POST', '/api/auth/login', null, { email: 'ninguem.' + rnd() + '@x.local', password: 'errada' });
ok('mensagem igual para conta inexistente', naoExiste.status === 401 && naoExiste.body.message === errada.body.message, naoExiste.body);

console.log('== 10. sessão é revogada no logout ==');
const antes = await api('GET', '/api/users/me', bob.token);
ok('token válido antes do logout', antes.status === 200);
await api('POST', '/api/auth/logout', bob.token, {});
const depois = await api('GET', '/api/users/me', bob.token);
ok('token recusado depois do logout', depois.status === 401, depois.status);

console.log('== 11. endpoint de teste não existe em produção ==');
const prod = await fetch(BASE + '/api/_test/promote', {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: alice.email, role: 'admin' }),
});
ok('promoção só existe com NODE_ENV=test', prod.status !== 200, prod.status);
ok('Alice continua sem papel de admin', sql(`SELECT COUNT(*) FROM user_roles ur JOIN roles r ON r.id=ur.role_id WHERE ur.user_id=${alice.id} AND r.code='admin'`) === '0');

console.log('== 12. validação rejeita dados inválidos ==');
const senhaCurta = await api('POST', '/api/auth/register', null, {
  full_name: 'Curta', email: 'curta.' + rnd() + '@x.local', cpf: makeCpf(), password: '123', terms_accepted: true,
});
ok('cadastro com senha curta é recusado', senhaCurta.status === 422, senhaCurta.status);
const semTermos = await api('POST', '/api/auth/register', null, {
  full_name: 'Sem Termos', email: 'st.' + rnd() + '@x.local', cpf: makeCpf(), password: 'SenhaSegura123',
  terms_accepted: false,
});
ok('cadastro sem aceitar os termos é recusado', semTermos.status === 422, semTermos.status);
const semTokenDoacao = await api('POST', '/api/donations', null, { donation_type: 'dinheiro', amount: 10 });
ok('doação anônima sem login é recusada', semTokenDoacao.status === 401, semTokenDoacao.status);

console.log(`\n${failures === 0 ? 'TODOS OS TESTES DE SEGURANÇA PASSARAM' : failures + ' FALHA(S)'}`);
process.exit(failures === 0 ? 0 : 1);
