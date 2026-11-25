import express from 'express';
import {
  assertInstitutionStaff, audit, badRequest, forbidden, notFound, parse, requireAuth,
} from '../middleware.js';
import { one, query, withTransaction } from '../db.js';
import { requestSchema, requestStatusSchema } from '../validation.js';
const router = express.Router();

const STATUS_FLOW = {
  rascunho: ['aberta', 'cancelada'],
  aberta: ['parcialmente_atendida', 'atendida', 'cancelada', 'expirada'],
  parcialmente_atendida: ['atendida', 'cancelada', 'expirada'],
  atendida: [],
  cancelada: [],
  expirada: [],
  bloqueada: ['aberta', 'cancelada'],
};

// ---- Consulta pública -----------------------------------------------------

router.get('/', async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 20, 100);
  const offset = Math.max(Number(req.query.offset) || 0, 0);
  const filters = ['r.deleted_at IS NULL', "r.is_public = 1", "r.status IN ('aberta','parcialmente_atendida')"];
  const params = [];

  if (req.query.uf) { filters.push('r.state_code = ?'); params.push(String(req.query.uf).toUpperCase()); }
  if (req.query.city) { filters.push('r.city = ?'); params.push(String(req.query.city)); }
  if (req.query.category) { filters.push('r.category_id = ?'); params.push(Number(req.query.category)); }

  params.push(limit, offset);
  const rows = await query(
    `SELECT r.id, r.title, r.description, r.priority, r.city, r.state_code, r.needed_by,
            r.beneficiary_count, r.status, r.created_at,
            c.slug AS category_slug, c.name AS category_name,
            COALESCE(i.trade_name, i.legal_name) AS institution_name,
            p.percent_complete
       FROM assistance_requests r
       LEFT JOIN institutions i ON i.id = r.institution_id
       LEFT JOIN item_categories c ON c.id = r.category_id
       LEFT JOIN v_request_progress p ON p.id = r.id
      WHERE ${filters.join(' AND ')}
      ORDER BY FIELD(r.priority,'urgente','alta','normal','baixa'), r.created_at DESC
      LIMIT ? OFFSET ?`,
    params,
  );

  // Itens pedidos em cada necessidade, em uma única consulta.
  const ids = rows.map((r) => r.id);
  let itemsByRequest = {};
  if (ids.length) {
    const items = await query(
      `SELECT id, request_id, description, unit_code, quantity_requested
         FROM request_items WHERE request_id IN (${ids.map(() => '?').join(',')})
        ORDER BY id`,
      ids,
    );
    itemsByRequest = items.reduce((acc, it) => {
      (acc[it.request_id] ??= []).push(it);
      return acc;
    }, {});
  }

  res.json({
    requests: rows.map((r) => ({ ...r, items: itemsByRequest[r.id] ?? [] })),
    limit,
    offset,
  });
});

router.get('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const request = await one(
      `SELECT r.*, COALESCE(i.trade_name, i.legal_name) AS institution_name
         FROM assistance_requests r
         LEFT JOIN institutions i ON i.id = r.institution_id
        WHERE r.id = ? AND r.deleted_at IS NULL`,
      [id],
    );
    if (!request) throw notFound('Solicitação não encontrada');
    if (!request.is_public && request.requester_user_id !== req.user?.id) {
      let staff = false;
      if (request.institution_id && req.user) {
        try { await assertInstitutionStaff(req.user, request.institution_id); staff = true; } catch { /* não é staff */ }
      }
      if (!staff) throw forbidden('Solicitação privada');
    }
    const [items, progress] = await Promise.all([
      query('SELECT * FROM request_items WHERE request_id = ? ORDER BY id', [id]),
      one('SELECT * FROM v_request_progress WHERE id = ?', [id]),
    ]);
    res.json({ request, items, progress });
  } catch (err) { next(err); }
});

// ---- Criar: como pessoa OU em nome de uma instituição ---------------------

router.post('/', requireAuth, async (req, res, next) => {
  try {
    const institutionId = req.body?.institution_id ? Number(req.body.institution_id) : null;
    const data = parse(requestSchema, req.body);
    if (institutionId) await assertInstitutionStaff(req.user, institutionId);

    const created = await withTransaction(async (conn) => {
      const [ins] = await conn.execute(
        `INSERT INTO assistance_requests
           (institution_id, requester_user_id, title, description, category_id, priority,
            city, state_code, beneficiary_count, needed_by, is_public, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 'aberta')`,
        [
          institutionId, institutionId ? null : req.user.id, data.title, data.description ?? null,
          data.category_id ?? null, data.priority, data.city ?? null, data.state_code ?? null,
          data.beneficiary_count ?? null, data.needed_by ?? null,
        ],
      );
      const requestId = ins.insertId;

      for (const item of data.items) {
        await conn.execute(
          `INSERT INTO request_items (request_id, category_id, description, unit_code, quantity_requested)
           VALUES (?, ?, ?, ?, ?)`,
          [requestId, item.category_id ?? null, item.description, item.unit_code, item.quantity_requested],
        );
      }
      await conn.execute(
        `INSERT INTO request_status_history (request_id, from_status, to_status, changed_by, note)
         VALUES (?, NULL, 'aberta', ?, 'Solicitação publicada')`,
        [requestId, req.user.id],
      );
      const [rows] = await conn.execute('SELECT * FROM assistance_requests WHERE id = ?', [requestId]);
      return rows[0];
    });

    await audit(req.user.id, 'request.create', 'request', created.id, { institutionId }, req);
    res.status(201).json({ request: created });
  } catch (err) { next(err); }
});

// ---- Minhas solicitações --------------------------------------------------

router.get('/mine/list', requireAuth, async (req, res) => {
  const rows = await query(
    `SELECT r.id, r.title, r.status, r.priority, r.city, r.state_code, r.created_at,
            (SELECT COUNT(*) FROM request_items ri WHERE ri.request_id = r.id) AS items_count
       FROM assistance_requests r
      WHERE (r.requester_user_id = ? OR r.institution_id IN
              (SELECT institution_id FROM institution_members
                WHERE user_id = ? AND status = 'ativo'))
        AND r.deleted_at IS NULL
      ORDER BY r.created_at DESC
      LIMIT 100`,
    [req.user.id, req.user.id],
  );
  res.json({ requests: rows });
});

// ---- Mudança de status ----------------------------------------------------

router.patch('/:id/status', requireAuth, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const { status, note } = parse(requestStatusSchema, req.body);

    const request = await one('SELECT * FROM assistance_requests WHERE id = ? AND deleted_at IS NULL', [id]);
    if (!request) throw notFound('Solicitação não encontrada');

    const isRequester = request.requester_user_id === req.user.id;
    let isStaff = false;
    if (request.institution_id) {
      try { await assertInstitutionStaff(req.user, request.institution_id); isStaff = true; } catch { /* não é staff */ }
    }
    if (!isRequester && !isStaff) throw forbidden('Você não gerencia esta solicitação');

    const allowed = STATUS_FLOW[request.status] ?? [];
    if (!allowed.includes(status)) {
      throw badRequest(`Não é possível passar de "${request.status}" para "${status}"`);
    }

    await withTransaction(async (conn) => {
      await conn.execute(
        `UPDATE assistance_requests SET status = ?,
                closed_at = CASE WHEN ? IN ('atendida','cancelada','expirada')
                                 THEN UTC_TIMESTAMP() ELSE closed_at END,
                close_reason = CASE WHEN ? IN ('cancelada','expirada') THEN ? ELSE close_reason END
          WHERE id = ?`,
        [status, status, status, note ?? null, id],
      );
      await conn.execute(
        `INSERT INTO request_status_history (request_id, from_status, to_status, changed_by, note)
         VALUES (?, ?, ?, ?, ?)`,
        [id, request.status, status, req.user.id, note ?? null],
      );
    });

    await audit(req.user.id, `request.${status}`, 'request', id, { from: request.status }, req);
    res.json({ request: await one('SELECT * FROM assistance_requests WHERE id = ?', [id]) });
  } catch (err) { next(err); }
});

export default router;
