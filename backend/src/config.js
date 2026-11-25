import { config as loadEnv } from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// O .env fica na raiz de backend/. Procuramos primeiro ao lado do código, para
// funcionar mesmo quando o terminal foi aberto em outra pasta (VS Code, tarefa,
// atalho do Windows). Depois o diretório atual, útil para sobrescrever valores.
const backendDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
loadEnv({ path: path.join(backendDir, '.env') });
loadEnv();

function int(value, fallback) {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) ? n : fallback;
}

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: int(process.env.PORT, 3000),
  db: {
    // 127.0.0.1 evita o atraso do IPv6 (::1) do "localhost" no Windows.
    host: process.env.DB_HOST ?? '127.0.0.1',
    port: int(process.env.DB_PORT, 3306),
    user: process.env.DB_USER ?? 'root',
    password: process.env.DB_PASSWORD ?? '',
    database: process.env.DB_NAME ?? 'ajudamais',
    charset: 'utf8mb4',
    timezone: 'Z',
    connectionLimit: int(process.env.DB_POOL, 10),
    waitForConnections: true,
    namedPlaceholders: false,
    // Bancos gerenciados gratuitos (Aiven, Railway, Clever Cloud) normalmente
    // exigem TLS. Ative com DB_SSL=true.
    ...(String(process.env.DB_SSL ?? '').toLowerCase() === 'true'
      ? { ssl: { rejectUnauthorized: false } }
      : {}),
  },
  sessionDays: int(process.env.SESSION_DAYS, 30),
  bcryptRounds: int(process.env.BCRYPT_ROUNDS, 12),
  loginMaxAttempts: int(process.env.LOGIN_MAX_ATTEMPTS, 5),
  loginLockMinutes: int(process.env.LOGIN_LOCK_MINUTES, 15),
  corsOrigin: process.env.CORS_ORIGIN ?? '*',
};

export function assertConfig() {
  const missing = [];
  if (!config.db.database) missing.push('DB_NAME');
  if (!config.db.user) missing.push('DB_USER');
  if (missing.length) {
    throw new Error(`Configuração ausente: ${missing.join(', ')}`);
  }
}
