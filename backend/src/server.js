import { config } from './config.js';
import { closePool } from './db.js';
import app from './app.js';

const server = app.listen(config.port, () => {
  console.log(`AjudaMais API em http://localhost:${config.port} (banco: ${config.db.database})`);
});

async function shutdown(signal) {
  console.log(`\n${signal} recebido, encerrando...`);
  server.close(async () => {
    await closePool();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

