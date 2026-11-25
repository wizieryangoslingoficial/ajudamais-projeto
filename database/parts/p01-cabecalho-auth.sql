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
