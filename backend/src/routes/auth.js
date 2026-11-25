import express from 'express';
import { z } from 'zod';
import {
  audit, conflict, forbidden, hashPassword, issueSession, loadRoles,
  notFound, parse, revokeSession, unauthorized, verifyPassword,
} from '../middleware.js';
import { one, query, withTransaction } from '../db.js';
import { loginSchema, recoverAccountSchema, registerSchema, toE164 } from '../validation.js';

const router = express.Router();

export function publicUser(u) {
  return {
    id: u.id,
    full_name: u.full_name,
    display_name: u.display_name,
    email: u.email,
    cpf_masked: u.cpf ? `***${String(u.cpf).slice(-2)}` : null,
    phone_e164: u.phone_e164,
    birth_date: u.birth_date,
    avatar_url: u.avatar_url,
    status: u.status,
    created_at: u.created_at,
  };
}

router.post('/register', async (req, res, next) => {
  try {
    const data = parse(registerSchema, req.body);

    const user = await withTransaction(async (conn) => {
      const [existing] = await conn.execute(
        'SELECT email, cpf FROM users WHERE email = ? OR cpf = ? LIMIT 1',
        [data.email, data.cpf],
      );
      if (existing.length) {
        throw conflict(`Já existe uma conta com este ${existing[0].email === data.email ? 'e-mail' : 'CPF'}`);
      }

      const [terms] = await conn.execute(
        'SELECT id FROM terms_versions WHERE is_current = 1 ORDER BY effective_at DESC LIMIT 1',
      );
      if (!terms.length) throw new Error('Nenhuma versão de termos ativa no banco');

      const passwordHash = await hashPassword(data.password);
      const [ins] = await conn.execute(
        `INSERT INTO users
           (full_name, email, cpf, phone_e164, password_hash, password_algo,
            status, terms_accepted_at)
         VALUES (?, ?, ?, ?, ?, 'bcrypt', 'ativo', UTC_TIMESTAMP())`,
        [data.full_name, data.email, data.cpf, data.phone ?? null, passwordHash],
      );
      const userId = ins.insertId;

      await conn.execute(
        `INSERT INTO user_roles (user_id, role_id) SELECT ?, id FROM roles WHERE code = 'doador'`,
        [userId],
      );
      await conn.execute(
        `INSERT INTO terms_acceptances (user_id, terms_version_id, ip_address, user_agent)
         VALUES (?, ?, ?, ?)`,
        [userId, terms[0].id, req.ip?.slice(0, 45) ?? null, req.get('user-agent')?.slice(0, 255) ?? null],
      );

      const [rows] = await conn.execute('SELECT * FROM users WHERE id = ?', [userId]);
      return rows[0];
    });

    const { token, expiresAt } = await issueSession(user.id, req);
    await audit(user.id, 'user.register', 'user', user.id, { email: user.email }, req);
    res.status(201).json({
      user: publicUser(user), roles: await loadRoles(user.id), token, expires_at: expiresAt,
    });
  } catch (err) { next(err); }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, cpf, password } = parse(loginSchema, req.body);
    const digits = cpf ? String(cpf).replace(/\D/g, '') : null;
    const user = email
      ? await one('SELECT * FROM users WHERE email = ? AND deleted_at IS NULL LIMIT 1', [email])
      : await one('SELECT * FROM users WHERE cpf = ? AND deleted_at IS NULL LIMIT 1', [digits]);

    // Mesma mensagem para conta inexistente e senha errada: não revela contas.
    const invalid = unauthorized('CPF/e-mail ou senha incorretos');
    if (!user) {
      await audit(null, 'auth.login_failed', 'user', null, { email, cpf: digits }, req);
      throw invalid;
    }
    if (user.locked_until && new Date(user.locked_until) > new Date()) {
      throw forbidden('Conta temporariamente bloqueada por tentativas inválidas');
    }
    if (user.status !== 'ativo') throw forbidden('Conta inativa ou pendente de verificação');

    if (!(await verifyPassword(user, password))) {
      const attempts = Number(user.login_attempts ?? 0) + 1;
      const lock = attempts >= 5 ? new Date(Date.now() + 15 * 60_000) : null;
      await query('UPDATE users SET login_attempts = ?, locked_until = ? WHERE id = ?', [attempts, lock, user.id]);
      await audit(user.id, 'auth.login_failed', 'user', user.id, { attempts }, req);
      throw invalid;
    }

    await query(
      'UPDATE users SET login_attempts = 0, locked_until = NULL, last_login_at = UTC_TIMESTAMP() WHERE id = ?',
      [user.id],
    );
    const { token, expiresAt } = await issueSession(user.id, req);
    await audit(user.id, 'auth.login', 'user', user.id, null, req);
    res.json({ user: publicUser(user), roles: await loadRoles(user.id), token, expires_at: expiresAt });
  } catch (err) { next(err); }
});

router.post('/logout', async (req, res, next) => {
  try {
    await revokeSession(req.user?.sessionToken);
    res.json({ ok: true });
  } catch (err) { next(err); }
});

// Localiza a conta pelo e-mail ou celular para orientar a recuperação.
// Não revela nada além de um contato mascarado; a redefinição exige CPF.
router.post('/recover-account', async (req, res, next) => {
  try {
    const { metodo, valor } = parse(recoverAccountSchema, req.body);
    const generic = {
      ok: true,
      found: false,
      message: 'Se os dados informados estiverem cadastrados, você receberá as instruções.',
    };
    let user = null;
    if (metodo === 'email') {
      user = await one('SELECT id, email, phone_e164 FROM users WHERE email = ? AND deleted_at IS NULL LIMIT 1',
        [valor.toLowerCase()]);
    } else {
      const e164 = toE164(valor);
      if (e164) {
        user = await one('SELECT id, email, phone_e164 FROM users WHERE phone_e164 = ? AND deleted_at IS NULL LIMIT 1',
          [e164]);
      }
    }
    if (!user) return res.json(generic);

    const maskedEmail = user.email
      ? user.email.replace(/^(.{2}).*(@.*)$/, (_, a, b) => `${a}${'*'.repeat(3)}${b}`)
      : null;
    const maskedPhone = user.phone_e164
      ? user.phone_e164.replace(/^(\+55\d{2})\d{4,5}(\d{4})$/, '$1*****$2')
      : null;
    res.json({
      ok: true,
      found: true,
      masked_email: maskedEmail,
      masked_phone: maskedPhone,
      message: 'Encontramos sua conta. Para definir uma nova senha, informe o e-mail e o CPF dela.',
    });
  } catch (err) { next(err); }
});

// Contas importadas têm senha em texto puro e não podem logar. Aqui o dono
// define uma senha nova usando e-mail + CPF da própria conta.
router.post('/redefine-password', async (req, res, next) => {
  try {
    const data = parse(z.object({
      email: z.string().trim().toLowerCase().email(),
      cpf: z.string(),
      password: z.string().min(8, 'A senha deve ter ao menos 8 caracteres').max(72),
    }), req.body);

    const cpf = String(data.cpf).replace(/\D/g, '');
    const user = await one('SELECT * FROM users WHERE email = ? AND cpf = ? LIMIT 1', [data.email, cpf]);
    if (!user) throw notFound('Conta não encontrada para os dados informados');

    const hash = await hashPassword(data.password);
    await query(
      `UPDATE users SET password_hash = ?, password_algo = 'bcrypt', must_change_password = 0,
              login_attempts = 0, locked_until = NULL WHERE id = ?`,
      [hash, user.id],
    );
    await query('UPDATE sessions SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ?', [user.id]);
    await audit(user.id, 'auth.password_redefined', 'user', user.id, null, req);
    res.json({ ok: true, message: 'Senha redefinida. Faça login novamente.' });
  } catch (err) { next(err); }
});

export default router;
