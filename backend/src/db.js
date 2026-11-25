import mysql from 'mysql2/promise';
import { config } from './config.js';

// Pool único por processo. O mysql2 escapa parâmetros com placeholders (?),
// então nenhuma query do backend concatena valor vindo do cliente.
export const pool = mysql.createPool({
  ...config.db,
  supportBigNumbers: true,
  dateStrings: false,
  decimalNumbers: true,
});

// Força a sessão em UTC. Sem isso, no Windows o MySQL usa o fuso do sistema
// (ex.: -03:00) e os DEFAULT CURRENT_TIMESTAMP ficariam 3h diferentes do
// UTC_TIMESTAMP() usado nas comparações de sessão.
pool.on('connection', (conn) => {
  conn.query("SET time_zone = '+00:00'");
});

export async function query(sql, params = []) {
  const [rows] = await pool.execute(sql, params);
  return rows;
}

export async function one(sql, params = []) {
  const rows = await query(sql, params);
  return rows.length ? rows[0] : null;
}

export async function withTransaction(fn) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (err) {
    try { await conn.rollback(); } catch { /* conexão já perdida */ }
    throw err;
  } finally {
    conn.release();
  }
}

export async function ping() {
  const [rows] = await pool.execute(
    "SELECT 1 AS ok, @@session.time_zone AS tz, @@version AS versao",
  );
  return rows[0];
}

export async function closePool() {
  await pool.end();
}
