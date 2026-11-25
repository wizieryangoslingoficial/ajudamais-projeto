-- Gera documentação de colunas e relacionamentos a partir do dicionário
-- de dados (information_schema), garantindo que o documento reflita o
-- banco real. Saída em Markdown, pensada para o arquivo
-- database/docs/03-documentacao-tabelas.md (seção gerada).
--
-- Uso: mysql -u root -p ajudamais --batch --raw < database/tools/gerar-dicionario.sql

SET SESSION group_concat_max_len = 1000000;

SELECT '<!-- INICIO GERADO -->';
SELECT '';
SELECT '## Dicionário de dados';
SELECT '';
SELECT 'Gerado automaticamente a partir do banco `ajudamais`.'
UNION ALL
SELECT CONCAT('Tabelas: ', COUNT(DISTINCT table_name), ' | Colunas: ', COUNT(*))
FROM information_schema.columns WHERE table_schema = DATABASE()
UNION ALL
SELECT CONCAT('Chaves estrangeiras: ', COUNT(*))
FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE()
UNION ALL
SELECT CONCAT('Verificações (CHECK): ', COUNT(*))
FROM information_schema.table_constraints
WHERE constraint_schema = DATABASE() AND constraint_type = 'CHECK';

-- Uma linha por tabela, com colunas resumidas em tabela Markdown.
SELECT ''
UNION ALL SELECT '### Tabelas e colunas'
UNION ALL
SELECT CONCAT('#### ', t.table_name)
FROM information_schema.tables t
WHERE t.table_schema = DATABASE() AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name;

SELECT
  CONCAT('| Coluna | Tipo | Nulo | Chave | Padrão | Extra | Comentário |') 
UNION ALL SELECT '|---|---|---|---|---|---|---|'
UNION ALL
SELECT CONCAT(
  '| `', c.column_name, '` | ',
  c.column_type, ' | ',
  IF(c.is_nullable = 'YES', 'sim', 'não'), ' | ',
  IF(c.column_key = '', '—', c.column_key), ' | ',
  IFNULL(c.column_default, '—'), ' | ',
  IF(c.extra = '', '—', c.extra), ' | ',
  IFNULL(c.column_comment, ''), ' |')
FROM information_schema.columns c
JOIN information_schema.tables t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE c.table_schema = DATABASE() AND t.table_type = 'BASE TABLE'
ORDER BY c.table_name, c.ordinal_position;

-- Relacionamentos (FK de → para).
SELECT ''
UNION ALL SELECT '### Relacionamentos (chaves estrangeiras)'
UNION ALL SELECT '| Tabela | Coluna | Referencia | Ao excluir | Ao atualizar |'
UNION ALL SELECT '|---|---|---|---|---|'
UNION ALL
SELECT CONCAT(
  '| `', k.table_name, '` | `', k.column_name, '` | `',
  k.referenced_table_name, '`.`', k.referenced_column_name, '` | ',
  IFNULL(r.delete_rule, '—'), ' | ', IFNULL(r.update_rule, '—'), ' |')
FROM information_schema.key_column_usage k
JOIN information_schema.referential_constraints r
  ON r.constraint_schema = k.constraint_schema
 AND r.constraint_name = k.constraint_name
WHERE k.table_schema = DATABASE() AND k.referenced_table_name IS NOT NULL
ORDER BY k.table_name, k.ordinal_position;

-- Índices e verificação de unicidade.
SELECT ''
UNION ALL SELECT '### Índices por tabela'
UNION ALL SELECT '| Tabela | Índice | Único | Colunas |'
UNION ALL SELECT '|---|---|---|---|'
UNION ALL
SELECT CONCAT(
  '| `', table_name, '` | ', index_name, ' | ',
  IF(non_unique = 0, 'sim', 'não'), ' | ',
  GROUP_CONCAT(column_name ORDER BY seq_in_index), ' |')
FROM information_schema.statistics
WHERE table_schema = DATABASE()
GROUP BY table_name, index_name, non_unique
ORDER BY table_name, index_name;
