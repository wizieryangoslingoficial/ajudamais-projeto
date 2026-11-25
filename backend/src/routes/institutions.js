import express from 'express';
import { z } from 'zod';
import { audit, assertInstitutionStaff, badRequest, conflict, notFound, parse, requireAuth } from '../middleware.js';
import { one, query, withTransaction } from '../db.js';
import { campaignSchema, institutionSchema, institutionUpdateSchema } from '../validation.js';

const router = express.Router();

const PUBLIC_COLUMNS = `
  i.id, i.legal_name, i.trade_name, i.cnpj, i.institution_type, i.description,
  i.mission, i.logo_url, i.cover_url, i.website_url, i.instagram_handle,
  i.accepts_items, i.accepts_money, i.accepts_volunteers, i.status, i.created_at`;

// ---- Consulta pública -----------------------------------------------------

router.get('/', async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 20, 100);
  const offset = Math.max(Number(req.query.offset) || 0, 0);
  const filters = ["i.deleted_at IS NULL", "i.status IN ('verificada','pendente')"];
  const params = [];

  if (req.query.city) { filters.push('a.city = ?'); params.push(String(req.query.city)); }
  if (req.query.uf) { filters.push('a.state_code = ?'); params.push(String(req.query.uf).toUpperCase()); }
  if (req.query.type) { filters.push('i.institution_type = ?'); params.push(String(req.query.type)); }

  params.push(limit, offset);
  const rows = await query(
    `SELECT ${PUBLIC_COLUMNS}, a.city, a.state_code, a.district
       FROM institutions i
       LEFT JOIN addresses a ON a.institution_id = i.id AND a.is_primary = 1
      WHERE ${filters.join(' AND ')}
      ORDER BY i.status = 'verificada' DESC, i.legal_name
      LIMIT ? OFFSET ?`,
    params,
  );
  res.json({ institutions: rows, limit, offset });
});

router.get('/:id', async (req, res, next) => {
  try {
    const inst = await one(
      `SELECT ${PUBLIC_COLUMNS} FROM institutions i
        WHERE i.id = ? AND i.deleted_at IS NULL`,
      [Number(req.params.id)],
    );
    if (!inst) throw notFound('Instituição não encontrada');
    const [addresses, campaigns] = await Promise.all([
      query('SELECT * FROM addresses WHERE institution_id = ? ORDER BY is_primary DESC', [inst.id]),
      query(
        `SELECT id, title, slug, goal_type, goal_amount, goal_quantity, status, starts_at, ends_at
           FROM campaigns WHERE institution_id = ? AND status IN ('ativa','encerrada')
           ORDER BY starts_at DESC`,
        [inst.id],
      ),
    ]);
    res.json({ institution: inst, addresses, campaigns });
  } catch (err) { next(err); }
});

// ---- Criação: o usuário logado vira admin da instituição ------------------

router.post('/', requireAuth, async (req, res, next) => {
  try {
    const data = parse(institutionSchema, req.body);
    const created = await withTransaction(async (conn) => {
      const [dupEmail] = await conn.execute('SELECT id FROM institutions WHERE email = ? LIMIT 1', [data.email]);
      if (dupEmail.length) throw conflict('Já existe instituição com este e-mail');
      if (data.cnpj) {
        const [dupCnpj] = await conn.execute('SELECT id FROM institutions WHERE cnpj = ? LIMIT 1', [data.cnpj]);
        if (dupCnpj.length) throw conflict('Já existe instituição com este CNPJ');
      }
      const [ins] = await conn.execute(
        `INSERT INTO institutions
           (legal_name, trade_name, cnpj, institution_type, description, email, phone_e164,
            website_url, accepts_items, accepts_money, accepts_volunteers, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pendente')`,
        [
          data.legal_name, data.trade_name ?? null, data.cnpj, data.institution_type,
          data.description ?? null, data.email, data.phone ?? null, data.website_url ?? null,
          data.accepts_items ? 1 : 0, data.accepts_money ? 1 : 0, data.accepts_volunteers ? 1 : 0,
        ],
      );
      const institutionId = ins.insertId;
      await conn.execute(
        `INSERT INTO institution_members (institution_id, user_id, member_role, status)
         VALUES (?, ?, 'admin', 'ativo')`,
        [institutionId, req.user.id],
      );
      await conn.execute(
        `INSERT IGNORE INTO user_roles (user_id, role_id) SELECT ?, id FROM roles WHERE code = 'instituicao'`,
        [req.user.id],
      );
      const [rows] = await conn.execute('SELECT * FROM institutions WHERE id = ?', [institutionId]);
      return rows[0];
    });
    await audit(req.user.id, 'institution.create', 'institution', created.id, { email: created.email }, req);
    res.status(201).json({ institution: created });
  } catch (err) { next(err); }
});

router.patch('/:id', requireAuth, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    await assertInstitutionStaff(req.user, id);
    const data = parse(institutionUpdateSchema, req.body);
    const fields = [];
    const params = [];
    for (const [key, value] of Object.entries(data)) {
      if (value === undefined) continue;
      fields.push(`${key} = ?`);
      params.push(typeof value === 'boolean' ? (value ? 1 : 0) : value);
    }
    if (!fields.length) throw badRequest('Nenhum campo para atualizar');
    params.push(id);
    await query(`UPDATE institutions SET ${fields.join(', ')} WHERE id = ? AND deleted_at IS NULL`, params);
    const updated = await one('SELECT * FROM institutions WHERE id = ?', [id]);
    await audit(req.user.id, 'institution.update', 'institution', id, data, req);
    res.json({ institution: updated });
  } catch (err) { next(err); }
});

// ---- Campanhas ------------------------------------------------------------

router.get('/:id/campaigns', async (req, res) => {
  const rows = await query(
    `SELECT * FROM campaigns WHERE institution_id = ? AND status <> 'rascunho' ORDER BY starts_at DESC`,
    [Number(req.params.id)],
  );
  res.json({ campaigns: rows });
});

router.post('/:id/campaigns', requireAuth, async (req, res, next) => {
  try {
    const institutionId = Number(req.params.id);
    await assertInstitutionStaff(req.user, institutionId);
    const data = parse(campaignSchema, req.body);
    const exists = await one("SELECT id FROM campaigns WHERE slug = ?", [data.slug]);
    if (exists) throw conflict('Já existe campanha com este endereço (slug)');
    const ins = await query(
      `INSERT INTO campaigns
         (institution_id, title, slug, description, goal_type, goal_amount, goal_quantity, ends_at, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        institutionId, data.title, data.slug, data.description ?? null, data.goal_type,
        data.goal_amount ?? null, data.goal_quantity ?? null, data.ends_at ?? null, req.user.id,
      ],
    );
    const campaign = await one('SELECT * FROM campaigns WHERE id = ?', [ins.insertId]);
    await audit(req.user.id, 'campaign.create', 'campaign', campaign.id, { institutionId }, req);
    res.status(201).json({ campaign });
  } catch (err) { next(err); }
});

router.patch('/:id/campaigns/:campaignId', requireAuth, async (req, res, next) => {
  try {
    const institutionId = Number(req.params.id);
    await assertInstitutionStaff(req.user, institutionId);
    const campaignId = Number(req.params.campaignId);
    const current = await one('SELECT * FROM campaigns WHERE id = ? AND institution_id = ?', [campaignId, institutionId]);
    if (!current) throw notFound('Campanha não encontrada');
    const data = parse(campaignSchema.partial().extend({
      status: z.enum(['rascunho', 'ativa', 'encerrada', 'cancelada']).optional(),
    }), req.body);
    const fields = [];
    const params = [];
    for (const [key, value] of Object.entries(data)) {
      if (value === undefined) continue;
      fields.push(`${key} = ?`);
      params.push(value);
    }
    if (!fields.length) throw badRequest('Nenhum campo para atualizar');
    params.push(campaignId, institutionId);
    await query(`UPDATE campaigns SET ${fields.join(', ')} WHERE id = ? AND institution_id = ?`, params);
    const campaign = await one('SELECT * FROM campaigns WHERE id = ?', [campaignId]);
    await audit(req.user.id, 'campaign.update', 'campaign', campaignId, data, req);
    res.json({ campaign });
  } catch (err) { next(err); }
});

export default router;
