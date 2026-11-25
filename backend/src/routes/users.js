import express from 'express';
import { z } from 'zod';
import {
  audit, badRequest, forbidden, hashPassword, hashToken, notFound, parse, requireAuth, verifyPassword,
} from '../middleware.js';
import { one, query, withTransaction } from '../db.js';
import { publicUser } from './auth.js';
import { addressSchema, changePasswordSchema, profileUpdateSchema } from '../validation.js';

const router = express.Router();
router.use(requireAuth);

router.get('/me', async (req, res) => {
  const [addresses, institutions] = await Promise.all([
    query(
      `SELECT id, label, address_type, postal_code, street, number, complement, district,
              city, state_code, is_primary
         FROM addresses WHERE user_id = ? ORDER BY is_primary DESC, id`,
      [req.user.id],
    ),
    query(
      `SELECT i.id, i.legal_name, i.trade_name, i.status, im.member_role, im.status AS membership_status
         FROM institution_members im
         JOIN institutions i ON i.id = im.institution_id
        WHERE im.user_id = ? AND i.deleted_at IS NULL
        ORDER BY i.legal_name`,
      [req.user.id],
    ),
  ]);
  res.json({ user: publicUser(req.user), roles: req.user.roles, addresses, institutions });
});

// Mapeia o campo do formulário (phone) para a coluna real da tabela.
const PROFILE_COLUMNS = {
  full_name: 'full_name',
  display_name: 'display_name',
  phone: 'phone_e164',
  birth_date: 'birth_date',
  avatar_url: 'avatar_url',
};

router.patch('/me', async (req, res, next) => {
  try {
    const data = parse(profileUpdateSchema, req.body);
    const fields = [];
    const params = [];
    for (const [key, value] of Object.entries(data)) {
      if (value === undefined) continue;
      const column = PROFILE_COLUMNS[key];
      if (!column) continue;
      fields.push(`${column} = ?`);
      params.push(value);
    }
    if (!fields.length) throw badRequest('Nenhum campo para atualizar');
    params.push(req.user.id);
    await query(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, params);
    const updated = await one('SELECT * FROM users WHERE id = ?', [req.user.id]);
    await audit(req.user.id, 'user.update', 'user', req.user.id, data, req);
    res.json({ user: publicUser(updated) });
  } catch (err) { next(err); }
});

// LGPD: anonimiza os dados pessoais e encerra as sessões. As doações ficam
// preservadas para a instituição (o trigger do banco libera a FK).
router.delete('/me', async (req, res, next) => {
  try {
    const password = parse(z.object({ password: z.string().min(1) }), req.body).password;
    if (!(await verifyPassword(req.user, password))) throw forbidden('Senha incorreta');

    await withTransaction(async (conn) => {
      await conn.execute(
        `UPDATE users SET status = 'excluido', deleted_at = UTC_TIMESTAMP(),
                email = CONCAT('excluido-', id, '@ajudamais.invalid'),
                phone_e164 = NULL, full_name = 'Conta excluída', cpf = LPAD(id, 11, '0')
         WHERE id = ?`,
        [req.user.id],
      );
      await conn.execute('UPDATE sessions SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ?', [req.user.id]);
    });
    await audit(req.user.id, 'user.delete', 'user', req.user.id, { lgpd: true }, req);
    res.json({ ok: true, message: 'Conta excluída e dados pessoais anonimizados.' });
  } catch (err) { next(err); }
});

// Troca de senha autenticada (perfil). Exige a senha atual.
router.post('/me/password', async (req, res, next) => {
  try {
    const data = parse(changePasswordSchema, req.body);
    if (!(await verifyPassword(req.user, data.current_password))) {
      throw forbidden('Senha atual incorreta');
    }
    const hash = await hashPassword(data.new_password);
    await query(
      "UPDATE users SET password_hash = ?, password_algo = 'bcrypt', must_change_password = 0 WHERE id = ?",
      [hash, req.user.id],
    );
    // Mantém a sessão atual e encerra as demais.
    await query(
      `UPDATE sessions SET revoked_at = UTC_TIMESTAMP()
        WHERE user_id = ? AND revoked_at IS NULL AND token_hash <> ?`,
      [req.user.id, hashToken(req.user.sessionToken ?? '')],
    );
    await audit(req.user.id, 'user.password_change', 'user', req.user.id, null, req);
    res.json({ ok: true, message: 'Senha alterada com sucesso.' });
  } catch (err) { next(err); }
});

// ---- Endereços ------------------------------------------------------------

router.get('/me/addresses', async (req, res) => {
  const rows = await query('SELECT * FROM addresses WHERE user_id = ? ORDER BY is_primary DESC, id', [req.user.id]);
  res.json({ addresses: rows });
});

router.post('/me/addresses', async (req, res, next) => {
  try {
    const data = parse(addressSchema, req.body);
    const address = await withTransaction(async (conn) => {
      if (data.is_primary) {
        await conn.execute('UPDATE addresses SET is_primary = 0 WHERE user_id = ?', [req.user.id]);
      }
      const [ins] = await conn.execute(
        `INSERT INTO addresses
           (user_id, label, address_type, postal_code, street, number, complement,
            district, city, state_code, is_primary)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          req.user.id, data.label ?? null, data.address_type, data.postal_code,
          data.street, data.number ?? null, data.complement ?? null,
          data.district ?? null, data.city, data.state_code ?? null, data.is_primary ? 1 : 0,
        ],
      );
      const [rows] = await conn.execute('SELECT * FROM addresses WHERE id = ?', [ins.insertId]);
      return rows[0];
    });
    await audit(req.user.id, 'address.create', 'address', address.id, { city: address.city }, req);
    res.status(201).json({ address });
  } catch (err) { next(err); }
});

router.patch('/me/addresses/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const current = await one('SELECT * FROM addresses WHERE id = ? AND user_id = ?', [id, req.user.id]);
    if (!current) throw notFound('Endereço não encontrado');

    const data = parse(addressSchema.partial(), req.body);
    const fields = [];
    const params = [];
    for (const [key, value] of Object.entries(data)) {
      if (value === undefined) continue;
      fields.push(`${key} = ?`);
      params.push(key === 'is_primary' ? (value ? 1 : 0) : value);
    }
    if (!fields.length) throw badRequest('Nenhum campo para atualizar');
    params.push(id, req.user.id);
    await query(`UPDATE addresses SET ${fields.join(', ')} WHERE id = ? AND user_id = ?`, params);
    const updated = await one('SELECT * FROM addresses WHERE id = ?', [id]);
    await audit(req.user.id, 'address.update', 'address', id, data, req);
    res.json({ address: updated });
  } catch (err) { next(err); }
});

router.delete('/me/addresses/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const result = await query('DELETE FROM addresses WHERE id = ? AND user_id = ?', [id, req.user.id]);
    if (!result.affectedRows) throw notFound('Endereço não encontrado');
    await audit(req.user.id, 'address.delete', 'address', id, null, req);
    res.status(204).end();
  } catch (err) { next(err); }
});

export default router;
