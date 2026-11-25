-- ============================================================================
-- 10. SOLICITAÇÕES / NECESSIDADES
-- ============================================================================
SET @c_s_tit    := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='solicitacoes' AND column_name='titulo');
SET @c_s_desc   := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='solicitacoes' AND column_name='descricao');
SET @c_s_cat    := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='solicitacoes' AND column_name='categoria');
SET @c_s_status := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='solicitacoes' AND column_name='status');
SET @c_s_criado := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='solicitacoes' AND column_name='criado_em');
SET @c_s_user   := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='solicitacoes' AND column_name='usuario_id');

SET @r_tit := IF(@c_s_tit = 1,
  CONCAT('LEFT(COALESCE(NULLIF(TRIM(s.titulo), ""), CONCAT("Solicitacao ", s.', @pk_req, ')), 150)'),
  CONCAT('CONCAT("Solicitacao ", s.', @pk_req, ')'));
SET @r_desc := IF(@c_s_desc = 1, 'NULLIF(TRIM(COALESCE(s.descricao, "")), "")', 'NULL');
SET @r_cat := IF(@c_s_cat = 1, 'COALESCE(s.categoria, "")', '""');
SET @r_status := IF(@c_s_status = 1, 'LOWER(COALESCE(s.status, "aberta"))', '"aberta"');
SET @r_criado := IF(@c_s_criado = 1, 'COALESCE(s.criado_em, CURRENT_TIMESTAMP)', 'CURRENT_TIMESTAMP');
SET @r_user := IF(@c_s_user = 1,
  CONCAT('(SELECT x.id FROM users x WHERE x.legacy_user_id = s.usuario_id)'), 'NULL');
-- Sem solicitante migrado, não há como vincular: a linha é registrada.
SET @r_where := IF(@c_s_user = 1,
  CONCAT('AND (SELECT COUNT(*) FROM users x WHERE x.legacy_user_id = s.usuario_id) = 1'),
  'AND 1 = 0');

SET @sql := CONCAT('INSERT INTO assistance_requests
   (legacy_request_id, requester_user_id, title, description, category_id,
    status, is_public, created_at)
 SELECT
   s.', @pk_req, ',
   ', @r_user, ',
   ', @r_tit, ',
   ', @r_desc, ',
   (SELECT c.id FROM item_categories c
     WHERE LOWER(c.slug) COLLATE utf8mb4_unicode_ci = LOWER(TRIM(', @r_cat, '))
              COLLATE utf8mb4_unicode_ci
        OR LOWER(c.name) COLLATE utf8mb4_unicode_ci = LOWER(TRIM(', @r_cat, '))
              COLLATE utf8mb4_unicode_ci
     LIMIT 1),
   CASE ', @r_status, '
     WHEN "atendida"  THEN "atendida"
     WHEN "cancelada" THEN "cancelada"
     WHEN "expirada"  THEN "expirada"
     ELSE "aberta" END,
   1,
   ', @r_criado, '
 FROM solicitacoes s
 WHERE NOT EXISTS (SELECT 1 FROM assistance_requests x WHERE x.legacy_request_id = s.', @pk_req, ')
   ', @r_where);
SET @sql := IF(@t_req IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Um item por necessidade (o original não tem itens separados).
SET @sql := CONCAT('INSERT INTO request_items
     (request_id, category_id, description, unit_code, quantity_requested)
 SELECT r.id, r.category_id, COALESCE(r.title, "Necessidade importada"), "un", 1
 FROM assistance_requests r
 WHERE r.legacy_request_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM request_items ri WHERE ri.request_id = r.id)');
SET @sql := IF(@t_req IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 11. TERMOS ACEITOS (termoAceito / termoVersao)
-- ============================================================================
SET @c_t_aceito := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='termoAceito');
SET @c_t_versao := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='termoVersao');

SET @sql := CONCAT('INSERT IGNORE INTO terms_versions (version, title, effective_at, is_current)
 SELECT DISTINCT LEFT(TRIM(u.termoVersao), 20),
        CONCAT("Termos de Uso ", TRIM(u.termoVersao)), CURRENT_TIMESTAMP, 0
 FROM usuarios u WHERE NULLIF(TRIM(u.termoVersao), "") IS NOT NULL');
SET @sql := IF(@c_t_versao = 1, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := CONCAT('INSERT INTO terms_acceptances (user_id, terms_version_id, accepted_at)
 SELECT nu.id, tv.id, ', @x_criado, '
 FROM usuarios u
 JOIN users nu ON nu.legacy_user_id = u.', @pk_users, '
 JOIN terms_versions tv ON tv.version = LEFT(TRIM(u.termoVersao), 20)
 WHERE u.termoAceito = 1
   AND NOT EXISTS (SELECT 1 FROM terms_acceptances ta
                    WHERE ta.user_id = nu.id AND ta.terms_version_id = tv.id)');
SET @sql := IF(@c_t_aceito = 1 AND @c_t_versao = 1, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 12. AUDITORIA LEGADA -> audit_logs
-- ============================================================================
SET @c_a_acao := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='auditoria_seguranca' AND column_name='acao');
SET @c_a_data := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='auditoria_seguranca' AND column_name='dataHora');
SET @c_a_ip := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='auditoria_seguranca' AND column_name='enderecoIp');
SET @c_a_det := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='auditoria_seguranca' AND column_name='detalhes');

SET @u_action := IF(@c_a_acao = 1,
  'LEFT(COALESCE(NULLIF(TRIM(a.acao), ""), "legado.desconhecido"), 60)',
  '"legado.desconhecido"');
SET @u_data := IF(@c_a_data = 1, 'COALESCE(a.dataHora, CURRENT_TIMESTAMP)', 'CURRENT_TIMESTAMP');
SET @u_ip := IF(@c_a_ip = 1, 'NULLIF(TRIM(a.enderecoIp), "")', 'NULL');
SET @u_values := IF(@c_a_det = 1,
  'JSON_OBJECT("detalhe", NULLIF(TRIM(a.detalhes), ""))', 'NULL');
SET @u_actor := IF(@col_audit_user IS NOT NULL,
  CONCAT('(SELECT x.id FROM users x WHERE x.legacy_user_id = a.', @col_audit_user, ')'), 'NULL');

SET @sql := CONCAT('INSERT INTO audit_logs
   (legacy_audit_id, actor_id, action, entity_type, entity_id, new_values,
    ip_address, created_at)
 SELECT
   a.', @pk_audit, ',
   ', @u_actor, ',
   ', @u_action, ',
   "legado",
   NULL,
   ', @u_values, ',
   ', @u_ip, ',
   ', @u_data, '
 FROM auditoria_seguranca a
 WHERE NOT EXISTS (SELECT 1 FROM audit_logs l WHERE l.legacy_audit_id = a.', @pk_audit, ')');
SET @sql := IF(@t_audit IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 13. HISTÓRICO, VERSÃO E AUDITORIA DA IMPORTAÇÃO
-- ============================================================================
INSERT INTO donation_status_history (donation_id, from_status, to_status, note)
SELECT d.id, NULL, d.status, 'Status importado da base original'
FROM donations d
WHERE d.legacy_donation_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM donation_status_history h WHERE h.donation_id = d.id);

INSERT INTO schema_migrations (version, description) VALUES
  ('2026.11.02', 'Migration aplicada: importacao da base original'),
  ('2026.11.25', 'Importacao adaptativa: descobre PK/tabelas e nao inventa dados')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT INTO audit_logs (action, entity_type, new_values)
SELECT 'migration.import', 'database',
       JSON_OBJECT(
         'users',        (SELECT COUNT(*) FROM users WHERE legacy_user_id IS NOT NULL),
         'institutions', (SELECT COUNT(*) FROM institutions WHERE legacy_institution_id IS NOT NULL),
         'donations',    (SELECT COUNT(*) FROM donations WHERE legacy_donation_id IS NOT NULL),
         'requests',     (SELECT COUNT(*) FROM assistance_requests WHERE legacy_request_id IS NOT NULL),
         'skipped',      (SELECT COUNT(*) FROM migration_skipped))
WHERE NOT EXISTS (SELECT 1 FROM audit_logs WHERE action = 'migration.import');

-- ============================================================================
-- 14. RELATÓRIO DA MIGRAÇÃO
-- ============================================================================
SELECT
  (SELECT COUNT(*) FROM users WHERE legacy_user_id IS NOT NULL)                 AS usuarios_migrados,
  (SELECT COUNT(*) FROM institutions WHERE legacy_institution_id IS NOT NULL)   AS instituicoes_migradas,
  (SELECT COUNT(*) FROM institution_members)                                    AS vinculos_criados,
  (SELECT COUNT(*) FROM addresses)                                              AS enderecos_migrados,
  (SELECT COUNT(*) FROM donations WHERE legacy_donation_id IS NOT NULL)         AS doacoes_migradas,
  (SELECT COUNT(*) FROM donation_items)                                         AS itens_doados,
  (SELECT COUNT(*) FROM assistance_requests WHERE legacy_request_id IS NOT NULL) AS solicitacoes_migradas,
  (SELECT COUNT(*) FROM terms_acceptances)                                      AS aceites_termos,
  (SELECT COUNT(*) FROM audit_logs WHERE entity_type = 'legado')                AS auditorias_importadas,
  (SELECT COUNT(*) FROM migration_skipped)                                      AS linhas_nao_aproveitadas;

SELECT legacy_table, reason, COUNT(*) AS total
FROM migration_skipped
GROUP BY legacy_table, reason
ORDER BY legacy_table, reason;
