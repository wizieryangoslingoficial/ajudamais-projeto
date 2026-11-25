-- ============================================================================
-- 2. INSTITUIÇÕES (ÓRGÃOS DE DOAÇÃO), EQUIPES E LOCALIZAÇÃO
-- ============================================================================

-- 2.1 Instituições / órgãos que recebem doações.
CREATE TABLE IF NOT EXISTS institutions (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  legal_name         VARCHAR(180)    NOT NULL,
  trade_name         VARCHAR(150)    NULL,
  cnpj               CHAR(14)        NULL,
  institution_type   VARCHAR(30)     NOT NULL DEFAULT 'ong',
  description        TEXT            NULL,
  mission            VARCHAR(500)    NULL,
  logo_url           VARCHAR(500)    NULL,
  cover_url          VARCHAR(500)    NULL,
  email              VARCHAR(254)    NOT NULL,
  phone_e164         VARCHAR(16)     NULL,
  whatsapp_e164      VARCHAR(16)     NULL,
  website_url        VARCHAR(500)    NULL,
  instagram_handle   VARCHAR(80)     NULL,
  founded_year       SMALLINT UNSIGNED NULL,
  accepts_items      TINYINT(1)      NOT NULL DEFAULT 1,
  accepts_money      TINYINT(1)      NOT NULL DEFAULT 0,
  accepts_volunteers TINYINT(1)      NOT NULL DEFAULT 0,
  status             VARCHAR(20)     NOT NULL DEFAULT 'pendente',
  verified_at        DATETIME        NULL,
  verified_by        BIGINT UNSIGNED NULL,
  rejection_reason   VARCHAR(255)    NULL,
  deleted_at         DATETIME        NULL,
  created_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_institutions_cnpj (cnpj),
  KEY idx_institutions_status (status),
  KEY idx_institutions_type (institution_type),
  KEY idx_institutions_name (legal_name),
  KEY idx_institutions_verified_by (verified_by),
  CONSTRAINT fk_institutions_verified_by FOREIGN KEY (verified_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_institutions_cnpj CHECK (cnpj IS NULL OR cnpj REGEXP '^[0-9]{14}$'),
  CONSTRAINT chk_institutions_type
    CHECK (institution_type IN ('ong','igreja','escola','hospital','abrigo','orgao_publico','grupo_comunitario','outro')),
  CONSTRAINT chk_institutions_status
    CHECK (status IN ('pendente','verificada','suspensa','encerrada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.2 Endereços de pessoas, instituições e pontos de coleta.
--     Exatamente um dono por linha (usuário OU instituição).
CREATE TABLE IF NOT EXISTS addresses (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id         BIGINT UNSIGNED NULL,
  institution_id  BIGINT UNSIGNED NULL,
  label           VARCHAR(60)     NULL COMMENT 'Ex.: Casa, Trabalho, Sede, Ponto de coleta',
  address_type    VARCHAR(20)     NOT NULL DEFAULT 'residencial',
  postal_code     CHAR(8)         NULL COMMENT 'CEP só com dígitos',
  street          VARCHAR(180)    NOT NULL,
  number          VARCHAR(20)     NULL,
  complement      VARCHAR(120)    NULL,
  district        VARCHAR(120)    NULL,
  city            VARCHAR(120)    NOT NULL,
  state_code      CHAR(2)         NULL,
  country_code    CHAR(2)         NOT NULL DEFAULT 'BR',
  latitude        DECIMAL(10,7)   NULL,
  longitude       DECIMAL(10,7)   NULL,
  reference_point VARCHAR(180)    NULL,
  is_primary      TINYINT(1)      NOT NULL DEFAULT 0,
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_addresses_user (user_id),
  KEY idx_addresses_institution (institution_id),
  KEY idx_addresses_city_state (state_code, city),
  KEY idx_addresses_postal_code (postal_code),
  CONSTRAINT fk_addresses_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_addresses_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT fk_addresses_state FOREIGN KEY (state_code) REFERENCES states (code) ON DELETE SET NULL,
  CONSTRAINT chk_addresses_single_owner
    CHECK ((user_id IS NULL) <> (institution_id IS NULL)),
  CONSTRAINT chk_addresses_type
    CHECK (address_type IN ('residencial','comercial','coleta','entrega','cobranca'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.3 Equipe da instituição (quem publica necessidades e confirma doações).
CREATE TABLE IF NOT EXISTS institution_members (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  institution_id BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  member_role    VARCHAR(20)     NOT NULL DEFAULT 'voluntario',
  status         VARCHAR(20)     NOT NULL DEFAULT 'ativo',
  invited_by     BIGINT UNSIGNED NULL,
  joined_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  left_at        DATETIME        NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_institution_members (institution_id, user_id),
  KEY idx_institution_members_user (user_id),
  KEY idx_institution_members_invited_by (invited_by),
  CONSTRAINT fk_institution_members_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT fk_institution_members_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_institution_members_invited_by FOREIGN KEY (invited_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_institution_members_role
    CHECK (member_role IN ('admin','gestor','atendente','voluntario')),
  CONSTRAINT chk_institution_members_status
    CHECK (status IN ('convidado','ativo','suspenso','removido'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.4 Documentos enviados para verificação da instituição.
CREATE TABLE IF NOT EXISTS institution_documents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  institution_id BIGINT UNSIGNED NOT NULL,
  document_type  VARCHAR(30)     NOT NULL,
  file_url       VARCHAR(500)    NOT NULL,
  status         VARCHAR(20)     NOT NULL DEFAULT 'pendente',
  reviewed_by    BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME        NULL,
  notes          VARCHAR(255)    NULL,
  created_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_institution_documents_institution (institution_id),
  KEY idx_institution_documents_status (status),
  KEY idx_institution_documents_reviewed_by (reviewed_by),
  CONSTRAINT fk_institution_documents_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT fk_institution_documents_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_institution_documents_type
    CHECK (document_type IN ('cnpj','estatuto','ata','comprovante_endereco','outro')),
  CONSTRAINT chk_institution_documents_status
    CHECK (status IN ('pendente','aprovado','recusado'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.5 Formas de receber dinheiro (Pix, conta bancária) exibidas na doação.
CREATE TABLE IF NOT EXISTS institution_payment_methods (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  institution_id BIGINT UNSIGNED NOT NULL,
  method         VARCHAR(20)     NOT NULL,
  pix_key        VARCHAR(140)    NULL,
  pix_key_type   VARCHAR(20)     NULL,
  bank_name      VARCHAR(80)     NULL,
  bank_code      VARCHAR(10)     NULL,
  branch         VARCHAR(20)     NULL,
  account_number VARCHAR(30)     NULL,
  account_type   VARCHAR(20)     NULL,
  holder_name    VARCHAR(150)    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_institution_payment_methods_institution (institution_id),
  CONSTRAINT fk_institution_payment_methods_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT chk_institution_payment_methods_method
    CHECK (method IN ('pix','transferencia','cartao','boleto')),
  CONSTRAINT chk_institution_payment_methods_pix_type
    CHECK (pix_key_type IS NULL OR pix_key_type IN ('cpf','cnpj','email','telefone','aleatoria'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.6 Categorias de itens (hierarquia usada em filtros e formulários).
CREATE TABLE IF NOT EXISTS item_categories (
  id         SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  parent_id  SMALLINT UNSIGNED NULL,
  slug       VARCHAR(60)       NOT NULL,
  name       VARCHAR(100)      NOT NULL,
  icon       VARCHAR(60)       NULL,
  sort_order SMALLINT          NOT NULL DEFAULT 0,
  is_active  TINYINT(1)        NOT NULL DEFAULT 1,
  created_at DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_item_categories_slug (slug),
  KEY idx_item_categories_parent (parent_id),
  CONSTRAINT fk_item_categories_parent FOREIGN KEY (parent_id) REFERENCES item_categories (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.7 Unidades de medida dos itens (un, kg, litro, caixa...).
CREATE TABLE IF NOT EXISTS item_units (
  code VARCHAR(10) NOT NULL,
  name VARCHAR(40) NOT NULL,
  PRIMARY KEY (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.8 Campanhas de arrecadação criadas pelas instituições.
CREATE TABLE IF NOT EXISTS campaigns (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  institution_id BIGINT UNSIGNED NOT NULL,
  title          VARCHAR(150)    NOT NULL,
  slug           VARCHAR(160)    NOT NULL,
  description    TEXT            NULL,
  cover_url      VARCHAR(500)    NULL,
  goal_type      VARCHAR(10)     NOT NULL DEFAULT 'itens',
  goal_amount    DECIMAL(12,2)   NULL,
  goal_quantity  INT UNSIGNED    NULL,
  starts_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ends_at        DATETIME        NULL,
  status         VARCHAR(20)     NOT NULL DEFAULT 'rascunho',
  created_by     BIGINT UNSIGNED NULL,
  created_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_campaigns_slug (slug),
  KEY idx_campaigns_institution (institution_id),
  KEY idx_campaigns_status (status),
  KEY idx_campaigns_created_by (created_by),
  CONSTRAINT fk_campaigns_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT fk_campaigns_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_campaigns_goal CHECK (goal_type IN ('itens','dinheiro')),
  CONSTRAINT chk_campaigns_status CHECK (status IN ('rascunho','ativa','encerrada','cancelada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2.9 Perfil de voluntário: área de interesse e disponibilidade.
CREATE TABLE IF NOT EXISTS volunteer_profiles (
  user_id         BIGINT UNSIGNED   NOT NULL,
  bio             VARCHAR(500)      NULL,
  skills          VARCHAR(500)      NULL,
  availability    VARCHAR(120)      NULL COMMENT 'Ex.: seg/qua à tarde',
  has_transport   TINYINT(1)        NOT NULL DEFAULT 0,
  max_distance_km SMALLINT UNSIGNED NULL,
  status          VARCHAR(20)       NOT NULL DEFAULT 'ativo',
  created_at      DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_volunteer_profiles_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT chk_volunteer_profiles_status CHECK (status IN ('ativo','inativo'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
