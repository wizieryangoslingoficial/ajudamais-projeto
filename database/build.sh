#!/usr/bin/env bash
# Gera database/01-schema.sql e database/02-migration.sql a partir de
# database/parts/. Os dois arquivos compartilham a mesma estrutura, por isso
# a parte estrutural entra nos dois (a migration é autossuficiente).
set -eu
cd "$(dirname "$0")"

mkdir -p build
# Estrutura comum: tabelas, triggers, seeds, views (sem cabeçalho de banco).
cat parts/p01-cabecalho-auth.sql \
    parts/p02-local-institucoes.sql \
    parts/p03-doacoes-logistica.sql \
    parts/p04-comunicacao-moderacao.sql \
    parts/p05-seed-views.sql > build/estrutura.sql

# 01-schema.sql: cabeçalho com CREATE DATABASE/USE + estrutura.
cat parts/p00-schema-header.sql build/estrutura.sql > 01-schema.sql

# 02-migration.sql: cabeçalho sem CREATE DATABASE + estrutura + cópia legada.
# A cópia está dividida em partes para facilitar a manutenção:
#   p12a descoberta da estrutura original (PK e nomes de tabela reais)
#   p12b usuários        p12c instituições/endereços
#   p12d doações         p12e solicitações/termos/auditoria/relatório
{ cat parts/p10-migration-header.sql
  echo
  cat build/estrutura.sql
  echo
  cat parts/p12a-descoberta.sql   parts/p12b-usuarios.sql
  cat parts/p12c-instituicoes.sql parts/p12d-doacoes.sql
  cat parts/p12e-final.sql
} > 02-migration.sql

printf '01-schema.sql: %s linhas\n02-migration.sql: %s linhas\n' \
  "$(wc -l < 01-schema.sql)" "$(wc -l < 02-migration.sql)"
