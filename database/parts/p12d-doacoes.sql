-- ============================================================================
-- 9. DOAÇÕES
--    (a) doacoes                -> donations + donation_items
--    (b) doacoes_transicoes     -> donations (doador -> instituição do destinatário)
--    Padrão seguro: CONCAT fecha sozinho; IF só escolhe o texto.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 9.1 Formato (a): tabela doacoes
-- ---------------------------------------------------------------------------
SET @c_d_msg1   := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='observacao');
SET @c_d_msg2   := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='mensagem');
SET @c_d_status := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='status');
SET @c_d_criado := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='criado_em');
SET @c_d_inst   := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='instituicao_id');
SET @c_d_user   := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='usuario_id');

SET @q_msg := CASE
  WHEN @c_d_msg1 = 1 AND @c_d_msg2 = 1
    THEN 'COALESCE(NULLIF(TRIM(d.observacao), ""), NULLIF(TRIM(d.mensagem), ""))'
  WHEN @c_d_msg1 = 1 THEN 'NULLIF(TRIM(d.observacao), "")'
  WHEN @c_d_msg2 = 1 THEN 'NULLIF(TRIM(d.mensagem), "")'
  ELSE 'NULL' END;
SET @q_status := IF(@c_d_status = 1, 'LOWER(COALESCE(d.status, "pendente"))', '"pendente"');
SET @q_criado := IF(@c_d_criado = 1, 'COALESCE(d.criado_em, CURRENT_TIMESTAMP)', 'CURRENT_TIMESTAMP');
SET @q_user := IF(@c_d_user = 1,
  CONCAT('(SELECT x.id FROM users x WHERE x.legacy_user_id = d.usuario_id)'), 'NULL');
SET @q_inst := IF(@c_d_inst = 1,
  CONCAT('(SELECT i.id FROM institutions i WHERE i.legacy_institution_id = d.instituicao_id)'), 'NULL');
SET @q_anon := IF(@c_d_user = 1,
  'CASE WHEN (SELECT COUNT(*) FROM users x WHERE x.legacy_user_id = d.usuario_id) = 0 THEN 1 ELSE 0 END',
  '1');

SET @sql := CONCAT('INSERT INTO donations
   (legacy_donation_id, code, donor_user_id, is_anonymous, institution_id,
    donation_type, status, message, created_at)
 SELECT
   d.', @pk_don, ',
   CONCAT("LEG-", d.', @pk_don, '),
   ', @q_user, ',
   ', @q_anon, ',
   ', @q_inst, ',
   "itens",
   CASE ', @q_status, '
     WHEN "confirmada" THEN "confirmada"
     WHEN "recebida"   THEN "recebida"
     WHEN "cancelada"  THEN "cancelada"
     WHEN "recusada"   THEN "recusada"
     ELSE "pendente" END,
   ', @q_msg, ',
   ', @q_criado, '
 FROM doacoes d
 WHERE NOT EXISTS (SELECT 1 FROM donations x WHERE x.legacy_donation_id = d.', @pk_don, ')');
SET @sql := IF(@t_don IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Itens do formato (a): um item por doação.
SET @c_d_desc := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='descricao');
SET @c_d_cat := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='categoria');
SET @c_d_qtd := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes' AND column_name='quantidade');

SET @q_desc := IF(@c_d_desc = 1,
  CONCAT('LEFT(COALESCE(NULLIF(TRIM(d.descricao), ""), "Item doado"), 200)'),
  CONCAT('CONCAT("Item doado ", d.', @pk_don, ')'));
SET @q_cat := IF(@c_d_cat = 1, 'COALESCE(d.categoria, "")', '""');
SET @q_qtd := IF(@c_d_qtd = 1, 'GREATEST(COALESCE(d.quantidade, 1), 1)', '1');

SET @sql := CONCAT('INSERT INTO donation_items
   (donation_id, category_id, description, unit_code, quantity, item_condition)
 SELECT dn.id,
        (SELECT c.id FROM item_categories c
          WHERE c.slug = LOWER(TRIM(', @q_cat, ')) COLLATE utf8mb4_unicode_ci
             OR LOWER(c.name) COLLATE utf8mb4_unicode_ci = LOWER(TRIM(', @q_cat, '))
                COLLATE utf8mb4_unicode_ci
          LIMIT 1),
        ', @q_desc, ',
        "un",
        ', @q_qtd, ',
        "usado"
 FROM doacoes d
 JOIN donations dn ON dn.legacy_donation_id = d.', @pk_don, '
 WHERE NOT EXISTS (SELECT 1 FROM donation_items di WHERE di.donation_id = dn.id)');
SET @sql := IF(@t_don IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- 9.2 Formato (b): doacoes_transicoes (doador -> destinatário)
-- ---------------------------------------------------------------------------
SET @c_t_doador := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes_transicoes' AND column_name='idDoador');
SET @c_t_dest := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema=@db AND table_name='doacoes_transicoes' AND column_name='idDestinatario');

-- Instituição do destinatário, quando ele for representante de uma.
SET @q_inst_dest := IF(@c_t_dest = 1,
  'COALESCE((SELECT im.institution_id FROM institution_members im
              WHERE im.user_id = (SELECT x.id FROM users x
                                   WHERE x.legacy_user_id = t.idDestinatario)
                AND im.status = "ativo" ORDER BY im.id LIMIT 1), NULL)', 'NULL');

SET @sql := CONCAT('INSERT INTO donations
   (legacy_donation_id, code, donor_user_id, is_anonymous, institution_id,
    donation_type, status, message, created_at)
 SELECT
   t.', @pk_trans, ',
   CONCAT("TRANS-", t.', @pk_trans, '),
   (SELECT x.id FROM users x WHERE x.legacy_user_id = t.idDoador),
   0,
   ', @q_inst_dest, ',
   "itens",
   "pendente",
   CONCAT("Doacao entre usuarios do sistema antigo (#", t.idDoador, " -> #",
          ', IF(@c_t_dest = 1, 't.idDestinatario', '"?"'), ', ")"),
   CURRENT_TIMESTAMP
 FROM doacoes_transicoes t
 WHERE EXISTS (SELECT 1 FROM users x WHERE x.legacy_user_id = t.idDoador)
   AND NOT EXISTS (SELECT 1 FROM donations dn WHERE dn.legacy_donation_id = t.', @pk_trans, ')');
SET @sql := IF(@t_trans IS NOT NULL AND @c_t_doador = 1, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Item representativo da transferência (o original não tem detalhe de itens).
SET @sql := CONCAT('INSERT INTO donation_items
     (donation_id, description, unit_code, quantity, item_condition)
 SELECT dn.id, "Doacao importada (sem detalhe de itens)", "un", 1, "usado"
 FROM donations dn
 WHERE dn.legacy_donation_id IS NOT NULL
   AND dn.code LIKE "TRANS-%"
   AND NOT EXISTS (SELECT 1 FROM donation_items di WHERE di.donation_id = dn.id)');
SET @sql := IF(@t_trans IS NOT NULL, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Transferências sem doador válido: registradas, não inventadas.
SET @sql := CONCAT('INSERT IGNORE INTO migration_skipped (legacy_table, legacy_id, reason)
 SELECT "doacoes_transicoes", t.', @pk_trans, ',
        "Doador nao encontrado na base de usuarios"
 FROM doacoes_transicoes t
 WHERE NOT EXISTS (SELECT 1 FROM users x WHERE x.legacy_user_id = t.idDoador)');
SET @sql := IF(@t_trans IS NOT NULL AND @c_t_doador = 1, @sql, 'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
