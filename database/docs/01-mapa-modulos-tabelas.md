# Mapa módulo → tabelas — AjudaMais

Cada módulo do sistema (tela ou conjunto de telas) e as tabelas que ele usa.
Serve para saber o que o backend precisa consultar em cada rota.

> **Legenda de acesso:** `L` leitura · `E` escrita · `A` apenas admin/moderador

---

## 1. Autenticação e conta

| Módulo | Tela / arquivo | Tabelas | Acesso |
|---|---|---|---|
| Cadastro | `cadastro.html` | `users`, `addresses`, `terms_versions`, `terms_acceptances`, `consents`, `verification_codes`, `roles`, `user_roles` | L E |
| Login | `login.html` | `users`, `sessions`, `user_roles`, `roles` | L E |
| Recuperar conta | `recuperar-conta.html` | `users`, `verification_codes`, `password_resets`, `sessions` | L E |
| Esqueci a senha | `esqueci-senha.html` | `users`, `password_resets` | L E |
| Termos e privacidade | `termos.html` | `terms_versions`, `terms_acceptances`, `consents`, `privacy_requests` | L E |
| Sair da conta / encerrar sessão | todas | `sessions` | E |
| Exclusão de conta (LGPD) | perfil | `privacy_requests`, `users.deleted_at`, `audit_logs` | E |

**Observação:** a senha nunca é guardada em texto puro em `users.password_hash`
(hash bcrypt/argon2). O token de sessão também não é guardado: `sessions` recebe
apenas o hash, conforme comentário da tabela.

---

## 2. Início (pagina inicial)

| Módulo | Tela | Tabelas / view | Acesso |
|---|---|---|---|
| Busca de instituições | `index.html` | `v_institutions_public`, `states`, `item_categories` | L |
| Filtros por estado e categoria | `index.html` | `states`, `item_categories` | L |
| Destaques e impacto | `index.html` | `v_institution_impact`, `campaigns` | L |
| Contadores da home | `index.html` | `donations`, `assistance_requests`, `institutions` | L |

---

## 3. Instituições

| Módulo | Tabelas | Acesso |
|---|---|---|
| Perfil público da instituição | `v_institutions_public`, `addresses`, `institution_payment_methods`, `reviews` | L |
| Cadastro / edição da instituição | `institutions`, `addresses`, `institution_documents`, `institution_members`, `institution_payment_methods` | L E |
| Verificação de documentos | `institution_documents`, `audit_logs` | A |
| Equipe da instituição | `institution_members`, `users`, `roles`, `user_roles` | L E |
| Formas de doação em dinheiro (Pix/conta) | `institution_payment_methods` | L E |
| Avaliações recebidas | `reviews`, `donations` | L |

---

## 4. Necessidades (pedidos de ajuda)

| Módulo | Tabelas / view | Acesso |
|---|---|---|
| Listar necessidades | `assistance_requests`, `request_items`, `v_request_progress`, `v_request_items_progress` | L |
| Detalhe da necessidade | `assistance_requests`, `request_items`, `v_request_items_progress`, `institutions` | L |
| Criar / editar necessidade | `assistance_requests`, `request_items`, `item_categories`, `item_units` | L E |
| Acompanhar progresso | `v_request_progress`, `request_status_history` | L |
| Encerrar necessidade | `assistance_requests`, `request_status_history`, `audit_logs` | E |

**Regra de negócio:** `v_request_progress.percent_complete` conta **apenas** itens
de doação vinculados a um item do pedido (`donation_items.request_item_id`).
Doações sem vínculo não entram no percentual — é o comportamento correto e testado.

---

## 5. Doações

| Módulo | Tabelas / view | Acesso |
|---|---|---|
| Doar itens | `donations`, `donation_items`, `request_items`, `item_categories`, `item_units`, `collection_points` | L E |
| Doar dinheiro | `donations`, `institution_payment_methods` | L E |
| Doação anônima | `donations` (`is_anonymous = 1`, `donor_user_id` nulo) | E |
| Meus comprovantes | `donations`, `uploads`, `v_donations_overview` | L E |
| Painel de doações (instituição) | `v_donations_overview`, `donation_status_history` | L |
| Confirmar recebimento | `donations.status`, `donation_status_history`, `request_items.quantity_received` | E |

**Regras garantidas pelo banco:**
- `chk_donations_identifier`: `(donor_user_id IS NULL) = (is_anonymous = 1)` —
  não existe doação anônima com doador nem doação identificada sem doador.
- `donations.donor_user_id` usa `ON DELETE RESTRICT` + trigger de anonimização:
  ao excluir a conta, as doações continuam existindo e viram anônimas (LGPD).

---

## 6. Logística e entrega

| Módulo | Tabelas | Acesso |
|---|---|---|
| Pontos de coleta | `collection_points`, `addresses`, `institutions` | L E |
| Agendar entrega | `deliveries`, `donations`, `collection_points` | L E |
| Acompanhar entrega | `deliveries`, `donation_status_history` | L E |

---

## 7. Campanhas e voluntariado

| Módulo | Tabelas | Acesso |
|---|---|---|
| Campanhas | `campaigns`, `institutions`, `uploads` | L E |
| Inscrever-se como voluntário | `volunteer_profiles`, `users` | L E |
| Gerenciar voluntários | `volunteer_profiles`, `institution_members` | L E |

---

## 8. Comunicação

| Módulo | Tabelas | Acesso |
|---|---|---|
| Conversas (Contatos) | `conversations`, `conversation_participants`, `messages` | L E |
| Notificações | `notifications` | L E |
| Favoritos | `favorites` | L E |

---

## 9. Moderação e administração

| Módulo | Tabelas | Acesso |
|---|---|---|
| Denúncias | `reports`, `audit_logs` | A |
| Auditoria | `audit_logs` | A |
| Configurações do sistema | `app_settings` | A |
| Papéis e permissões | `roles`, `user_roles` | A |
| Solicitações LGPD | `privacy_requests`, `audit_logs` | A |

---

## 10. Infraestrutura

| Tabela | Uso |
|---|---|
| `schema_migrations` | registra as migrations aplicadas (idempotência) |
| `uploads` | metadados de arquivos enviados |
| `app_settings` | limites, prazos e textos padrão |
| `audit_logs` | trilha de operações sensíveis |

---

## Resumo por tabela (39 tabelas + controle de versão)

| Área | Tabelas |
|---|---|
| Auth / LGPD (10) | `users`, `roles`, `user_roles`, `sessions`, `verification_codes`, `password_resets`, `terms_versions`, `terms_acceptances`, `consents`, `privacy_requests` |
| Local / instituições (9) | `states`, `institutions`, `addresses`, `institution_members`, `institution_documents`, `institution_payment_methods`, `item_categories`, `item_units`, `campaigns` |
| Voluntariado (1) | `volunteer_profiles` |
| Necessidades (4) | `assistance_requests`, `request_items`, `request_status_history`, `reports` |
| Doações (5) | `donations`, `donation_items`, `donation_status_history`, `collection_points`, `deliveries` |
| Comunicação (5) | `conversations`, `conversation_participants`, `messages`, `notifications`, `favorites` |
| Moderação / operação (4) | `reviews`, `audit_logs`, `app_settings`, `uploads` |
| Controle (1) | `schema_migrations` |

> Total: **39 tabelas base** + **5 views** + **76 chaves estrangeiras** + **49 CHECK** + **1 trigger**.

> A tabela extra `role_legacy_backup` é criada **apenas pela migration**
> (`02-migration.sql`), para guardar o campo `tipo` do banco antigo. Ela não faz
> parte do schema novo.
