// Teste de integração real: sobe a API contra um MySQL/MariaDB já inicializado
// com database/01-schema.sql e exercita as rotas principais.
// Uso: node tests/integration.test.js
import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';

const BASE = process.env.API_URL ?? 'http://127.0.0.1:3111';

let adminToken = null;

async function api(method, path, { body, token } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  return { status: res.status, body: json };
}

const rnd = () => Math.random().toString(36).slice(2, 8);

// Gera CPF válido aleatório para os testes.
function makeCpf() {
  const n = Array.from({ length: 9 }, () => Math.floor(Math.random() * 10));
  for (const len of [9, 10]) {
    let sum = 0;
    for (let i = 0; i < len; i++) sum += n[i] * (len + 1 - i);
    const d = ((sum * 10) % 11) % 10;
    n.push(d);
  }
  return n.join('');
}

function makeCnpj() {
  const n = Array.from({ length: 8 }, () => Math.floor(Math.random() * 10));
  n.push(0, 0, 0, 1);
  const calc = (len) => {
    const w = len === 12
      ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
      : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    let sum = 0;
    for (let i = 0; i < len; i++) sum += n[i] * w[i];
    const r = sum % 11;
    return r < 2 ? 0 : 11 - r;
  };
  n.push(calc(12));
  n.push(calc(13));
  return n.join('');
}

describe('AjudaMais API', () => {
  // Administrador descartável, usado para aprovar doações sem instituição.
  // A atribuição do papel é feita pelo endpoint interno de teste abaixo, que só
  // existe quando NODE_ENV=test.
  before(async () => {
    const email = `admin.${rnd()}@teste.local`;
    const password = 'SenhaForte123';
    const reg = await api('POST', '/api/auth/register', {
      body: { full_name: 'Admin Teste', email, cpf: makeCpf(), password, terms_accepted: true },
    });
    assert.equal(reg.status, 201, JSON.stringify(reg.body));
    const promoted = await api('POST', '/api/_test/promote', {
      body: { email, role: 'admin' }, token: reg.body.token,
    });
    assert.equal(promoted.status, 200, JSON.stringify(promoted.body));
    adminToken = promoted.body.token;
  });

  it('GET /api/health responde e conecta no banco', async () => {
    const r = await api('GET', '/api/health');
    assert.equal(r.status, 200);
    assert.equal(r.body.ok, true);
  });

  it('rota inexistente devolve 404 em JSON', async () => {
    const r = await api('GET', '/api/nao-existe');
    assert.equal(r.status, 404);
    assert.equal(r.body.code, 'rota_nao_encontrada');
  });

  describe('cadastro e login', () => {
    const email = `doador.${rnd()}@teste.local`;
    const cpf = makeCpf();
    const password = 'SenhaForte123';
    let token;

    it('rejeita CPF inválido', async () => {
      const r = await api('POST', '/api/auth/register', {
        body: { full_name: 'Teste CPF', email: `x.${rnd()}@t.local`, cpf: '11111111111', password, terms_accepted: true },
      });
      assert.equal(r.status, 422);
    });

    it('rejeita cadastro sem aceitar termos', async () => {
      const r = await api('POST', '/api/auth/register', {
        body: { full_name: 'Sem Termos', email: `y.${rnd()}@t.local`, cpf: makeCpf(), password },
      });
      assert.equal(r.status, 422);
    });

    it('cadastra com dados válidos', async () => {
      const r = await api('POST', '/api/auth/register', {
        body: {
          full_name: 'Doadora Teste', email, cpf, phone: '(14) 99876-5432',
          password, terms_accepted: true,
        },
      });
      assert.equal(r.status, 201, JSON.stringify(r.body));
      assert.equal(r.body.user.email, email);
      assert.equal(r.body.user.phone_e164, '+5514998765432');
      assert.equal(r.body.user.cpf_masked.slice(0, 3), '***');
      assert.deepEqual(r.body.roles, ['doador']);
      assert.ok(r.body.token);
      token = r.body.token;
    });

    it('impede e-mail duplicado', async () => {
      const r = await api('POST', '/api/auth/register', {
        body: { full_name: 'Duplicada', email, cpf: makeCpf(), password, terms_accepted: true },
      });
      assert.equal(r.status, 409);
    });

    it('impede CPF duplicado', async () => {
      const r = await api('POST', '/api/auth/register', {
        body: { full_name: 'Duplicada 2', email: `z.${rnd()}@t.local`, cpf, password, terms_accepted: true },
      });
      assert.equal(r.status, 409);
    });

    it('login com senha errada devolve 401 e mensagem genérica', async () => {
      const r = await api('POST', '/api/auth/login', { body: { email, password: 'errada' } });
      assert.equal(r.status, 401);
      assert.equal(r.body.message, 'CPF/e-mail ou senha incorretos');
    });

    it('login por CPF devolve token', async () => {
      const cpf = makeCpf();
      const reg = await api('POST', '/api/auth/register', {
        body: {
          full_name: 'Login CPF', email: `cpf.${rnd()}@t.local`, cpf, phone: `(14) 9${Math.floor(10000000 + Math.random() * 89999999)}`,
          password, terms_accepted: true,
        },
      });
      assert.equal(reg.status, 201, JSON.stringify(reg.body));
      const r = await api('POST', '/api/auth/login', { body: { cpf, password } });
      assert.equal(r.status, 200, JSON.stringify(r.body));
      assert.ok(r.body.token);
    });

    it('login sem CPF nem e-mail é rejeitado', async () => {
      const r = await api('POST', '/api/auth/login', { body: { password } });
      assert.equal(r.status, 422);
    });

    it('login correto devolve token', async () => {
      const r = await api('POST', '/api/auth/login', { body: { email, password } });
      assert.equal(r.status, 200, JSON.stringify(r.body));
      assert.ok(r.body.token);
      token = r.body.token;
    });

    it('GET /api/users/me devolve o perfil', async () => {
      const r = await api('GET', '/api/users/me', { token });
      assert.equal(r.status, 200);
      assert.equal(r.body.user.full_name, 'Doadora Teste');
      assert.equal(r.body.addresses.length, 0);
    });

    it('GET /api/users/me sem token devolve 401', async () => {
      const r = await api('GET', '/api/users/me');
      assert.equal(r.status, 401);
    });

    it('PATCH /api/users/me atualiza o perfil', async () => {
      const r = await api('PATCH', '/api/users/me', {
        token, body: { full_name: 'Doadora Teste Atualizada', display_name: 'Dora' },
      });
      assert.equal(r.status, 200, JSON.stringify(r.body));
      assert.equal(r.body.user.display_name, 'Dora');
    });

    describe('CRUD de endereço', () => {
      let addressId;
      it('cria endereço', async () => {
        const r = await api('POST', '/api/users/me/addresses', {
          token,
          body: { street: 'Rua das Acácias', number: '100', city: 'Botucatu', state_code: 'sp', is_primary: true },
        });
        assert.equal(r.status, 201, JSON.stringify(r.body));
        assert.equal(r.body.address.state_code, 'SP');
        addressId = r.body.address.id;
      });
      it('lista endereços', async () => {
        const r = await api('GET', '/api/users/me/addresses', { token });
        assert.equal(r.status, 200);
        assert.equal(r.body.addresses.length, 1);
      });
      it('atualiza endereço', async () => {
        const r = await api('PATCH', `/api/users/me/addresses/${addressId}`, {
          token, body: { complement: 'Apto 12' },
        });
        assert.equal(r.status, 200);
        assert.equal(r.body.address.complement, 'Apto 12');
      });
      it('rejeita UF inválida no banco (FK de estados)', async () => {
        const r = await api('POST', '/api/users/me/addresses', {
          token, body: { street: 'Rua X', city: 'Cidade', state_code: 'ZZ' },
        });
        assert.equal(r.status, 422, JSON.stringify(r.body));
        assert.equal(r.body.code, 'vinculo_invalido');
      });
      it('exclui endereço', async () => {
        const r = await api('DELETE', `/api/users/me/addresses/${addressId}`, { token });
        assert.equal(r.status, 204);
      });
      it('não deixa excluir endereço de outro usuário', async () => {
        const r = await api('DELETE', '/api/users/me/addresses/1', { token });
        assert.equal(r.status, 404);
      });
    });

    describe('instituição, campanha, doação e solicitação', () => {
      let institutionId;
      let requestId;
      let donationId;

      it('cria instituição e vira admin', async () => {
        const r = await api('POST', '/api/institutions', {
          token,
          body: {
            legal_name: `Instituto Teste ${rnd()}`, cnpj: makeCnpj(), email: `ong.${rnd()}@teste.local`,
            institution_type: 'ong', accepts_money: true,
          },
        });
        assert.equal(r.status, 201, JSON.stringify(r.body));
        assert.equal(r.body.institution.status, 'pendente');
        institutionId = r.body.institution.id;
      });

      it('usuário não-staff não edita a instituição de outro', async () => {
        const other = await api('POST', '/api/auth/register', {
          body: {
            full_name: 'Outro Usuário', email: `outro.${rnd()}@t.local`, cpf: makeCpf(),
            password: 'SenhaForte123', terms_accepted: true,
          },
        });
        assert.equal(other.status, 201);
        const r = await api('PATCH', `/api/institutions/${institutionId}`, {
          token: other.body.token, body: { trade_name: 'Invasão' },
        });
        assert.equal(r.status, 403);
        assert.equal(r.body.code, 'sem_permissao');
      });

      it('edita a própria instituição', async () => {
        const r = await api('PATCH', `/api/institutions/${institutionId}`, {
          token, body: { trade_name: 'Instituto Atualizado' },
        });
        assert.equal(r.status, 200);
        assert.equal(r.body.institution.trade_name, 'Instituto Atualizado');
      });

      it('cria campanha', async () => {
        const r = await api('POST', `/api/institutions/${institutionId}/campaigns`, {
          token, body: { title: 'Campanha de Inverno', slug: `inverno-${rnd()}`, goal_type: 'itens', goal_quantity: 100 },
        });
        assert.equal(r.status, 201, JSON.stringify(r.body));
      });

      it('rejeita slug duplicado', async () => {
        const slug = `rep-${rnd()}`;
        await api('POST', `/api/institutions/${institutionId}/campaigns`, {
          token, body: { title: 'Campanha A', slug },
        });
        const r = await api('POST', `/api/institutions/${institutionId}/campaigns`, {
          token, body: { title: 'Campanha B', slug },
        });
        assert.equal(r.status, 409);
      });

      it('cria solicitação com itens', async () => {
        const r = await api('POST', '/api/requests', {
          token,
          body: {
            institution_id: institutionId,
            title: 'Cobertores para o abrigo',
            description: 'Precisamos de cobertores para o inverno',
            priority: 'alta', city: 'Botucatu', state_code: 'SP',
            items: [{ description: 'Cobertor casal', quantity_requested: 10, unit_code: 'un' }],
          },
        });
        assert.equal(r.status, 201, JSON.stringify(r.body));
        requestId = r.body.request.id;
      });

      it('solicitação aparece na consulta pública', async () => {
        const r = await api('GET', '/api/requests?uf=SP&limit=100');
        assert.equal(r.status, 200);
        assert.ok(r.body.requests.some((x) => x.id === requestId));
      });

      it('detalhe da solicitação mostra itens e progresso', async () => {
        const r = await api('GET', `/api/requests/${requestId}`);
        assert.equal(r.status, 200);
        assert.equal(r.body.items.length, 1);
        assert.equal(Number(r.body.items[0].quantity_requested), 10);
      });

      it('doação em dinheiro exige valor', async () => {
        const r = await api('POST', '/api/donations', {
          token, body: { institution_id: institutionId, donation_type: 'dinheiro' },
        });
        assert.equal(r.status, 422);
      });

      it('doação de itens exige item', async () => {
        const r = await api('POST', '/api/donations', {
          token, body: { institution_id: institutionId, donation_type: 'itens', items: [] },
        });
        assert.equal(r.status, 422);
      });

      it('cria doação de itens vinculada à solicitação', async () => {
        const r = await api('POST', '/api/donations', {
          token,
          body: {
            institution_id: institutionId,
            request_id: requestId,
            donation_type: 'itens',
            message: 'Entrego no sábado',
            items: [{ description: 'Cobertor casal', quantity: 4, item_condition: 'usado' }],
          },
        });
        assert.equal(r.status, 201, JSON.stringify(r.body));
        assert.match(r.body.donation.code, /^AJM[A-Z0-9]{5}$/);
        donationId = r.body.donation.id;
      });

      it('detalhe da doação traz histórico e itens', async () => {
        const r = await api('GET', `/api/donations/${donationId}`, { token });
        assert.equal(r.status, 200);
        assert.equal(r.body.items.length, 1);
        assert.equal(r.body.history.length, 1);
        assert.equal(r.body.history[0].to_status, 'pendente');
      });

      it('doador aparecer em /api/donations/mine', async () => {
        const r = await api('GET', '/api/donations/mine', { token });
        assert.equal(r.status, 200);
        assert.ok(r.body.donations.some((d) => d.id === donationId));
      });

      it('outro usuário não vê a doação', async () => {
        const other = await api('POST', '/api/auth/register', {
          body: {
            full_name: 'Curioso', email: `cur.${rnd()}@t.local`, cpf: makeCpf(),
            password: 'SenhaForte123', terms_accepted: true,
          },
        });
        const r = await api('GET', `/api/donations/${donationId}`, { token: other.body.token });
        assert.equal(r.status, 403);
      });

      it('instituição confirma a doação', async () => {
        const r = await api('PATCH', `/api/donations/${donationId}/status`, {
          token, body: { status: 'confirmada', note: 'Recebida no ponto de coleta' },
        });
        assert.equal(r.status, 200, JSON.stringify(r.body));
        assert.equal(r.body.donation.status, 'confirmada');
      });

      it('não permite salto de status inválido', async () => {
        const r = await api('PATCH', `/api/donations/${donationId}/status`, {
          token, body: { status: 'confirmada' },
        });
        assert.equal(r.status, 400);
      });

      it('progresso da solicitação reflete a doação', async () => {
        const r = await api('GET', `/api/requests/${requestId}`);
        assert.equal(r.status, 200);
        assert.equal(Number(r.body.progress.percent_complete), 40);
      });

      it('doador não pode mudar status (só a instituição)', async () => {
        const other = await api('POST', '/api/auth/register', {
          body: {
            full_name: 'Sem Staff', email: `ns.${rnd()}@t.local`, cpf: makeCpf(),
            password: 'SenhaForte123', terms_accepted: true,
          },
        });
        const r = await api('PATCH', `/api/donations/${donationId}/status`, {
          token: other.body.token, body: { status: 'recebida' },
        });
        assert.equal(r.status, 403);
      });

      it('instituição marca como recebida', async () => {
        const r = await api('PATCH', `/api/donations/${donationId}/status`, {
          token, body: { status: 'em_transito' },
        });
        assert.equal(r.status, 200);
        const r2 = await api('PATCH', `/api/donations/${donationId}/status`, {
          token, body: { status: 'recebida' },
        });
        assert.equal(r2.status, 200);
        assert.equal(r2.body.donation.status, 'recebida');
      });

      it('cria doação anônima sem vincular o doador', async () => {
        const r = await api('POST', '/api/donations', {
          token,
          body: {
            institution_id: institutionId, donation_type: 'itens', is_anonymous: true,
            items: [{ description: 'Doação anônima', quantity: 1 }],
          },
        });
        assert.equal(r.status, 201, JSON.stringify(r.body));
        assert.equal(r.body.donation.is_anonymous, 1);
        assert.equal(r.body.donation.donor_user_id, null);
        // Não aparece em "minhas doações" porque não há vínculo com a conta.
        const mine = await api('GET', '/api/donations/mine', { token });
        assert.ok(!mine.body.donations.some((d) => d.id === r.body.donation.id));
      });

      it('rejeita item de solicitação de outra instituição', async () => {
        const r = await api('POST', '/api/donations', {
          token,
          body: {
            institution_id: institutionId, request_id: requestId, donation_type: 'itens',
            items: [{ description: 'Inexistente', quantity: 1, request_item_id: 999999 }],
          },
        });
        assert.equal(r.status, 400, JSON.stringify(r.body));
        assert.equal(r.body.code, 'requisicao_invalida');
      });

      it('não permite doação em dinheiro para instituição que não aceita', async () => {
        const inst = await api('POST', '/api/institutions', {
          token,
          body: {
            legal_name: `Sem Dinheiro ${rnd()}`, cnpj: makeCnpj(),
            email: `sd.${rnd()}@teste.local`, accepts_money: false,
          },
        });
        const r = await api('POST', '/api/donations', {
          token, body: { institution_id: inst.body.institution.id, donation_type: 'dinheiro', amount: 50 },
        });
        assert.equal(r.status, 400);
      });

      it('doação em dinheiro válida entra como pendente de pagamento', async () => {
        const r = await api('POST', '/api/donations', {
          token,
          body: {
            institution_id: institutionId, donation_type: 'dinheiro', amount: 150.5,
            payment_method: 'pix',
          },
        });
        assert.equal(r.status, 201, JSON.stringify(r.body));
        assert.equal(r.body.donation.payment_status, 'pendente');
      });

      it('não permite cancelar doação já recebida', async () => {
        const r = await api('DELETE', `/api/donations/${donationId}`, { token });
        assert.equal(r.status, 400);
      });

      it('lista doações recebidas pela instituição', async () => {
        const r = await api('GET', `/api/donations/institution/${institutionId}`, { token });
        assert.equal(r.status, 200);
        assert.ok(r.body.donations.some((d) => d.id === donationId));
      });

      it('solicitação pode ser marcada como atendida', async () => {
        const r = await api('PATCH', `/api/requests/${requestId}/status`, {
          token, body: { status: 'atendida', note: 'Meta atingida' },
        });
        assert.equal(r.status, 200);
        assert.equal(r.body.request.status, 'atendida');
      });

      it('listagem pública exclui solicitação atendida', async () => {
        const r = await api('GET', '/api/requests?limit=100');
        assert.ok(!r.body.requests.some((x) => x.id === requestId));
      });
    });

    it('logout invalida o token', async () => {
      const before = await api('GET', '/api/users/me', { token });
      assert.equal(before.status, 200);
      const out = await api('POST', '/api/auth/logout', { token });
      assert.equal(out.status, 200);
      const after = await api('GET', '/api/users/me', { token });
      assert.equal(after.status, 401);
    });

    it('exclusão de conta exige a senha correta', async () => {
      const login = await api('POST', '/api/auth/login', { body: { email, password } });
      const r = await api('DELETE', '/api/users/me', { token: login.body.token, body: { password: 'errada' } });
      assert.equal(r.status, 403);
    });
  });

  // ------------------------------------------------------------------------
  // Fluxos usados diretamente pelas telas do site (frontend/):
  // doação sem escolher instituição, lista pública de doações, necessidades
  // públicas e troca de senha pelo perfil.
  // ------------------------------------------------------------------------
  describe('integração com as telas do site', () => {
    let token;
    let email;
    const password = 'SenhaForte123';
    let moneyId;
    let itemsId;

    before(async () => {
      email = `site.${rnd()}@teste.local`;
      // Telefone único: users.phone_e164 tem índice único no banco.
      const phone = `(14) 9${String(Math.floor(10000000 + Math.random() * 89999999))}`;
      const r = await api('POST', '/api/auth/register', {
        body: {
          full_name: 'Ana Paula Souza', email, cpf: makeCpf(), phone,
          password, terms_accepted: true,
        },
      });
      assert.equal(r.status, 201, JSON.stringify(r.body));
      token = r.body.token;
    });

    it('doação em dinheiro sem instituição é gravada', async () => {
      const r = await api('POST', '/api/donations', {
        token,
        body: {
          donation_type: 'dinheiro', amount: 100, payment_method: 'pix',
          donor_name: 'Ana Paula Souza', donor_email: 'ana@teste.local', donor_phone: '(14) 99876-5432',
        },
      });
      assert.equal(r.status, 201, JSON.stringify(r.body));
      assert.equal(r.body.donation.donation_type, 'dinheiro');
      assert.equal(r.body.donation.institution_id, null);
      assert.equal(r.body.donation.payment_status, 'pendente');
      assert.match(r.body.donation.code, /^AJM[A-Z0-9]{5}$/);
      moneyId = r.body.donation.id;
    });

    it('doação de itens sem instituição grava todos os itens', async () => {
      const r = await api('POST', '/api/donations', {
        token,
        body: {
          donation_type: 'itens',
          donor_name: 'Ana Paula Souza',
          items: [
            { description: 'Arroz', quantity: 2, unit_code: 'un', item_condition: 'novo' },
            { description: 'Feijão', quantity: 3, unit_code: 'un', item_condition: 'novo' },
          ],
        },
      });
      assert.equal(r.status, 201, JSON.stringify(r.body));
      itemsId = r.body.donation.id;

      const detail = await api('GET', `/api/donations/${itemsId}`, { token });
      assert.equal(detail.status, 200);
      assert.equal(detail.body.items.length, 2);
    });

    it('doação anônima pelo site não vincula a conta', async () => {
      const r = await api('POST', '/api/donations', {
        token, body: { donation_type: 'dinheiro', amount: 20, is_anonymous: true },
      });
      assert.equal(r.status, 201, JSON.stringify(r.body));
      assert.equal(r.body.donation.is_anonymous, 1);
      assert.equal(r.body.donation.donor_user_id, null);
    });

    it('doações recentes só listam confirmadas e escondem dados pessoais', async () => {
      const before = await api('GET', '/api/donations/recent');
      assert.equal(before.status, 200);
      assert.ok(!before.body.donations.some((d) => d.id === moneyId), 'pendente não deve aparecer');

      // Doação sem instituição é confirmada pela administração.
      const r = await api('PATCH', `/api/donations/${moneyId}/status`, {
        token: adminToken, body: { status: 'confirmada' },
      });
      assert.equal(r.status, 200, JSON.stringify(r.body));

      const after = await api('GET', '/api/donations/recent');
      const found = after.body.donations.find((d) => d.id === moneyId);
      assert.ok(found, 'doação confirmada deve aparecer');
      assert.equal(found.name, 'Ana', 'apenas o primeiro nome');
      assert.equal(found.donation_type, 'dinheiro');
      assert.match(found.detail, /R\$ 100,00/);
      // Nenhum campo sensível na resposta pública.
      const raw = JSON.stringify(after.body);
      assert.ok(!raw.includes('ana@teste.local'));
      assert.ok(!raw.includes('99876'));
    });

    it('doador comum não altera doação sem instituição', async () => {
      const r = await api('PATCH', `/api/donations/${itemsId}/status`, {
        token, body: { status: 'confirmada' },
      });
      assert.equal(r.status, 403);
    });

    it('necessidade criada aparece na listagem pública com itens', async () => {
      const created = await api('POST', '/api/requests', {
        token,
        body: {
          title: 'Cesta básica para família', description: 'Família com três crianças',
          priority: 'urgente', city: 'Botucatu', state_code: 'SP', beneficiary_count: 5,
          items: [{ description: 'Cesta básica', quantity_requested: 2, unit_code: 'un' }],
        },
      });
      assert.equal(created.status, 201, JSON.stringify(created.body));
      const id = created.body.request.id;

      const list = await api('GET', '/api/requests?limit=100');
      assert.equal(list.status, 200);
      const found = list.body.requests.find((r) => r.id === id);
      assert.ok(found, 'necessidade deve aparecer na lista');
      assert.equal(found.priority, 'urgente');
      assert.equal(found.items.length, 1);
      assert.equal(found.items[0].description, 'Cesta básica');
    });

    it('troca de senha exige a senha atual', async () => {
      const r = await api('POST', '/api/users/me/password', {
        token, body: { current_password: 'errada', new_password: 'OutraSenha123' },
      });
      assert.equal(r.status, 403);
    });

    it('troca de senha permite login com a nova senha', async () => {
      const r = await api('POST', '/api/users/me/password', {
        token, body: { current_password: password, new_password: 'OutraSenha123' },
      });
      assert.equal(r.status, 200, JSON.stringify(r.body));

      const old = await api('POST', '/api/auth/login', { body: { email, password } });
      assert.equal(old.status, 401, 'senha antiga deve falhar');

      const fresh = await api('POST', '/api/auth/login', { body: { email, password: 'OutraSenha123' } });
      assert.equal(fresh.status, 200, JSON.stringify(fresh.body));
      token = fresh.body.token;
    });

    it('perfil atualizado é lido de volta do banco', async () => {
      const up = await api('PATCH', '/api/users/me', {
        token, body: { display_name: 'Ana P.', birth_date: '1990-05-20' },
      });
      assert.equal(up.status, 200, JSON.stringify(up.body));

      const me = await api('GET', '/api/users/me', { token });
      assert.equal(me.status, 200);
      assert.equal(me.body.user.display_name, 'Ana P.');
      assert.equal(me.body.user.birth_date.slice(0, 10), '1990-05-20');
    });
  });

  // Usuário descartável: os testes de exclusão apagam a conta, então não
  // podem compartilhar o usuário dos demais cenários.
  describe('exclusão de conta (LGPD)', () => {
    let email;
    const password = 'SenhaForte123';

    before(async () => {
      email = `excluir.${rnd()}@teste.local`;
      const r = await api('POST', '/api/auth/register', {
        body: { full_name: 'Conta Descartável', email, cpf: makeCpf(), password, terms_accepted: true },
      });
      assert.equal(r.status, 201, JSON.stringify(r.body));
    });

    it('anonimiza os dados e encerra as sessões', async () => {
      const login = await api('POST', '/api/auth/login', { body: { email, password } });
      const t = login.body.token;

      const r = await api('DELETE', '/api/users/me', { token: t, body: { password } });
      assert.equal(r.status, 200, JSON.stringify(r.body));

      const after = await api('GET', '/api/users/me', { token: t });
      assert.equal(after.status, 401);

      const loginAgain = await api('POST', '/api/auth/login', { body: { email, password } });
      assert.equal(loginAgain.status, 401, 'conta excluída não deve logar');
    });
  });

  describe('conta importada do sistema antigo', () => {
    it('não loga com senha em texto puro', async () => {
      const r = await api('POST', '/api/auth/login', {
        body: { email: 'carlos@gmail.com', password: 'senha123' },
      });
      assert.equal(r.status, 401);
    });

    it('redefine a senha com e-mail + CPF e passa a logar', async () => {
      const r = await api('POST', '/api/auth/redefine-password', {
        body: { email: 'carlos@gmail.com', cpf: '12345678901', password: 'NovaSenha123' },
      });
      assert.equal(r.status, 200, JSON.stringify(r.body));
      const login = await api('POST', '/api/auth/login', {
        body: { email: 'carlos@gmail.com', password: 'NovaSenha123' },
      });
      assert.equal(login.status, 200);
    });
  });
});
