// Verificação rápida antes de subir a API: confere o .env e a conexão com o
// MySQL, mostrando uma mensagem clara (em português) quando algo está errado.
// Roda automaticamente com "npm start" e "npm run dev".
import { config } from './config.js';
import { ping, closePool } from './db.js';

const dicas = {
  ECONNREFUSED: 'O MySQL não respondeu. Verifique se o serviço "MySQL80" está em execução (services.msc) e se DB_PORT está correto.',
  ETIMEDOUT: 'Tempo esgotado ao conectar. Confira DB_HOST e se o firewall não está bloqueando a porta do MySQL.',
  ENOTFOUND: 'Endereço do banco não encontrado. Confira DB_HOST (normalmente 127.0.0.1).',
  ER_ACCESS_DENIED_ERROR: 'Usuário ou senha do banco incorretos. Confira DB_USER e DB_PASSWORD no arquivo backend\\.env.',
  ER_BAD_DB_ERROR: 'O banco informado não existe. Execute database\\00-preparar-banco.sql e depois database\\01-schema.sql.',
  ER_NOT_SUPPORTED_AUTH_MODE: 'O usuário do banco usa um método de senha não suportado. Recrie o usuário com mysql_native_password.',
};

try {
  const info = await ping();
  console.log(`Banco conectado: ${config.db.user}@${config.db.host}:${config.db.port}/${config.db.database}`);
  console.log(`MySQL/MariaDB ${info.versao} | fuso da sessão: ${info.tz}`);
  await closePool();
} catch (err) {
  console.error('\n[ERRO] Não foi possível conectar ao banco de dados.');
  console.error(`Motivo: ${err.code ?? ''} ${err.message}`);
  if (dicas[err.code]) console.error(`Dica: ${dicas[err.code]}`);
  console.error('\nConfiguração em uso (senha oculta):');
  console.error(`  DB_HOST=${config.db.host}`);
  console.error(`  DB_PORT=${config.db.port}`);
  console.error(`  DB_USER=${config.db.user}`);
  console.error(`  DB_NAME=${config.db.database}`);
  console.error('\nSe o arquivo backend\\.env ainda não existe, copie de .env.example.');
  try { await closePool(); } catch { /* ignora */ }
  process.exit(1);
}
