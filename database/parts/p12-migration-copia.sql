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

-- Backup do campo "tipo" (perfil) dos usuários originais, quando existir.
CREATE TABLE IF NOT EXISTS role_legacy_backup (
  user_legacy_id INT UNSIGNED NOT NULL,
  legacy_type    VARCHAR(50)  NULL,
  copied_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_legacy_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @has_usuarios  := (SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = @db AND table_name = 'usuarios');
SET @has_instituicoes := (SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = @db AND table_name = 'instituicoes');
SET @has_doacoes   := (SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = @db AND table_name = 'doacoes');
SET @has_solicitacoes := (SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = @db AND table_name = 'solicitacoes');

SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'usuarios' AND column_name = 'tipo');
SET @sql := IF(@has_usuarios = 1 AND @col = 1,
  'INSERT INTO role_legacy_backup (user_legacy_id, legacy_type)
     SELECT u.id, u.tipo FROM usuarios u
      WHERE NOT EXISTS (SELECT 1 FROM role_legacy_backup b WHERE b.user_legacy_id = u.id)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 3. USUÁRIOS
--    Normaliza CPF (só dígitos) e telefone (E.164). A senha original é
--    preservada em password_hash; contas entram como "pendente".
--    Linhas sem CPF de 11 dígitos não são copiadas: ficam nas tabelas
--    originais para correção manual (evita perder a origem).
-- ============================================================================
--    Apenas colunas que existirem na tabela original são usadas: colunas
--    ausentes recebem um valor padrão, e a migration não falha.
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'usuarios' AND column_name = 'telefone');
SET @tel_expr := IF(@col = 1, 'REGEXP_REPLACE(COALESCE(u.telefone, ""), "[^0-9]", "")', '""');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'usuarios' AND column_name = 'senha');
SET @senha_expr := IF(@col = 1, 'NULLIF(u.senha, "")', 'NULL');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'usuarios' AND column_name = 'criado_em');
SET @criado_expr := IF(@col = 1, 'COALESCE(u.criado_em, CURRENT_TIMESTAMP)', 'CURRENT_TIMESTAMP');

SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'usuarios' AND column_name = 'nome');
SET @nome_u := IF(@col = 1,
  'LEFT(COALESCE(NULLIF(TRIM(u.nome), ""), CONCAT("Usuario ", u.id)), 150)',
  'CONCAT("Usuario ", u.id)');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'usuarios' AND column_name = 'email');
SET @email_u := IF(@col = 1,
  'LOWER(TRIM(u.email))',
  'CONCAT("usuario", u.id, "@pendente.ajudamais")');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'usuarios' AND column_name = 'cpf');
-- CONVERT(... USING utf8mb4): no MySQL, REGEXP_REPLACE devolve string binária,
-- e strings binárias não aceitam COLLATE de utf8mb4.
SET @cpf_u := IF(@col = 1,
  'CONVERT(REGEXP_REPLACE(COALESCE(u.cpf, ""), "[^0-9]", "") USING utf8mb4)',
  '""');
-- Sem coluna de CPF não há como deduplicar com segurança: nesse caso só
-- migra quando existir a coluna; caso contrário, nenhuma linha é copiada.
SET @cpf_len := IF(@col = 1,
  'CHAR_LENGTH(CONVERT(REGEXP_REPLACE(COALESCE(u.cpf, ""), "[^0-9]", "") USING utf8mb4)) = 11',
  '1 = 0');

SET @sql := IF(@has_usuarios = 1,
CONCAT('INSERT INTO users
   (legacy_user_id, full_name, email, cpf, phone_e164, password_hash, status, created_at)
 SELECT
   u.id,
   ', @nome_u, ',
   ', @email_u, ',
   ', @cpf_u, ',
   CASE
     WHEN ', @tel_expr, ' = "" THEN NULL
     WHEN CHAR_LENGTH(', @tel_expr, ') = 11
       THEN CONCAT("+55", ', @tel_expr, ')
     WHEN CHAR_LENGTH(', @tel_expr, ') = 10
       THEN CONCAT("+55", LEFT(', @tel_expr, ', 2), "9", SUBSTRING(', @tel_expr, ', 3))
     ELSE NULL
   END,
   COALESCE(', @senha_expr, ', "MIGRACAO_PENDENTE_RESET"),
   "pendente",
   ', @criado_expr, '
 FROM usuarios u
 WHERE ', @cpf_len, '
   AND NOT EXISTS (SELECT 1 FROM users x
                    WHERE x.legacy_user_id = u.id
                       OR x.cpf = ', @cpf_u, ' COLLATE utf8mb4_unicode_ci
                       OR x.email = ', @email_u, ' COLLATE utf8mb4_unicode_ci)'),
'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Papéis a partir do backup do campo "tipo"; todo migrado vira doador.
INSERT IGNORE INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM role_legacy_backup b
JOIN users u ON u.legacy_user_id = b.user_legacy_id
JOIN roles r ON r.code = CASE
    WHEN UPPER(b.legacy_type) LIKE 'INSTITUI%'  THEN 'instituicao'
    WHEN UPPER(b.legacy_type) LIKE 'BENEFICI%'  THEN 'beneficiario'
    WHEN UPPER(b.legacy_type) = 'MODERADOR'     THEN 'moderador'
    WHEN UPPER(b.legacy_type) = 'ADMIN'         THEN 'admin'
    WHEN UPPER(b.legacy_type) = 'VOLUNTARIO'    THEN 'voluntario'
    ELSE 'doador'
  END;

INSERT IGNORE INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.code = 'doador'
WHERE u.legacy_user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id);

-- ============================================================================
-- 4. INSTITUIÇÕES (+ endereço e contato)
-- ============================================================================
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'instituicoes' AND column_name = 'telefone');
SET @tel_i := IF(@col = 1, 'REGEXP_REPLACE(COALESCE(i.telefone, ""), "[^0-9]", "")', '""');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'instituicoes' AND column_name = 'email');
SET @email_i := IF(@col = 1,
  'COALESCE(NULLIF(LOWER(TRIM(i.email)), ""), CONCAT("instituicao", i.id, "@pendente.ajudamais"))',
  'CONCAT("instituicao", i.id, "@pendente.ajudamais")');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'instituicoes' AND column_name = 'cnpj');
SET @cnpj_i := IF(@col = 1, 'NULLIF(CONVERT(REGEXP_REPLACE(COALESCE(i.cnpj, ""), "[^0-9]", "") USING utf8mb4), "")', 'NULL');
-- A cláusula de deduplicação por CNPJ só existe quando a coluna existe:
-- MySQL recusa aplicar COLLATE a um literal NULL.
SET @cnpj_dup := IF(@col = 1,
  ' OR (x.cnpj IS NOT NULL AND x.cnpj = NULLIF(CONVERT(REGEXP_REPLACE(COALESCE(i.cnpj, ""), "[^0-9]", "") USING utf8mb4), "") COLLATE utf8mb4_unicode_ci)',
  '');

SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'instituicoes' AND column_name = 'nome');
SET @nome_i := IF(@col = 1,
  'LEFT(COALESCE(NULLIF(TRIM(i.nome), ""), CONCAT("Instituicao ", i.id)), 180)',
  'CONCAT("Instituicao ", i.id)');

SET @sql := IF(@has_instituicoes = 1,
CONCAT('INSERT INTO institutions
   (legacy_institution_id, legal_name, cnpj, email, phone_e164, status, created_at)
 SELECT
   i.id,
   ', @nome_i, ',
   ', @cnpj_i, ',
   ', @email_i, ',
   CASE
     WHEN ', @tel_i, ' = "" THEN NULL
     WHEN CHAR_LENGTH(', @tel_i, ') >= 10
       THEN CONCAT("+55", ', @tel_i, ')
     ELSE NULL
   END,
   "pendente",
   CURRENT_TIMESTAMP
 FROM instituicoes i
 WHERE NOT EXISTS (SELECT 1 FROM institutions x
                    WHERE x.legacy_institution_id = i.id', @cnpj_dup, ')'),
'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Endereço: usa cidade como gatilho; rua e UF também são verificadas.
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'instituicoes' AND column_name = 'cidade');
SET @has_cidade := @col;
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'instituicoes' AND column_name = 'endereco');
SET @rua_i := IF(@col = 1, 'COALESCE(NULLIF(TRIM(i_velho.endereco), ""), "Nao informado")', '"Nao informado"');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'instituicoes' AND column_name = 'estado');
SET @uf_i := IF(@col = 1,
  '(SELECT s.code FROM states s WHERE s.code = CONVERT(UPPER(TRIM(i_velho.estado)) USING utf8mb4) COLLATE utf8mb4_unicode_ci)',
  'NULL');

SET @sql := IF(@has_instituicoes = 1 AND @has_cidade = 1,
CONCAT('INSERT INTO addresses (institution_id, address_type, street, city, state_code, is_primary)
 SELECT i_novo.id, "comercial",
        ', @rua_i, ',
        COALESCE(NULLIF(TRIM(i_velho.cidade), ""), "Nao informado"),
        ', @uf_i, ',
        1
 FROM instituicoes i_velho
 JOIN institutions i_novo ON i_novo.legacy_institution_id = i_velho.id
 WHERE NOT EXISTS (SELECT 1 FROM addresses a WHERE a.institution_id = i_novo.id)'),
'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 5. DOAÇÕES + ITENS
--    Cada doação legada vira uma doação com um item. Doações sem usuário
--    vinculado entram como anônimas (regra do sistema).
-- ============================================================================
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'observacao');
SET @msg1 := IF(@col = 1, 'NULLIF(TRIM(d.observacao), "")', 'NULL');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'mensagem');
SET @msg2 := IF(@col = 1, 'NULLIF(TRIM(d.mensagem), "")', 'NULL');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'status');
SET @status_expr := IF(@col = 1, 'LOWER(COALESCE(d.status, "pendente"))', '"pendente"');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'criado_em');
SET @criado_expr := IF(@col = 1, 'COALESCE(d.criado_em, CURRENT_TIMESTAMP)', 'CURRENT_TIMESTAMP');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'instituicao_id');
SET @inst_expr := IF(@col = 1,
  '(SELECT i.id FROM institutions i WHERE i.legacy_institution_id = d.instituicao_id)', 'NULL');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'usuario_id');
SET @user_expr := IF(@col = 1,
  '(SELECT u.id FROM users u WHERE u.legacy_user_id = d.usuario_id)', 'NULL');
SET @anon_expr := IF(@col = 1,
  'CASE WHEN (SELECT COUNT(*) FROM users u WHERE u.legacy_user_id = d.usuario_id) = 0 THEN 1 ELSE 0 END',
  '1');

SET @sql := IF(@has_doacoes = 1,
CONCAT('INSERT INTO donations
   (legacy_donation_id, code, donor_user_id, is_anonymous, institution_id,
    donation_type, status, message, created_at)
 SELECT
   d.id,
   CONCAT("LEG-", d.id),
   ', @user_expr, ',
   ', @anon_expr, ',
   ', @inst_expr, ',
   "itens",
   CASE ', @status_expr, '
     WHEN "confirmada" THEN "confirmada"
     WHEN "recebida"   THEN "recebida"
     WHEN "cancelada"  THEN "cancelada"
     WHEN "recusada"   THEN "recusada"
     ELSE "pendente"
   END,
   COALESCE(', @msg1, ', ', @msg2, '),
   ', @criado_expr, '
 FROM doacoes d
 WHERE NOT EXISTS (SELECT 1 FROM donations x WHERE x.legacy_donation_id = d.id)'),
'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'categoria');
SET @cat_expr := IF(@col = 1, 'COALESCE(d_velho.categoria, "")', '""');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'descricao');
SET @desc_expr := IF(@col = 1,
  'LEFT(COALESCE(NULLIF(TRIM(d_velho.descricao), ""), "Item doado"), 200)',
  'CONCAT("Item da doacao ", d_velho.id)');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'doacoes' AND column_name = 'quantidade');
SET @qtd_expr := IF(@col = 1, 'GREATEST(COALESCE(d_velho.quantidade, 1), 1)', '1');
SET @sql := IF(@has_doacoes = 1,
CONCAT('INSERT INTO donation_items
   (donation_id, category_id, description, unit_code, quantity, item_condition)
 SELECT d_novo.id,
        (SELECT c.id FROM item_categories c
          WHERE c.slug = LOWER(TRIM(', @cat_expr, ')) COLLATE utf8mb4_unicode_ci
             OR LOWER(c.name) COLLATE utf8mb4_unicode_ci = LOWER(TRIM(', @cat_expr, ')) COLLATE utf8mb4_unicode_ci
          LIMIT 1),
        ', @desc_expr, ',
        "un",
        ', @qtd_expr, ',
        "usado"
 FROM doacoes d_velho
 JOIN donations d_novo ON d_novo.legacy_donation_id = d_velho.id
 WHERE NOT EXISTS (SELECT 1 FROM donation_items di WHERE di.donation_id = d_novo.id)'),
'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 6. SOLICITAÇÕES (necessidades)
--    Sem instituição no original, a solicitação fica vinculada ao usuário.
--    Cria um item com quantidade 1 para a tela de doação já funcionar.
-- ============================================================================
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'solicitacoes' AND column_name = 'titulo');
SET @tit_expr := IF(@col = 1,
  'LEFT(COALESCE(NULLIF(TRIM(s.titulo), ""), CONCAT("Solicitacao ", s.id)), 150)',
  'CONCAT("Solicitacao ", s.id)');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'solicitacoes' AND column_name = 'descricao');
SET @desc_s := IF(@col = 1, 'NULLIF(TRIM(COALESCE(s.descricao, "")), "")', 'NULL');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'solicitacoes' AND column_name = 'categoria');
SET @cat_s := IF(@col = 1, 'COALESCE(s.categoria, "")', '""');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'solicitacoes' AND column_name = 'status');
SET @status_s := IF(@col = 1, 'LOWER(COALESCE(s.status, "aberta"))', '"aberta"');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'solicitacoes' AND column_name = 'criado_em');
SET @criado_s := IF(@col = 1, 'COALESCE(s.criado_em, CURRENT_TIMESTAMP)', 'CURRENT_TIMESTAMP');
SET @col := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'solicitacoes' AND column_name = 'usuario_id');
SET @user_s := IF(@col = 1,
  '(SELECT u.id FROM users u WHERE u.legacy_user_id = s.usuario_id)',
  'NULL');
SET @where_s := IF(@col = 1,
  'AND (SELECT COUNT(*) FROM users u WHERE u.legacy_user_id = s.usuario_id) = 1',
  'AND 1 = 0');

SET @sql := IF(@has_solicitacoes = 1,
CONCAT('INSERT INTO assistance_requests
   (legacy_request_id, requester_user_id, title, description, category_id,
    status, is_public, created_at)
 SELECT
   s.id,
   ', @user_s, ',
   ', @tit_expr, ',
   ', @desc_s, ',
   (SELECT c.id FROM item_categories c
     WHERE LOWER(c.slug) COLLATE utf8mb4_unicode_ci = LOWER(TRIM(', @cat_s, ')) COLLATE utf8mb4_unicode_ci
        OR LOWER(c.name) COLLATE utf8mb4_unicode_ci = LOWER(TRIM(', @cat_s, ')) COLLATE utf8mb4_unicode_ci
     LIMIT 1),
   CASE ', @status_s, '
     WHEN "atendida"  THEN "atendida"
     WHEN "cancelada" THEN "cancelada"
     WHEN "expirada"  THEN "expirada"
     ELSE "aberta"
   END,
   1,
   ', @criado_s, '
 FROM solicitacoes s
 WHERE NOT EXISTS (SELECT 1 FROM assistance_requests x WHERE x.legacy_request_id = s.id)
   ', @where_s),
'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

INSERT INTO request_items (request_id, category_id, description, unit_code, quantity_requested)
SELECT r.id, r.category_id,
       LEFT(COALESCE(NULLIF(TRIM(r.title), ''), 'Item solicitado'), 200),
       'un', 1
FROM assistance_requests r
WHERE r.legacy_request_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM request_items ri WHERE ri.request_id = r.id);

-- ============================================================================
-- 7. HISTÓRICO, VERSÃO E AUDITORIA DA IMPORTAÇÃO
-- ============================================================================
INSERT INTO donation_status_history (donation_id, from_status, to_status, note)
SELECT d.id, NULL, d.status, 'Status importado da base original'
FROM donations d
WHERE d.legacy_donation_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM donation_status_history h WHERE h.donation_id = d.id);

INSERT INTO schema_migrations (version, description) VALUES
  ('2026.11.02', 'Migration aplicada: importacao da base original')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT INTO audit_logs (action, entity_type, new_values)
SELECT 'migration.import', 'database',
       JSON_OBJECT(
         'users',        (SELECT COUNT(*) FROM users WHERE legacy_user_id IS NOT NULL),
         'institutions', (SELECT COUNT(*) FROM institutions WHERE legacy_institution_id IS NOT NULL),
         'donations',    (SELECT COUNT(*) FROM donations WHERE legacy_donation_id IS NOT NULL),
         'requests',     (SELECT COUNT(*) FROM assistance_requests WHERE legacy_request_id IS NOT NULL)
       )
WHERE NOT EXISTS (SELECT 1 FROM audit_logs WHERE action = 'migration.import');

-- ============================================================================
-- 8. RELATÓRIO DA MIGRAÇÃO
-- ============================================================================
SELECT
  (SELECT COUNT(*) FROM schema_migrations)                       AS versoes_registradas,
  (SELECT COUNT(*) FROM users WHERE legacy_user_id IS NOT NULL)  AS usuarios_migrados,
  (SELECT COUNT(*) FROM institutions WHERE legacy_institution_id IS NOT NULL) AS instituicoes_migradas,
  (SELECT COUNT(*) FROM donations WHERE legacy_donation_id IS NOT NULL)      AS doacoes_migradas,
  (SELECT COUNT(*) FROM assistance_requests WHERE legacy_request_id IS NOT NULL) AS solicitacoes_migradas;
