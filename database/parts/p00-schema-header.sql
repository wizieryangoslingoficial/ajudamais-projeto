-- ============================================================================
-- AJUDAMAIS — ESTRUTURA COMPLETA DO BANCO DE DADOS
-- Arquivo: database/01-schema.sql
-- Compatível com: MySQL 8.0.16+ e MariaDB 10.4+ (InnoDB, utf8mb4)
-- Uso: mysql -u root -p < database/01-schema.sql
--
-- Cria a estrutura do zero e é seguro para reexecução (IF NOT EXISTS +
-- seeds idempotentes). Para bancos que já têm dados do SQL original,
-- use 02-migration.sql.
--
-- Convenções:
--   * Tabelas no plural, colunas em snake_case, nomes de domínio em português.
--   * PK BIGINT UNSIGNED AUTO_INCREMENT; FKs com o mesmo tipo.
--   * Datas/horas em DATETIME (UTC) + created_at/updated_at.
--   * Exclusão lógica (deleted_at) nas entidades de negócio.
--   * Status em VARCHAR + CHECK (evolui sem ALTER de ENUM).
--   * Nomes: fk_<tabela>_<coluna>, uq_..., idx_..., chk_....
--   * Dinheiro em DECIMAL(12,2); CPF/CNPJ/CEP/telefone só com dígitos.
-- ============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE DATABASE IF NOT EXISTS ajudamais
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE ajudamais;

