import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { config, assertConfig } from './config.js';
import { ping, query } from './db.js';
import { HttpError } from './errors.js';
import { bearerToken, loadRoles, sessionUser } from './auth.js';
import authRoutes from './routes/auth.js';
import userRoutes from './routes/users.js';
import institutionRoutes from './routes/institutions.js';
import donationRoutes from './routes/donations.js';
import requestRoutes from './routes/requests.js';
import metaRoutes from './routes/meta.js';

assertConfig();

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '1mb' }));

// Sem dependência de CORS: libera a origem configurada (padrão: qualquer uma
// em desenvolvimento). Ajuste CORS_ORIGIN em produção.
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', config.corsOrigin);
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, PUT, DELETE, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();
  next();
});

// Cabeçalhos básicos de segurança.
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  next();
});

// Carrega o usuário da sessão (opcional) em toda requisição.
app.use(async (req, _res, next) => {
  try {
    const token = bearerToken(req);
    const user = await sessionUser(token);
    if (user) {
      user.roles = await loadRoles(user.id);
      user.sessionToken = token;
    }
    req.user = user;
    next();
  } catch (err) { next(err); }
});

app.get('/api/health', async (_req, res) => {
  try {
    const info = await ping();
    res.json({
      ok: info.ok === 1,
      database: config.db.database,
      mysql_version: info.versao,
      timezone: info.tz,
      env: config.env,
      time: new Date().toISOString(),
    });
  } catch (err) {
    res.status(503).json({ ok: false, error: 'banco_indisponivel', message: err.message });
  }
});

// Endpoint exclusivo de teste: promove a própria conta a um papel para validar
// fluxos administrativos. Só existe com NODE_ENV=test; em produção retorna 404.
if (config.env === 'test') {
  app.post('/api/_test/promote', async (req, res, next) => {
    try {
      if (!req.user) return res.status(401).json({ code: 'nao_autenticado' });
      const email = String(req.body?.email ?? '').toLowerCase();
      if (email !== String(req.user.email).toLowerCase()) {
        return res.status(403).json({ code: 'sem_permissao' });
      }
      const role = String(req.body?.role ?? 'admin');
      await query(
        `INSERT IGNORE INTO user_roles (user_id, role_id) SELECT ?, id FROM roles WHERE code = ?`,
        [req.user.id, role],
      );
      res.json({ ok: true, token: req.user.sessionToken, roles: await loadRoles(req.user.id) });
    } catch (err) { next(err); }
  });
}

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/institutions', institutionRoutes);
app.use('/api/donations', donationRoutes);
app.use('/api/requests', requestRoutes);
app.use('/api', metaRoutes);

app.use('/api', (_req, res) => {
  res.status(404).json({ code: 'rota_nao_encontrada', message: 'Rota não encontrada' });
});

// O site (frontend/) é servido pelo próprio Express, na mesma origem da API.
// Assim o site funciona abrindo http://localhost:3000 sem configurar nada.
// Local: ../frontend ao lado de backend/. Na Vercel, api/index.js informa o caminho.
const FRONTEND_DIR = process.env.FRONTEND_DIR
  ? path.resolve(process.env.FRONTEND_DIR)
  : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'frontend');
// O navegador pede /favicon.ico automaticamente; responder 204 evita 404 no painel.
app.get('/favicon.ico', (_req, res) => res.status(204).end());

app.use(express.static(FRONTEND_DIR, {
  extensions: ['html'],
  setHeaders: (res, filePath) => {
    // HTML do site muda com frequência; evita cache entre versões.
    if (filePath.endsWith('.html')) res.setHeader('Cache-Control', 'no-cache');
  },
}));

// Handler único de erros: formato estável para o frontend.
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  if (err instanceof HttpError) {
    return res.status(err.status).json({
      code: err.code, message: err.message, ...(err.details ? { details: err.details } : {}),
    });
  }
  // Violações do banco (FK, CHECK, unicidade) viram resposta legível.
  if (err?.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({ code: 'conflito', message: 'Já existe um registro com estes dados' });
  }
  if (['ER_NO_REFERENCED_ROW_2', 'ER_ROW_IS_REFERENCED_2', 'ER_NO_REFERENCED_ROW',
    'ER_ROW_IS_REFERENCED'].includes(err?.code)) {
    return res.status(422).json({ code: 'vinculo_invalido', message: 'Referência inválida entre registros' });
  }
  if (['ER_CHECK_CONSTRAINT_VIOLATED', 'ER_CONSTRAINT_FAILED', 'WARN_DATA_TRUNCATED',
    'ER_DATA_TOO_LONG', 'ER_TRUNCATED_WRONG_VALUE', 'ER_WARN_DATA_OUT_OF_RANGE'].includes(err?.code)) {
    return res.status(422).json({ code: 'dado_invalido', message: 'Os dados não respeitam as regras do banco' });
  }
  if (err?.type === 'entity.parse.failed') {
    return res.status(400).json({ code: 'json_invalido', message: 'Corpo JSON inválido' });
  }
  if (err?.type === 'entity.too.large') {
    return res.status(413).json({ code: 'corpo_muito_grande', message: 'Requisição muito grande' });
  }

  console.error('[erro]', err);
  res.status(500).json({ code: 'erro_interno', message: 'Erro interno no servidor' });
});

export default app;
