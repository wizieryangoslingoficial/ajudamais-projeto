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
