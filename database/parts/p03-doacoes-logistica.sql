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
