/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.11.19-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: ajudamais
-- ------------------------------------------------------
-- Server version	10.11.19-MariaDB-0+deb12u1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `addresses`
--

DROP TABLE IF EXISTS `addresses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `addresses` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `institution_id` bigint(20) unsigned DEFAULT NULL,
  `label` varchar(60) DEFAULT NULL COMMENT 'Ex.: Casa, Trabalho, Sede, Ponto de coleta',
  `address_type` varchar(20) NOT NULL DEFAULT 'residencial',
  `postal_code` char(8) DEFAULT NULL COMMENT 'CEP só com dígitos',
  `street` varchar(180) NOT NULL,
  `number` varchar(20) DEFAULT NULL,
  `complement` varchar(120) DEFAULT NULL,
  `district` varchar(120) DEFAULT NULL,
  `city` varchar(120) NOT NULL,
  `state_code` char(2) DEFAULT NULL,
  `country_code` char(2) NOT NULL DEFAULT 'BR',
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `reference_point` varchar(180) DEFAULT NULL,
  `is_primary` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_addresses_user` (`user_id`),
  KEY `idx_addresses_institution` (`institution_id`),
  KEY `idx_addresses_city_state` (`state_code`,`city`),
  KEY `idx_addresses_postal_code` (`postal_code`),
  CONSTRAINT `fk_addresses_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_addresses_state` FOREIGN KEY (`state_code`) REFERENCES `states` (`code`) ON DELETE SET NULL,
  CONSTRAINT `fk_addresses_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_addresses_single_owner` CHECK (`user_id` is null <> (`institution_id` is null)),
  CONSTRAINT `chk_addresses_type` CHECK (`address_type` in ('residencial','comercial','coleta','entrega','cobranca'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `addresses`
--

LOCK TABLES `addresses` WRITE;
/*!40000 ALTER TABLE `addresses` DISABLE KEYS */;
/*!40000 ALTER TABLE `addresses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `app_settings`
--

DROP TABLE IF EXISTS `app_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `app_settings` (
  `setting_key` varchar(80) NOT NULL,
  `setting_value` varchar(500) DEFAULT NULL,
  `value_type` varchar(20) NOT NULL DEFAULT 'string',
  `description` varchar(255) DEFAULT NULL,
  `updated_by` bigint(20) unsigned DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`setting_key`),
  KEY `idx_app_settings_updated_by` (`updated_by`),
  CONSTRAINT `fk_app_settings_updated_by` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_app_settings_type` CHECK (`value_type` in ('string','int','decimal','bool','json'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `app_settings`
--

LOCK TABLES `app_settings` WRITE;
/*!40000 ALTER TABLE `app_settings` DISABLE KEYS */;
INSERT INTO `app_settings` VALUES
('doacao.anonima.ativa','1','bool','Permite o fluxo de doação anônima',NULL,'2026-11-25 04:04:55'),
('doacao.codigo.prefixo','AJM','string','Prefixo do código público da doação',NULL,'2026-11-25 04:04:55'),
('doacao.item.quantidade.max','999','int','Quantidade máxima por item na doação',NULL,'2026-11-25 04:04:55'),
('lgpd.retencao_meses','24','int','Retenção de dados de contas inativas',NULL,'2026-11-25 04:04:55'),
('login.bloqueio_min','15','int','Minutos de bloqueio após exceder tentativas',NULL,'2026-11-25 04:04:55'),
('login.max_tentativas','5','int','Tentativas de login antes do bloqueio',NULL,'2026-11-25 04:04:55'),
('moderacao.auto_aprovar_instituicao','0','bool','Aprova instituições sem análise manual',NULL,'2026-11-25 04:04:55'),
('senha.reset.validade_min','60','int','Validade do link de redefinição de senha',NULL,'2026-11-25 04:04:55'),
('solicitacao.prazo.dias','30','int','Dias até a expiração automática de uma necessidade',NULL,'2026-11-25 04:04:55'),
('verificacao.codigo.tentativas','5','int','Tentativas permitidas por código',NULL,'2026-11-25 04:04:55'),
('verificacao.codigo.validade_min','10','int','Validade do código de verificação em minutos',NULL,'2026-11-25 04:04:55');
/*!40000 ALTER TABLE `app_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `assistance_requests`
--

DROP TABLE IF EXISTS `assistance_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `assistance_requests` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `institution_id` bigint(20) unsigned DEFAULT NULL,
  `requester_user_id` bigint(20) unsigned DEFAULT NULL,
  `campaign_id` bigint(20) unsigned DEFAULT NULL,
  `title` varchar(150) NOT NULL,
  `description` text DEFAULT NULL,
  `category_id` smallint(5) unsigned DEFAULT NULL COMMENT 'Categoria principal, usada em filtros',
  `priority` varchar(20) NOT NULL DEFAULT 'normal',
  `beneficiary_count` smallint(5) unsigned DEFAULT NULL COMMENT 'Quantas pessoas serão atendidas',
  `city` varchar(120) DEFAULT NULL,
  `state_code` char(2) DEFAULT NULL,
  `address_id` bigint(20) unsigned DEFAULT NULL,
  `is_public` tinyint(1) NOT NULL DEFAULT 1,
  `allows_anonymous` tinyint(1) NOT NULL DEFAULT 1,
  `needed_by` date DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'aberta',
  `published_at` datetime DEFAULT NULL,
  `closed_at` datetime DEFAULT NULL,
  `close_reason` varchar(255) DEFAULT NULL,
  `moderated_by` bigint(20) unsigned DEFAULT NULL,
  `moderated_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_requests_institution` (`institution_id`,`status`),
  KEY `idx_requests_requester` (`requester_user_id`,`status`),
  KEY `idx_requests_campaign` (`campaign_id`),
  KEY `idx_requests_status_public` (`is_public`,`status`,`created_at`),
  KEY `idx_requests_location` (`state_code`,`city`),
  KEY `idx_requests_category` (`category_id`),
  KEY `idx_requests_address` (`address_id`),
  KEY `idx_requests_moderated_by` (`moderated_by`),
  CONSTRAINT `fk_requests_address` FOREIGN KEY (`address_id`) REFERENCES `addresses` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_requests_campaign` FOREIGN KEY (`campaign_id`) REFERENCES `campaigns` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_requests_category` FOREIGN KEY (`category_id`) REFERENCES `item_categories` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_requests_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_requests_moderated_by` FOREIGN KEY (`moderated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_requests_requester` FOREIGN KEY (`requester_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_requests_state` FOREIGN KEY (`state_code`) REFERENCES `states` (`code`) ON DELETE SET NULL,
  CONSTRAINT `chk_requests_single_requester` CHECK (`institution_id` is null <> (`requester_user_id` is null)),
  CONSTRAINT `chk_requests_priority` CHECK (`priority` in ('baixa','normal','alta','urgente')),
  CONSTRAINT `chk_requests_status` CHECK (`status` in ('rascunho','aberta','parcialmente_atendida','atendida','expirada','cancelada','bloqueada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `assistance_requests`
--

LOCK TABLES `assistance_requests` WRITE;
/*!40000 ALTER TABLE `assistance_requests` DISABLE KEYS */;
/*!40000 ALTER TABLE `assistance_requests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `audit_logs`
--

DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `actor_id` bigint(20) unsigned DEFAULT NULL,
  `action` varchar(60) NOT NULL,
  `entity_type` varchar(40) NOT NULL,
  `entity_id` bigint(20) unsigned DEFAULT NULL,
  `old_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`old_values`)),
  `new_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`new_values`)),
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_audit_logs_actor` (`actor_id`,`created_at`),
  KEY `idx_audit_logs_entity` (`entity_type`,`entity_id`),
  KEY `idx_audit_logs_action` (`action`,`created_at`),
  CONSTRAINT `fk_audit_logs_actor` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `audit_logs`
--

LOCK TABLES `audit_logs` WRITE;
/*!40000 ALTER TABLE `audit_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `audit_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `campaigns`
--

DROP TABLE IF EXISTS `campaigns`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `campaigns` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `institution_id` bigint(20) unsigned NOT NULL,
  `title` varchar(150) NOT NULL,
  `slug` varchar(160) NOT NULL,
  `description` text DEFAULT NULL,
  `cover_url` varchar(500) DEFAULT NULL,
  `goal_type` varchar(10) NOT NULL DEFAULT 'itens',
  `goal_amount` decimal(12,2) DEFAULT NULL,
  `goal_quantity` int(10) unsigned DEFAULT NULL,
  `starts_at` datetime NOT NULL DEFAULT current_timestamp(),
  `ends_at` datetime DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'rascunho',
  `created_by` bigint(20) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_campaigns_slug` (`slug`),
  KEY `idx_campaigns_institution` (`institution_id`),
  KEY `idx_campaigns_status` (`status`),
  KEY `idx_campaigns_created_by` (`created_by`),
  CONSTRAINT `fk_campaigns_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_campaigns_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_campaigns_goal` CHECK (`goal_type` in ('itens','dinheiro')),
  CONSTRAINT `chk_campaigns_status` CHECK (`status` in ('rascunho','ativa','encerrada','cancelada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `campaigns`
--

LOCK TABLES `campaigns` WRITE;
/*!40000 ALTER TABLE `campaigns` DISABLE KEYS */;
/*!40000 ALTER TABLE `campaigns` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `collection_points`
--

DROP TABLE IF EXISTS `collection_points`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `collection_points` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `institution_id` bigint(20) unsigned NOT NULL,
  `address_id` bigint(20) unsigned NOT NULL,
  `name` varchar(120) NOT NULL,
  `instructions` varchar(500) DEFAULT NULL,
  `opening_hours` varchar(120) DEFAULT NULL COMMENT 'Ex.: seg a sex, 9h às 17h',
  `contact_phone` varchar(16) DEFAULT NULL,
  `accepts_items` tinyint(1) NOT NULL DEFAULT 1,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_collection_points_institution` (`institution_id`),
  KEY `idx_collection_points_address` (`address_id`),
  CONSTRAINT `fk_collection_points_address` FOREIGN KEY (`address_id`) REFERENCES `addresses` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_collection_points_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `collection_points`
--

LOCK TABLES `collection_points` WRITE;
/*!40000 ALTER TABLE `collection_points` DISABLE KEYS */;
/*!40000 ALTER TABLE `collection_points` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `consents`
--

DROP TABLE IF EXISTS `consents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `consents` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `type` varchar(30) NOT NULL,
  `granted` tinyint(1) NOT NULL DEFAULT 1,
  `version` varchar(20) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `granted_at` datetime NOT NULL DEFAULT current_timestamp(),
  `revoked_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_consents_user_type` (`user_id`,`type`),
  CONSTRAINT `fk_consents_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_consents_type` CHECK (`type` in ('marketing','compartilhar_dados','dados_sensiveis','comunicacoes_doacao'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `consents`
--

LOCK TABLES `consents` WRITE;
/*!40000 ALTER TABLE `consents` DISABLE KEYS */;
/*!40000 ALTER TABLE `consents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `conversation_participants`
--

DROP TABLE IF EXISTS `conversation_participants`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversation_participants` (
  `conversation_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `participant_role` varchar(20) NOT NULL DEFAULT 'membro',
  `last_read_at` datetime DEFAULT NULL,
  `joined_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`conversation_id`,`user_id`),
  KEY `idx_conversation_participants_user` (`user_id`),
  CONSTRAINT `fk_conversation_participants_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_conversation_participants_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_conversation_participants_role` CHECK (`participant_role` in ('doador','instituicao','solicitante','moderador'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversation_participants`
--

LOCK TABLES `conversation_participants` WRITE;
/*!40000 ALTER TABLE `conversation_participants` DISABLE KEYS */;
/*!40000 ALTER TABLE `conversation_participants` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `conversations`
--

DROP TABLE IF EXISTS `conversations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `subject` varchar(150) DEFAULT NULL,
  `donation_id` bigint(20) unsigned DEFAULT NULL,
  `request_id` bigint(20) unsigned DEFAULT NULL,
  `institution_id` bigint(20) unsigned DEFAULT NULL,
  `created_by` bigint(20) unsigned DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'aberta',
  `last_message_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_conversations_donation` (`donation_id`),
  KEY `idx_conversations_request` (`request_id`),
  KEY `idx_conversations_institution` (`institution_id`),
  KEY `idx_conversations_created_by` (`created_by`),
  KEY `idx_conversations_status` (`status`,`last_message_at`),
  CONSTRAINT `fk_conversations_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_conversations_donation` FOREIGN KEY (`donation_id`) REFERENCES `donations` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_conversations_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_conversations_request` FOREIGN KEY (`request_id`) REFERENCES `assistance_requests` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_conversations_status` CHECK (`status` in ('aberta','arquivada','bloqueada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversations`
--

LOCK TABLES `conversations` WRITE;
/*!40000 ALTER TABLE `conversations` DISABLE KEYS */;
/*!40000 ALTER TABLE `conversations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `deliveries`
--

DROP TABLE IF EXISTS `deliveries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `deliveries` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `donation_id` bigint(20) unsigned NOT NULL,
  `method` varchar(20) NOT NULL,
  `collection_point_id` bigint(20) unsigned DEFAULT NULL,
  `origin_address_id` bigint(20) unsigned DEFAULT NULL,
  `destination_address_id` bigint(20) unsigned DEFAULT NULL,
  `carrier_name` varchar(120) DEFAULT NULL,
  `tracking_code` varchar(60) DEFAULT NULL,
  `scheduled_at` datetime DEFAULT NULL,
  `picked_up_at` datetime DEFAULT NULL,
  `delivered_at` datetime DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'agendada',
  `proof_url` varchar(500) DEFAULT NULL,
  `recipient_name` varchar(150) DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `created_by` bigint(20) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_deliveries_donation` (`donation_id`),
  KEY `idx_deliveries_status` (`status`),
  KEY `idx_deliveries_point` (`collection_point_id`),
  KEY `idx_deliveries_origin` (`origin_address_id`),
  KEY `idx_deliveries_destination` (`destination_address_id`),
  KEY `idx_deliveries_created_by` (`created_by`),
  CONSTRAINT `fk_deliveries_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_deliveries_destination` FOREIGN KEY (`destination_address_id`) REFERENCES `addresses` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_deliveries_donation` FOREIGN KEY (`donation_id`) REFERENCES `donations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_deliveries_origin` FOREIGN KEY (`origin_address_id`) REFERENCES `addresses` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_deliveries_point` FOREIGN KEY (`collection_point_id`) REFERENCES `collection_points` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_deliveries_method` CHECK (`method` in ('retirada','ponto_coleta','entrega','correio')),
  CONSTRAINT `chk_deliveries_status` CHECK (`status` in ('agendada','em_transito','entregue','falhou','cancelada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `deliveries`
--

LOCK TABLES `deliveries` WRITE;
/*!40000 ALTER TABLE `deliveries` DISABLE KEYS */;
/*!40000 ALTER TABLE `deliveries` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `donation_items`
--

DROP TABLE IF EXISTS `donation_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `donation_items` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `donation_id` bigint(20) unsigned NOT NULL,
  `request_item_id` bigint(20) unsigned DEFAULT NULL COMMENT 'Item da necessidade que esta doação atende',
  `category_id` smallint(5) unsigned DEFAULT NULL,
  `description` varchar(200) NOT NULL,
  `unit_code` varchar(10) NOT NULL DEFAULT 'un',
  `quantity` decimal(10,2) NOT NULL,
  `item_condition` varchar(20) NOT NULL DEFAULT 'usado',
  `size` varchar(30) DEFAULT NULL,
  `gender` varchar(20) DEFAULT NULL,
  `brand` varchar(80) DEFAULT NULL,
  `expires_on` date DEFAULT NULL COMMENT 'Validade para alimentos e medicamentos',
  `photo_url` varchar(500) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_donation_items_donation` (`donation_id`),
  KEY `idx_donation_items_request_item` (`request_item_id`),
  KEY `idx_donation_items_category` (`category_id`),
  KEY `fk_donation_items_unit` (`unit_code`),
  CONSTRAINT `fk_donation_items_category` FOREIGN KEY (`category_id`) REFERENCES `item_categories` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_donation_items_donation` FOREIGN KEY (`donation_id`) REFERENCES `donations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_donation_items_request_item` FOREIGN KEY (`request_item_id`) REFERENCES `request_items` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_donation_items_unit` FOREIGN KEY (`unit_code`) REFERENCES `item_units` (`code`),
  CONSTRAINT `chk_donation_items_quantity` CHECK (`quantity` > 0),
  CONSTRAINT `chk_donation_items_condition` CHECK (`item_condition` in ('novo','seminovo','usado')),
  CONSTRAINT `chk_donation_items_size` CHECK (`size` is null or `size` in ('rn','pp','p','m','g','gg','xg','unico','infantil','outro'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `donation_items`
--

LOCK TABLES `donation_items` WRITE;
/*!40000 ALTER TABLE `donation_items` DISABLE KEYS */;
/*!40000 ALTER TABLE `donation_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `donation_status_history`
--

DROP TABLE IF EXISTS `donation_status_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `donation_status_history` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `donation_id` bigint(20) unsigned NOT NULL,
  `from_status` varchar(20) DEFAULT NULL,
  `to_status` varchar(20) NOT NULL,
  `changed_by` bigint(20) unsigned DEFAULT NULL COMMENT 'Nulo quando a mudança é automática',
  `note` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_donation_history_donation` (`donation_id`,`created_at`),
  KEY `idx_donation_history_changed_by` (`changed_by`),
  CONSTRAINT `fk_donation_history_changed_by` FOREIGN KEY (`changed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_donation_history_donation` FOREIGN KEY (`donation_id`) REFERENCES `donations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `donation_status_history`
--

LOCK TABLES `donation_status_history` WRITE;
/*!40000 ALTER TABLE `donation_status_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `donation_status_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `donations`
--

DROP TABLE IF EXISTS `donations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `donations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(20) NOT NULL COMMENT 'Código curto exibido ao doador',
  `donor_user_id` bigint(20) unsigned DEFAULT NULL COMMENT 'Nulo em doação anônima',
  `donor_name` varchar(150) DEFAULT NULL COMMENT 'Nome informado no fluxo anônimo (opcional)',
  `donor_email` varchar(254) DEFAULT NULL COMMENT 'Contato para acompanhamento da doação',
  `is_anonymous` tinyint(1) NOT NULL DEFAULT 0,
  `show_name_publicly` tinyint(1) NOT NULL DEFAULT 1,
  `institution_id` bigint(20) unsigned DEFAULT NULL,
  `request_id` bigint(20) unsigned DEFAULT NULL,
  `campaign_id` bigint(20) unsigned DEFAULT NULL,
  `donation_type` varchar(10) NOT NULL DEFAULT 'itens',
  `status` varchar(20) NOT NULL DEFAULT 'pendente',
  `amount` decimal(12,2) DEFAULT NULL,
  `payment_method` varchar(20) DEFAULT NULL,
  `payment_status` varchar(20) DEFAULT NULL,
  `payment_reference` varchar(120) DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL,
  `dropoff_address_id` bigint(20) unsigned DEFAULT NULL COMMENT 'Endereço de retirada informado pelo doador',
  `scheduled_at` datetime DEFAULT NULL,
  `message` varchar(500) DEFAULT NULL,
  `cancel_reason` varchar(255) DEFAULT NULL,
  `confirmed_by` bigint(20) unsigned DEFAULT NULL,
  `confirmed_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_donations_code` (`code`),
  KEY `idx_donations_donor` (`donor_user_id`,`created_at`),
  KEY `idx_donations_institution` (`institution_id`,`status`),
  KEY `idx_donations_request` (`request_id`),
  KEY `idx_donations_campaign` (`campaign_id`),
  KEY `idx_donations_status` (`status`,`created_at`),
  KEY `idx_donations_payment` (`payment_status`),
  KEY `idx_donations_dropoff` (`dropoff_address_id`),
  KEY `idx_donations_confirmed_by` (`confirmed_by`),
  CONSTRAINT `fk_donations_campaign` FOREIGN KEY (`campaign_id`) REFERENCES `campaigns` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_donations_confirmed_by` FOREIGN KEY (`confirmed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_donations_donor` FOREIGN KEY (`donor_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_donations_dropoff` FOREIGN KEY (`dropoff_address_id`) REFERENCES `addresses` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_donations_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_donations_request` FOREIGN KEY (`request_id`) REFERENCES `assistance_requests` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_donations_type` CHECK (`donation_type` in ('itens','dinheiro')),
  CONSTRAINT `chk_donations_amount` CHECK (`amount` is null or `amount` >= 0),
  CONSTRAINT `chk_donations_money_requires_amount` CHECK (`donation_type` <> 'dinheiro' or `amount` is not null and `amount` > 0),
  CONSTRAINT `chk_donations_identifier` CHECK (`donor_user_id` is null = (`is_anonymous` = 1)),
  CONSTRAINT `chk_donations_status` CHECK (`status` in ('pendente','confirmada','em_transito','recebida','cancelada','recusada')),
  CONSTRAINT `chk_donations_payment_method` CHECK (`payment_method` is null or `payment_method` in ('pix','transferencia','cartao','boleto','dinheiro')),
  CONSTRAINT `chk_donations_payment_status` CHECK (`payment_status` is null or `payment_status` in ('pendente','pago','estornado','falhou'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `donations`
--

LOCK TABLES `donations` WRITE;
/*!40000 ALTER TABLE `donations` DISABLE KEYS */;
/*!40000 ALTER TABLE `donations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `favorites`
--

DROP TABLE IF EXISTS `favorites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `favorites` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `institution_id` bigint(20) unsigned DEFAULT NULL,
  `request_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_favorites_user_institution` (`user_id`,`institution_id`),
  UNIQUE KEY `uq_favorites_user_request` (`user_id`,`request_id`),
  KEY `idx_favorites_institution` (`institution_id`),
  KEY `idx_favorites_request` (`request_id`),
  CONSTRAINT `fk_favorites_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_favorites_request` FOREIGN KEY (`request_id`) REFERENCES `assistance_requests` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_favorites_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_favorites_single_target` CHECK (`institution_id` is null <> (`request_id` is null))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `favorites`
--

LOCK TABLES `favorites` WRITE;
/*!40000 ALTER TABLE `favorites` DISABLE KEYS */;
/*!40000 ALTER TABLE `favorites` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `institution_documents`
--

DROP TABLE IF EXISTS `institution_documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `institution_documents` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `institution_id` bigint(20) unsigned NOT NULL,
  `document_type` varchar(30) NOT NULL,
  `file_url` varchar(500) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'pendente',
  `reviewed_by` bigint(20) unsigned DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_institution_documents_institution` (`institution_id`),
  KEY `idx_institution_documents_status` (`status`),
  KEY `idx_institution_documents_reviewed_by` (`reviewed_by`),
  CONSTRAINT `fk_institution_documents_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_institution_documents_reviewed_by` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_institution_documents_type` CHECK (`document_type` in ('cnpj','estatuto','ata','comprovante_endereco','outro')),
  CONSTRAINT `chk_institution_documents_status` CHECK (`status` in ('pendente','aprovado','recusado'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `institution_documents`
--

LOCK TABLES `institution_documents` WRITE;
/*!40000 ALTER TABLE `institution_documents` DISABLE KEYS */;
/*!40000 ALTER TABLE `institution_documents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `institution_members`
--

DROP TABLE IF EXISTS `institution_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `institution_members` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `institution_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `member_role` varchar(20) NOT NULL DEFAULT 'voluntario',
  `status` varchar(20) NOT NULL DEFAULT 'ativo',
  `invited_by` bigint(20) unsigned DEFAULT NULL,
  `joined_at` datetime NOT NULL DEFAULT current_timestamp(),
  `left_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_institution_members` (`institution_id`,`user_id`),
  KEY `idx_institution_members_user` (`user_id`),
  KEY `idx_institution_members_invited_by` (`invited_by`),
  CONSTRAINT `fk_institution_members_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_institution_members_invited_by` FOREIGN KEY (`invited_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_institution_members_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_institution_members_role` CHECK (`member_role` in ('admin','gestor','atendente','voluntario')),
  CONSTRAINT `chk_institution_members_status` CHECK (`status` in ('convidado','ativo','suspenso','removido'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `institution_members`
--

LOCK TABLES `institution_members` WRITE;
/*!40000 ALTER TABLE `institution_members` DISABLE KEYS */;
/*!40000 ALTER TABLE `institution_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `institution_payment_methods`
--

DROP TABLE IF EXISTS `institution_payment_methods`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `institution_payment_methods` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `institution_id` bigint(20) unsigned NOT NULL,
  `method` varchar(20) NOT NULL,
  `pix_key` varchar(140) DEFAULT NULL,
  `pix_key_type` varchar(20) DEFAULT NULL,
  `bank_name` varchar(80) DEFAULT NULL,
  `bank_code` varchar(10) DEFAULT NULL,
  `branch` varchar(20) DEFAULT NULL,
  `account_number` varchar(30) DEFAULT NULL,
  `account_type` varchar(20) DEFAULT NULL,
  `holder_name` varchar(150) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_institution_payment_methods_institution` (`institution_id`),
  CONSTRAINT `fk_institution_payment_methods_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_institution_payment_methods_method` CHECK (`method` in ('pix','transferencia','cartao','boleto')),
  CONSTRAINT `chk_institution_payment_methods_pix_type` CHECK (`pix_key_type` is null or `pix_key_type` in ('cpf','cnpj','email','telefone','aleatoria'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `institution_payment_methods`
--

LOCK TABLES `institution_payment_methods` WRITE;
/*!40000 ALTER TABLE `institution_payment_methods` DISABLE KEYS */;
/*!40000 ALTER TABLE `institution_payment_methods` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `institutions`
--

DROP TABLE IF EXISTS `institutions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `institutions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `legal_name` varchar(180) NOT NULL,
  `trade_name` varchar(150) DEFAULT NULL,
  `cnpj` char(14) DEFAULT NULL,
  `institution_type` varchar(30) NOT NULL DEFAULT 'ong',
  `description` text DEFAULT NULL,
  `mission` varchar(500) DEFAULT NULL,
  `logo_url` varchar(500) DEFAULT NULL,
  `cover_url` varchar(500) DEFAULT NULL,
  `email` varchar(254) NOT NULL,
  `phone_e164` varchar(16) DEFAULT NULL,
  `whatsapp_e164` varchar(16) DEFAULT NULL,
  `website_url` varchar(500) DEFAULT NULL,
  `instagram_handle` varchar(80) DEFAULT NULL,
  `founded_year` smallint(5) unsigned DEFAULT NULL,
  `accepts_items` tinyint(1) NOT NULL DEFAULT 1,
  `accepts_money` tinyint(1) NOT NULL DEFAULT 0,
  `accepts_volunteers` tinyint(1) NOT NULL DEFAULT 0,
  `status` varchar(20) NOT NULL DEFAULT 'pendente',
  `verified_at` datetime DEFAULT NULL,
  `verified_by` bigint(20) unsigned DEFAULT NULL,
  `rejection_reason` varchar(255) DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_institutions_cnpj` (`cnpj`),
  KEY `idx_institutions_status` (`status`),
  KEY `idx_institutions_type` (`institution_type`),
  KEY `idx_institutions_name` (`legal_name`),
  KEY `idx_institutions_verified_by` (`verified_by`),
  CONSTRAINT `fk_institutions_verified_by` FOREIGN KEY (`verified_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_institutions_cnpj` CHECK (`cnpj` is null or `cnpj` regexp '^[0-9]{14}$'),
  CONSTRAINT `chk_institutions_type` CHECK (`institution_type` in ('ong','igreja','escola','hospital','abrigo','orgao_publico','grupo_comunitario','outro')),
  CONSTRAINT `chk_institutions_status` CHECK (`status` in ('pendente','verificada','suspensa','encerrada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `institutions`
--

LOCK TABLES `institutions` WRITE;
/*!40000 ALTER TABLE `institutions` DISABLE KEYS */;
/*!40000 ALTER TABLE `institutions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `item_categories`
--

DROP TABLE IF EXISTS `item_categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `item_categories` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` smallint(5) unsigned DEFAULT NULL,
  `slug` varchar(60) NOT NULL,
  `name` varchar(100) NOT NULL,
  `icon` varchar(60) DEFAULT NULL,
  `sort_order` smallint(6) NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_item_categories_slug` (`slug`),
  KEY `idx_item_categories_parent` (`parent_id`),
  CONSTRAINT `fk_item_categories_parent` FOREIGN KEY (`parent_id`) REFERENCES `item_categories` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=26 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `item_categories`
--

LOCK TABLES `item_categories` WRITE;
/*!40000 ALTER TABLE `item_categories` DISABLE KEYS */;
INSERT INTO `item_categories` VALUES
(1,NULL,'alimentos','Alimentos','basket',1,1,'2026-11-25 04:04:55'),
(2,NULL,'roupas','Roupas e calçados','shirt',2,1,'2026-11-25 04:04:55'),
(3,NULL,'higiene','Higiene e limpeza','sparkles',3,1,'2026-11-25 04:04:55'),
(4,NULL,'moveis','Móveis e utensílios','armchair',4,1,'2026-11-25 04:04:55'),
(5,NULL,'eletronicos','Eletrônicos','laptop',5,1,'2026-11-25 04:04:55'),
(6,NULL,'brinquedos','Brinquedos','teddy-bear',6,1,'2026-11-25 04:04:55'),
(7,NULL,'material-escolar','Material escolar','book',7,1,'2026-11-25 04:04:55'),
(8,NULL,'saude','Saúde e medicamentos','heart-pulse',8,1,'2026-11-25 04:04:55'),
(9,NULL,'financeiro','Ajuda financeira','wallet',9,1,'2026-11-25 04:04:55'),
(10,NULL,'outros','Outros','box',99,1,'2026-11-25 04:04:55'),
(11,1,'alimentos-nao-pereciveis','Não perecíveis',NULL,1,1,'2026-11-25 04:04:55'),
(12,1,'alimentos-pereciveis','Perecíveis',NULL,2,1,'2026-11-25 04:04:55'),
(13,1,'agua','Água potável',NULL,3,1,'2026-11-25 04:04:55'),
(14,2,'roupas-infantis','Roupas infantis',NULL,1,1,'2026-11-25 04:04:55'),
(15,2,'roupas-adultas','Roupas adultas',NULL,2,1,'2026-11-25 04:04:55'),
(16,2,'calcados','Calçados',NULL,3,1,'2026-11-25 04:04:55'),
(17,2,'cobertores','Cobertores e agasalhos',NULL,4,1,'2026-11-25 04:04:55'),
(18,3,'higiene-pessoal','Higiene pessoal',NULL,1,1,'2026-11-25 04:04:55'),
(19,3,'fraldas','Fraldas',NULL,2,1,'2026-11-25 04:04:55'),
(20,3,'limpeza','Produtos de limpeza',NULL,3,1,'2026-11-25 04:04:55'),
(21,8,'medicamentos','Medicamentos',NULL,1,1,'2026-11-25 04:04:55'),
(22,8,'equipamentos','Equipamentos e insumos',NULL,2,1,'2026-11-25 04:04:55'),
(23,7,'livros','Livros',NULL,1,1,'2026-11-25 04:04:55'),
(24,7,'cadernos','Cadernos e papelaria',NULL,2,1,'2026-11-25 04:04:55');
/*!40000 ALTER TABLE `item_categories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `item_units`
--

DROP TABLE IF EXISTS `item_units`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `item_units` (
  `code` varchar(10) NOT NULL,
  `name` varchar(40) NOT NULL,
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `item_units`
--

LOCK TABLES `item_units` WRITE;
/*!40000 ALTER TABLE `item_units` DISABLE KEYS */;
INSERT INTO `item_units` VALUES
('cx','Caixa'),
('fardo','Fardo'),
('g','Grama'),
('kg','Quilograma'),
('kit','Kit'),
('l','Litro'),
('ml','Mililitro'),
('par','Par'),
('pct','Pacote'),
('un','Unidade');
/*!40000 ALTER TABLE `item_units` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `messages` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `conversation_id` bigint(20) unsigned NOT NULL,
  `sender_user_id` bigint(20) unsigned DEFAULT NULL,
  `body` text NOT NULL,
  `attachment_url` varchar(500) DEFAULT NULL,
  `read_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_messages_conversation` (`conversation_id`,`created_at`),
  KEY `idx_messages_sender` (`sender_user_id`),
  CONSTRAINT `fk_messages_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_messages_sender` FOREIGN KEY (`sender_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `messages`
--

LOCK TABLES `messages` WRITE;
/*!40000 ALTER TABLE `messages` DISABLE KEYS */;
/*!40000 ALTER TABLE `messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `type` varchar(40) NOT NULL,
  `title` varchar(150) NOT NULL,
  `body` varchar(500) DEFAULT NULL,
  `link_url` varchar(500) DEFAULT NULL,
  `entity_type` varchar(30) DEFAULT NULL,
  `entity_id` bigint(20) unsigned DEFAULT NULL,
  `read_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_notifications_user` (`user_id`,`read_at`,`created_at`),
  KEY `idx_notifications_entity` (`entity_type`,`entity_id`),
  CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_notifications_type` CHECK (`type` in ('doacao_nova','doacao_confirmada','doacao_recebida','doacao_cancelada','solicitacao_nova','solicitacao_atendida','mensagem','verificacao','termos_atualizados','seguranca','sistema'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `password_resets`
--

DROP TABLE IF EXISTS `password_resets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `password_resets` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `token_hash` char(64) NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_password_resets_token_hash` (`token_hash`),
  KEY `idx_password_resets_user` (`user_id`),
  CONSTRAINT `fk_password_resets_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `password_resets`
--

LOCK TABLES `password_resets` WRITE;
/*!40000 ALTER TABLE `password_resets` DISABLE KEYS */;
/*!40000 ALTER TABLE `password_resets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `privacy_requests`
--

DROP TABLE IF EXISTS `privacy_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `privacy_requests` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `email` varchar(254) NOT NULL COMMENT 'Contato de quem pediu, mesmo sem conta',
  `type` varchar(20) NOT NULL,
  `details` text DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'recebida',
  `response` text DEFAULT NULL,
  `handled_by` bigint(20) unsigned DEFAULT NULL,
  `requested_at` datetime NOT NULL DEFAULT current_timestamp(),
  `resolved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_privacy_requests_user` (`user_id`),
  KEY `idx_privacy_requests_status` (`status`),
  KEY `fk_privacy_requests_handler` (`handled_by`),
  CONSTRAINT `fk_privacy_requests_handler` FOREIGN KEY (`handled_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_privacy_requests_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_privacy_requests_type` CHECK (`type` in ('acesso','correcao','exclusao','portabilidade','revogacao')),
  CONSTRAINT `chk_privacy_requests_status` CHECK (`status` in ('recebida','em_analise','atendida','recusada','cancelada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `privacy_requests`
--

LOCK TABLES `privacy_requests` WRITE;
/*!40000 ALTER TABLE `privacy_requests` DISABLE KEYS */;
/*!40000 ALTER TABLE `privacy_requests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reports`
--

DROP TABLE IF EXISTS `reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reports` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `reporter_id` bigint(20) unsigned DEFAULT NULL,
  `target_type` varchar(20) NOT NULL,
  `target_id` bigint(20) unsigned NOT NULL,
  `reason` varchar(40) NOT NULL,
  `details` text DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'aberta',
  `resolution_note` varchar(500) DEFAULT NULL,
  `resolved_by` bigint(20) unsigned DEFAULT NULL,
  `resolved_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_reports_target` (`target_type`,`target_id`),
  KEY `idx_reports_status` (`status`),
  KEY `idx_reports_reporter` (`reporter_id`),
  KEY `idx_reports_resolved_by` (`resolved_by`),
  CONSTRAINT `fk_reports_reporter` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_reports_resolved_by` FOREIGN KEY (`resolved_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_reports_target` CHECK (`target_type` in ('instituicao','solicitacao','doacao','mensagem','usuario')),
  CONSTRAINT `chk_reports_reason` CHECK (`reason` in ('fraude','conteudo_improprio','informacao_falsa','spam','seguranca','outro')),
  CONSTRAINT `chk_reports_status` CHECK (`status` in ('aberta','em_analise','resolvida','arquivada'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reports`
--

LOCK TABLES `reports` WRITE;
/*!40000 ALTER TABLE `reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `request_items`
--

DROP TABLE IF EXISTS `request_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `request_items` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `request_id` bigint(20) unsigned NOT NULL,
  `category_id` smallint(5) unsigned DEFAULT NULL,
  `description` varchar(200) NOT NULL,
  `unit_code` varchar(10) NOT NULL DEFAULT 'un',
  `quantity_requested` decimal(10,2) NOT NULL,
  `size` varchar(30) DEFAULT NULL,
  `gender` varchar(20) DEFAULT NULL,
  `condition_required` varchar(20) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_request_items_request` (`request_id`),
  KEY `idx_request_items_category` (`category_id`),
  KEY `fk_request_items_unit` (`unit_code`),
  CONSTRAINT `fk_request_items_category` FOREIGN KEY (`category_id`) REFERENCES `item_categories` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_request_items_request` FOREIGN KEY (`request_id`) REFERENCES `assistance_requests` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_request_items_unit` FOREIGN KEY (`unit_code`) REFERENCES `item_units` (`code`),
  CONSTRAINT `chk_request_items_quantity` CHECK (`quantity_requested` > 0),
  CONSTRAINT `chk_request_items_condition` CHECK (`condition_required` is null or `condition_required` in ('novo','seminovo','usado','qualquer')),
  CONSTRAINT `chk_request_items_size` CHECK (`size` is null or `size` in ('rn','pp','p','m','g','gg','xg','unico','infantil','outro'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `request_items`
--

LOCK TABLES `request_items` WRITE;
/*!40000 ALTER TABLE `request_items` DISABLE KEYS */;
/*!40000 ALTER TABLE `request_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `request_status_history`
--

DROP TABLE IF EXISTS `request_status_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `request_status_history` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `request_id` bigint(20) unsigned NOT NULL,
  `from_status` varchar(20) DEFAULT NULL,
  `to_status` varchar(20) NOT NULL,
  `changed_by` bigint(20) unsigned DEFAULT NULL,
  `note` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_request_history_request` (`request_id`,`created_at`),
  KEY `idx_request_history_changed_by` (`changed_by`),
  CONSTRAINT `fk_request_history_changed_by` FOREIGN KEY (`changed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_request_history_request` FOREIGN KEY (`request_id`) REFERENCES `assistance_requests` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `request_status_history`
--

LOCK TABLES `request_status_history` WRITE;
/*!40000 ALTER TABLE `request_status_history` DISABLE KEYS */;
/*!40000 ALTER TABLE `request_status_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reviews`
--

DROP TABLE IF EXISTS `reviews`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reviews` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `donation_id` bigint(20) unsigned DEFAULT NULL,
  `institution_id` bigint(20) unsigned NOT NULL,
  `reviewer_id` bigint(20) unsigned NOT NULL,
  `rating` tinyint(3) unsigned NOT NULL,
  `comment` varchar(500) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'publicada',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_reviews_donation` (`donation_id`),
  KEY `idx_reviews_institution` (`institution_id`,`status`),
  KEY `idx_reviews_reviewer` (`reviewer_id`),
  CONSTRAINT `fk_reviews_donation` FOREIGN KEY (`donation_id`) REFERENCES `donations` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_reviews_institution` FOREIGN KEY (`institution_id`) REFERENCES `institutions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reviews_reviewer` FOREIGN KEY (`reviewer_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_reviews_rating` CHECK (`rating` between 1 and 5),
  CONSTRAINT `chk_reviews_status` CHECK (`status` in ('pendente','publicada','oculta'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reviews`
--

LOCK TABLES `reviews` WRITE;
/*!40000 ALTER TABLE `reviews` DISABLE KEYS */;
/*!40000 ALTER TABLE `reviews` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(30) NOT NULL,
  `name` varchar(80) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_roles_code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES
(1,'admin','Administrador','Acesso total ao sistema e à moderação','2026-11-25 04:04:55'),
(2,'moderador','Moderador','Analisa denúncias, instituições e conteúdo','2026-11-25 04:04:55'),
(3,'instituicao','Instituição','Gerencia a instituição, necessidades e doações recebidas','2026-11-25 04:04:55'),
(4,'doador','Doador','Realiza doações de itens ou dinheiro','2026-11-25 04:04:55'),
(5,'beneficiario','Beneficiário','Solicita ajuda e acompanha seus pedidos','2026-11-25 04:04:55'),
(6,'voluntario','Voluntário','Apoia instituições e pontos de coleta','2026-11-25 04:04:55');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `schema_migrations`
--

DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `schema_migrations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `version` varchar(40) NOT NULL,
  `description` varchar(255) NOT NULL,
  `applied_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_schema_migrations_version` (`version`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `schema_migrations`
--

LOCK TABLES `schema_migrations` WRITE;
/*!40000 ALTER TABLE `schema_migrations` DISABLE KEYS */;
INSERT INTO `schema_migrations` VALUES
(1,'2026.11.01','Estrutura completa do banco AjudaMais','2026-11-25 04:04:55');
/*!40000 ALTER TABLE `schema_migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `token_hash` char(64) NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `device_label` varchar(80) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `last_used_at` datetime DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sessions_token_hash` (`token_hash`),
  KEY `idx_sessions_user` (`user_id`),
  KEY `idx_sessions_expires` (`expires_at`),
  CONSTRAINT `fk_sessions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sessions`
--

LOCK TABLES `sessions` WRITE;
/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `states`
--

DROP TABLE IF EXISTS `states`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `states` (
  `code` char(2) NOT NULL,
  `name` varchar(60) NOT NULL,
  `region` varchar(20) NOT NULL,
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `states`
--

LOCK TABLES `states` WRITE;
/*!40000 ALTER TABLE `states` DISABLE KEYS */;
INSERT INTO `states` VALUES
('AC','Acre','Norte'),
('AL','Alagoas','Nordeste'),
('AM','Amazonas','Norte'),
('AP','Amapá','Norte'),
('BA','Bahia','Nordeste'),
('CE','Ceará','Nordeste'),
('DF','Distrito Federal','Centro-Oeste'),
('ES','Espírito Santo','Sudeste'),
('GO','Goiás','Centro-Oeste'),
('MA','Maranhão','Nordeste'),
('MG','Minas Gerais','Sudeste'),
('MS','Mato Grosso do Sul','Centro-Oeste'),
('MT','Mato Grosso','Centro-Oeste'),
('PA','Pará','Norte'),
('PB','Paraíba','Nordeste'),
('PE','Pernambuco','Nordeste'),
('PI','Piauí','Nordeste'),
('PR','Paraná','Sul'),
('RJ','Rio de Janeiro','Sudeste'),
('RN','Rio Grande do Norte','Nordeste'),
('RO','Rondônia','Norte'),
('RR','Roraima','Norte'),
('RS','Rio Grande do Sul','Sul'),
('SC','Santa Catarina','Sul'),
('SE','Sergipe','Nordeste'),
('SP','São Paulo','Sudeste'),
('TO','Tocantins','Norte');
/*!40000 ALTER TABLE `states` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `terms_acceptances`
--

DROP TABLE IF EXISTS `terms_acceptances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `terms_acceptances` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL COMMENT 'Nulo quando o aceite ocorre antes de haver conta',
  `terms_version_id` bigint(20) unsigned NOT NULL,
  `anonymous_id` char(36) DEFAULT NULL COMMENT 'Identifica o aceite na tela inicial sem login',
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `accepted_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_terms_acceptances_user` (`user_id`),
  KEY `idx_terms_acceptances_version` (`terms_version_id`),
  KEY `idx_terms_acceptances_anonymous` (`anonymous_id`),
  CONSTRAINT `fk_terms_acceptances_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_terms_acceptances_version` FOREIGN KEY (`terms_version_id`) REFERENCES `terms_versions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `terms_acceptances`
--

LOCK TABLES `terms_acceptances` WRITE;
/*!40000 ALTER TABLE `terms_acceptances` DISABLE KEYS */;
/*!40000 ALTER TABLE `terms_acceptances` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `terms_versions`
--

DROP TABLE IF EXISTS `terms_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `terms_versions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `version` varchar(20) NOT NULL,
  `title` varchar(150) NOT NULL,
  `body` mediumtext DEFAULT NULL,
  `body_url` varchar(500) DEFAULT NULL,
  `effective_at` datetime NOT NULL DEFAULT current_timestamp(),
  `is_current` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_terms_versions_version` (`version`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `terms_versions`
--

LOCK TABLES `terms_versions` WRITE;
/*!40000 ALTER TABLE `terms_versions` DISABLE KEYS */;
INSERT INTO `terms_versions` VALUES
(1,'1.0','Termos de Uso e Política de Privacidade',NULL,NULL,'2026-11-25 04:04:55',1,'2026-11-25 04:04:55');
/*!40000 ALTER TABLE `terms_versions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `uploads`
--

DROP TABLE IF EXISTS `uploads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `uploads` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `uploader_id` bigint(20) unsigned DEFAULT NULL,
  `entity_type` varchar(40) DEFAULT NULL,
  `entity_id` bigint(20) unsigned DEFAULT NULL,
  `file_name` varchar(255) NOT NULL,
  `mime_type` varchar(100) NOT NULL,
  `file_size` int(10) unsigned NOT NULL,
  `storage_path` varchar(500) NOT NULL,
  `public_url` varchar(500) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_uploads_entity` (`entity_type`,`entity_id`),
  KEY `idx_uploads_uploader` (`uploader_id`),
  CONSTRAINT `fk_uploads_uploader` FOREIGN KEY (`uploader_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `uploads`
--

LOCK TABLES `uploads` WRITE;
/*!40000 ALTER TABLE `uploads` DISABLE KEYS */;
/*!40000 ALTER TABLE `uploads` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_roles`
--

DROP TABLE IF EXISTS `user_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_roles` (
  `user_id` bigint(20) unsigned NOT NULL,
  `role_id` smallint(5) unsigned NOT NULL,
  `granted_by` bigint(20) unsigned DEFAULT NULL,
  `granted_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`user_id`,`role_id`),
  KEY `idx_user_roles_role` (`role_id`),
  KEY `idx_user_roles_granted_by` (`granted_by`),
  CONSTRAINT `fk_user_roles_granted_by` FOREIGN KEY (`granted_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_user_roles_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_roles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_roles`
--

LOCK TABLES `user_roles` WRITE;
/*!40000 ALTER TABLE `user_roles` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `full_name` varchar(150) NOT NULL,
  `display_name` varchar(80) DEFAULT NULL,
  `email` varchar(254) NOT NULL,
  `email_verified_at` datetime DEFAULT NULL,
  `cpf` char(11) NOT NULL,
  `cpf_verified_at` datetime DEFAULT NULL,
  `govbr_sub` varchar(64) DEFAULT NULL COMMENT 'Claim sub devolvida pelo Gov.br',
  `govbr_verified_at` datetime DEFAULT NULL,
  `phone_e164` varchar(16) DEFAULT NULL COMMENT 'Celular como +5511999999999',
  `phone_verified_at` datetime DEFAULT NULL,
  `birth_date` date DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `password_algo` varchar(20) NOT NULL DEFAULT 'bcrypt',
  `must_change_password` tinyint(1) NOT NULL DEFAULT 0,
  `avatar_url` varchar(500) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'pendente',
  `login_attempts` smallint(5) unsigned NOT NULL DEFAULT 0,
  `locked_until` datetime DEFAULT NULL,
  `last_login_at` datetime DEFAULT NULL,
  `terms_accepted_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_email` (`email`),
  UNIQUE KEY `uq_users_cpf` (`cpf`),
  UNIQUE KEY `uq_users_govbr_sub` (`govbr_sub`),
  UNIQUE KEY `uq_users_phone_e164` (`phone_e164`),
  KEY `idx_users_status` (`status`),
  KEY `idx_users_created_at` (`created_at`),
  CONSTRAINT `chk_users_cpf_digits` CHECK (`cpf` regexp '^[0-9]{11}$'),
  CONSTRAINT `chk_users_status` CHECK (`status` in ('pendente','ativo','suspenso','inativo','excluido'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=``*/ /*!50003 TRIGGER trg_users_bd_anonymize_donations
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
  UPDATE donations
     SET is_anonymous = 1,
         donor_user_id = NULL,
         donor_name = NULL,
         donor_email = NULL,
         show_name_publicly = 0
   WHERE donor_user_id = OLD.id;
END 
*/;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Temporary table structure for view `v_donations_overview`
--

DROP TABLE IF EXISTS `v_donations_overview`;
/*!50001 DROP VIEW IF EXISTS `v_donations_overview`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_donations_overview` AS SELECT
 NULL AS `id`,
 NULL AS `code`,
 NULL AS `donation_type`,
 NULL AS `status`,
 NULL AS `amount`,
 NULL AS `payment_status`,
 NULL AS `is_anonymous`,
 NULL AS `created_at`,
 NULL AS `confirmed_at`,
 NULL AS `donor_user_id`,
 NULL AS `donor_display_name`,
 NULL AS `institution_id`,
 NULL AS `institution_name`,
 NULL AS `request_title`,
 NULL AS `items_lines`,
 NULL AS `items_quantity` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_institution_impact`
--

DROP TABLE IF EXISTS `v_institution_impact`;
/*!50001 DROP VIEW IF EXISTS `v_institution_impact`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_institution_impact` AS SELECT
 NULL AS `institution_id`,
 NULL AS `donations_count`,
 NULL AS `money_total`,
 NULL AS `items_total`,
 NULL AS `requests_count` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_institutions_public`
--

DROP TABLE IF EXISTS `v_institutions_public`;
/*!50001 DROP VIEW IF EXISTS `v_institutions_public`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_institutions_public` AS SELECT
 NULL AS `id`,
 NULL AS `legal_name`,
 NULL AS `trade_name`,
 NULL AS `institution_type`,
 NULL AS `description`,
 NULL AS `mission`,
 NULL AS `logo_url`,
 NULL AS `cover_url`,
 NULL AS `website_url`,
 NULL AS `instagram_handle`,
 NULL AS `accepts_items`,
 NULL AS `accepts_money`,
 NULL AS `accepts_volunteers`,
 NULL AS `status`,
 NULL AS `verified_at`,
 NULL AS `city`,
 NULL AS `state_code`,
 NULL AS `average_rating`,
 NULL AS `reviews_count` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_request_items_progress`
--

DROP TABLE IF EXISTS `v_request_items_progress`;
/*!50001 DROP VIEW IF EXISTS `v_request_items_progress`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_request_items_progress` AS SELECT
 NULL AS `id`,
 NULL AS `request_id`,
 NULL AS `description`,
 NULL AS `unit_code`,
 NULL AS `quantity_requested`,
 NULL AS `quantity_received`,
 NULL AS `quantity_remaining`,
 NULL AS `computed_status` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_request_progress`
--

DROP TABLE IF EXISTS `v_request_progress`;
/*!50001 DROP VIEW IF EXISTS `v_request_progress`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_request_progress` AS SELECT
 NULL AS `id`,
 NULL AS `institution_id`,
 NULL AS `requester_user_id`,
 NULL AS `title`,
 NULL AS `status`,
 NULL AS `priority`,
 NULL AS `needed_by`,
 NULL AS `city`,
 NULL AS `state_code`,
 NULL AS `is_public`,
 NULL AS `created_at`,
 NULL AS `items_count`,
 NULL AS `quantity_requested`,
 NULL AS `quantity_received`,
 NULL AS `percent_complete` */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `verification_codes`
--

DROP TABLE IF EXISTS `verification_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `verification_codes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `channel` varchar(10) NOT NULL,
  `destination` varchar(254) NOT NULL COMMENT 'E-mail ou celular que recebeu o código',
  `purpose` varchar(30) NOT NULL,
  `code_hash` char(64) NOT NULL,
  `attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `ip_address` varchar(45) DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `verified_at` datetime DEFAULT NULL,
  `consumed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_verification_codes_lookup` (`destination`,`purpose`,`expires_at`),
  KEY `idx_verification_codes_user` (`user_id`),
  CONSTRAINT `fk_verification_codes_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_verification_codes_channel` CHECK (`channel` in ('email','sms','whatsapp')),
  CONSTRAINT `chk_verification_codes_purpose` CHECK (`purpose` in ('cadastro','recuperar_conta','login','trocar_senha','trocar_contato'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `verification_codes`
--

LOCK TABLES `verification_codes` WRITE;
/*!40000 ALTER TABLE `verification_codes` DISABLE KEYS */;
/*!40000 ALTER TABLE `verification_codes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `volunteer_profiles`
--

DROP TABLE IF EXISTS `volunteer_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `volunteer_profiles` (
  `user_id` bigint(20) unsigned NOT NULL,
  `bio` varchar(500) DEFAULT NULL,
  `skills` varchar(500) DEFAULT NULL,
  `availability` varchar(120) DEFAULT NULL COMMENT 'Ex.: seg/qua à tarde',
  `has_transport` tinyint(1) NOT NULL DEFAULT 0,
  `max_distance_km` smallint(5) unsigned DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'ativo',
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_volunteer_profiles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_volunteer_profiles_status` CHECK (`status` in ('ativo','inativo'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `volunteer_profiles`
--

LOCK TABLES `volunteer_profiles` WRITE;
/*!40000 ALTER TABLE `volunteer_profiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `volunteer_profiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'ajudamais'
--

--
-- Final view structure for view `v_donations_overview`
--

/*!50001 DROP VIEW IF EXISTS `v_donations_overview`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED DEFINER=`` SQL SECURITY DEFINER VIEW `v_donations_overview` AS select `d`.`id` AS `id`,`d`.`code` AS `code`,`d`.`donation_type` AS `donation_type`,`d`.`status` AS `status`,`d`.`amount` AS `amount`,`d`.`payment_status` AS `payment_status`,`d`.`is_anonymous` AS `is_anonymous`,`d`.`created_at` AS `created_at`,`d`.`confirmed_at` AS `confirmed_at`,`d`.`donor_user_id` AS `donor_user_id`,coalesce(`u`.`full_name`,`d`.`donor_name`) AS `donor_display_name`,`i`.`id` AS `institution_id`,coalesce(`i`.`trade_name`,`i`.`legal_name`) AS `institution_name`,`r`.`title` AS `request_title`,count(`di`.`id`) AS `items_lines`,coalesce(sum(`di`.`quantity`),0) AS `items_quantity` from ((((`donations` `d` left join `users` `u` on(`u`.`id` = `d`.`donor_user_id`)) left join `institutions` `i` on(`i`.`id` = `d`.`institution_id`)) left join `assistance_requests` `r` on(`r`.`id` = `d`.`request_id`)) left join `donation_items` `di` on(`di`.`donation_id` = `d`.`id`)) where `d`.`deleted_at` is null group by `d`.`id`,`u`.`full_name`,`i`.`id`,`i`.`trade_name`,`i`.`legal_name`,`r`.`title` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_institution_impact`
--

/*!50001 DROP VIEW IF EXISTS `v_institution_impact`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED DEFINER=`` SQL SECURITY DEFINER VIEW `v_institution_impact` AS select `i`.`id` AS `institution_id`,(select count(0) from `donations` `d` where `d`.`institution_id` = `i`.`id` and `d`.`deleted_at` is null and `d`.`status` in ('confirmada','em_transito','recebida')) AS `donations_count`,(select coalesce(sum(`d`.`amount`),0) from `donations` `d` where `d`.`institution_id` = `i`.`id` and `d`.`deleted_at` is null and `d`.`donation_type` = 'dinheiro' and `d`.`status` in ('confirmada','em_transito','recebida')) AS `money_total`,(select coalesce(sum(`di`.`quantity`),0) from (`donation_items` `di` join `donations` `d` on(`d`.`id` = `di`.`donation_id`)) where `d`.`institution_id` = `i`.`id` and `d`.`deleted_at` is null and `d`.`status` in ('confirmada','em_transito','recebida')) AS `items_total`,(select count(0) from `assistance_requests` `rq` where `rq`.`institution_id` = `i`.`id` and `rq`.`deleted_at` is null) AS `requests_count` from `institutions` `i` where `i`.`deleted_at` is null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_institutions_public`
--

/*!50001 DROP VIEW IF EXISTS `v_institutions_public`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED DEFINER=`` SQL SECURITY DEFINER VIEW `v_institutions_public` AS select `i`.`id` AS `id`,`i`.`legal_name` AS `legal_name`,`i`.`trade_name` AS `trade_name`,`i`.`institution_type` AS `institution_type`,`i`.`description` AS `description`,`i`.`mission` AS `mission`,`i`.`logo_url` AS `logo_url`,`i`.`cover_url` AS `cover_url`,`i`.`website_url` AS `website_url`,`i`.`instagram_handle` AS `instagram_handle`,`i`.`accepts_items` AS `accepts_items`,`i`.`accepts_money` AS `accepts_money`,`i`.`accepts_volunteers` AS `accepts_volunteers`,`i`.`status` AS `status`,`i`.`verified_at` AS `verified_at`,`a`.`city` AS `city`,`a`.`state_code` AS `state_code`,round(avg(`r`.`rating`),2) AS `average_rating`,count(`r`.`id`) AS `reviews_count` from ((`institutions` `i` left join `addresses` `a` on(`a`.`institution_id` = `i`.`id` and `a`.`is_primary` = 1)) left join `reviews` `r` on(`r`.`institution_id` = `i`.`id` and `r`.`status` = 'publicada')) where `i`.`deleted_at` is null group by `i`.`id`,`a`.`city`,`a`.`state_code` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_request_items_progress`
--

/*!50001 DROP VIEW IF EXISTS `v_request_items_progress`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED DEFINER=`` SQL SECURITY DEFINER VIEW `v_request_items_progress` AS select `ri`.`id` AS `id`,`ri`.`request_id` AS `request_id`,`ri`.`description` AS `description`,`ri`.`unit_code` AS `unit_code`,`ri`.`quantity_requested` AS `quantity_requested`,coalesce(sum(`di`.`quantity`),0) AS `quantity_received`,greatest(`ri`.`quantity_requested` - coalesce(sum(`di`.`quantity`),0),0) AS `quantity_remaining`,case when coalesce(sum(`di`.`quantity`),0) >= `ri`.`quantity_requested` then 'atendido' when coalesce(sum(`di`.`quantity`),0) > 0 then 'parcial' else 'pendente' end AS `computed_status` from ((`request_items` `ri` left join `donation_items` `di` on(`di`.`request_item_id` = `ri`.`id`)) left join `donations` `d` on(`d`.`id` = `di`.`donation_id` and `d`.`deleted_at` is null and `d`.`status` in ('confirmada','em_transito','recebida'))) group by `ri`.`id` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_request_progress`
--

/*!50001 DROP VIEW IF EXISTS `v_request_progress`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED DEFINER=`` SQL SECURITY DEFINER VIEW `v_request_progress` AS select `r`.`id` AS `id`,`r`.`institution_id` AS `institution_id`,`r`.`requester_user_id` AS `requester_user_id`,`r`.`title` AS `title`,`r`.`status` AS `status`,`r`.`priority` AS `priority`,`r`.`needed_by` AS `needed_by`,`r`.`city` AS `city`,`r`.`state_code` AS `state_code`,`r`.`is_public` AS `is_public`,`r`.`created_at` AS `created_at`,count(`ri`.`id`) AS `items_count`,coalesce(sum(`ri`.`quantity_requested`),0) AS `quantity_requested`,coalesce(sum(`p`.`quantity_received`),0) AS `quantity_received`,case when coalesce(sum(`ri`.`quantity_requested`),0) = 0 then 0 else round(sum(`p`.`quantity_received`) / sum(`ri`.`quantity_requested`) * 100,1) end AS `percent_complete` from ((`assistance_requests` `r` left join `request_items` `ri` on(`ri`.`request_id` = `r`.`id`)) left join `v_request_items_progress` `p` on(`p`.`id` = `ri`.`id`)) where `r`.`deleted_at` is null group by `r`.`id` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-25  4:04:55
