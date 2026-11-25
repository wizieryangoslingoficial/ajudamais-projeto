-- ============================================================================
-- AJUDAMAIS — MIGRATION PARA BANCOS EXISTENTES
-- Arquivo: database/02-migration.sql
-- Compatível com: MySQL 8.0.16+ e MariaDB 10.4+
-- Uso: mysql -u root -p ajudamais < database/02-migration.sql
--
-- O QUE FAZ
--   1. Cria toda a estrutura nova (mesmas tabelas de 01-schema.sql) sem
--      apagar nada do que já existe.
--   2. Se encontrar as tabelas do SQL original em português
--      (usuarios, instituicoes, doacoes, solicitacoes), copia os dados para
--      users, institutions, donations, donation_items e assistance_requests,
--      normalizando CPF/CNPJ/telefone.
--   3. Mantém as tabelas originais intactas. A remoção é manual, só depois
--      de validar o sistema.
--   4. Pode ser executada mais de uma vez: cada cópia é controlada por
--      legacy_*_id, então nada é duplicado.
--
-- ANTES DE EXECUTAR
--   mysqldump -u root -p ajudamais > backup-ajudamais.sql
--   Escolha o banco antes de rodar (USE ajudamais;) — este arquivo não
--   cria nem seleciona banco.
--
-- NÃO HÁ DROP TABLE, TRUNCATE OU DELETE NESTE ARQUIVO.
-- ============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

