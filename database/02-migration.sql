-- ============================================================================
-- AJUDAMAIS — MIGRATION PARA BANCOS EXISTENTES
-- Arquivo: database/02-migration.sql
-- Compatível com: MySQL 8.0.16+ e MariaDB 10.4+
-- Uso: mysql -u root -p ajudamais < database/02-migration.sql
--
-- O QUE FAZ
--   1. Cria toda a estrutura nova (mesmas tabelas de 01-schema.sql) sem
--      apagar nada do que já existe.
--   2. Se encontrar as tabelas do SQL original em português
--      (usuarios, instituicoes, doacoes, solicitacoes), copia os dados para
--      users, institutions, donations, donation_items e assistance_requests,
--      normalizando CPF/CNPJ/telefone.
--   3. Mantém as tabelas originais intactas. A remoção é manual, só depois
--      de validar o sistema.
--   4. Pode ser executada mais de uma vez: cada cópia é controlada por
--      legacy_*_id, então nada é duplicado.
--
-- ANTES DE EXECUTAR
--   mysqldump -u root -p ajudamais > backup-ajudamais.sql
--   Escolha o banco antes de rodar (USE ajudamais;) — este arquivo não
--   cria nem seleciona banco.
--
-- NÃO HÁ DROP TABLE, TRUNCATE OU DELETE NESTE ARQUIVO.
-- ============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';


-- ============================================================================
-- 0. CONTROLE DE VERSÃO
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  version     VARCHAR(40)     NOT NULL,
  description VARCHAR(255)    NOT NULL,
  applied_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_schema_migrations_version (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 1. AUTENTICAÇÃO, PERMISSÕES E LGPD
-- ============================================================================

-- 1.1 Usuários: doador, beneficiário, membro de instituição, moderador, admin.
CREATE TABLE IF NOT EXISTS users (
  id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  full_name            VARCHAR(150)    NOT NULL,
  display_name         VARCHAR(80)     NULL,
  email                VARCHAR(254)    NOT NULL,
  email_verified_at    DATETIME        NULL,
  cpf                  CHAR(11)        NOT NULL,
  cpf_verified_at      DATETIME        NULL,
  govbr_sub            VARCHAR(64)     NULL COMMENT 'Claim sub devolvida pelo Gov.br',
  govbr_verified_at    DATETIME        NULL,
  phone_e164           VARCHAR(16)     NULL COMMENT 'Celular como +5511999999999',
  phone_verified_at    DATETIME        NULL,
  birth_date           DATE            NULL,
  password_hash        VARCHAR(255)    NOT NULL,
  password_algo        VARCHAR(20)     NOT NULL DEFAULT 'bcrypt',
  must_change_password TINYINT(1)      NOT NULL DEFAULT 0,
  avatar_url           VARCHAR(500)    NULL,
  status               VARCHAR(20)     NOT NULL DEFAULT 'pendente',
  login_attempts       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until         DATETIME        NULL,
  last_login_at        DATETIME        NULL,
  terms_accepted_at    DATETIME        NULL,
  deleted_at           DATETIME        NULL,
  created_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_cpf (cpf),
  UNIQUE KEY uq_users_govbr_sub (govbr_sub),
  UNIQUE KEY uq_users_phone_e164 (phone_e164),
  KEY idx_users_status (status),
  KEY idx_users_created_at (created_at),
  CONSTRAINT chk_users_cpf_digits CHECK (cpf REGEXP '^[0-9]{11}$'),
  CONSTRAINT chk_users_status CHECK (status IN ('pendente','ativo','suspenso','inativo','excluido'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1.2 Papéis e vínculo N:N (a mesma pessoa pode doar e administrar uma ONG).
CREATE TABLE IF NOT EXISTS roles (
  id          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code        VARCHAR(30)       NOT NULL,
  name        VARCHAR(80)       NOT NULL,
  description VARCHAR(255)      NULL,
  created_at  DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_roles_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_roles (
  user_id    BIGINT UNSIGNED   NOT NULL,
  role_id    SMALLINT UNSIGNED NOT NULL,
  granted_by BIGINT UNSIGNED   NULL,
  granted_at DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, role_id),
  KEY idx_user_roles_role (role_id),
  KEY idx_user_roles_granted_by (granted_by),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE,
  CONSTRAINT fk_user_roles_granted_by FOREIGN KEY (granted_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1.3 Sessões de login (guarda o hash do token, nunca o token).
CREATE TABLE IF NOT EXISTS sessions (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED NOT NULL,
  token_hash   CHAR(64)        NOT NULL,
  ip_address   VARCHAR(45)     NULL,
  user_agent   VARCHAR(255)    NULL,
  device_label VARCHAR(80)     NULL,
  created_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used_at DATETIME        NULL,
  expires_at   DATETIME        NOT NULL,
  revoked_at   DATETIME        NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sessions_token_hash (token_hash),
  KEY idx_sessions_user (user_id),
  KEY idx_sessions_expires (expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1.4 Códigos de verificação (recuperar conta por e-mail/celular, cadastro,
--     login em dois passos e troca de contato).
CREATE TABLE IF NOT EXISTS verification_codes (
  id          BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED   NULL,
  channel     VARCHAR(10)       NOT NULL,
  destination VARCHAR(254)      NOT NULL COMMENT 'E-mail ou celular que recebeu o código',
  purpose     VARCHAR(30)       NOT NULL,
  code_hash   CHAR(64)          NOT NULL,
  attempts    TINYINT UNSIGNED  NOT NULL DEFAULT 0,
  ip_address  VARCHAR(45)       NULL,
  expires_at  DATETIME          NOT NULL,
  verified_at DATETIME          NULL,
  consumed_at DATETIME          NULL,
  created_at  DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_verification_codes_lookup (destination, purpose, expires_at),
  KEY idx_verification_codes_user (user_id),
  CONSTRAINT fk_verification_codes_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT chk_verification_codes_channel CHECK (channel IN ('email','sms','whatsapp')),
  CONSTRAINT chk_verification_codes_purpose
    CHECK (purpose IN ('cadastro','recuperar_conta','login','trocar_senha','trocar_contato'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1.5 Redefinição de senha por link (tela "Esqueci minha senha").
CREATE TABLE IF NOT EXISTS password_resets (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64)        NOT NULL,
  ip_address VARCHAR(45)     NULL,
  expires_at DATETIME        NOT NULL,
  used_at    DATETIME        NULL,
  created_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_password_resets_token_hash (token_hash),
  KEY idx_password_resets_user (user_id),
  CONSTRAINT fk_password_resets_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1.6 Termos de Uso / Política de Privacidade versionados e aceite auditável.
CREATE TABLE IF NOT EXISTS terms_versions (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  version      VARCHAR(20)     NOT NULL,
  title        VARCHAR(150)    NOT NULL,
  body         MEDIUMTEXT      NULL,
  body_url     VARCHAR(500)    NULL,
  effective_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_current   TINYINT(1)      NOT NULL DEFAULT 1,
  created_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_terms_versions_version (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS terms_acceptances (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id          BIGINT UNSIGNED NULL COMMENT 'Nulo quando o aceite ocorre antes de haver conta',
  terms_version_id BIGINT UNSIGNED NOT NULL,
  anonymous_id     CHAR(36)        NULL COMMENT 'Identifica o aceite na tela inicial sem login',
  ip_address       VARCHAR(45)     NULL,
  user_agent       VARCHAR(255)    NULL,
  accepted_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_terms_acceptances_user (user_id),
  KEY idx_terms_acceptances_version (terms_version_id),
  KEY idx_terms_acceptances_anonymous (anonymous_id),
  CONSTRAINT fk_terms_acceptances_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_terms_acceptances_version FOREIGN KEY (terms_version_id) REFERENCES terms_versions (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1.7 Consentimentos granulares exigidos pela LGPD.
CREATE TABLE IF NOT EXISTS consents (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    BIGINT UNSIGNED NOT NULL,
  type       VARCHAR(30)     NOT NULL,
  granted    TINYINT(1)      NOT NULL DEFAULT 1,
  version    VARCHAR(20)     NULL,
  ip_address VARCHAR(45)     NULL,
  granted_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at DATETIME        NULL,
  PRIMARY KEY (id),
  KEY idx_consents_user_type (user_id, type),
  CONSTRAINT fk_consents_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT chk_consents_type
    CHECK (type IN ('marketing','compartilhar_dados','dados_sensiveis','comunicacoes_doacao'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1.8 Solicitações do titular (acesso, correção, exclusão, portabilidade).
CREATE TABLE IF NOT EXISTS privacy_requests (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED NULL,
  email        VARCHAR(254)    NOT NULL COMMENT 'Contato de quem pediu, mesmo sem conta',
  type         VARCHAR(20)     NOT NULL,
  details      TEXT            NULL,
  status       VARCHAR(20)     NOT NULL DEFAULT 'recebida',
  response     TEXT            NULL,
  handled_by   BIGINT UNSIGNED NULL,
  requested_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at  DATETIME        NULL,
  PRIMARY KEY (id),
  KEY idx_privacy_requests_user (user_id),
  KEY idx_privacy_requests_status (status),
  CONSTRAINT fk_privacy_requests_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_privacy_requests_handler FOREIGN KEY (handled_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_privacy_requests_type
    CHECK (type IN ('acesso','correcao','exclusao','portabilidade','revogacao')),
  CONSTRAINT chk_privacy_requests_status
    CHECK (status IN ('recebida','em_analise','atendida','recusada','cancelada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1.9 Unidades da federação (combos de endereço e filtros por região).
CREATE TABLE IF NOT EXISTS states (
  code   CHAR(2)     NOT NULL,
  name   VARCHAR(60) NOT NULL,
  region VARCHAR(20) NOT NULL,
  PRIMARY KEY (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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
-- ============================================================================
-- 3. NECESSIDADES, DOAÇÕES E LOGÍSTICA
-- ============================================================================

-- 3.1 Necessidades / solicitações de ajuda.
--     Atende os dois fluxos do AjudaMais:
--       * instituição pedindo itens  -> institution_id preenchido;
--       * pessoa em vulnerabilidade  -> requester_user_id preenchido.
--     A CHECK garante exatamente um solicitante por linha.
CREATE TABLE IF NOT EXISTS assistance_requests (
  id                BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  institution_id    BIGINT UNSIGNED   NULL,
  requester_user_id BIGINT UNSIGNED   NULL,
  campaign_id       BIGINT UNSIGNED   NULL,
  title             VARCHAR(150)      NOT NULL,
  description       TEXT              NULL,
  category_id       SMALLINT UNSIGNED NULL COMMENT 'Categoria principal, usada em filtros',
  priority          VARCHAR(20)       NOT NULL DEFAULT 'normal',
  beneficiary_count SMALLINT UNSIGNED NULL COMMENT 'Quantas pessoas serão atendidas',
  city              VARCHAR(120)      NULL,
  state_code        CHAR(2)           NULL,
  address_id        BIGINT UNSIGNED   NULL,
  is_public         TINYINT(1)        NOT NULL DEFAULT 1,
  allows_anonymous  TINYINT(1)        NOT NULL DEFAULT 1,
  needed_by         DATE              NULL,
  status            VARCHAR(20)       NOT NULL DEFAULT 'aberta',
  published_at      DATETIME          NULL,
  closed_at         DATETIME          NULL,
  close_reason      VARCHAR(255)      NULL,
  moderated_by      BIGINT UNSIGNED   NULL,
  moderated_at      DATETIME          NULL,
  deleted_at        DATETIME          NULL,
  created_at        DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_requests_institution (institution_id, status),
  KEY idx_requests_requester (requester_user_id, status),
  KEY idx_requests_campaign (campaign_id),
  KEY idx_requests_status_public (is_public, status, created_at),
  KEY idx_requests_location (state_code, city),
  KEY idx_requests_category (category_id),
  KEY idx_requests_address (address_id),
  KEY idx_requests_moderated_by (moderated_by),
  CONSTRAINT fk_requests_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT fk_requests_requester FOREIGN KEY (requester_user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_requests_campaign FOREIGN KEY (campaign_id) REFERENCES campaigns (id) ON DELETE SET NULL,
  CONSTRAINT fk_requests_category FOREIGN KEY (category_id) REFERENCES item_categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_requests_address FOREIGN KEY (address_id) REFERENCES addresses (id) ON DELETE SET NULL,
  CONSTRAINT fk_requests_state FOREIGN KEY (state_code) REFERENCES states (code) ON DELETE SET NULL,
  CONSTRAINT fk_requests_moderated_by FOREIGN KEY (moderated_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_requests_single_requester
    CHECK ((institution_id IS NULL) <> (requester_user_id IS NULL)),
  CONSTRAINT chk_requests_priority CHECK (priority IN ('baixa','normal','alta','urgente')),
  CONSTRAINT chk_requests_status
    CHECK (status IN ('rascunho','aberta','parcialmente_atendida','atendida','expirada','cancelada','bloqueada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3.2 Itens pedidos em cada necessidade.
--     O total recebido NÃO é duplicado aqui: vem da view
--     v_request_items_progress (soma das doações confirmadas).
CREATE TABLE IF NOT EXISTS request_items (
  id                 BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  request_id         BIGINT UNSIGNED   NOT NULL,
  category_id        SMALLINT UNSIGNED NULL,
  description        VARCHAR(200)      NOT NULL,
  unit_code          VARCHAR(10)       NOT NULL DEFAULT 'un',
  quantity_requested DECIMAL(10,2)     NOT NULL,
  size               VARCHAR(30)       NULL,
  gender             VARCHAR(20)       NULL,
  condition_required VARCHAR(20)       NULL,
  notes              VARCHAR(255)      NULL,
  created_at         DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_request_items_request (request_id),
  KEY idx_request_items_category (category_id),
  CONSTRAINT fk_request_items_request FOREIGN KEY (request_id) REFERENCES assistance_requests (id) ON DELETE CASCADE,
  CONSTRAINT fk_request_items_category FOREIGN KEY (category_id) REFERENCES item_categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_request_items_unit FOREIGN KEY (unit_code) REFERENCES item_units (code),
  CONSTRAINT chk_request_items_quantity CHECK (quantity_requested > 0),
  CONSTRAINT chk_request_items_condition
    CHECK (condition_required IS NULL OR condition_required IN ('novo','seminovo','usado','qualquer')),
  CONSTRAINT chk_request_items_size
    CHECK (size IS NULL OR size IN ('rn','pp','p','m','g','gg','xg','unico','infantil','outro'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3.3 Doações de itens ou dinheiro, de usuário logado ou anônima.
--     Doação anônima = is_anonymous 1 e donor_user_id nulo; o contato é
--     opcional (donor_email) para envio do código de acompanhamento.
CREATE TABLE IF NOT EXISTS donations (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code               VARCHAR(20)     NOT NULL COMMENT 'Código curto exibido ao doador',
  donor_user_id      BIGINT UNSIGNED NULL COMMENT 'Nulo em doação anônima',
  donor_name         VARCHAR(150)    NULL COMMENT 'Nome informado no fluxo anônimo (opcional)',
  donor_email        VARCHAR(254)    NULL COMMENT 'Contato para acompanhamento da doação',
  is_anonymous       TINYINT(1)      NOT NULL DEFAULT 0,
  show_name_publicly TINYINT(1)      NOT NULL DEFAULT 1,
  institution_id     BIGINT UNSIGNED NULL,
  request_id         BIGINT UNSIGNED NULL,
  campaign_id        BIGINT UNSIGNED NULL,
  donation_type      VARCHAR(10)     NOT NULL DEFAULT 'itens',
  status             VARCHAR(20)     NOT NULL DEFAULT 'pendente',
  amount             DECIMAL(12,2)   NULL,
  payment_method     VARCHAR(20)     NULL,
  payment_status     VARCHAR(20)     NULL,
  payment_reference  VARCHAR(120)    NULL,
  paid_at            DATETIME        NULL,
  dropoff_address_id BIGINT UNSIGNED NULL COMMENT 'Endereço de retirada informado pelo doador',
  scheduled_at       DATETIME        NULL,
  message            VARCHAR(500)    NULL,
  cancel_reason      VARCHAR(255)    NULL,
  confirmed_by       BIGINT UNSIGNED NULL,
  confirmed_at       DATETIME        NULL,
  deleted_at         DATETIME        NULL,
  created_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_donations_code (code),
  KEY idx_donations_donor (donor_user_id, created_at),
  KEY idx_donations_institution (institution_id, status),
  KEY idx_donations_request (request_id),
  KEY idx_donations_campaign (campaign_id),
  KEY idx_donations_status (status, created_at),
  KEY idx_donations_payment (payment_status),
  KEY idx_donations_dropoff (dropoff_address_id),
  KEY idx_donations_confirmed_by (confirmed_by),
  CONSTRAINT fk_donations_donor FOREIGN KEY (donor_user_id) REFERENCES users (id) ON DELETE RESTRICT,
  CONSTRAINT fk_donations_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE SET NULL,
  CONSTRAINT fk_donations_request FOREIGN KEY (request_id) REFERENCES assistance_requests (id) ON DELETE SET NULL,
  CONSTRAINT fk_donations_campaign FOREIGN KEY (campaign_id) REFERENCES campaigns (id) ON DELETE SET NULL,
  CONSTRAINT fk_donations_dropoff FOREIGN KEY (dropoff_address_id) REFERENCES addresses (id) ON DELETE SET NULL,
  CONSTRAINT fk_donations_confirmed_by FOREIGN KEY (confirmed_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_donations_type CHECK (donation_type IN ('itens','dinheiro')),
  CONSTRAINT chk_donations_amount CHECK (amount IS NULL OR amount >= 0),
  CONSTRAINT chk_donations_money_requires_amount
    CHECK (donation_type <> 'dinheiro' OR (amount IS NOT NULL AND amount > 0)),
  CONSTRAINT chk_donations_identifier
    CHECK ((donor_user_id IS NULL) = (is_anonymous = 1)),
  CONSTRAINT chk_donations_status
    CHECK (status IN ('pendente','confirmada','em_transito','recebida','cancelada','recusada')),
  CONSTRAINT chk_donations_payment_method
    CHECK (payment_method IS NULL OR payment_method IN ('pix','transferencia','cartao','boleto','dinheiro')),
  CONSTRAINT chk_donations_payment_status
    CHECK (payment_status IS NULL OR payment_status IN ('pendente','pago','estornado','falhou'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3.4 Itens de cada doação física.
CREATE TABLE IF NOT EXISTS donation_items (
  id              BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  donation_id     BIGINT UNSIGNED   NOT NULL,
  request_item_id BIGINT UNSIGNED   NULL COMMENT 'Item da necessidade que esta doação atende',
  category_id     SMALLINT UNSIGNED NULL,
  description     VARCHAR(200)      NOT NULL,
  unit_code       VARCHAR(10)       NOT NULL DEFAULT 'un',
  quantity        DECIMAL(10,2)     NOT NULL,
  item_condition  VARCHAR(20)       NOT NULL DEFAULT 'usado',
  size            VARCHAR(30)       NULL,
  gender          VARCHAR(20)       NULL,
  brand           VARCHAR(80)       NULL,
  expires_on      DATE              NULL COMMENT 'Validade para alimentos e medicamentos',
  photo_url       VARCHAR(500)      NULL,
  notes           VARCHAR(255)      NULL,
  created_at      DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_donation_items_donation (donation_id),
  KEY idx_donation_items_request_item (request_item_id),
  KEY idx_donation_items_category (category_id),
  CONSTRAINT fk_donation_items_donation FOREIGN KEY (donation_id) REFERENCES donations (id) ON DELETE CASCADE,
  CONSTRAINT fk_donation_items_request_item FOREIGN KEY (request_item_id) REFERENCES request_items (id) ON DELETE SET NULL,
  CONSTRAINT fk_donation_items_category FOREIGN KEY (category_id) REFERENCES item_categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_donation_items_unit FOREIGN KEY (unit_code) REFERENCES item_units (code),
  CONSTRAINT chk_donation_items_quantity CHECK (quantity > 0),
  CONSTRAINT chk_donation_items_condition CHECK (item_condition IN ('novo','seminovo','usado')),
  CONSTRAINT chk_donation_items_size
    CHECK (size IS NULL OR size IN ('rn','pp','p','m','g','gg','xg','unico','infantil','outro'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3.5 Pontos de coleta (endereço + responsável + horários).
CREATE TABLE IF NOT EXISTS collection_points (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  institution_id BIGINT UNSIGNED NOT NULL,
  address_id     BIGINT UNSIGNED NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  instructions   VARCHAR(500)    NULL,
  opening_hours  VARCHAR(120)    NULL COMMENT 'Ex.: seg a sex, 9h às 17h',
  contact_phone  VARCHAR(16)     NULL,
  accepts_items  TINYINT(1)      NOT NULL DEFAULT 1,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_collection_points_institution (institution_id),
  KEY idx_collection_points_address (address_id),
  CONSTRAINT fk_collection_points_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT fk_collection_points_address FOREIGN KEY (address_id) REFERENCES addresses (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3.6 Entrega / retirada das doações de itens.
CREATE TABLE IF NOT EXISTS deliveries (
  id                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  donation_id            BIGINT UNSIGNED NOT NULL,
  method                 VARCHAR(20)     NOT NULL,
  collection_point_id    BIGINT UNSIGNED NULL,
  origin_address_id      BIGINT UNSIGNED NULL,
  destination_address_id BIGINT UNSIGNED NULL,
  carrier_name           VARCHAR(120)    NULL,
  tracking_code          VARCHAR(60)     NULL,
  scheduled_at           DATETIME        NULL,
  picked_up_at           DATETIME        NULL,
  delivered_at           DATETIME        NULL,
  status                 VARCHAR(20)     NOT NULL DEFAULT 'agendada',
  proof_url              VARCHAR(500)    NULL,
  recipient_name         VARCHAR(150)    NULL,
  notes                  VARCHAR(500)    NULL,
  created_by             BIGINT UNSIGNED NULL,
  created_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_deliveries_donation (donation_id),
  KEY idx_deliveries_status (status),
  KEY idx_deliveries_point (collection_point_id),
  KEY idx_deliveries_origin (origin_address_id),
  KEY idx_deliveries_destination (destination_address_id),
  KEY idx_deliveries_created_by (created_by),
  CONSTRAINT fk_deliveries_donation FOREIGN KEY (donation_id) REFERENCES donations (id) ON DELETE CASCADE,
  CONSTRAINT fk_deliveries_point FOREIGN KEY (collection_point_id) REFERENCES collection_points (id) ON DELETE SET NULL,
  CONSTRAINT fk_deliveries_origin FOREIGN KEY (origin_address_id) REFERENCES addresses (id) ON DELETE SET NULL,
  CONSTRAINT fk_deliveries_destination FOREIGN KEY (destination_address_id) REFERENCES addresses (id) ON DELETE SET NULL,
  CONSTRAINT fk_deliveries_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_deliveries_method CHECK (method IN ('retirada','ponto_coleta','entrega','correio')),
  CONSTRAINT chk_deliveries_status CHECK (status IN ('agendada','em_transito','entregue','falhou','cancelada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3.7 Trilha de status para as telas de acompanhamento e auditoria.
CREATE TABLE IF NOT EXISTS donation_status_history (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  donation_id BIGINT UNSIGNED NOT NULL,
  from_status VARCHAR(20)     NULL,
  to_status   VARCHAR(20)     NOT NULL,
  changed_by  BIGINT UNSIGNED NULL COMMENT 'Nulo quando a mudança é automática',
  note        VARCHAR(255)    NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_donation_history_donation (donation_id, created_at),
  KEY idx_donation_history_changed_by (changed_by),
  CONSTRAINT fk_donation_history_donation FOREIGN KEY (donation_id) REFERENCES donations (id) ON DELETE CASCADE,
  CONSTRAINT fk_donation_history_changed_by FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS request_status_history (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_id  BIGINT UNSIGNED NOT NULL,
  from_status VARCHAR(20)     NULL,
  to_status   VARCHAR(20)     NOT NULL,
  changed_by  BIGINT UNSIGNED NULL,
  note        VARCHAR(255)    NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_request_history_request (request_id, created_at),
  KEY idx_request_history_changed_by (changed_by),
  CONSTRAINT fk_request_history_request FOREIGN KEY (request_id) REFERENCES assistance_requests (id) ON DELETE CASCADE,
  CONSTRAINT fk_request_history_changed_by FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3.8 Exclusão de conta / LGPD.
--     A FK de doador usa ON DELETE RESTRICT, então a conta não é apagada
--     enquanto existir doação vinculada. Este trigger roda antes do DELETE:
--     anonimiza as doações da pessoa (mantendo o histórico da instituição),
--     libera a FK e só então remove a conta. É idempotente (DROP IF EXISTS),
--     então o schema pode ser reexecutado sem erro.
DROP TRIGGER IF EXISTS trg_users_bd_anonymize_donations;

DELIMITER $$

CREATE TRIGGER trg_users_bd_anonymize_donations
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  UPDATE donations
     SET is_anonymous = 1,
         donor_user_id = NULL,
         donor_name = NULL,
         donor_email = NULL,
         show_name_publicly = 0
   WHERE donor_user_id = OLD.id;
END$$

DELIMITER ;
-- ============================================================================
-- 4. COMUNICAÇÃO, ENGAJAMENTO, MODERAÇÃO E OPERAÇÃO
-- ============================================================================

-- 4.1 Conversas entre doador, instituição e solicitante (módulo Contatos).
CREATE TABLE IF NOT EXISTS conversations (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  subject         VARCHAR(150)    NULL,
  donation_id     BIGINT UNSIGNED NULL,
  request_id      BIGINT UNSIGNED NULL,
  institution_id  BIGINT UNSIGNED NULL,
  created_by      BIGINT UNSIGNED NULL,
  status          VARCHAR(20)     NOT NULL DEFAULT 'aberta',
  last_message_at DATETIME        NULL,
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_conversations_donation (donation_id),
  KEY idx_conversations_request (request_id),
  KEY idx_conversations_institution (institution_id),
  KEY idx_conversations_created_by (created_by),
  KEY idx_conversations_status (status, last_message_at),
  CONSTRAINT fk_conversations_donation FOREIGN KEY (donation_id) REFERENCES donations (id) ON DELETE SET NULL,
  CONSTRAINT fk_conversations_request FOREIGN KEY (request_id) REFERENCES assistance_requests (id) ON DELETE SET NULL,
  CONSTRAINT fk_conversations_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE SET NULL,
  CONSTRAINT fk_conversations_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_conversations_status CHECK (status IN ('aberta','arquivada','bloqueada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id  BIGINT UNSIGNED NOT NULL,
  user_id          BIGINT UNSIGNED NOT NULL,
  participant_role VARCHAR(20)     NOT NULL DEFAULT 'membro',
  last_read_at     DATETIME        NULL,
  joined_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (conversation_id, user_id),
  KEY idx_conversation_participants_user (user_id),
  CONSTRAINT fk_conversation_participants_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE,
  CONSTRAINT fk_conversation_participants_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT chk_conversation_participants_role
    CHECK (participant_role IN ('doador','instituicao','solicitante','moderador'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS messages (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  conversation_id BIGINT UNSIGNED NOT NULL,
  sender_user_id  BIGINT UNSIGNED NULL,
  body            TEXT            NOT NULL,
  attachment_url  VARCHAR(500)    NULL,
  read_at         DATETIME        NULL,
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_messages_conversation (conversation_id, created_at),
  KEY idx_messages_sender (sender_user_id),
  CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE,
  CONSTRAINT fk_messages_sender FOREIGN KEY (sender_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4.2 Notificações in-app.
CREATE TABLE IF NOT EXISTS notifications (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NOT NULL,
  type        VARCHAR(40)     NOT NULL,
  title       VARCHAR(150)    NOT NULL,
  body        VARCHAR(500)    NULL,
  link_url    VARCHAR(500)    NULL,
  entity_type VARCHAR(30)     NULL,
  entity_id   BIGINT UNSIGNED NULL,
  read_at     DATETIME        NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_notifications_user (user_id, read_at, created_at),
  KEY idx_notifications_entity (entity_type, entity_id),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT chk_notifications_type CHECK (type IN (
    'doacao_nova','doacao_confirmada','doacao_recebida','doacao_cancelada',
    'solicitacao_nova','solicitacao_atendida','mensagem','verificacao',
    'termos_atualizados','seguranca','sistema'
  ))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4.3 Favoritos (instituições e necessidades salvas pelo doador).
CREATE TABLE IF NOT EXISTS favorites (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  institution_id BIGINT UNSIGNED NULL,
  request_id     BIGINT UNSIGNED NULL,
  created_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_favorites_user_institution (user_id, institution_id),
  UNIQUE KEY uq_favorites_user_request (user_id, request_id),
  KEY idx_favorites_institution (institution_id),
  KEY idx_favorites_request (request_id),
  CONSTRAINT fk_favorites_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_favorites_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT fk_favorites_request FOREIGN KEY (request_id) REFERENCES assistance_requests (id) ON DELETE CASCADE,
  CONSTRAINT chk_favorites_single_target
    CHECK ((institution_id IS NULL) <> (request_id IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4.4 Avaliações do doador sobre a instituição (uma por doação).
CREATE TABLE IF NOT EXISTS reviews (
  id             BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  donation_id    BIGINT UNSIGNED  NULL,
  institution_id BIGINT UNSIGNED  NOT NULL,
  reviewer_id    BIGINT UNSIGNED  NOT NULL,
  rating         TINYINT UNSIGNED NOT NULL,
  comment        VARCHAR(500)     NULL,
  status         VARCHAR(20)      NOT NULL DEFAULT 'publicada',
  created_at     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_reviews_donation (donation_id),
  KEY idx_reviews_institution (institution_id, status),
  KEY idx_reviews_reviewer (reviewer_id),
  CONSTRAINT fk_reviews_donation FOREIGN KEY (donation_id) REFERENCES donations (id) ON DELETE SET NULL,
  CONSTRAINT fk_reviews_institution FOREIGN KEY (institution_id) REFERENCES institutions (id) ON DELETE CASCADE,
  CONSTRAINT fk_reviews_reviewer FOREIGN KEY (reviewer_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT chk_reviews_status CHECK (status IN ('pendente','publicada','oculta'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4.5 Denúncias de conteúdo (instituições, pedidos, doações, mensagens, perfis).
CREATE TABLE IF NOT EXISTS reports (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  reporter_id     BIGINT UNSIGNED NULL,
  target_type     VARCHAR(20)     NOT NULL,
  target_id       BIGINT UNSIGNED NOT NULL,
  reason          VARCHAR(40)     NOT NULL,
  details         TEXT            NULL,
  status          VARCHAR(20)     NOT NULL DEFAULT 'aberta',
  resolution_note VARCHAR(500)    NULL,
  resolved_by     BIGINT UNSIGNED NULL,
  resolved_at     DATETIME        NULL,
  created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_reports_target (target_type, target_id),
  KEY idx_reports_status (status),
  KEY idx_reports_reporter (reporter_id),
  KEY idx_reports_resolved_by (resolved_by),
  CONSTRAINT fk_reports_reporter FOREIGN KEY (reporter_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_reports_resolved_by FOREIGN KEY (resolved_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_reports_target
    CHECK (target_type IN ('instituicao','solicitacao','doacao','mensagem','usuario')),
  CONSTRAINT chk_reports_reason
    CHECK (reason IN ('fraude','conteudo_improprio','informacao_falsa','spam','seguranca','outro')),
  CONSTRAINT chk_reports_status CHECK (status IN ('aberta','em_analise','resolvida','arquivada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4.6 Auditoria de operações sensíveis.
CREATE TABLE IF NOT EXISTS audit_logs (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  actor_id    BIGINT UNSIGNED NULL,
  action      VARCHAR(60)     NOT NULL,
  entity_type VARCHAR(40)     NOT NULL,
  entity_id   BIGINT UNSIGNED NULL,
  old_values  JSON            NULL,
  new_values  JSON            NULL,
  ip_address  VARCHAR(45)     NULL,
  user_agent  VARCHAR(255)    NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_logs_actor (actor_id, created_at),
  KEY idx_audit_logs_entity (entity_type, entity_id),
  KEY idx_audit_logs_action (action, created_at),
  CONSTRAINT fk_audit_logs_actor FOREIGN KEY (actor_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4.7 Configurações do sistema (limites, prazos, textos padrão).
CREATE TABLE IF NOT EXISTS app_settings (
  setting_key   VARCHAR(80)     NOT NULL,
  setting_value VARCHAR(500)    NULL,
  value_type    VARCHAR(20)     NOT NULL DEFAULT 'string',
  description   VARCHAR(255)    NULL,
  updated_by    BIGINT UNSIGNED NULL,
  updated_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (setting_key),
  KEY idx_app_settings_updated_by (updated_by),
  CONSTRAINT fk_app_settings_updated_by FOREIGN KEY (updated_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT chk_app_settings_type CHECK (value_type IN ('string','int','decimal','bool','json'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4.8 Arquivos enviados (comprovantes, fotos, documentos).
CREATE TABLE IF NOT EXISTS uploads (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uploader_id BIGINT UNSIGNED NULL,
  entity_type VARCHAR(40)     NULL,
  entity_id   BIGINT UNSIGNED NULL,
  file_name   VARCHAR(255)    NOT NULL,
  mime_type   VARCHAR(100)    NOT NULL,
  file_size   INT UNSIGNED    NOT NULL,
  storage_path VARCHAR(500)   NOT NULL,
  public_url  VARCHAR(500)    NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_uploads_entity (entity_type, entity_id),
  KEY idx_uploads_uploader (uploader_id),
  CONSTRAINT fk_uploads_uploader FOREIGN KEY (uploader_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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

-- 5.8 Papel padrão: todos entram como doador.
INSERT IGNORE INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.code = 'doador'
WHERE u.legacy_user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id);
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
        WHEN CHAR_LENGTH(', @z_tel, ') = 10
          THEN CONCAT("+55", LEFT(', @z_tel, ', 2), "9", SUBSTRING(', @z_tel, ', 3))
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
