import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';
import { config } from './config.js';
import { one, query } from './db.js';
import { forbidden, unauthorized } from './errors.js';

const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');

export function newToken() {
  return crypto.randomBytes(32).toString('hex');
}
export const hashToken = sha256;

export async function hashPassword(plain) {
  return bcrypt.hash(plain, config.bcryptRounds);
}

// Contas importadas do sistema antigo têmsenha em texto puro: não podem logar
// até redefinirem a senha (endpoint /auth/redefine-password).
export async function verifyPassword(user, plain) {
  if (!user?.password_hash) return false;
  if (user.password_algo === 'bcrypt') return bcrypt.compare(plain, user.password_hash);
  return false;
}

export async function issueSession(userId, req) {
  const token = newToken();
  const expires = new Date(Date.now() + config.sessionDays * 86400_000);
  await query(
    `INSERT INTO sessions (user_id, token_hash, ip_address, user_agent, expires_at)
     VALUES (?, ?, ?, ?, ?)`,
    [
      userId,
      sha256(token),
      req.ip?.slice(0, 45) ?? null,
      req.get('user-agent')?.slice(0, 255) ?? null,
      expires,
    ],
  );
  return { token, expiresAt: expires };
}

export async function sessionUser(token) {
  if (!token) return null;
  const row = await one(
    `SELECT u.*, s.id AS session_id
       FROM sessions s
       JOIN users u ON u.id = s.user_id
      WHERE s.token_hash = ?
        AND s.revoked_at IS NULL
        AND s.expires_at > UTC_TIMESTAMP()
        AND u.deleted_at IS NULL
        AND u.status = 'ativo'
      LIMIT 1`,
    [sha256(token)],
  );
  if (row) {
    await query('UPDATE sessions SET last_used_at = UTC_TIMESTAMP() WHERE id = ?', [row.session_id]);
  }
  return row;
}

export async function revokeSession(token) {
  if (!token) return;
  await query('UPDATE sessions SET revoked_at = UTC_TIMESTAMP() WHERE token_hash = ?', [sha256(token)]);
}

export function bearerToken(req) {
  const header = req.get('authorization') ?? '';
  const m = /^Bearer\s+([a-f0-9]{64})$/i.exec(header.trim());
  return m ? m[1].toLowerCase() : null;
}

export async function loadRoles(userId) {
  const rows = await query(
    'SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ?',
    [userId],
  );
  return rows.map((r) => r.code);
}

export function requireAuth(req, _res, next) {
  if (!req.user) return next(unauthorized());
  next();
}

export function requireRole(...codes) {
  return (req, _res, next) => {
    if (!req.user) return next(unauthorized());
    if (!(req.user.roles ?? []).some((r) => codes.includes(r))) {
      return next(forbidden(`Requer perfil: ${codes.join(' ou ')}`));
    }
    next();
  };
}

// Quem gerencia a instituição: admin global, ou admin/gestor do vínculo ativo.
export async function assertInstitutionStaff(user, institutionId) {
  if (!user) throw unauthorized();
  if ((user.roles ?? []).includes('admin')) return true;
  const row = await one(
    `SELECT 1 AS ok FROM institution_members
      WHERE institution_id = ? AND user_id = ? AND status = 'ativo'
        AND member_role IN ('admin','gestor')`,
    [institutionId, user.id],
  );
  if (!row) throw forbidden('Você não gerencia esta instituição');
  return true;
}

export async function audit(actorId, action, entityType, entityId, newValues, req) {
  await query(
    `INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, new_values, ip_address, user_agent)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      actorId ?? null,
      String(action).slice(0, 60),
      String(entityType).slice(0, 40),
      entityId ?? null,
      newValues ? JSON.stringify(newValues) : null,
      req?.ip?.slice(0, 45) ?? null,
      req?.get('user-agent')?.slice(0, 255) ?? null,
    ],
  );
}
