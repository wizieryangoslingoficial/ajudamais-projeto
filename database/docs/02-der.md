# DER — Diagrama de Entidade e Relacionamento — AjudaMais

Modelo do banco `ajudamais`: **39 tabelas base**, **5 views**, **76 chaves
estrangeiras**. Diagrama em Mermaid (renderiza no GitHub, no VS Code e no
MySQL Workbench via *Reverse Engineer*).

---

## Visão geral (domínios)

```mermaid
flowchart LR
  subgraph AUTH["1. Autenticação e LGPD"]
    users; roles; user_roles; sessions; verification_codes
    password_resets; terms_versions; terms_acceptances; consents; privacy_requests
  end
  subgraph LOCAL["2. Instituições e localização"]
    states; institutions; addresses; institution_members
    institution_documents; institution_payment_methods
    item_categories; item_units; campaigns; volunteer_profiles
  end
  subgraph DOA["3. Necessidades, doações e logística"]
    assistance_requests; request_items; request_status_history
    donations; donation_items; donation_status_history
    collection_points; deliveries
  end
  subgraph COM["4. Comunicação e operação"]
    conversations; conversation_participants; messages; notifications
    favorites; reviews; reports; audit_logs; app_settings; uploads
  end
  CTRL[schema_migrations]

  users --> AUTH
  institutions --> LOCAL
  donations --> DOA
```

---

## Núcleo: usuários, papéis e instituições

```mermaid
erDiagram
  USERS ||--o{ USER_ROLES : "possui"
  ROLES ||--o{ USER_ROLES : "atribuído a"
  USERS ||--o{ SESSIONS : "abre"
  USERS ||--o{ VERIFICATION_CODES : "recebe"
  USERS ||--o{ PASSWORD_RESETS : "solicita"
  USERS ||--o{ TERMS_ACCEPTANCES : "aceita"
  TERMS_VERSIONS ||--o{ TERMS_ACCEPTANCES : "versão aceita"
  USERS ||--o{ CONSENTS : "concede"
  USERS ||--o{ PRIVACY_REQUESTS : "solicita"
  USERS ||--o{ ADDRESSES : "tem"
  INSTITUTIONS ||--o{ ADDRESSES : "tem"
  INSTITUTIONS ||--o{ INSTITUTION_MEMBERS : "tem equipe"
  USERS ||--o{ INSTITUTION_MEMBERS : "participa"
  INSTITUTIONS ||--o{ INSTITUTION_DOCUMENTS : "envia"
  INSTITUTIONS ||--o{ INSTITUTION_PAYMENT_METHODS : "recebe em"
  INSTITUTIONS ||--o{ CAMPAIGNS : "cria"
  USERS ||--o{ VOLUNTEER_PROFILES : "é voluntário"
  STATES ||--o{ ADDRESSES : "UF"

  USERS {
    bigint id PK
    varchar full_name
    varchar email UK
    char cpf UK "11 dígitos"
    varchar phone_e164
    varchar password_hash
    varchar status "pendente|ativo|..."
    datetime deleted_at "exclusão lógica"
    int legacy_user_id "só na migration"
  }
  INSTITUTIONS {
    bigint id PK
    varchar legal_name
    char cnpj UK "14 dígitos"
    varchar email
    varchar phone_e164
    varchar status "pendente|verificada|..."
    datetime deleted_at
    int legacy_institution_id "só na migration"
  }
  ROLES {
    bigint id PK
    varchar code UK "doador|beneficiario|instituicao|moderador|admin|voluntario"
  }
```

---

## Necessidades → itens → doações

```mermaid
erDiagram
  INSTITUTIONS ||--o{ ASSISTANCE_REQUESTS : "publica"
  USERS ||--o{ ASSISTANCE_REQUESTS : "solicita"
  ASSISTANCE_REQUESTS ||--o{ REQUEST_ITEMS : "pede"
  ITEM_CATEGORIES ||--o{ REQUEST_ITEMS : "classifica"
  ITEM_UNITS ||--o{ REQUEST_ITEMS : "mede"
  ASSISTANCE_REQUESTS ||--o{ REQUEST_STATUS_HISTORY : "trilha"

  USERS ||--o{ DONATIONS : "dá (nulo se anônima)"
  INSTITUTIONS ||--o{ DONATIONS : "recebe"
  ASSISTANCE_REQUESTS ||--o{ DONATIONS : "atende"
  DONATIONS ||--o{ DONATION_ITEMS : "contém"
  REQUEST_ITEMS ||--o{ DONATION_ITEMS : "atendido por"
  ITEM_CATEGORIES ||--o{ DONATION_ITEMS : "classifica"
  DONATIONS ||--o{ DONATION_STATUS_HISTORY : "trilha"

  ASSISTANCE_REQUESTS {
    bigint id PK
    bigint institution_id FK
    bigint requester_user_id FK
    varchar title
    varchar status "aberta|atendida|cancelada|expirada"
    int legacy_request_id "só na migration"
  }
  REQUEST_ITEMS {
    bigint id PK
    bigint request_id FK
    bigint category_id FK
    varchar description
    varchar unit_code FK
    decimal quantity_requested
    varchar condition_required
  }
  DONATIONS {
    bigint id PK
    varchar code UK
    bigint donor_user_id FK "RESTRICT"
    varchar donor_name "anônima"
    varchar donor_email
    tinyint is_anonymous
    bigint institution_id FK
    bigint request_id FK
    varchar donation_type "itens|dinheiro"
    varchar status
    decimal amount "quando dinheiro"
    int legacy_donation_id "só na migration"
  }
  DONATION_ITEMS {
    bigint id PK
    bigint donation_id FK
    bigint request_item_id FK "define o % do pedido"
    bigint category_id FK
    decimal quantity
  }
```

**Regra declarativa da doação** (garantida pelo banco, não por código):

```sql
CONSTRAINT chk_donations_identifier
  CHECK ((donor_user_id IS NULL) = (is_anonymous = 1))
```

E ao excluir um usuário, a trigger `trg_users_before_delete` **anonimiza** as
doações dele antes do `DELETE`, preservando o histórico (LGPD).

---

## Logística

```mermaid
erDiagram
  INSTITUTIONS ||--o{ COLLECTION_POINTS : "mantém"
  ADDRESSES ||--o{ COLLECTION_POINTS : "localiza"
  COLLECTION_POINTS ||--o{ DELIVERIES : "origem"
  DONATIONS ||--o{ DELIVERIES : "transporta"
  USERS ||--o{ DELIVERIES : "responsável"

  DELIVERIES {
    bigint id PK
    bigint donation_id FK
    bigint collection_point_id FK
    varchar status
    datetime scheduled_at
  }
```

---

## Comunicação, engajamento e moderação

```mermaid
erDiagram
  CONVERSATIONS ||--o{ CONVERSATION_PARTICIPANTS : "tem"
  USERS ||--o{ CONVERSATION_PARTICIPANTS : "participa"
  CONVERSATIONS ||--o{ MESSAGES : "contém"
  USERS ||--o{ MESSAGES : "envia"
  USERS ||--o{ NOTIFICATIONS : "recebe"
  USERS ||--o{ FAVORITES : "salva"
  INSTITUTIONS ||--o{ FAVORITES : "favoritada"
  DONATIONS ||--o| REVIEWS : "avaliada"
  INSTITUTIONS ||--o{ REVIEWS : "recebe"
  USERS ||--o{ REPORTS : "denuncia"
  USERS ||--o{ AUDIT_LOGS : "autor"
  USERS ||--o{ UPLOADS : "envia"
```

---

## Colunas que existem apenas na migration

As colunas `legacy_user_id`, `legacy_institution_id`, `legacy_donation_id` e
`legacy_request_id` **não fazem parte de `01-schema.sql`**. Elas são criadas por
`02-migration.sql` para guardar o `id` da tabela antiga e impedir cópia duplicada
(nascem com `UNIQUE`). A tabela `role_legacy_backup` segue a mesma regra: só
existe depois da migration.

---

## Views (não são tabelas, servem de leitura pronta)

| View | Retorna |
|---|---|
| `v_institutions_public` | instituições ativas com contato e endereço principal |
| `v_request_items_progress` | cada item pedido com recebido, faltante e `computed_status` |
| `v_request_progress` | total pedido x recebido por necessidade e `percent_complete` |
| `v_donations_overview` | doações com doador, instituição e quantidade de itens |
| `v_institution_impact` | somas de itens, valores e necessidades por instituição |

---

## Regras de integridade aplicadas no banco

| Tipo | Quantidade | Exemplos |
|---|---|---|
| Chaves primárias | 39 | `id` em todas as tabelas |
| Chaves estrangeiras | 76 | com `RESTRICT`, `CASCADE` ou `SET NULL` conforme o caso |
| CHECK | 49 | CPF/CNPJ/CEP com 11/14/8 dígitos, status válido, quantidades ≥ 0, `chk_donations_identifier` |
| UNIQUE | várias | `users.email`, `users.cpf`, `institutions.cnpj`, `donations.code` |
| Trigger | 1 | anonimização de doações ao excluir usuário |
| Índices | 149 | chaves estrangeiras e colunas de busca/filtro |

> **Como abrir o DER no MySQL Workbench:** menu *Database → Reverse Engineer*
> (Ctrl+R), aponte para a conexão local, escolha o schema `ajudamais` e marque
> as tabelas. O Workbench desenha as relações a partir das 76 FKs reais.
