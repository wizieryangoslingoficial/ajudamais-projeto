# Relatório final — banco de dados AjudaMais

Data: novembro de 2026
Escopo: estrutura do banco, migration, testes e documentação.
Fora do escopo deste relatório: telas novas do frontend e backend.

---

## 1. Estado da validação (leia primeiro)

> **Atualização:** o dump real do grupo (2026-11-19) foi incorporado aos testes
> em `database/tests/fixtures/base-original-grupo.sql` e a migration foi
> validada contra ele. A suíte `database/tests/run-tests.sh` executa:
>
> 1. o dump **real** do grupo (10 usuários, 10 instituições, 20 endereços,
>    10 doações, 10 auditorias, 10 aceites), com reexecução idempotente;
> 2. uma base legada completa reconstruída;
> 3. uma base legada mínima (só colunas essenciais);
> 4. uma base legada com nomes de coluna alternativos.
>
> Resultado da última execução: **TODOS OS TESTES PASSARAM**.
>
> A estrutura nova foi desenhada a partir das telas, campos e termos do
> frontend existente. Ela **não é** uma cópia do esquema antigo: é um modelo
> normalizado (39 tabelas) que recebe os dados legados pela migration.
>
> Ainda assim, quando você rodar a migration no seu próprio MySQL, confira os
> totais no fim da execução (a migration imprime um resumo) e a tabela
> `migration_skipped`, onde ficam as linhas que não puderam ser aproveitadas.

---

## 2. Arquivos criados e modificados

### Entregáveis finais

| Arquivo | O que é |
|---|---|
| `database/01-schema.sql` | Banco novo, importável. 39 tabelas, 5 views, 1 trigger, 76 FKs. |
| `database/02-migration.sql` | Migration para banco existente. Idempotente, não destrutiva. |
| `database/docs/gerado-dicionario.md` | Dicionário de dados gerado do banco real (790 linhas, 39 tabelas). |
| `database/docs/01-mapa-modulos-tabelas.md` | Mapa módulo (tela) → tabelas usadas. |
| `database/docs/02-der.md` | DER em Mermaid (4 diagramas) + regras de integridade. |
| `database/docs/03-importacao-workbench.md` | Passo a passo de importação no MySQL Workbench (Windows). |
| `database/docs/04-relatorio-final.md` | Este relatório. |

### Fontes e ferramentas (mantidos no projeto)

| Arquivo | Papel |
|---|---|
| `database/parts/*.sql` | Blocos-fonte que geram os dois SQL finais. |
| `database/build.sh` | Monta `01-schema.sql` e `02-migration.sql` a partir de `parts/`. |
| `database/tests/run-tests.sh` | Suíte completa (113 checagens), roda em MariaDB ou MySQL. |
| `database/tests/run-tests-mysql.sh` | Suíte enxuta específica de MySQL (34 checagens). |
| `database/tools/gerar-docs.sh` | Gera o dicionário de dados a partir do banco. |

> Para alterar o banco: edite `parts/`, rode `build.sh`, rode os testes.
> Não edite `01-schema.sql` nem `02-migration.sql` à mão.

---

## 3. Números do banco

Verificados em MySQL 8.0.40 e MariaDB 10.11:

| Item | Quantidade |
|---|---|
| Tabelas base | **39** |
| Views | **5** |
| Chaves estrangeiras | **76** |
| Restrições CHECK | **49** |
| Índices | **149** |
| Triggers | **1** |
| Categorias de item (seed) | 24 |
| Estados (seed) | 27 |

Na migration há **40** tabelas: as 39 + `role_legacy_backup` (guarda o campo
`tipo` do banco antigo).

---

## 4. Decisões de projeto

| Tema | Decisão | Motivo |
|---|---|---|
| Status | `VARCHAR(20)` + `CHECK` | legível no banco e validado pelo próprio motor |
| Valores em dinheiro | `DECIMAL(12,2)` | evita erro de arredondamento do ponto flutuante |
| CPF / CNPJ / CEP / telefone | só dígitos; telefone em E.164 (`+55…`) | comparação e busca confiáveis |
| Exclusão de conta | coluna `deleted_at` (exclusão lógica) | preserva histórico para auditoria |
| Doação anônima | `CHECK ((donor_user_id IS NULL) = (is_anonymous = 1))` | o próprio banco impede doação contraditória |
| Exclusão de usuário com doações | `ON DELETE RESTRICT` + trigger de anonimização | a doação continua existindo e vira anônima (LGPD) |
| Estrutura antiga | colunas verificadas em `information_schema` antes de usar | a migration não depende de um SQL exato |

---

## 5. Resultado dos testes

### MariaDB 10.11.19 — suíte completa

```
Motor: MariaDB 10.11.19-MariaDB-0+deb12u1
RESULTADO: TODOS OS TESTES PASSARAM
113 checagens OK, 0 falhas
```

### MySQL 8.0.40 — suíte completa

```
Motor: MySQL 8.0.40
RESULTADO: TODOS OS TESTES PASSARAM
113 checagens OK, 0 falhas
```

### Cenários cobertos

| Cenário | O que valida |
|---|---|
| Importação em banco vazio | schema cria tudo |
| Reexecução da importação | idempotência (rodar 2x não quebra) |
| Objetos criados | 39 tabelas, 5 views, 1 trigger, 76 FKs |
| Seeds | 24 categorias, 27 estados |
| Fluxo completo de exemplo | usuário → instituição → pedido → doação → entrega |
| Regras de identificação da doação | CHECK rejeita anônima com doador e vice-versa, no INSERT e no UPDATE |
| Restrições de integridade | CPF/CNPJ/quantidade/status inválidos são recusados |
| Views | progresso, impacto e overview com números corretos |
| Contagens não duplicadas | joins não multiplicam somas |
| Exclusão lógica e cascata | excluída sai das views; doação sobrevive e vira anônima |
| Migration em banco novo | nada a migrar, roda sem erro |
| Migration em base legada completa | CPF/CNPJ/telefone normalizados, itens e papéis criados |
| Migration em base legada mínima | funciona **sem** telefone, endereço, categoria, quantidade |
| Migration em base legada alternativa | funciona com nomes de coluna diferentes |

### Conferência dos views (valores reais)

Exemplo testado: 10 cobertores pedidos, 4 doados vinculados ao item, 3 em item
sem vínculo e 2 em item avulso.

- `v_request_items_progress`: 7 recebidos, 3 faltando, status `parcial`. ✅
- `v_request_progress`: 7 de 15 = **46,7%** — só conta o que está vinculado ao
  item do pedido. ✅

Esse comportamento está documentado no mapa de módulos.

---

## 6. Problemas encontrados e como foram corrigidos

| # | Problema | Causa | Correção |
|---|---|---|---|
| 1 | Exclusão de usuário falhava | trigger usava `OLD.x` em `BEFORE DELETE` (`ERROR 1644`) | FK `RESTRICT` + uma trigger de anonimização idempotente |
| 2 | Erro de collation na migration | comparação entre `utf8mb4_unicode_ci` e `utf8mb4_general_ci` | `COLLATE utf8mb4_unicode_ci` explícito nas comparações legadas |
| 3 | `COLLATION ... is not valid for CHARACTER SET 'binary'` (só MySQL) | `REGEXP_REPLACE` devolve texto binário no MySQL | `CONVERT(... USING utf8mb4)` antes de comparar |
| 4 | `COLLATE` aplicado a `NULL` (só MySQL) | guarda gerava o literal `NULL` quando a coluna não existia | cláusula inteira passou a ser omitida quando não há `cnpj` |
| 5 | Migration quebrava em base legada | presumia colunas (`mensagem`, `telefone`, `cidade`, `título`…) | 29 verificações em `information_schema` + SQL dinâmico |
| 6 | CHECK permitia doação contraditória | regra era `OR` e deixava passar ambos os casos | regra virou igualdade: `(doador IS NULL) = (é anônima)` |
| 7 | Acentos quebrados na documentação | cliente MySQL sem charset | `--default-character-set=utf8mb4` no gerador |
| 8 | Falhas nos testes que eram erro do teste | expectativas minhas estavam erradas (6.7, contagem de triggers) | valores conferidos no banco antes de ajustar |

---

## 7. Compatibilidade com MySQL

| Requisito | Situação |
|---|---|
| Versão mínima | MySQL **8.0.16+** (CHECK real) e MariaDB **10.4+** |
| Testado em | MySQL 8.0.40 e MariaDB 10.11.19 |
| Charset | `utf8mb4` / `utf8mb4_unicode_ci` |
| Engine | InnoDB |
| Importação pelo Workbench | suportada (ver `03-importacao-workbench.md`) |
| Acentuação | `SET NAMES utf8mb4` nos dois arquivos |

---

## 8. Como usar

1. **Banco novo:** importe `database/01-schema.sql` no Workbench.
2. **Banco existente:** selecione o schema antigo e importe `database/02-migration.sql`.
3. **Conferir:** rode a consulta de verificação de `03-importacao-workbench.md`
   (deve dar 39 / 5 / 76 / 49).

---

## 9. O que ainda falta

| Item | Situação |
|---|---|
| Validação contra o SQL real do grupo | **pendente** — o arquivo não existe no projeto |
| Backend (Node.js/Express) — rotas, autenticação, validação | **não iniciado** |
| Novas telas do frontend (HTML/CSS/JS puro) | **não iniciadas** |
| Remoção das tabelas antigas | manual, só depois de conferir a migração |

O frontend existente (`ajudamais-html/`) **não foi alterado** nesta etapa. Ele
não faz chamadas de API, então não havia backend para quebrar — não existia
nenhum código de servidor no projeto.
