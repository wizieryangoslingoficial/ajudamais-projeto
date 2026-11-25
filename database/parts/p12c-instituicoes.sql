-- ============================================================================
-- 6. INSTITUIÇÕES
--    Origem A (dump real): orgaos_doacao(idOrgao, idConta, descricao, categoria)
--    Origem B (formato alternativo): instituicoes(id, nome, cnpj, email...)
--    Padrão seguro: CONCAT fecha sozinho; IF só escolhe entre dois textos.
-- ============================================================================

SET @c_o_desc  := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='orgaos_doacao' AND column_name='descricao');
SET @c_o_cat   := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='orgaos_doacao' AND column_name='categoria');
SET @c_o_conta := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='orgaos_doacao' AND column_name='idConta');

-- 6.1 Nome / descrição / e-mail de cada instituição vinda de orgaos_doacao.
--     O representante vem de usuarios via idConta, por isso o LEFT JOIN abaixo.
SET @y_from := IF(@c_o_conta = 1,
  CONCAT(' FROM orgaos_doacao o LEFT JOIN usuarios u ON u.', @pk_users, ' = o.idConta'),
  ' FROM orgaos_doacao o');

SET @y_nome := IF(@c_o_conta = 1 AND @c_nome = 1,
  CONCAT('COALESCE(NULLIF(LEFT(TRIM(u.nome), 180), ""), CONCAT("Orgao ", o.', @pk_inst, '))'),
  CONCAT('CONCAT("Orgao ", o.', @pk_inst, ')'));

SET @y_desc := CASE
  WHEN @c_o_desc = 1 THEN 'NULLIF(TRIM(o.descricao), "")'
  WHEN @c_o_cat  = 1 THEN 'NULLIF(TRIM(o.categoria), "")'
  ELSE 'NULL' END;

SET @y_email := IF(@c_o_conta = 1,
  CONCAT('COALESCE(
    (SELECT CASE WHEN NULLIF(TRIM(u2.email), "") IS NOT NULL
                  AND TRIM(u2.email) LIKE "%_@_%._%"
                  AND NOT EXISTS (SELECT 1 FROM users x
                                   WHERE x.email = LOWER(TRIM(u2.email)) COLLATE utf8mb4_unicode_ci)
             THEN LOWER(TRIM(u2.email)) END
       FROM usuarios u2 WHERE u2.', @pk_users, ' = o.idConta),
    CONCAT("orgao", o.', @pk_inst, ', "@importado.ajudamais.invalid"))'),
  CONCAT('CONCAT("orgao", o.', @pk_inst, ', "@importado.ajudamais.invalid")'));

-- 6.2 Cópia das instituições.
SET @sql := CONCAT('INSERT INTO institutions
   (legacy_institution_id, legal_name, description, email, status, created_at)
 SELECT
   o.', @pk_inst, ',
   ', @y_nome, ',
   ', @y_desc, ',
   ', @y_email, ',
   "pendente",
   CURRENT_TIMESTAMP', @y_from, '
 WHERE NOT EXISTS (SELECT 1 FROM institutions i WHERE i.legacy_institution_id = o.', @pk_inst, ')');
SET @sql := IF(@t_inst = 'orgaos_doacao', @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 6.3 Formato alternativo: tabela instituicoes.
SET @c_i_nome  := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='instituicoes' AND column_name='nome');
SET @c_i_email := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='instituicoes' AND column_name='email');
SET @c_i_cnpj  := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='instituicoes' AND column_name='cnpj');
SET @c_i_tel   := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='instituicoes' AND column_name='telefone');

SET @z_nome := IF(@c_i_nome = 1,
  CONCAT('LEFT(COALESCE(NULLIF(TRIM(i.nome), ""), CONCAT("Instituicao ", i.', @pk_inst, ')), 180)'),
  CONCAT('CONCAT("Instituicao ", i.', @pk_inst, ')'));
SET @z_cnpj := IF(@c_i_cnpj = 1,
  'NULLIF(CONVERT(REGEXP_REPLACE(COALESCE(i.cnpj, ""), "[^0-9]", "") USING utf8mb4), "")', 'NULL');
SET @z_email := IF(@c_i_email = 1,
  CONCAT('COALESCE(NULLIF(LOWER(TRIM(i.email)), ""), CONCAT("instituicao", i.', @pk_inst,
         ', "@importado.ajudamais.invalid"))'),
  CONCAT('CONCAT("instituicao", i.', @pk_inst, ', "@importado.ajudamais.invalid")'));
SET @z_tel := IF(@c_i_tel = 1,
  'CONVERT(REGEXP_REPLACE(COALESCE(i.telefone, ""), "[^0-9]", "") USING utf8mb4)', '""');

-- Deduplicação por CNPJ só quando a coluna existir (NULL com COLLATE é inválido).
SET @z_cnpj_where := IF(@c_i_cnpj = 1,
  CONCAT(' AND (', @z_cnpj, ' IS NULL OR NOT EXISTS (SELECT 1 FROM institutions x
                    WHERE x.cnpj IS NOT NULL AND x.cnpj = ', @z_cnpj,
         ' COLLATE utf8mb4_unicode_ci))'), '');

SET @sql := CONCAT('INSERT INTO institutions
   (legacy_institution_id, legal_name, cnpj, email, phone_e164, status, created_at)
 SELECT
   i.', @pk_inst, ',
   ', @z_nome, ',
   ', @z_cnpj, ',
   ', @z_email, ',
   CASE WHEN ', @z_tel, ' = "" THEN NULL
        WHEN CHAR_LENGTH(', @z_tel, ') = 11 THEN CONCAT("+55", ', @z_tel, ')
        WHEN CHAR_LENGTH(', @z_tel, ') = 10 THEN CONCAT("+55", ', @z_tel, ')
        ELSE NULL END,
   "pendente",
   CURRENT_TIMESTAMP
 FROM instituicoes i
 WHERE NOT EXISTS (SELECT 1 FROM institutions x WHERE x.legacy_institution_id = i.', @pk_inst, ')',
   @z_cnpj_where);
SET @sql := IF(@t_inst = 'instituicoes', @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 7. VÍNCULO PESSOA <-> INSTITUIÇÃO
--    Quem aparece em orgaos_doacao também é usuário: é o representante legal.
-- ============================================================================
SET @sql := CONCAT('INSERT IGNORE INTO institution_members
     (institution_id, user_id, member_role, status, joined_at)
 SELECT ins.id, u.id, "admin", "ativo", CURRENT_TIMESTAMP
 FROM orgaos_doacao o
 JOIN institutions ins ON ins.legacy_institution_id = o.', @pk_inst, '
 JOIN users u ON u.legacy_user_id = o.idConta');
SET @sql := IF(@t_inst = 'orgaos_doacao' AND @c_o_conta = 1, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

INSERT IGNORE INTO user_roles (user_id, role_id)
SELECT DISTINCT im.user_id, r.id
FROM institution_members im
JOIN users u ON u.id = im.user_id
JOIN roles r ON r.code = 'instituicao'
WHERE u.legacy_user_id IS NOT NULL;

-- ============================================================================
-- 8. ENDEREÇOS
--    enderecos(idEndereco, idConta, logradouro, cidade, estado, unidade)
-- ============================================================================
SET @c_e_lograd := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='enderecos' AND column_name='logradouro');
SET @c_e_bairro := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='enderecos' AND column_name='unidade');
SET @c_e_cidade := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='enderecos' AND column_name='cidade');
SET @c_e_estado := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='enderecos' AND column_name='estado');

SET @w_rua := IF(@c_e_lograd = 1,
  'COALESCE(NULLIF(TRIM(e.logradouro), ""), "Nao informado")', '"Nao informado"');
SET @w_bairro := IF(@c_e_bairro = 1, 'NULLIF(TRIM(e.unidade), "")', 'NULL');
SET @w_cidade := IF(@c_e_cidade = 1,
  'COALESCE(NULLIF(TRIM(e.cidade), ""), "Nao informado")', '"Nao informado"');
SET @w_uf := IF(@c_e_estado = 1,
  'CONVERT(UPPER(TRIM(e.estado)) USING utf8mb4)', 'NULL');

-- 8.1 Endereço da pessoa.
SET @sql := CONCAT('INSERT INTO addresses
     (user_id, label, address_type, street, district, city, state_code, is_primary)
 SELECT u.id, "Cadastro importado", "residencial", ', @w_rua, ', ', @w_bairro, ', ',
   @w_cidade, ', (SELECT s.code FROM states s WHERE s.code = ', @w_uf,
   ' COLLATE utf8mb4_unicode_ci), 1
 FROM enderecos e
 JOIN users u ON u.legacy_user_id = e.', @col_end_user, '
 WHERE NOT EXISTS (SELECT 1 FROM addresses a WHERE a.user_id = u.id)');
SET @sql := IF(@t_end IS NOT NULL AND @col_end_user IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 8.2 Cópia na instituição representada pela mesma pessoa.
SET @sql := CONCAT('INSERT INTO addresses
     (institution_id, label, address_type, street, district, city, state_code, is_primary)
 SELECT ins.id, "Sede", "comercial", ', @w_rua, ', ', @w_bairro, ', ',
   @w_cidade, ', (SELECT s.code FROM states s WHERE s.code = ', @w_uf,
   ' COLLATE utf8mb4_unicode_ci), 1
 FROM enderecos e
 JOIN orgaos_doacao o ON o.idConta = e.', @col_end_user, '
 JOIN institutions ins ON ins.legacy_institution_id = o.', @pk_inst, '
 WHERE NOT EXISTS (SELECT 1 FROM addresses a WHERE a.institution_id = ins.id)');
SET @sql := IF(@t_end IS NOT NULL AND @col_end_user IS NOT NULL AND @t_inst = 'orgaos_doacao',
  @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 8.3 Formato alternativo: endereço dentro da própria tabela instituicoes.
SET @c_i_cidade := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='instituicoes' AND column_name='cidade');
SET @c_i_end := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='instituicoes' AND column_name='endereco');
SET @c_i_estado := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='instituicoes' AND column_name='estado');

SET @v_rua := IF(@c_i_end = 1,
  'COALESCE(NULLIF(TRIM(i.endereco), ""), "Nao informado")', '"Nao informado"');
SET @v_uf := IF(@c_i_estado = 1, 'CONVERT(UPPER(TRIM(i.estado)) USING utf8mb4)', 'NULL');

SET @sql := CONCAT('INSERT INTO addresses
     (institution_id, label, address_type, street, city, state_code, is_primary)
 SELECT ins.id, "Sede", "comercial", ', @v_rua, ', ',
   'COALESCE(NULLIF(TRIM(i.cidade), ""), "Nao informado"), ',
   '(SELECT s.code FROM states s WHERE s.code = ', @v_uf, ' COLLATE utf8mb4_unicode_ci), 1
 FROM instituicoes i
 JOIN institutions ins ON ins.legacy_institution_id = i.', @pk_inst, '
 WHERE NOT EXISTS (SELECT 1 FROM addresses a WHERE a.institution_id = ins.id)');
SET @sql := IF(@t_inst = 'instituicoes' AND @c_i_cidade = 1, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
