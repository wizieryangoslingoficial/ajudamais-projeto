<!-- Arquivo gerado por database/tools/gerar-docs.sh — não editar à mão. -->

## Dicionário de dados (gerado do banco)

Tabelas base: 39 · Colunas: 414 · Chaves estrangeiras: 76 · Verificações: 51 · Índices: 149

### `addresses`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `institution_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `label` | varchar(60) | sim | — | NULL | Ex.: Casa, Trabalho, Sede, Ponto de coleta |
| `address_type` | varchar(20) | não | — | 'residencial' |  |
| `postal_code` | char(8) | sim | MUL | NULL | CEP só com dígitos |
| `street` | varchar(180) | não | — | — |  |
| `number` | varchar(20) | sim | — | NULL |  |
| `complement` | varchar(120) | sim | — | NULL |  |
| `district` | varchar(120) | sim | — | NULL |  |
| `city` | varchar(120) | não | — | — |  |
| `state_code` | char(2) | sim | MUL | NULL |  |
| `country_code` | char(2) | não | — | 'BR' |  |
| `latitude` | decimal(10,7) | sim | — | NULL |  |
| `longitude` | decimal(10,7) | sim | — | NULL |  |
| `reference_point` | varchar(180) | sim | — | NULL |  |
| `is_primary` | tinyint(1) | não | — | 0 |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)
- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)
- `state_code` → `states.``code``  (ON DELETE SET NULL)

### `app_settings`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `setting_key` | varchar(80) | não | PRI | — |  |
| `setting_value` | varchar(500) | sim | — | NULL |  |
| `value_type` | varchar(20) | não | — | 'string' |  |
| `description` | varchar(255) | sim | — | NULL |  |
| `updated_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `updated_by` → `users.``id``  (ON DELETE SET NULL)

### `assistance_requests`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `institution_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `requester_user_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `campaign_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `title` | varchar(150) | não | — | — |  |
| `description` | text | sim | — | NULL |  |
| `category_id` | smallint(5) unsigned | sim | MUL | NULL | Categoria principal, usada em filtros |
| `priority` | varchar(20) | não | — | 'normal' |  |
| `beneficiary_count` | smallint(5) unsigned | sim | — | NULL | Quantas pessoas serão atendidas |
| `city` | varchar(120) | sim | — | NULL |  |
| `state_code` | char(2) | sim | MUL | NULL |  |
| `address_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `is_public` | tinyint(1) | não | MUL | 1 |  |
| `allows_anonymous` | tinyint(1) | não | — | 1 |  |
| `needed_by` | date | sim | — | NULL |  |
| `status` | varchar(20) | não | — | 'aberta' |  |
| `published_at` | datetime | sim | — | NULL |  |
| `closed_at` | datetime | sim | — | NULL |  |
| `close_reason` | varchar(255) | sim | — | NULL |  |
| `moderated_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `moderated_at` | datetime | sim | — | NULL |  |
| `deleted_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `category_id` → `item_categories.``id``  (ON DELETE SET NULL)
- `requester_user_id` → `users.``id``  (ON DELETE CASCADE)
- `address_id` → `addresses.``id``  (ON DELETE SET NULL)
- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)
- `state_code` → `states.``code``  (ON DELETE SET NULL)
- `campaign_id` → `campaigns.``id``  (ON DELETE SET NULL)
- `moderated_by` → `users.``id``  (ON DELETE SET NULL)

### `audit_logs`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `actor_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `action` | varchar(60) | não | MUL | — |  |
| `entity_type` | varchar(40) | não | MUL | — |  |
| `entity_id` | bigint(20) unsigned | sim | — | NULL |  |
| `old_values` | longtext | sim | — | NULL |  |
| `new_values` | longtext | sim | — | NULL |  |
| `ip_address` | varchar(45) | sim | — | NULL |  |
| `user_agent` | varchar(255) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `actor_id` → `users.``id``  (ON DELETE SET NULL)

### `campaigns`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `institution_id` | bigint(20) unsigned | não | MUL | — |  |
| `title` | varchar(150) | não | — | — |  |
| `slug` | varchar(160) | não | UNI | — |  |
| `description` | text | sim | — | NULL |  |
| `cover_url` | varchar(500) | sim | — | NULL |  |
| `goal_type` | varchar(10) | não | — | 'itens' |  |
| `goal_amount` | decimal(12,2) | sim | — | NULL |  |
| `goal_quantity` | int(10) unsigned | sim | — | NULL |  |
| `starts_at` | datetime | não | — | current_timestamp() |  |
| `ends_at` | datetime | sim | — | NULL |  |
| `status` | varchar(20) | não | MUL | 'rascunho' |  |
| `created_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `created_by` → `users.``id``  (ON DELETE SET NULL)
- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)

### `collection_points`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `institution_id` | bigint(20) unsigned | não | MUL | — |  |
| `address_id` | bigint(20) unsigned | não | MUL | — |  |
| `name` | varchar(120) | não | — | — |  |
| `instructions` | varchar(500) | sim | — | NULL |  |
| `opening_hours` | varchar(120) | sim | — | NULL | Ex.: seg a sex, 9h às 17h |
| `contact_phone` | varchar(16) | sim | — | NULL |  |
| `accepts_items` | tinyint(1) | não | — | 1 |  |
| `is_active` | tinyint(1) | não | — | 1 |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `address_id` → `addresses.``id``  (ON DELETE CASCADE)
- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)

### `consents`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | não | MUL | — |  |
| `type` | varchar(30) | não | — | — |  |
| `granted` | tinyint(1) | não | — | 1 |  |
| `version` | varchar(20) | sim | — | NULL |  |
| `ip_address` | varchar(45) | sim | — | NULL |  |
| `granted_at` | datetime | não | — | current_timestamp() |  |
| `revoked_at` | datetime | sim | — | NULL |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)

### `conversations`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `subject` | varchar(150) | sim | — | NULL |  |
| `donation_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `request_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `institution_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `created_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `status` | varchar(20) | não | MUL | 'aberta' |  |
| `last_message_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `institution_id` → `institutions.``id``  (ON DELETE SET NULL)
- `created_by` → `users.``id``  (ON DELETE SET NULL)
- `request_id` → `assistance_requests.``id``  (ON DELETE SET NULL)
- `donation_id` → `donations.``id``  (ON DELETE SET NULL)

### `conversation_participants`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `conversation_id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | não | PRI | — |  |
| `participant_role` | varchar(20) | não | — | 'membro' |  |
| `last_read_at` | datetime | sim | — | NULL |  |
| `joined_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `conversation_id` → `conversations.``id``  (ON DELETE CASCADE)
- `user_id` → `users.``id``  (ON DELETE CASCADE)

### `deliveries`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `donation_id` | bigint(20) unsigned | não | MUL | — |  |
| `method` | varchar(20) | não | — | — |  |
| `collection_point_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `origin_address_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `destination_address_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `carrier_name` | varchar(120) | sim | — | NULL |  |
| `tracking_code` | varchar(60) | sim | — | NULL |  |
| `scheduled_at` | datetime | sim | — | NULL |  |
| `picked_up_at` | datetime | sim | — | NULL |  |
| `delivered_at` | datetime | sim | — | NULL |  |
| `status` | varchar(20) | não | MUL | 'agendada' |  |
| `proof_url` | varchar(500) | sim | — | NULL |  |
| `recipient_name` | varchar(150) | sim | — | NULL |  |
| `notes` | varchar(500) | sim | — | NULL |  |
| `created_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `donation_id` → `donations.``id``  (ON DELETE CASCADE)
- `created_by` → `users.``id``  (ON DELETE SET NULL)
- `origin_address_id` → `addresses.``id``  (ON DELETE SET NULL)
- `destination_address_id` → `addresses.``id``  (ON DELETE SET NULL)
- `collection_point_id` → `collection_points.``id``  (ON DELETE SET NULL)

### `donations`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `code` | varchar(20) | não | UNI | — | Código curto exibido ao doador |
| `donor_user_id` | bigint(20) unsigned | sim | MUL | NULL | Nulo em doação anônima |
| `donor_name` | varchar(150) | sim | — | NULL | Nome informado no fluxo anônimo (opcional) |
| `donor_email` | varchar(254) | sim | — | NULL | Contato para acompanhamento da doação |
| `is_anonymous` | tinyint(1) | não | — | 0 |  |
| `show_name_publicly` | tinyint(1) | não | — | 1 |  |
| `institution_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `request_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `campaign_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `donation_type` | varchar(10) | não | — | 'itens' |  |
| `status` | varchar(20) | não | MUL | 'pendente' |  |
| `amount` | decimal(12,2) | sim | — | NULL |  |
| `payment_method` | varchar(20) | sim | — | NULL |  |
| `payment_status` | varchar(20) | sim | MUL | NULL |  |
| `payment_reference` | varchar(120) | sim | — | NULL |  |
| `paid_at` | datetime | sim | — | NULL |  |
| `dropoff_address_id` | bigint(20) unsigned | sim | MUL | NULL | Endereço de retirada informado pelo doador |
| `scheduled_at` | datetime | sim | — | NULL |  |
| `message` | varchar(500) | sim | — | NULL |  |
| `cancel_reason` | varchar(255) | sim | — | NULL |  |
| `confirmed_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `confirmed_at` | datetime | sim | — | NULL |  |
| `deleted_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `donor_user_id` → `users.``id``  (ON DELETE RESTRICT)
- `request_id` → `assistance_requests.``id``  (ON DELETE SET NULL)
- `campaign_id` → `campaigns.``id``  (ON DELETE SET NULL)
- `dropoff_address_id` → `addresses.``id``  (ON DELETE SET NULL)
- `confirmed_by` → `users.``id``  (ON DELETE SET NULL)
- `institution_id` → `institutions.``id``  (ON DELETE SET NULL)

### `donation_items`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `donation_id` | bigint(20) unsigned | não | MUL | — |  |
| `request_item_id` | bigint(20) unsigned | sim | MUL | NULL | Item da necessidade que esta doação atende |
| `category_id` | smallint(5) unsigned | sim | MUL | NULL |  |
| `description` | varchar(200) | não | — | — |  |
| `unit_code` | varchar(10) | não | MUL | 'un' |  |
| `quantity` | decimal(10,2) | não | — | — |  |
| `item_condition` | varchar(20) | não | — | 'usado' |  |
| `size` | varchar(30) | sim | — | NULL |  |
| `gender` | varchar(20) | sim | — | NULL |  |
| `brand` | varchar(80) | sim | — | NULL |  |
| `expires_on` | date | sim | — | NULL | Validade para alimentos e medicamentos |
| `photo_url` | varchar(500) | sim | — | NULL |  |
| `notes` | varchar(255) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `request_item_id` → `request_items.``id``  (ON DELETE SET NULL)
- `category_id` → `item_categories.``id``  (ON DELETE SET NULL)
- `unit_code` → `item_units.``code``  (ON DELETE RESTRICT)
- `donation_id` → `donations.``id``  (ON DELETE CASCADE)

### `donation_status_history`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `donation_id` | bigint(20) unsigned | não | MUL | — |  |
| `from_status` | varchar(20) | sim | — | NULL |  |
| `to_status` | varchar(20) | não | — | — |  |
| `changed_by` | bigint(20) unsigned | sim | MUL | NULL | Nulo quando a mudança é automática |
| `note` | varchar(255) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `changed_by` → `users.``id``  (ON DELETE SET NULL)
- `donation_id` → `donations.``id``  (ON DELETE CASCADE)

### `favorites`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | não | MUL | — |  |
| `institution_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `request_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)
- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)
- `request_id` → `assistance_requests.``id``  (ON DELETE CASCADE)

### `institutions`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `legal_name` | varchar(180) | não | MUL | — |  |
| `trade_name` | varchar(150) | sim | — | NULL |  |
| `cnpj` | char(14) | sim | UNI | NULL |  |
| `institution_type` | varchar(30) | não | MUL | 'ong' |  |
| `description` | text | sim | — | NULL |  |
| `mission` | varchar(500) | sim | — | NULL |  |
| `logo_url` | varchar(500) | sim | — | NULL |  |
| `cover_url` | varchar(500) | sim | — | NULL |  |
| `email` | varchar(254) | não | — | — |  |
| `phone_e164` | varchar(16) | sim | — | NULL |  |
| `whatsapp_e164` | varchar(16) | sim | — | NULL |  |
| `website_url` | varchar(500) | sim | — | NULL |  |
| `instagram_handle` | varchar(80) | sim | — | NULL |  |
| `founded_year` | smallint(5) unsigned | sim | — | NULL |  |
| `accepts_items` | tinyint(1) | não | — | 1 |  |
| `accepts_money` | tinyint(1) | não | — | 0 |  |
| `accepts_volunteers` | tinyint(1) | não | — | 0 |  |
| `status` | varchar(20) | não | MUL | 'pendente' |  |
| `verified_at` | datetime | sim | — | NULL |  |
| `verified_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `rejection_reason` | varchar(255) | sim | — | NULL |  |
| `deleted_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `verified_by` → `users.``id``  (ON DELETE SET NULL)

### `institution_documents`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `institution_id` | bigint(20) unsigned | não | MUL | — |  |
| `document_type` | varchar(30) | não | — | — |  |
| `file_url` | varchar(500) | não | — | — |  |
| `status` | varchar(20) | não | MUL | 'pendente' |  |
| `reviewed_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `reviewed_at` | datetime | sim | — | NULL |  |
| `notes` | varchar(255) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)
- `reviewed_by` → `users.``id``  (ON DELETE SET NULL)

### `institution_members`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `institution_id` | bigint(20) unsigned | não | MUL | — |  |
| `user_id` | bigint(20) unsigned | não | MUL | — |  |
| `member_role` | varchar(20) | não | — | 'voluntario' |  |
| `status` | varchar(20) | não | — | 'ativo' |  |
| `invited_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `joined_at` | datetime | não | — | current_timestamp() |  |
| `left_at` | datetime | sim | — | NULL |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)
- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)
- `invited_by` → `users.``id``  (ON DELETE SET NULL)

### `institution_payment_methods`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `institution_id` | bigint(20) unsigned | não | MUL | — |  |
| `method` | varchar(20) | não | — | — |  |
| `pix_key` | varchar(140) | sim | — | NULL |  |
| `pix_key_type` | varchar(20) | sim | — | NULL |  |
| `bank_name` | varchar(80) | sim | — | NULL |  |
| `bank_code` | varchar(10) | sim | — | NULL |  |
| `branch` | varchar(20) | sim | — | NULL |  |
| `account_number` | varchar(30) | sim | — | NULL |  |
| `account_type` | varchar(20) | sim | — | NULL |  |
| `holder_name` | varchar(150) | sim | — | NULL |  |
| `is_active` | tinyint(1) | não | — | 1 |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)

### `item_categories`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | smallint(5) unsigned | não | PRI | — |  |
| `parent_id` | smallint(5) unsigned | sim | MUL | NULL |  |
| `slug` | varchar(60) | não | UNI | — |  |
| `name` | varchar(100) | não | — | — |  |
| `icon` | varchar(60) | sim | — | NULL |  |
| `sort_order` | smallint(6) | não | — | 0 |  |
| `is_active` | tinyint(1) | não | — | 1 |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `parent_id` → `item_categories.``id``  (ON DELETE SET NULL)

### `item_units`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `code` | varchar(10) | não | PRI | — |  |
| `name` | varchar(40) | não | — | — |  |

### `messages`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `conversation_id` | bigint(20) unsigned | não | MUL | — |  |
| `sender_user_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `body` | text | não | — | — |  |
| `attachment_url` | varchar(500) | sim | — | NULL |  |
| `read_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `conversation_id` → `conversations.``id``  (ON DELETE CASCADE)
- `sender_user_id` → `users.``id``  (ON DELETE SET NULL)

### `notifications`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | não | MUL | — |  |
| `type` | varchar(40) | não | — | — |  |
| `title` | varchar(150) | não | — | — |  |
| `body` | varchar(500) | sim | — | NULL |  |
| `link_url` | varchar(500) | sim | — | NULL |  |
| `entity_type` | varchar(30) | sim | MUL | NULL |  |
| `entity_id` | bigint(20) unsigned | sim | — | NULL |  |
| `read_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)

### `password_resets`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | não | MUL | — |  |
| `token_hash` | char(64) | não | UNI | — |  |
| `ip_address` | varchar(45) | sim | — | NULL |  |
| `expires_at` | datetime | não | — | — |  |
| `used_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)

### `privacy_requests`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `email` | varchar(254) | não | — | — | Contato de quem pediu, mesmo sem conta |
| `type` | varchar(20) | não | — | — |  |
| `details` | text | sim | — | NULL |  |
| `status` | varchar(20) | não | MUL | 'recebida' |  |
| `response` | text | sim | — | NULL |  |
| `handled_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `requested_at` | datetime | não | — | current_timestamp() |  |
| `resolved_at` | datetime | sim | — | NULL |  |

**Referencia:**

- `handled_by` → `users.``id``  (ON DELETE SET NULL)
- `user_id` → `users.``id``  (ON DELETE SET NULL)

### `reports`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `reporter_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `target_type` | varchar(20) | não | MUL | — |  |
| `target_id` | bigint(20) unsigned | não | — | — |  |
| `reason` | varchar(40) | não | — | — |  |
| `details` | text | sim | — | NULL |  |
| `status` | varchar(20) | não | MUL | 'aberta' |  |
| `resolution_note` | varchar(500) | sim | — | NULL |  |
| `resolved_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `resolved_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `reporter_id` → `users.``id``  (ON DELETE SET NULL)
- `resolved_by` → `users.``id``  (ON DELETE SET NULL)

### `request_items`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `request_id` | bigint(20) unsigned | não | MUL | — |  |
| `category_id` | smallint(5) unsigned | sim | MUL | NULL |  |
| `description` | varchar(200) | não | — | — |  |
| `unit_code` | varchar(10) | não | MUL | 'un' |  |
| `quantity_requested` | decimal(10,2) | não | — | — |  |
| `size` | varchar(30) | sim | — | NULL |  |
| `gender` | varchar(20) | sim | — | NULL |  |
| `condition_required` | varchar(20) | sim | — | NULL |  |
| `notes` | varchar(255) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `unit_code` → `item_units.``code``  (ON DELETE RESTRICT)
- `category_id` → `item_categories.``id``  (ON DELETE SET NULL)
- `request_id` → `assistance_requests.``id``  (ON DELETE CASCADE)

### `request_status_history`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `request_id` | bigint(20) unsigned | não | MUL | — |  |
| `from_status` | varchar(20) | sim | — | NULL |  |
| `to_status` | varchar(20) | não | — | — |  |
| `changed_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `note` | varchar(255) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `changed_by` → `users.``id``  (ON DELETE SET NULL)
- `request_id` → `assistance_requests.``id``  (ON DELETE CASCADE)

### `reviews`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `donation_id` | bigint(20) unsigned | sim | UNI | NULL |  |
| `institution_id` | bigint(20) unsigned | não | MUL | — |  |
| `reviewer_id` | bigint(20) unsigned | não | MUL | — |  |
| `rating` | tinyint(3) unsigned | não | — | — |  |
| `comment` | varchar(500) | sim | — | NULL |  |
| `status` | varchar(20) | não | — | 'publicada' |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `reviewer_id` → `users.``id``  (ON DELETE CASCADE)
- `donation_id` → `donations.``id``  (ON DELETE SET NULL)
- `institution_id` → `institutions.``id``  (ON DELETE CASCADE)

### `roles`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | smallint(5) unsigned | não | PRI | — |  |
| `code` | varchar(30) | não | UNI | — |  |
| `name` | varchar(80) | não | — | — |  |
| `description` | varchar(255) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

### `schema_migrations`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `version` | varchar(40) | não | UNI | — |  |
| `description` | varchar(255) | não | — | — |  |
| `applied_at` | datetime | não | — | current_timestamp() |  |

### `sessions`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | não | MUL | — |  |
| `token_hash` | char(64) | não | UNI | — |  |
| `ip_address` | varchar(45) | sim | — | NULL |  |
| `user_agent` | varchar(255) | sim | — | NULL |  |
| `device_label` | varchar(80) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `last_used_at` | datetime | sim | — | NULL |  |
| `expires_at` | datetime | não | MUL | — |  |
| `revoked_at` | datetime | sim | — | NULL |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)

### `states`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `code` | char(2) | não | PRI | — |  |
| `name` | varchar(60) | não | — | — |  |
| `region` | varchar(20) | não | — | — |  |

### `terms_acceptances`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | sim | MUL | NULL | Nulo quando o aceite ocorre antes de haver conta |
| `terms_version_id` | bigint(20) unsigned | não | MUL | — |  |
| `anonymous_id` | char(36) | sim | MUL | NULL | Identifica o aceite na tela inicial sem login |
| `ip_address` | varchar(45) | sim | — | NULL |  |
| `user_agent` | varchar(255) | sim | — | NULL |  |
| `accepted_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE SET NULL)
- `terms_version_id` → `terms_versions.``id``  (ON DELETE RESTRICT)

### `terms_versions`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `version` | varchar(20) | não | UNI | — |  |
| `title` | varchar(150) | não | — | — |  |
| `body` | mediumtext | sim | — | NULL |  |
| `body_url` | varchar(500) | sim | — | NULL |  |
| `effective_at` | datetime | não | — | current_timestamp() |  |
| `is_current` | tinyint(1) | não | — | 1 |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

### `uploads`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `uploader_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `entity_type` | varchar(40) | sim | MUL | NULL |  |
| `entity_id` | bigint(20) unsigned | sim | — | NULL |  |
| `file_name` | varchar(255) | não | — | — |  |
| `mime_type` | varchar(100) | não | — | — |  |
| `file_size` | int(10) unsigned | não | — | — |  |
| `storage_path` | varchar(500) | não | — | — |  |
| `public_url` | varchar(500) | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `uploader_id` → `users.``id``  (ON DELETE SET NULL)

### `users`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `full_name` | varchar(150) | não | — | — |  |
| `display_name` | varchar(80) | sim | — | NULL |  |
| `email` | varchar(254) | não | UNI | — |  |
| `email_verified_at` | datetime | sim | — | NULL |  |
| `cpf` | char(11) | não | UNI | — |  |
| `cpf_verified_at` | datetime | sim | — | NULL |  |
| `govbr_sub` | varchar(64) | sim | UNI | NULL | Claim sub devolvida pelo Gov.br |
| `govbr_verified_at` | datetime | sim | — | NULL |  |
| `phone_e164` | varchar(16) | sim | UNI | NULL | Celular como +5511999999999 |
| `phone_verified_at` | datetime | sim | — | NULL |  |
| `birth_date` | date | sim | — | NULL |  |
| `password_hash` | varchar(255) | não | — | — |  |
| `password_algo` | varchar(20) | não | — | 'bcrypt' |  |
| `must_change_password` | tinyint(1) | não | — | 0 |  |
| `avatar_url` | varchar(500) | sim | — | NULL |  |
| `status` | varchar(20) | não | MUL | 'pendente' |  |
| `login_attempts` | smallint(5) unsigned | não | — | 0 |  |
| `locked_until` | datetime | sim | — | NULL |  |
| `last_login_at` | datetime | sim | — | NULL |  |
| `terms_accepted_at` | datetime | sim | — | NULL |  |
| `deleted_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | MUL | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

### `user_roles`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `user_id` | bigint(20) unsigned | não | PRI | — |  |
| `role_id` | smallint(5) unsigned | não | PRI | — |  |
| `granted_by` | bigint(20) unsigned | sim | MUL | NULL |  |
| `granted_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)
- `granted_by` → `users.``id``  (ON DELETE SET NULL)
- `role_id` → `roles.``id``  (ON DELETE CASCADE)

### `verification_codes`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `id` | bigint(20) unsigned | não | PRI | — |  |
| `user_id` | bigint(20) unsigned | sim | MUL | NULL |  |
| `channel` | varchar(10) | não | — | — |  |
| `destination` | varchar(254) | não | MUL | — | E-mail ou celular que recebeu o código |
| `purpose` | varchar(30) | não | — | — |  |
| `code_hash` | char(64) | não | — | — |  |
| `attempts` | tinyint(3) unsigned | não | — | 0 |  |
| `ip_address` | varchar(45) | sim | — | NULL |  |
| `expires_at` | datetime | não | — | — |  |
| `verified_at` | datetime | sim | — | NULL |  |
| `consumed_at` | datetime | sim | — | NULL |  |
| `created_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)

### `volunteer_profiles`

| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |
|---|---|---|---|---|---|
| `user_id` | bigint(20) unsigned | não | PRI | — |  |
| `bio` | varchar(500) | sim | — | NULL |  |
| `skills` | varchar(500) | sim | — | NULL |  |
| `availability` | varchar(120) | sim | — | NULL | Ex.: seg/qua à tarde |
| `has_transport` | tinyint(1) | não | — | 0 |  |
| `max_distance_km` | smallint(5) unsigned | sim | — | NULL |  |
| `status` | varchar(20) | não | — | 'ativo' |  |
| `created_at` | datetime | não | — | current_timestamp() |  |
| `updated_at` | datetime | não | — | current_timestamp() |  |

**Referencia:**

- `user_id` → `users.``id``  (ON DELETE CASCADE)

