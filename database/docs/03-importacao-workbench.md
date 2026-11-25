# Como importar o banco no MySQL Workbench (Windows)

Dois arquivos, dois cenários. Escolha **um** deles.

| Arquivo | Quando usar |
|---|---|
| `01-schema.sql` | Começar do zero (banco novo, sem dados antigos) |
| `02-migration.sql` | Você **já tem** o banco antigo e quer migrar os dados |

> Os dois arquivos são **idempotentes**: podem ser executados mais de uma vez
> sem duplicar tabelas nem dados. Nenhum deles apaga dados existentes.

---

## Antes de começar

1. MySQL Server instalado e rodando (serviço `MySQL80`).
2. MySQL Workbench aberto e conectado na conexão local (`Local instance`).
3. Faça **backup** do banco antigo antes da migration:
   ```
   Server → Data Export → selecione o schema → Export to Self-Contained File
   ```

---

## Cenário A — banco novo (`01-schema.sql`)

1. No Workbench: **File → Open SQL Script…** e escolha `database/01-schema.sql`.
2. Confira o seletor de schema no topo (deve estar vazio ou em outro schema).
3. Clique no **raio** (⚡ *Execute*).
4. Se aparecer erro de "database não existe", rode antes:

   ```sql
   CREATE DATABASE IF NOT EXISTS ajudamais
     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

   O próprio `01-schema.sql` já cria o banco com esse charset — o comando acima
   só é necessário se você preferir criar manualmente.
5. **Confira o resultado:**

   ```sql
   USE ajudamais;
   SHOW TABLES;                          -- 39 tabelas
   SELECT COUNT(*) FROM item_categories; -- 24
   SELECT COUNT(*) FROM states;          -- 27
   ```

6. Recarregue a lista de schemas no painel esquerdo (botão de refresh) para ver
   as tabelas e as 5 views.

### Importante sobre acentos

O arquivo já contém `SET NAMES utf8mb4;` e cria tudo em `utf8mb4`. Se os acentos
aparecerem quebrados **depois** de importar, verifique a conexão:

- **Database → Manage Connections → Advanced → Others:** `--default-character-set=utf8mb4`
- No Windows, edite `my.ini` e confirme `character-set-server=utf8mb4`.

---

## Cenário B — migrar o banco antigo (`02-migration.sql`)

A migration foi feita para **não presumir** a estrutura antiga. Ela verifica
quais colunas existem antes de usá-las.

### Passo a passo

1. Faça o backup (acima).
2. Abra `database/02-migration.sql` no Workbench (**File → Open SQL Script…**).
3. **Selecione o schema do banco antigo** no painel esquerdo (duplo clique nele
   para ficar em negrito). A migration usa o banco selecionado — ela não troca
   de schema por conta própria.
4. Execute com o raio (⚡).
5. Ao final, aparece um resumo:

   | Coluna | Significado |
   |---|---|
   | `versoes_registradas` | migrations aplicadas (deve ser 2) |
   | `usuarios_migrados` | linhas copiadas de `usuarios` |
   | `instituicoes_migradas` | linhas copiadas de `instituicoes` |
   | `doacoes_migradas` | linhas copiadas de `doacoes` |
   | `solicitacoes_migradas` | linhas copiadas de `solicitacoes` |

6. Rodar de novo é seguro: os totais repetem os mesmos valores, sem duplicar.

### O que a migration faz com os dados

| Origem | Destino | Regra |
|---|---|---|
| `usuarios` | `users` | CPF só dígitos; telefone em `+55…`; senha preservada em `password_hash`; status `pendente` |
| `instituicoes` | `institutions` + `addresses` | CNPJ só dígitos; endereço criado se houver `cidade` |
| `doacoes` | `donations` + `donation_items` | sem usuário vinculado → doação **anônima** |
| `solicitacoes` | `assistance_requests` + item | vinculada ao usuário de origem |
| `usuarios.tipo` | `role_legacy_backup` → `user_roles` | `admin`/`moderador`/`instituicao`/etc. viram papéis |

### O que **não** é copiado

- Linhas de `usuarios` **sem CPF de 11 dígitos** ficam nas tabelas antigas para
  correção manual. A migration nunca apaga a origem.
- Se a tabela antiga não tiver alguma coluna (ex.: `telefone`, `cidade`,
  `categoria`), o campo correspondente fica nulo — nada é inventado.

### Depois da migration

1. Confira os números acima contra o banco antigo:

   ```sql
   SELECT COUNT(*) FROM usuarios;   -- deve bater com usuarios_migrados (+ linhas sem CPF válido)
   SELECT COUNT(*) FROM users;      -- conta nova
   ```

2. Usuários entram com status `pendente`. O login deve pedir redefinição de
   senha, porque o hash antigo pode não ser compatível.
3. As tabelas antigas **continuam existindo** — você pode apagá-las manualmente
   depois de conferir tudo.

---

## Problemas comuns

| Erro | Causa | Solução |
|---|---|---|
| `Unknown database 'ajudamais'` | schema não existe | rode o `CREATE DATABASE` acima ou execute o `01-schema.sql` |
| `Access denied for user` | usuário sem permissão | conecte como `root` ou dê `GRANT ALL ON ajudamais.* TO ...` |
| Acentos quebrados (`CÃ³digo`) | conexão em charset errado | use `--default-character-set=utf8mb4` na conexão |
| `Duplicate entry` ao migrar | migration rodada 2x com dados novos | normal — a migration ignora o que já foi copiado |
| `Cannot add foreign key constraint` | tabela antiga com engine MyISAM | `ALTER TABLE tabela ENGINE=InnoDB;` antes |
| Timeout no Workbench | *Preferences → SQL Editor* | aumente o `DBMS connection read timeout` para 600 |

---

## Conferir que deu certo (script rápido)

```sql
USE ajudamais;

SELECT 'tabelas' AS item, COUNT(*) AS total
  FROM information_schema.tables
 WHERE table_schema = 'ajudamais' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'views', COUNT(*) FROM information_schema.views
 WHERE table_schema = 'ajudamais'
UNION ALL
SELECT 'chaves estrangeiras', COUNT(*)
  FROM information_schema.referential_constraints
 WHERE constraint_schema = 'ajudamais'
UNION ALL
SELECT 'verificacoes (CHECK)', COUNT(*)
  FROM information_schema.table_constraints
 WHERE constraint_schema = 'ajudamais' AND constraint_type = 'CHECK';
```

Resultado esperado:

| item | total |
|---|---|
| tabelas | 39 |
| views | 5 |
| chaves estrangeiras | 76 |
| verificacoes (CHECK) | 49 |

---

## Testar que está tudo funcionando

```sql
USE ajudamais;

-- 1. Deve ser aceito
INSERT INTO users (full_name, email, cpf, password_hash)
VALUES ('Teste', 'teste@exemplo.com', '11144477735', 'hash');

-- 2. Deve FALHAR (CPF com menos de 11 dígitos)
INSERT INTO users (full_name, email, cpf, password_hash)
VALUES ('Errado', 'errado@exemplo.com', '123', 'hash');

-- 3. Deve FALHAR (doação anônima COM doador)
INSERT INTO donations (code, donor_user_id, is_anonymous, donation_type)
VALUES ('X1', 1, 1, 'itens');

-- 4. Deve ser aceito (doação anônima de verdade)
INSERT INTO donations (code, donor_user_id, is_anonymous, donation_type)
VALUES ('X2', NULL, 1, 'itens');

-- limpeza
DELETE FROM donations WHERE code IN ('X1','X2');
DELETE FROM users WHERE email = 'teste@exemplo.com';
```

Se os itens 2 e 3 derem erro e os 1 e 4 funcionarem, o banco está correto.
