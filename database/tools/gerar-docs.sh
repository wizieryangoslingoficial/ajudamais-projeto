#!/usr/bin/env bash
# Gera o dicionário de dados (Markdown) a partir do banco real.
# Uso: bash database/tools/gerar-docs.sh "mariadb --socket=/tmp/x.sock" ajudamais
# Saída: database/docs/gerado-dicionario.md
set -u
CLI="${1:?informe o cliente mysql/mariadb com socket}"
DB="${2:-ajudamais}"
OUT="$(dirname "$0")/../docs/gerado-dicionario.md"
mkdir -p "$(dirname "$OUT")"

q() { $CLI --default-character-set=utf8mb4 --batch --skip-column-names -e "$1" 2>/dev/null; }

{
  echo "<!-- Arquivo gerado por database/tools/gerar-docs.sh — não editar à mão. -->"
  echo
  echo "## Dicionário de dados (gerado do banco)"
  echo
  echo "Tabelas base: $(q "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB' AND table_type='BASE TABLE'") · \
Colunas: $(q "SELECT COUNT(*) FROM information_schema.columns c JOIN information_schema.tables t ON t.table_schema=c.table_schema AND t.table_name=c.table_name WHERE c.table_schema='$DB' AND t.table_type='BASE TABLE'") · \
Chaves estrangeiras: $(q "SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema='$DB'") · \
Verificações: $(q "SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_schema='$DB' AND constraint_type='CHECK'") · \
Índices: $(q "SELECT COUNT(DISTINCT table_name,index_name) FROM information_schema.statistics WHERE table_schema='$DB'")"
  echo

  for t in $(q "SELECT table_name FROM information_schema.tables WHERE table_schema='$DB' AND table_type='BASE TABLE' ORDER BY table_name"); do
    echo "### \`$t\`"
    echo
    echo "| Coluna | Tipo | Nulo | Chave | Padrão | Comentário |"
    echo "|---|---|---|---|---|---|"
    $CLI --default-character-set=utf8mb4 --batch --skip-column-names -e "
      SELECT CONCAT('| \`', column_name, '\` | ', column_type,
                    ' | ', IF(is_nullable='YES','sim','não'),
                    ' | ', IF(column_key='','—',column_key),
                    ' | ', IF(column_default IS NULL,'—',column_default),
                    ' | ', IF(column_comment='','',column_comment), ' |')
      FROM information_schema.columns
      WHERE table_schema='$DB' AND table_name='$t'
      ORDER BY ordinal_position" 2>/dev/null
    echo
    fks=$($CLI --default-character-set=utf8mb4 --batch --skip-column-names -e "
      SELECT CONCAT('- \`', k.column_name, '\` → \`', k.referenced_table_name, '.\`\`', k.referenced_column_name,
                    '\`\`  (ON DELETE ', r.delete_rule, ')')
      FROM information_schema.key_column_usage k
      JOIN information_schema.referential_constraints r
        ON r.constraint_schema=k.constraint_schema AND r.constraint_name=k.constraint_name
      WHERE k.table_schema='$DB' AND k.table_name='$t' AND k.referenced_table_name IS NOT NULL
      ORDER BY k.ordinal_position" 2>/dev/null)
    if [ -n "$fks" ]; then echo "**Referencia:**"; echo; echo "$fks"; echo; fi
  done
} > "$OUT"

echo "Gerado: $OUT ($(wc -l < "$OUT") linhas)"
