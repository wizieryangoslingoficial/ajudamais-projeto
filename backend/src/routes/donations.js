import express from 'express';
import crypto from 'node:crypto';
import {
  assertInstitutionStaff, audit, badRequest, forbidden, notFound, parse, requireAuth,
} from '../middleware.js';
import { one, query, withTransaction } from '../db.js';
import { donationSchema, donationStatusSchema } from '../validation.js';

const router = express.Router();

// Código curto e único exibido ao doador (ex.: AJM7K2QX).
function newCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = 'AJM';
  for (let i = 0; i < 5; i++) code += alphabet[crypto.randomInt(alphabet.length)];
  return code;
}

const STATUS_FLOW = {
  pendente: ['confirmada', 'cancelada', 'recusada'],
  confirmada: ['em_transito', 'recebida', 'cancelada'],
  em_transito: ['recebida', 'cancelada'],
  recebida: [],
  cancelada: [],
  recusada: [],
};

// ---- Doações recentes (público, para a tela inicial) ---------------------
// Mostra apenas doações confirmadas/recebidas e nunca expõe dados pessoais:
// nome reduzido a inicial + primeiro nome, sem e-mail, CPF ou telefone.

router.get('/recent', async (_req, res) => {
  const rows = await query(
    `SELECT d.id, d.code, d.donation_type, d.status, d.amount, d.is_anonymous,
            d.created_at, d.confirmed_at, d.donor_name, u.full_name, u.display_name,
            COALESCE(i.trade_name, i.legal_name) AS institution_name,
            (SELECT GROUP_CONCAT(di.description ORDER BY di.id SEPARATOR ' | ')
               FROM donation_items di WHERE di.donation_id = d.id) AS items_list,
            (SELECT COALESCE(SUM(di.quantity), 0)
               FROM donation_items di WHERE di.donation_id = d.id) AS items_quantity
       FROM donations d
       LEFT JOIN users u ON u.id = d.donor_user_id
       LEFT JOIN institutions i ON i.id = d.institution_id
      WHERE d.deleted_at IS NULL
        AND d.show_name_publicly = 1
        AND d.status IN ('confirmada', 'em_transito', 'recebida')
      ORDER BY d.created_at DESC
      LIMIT 10`,
  );

  res.json({
    donations: rows.map((d) => {
      const raw = d.is_anonymous ? null : (d.display_name || d.full_name || d.donor_name || '');
      const name = d.is_anonymous || !raw ? 'Doador anônimo' : String(raw).trim().split(/\s+/)[0];
      const initials = name === 'Doador anônimo' ? 'A' : name.charAt(0).toUpperCase();
      let detail;
      if (d.donation_type === 'dinheiro') {
        detail = `Dinheiro • R$ ${Number(d.amount ?? 0).toFixed(2).replace('.', ',')}`;
      } else {
        const first = d.items_list ? String(d.items_list).split(' | ')[0] : 'Itens';
        const total = Number(d.items_quantity ?? 0);
        detail = `Itens • ${first}${total > 1 ? ` (${total} un.)` : ''}`;
      }
      return {
        id: d.id,
        code: d.code,
        name,
        initials,
        detail,
        donation_type: d.donation_type,
        status: d.status,
        created_at: d.confirmed_at ?? d.created_at,
        institution_name: d.institution_name,
      };
    }),
  });
});

// ---- Minhas doações -------------------------------------------------------

router.get('/mine', requireAuth, async (req, res) => {
  const rows = await query(
    `SELECT d.id, d.code, d.donation_type, d.status, d.amount, d.payment_method, d.payment_status,
            d.is_anonymous, d.message, d.created_at, d.confirmed_at,
            i.id AS institution_id, COALESCE(i.trade_name, i.legal_name) AS institution_name,
            (SELECT COALESCE(SUM(di.quantity), 0) FROM donation_items di WHERE di.donation_id = d.id) AS items_quantity
       FROM donations d
       LEFT JOIN institutions i ON i.id = d.institution_id
      WHERE d.donor_user_id = ? AND d.deleted_at IS NULL
      ORDER BY d.created_at DESC
      LIMIT 100`,
    [req.user.id],
  );
  res.json({ donations: rows });
});

// ---- Doações recebidas pela instituição ----------------------------------

router.get('/institution/:institutionId', requireAuth, async (req, res, next) => {
  try {
    const institutionId = Number(req.params.institutionId);
    await assertInstitutionStaff(req.user, institutionId);
    const status = req.query.status ? String(req.query.status) : null;
    const params = [institutionId];
    let sql = `SELECT d.id, d.code, d.donation_type, d.status, d.amount, d.payment_status,
                      d.is_anonymous, COALESCE(u.full_name, d.donor_name) AS donor_name,
                      d.created_at, d.confirmed_at,
                      (SELECT COALESCE(SUM(di.quantity), 0) FROM donation_items di WHERE di.donation_id = d.id) AS items_quantity
                 FROM donations d
                 LEFT JOIN users u ON u.id = d.donor_user_id
                WHERE d.institution_id = ? AND d.deleted_at IS NULL`;
    if (status) { sql += ' AND d.status = ?'; params.push(status); }
    sql += ' ORDER BY d.created_at DESC LIMIT 200';
    res.json({ donations: await query(sql, params) });
  } catch (err) { next(err); }
});

// ---- Detalhe --------------------------------------------------------------

router.get('/:id', requireAuth, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const donation = await one(
      `SELECT d.*, COALESCE(i.trade_name, i.legal_name) AS institution_name,
              COALESCE(u.full_name, d.donor_name) AS donor_display_name
         FROM donations d
         LEFT JOIN institutions i ON i.id = d.institution_id
         LEFT JOIN users u ON u.id = d.donor_user_id
        WHERE d.id = ? AND d.deleted_at IS NULL`,
      [id],
    );
    if (!donation) throw notFound('Doação não encontrada');

    const isDonor = donation.donor_user_id === req.user.id;
    let isStaff = false;
    if (donation.institution_id) {
      try { await assertInstitutionStaff(req.user, donation.institution_id); isStaff = true; } catch { /* não é staff */ }
    }
    if (!isDonor && !isStaff) throw forbidden('Você não tem acesso a esta doação');

    const [items, history] = await Promise.all([
      query(
        `SELECT di.*, c.name AS category_name FROM donation_items di
           LEFT JOIN item_categories c ON c.id = di.category_id
          WHERE di.donation_id = ? ORDER BY di.id`,
        [id],
      ),
      query(
        `SELECT from_status, to_status, note, created_at FROM donation_status_history
          WHERE donation_id = ? ORDER BY created_at, id`,
        [id],
      ),
    ]);
    res.json({ donation, items, history });
  } catch (err) { next(err); }
});

// ---- Criar doação ---------------------------------------------------------

router.post('/', requireAuth, async (req, res, next) => {
  try {
    const data = parse(donationSchema, req.body);

    // Endereço de coleta precisa existir como endereço do próprio usuário.
    if (data.dropoff_address_id) {
      const address = await one(
        'SELECT id FROM addresses WHERE id = ? AND user_id = ?',
        [data.dropoff_address_id, req.user.id],
      );
      if (!address) throw notFound('Endereço de coleta não encontrado');
    }

    // Instituição é opcional: quando vem, validamos o que ela aceita.
    if (data.institution_id) {
      const institution = await one(
        "SELECT id, accepts_items, accepts_money FROM institutions WHERE id = ? AND deleted_at IS NULL",
        [data.institution_id],
      );
      if (!institution) throw notFound('Instituição não encontrada');
      if (data.donation_type === 'itens' && !institution.accepts_items) {
        throw badRequest('Esta instituição não recebe doações de itens');
      }
      if (data.donation_type === 'dinheiro' && !institution.accepts_money) {
        throw badRequest('Esta instituição não recebe doações em dinheiro');
      }
    }
    if (data.request_id) {
      const request = await one(
        'SELECT id, institution_id FROM assistance_requests WHERE id = ? AND deleted_at IS NULL',
        [data.request_id],
      );
      if (!request) throw notFound('Solicitação não encontrada');
      if (request.institution_id && data.institution_id && request.institution_id !== data.institution_id) {
        throw badRequest('A solicitação pertence a outra instituição');
      }
    }

    const result = await withTransaction(async (conn) => {
      let code = newCode();
      for (let i = 0; i < 5; i++) {
        const [dup] = await conn.execute('SELECT id FROM donations WHERE code = ?', [code]);
        if (!dup.length) break;
        code = newCode();
      }

      const [ins] = await conn.execute(
        `INSERT INTO donations
           (code, donor_user_id, donor_name, donor_email, is_anonymous, donation_type, status, amount,
            payment_method, payment_status, institution_id, request_id, campaign_id,
            dropoff_address_id, message)
         VALUES (?, ?, ?, ?, ?, ?, 'pendente', ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          code,
          // Doação anônima não guarda vínculo com a conta (exigência do CHECK
          // chk_donations_identifier: sem doador <=> anônima).
          data.is_anonymous ? null : req.user.id,
          data.is_anonymous ? (data.donor_name ?? null) : (data.donor_name ?? req.user.full_name ?? null),
          data.donor_email ?? req.user.email ?? null,
          data.is_anonymous ? 1 : 0,
          data.donation_type,
          data.donation_type === 'dinheiro' ? data.amount : null,
          data.donation_type === 'dinheiro' ? (data.payment_method ?? 'pix') : null,
          data.donation_type === 'dinheiro' ? 'pendente' : null,
          data.institution_id ?? null, data.request_id ?? null, data.campaign_id ?? null,
          data.dropoff_address_id ?? null,
          data.message ?? null,
        ],
      );
      const donationId = ins.insertId;

      if (data.donation_type === 'itens') {
        for (const item of data.items) {
          // Quando a doação é para uma solicitação, o item é vinculado ao item
          // pedido de mesma descrição (ou ao informado pelo cliente). Isso é o
          // que alimenta a barra de progresso da necessidade.
          let requestItemId = item.request_item_id ?? null;
          if (!requestItemId && data.request_id) {
            const [match] = await conn.execute(
              `SELECT id FROM request_items
                WHERE request_id = ?
                  AND LOWER(TRIM(description)) = LOWER(TRIM(?))
                ORDER BY id LIMIT 1`,
              [data.request_id, item.description],
            );
            requestItemId = match[0]?.id ?? null;
          }
          if (requestItemId) {
            const [valid] = await conn.execute(
              'SELECT id FROM request_items WHERE id = ? AND request_id = ?',
              [requestItemId, data.request_id ?? 0],
            );
            if (!valid.length) throw badRequest('Item da solicitação não pertence a esta solicitação');
          }

          await conn.execute(
            `INSERT INTO donation_items
               (donation_id, request_item_id, category_id, description, unit_code, quantity, item_condition)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
              donationId, requestItemId, item.category_id ?? null,
              item.description, item.unit_code, item.quantity, item.item_condition,
            ],
          );
        }
      }

      await conn.execute(
        `INSERT INTO donation_status_history (donation_id, from_status, to_status, changed_by, note)
         VALUES (?, NULL, 'pendente', ?, 'Doação registrada pelo doador')`,
        [donationId, req.user.id],
      );

      const [rows] = await conn.execute('SELECT * FROM donations WHERE id = ?', [donationId]);
      return rows[0];
    });

    await audit(req.user.id, 'donation.create', 'donation', result.id, { code: result.code }, req);
    res.status(201).json({ donation: result });
  } catch (err) { next(err); }
});

// ---- Mudança de status (instituição dona ou admin) ------------------------

router.patch('/:id/status', requireAuth, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const { status, note } = parse(donationStatusSchema, req.body);

    const donation = await one('SELECT * FROM donations WHERE id = ? AND deleted_at IS NULL', [id]);
    if (!donation) throw notFound('Doação não encontrada');
    // Doação sem instituição fica sob responsabilidade da administração.
    const isAdmin = (req.user.roles ?? []).some((r) => ['admin', 'moderador'].includes(r));
    if (donation.institution_id) {
      await assertInstitutionStaff(req.user, donation.institution_id);
    } else if (!isAdmin) {
      throw forbidden('Apenas a administração pode alterar doação sem instituição');
    }

    const allowed = STATUS_FLOW[donation.status] ?? [];
    if (!allowed.includes(status)) {
      throw badRequest(`Não é possível passar de "${donation.status}" para "${status}"`);
    }

    await withTransaction(async (conn) => {
      await conn.execute(
        `UPDATE donations SET status = ?,
                confirmed_at = CASE WHEN ? IN ('confirmada','recebida') AND confirmed_at IS NULL
                                    THEN UTC_TIMESTAMP() ELSE confirmed_at END,
                confirmed_by = CASE WHEN ? IN ('confirmada','recebida') AND confirmed_by IS NULL
                                    THEN ? ELSE confirmed_by END
          WHERE id = ?`,
        [status, status, status, req.user.id, id],
      );
      await conn.execute(
        `INSERT INTO donation_status_history (donation_id, from_status, to_status, changed_by, note)
         VALUES (?, ?, ?, ?, ?)`,
        [id, donation.status, status, req.user.id, note ?? null],
      );
      if (donation.donor_user_id) {
        const map = {
          confirmada: ['doacao_confirmada', 'Sua doação foi confirmada'],
          recebida: ['doacao_recebida', 'Sua doação foi recebida'],
          cancelada: ['doacao_cancelada', 'Sua doação foi cancelada'],
        };
        if (map[status]) {
          await conn.execute(
            `INSERT INTO notifications (user_id, type, title, body, entity_type, entity_id)
             VALUES (?, ?, ?, ?, 'donation', ?)`,
            [donation.donor_user_id, map[status][0], map[status][1], `Doação ${donation.code}`, id],
          );
        }
      }
    });

    await audit(req.user.id, `donation.${status}`, 'donation', id, { from: donation.status, to: status }, req);
    const updated = await one('SELECT * FROM donations WHERE id = ?', [id]);
    res.json({ donation: updated });
  } catch (err) { next(err); }
});

// ---- Cancelamento pelo próprio doador (só enquanto pendente) -------------

router.delete('/:id', requireAuth, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const donation = await one('SELECT * FROM donations WHERE id = ? AND deleted_at IS NULL', [id]);
    if (!donation) throw notFound('Doação não encontrada');
    if (donation.donor_user_id !== req.user.id) throw forbidden('Apenas o doador pode cancelar');
    if (donation.status !== 'pendente') throw badRequest('Só é possível cancelar doação pendente');

    await withTransaction(async (conn) => {
      await conn.execute(
        "UPDATE donations SET status = 'cancelada', cancel_reason = ? WHERE id = ?",
        ['Cancelada pelo doador', id],
      );
      await conn.execute(
        `INSERT INTO donation_status_history (donation_id, from_status, to_status, changed_by, note)
         VALUES (?, 'pendente', 'cancelada', ?, 'Cancelada pelo doador')`,
        [id, req.user.id],
      );
    });
    await audit(req.user.id, 'donation.cancel', 'donation', id, null, req);
    res.json({ ok: true });
  } catch (err) { next(err); }
});

export default router;
