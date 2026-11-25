-- ============================================================================
-- AjudaMais — preparação do banco no MySQL local (Windows 10)
--
-- Use este arquivo UMA VEZ, no MySQL Workbench ou na linha de comando,
-- logado como root. Ele:
--   1. cria o banco "ajudamais" com utf8mb4;
--   2. cria o usuário "ajudamais" com permissões só neste banco;
--   3. NÃO apaga nem altera nenhum banco existente.
--
-- TROQUE a senha 'TroqueEstaSenha123' antes de executar, e use a mesma
-- senha no arquivo backend\.env (DB_PASSWORD).
-- ============================================================================

CREATE DATABASE IF NOT EXISTS ajudamais
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'ajudamais'@'localhost' IDENTIFIED BY 'TroqueEstaSenha123';
CREATE USER IF NOT EXISTS 'ajudamais'@'127.0.0.1' IDENTIFIED BY 'TroqueEstaSenha123';

GRANT ALL PRIVILEGES ON ajudamais.* TO 'ajudamais'@'localhost';
GRANT ALL PRIVILEGES ON ajudamais.* TO 'ajudamais'@'127.0.0.1';

FLUSH PRIVILEGES;

SELECT 'Banco e usuário prontos. Senha padrão: TroqueEstaSenha123' AS resultado;
