-- ============================================================================
-- 2. RASTREIO DA ORIGEM LEGADA
--    Guarda o id original para a cópia ser repetível e auditável.
-- ============================================================================
SET @db := DATABASE();

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'users' AND column_name = 'legacy_user_id') = 0,
  'ALTER TABLE users ADD COLUMN legacy_user_id INT UNSIGNED NULL AFTER id, ADD UNIQUE KEY uq_users_legacy (legacy_user_id)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'institutions' AND column_name = 'legacy_institution_id') = 0,
  'ALTER TABLE institutions ADD COLUMN legacy_institution_id INT UNSIGNED NULL AFTER id, ADD UNIQUE KEY uq_institutions_legacy (legacy_institution_id)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'donations' AND column_name = 'legacy_donation_id') = 0,
  'ALTER TABLE donations ADD COLUMN legacy_donation_id INT UNSIGNED NULL AFTER id, ADD UNIQUE KEY uq_donations_legacy (legacy_donation_id)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'assistance_requests' AND column_name = 'legacy_request_id') = 0,
  'ALTER TABLE assistance_requests ADD COLUMN legacy_request_id INT UNSIGNED NULL AFTER id, ADD UNIQUE KEY uq_requests_legacy (legacy_request_id)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Auditoria legada: guarda o id original para não duplicar ao reexecutar.
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'audit_logs' AND column_name = 'legacy_audit_id') = 0,
  'ALTER TABLE audit_logs ADD COLUMN legacy_audit_id INT UNSIGNED NULL, ADD UNIQUE KEY uq_audit_legacy (legacy_audit_id)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backup do campo "tipo" (perfil) dos usuários originais, quando existir.
CREATE TABLE IF NOT EXISTS role_legacy_backup (
  user_legacy_id INT UNSIGNED NOT NULL,
  legacy_type    VARCHAR(50)  NULL,
  copied_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_legacy_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Registro de linhas que não puderam ser aproveitadas (não inventa dados).
CREATE TABLE IF NOT EXISTS migration_skipped (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  legacy_table VARCHAR(64)    NOT NULL,
  legacy_id    INT UNSIGNED   NULL,
  reason       VARCHAR(255)   NOT NULL,
  noted_at     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_migration_skipped (legacy_table, legacy_id),
  KEY idx_migration_skipped_table (legacy_table)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 3. DESCOBERTA DA ESTRUTURA ORIGINAL
--    Nada de presumir nomes. O dump real do grupo usa:
--      usuarios( PK idConta ), contatos, enderecos, orgaos_doacao,
--      doacoes_transicoes, auditoria_seguranca
--    mas aceitamos também o formato "português" com id e tabelas
--      instituicoes / doacoes / solicitacoes.
-- ============================================================================
-- 3.1 Nome da tabela de usuários: só existe um nome possível.
SET @t_users := IF((SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = @db AND table_name = 'usuarios') = 1, 'usuarios', NULL);

-- 3.2 Chave primária real de cada tabela legada (id, idConta, idOrgao...).
SET @pk_users := (SELECT column_name FROM information_schema.key_column_usage
  WHERE table_schema = @db AND table_name = 'usuarios'
    AND constraint_name = 'PRIMARY' LIMIT 1);

-- 3.3 Tabela de instituições: instituicoes ou orgaos_doacao.
SET @t_inst := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = @db AND table_name = 'instituicoes') = 1 THEN 'instituicoes'
  WHEN (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = @db AND table_name = 'orgaos_doacao') = 1 THEN 'orgaos_doacao'
  ELSE NULL END;
SET @pk_inst := (SELECT column_name FROM information_schema.key_column_usage
  WHERE table_schema = @db AND table_name = @t_inst
    AND constraint_name = 'PRIMARY' LIMIT 1);

-- 3.4 Doações: tabela "doacoes" (modelo por item) ou "doacoes_transicoes".
SET @t_don := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = @db AND table_name = 'doacoes') = 1 THEN 'doacoes'
  ELSE NULL END;
SET @pk_don := (SELECT column_name FROM information_schema.key_column_usage
  WHERE table_schema = @db AND table_name = @t_don
    AND constraint_name = 'PRIMARY' LIMIT 1);

SET @t_trans := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = @db AND table_name = 'doacoes_transicoes') = 1 THEN 'doacoes_transicoes'
  ELSE NULL END;
SET @pk_trans := (SELECT column_name FROM information_schema.key_column_usage
  WHERE table_schema = @db AND table_name = @t_trans
    AND constraint_name = 'PRIMARY' LIMIT 1);

-- 3.5 Solicitações / necessidades.
SET @t_req := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = @db AND table_name = 'solicitacoes') = 1 THEN 'solicitacoes'
  ELSE NULL END;
SET @pk_req := (SELECT column_name FROM information_schema.key_column_usage
  WHERE table_schema = @db AND table_name = @t_req
    AND constraint_name = 'PRIMARY' LIMIT 1);

-- 3.6 Contatos (telefone) e endereços.
SET @t_contato := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = @db AND table_name = 'contatos') = 1 THEN 'contatos'
  ELSE NULL END;
SET @pk_contato := (SELECT column_name FROM information_schema.key_column_usage
  WHERE table_schema = @db AND table_name = @t_contato
    AND constraint_name = 'PRIMARY' LIMIT 1);

SET @t_end := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = @db AND table_name = 'enderecos') = 1 THEN 'enderecos'
  ELSE NULL END;
SET @pk_end := (SELECT column_name FROM information_schema.key_column_usage
  WHERE table_schema = @db AND table_name = @t_end
    AND constraint_name = 'PRIMARY' LIMIT 1);

-- 3.7 Auditoria legada.
SET @t_audit := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = @db AND table_name = 'auditoria_seguranca') = 1 THEN 'auditoria_seguranca'
  ELSE NULL END;
SET @pk_audit := (SELECT column_name FROM information_schema.key_column_usage
  WHERE table_schema = @db AND table_name = @t_audit
    AND constraint_name = 'PRIMARY' LIMIT 1);

-- 3.8 FK que liga cada tabela filha a usuários.
SET @fk_users_col := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = @db AND table_name = 'usuarios' AND column_name = 'idConta') = 1 THEN 'idConta'
  ELSE 'id' END;

-- 3.9 Coluna de vínculo com usuário nas tabelas filhas.
SET @col_contato_user := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = @db AND table_name = 'contatos' AND column_name = 'idConta') = 1 THEN 'idConta'
  WHEN (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = @db AND table_name = 'contatos' AND column_name = 'usuario_id') = 1 THEN 'usuario_id'
  ELSE NULL END;

SET @col_end_user := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = @db AND table_name = 'enderecos' AND column_name = 'idConta') = 1 THEN 'idConta'
  WHEN (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = @db AND table_name = 'enderecos' AND column_name = 'usuario_id') = 1 THEN 'usuario_id'
  ELSE NULL END;

SET @col_audit_user := CASE
  WHEN (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = @db AND table_name = 'auditoria_seguranca' AND column_name = 'idConta') = 1 THEN 'idConta'
  WHEN (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = @db AND table_name = 'auditoria_seguranca' AND column_name = 'usuario_id') = 1 THEN 'usuario_id'
  ELSE NULL END;
