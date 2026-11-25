-- ============================================================================
-- 5. DADOS INICIAIS (idempotentes — nunca sobrescrevem dados existentes)
-- ============================================================================

INSERT INTO schema_migrations (version, description) VALUES
  ('2026.11.01', 'Estrutura completa do banco AjudaMais')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT INTO roles (code, name, description) VALUES
  ('admin',        'Administrador', 'Acesso total ao sistema e à moderação'),
  ('moderador',    'Moderador',     'Analisa denúncias, instituições e conteúdo'),
  ('instituicao',  'Instituição',   'Gerencia a instituição, necessidades e doações recebidas'),
  ('doador',       'Doador',        'Realiza doações de itens ou dinheiro'),
  ('beneficiario', 'Beneficiário',  'Solicita ajuda e acompanha seus pedidos'),
  ('voluntario',   'Voluntário',    'Apoia instituições e pontos de coleta')
ON DUPLICATE KEY UPDATE name = VALUES(name), description = VALUES(description);

INSERT INTO states (code, name, region) VALUES
  ('AC','Acre','Norte'), ('AL','Alagoas','Nordeste'), ('AP','Amapá','Norte'),
  ('AM','Amazonas','Norte'), ('BA','Bahia','Nordeste'), ('CE','Ceará','Nordeste'),
  ('DF','Distrito Federal','Centro-Oeste'), ('ES','Espírito Santo','Sudeste'),
  ('GO','Goiás','Centro-Oeste'), ('MA','Maranhão','Nordeste'),
  ('MT','Mato Grosso','Centro-Oeste'), ('MS','Mato Grosso do Sul','Centro-Oeste'),
  ('MG','Minas Gerais','Sudeste'), ('PA','Pará','Norte'), ('PB','Paraíba','Nordeste'),
  ('PR','Paraná','Sul'), ('PE','Pernambuco','Nordeste'), ('PI','Piauí','Nordeste'),
  ('RJ','Rio de Janeiro','Sudeste'), ('RN','Rio Grande do Norte','Nordeste'),
  ('RS','Rio Grande do Sul','Sul'), ('RO','Rondônia','Norte'), ('RR','Roraima','Norte'),
  ('SC','Santa Catarina','Sul'), ('SP','São Paulo','Sudeste'), ('SE','Sergipe','Nordeste'),
  ('TO','Tocantins','Norte')
ON DUPLICATE KEY UPDATE name = VALUES(name), region = VALUES(region);

INSERT INTO item_units (code, name) VALUES
  ('un','Unidade'), ('kg','Quilograma'), ('g','Grama'), ('l','Litro'), ('ml','Mililitro'),
  ('cx','Caixa'), ('pct','Pacote'), ('fardo','Fardo'), ('par','Par'), ('kit','Kit')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO item_categories (slug, name, icon, sort_order) VALUES
  ('alimentos','Alimentos','basket',1),
  ('roupas','Roupas e calçados','shirt',2),
  ('higiene','Higiene e limpeza','sparkles',3),
  ('moveis','Móveis e utensílios','armchair',4),
  ('eletronicos','Eletrônicos','laptop',5),
  ('brinquedos','Brinquedos','teddy-bear',6),
  ('material-escolar','Material escolar','book',7),
  ('saude','Saúde e medicamentos','heart-pulse',8),
  ('financeiro','Ajuda financeira','wallet',9),
  ('outros','Outros','box',99)
ON DUPLICATE KEY UPDATE name = VALUES(name), icon = VALUES(icon), sort_order = VALUES(sort_order);

-- Subcategorias úteis nos formulários de doação e de necessidade.
INSERT INTO item_categories (parent_id, slug, name, sort_order)
SELECT p.id, v.slug, v.name, v.sort_order
FROM (
            SELECT 'alimentos' AS parent_slug, 'alimentos-nao-pereciveis' AS slug, 'Não perecíveis' AS name, 1 AS sort_order
  UNION ALL SELECT 'alimentos',        'alimentos-pereciveis',    'Perecíveis', 2
  UNION ALL SELECT 'alimentos',        'agua',                    'Água potável', 3
  UNION ALL SELECT 'roupas',           'roupas-infantis',         'Roupas infantis', 1
  UNION ALL SELECT 'roupas',           'roupas-adultas',          'Roupas adultas', 2
  UNION ALL SELECT 'roupas',           'calcados',                'Calçados', 3
  UNION ALL SELECT 'roupas',           'cobertores',              'Cobertores e agasalhos', 4
  UNION ALL SELECT 'higiene',          'higiene-pessoal',         'Higiene pessoal', 1
  UNION ALL SELECT 'higiene',          'fraldas',                 'Fraldas', 2
  UNION ALL SELECT 'higiene',          'limpeza',                 'Produtos de limpeza', 3
  UNION ALL SELECT 'saude',            'medicamentos',            'Medicamentos', 1
  UNION ALL SELECT 'saude',            'equipamentos',            'Equipamentos e insumos', 2
  UNION ALL SELECT 'material-escolar', 'livros',                  'Livros', 1
  UNION ALL SELECT 'material-escolar', 'cadernos',                'Cadernos e papelaria', 2
) AS v
JOIN item_categories p ON p.slug = v.parent_slug
WHERE NOT EXISTS (SELECT 1 FROM item_categories c WHERE c.slug = v.slug);

INSERT INTO terms_versions (version, title, effective_at, is_current) VALUES
  ('1.0', 'Termos de Uso e Política de Privacidade', CURRENT_TIMESTAMP, 1)
ON DUPLICATE KEY UPDATE title = VALUES(title);

INSERT INTO app_settings (setting_key, setting_value, value_type, description) VALUES
  ('doacao.codigo.prefixo','AJM','string','Prefixo do código público da doação'),
  ('doacao.anonima.ativa','1','bool','Permite o fluxo de doação anônima'),
  ('doacao.item.quantidade.max','999','int','Quantidade máxima por item na doação'),
  ('solicitacao.prazo.dias','30','int','Dias até a expiração automática de uma necessidade'),
  ('verificacao.codigo.validade_min','10','int','Validade do código de verificação em minutos'),
  ('verificacao.codigo.tentativas','5','int','Tentativas permitidas por código'),
  ('senha.reset.validade_min','60','int','Validade do link de redefinição de senha'),
  ('login.max_tentativas','5','int','Tentativas de login antes do bloqueio'),
  ('login.bloqueio_min','15','int','Minutos de bloqueio após exceder tentativas'),
  ('moderacao.auto_aprovar_instituicao','0','bool','Aprova instituições sem análise manual'),
  ('lgpd.retencao_meses','24','int','Retenção de dados de contas inativas')
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- ============================================================================
-- 6. VIEWS PARA AS TELAS (somente leitura; mantêm a lógica no banco)
-- ============================================================================

-- 6.1 Card de instituição com nota média e cidade da sede.
CREATE OR REPLACE VIEW v_institutions_public AS
SELECT
  i.id,
  i.legal_name,
  i.trade_name,
  i.institution_type,
  i.description,
  i.mission,
  i.logo_url,
  i.cover_url,
  i.website_url,
  i.instagram_handle,
  i.accepts_items,
  i.accepts_money,
  i.accepts_volunteers,
  i.status,
  i.verified_at,
  a.city,
  a.state_code,
  ROUND(AVG(r.rating), 2) AS average_rating,
  COUNT(r.id)             AS reviews_count
FROM institutions i
LEFT JOIN addresses a ON a.institution_id = i.id AND a.is_primary = 1
LEFT JOIN reviews r   ON r.institution_id = i.id AND r.status = 'publicada'
WHERE i.deleted_at IS NULL
GROUP BY i.id, a.city, a.state_code;

-- 6.2 Progresso de cada item pedido (quanto já foi doado).
CREATE OR REPLACE VIEW v_request_items_progress AS
SELECT
  ri.id,
  ri.request_id,
  ri.description,
  ri.unit_code,
  ri.quantity_requested,
  COALESCE(SUM(di.quantity), 0) AS quantity_received,
  GREATEST(ri.quantity_requested - COALESCE(SUM(di.quantity), 0), 0) AS quantity_remaining,
  CASE
    WHEN COALESCE(SUM(di.quantity), 0) >= ri.quantity_requested THEN 'atendido'
    WHEN COALESCE(SUM(di.quantity), 0) > 0 THEN 'parcial'
    ELSE 'pendente'
  END AS computed_status
FROM request_items ri
LEFT JOIN donation_items di ON di.request_item_id = ri.id
LEFT JOIN donations d
       ON d.id = di.donation_id
      AND d.deleted_at IS NULL
      AND d.status IN ('confirmada','em_transito','recebida')
GROUP BY ri.id;

-- 6.3 Progresso consolidado da necessidade (barra de percentual das telas).
CREATE OR REPLACE VIEW v_request_progress AS
SELECT
  r.id,
  r.institution_id,
  r.requester_user_id,
  r.title,
  r.status,
  r.priority,
  r.needed_by,
  r.city,
  r.state_code,
  r.is_public,
  r.created_at,
  COUNT(ri.id)                     AS items_count,
  COALESCE(SUM(ri.quantity_requested), 0) AS quantity_requested,
  COALESCE(SUM(p.quantity_received), 0)   AS quantity_received,
  CASE
    WHEN COALESCE(SUM(ri.quantity_requested), 0) = 0 THEN 0
    ELSE ROUND(SUM(p.quantity_received) / SUM(ri.quantity_requested) * 100, 1)
  END AS percent_complete
FROM assistance_requests r
LEFT JOIN request_items ri ON ri.request_id = r.id
LEFT JOIN v_request_items_progress p ON p.id = ri.id
WHERE r.deleted_at IS NULL
GROUP BY r.id;

-- 6.4 Lista de doações pronta para o painel do doador e da instituição.
CREATE OR REPLACE VIEW v_donations_overview AS
SELECT
  d.id,
  d.code,
  d.donation_type,
  d.status,
  d.amount,
  d.payment_status,
  d.is_anonymous,
  d.created_at,
  d.confirmed_at,
  d.donor_user_id,
  COALESCE(u.full_name, d.donor_name) AS donor_display_name,
  i.id                                AS institution_id,
  COALESCE(i.trade_name, i.legal_name) AS institution_name,
  r.title                             AS request_title,
  COUNT(di.id)                        AS items_lines,
  COALESCE(SUM(di.quantity), 0)       AS items_quantity
FROM donations d
LEFT JOIN users u                ON u.id = d.donor_user_id
LEFT JOIN institutions i         ON i.id = d.institution_id
LEFT JOIN assistance_requests r  ON r.id = d.request_id
LEFT JOIN donation_items di      ON di.donation_id = d.id
WHERE d.deleted_at IS NULL
GROUP BY d.id, u.full_name, i.id, i.trade_name, i.legal_name, r.title;

-- 6.5 Painel de impacto da instituição (substitui tabela de estatísticas).
--     Subconsultas independentes evitam multiplicação de linhas entre
--     doações, itens e necessidades.
CREATE OR REPLACE VIEW v_institution_impact AS
SELECT
  i.id AS institution_id,
  (SELECT COUNT(*)
     FROM donations d
    WHERE d.institution_id = i.id
      AND d.deleted_at IS NULL
      AND d.status IN ('confirmada','em_transito','recebida'))            AS donations_count,
  (SELECT COALESCE(SUM(d.amount), 0)
     FROM donations d
    WHERE d.institution_id = i.id
      AND d.deleted_at IS NULL
      AND d.donation_type = 'dinheiro'
      AND d.status IN ('confirmada','em_transito','recebida'))            AS money_total,
  (SELECT COALESCE(SUM(di.quantity), 0)
     FROM donation_items di
     JOIN donations d ON d.id = di.donation_id
    WHERE d.institution_id = i.id
      AND d.deleted_at IS NULL
      AND d.status IN ('confirmada','em_transito','recebida'))            AS items_total,
  (SELECT COUNT(*)
     FROM assistance_requests rq
    WHERE rq.institution_id = i.id
      AND rq.deleted_at IS NULL)                                          AS requests_count
FROM institutions i
WHERE i.deleted_at IS NULL;
