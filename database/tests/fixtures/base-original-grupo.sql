-- ============================================================================
-- BASE DE TESTE: estrutura + dados REAIS do grupo (dump de 2026-11-19).
-- Usada pelos testes para validar a migration contra a estrutura verdadeira.
-- Somente para banco de teste. Não é entregável de produção.
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `auditoria_seguranca`;
CREATE TABLE `auditoria_seguranca` (
  `idAuditoria` int NOT NULL AUTO_INCREMENT,
  `idConta` int DEFAULT NULL,
  `acao` varchar(100) DEFAULT NULL,
  `dataHora` timestamp NULL DEFAULT NULL,
  `enderecoIp` varchar(45) DEFAULT NULL,
  `detalhes` text,
  PRIMARY KEY (`idAuditoria`),
  KEY `idConta` (`idConta`),
  CONSTRAINT `auditoria_seguranca_ibfk_1` FOREIGN KEY (`idConta`) REFERENCES `usuarios` (`idConta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS `contatos`;
CREATE TABLE `contatos` (
  `idContato` int NOT NULL AUTO_INCREMENT,
  `idConta` int DEFAULT NULL,
  `telefone` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`idContato`),
  KEY `idConta` (`idConta`),
  CONSTRAINT `contatos_ibfk_1` FOREIGN KEY (`idConta`) REFERENCES `usuarios` (`idConta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS `doacoes_transicoes`;
CREATE TABLE `doacoes_transicoes` (
  `idTransicao` int NOT NULL AUTO_INCREMENT,
  `idDoador` int DEFAULT NULL,
  `idDestinatario` int DEFAULT NULL,
  PRIMARY KEY (`idTransicao`),
  KEY `idDoador` (`idDoador`),
  KEY `idDestinatario` (`idDestinatario`),
  CONSTRAINT `doacoes_transicoes_ibfk_1` FOREIGN KEY (`idDoador`) REFERENCES `usuarios` (`idConta`),
  CONSTRAINT `doacoes_transicoes_ibfk_2` FOREIGN KEY (`idDestinatario`) REFERENCES `usuarios` (`idConta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS `enderecos`;
CREATE TABLE `enderecos` (
  `idEndereco` int NOT NULL AUTO_INCREMENT,
  `idConta` int DEFAULT NULL,
  `logradouro` varchar(150) NOT NULL,
  `cidade` varchar(50) NOT NULL,
  `estado` char(2) NOT NULL,
  `unidade` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`idEndereco`),
  KEY `idConta` (`idConta`),
  CONSTRAINT `enderecos_ibfk_1` FOREIGN KEY (`idConta`) REFERENCES `usuarios` (`idConta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS `orgaos_doacao`;
CREATE TABLE `orgaos_doacao` (
  `idOrgao` int NOT NULL AUTO_INCREMENT,
  `idConta` int DEFAULT NULL,
  `descricao` varchar(100) DEFAULT NULL,
  `categoria` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`idOrgao`),
  KEY `idConta` (`idConta`),
  CONSTRAINT `orgaos_doacao_ibfk_1` FOREIGN KEY (`idConta`) REFERENCES `usuarios` (`idConta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS `usuarios`;
CREATE TABLE `usuarios` (
  `idConta` int NOT NULL AUTO_INCREMENT,
  `senha` varchar(255) DEFAULT NULL,
  `termoAceito` tinyint DEFAULT NULL,
  `termoVersao` varchar(10) DEFAULT NULL,
  `statusConta` int DEFAULT NULL,
  `criadoEm` date DEFAULT NULL,
  `nome` varchar(80) NOT NULL,
  `cpf` char(11) NOT NULL,
  `identificadorGov` varchar(100) DEFAULT NULL,
  `email` varchar(60) DEFAULT NULL,
  PRIMARY KEY (`idConta`),
  UNIQUE KEY `cpf` (`cpf`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `usuarios` VALUES
 (1,'senha123',1,'1.0',1,'2026-01-10','Carlos Silva','12345678901','GOV1001','carlos@gmail.com'),
 (2,'maria456',1,'1.0',1,'2026-01-12','Maria Oliveira','23456789012','GOV1002','maria@gmail.com'),
 (3,'joao789',1,'1.0',1,'2026-01-15','Joao Santos','34567890123','GOV1003','joao@gmail.com'),
 (4,'ana321',1,'1.0',1,'2026-01-18','Ana Costa','45678901234','GOV1004','ana@gmail.com'),
 (5,'pedro654',1,'1.0',1,'2026-01-20','Pedro Almeida','56789012345','GOV1005','pedro@gmail.com'),
 (6,'lucas987',1,'1.0',1,'2026-01-22','Lucas Ferreira','67890123456','GOV1006','lucas@gmail.com'),
 (7,'juliana159',1,'1.0',1,'2026-01-25','Juliana Martins','78901234567','GOV1007','juliana@gmail.com'),
 (8,'gabriel753',1,'1.0',1,'2026-01-28','Gabriel Lima','89012345678','GOV1008','gabriel@gmail.com'),
 (9,'fernanda852',1,'1.0',1,'2026-02-01','Fernanda Rocha','90123456789','GOV1009','fernanda@gmail.com'),
 (10,'ricardo951',1,'1.0',1,'2026-02-05','Ricardo Mendes','01234567890','GOV1010','ricardo@gmail.com');

INSERT INTO `contatos` VALUES
 (1,1,'(14) 99123-4567'),(2,2,'(14) 99234-5678'),(3,3,'(14) 99345-6789'),
 (4,4,'(14) 99456-7890'),(5,5,'(14) 99567-8901'),(6,6,'(14) 99678-9012'),
 (7,7,'(14) 99789-0123'),(8,8,'(14) 99890-1234'),(9,9,'(14) 99901-2345'),
 (10,10,'(14) 99012-3456');

INSERT INTO `enderecos` VALUES
 (1,1,'Rua Amando de Barros, 120','Botucatu','SP','Centro'),
 (2,2,'Rua das Flores, 250','Botucatu','SP','Vila dos Lavradores'),
 (3,3,'Rua dos Pinheiros, 85','Botucatu','SP','Jardim Paraiso'),
 (4,4,'Rua Sao Paulo, 310','Botucatu','SP','Vila Antartica'),
 (5,5,'Rua das Acacias, 440','Botucatu','SP','Cohab I'),
 (6,6,'Rua Bahia, 95','Botucatu','SP','Centro'),
 (7,7,'Rua dos Ipes, 180','Botucatu','SP','Jardim Brasil'),
 (8,8,'Rua Principal, 520','Botucatu','SP','Rubiao Junior'),
 (9,9,'Rua das Palmeiras, 75','Botucatu','SP','Vila dos Lavradores'),
 (10,10,'Rua Minas Gerais, 210','Botucatu','SP','Parque Marajoara');

INSERT INTO `orgaos_doacao` VALUES
 (1,1,'Instituicao de apoio a familias carentes','Assistencia Social'),
 (2,2,'Organizacao de arrecadacao de alimentos','Alimentacao'),
 (3,3,'Projeto de distribuicao de roupas','Vestuario'),
 (4,4,'Instituicao de acolhimento infantil','Assistencia Infantil'),
 (5,5,'Organizacao de arrecadacao de cobertores','Apoio Social'),
 (6,6,'Projeto de apoio comunitario','Assistencia Social'),
 (7,7,'Centro de distribuicao de alimentos','Alimentacao'),
 (8,8,'Projeto de arrecadacao de roupas','Vestuario'),
 (9,9,'Instituicao de apoio a criancas','Assistencia Infantil'),
 (10,10,'Projeto de distribuicao de cobertores','Apoio Social');

INSERT INTO `doacoes_transicoes` VALUES
 (1,1,2),(2,3,4),(3,5,6),(4,7,8),(5,9,10),
 (6,2,3),(7,4,5),(8,6,7),(9,8,9),(10,10,1);

INSERT INTO `auditoria_seguranca` VALUES
 (1,1,'Login','2026-02-15 11:30:00','192.168.1.10','Login realizado com sucesso'),
 (2,2,'Alteracao de dados','2026-02-15 12:15:00','192.168.1.11','Dados pessoais atualizados'),
 (3,3,'Cadastro de doacao','2026-02-15 13:20:00','192.168.1.12','Nova doacao cadastrada'),
 (4,4,'Login','2026-02-15 14:00:00','192.168.1.13','Login realizado com sucesso'),
 (5,5,'Alteracao de senha','2026-02-15 15:30:00','192.168.1.14','Senha alterada'),
 (6,6,'Consulta de doacoes','2026-02-15 16:45:00','192.168.1.15','Lista de doacoes consultada'),
 (7,7,'Logout','2026-02-15 17:10:00','192.168.1.16','Sessao encerrada'),
 (8,8,'Cadastro de endereco','2026-02-15 18:20:00','192.168.1.17','Novo endereco cadastrado'),
 (9,9,'Login','2026-02-15 19:00:00','192.168.1.18','Login realizado com sucesso'),
 (10,10,'Cadastro de contato','2026-02-15 20:30:00','192.168.1.19','Telefone cadastrado');

SET FOREIGN_KEY_CHECKS = 1;
