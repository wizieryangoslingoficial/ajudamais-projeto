-- ============================================================================
-- 5. USUÁRIOS
--    Padrão seguro: cada CONCAT fecha sozinho, e só depois o IF decide.
--    Origem: usuarios(idConta, nome, cpf, email, senha, statusConta,
--    criadoEm, termoAceito, termoVersao, identificadorGov) + contatos.telefone
-- ============================================================================

-- 5.1 Colunas disponíveis na origem.
SET @c_nome  := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='nome');
SET @c_email := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='email');
SET @c_senha := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='senha');
SET @c_criado := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='criadoEm');
SET @c_criado2 := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='criado_em');
SET @c_status := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='statusConta');
SET @c_gov := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='identificadorGov');

-- 5.2 Expressões de cada campo (cada uma é uma expressão única e fechada).
SET @x_nome := IF(@c_nome = 1,
  CONCAT('LEFT(COALESCE(NULLIF(TRIM(u.nome), ""), CONCAT("Usuario ", u.', @pk_users, ')), 150)'),
  CONCAT('CONCAT("Usuario ", u.', @pk_users, ')'));
SET @x_senha := IF(@c_senha = 1, 'NULLIF(u.senha, "")', 'NULL');
SET @x_gov := IF(@c_gov = 1, 'NULLIF(TRIM(u.identificadorGov), "")', 'NULL');
SET @x_criado := CASE
  WHEN @c_criado = 1  THEN 'COALESCE(u.criadoEm, CURRENT_DATE)'
  WHEN @c_criado2 = 1 THEN 'COALESCE(u.criado_em, CURRENT_TIMESTAMP)'
  ELSE 'CURRENT_TIMESTAMP' END;
SET @x_status := IF(@c_status = 1,
  'CASE WHEN u.statusConta = 1 THEN "ativo" ELSE "pendente" END', '"pendente"');
SET @x_algo := IF(@c_senha = 1,
  'CASE WHEN u.senha IS NULL OR u.senha = "" THEN "desconhecido"
        WHEN u.senha REGEXP "^\\$2[aby]\\$" THEN "bcrypt"
        WHEN u.senha REGEXP "^\\$argon2" THEN "argon2"
        ELSE "legado_texto" END',
  '"desconhecido"');

-- 5.3 CPF: só dígitos, 11 caracteres.
SET @x_cpf := IF((SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema=@db AND table_name='usuarios' AND column_name='cpf') = 1,
  'CONVERT(REGEXP_REPLACE(COALESCE(u.cpf, ""), "[^0-9]", "") USING utf8mb4)', '""');
SET @x_cpf_len := IF((SELECT COUNT(*) FROM information_schema.columns
      WHERE table_schema=@db AND table_name='usuarios' AND column_name='cpf') = 1,
  'CHAR_LENGTH(CONVERT(REGEXP_REPLACE(COALESCE(u.cpf, ""), "[^0-9]", "") USING utf8mb4)) = 11',
  '1 = 0');

-- 5.4 Email: usa o original se válido e livre; senão gera um provisório.
SET @x_email := IF(@c_email = 1,
  CONCAT('COALESCE(
      (SELECT CASE
         WHEN NULLIF(TRIM(u.email), "") IS NOT NULL
          AND TRIM(u.email) LIKE "%_@_%._%"
          AND NOT EXISTS (SELECT 1 FROM users x WHERE x.email = LOWER(TRIM(u.email)) COLLATE utf8mb4_unicode_ci)
         THEN LOWER(TRIM(u.email)) END),
      CONCAT("legado", u.', @pk_users, ', "@importado.ajudamais.invalid"))'),
  CONCAT('CONCAT("legado", u.', @pk_users, ', "@importado.ajudamais.invalid")'));

-- 5.5 Telefone: contatos.telefone (quando existir) ou usuarios.telefone.
SET @x_tel_raw := IF(@t_contato IS NOT NULL AND @col_contato_user IS NOT NULL,
  CONCAT('(SELECT CONVERT(REGEXP_REPLACE(COALESCE(c.telefone, ""), "[^0-9]", "") USING utf8mb4)
             FROM contatos c WHERE c.', @col_contato_user, ' = u.', @pk_users, '
            ORDER BY c.', @pk_contato, ' LIMIT 1)'),
  IF((SELECT COUNT(*) FROM information_schema.columns
       WHERE table_schema=@db AND table_name='usuarios' AND column_name='telefone') = 1,
    'CONVERT(REGEXP_REPLACE(COALESCE(u.telefone, ""), "[^0-9]", "") USING utf8mb4)',
    '""'));

-- ============================================================================
-- 5.6 Cópia dos usuários
-- ============================================================================
SET @sql := CONCAT('INSERT INTO users
   (legacy_user_id, full_name, email, cpf, phone_e164, password_hash, password_algo,
    status, govbr_sub, created_at)
 SELECT
   u.', @pk_users, ',
   ', @x_nome, ',
   ', @x_email, ',
   ', @x_cpf, ',
   CASE
     WHEN ', @x_tel_raw, ' = "" THEN NULL
     WHEN CHAR_LENGTH(', @x_tel_raw, ') = 13 AND LEFT(', @x_tel_raw, ', 2) = "55"
       THEN CONCAT("+", ', @x_tel_raw, ')
     WHEN CHAR_LENGTH(', @x_tel_raw, ') = 12 AND LEFT(', @x_tel_raw, ', 2) = "55"
       THEN CONCAT("+", ', @x_tel_raw, ')
     WHEN CHAR_LENGTH(', @x_tel_raw, ') = 11 THEN CONCAT("+55", ', @x_tel_raw, ')
     WHEN CHAR_LENGTH(', @x_tel_raw, ') = 10 THEN CONCAT("+55", ', @x_tel_raw, ')
     ELSE NULL END,
   COALESCE(', @x_senha, ', "SENHA_NAO_IMPORTADA"),
   ', @x_algo, ',
   ', @x_status, ',
   ', @x_gov, ',
   ', @x_criado, '
 FROM usuarios u
 WHERE ', @x_cpf_len, '
   AND NOT EXISTS (SELECT 1 FROM users x WHERE x.legacy_user_id = u.', @pk_users, ')');
SET @sql := IF(@t_users IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 5.7 Usuários sem CPF válido: registrados para conferência (nada é inventado).
SET @sql := CONCAT('INSERT IGNORE INTO migration_skipped (legacy_table, legacy_id, reason)
 SELECT "usuarios", u.', @pk_users, ',
        CONCAT("CPF inválido ou ausente: ", IFNULL(TRIM(u.cpf), "vazio"))
 FROM usuarios u
 WHERE NOT (', @x_cpf_len, ')');
SET @sql := IF(@t_users IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 5.7b Perfis legados: guarda o campo "tipo" original e aplica o papel
--      correspondente. Roda antes do papel padrão para que quem era
--      instituição não receba também o papel de doador.
SET @c_tipo := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='usuarios' AND column_name='tipo');

SET @sql := CONCAT('INSERT INTO role_legacy_backup (user_legacy_id, legacy_type)
 SELECT u.', @pk_users, ', LEFT(TRIM(u.tipo), 50)
 FROM usuarios u
 WHERE NULLIF(TRIM(u.tipo), "") IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM role_legacy_backup b
                    WHERE b.user_legacy_id = u.', @pk_users, ')');
SET @sql := IF(@t_users IS NOT NULL AND @c_tipo = 1, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

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
    ELSE 'doador' END;

-- 5.8 Papel padrão: quem ainda não tem papel entra como doador.
INSERT IGNORE INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.code = 'doador'
WHERE u.legacy_user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id);
